# W10 Project Implementation Roadmap - From Zero to Secure Platform

> Tài liệu này mô tả lộ trình triển khai W10 như một dự án thực tế bắt đầu từ con số 0. Repo source không tách theo phase học tập. Tất cả cấu hình dự án nằm trong `cloud/w10/project-01-secure-operate-platform`, còn folder `cloud/w10/guides` chỉ chứa tài liệu hướng dẫn.

---

## 1. Tư duy triển khai đúng

W10 không nên triển khai theo kiểu:

```text
folder bài học 1/
folder bài học 2/
folder bài học 3/
```

Vì đó là cách chia bài học, không phải cách tổ chức source code của một platform thật.

Cách đúng hơn:

```text
infra      tạo và quản lý tài nguyên AWS
platform   cài ArgoCD, Rollouts, Prometheus, ESO, Gatekeeper, policy controller
apps       source app + Kubernetes manifests
security   RBAC, admission policy, image verification, secret access
ci         pipeline build/scan/sign/update manifest
runbooks   vận hành, rollback, incident response
```

Trong dự án thực tế, lộ trình vẫn đi theo thứ tự, nhưng source code được nhóm theo trách nhiệm hệ thống.

---

## 2. Cấu trúc project chuẩn

```text
cloud/w10/
  guides/
    PROJECT-IMPLEMENTATION-ROADMAP.md
    implementation-steps/
      README.md
      STEP-01-TERRAFORM-FOUNDATION.md
      STEP-01B-CICD-TERRAFORM-APPLY.md
      STEP-02-EKS-CLUSTER.md

  project-01-secure-operate-platform/
    README.md

    infra/
      terraform/
        foundation/
          versions.tf
          variables.tf
          main.tf
          outputs.tf
          terraform.tfvars.example
      reference-policies/
        ecr/
        iam/

    platform/
      argocd/
      helm-values/

    apps/
      w10-api/
        app/
        manifests/

    security/
      rbac/
      gatekeeper/
      image-policy/
      external-secrets/

    ci/
      github-actions/

    runbooks/
```

Giải thích:

| Folder | Vai trò |
|---|---|
| `infra/terraform/foundation` | Tạo AWS foundation bằng Terraform: ECR, IAM OIDC role, về sau có EKS/VPC/backend |
| `infra/reference-policies` | Policy JSON mẫu để đọc/đối chiếu hoặc dùng khi lab CLI; source of truth vẫn là Terraform |
| `platform` | Add-ons chạy trong cluster và được ArgoCD quản lý |
| `apps` | Source app, Dockerfile, K8s manifests, rollout, service, ServiceMonitor |
| `security` | RBAC, Gatekeeper, image signature policy, ESO config |
| `ci` | GitHub Actions hoặc pipeline config |
| `runbooks` | Tài liệu vận hành, rollback, incident response |

---

## 3. Vì sao bắt đầu bằng AWS foundation

W9 dùng Minikube:

```text
minikube image build
-> image nằm local trong cluster
```

W10 dùng AWS/EKS:

```text
CI build image
-> scan image
-> push ECR
-> sign image
-> ArgoCD deploy image từ ECR vào EKS
```

Vì vậy từ số 0, cần chuẩn bị foundation trước:

```text
AWS account đúng
Terraform state/backends
ECR registry
IAM role cho CI
EKS cluster
kubeconfig
```

Nếu làm app trước mà chưa có ECR/IAM/EKS, pipeline sẽ không có nơi push image và không có identity an toàn để thao tác với AWS.

---

## 4. Nguyên tắc best practice

1. Terraform là source of truth cho AWS resources.
2. AWS CLI chỉ dùng để kiểm tra hoặc debug.
3. Không tạo tài nguyên production bằng tay trên console.
4. GitHub Actions dùng OIDC, không dùng AWS access key dài hạn.
5. Image phải nằm trong ECR hoặc registry chuẩn, không nằm trong Minikube cache.
6. Không dùng image tag `latest`.
7. Image phải scan trước, sign sau.
8. Secret thật nằm trong AWS Secrets Manager, không nằm trong Git.
9. Cluster enforce policy bằng admission controller.
10. Rollback đi qua Git, không sửa tay trong cluster.

---

## 5. Bước 0 - Chuẩn bị local workstation

Kiểm tra tool:

```powershell
aws --version
terraform version
kubectl version --client
helm version
docker version
git --version
```

Giải thích:

| Tool | Dùng để làm gì |
|---|---|
| `aws` | Kiểm tra account, ECR, EKS, IAM |
| `terraform` | Tạo AWS resources bằng IaC |
| `kubectl` | Kiểm tra cluster |
| `helm` | Bootstrap ArgoCD hoặc một số chart ban đầu |
| `docker` | Build/test image local nếu cần |
| `git` | Version control, rollback, GitOps |

