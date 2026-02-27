#!/bin/bash
# ============================================================================
# Simple Deployment Script - Run on server
# ============================================================================

set -e

echo "========================================="
echo "  Simple Deployment"
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

echo "[1/12] Installing dependencies..."
apt update -qq
apt upgrade -yqq

apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib redis-server git curl certbot > /dev/null 2>&1

echo "Dependencies installed"
echo ""

# ============================================================================
# Step 2: Create user and directories
# ============================================================================

echo "[2/12] Creating user and directories..."

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

echo "[3/12] Setting up PostgreSQL..."

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
# Step 4: Copy requirements file
# ============================================================================

echo "[4/12] Copying requirements files..."

if [ -f "/tmp/requirements-production.txt" ]; then
    cp /tmp/requirements-production.txt /home/django/myproject/requirements-production.txt
    chown django:django /home/django/myproject/requirements-production.txt
fi

if [ -f "/tmp/requirements.txt" ]; then
    cp /tmp/requirements.txt /home/django/myproject/requirements.txt
    chown django:django /home/django/myproject/requirements.txt
fi

if [ ! -f "/tmp/requirements-production.txt" ] && [ ! -f "/tmp/requirements.txt" ]; then
    echo "ERROR: No requirements file found in /tmp/"
    exit 1
fi

echo "Requirements files copied"
echo ""

# ============================================================================
# Step 5: Setup virtual environment
# ============================================================================

echo "[5/12] Setting up virtual environment..."
su - django -c "cd /home/django/myproject && python3 -m venv venv"
echo "Virtual environment created"
echo ""

# ============================================================================
# Step 6: Install Python packages
# ============================================================================

echo "[6/12] Installing Python packages..."

# Check which requirements file to use
if [ -f "/home/django/myproject/requirements-production.txt" ]; then
    echo "Using requirements-production.txt"
    REQ_FILE="requirements-production.txt"
else
    echo "Using requirements.txt"
    REQ_FILE="requirements.txt"
fi

su - django -c "cd /home/django/myproject && source venv/bin/activate && pip install --upgrade pip -q && pip install -r $REQ_FILE -q"
echo "Python packages installed"
echo ""

# ============================================================================
# Step 7: Unzip project files
# ============================================================================

echo "[7/12] Extracting project files..."

if [ -f "/tmp/project.zip" ]; then
    su - django -c "unzip -q /tmp/project.zip -d /home/django/myproject && rm /tmp/project.zip"
    echo "Project files extracted"
else
    echo "WARNING: project.zip not found, skipping..."
fi
echo ""

# ============================================================================
# Step 8: Create environment file
# ============================================================================

echo "[8/12] Creating environment file..."

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
# Step 9: Run migrations
# ============================================================================

echo "[9/12] Running database migrations..."
su - django -c "cd /home/django/myproject && source venv/bin/activate && python manage.py migrate --noinput"
echo "Migrations complete"
echo ""

# ============================================================================
# Step 10: Collect static files
# ============================================================================

echo "[10/12] Collecting static files..."
su - django -c "cd /home/django/myproject && source venv/bin/activate && python manage.py collectstatic --noinput"
echo "Static files collected"
echo ""

# ============================================================================
# Step 11: Configure Nginx and SSL
# ============================================================================

echo "[11/12] Configuring Nginx..."

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

echo "Nginx configured and started"
echo ""

# Get SSL certificate
echo "Getting SSL certificate..."
certbot certonly --webroot -w /var/www/certbot -d bluepivot.net -d www.bluepivot.net --email admin@bluepivot.net --agree-tos --non-interactive

(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && systemctl reload nginx") | crontab -

echo "SSL certificate obtained"
echo ""

# ============================================================================
# Step 12: Configure Systemd service
# ============================================================================

echo "[12/12] Configuring Systemd service..."

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

# Configure firewall
echo "Configuring firewall..."
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
echo "Firewall configured"
echo ""

echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "Website: https://bluepivot.net"
echo "Admin:   https://bluepivot.net/admin"
echo ""
echo "Create superuser:"
echo "  su - django"
echo "  cd myproject"
echo "  source venv/bin/activate"
echo "  python manage.py createsuperuser"
echo ""
echo "View logs:"
echo "  Daphne:  sudo journalctl -u bluepivot-daphne -f"
echo "  Nginx:   sudo tail -f /var/log/nginx/error.log"
echo ""
