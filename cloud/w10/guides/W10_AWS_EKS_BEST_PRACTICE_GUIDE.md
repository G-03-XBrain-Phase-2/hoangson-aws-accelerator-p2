# W10 AWS/EKS Best Practice Deployment Guide

> Mục tiêu: triển khai lại bài W10 theo hướng production-like trên AWS/EKS, thay cho cách W9 build image trực tiếp vào Minikube. Tài liệu này ưu tiên cách làm đúng trong dự án thực tế: GitOps làm source of truth, image đi qua registry, CI scan/sign, cluster enforce policy, secret lấy từ AWS Secrets Manager, và toàn bộ platform có thể dựng lại từ repo.

---

## 1. Bức tranh tổng thể

W9 không sai, nhưng W9 là lab local:

```text
Code
-> minikube image build
-> image nằm trong Minikube cache
-> ArgoCD sync manifest
-> Argo Rollouts canary
-> Prometheus analysis
```

W10 phải nâng mô hình đó lên AWS/EKS:

```text
Code push
-> GitHub Actions
-> build image
-> Trivy scan
-> push image lên ECR
-> Cosign sign image
-> update GitOps manifest bằng image tag/digest
-> ArgoCD trên EKS sync
-> admission policy verify image signature
-> Argo Rollouts canary
-> Prometheus/Grafana/Alertmanager observe
-> ESO sync secret từ AWS Secrets Manager
```

Điểm thay đổi quan trọng nhất:

| Phần | W9 local | W10 AWS/EKS chuẩn hơn |
|---|---|---|
| Image | `w9-api:1` nằm trong Minikube | ECR image dùng Git SHA hoặc digest |
| Secret | K8s Secret/placeholder | AWS Secrets Manager + ESO |
| AWS credential | Không cần hoặc dùng local | GitHub OIDC, IRSA/EKS Pod Identity |
| Image security | Chưa scan/sign | Trivy + Cosign |
| Admission | Chủ yếu rollout/analysis | Gatekeeper + signature policy |
| Drift control | ArgoCD | ArgoCD + policy enforce |
| Rollback | `git revert` | `git revert` + rollback image digest |

---

## 2. Nguyên tắc bắt buộc

1. Git là source of truth.
2. Không `kubectl edit` workload trong cluster.
3. Không commit secret thật vào Git.
4. Không dùng image local trong EKS.
5. Không dùng image `latest`.
6. Image phải được scan trước khi sign.
7. Image fail HIGH/CRITICAL không được deploy, trừ khi có exception ADR có thời hạn.
8. Manifest phải có `requests`, `limits`, `runAsNonRoot`, `readOnlyRootFilesystem` nếu app hỗ trợ.
9. Admission policy chạy audit trước, enforce sau.
10. Rollback phải đi qua Git, không rollback bằng thao tác tay trên cluster.

---

## 3. Repo layout khuyến nghị

Trong repo cá nhân, W10 nên tách rõ platform, app, policy và runbook:

```text
cloud/w10/
  README.md
  W10_AWS_EKS_BEST_PRACTICE_GUIDE.md

  platform/
    argocd/
      app-of-apps.yaml
      apps/
        argo-rollouts.yaml
        kube-prometheus-stack.yaml
        external-secrets.yaml
        gatekeeper.yaml
        sigstore-policy-controller.yaml
        w10-api.yaml
        platform-policies.yaml
    namespaces/
      demo.yaml
      observability.yaml
      security.yaml

  apps/
    w10-api/
      app/
        app.py
        requirements.txt
        Dockerfile
      base/
        deployment-or-rollout.yaml
        service.yaml
        serviceaccount.yaml
        servicemonitor.yaml
        prometheusrule.yaml
        externalsecret.yaml
      overlays/
        dev/
          kustomization.yaml
        prod/
          kustomization.yaml

  security/
    rbac/
      developer-role.yaml
      sre-role.yaml
      viewer-role.yaml
      rolebindings.yaml
    gatekeeper/
      templates/
      constraints/
    image-policy/
      cluster-image-policy.yaml
    secrets/
      secretstore.yaml

  ci/
    github-actions/
      build-scan-sign.yml
      validate-manifests.yml

  runbooks/
    incident-response.md
    secret-rotation.md
    rollback.md
    unsigned-image-rejected.md

  docs/
    evidence/
    images/
```

