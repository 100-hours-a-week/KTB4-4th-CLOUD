import json
import os
import urllib.error
import urllib.request

import boto3


secrets = boto3.client("secretsmanager")


def get_webhook():
    value = secrets.get_secret_value(
        SecretId=os.environ["DISCORD_WEBHOOK_SECRET_ARN"]
    )["SecretString"]

    try:
        return json.loads(value)["webhook_url"]
    except (ValueError, TypeError):
        return value


def truncate(value, limit=1024):
    return str(value or "-")[:limit]


def create_embed(message):
    status = message.get("status", "unknown").lower()
    alerts = message.get("alerts", [])
    alert = alerts[0] if alerts else {}
    labels = alert.get("labels") or message.get("commonLabels") or {}
    annotations = alert.get("annotations") or message.get("commonAnnotations") or {}
    name = labels.get("alertname", "Unknown Alert")
    resolved = status in ("resolved", "ok")

    return {
        "title": truncate(
            f"NeedU V3 Prod Alarm {'Recovered' if resolved else 'Firing'}: "
            f"{annotations.get('summary') or name}",
            256,
        ),
        "color": 0x2ECC71 if resolved else 0xE74C3C,
        "fields": [
            {"name": "State", "value": "RECOVERED" if resolved else "FIRING", "inline": True},
            {"name": "Metric", "value": truncate(annotations.get("metric", name)), "inline": True},
            {"name": "Meaning", "value": truncate(annotations.get("description")), "inline": False},
            {"name": "First check", "value": truncate(annotations.get("first_check")), "inline": False},
            {"name": "Response guide", "value": truncate(annotations.get("response_guide")), "inline": False},
        ],
        "footer": {"text": "NeedU V3 Prod | Alerting"},
    }


def handler(event, context):
    webhook = get_webhook()

    for record in event["Records"]:
        message = record["Sns"].get("Message", "")

        try:
            data = json.loads(message)
        except (ValueError, TypeError):
            data = None

        if isinstance(data, dict) and "alerts" in data:
            payload = {
                "username": "NeedU V3 Prod Alerts",
                "embeds": [create_embed(data)],
            }
        else:
            payload = {
                "username": "NeedU V3 Prod Alerts",
                "content": truncate(message, 2000),
            }

        request = urllib.request.Request(
            webhook,
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
            headers={"Content-Type": "application/json", "User-Agent": "NeedU-AlertBot/1.0"},
            method="POST",
        )

        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                if response.status not in (200, 204):
                    raise RuntimeError(f"Discord returned HTTP {response.status}")
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            print(f"Discord HTTP {error.code}: {body[:500]}")
            raise

    return {"processed": len(event["Records"])}
