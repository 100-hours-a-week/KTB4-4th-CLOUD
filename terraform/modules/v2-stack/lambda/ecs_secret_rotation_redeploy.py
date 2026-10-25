import logging
import os

import boto3


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

ECS = boto3.client("ecs")
CLUSTER_NAME = os.environ["CLUSTER_NAME"]
SERVICE_NAME = os.environ["SERVICE_NAME"]
EXPECTED_SECRET_NAME = os.environ["EXPECTED_SECRET_NAME"]


def handler(event, _context):
    detail = event.get("detail", {})
    secret_name = detail.get("name")
    label = detail.get("labelUpdated")

    if secret_name != EXPECTED_SECRET_NAME or label != "AWSCURRENT":
        LOGGER.warning(
            "Ignoring unexpected Secrets Manager event: name=%s label=%s",
            secret_name,
            label,
        )
        return {"redeployed": False, "reason": "unexpected event"}

    response = ECS.update_service(
        cluster=CLUSTER_NAME,
        service=SERVICE_NAME,
        forceNewDeployment=True,
    )

    deployment = response["service"]["deployments"][0]
    LOGGER.info(
        "Started Backend ECS deployment after DB secret rotation: deploymentId=%s",
        deployment["id"],
    )
    return {"redeployed": True, "deploymentId": deployment["id"]}
