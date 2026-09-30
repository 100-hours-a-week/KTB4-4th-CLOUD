export const thresholds = {
  // 전체 Backend 요청
  http_req_failed: ['rate<=0.01'],
  http_req_duration: [
    'p(95)<=300',
    'p(99)<=1000',
  ],

  // API별 성공률/응답시간
  'http_req_failed{endpoint:friends}': ['rate<=0.01'],
  'http_req_duration{endpoint:friends}': [
    'p(95)<=300',
    'p(99)<=1000',
  ],

  'http_req_failed{endpoint:friend-detail}': ['rate<=0.01'],
  'http_req_duration{endpoint:friend-detail}': [
    'p(95)<=300',
    'p(99)<=1000',
  ],

  'http_req_failed{endpoint:gift-recommendations}': ['rate<=0.01'],
  'http_req_duration{endpoint:gift-recommendations}': [
    'p(95)<=300',
    'p(99)<=1000',
  ],
};

export const userFlowOptions = {
  scenarios: {
    baseline: {
      executor: 'constant-arrival-rate',
      rate: 32,
      timeUnit: '10m',
      duration: '10m',
      preAllocatedVUs: 2,
      maxVUs: 10,
      exec: 'userFlow',
    },

    load_032: {
      executor: 'constant-arrival-rate',
      startTime: '10m',
      rate: 64,
      timeUnit: '10m',
      duration: '10m',
      preAllocatedVUs: 2,
      maxVUs: 10,
      exec: 'userFlow',
    },

    load_080: {
      executor: 'constant-arrival-rate',
      startTime: '20m',
      rate: 160,
      timeUnit: '10m',
      duration: '10m',
      preAllocatedVUs: 2,
      maxVUs: 10,
      exec: 'userFlow',
    },

    load_160: {
      executor: 'constant-arrival-rate',
      startTime: '30m',
      rate: 320,
      timeUnit: '10m',
      duration: '10m',
      preAllocatedVUs: 2,
      maxVUs: 10,
      exec: 'userFlow',
    },

    load_320: {
      executor: 'constant-arrival-rate',
      startTime: '40m',
      rate: 640,
      timeUnit: '10m',
      duration: '10m',
      preAllocatedVUs: 2,
      maxVUs: 10,
      exec: 'userFlow',
    },
  },

  thresholds,
};