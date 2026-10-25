const target = __ENV.T2_TARGET || 'mixed';
if (!['insert', 'update', 'mixed'].includes(target)) {
  throw new Error('T2_TARGET must be insert, update, or mixed');
}
const mode = __ENV.MODE || 'load';
if (!['smoke', 'load'].includes(mode)) {
  throw new Error('MODE must be smoke or load');
}
const thresholds = {
  dropped_iterations: ['count==0'],
};
for (const endpoint of (target === 'mixed' ? ['t2-insert', 't2-update'] : [`t2-${target}`])) {
  thresholds[`http_req_failed{endpoint:${endpoint}}`] = ['rate<=0.01'];
  thresholds[`http_req_duration{endpoint:${endpoint}}`] = ['p(95)<=300', 'p(99)<=1000'];
}
const scenario = mode === 'smoke'
  ? { executor: 'shared-iterations', vus: 1, iterations: target === 'mixed' ? 2 : 1,
      maxDuration: '30s', exec: 'write' }
  : { executor: 'constant-arrival-rate', rate: Number(__ENV.RATE || 2), timeUnit: '1s',
      duration: __ENV.DURATION || '1m',
      preAllocatedVUs: Number(__ENV.PRE_ALLOCATED_VUS || 20),
      maxVUs: Number(__ENV.MAX_VUS || 200), exec: 'write' };
export const options = { scenarios: { write: scenario }, thresholds };
