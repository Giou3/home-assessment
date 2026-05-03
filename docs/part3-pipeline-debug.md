# Part 3 — What broke the staging pipeline

The log looked noisy because three different steps failed, but the brief asked for **two** real root causes. Here is how I read it.

## What the logs showed

The build step died with “can’t open Dockerfile”. Trivy then said the image wasn’t in the local Docker store. Separately, ECR login complained that **the security token … is expired**.

## Cause 1: Building from the wrong folder

The workflow was effectively doing `docker build … .` at the **repo root**. In this project the `Dockerfile` sits under **`app/`**, so Docker never finds a file named `Dockerfile` next to where you ran the command. That’s a quick fail and it happens before any meaningful image exists.

**What to change:** point the build at the app directory, e.g. `docker build -t … ./app`, or keep context `.` but pass `-f app/Dockerfile` explicitly. Same idea.

## Cause 2: Bad or stale AWS credentials when talking to ECR

`aws ecr get-login-password` only works with credentials that are **valid right then**. That error usually means the role session on the runner had already expired, or you never refreshed OIDC in the job that actually pushes.

Common gotchas in GitHub Actions: assuming the **push** job can reuse `AWS_*` from an **earlier** job (it can’t — new runner, those vars aren’t there). Or running a long gap between assuming the role and calling ECR so the session times out. Less common on hosted runners: clock skew.

**What to change:** in the **same** job that logs in to ECR and pushes, run `configure-aws-credentials` (OIDC) **right before** ECR login, then don’t let unrelated slow steps sit between login and push if you can avoid it.

## Trivy wasn’t a separate “third bug”

Trivy was meant to scan the image the workflow had just built. If the build never produced an image, there is nothing in the local Docker daemon for Trivy to look at — hence “image not found in local store”. Fix the build path first and that message usually goes away on its own.

## Why order of fixes matters

If you only chase the Trivy message, you’re still building from `.` and the image never exists. If you only fix AWS and get a clean `docker login`, the build from `.` still fails, so you still have nothing to scan or push.

What worked in practice: checkout → assume role in **this** job → ECR login → **build with `./app`** → Trivy on that tag → retag for the registry → push.

## Shell equivalents (same fixes on the command line)

These match the two root causes plus the Trivy step that only makes sense **after** a successful build. Fix 1 and Fix 2 are the real breakages; Fix 3 is “scan what you actually built,” not another independent failure mode.

```bash
# Fix 1: correct build context (Dockerfile lives under app/)
docker build -t home-assessment-api:$IMAGE_TAG ./app

# Fix 2: valid AWS session right before ECR login (OIDC/configure-aws-credentials in Actions)
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS --password-stdin $ECR_REGISTRY

# Fix 3: scan the image that exists locally after Fix 1
trivy image --exit-code 1 --severity HIGH,CRITICAL home-assessment-api:$IMAGE_TAG
```

In a real pipeline you’d run Fix 2 only when `AWS_ACCESS_KEY_ID` / session creds are already fresh (e.g. right after `configure-aws-credentials`). Order on the runner: authenticate → build from `./app` → Trivy → `docker tag` / `docker push` to `$ECR_REGISTRY/...`.

## Reference: workflow shape we use

The push job in `.github/workflows/ci.yml` follows that order. Roughly:

```yaml
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_OIDC_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION || 'eu-central-1' }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build image (local tag for Trivy)
        env:
          LOCAL_IMAGE: home-assessment-api:${{ github.sha }}
        run: |
          docker build -t "${LOCAL_IMAGE}" ./app

      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@0.28.0
        with:
          image-ref: "home-assessment-api:${{ github.sha }}"
          exit-code: "1"
          severity: "HIGH,CRITICAL"

      - name: Tag and push to ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ${{ vars.ECR_REPOSITORY || 'home-assessment-api' }}
          IMAGE_TAG: ${{ github.sha }}
          LOCAL_IMAGE: home-assessment-api:${{ github.sha }}
        run: |
          docker tag "${LOCAL_IMAGE}" "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
          docker push "${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
```

That’s the same story as above: fresh creds, correct context, then scan, then push.
