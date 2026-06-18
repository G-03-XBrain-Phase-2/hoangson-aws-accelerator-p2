# Step 02 - EKS Cluster and Kubeconfig

> Mục tiêu của bước này là tạo EKS cluster bằng Terraform automation, sau đó cấu hình `kubectl` để kết nối được cluster. Đây là nền bắt buộc trước khi sang Step 03 bootstrap ArgoCD và GitOps platform.

---

## 1. Step 02 nằm ở đâu trong quy trình W9 -> W10

W9 chạy local:

```text
Minikube
-> ArgoCD trong local cluster
-> image local
```

W10 chạy production-like:

```text
AWS foundation
-> EKS cluster
-> ArgoCD bootstrap
-> GitOps platform add-ons
-> app deploy từ ECR
```

Step 02 tạo phần này:

```text
VPC
public/private subnets
NAT Gateway
EKS control plane
managed node group
EKS add-ons cơ bản
IRSA/OIDC issuer cho các bước ESO sau này
kubeconfig để kubectl kết nối cluster
```

Quan trọng:

```text
GitOps/ArgoCD chưa bắt đầu ở Step 02, vì cluster và ArgoCD chưa tồn tại.
Step 02 vẫn thuộc lớp infrastructure automation bằng Terraform.
GitOps bắt đầu từ Step 03 sau khi ArgoCD được bootstrap.
```

---

## 2. File và folder liên quan

Terraform source:

```text
cloud/w10/project-01-secure-operate-platform/infra/terraform/eks/
  versions.tf
  variables.tf
  main.tf
  outputs.tf
  terraform.tfvars.example
```

Workflow template:

```text
cloud/w10/project-01-secure-operate-platform/ci/github-actions/terraform-eks.yml
```

Guide:

```text
cloud/w10/guides/implementation-steps/STEP-02-EKS-CLUSTER.md
```

Giải thích các file Terraform:

| File | Cấu hình gì |
|---|---|
| `versions.tf` | Terraform version và AWS provider |
| `variables.tf` | Biến cấu hình cluster, VPC CIDR, node size, endpoint CIDR |
| `main.tf` | Tạo VPC bằng module, tạo EKS bằng module, bật add-ons và node group |
| `outputs.tf` | In cluster name, endpoint, OIDC issuer, VPC ID, kubeconfig command |
| `terraform.tfvars.example` | File mẫu biến môi trường |

---

## 3. Vì sao dùng Terraform module

EKS có nhiều thành phần liên quan:

```text
VPC
subnets
route tables
NAT Gateway
security groups
EKS control plane
node IAM role
managed node group
cluster add-ons
OIDC issuer
```

Nếu tự viết tất cả resource từ đầu, dễ sai và khó bảo trì. Trong dự án thực tế, team thường dùng module đã được kiểm chứng, sau đó khóa version và review plan.

Stack này dùng:

```text
terraform-aws-modules/vpc/aws
terraform-aws-modules/eks/aws
```

Best practice ở đây:

```text
Không tạo EKS bằng console.
Không dùng eksctl làm source of truth lâu dài.
Terraform code + plan review + protected apply là đường chính.
```

---

## 4. Điều kiện trước khi làm

Step 01/01B đã xong:

```text
Terraform foundation đã có.
CI/CD Terraform apply đã sẵn sàng hoặc có bootstrap path rõ ràng.
W10_TERRAFORM_ROLE_ARN đã có trong GitHub variables nếu dùng CI/CD.
AWS account/region đã xác nhận đúng.
```

Kiểm tra local:

```powershell
Set-Location E:\Xbrain\tf_learning

aws sts get-caller-identity
aws configure get region
terraform version
kubectl version --client
```

Nếu `kubectl` chưa có, cài trước. Step 02 kết thúc bằng việc dùng `kubectl get nodes`.

---

## 5. Vào thư mục Terraform EKS

```powershell
Set-Location E:\Xbrain\tf_learning\cloud\w10\project-01-secure-operate-platform\infra\terraform\eks
```

Kiểm tra file:

```powershell
Get-ChildItem
```

Kết quả cần có:

```text
main.tf
outputs.tf
terraform.tfvars.example
variables.tf
versions.tf
```

---

## 6. Tạo terraform.tfvars

Copy file mẫu:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Mở `terraform.tfvars` và kiểm tra:

```hcl
aws_region      = "ap-southeast-1"
cluster_name    = "w10-secure-platform"
cluster_version = "1.30"

vpc_cidr                = "10.40.0.0/16"
availability_zone_count = 2

cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

node_instance_types = ["t3.medium"]
node_min_size       = 1
node_desired_size   = 2
node_max_size       = 3
```

Giải thích các biến quan trọng:

