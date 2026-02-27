# ============================================================================
# 🚀 Windows 生产环境部署脚本 (PowerShell)
# ============================================================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Django 项目生产环境部署" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# 1. 检查环境
# ============================================================================

Write-Host "[1/8] 检查部署环境..." -ForegroundColor Yellow

if (-not (Test-Path ".env.production")) {
    Write-Host "❌ 未找到 .env.production 文件" -ForegroundColor Red
    Write-Host "请先复制 .env.production.example 并配置" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ 环境检查通过" -ForegroundColor Green
Write-Host ""

# ============================================================================
# 2. 检查 Python 版本
# ============================================================================

Write-Host "[2/8] 检查 Python 版本..." -ForegroundColor Yellow

$pythonVersion = python --version
Write-Host "Python 版本: $pythonVersion" -ForegroundColor Cyan

Write-Host "✅ Python 版本检查完成" -ForegroundColor Green
Write-Host ""

# ============================================================================
# 3. 创建虚拟环境
# ============================================================================

Write-Host "[3/8] 创建虚拟环境..." -ForegroundColor Yellow

if (-not (Test-Path "venv")) {
    python -m venv venv
    Write-Host "✅ 虚拟环境创建完成" -ForegroundColor Green
} else {
    Write-Host "ℹ️  虚拟环境已存在，跳过创建" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================================
# 4. 安装依赖
# ============================================================================

Write-Host "[4/8] 安装生产环境依赖..." -ForegroundColor Yellow

& "./venv/Scripts/Activate.ps1"
pip install --upgrade pip
pip install -r requirements-production.txt

Write-Host "✅ 依赖安装完成" -ForegroundColor Green
Write-Host ""

# ============================================================================
# 5. 配置环境变量
# ============================================================================

Write-Host "[5/8] 配置环境变量..." -ForegroundColor Yellow

if (-not (Test-Path ".env")) {
    Copy-Item ".env.production" ".env"
    Write-Host "✅ 环境变量配置完成" -ForegroundColor Green
} else {
    Write-Host "ℹ️  .env 文件已存在" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================================
# 6. 数据库迁移
# ============================================================================

Write-Host "[6/8] 运行数据库迁移..." -ForegroundColor Yellow

# 收集静态文件
python manage.py collectstatic --noinput

# 运行迁移
python manage.py migrate --noinput

Write-Host "✅ 数据库迁移完成" -ForegroundColor Green
Write-Host ""

# ============================================================================
# 7. 检查管理员账号
# ============================================================================

Write-Host "[7/8] 检查管理员账号..." -ForegroundColor Yellow

$hasAdmin = python -c "import os; os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'myproject.settings'); import django; django.setup(); from django.contrib.auth import get_user_model; User = get_user_model(); exit(0 if User.objects.filter(is_superuser=True).exists() else 1)"

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  未找到管理员账号，请手动创建：" -ForegroundColor Yellow
    Write-Host "   python manage.py createsuperuser" -ForegroundColor Cyan
} else {
    Write-Host "✅ 管理员账号已存在" -ForegroundColor Green
}

Write-Host ""

# ============================================================================
# 8. 运行安全检查
# ============================================================================

Write-Host "[8/8] 运行安全检查..." -ForegroundColor Yellow

Write-Host "运行 Django 安全检查..." -ForegroundColor Cyan
python manage.py check --deploy

Write-Host ""
Write-Host "检查依赖包安全漏洞..." -ForegroundColor Cyan
safety check

Write-Host ""
Write-Host "扫描 Python 代码安全问题..." -ForegroundColor Cyan
bandit -r . || Write-Host "⚠️  Bandit 扫描完成（可能发现问题）" -ForegroundColor Yellow

Write-Host ""

# ============================================================================
# 完成部署
# ============================================================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  🎉 部署完成！" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步操作：" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 启动 Daphne 服务器：" -ForegroundColor Cyan
Write-Host "   daphne myproject.asgi:application -b 127.0.0.1 -p 8000" -ForegroundColor White
Write-Host ""
Write-Host "2. 或使用 start_with_websocket.bat 启动" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. 配置反向代理（IIS/Nginx/Apache）" -ForegroundColor Cyan
Write-Host "   详见 SECURITY.md" -ForegroundColor White
Write-Host ""
Write-Host "4. 配置 HTTPS 证书" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. 配置防火墙规则" -ForegroundColor Cyan
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
