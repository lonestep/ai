# 部署步骤 - 腾讯云服务器 bluepivot.net

## 服务器信息
- IP: 1.14.208.141
- 用户: root
- 密码: Lkg4btlf_
- 域名: bluepivot.net

---

## 方法一：手动分步部署（推荐）

### 步骤 1: 使用 SSH 登录服务器

打开 PowerShell 或 CMD，执行：

```bash
ssh root@1.14.208.141
```

输入密码：`Lkg4btlf_`

### 步骤 2: 安装必要软件

```bash
# 更新系统
apt update && apt upgrade -y

# 安装软件
apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib redis-server git curl certbot

# 创建项目用户
adduser --gecos "" --disabled-password django
usermod -aG sudo django

# 创建项目目录
mkdir -p /home/django/myproject
mkdir -p /var/www/certbot
```

### 步骤 3: 上传项目代码

**从本地 PowerShell 执行（在新窗口）：**

```powershell
# 上传配置文件
scp .env.domain root@1.14.208.141:/home/django/
scp nginx-domain.conf root@1.14.208.141:/home/django/
scp setup-domain-https.sh root@1.14.208.141:/home/django/
scp quick-deploy-with-https.sh root@1.14.208.141:/home/django/

# 上传项目代码（压缩包）
Compress-Archive -Path .\myproject\* -DestinationPath project.zip -Force
scp project.zip root@1.14.208.141:/home/django/
```

### 步骤 4: 在服务器上解压和配置

**回到 SSH 会话（服务器上）执行：**

```bash
# 切换到项目目录
cd /home/django

# 解压项目
unzip -q project.zip -d /home/django/myproject
rm project.zip

# 设置权限
chown -R django:django /home/django/myproject
chown -R django:django /home/django

# 设置脚本执行权限
chmod +x setup-domain-https.sh
chmod +x quick-deploy-with-https.sh
```

### 步骤 5: 配置虚拟环境

```bash
# 创建虚拟环境
su - django
cd myproject
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install --upgrade pip
pip install -r requirements-production.txt
```

### 步骤 6: 配置数据库

```bash
# 退出到 root 用户
exit

# 配置 PostgreSQL
sudo -u postgres psql <<EOF
CREATE DATABASE myprojectdb;
CREATE USER django_user WITH PASSWORD 'StrongPass123!@#';
GRANT ALL PRIVILEGES ON DATABASE myprojectdb TO django_user;
\q
EOF
```

### 步骤 7: 创建环境变量文件

```bash
# 切换到 django 用户
su - django
cd myproject

# 生成密钥
DB_PASS=$(openssl rand -base64 32)
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")

# 创建 .env 文件
cat > .env <<EOF
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

chmod 600 .env
```

### 步骤 8: 运行数据库迁移

```bash
source venv/bin/activate
python manage.py migrate --noinput
python manage.py collectstatic --noinput

# 创建超级用户（可选）
python manage.py createsuperuser
```

### 步骤 9: 配置 Nginx

```bash
# 退出到 root 用户
exit

# 创建 Nginx 配置
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

# 启用配置
ln -sf /etc/nginx/sites-available/bluepivot /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl start nginx
```

### 步骤 10: 获取 SSL 证书

```bash
# 获取证书
certbot certonly --webroot -w /var/www/certbot -d bluepivot.net -d www.bluepivot.net --email admin@bluepivot.net --agree-tos --non-interactive

# 配置自动续期
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && systemctl reload nginx") | crontab -
```

### 步骤 11: 配置 Systemd 服务

```bash
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
```

### 步骤 12: 配置防火墙

```bash
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
```

### 步骤 13: 验证部署

```bash
# 检查服务状态
systemctl status nginx
systemctl status bluepivot-daphne
systemctl status postgresql
systemctl status redis-server

# 查看日志
journalctl -u bluepivot-daphne -f
tail -f /var/log/nginx/error.log
```

### 步骤 14: 访问测试

打开浏览器访问：
- https://bluepivot.net
- https://bluepivot.net/admin

---

## 方法二：使用自动化脚本

如果要在服务器上运行自动化脚本，请：

1. 先按照步骤 1-3 上传所有文件
2. 在服务器上执行：

```bash
cd /home/django
sudo ./quick-deploy-with-https.sh
```

---

## 常见问题

### 1. 域名未解析
等待 DNS 生效（最多 48 小时），或使用：
```bash
nslookup bluepivot.net
```

### 2. SSL 证书获取失败
确保：
- 域名已正确解析到服务器 IP
- 80 端口已开放
- Nginx 正在运行

### 3. 数据库连接失败
```bash
sudo -u postgres psql
\l  # 查看数据库
\du  # 查看用户
```

### 4. 查看 Daphne 日志
```bash
sudo journalctl -u bluepivot-daphne -f
```

### 5. 查看 Nginx 日志
```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

---

## 维护命令

```bash
# 重启服务
sudo systemctl restart bluepivot-daphne nginx

# 更新代码
cd /home/django/myproject
git pull
source venv/bin/activate
pip install -r requirements-production.txt
python manage.py migrate
python manage.py collectstatic --noinput
sudo systemctl restart bluepivot-daphne

# 备份数据库
sudo -u postgres pg_dump myprojectdb > backup_$(date +%Y%m%d).sql
```
