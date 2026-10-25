import { check } from 'k6';
import { users } from '../lib/auth.js';
import { prepareFriendIds } from '../lib/fixtures.js';
import {
  getFriends,
  getFriendDetail,
  getPersonalRecommendations,
  getGiftRecommendations,
} from '../lib/api.js';

export const options = {
  scenarios: {
    diagnose: {
      executor: 'shared-iterations',
      vus: 1,
      iterations: 1,
      exec: 'diagnose',
    },
  },
};

export function setup() {
  return prepareFriendIds();
}

export function diagnose(data) {
  for (const user of users) {
    const friendId = data.friendIds[user.userId];

    if (!friendId) {
      console.log(`userId=${user.userId} | friendId=MISSING`);
      continue;
    }

    const responses = [
      ['friends', getFriends(user)],
      ['friend-detail', getFriendDetail(user, friendId)],
      ['personal', getPersonalRecommendations(user)],
      ['gift', getGiftRecommendations(user, friendId)],
    ];

    for (const [endpoint, response] of responses) {
      console.log(
        `userId=${user.userId} | ${endpoint} | HTTP ${response.status}`
      );
    }
  }
}
