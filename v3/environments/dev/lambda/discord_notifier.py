
import json
import os
import urllib.request
import urllib.error

import boto3

secrets = boto3.client("secretsmanager")


def get_webhook():
    secret = secrets.get_secret_value(
        SecretId=os.environ["DISCORD_WEBHOOK_SECRET_ARN"]
    )["SecretString"]

    try:
        return json.loads(secret)["webhook_url"]
    except (ValueError, TypeError):
        return secret


def truncate(value, limit=1024):
    return str(value or "-")[:limit]


def create_embed(message):
    status = message.get("status", "unknown").lower()
    alerts = message.get("alerts", [])

    alert = alerts[0] if alerts else {}
    labels = alert.get("labels") or message.get("commonLabels") or {}
    annotations = alert.get("annotations") or message.get("commonAnnotations") or {}

    name = labels.get("alertname", "Unknown Alert")
    title = annotations.get("summary") or name

    is_resolved = status in ("resolved", "ok")

    state = "RECOVERED" if is_resolved else "FIRING"
    color = 0x2ECC71 if is_resolved else 0xE74C3C

    fields = [
        {
            "name": "State",
            "value": state,
            "inline": True,
        },
        {
            "name": "Metric",
            "value": truncate(annotations.get("metric", name)),
            "inline": True,
        },
        {
            "name": "Meaning",
            "value": truncate(annotations.get("description")),
            "inline": False,
        },
        {
            "name": "First check",
            "value": truncate(annotations.get("first_check")),
            "inline": False,
        },
        {
            "name": "Response guide",
            "value": truncate(annotations.get("response_guide")),
            "inline": False,
        },
    ]

    links = []
    if alert.get("dashboardURL"):
        links.append(f"[Dashboard]({alert['dashboardURL']})")
    if alert.get("panelURL"):
        links.append(f"[Panel]({alert['panelURL']})")

    if links:
        fields.append({
            "name": "Links",
            "value": " | ".join(links),
            "inline": False,
        })

    return {
        "title": truncate(
            f"NeedU V3 Dev Alarm {'Recovered' if is_resolved else 'Firing'}: {title}",
            256,
        ),
        "color": color,
        "fields": fields,
        "footer": {
            "text": "NeedU V3 Dev | Grafana Alerting"
        },
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
                "username": "NeedU V3 Dev Alerts",
                "embeds": [create_embed(data)],
            }
        else:
            payload = {
                "username": "NeedU V3 Dev Alerts",
                "content": truncate(message, 2000),
            }

        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")

        req = urllib.request.Request(
            webhook,
            data=body,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "NeedU-AlertBot/1.0",
            },
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                if response.status not in (200, 204):
                    raise RuntimeError(
                        f"Discord returned HTTP {response.status}"
                    )
        except urllib.error.HTTPError as error:
            error_body = error.read().decode(
                "utf-8", errors="replace"
            )
            print(f"Discord HTTP {error.code}: {error_body[:500]}")
            raise

    return {"processed": len(event["Records"])}
