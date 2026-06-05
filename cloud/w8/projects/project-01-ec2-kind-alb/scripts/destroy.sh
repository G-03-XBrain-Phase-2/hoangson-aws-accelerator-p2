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
KUBECONFIG_PATH="${PROJECT_ROOT}/generated/kubeconfig"

destroy_args=(destroy)
if [[ "${AUTO_APPROVE}" -eq 1 ]]; then
  destroy_args+=("-auto-approve")
fi

if [[ -f "${KUBECONFIG_PATH}" ]]; then
  node_port="$(terraform -chdir="${INFRA_DIR}" output -raw node_port)"

  echo "==> Destroying workloads stack"
  terraform -chdir="${WORKLOADS_DIR}" destroy \
    -var "kubeconfig_path=${KUBECONFIG_PATH}" \
    -var "node_port=${node_port}" \
    "${destroy_args[@]:1}"
else
  echo "Kubeconfig not found. Skipping workloads destroy. Continue only if workloads are already gone or cluster is unreachable."
fi

echo "==> Destroying infra stack"
terraform -chdir="${INFRA_DIR}" "${destroy_args[@]}"

echo "Destroy completed."