Kiểm tra AWS identity:

```powershell
aws sts get-caller-identity
aws configure get region
```

Nếu chưa có region:

```powershell
aws configure set region ap-southeast-1
```

---

## 6. Bước 1 - Terraform foundation automation

Hướng dẫn chi tiết riêng cho bước này nằm ở:

```text
cloud/w10/guides/implementation-steps/STEP-01-TERRAFORM-FOUNDATION.md
cloud/w10/guides/implementation-steps/STEP-01B-CICD-TERRAFORM-APPLY.md
```

Đi tới Terraform foundation:

```powershell
Set-Location E:\Xbrain\tf_learning\cloud\w10\project-01-secure-operate-platform\infra\terraform\foundation
```

Tạo file biến thật từ file mẫu:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Sửa `terraform.tfvars`:

```text
aws_region
ecr_repository_name
github_org
github_repo
github_branch
create_github_oidc_provider
```

Các file Terraform đang cấu hình:

| File | Cấu hình gì |
|---|---|
| `versions.tf` | Terraform version và AWS provider |
| `variables.tf` | Input variables |
| `main.tf` | ECR repo, lifecycle policy, GitHub OIDC provider, IAM role cho CI |
| `outputs.tf` | ECR URL, AWS account ID, IAM role ARN |
| `terraform.tfvars.example` | File mẫu biến môi trường |

Chạy local để kiểm tra trước khi mở PR:

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

Đường triển khai chuẩn:

```text
branch -> Pull Request -> CI terraform plan -> review -> merge main -> CD terraform apply
```

`terraform apply` từ laptop chỉ dùng cho bootstrap/lab khi chưa có CI role.

Giải thích:

| Lệnh | Ý nghĩa |
|---|---|
| `terraform init` | Tải provider và chuẩn bị working directory |
| `terraform fmt` | Format code Terraform |
| `terraform validate` | Kiểm tra cú pháp và cấu trúc |
| `terraform plan` | Xem Terraform sẽ tạo/sửa/xóa gì |
| `terraform apply` | Chỉ chạy trong CD/protected environment, hoặc bootstrap/lab có kiểm soát |

Sau khi apply bằng CI/CD hoặc bootstrap xong, kiểm tra output:

```powershell
terraform output
Set-Location E:\Xbrain\tf_learning
```

---

## 7. Bước 2 - Kiểm tra AWS foundation

Kiểm tra ECR:

```powershell
$env:AWS_REGION = "ap-southeast-1"
$env:ECR_REPO = "w10-api"

aws ecr describe-repositories `
  --repository-names $env:ECR_REPO `
  --region $env:AWS_REGION
```

Kiểm tra lifecycle policy:

```powershell
aws ecr get-lifecycle-policy `
  --repository-name $env:ECR_REPO `
  --region $env:AWS_REGION
```

Kiểm tra IAM role:

```powershell
aws iam get-role --role-name github-actions-w10-ecr
aws iam get-role-policy `
  --role-name github-actions-w10-ecr `
  --policy-name github-actions-w10-ecr-push
```

Giải thích:

```text
Các lệnh AWS CLI ở đây không tạo tài nguyên.
Chúng chỉ xác nhận tài nguyên Terraform đã tạo đúng.
```

---

## 8. Bước 2 - EKS cluster

Hướng dẫn chi tiết riêng cho bước này nằm ở:

```text
cloud/w10/guides/implementation-steps/STEP-02-EKS-CLUSTER.md
```

Trong project thật, EKS cũng nên được quản lý bằng Terraform module, ví dụ:

```text
infra/terraform/eks/
```

Nếu cluster đã có từ bài trước hoặc lab đã dựng, chỉ cần xác nhận:

```powershell
$env:CLUSTER_NAME = "w10-secure-platform"
$env:AWS_REGION = "ap-southeast-1"

aws eks describe-cluster `
  --name $env:CLUSTER_NAME `
  --region $env:AWS_REGION `
  --query "cluster.{name:name,status:status,version:version}" `
  --output table
```

Cập nhật kubeconfig:

```powershell
aws eks update-kubeconfig `
  --name $env:CLUSTER_NAME `
  --region $env:AWS_REGION
```

Kiểm tra:

```powershell
kubectl config current-context
kubectl get nodes -o wide
```

Best practice:

```text
Không click tay tạo EKS trên console nếu mục tiêu là reproduce được.
Lab có thể dùng eksctl, nhưng project thật nên đưa EKS vào Terraform.
```

---

## 9. Bước 4 - Bootstrap GitOps platform

Khi EKS đã sẵn sàng, cài ArgoCD làm bootstrap exception:

