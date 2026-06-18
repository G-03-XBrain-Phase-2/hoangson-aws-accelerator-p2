# W10 Project 02 - Kiến Trúc Hệ Thống

Tài liệu này giải thích toàn bộ kiến trúc của `project-02-secure-operate-gitops-lab` theo cách dễ hiểu: hệ thống có những phần nào, các phần nói chuyện với nhau ra sao, vì sao cần từng file, và mỗi phần đáp ứng yêu cầu nào của mentor.

Project này mô phỏng một nền tảng Kubernetes nhỏ nhưng đủ các năng lực cốt lõi:

```text
GitOps
Progressive delivery
Observability
RBAC
Admission policy
Secret management
Supply chain security
Image signature enforcement
```

## 1. Mục Tiêu Tổng Quát

Project 2 không nhằm dựng một hệ thống AWS/EKS production lớn. Mục tiêu chính là chứng minh các năng lực bảo mật và vận hành Kubernetes theo đúng phạm vi W10.

Hệ thống cần trả lời được:

```text
1. Ai được quyền làm gì trong cluster?
2. Manifest xấu có bị chặn trước khi vào cluster không?
3. Secret có được lấy từ external secret store thay vì commit vào Git không?
4. Image có được scan và ký trước khi deploy không?
5. Cluster có từ chối image chưa ký không?
6. Mọi thay đổi có đi qua Git và ArgoCD không?
```

## 2. Phạm Vi Theo Mentor

### Buổi Sáng - RBAC + Admission Policy

Yêu cầu:

```text
RBAC:
  alice = developer, chỉ thao tác workload trong namespace demo
  bob   = SRE, xem/thao tác pod toàn cluster
  carol = viewer, chỉ đọc toàn cluster

Gatekeeper:
  Cấm image tag latest
  Bắt buộc resources.limits
  Cấm runAsUser: 0
  Cấm hostNetwork: true
```

Project đáp ứng bằng:

```text
rbac/roles.yaml
rbac/rolebindings.yaml
gatekeeper/templates/*.yaml
gatekeeper/constraints/*.yaml
gatekeeper/tests/*.yaml
argocd/apps/rbac.yaml
argocd/apps/k8s-gatekeeper.yaml
argocd/apps/gatekeeper-templates.yaml
argocd/apps/gatekeeper-constraints.yaml
```

### Buổi Chiều - Secrets + Supply Chain

Yêu cầu:

```text
Secrets:
  AWS Secrets Manager là nơi lưu secret gốc
  External Secrets Operator sync secret về Kubernetes
  Rotate secret và chứng minh Kubernetes Secret cập nhật

Supply chain:
  CI build image
  Trivy scan image
  Cosign sign image
  Admission reject unsigned image
```

Project đáp ứng bằng:

```text
k8s-eso/secret-store.yaml
k8s-eso/external-secret.yaml
argocd/apps/k8s-external-secrets.yaml
argocd/apps/eso.yaml
.github/workflows/build-scan-sign.yml
image-policy/cluster-image-policy.yaml.example
argocd/apps/k8s-policy-controller.yaml
argocd/apps/image-policy.yaml.example
```

## 3. Bức Tranh Toàn Hệ Thống

Luồng tổng quan:

```text
Developer
  |
  | git commit / git push
  v
GitHub Repository
  |
  | ArgoCD watches main branch
  v
ArgoCD in Kubernetes
  |
  | sync Applications
  v
Kubernetes Cluster
  |
  | runs platform controllers and demo app
  v
RBAC + Gatekeeper + ESO + Prometheus + Rollouts + Policy Controller
```

Hệ thống có 5 lớp chính:

```text
1. Source layer:
   GitHub repo chứa toàn bộ manifest và source code.

2. GitOps layer:
   ArgoCD đọc repo và sync tài nguyên vào cluster.

3. Platform layer:
   Argo Rollouts, Prometheus, Gatekeeper, ESO, Sigstore policy-controller.

4. Application layer:
   Flask API chạy bằng Argo Rollout trong namespace demo.

5. Security layer:
   RBAC, admission policy, secret sync, image scan/sign, signature admission.
```

