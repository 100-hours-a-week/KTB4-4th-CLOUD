import { SharedArray } from "k6/data";
import exec from "k6/execution";

export const users = new SharedArray("t2-users", () =>
  JSON.parse(open("../config/users.json")),
);

export const products = new SharedArray("t2-products", () =>
  JSON.parse(open("../config/products.json")),
);

if (users.length !== 300) {
  throw new Error(`Expected 300 users, got ${users.length}`);
}

if (products.length === 0) {
  throw new Error("No products found");
}

export function selected() {
  const iteration = exec.scenario.iterationInTest;
  const userIndex = iteration % users.length;
  const sequence = Math.floor(iteration / users.length);

  const user = users[userIndex];

  if (!user.accessToken) {
    throw new Error(`Missing JWT for user ${user.userId}`);
  }

  return {
    user,
    sequence,
    iteration,
  };
}
