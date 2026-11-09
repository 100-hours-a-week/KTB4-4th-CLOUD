#!/usr/bin/env python3
"""Upload the vLLM container model and deploy it to a Terraform-managed endpoint."""

from __future__ import annotations

import argparse
import re
import sys

import google.auth
from google.auth import impersonated_credentials
from google.cloud import aiplatform


IMAGE_URI_PATTERN = re.compile(
    r"^asia-northeast3-docker\.pkg\.dev/[^\s@]+@sha256:[0-9a-f]{64}$"
)
MODEL_ID_PATTERN = re.compile(r"^[a-z][a-z0-9_-]{0,62}$")
FORBIDDEN_SECRET_ARGUMENTS = ("--api-key", "--hf-token", "--token")
SCOPES = ["https://www.googleapis.com/auth/cloud-platform"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Upload a custom vLLM container as a Vertex Model and deploy it to "
            "an existing dedicated endpoint."
        )
    )
    parser.add_argument("--project-id", default="needu-v3-dev-ai-514205")
    parser.add_argument("--region", default="asia-northeast3")
    parser.add_argument("--endpoint-id", required=True)
    parser.add_argument("--model-id", required=True)
    parser.add_argument("--model-display-name", default="needu-v3-dev-vllm")
    parser.add_argument("--deployed-model-display-name", default="needu-v3-dev-vllm")
    parser.add_argument("--image-uri", required=True)
    parser.add_argument(
        "--artifact-uri",
        help="Optional gs:// model artifact directory staged by Vertex AI for the custom container.",
    )
    parser.add_argument("--runtime-service-account", required=True)
    parser.add_argument("--impersonate-service-account", required=True)
    parser.add_argument("--machine-type", required=True)
    parser.add_argument("--accelerator-type", required=True)
    parser.add_argument("--accelerator-count", type=int, default=1)
    parser.add_argument("--min-replica-count", type=int, default=1)
    parser.add_argument("--max-replica-count", type=int, default=1)
    parser.add_argument("--container-port", type=int, default=8080)
    parser.add_argument("--health-route", default="/health")
    parser.add_argument("--container-arg", action="append", default=[])
    parser.add_argument(
        "--use-hf-token",
        action="store_true",
        help="Tell the custom image wrapper to read the Dev HF token from Secret Manager.",
    )
    parser.add_argument("--deployment-timeout-seconds", type=int, default=3600)
    parser.add_argument(
        "--confirm-billable-deployment",
        action="store_true",
        help="Acknowledge that creating the GPU-backed deployment incurs charges.",
    )
    args = parser.parse_args()

    if not IMAGE_URI_PATTERN.fullmatch(args.image_uri):
        parser.error("--image-uri must be a Seoul Artifact Registry image pinned by sha256 digest")
    expected_image_prefix = (
        f"asia-northeast3-docker.pkg.dev/{args.project_id}/needu-vllm/"
    )
    if not args.image_uri.startswith(expected_image_prefix):
        parser.error("--image-uri must be stored in this project's needu-vllm Artifact Registry repository")
    if args.artifact_uri is not None and not args.artifact_uri.startswith("gs://"):
        parser.error("--artifact-uri must be a gs:// URI")
    if not MODEL_ID_PATTERN.fullmatch(args.model_id):
        parser.error("--model-id must start with a lowercase letter and contain only lowercase letters, digits, _ or -")
    if not args.endpoint_id.isdigit() or args.endpoint_id.startswith("0") or len(args.endpoint_id) > 10:
        parser.error("--endpoint-id must be a numeric Vertex endpoint ID of at most 10 digits")
    if args.accelerator_count < 1:
        parser.error("--accelerator-count must be at least 1")
    if args.min_replica_count < 1 or args.max_replica_count < args.min_replica_count:
        parser.error("replica counts must satisfy 1 <= min <= max")
    if args.container_port < 1 or args.container_port > 65535:
        parser.error("--container-port must be between 1 and 65535")
    if not args.container_arg:
        parser.error("provide the non-secret vLLM launch options with one or more --container-arg values")
    normalized_args = [arg.strip().lower() for arg in args.container_arg]
    forbidden_flag = any(
        normalized.split("=", maxsplit=1)[0] in FORBIDDEN_SECRET_ARGUMENTS
        or normalized.startswith(("hf_token=", "api_key=", "hf-token="))
        or re.search(r"\bhf_[a-z0-9]{20,}\b", normalized) is not None
        for normalized in normalized_args
    )
    if forbidden_flag:
        parser.error("do not pass an API key or Hugging Face token through container arguments")
    if not args.confirm_billable_deployment:
        parser.error("pass --confirm-billable-deployment after reviewing the GPU type and replica count")

    return args


def main() -> int:
    args = parse_args()
    source_credentials, _ = google.auth.default(scopes=SCOPES)
    credentials = impersonated_credentials.Credentials(
        source_credentials=source_credentials,
        target_principal=args.impersonate_service_account,
        target_scopes=SCOPES,
        lifetime=3600,
    )

    aiplatform.init(
        project=args.project_id,
        location=args.region,
        credentials=credentials,
    )

    endpoint = aiplatform.Endpoint(
        endpoint_name=args.endpoint_id,
        project=args.project_id,
        location=args.region,
    )
    endpoint_state = endpoint.gca_resource
    if endpoint_state.deployed_models:
        print(
            "Endpoint already has a deployed model. Review the rollout and traffic split "
            "before deploying another version.",
            file=sys.stderr,
        )
        return 2

    container_environment = {}
    if args.use_hf_token:
        container_environment["HF_TOKEN_SECRET_RESOURCE"] = (
            f"projects/{args.project_id}/secrets/needu-dev-hf-token/versions/latest"
        )

    model = aiplatform.Model.upload(
        model_id=args.model_id,
        display_name=args.model_display_name,
        serving_container_image_uri=args.image_uri,
        artifact_uri=args.artifact_uri,
        serving_container_invoke_route_prefix="/*",
        serving_container_health_route=args.health_route,
        serving_container_ports=[args.container_port],
        serving_container_args=args.container_arg,
        serving_container_deployment_timeout=args.deployment_timeout_seconds,
        serving_container_environment_variables=container_environment,
        sync=True,
    )
    print(f"Uploaded Vertex model: {model.resource_name}", flush=True)

    endpoint.deploy(
        model=model,
        deployed_model_display_name=args.deployed_model_display_name,
        traffic_percentage=100,
        machine_type=args.machine_type,
        min_replica_count=args.min_replica_count,
        max_replica_count=args.max_replica_count,
        accelerator_type=args.accelerator_type,
        accelerator_count=args.accelerator_count,
        service_account=args.runtime_service_account,
        sync=True,
        enable_access_logging=False,
    )
    print(f"Deployed model to Vertex endpoint: {endpoint.resource_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
