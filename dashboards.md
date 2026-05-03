# Part 5 — Observability (`dashboards.md`)

Maps to the brief:

- **SLO1:** monthly API availability **≥ 99.9%** (tracked via ALB health + errors; exact monthly SLO math is usually done in your observability tool or reporting—here we use **operational alarms** as guardrails).
- **SLO2:** **P95 latency ≤ 300 ms** on traffic through the ALB to the API (health checks hit `/healthz` on targets). The dashboard plots **target-group P95**; path-only `/healthz` P95 needs access logs or tracing if you need it strict.

**Three alert rules (required):**

1. **SLO burn (availability)** — unhealthy targets on the API target group (early burn / outage signal).
2. **5-minute error rate > 2%** — ELB + target **5xx** as a share of requests over 5 minutes.
3. **Daily / monthly cost threshold** — AWS **Budgets** notification (configure period/thresholds to match how you run “daily” guardrails).

Replace `REGION`, `LOAD_BALANCER_FULL_NAME`, `TARGET_GROUP_FULL_NAME`, `REPLACE_ALB_ARN_SUFFIX`, `REPLACE_TG_ARN_SUFFIX`, and emails before use.

---

## One dashboard (JSON stub)

```bash
aws cloudwatch put-dashboard --dashboard-name home-assessment-api --dashboard-body file://dashboard.json
```

```json
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB — Requests & 5xx (SLO1 signals)",
        "region": "REGION",
        "metrics": [
          [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "LOAD_BALANCER_FULL_NAME", { "stat": "Sum" } ],
          [ ".", "HTTPCode_ELB_5XX_Count", ".", ".", { "stat": "Sum", "yAxis": "right" } ],
          [ ".", "HTTPCode_Target_5XX_Count", ".", ".", { "stat": "Sum", "yAxis": "right" } ]
        ],
        "period": 60,
        "view": "timeSeries"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB — Target P95 latency (SLO2 proxy)",
        "region": "REGION",
        "metrics": [
          [ "AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "LOAD_BALANCER_FULL_NAME", "TargetGroup", "TARGET_GROUP_FULL_NAME", { "stat": "p95" } ]
        ],
        "period": 60,
        "yAxis": { "left": { "label": "ms" } }
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB — Unhealthy targets (burn)",
        "region": "REGION",
        "metrics": [
          [ "AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", "LOAD_BALANCER_FULL_NAME", "TargetGroup", "TARGET_GROUP_FULL_NAME", { "stat": "Maximum" } ]
        ],
        "period": 60
      }
    }
  ]
}
```

---

## Alert 1 — SLO burn (unhealthy targets)

`LoadBalancer` / `TargetGroup` = CloudWatch **dimension suffix** (e.g. `app/my-alb/…`), not full ARN.

```hcl
resource "aws_sns_topic" "ops_alerts" {
  name = "home-assessment-ops-alerts"
}

resource "aws_cloudwatch_metric_alarm" "slo_burn_unhealthy_targets" {
  alarm_name          = "home-assessment-slo-burn-unhealthy-targets"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "SLO burn: API target group has unhealthy hosts"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = "REPLACE_ALB_ARN_SUFFIX"
    TargetGroup  = "REPLACE_TG_ARN_SUFFIX"
  }

  alarm_actions = [aws_sns_topic.ops_alerts.arn]
}
```

---

## Alert 2 — 5-minute error rate > 2%

```hcl
resource "aws_cloudwatch_metric_alarm" "error_rate_over_2pct" {
  alarm_name          = "home-assessment-5xx-rate-over-2pct-5m"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 2
  alarm_description   = "5xx exceeded 2% of requests in a 5-minute window"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "e1"
    return_data = true
    expression  = "100 * (m1 + m2) / (m4 + 0.0001)"
    label       = "5xx percent"
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = "REPLACE_ALB_ARN_SUFFIX"
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = "REPLACE_ALB_ARN_SUFFIX"
        TargetGroup  = "REPLACE_TG_ARN_SUFFIX"
      }
    }
  }

  metric_query {
    id = "m4"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = "REPLACE_ALB_ARN_SUFFIX"
      }
    }
  }

  alarm_actions = [aws_sns_topic.ops_alerts.arn]
}
```

---

## Alert 3 — Cost threshold (AWS Budgets)

Use **monthly** budget with alerts at e.g. 85% actual and 100% forecast; pair with **`PAUSE_PROD_DEPLOYS`** in `deploy.yml` / `COST_NOTES.md` for the pipeline side.

```hcl
resource "aws_budgets_budget" "cost_guardrail" {
  name              = "home-assessment-monthly"
  budget_type       = "COST"
  limit_amount      = "500"
  limit_unit        = "USD"
  time_period_start = "2026-01-01_00:00"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 85
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["ops@example.com"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "FORECASTED"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = ["ops@example.com"]
  }
}
```
