import http from "k6/http";
import { check } from "k6";
import { SharedArray } from "k6/data";
import { Counter, Rate, Trend } from "k6/metrics";
import exec from "k6/execution";

// ============================================================
// 1. Configuration
// ============================================================

const BASE_URL = (__ENV.BASE_URL || "https://needu.gift").replace(/\/$/, "");

const RATE = Number(__ENV.RATE || 483);
const DURATION = __ENV.DURATION || "5m";

const PRE_ALLOCATED_VUS = Number(__ENV.VUS || 1000);
const MAX_VUS = Number(__ENV.MAX_VUS || 3000);

const POOL_FILE = __ENV.POOL_FILE || "./pool.json";

const EXPECTED_STATUS = 202;

// AI Session Idle TTL = 1800 seconds.
// Reserve time for the test execution.
const MAX_POOL_AGE_SECONDS = Number(__ENV.MAX_POOL_AGE_SECONDS || 1200);

// ============================================================
// 2. Duration Parser
// ============================================================

function durationSeconds(value) {
  const match = /^(\d+(?:\.\d+)?)(ms|s|m|h)$/.exec(value);

  if (!match) {
    throw new Error(`Unsupported DURATION: ${value}`);
  }

  const amount = Number(match[1]);
  const unit = match[2];

  if (unit === "ms") return amount / 1000;
  if (unit === "s") return amount;
  if (unit === "m") return amount * 60;

  return amount * 3600;
}

const RUN_SECONDS = durationSeconds(DURATION);
const EXPECTED_REQUESTS = Math.ceil(RATE * RUN_SECONDS);

// ============================================================
// 3. Load Conversation Pool
// ============================================================

const pool = new SharedArray("conversation-pool", () => {
  const data = JSON.parse(open(POOL_FILE));

  if (!Array.isArray(data)) {
    throw new Error("pool.json must contain a JSON array");
  }

  return data;
});

// ============================================================
// 4. Validate Configuration
// ============================================================

if (!Number.isInteger(RATE) || RATE <= 0) {
  throw new Error("RATE must be a positive integer");
}

if (!Number.isInteger(PRE_ALLOCATED_VUS) || PRE_ALLOCATED_VUS <= 0) {
  throw new Error("VUS must be a positive integer");
}

if (!Number.isInteger(MAX_VUS) || MAX_VUS <= 0) {
  throw new Error("MAX_VUS must be a positive integer");
}

if (PRE_ALLOCATED_VUS > MAX_VUS) {
  throw new Error("VUS cannot exceed MAX_VUS");
}

if (pool.length < EXPECTED_REQUESTS) {
  throw new Error(
    `Insufficient pool: required=${EXPECTED_REQUESTS}, ` +
      `available=${pool.length}`,
  );
}

// ============================================================
// 5. Session Timestamp Parser
// ============================================================

// Supports:
// - Unix timestamp in seconds: 1794500000
// - Unix timestamp in milliseconds: 1794500000000
// - ISO 8601 string: "2026-11-13T10:00:00Z"

function parseCreatedAt(value) {
  if (value === undefined || value === null || value === "") {
    return NaN;
  }

  if (typeof value === "number") {
    return value > 1e11 ? value / 1000 : value;
  }

  if (typeof value === "string") {
    const trimmed = value.trim();

    if (/^\d+$/.test(trimmed)) {
      const numeric = Number(trimmed);
      return numeric > 1e11 ? numeric / 1000 : numeric;
    }

    const parsed = Date.parse(trimmed);

    return Number.isFinite(parsed) ? parsed / 1000 : NaN;
  }

  return NaN;
}

// ============================================================
// 6. Validate Conversation Pool
// ============================================================

const nowSeconds = Date.now() / 1000;

