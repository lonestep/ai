# Upload and Deploy Script
# Run this from Windows PowerShell

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Upload and Deploy to Server" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$SERVER = "1.14.208.141"
$USER = "root"

# Step 1: Compress project
Write-Host "[Step 1/3] Compressing project..." -ForegroundColor Green
Compress-Archive -Path "myproject\*" -DestinationPath "project.zip" -Force
Write-Host "Project compressed to project.zip" -ForegroundColor Gray
Write-Host ""

# Step 2: Upload files
Write-Host "[Step 2/3] Upload files to server..." -ForegroundColor Green
Write-Host "Please execute the following command to upload:" -ForegroundColor Yellow
Write-Host ""

Write-Host "scp project.zip deploy-complete.sh ${USER}@${SERVER}:/tmp/" -ForegroundColor Cyan
Write-Host ""
Write-Host "After uploading, connect to server:" -ForegroundColor Yellow
Write-Host "ssh ${USER}@${SERVER}" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then run deployment script:" -ForegroundColor Yellow
Write-Host "sudo bash /tmp/deploy-complete.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
