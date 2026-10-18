import http from "k6/http";
import { check } from "k6";
import { SharedArray } from "k6/data";
import { Counter, Rate, Trend } from "k6/metrics";
import exec from "k6/execution";
import { endpoints } from "./config.js";

const BASE_URL = (__ENV.BASE_URL || "https://v1.needu.gift").replace(
  /\/+$/,
  "",
);

const RATE = Number(__ENV.RATE || 10);
const DURATION = __ENV.DURATION || "20m";
const VUS = Number(__ENV.VUS || 30);
const MAX_VUS = Number(__ENV.MAX_VUS || 100);
const ITERATIONS = __ENV.ITERATIONS ? Number(__ENV.ITERATIONS) : null;

const TIMEOUT = __ENV.TIMEOUT || "10s";
const LOG_REQUESTS = __ENV.LOG_REQUESTS === "true";
const DEBUG_400 = __ENV.DEBUG_400 === "true";

const EXPECTED_USERS = 20;

if (
  !Number.isInteger(RATE) ||
  RATE < 1 ||
  !Number.isInteger(VUS) ||
  VUS < 1 ||
  !Number.isInteger(MAX_VUS) ||
  MAX_VUS < VUS ||
  (ITERATIONS !== null && (!Number.isInteger(ITERATIONS) || ITERATIONS < 1))
) {
  throw new Error(
    "RATE/VUS/MAX_VUS/ITERATIONS must be valid positive integers",
  );
}

if (!Array.isArray(endpoints) || endpoints.length !== 4) {
  throw new Error("config.js must define exactly 4 endpoints");
}

const users = new SharedArray("cutover-users", () => {
  const parsed = JSON.parse(open("./data/users.json"));

  if (!Array.isArray(parsed) || parsed.length !== EXPECTED_USERS) {
    throw new Error(
      `data/users.json must contain exactly ${EXPECTED_USERS} accounts`,
    );
  }

  const tokens = new Set();

  parsed.forEach((user, index) => {
    if (
      typeof user.token !== "string" ||
      !user.token.trim() ||
      user.token.startsWith("REPLACE_WITH_") ||
      user.friendUserId === undefined ||
      user.friendUserId === null ||
      String(user.friendUserId).trim() === "" ||
      user.giftUserId === undefined ||
      user.giftUserId === null ||
      String(user.giftUserId).trim() === ""
    ) {
      throw new Error(`Invalid account data at index ${index}`);
    }

    if (tokens.has(user.token)) {
      throw new Error(`Duplicate JWT at index ${index}`);
    }

    tokens.add(user.token);
  });

  return parsed;
});

const unexpected = new Counter("cutover_unexpected_failures");
const timeouts = new Counter("cutover_timeouts");
const serverErrors = new Counter("cutover_5xx");
const invalidBodies = new Counter("cutover_invalid_bodies");
const success = new Rate("cutover_success");
const latency = new Trend("cutover_latency_ms", true);

const scenario =
  ITERATIONS !== null
    ? {
        executor: "shared-iterations",
        vus: VUS,
        iterations: ITERATIONS,
        maxDuration: DURATION,
        gracefulStop: "5s",
      }
    : {
        executor: "constant-arrival-rate",
        rate: RATE,
        timeUnit: "1s",
        duration: DURATION,
        preAllocatedVUs: VUS,
        maxVUs: MAX_VUS,
        gracefulStop: "5s",
      };

export const options = {
  scenarios: {
    cutover_read: scenario,
  },

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
  // One iteration = one HTTP request.
  const iteration = exec.scenario.iterationInTest;

  // Each user calls all four APIs.
  const endpointIndex = iteration % endpoints.length;
  const userIndex = Math.floor(iteration / endpoints.length) % users.length;

  const user = users[userIndex];
  const endpoint = endpoints[endpointIndex];

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

  const statusOK = res.status === 200;

  const contentType = String(
    res.headers["Content-Type"] || res.headers["content-type"] || "",
  );

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

  success.add(ok, { api: endpoint.name });
  latency.add(res.timings.duration, { api: endpoint.name });

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

  if (LOG_REQUESTS || !ok) {
    const logEntry = {
      type: "request",
      at: startedAt,
      user_index: userIndex + 1,
      api: endpoint.name,
      status: res.status,
      duration_ms: res.timings.duration,
      ok,
      error: res.error || null,
    };

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
