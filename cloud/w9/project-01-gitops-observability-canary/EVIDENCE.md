# W9 Evidence Template

Save screenshots under `docs/image/`.

## Evidence Checklist By Phase

| No. | Evidence | Expected proof |
| --- | --- | --- |
| P0-01 | Cluster readiness | `kubectl get nodes` shows node `Ready` |
| P0-02 | ArgoCD installed | ArgoCD pods are running |
| P1-01 | Kustomize render | `kubectl kustomize` renders app successfully |
| P1-02 | Kubectl dry-run | `kubectl apply --dry-run=client -k ...` passes |
| P1-03 | Optional app smoke test | Pods, Service, and `/healthz` work |
| P2-01 | ArgoCD app list | Apps are `Synced` and `Healthy` |
| P2-02 | GitOps app health | `demo-web` is deployed by ArgoCD |
| P2-03 | Self-heal | Manual replica drift is restored from Git |
| P3-01 | GitHub Actions PR check | Manifest validation passes |
| P4-01 | Prometheus targets | App/collector targets are up |
| P4-02 | Grafana dashboard | Availability and latency panels exist |
| P4-03 | Burn rate alert rule | Prometheus alert rule exists |
| P5-01 | Argo Rollout canary | Rollout steps are visible |
| P5-02 | Canary analysis | AnalysisTemplate queries Prometheus |
| P5-03 | Abort evidence | Bad metric can abort rollout |

## Commands

```powershell
kubectl get nodes
kubectl get ns
kubectl kustomize apps/demo-web/overlays/dev
kubectl apply --dry-run=client -k apps/demo-web/overlays/dev
kubectl get pods -A
kubectl get applications -n argocd
kubectl get pods -n demo-web
kubectl get rollout -A
kubectl get analysistemplate -A
```

## Final Checklist

- [ ] ArgoCD owns app deployment.
- [ ] CI validates manifests.
- [ ] Observability stack is installed.
- [ ] SLO or burn rate rule exists.
- [ ] Canary rollout is configured.
- [ ] Evidence screenshots are saved.