| Biến | Ý nghĩa |
|---|---|
| `cluster_name` | Tên EKS cluster |
| `cluster_version` | Version Kubernetes trên EKS |
| `vpc_cidr` | CIDR cho VPC riêng của cluster |
| `availability_zone_count` | Số AZ dùng cho public/private subnets |
| `cluster_endpoint_public_access_cidrs` | IP nào được gọi public EKS API endpoint |
| `node_instance_types` | Loại EC2 cho managed node group |
| `node_desired_size` | Số node mong muốn |

Về `cluster_endpoint_public_access_cidrs`:

```text
Lab default đang là 0.0.0.0/0 để tránh kẹt truy cập.
Best practice hơn là thay bằng public IP của em dạng x.x.x.x/32.
```

Lấy public IP:

```powershell
(Invoke-RestMethod https://checkip.amazonaws.com).Trim()
```

Sau đó sửa:

```hcl
cluster_endpoint_public_access_cidrs = ["<YOUR_PUBLIC_IP>/32"]
```

---

## 7. Chạy kiểm tra Terraform local

Các lệnh này chỉ kiểm tra trước khi push, không thay thế CI/CD.

```powershell
terraform init
terraform fmt
terraform validate
terraform plan
```

Giải thích:

| Lệnh | Ý nghĩa |
|---|---|
| `terraform init` | Tải AWS provider và module VPC/EKS |
| `terraform fmt` | Format Terraform |
| `terraform validate` | Kiểm tra cấu trúc |
| `terraform plan` | Xem Terraform sẽ tạo gì |

Trong plan, em cần thấy các nhóm tài nguyên:

```text
VPC
public subnets
private subnets
route tables
NAT Gateway
EKS cluster
EKS managed node group
cluster add-ons: coredns, kube-proxy, vpc-cni, aws-ebs-csi-driver
IAM role/policy cho EKS/node group
```

Không apply nếu thấy:

```text
Sai region.
Sai cluster name.
CIDR trùng với VPC khác.
Node instance quá lớn gây tốn tiền.
Plan có destroy ngoài ý muốn.
```

---

## 8. CI/CD apply cho EKS

Workflow template:

```text
cloud/w10/project-01-secure-operate-platform/ci/github-actions/terraform-eks.yml
```

Workflow chạy thật ở root repo:

```text
.github/workflows/w10-terraform-eks.yml
```

Workflow này dùng:

```text
W10_TERRAFORM_ROLE_ARN
```

Role này phải có quyền tạo EKS/VPC/IAM/EC2 liên quan. Role chỉ có quyền push ECR là chưa đủ.

Quy trình chạy:

```text
branch
-> Pull Request
-> CI terraform plan
-> review plan
-> merge main
-> CD terraform apply trong environment w10-production
```

Stage và commit:

```powershell
git add cloud/w10/project-01-secure-operate-platform/infra/terraform/eks
git add cloud/w10/project-01-secure-operate-platform/ci/github-actions/terraform-eks.yml
git add cloud/w10/guides/implementation-steps/STEP-02-EKS-CLUSTER.md
git add .github/workflows/w10-terraform-eks.yml

git commit -m "feat: add w10 eks terraform automation"
git push origin <branch-name>
```

Mở PR và review `terraform plan`.

Sau merge main, approve environment nếu GitHub yêu cầu.

---

## 9. Trường hợp lab: apply local có được không

Có, nhưng chỉ là bootstrap/lab exception.

Chỉ chạy local apply nếu:

```text
Bạn đang làm lab cá nhân.
CI role chưa đủ quyền tạo EKS.
Bạn đã đọc kỹ terraform plan.
Bạn chấp nhận tài nguyên AWS và cost phát sinh.
```

Lệnh:

```powershell
Set-Location E:\Xbrain\tf_learning\cloud\w10\project-01-secure-operate-platform\infra\terraform\eks
terraform apply
```

Sau khi bootstrap xong, các thay đổi tiếp theo phải đi qua PR/CI/CD.

---

## 10. Kiểm tra sau khi apply

Set biến:

```powershell
$env:AWS_REGION = "ap-southeast-1"
$env:CLUSTER_NAME = "w10-secure-platform"
```

Kiểm tra cluster:

```powershell
aws eks describe-cluster `
  --name $env:CLUSTER_NAME `
  --region $env:AWS_REGION `
  --query "cluster.{name:name,status:status,version:version,endpoint:endpoint}" `
  --output table
```

Kết quả mong muốn:

```text
status = ACTIVE
version = 1.30 hoặc version em chọn
endpoint có giá trị
```

Kiểm tra node group:

```powershell
aws eks list-nodegroups `
  --cluster-name $env:CLUSTER_NAME `
  --region $env:AWS_REGION
```

Kiểm tra add-ons:

