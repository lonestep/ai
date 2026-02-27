#!/bin/bash
# ============================================================================
# Complete Deployment Script - Run this on the server
# ============================================================================

set -e

echo "========================================="
echo "  Complete Deployment for bluepivot.net"
echo "========================================="
echo ""

# Check if root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# ============================================================================
# Step 1: Install dependencies
# ============================================================================

echo "[1/13] Installing dependencies..."
apt update
apt upgrade -y

apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib redis-server git curl certbot

echo "Dependencies installed"
echo ""

# ============================================================================
# Step 2: Create user and directories
# ============================================================================

echo "[2/13] Creating user and directories..."

if id "django" &>/dev/null; then
    echo "User django already exists"
else
    adduser --gecos "" --disabled-password django
    usermod -aG sudo django
    echo "User django created"
fi

mkdir -p /home/django/myproject
mkdir -p /var/www/certbot
chown -R django:django /home/django

echo "Directories created"
echo ""

# ============================================================================
# Step 3: Setup database
# ============================================================================

echo "[3/13] Setting up PostgreSQL..."

sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS myprojectdb;
DROP USER IF EXISTS django_user;
CREATE DATABASE myprojectdb;
CREATE USER django_user WITH PASSWORD 'BluePivot2024!@#';
GRANT ALL PRIVILEGES ON DATABASE myprojectdb TO django_user;
\q
EOF

echo "Database setup complete"
echo ""

# ============================================================================
# Step 4: Setup virtual environment
# ============================================================================

echo "[4/13] Setting up virtual environment..."
cd /home/django/myproject

su - django -c "cd /home/django/myproject && python3 -m venv venv"

echo "Virtual environment created"
echo ""

# ============================================================================
# Step 5: Install Python packages
# ============================================================================

echo "[5/13] Installing Python packages..."

# Unzip project.zip if it exists
if [ -f "/home/django/project.zip" ]; then
    echo "Found project.zip, extracting..."
    su - django -c "unzip -q /home/django/project.zip -d /home/django/myproject && rm /home/django/project.zip"
fi

# Copy requirements files from /tmp if they exist
if [ -f "/tmp/requirements-production.txt" ]; then
    echo "Copying requirements-production.txt from /tmp..."
    cp /tmp/requirements-production.txt /home/django/myproject/
    chown django:django /home/django/myproject/requirements-production.txt
fi

# List files to debug
echo "Files in /home/django/myproject:"
ls -la /home/django/myproject/ | head -20

# Check if requirements files exist
if [ -f "/home/django/myproject/requirements-production.txt" ]; then
    echo "Using requirements-production.txt"
    REQ_FILE="/home/django/myproject/requirements-production.txt"
elif [ -f "/home/django/myproject/requirements.txt" ]; then
    echo "Using requirements.txt"
    REQ_FILE="/home/django/myproject/requirements.txt"
else
    echo "ERROR: requirements file not found in /home/django/myproject/"
    exit 1
fi

su - django -c "cd /home/django/myproject && source venv/bin/activate && pip install --upgrade pip && pip install -r $REQ_FILE"

echo "Python packages installed"
echo ""

# ============================================================================
# Step 6: Create environment file
# ============================================================================

echo "[6/13] Creating environment file..."

DB_PASS="BluePivot2024!@#"
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")

cat > /home/django/myproject/.env <<EOF
DEBUG=False
SECRET_KEY=${SECRET_KEY}
ALLOWED_HOSTS=bluepivot.net,www.bluepivot.net,1.14.208.141

DB_NAME=myprojectdb
DB_USER=django_user
DB_PASSWORD=${DB_PASS}
DB_HOST=localhost
DB_PORT=5432

REDIS_HOST=localhost
REDIS_PORT=6379

ADMIN_NAME=Admin
ADMIN_EMAIL=admin@bluepivot.net

LANGUAGE_CODE=zh-hans
TIME_ZONE=Asia/Shanghai
EOF

chmod 600 /home/django/myproject/.env

echo "Environment file created"
echo ""

# ============================================================================
# Step 7: Run migrations
# ============================================================================

echo "[7/13] Running database migrations..."

su - django -c "cd /home/django/myproject && source venv/bin/activate && python manage.py migrate --noinput"

echo "Migrations complete"
echo ""

# ============================================================================
# Step 8: Collect static files
# ============================================================================

echo "[8/13] Collecting static files..."

su - django -c "cd /home/django/myproject && source venv/bin/activate && python manage.py collectstatic --noinput"

echo "Static files collected"
echo ""

# ============================================================================
# Step 9: Configure Nginx
# ============================================================================

echo "[9/13] Configuring Nginx..."

cat > /etc/nginx/sites-available/bluepivot <<'NGINX_CONF'
server {
    listen 80;
    server_name bluepivot.net www.bluepivot.net;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name bluepivot.net www.bluepivot.net;

    ssl_certificate /etc/letsencrypt/live/bluepivot.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/bluepivot.net/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    client_max_body_size 20M;

    location /static/ {
        alias /home/django/myproject/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /home/django/myproject/media/;
        expires 30d;
    }

    location /health/ {
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        proxy_buffering off;
    }

    location /ws/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
    }

    location ~ /\. {
        deny all;
    }
}
NGINX_CONF

ln -sf /etc/nginx/sites-available/bluepivot /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl start nginx

echo "Nginx configured"
echo ""

# ============================================================================
# Step 10: Get SSL certificate
# ============================================================================

echo "[10/13] Getting SSL certificate..."

certbot certonly --webroot -w /var/www/certbot -d bluepivot.net -d www.bluepivot.net --email admin@bluepivot.net --agree-tos --non-interactive

(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

echo "SSL certificate obtained and auto-renewal configured"
echo ""

# ============================================================================
# Step 11: Configure Systemd service
# ============================================================================

echo "[11/13] Configuring Systemd service..."

cat > /etc/systemd/system/bluepivot-daphne.service <<EOF
[Unit]
Description=Daphne ASGI server for bluepivot
After=network.target

[Service]
Type=notify
User=django
Group=django
WorkingDirectory=/home/django/myproject
Environment="PATH=/home/django/myproject/venv/bin"
EnvironmentFile=/home/django/myproject/.env
ExecStart=/home/django/myproject/venv/bin/daphne -b 127.0.0.1 -p 8000 myproject.asgi:application -v 2
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable bluepivot-daphne
systemctl start bluepivot-daphne

echo "Systemd service configured and started"
echo ""

# ============================================================================
# Step 12: Configure firewall
# ============================================================================

echo "[12/13] Configuring firewall..."

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "Firewall configured"
echo ""

# ============================================================================
# Step 13: Verify services
# ============================================================================

echo "[13/13] Verifying services..."

echo ""
echo "Service status:"
echo ""

systemctl status nginx --no-pager | head -n 5
echo ""

systemctl status bluepivot-daphne --no-pager | head -n 5
echo ""

systemctl status postgresql --no-pager | head -n 5
echo ""

systemctl status redis-server --no-pager | head -n 5
echo ""

echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "Website: https://bluepivot.net"
echo "Admin:   https://bluepivot.net/admin"
echo ""
echo "Logs:"
echo "  Daphne:  sudo journalctl -u bluepivot-daphne -f"
echo "  Nginx:   sudo tail -f /var/log/nginx/error.log"
echo ""
echo "Create superuser:"
echo "  su - django"
echo "  cd myproject"
echo "  source venv/bin/activate"
echo "  python manage.py createsuperuser"
echo ""
