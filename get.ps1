# Axios Supply Chain Attack Scanner — Remote Launcher
# Run this with:  irm https://raw.githubusercontent.com/SufficientDaikon/axios-scanner/main/get.ps1 | iex

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "  Downloading Axios Scanner..." -ForegroundColor Cyan
Write-Host ""

$scriptUrl = "https://raw.githubusercontent.com/SufficientDaikon/axios-scanner/main/axios-scanner.ps1"
$tempPath  = Join-Path $env:TEMP "axios-scanner.ps1"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $scriptUrl -OutFile $tempPath -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Host "  [ERROR] Failed to download scanner." -ForegroundColor Red
    Write-Host "  Check your internet connection and try again." -ForegroundColor Red
    Write-Host "  URL: $scriptUrl" -ForegroundColor Gray
    Write-Host ""
    return
}

if (-not (Test-Path $tempPath)) {
    Write-Host "  [ERROR] Download failed. File not found." -ForegroundColor Red
    return
}

$fileSize = (Get-Item $tempPath).Length
if ($fileSize -lt 1000) {
    Write-Host "  [ERROR] Downloaded file is too small ($fileSize bytes). May be corrupted." -ForegroundColor Red
    Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
    return
}

Write-Host "  Scanner downloaded ($fileSize bytes). Starting scan..." -ForegroundColor Green
Write-Host ""

& powershell -NoProfile -ExecutionPolicy Bypass -File $tempPath

# Clean up
Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
