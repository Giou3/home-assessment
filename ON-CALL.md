# Part 6 — Backups, DR, and on-call (`ON-CALL.md`)

## Backup strategy *if a database existed* (e.g. RDS Postgres)

We don’t provision RDS in this repo (stub only). If we added a **managed DB**, a sensible baseline would be:

**Frequency (how often we back up)**  
- Turn on **automated backups** on RDS (continuous window for point-in-time restore).  
- Take a **manual snapshot** after big **schema** changes.  
- Optionally copy **logical dumps** to S3 for long retention or another account.

**Retention (how long we keep copies)**  
- Keep **automated** backups **7–35 days** (pick what compliance needs).  
- Keep **manual** snapshots until a ticket says they can be deleted.

**Restore procedure (how we recover after a failure)**  
1. Restore to a **new** RDS instance (point-in-time or from a snapshot ID).  
2. **Validate** data (smoke tests, app in maintenance mode if needed).  
3. Point the app at the new endpoint (**Secrets Manager** / connection string) **or** promote that instance and retire the old one.  
4. If the restore is empty, **re-run migrations** as needed.  
5. Write down **RTO/RPO** targets next to this runbook so everyone agrees what “good” looks like.

Always test a restore **quarterly** (game day): “restore to staging” and run the app against it.

---

## DR concept — CloudFront origin failover + state

**Origin failover (static / CDN path):** CloudFront can use an **origin group** with a **primary** and **secondary** origin (e.g. primary S3 bucket in `eu-central-1`, secondary bucket in another region or second bucket after replication). If primary fails health checks, traffic **fails over** to secondary. **S3 CRR** (cross-region replication) keeps objects in sync for static assets; **RPO** is replication lag.

**API / ECS path:** This stack serves the API via **ALB + ECS**, not CloudFront. DR for the API is usually **multi-AZ** within one region first, then **runbooks** to redeploy in a second region (new VPC/state workspace, restore DB, point DNS). CloudFront failover alone doesn’t replace that.

**State considerations:** Terraform **remote state** (S3 + lock) is a **single-region** dependency unless you replicate the bucket and document **break-glass** procedures. **Secrets** and **AMIs / ECR images** must exist or be rebuildable in the DR region. **DNS** (Route 53 health checks + failover) is the usual switch for customer-facing names—not CloudFront origin failover for the API unless the API is behind CloudFront.

---

## On-call — first 15 minutes

Use this when prod (or staging) is **down**, **degraded**, or **screaming alerts**.

1. **Acknowledge** the page/incident channel; note **start time** and **on-call owner**.
2. **Classify:** user-facing outage vs internal vs single dependency (DB, ALB, ECS, CDN).
3. **Quick checks (read-only):** AWS **health** for the region; **ECS** service events; **ALB** target health; **CloudWatch** dashboard (`dashboards.md`); recent **deploys** / GitHub Actions.
4. **Stabilize:** if a **bad deploy**, use **rollback** (below). If **capacity**, scale ECS / check autoscaling. If **DB**, fail over read replica or invoke DBA runbook—**don’t guess** on data.
5. **Communicate** using the template below (even a short “investigating”).
6. **Escalate** if no progress in **15 minutes** or scope is security/data loss.

---

## Comms template (Slack / email / status page)

```
Subject/Incident: [SERVICE] — [Investigating | Identified | Monitoring | Resolved]

Status: [Investigating / Mitigating / Resolved]
Impact: [Who is affected — e.g. API errors, static site OK]
Started: [UTC time]
What we know: [1–2 sentences]
What we’re doing: [1–2 sentences]
Next update: [time in UTC]

— On-call: [name]
```

---

## Rollback steps (this repository)

**ECS / API (image rollback):**

- **Automatic:** `scripts/ecs-deploy.sh` rolls ECS back to the **previous task definition** if **`/healthz`** fails after a deploy (when ALB DNS is wired).
- **Manual:** `deploy.yml` header documents **`aws ecs update-service --task-definition <previous-arn>`**. Get the previous ARN from **ECS console** or **`aws ecs describe-services`** before/after deploy.

**Pipeline freeze (cost / change freeze):** set **`PAUSE_PROD_DEPLOYS=true`** (repo variable) to stop **production** deploy workflows; see `COST_NOTES.md`.

**Terraform:** only roll back Terraform if the incident was caused by **infra change**; use **version control** + **`terraform plan`** against the right **state** workspace; avoid `apply` during an outage unless that *is* the fix.

**CDN / static:** invalidate or revert **last deployment** to S3; WAF rule changes may need revert in Terraform or console (document change IDs).

---

## Postmortem template (blameless)

```markdown
# Incident: [title] — [date UTC]

## Summary
- **Duration:** 
- **Impact:** (users, revenue, SLO)
- **Severity:** (e.g. SEV1/2/3)

## Timeline (UTC)
- HH:MM — 
- HH:MM — 

## Root cause
- 

## What went well
- 

## What went wrong / gaps
- 

## Action items
| Action | Owner | Due |
| --- | --- | --- |
| | | |

## Links
- Metrics/dashboards:
- PRs/deploys:
```

---

