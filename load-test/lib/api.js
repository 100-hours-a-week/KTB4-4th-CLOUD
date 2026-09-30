// Need U V1 부하테스트에서 반복 사용할 Backend API 호출 함수 모음입니다.
// 각 요청에는 인증 Cookie와 endpoint tag를 붙여 API별 p95/p99를 분리해서 볼 수 있게 합니다.
import http from 'k6/http';

import { authParams } from './auth.js';

export const BASE_URL = (__ENV.BASE_URL || 'https://needu.gift').replace(/\/$/, '');

// endpoint tag는 k6 결과에서 API별 성능 지표를 분리하기 위해 사용합니다.
function taggedParams(user, endpoint, extra = {}) {
  return authParams(user, {
    ...extra,
    tags: {
      ...(extra.tags || {}),
      endpoint,
    },
  });
}

export function getFriends(user) {
  return http.get(
    `${BASE_URL}/api/v1/friends?size=20`,
    taggedParams(user, 'friends'),
  );
}

export function getFriendDetail(user, friendId) {
  if (!friendId) {
    throw new Error('friendId is required for getFriendDetail(user, friendId).');
  }

  return http.get(
    `${BASE_URL}/api/v1/friends/${friendId}`,
    taggedParams(user, 'friend-detail'),
  );
}

export function getPersonalRecommendations(user) {
  return http.get(
    `${BASE_URL}/api/v1/users/me/personal-recommendations?size=20`,
    taggedParams(user, 'personal-recommendations'),
  );
}

export function getGiftRecommendations(user, friendId) {
  if (!friendId) {
    throw new Error('friendId is required for getGiftRecommendations(user, friendId).');
  }

  return http.get(
    `${BASE_URL}/api/v1/users/${friendId}/gift-recommendations?size=20`,
    taggedParams(user, 'gift-recommendations'),
  );
}

export function parseJson(response) {
  try {
    return response.json();
  } catch (error) {
    throw new Error(`Failed to parse JSON response. status=${response.status}, body=${response.body}`);
  }
}

// Need U API 응답의 data 필드만 꺼내고, data가 없으면 전체 body를 반환합니다.
export function responseData(response) {
  const body = parseJson(response);
  return body && Object.prototype.hasOwnProperty.call(body, 'data') ? body.data : body;
}
