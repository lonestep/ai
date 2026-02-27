#!/bin/bash
# ============================================================================
# 自动域名和 HTTPS 配置脚本
# ============================================================================

set -e

echo "========================================="
echo "  域名和 HTTPS 自动配置"
echo "========================================="
echo ""

# ============================================================================
# 配置变量
# ============================================================================

read -p "请输入你的域名 (例如: example.com): " DOMAIN
read -p "请输入你的服务器 IP: " SERVER_IP
read -p "请输入项目目录 (默认: /home/django/myproject): " PROJECT_DIR
PROJECT_DIR=${PROJECT_DIR:-/home/django/myproject}

WWW_DOMAIN="www.${DOMAIN}"
USER="django"
GROUP="django"

echo ""
echo "配置信息："
echo "  域名: ${DOMAIN}"
echo "  WWW域名: ${WWW_DOMAIN}"
echo "  服务器IP: ${SERVER_IP}"
echo "  项目目录: ${PROJECT_DIR}"
echo ""
read -p "确认以上信息正确吗？(y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "配置取消"
    exit 1
fi

# ============================================================================
# 1. 生成强密码和密钥
# ============================================================================

echo "[1/8] 生成安全密钥..."

# 生成数据库密码
DB_PASSWORD=$(openssl rand -base64 32)
# 生成 Django SECRET_KEY
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")

echo "✅ 密钥生成完成"
echo ""

# ============================================================================
# 2. 创建 .env 文件
# ============================================================================

echo "[2/8] 创建环境变量文件..."

cat > ${PROJECT_DIR}/.env <<EOF
# ============================================================================
# 生产环境配置
# ============================================================================
# 生成时间: $(date)

# Django 设置
DEBUG=False
SECRET_KEY=${SECRET_KEY}
ALLOWED_HOSTS=${DOMAIN},${WWW_DOMAIN},${SERVER_IP}

# 数据库配置
DB_NAME=myprojectdb
DB_USER=django_user
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=localhost
DB_PORT=5432

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379

# 管理员配置
ADMIN_NAME=管理员
ADMIN_EMAIL=admin@${DOMAIN}

# 安全设置
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000

# 语言和时区
LANGUAGE_CODE=zh-hans
TIME_ZONE=Asia/Shanghai
EOF

chmod 600 ${PROJECT_DIR}/.env

echo "✅ 环境变量文件创建完成"
echo ""

# ============================================================================
# 3. 配置 PostgreSQL 数据库
# ============================================================================

echo "[3/8] 配置数据库..."

sudo -u postgres psql <<EOF
-- 创建数据库
CREATE DATABASE myprojectdb;

-- 创建用户并设置密码
CREATE USER django_user WITH PASSWORD '${DB_PASSWORD}';

-- 授权
GRANT ALL PRIVILEGES ON DATABASE myprojectdb TO django_user;

-- 退出
\q
EOF

echo "✅ 数据库配置完成"
echo ""

# ============================================================================
# 4. 创建 certbot 目录
# ============================================================================

echo "[4/8] 准备 SSL 证书目录..."

sudo mkdir -p /var/www/certbot
sudo chown -R ${USER}:${GROUP} /var/www/certbot

echo "✅ SSL 证书目录准备完成"
echo ""

# ============================================================================
# 5. 创建 Nginx 配置
# ============================================================================

echo "[5/8] 创建 Nginx 配置..."

cat > /etc/nginx/sites-available/myproject <<EOF
# HTTP 重定向到 HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} ${WWW_DOMAIN};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS 配置
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN} ${WWW_DOMAIN};

    # SSL 证书（稍后配置）
    # ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # 日志
    access_log /var/log/nginx/myproject_access.log;
    error_log /var/log/nginx/myproject_error.log;

    # 静态文件
    location /static/ {
        alias ${PROJECT_DIR}/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # 媒体文件
    location /media/ {
        alias ${PROJECT_DIR}/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # HTTP 请求
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        proxy_buffering off;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # WebSocket
    location /ws/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_read_timeout 86400;
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
    }

    # 健康检查
    location /health/ {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # 禁止访问隐藏文件
    location ~ /\./ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# 启用配置
sudo ln -sf /etc/nginx/sites-available/myproject /etc/nginx/sites-enabled/

# 删除默认配置（可选）
sudo rm -f /etc/nginx/sites-enabled/default

# 测试 Nginx 配置
sudo nginx -t

echo "✅ Nginx 配置创建完成"
echo ""

# ============================================================================
# 6. 临时启动 Nginx（HTTP 模式）
# ============================================================================

echo "[6/8] 启动 Nginx（HTTP 模式）..."

sudo systemctl restart nginx
sudo systemctl enable nginx

echo "✅ Nginx 已启动"
echo ""

# ============================================================================
# 7. 获取 SSL 证书
# ============================================================================

echo "[7/8] 获取 SSL 证书..."

sudo certbot certonly --webroot \
    -w /var/www/certbot \
    -d ${DOMAIN} \
    -d ${WWW_DOMAIN} \
    --email admin@${DOMAIN} \
    --agree-tos \
    --non-interactive

if [ $? -eq 0 ]; then
    echo "✅ SSL 证书获取成功"
else
    echo "⚠️  SSL 证书获取失败，请手动运行："
    echo "   sudo certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN} -d ${WWW_DOMAIN}"
    exit 1
fi

echo ""

# ============================================================================
# 8. 启用 HTTPS
# ============================================================================

echo "[8/8] 启用 HTTPS..."

# 取消 Nginx 配置中 SSL 证书的注释
sudo sed -i 's|# ssl_certificate|ssl_certificate|' /etc/nginx/sites-available/myproject
sudo sed -i 's|# ssl_certificate_key|ssl_certificate_key|' /etc/nginx/sites-available/myproject

# 重启 Nginx
sudo systemctl restart nginx

echo "✅ HTTPS 已启用"
echo ""

# ============================================================================
# 配置 SSL 自动续期
# ============================================================================

echo "配置 SSL 证书自动续期..."

# 添加 certbot-renew 到 crontab
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

echo "✅ SSL 自动续期已配置（每天凌晨 3 点检查）"
echo ""

# ============================================================================
# 完成
# ============================================================================

echo "========================================="
echo "  🎉 域名和 HTTPS 配置完成！"
echo "========================================="
echo ""
echo "配置信息："
echo "  域名: https://${DOMAIN}"
echo "  管理后台: https://${DOMAIN}/admin"
echo "  数据库密码: ${DB_PASSWORD}"
echo "  SECRET_KEY: ${SECRET_KEY}"
echo ""
echo "下一步操作："
echo ""
echo "1. 运行数据库迁移："
echo "   cd ${PROJECT_DIR}"
echo "   source venv/bin/activate"
echo "   python manage.py migrate"
echo ""
echo "2. 收集静态文件："
echo "   python manage.py collectstatic --noinput"
echo ""
echo "3. 创建超级用户："
echo "   python manage.py createsuperuser"
echo ""
echo "4. 重启 Daphne 服务："
echo "   sudo systemctl restart myproject-daphne"
echo ""
echo "5. 检查服务状态："
echo "   sudo systemctl status nginx"
echo "   sudo systemctl status myproject-daphne"
echo ""
echo "6. 测试访问："
echo "   https://${DOMAIN}"
echo ""
echo "7. 测试 HTTPS 评分："
echo "   访问 https://www.ssllabs.com/ssltest/analyze.html?d=${DOMAIN}"
echo ""
echo "========================================="
