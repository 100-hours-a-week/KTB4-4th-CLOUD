import http from 'k6/http';
import { authParams } from './auth.js';

if (!__ENV.BASE_URL) throw new Error('BASE_URL is required. Supply the approved V2 Staging URL.');
export const BASE_URL = __ENV.BASE_URL.replace(/\/$/, '');

function taggedParams(user, endpoint) {
  return authParams(user, {
    tags: { endpoint },
    responseCallback: http.expectedStatuses(200),
    timeout: __ENV.HTTP_TIMEOUT || '10s',
  });
}
export function getFriends(user) {
  return http.get(`${BASE_URL}/api/v1/friends?size=20`, taggedParams(user, 'friends'));
}
export function getFriendDetail(user, friendId) {
  if (!friendId) throw new Error('friendId required');
  return http.get(`${BASE_URL}/api/v1/friends/${friendId}`, taggedParams(user, 'friend-detail'));
}
export function getPersonalRecommendations(user) {
  return http.get(`${BASE_URL}/api/v1/users/me/personal-recommendations?size=20`, taggedParams(user, 'personal-recommendations'));
}
export function getGiftRecommendations(user, friendId) {
  if (!friendId) throw new Error('friendId required');
  return http.get(`${BASE_URL}/api/v1/users/${friendId}/gift-recommendations?size=20`, taggedParams(user, 'gift-recommendations'));
}
export function responseData(response) {
  let body;
  try { body = response.json(); }
  catch (_) { throw new Error(`Invalid JSON response, HTTP ${response.status}`); }
  return body && Object.prototype.hasOwnProperty.call(body, 'data') ? body.data : body;
}
