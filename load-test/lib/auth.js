import exec from 'k6/execution';
import { SharedArray } from 'k6/data';

const TOKEN_FILE = __ENV.TOKEN_FILE || '../config/tokens.json';

// k6 VU들이 같은 tokens.json 데이터를 공유하도록 SharedArray로 한 번만 로드합니다.
export const users = new SharedArray('needu-load-test-users', () => {
  const parsed = JSON.parse(open(TOKEN_FILE));

  if (!Array.isArray(parsed) || parsed.length === 0) {
    throw new Error(`${TOKEN_FILE} must contain at least one test user.`);
  }

  return parsed.map((user, index) => {
    if (!user.userId || !user.accessToken) {
      throw new Error(
        `Invalid user at index ${index}. userId and accessToken are required.`,
      );
    }

    return {
      userId: user.userId,
      accessToken: user.accessToken,
    };
  });
});

export function getUser(index = 0) {
  return users[index % users.length];
}

// 전체 iteration 번호를 기준으로 테스트 계정을 순환해서 선택합니다.
export function getIterationUser() {
  return getUser(exec.scenario.iterationInTest % users.length);
}

export function authCookie(user) {
  return `NEEDU_ACCESS_TOKEN=${user.accessToken}`;
}

// k6 http 요청 params에 인증 Cookie를 붙입니다.
export function authParams(user, extra = {}) {
  return {
    ...extra,
    headers: {
      ...(extra.headers || {}),
      Cookie: authCookie(user),
    },
  };
}