Nếu làm nhanh cho lab, có thể gộp bớt. Nhưng khi giải thích với mentor, nên nói rõ: layout này tách ownership theo đúng thực tế.

---

## 4. Target architecture

```text
Developer
  |
  | git push
  v
GitHub Actions
  |-- assume AWS role bằng GitHub OIDC
  |-- docker build
  |-- Trivy scan HIGH/CRITICAL
  |-- docker push ECR
  |-- Cosign sign image
  |-- update manifest image digest/tag
  v
Git repository
  |
  | ArgoCD sync
  v
EKS Cluster
  |-- Argo Rollouts canary
  |-- Prometheus SLO analysis
  |-- Gatekeeper policy enforcement
  |-- Sigstore policy-controller verify signature
  |-- ESO sync secret từ AWS Secrets Manager
  |-- Alertmanager gửi alert
```

---

## 5. Phase 0 - Chuẩn bị AWS và công cụ

### 5.1 Biến môi trường

PowerShell:

```powershell
$env:AWS_REGION = "ap-southeast-1"
$env:AWS_ACCOUNT_ID = "419022576090"
$env:CLUSTER_NAME = "w10-secure-platform"
$env:ECR_REPO = "w10-api"
$env:APP_NAMESPACE = "demo"
$env:SECURITY_NAMESPACE = "security"
$env:OBS_NAMESPACE = "observability"
```

Kiểm tra identity:

```powershell
aws sts get-caller-identity
aws configure get region
```

### 5.2 Tool cần có

```powershell
aws --version
kubectl version --client
helm version
docker version
cosign version
trivy --version
git --version
```

Nếu thiếu tool, cài trước rồi mới làm. Không nên vừa debug tool vừa debug cluster.

---

## 6. Phase 1 - AWS foundation cho EKS

### 6.1 Tạo ECR repo

```powershell
aws ecr create-repository `
  --repository-name $env:ECR_REPO `
  --image-scanning-configuration scanOnPush=true `
  --encryption-configuration encryptionType=AES256 `
  --region $env:AWS_REGION
```

Kiểm tra:

```powershell
aws ecr describe-repositories `
  --repository-names $env:ECR_REPO `
  --region $env:AWS_REGION
```

Best practice:

```text
Không dùng Docker Hub cho app nội bộ.
Dùng ECR private repo.
Tag bằng Git SHA.
Ưu tiên deploy bằng digest khi đã ổn định pipeline.
Bật scanOnPush, nhưng vẫn giữ Trivy trong CI vì CI cần fail sớm.
```

### 6.2 Tạo EKS cluster

Trong dự án thật, nên tạo EKS bằng Terraform hoặc eksctl, không tạo thủ công trên console.

Checklist cluster:

```text
EKS private/public endpoint theo nhu cầu lab
Managed node group hoặc Fargate
OIDC provider nếu dùng IRSA
EKS Pod Identity Agent nếu dùng EKS Pod Identity
CloudWatch control plane logs: api, audit, authenticator, controllerManager, scheduler
Add-ons: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver nếu cần volume
```

Sau khi tạo cluster:

```powershell
aws eks update-kubeconfig `
  --name $env:CLUSTER_NAME `
  --region $env:AWS_REGION

kubectl get nodes
kubectl get ns
```

### 6.3 GitHub Actions dùng OIDC thay vì AWS key dài hạn

Trong AWS IAM, tạo role cho GitHub Actions với trust policy giới hạn repo/branch.

