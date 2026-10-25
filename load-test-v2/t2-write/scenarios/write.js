import { check } from "k6";
import exec from "k6/execution";
import { options } from "../config/options.js";
import { users } from "../lib/data.js";
import { insertClick, updateFavorite } from "../lib/write.js";

export { options };

const target = __ENV.T2_TARGET || "mixed";

// 기본값은 기존 단일 실행기 방식
const generatorId = Number(__ENV.GENERATOR_ID ?? 0);
const generatorCount = Number(__ENV.GENERATOR_COUNT ?? 1);

if (
  !Number.isSafeInteger(generatorId) ||
  !Number.isSafeInteger(generatorCount) ||
  generatorCount < 1 ||
  generatorId < 0 ||
  generatorId >= generatorCount
) {
  throw new Error("Invalid GENERATOR_ID or GENERATOR_COUNT");
}

if (users.length % generatorCount !== 0) {
  throw new Error(
    `Cannot divide ${users.length} users across ${generatorCount} generators`,
  );
}

const usersPerGenerator = users.length / generatorCount;
const userStart = generatorId * usersPerGenerator;

export function write() {
  const n = exec.scenario.iterationInTest;

  // Mixed: INSERT / UPDATE 번갈아 실행
  const isMixed = target === "mixed";
  const operation = isMixed ? (n % 2 === 0 ? "insert" : "update") : target;

  // 실행기별 사용자 범위 내에서 선택
  const localUserIndex = isMixed
    ? Math.floor(n / 2) % usersPerGenerator
    : n % usersPerGenerator;

  // 각 사용자별 반복 횟수
  const sequence = isMixed
    ? Math.floor(n / (2 * usersPerGenerator))
    : Math.floor(n / usersPerGenerator);

  const userIndex = userStart + localUserIndex;
  const user = users[userIndex];

  if (!user.accessToken) {
    throw new Error(`Missing JWT for user ${user.userId}`);
  }

  const response =
    operation === "insert"
      ? insertClick(user, sequence)
      : updateFavorite(user, sequence);

  const expected = operation === "insert" ? 204 : 200;

  check(response, {
    [`${operation} expected status`]: (r) => r.status === expected,
  });
}

export default write;
