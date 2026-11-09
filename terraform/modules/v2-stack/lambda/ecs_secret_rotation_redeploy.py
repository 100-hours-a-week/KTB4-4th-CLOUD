import json
import logging
import os
from urllib.parse import quote, urlsplit, urlunsplit

import boto3


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

ECS = boto3.client("ecs")
SECRETS_MANAGER = boto3.client("secretsmanager")
SSM = boto3.client("ssm")
CLUSTER_NAME = os.environ["CLUSTER_NAME"]
BACKEND_SERVICE_NAME = os.environ["BACKEND_SERVICE_NAME"]
AI_SERVICE_NAME = os.environ["AI_SERVICE_NAME"]
MYSQL_SECRET_ARN = os.environ["MYSQL_SECRET_ARN"]
POSTGRES_SECRET_ARN = os.environ["POSTGRES_SECRET_ARN"]
POSTGRES_HOST = os.environ["POSTGRES_HOST"]
POSTGRES_PORT = int(os.environ["POSTGRES_PORT"])
AI_DATABASE_URL_PARAMETER = os.environ["AI_DATABASE_URL_PARAMETER"]


def build_database_url(current_url, username, password, host, port):
    parsed = urlsplit(current_url)
    if parsed.scheme not in {"postgres", "postgresql", "postgresql+asyncpg"}:
        raise ValueError("Unsupported PostgreSQL URL scheme")
    if not parsed.path or parsed.path == "/":
        raise ValueError("PostgreSQL URL must include a database name")

    netloc = (
        f"{quote(username, safe='')}:{quote(password, safe='')}"
        f"@{host}:{port}"
    )
    return urlunsplit(
        (parsed.scheme, netloc, parsed.path, parsed.query, parsed.fragment)
    )


def redeploy(service_name):
    response = ECS.update_service(
        cluster=CLUSTER_NAME,
        service=service_name,
        forceNewDeployment=True,
    )
    return response["service"]["deployments"][0]["id"]


def sync_ai_database_url():
    secret_response = SECRETS_MANAGER.get_secret_value(SecretId=POSTGRES_SECRET_ARN)
    secret = json.loads(secret_response["SecretString"])
    username = secret.get("username")
    password = secret.get("password")
    if not username or not password:
        raise ValueError("PostgreSQL secret is missing username or password")

    parameter = SSM.get_parameter(
        Name=AI_DATABASE_URL_PARAMETER,
        WithDecryption=True,
    )["Parameter"]
    current_url = parameter["Value"]
    updated_url = build_database_url(
        current_url,
        username,
        password,
        POSTGRES_HOST,
        POSTGRES_PORT,
    )

    changed = updated_url != current_url
    if changed:
        response = SSM.put_parameter(
            Name=AI_DATABASE_URL_PARAMETER,
            Value=updated_url,
            Type="SecureString",
            Overwrite=True,
        )
        LOGGER.info(
            "Updated AI database URL parameter to version %s",
            response["Version"],
        )
    else:
        LOGGER.info("AI database URL parameter already uses the current secret")
    return changed


def handler(event, _context):
    detail = event.get("detail", {})
    label = detail.get("labelUpdated")
    resources = event.get("resources", [])

    if label != "AWSCURRENT" or len(resources) != 1:
        LOGGER.warning(
            "Ignoring unexpected Secrets Manager event: resources=%s label=%s",
            resources,
            label,
        )
        return {"redeployed": False, "reason": "unexpected event"}

    secret_arn = resources[0]
    if secret_arn == MYSQL_SECRET_ARN:
        deployment_id = redeploy(BACKEND_SERVICE_NAME)
        LOGGER.info(
            "Started Backend ECS deployment after MySQL secret rotation: deploymentId=%s",
            deployment_id,
        )
        return {
            "target": "backend",
            "parameterUpdated": False,
            "redeployed": True,
            "deploymentId": deployment_id,
        }

    if secret_arn == POSTGRES_SECRET_ARN:
        parameter_updated = sync_ai_database_url()
        deployment_id = redeploy(AI_SERVICE_NAME)
        LOGGER.info(
            "Started AI ECS deployment after PostgreSQL secret rotation: deploymentId=%s",
            deployment_id,
        )
        return {
            "target": "ai",
            "parameterUpdated": parameter_updated,
            "redeployed": True,
            "deploymentId": deployment_id,
        }

    LOGGER.warning("Ignoring event for an unmanaged secret: resources=%s", resources)
    return {"redeployed": False, "reason": "unexpected secret"}
