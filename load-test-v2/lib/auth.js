import exec from 'k6/execution';
import { SharedArray } from 'k6/data';

const TOKEN_FILE = __ENV.TOKEN_FILE || '../config/tokens.json';
export const users = new SharedArray('needu-load-test-users', () => {
  const parsed = JSON.parse(open(TOKEN_FILE));
  if (!Array.isArray(parsed) || parsed.length === 0) {
    throw new Error(`${TOKEN_FILE} must contain at least one test user`);
  }
  return parsed.map((user, index) => {
    if (!user.userId || !user.accessToken) {
      throw new Error(`Invalid user at index ${index}: userId/accessToken required`);
    }
    return { userId: user.userId, accessToken: user.accessToken };
  });
});
export function getUser(index = 0) { return users[index % users.length]; }
export function getIterationUser() { return getUser(exec.scenario.iterationInTest); }
export function authParams(user, extra = {}) {
  return { ...extra, headers: { ...(extra.headers || {}), Cookie: `NEEDU_ACCESS_TOKEN=${user.accessToken}` } };
}