```powershell
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd `
  -n argocd `
  --set server.service.type=ClusterIP
```

Giải thích:

```text
ArgoCD được cài trước vì nó sẽ quản lý các thành phần còn lại.
Sau khi ArgoCD chạy, hạn chế apply tay từng app.
```

Kiểm tra:

```powershell
kubectl get pods -n argocd
kubectl get svc -n argocd
```

Sau đó tạo app-of-apps trong `platform/argocd`.

---

## 10. Bước 5 - Cài platform add-ons bằng GitOps

Các add-ons nên nằm trong `platform`:

```text
platform/
  argocd/
    app-of-apps.yaml
    apps/
      argo-rollouts.yaml
      kube-prometheus-stack.yaml
      external-secrets.yaml
      gatekeeper.yaml
      sigstore-policy-controller.yaml
```

Thứ tự sync nên là:

```text
1. CRD/controllers: Argo Rollouts, Prometheus stack, ESO, Gatekeeper, Policy Controller
2. Security policies: RBAC, Gatekeeper constraints, image policy
3. Application manifests
```

Vì sao:

```text
App dùng Rollout thì CRD Rollout phải có trước.
App dùng ServiceMonitor/PrometheusRule thì Prometheus CRD phải có trước.
App dùng ExternalSecret thì ESO CRD/controller phải có trước.
Policy nên sẵn sàng trước khi app production chạy.
```

---

## 11. Bước 6 - CI/CD supply chain

CI nằm trong `ci/github-actions`.

Pipeline chuẩn:

```text
checkout
configure AWS credential bằng OIDC
login ECR
build image
Trivy scan HIGH/CRITICAL
push image lên ECR
Cosign sign image
update GitOps manifest bằng tag/digest
```

Không dùng:

```text
AWS_ACCESS_KEY_ID dài hạn trong GitHub Secrets
image latest
image build thẳng vào cluster
```

Nên dùng:

```text
GitHub OIDC role
ECR private repo
Git SHA hoặc digest
Trivy fail-on HIGH/CRITICAL
Cosign keyless signing nếu có thể
```

---

## 12. Bước 7 - App deployment

App nằm trong:

```text
apps/w10-api/
  app/
  manifests/
```

Manifest nên có:

```text
Rollout hoặc Deployment
Service
ServiceAccount
ServiceMonitor
PrometheusRule
AnalysisTemplate
ExternalSecret reference hoặc mounted Secret
```

Khi deploy:

```text
CI update image trong manifest
Git commit/PR merge
ArgoCD sync
Argo Rollouts canary
Prometheus analysis quyết định promote/abort
```

---

## 13. Bước 8 - Security enforcement

Security nằm trong:

```text
security/
  rbac/
  gatekeeper/
  image-policy/
  external-secrets/
```

Các guardrail tối thiểu:

```text
viewer/developer/sre RBAC
Gatekeeper: require requests/limits
Gatekeeper: disallow privileged
Gatekeeper: require runAsNonRoot
Gatekeeper: disallow latest
Sigstore policy: reject unsigned image
ESO: secret lấy từ AWS Secrets Manager
```

Kiểm tra:

```powershell
kubectl auth can-i get pods -n demo --as viewer
kubectl auth can-i delete namespace demo --as developer
kubectl get constraints
kubectl get clusterimagepolicy
kubectl get externalsecret -n demo
```

---

## 14. Bước 9 - Operate, rollback, incident response

Runbooks nằm trong:

```text
runbooks/
  rollback.md
  incident-response.md
  secret-rotation.md
  unsigned-image-rejected.md
```

Rollback chuẩn:

```powershell
git revert <bad_commit>
git push origin main
kubectl get application -n argocd
kubectl get rollout -n demo
```

Incident response 5 phút đầu:

```text
Detect
Triage
Contain
Eradicate
Recover
Post-mortem
```

---

## 15. Definition of Done

Dự án đạt chuẩn W10 khi đủ:

```text
1. AWS foundation do Terraform quản lý.
2. ECR repo tồn tại, scan on push, lifecycle policy.
3. GitHub Actions dùng OIDC role, không dùng static AWS key.
4. EKS cluster kết nối được bằng kubectl.
5. ArgoCD quản lý platform bằng app-of-apps.
6. App image đi qua CI -> ECR, không build vào Minikube.
7. Image được Trivy scan và Cosign sign.
8. Unsigned image bị reject bởi admission.
9. Secret thật nằm trong AWS Secrets Manager.
10. ESO sync secret về Kubernetes.
11. RBAC phân quyền viewer/developer/sre.
12. Gatekeeper enforce ít nhất 4 constraint.
13. Observability/SLO/canary hoạt động.
14. Bad canary tự abort.
15. Rollback bằng Git revert.
16. Có runbook vận hành.
```
