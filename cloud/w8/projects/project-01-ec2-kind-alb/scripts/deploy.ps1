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

function Resolve-StackPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$BaseDir,
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return (Resolve-Path $Path).Path
  }

  return (Resolve-Path (Join-Path $BaseDir $Path)).Path
}

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$InfraDir = Join-Path $ProjectRoot "terraform\infra"
$WorkloadsDir = Join-Path $ProjectRoot "terraform\workloads"
$GeneratedDir = Join-Path $ProjectRoot "generated"

New-Item -ItemType Directory -Force -Path $GeneratedDir | Out-Null

$applyArgs = @("apply")
if ($AutoApprove) {
  $applyArgs += "-auto-approve"
}

Write-Host "==> Initializing infra stack"
Invoke-Native terraform "-chdir=$InfraDir" init

Write-Host "==> Applying infra stack"
Invoke-Native terraform "-chdir=$InfraDir" @applyArgs

$InstanceIp = & terraform "-chdir=$InfraDir" output -raw instance_public_ip
if ($LASTEXITCODE -ne 0) { throw "Failed to read infra output: instance_public_ip" }
$KeyPath = & terraform "-chdir=$InfraDir" output -raw ssh_private_key_path
if ($LASTEXITCODE -ne 0) { throw "Failed to read infra output: ssh_private_key_path" }
$KeyPath = Resolve-StackPath -BaseDir $InfraDir -Path $KeyPath
$NodePort = & terraform "-chdir=$InfraDir" output -raw node_port
if ($LASTEXITCODE -ne 0) { throw "Failed to read infra output: node_port" }
$AlbDns = & terraform "-chdir=$InfraDir" output -raw alb_dns_name
if ($LASTEXITCODE -ne 0) { throw "Failed to read infra output: alb_dns_name" }
$KubeconfigPath = Join-Path $GeneratedDir "kubeconfig"

$IsWindowsHost = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
if ($IsWindowsHost) {
  icacls $KeyPath /inheritance:r | Out-Null
  icacls $KeyPath /grant:r "$($env:USERNAME):R" | Out-Null
}

Write-Host "==> Fetching kubeconfig from EC2"
$KubeconfigContent = & ssh -o StrictHostKeyChecking=accept-new -i $KeyPath "ec2-user@$InstanceIp" "sudo cat /opt/demo-kind/kubeconfig"
if ($LASTEXITCODE -ne 0) {
  throw "Failed to fetch kubeconfig from EC2."
}
$KubeconfigContent | Set-Content -Encoding ascii -Path $KubeconfigPath

Write-Host "==> Initializing workloads stack"
Invoke-Native terraform "-chdir=$WorkloadsDir" init

Write-Host "==> Applying workloads stack with Kubernetes provider"
$workloadApplyArgs = @("apply", "-var", "kubeconfig_path=$KubeconfigPath", "-var", "node_port=$NodePort")
if ($AutoApprove) {
  $workloadApplyArgs += "-auto-approve"
}
Invoke-Native terraform "-chdir=$WorkloadsDir" @workloadApplyArgs

Write-Host ""
Write-Host "Deployment completed."
Write-Host "ALB URL: http://$AlbDns"
Write-Host "Kubeconfig: $KubeconfigPath"