## 4. Vì Sao Dùng Local Cluster Thay Vì EKS?

Phạm vi W10 là chứng minh Kubernetes security controls, không phải provisioning AWS platform.

Local cluster giúp:

```text
Demo nhanh hơn
Tái lập dễ hơn
Tập trung vào RBAC, Gatekeeper, ESO, Trivy, Cosign
Giảm rủi ro mất thời gian vào VPC, NAT Gateway, EKS node group, IAM
```

AWS vẫn xuất hiện ở đúng chỗ:

```text
AWS Secrets Manager
```

Nghĩa là AWS được dùng như external secret backend, không dùng để dựng toàn bộ cluster.

## 5. Cấu Trúc Thư Mục

```text
project-02-secure-operate-gitops-lab/
  src/api/
    app.py
    Dockerfile

  app-common/
    demo-namespace.yaml

  app-api/
    rollout.yaml
    service.yaml
    servicemonitor.yaml

  app-analysis/
    analysis-template.yaml

  app-alert/
    prometheus-rules.yaml
    email-secret.yaml.example

  rbac/
    roles.yaml
    rolebindings.yaml

  gatekeeper/
    templates/
    constraints/
    tests/
    custom/

  k8s-eso/
    secret-store.yaml
    external-secret.yaml

  image-policy/
    cluster-image-policy.yaml.example
    cosign.pub.example

  argocd/
    root.yaml
    apps/

  .github/workflows/
    build-scan-sign.yml
    validate.yml

  guides/configuration-steps/
  runbooks/
  docs/
```

## 6. Lớp GitOps

### 6.1. `argocd/root.yaml`

`root.yaml` là điểm bắt đầu của GitOps.

Nó nói với ArgoCD:

```text
Repo nào cần đọc?
Branch nào cần theo dõi?
Folder nào chứa child Applications?
Child Applications sẽ được tạo ở namespace nào?
```

Cấu hình chính:

```text
repoURL:
  https://github.com/G-03-XBrain-Phase-2/hoangson-aws-accelerator-p2.git

path:
  cloud/w10/project-02-secure-operate-gitops-lab/argocd/apps

targetRevision:
  main
```

Ý nghĩa quan trọng:

```text
ArgoCD không đọc file local.
ArgoCD chỉ đọc file đã có trên GitHub branch main.
```

### 6.2. `argocd/apps/*.yaml`

Mỗi file trong `argocd/apps` là một ArgoCD `Application`.

Các application chia thành nhóm:

```text
Platform controllers:
  k8s-rollout.yaml
  k8s-prometheus.yaml
  k8s-gatekeeper.yaml
  k8s-external-secrets.yaml
  k8s-policy-controller.yaml

App resources:
  app-common.yaml
  app-api.yaml
  app-analysis.yaml
  app-alert.yaml

Security resources:
  rbac.yaml
  gatekeeper-templates.yaml
  gatekeeper-constraints.yaml
  eso.yaml

Disabled until Step 08:
  image-policy.yaml.example
```

Vì sao tách thành nhiều Application?

```text
Dễ đọc
Dễ debug
Dễ sync từng nhóm
Dễ chứng minh với mentor từng phần của project
Controller có thể cài trước custom resources
```

## 7. Lớp Platform

### 7.1. Argo Rollouts

File GitOps:

```text
argocd/apps/k8s-rollout.yaml
```

Vai trò:

```text
Cài Argo Rollouts controller và CRDs.
Cho phép dùng kind Rollout thay vì Deployment thường.
Hỗ trợ canary rollout và analysis.
```

Liên quan app:

```text
app-api/rollout.yaml
app-analysis/analysis-template.yaml
```

### 7.2. Prometheus Stack

File GitOps:

```text
argocd/apps/k8s-prometheus.yaml
```

Vai trò:

```text
Cài Prometheus, Alertmanager, Grafana.
Cài CRDs ServiceMonitor và PrometheusRule.
```

