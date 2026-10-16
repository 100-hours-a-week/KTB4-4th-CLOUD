import http from "k6/http";
import { check } from "k6";
import { SharedArray } from "k6/data";
import { Counter, Rate, Trend } from "k6/metrics";
import exec from "k6/execution";
import { endpoints } from "./config.js";

const BASE_URL = (__ENV.BASE_URL || "https://staging.needu.gift").replace(
  /\/$/,
  "",
);
const RATE = Number(__ENV.RATE || 10);
const DURATION = __ENV.DURATION || "20m";
const VUS = Number(__ENV.VUS || 30);
const MAX_VUS = Number(__ENV.MAX_VUS || 100);
const TIMEOUT = __ENV.TIMEOUT || "10s";
const LOG_REQUESTS = __ENV.LOG_REQUESTS === "true";
const DEBUG_400 = __ENV.DEBUG_400 === "true";

if (
  !Number.isInteger(RATE) ||
  RATE < 1 ||
  !Number.isInteger(VUS) ||
  VUS < 1 ||
  !Number.isInteger(MAX_VUS) ||
  MAX_VUS < VUS
) {
  throw new Error(
    "RATE/VUS/MAX_VUS must be valid positive integers (MAX_VUS >= VUS)",
  );
}

// Load one or more test accounts.
// A single JWT can be shared by all k6 virtual users.
const users = new SharedArray("cutover-users", () => {
  const parsed = JSON.parse(open("./data/users.json"));

  if (!Array.isArray(parsed) || parsed.length < 1) {
    throw new Error("data/users.json must contain at least one test account");
  }

  parsed.forEach((u, i) => {
    if (!u.token || !u.friendUserId || !u.giftUserId) {
      throw new Error(`Missing token/IDs for user ${i}`);
    }
  });

  return parsed;
});

// Custom metrics
const unexpected = new Counter("cutover_unexpected_failures");
const timeouts = new Counter("cutover_timeouts");
const serverErrors = new Counter("cutover_5xx");
const invalidBodies = new Counter("cutover_invalid_bodies");
const success = new Rate("cutover_success");
const latency = new Trend("cutover_latency_ms", true);

export const options = {
  scenarios: {
    cutover_read: {
      executor: "constant-arrival-rate",
      rate: RATE,
      timeUnit: "1s",
      duration: DURATION,
      preAllocatedVUs: VUS,
      maxVUs: MAX_VUS,
      gracefulStop: "5s",
    },
  },

  // k6 is a single DNS observation point,
  // not proof that all clients switched.
  dns: {
    ttl: "0",
    select: "first",
    policy: "preferIPv4",
  },

  noConnectionReuse: true,
  noVUConnectionReuse: true,

  thresholds: {
    cutover_unexpected_failures: ["count==0"],
    cutover_success: ["rate==1"],
    dropped_iterations: ["count==0"],
  },

  summaryTrendStats: ["avg", "min", "med", "p(90)", "p(95)", "p(99)", "max"],
};

export default function () {
  // One HTTP request per iteration.
  // RATE represents total HTTP requests per second.
  const index = exec.scenario.iterationInTest;

  const user = users[index % users.length];
  const endpoint = endpoints[index % endpoints.length];

  const path =
    typeof endpoint.path === "function" ? endpoint.path(user) : endpoint.path;

  const startedAt = new Date().toISOString();

  const res = http.get(`${BASE_URL}${path}`, {
    headers: {
      Cookie: `NEEDU_ACCESS_TOKEN=${user.token}`,
      Accept: "application/json",
    },
    tags: {
      api: endpoint.name,
      name: endpoint.name,
    },
    timeout: TIMEOUT,
    redirects: 0,
  });

  // HTTP 200 validation
  const statusOK = res.status === 200;

  const contentType = String(
    res.headers["Content-Type"] || res.headers["content-type"] || "",
  );

  // JSON response validation
  const bodyOK =
    statusOK &&
    contentType.toLowerCase().includes("json") &&
    Boolean(res.body) &&
    (() => {
      try {
        JSON.parse(res.body);
        return true;
      } catch (_) {
        return false;
      }
    })();

  const ok = statusOK && bodyOK;

  check(
    res,
    {
      "HTTP 200": () => statusOK,
      "valid JSON response": () => bodyOK,
    },
    {
      api: endpoint.name,
    },
  );

  // Metrics
  success.add(ok, {
    api: endpoint.name,
  });

  latency.add(res.timings.duration, {
    api: endpoint.name,
  });

  if (!ok) {
    unexpected.add(1, {
      api: endpoint.name,
      status: String(res.status),
    });
  }

  if (res.status >= 500) {
    serverErrors.add(1, {
      api: endpoint.name,
      status: String(res.status),
    });
  }

  // Status 0 means transport failure, not necessarily a timeout.
  if (res.status === 0) {
    timeouts.add(1, {
      api: endpoint.name,
    });
  }

  if (statusOK && !bodyOK) {
    invalidBodies.add(1, {
      api: endpoint.name,
    });
  }

  // Log failed requests, or all requests when explicitly enabled.
  if (LOG_REQUESTS || !ok) {
    const logEntry = {
      type: "request",
      at: startedAt,
      api: endpoint.name,
      status: res.status,
      duration_ms: res.timings.duration,
      ok,
      error: res.error || null,
    };

    // Temporary debugging: inspect HTTP 400 response bodies.
    // May contain sensitive data; do not share raw logs publicly.
    if (DEBUG_400 && res.status === 400) {
      logEntry.response_body = String(res.body || "").slice(0, 500);
    }

    console.log(JSON.stringify(logEntry));
  }
}

export function handleSummary(data) {
  return {
    "results/summary.json": JSON.stringify(data, null, 2),
  };
}
