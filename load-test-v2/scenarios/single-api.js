import { check } from 'k6';
import { singleApiOptions } from '../config/options.js';
import { getIterationUser } from '../lib/auth.js';
import { prepareFriendIds } from '../lib/fixtures.js';
import { getFriends, getFriendDetail, getPersonalRecommendations, getGiftRecommendations } from '../lib/api.js';
export const options = singleApiOptions;
const target = __ENV.API_TARGET || 'friends';
const valid = ['friends', 'friend-detail', 'personal-recommendations', 'gift-recommendations'];
if (!valid.includes(target)) throw new Error(`Invalid API_TARGET: ${target}`);
export function setup() {
  return target === 'friend-detail' || target === 'gift-recommendations' ? prepareFriendIds() : {};
}
export function singleApi(data) {
  const user = getIterationUser();
  let response;
  if (target === 'friends') response = getFriends(user);
  else if (target === 'personal-recommendations') response = getPersonalRecommendations(user);
  else {
    const friendId = data.friendIds[user.userId];
    if (!friendId) throw new Error(`Missing friendId for user ${user.userId}`);
    response = target === 'friend-detail' ? getFriendDetail(user, friendId) : getGiftRecommendations(user, friendId);
  }
  check(response, { [`${target} 200`]: r => r.status === 200 });
}
export default singleApi;
