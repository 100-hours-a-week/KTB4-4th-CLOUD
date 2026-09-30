import { check } from 'k6';

import { smokeOptions } from '../config/options.js';
import { getVuUser } from '../lib/auth.js';
import {
  getFriends,
  getFriendDetail,
  getGiftRecommendations,
  getPersonalRecommendations,
  responseData,
} from '../lib/api.js';

export const options = smokeOptions;

function selectFriendId(user, friendsResponse) {
  const friendsData = responseData(friendsResponse);
  const friendId = friendsData?.items?.[0]?.userId;

  if (!friendId) {
    console.error(`Friend userId is missing. userId=${user.userId}`);
  }

  return friendId;
}

export function smoke() {
  const user = getVuUser();

  // 1. 친구 목록 조회
  const friendsResponse = getFriends(user);

  const friendsOk = check(friendsResponse, {
    'friends status is 200': (res) => res.status === 200,
  });

  if (!friendsOk) {
    return;
  }

  // 2. 친구 목록에서 첫 번째 친구 선택
  const friendId = selectFriendId(user, friendsResponse);

  if (!friendId) {
    return;
  }

  // 3. 친구 상세 조회
  const friendDetailResponse = getFriendDetail(user, friendId);

  check(friendDetailResponse, {
    'friend detail status is 200': (res) => res.status === 200,
  });

  // 4. 개인 추천 조회
  const personalRecommendationsResponse = getPersonalRecommendations(user);

  check(personalRecommendationsResponse, {
    'personal recommendations status is 200': (res) => res.status === 200,
  });

  // 5. 친구 선물 추천 조회
  const giftRecommendationsResponse = getGiftRecommendations(user, friendId);

  check(giftRecommendationsResponse, {
    'gift recommendations status is 200': (res) => res.status === 200,
  });
}

export default smoke;
