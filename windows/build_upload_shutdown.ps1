# -----------------------------------------------
# Build Docker, run upload script in venv, shutdown
# -----------------------------------------------

# Path to your project (scripts are in windows/, go up one level)
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# Docker Compose service name
$ServiceName = "pishrink"

# Path to venv Python
$VenvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"

# Path to upload script
$UploadScript = Join-Path $ProjectRoot "wait_upload.py"

# -----------------------------------------------
Write-Host "========================================"
Write-Host "Building Docker image and starting job"
Write-Host "========================================"

# Build and run container
docker compose up --build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build or run failed!" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "========================================"
Write-Host "Docker finished successfully"
Write-Host "Starting upload script"
Write-Host "========================================"

# Run Python script inside venv
& $VenvPython $UploadScript
if ($LASTEXITCODE -ne 0) {
    Write-Host "Upload failed - shutdown cancelled" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "========================================"
Write-Host "Upload complete"
Write-Host "System will shut down in 30 seconds"
Write-Host "========================================"

# Shutdown PC after 30 seconds
Stop-Computer -Force -Delay 30
