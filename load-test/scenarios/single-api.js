import { check } from 'k6';
import exec from 'k6/execution';

import { singleApiOptions } from '../config/options.js';
import { getUser, users } from '../lib/auth.js';
import {
  getFriends,
  getFriendDetail,
  getGiftRecommendations,
  getPersonalRecommendations,
  responseData,
} from '../lib/api.js';

export const options = singleApiOptions;

const API_TARGETS = [
  'friends',
  'friend-detail',
  'personal-recommendations',
  'gift-recommendations',
];

const API_TARGET = __ENV.API_TARGET || 'friends';

if (!API_TARGETS.includes(API_TARGET)) {
  throw new Error(
    `Unsupported API_TARGET=${API_TARGET}. Use one of: ${API_TARGETS.join(', ')}`,
  );
}

function checkStatus(response, name) {
  return check(response, {
    [`${name} status is 200`]: (res) => res.status === 200,
  });
}

// friend-detail / gift-recommendations 테스트에 필요한 friendId를
// 실제 부하 테스트가 시작되기 전에 미리 조회합니다.
export function setup() {
  if (
    API_TARGET === 'friends' ||
    API_TARGET === 'personal-recommendations'
  ) {
    return {
      friendIds: {},
    };
  }

  const friendIds = {};

  for (let index = 0; index < users.length; index += 1) {
    const user = getUser(index);
    const friendsResponse = getFriends(user);

    if (friendsResponse.status !== 200) {
      throw new Error(
        `Failed to prepare friendId. userId=${user.userId}, status=${friendsResponse.status}`,
      );
    }

    const friendsData = responseData(friendsResponse);
    const friendId = friendsData?.items?.[0]?.userId;

    if (!friendId) {
      throw new Error(
        `No friend found. userId=${user.userId}`,
      );
    }

    friendIds[user.userId] = friendId;
  }

  return {
    friendIds,
  };
}

export function singleApi(data) {
  const user = getUser(
    exec.scenario.iterationInTest % users.length,
  );

  if (API_TARGET === 'friends') {
    const response = getFriends(user);
    checkStatus(response, 'friends');
    return;
  }

  if (API_TARGET === 'personal-recommendations') {
    const response = getPersonalRecommendations(user);
    checkStatus(response, 'personal recommendations');
    return;
  }

  const friendId = data.friendIds[user.userId];

  if (!friendId) {
    throw new Error(
      `Prepared friendId is missing. userId=${user.userId}`,
    );
  }

  if (API_TARGET === 'friend-detail') {
    const response = getFriendDetail(user, friendId);
    checkStatus(response, 'friend detail');
    return;
  }

  const response = getGiftRecommendations(user, friendId);
  checkStatus(response, 'gift recommendations');
}

export default singleApi;