Project dùng Prometheus để:

```text
Scrape /metrics của API
Tính success rate
Làm metric cho canary analysis
Tạo alert SLOViolation
Gửi email qua Alertmanager
```

### 7.3. Gatekeeper

File GitOps:

```text
argocd/apps/k8s-gatekeeper.yaml
```

Vai trò:

```text
Cài OPA Gatekeeper controller.
Tạo admission webhook.
Cho phép viết policy-as-code bằng ConstraintTemplate và Constraint.
```

### 7.4. External Secrets Operator

File GitOps:

```text
argocd/apps/k8s-external-secrets.yaml
```

Vai trò:

```text
Cài ESO controller.
Cho phép Kubernetes đọc secret từ AWS Secrets Manager.
```

### 7.5. Sigstore Policy Controller

File GitOps:

```text
argocd/apps/k8s-policy-controller.yaml
```

Vai trò:

```text
Cài admission controller kiểm tra chữ ký image.
Kết hợp với ClusterImagePolicy ở Step 08.
```

## 8. Lớp Application

### 8.1. Source Code API

File:

```text
src/api/app.py
src/api/Dockerfile
```

App là Flask API đơn giản có:

```text
/        endpoint chính, trả version hoặc lỗi giả lập
/healthz health check
/metrics metric Prometheus tự động từ prometheus-flask-exporter
```

Biến môi trường:

```text
VERSION    hiển thị version app
ERROR_RATE tạo lỗi có kiểm soát khi demo canary/SLO
```

### 8.2. Namespace Demo

File:

```text
app-common/demo-namespace.yaml
```

Vai trò:

```text
Tạo namespace demo.
Đây là nơi chạy app API, RBAC target và ESO target secret.
```

### 8.3. API Rollout

File:

```text
app-api/rollout.yaml
```

Vai trò:

```text
Deploy API bằng Argo Rollout.
Định nghĩa replicas, probes, resources, env và canary steps.
```

Image hiện tại:

```text
ghcr.io/g-03-xbrain-phase-2/w10-api:0.0.1
```

Sau Step 07, workflow CI sẽ cập nhật image tag mới vào file này.

### 8.4. API Service

File:

```text
app-api/service.yaml
```

Vai trò:

```text
Tạo Kubernetes Service tên api.
Cho phép Prometheus và user gọi vào API.
```

### 8.5. ServiceMonitor

File:

```text
app-api/servicemonitor.yaml
```

Vai trò:

```text
Nói với Prometheus cách scrape /metrics của API.
```

### 8.6. AnalysisTemplate

File:

```text
app-analysis/analysis-template.yaml
```

Vai trò:

```text
Định nghĩa metric success-rate cho Argo Rollouts.
Khi canary chạy, Rollouts hỏi Prometheus xem success rate có đạt không.
```

### 8.7. PrometheusRule

File:

```text
app-alert/prometheus-rules.yaml
```

Vai trò:

```text
Tạo SLO rule.
Nếu success rate thấp hơn ngưỡng, alert SLOViolation fire.
```

Email password không commit. File mẫu nằm ở:

```text
app-alert/email-secret.yaml.example
```

File thật `email-secret.yaml` phải tạo runtime và được `.gitignore` chặn.

## 9. Lớp RBAC

File:

```text
rbac/roles.yaml
rbac/rolebindings.yaml
argocd/apps/rbac.yaml
```

Thiết kế quyền:

```text
alice:
  Role trong namespace demo
  Được tạo/sửa workload trong demo
  Không có quyền tạo workload ở kube-system

bob:
  ClusterRole
  Được xem/thao tác pod toàn cluster
  Phù hợp vai trò SRE

carol:
  ClusterRole viewer
  Chỉ get/list/watch toàn cluster
  Không được delete node
```

Nghiệm thu mentor:

```text
kubectl auth can-i create deploy -n demo --as alice        -> yes
kubectl auth can-i create deploy -n kube-system --as alice -> no
kubectl auth can-i get pods -A --as bob                    -> yes
kubectl auth can-i delete nodes --as carol                 -> no
```

