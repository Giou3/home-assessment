# Optional technical questions (3 of 6)

Answered here: **Q2**, **Q4**, and **Q6**.

---

## Q2 — Overlapping CIDRs in multi-VPC

Overlapping CIDRs mean two networks share the same address space (for example both use `10.0.0.0/16`). In that case, routing between them is ambiguous, so VPC peering/TGW/VPN cannot reliably decide where packets should go.

**Most cost-effective long-term fix:** re-address the smaller/newer VPC to a non-overlapping CIDR and migrate once.  
Short-term workarounds (NAT/proxy/segmented routing) can unblock things, but usually add recurring cost and operational complexity.

---

## Q4 — Why not ship logs directly from pods?

Shipping logs directly from every pod to a remote log server is fragile because:

- pod IPs are ephemeral (frequent reconnect/reconfig);
- app containers now carry logging/network concerns (tight coupling);
- backpressure can hurt app performance or lose logs during spikes;
- credentials and TLS config are duplicated across many workloads.

An aggregator (node-level agent like Fluent Bit/Vector, or sidecar in special cases) helps by buffering, retrying, enriching metadata (namespace/pod), and centralizing routing.

You can skip a heavy aggregator for tiny/simple setups if:

- workload is low volume;
- logs already go to a managed platform stdout collector;
- retention/search needs are minimal.

But once scale/compliance/reliability matters, an aggregator pattern is usually worth it.

---

## Q6 — If staging moves to a second cloud

### Three biggest changes

1. **Identity and deploy auth**
   - Add cloud-specific federation (GitHub OIDC trust) for the second cloud.
   - Keep separate deploy roles/permissions per environment and provider.

2. **Infrastructure and state**
   - Add Terraform provider/modules for cloud #2 networking, LB, compute, registry.
   - Use separate remote state/backends and environment isolation per provider.

3. **Delivery + observability integration**
   - Update deploy workflow to target both providers (matrix or separate jobs).
   - Map metrics/logs/alerts to each cloud’s native stack while preserving common SLOs.

### What should stay identical

- Same app artifact strategy (image tagged by SHA/semver).
- Same promotion model (dev → staging → prod gates + approvals).
- Same health contract (`/healthz` = 200), rollback playbook, and release policy.
- Same security baseline intent (least privilege, scanning, secrets management), implemented with provider-specific services.