Trust policy mẫu:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:<ORG>/<REPO>:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

Policy tối thiểu cho CI build/push ECR:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart",
        "ecr:BatchGetImage",
        "ecr:DescribeImages"
      ],
      "Resource": "arn:aws:ecr:<REGION>:<AWS_ACCOUNT_ID>:repository/w10-api"
    }
  ]
}
```

Best practice:

```text
Không lưu AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY trong GitHub Secrets.
Role trust policy phải giới hạn đúng repo và branch hoặc environment.
Production nên dùng GitHub Environment protection trước khi deploy.
```

---

## 7. Phase 2 - Bootstrap platform bằng GitOps

### 7.1 Cài ArgoCD bằng Helm

ArgoCD là ngoại lệ bootstrap. Sau khi ArgoCD chạy, mọi thứ còn lại nên đi qua GitOps.

```powershell
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd `
  -n argocd `
  --set server.service.type=ClusterIP
```

Kiểm tra:

```powershell
kubectl get pods -n argocd
kubectl get svc -n argocd
```

### 7.2 App-of-apps

Root app quản lý các child apps:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: w10-app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<ORG>/<REPO>.git
    targetRevision: main
    path: cloud/w10/platform/argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Apply root app:

```powershell
kubectl apply -f cloud/w10/platform/argocd/app-of-apps.yaml
kubectl get applications -n argocd
```

Sync wave khuyến nghị:

| Wave | App | Lý do |
|---|---|---|
| 0 | namespaces | Namespace phải có trước |
| 0 | gatekeeper | CRD policy phải có trước constraint |
| 0 | external-secrets | CRD secret phải có trước ExternalSecret |
| 0 | sigstore-policy-controller | Admission verify phải có trước test |
| 0 | kube-prometheus-stack | CRD ServiceMonitor/PrometheusRule |
| 0 | argo-rollouts | CRD Rollout/AnalysisTemplate |
| 1 | platform-policies | RBAC, constraints, image policy |
| 2 | app workload | App phụ thuộc toàn bộ nền trên |

---

## 8. Phase 3 - RBAC chuẩn

### 8.1 Role model

| Role | Quyền | Không được |
|---|---|---|
| viewer | `get/list/watch` resource trong namespace | create/update/delete |
| developer | deploy app trong namespace app | sửa clusterrole, namespace, CRD, policy |
| sre | vận hành rollout, debug pod, xem observability | cấp quyền IAM/AWS tùy tiện |

Test bằng:

```powershell
kubectl auth can-i get pods -n demo --as viewer
kubectl auth can-i create deployment -n demo --as developer
kubectl auth can-i delete namespace demo --as developer
kubectl auth can-i get rollout -n demo --as sre
kubectl auth can-i patch rollout -n demo --as sre
```

Kết quả đạt:

```text
viewer: chỉ xem
developer: thao tác app trong namespace
sre: vận hành rollout/debug
developer không được xóa namespace hoặc sửa cluster-wide policy
```

---

## 9. Phase 4 - Admission policy bằng Gatekeeper

### 9.1 Chính sách nên enforce

4 constraint tối thiểu:

```text
1. Bắt buộc container chạy non-root.
2. Cấm privileged container.
3. Bắt buộc CPU/memory requests và limits.
4. Cấm image latest hoặc image không thuộc registry được phép.
```

Best practice rollout:

```text
Audit mode trước.
Fix toàn bộ violation.
Chuyển enforce.
Test manifest xấu bị reject.
Ghi exception bằng ADR, có owner và ngày hết hạn.
```

Lệnh kiểm tra:

```powershell
kubectl get constrainttemplates
kubectl get constraints
kubectl describe constraint <constraint-name>
kubectl get k8spsp* -A
```

Test reject:

```powershell
kubectl run bad-root `
  --image=nginx:latest `
  -n demo
