# W9 Project 01 - GitOps, Observability, Canary

Final W9 project: deploy a small web app through GitOps, observe it with Prometheus/Grafana, and release it with Argo Rollouts canary analysis.

## Pass Criteria

The project is considered `DAT` only when all 4 items are proven:

1. Changes go through Git, ArgoCD shows `Synced` with no drift, and the app can be reproduced from Git.
2. `git revert` rollback finishes in less than 5 minutes.
3. One SLO and one alert fire to a personal email when an error is injected.
4. A bad canary automatically aborts and returns traffic to the previous good version.

## Architecture

```mermaid
flowchart LR
  Dev[Developer] --> Git[Git commit / push]
  Git --> Actions[GitHub Actions validation]
  Git --> ArgoCD[ArgoCD app-of-apps]
  ArgoCD --> Addons[Argo Rollouts + Prometheus Stack]
  ArgoCD --> Rollout[w9-api Rollout]

  Rollout --> App[Frontend + Backend API]
  App --> Metrics[/metrics]
  Metrics --> Prometheus[Prometheus]
  Prometheus --> SLO[PrometheusRule SLO + Alert]
  Prometheus --> Analysis[AnalysisTemplate]
  SLO --> Alertmanager[Alertmanager email]
  Analysis -->|pass promote / fail abort| Rollout
```

Pipeline:

```text
Git change -> ArgoCD sync -> canary rollout -> Prometheus SLO check -> promote or auto-abort
```

## Active Files

```text
app/                              # Flask frontend/backend source
apps/w9-api/base/rollout.yaml     # Argo Rollouts workload
apps/w9-api/base/analysis-template.yaml
apps/w9-api/base/servicemonitor.yaml
apps/w9-api/base/prometheusrule.yaml
apps/w9-api/base/alertmanagerconfig.yaml
apps/w9-api/overlays/dev/
argocd/app-of-apps.yaml
argocd/apps/
.github/workflows/w9-*.yml
EVIDENCE.md
```

## Quick Start

Run from project root:

```powershell
cd E:\Xbrain\tf_learning\cloud\w9\project-01-gitops-observability-canary
minikube start -p w9 --driver=docker --cpus=4 --memory=6144
kubectl config use-context w9
minikube image build -p w9 -t w9-api:3 app
```

Install ArgoCD and apply only the root app:

```powershell
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd -n argocd
kubectl apply -f argocd/app-of-apps.yaml
```

Check state:

```powershell
kubectl get applications -n argocd
kubectl get rollout,pods,svc -n demo
kubectl get analysistemplate,servicemonitor,prometheusrule,alertmanagerconfig -n demo
```

Open app:

```powershell
kubectl port-forward svc/w9-api -n demo 8080:80
Invoke-RestMethod http://localhost:8080/api/status
```

## SLO, Alert Query, And Threshold

The SLO is 98% successful requests over a 2-minute window.

Recording rule in `apps/w9-api/base/prometheusrule.yaml`:

```promql
(
  sum(rate(flask_http_request_total{namespace="demo",status!~"5.."}[2m]))
  /
  sum(rate(flask_http_request_total{namespace="demo"}[2m]))
) or vector(1)
```

Why this query:

- Numerator: all non-5xx Flask HTTP requests in namespace `demo`.
- Denominator: all Flask HTTP requests in namespace `demo`.
- `or vector(1)`: when there is no traffic yet, the app should not be marked unhealthy only because there is no sample.

Alert rule:

```promql
w9_api:slo_success_rate:2m < 0.98
```

Threshold:

- `0.98` means at least 98% success rate.
- The alert fires after the SLO stays below 98% for `1m`.
- This short window is intentional for a learning lab so the email proof can be captured quickly. In production, use multi-window burn-rate alerts.

## Canary Analysis Query

The Argo Rollouts `AnalysisTemplate` uses the same success-rate idea:

```promql
(
  sum(rate(flask_http_request_total{namespace="demo",status!~"5.."}[2m]))
  /
  sum(rate(flask_http_request_total{namespace="demo"}[2m]))
) or vector(1)
```

Analysis threshold:

```yaml
successCondition: result[0] >= 0.98
failureLimit: 1
```

Meaning:

- If success rate is at least 98%, the canary can continue.
- If the metric fails beyond the limit, Argo Rollouts aborts the new version.
- Because this is a local minikube lab without ingress/service-mesh traffic routing, canary weight is approximated by replica count. In production, connect Argo Rollouts to NGINX Ingress, AWS ALB, Istio, Linkerd, or another traffic router.

## Email Alert Setup

The alert route is Git-managed in:

```text
apps/w9-api/base/alertmanagerconfig.yaml
```

Before testing email, replace these placeholders with your real email values and commit them:

```yaml
to: CHANGE_ME_PERSONAL_EMAIL@example.com
from: CHANGE_ME_SENDER_EMAIL@example.com
authUsername: CHANGE_ME_SENDER_EMAIL@example.com
```

Do not commit the SMTP password. Create it as a Kubernetes Secret:

```powershell
kubectl create secret generic alertmanager-smtp-auth `
  -n demo `
  --from-literal=password="YOUR_SMTP_APP_PASSWORD"
```

Then push the email config change through Git and let ArgoCD sync it.

## Evidence

Use `EVIDENCE.md` for the exact screenshot and clip checklist. Required proof:

- Git commit plus ArgoCD `Synced/Healthy`.
- Reproduce from Git on a clean cluster.
- `git revert` rollback time under 300 seconds.
- SLO alert firing and email received after injecting errors.
- Bad canary `AnalysisRun` failed and rollout auto-aborted to the old good version.

For a command-by-command demo flow, use `DEMO-TEST-RUNBOOK.md`.

## Destroy Local Lab

```powershell
kubectl delete -f argocd/app-of-apps.yaml --ignore-not-found
helm uninstall argocd -n argocd
minikube delete -p w9
```

Do not use these commands until evidence is captured.
