#!/bin/bash
# ============================================================================
# 快速部署脚本（包含域名和 HTTPS）
# ============================================================================

set -e

echo "========================================="
echo "  Django 项目快速部署（域名+HTTPS）"
echo "========================================="
echo ""

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "❌ 请使用 sudo 运行此脚本"
    echo "   sudo ./quick-deploy-with-https.sh"
    exit 1
fi

# ============================================================================
# 1. 检查并安装必要软件
# ============================================================================

echo "[1/10] 检查并安装必要软件..."

apt update
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib redis-server git curl certbot python3-certbot-nginx

echo "✅ 必要软件安装完成"
echo ""

# ============================================================================
# 2. 创建项目用户
# ============================================================================

echo "[2/10] 创建项目用户..."

if id "django" &>/dev/null; then
    echo "ℹ️  用户 django 已存在"
else
    adduser --gecos "" --disabled-password django
    usermod -aG sudo django
    echo "✅ 用户 django 创建完成"
fi

echo ""

# ============================================================================
# 3. 上传项目代码
# ============================================================================

echo "[3/10] 准备项目目录..."

PROJECT_DIR="/home/django/myproject"
mkdir -p ${PROJECT_DIR}

echo "请选择上传代码的方式："
echo "1. 使用 Git 克隆"
echo "2. 使用 SCP 上传（从本地）"
read -p "请选择 (1/2): " UPLOAD_METHOD

if [ "$UPLOAD_METHOD" = "1" ]; then
    read -p "请输入 Git 仓库地址: " GIT_REPO
    su - django -c "git clone ${GIT_REPO} ${PROJECT_DIR}"
else
    echo "请在本地执行以下命令上传代码："
    echo ""
    echo "  scp -r myproject/* root@$(hostname -I | awk '{print $1}'):${PROJECT_DIR}/"
    echo ""
    read -p "上传完成后按 Enter 继续..."
    chown -R django:django ${PROJECT_DIR}
fi

echo "✅ 项目代码准备完成"
echo ""

# ============================================================================
# 4. 配置虚拟环境
# ============================================================================

echo "[4/10] 配置虚拟环境..."

su - django -c "cd ${PROJECT_DIR} && python3 -m venv venv"

if [ -f "${PROJECT_DIR}/requirements-production.txt" ]; then
    su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements-production.txt"
else
    su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"
fi

echo "✅ 虚拟环境配置完成"
echo ""

# ============================================================================
# 5. 配置域名和 HTTPS
# ============================================================================

echo "[5/10] 配置域名和 HTTPS..."

# 复制配置脚本
cp setup-domain-https.sh ${PROJECT_DIR}/
chmod +x ${PROJECT_DIR}/setup-domain-https.sh

# 运行域名配置脚本
su - django -c "cd ${PROJECT_DIR} && sudo ./setup-domain-https.sh"

echo "✅ 域名和 HTTPS 配置完成"
echo ""

# ============================================================================
# 6. 配置 Systemd 服务
# ============================================================================

echo "[6/10] 配置 Systemd 服务..."

cat > /etc/systemd/system/myproject-daphne.service <<EOF
[Unit]
Description=Daphne ASGI server for myproject
After=network.target

[Service]
Type=notify
User=django
Group=django
WorkingDirectory=${PROJECT_DIR}
Environment="PATH=${PROJECT_DIR}/venv/bin"
EnvironmentFile=${PROJECT_DIR}/.env
ExecStart=${PROJECT_DIR}/venv/bin/daphne -b 127.0.0.1 -p 8000 myproject.asgi:application -v 2
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable myproject-daphne

echo "✅ Systemd 服务配置完成"
echo ""

# ============================================================================
# 7. 运行数据库迁移
# ============================================================================

echo "[7/10] 运行数据库迁移..."

su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && python manage.py migrate --noinput"

echo "✅ 数据库迁移完成"
echo ""

# ============================================================================
# 8. 收集静态文件
# ============================================================================

echo "[8/10] 收集静态文件..."

su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && python manage.py collectstatic --noinput"

echo "✅ 静态文件收集完成"
echo ""

# ============================================================================
# 9. 创建超级用户
# ============================================================================

echo "[9/10] 创建超级用户..."

su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && python manage.py shell -c \"
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(is_superuser=True).exists():
    print('需要创建超级用户')
\" || su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && python manage.py createsuperuser"

echo "✅ 超级用户检查完成"
echo ""

# ============================================================================
# 10. 启动服务
# ============================================================================

echo "[10/10] 启动服务..."

systemctl start myproject-daphne
systemctl start nginx

echo "✅ 服务启动完成"
echo ""

# ============================================================================
# 配置防火墙
# ============================================================================

echo "配置防火墙..."

if command -v ufw &> /dev/null; then
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    echo "✅ 防火墙配置完成"
else
    echo "ℹ️  UFW 未安装，跳过防火墙配置"
fi

echo ""

# ============================================================================
# 完成
# ============================================================================

echo "========================================="
echo "  🎉 部署完成！"
echo "========================================="
echo ""
echo "服务状态："
echo ""
echo "  Nginx:"
systemctl status nginx --no-pager | head -n 3
echo ""
echo "  Daphne:"
systemctl status myproject-daphne --no-pager | head -n 3
echo ""
echo "查看日志："
echo "  Nginx:   sudo tail -f /var/log/nginx/error.log"
echo "  Daphne:  sudo journalctl -u myproject-daphne -f"
echo ""
echo "常用命令："
echo "  重启服务: sudo systemctl restart myproject-daphne nginx"
echo "  更新代码: cd ${PROJECT_DIR} && git pull && source venv/bin/activate && python manage.py migrate && sudo systemctl restart myproject-daphne"
echo "  SSL续期: sudo certbot renew --dry-run"
echo ""
echo "========================================="
