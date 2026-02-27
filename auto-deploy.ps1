# ============================================================================
# 自动化部署脚本（非交互式）
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Django 项目自动部署" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 配置
$SERVER = "1.14.208.141"
$USER = "root"
$DOMAIN = "bluepivot.net"
$PROJECT_DIR = "/home/django/myproject"

Write-Host "服务器信息:" -ForegroundColor Yellow
Write-Host "  地址: $SERVER" -ForegroundColor Gray
Write-Host "  域名: $DOMAIN" -ForegroundColor Gray
Write-Host ""

# 检查文件
Write-Host "[1/6] 检查必需文件..." -ForegroundColor Green

$requiredFiles = @(
    ".env.domain",
    "nginx-domain.conf",
    "setup-domain-https.sh",
    "quick-deploy-with-https.sh"
)

$missingFiles = @()
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "  OK: $file" -ForegroundColor Gray
    } else {
        Write-Host "  FAIL: $file (缺失)" -ForegroundColor Red
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "错误: 缺少必需文件" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 检查项目目录
Write-Host "[2/6] 检查项目目录..." -ForegroundColor Green

if (-not (Test-Path "myproject")) {
    Write-Host "  FAIL: myproject 目录不存在" -ForegroundColor Red
    exit 1
}

Write-Host "  OK: myproject 目录存在" -ForegroundColor Gray
Write-Host ""

# 压缩项目
Write-Host "[3/6] 压缩项目文件..." -ForegroundColor Green
Write-Host "  正在压缩,请稍候..." -ForegroundColor Yellow

$zipFile = "project_deploy.zip"
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

Compress-Archive -Path "myproject\*" -DestinationPath $zipFile -Force

Write-Host "  OK: 项目压缩完成" -ForegroundColor Gray
Write-Host ""

# 上传文件
Write-Host "[4/6] 上传文件到服务器..." -ForegroundColor Green
Write-Host "  这可能需要几分钟..." -ForegroundColor Yellow

$uploadFiles = @(
    ".env.domain",
    "nginx-domain.conf",
    "setup-domain-https.sh",
    "quick-deploy-with-https.sh",
    $zipFile
)

foreach ($file in $uploadFiles) {
    $remotePath = "/home/django/" + $file
    Write-Host "  上传 $file..." -ForegroundColor DarkGray
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $file "${USER}@${SERVER}:${remotePath}"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAIL: 上传失败 $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host "  OK: 文件上传完成" -ForegroundColor Gray
Write-Host ""

# 在服务器上执行部署
Write-Host "[5/6] 在服务器上准备部署..." -ForegroundColor Green

$commands = @(
    "chmod +x /home/django/setup-domain-https.sh",
    "chmod +x /home/django/quick-deploy-with-https.sh",
    "unzip -q /home/django/project_deploy.zip -d $PROJECT_DIR",
    "rm /home/django/project_deploy.zip",
    "chown -R django:django $PROJECT_DIR"
)

foreach ($cmd in $commands) {
    Write-Host "  执行: $cmd" -ForegroundColor DarkGray
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${USER}@${SERVER}" "$cmd"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAIL: 命令失败 $cmd" -ForegroundColor Red
        exit 1
    }
}

Write-Host "  OK: 服务器准备完成" -ForegroundColor Gray
Write-Host ""

# 提示手动执行部署脚本
Write-Host "[6/6] 部署说明" -ForegroundColor Green
Write-Host ""
Write-Host "文件已上传完成!现在需要在服务器上执行部署脚本。" -ForegroundColor Yellow
Write-Host ""
Write-Host "请执行以下命令:" -ForegroundColor Cyan
Write-Host "  ssh ${USER}@${SERVER}" -ForegroundColor White
Write-Host "  cd /home/django" -ForegroundColor White
Write-Host "  sudo ./quick-deploy-with-https.sh" -ForegroundColor White
Write-Host ""
Write-Host "或者使用一键命令:" -ForegroundColor Cyan
Write-Host "  ssh ${USER}@${SERVER} 'cd /home/django && sudo bash quick-deploy-with-https.sh'" -ForegroundColor White
Write-Host ""
Write-Host "注意:" -ForegroundColor Yellow
Write-Host "  1. 确保域名 $DOMAIN 已解析到服务器 IP" -ForegroundColor Gray
Write-Host "  2. 部署过程可能需要 10-20 分钟" -ForegroundColor Gray
Write-Host "  3. 需要输入相关信息(如 Git 仓库地址等)" -ForegroundColor Gray
Write-Host ""
Write-Host "部署完成后访问:" -ForegroundColor Cyan
Write-Host "  https://$DOMAIN" -ForegroundColor White
Write-Host "  https://$DOMAIN/admin" -ForegroundColor White
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
