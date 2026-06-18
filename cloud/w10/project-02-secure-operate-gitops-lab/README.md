# W10 Project 02 - Secure Operate GitOps Lab

Project này là bản W10 đúng phạm vi mentor: triển khai một mini Kubernetes platform trên local/fresh cluster, có GitOps, progressive delivery, observability, RBAC, admission policy, secrets management và supply-chain security.

Mục tiêu không phải dựng AWS EKS platform đầy đủ. Mục tiêu là chứng minh các control bảo mật Kubernetes theo lộ trình W10.

## Scope Chính

```text
GitOps + ArgoCD app-of-apps
Argo Rollouts + Prometheus canary analysis
PrometheusRule + Alertmanager email
RBAC 3 user: alice, bob, carol
Gatekeeper admission policy
External Secrets Operator + AWS Secrets Manager
Trivy scan + Cosign sign
Sigstore policy-controller reject unsigned image
```

AWS chỉ dùng cho Secrets Manager trong bài ESO. Terraform/EKS/IRSA là hướng production mở rộng, không phải flow nộp chính của project này.

## Cấu Trúc

```text
project-02-secure-operate-gitops-lab/
  src/api/                  # Flask API + Dockerfile
  app-common/               # Namespace demo
  app-api/                  # Rollout, Service, ServiceMonitor
  app-analysis/             # AnalysisTemplate cho canary
  app-alert/                # PrometheusRule + email secret example
  rbac/                     # Role/ClusterRole/Binding cho alice, bob, carol
  gatekeeper/
    templates/              # 4 ConstraintTemplate bắt buộc
    constraints/            # 4 Constraint enforce bắt buộc
    custom/                 # Optional custom Rego challenge
    tests/                  # Manifest pass/fail để demo admission
  k8s-eso/                  # SecretStore + ExternalSecret
  image-policy/             # Cosign public key + ClusterImagePolicy example
  argocd/
    root.yaml               # Root app-of-apps
    apps/                   # Child Applications
  .github/workflows/        # Workflow template cho validate/build/scan/sign
  docs/                     # Phân tích scope
  runbooks/                 # Demo command nhanh
  guides/                   # Hướng dẫn triển khai step-by-step
```

## Cấu Hình Repo, Image Và Email

Project đã được cấu hình theo thông tin nộp bài:

```text
https://github.com/G-03-XBrain-Phase-2/hoangson-aws-accelerator-p2.git
ghcr.io/g-03-xbrain-phase-2/w10-api
nguyenhoangson.13032004@gmail.com
```

Kiểm tra không còn placeholder trong manifest deploy:

```powershell
Get-ChildItem cloud/w10/project-02-secure-operate-gitops-lab -Recurse -File |
  Select-String -Pattern "YOUR_GITHUB|YOUR_EMAIL"
```

`REPLACE_WITH_COSIGN_PUBLIC_KEY` vẫn được giữ đến bước signature admission.

## Lộ Trình

1. Chuẩn bị tool, repo, placeholder.
2. Tạo fresh local cluster bằng minikube.
3. Cài ArgoCD và apply root app.
4. Sync base platform: Rollouts, Prometheus, API, alerts.
5. Demo RBAC bằng `kubectl auth can-i`.
6. Demo Gatekeeper reject manifest xấu.
7. Tạo AWS Secrets Manager secret và sync bằng ESO.
8. CI build, Trivy scan, push GHCR, Cosign sign.
9. Bật signature admission và chứng minh unsigned image bị reject.

Hướng dẫn chi tiết nằm trong:

```text
docs/ARCHITECTURE.md
guides/configuration-steps/
runbooks/DEMO-RUNBOOK.md
```

## Best Practice Boundary

Project 1 vẫn hữu ích cho hướng AWS/EKS/Terraform production. Project 2 là bản nộp chính nên giữ phạm vi vừa đủ:

```text
Local Kubernetes + GitOps + Security Controls + AWS Secrets Manager
```

Điểm mạnh của cách này là demo nhanh, dễ tái lập, bám đúng file mentor W10 và không biến bài security lab thành bài vận hành EKS quá rộng.
