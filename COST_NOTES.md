# Part 5 — Cost & performance (`COST_NOTES.md`)

One-pager per the brief.

## ALB vs API Gateway vs CloudFront-only (small service)

- **ALB + ECS (this repo’s API path):** Simple L7 to Fargate, health checks, scaling signals. Pay **ALB + LCU**; no per-request API Gateway fee.
- **API Gateway:** Strong **auth/throttle** at the edge; **per-million** pricing—compare to your traffic shape.
- **CloudFront-only:** Ideal for **static** (we use **S3 + CloudFront**). A **dynamic** API still needs a compute origin behind CloudFront unless you adopt edge compute.

**Choice here:** CloudFront+S3 for static, ALB+Fargate for API.

## Default autoscaling policy

- **Today:** fixed `desired_count` in Terraform.
- **Default we’d add:** ECS **Application Auto Scaling** — **target tracking** on **CPU ~60–70%** or **ALB requests per target**; **min/max** + **cooldown** to limit flapping.

## Static asset caching

- **Today:** default CloudFront behaviour — GET/HEAD, cookies not forwarded; good for **immutable hashed** assets.
- **Tweak:** longer TTL or path behaviours for `/static/*`; prefer **versioned keys** over full distribution invalidations.

## Daily budget guardrail + alert + pause prod deploys

1. **AWS Budgets** — monthly cap + alerts (see **`dashboards.md`** Terraform for Alert 3). Adjust thresholds for how you treat “daily” vs monthly spend.
2. **Pipeline toggle** — repo variable **`PAUSE_PROD_DEPLOYS=true`** skips **production** jobs in `.github/workflows/deploy.yml` (staging can still run). Document who may set/clear it.

For real accounts, also use **org/payer billing alarms** and **SCPs** where appropriate—Budgets + this flag are not the whole story.
