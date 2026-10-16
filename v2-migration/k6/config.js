export const endpoints = [
  {
    name: "friends",
    path: "/api/v1/friends?size=20",
  },
  {
    name: "friend-detail",
    path: (u) => `/api/v1/friends/${encodeURIComponent(u.friendUserId)}`,
  },
  {
    name: "personal",
    path: "/api/v1/users/me/personal-recommendations",
  },
  {
    name: "gift",
    path: (u) =>
      `/api/v1/users/${encodeURIComponent(u.giftUserId)}/gift-recommendations?size=20`,
  },
];
