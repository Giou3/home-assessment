#!/usr/bin/env bash
# Register a new ECS task definition with an updated container image, update the
# service, wait for stability, then optionally hit ALB /healthz. On health
# failure, rolls back to the previous task definition revision.
set -euo pipefail

TASK_FAMILY="$1"
SERVICE_NAME="$2"
CLUSTER_NAME="$3"
IMAGE_URI="$4"
AWS_REGION="$5"
CONTAINER_NAME="$6"
ALB_DNS="${7:-}"

old_arn="$(aws ecs describe-services \
  --cluster "${CLUSTER_NAME}" \
  --services "${SERVICE_NAME}" \
  --region "${AWS_REGION}" \
  --query 'services[0].taskDefinition' \
  --output text)"

task_json="$(aws ecs describe-task-definition \
  --task-definition "${TASK_FAMILY}" \
  --region "${AWS_REGION}" \
  --query 'taskDefinition' \
  --output json)"

new_def="$(echo "${task_json}" | jq --arg IMG "${IMAGE_URI}" --arg NAME "${CONTAINER_NAME}" '
  del(
    .taskDefinitionArn,
    .revision,
    .status,
    .requiresAttributes,
    .compatibilities,
    .registeredAt,
    .registeredBy
  )
  | .containerDefinitions |= map(if .name == $NAME then .image = $IMG else . end)
')"

new_arn="$(echo "${new_def}" | aws ecs register-task-definition \
  --cli-input-json file:///dev/stdin \
  --region "${AWS_REGION}" \
  --query 'taskDefinition.taskDefinitionArn' \
  --output text)"

rollback() {
  echo "Rolling back to ${old_arn}"
  aws ecs update-service \
    --cluster "${CLUSTER_NAME}" \
    --service "${SERVICE_NAME}" \
    --task-definition "${old_arn}" \
    --region "${AWS_REGION}" >/dev/null
  aws ecs wait services-stable \
    --cluster "${CLUSTER_NAME}" \
    --services "${SERVICE_NAME}" \
    --region "${AWS_REGION}" || true
}

trap 'rollback' ERR

aws ecs update-service \
  --cluster "${CLUSTER_NAME}" \
  --service "${SERVICE_NAME}" \
  --task-definition "${new_arn}" \
  --region "${AWS_REGION}" >/dev/null

aws ecs wait services-stable \
  --cluster "${CLUSTER_NAME}" \
  --services "${SERVICE_NAME}" \
  --region "${AWS_REGION}"

if [[ -n "${ALB_DNS}" ]]; then
  curl -fsS --max-time 30 "http://${ALB_DNS}/healthz" >/dev/null
fi

trap - ERR
