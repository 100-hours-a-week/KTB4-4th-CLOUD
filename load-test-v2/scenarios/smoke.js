import { check, fail } from "k6";
import { smokeOptions } from "../config/options.js";
import { getIterationUser } from "../lib/auth.js";
import {
  getFriends,
  getFriendDetail,
  getPersonalRecommendations,
  getGiftRecommendations,
  responseData,
} from "../lib/api.js";

export const options = smokeOptions;

function checkResponse(name, response) {
  const success = check(response, {
    [`${name} 200`]: (r) => r.status === 200,
  });

  console.log(
    `[${name}] HTTP ${response.status} | Duration: ${response.timings.duration.toFixed(2)}ms`,
  );

  return success;
}

export function smoke() {
  const user = getIterationUser();

  console.log(`Smoke Test 시작 | userId=${user.userId}`);

  // 1. 친구 목록 조회
  const friends = getFriends(user);

  if (!checkResponse("friends", friends)) {
    fail(`Friends API failed: HTTP ${friends.status}`);
  }

  // 친구 목록에서 친구 ID 추출
  let friendId;

  try {
    friendId = responseData(friends)?.items?.[0]?.userId;
  } catch (error) {
    fail(`Friends response parsing failed: ${error.message}`);
  }

  if (!friendId) {
    fail("Smoke test user has no friends");
  }

  // 2. 친구 상세 조회
  const detail = getFriendDetail(user, friendId);
  const detailOk = checkResponse("friend-detail", detail);

  // 3. 개인 추천 조회
  const personal = getPersonalRecommendations(user);
  const personalOk = checkResponse("personal-recommendations", personal);

  // 4. 선물 추천 조회
  const gift = getGiftRecommendations(user, friendId);
  const giftOk = checkResponse("gift-recommendations", gift);

  // 전체 결과
  if (!detailOk || !personalOk || !giftOk) {
    fail("Smoke Test FAILED: One or more APIs returned non-200");
  }

  console.log("Smoke Test PASSED: All 4 APIs returned HTTP 200");
}

export default smoke;
