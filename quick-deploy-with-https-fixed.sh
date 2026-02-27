#!/bin/bash
# ============================================================================
# Quick Deployment Script (with Domain and HTTPS)
# ============================================================================

set -e

echo "========================================="
echo "  Django Quick Deployment with HTTPS"
echo "========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo"
    echo "   sudo bash quick-deploy-with-https.sh"
    exit 1
fi

# ============================================================================
# 1. Install required software
# ============================================================================

echo "[1/10] Installing required software..."

apt update
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib redis-server git curl certbot python3-certbot-nginx

echo "Software installation complete"
echo ""

# ============================================================================
# 2. Create project user
# ============================================================================

echo "[2/10] Creating project user..."

if id "django" &>/dev/null; then
    echo "User django already exists"
else
    adduser --gecos "" --disabled-password django
    usermod -aG sudo django
    echo "User django created"
fi

echo ""

# ============================================================================
# 3. Prepare project directory
# ============================================================================

echo "[3/10] Preparing project directory..."

PROJECT_DIR="/home/django/myproject"
mkdir -p ${PROJECT_DIR}

echo "Project directory: ${PROJECT_DIR}"
echo ""

# ============================================================================
# 4. Setup virtual environment
# ============================================================================

echo "[4/10] Setting up virtual environment..."

su - django -c "cd ${PROJECT_DIR} && python3 -m venv venv"

if [ -f "${PROJECT_DIR}/requirements-production.txt" ]; then
    su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements-production.txt"
else
    su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"
fi

echo "Virtual environment setup complete"
echo ""

# ============================================================================
# 5. Configure domain and HTTPS
# ============================================================================

echo "[5/10] Configuring domain and HTTPS..."

# Copy and setup configuration script
cp /home/django/setup-domain-https.sh ${PROJECT_DIR}/
chmod +x ${PROJECT_DIR}/setup-domain-https.sh

# Run domain configuration script
su - django -c "cd ${PROJECT_DIR} && sudo ./setup-domain-https.sh"

echo "Domain and HTTPS configuration complete"
echo ""

# ============================================================================
# 6. Configure Systemd service
# ============================================================================

echo "[6/10] Configuring Systemd service..."

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

echo "Systemd service configured"
echo ""

# ============================================================================
# 7. Run database migrations
# ============================================================================

echo "[7/10] Running database migrations..."

su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && python manage.py migrate --noinput"

echo "Database migrations complete"
echo ""

# ============================================================================
# 8. Collect static files
# ============================================================================

echo "[8/10] Collecting static files..."

su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && python manage.py collectstatic --noinput"

echo "Static files collection complete"
echo ""

# ============================================================================
# 9. Create superuser
# ============================================================================

echo "[9/10] Checking superuser..."

su - django -c "cd ${PROJECT_DIR} && source venv/bin/activate && python manage.py shell -c \"from django.contrib.auth import get_user_model; User = get_user_model(); print('Superuser exists' if User.objects.filter(is_superuser=True).exists() else 'Need to create superuser')\""

echo "Superuser check complete"
echo ""

# ============================================================================
# 10. Start services
# ============================================================================

echo "[10/10] Starting services..."

systemctl start myproject-daphne
systemctl start nginx

echo "Services started"
echo ""

# ============================================================================
# Configure firewall
# ============================================================================

echo "Configuring firewall..."

if command -v ufw &> /dev/null; then
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw --force enable
    echo "Firewall configured"
else
    echo "UFW not installed, skipping firewall configuration"
fi

echo ""

# ============================================================================
# Complete
# ============================================================================

echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""

echo "Service Status:"
echo ""
echo "  Nginx:"
systemctl status nginx --no-pager | head -n 3
echo ""
echo "  Daphne:"
systemctl status myproject-daphne --no-pager | head -n 3
echo ""

echo "View logs:"
echo "  Nginx:   sudo tail -f /var/log/nginx/error.log"
echo "  Daphne:  sudo journalctl -u myproject-daphne -f"
echo ""

echo "Common commands:"
echo "  Restart:  sudo systemctl restart myproject-daphne nginx"
echo "  Update:   cd ${PROJECT_DIR} && git pull && source venv/bin/activate && python manage.py migrate && sudo systemctl restart myproject-daphne"
echo "  SSL:      sudo certbot renew --dry-run"
echo ""

echo "========================================="
