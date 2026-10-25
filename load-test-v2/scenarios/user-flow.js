import { check } from 'k6';
import { userFlowOptions } from '../config/options.js';
import { getIterationUser } from '../lib/auth.js';
import { getFriends, getFriendDetail, getGiftRecommendations, responseData } from '../lib/api.js';
export const options = userFlowOptions;
export function userFlow() {
  const user = getIterationUser();
  const friends = getFriends(user);
  if (!check(friends, { 'friends 200': r => r.status === 200 })) return;
  const friendId = responseData(friends)?.items?.[0]?.userId;
  if (!friendId) throw new Error(`No friend for userId=${user.userId}`);
  const detail = getFriendDetail(user, friendId);
  if (!check(detail, { 'friend-detail 200': r => r.status === 200 })) return;
  check(getGiftRecommendations(user, friendId), { 'gift-recommendations 200': r => r.status === 200 });
}
export default userFlow;
