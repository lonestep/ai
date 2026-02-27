#!/bin/bash
# ============================================================================
# 🚀 生产环境部署脚本
# ============================================================================

set -e  # 遇到错误立即退出

echo "========================================="
echo "  Django 项目生产环境部署"
echo "========================================="
echo ""

# ============================================================================
# 配置变量
# ============================================================================

PROJECT_NAME="myproject"
PROJECT_DIR="/var/www/${PROJECT_NAME}"
VENV_DIR="${PROJECT_DIR}/venv"
USER="www-data"
GROUP="www-data"

# ============================================================================
# 1. 检查环境
# ============================================================================

echo "[1/8] 检查部署环境..."

if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 sudo 运行此脚本"
    exit 1
fi

if [ ! -f ".env.production" ]; then
    echo "❌ 未找到 .env.production 文件"
    echo "请先复制 .env.production.example 并配置"
    exit 1
fi

echo "✅ 环境检查通过"
echo ""

# ============================================================================
# 2. 创建项目目录
# ============================================================================

echo "[2/8] 创建项目目录..."

mkdir -p ${PROJECT_DIR}
mkdir -p ${PROJECT_DIR}/logs

echo "✅ 项目目录创建完成"
echo ""

# ============================================================================
# 3. 创建虚拟环境
# ============================================================================

echo "[3/8] 创建虚拟环境..."

if [ ! -d "${VENV_DIR}" ]; then
    python3 -m venv ${VENV_DIR}
    echo "✅ 虚拟环境创建完成"
else
    echo "ℹ️  虚拟环境已存在，跳过创建"
fi

echo ""

# ============================================================================
# 4. 安装依赖
# ============================================================================

echo "[4/8] 安装生产环境依赖..."

source ${VENV_DIR}/bin/activate
pip install --upgrade pip
pip install -r requirements-production.txt

echo "✅ 依赖安装完成"
echo ""

# ============================================================================
# 5. 配置环境变量
# ============================================================================

echo "[5/8] 配置环境变量..."

cp .env.production ${PROJECT_DIR}/.env
chmod 600 ${PROJECT_DIR}/.env

echo "✅ 环境变量配置完成"
echo ""

# ============================================================================
# 6. 数据库迁移
# ============================================================================

echo "[6/8] 运行数据库迁移..."

cd ${PROJECT_DIR}

# 设置环境变量
export $(cat .env | xargs)

# 收集静态文件
python manage.py collectstatic --noinput

# 运行迁移
python manage.py migrate --noinput

echo "✅ 数据库迁移完成"
echo ""

# ============================================================================
# 7. 创建超级用户（如果不存在）
# ============================================================================

echo "[7/8] 检查管理员账号..."

if ! python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); exit(0 if User.objects.filter(is_superuser=True).exists() else 1)"; then
    echo "创建超级用户..."
    python manage.py createsuperuser
else
    echo "ℹ️  管理员账号已存在"
fi

echo ""

# ============================================================================
# 8. 配置 systemd 服务
# ============================================================================

echo "[8/8] 配置系统服务..."

# Daphne 服务
cat > /etc/systemd/system/${PROJECT_NAME}-daphne.service <<EOF
[Unit]
Description=Daphne ASGI server for ${PROJECT_NAME}
After=network.target

[Service]
Type=notify
User=${USER}
Group=${GROUP}
WorkingDirectory=${PROJECT_DIR}
Environment="PATH=${VENV_DIR}/bin"
ExecStart=${VENV_DIR}/bin/daphne -b 127.0.0.1 -p 8000 myproject.asgi:application -v 2
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
systemctl daemon-reload
systemctl enable ${PROJECT_NAME}-daphne

echo "✅ 系统服务配置完成"
echo ""

# ============================================================================
# 完成部署
# ============================================================================

echo "========================================="
echo "  🎉 部署完成！"
echo "========================================="
echo ""
echo "下一步操作："
echo ""
echo "1. 启动服务："
echo "   sudo systemctl start ${PROJECT_NAME}-daphne"
echo ""
echo "2. 查看状态："
echo "   sudo systemctl status ${PROJECT_NAME}-daphne"
echo ""
echo "3. 查看日志："
echo "   sudo journalctl -u ${PROJECT_NAME}-daphne -f"
echo ""
echo "4. 配置 Nginx（见 SECURITY.md）"
echo ""
echo "5. 运行安全检查："
echo "   python manage.py check --deploy"
echo "   safety check"
echo "   bandit -r ."
echo ""
echo "========================================="
