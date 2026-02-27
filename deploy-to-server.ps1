# ============================================================================
# Auto Deployment Script for Tencent Cloud Server
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Deploy to Tencent Cloud Server" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Config
$SERVER = "1.14.208.141"
$USER = "root"
$PASSWORD = Read-Host "请输入服务器密码"
$DOMAIN = "bluepivot.net"
$PROJECT_DIR = "/home/django/myproject"

Write-Host "Server Info:" -ForegroundColor Yellow
Write-Host "  Address: $SERVER" -ForegroundColor Gray
Write-Host "  Domain: $DOMAIN" -ForegroundColor Gray
Write-Host ""

# Check required files
Write-Host "[1/7] Check required files..." -ForegroundColor Green

$files = @(
    ".env.domain",
    "nginx-domain.conf",
    "setup-domain-https.sh",
    "quick-deploy-with-https.sh"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "  OK: $file" -ForegroundColor Gray
    } else {
        Write-Host "  FAIL: $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Check project directory
Write-Host "[2/7] Check project directory..." -ForegroundColor Green

if (-not (Test-Path "myproject")) {
    Write-Host "  FAIL: myproject directory not found" -ForegroundColor Red
    exit 1
}

Write-Host "  OK: myproject directory exists" -ForegroundColor Gray
Write-Host ""

# Choose deployment method
Write-Host "Select deployment method:" -ForegroundColor Yellow
Write-Host "  1. Upload via SCP" -ForegroundColor Gray
Write-Host "  2. Clone via Git" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Choose (1/2)"

# SSH/SCP functions using OpenSSH (Windows 10+)
function Invoke-SSHCommand {
    param([string]$Command)

    $sshCmd = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $USER@$SERVER `"$Command`""
    Write-Host "Executing: $Command" -ForegroundColor DarkGray
    $result = Invoke-Expression $sshCmd 2>&1
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        Write-Host "  Error occurred (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
    return $result
}

function Invoke-SCPUpload {
    param(
        [string]$Source,
        [string]$Destination = "/home/django/"
    )

    Write-Host "Uploading: $Source -> $Destination" -ForegroundColor DarkGray
    $scpCmd = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $Source $USER@$SERVER`:$Destination"
    $result = Invoke-Expression $scpCmd 2>&1
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        Write-Host "  Upload failed (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
    return $result
}

# Check SSH tool
Write-Host "[3/7] Check SSH tool..." -ForegroundColor Green

try {
    $null = Get-Command ssh -ErrorAction Stop
    Write-Host "  OK: ssh is available" -ForegroundColor Gray
} catch {
    Write-Host "  FAIL: ssh not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install OpenSSH Client:" -ForegroundColor Yellow
    Write-Host "  Windows 10+: Settings -> Apps -> Optional Features -> OpenSSH Client" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# Test server connection
Write-Host "[4/7] Test server connection..." -ForegroundColor Green

try {
    $result = Invoke-SSHCommand "echo 'Connection successful'"
    if ($result -notmatch "Connection successful") {
        Write-Host "  FAIL: Connection failed" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  FAIL: Connection failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "  OK: Server connection successful" -ForegroundColor Gray
Write-Host ""

# Upload config files
Write-Host "[5/7] Upload config files..." -ForegroundColor Green

$configFiles = @(
    ".env.domain",
    "nginx-domain.conf",
    "setup-domain-https.sh",
    "quick-deploy-with-https.sh"
)

foreach ($file in $configFiles) {
    Write-Host "  Uploading $file..." -ForegroundColor DarkGray
    Invoke-SCPUpload $file
}

Write-Host "  OK: Config files uploaded" -ForegroundColor Gray
Write-Host ""

# Upload project code
Write-Host "[6/7] Upload project code..." -ForegroundColor Green

if ($choice -eq "1") {
    # Use SCP upload
    Write-Host "  Uploading project via SCP..." -ForegroundColor DarkGray
    Write-Host "  This may take a few minutes, please wait..." -ForegroundColor Yellow

    # Create temp zip
    $tempZip = "project_temp.zip"
    Compress-Archive -Path "myproject\*" -DestinationPath $tempZip -Force

    Invoke-SCPUpload $tempZip "/home/django/"
    Invoke-SSHCommand "unzip -q /home/django/$tempZip -d $PROJECT_DIR; rm /home/django/$tempZip"

    Remove-Item $tempZip -Force
} else {
    # Use Git
    Write-Host "  Will use Git to clone project on server" -ForegroundColor DarkGray
    Invoke-SSHCommand "mkdir -p /home/django/myproject"
    $gitUrl = Read-Host "Enter Git repository URL"
    Invoke-SSHCommand "cd /home/django; rm -rf myproject; git clone $gitUrl myproject"
}

Write-Host "  OK: Project code uploaded" -ForegroundColor Gray
Write-Host ""

# Execute deployment on server
Write-Host "[7/7] Execute deployment on server..." -ForegroundColor Green
Write-Host ""

Write-Host "Ready to run deployment script on server..." -ForegroundColor Yellow
Write-Host "This will automatically:" -ForegroundColor Gray
Write-Host "  - Install dependencies" -ForegroundColor Gray
Write-Host "  - Configure database" -ForegroundColor Gray
Write-Host "  - Get SSL certificate" -ForegroundColor Gray
Write-Host "  - Configure Nginx" -ForegroundColor Gray
Write-Host "  - Start services" -ForegroundColor Gray
Write-Host ""

$confirm = Read-Host "Continue? (y/n)"

if ($confirm -ne "y") {
    Write-Host "Deployment cancelled" -ForegroundColor Yellow
    exit 0
}

# Set script permissions
Write-Host "Setting script permissions..." -ForegroundColor DarkGray
Invoke-SSHCommand "chmod +x /home/django/setup-domain-https.sh"
Invoke-SSHCommand "chmod +x /home/django/quick-deploy-with-https.sh"

# Run deployment script
Write-Host ""
Write-Host "Starting deployment..." -ForegroundColor Yellow
Write-Host "(This may take 10-20 minutes, please wait)" -ForegroundColor Gray
Write-Host ""

Invoke-SSHCommand "cd /home/django; nohup bash quick-deploy-with-https.sh > deploy.log 2>&1 &"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Deployment script started" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "View deployment log:" -ForegroundColor Yellow
Write-Host "  ssh root@$SERVER" -ForegroundColor Gray
Write-Host "  tail -f /home/django/deploy.log" -ForegroundColor Gray
Write-Host ""
Write-Host "Or use:" -ForegroundColor Yellow
Write-Host "  ssh root@$SERVER 'tail -f /home/django/deploy.log'" -ForegroundColor Gray
Write-Host ""
Write-Host "After deployment, visit:" -ForegroundColor Yellow
Write-Host "  https://$DOMAIN" -ForegroundColor Gray
Write-Host "  https://$DOMAIN/admin" -ForegroundColor Gray
Write-Host ""