```

Kết quả mong muốn:

```text
Error from server: admission webhook denied the request
```

---

## 10. Phase 5 - Secrets bằng AWS Secrets Manager + ESO

### 10.1 Tạo secret trong AWS

```powershell
aws secretsmanager create-secret `
  --name prod/w10/db `
  --secret-string '{"password":"MyS3cr3tP@ss"}' `
  --region $env:AWS_REGION
```

Kiểm tra:

```powershell
aws secretsmanager describe-secret `
  --secret-id prod/w10/db `
  --region $env:AWS_REGION
```

### 10.2 Cấp quyền cho ESO

Best practice hiện đại trên EKS:

```text
Ưu tiên EKS Pod Identity nếu platform đã bật và team đang dùng EKS managed flow.
IRSA vẫn hợp lệ và rất phổ biến.
Không dùng static AWS access key trong production.
```

IAM policy tối thiểu:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:<REGION>:<AWS_ACCOUNT_ID>:secret:prod/w10/*"
    }
  ]
}
```

### 10.3 SecretStore

Với IRSA/EKS Pod Identity, SecretStore không cần chứa AWS key. Nó dùng identity của service account.

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: demo
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-southeast-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets
            namespace: external-secrets
```

Nếu lab buộc dùng access key, chỉ tạo bằng `kubectl create secret`, tuyệt đối không commit key vào Git.

### 10.4 ExternalSecret

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: w10-db
  namespace: demo
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: db-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: prod/w10/db
        property: password
```

Kiểm tra:

```powershell
kubectl get secretstore -n demo
kubectl get externalsecret -n demo
kubectl describe externalsecret w10-db -n demo
kubectl get secret db-secret -n demo
```

### 10.5 App mount secret qua volume

Không nên đọc secret qua env var nếu mục tiêu là rotate không restart. Nên mount secret thành file và app đọc file.

```yaml
volumes:
  - name: db-secret
    secret:
      secretName: db-secret
containers:
  - name: api
    env:
      - name: DB_PASSWORD_PATH
        value: /secrets/password
    volumeMounts:
      - name: db-secret
        mountPath: /secrets
        readOnly: true
```

Test rotation:

```powershell
kubectl get secret db-secret -n demo -o jsonpath='{.data.password}'

aws secretsmanager update-secret `
  --secret-id prod/w10/db `
  --secret-string '{"password":"NewP@ss123"}' `
  --region $env:AWS_REGION

Start-Sleep -Seconds 70

kubectl get secret db-secret -n demo -o jsonpath='{.data.password}'
kubectl get pods -n demo
```

Tiêu chí đạt:

```text
ExternalSecret READY=True.
K8s Secret đổi trong khoảng 60s.
Pod không restart.
App đọc được password mới từ mounted file.
```

---

## 11. Phase 6 - CI/CD image supply chain

### 11.1 Tag strategy

Không dùng:

```text
w10-api:latest
w10-api:v1
```

Nên dùng:

```text
<account>.dkr.ecr.<region>.amazonaws.com/w10-api:<git-sha>
```

Tốt hơn sau khi push:

```text
<account>.dkr.ecr.<region>.amazonaws.com/w10-api@sha256:<digest>
```

### 11.2 GitHub Actions workflow mẫu

```yaml
name: build-scan-sign

on:
  push:
    branches:
      - main
    paths:
      - "cloud/w10/apps/w10-api/**"
      - ".github/workflows/build-scan-sign.yml"

permissions:
  id-token: write
  contents: read
  packages: write

env:
  AWS_REGION: ap-southeast-1
  ECR_REPOSITORY: w10-api

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials by OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<AWS_ACCOUNT_ID>:role/github-actions-w10-ecr
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Set image
        id: image
        run: |
          IMAGE="${{ steps.ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }}"
          echo "image=$IMAGE" >> "$GITHUB_OUTPUT"

      - name: Build image
        run: |
          docker build \
            -t "${{ steps.image.outputs.image }}" \
            cloud/w10/apps/w10-api/app

      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.image.outputs.image }}
          severity: HIGH,CRITICAL
          exit-code: "1"
          ignore-unfixed: true

      - name: Push image
        run: docker push "${{ steps.image.outputs.image }}"

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign image keyless
        run: cosign sign --yes "${{ steps.image.outputs.image }}"
```

Best practice:

```text
Scan trước khi push/sign nếu workflow cho phép.
Nếu cần digest chính xác, push trước, lấy digest, sign digest.
Production nên sign digest thay vì tag.
GitHub OIDC dùng short-lived credential, không dùng AWS key dài hạn.
```

### 11.3 Cập nhật manifest sau khi image mới hợp lệ

Có hai cách:

```text
Cách 1: CI mở PR đổi image tag/digest trong GitOps manifest.
Cách 2: Argo CD Image Updater tự tạo commit đổi image.
```

Best practice cho học viên: dùng PR để dễ review.

```text
build/scan/sign pass
-> CI tạo PR update image digest
-> review
-> merge main
-> ArgoCD sync
```

---

## 12. Phase 7 - Admission verify signed image

### 12.1 Cài Sigstore Policy Controller

Theo lộ trình W10 slide, dùng Sigstore Policy Controller để chặn unsigned image.

Với GitOps, nên tạo ArgoCD Application cho Helm chart hoặc manifest release. Nếu lab cần chạy nhanh:

```powershell
kubectl apply -f https://github.com/sigstore/policy-controller/releases/download/v0.13.0/release.yaml
```

Kiểm tra:

```powershell
kubectl get pods -n cosign-system
kubectl get crd | Select-String "clusterimagepolicies"
```

### 12.2 Bật verify theo namespace

Sigstore policy-controller mặc định opt-in theo namespace. Label namespace app:

```powershell
kubectl label namespace demo policy.sigstore.dev/include=true --overwrite
```

### 12.3 ClusterImagePolicy keyless cho GitHub Actions

Mẫu policy chỉ cho image từ ECR repo của mình, được ký bởi workflow trong repo của mình:

```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: require-w10-api-signed-image
spec:
  images:
    - glob: "<AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/w10-api**"
  authorities:
    - keyless:
        identities:
          - issuer: https://token.actions.githubusercontent.com
            subjectRegExp: "https://github.com/<ORG>/<REPO>/.github/workflows/.*@refs/heads/main"
```

Kiểm tra policy:

```powershell
kubectl get clusterimagepolicy
kubectl describe clusterimagepolicy require-w10-api-signed-image
```

### 12.4 Test unsigned image bị reject

```powershell
kubectl run unsigned-test `
  --image=nginx:latest `
  -n demo
```

Kết quả mong muốn:

```text
Error from server: admission webhook denied the request
```

Test signed image:

```powershell
kubectl run signed-test `
  --image=<AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/w10-api:<SIGNED_GIT_SHA> `
  -n demo
```

Kết quả mong muốn:

```text
pod/signed-test created
```

---

## 13. Phase 8 - App deployment bằng Argo Rollouts

Rollout nên giữ tinh thần W9, nhưng image chuyển sang ECR.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: w10-api
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: w10-api
  strategy:
    canary:
      steps:
        - setWeight: 25
        - pause:
            duration: 60s
        - analysis:
            templates:
              - templateName: w10-api-success-rate
        - setWeight: 50
        - pause:
            duration: 60s
        - analysis:
            templates:
              - templateName: w10-api-success-rate
        - setWeight: 100
  template:
    metadata:
      labels:
        app.kubernetes.io/name: w10-api
    spec:
      serviceAccountName: w10-api
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: api
          image: <AWS_ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/w10-api:<GIT_SHA>
          imagePullPolicy: IfNotPresent
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 250m
              memory: 256Mi
```

Kiểm tra:

```powershell
kubectl get application w10-api -n argocd
kubectl get rollout w10-api -n demo
kubectl get pods -n demo
kubectl get analysisrun -n demo
```

---

## 14. Phase 9 - Observability và SLO

Giữ pattern W9:

```text
ServiceMonitor scrape /metrics
PrometheusRule tạo recording rule + alert
AnalysisTemplate dùng Prometheus query để promote/abort canary
Alertmanager gửi email/Slack khi SLO fail
```

Kiểm tra:

```powershell
kubectl get servicemonitor,prometheusrule -n demo
kubectl get pods -n observability
kubectl port-forward svc/kube-prometheus-stack-prometheus -n observability 9090:9090
```

Prometheus query nên có:

```promql
sum(rate(flask_http_request_total{namespace="demo",status!~"5.."}[2m]))
/
sum(rate(flask_http_request_total{namespace="demo"}[2m]))
```

Tiêu chí đạt:

```text
Prometheus target UP.
SLO recording rule có dữ liệu.
Bad canary làm AnalysisRun Failed.
Rollout tự abort về stable.
Alert firing khi success rate dưới ngưỡng.
```

---

## 15. Phase 10 - ResourceQuota, LimitRange và cost guard

### 15.1 ResourceQuota

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-quota
  namespace: demo
spec:
  hard:
    pods: "20"
    requests.cpu: "2"
    requests.memory: 4Gi
    limits.cpu: "4"
    limits.memory: 8Gi
```

### 15.2 LimitRange

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: demo-default-limits
  namespace: demo
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 50m
        memory: 64Mi
      default:
        cpu: 250m
        memory: 256Mi
```

Kiểm tra:

```powershell
kubectl get resourcequota,limitrange -n demo
kubectl describe resourcequota demo-quota -n demo
kubectl describe limitrange demo-default-limits -n demo
```

Best practice:

```text
Quota để chặn namespace dùng quá tài nguyên.
LimitRange để workload thiếu request/limit vẫn có default an toàn.
Policy Gatekeeper vẫn nên bắt app khai báo request/limit rõ ràng.
```

---

## 16. Phase 11 - Rollback chuẩn

Rollback vẫn đi qua Git:

```powershell
git log --oneline -- cloud/w10/apps/w10-api
git revert <BAD_COMMIT_SHA>
git push origin main
```

Refresh ArgoCD:

```powershell
kubectl annotate application w10-api `
  -n argocd `
  argocd.argoproj.io/refresh=hard `
  --overwrite
```

Kiểm tra:

```powershell
kubectl get application w10-api -n argocd
kubectl get rollout w10-api -n demo
kubectl get pods -n demo -o wide
```

Tiêu chí đạt:

```text
ArgoCD Synced/Healthy.
Rollout quay về stable image cũ.
Không kubectl edit trực tiếp.
Rollback hoàn tất trong mục tiêu thời gian đã công bố.
```

---

## 17. Runbook sự cố 5 phút đầu

Khi nghi ngờ app hoặc cluster bị compromise:

```text
1. Detect
   - Alert nào firing?
   - Pod nào bất thường?
   - Image digest nào đang chạy?

2. Triage
   - Kiểm tra rollout history.
   - Kiểm tra commit Git mới nhất.
   - Kiểm tra event admission/policy.

3. Contain
   - Scale down workload xấu hoặc rollback qua Git.
   - Nếu là credential leak, disable/rotate secret trong AWS Secrets Manager.
   - Nếu là image xấu, revoke policy exception và block digest.

4. Eradicate
   - Fix code hoặc manifest.
   - Rebuild image.
   - Scan/sign lại.

5. Recover
   - ArgoCD sync.
   - SLO xanh lại.
   - Alert resolved.

6. Post-mortem
   - Root cause.
   - Timeline.
   - Missing guardrail.
   - Action item có owner và deadline.
```

Lệnh cần dùng:

```powershell
kubectl get events -A --sort-by=.lastTimestamp
kubectl get pods -n demo -o wide
kubectl describe pod <pod> -n demo
kubectl get rollout w10-api -n demo
kubectl argo rollouts history w10-api -n demo
git log --oneline -10
aws secretsmanager describe-secret --secret-id prod/w10/db --region $env:AWS_REGION
```

---

## 18. Demo end-to-end chuẩn cho mentor

Thứ tự demo nên chạy:

```text
1. Show repo layout W10.
2. Show ArgoCD app-of-apps.
3. Show EKS cluster + namespaces.
4. Show RBAC can-i cho viewer/developer/sre.
5. Show Gatekeeper constraints enforce.
6. Deploy manifest xấu và chứng minh bị reject.
7. Show AWS Secrets Manager secret.
8. Show ExternalSecret READY=True và K8s Secret được tạo.
9. Rotate secret trên AWS và chứng minh K8s Secret đổi < 60s.
10. Show GitHub Actions build-scan-sign.
11. Show Trivy pass/fail.
12. Show Cosign verify.
13. Show unsigned image bị admission reject.
14. Show signed image deploy được.
15. Show Argo Rollouts canary.
16. Inject lỗi, chứng minh AnalysisRun fail và rollout abort.
17. Rollback bằng git revert.
18. Show ResourceQuota/LimitRange.
19. Show runbook incident response.
```

---

## 19. Evidence checklist

| # | Evidence | Lệnh/nguồn |
|---|---|---|
| 1 | AWS identity đúng account | `aws sts get-caller-identity` |
| 2 | ECR repo tồn tại | `aws ecr describe-repositories` |
| 3 | EKS nodes ready | `kubectl get nodes` |
| 4 | ArgoCD running | `kubectl get pods -n argocd` |
| 5 | App-of-apps Synced | `kubectl get applications -n argocd` |
| 6 | RBAC phân quyền | `kubectl auth can-i ... --as ...` |
| 7 | Gatekeeper constraints | `kubectl get constraints` |
| 8 | Manifest xấu bị reject | `kubectl run bad-root ...` |
| 9 | AWS Secrets Manager secret | `aws secretsmanager describe-secret` |
| 10 | ExternalSecret ready | `kubectl get externalsecret -n demo` |
| 11 | Secret rotation | trước/sau `aws secretsmanager update-secret` |
| 12 | Pod không restart | `kubectl get pods -n demo` |
| 13 | CI Trivy scan | GitHub Actions log |
| 14 | Cosign signature | `cosign verify ...` |
| 15 | Unsigned image rejected | `kubectl run unsigned-test ...` |
| 16 | Signed image accepted | `kubectl run signed-test ...` |
| 17 | Rollout canary | `kubectl get rollout -n demo` |
| 18 | AnalysisRun result | `kubectl get analysisrun -n demo` |
| 19 | Prometheus target UP | Prometheus UI hoặc query |
| 20 | ResourceQuota/LimitRange | `kubectl get resourcequota,limitrange -n demo` |
| 21 | Rollback qua Git | `git show`, `git revert`, ArgoCD Synced |

---

## 20. Các lỗi hay gặp và cách đọc lỗi

### ImagePullBackOff

Nguyên nhân thường gặp:

```text
Image chưa push lên ECR.
Node chưa có quyền pull ECR.
Sai region/account/repo.
Manifest dùng tag không tồn tại.
Admission mutate tag sang digest nhưng digest không pull được.
```

Lệnh kiểm tra:

```powershell
kubectl describe pod <pod> -n demo
aws ecr describe-images --repository-name w10-api --region $env:AWS_REGION
```

### ExternalSecret không sync

Nguyên nhân thường gặp:

```text
IAM role thiếu secretsmanager:GetSecretValue.
Sai region.
Sai secret name hoặc property.
ServiceAccount chưa gắn IRSA/EKS Pod Identity.
ESO controller chưa chạy.
```

Lệnh kiểm tra:

```powershell
kubectl describe externalsecret w10-db -n demo
kubectl logs -n external-secrets deploy/external-secrets
aws secretsmanager get-secret-value --secret-id prod/w10/db --region $env:AWS_REGION
```

### Signed image vẫn bị reject

Nguyên nhân thường gặp:

```text
ClusterImagePolicy glob không match image.
Ký tag nhưng deploy digest khác, hoặc ngược lại.
Keyless identity subjectRegExp không match workflow.
Namespace chưa label policy.sigstore.dev/include=true.
Signature chưa push hoặc registry không hỗ trợ kiểu lưu signature đang dùng.
```

Lệnh kiểm tra:

```powershell
kubectl describe clusterimagepolicy require-w10-api-signed-image
kubectl get ns demo --show-labels
cosign verify <image>
kubectl get events -n demo --sort-by=.lastTimestamp
```

### Gatekeeper làm app không deploy được

Nguyên nhân thường gặp:

```text
App thiếu requests/limits.
Container chạy root.
Image dùng latest.
SecurityContext thiếu allowPrivilegeEscalation=false.
```

Cách xử lý đúng:

```text
Không tắt Gatekeeper ngay.
Đọc violation.
Fix manifest.
Nếu cần exception, viết ADR có expiry.
```

---

## 21. Definition of Done cuối W10

Đạt khi đủ các tiêu chí sau:

```text
1. EKS cluster dựng được từ IaC/bootstrap script.
2. ArgoCD app-of-apps quản lý toàn bộ platform.
3. App deploy từ ECR, không dùng Minikube image.
4. GitHub Actions dùng OIDC vào AWS, không dùng AWS static key.
5. Image được Trivy scan và Cosign sign.
6. Unsigned image bị admission reject.
7. Secret thật nằm trong AWS Secrets Manager, không nằm trong Git.
8. ESO sync secret về K8s và rotate < 60s.
9. RBAC có viewer/developer/sre rõ ràng.
10. Gatekeeper enforce ít nhất 4 constraint.
11. ResourceQuota + LimitRange tồn tại.
12. Observability/SLO/canary từ W9 vẫn hoạt động.
13. Bad canary tự abort.
14. Rollback bằng git revert.
15. Có runbook incident response.
```

---

## 22. Cách giải thích ngắn gọn với mentor

```text
W9 chứng minh mô hình GitOps, observability và canary trong môi trường local. W10 triển khai lại theo hướng AWS/EKS production-like: image không còn nằm trong Minikube mà được build bằng CI, scan bằng Trivy, đẩy lên ECR, ký bằng Cosign và chỉ image đã ký mới được admission cho vào cluster. Secret thật không nằm trong Git mà nằm trong AWS Secrets Manager, ESO sync về K8s với refreshInterval 1 phút. Cluster có RBAC, Gatekeeper, quota, limit và runbook để vận hành an toàn hơn.
```

---

## 23. Tài liệu chính thống nên đọc

- AWS EKS Best Practices Guide for Security: https://aws.github.io/aws-eks-best-practices/security/docs/
- AWS EKS Pod Identity: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- AWS EKS IRSA: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- GitHub Actions OIDC with AWS: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
- External Secrets Operator with AWS Secrets Manager: https://external-secrets.io/latest/provider/aws-secrets-manager/
- Sigstore Policy Controller: https://docs.sigstore.dev/policy-controller/overview/
- Cosign signing overview: https://docs.sigstore.dev/cosign/signing/overview/
- Trivy documentation: https://trivy.dev/docs/latest/
- Kubernetes RBAC: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- Kubernetes ResourceQuota: https://kubernetes.io/docs/concepts/policy/resource-quotas/
- Kubernetes LimitRange: https://kubernetes.io/docs/concepts/policy/limit-range/

