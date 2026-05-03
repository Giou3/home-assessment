# home-assessment

DevOps home assessment: Terraform (AWS), containerized API, GitHub Actions.

Assessment write-ups: [Part 1 — CDN bugs](docs/terraform-bugfixes.md) · [Part 3 — pipeline debug](docs/part3-pipeline-debug.md) · [Part 5 — observability](dashboards.md) · [Part 5 — security](SECURITY.md) · [Part 5 — cost](COST_NOTES.md).

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

- `ci.yml` — **Dev lane:** runs **unit tests** (`app/test_*.py`), builds the `app/` image on every PR; on **`main`** also runs **Trivy** (HIGH/CRITICAL) and pushes **two immutable tags** to ECR: `:<github.sha>` and `:1.0.<run_number>` (semver-style). AWS/OIDC only on `main`.
- `deploy.yml` — manual **promotion** (`workflow_dispatch`). Choose `pipeline`: **staging** (staging only), **production** (prod only, break-glass), or **staging_then_production** (staging job, then prod only if staging succeeds — health check + ECS rollback are in `scripts/ecs-deploy.sh`). Each job uses the matching GitHub **Environment** so you can add **required reviewers** on `staging` and/or `production`. See the workflow file header for a **one-line ECS rollback** command if you need to revert after a good deploy.

### One-time GitHub configuration

Repository secret (used by `ci.yml` on `main`):

| Secret | Purpose |
| --- | --- |
| `AWS_OIDC_ROLE_ARN` | IAM role ARN trusted for `repo:<org>/<repo>:ref:refs/heads/main` (for example the Terraform output `github_deploy_role_arn` from **one** stack that is allowed to push to the shared ECR repo). |

Optional repository variable (cost guardrail — see `COST_NOTES.md`):

| Variable | Purpose |
| --- | --- |
| `PAUSE_PROD_DEPLOYS` | Set to `true` to skip **production** deploy jobs in `deploy.yml` (staging still runs). Omit or use any other value to allow prod. |

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

### How artifacts flow (Dev → staging → prod)

1. Merge to `main` runs `ci.yml`: tests → image build → Trivy → ECR push with **SHA** and **semver** tags.
2. Run **Deploy** with `image_tag` set to either tag from step 1 (SHA is safest for traceability).
3. Use **`staging_then_production`** to enforce staging first, production runs only after the staging job succeeds (including `/healthz` when `ALB_DNS_NAME` is set). Use **`production`** only for break-glass. Configure **Environment protection rules** for human gates.
4. If `/healthz` fails after a deploy, `ecs-deploy.sh` **automatically** rolls ECS back to the previous task definition. For a manual revert later, use the `aws ecs update-service --task-definition …` one-liner in `deploy.yml` comments.

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
