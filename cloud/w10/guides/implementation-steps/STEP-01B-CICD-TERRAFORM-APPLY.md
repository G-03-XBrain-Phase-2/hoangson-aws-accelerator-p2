# Step 01B - CI/CD Terraform Apply

> Mục tiêu của bước này là biến Terraform foundation thành quy trình automation: Pull Request chạy `terraform plan`, sau khi review và merge vào `main` thì GitHub Actions chạy `terraform apply` trong protected environment.

---

## 1. Vì sao cần Step 01B

Ở Step 01, `terraform plan` chỉ cho biết Terraform sẽ tạo gì. Nó chưa tạo tài nguyên AWS thật.

Muốn hoàn thành AWS foundation thì vẫn cần `terraform apply`, nhưng best practice là:

```text
Không apply thủ công hằng ngày từ laptop.
Apply nên chạy bằng CI/CD sau khi PR đã được review.
```

Luồng chuẩn:

```text
branch
-> Pull Request
-> GitHub Actions terraform plan
-> review plan
-> merge main
-> GitHub Actions terraform apply
-> kiểm tra ECR/IAM bằng AWS CLI
```

---

## 2. File workflow đang nằm ở đâu

Template workflow đã có trong project:

```text
cloud/w10/project-01-secure-operate-platform/ci/github-actions/terraform-foundation.yml
```

Workflow chạy thật ở root repo:

```text
.github/workflows/w10-terraform-foundation.yml
```

Lưu ý quan trọng:

```text
GitHub chỉ tự chạy workflow nếu file nằm ở .github/workflows/ tại root repo.
```

Vì vậy project giữ một bản template/source để dễ quản lý theo W10, còn root workflow là bản GitHub Actions chạy thật.

---

## 3. Bootstrap role là gì

Workflow Terraform cần một AWS IAM role để assume:

```text
W10_TERRAFORM_ROLE_ARN
```

Role này dùng để GitHub Actions có quyền chạy:

```text
terraform plan
terraform apply
```

Điểm hơi vòng lặp:

```text
Muốn GitHub Actions tạo AWS resources thì GitHub Actions cần role trước.
Nhưng role cũng là AWS resource.
```

Trong công ty thật, bootstrap role thường được tạo bởi:

```text
platform team
Control Tower / Account Factory
Terraform Cloud / Atlantis
bootstrap stack riêng
```

Trong lab cá nhân, có thể dùng một trong hai cách:

```text
Cách A: tạo bootstrap role riêng bằng tay/IaC tối thiểu rồi dùng CI/CD.
Cách B: chạy terraform apply local một lần để tạo role, sau đó mọi thay đổi đi qua CI/CD.
```

Nếu em đang mô phỏng dự án chuẩn, hãy ghi rõ:

```text
Local apply chỉ là bootstrap exception. Sau bootstrap, Terraform changes đi qua PR plan và protected apply.
```

---

## 4. Kiểm tra workflow root

Đứng ở root repo:

```powershell
Set-Location E:\Xbrain\tf_learning
```

Kiểm tra:

```powershell
Get-Content .github/workflows/w10-terraform-foundation.yml
```

Giải thích:

```text
File trong cloud/w10/project... là template thuộc project.
File trong .github/workflows là bản GitHub Actions sẽ chạy thật.
```

---

## 5. Cấu hình GitHub repository variable

Vào GitHub repo:

```text
Settings
-> Secrets and variables
-> Actions
-> Variables
-> New repository variable
```

Tạo variable:

```text
Name: W10_TERRAFORM_ROLE_ARN
Value: arn:aws:iam::<AWS_ACCOUNT_ID>:role/<BOOTSTRAP_OR_TERRAFORM_ROLE>
```

Giải thích:

```text
Workflow dùng vars.W10_TERRAFORM_ROLE_ARN để assume role.
Không hardcode role ARN vào workflow để dễ đổi giữa lab/staging/prod.
```

Không dùng secret cho giá trị này cũng được vì role ARN không phải secret. Secret thật là quyền assume role, được bảo vệ bằng IAM trust policy + GitHub OIDC.

---

## 6. Cấu hình GitHub environment bảo vệ apply

Vào GitHub repo:

```text
Settings
-> Environments
-> New environment
```

Tạo environment:

```text
w10-production
```

Bật:

```text
Required reviewers
```

Giải thích:

```text
Workflow apply dùng environment: w10-production.
Nhờ vậy apply không chạy bừa sau merge nếu chưa có reviewer approve environment.
```

Đây là cách mô phỏng thực tế:

```text
PR review code + plan.
Environment approval bảo vệ bước apply.
```

