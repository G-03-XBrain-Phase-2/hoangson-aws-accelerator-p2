param(
  [Alias("auto-approve")]
  [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

function Invoke-Native {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
  )

  & $FilePath @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
  }
}

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$InfraDir = Join-Path $ProjectRoot "terraform\infra"
$WorkloadsDir = Join-Path $ProjectRoot "terraform\workloads"
$KubeconfigPath = Join-Path $ProjectRoot "generated\kubeconfig"

$destroyArgs = @("destroy")
if ($AutoApprove) {
  $destroyArgs += "-auto-approve"
}

if (Test-Path $KubeconfigPath) {
  $NodePort = & terraform "-chdir=$InfraDir" output -raw node_port
  if ($LASTEXITCODE -ne 0) { throw "Failed to read infra output: node_port" }
  Write-Host "==> Destroying workloads stack"
  $workloadDestroyArgs = @("destroy", "-var", "kubeconfig_path=$KubeconfigPath", "-var", "node_port=$NodePort")
  if ($AutoApprove) {
    $workloadDestroyArgs += "-auto-approve"
  }
  Invoke-Native terraform "-chdir=$WorkloadsDir" @workloadDestroyArgs
} else {
  Write-Host "Kubeconfig not found. Skipping workloads destroy. Continue only if workloads are already gone or cluster is unreachable."
}

Write-Host "==> Destroying infra stack"
Invoke-Native terraform "-chdir=$InfraDir" @destroyArgs

Write-Host "Destroy completed."
