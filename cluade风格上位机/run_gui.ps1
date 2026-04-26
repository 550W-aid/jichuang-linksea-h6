$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pythonExe = Join-Path $projectRoot ".venv\\Scripts\\python.exe"

if (-not (Test-Path $pythonExe)) {
    Write-Host "Virtual environment not found. Please run setup first:" -ForegroundColor Yellow
    Write-Host "  python -m venv .venv" -ForegroundColor Yellow
    Write-Host "  .\\.venv\\Scripts\\python -m pip install -r requirements.txt" -ForegroundColor Yellow
    exit 1
}

Set-Location $projectRoot
& $pythonExe "main.py"
