# Upload files to server script
$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Upload Files to Server" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$SERVER = "1.14.208.141"
$USER = "root"

# Files to upload
$files = @(
    ".env.domain",
    "nginx-domain.conf",
    "setup-domain-https.sh",
    "quick-deploy-with-https.sh",
    "project.zip"
)

Write-Host "Files to upload:" -ForegroundColor Yellow
foreach ($file in $files) {
    Write-Host "  - $file" -ForegroundColor Gray
}
Write-Host ""

Write-Host "Please execute the following commands in PowerShell:" -ForegroundColor Green
Write-Host ""

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "scp $file ${USER}@${SERVER}:/home/django/" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "After uploading, SSH to the server and follow DEPLOY_STEPS.md" -ForegroundColor Yellow
