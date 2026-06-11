# W9 Evidence Guide

Use this file as the final submission checklist. Save screenshots under `docs/image/` and clips under `docs/video/`.

## Acceptance Checklist

The submission is `DAT` only when all 4 items are proven:

- [ ] Change goes through Git, ArgoCD is `Synced/Healthy`, no drift remains, and the system can be reproduced from Git.
- [ ] `git revert` rollback finishes in less than 5 minutes.
- [ ] One SLO and one alert fire to a personal email when an error is injected.
- [ ] A bad canary automatically aborts and stays on the previous good version.

## Evidence Architecture

```mermaid
flowchart LR
  Git[GitHub repo] --> Actions[GitHub Actions]
  Git --> ArgoCD[ArgoCD app-of-apps]
  ArgoCD --> Addons[Argo Rollouts + Prometheus Stack]
  ArgoCD --> Rollout[w9-api Rollout]
  Rollout --> App[Frontend + Backend API]
  App --> Metrics[/metrics]
  Metrics --> Prometheus[Prometheus]
  Prometheus --> SLO[PrometheusRule SLO]
  SLO --> Alert[Alertmanager email]
  Prometheus --> Analysis[AnalysisTemplate]
  Analysis -->|healthy| Promote[Promote canary]
  Analysis -->|bad metric| Abort[Auto-abort to old version]
```

## Screenshot Naming

Use these names so the reviewer can follow the proof quickly:

| File | Proof |
| --- | --- |
| `docs/image/01-git-commit.png` | Git commit that changed desired state |
| `docs/image/02-actions-pass.png` | GitHub Actions validation passed |
| `docs/image/03-argocd-synced-healthy.png` | ArgoCD app is `Synced/Healthy` |
| `docs/image/04-no-drift-self-heal.png` | Drift was corrected back to Git |
| `docs/image/05-reproduce-from-git.png` | Clean deploy from Git works |
| `docs/image/06-slo-rule-query.png` | Prometheus SLO query exists and returns value |
| `docs/image/07-alert-firing.png` | Alert is `Firing` after error injection |
| `docs/image/08-alert-email.png` | Email was received |
| `docs/image/09-canary-analysis-failed.png` | Bad canary AnalysisRun failed |
| `docs/image/10-canary-auto-aborted.png` | Rollout auto-aborted and old version stayed available |
| `docs/image/11-git-revert-rollback-time.png` | Rollback completed under 300 seconds |
| `docs/image/12-final-healthy.png` | Final state is healthy after rollback |

Recommended clip:

```text
docs/video/01-canary-auto-abort-and-rollback.mp4
```

Clip must show:

1. Git change to bad version.
2. ArgoCD sync starts.
3. Canary analysis fails.
4. Rollout aborts.
5. `git revert` rollback returns system to healthy state in less than 5 minutes.

## 1. GitOps And No Drift

Capture current commit:

```powershell
git log --oneline -5 -- cloud/w9/project-01-gitops-observability-canary
```

Capture ArgoCD:

```powershell
kubectl get applications -n argocd
kubectl get application w9-api -n argocd -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"`n"}'
```

Expected:

```text
Synced Healthy
```

Capture workload:

```powershell
kubectl get rollout,pods,svc -n demo
kubectl get analysistemplate,servicemonitor,prometheusrule,alertmanagerconfig -n demo
```

No-drift proof:

```powershell
kubectl scale rollout w9-api -n demo --replicas=1
kubectl get rollout w9-api -n demo
kubectl annotate application w9-api -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl get rollout w9-api -n demo -w
```

Expected:

- Replica briefly becomes `1`.
- ArgoCD self-heals it back to the Git value `2`.
- ArgoCD returns to `Synced/Healthy`.

## 2. Reproduce From Git

Use a clean folder or a clean machine:

```powershell
git clone https://github.com/G-03-XBrain-Phase-2/hoangson-aws-accelerator-p2.git w9-reproduce
cd w9-reproduce\cloud\w9\project-01-gitops-observability-canary
minikube start -p w9 --driver=docker --cpus=4 --memory=6144
kubectl config use-context w9
minikube image build -p w9 -t w9-api:3 app
kubectl create namespace argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install argocd argo/argo-cd -n argocd
kubectl apply -f argocd/app-of-apps.yaml
kubectl get applications -n argocd
```

Expected:

- `argo-rollouts`, `kube-prometheus-stack`, and `w9-api` exist.
- `w9-api` becomes `Synced/Healthy`.

## 3. SLO And Email Alert

Confirm the Git-managed resources exist:

```powershell
kubectl get prometheusrule w9-api-slo -n demo -o yaml
kubectl get alertmanagerconfig w9-api-email-alerts -n demo -o yaml
```

Confirm Prometheus query:

```powershell
kubectl port-forward svc/kube-prometheus-stack-prometheus -n observability 9090:9090
```

Open:

```text
http://localhost:9090
```

Run:

```promql
w9_api:slo_success_rate:2m
```

Expected:

- Healthy app returns a value near `1`.
- SLO threshold is `0.98`.

Prepare email:

1. Replace `to`, `from`, and `authUsername` in `apps/w9-api/base/alertmanagerconfig.yaml`.
2. Commit and push the change.
3. Create the SMTP password secret:

```powershell
kubectl create secret generic alertmanager-smtp-auth `
  -n demo `
  --from-literal=password="YOUR_SMTP_APP_PASSWORD"
