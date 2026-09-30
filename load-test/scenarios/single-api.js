import { check } from 'k6';

import { singleApiOptions } from '../config/options.js';
import { getVuUser } from '../lib/auth.js';
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
  throw new Error(`Unsupported API_TARGET=${API_TARGET}. Use one of: ${API_TARGETS.join(', ')}`);
}

function checkStatus(response, name) {
  return check(response, {
    [`${name} status is 200`]: (res) => res.status === 200,
  });
}

function getFirstFriendId(user) {
  // 친구 기반 API는 대상 친구가 필요하므로 친구 목록을 먼저 조회합니다.
  const friendsResponse = getFriends(user);

  const friendsOk = checkStatus(friendsResponse, 'friends');

  if (!friendsOk) {
    return null;
  }

  const friendsData = responseData(friendsResponse);
  const friendId = friendsData?.items?.[0]?.userId;

  if (!friendId) {
    console.error(`Friend userId is missing. userId=${user.userId}`);
  }

  return friendId;
}

export function singleApi() {
  const user = getVuUser();

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

  const friendId = getFirstFriendId(user);

  if (!friendId) {
    return;
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