for (let i = 0; i < EXPECTED_REQUESTS; i++) {
  const item = pool[i];

  if (!item.conversationId || !item.cookie || !item.csrfToken) {
    throw new Error(`Invalid pool item at index=${i}`);
  }

  const createdAtSeconds = parseCreatedAt(item.createdAt);

  if (!Number.isFinite(createdAtSeconds)) {
    throw new Error(`Invalid createdAt at index=${i}: ${item.createdAt}`);
  }

  const ageSeconds = nowSeconds - createdAtSeconds;

  if (ageSeconds < -60) {
    throw new Error(
      `Pool session timestamp is in the future: ` +
        `index=${i}, age=${ageSeconds.toFixed(1)}s`,
    );
  }

  if (ageSeconds + RUN_SECONDS > 1800) {
    throw new Error(
      `Pool session may expire during the test: ` +
        `index=${i}, age=${ageSeconds.toFixed(1)}s, ` +
        `duration=${RUN_SECONDS}s`,
    );
  }

  if (ageSeconds > MAX_POOL_AGE_SECONDS) {
    throw new Error(
      `Pool session is stale at index=${i}, ` + `age=${ageSeconds.toFixed(1)}s`,
    );
  }
}

// ============================================================
// 7. Custom Metrics
// ============================================================

const accepted = new Counter("k1_accepted");
const rejected = new Counter("k1_rejected");

const status429 = new Counter("k1_status_429");
const status5xx = new Counter("k1_status_5xx");
const statusOther = new Counter("k1_status_other");

const acceptanceRate = new Rate("k1_acceptance_rate");

const submitLatency = new Trend("k1_submit_latency", true);

// ============================================================
// 8. k6 Options
// ============================================================

export const options = {
  scenarios: {
    k1_ai_chat: {
      executor: "constant-arrival-rate",

      rate: RATE,
      timeUnit: "1s",
      duration: DURATION,

      preAllocatedVUs: PRE_ALLOCATED_VUS,
      maxVUs: MAX_VUS,

      gracefulStop: "30s",
    },
  },

  thresholds: {
    k1_acceptance_rate: ["rate>=0.99"],
    k1_submit_latency: ["p(95)<1000"],
    dropped_iterations: ["count==0"],
    k1_status_5xx: ["count==0"],
  },
};

// ============================================================
// 9. UUID v4
// ============================================================

function uuidV4() {
  const bytes = new Uint8Array(16);

  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = Math.floor(Math.random() * 256);
  }

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, "0"));

  return (
    hex.slice(0, 4).join("") +
    "-" +
    hex.slice(4, 6).join("") +
    "-" +
    hex.slice(6, 8).join("") +
    "-" +
    hex.slice(8, 10).join("") +
    "-" +
    hex.slice(10, 16).join("")
  );
}

// ============================================================
// 10. Test Scenario
// ============================================================

export default function () {
  const index = exec.scenario.iterationInTest;

  if (index >= EXPECTED_REQUESTS) {
    throw new Error(
      `Unexpected iteration index=${index}, ` + `expected=${EXPECTED_REQUESTS}`,
    );
  }

  const item = pool[index];

  const url =
    `${BASE_URL}/api/v1/ai/conversations/` + `${item.conversationId}/messages`;

  const payload = JSON.stringify({
    clientMessageId: uuidV4(),
    content: "요즘에는 독서와 산책을 즐깁니다.",
  });

  const response = http.post(url, payload, {
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Cookie: item.cookie,
      "X-XSRF-TOKEN": item.csrfToken,
      "X-K1-Test": "true",
    },

    timeout: "30s",

    tags: {
      endpoint: "ai-chat-message",
      test: "K1",
    },
  });

  const ok = response.status === EXPECTED_STATUS;

  acceptanceRate.add(ok);
  submitLatency.add(response.timings.duration);

  if (ok) {
    accepted.add(1);
  } else {
    rejected.add(1);

    if (response.status === 429) {
      status429.add(1);
    } else if (response.status >= 500) {
      status5xx.add(1);
    } else {
      statusOther.add(1);
    }

    if (index < 20) {
      console.error(
        `index=${index} ` +
          `conversation=${item.conversationId} ` +
          `status=${response.status} ` +
          `body=${String(response.body).slice(0, 300)}`,
      );
    }
  }

  check(response, {
    "AI message accepted (202)": (r) => r.status === EXPECTED_STATUS,
  });
}
