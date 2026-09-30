import { check } from 'k6';

import { userFlowOptions } from '../config/options.js';
import { getVuUser } from '../lib/auth.js';
import {
  getFriends,
  getFriendDetail,
  getGiftRecommendations,
  responseData,
} from '../lib/api.js';

export const options = userFlowOptions;

export function userFlow() {
  const user = getVuUser();

  // 1. 친구 목록 조회
  const friendsResponse = getFriends(user);

  const friendsOk = check(friendsResponse, {
    'friends status is 200': (res) => res.status === 200,
  });

  if (!friendsOk) {
    return;
  }

  const friendsData = responseData(friendsResponse);

  if (!friendsData?.items?.length) {
    console.error(`No friends found. userId=${user.userId}`);
    return;
  }

  // 친구 목록에서 첫 번째 친구 선택
  const friendId = friendsData.items[0]?.userId;

  if (!friendId) {
    console.error(`Friend userId is missing. userId=${user.userId}`);
    return;
  }

  // 2. 친구 상세 조회
  const friendDetailResponse = getFriendDetail(user, friendId);

  const friendDetailOk = check(friendDetailResponse, {
    'friend detail status is 200': (res) => res.status === 200,
  });

  if (!friendDetailOk) {
    return;
  }

  // 3. 친구 선물 추천 조회
  const giftRecommendationsResponse = getGiftRecommendations(user, friendId);

  check(giftRecommendationsResponse, {
    'gift recommendations status is 200': (res) => res.status === 200,
  });
}