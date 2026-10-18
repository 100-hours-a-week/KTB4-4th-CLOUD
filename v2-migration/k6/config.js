export const endpoints = [
  {
    name: "friends",
    path: "/api/v1/friends?size=20",
  },
  {
    name: "friend-detail",
    path: (user) => `/api/v1/friends/${user.friendUserId}`,
  },
  {
    name: "personal-recommendations",
    path: "/api/v1/users/me/personal-recommendations",
  },
  {
    name: "gift-recommendations",
    path: (user) =>
      `/api/v1/users/${user.giftUserId}/gift-recommendations?size=20`,
  },
];
