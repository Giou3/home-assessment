# Part 5 — Security baselines (`SECURITY.md`)

Checklist from the brief, tied to this repo.

## IAM least privilege + GitHub OIDC

- **Where:** `infra/modules/iam_oidc` (trust policy + deploy role), `infra/modules/ecs_iam` (ECS task + execution roles).
- **What:** GitHub assumes AWS only via **OIDC** and allowed **`sub`** claims; deploy role can **ECR** (named repo), **ECS** (named cluster/service/task family), **PassRole** to those ECS roles only, **logs** for `/ecs/<service>`.

## Secrets in AWS Secrets Manager

- **Today:** no app secrets in task defs; RDS is **stub variables** only.
- **Intended:** secrets in **Secrets Manager**, ECS `secrets` references, execution role **`secretsmanager:GetSecretValue`** on those ARNs only.

## Image scan in CI (Trivy)

- **Where:** `.github/workflows/ci.yml` on `main` — **HIGH/CRITICAL** fails the job before ECR push.

## HTTPS everywhere (redirect 80→443, secure headers)

| Surface | Status |
| --- | --- |
| **CloudFront (static)** | **HTTPS enforced** — `redirect-to-https` in `infra/modules/cdn`. |
| **ALB (API)** | **HTTP :80 only** in `infra/modules/alb` — add **ACM + 443**, redirect **80→443**, and **security headers** (e.g. response headers policy / app) for production hardening. |

## WAF managed rules (production)

- **Where:** `infra/modules/waf` — **AWSManagedRulesCommonRuleSet** on **CloudFront** Web ACL (prod only; staging has no WAF per README).
- **Exclusions:** **none** in Terraform. For false positives, override specific managed rule IDs to **count** after reviewing sampled requests—don’t disable the whole group blindly.