```powershell
aws eks list-addons `
  --cluster-name $env:CLUSTER_NAME `
  --region $env:AWS_REGION
```

Cần thấy:

```text
coredns
kube-proxy
vpc-cni
aws-ebs-csi-driver
```

---

## 11. Cập nhật kubeconfig

```powershell
aws eks update-kubeconfig `
  --name $env:CLUSTER_NAME `
  --region $env:AWS_REGION
```

Giải thích:

```text
Lệnh này thêm EKS context vào kubeconfig local.
Sau lệnh này, kubectl sẽ biết gọi API server của cluster W10.
```

Kiểm tra context:

```powershell
kubectl config current-context
```

Kiểm tra node:

```powershell
kubectl get nodes -o wide
```

Kết quả mong muốn:

```text
Node ở trạng thái Ready.
Internal IP thuộc VPC CIDR.
Version khớp EKS/node group.
```

Kiểm tra namespace mặc định:

```powershell
kubectl get ns
```

Cần thấy:

```text
default
kube-node-lease
kube-public
kube-system
```

---

## 12. Kiểm tra IRSA/OIDC cho bước ESO sau này

Lấy OIDC issuer:

```powershell
aws eks describe-cluster `
  --name $env:CLUSTER_NAME `
  --region $env:AWS_REGION `
  --query "cluster.identity.oidc.issuer" `
  --output text
```

Giải thích:

```text
OIDC issuer là nền để sau này ESO dùng IRSA đọc AWS Secrets Manager mà không cần hardcode AWS keys.
```

Nếu output rỗng hoặc lỗi, cần kiểm tra lại EKS cluster và Terraform module config.

---

## 13. Lỗi thường gặp

### Terraform init tải module lỗi

Triệu chứng:

```text
Could not download module
```

Cách xử lý:

```text
Kiểm tra internet/proxy.
Chạy lại terraform init.
```

### CIDR bị trùng

Triệu chứng:

```text
VPC/subnet CIDR conflict hoặc routing không như kỳ vọng.
```

Cách xử lý:

```text
Đổi vpc_cidr trong terraform.tfvars.
Ví dụ 10.50.0.0/16.
```

### Không truy cập được EKS API

Triệu chứng:

```text
kubectl get nodes timeout.
```

Kiểm tra:

```text
cluster_endpoint_public_access_cidrs có chứa public IP của bạn không?
aws eks update-kubeconfig đã chạy đúng region/cluster chưa?
```

### Node không Ready

Triệu chứng:

```text
kubectl get nodes không có node hoặc node NotReady.
```

Kiểm tra:

```powershell
aws eks list-nodegroups --cluster-name $env:CLUSTER_NAME --region $env:AWS_REGION
kubectl get pods -n kube-system
```

Nguyên nhân thường gặp:

```text
Node group chưa tạo xong.
VPC CNI lỗi.
IAM role node thiếu permission.
Subnet/route/NAT Gateway chưa ổn.
```

### Cost cao

Nguồn cost chính:

```text
EKS control plane hourly cost
EC2 worker nodes
NAT Gateway
EBS volume
CloudWatch logs nếu bật nhiều
```

Nếu chỉ lab ngắn, nhớ destroy khi xong:

```powershell
terraform destroy
```

Nhưng destroy cũng phải qua quy trình có kiểm soát nếu đang dùng CI/CD.

---

## 14. Khi nào Step 02 hoàn thành

Step 02 hoàn thành khi đủ:

```text
Terraform EKS plan đã được review.
Terraform apply chạy qua CI/CD hoặc bootstrap/lab có kiểm soát.
aws eks describe-cluster trả status ACTIVE.
aws eks list-nodegroups thấy node group.
aws eks list-addons thấy add-ons cơ bản.
aws eks update-kubeconfig chạy thành công.
kubectl config current-context trỏ đúng cluster.
kubectl get nodes thấy node Ready.
OIDC issuer có giá trị để dùng cho IRSA/ESO ở các bước sau.
```

Kết luận có thể nói với mentor:

```text
Em đã tạo EKS bằng Terraform automation, không tạo tay trên console. Cluster có VPC riêng, managed node group, add-ons cơ bản và OIDC issuer để chuẩn bị cho IRSA/ESO. Sau khi update kubeconfig, kubectl đã kết nối được và nodes ở trạng thái Ready. Từ bước sau, em có thể bootstrap ArgoCD để bắt đầu GitOps layer.
```

---

## 15. Bước tiếp theo

Sau Step 02:

```text
Step 03 - ArgoCD bootstrap and app-of-apps
```

Ở Step 03, GitOps mới bắt đầu quản lý các thành phần Kubernetes như:

```text
Argo Rollouts
kube-prometheus-stack
External Secrets Operator
Gatekeeper
Sigstore Policy Controller
application manifests
```
