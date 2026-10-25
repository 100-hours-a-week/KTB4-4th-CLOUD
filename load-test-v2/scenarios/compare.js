import { check } from "k6";
import { Counter } from "k6/metrics";
import exec from "k6/execution";

import { compareOptions } from "../config/options.js";
import { getIterationUser } from "../lib/auth.js";
import { prepareFriendIds } from "../lib/fixtures.js";

import {
  getFriends,
  getFriendDetail,
  getPersonalRecommendations,
  getGiftRecommendations,
} from "../lib/api.js";

export const options = compareOptions;

// 실패 HTTP 요청 수 집계
const failedHttpStatus = new Counter("failed_http_status");

export function setup() {
  return prepareFriendIds();
}

export function compare(data) {
  const user = getIterationUser();
  const friendId = data.friendIds[user.userId];

  if (!friendId) {
    throw new Error(`Prepared friendId missing for userId=${user.userId}`);
  }

  // 1 iteration = 4 HTTP requests
  const friends = getFriends(user);
  const detail = getFriendDetail(user, friendId);
  const personal = getPersonalRecommendations(user);
  const gift = getGiftRecommendations(user, friendId);

  // API별 HTTP 200 검사
  check(friends, {
    "friends 200": (r) => r.status === 200,
  });

  check(detail, {
    "friend-detail 200": (r) => r.status === 200,
  });

  check(personal, {
    "personal-recommendations 200": (r) => r.status === 200,
  });

  check(gift, {
    "gift-recommendations 200": (r) => r.status === 200,
  });

  const responses = [
    ["friends", friends],
    ["friend-detail", detail],
    ["personal-recommendations", personal],
    ["gift-recommendations", gift],
  ];

  // 실패한 요청만 기록
  for (const [endpoint, response] of responses) {
    if (response.status !== 200) {
      const status = String(response.status);

      failedHttpStatus.add(1, {
        endpoint,
        status,
        userId: String(user.userId),
      });

      console.error(
        `HTTP_FAILURE ` +
          `iteration=${exec.scenario.iterationInTest} ` +
          `userId=${user.userId} ` +
          `endpoint=${endpoint} ` +
          `status=${status} ` +
          `duration=${response.timings.duration}ms ` +
          `error=${response.error || "none"}`,
      );
    }
  }
}

export default compare;
