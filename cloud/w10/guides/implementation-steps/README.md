# W10 Implementation Steps

Folder này chứa tài liệu hướng dẫn triển khai theo từng bước vận hành thực tế.

Các file trong folder này chỉ là tài liệu hướng dẫn. Source code, Terraform, manifest, policy và pipeline thật nằm trong:

```text
cloud/w10/project-01-secure-operate-platform/
```

Danh sách bước:

| Bước | File | Mục tiêu |
|---|---|---|
| 01 | `STEP-01-TERRAFORM-FOUNDATION.md` | Tạo AWS foundation bằng Terraform: ECR, lifecycle policy, GitHub OIDC provider, IAM role cho CI |
| 01B | `STEP-01B-CICD-TERRAFORM-APPLY.md` | Thiết lập GitHub Actions để PR chạy Terraform plan và merge main chạy Terraform apply |
| 02 | `STEP-02-EKS-CLUSTER.md` | Tạo EKS cluster bằng Terraform automation và cấu hình kubeconfig |

Nguyên tắc:

```text
Guides giải thích cách làm.
Project folder chứa source/config để chạy thật.
Không tạo source code theo phase học tập.
```
