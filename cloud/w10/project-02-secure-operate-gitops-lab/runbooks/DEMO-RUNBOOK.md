# W10 Project 02 - Demo Runbook

Runbook này dùng để demo nhanh sau khi đã đọc các file hướng dẫn trong `guides/configuration-steps`.

## 0. Vào Đúng Thư Mục

```powershell
$ProjectRoot = "E:\Xbrain\tf_learning\cloud\w10\project-02-secure-operate-gitops-lab"
Set-Location $ProjectRoot
```

## 1. Kiểm Tra Repo, Image Và Email

```powershell
Get-ChildItem argocd,app-api,image-policy -Recurse -File |
  Select-String -Pattern "YOUR_GITHUB|YOUR_EMAIL"
```

Thông tin chuẩn của bài này:

```text
GitHub repo:
  https://github.com/G-03-XBrain-Phase-2/hoangson-aws-accelerator-p2.git

GHCR image:
  ghcr.io/g-03-xbrain-phase-2/w10-api

Email alert:
  nguyenhoangson.13032004@gmail.com
```

Kết quả đúng: không có output. Nếu còn placeholder trong manifest deploy, xử lý trước khi bootstrap ArgoCD.

## 2. Tạo Fresh Cluster

```powershell
$Profile = "w10-secure-lab"
minikube start -p $Profile --driver=docker --cpus=4 --memory=8192 --disk-size=30g
minikube profile $Profile
kubectl config use-context $Profile
kubectl get nodes -o wide
```

## 3. Cài ArgoCD

```powershell
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s
kubectl apply -f argocd/root.yaml
kubectl get applications -n argocd
```

## 4. Quan Sát GitOps Sync

```powershell
kubectl get applications -n argocd
kubectl get pods -A
kubectl get rollout api -n demo
kubectl get servicemonitor -n demo
kubectl get prometheusrule -n monitoring
```

## 5. Demo RBAC

```powershell
kubectl auth can-i create deploy -n demo --as alice
kubectl auth can-i create deploy -n kube-system --as alice
kubectl auth can-i get pods -A --as bob
kubectl auth can-i delete nodes --as carol
```

Kỳ vọng:

```text
yes
no
yes
no
```

## 6. Demo Gatekeeper

```powershell
kubectl get constrainttemplates
kubectl get constraints
kubectl apply -f gatekeeper/tests/invalid-latest-pod.yaml
kubectl apply -f gatekeeper/tests/invalid-no-limits-pod.yaml
kubectl apply -f gatekeeper/tests/invalid-root-pod.yaml
kubectl apply -f gatekeeper/tests/invalid-host-network-pod.yaml
kubectl apply -f gatekeeper/tests/valid-pod.yaml
kubectl delete -f gatekeeper/tests/valid-pod.yaml
```

Các manifest invalid phải bị reject. Manifest valid phải tạo thành công.

## 7. Demo ESO Với AWS Secrets Manager

Tạo secret trên AWS:

```powershell
aws secretsmanager create-secret `
  --name prod/db/password `
  --secret-string "initial-password" `
  --region ap-southeast-1
```

Tạo credential runtime trong cluster:

```powershell
kubectl create secret generic aws-credentials -n demo `
  --from-literal=access-key-id=YOUR_AWS_ACCESS_KEY_ID `
  --from-literal=secret-access-key=YOUR_AWS_SECRET_ACCESS_KEY
```

Verify sync:

```powershell
kubectl get secretstore -n demo
kubectl get externalsecret -n demo
kubectl get secret db-secret -n demo
kubectl get secret db-secret -n demo -o jsonpath="{.data.password}" | ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }
```

Rotate:

```powershell
aws secretsmanager put-secret-value `
  --secret-id prod/db/password `
  --secret-string "rotated-password" `
  --region ap-southeast-1
```

Sau khoảng 30-60 giây, đọc lại secret Kubernetes để chứng minh giá trị đã đổi.

## 8. Demo Supply Chain

Tạo GitHub Actions secrets bằng GitHub Web UI:

```text
GitHub repo -> Settings -> Secrets and variables -> Actions -> New repository secret
```

Cần có:

```text
COSIGN_PRIVATE_KEY
COSIGN_PASSWORD
```

Kiểm tra workflow bằng GitHub Web UI:

```text
GitHub repo -> Actions -> Build, Scan, Sign
```

Workflow:

```text
Build image -> Trivy scan -> Push GHCR -> Cosign sign -> Commit rollout image update
```

Sau khi workflow pass, kiểm tra image bằng GitHub Web UI:

```text
GitHub profile/org -> Packages -> w10-api
```

Verify chữ ký:

```powershell
cosign verify --key image-policy/cosign.pub ghcr.io/g-03-xbrain-phase-2/w10-api:<tag>
```

## 9. Demo Signature Admission

Chỉ bật sau khi image đã sign:

```powershell
Copy-Item image-policy/cluster-image-policy.yaml.example image-policy/cluster-image-policy.yaml
Copy-Item argocd/apps/image-policy.yaml.example argocd/apps/image-policy.yaml
```

Thay public key thật trong `cluster-image-policy.yaml`, commit/push, chờ ArgoCD sync.

Test:

```powershell
kubectl run unsigned-test -n demo --image=nginx:1.27
kubectl get events -n demo --sort-by=.lastTimestamp
```

Kỳ vọng: unsigned image bị admission reject.
