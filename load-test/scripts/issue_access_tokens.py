#!/usr/bin/env python3
"""부하 테스트용 Access JWT를 오프라인으로 발급한다.

서버의 AccessTokenService와 같은 형식(HS256, userId/iat/exp 클레임)으로 서명하므로
서버에 발급 엔드포인트를 열지 않고도 k6에서 사용할 수 있다.

사용 예:
    export JWT_SECRET='<대상 서버와 같은 Base64 시크릿>'
    python3 scripts/loadtest/issue_access_tokens.py --user-ids 101-120 --ttl-hours 3 --out tokens.json

- 시크릿은 셸 히스토리에 남지 않도록 인자가 아닌 환경 변수(JWT_SECRET)로만 받는다.
- 출력 파일에는 유효한 토큰이 들어 있으므로 커밋하거나 공유 채널에 올리지 않는다.
"""
import argparse
import base64
import binascii
import hashlib
import hmac
import json
import os
import sys
import time

MIN_SECRET_BYTES = 32  # JwtConfig와 동일한 제약


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def encode_json(value: dict) -> str:
    return b64url(json.dumps(value, separators=(",", ":")).encode("utf-8"))


def load_secret() -> bytes:
    encoded = os.environ.get("JWT_SECRET")
    if not encoded:
        sys.exit("JWT_SECRET 환경 변수가 필요합니다.")
    try:
        # 서버는 java.util.Base64.getDecoder()(표준 Base64)로 디코딩한다
        secret = base64.b64decode(encoded, validate=True)
    except binascii.Error:
        sys.exit("JWT_SECRET must be Base64 encoded")
    if len(secret) < MIN_SECRET_BYTES:
        sys.exit("JWT_SECRET must contain at least 32 bytes")
    return secret


def parse_user_ids(value: str) -> list[int]:
    user_ids = []
    for part in value.split(","):
        part = part.strip()
        if "-" in part:
            start, end = (int(v) for v in part.split("-", 1))
            user_ids.extend(range(start, end + 1))
        elif part:
            user_ids.append(int(part))
    if not user_ids or any(user_id <= 0 for user_id in user_ids):
        raise argparse.ArgumentTypeError("userId는 양수여야 합니다.")
    return user_ids


def issue_access_token(secret: bytes, user_id: int, issued_at: int, ttl_seconds: int) -> str:
    header = encode_json({"alg": "HS256"})
    payload = encode_json({"userId": user_id, "iat": issued_at, "exp": issued_at + ttl_seconds})
    signing_input = f"{header}.{payload}"
    signature = hmac.new(secret, signing_input.encode("ascii"), hashlib.sha256).digest()
    return f"{signing_input}.{b64url(signature)}"


def main() -> None:
    parser = argparse.ArgumentParser(description="부하 테스트용 Access JWT 발급")
    parser.add_argument("--user-ids", required=True, type=parse_user_ids,
                        help="users.id 목록. 예) 101-120 또는 101,102,105")
    parser.add_argument("--ttl-hours", type=float, default=3.0, help="만료까지 시간 (기본 3)")
    parser.add_argument("--out", default="tokens.json", help="출력 파일 (기본 tokens.json)")
    args = parser.parse_args()

    secret = load_secret()
    issued_at = int(time.time())
    ttl_seconds = int(args.ttl_hours * 3600)
    tokens = [
        {"userId": user_id, "accessToken": issue_access_token(secret, user_id, issued_at, ttl_seconds)}
        for user_id in args.user_ids
    ]
    with open(args.out, "w", encoding="utf-8") as file:
        json.dump(tokens, file, indent=2)
    expires_at = time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime(issued_at + ttl_seconds))
    print(f"{len(tokens)}개 토큰을 {args.out}에 저장했습니다. 만료: {expires_at}")


if __name__ == "__main__":
    main()

