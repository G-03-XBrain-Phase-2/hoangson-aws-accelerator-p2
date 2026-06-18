# GitHub Actions Templates

This folder stores workflow templates for the W10 project.

Important:

```text
GitHub only runs workflows from .github/workflows at the repository root.
```

So this project keeps the workflow source here for documentation and ownership, then the runnable copy should be placed at:

```text
.github/workflows/w10-terraform-foundation.yml
```

The Terraform foundation workflow expects this repository variable:

```text
W10_TERRAFORM_ROLE_ARN
```

That role must already exist before the workflow can assume it. In a real company, this role usually comes from an account bootstrap process, Terraform Cloud/Atlantis, or a platform-owned bootstrap stack.

For a lab, a one-time bootstrap apply can be acceptable, but after that all changes should go through PR plan and protected apply.

Available workflow templates:

| Template | Runnable copy |
|---|---|
| `terraform-foundation.yml` | `.github/workflows/w10-terraform-foundation.yml` |
| `terraform-eks.yml` | `.github/workflows/w10-terraform-eks.yml` |

The EKS workflow uses the same `W10_TERRAFORM_ROLE_ARN`, but that role must have enough permissions to manage VPC, EKS, EC2, IAM roles/policies for EKS, and related resources.