---

## 7. Kiểm tra workflow làm gì

Workflow có 2 job:

```text
plan
apply
```

Job `plan` chạy khi:

```text
pull_request thay đổi infra/terraform/foundation
push main thay đổi infra/terraform/foundation
workflow_dispatch
```

Job `plan` chạy:

```text
terraform fmt -check
terraform init
terraform validate
terraform plan -input=false
```

Job `apply` chỉ chạy khi:

```text
event là push
branch là main
job plan đã pass
environment w10-production được approve
```

Job `apply` chạy:

```text
terraform init
terraform apply -input=false -auto-approve
```

Giải thích:

```text
-auto-approve trong CI là bình thường vì approval nằm ở PR review và protected environment.
Không dùng -auto-approve từ laptop như thói quen hằng ngày.
```

---

## 8. Quy trình chạy thật

Tạo branch:

```powershell
git checkout -b w10/terraform-foundation
```

Stage các file liên quan:

```powershell
git add cloud/w10/project-01-secure-operate-platform/infra/terraform/foundation
git add cloud/w10/project-01-secure-operate-platform/ci/github-actions
git add cloud/w10/guides
git add .github/workflows/w10-terraform-foundation.yml
```

Commit:

```powershell
git commit -m "feat: add w10 terraform foundation automation"
```

Push branch:

```powershell
git push origin w10/terraform-foundation
```

Mở Pull Request.

Trong PR, kiểm tra GitHub Actions:

```text
W10 Terraform Foundation / Terraform plan
```

Review plan:

```text
ECR repo đúng tên.
IAM role đúng tên.
Trust policy đúng repo/branch.
Không có destroy ngoài ý muốn.
```

Merge PR vào `main`.

Sau khi merge:

```text
GitHub Actions chạy apply.
Nếu environment w10-production yêu cầu approval, approve để apply chạy.
```

---

## 9. Kiểm tra sau khi CI apply xong

Local PowerShell:

```powershell
$env:AWS_REGION = "ap-southeast-1"
$env:ECR_REPO = "w10-api"
```

Kiểm tra ECR:

```powershell
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
```

Kiểm tra role policy:

```powershell
aws iam get-role-policy `
  --role-name github-actions-w10-ecr `
  --policy-name github-actions-w10-ecr-push
```

Kết quả đạt:

```text
ECR repo w10-api tồn tại.
Lifecycle policy tồn tại.
IAM role github-actions-w10-ecr tồn tại.
Role policy cho phép push/pull đúng ECR repo.
```

---

## 10. Nếu chưa có bootstrap role thì làm gì

Nếu chưa có role để gán vào `W10_TERRAFORM_ROLE_ARN`, workflow sẽ fail ở bước:

```text
Configure AWS credentials
```

Lúc này có 2 hướng:

### Hướng lab nhanh

Chạy local apply một lần:

```powershell
Set-Location E:\Xbrain\tf_learning\cloud\w10\project-01-secure-operate-platform\infra\terraform\foundation
terraform init
terraform plan
terraform apply
```

Sau đó lấy output:

```powershell
terraform output github_actions_role_arn
```

Gán ARN đó vào GitHub variable:

```text
W10_TERRAFORM_ROLE_ARN
```

Từ lúc này trở đi, không apply local nữa. Các thay đổi đi qua CI/CD.

### Hướng chuẩn hơn

Tạo riêng bootstrap role bằng platform/account bootstrap process, sau đó workflow dùng role đó để quản lý Terraform foundation.

Nói với mentor:

```text
Do đây là lab cá nhân, em bootstrap lần đầu bằng local apply để tạo role CI. Sau đó em chuyển sang PR plan và protected apply bằng GitHub Actions. Trong môi trường thật, bootstrap role nên do platform team hoặc account factory tạo trước.
```

---

## 11. Khi nào phần CI/CD apply hoàn thành

Hoàn thành khi đủ:

```text
.github/workflows/w10-terraform-foundation.yml tồn tại.
GitHub variable W10_TERRAFORM_ROLE_ARN đã cấu hình.
Environment w10-production đã có reviewer.
PR chạy terraform plan thành công.
Merge main chạy terraform apply thành công.
AWS CLI kiểm tra thấy ECR và IAM role đã tồn tại.
```

Kết luận ngắn:

```text
CI/CD Terraform apply là cầu nối giữa IaC và AWS foundation. Nó không phải GitOps/ArgoCD, vì ArgoCD chưa tồn tại ở bước này. GitOps bắt đầu quản lý Kubernetes resources sau khi EKS và ArgoCD đã được bootstrap.
```
