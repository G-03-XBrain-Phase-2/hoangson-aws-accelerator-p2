# Demo Test Runbook - W9 GitOps Observability Canary

File nay dung de demo/test toan bo he thong bang tay, tung lenh mot. Muc tieu la chung minh du 4 tieu chi:

1. Thay doi qua Git, ArgoCD `Synced/Healthy`, khong con drift, reproduce duoc tu Git.
2. `git revert` rollback duoi 5 phut.
3. SLO alert fire va gui mail ve email ca nhan khi inject loi.
4. Canary ban loi tu dong abort ve ban cu.

Runbook nay dung PowerShell tren Windows.

## 0. Nguyen Tac An Toan

- Khong commit SMTP password vao Git.
- Chi commit dia chi email neu ban chap nhan email xuat hien trong Git history.
- Neu repo public va khong muon lo email ca nhan, hay dung email demo/school email rieng cho bai nop.
- Tat ca thay doi workload phai di qua Git, khong `kubectl edit`, khong `kubectl set image`.
- Sau demo phai revert bad canary commit va xoa SMTP secret.

## 1. Chuan Bi Bien Moi Truong

Mo PowerShell tai root repo:

```powershell
Set-Location E:\Xbrain\tf_learning
```

Dat bien project:

```powershell
$Project = "cloud/w9/project-01-gitops-observability-canary"
$AppPath = "$Project/apps/w9-api/base/rollout.yaml"
$AlertPath = "$Project/apps/w9-api/base/alertmanagerconfig.yaml"
```

Kiem tra Git:

```powershell
git status --short
git log --oneline -5
```

Expected:

- Dang o branch `main`.
- Khong co thay doi dang stage.
- Neu co file local khac ngoai project, khong can dung vao trong demo.

Kiem tra context Kubernetes:

```powershell
kubectl config current-context
kubectl get nodes
```

Expected:

```text
w9
```

Neu chua dung context:

```powershell
kubectl config use-context w9
```

## 2. Baseline: Kiem Tra He Thong Dang Healthy

Kiem tra ArgoCD:

```powershell
kubectl get applications -n argocd
```

Expected:

```text
argo-rollouts           Synced   Healthy
kube-prometheus-stack   Synced   Healthy
w9-api                  Synced   Healthy
w9-app-of-apps          Synced   Healthy
```

Kiem tra workload:

```powershell
kubectl get rollout,pods,svc -n demo
kubectl get analysistemplate,servicemonitor,prometheusrule,alertmanagerconfig -n demo
```

Expected:

- `rollout/w9-api` co `2/2` available.
- Co `AnalysisTemplate`.
- Co `ServiceMonitor`.
- Co `PrometheusRule`.
- Co `AlertmanagerConfig`.

Chup evidence:

```text
docs/image/03-argocd-synced-healthy.png
docs/image/12-final-healthy.png
```

## 3. Kiem Tra App, Backend, Metrics

Terminal 1:

```powershell
kubectl port-forward svc/w9-api -n demo 8080:80
```

Terminal 2:

```powershell
Invoke-RestMethod http://localhost:8080/api/status
```

Expected:

```text
version: v3
status: ok
frontend: healthy
backend: healthy
```

Kiem tra metrics:

```powershell
Invoke-WebRequest http://localhost:8080/metrics | Select-Object -ExpandProperty Content | Select-String "flask_http_request_total"
```

Dung port-forward bang `Ctrl+C` sau khi test xong.

## 4. Kiem Tra GitOps No Drift / Self-Heal

Tao drift bang cach scale truc tiep tren cluster:

```powershell
kubectl scale rollout w9-api -n demo --replicas=1
kubectl get rollout w9-api -n demo
```

Ep ArgoCD hard refresh:

```powershell
kubectl annotate application w9-api -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

Watch self-heal:

```powershell
kubectl get rollout w9-api -n demo -w
```

Expected:

- Ban dau rollout bi scale xuong `1`.
- ArgoCD self-heal ve desired state trong Git la `2`.

Kiem tra lai ArgoCD:

```powershell
kubectl get application w9-api -n argocd
```

Chup evidence:

```text
docs/image/04-no-drift-self-heal.png
```

## 5. Cau Hinh Email Alert Qua Git

Mo file:

```powershell
notepad $AlertPath
```

Doi 3 dong placeholder:

```yaml
to: CHANGE_ME_PERSONAL_EMAIL@example.com
from: CHANGE_ME_SENDER_EMAIL@example.com
authUsername: CHANGE_ME_SENDER_EMAIL@example.com
```

Thanh email that, vi du:

```yaml
to: your-personal-email@gmail.com
from: your-sender-email@gmail.com
authUsername: your-sender-email@gmail.com
```

Luu y:

- `to` la email nhan alert.
- `from` va `authUsername` la email gui alert.
- Neu dung Gmail, can dung App Password, khong dung mat khau Gmail binh thuong.
- SMTP password khong nam trong file Git.

Commit va push email config:

```powershell
git add $AlertPath
git commit -m "configure w9 alert email"
git push origin main
```

Tao SMTP password secret tren cluster:

```powershell
kubectl create secret generic alertmanager-smtp-auth `
  -n demo `
  --from-literal=password="YOUR_SMTP_APP_PASSWORD"