Ý nghĩa:

```text
RBAC kiểm tra "ai được làm gì".
RBAC không kiểm tra manifest có an toàn hay không.
Phần đó do Gatekeeper xử lý.
```

## 10. Lớp Admission Policy Với Gatekeeper

Gatekeeper có hai loại file chính:

```text
ConstraintTemplate:
  định nghĩa logic policy bằng Rego

Constraint:
  bật policy đó vào cluster
```

Project có 4 policy bắt buộc:

```text
1. disallow-latest-tag
   Chặn image dùng tag latest.

2. required-resources
   Bắt buộc container có resources.limits.

3. disallow-root-user
   Chặn container chạy runAsUser: 0.

4. disallow-host-network
   Chặn Pod dùng hostNetwork: true.
```

File:

```text
gatekeeper/templates/*.yaml
gatekeeper/constraints/*.yaml
gatekeeper/tests/*.yaml
```

Test manifests:

```text
invalid-latest-pod.yaml        phải bị reject
invalid-no-limits-pod.yaml     phải bị reject
invalid-root-pod.yaml          phải bị reject
invalid-host-network-pod.yaml  phải bị reject
valid-pod.yaml                 phải pass
```

Ý nghĩa:

```text
RBAC có thể cho alice quyền tạo Pod.
Nhưng nếu Pod thiếu limits hoặc dùng latest, Gatekeeper vẫn reject.
```

## 11. Lớp Secrets Với ESO Và AWS Secrets Manager

Mục tiêu:

```text
Không commit secret thật vào Git.
Secret thật nằm trong AWS Secrets Manager.
Kubernetes chỉ nhận bản sync qua External Secrets Operator.
```

File:

```text
k8s-eso/secret-store.yaml
k8s-eso/external-secret.yaml
argocd/apps/k8s-external-secrets.yaml
argocd/apps/eso.yaml
```

Luồng hoạt động:

```text
AWS Secrets Manager
  secret: prod/db/password
        |
        | ESO đọc bằng AWS credential runtime
        v
External Secrets Operator
        |
        | tạo/cập nhật Kubernetes Secret
        v
Kubernetes Secret
  namespace: demo
  name: db-secret
```

Vì đây là local lab, AWS credential được tạo runtime bằng `kubectl create secret`, không commit vào Git.

Trong production EKS, best practice tốt hơn là dùng IRSA. Nhưng trong project này, static runtime secret phù hợp với scope mentor và dễ demo trên local cluster.

## 12. Lớp Supply Chain

File:

```text
.github/workflows/build-scan-sign.yml
.github/workflows/validate.yml
src/api/Dockerfile
app-api/rollout.yaml
image-policy/cosign.pub.example
```

Luồng CI:

```text
Developer thay đổi src/api
        |
        v
GitHub Actions
        |
        | docker build
        v
Container image
        |
        | Trivy scan HIGH/CRITICAL
        v
GHCR push
        |
        | Cosign sign
        v
Signed image
        |
        | workflow commit image tag mới
        v
app-api/rollout.yaml
        |
        | ArgoCD sync
        v
Kubernetes rollout
```

Secret CI cần tạo trên GitHub Web UI:

```text
COSIGN_PRIVATE_KEY
COSIGN_PASSWORD
```

Không dùng GitHub CLI trong project này.

## 13. Lớp Signature Admission

File ban đầu:

```text
image-policy/cluster-image-policy.yaml.example
argocd/apps/image-policy.yaml.example
```

Vì sao để `.example`?

```text
Nếu bật policy quá sớm, cluster sẽ reject image chưa ký.
Best practice là build -> scan -> sign trước, rồi mới bật admission policy.
```

Ở Step 08 mới tạo file thật:

```text
image-policy/cosign.pub
image-policy/cluster-image-policy.yaml
argocd/apps/image-policy.yaml
```

Luồng kiểm tra:

