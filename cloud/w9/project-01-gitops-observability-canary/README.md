# W9 Project 01 - GitOps, Observability, Canary

Project nay la final project cho W9: build mot web app co frontend va backend nho, dua toan bo desired state vao Git, de ArgoCD reconcile tu dong, quan sat bang Prometheus/Grafana, va rollout bang Argo Rollouts dua tren metric.

Muc tieu cuoi:

- Git la source of truth; khong deploy app bang `kubectl apply` thu cong sau khi da bat GitOps.
- ArgoCD quan ly platform add-ons va workload theo app-of-apps.
- App co frontend tai `/`, backend API tai `/api/status`, va `/healthz`, `/readyz`, `/metrics` cho monitoring/rollout analysis.
- Prometheus scrape ServiceMonitor, Grafana hien thi metrics, PrometheusRule canh bao SLO.
- Argo Rollouts thuc hien canary theo tung buoc va co the abort khi success rate xau.

## Architecture

```mermaid
flowchart LR
  Dev[Developer] --> PR[Pull Request]
  PR --> CI[GitHub Actions<br/>lint + dry-run]
  CI --> Merge[Merge to main]
  Merge --> ArgoCD[ArgoCD]
  ArgoCD --> K8s[Kubernetes Cluster]

  K8s --> App[w9-api Web App]
  App --> Frontend[Frontend HTML/CSS/JS]
  App --> Backend[Backend API /api/status]
  Backend --> Metrics[/metrics]

  Metrics --> Grafana[Grafana Dashboard]
  Metrics --> Rollouts[Argo Rollouts AnalysisTemplate]
  Rollouts -->|abort if metric bad| App
```

## Folder Structure

```text
project-01-gitops-observability-canary/
  README.md
  PROJECT-STEPS.md
  ARCHITECTURE.md
  EVIDENCE.md
  reflection.md
  app/                         # Flask backend and frontend static assets
  ci/github-actions/          # PR checks and merge workflow examples
  argocd/apps/                # Active ArgoCD Applications
  apps/w9-api/                # Final app manifests managed by GitOps
  observability/              # Optional notes for extending telemetry
  loadtest/                   # k6 scripts for traffic and canary tests
  docs/image/                 # Evidence screenshots
```

## Learning Order

1. Read `ARCHITECTURE.md`.
2. Read `PROJECT-STEPS.md`.
3. Complete `PHASE-0-SETUP.md`.
4. Complete `PHASE-1-APP-MANIFESTS.md`.
5. Complete `PHASE-2-GITOPS-ARGOCD.md`.
6. Complete `PHASE-3-CICD-GUARDRAILS.md`.
7. Complete `PHASE-4-OBSERVABILITY.md`.
8. Complete `PHASE-5-CANARY.md`.
9. Build the local image into the cluster:

```powershell
minikube image build -p w9 -t w9-api:2 app
```

10. Install ArgoCD, then apply the root app:

```powershell
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd -n argocd
kubectl apply -f argocd/app-of-apps.yaml
```

11. Check sync and health:

```powershell
kubectl get applications -n argocd
kubectl get pods -n demo
kubectl get rollout -n demo
kubectl get servicemonitor,prometheusrule -n demo
```

12. Use `EVIDENCE.md` to capture final proof.

## Notes

- The guide uses a dedicated minikube profile named `w9`. If you want to reuse the default profile, replace `-p w9` with `-p minikube` and use context `minikube`.
- Replace repo URL, namespace, image tag, and metric queries if your real project naming changes.
- Do not commit real secrets. Use sealed-secrets, external-secrets, or cloud secret manager in real projects.
- Prefer GitOps pull-based sync through ArgoCD instead of `kubectl apply` for app changes.
- `argocd/apps` is active from the start and is the only path deployed by the root app.
