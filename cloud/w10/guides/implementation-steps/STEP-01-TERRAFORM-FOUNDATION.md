# Step 01 - Terraform Foundation

> Mục tiêu của bước này là tạo nền AWS đầu tiên cho W10 bằng Terraform automation. Sau bước này, project có ECR repository để chứa image app và IAM role để GitHub Actions có thể push image lên ECR bằng OIDC, không cần AWS access key dài hạn.

---

## 1. Bức tranh của bước này

Trong W9, image được build trực tiếp vào Minikube:

```text
minikube image build
-> image nằm trong local cluster
```

Trong W10, luồng đúng hơn là:

```text
GitHub Actions
-> assume AWS role bằng OIDC
-> build image
-> scan image
-> push image lên ECR
-> sign image
-> ArgoCD deploy vào EKS
```

Vì vậy bước đầu tiên cần chuẩn bị:

```text
ECR repository
ECR lifecycle policy
GitHub OIDC provider
IAM role cho GitHub Actions
IAM permission tối thiểu để push/pull ECR
```

Không tạo các tài nguyên này bằng tay trên AWS Console. Terraform là source of truth, và đường triển khai chuẩn là PR -> CI plan -> review -> merge -> CD apply.

Lưu ý quan trọng:

```text
ArgoCD/GitOps không thể tạo ECR/EKS trước khi cluster và ArgoCD tồn tại.
Vì vậy AWS foundation đi qua Terraform automation.
Sau khi EKS + ArgoCD có mặt, Kubernetes resources mới đi qua GitOps/ArgoCD.
```

---

## 2. Folder và file liên quan

Toàn bộ code/config của bước này nằm trong project chính:

```text
cloud/w10/project-01-secure-operate-platform/infra/terraform/foundation/
  versions.tf
  variables.tf
  main.tf
  outputs.tf
  terraform.tfvars.example
```

Giải thích từng file:

| File | Cấu hình gì |
|---|---|
| `versions.tf` | Khai báo version Terraform và AWS provider |
| `variables.tf` | Khai báo các biến đầu vào: region, ECR repo, GitHub org/repo/branch |
| `main.tf` | Tạo ECR repo, lifecycle policy, GitHub OIDC provider, IAM role và IAM policy |
| `outputs.tf` | In ra AWS account ID, ECR repository URL và IAM role ARN |
| `terraform.tfvars.example` | File mẫu để tạo `terraform.tfvars` khi chạy thật |

Các file policy JSON tham khảo nằm ở:

```text
cloud/w10/project-01-secure-operate-platform/infra/reference-policies/
```

Nhóm file này chỉ để đọc/đối chiếu hoặc dùng lab CLI khi cần. Đường triển khai chính vẫn là Terraform.

Workflow template cho CI/CD nằm ở:

```text
cloud/w10/project-01-secure-operate-platform/ci/github-actions/terraform-foundation.yml
```

GitHub chỉ chạy workflow nếu file nằm ở `.github/workflows/`. Vì vậy file trong project là template/source để đưa lên workflow root khi bắt đầu chạy automation thật.

Hướng dẫn chi tiết phần CI/CD chạy `terraform apply` nằm ở:

```text
cloud/w10/guides/implementation-steps/STEP-01B-CICD-TERRAFORM-APPLY.md
```

---

## 3. Điều kiện trước khi làm

Đứng ở root repo:

```powershell
Set-Location E:\Xbrain\tf_learning
```

Kiểm tra tool:

```powershell
aws --version
terraform version
git --version
```

Giải thích:

| Lệnh | Vì sao cần |
|---|---|
| `aws --version` | Đảm bảo AWS CLI dùng được để kiểm tra account và tài nguyên |
| `terraform version` | Đảm bảo máy có Terraform để tạo hạ tầng |
| `git --version` | Đảm bảo repo có thể version control và commit thay đổi |

Kiểm tra AWS identity:

```powershell
aws sts get-caller-identity
```

Em cần nhìn kỹ:

```text
Account có đúng account lab không?
Arn có đúng user/role em đang dùng không?
```

Nếu sai account, dừng lại. Không chạy Terraform khi chưa chắc account.

Kiểm tra region:

```powershell
aws configure get region
```

Nếu chưa có region:

```powershell
aws configure set region ap-southeast-1
```

Giải thích:

```text
Phase W10 đang dùng ap-southeast-1 làm region mặc định.
Nếu region không thống nhất, ECR có thể tạo ở region này còn EKS ở region khác, sau đó pipeline sẽ rất khó debug.
```

---

## 4. Vào thư mục Terraform foundation

Chạy:

```powershell
Set-Location E:\Xbrain\tf_learning\cloud\w10\project-01-secure-operate-platform\infra\terraform\foundation
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

Giải thích:

```text
Đây là module foundation đầu tiên của project.
Nó không nằm trong guides vì đây là source/config thật của dự án.
```

---

## 5. Tạo file biến terraform.tfvars

Copy file mẫu:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Mở `terraform.tfvars` và kiểm tra các giá trị:

```hcl
aws_region          = "ap-southeast-1"
ecr_repository_name = "w10-api"
github_org          = "G-03-XBrain-Phase-2"
github_repo         = "hoangson-aws-accelerator-p2"
github_branch       = "main"
create_github_oidc_provider = true
```

Giải thích từng biến:

| Biến | Ý nghĩa |
|---|---|
| `aws_region` | Region AWS để tạo foundation |
| `ecr_repository_name` | Tên ECR repo chứa image app W10 |
| `github_org` | GitHub org/user sở hữu repo |
| `github_repo` | Tên repo được phép assume IAM role |
| `github_branch` | Branch được phép deploy/push image |
| `create_github_oidc_provider` | `true` nếu AWS account chưa có GitHub OIDC provider |

Quan trọng:

```text
Nếu AWS account đã có OIDC provider token.actions.githubusercontent.com, đặt create_github_oidc_provider = false.
Nếu để true trong khi provider đã tồn tại, Terraform có thể báo lỗi trùng provider.
```

Kiểm tra provider đã có chưa:

```powershell
aws iam list-open-id-connect-providers
```

Nếu output đã có provider liên quan `token.actions.githubusercontent.com`, cân nhắc đặt:

```hcl
create_github_oidc_provider = false
```

---

## 6. Quy trình automation chuẩn

Quy trình đúng trong dự án thực tế:

```text
1. Developer sửa Terraform trong branch riêng.
2. Mở Pull Request.
3. GitHub Actions chạy terraform fmt/validate/plan.
4. Team review plan.
5. Merge vào main.
6. GitHub Actions chạy terraform apply trong protected environment.
7. AWS resources được tạo/cập nhật.
8. AWS CLI chỉ dùng để kiểm tra kết quả.
```

Không nên coi `terraform apply` từ laptop là đường chính. Local apply chỉ chấp nhận trong 2 trường hợp:

```text
Lab đang mô phỏng nhanh.
Bootstrap lần đầu khi chưa có CI deployment role.
```

Vấn đề bootstrap:

```text
GitHub Actions muốn apply Terraform thì cần một AWS role để assume.
Nhưng role đó cũng là tài nguyên AWS.
Trong thực tế, role bootstrap này thường được tạo bởi platform team, Terraform Cloud/Atlantis, Control Tower, hoặc một stack bootstrap riêng.
Trong lab cá nhân, có thể apply một lần bằng credential admin/lab rồi sau đó chuyển toàn bộ thay đổi sang CI/CD.
```

---

## 7. Chạy kiểm tra Terraform local trước khi push

Các lệnh dưới đây dùng để kiểm tra trước khi commit. Chúng không thay thế CI.

### Terraform init

```powershell
terraform init
```

Lệnh này làm gì:

```text
Tải AWS provider.
Chuẩn bị thư mục .terraform.
Đọc cấu hình trong versions.tf.
```

Kết quả mong muốn:

```text
Terraform has been successfully initialized
```

Nếu lỗi network/provider:

```text
Kiểm tra internet.
Kiểm tra Terraform có bị proxy/firewall chặn không.
Chạy lại terraform init.
```

---

### Format và validate Terraform

Format:

```powershell
terraform fmt
```

Giải thích:

```text
Đưa code Terraform về format chuẩn để dễ review.
```

Validate:

```powershell
terraform validate
```

Giải thích:

```text
Kiểm tra syntax và cấu trúc Terraform trước khi plan.
Nếu validate lỗi, không chạy apply.
```

Kết quả mong muốn:

```text
Success! The configuration is valid.
```

---

### Xem terraform plan local

```powershell
terraform plan
```

Lệnh này làm gì:

```text
Terraform đọc code hiện tại.
So sánh với state.
In ra danh sách tài nguyên sẽ được tạo/sửa/xóa.
```

Trong plan, em cần thấy Terraform chuẩn bị tạo các nhóm tài nguyên sau:

```text
aws_ecr_repository.w10_api
aws_ecr_lifecycle_policy.w10_api
aws_iam_openid_connect_provider.github nếu create_github_oidc_provider = true
aws_iam_role.github_actions_ecr
aws_iam_role_policy.github_actions_ecr
```

Những điểm cần kiểm tra trong plan:

| Nội dung | Kỳ vọng |
|---|---|
| ECR repo name | `w10-api` |
| image tag mutability | `IMMUTABLE` |
| scan on push | `true` |
| lifecycle policy | expire untagged images older than 7 days |
| IAM role name | `github-actions-w10-ecr` |
| GitHub subject | đúng `org/repo:ref:refs/heads/main` |

Không chạy apply nếu thấy:

```text
Sai AWS account.
Sai GitHub org/repo.
Terraform định xóa tài nguyên ngoài ý muốn.
Provider OIDC bị tạo trùng.
```

---

## 8. Commit và mở Pull Request

Quay về root repo:

```powershell
Set-Location E:\Xbrain\tf_learning
```

Kiểm tra thay đổi:

```powershell
git status --short cloud/w10/project-01-secure-operate-platform/infra/terraform/foundation
git diff -- cloud/w10/project-01-secure-operate-platform/infra/terraform/foundation
```

Commit:

```powershell
git add cloud/w10/project-01-secure-operate-platform/infra/terraform/foundation
git commit -m "feat: add w10 terraform foundation"
git push origin <branch-name>
```

Sau đó mở Pull Request trên GitHub.

CI cần chạy:

```text
terraform fmt -check
terraform init
terraform validate
terraform plan
```

Mentor/team review cái quan trọng nhất là `terraform plan`, không chỉ nhìn workflow xanh.

---

## 9. Apply bằng CI/CD

Khi PR được merge vào `main`, workflow apply sẽ chạy trong protected environment.

Workflow template:

```text
cloud/w10/project-01-secure-operate-platform/ci/github-actions/terraform-foundation.yml
```

Để workflow chạy thật, cần đặt bản runnable ở:

```text
.github/workflows/w10-terraform-foundation.yml
```

Repository variable cần có:

```text
W10_TERRAFORM_ROLE_ARN
```

Giải thích:

```text
W10_TERRAFORM_ROLE_ARN là IAM role mà GitHub Actions assume bằng OIDC để chạy terraform plan/apply.
Role này nên là bootstrap/platform role đã có sẵn, hoặc được tạo một lần trong lab rồi dùng cho các lần sau.
```

Protected environment nên có:

```text
environment: w10-production
required reviewer
```

Mục tiêu:

```text
Plan chạy trên PR.
Apply chỉ chạy sau khi merge main và qua approval.
Không apply tùy tiện từ laptop.
```

---

## 10. Chỉ dùng terraform apply local khi bootstrap/lab

Nếu đây là lab cá nhân và chưa có CI role để apply, có thể chạy local apply một lần:

Trước khi chạy, phải chắc chắn:

```text
Đúng AWS account.
Đúng region.
Plan đã đọc kỹ.
Không có destroy ngoài ý muốn.
Đây là bootstrap/lab, không phải quy trình vận hành lâu dài.
```

Lệnh:

```powershell
terraform apply
```

Terraform sẽ hỏi xác nhận:

```text
Do you want to perform these actions?
```

Gõ:

```text
yes
```

Kết quả mong muốn:

```text
Apply complete!
```

Giải thích:

```text
Từ thời điểm này, AWS foundation do Terraform quản lý.
Sau bootstrap, các thay đổi tiếp theo phải đi qua PR và CI/CD.
```

---

## 11. Xem output sau apply

```powershell
terraform output
```

Kết quả cần có:

```text
aws_account_id
ecr_repository_url
github_actions_role_arn
```

Ý nghĩa:

| Output | Dùng để làm gì |
|---|---|
| `aws_account_id` | Xác nhận account Terraform đang thao tác |
| `ecr_repository_url` | URL image repo, dùng trong CI/CD |
| `github_actions_role_arn` | ARN role để GitHub Actions assume bằng OIDC |

Ví dụ ECR URL:

```text
<account>.dkr.ecr.ap-southeast-1.amazonaws.com/w10-api
```

Ví dụ role ARN:

```text
arn:aws:iam::<account>:role/github-actions-w10-ecr
```

---

## 12. Kiểm tra bằng AWS CLI

Quay lại root repo:

```powershell
Set-Location E:\Xbrain\tf_learning
```

Set biến kiểm tra:

```powershell
$env:AWS_REGION = "ap-southeast-1"
$env:ECR_REPO = "w10-api"
```

Kiểm tra ECR repo:

```powershell
aws ecr describe-repositories `
  --repository-names $env:ECR_REPO `
  --region $env:AWS_REGION
