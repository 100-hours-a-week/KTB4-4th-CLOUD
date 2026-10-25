import { getUser, users } from './auth.js';
import { getFriends, responseData } from './api.js';

// setup() runs before timed load. Resolve one valid friend per test user.
export function prepareFriendIds() {
  const friendIds = {};
  for (let i = 0; i < users.length; i += 1) {
    const user = getUser(i);
    const response = getFriends(user);
    if (response.status !== 200) {
      throw new Error(`Friend preparation failed for userId=${user.userId}, HTTP ${response.status}`);
    }
    const friendId = responseData(response)?.items?.[0]?.userId;
    if (!friendId) throw new Error(`No friend found for userId=${user.userId}`);
    friendIds[user.userId] = friendId;
  }
  return { friendIds };
}