```text
User tạo Pod dùng unsigned image
        |
        v
Sigstore policy-controller kiểm tra chữ ký
        |
        v
Không có chữ ký hợp lệ -> reject

ArgoCD deploy signed image từ GHCR
        |
        v
Có chữ ký hợp lệ -> allow
```

## 14. Namespace Runtime

Khi hệ thống chạy, các namespace chính là:

```text
argocd:
  ArgoCD server, repo-server, application-controller

demo:
  API Rollout, Service, ServiceMonitor, db-secret, RBAC target namespace

argo-rollouts:
  Argo Rollouts controller

monitoring:
  Prometheus, Alertmanager, Grafana, PrometheusRule

gatekeeper-system:
  Gatekeeper controller

external-secrets:
  External Secrets Operator

cosign-system:
  Sigstore policy-controller
```

## 15. Các Luồng Chính Cần Hiểu

### 15.1. Luồng GitOps

```text
Sửa manifest
  -> commit
  -> push/merge main
  -> ArgoCD phát hiện thay đổi
  -> ArgoCD sync vào cluster
  -> kubectl/ArgoCD UI kiểm tra kết quả
```

### 15.2. Luồng Request Và Metrics

```text
User gọi API Service
  -> Pod Flask xử lý request
  -> prometheus-flask-exporter tạo metrics
  -> Prometheus scrape /metrics qua ServiceMonitor
  -> AnalysisTemplate dùng metric success-rate
  -> PrometheusRule tạo alert nếu SLO thấp
```

### 15.3. Luồng RBAC + Admission

```text
User gửi request tạo workload
  -> Kubernetes authentication
  -> RBAC authorization: user có quyền không?
  -> Gatekeeper admission: manifest có hợp lệ không?
  -> Nếu pass cả hai, tài nguyên mới được lưu vào cluster
```

### 15.4. Luồng Secrets

```text
AWS Secrets Manager lưu secret thật
  -> ESO đọc secret
  -> ESO tạo Kubernetes Secret db-secret
  -> Rotate secret trên AWS
  -> ESO sync giá trị mới về Kubernetes
```

### 15.5. Luồng Image Security

```text
Code thay đổi
  -> CI build image
  -> Trivy scan
  -> Push GHCR
  -> Cosign sign
  -> Update rollout image tag
  -> ArgoCD deploy
  -> Policy-controller chỉ cho image đã ký chạy
```

## 16. Vì Sao Kiến Trúc Này Là Best Practice Cho W10?

Kiến trúc này tốt cho phạm vi W10 vì:

```text
1. Bám đúng yêu cầu mentor, không over-engineer sang EKS/Terraform.
2. Mọi manifest quan trọng đi qua GitOps.
3. Có ranh giới rõ giữa bootstrap exception và GitOps-managed resources.
4. Tách platform controller khỏi app config.
5. Tách Gatekeeper template khỏi constraint.
6. Không bật signature admission trước khi image được ký.
7. Không commit secret thật.
8. Mỗi phần có file test/evidence rõ ràng.
```

## 17. Mentor Cần Nhìn Thấy Gì?

Khi đọc evidence, mentor cần thấy:

```text
GitOps:
  root app và child apps đọc từ GitHub main

RBAC:
  4 lệnh can-i đúng kết quả

Gatekeeper:
  4 manifest xấu bị reject
  1 manifest hợp lệ pass

ESO:
  AWS secret tồn tại
  ExternalSecret Ready
  Kubernetes Secret được tạo
  Rotation cập nhật xuống cluster

Supply chain:
  GitHub Actions build/scan/sign pass
  GHCR có image
  Cosign verify thành công

Signature admission:
  unsigned image bị reject
  signed image được deploy
```

## 18. Tóm Tắt Một Câu

Project 2 là một mini Kubernetes platform chạy local, dùng GitHub làm source of truth, ArgoCD làm GitOps engine, Prometheus/Rollouts làm observability và progressive delivery, Gatekeeper/RBAC/ESO/Cosign/Sigstore làm các lớp bảo mật để chứng minh đầy đủ yêu cầu W10.