```

Em cần thấy:

```text
repositoryName: w10-api
imageTagMutability: IMMUTABLE
imageScanningConfiguration.scanOnPush: true
```

Kiểm tra lifecycle policy:

```powershell
aws ecr get-lifecycle-policy `
  --repository-name $env:ECR_REPO `
  --region $env:AWS_REGION
```

Em cần thấy:

```text
Expire untagged images older than 7 days
```

Kiểm tra IAM role:

```powershell
aws iam get-role --role-name github-actions-w10-ecr
```

Em cần thấy:

```text
AssumeRolePolicyDocument có token.actions.githubusercontent.com
Condition giới hạn đúng repo và branch
```

Kiểm tra permission policy:

```powershell
aws iam get-role-policy `
  --role-name github-actions-w10-ecr `
  --policy-name github-actions-w10-ecr-push
```

Em cần thấy:

```text
ecr:GetAuthorizationToken
ecr:PutImage
ecr:InitiateLayerUpload
ecr:UploadLayerPart
Resource trỏ đúng repository w10-api
```

---

## 13. Mô phỏng cách CI sẽ dùng foundation này

GitHub Actions ở bước sau sẽ dùng role ARN từ Terraform output.

Flow sẽ là:

```text
GitHub workflow chạy trên branch main
-> GitHub phát OIDC token
-> AWS STS kiểm tra trust policy
-> nếu org/repo/branch khớp thì cho assume role
-> workflow login ECR
-> workflow push image vào ECR w10-api
```

Vì sao cách này chuẩn:

```text
Không lưu AWS_ACCESS_KEY_ID trong GitHub Secrets.
Credential là short-lived.
IAM trust policy giới hạn đúng repo và branch.
Permission policy chỉ cho push/pull đúng ECR repo.
```

---

## 14. Nếu muốn test Docker login ECR từ local

Lấy account ID:

```powershell
$env:AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$env:ECR_REGISTRY = "$env:AWS_ACCOUNT_ID.dkr.ecr.$env:AWS_REGION.amazonaws.com"
```

Login:

```powershell
aws ecr get-login-password --region $env:AWS_REGION |
  docker login --username AWS --password-stdin $env:ECR_REGISTRY
