$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$InstallDir = "$env:USERPROFILE\grafana-dashboard"

Write-Host "=========================================="
Write-Host " Grafana Dashboard Installer for Windows"
Write-Host "=========================================="

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Set-Location $InstallDir

Write-Host "-> Downloading Grafana v11.1.0..."
Invoke-WebRequest -Uri "https://dl.grafana.com/oss/release/grafana-11.1.0.windows-amd64.zip" -OutFile "grafana.zip"
Expand-Archive -Path "grafana.zip" -DestinationPath "." -Force
Rename-Item -Path "grafana-v11.1.0" -NewName "grafana"
Remove-Item -Path "grafana.zip"

Write-Host "-> Downloading Prometheus v2.53.0..."
Invoke-WebRequest -Uri "https://github.com/prometheus/prometheus/releases/download/v2.53.0/prometheus-2.53.0.windows-amd64.zip" -OutFile "prometheus.zip"
Expand-Archive -Path "prometheus.zip" -DestinationPath "." -Force
Rename-Item -Path "prometheus-2.53.0.windows-amd64" -NewName "prometheus"
Remove-Item -Path "prometheus.zip"

Write-Host "-> Downloading Windows Exporter v0.25.1 (with GPU collector)..."
Invoke-WebRequest -Uri "https://github.com/prometheus-community/windows_exporter/releases/download/v0.25.1/windows_exporter-0.25.1-amd64.exe" -OutFile "windows_exporter.exe"

# ==========================================
#  GPU DETECTION
# ==========================================
$NvidiaInstalled = $false

Write-Host "-> Detecting GPU hardware..."
$nvidiaSmi = @(
    "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
    "$env:SystemRoot\System32\nvidia-smi.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($nvidiaSmi) {
    Write-Host "   NVIDIA GPU detected (nvidia-smi found at $nvidiaSmi)"
    Write-Host "   Downloading nvidia_gpu_exporter v1.5.0 for Windows..."
    Invoke-WebRequest -Uri "https://github.com/utkuozdemir/nvidia_gpu_exporter/releases/download/v1.5.0/nvidia_gpu_exporter_1.5.0_windows_x86_64.zip" -OutFile "nvidia_gpu_exporter.zip"
    Expand-Archive -Path "nvidia_gpu_exporter.zip" -DestinationPath "nvidia_gpu_exporter_tmp" -Force
    $exePath = Get-ChildItem -Path "nvidia_gpu_exporter_tmp" -Filter "nvidia_gpu_exporter.exe" -Recurse | Select-Object -First 1
    Move-Item -Path $exePath.FullName -Destination "$InstallDir\nvidia_gpu_exporter.exe" -Force
    Remove-Item -Path "nvidia_gpu_exporter_tmp" -Recurse -Force
    Remove-Item -Path "nvidia_gpu_exporter.zip"
    $NvidiaInstalled = $true
    Write-Host "   nvidia_gpu_exporter.exe installed. Metrics on port 9835."
} else {
    Write-Host "   No NVIDIA GPU detected — skipping nvidia_gpu_exporter."
    Write-Host "   AMD/Intel GPU metrics will be collected via windows_exporter GPU collector."
}

Write-Host "-> Copying configuration files..."
$ScriptDir = $PSScriptRoot
Copy-Item -Path "$ScriptDir\config\*" -Destination $InstallDir -Recurse -Force

Move-Item -Path "$InstallDir\prometheus.yml" -Destination "$InstallDir\prometheus\prometheus.yml" -Force
New-Item -ItemType Directory -Force -Path "$InstallDir\grafana\conf\provisioning\datasources" | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\grafana\conf\provisioning\dashboards" | Out-Null
Copy-Item -Path "$InstallDir\datasources\*" -Destination "$InstallDir\grafana\conf\provisioning\datasources\" -Recurse -Force
Copy-Item -Path "$InstallDir\dashboards\*" -Destination "$InstallDir\grafana\conf\provisioning\dashboards\" -Recurse -Force
Remove-Item -Path "$InstallDir\datasources" -Recurse -Force
Remove-Item -Path "$InstallDir\dashboards" -Recurse -Force

# Inject correct dashboard path
$DashboardsPath = "$InstallDir\grafana\conf\provisioning\dashboards"
$DashYml = "$InstallDir\grafana\conf\provisioning\dashboards\dashboards.yml"
(Get-Content $DashYml).Replace('DASHBOARDS_PATH_PLACEHOLDER', $DashboardsPath) | Set-Content $DashYml

# ==========================================
#  GENERATE start.bat
# ==========================================
Write-Host "-> Creating start.bat..."
$NvidiaLine = if ($NvidiaInstalled) { 'start /B "" nvidia_gpu_exporter.exe' } else { 'rem No NVIDIA GPU detected — skipping nvidia_gpu_exporter' }
$StartScript = @"
@echo off
cd /d "%~dp0"
echo Starting Windows Exporter (CPU, RAM, Disk, Network, GPU)...
start /B "" windows_exporter.exe --collectors.enabled=cpu,memory,net,gpu,os,logical_disk
echo Starting Prometheus...
start /B "" prometheus\prometheus.exe --config.file=prometheus\prometheus.yml --storage.tsdb.retention.time=1y
echo Starting Grafana...
cd grafana\bin
start /B "" grafana.exe server --homepath ..
cd ..\..
$NvidiaLine
echo All services started. Dashboard: http://localhost:3000
"@
Set-Content -Path "start.bat" -Value $StartScript

Copy-Item -Path "$ScriptDir\start-silent.vbs" -Destination $InstallDir -Force

# ==========================================
#  GENERATE stop.bat
# ==========================================
$StopScript = @"
@echo off
taskkill /F /IM windows_exporter.exe >nul 2>&1
taskkill /F /IM prometheus.exe >nul 2>&1
taskkill /F /IM grafana.exe >nul 2>&1
taskkill /F /IM nvidia_gpu_exporter.exe >nul 2>&1
echo All services stopped.
"@
Set-Content -Path "stop.bat" -Value $StopScript

Write-Host "=========================================="
Write-Host " Installation Complete!"
Write-Host " Run start-silent.vbs to launch invisibly"
Write-Host " Dashboard: http://localhost:3000"
Write-Host "=========================================="