```

Refresh ArgoCD:

```powershell
kubectl annotate application w9-api -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl get application w9-api -n argocd
```

Kiem tra AlertmanagerConfig da apply:

```powershell
kubectl get alertmanagerconfig w9-api-email-alerts -n demo -o yaml
```

Kiem tra Alertmanager dang doc config cross-namespace:

```powershell
kubectl get alertmanager kube-prometheus-stack-alertmanager -n observability -o yaml |
  Select-String -Pattern "alertmanagerConfigSelector|alertmanagerConfigNamespaceSelector" -Context 0,3
```

Expected:

```text
alertmanagerConfigNamespaceSelector: {}
alertmanagerConfigSelector: {}
```

## 6. Kiem Tra SLO Query

Port-forward Prometheus:

```powershell
kubectl port-forward svc/kube-prometheus-stack-prometheus -n observability 9090:9090
```

Mo browser:

```text
http://localhost:9090
```

Query:

```promql
w9_api:slo_success_rate:2m
```

Expected:

- Khi app healthy, gia tri gan `1`.
- Threshold canh bao la `< 0.98`.

Chup evidence:

```text
docs/image/06-slo-rule-query.png
```

Dung port-forward bang `Ctrl+C` neu khong dung nua.

## 7. Tao Bad Canary Qua Git

Build image v4 vao minikube:

```powershell
Set-Location E:\Xbrain\tf_learning\$Project
minikube image build -p w9 -t w9-api:4 app
Set-Location E:\Xbrain\tf_learning
```

Mo rollout:

```powershell
notepad $AppPath
```

Doi 3 gia tri:

```yaml
image: w9-api:3
```

Thanh:

```yaml
image: w9-api:4
```

Doi:

```yaml
- name: APP_VERSION
  value: v3
```

Thanh:

```yaml
- name: APP_VERSION
  value: v4
```

Doi:

```yaml
- name: FAIL_RATE
  value: "0"
```

Thanh:

```yaml
- name: FAIL_RATE
  value: "1"
```

Validate manifest truoc khi commit:

```powershell
kubectl kustomize $Project/apps/w9-api/overlays/dev |
  Select-String -Pattern "image: w9-api:4|value: v4|value: `"1`"|kind: Rollout|kind: AnalysisTemplate"
```

Commit va push bad canary:

```powershell
git add $AppPath
git commit -m "test bad w9 canary"
git push origin main
```

Chup evidence:

```text
docs/image/01-git-commit.png
```

Refresh ArgoCD:

```powershell
kubectl annotate application w9-api -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl get application w9-api -n argocd
```

## 8. Tao Traffic De Canary Va Alert Co Metric

Terminal 1: watch rollout.

```powershell
kubectl get rollout w9-api -n demo -w
```

Terminal 2: watch AnalysisRun.

```powershell
kubectl get analysisrun -n demo -w
```

Terminal 3: port-forward app.

```powershell
kubectl port-forward svc/w9-api -n demo 8080:80
```

Terminal 4: generate traffic lien tuc.

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

Expected:

- Co request tra 500 khi hit vao canary pod v4.
- `AnalysisRun` fail vi success rate < 0.98.
- Rollout bad canary bi abort.

Kiem tra chi tiet:

```powershell
kubectl describe rollout w9-api -n demo
kubectl describe analysisrun -n demo
```

Chup evidence:

```text
docs/image/09-canary-analysis-failed.png
docs/image/10-canary-auto-aborted.png
```

## 9. Kiem Tra Alert Fire Va Email Da Gui

Port-forward Alertmanager:

```powershell
kubectl port-forward svc/kube-prometheus-stack-alertmanager -n observability 9093:9093
```

Mo browser:

```text
http://localhost:9093
```

Expected:

- Alert `W9ApiHighErrorRate` o trang Alertmanager.
- Status la `Firing`.

Neu muon check bang Prometheus API, port-forward Prometheus:

```powershell
kubectl port-forward svc/kube-prometheus-stack-prometheus -n observability 9090:9090
```

Query alert bang PowerShell:

```powershell
Invoke-RestMethod "http://localhost:9090/api/v1/query?query=ALERTS%7Balertname%3D%22W9ApiHighErrorRate%22%7D" |
  ConvertTo-Json -Depth 10
```

Expected:

- Co series `alertstate: firing`.

Kiem tra hop thu email ca nhan.

Chup evidence:

```text
docs/image/07-alert-firing.png
docs/image/08-alert-email.png
```

## 10. Rollback Bang Git Revert Duoi 5 Phut

Quan trong: lenh nay gia dinh bad canary commit la commit moi nhat.

Chay timer rollback:

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

Kiem tra app ve ban tot:

```powershell
Invoke-RestMethod http://localhost:8080/api/status
```

Expected:

```text
version: v3
status: ok
```

Chup evidence:

```text
docs/image/11-git-revert-rollback-time.png
docs/image/12-final-healthy.png
```

## 11. Clear Sau Demo - Bat Buoc

### 11.1. Tat port-forward/watch

Trong cac terminal dang watch hoac port-forward, nhan:

```text
Ctrl+C
```

### 11.2. Xoa SMTP secret khoi cluster

```powershell
kubectl delete secret alertmanager-smtp-auth -n demo --ignore-not-found
```

### 11.3. Reset email placeholder trong Git

Mo file:

```powershell
notepad $AlertPath
```

Doi lai:

```yaml
to: CHANGE_ME_PERSONAL_EMAIL@example.com
from: CHANGE_ME_SENDER_EMAIL@example.com
authUsername: CHANGE_ME_SENDER_EMAIL@example.com
```

Commit va push:

```powershell
git add $AlertPath
git commit -m "reset w9 demo email placeholders"
git push origin main
kubectl annotate application w9-api -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

### 11.4. Kiem tra rollout da ve stable

```powershell
kubectl get applications -n argocd
kubectl get rollout,pods -n demo
kubectl get alertmanagerconfig w9-api-email-alerts -n demo -o yaml
```

Expected:

- `w9-api` `Synced/Healthy`.
- Rollout `2/2`.
- `FAIL_RATE` trong Git la `"0"`.
- Email config da ve placeholder neu ban da reset.

Kiem tra Git:

```powershell
git status --short
git log --oneline -5
```

Expected:

- Khong co file demo dang modified/staged.
- Commit history co bad canary commit va revert commit.

## 12. Optional Full Cleanup Neu Khong Can Giu Lab

Chi chay neu muon xoa toan bo lab local:

```powershell
Set-Location E:\Xbrain\tf_learning\$Project
kubectl delete -f argocd/app-of-apps.yaml --ignore-not-found
helm uninstall argocd -n argocd
kubectl delete namespace argocd observability demo --ignore-not-found
minikube delete -p w9
Set-Location E:\Xbrain\tf_learning
```

Sau lenh nay, cluster/profile `w9` se bi xoa. Muon demo lai thi lam lai tu README/phase setup.

## 13. Bang Evidence Cuoi Cung

| Evidence | File nen chup |
| --- | --- |
| Git commit bad canary | `docs/image/01-git-commit.png` |
| GitHub Actions pass | `docs/image/02-actions-pass.png` |
| ArgoCD Synced/Healthy | `docs/image/03-argocd-synced-healthy.png` |
| No drift self-heal | `docs/image/04-no-drift-self-heal.png` |
| Reproduce from Git | `docs/image/05-reproduce-from-git.png` |
| SLO query | `docs/image/06-slo-rule-query.png` |
| Alert firing | `docs/image/07-alert-firing.png` |
| Email received | `docs/image/08-alert-email.png` |
| Analysis failed | `docs/image/09-canary-analysis-failed.png` |
| Canary auto-aborted | `docs/image/10-canary-auto-aborted.png` |
| Git revert under 5 minutes | `docs/image/11-git-revert-rollback-time.png` |
| Final healthy state | `docs/image/12-final-healthy.png` |

Clip tot nhat:

```text
docs/video/01-canary-auto-abort-and-rollback.mp4
```

Noi dung clip:

```text
Git push bad version -> ArgoCD sync -> canary starts -> Prometheus metric fails -> AnalysisRun failed -> rollout aborted -> git revert -> healthy under 5 minutes
```