```

Kết quả mong muốn:

```text
Login Succeeded
```

Lưu ý:

```text
Đây chỉ là test local xem ECR hoạt động.
Trong CI thật, GitHub Actions sẽ login bằng OIDC role.
```

---

## 15. Lỗi thường gặp

### Sai AWS account

Triệu chứng:

```text
Terraform tạo tài nguyên ở account khác.
AWS CLI kiểm tra không thấy tài nguyên vừa tạo.
```

Kiểm tra:

```powershell
aws sts get-caller-identity
```

### OIDC provider bị trùng

Triệu chứng:

```text
Error: EntityAlreadyExists
```

Cách xử lý:

```text
Kiểm tra aws iam list-open-id-connect-providers.
Nếu provider GitHub đã tồn tại, đặt create_github_oidc_provider = false.
```

### GitHub repo/branch sai trong trust policy

Triệu chứng:

```text
GitHub Actions không assume role được.
Lỗi sts:AssumeRoleWithWebIdentity.
```

Kiểm tra:

```text
github_org
github_repo
github_branch
```

### ECR repo đã tồn tại nhưng không trong Terraform state

Triệu chứng:

```text
RepositoryAlreadyExistsException
```

Cách xử lý đúng:

```text
Nếu tài nguyên đã tạo tay trước đó, import vào Terraform hoặc xóa rồi để Terraform tạo lại.
Không để cùng một tài nguyên vừa quản lý tay vừa quản lý Terraform.
```

### Terraform định xóa tài nguyên không mong muốn

Triệu chứng:

```text
terraform plan có dòng destroy.
```

Cách xử lý:

```text
Dừng lại.
Đọc kỹ plan.
Không apply khi chưa hiểu vì sao destroy xuất hiện.
```

---

## 16. Khi nào bước 1 được xem là xong

Bước 1 đạt khi đủ:

```text
terraform init chạy thành công.
terraform validate pass.
terraform plan được review trong PR hoặc local bootstrap.
terraform apply chạy bằng CI/CD, hoặc chỉ chạy local trong bootstrap/lab có ghi rõ.
terraform output có ECR URL và GitHub Actions role ARN.
aws ecr describe-repositories thấy repo w10-api.
aws ecr get-lifecycle-policy thấy policy dọn untagged image.
aws iam get-role thấy role github-actions-w10-ecr.
```

Kết luận có thể nói với mentor:

```text
Em đã tạo AWS foundation bằng Terraform theo hướng automation. ECR repo dùng để chứa image W10 đã có scan on push, immutable tag và lifecycle policy. Terraform changes đi qua PR/plan/apply bằng CI/CD, còn GitHub Actions sẽ dùng OIDC role để push image vào ECR mà không cần AWS access key dài hạn. Đây là nền để bước sau xây CI build, scan, sign và deploy image lên EKS.
```

---

## 17. Bước tiếp theo

Sau bước này, tiếp tục với:

```text
Step 02 - EKS cluster and kubeconfig
Step 03 - ArgoCD bootstrap and app-of-apps
Step 04 - Platform add-ons
Step 05 - CI build scan sign
Step 06 - App deployment
Step 07 - Security enforcement
```
