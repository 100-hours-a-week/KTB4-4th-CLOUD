
#!/usr/bin/env python3
"""Prepare AI conversations using JWT test accounts.

Default: dry run.
Use --execute to create real conversations in Production.
"""

import argparse
import concurrent.futures
import json
import os
import sys
import threading
import time
from pathlib import Path

import requests

_tls = threading.local()


def get_session():
    if not hasattr(_tls, "session"):
        _tls.session = requests.Session()
    return _tls.session


def create_conversation(index, accounts, base_url):
    account = accounts[index % len(accounts)]
    user_id = account["userId"]
    access_token = account["accessToken"]

    s = get_session()
    s.cookies.clear()
    s.cookies.set("NEEDU_ACCESS_TOKEN", access_token, path="/")

    try:
        # 1. CSRF 토큰 발급
        csrf_response = s.get(
            f"{base_url}/api/v1/auth/csrf",
            timeout=15,
        )
        csrf_response.raise_for_status()

        csrf_token = csrf_response.json()["data"]["token"]

        # 2. 채팅방 생성
        response = s.post(
            f"{base_url}/api/v1/ai/conversations",
            headers={
                "X-XSRF-TOKEN": csrf_token,
                "X-K1-Test": "true",
            },
            json={},
            timeout=30,
        )

        if response.status_code not in (200, 201):
            return False, index, (
                f"userId={user_id} HTTP {response.status_code} "
                f"{response.text[:150]}"
            )

        conversation_id = response.json()["data"]["conversationId"]

        # 3. k6에서 사용할 인증 정보 저장
        cookie = "; ".join(
            f"{c.name}={c.value}" for c in s.cookies
        )

        return True, index, {
            "userId": user_id,
            "conversationId": conversation_id,
            "cookie": cookie,
            "csrfToken": csrf_token,
            "createdAt": int(time.time()),
        }

    except Exception as exc:
        return False, index, f"userId={user_id}: {exc}"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tokens", default="tokens.json")
    parser.add_argument("--out", default="pool.json")
    parser.add_argument("--base-url", default="https://needu.gift")
    parser.add_argument("--count", type=int, default=10)
    parser.add_argument("--workers", type=int, default=2)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()

    accounts = json.loads(Path(args.tokens).read_text())

    if not accounts:
        sys.exit("No test accounts found")

    if any(
        not a.get("userId") or not a.get("accessToken")
        for a in accounts
    ):
        sys.exit("Each account needs userId and accessToken")

    if args.count <= 0 or args.workers <= 0:
        sys.exit("count and workers must be positive")

    print(
        f"accounts={len(accounts)} "
        f"count={args.count} "
        f"workers={args.workers} "
        f"execute={args.execute}"
    )

    if not args.execute:
        print("DRY RUN: no Production requests sent")
        return

    results = []
    errors = []

    with concurrent.futures.ThreadPoolExecutor(
        max_workers=args.workers
    ) as executor:
        futures = [
            executor.submit(
                create_conversation,
                i,
                accounts,
                args.base_url.rstrip("/"),
            )
            for i in range(args.count)
        ]

        for future in concurrent.futures.as_completed(futures):
            ok, index, result = future.result()

            if ok:
                results.append(result)
            else:
                errors.append({
                    "index": index,
                    "error": result,
                })

    results.sort(key=lambda x: x["createdAt"])

    output = Path(args.out)
    output.write_text(json.dumps(results, ensure_ascii=False, indent=2))
    os.chmod(output, 0o600)

    error_path = Path(str(output) + ".errors.json")
    error_path.write_text(
        json.dumps(errors, ensure_ascii=False, indent=2)
    )
    os.chmod(error_path, 0o600)

    print(f"Success: {len(results)}")
    print(f"Errors: {len(errors)}")
    print(f"Pool: {output}")

    if errors:
        for error in errors[:5]:
            print(error, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
