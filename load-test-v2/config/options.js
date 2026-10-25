const endpoints = ['friends', 'friend-detail', 'personal-recommendations', 'gift-recommendations'];
const thresholds = {
  http_req_failed: ['rate<=0.01'],
  http_req_duration: ['p(95)<=300', 'p(99)<=1000'],
};
for (const endpoint of endpoints) {
  thresholds[`http_req_failed{endpoint:${endpoint}}`] = ['rate<=0.01'];
  thresholds[`http_req_duration{endpoint:${endpoint}}`] = ['p(95)<=300', 'p(99)<=1000'];
}
export { thresholds };

export const smokeOptions = {
  scenarios: { smoke: { executor: 'shared-iterations', vus: 1, iterations: 1, maxDuration: '1m', exec: 'smoke' } },
  thresholds,
};

export const singleApiOptions = {
  scenarios: { single_api: {
    executor: 'constant-arrival-rate',
    rate: Number(__ENV.RATE || 1), timeUnit: '1s', duration: __ENV.DURATION || '1m',
    preAllocatedVUs: Number(__ENV.PRE_ALLOCATED_VUS || 2),
    maxVUs: Number(__ENV.MAX_VUS || 10), exec: 'singleApi',
  } },
  thresholds: { ...thresholds, dropped_iterations: ['count==0'] },
};

// Legacy user-flow: exactly 3 HTTP requests per successful iteration.
export const userFlowOptions = {
  scenarios: { user_flow: {
    executor: 'constant-arrival-rate',
    rate: Number(__ENV.RATE || 1), timeUnit: __ENV.TIME_UNIT || '1s',
    duration: __ENV.DURATION || '10m',
    preAllocatedVUs: Number(__ENV.PRE_ALLOCATED_VUS || 10),
    maxVUs: Number(__ENV.MAX_VUS || 100), exec: 'userFlow',
  } },
  thresholds: { ...thresholds, dropped_iterations: ['count==0'] },
};

// V1/V2 comparison: exactly four GET requests per successful iteration.
// RATE is iterations/sec; target HTTP RPS = RATE * 4, absent early failures.
export const compareOptions = {
  scenarios: { compare: {
    executor: 'constant-arrival-rate',
    rate: Number(__ENV.RATE || 25), timeUnit: __ENV.TIME_UNIT || '1s',
    duration: __ENV.DURATION || '5m',
    preAllocatedVUs: Number(__ENV.PRE_ALLOCATED_VUS || 100),
    maxVUs: Number(__ENV.MAX_VUS || 500), exec: 'compare',
    tags: { test_type: 'v1-v2-compare' },
  } },
  thresholds: { ...thresholds, dropped_iterations: ['count==0'] },
};