```

Inject an error through Git:

```powershell
# Edit apps/w9-api/base/rollout.yaml
# Set image: w9-api:4
# Set APP_VERSION to v4
# Set FAIL_RATE to "1"
minikube image build -p w9 -t w9-api:4 app
git add cloud/w9/project-01-gitops-observability-canary/apps/w9-api/base/rollout.yaml
git commit -m "test bad canary alert"
git push origin main
kubectl annotate application w9-api -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

Generate traffic while canary is running:

```powershell
kubectl port-forward svc/w9-api -n demo 8080:80
```

In another terminal:

```powershell
1..1200 | ForEach-Object {
  try {
    Invoke-RestMethod http://localhost:8080/api/status | Out-Null
  } catch {
    Write-Host "expected 500 from bad canary"
  }
  Start-Sleep -Milliseconds 150
}
```

Check alert:

```powershell
kubectl port-forward svc/kube-prometheus-stack-alertmanager -n observability 9093:9093
```

Open:

```text
http://localhost:9093
```

Expected:

- Alert `W9ApiHighErrorRate` becomes `Firing`.
- Personal email receives the alert.

Capture:

- `docs/image/06-slo-rule-query.png`
- `docs/image/07-alert-firing.png`
- `docs/image/08-alert-email.png`

## 4. Bad Canary Auto-Abort

During the bad version test, watch rollout:

```powershell
kubectl get rollout w9-api -n demo -w
```

In another terminal:

```powershell
kubectl get analysisrun -n demo -w
```

Detailed view:

```powershell
kubectl describe rollout w9-api -n demo
kubectl describe analysisrun -n demo
```

Expected:

- New version `v4` starts as canary.
- `AnalysisRun` reads Prometheus.
- Success rate is below `0.98`.
- `AnalysisRun` becomes `Failed`.
- Rollout is aborted and stable pods for the previous good version stay available.

Verify app is still served by the old good version:

```powershell
Invoke-RestMethod http://localhost:8080/api/status
```

Expected after abort:

```text
version: v3
status: ok
```

Capture:

- `docs/image/09-canary-analysis-failed.png`
- `docs/image/10-canary-auto-aborted.png`

## 5. Git Revert Rollback Under 5 Minutes

Use this when the bad canary commit is the latest commit:

```powershell
$Start = Get-Date
git revert --no-edit HEAD
git push origin main
kubectl annotate application w9-api -n argocd argocd.argoproj.io/refresh=hard --overwrite

do {
  Start-Sleep -Seconds 10
  $Sync = kubectl get application w9-api -n argocd -o jsonpath='{.status.sync.status}'
  $Health = kubectl get application w9-api -n argocd -o jsonpath='{.status.health.status}'
  $Available = kubectl get rollout w9-api -n demo -o jsonpath='{.status.availableReplicas}'
  Write-Host "sync=$Sync health=$Health available=$Available"
} until ($Sync -eq "Synced" -and $Health -eq "Healthy" -and $Available -eq "2")

$Elapsed = [math]::Round(((Get-Date) - $Start).TotalSeconds, 2)
Write-Host "Rollback seconds: $Elapsed"
```

Expected:

```text
Rollback seconds: < 300
```

Capture:

- `docs/image/11-git-revert-rollback-time.png`
- `docs/image/12-final-healthy.png`

## Final Submission

Submit:

- GitHub repo link.
- `README.md`.
- `EVIDENCE.md`.
- Screenshots from `docs/image/`.
- Optional clip from `docs/video/`.

The strongest final proof is one screen recording showing:

```text
Git push bad version -> ArgoCD sync -> canary starts -> Prometheus metric fails -> AnalysisRun failed -> rollout aborted -> git revert -> healthy under 5 minutes
```
