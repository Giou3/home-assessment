# home-assessment

DevOps home assessment: Terraform (AWS), containerized API, GitHub Actions.

Assessment write-ups: [Part 1 CDN bugfixes](docs/terraform-bugfixes.md) · [Part 3 pipeline debug](docs/part3-pipeline-debug.md).

## Terraform quickstart

Prerequisites:

- Terraform installed
- AWS credentials configured (`aws sts get-caller-identity` works)
- An S3 bucket + DynamoDB table created for remote state (see `infra/envs/*/backend.hcl.example`)

Remote state setup (once per environment folder):

```powershell
copy infra\envs\prod\backend.hcl.example infra\envs\prod\backend.hcl
copy infra\envs\staging\backend.hcl.example infra\envs\staging\backend.hcl
```

Production:

```powershell
cd infra\envs\prod
terraform init -backend-config backend.hcl
terraform validate
terraform plan -var-file terraform.tfvars
terraform apply -var-file terraform.tfvars
```

Staging:

```powershell
cd infra\envs\staging
terraform init -backend-config backend.hcl
terraform validate
terraform plan -var-file terraform.tfvars
terraform apply -var-file terraform.tfvars
```

Notes:

- Keep `terraform.tfvars` local (do not commit secrets).
- `cdn_bucket_name` must be globally unique per environment.
- On Windows with Terraform 1.15.x, `-backend-config=...` / `-var-file=...` can be parsed incorrectly; prefer the spaced forms shown above.
- After creating or editing `backend.hcl`, run `terraform init -reconfigure -backend-config backend.hcl` once so Terraform picks up the remote backend.
- Prod and staging both default `ecr_repository_name = "home-assessment-api"`. In a single account, only one stack should own that ECR repository (or use `terraform import`, or use different repository names per environment).

## CI and deploy (GitHub Actions)

Workflows live in `.github/workflows/`:

- `ci.yml` — on pull requests, builds the `app/` Docker image. On pushes to `main`, assumes AWS via OIDC (fresh session in that job), logs in to ECR, builds from `./app`, runs **Trivy** (HIGH/CRITICAL, fail on findings), then tags and pushes `:<full-git-sha>` to ECR (default repo `home-assessment-api`, immutable tags).
- `deploy.yml` — manual (`workflow_dispatch`). Picks a GitHub Environment (`staging` or `production`), assumes that environment’s deploy role, runs `scripts/ecs-deploy.sh` to register a new task definition with the chosen image tag, updates the ECS service, waits for stability, then curls `http://<ALB_DNS_NAME>/healthz`. If the health check fails, the script rolls the service back to the previous task definition.

### One-time GitHub configuration

Repository secret (used by `ci.yml` on `main`):

| Secret | Purpose |
| --- | --- |
| `AWS_OIDC_ROLE_ARN` | IAM role ARN trusted for `repo:<org>/<repo>:ref:refs/heads/main` (for example the Terraform output `github_deploy_role_arn` from **one** stack that is allowed to push to the shared ECR repo). |

Per-environment configuration (Settings → Environments → `staging` / `production`):

| Type | Name | Purpose |
| --- | --- | --- |
| Secret | `AWS_DEPLOY_ROLE_ARN` | That environment’s `github_deploy_role_arn` from `terraform output` (prod vs staging roles differ). |
| Variable | `AWS_REGION` | e.g. `eu-central-1` (optional; workflows default to this). |
| Variable | `ECR_REGISTRY` | `<account-id>.dkr.ecr.<region>.amazonaws.com` |
| Variable | `ECR_REPOSITORY` | ECR repo name (optional; defaults to `home-assessment-api`). |
| Variable | `ECS_CLUSTER_NAME` | e.g. `home-assessment-staging-cluster` / `home-assessment-prod-cluster` |
| Variable | `ECS_SERVICE_NAME` | e.g. `home-assessment-staging-api` / `home-assessment-prod-api` |
| Variable | `ECS_TASK_DEFINITION_FAMILY` | Same as service name by default (`…-api`). |
| Variable | `ECS_CONTAINER_NAME` | `api` (optional; defaults to `api` in the deploy script). |
| Variable | `ALB_DNS_NAME` | From `terraform output alb_dns_name` (optional; if unset, deploy skips the HTTP smoke check). |

Add a protection rule on the `production` environment (required reviewers) if you want a manual approval before prod deploys.

### How artifacts flow

1. A merge to `main` runs `ci.yml`, which produces a new **immutable** image tag in ECR (`:<github.sha>`).
2. You run **Deploy** manually, choose `staging` or `production`, and paste that **same** git SHA as `image_tag`.
3. The workflow updates only the ECS task’s container image for that environment, validates `/healthz` through the ALB when `ALB_DNS_NAME` is set, and rolls back the service to the previous task definition if that check fails.

## Key Decisions

### 1) ECS Fargate vs EC2 for the API

Choice: ECS Fargate.

Tradeoffs:

- Fargate reduces operational work (no AMI patching, no capacity management) which fits a small service and a time-boxed assessment.
- Fargate can be more expensive per vCPU/GB-hour at steady high utilization, and offers less fine-grained host customization than EC2.

### 2) Staging isolation: separate AWS account vs isolated VPC (same account)

Choice: isolated VPC in the same AWS account (`10.1.0.0/16` staging vs `10.0.0.0/16` prod).

Tradeoffs:

- Same account is faster and cheaper to operate (single billing, shared ECR, simpler OIDC role management).
- Blast radius is larger than a dedicated account: a highly privileged mistake could impact both environments, so guardrails rely on IAM scoping, approvals, and separate state keys.

### 3) Shared ECR repository vs separate repositories

Choice: shared ECR repository for both environments.

Tradeoffs:

- Shared repo simplifies promotion (same image digest moves staging → prod) and reduces repo sprawl.
- Shared repo increases the importance of immutable tags and access control, since both environments read from the same registry.

### Staging-only notes (per requirements)

- Staging intentionally does not attach WAF to CloudFront to reduce cost and complexity. Risk: staging edge traffic is easier to abuse for probing; mitigate with separate URLs, auth, and rate limiting at the app where possible.
- Staging runs smaller Fargate sizing: `cpu = 256`, `memory = 512`, `desired_count = 1` to cut cost while keeping the same topology.

### Mocks / stubs

- RDS is stubbed via variables only (`rds_engine`, `rds_instance_class`) and is not provisioned.
- Next step to make this production-grade: add RDS/Secrets Manager, migrate S3 access from OAI to OAC, add TLS on ALB, and tighten IAM policies beyond the assessment defaults.
