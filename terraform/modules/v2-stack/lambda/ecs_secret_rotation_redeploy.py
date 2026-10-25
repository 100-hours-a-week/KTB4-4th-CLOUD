import logging
import os

import boto3


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

ECS = boto3.client("ecs")
CLUSTER_NAME = os.environ["CLUSTER_NAME"]
SERVICE_NAME = os.environ["SERVICE_NAME"]
EXPECTED_SECRET_ARN = os.environ["EXPECTED_SECRET_ARN"]


def handler(event, _context):
    detail = event.get("detail", {})
    label = detail.get("labelUpdated")
    resources = event.get("resources", [])

    if EXPECTED_SECRET_ARN not in resources or label != "AWSCURRENT":
        LOGGER.warning(
            "Ignoring unexpected Secrets Manager event: resources=%s label=%s",
            resources,
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
