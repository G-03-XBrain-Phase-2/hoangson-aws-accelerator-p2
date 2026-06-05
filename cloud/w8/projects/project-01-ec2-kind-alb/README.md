# Project 01 - EC2 kind ALB

## Muc tieu

Dung Terraform de tao AWS infrastructure, bootstrap Kubernetes bang `kind` tren EC2, sau do dung Terraform Kubernetes provider de deploy mot web app nho va expose qua AWS ALB.

Project nay tap trung vao 3 y:

- Terraform quan ly AWS bang `aws` provider.
- EC2 tu tao kind cluster 3 node: 1 control-plane, 2 worker.
- Terraform quan ly Kubernetes workload bang `kubernetes` provider.

## Kien truc

```text
Internet
  -> AWS ALB :80
  -> Target Group instance target :30080
  -> EC2 host :30080
  -> kind port mapping
  -> Kubernetes Service NodePort 30080
  -> Deployment nginx, 2 replicas
```

```text
EC2 t3.small
  -> Docker
  -> kind cluster
       demo-kind-control-plane
       demo-kind-worker
       demo-kind-worker2
  -> demo-app pods spread across worker nodes
```

## Terraform stacks

```text
terraform/infra
  -> aws, tls, local providers
  -> VPC, public subnets, security groups
  -> EC2, IAM role for SSM, ALB, target group
  -> user_data installs Docker, kind, kubectl
  -> generated kubeconfig for local Terraform

terraform/workloads
  -> kubernetes provider
  -> Namespace, ConfigMap, Deployment, NodePort Service
```

Hai stack duoc tach rieng vi Kubernetes API chi san sang sau khi EC2 bootstrap xong kind cluster.

## Cau truc source

```text
project-01-ec2-kind-alb/
  scripts/
    deploy.ps1
    destroy.ps1
  terraform/
    infra/
      versions.tf
      providers.tf
      variables.tf
      network.tf
      security-groups.tf
      iam.tf
      ec2.tf
      alb.tf
      outputs.tf
      user-data.sh.tftpl
      terraform.tfvars.example
    workloads/
      versions.tf
      providers.tf
      variables.tf
      namespace.tf
      config.tf
      deployment.tf
      service.tf
      outputs.tf
      terraform.tfvars.example
```

Generated files nhu state, private key, kubeconfig, `.terraform/`, `terraform.tfvars` khong commit len git.

## Deploy

Tu thu muc project:

```powershell
Copy-Item terraform\infra\terraform.tfvars.example terraform\infra\terraform.tfvars
Copy-Item terraform\workloads\terraform.tfvars.example terraform\workloads\terraform.tfvars
```

Sua `terraform/infra/terraform.tfvars`:

Lay public IP hien tai cua may local:

```powershell
"$((Invoke-RestMethod https://checkip.amazonaws.com).Trim())/32"
```

Copy ket qua vao `admin_cidr`, vi du:

```hcl
admin_cidr = "203.0.113.10/32"
```

Deploy:

```powershell
.\scripts\deploy.ps1
```

Destroy:

```powershell
.\scripts\destroy.ps1
```

## Evidence

Huong dan evidence day du nam trong [EVIDENCE.md](EVIDENCE.md).

```powershell
kubectl --kubeconfig generated\kubeconfig get nodes -o wide
kubectl --kubeconfig generated\kubeconfig get pods -n demo-local -o wide
kubectl --kubeconfig generated\kubeconfig get svc -n demo-local -o wide
terraform -chdir=terraform\infra output -raw alb_url
```

Test web:

```powershell
$ALB_URL = terraform -chdir=terraform\infra output -raw alb_url
Invoke-WebRequest $ALB_URL
Invoke-WebRequest "$ALB_URL/healthz"
```

## Best practice trong lab

- Pin Terraform/provider versions.
- Tach `infra` va `workloads` de ro lifecycle.
- Khong hard-code AWS credentials.
- `admin_cidr` chi mo SSH `22` va Kubernetes API `6443` cho public IP cua ban.
- ALB public chi expose HTTP `80`; EC2 app port `30080` chi nhan traffic tu ALB security group.
- EC2 bat IMDSv2 va root volume encrypted gp3.
- EC2 co IAM role cho AWS Systems Manager Session Manager de debug khi can.
- Workload dung 2 replicas va topology spread de chung minh load balancing tren 2 worker node.
- `t3.small` duoc chon vi account sandbox chi cho instance type Free Tier eligible.

## Gioi han

Day la lab hoc Terraform va Kubernetes provider, khong phai production Kubernetes. Toan bo kind cluster nam tren mot EC2 nen EC2 van la single point of failure.
