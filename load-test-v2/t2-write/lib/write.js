import http from "k6/http";
import { BASE_URL } from "../../lib/api.js";
import { products } from "./data.js";

function csrf(user) {
  const jar = http.cookieJar();

  const authCookie = `NEEDU_ACCESS_TOKEN=${user.accessToken}`;

  const response = http.get(`${BASE_URL}/api/v1/auth/csrf`, {
    headers: {
      Cookie: authCookie,
    },
    tags: {
      endpoint: "t2-csrf",
    },
    timeout: "10s",
  });

  // CSRF 요청 실패 시 HTTP Timing 및 오류 정보 기록
  if (response.status !== 200) {
    console.error(
      JSON.stringify({
        event: "csrf_failed",
        timestamp: new Date().toISOString(),
        userId: user.userId,
        status: response.status,
        error: response.error,
        errorCode: response.error_code,
        timings: {
          blocked: response.timings.blocked,
          connecting: response.timings.connecting,
          tls_handshaking: response.timings.tls_handshaking,
          sending: response.timings.sending,
          waiting: response.timings.waiting,
          receiving: response.timings.receiving,
          duration: response.timings.duration,
        },
      }),
    );

    throw new Error(
      `CSRF failed: HTTP ${response.status}, user=${user.userId}`,
    );
  }

  let token;

  try {
    token = response.json("data.token");
  } catch (_) {
    throw new Error(`Invalid CSRF response, user=${user.userId}`);
  }

  if (!token) {
    throw new Error(`CSRF token missing, user=${user.userId}`);
  }

  const cookies = jar.cookiesForURL(BASE_URL);

  const csrfCookies = Object.entries(cookies)
    .filter(([name]) => name !== "NEEDU_ACCESS_TOKEN")
    .map(([name, values]) => `${name}=${values[0]}`)
    .join("; ");

  return {
    Cookie: [authCookie, csrfCookies].filter(Boolean).join("; "),
    "X-XSRF-TOKEN": token,
    "Content-Type": "application/json",
  };
}

export function insertClick(user, sequence) {
  const offset = Number(__ENV.PRODUCT_OFFSET || 0);
  const index = offset + sequence;

  if (!Number.isSafeInteger(index) || index < 0) {
    throw new Error(`Invalid product index: ${index}`);
  }

  if (index >= products.length * 2) {
    throw new Error(
      `Insufficient unique product/context combinations: ${index}`,
    );
  }

  const productId = products[Math.floor(index / 2)];
  const context = index % 2 === 0 ? "PERSONAL" : "MY_GIFT";

  return http.post(
    `${BASE_URL}/api/v1/analytics/product-link-clicks`,
    JSON.stringify({
      productId,
      context,
    }),
    {
      headers: csrf(user),
      tags: {
        endpoint: "t2-insert",
      },
      timeout: "10s",
      responseCallback: http.expectedStatuses(204),
    },
  );
}

export function updateFavorite(user, sequence) {
  const initialFavorite =
    user.initialFavorite === true ||
    user.initialFavorite === 1 ||
    user.initialFavorite === "1";

  // 첫 번째 요청은 초기값과 반대 상태로 변경
  // 이후 계정별 요청마다 true/false 교대
  const isFavorite = sequence % 2 === 0 ? !initialFavorite : initialFavorite;

  return http.put(
    `${BASE_URL}/api/v1/friends/${user.friendUserId}/favorite`,
    JSON.stringify({
      isFavorite,
    }),
    {
      headers: csrf(user),
      tags: {
        endpoint: "t2-update",
      },
      timeout: "10s",
      responseCallback: http.expectedStatuses(200),
    },
  );
}
