#!/usr/bin/env bash
set -euo pipefail

AUTO_APPROVE=0
case "${1:-}" in
  -auto-approve|--auto-approve)
    AUTO_APPROVE=1
    ;;
  "")
    ;;
  *)
    echo "Usage: $0 [--auto-approve]" >&2
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${PROJECT_ROOT}/terraform/infra"
WORKLOADS_DIR="${PROJECT_ROOT}/terraform/workloads"
GENERATED_DIR="${PROJECT_ROOT}/generated"

mkdir -p "${GENERATED_DIR}"

apply_args=(apply)
destroy_hint=""
if [[ "${AUTO_APPROVE}" -eq 1 ]]; then
  apply_args+=("-auto-approve")
  destroy_hint=" --auto-approve"
fi

resolve_stack_path() {
  local base_dir="$1"
  local path="$2"

  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    (
      cd "${base_dir}" >/dev/null
      cd "$(dirname "${path}")" >/dev/null
      printf '%s/%s\n' "$(pwd)" "$(basename "${path}")"
    )
  fi
}

echo "==> Initializing infra stack"
terraform -chdir="${INFRA_DIR}" init

echo "==> Applying infra stack"
terraform -chdir="${INFRA_DIR}" "${apply_args[@]}"

instance_ip="$(terraform -chdir="${INFRA_DIR}" output -raw instance_public_ip)"
key_path="$(terraform -chdir="${INFRA_DIR}" output -raw ssh_private_key_path)"
key_path="$(resolve_stack_path "${INFRA_DIR}" "${key_path}")"
node_port="$(terraform -chdir="${INFRA_DIR}" output -raw node_port)"
alb_dns="$(terraform -chdir="${INFRA_DIR}" output -raw alb_dns_name)"
kubeconfig_path="${GENERATED_DIR}/kubeconfig"

chmod 600 "${key_path}"

echo "==> Fetching kubeconfig from EC2"
ssh -o StrictHostKeyChecking=accept-new -i "${key_path}" "ec2-user@${instance_ip}" \
  "sudo cat /opt/demo-kind/kubeconfig" > "${kubeconfig_path}"

echo "==> Initializing workloads stack"
terraform -chdir="${WORKLOADS_DIR}" init

echo "==> Applying workloads stack with Kubernetes provider"
terraform -chdir="${WORKLOADS_DIR}" apply \
  -var "kubeconfig_path=${kubeconfig_path}" \
  -var "node_port=${node_port}" \
  "${apply_args[@]:1}"

echo
echo "Deployment completed."
echo "ALB URL: http://${alb_dns}"
echo "Kubeconfig: ${kubeconfig_path}"
echo "Destroy command: ./scripts/destroy.sh${destroy_hint}"
