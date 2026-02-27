#!/bin/bash
# ============================================================================
# Domain and HTTPS Auto-Configuration Script
# ============================================================================

set -e

echo "========================================="
echo "  Domain and HTTPS Configuration"
echo "========================================="
echo ""

# ============================================================================
# Configuration variables
# ============================================================================

DOMAIN="bluepivot.net"
WWW_DOMAIN="www.bluepivot.net"
SERVER_IP="1.14.208.141"
PROJECT_DIR="/home/django/myproject"
USER="django"
GROUP="django"

echo "Configuration:"
echo "  Domain: ${DOMAIN}"
echo "  WWW Domain: ${WWW_DOMAIN}"
echo "  Server IP: ${SERVER_IP}"
echo "  Project Dir: ${PROJECT_DIR}"
echo ""

# ============================================================================
# 1. Generate secure keys
# ============================================================================

echo "[1/8] Generating secure keys..."

# Generate database password
DB_PASSWORD=$(openssl rand -base64 32)
# Generate Django SECRET_KEY
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")

echo "Keys generated"
echo ""

# ============================================================================
# 2. Create .env file
# ============================================================================

echo "[2/8] Creating environment file..."

cat > ${PROJECT_DIR}/.env <<EOF
# Production Environment
# Generated: $(date)

# Django settings
DEBUG=False
SECRET_KEY=${SECRET_KEY}
ALLOWED_HOSTS=${DOMAIN},${WWW_DOMAIN},${SERVER_IP}

# Database configuration
DB_NAME=myprojectdb
DB_USER=django_user
DB_PASSWORD=${DB_PASSWORD}
DB_HOST=localhost
DB_PORT=5432

# Redis configuration
REDIS_HOST=localhost
REDIS_PORT=6379

# Admin configuration
ADMIN_NAME=Admin
ADMIN_EMAIL=admin@${DOMAIN}

# Security settings
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000

# Language and timezone
LANGUAGE_CODE=zh-hans
TIME_ZONE=Asia/Shanghai
EOF

chmod 600 ${PROJECT_DIR}/.env

echo "Environment file created"
echo ""

# ============================================================================
# 3. Configure PostgreSQL
# ============================================================================

echo "[3/8] Configuring database..."

sudo -u postgres psql <<EOF
CREATE DATABASE myprojectdb;
CREATE USER django_user WITH PASSWORD '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE myprojectdb TO django_user;
\q
EOF

echo "Database configured"
echo ""

# ============================================================================
# 4. Create certbot directory
# ============================================================================

echo "[4/8] Preparing SSL certificate directory..."

mkdir -p /var/www/certbot
chown -R ${USER}:${GROUP} /var/www/certbot

echo "SSL directory prepared"
echo ""

# ============================================================================
# 5. Create Nginx configuration
# ============================================================================

echo "[5/8] Creating Nginx configuration..."

cat > /etc/nginx/sites-available/bluepivot <<EOF
# HTTP to HTTPS redirect
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

# HTTPS configuration
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN} ${WWW_DOMAIN};

    # SSL certificates
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/bluepivot_access.log;
    error_log /var/log/nginx/bluepivot_error.log;

    # Client upload size
    client_max_body_size 20M;

    # Static files
    location /static/ {
        alias ${PROJECT_DIR}/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Media files
    location /media/ {
        alias ${PROJECT_DIR}/media/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Health check
    location /health/ {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # HTTP requests proxy to Daphne
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

    # WebSocket support
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

    # Deny hidden files
    location ~ /\./ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# Enable configuration
ln -sf /etc/nginx/sites-available/bluepivot /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
nginx -t

echo "Nginx configuration created"
echo ""

# ============================================================================
# 6. Start Nginx (HTTP mode first)
# ============================================================================

echo "[6/8] Starting Nginx (HTTP mode)..."

systemctl restart nginx
systemctl enable nginx

echo "Nginx started"
echo ""

# ============================================================================
# 7. Get SSL certificate
# ============================================================================

echo "[7/8] Getting SSL certificate..."

certbot certonly --webroot \
    -w /var/www/certbot \
    -d ${DOMAIN} \
    -d ${WWW_DOMAIN} \
    --email admin@${DOMAIN} \
    --agree-tos \
    --non-interactive

if [ $? -eq 0 ]; then
    echo "SSL certificate obtained"
else
    echo "SSL certificate failed. Manual setup required:"
    echo "  sudo certbot certonly --webroot -w /var/www/certbot -d ${DOMAIN} -d ${WWW_DOMAIN}"
    exit 1
fi

echo ""

# ============================================================================
# 8. Enable HTTPS
# ============================================================================

echo "[8/8] Enabling HTTPS..."

# Restart Nginx to enable HTTPS
systemctl restart nginx

echo "HTTPS enabled"
echo ""

# ============================================================================
# Configure SSL auto-renewal
# ============================================================================

echo "Configuring SSL auto-renewal..."

# Add certbot-renew to crontab
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

echo "SSL auto-renewal configured (daily at 3 AM)"
echo ""

# ============================================================================
# Complete
# ============================================================================

echo "========================================="
echo "  Domain and HTTPS Configuration Complete!"
echo "========================================="
echo ""

echo "Configuration info:"
echo "  Domain: https://${DOMAIN}"
echo "  Admin: https://${DOMAIN}/admin"
echo "  DB Password: ${DB_PASSWORD}"
echo ""

echo "Next steps:"
echo ""
echo "1. Run migrations:"
echo "   cd ${PROJECT_DIR}"
echo "   source venv/bin/activate"
echo "   python manage.py migrate"
echo ""
echo "2. Collect static:"
echo "   python manage.py collectstatic --noinput"
echo ""
echo "3. Create superuser:"
echo "   python manage.py createsuperuser"
echo ""
echo "4. Restart Daphne:"
echo "   sudo systemctl restart myproject-daphne"
echo ""
echo "5. Check services:"
echo "   sudo systemctl status nginx"
echo "   sudo systemctl status myproject-daphne"
echo ""
echo "========================================="
