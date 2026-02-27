# 腾讯云 Ubuntu 服务器部署指南

## 📋 部署前准备

### 1. 服务器要求
- Ubuntu 20.04 或 22.04 LTS
- 至少 2GB RAM（推荐 4GB）
- 至少 20GB 磁盘空间
- 公网 IP 地址
- 已开放必要端口：22（SSH）、80（HTTP）、443（HTTPS）

### 2. 本地准备
- 确保本地代码已提交到 Git
- 准备服务器登录密钥或密码
- 准备域名（可选，用于 HTTPS）

---

## 🚀 部署步骤

### 第一步：服务器基础配置

```bash
# 1. 使用 SSH 登录到腾讯云服务器
ssh root@你的服务器IP

# 2. 更新系统
sudo apt update
sudo apt upgrade -y

# 3. 安装必要软件
sudo apt install -y python3 python3-pip python3-venv nginx postgresql postgresql-contrib redis-server git

# 4. 安装 certbot（用于 HTTPS 证书）
sudo apt install -y certbot python3-certbot-nginx
```

### 第二步：创建项目用户

```bash
# 创建专用用户（不要使用 root 运行应用）
sudo adduser django
sudo usermod -aG sudo django

# 切换到 django 用户
su - django
```

### 第三步：上传项目代码

**方式1：使用 Git（推荐）**

```bash
# 在服务器上
cd ~
git clone https://github.com/你的用户名/你的仓库.git myproject
cd myproject

# 或使用 SSH 密钥
git clone git@github.com:你的用户名/你的仓库.git myproject
```

**方式2：使用 SCP（从本地 Windows）**

```powershell
# 在本地 Windows PowerShell 中执行
scp -r .\myproject root@你的服务器IP:/home/django/

# 或使用 Git Bash
scp -r /f/src/codebuddy/ai root@你的服务器IP:/home/django/
```

### 第四步：配置虚拟环境

```bash
# 在服务器上（django 用户）
cd ~/myproject

# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
pip install --upgrade pip
pip install -r requirements-production.txt
```

### 第五步：配置 PostgreSQL 数据库

```bash
# 切换到 postgres 用户
sudo -u postgres psql

# 在 PostgreSQL 命令行中执行
CREATE DATABASE myprojectdb;
CREATE USER django_user WITH PASSWORD '强密码123!';
GRANT ALL PRIVILEGES ON DATABASE myprojectdb TO django_user;
\q
```

### 第六步：配置环境变量

```bash
# 在项目目录下创建 .env 文件
cd ~/myproject
nano .env
```

**.env 文件内容：**

```bash
# ============================================================================
# 生产环境配置
# ============================================================================

# Django 设置
DEBUG=False
SECRET_KEY=使用 python -c "import secrets; print(secrets.token_urlsafe(50))" 生成
ALLOWED_HOSTS=你的域名.com,www.你的域名.com

# 数据库配置
DB_NAME=myprojectdb
DB_USER=django_user
DB_PASSWORD=你的数据库密码
DB_HOST=localhost
DB_PORT=5432

# Redis 配置（用于 WebSocket）
REDIS_HOST=localhost
REDIS_PORT=6379

# 管理员邮箱
ADMINS=管理员名,admin@你的域名.com
```

```bash
# 设置文件权限
chmod 600 .env
```

### 第七步：配置 Django 设置

```bash
# 编辑 settings.py
nano myproject/settings.py
```

**关键配置（修改 settings.py）：**

```python
# 允许的主机
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '').split(',')

# 数据库配置
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME'),
        'USER': os.environ.get('DB_USER'),
        'PASSWORD': os.environ.get('DB_PASSWORD'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

# Channel Layers 配置（Redis）
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [(os.environ.get('REDIS_HOST', 'localhost'), 6379)],
        },
    },
}

# 静态文件
STATIC_ROOT = '/home/django/myproject/staticfiles'
STATIC_URL = '/static/'

# 媒体文件
MEDIA_ROOT = '/home/django/myproject/media'
MEDIA_URL = '/media/'
```

### 第八步：运行迁移和收集静态文件

```bash
# 在虚拟环境中
cd ~/myproject
source venv/bin/activate

# 运行迁移
python manage.py migrate

# 收集静态文件
python manage.py collectstatic --noinput

# 创建超级用户（如果需要）
python manage.py createsuperuser
```

### 第九步：配置 Nginx

```bash
# 创建 Nginx 配置文件
sudo nano /etc/nginx/sites-available/myproject
```

**Nginx 配置文件内容：**

```nginx
# HTTP 重定向到 HTTPS
server {
    listen 80;
    server_name 你的域名.com www.你的域名.com;

    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS 配置
server {
    listen 443 ssl http2;
    server_name 你的域名.com www.你的域名.com;

    # SSL 证书（稍后配置）
    # ssl_certificate /etc/letsencrypt/live/你的域名.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/你的域名.com/privkey.pem;

    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # 静态文件
    location /static/ {
        alias /home/django/myproject/staticfiles/;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # 媒体文件
    location /media/ {
        alias /home/django/myproject/media/;
        expires 30d;
    }

    # HTTP 请求代理到 Daphne
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

    # WebSocket 支持
    location /ws/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
}
```

```bash
# 启用配置
sudo ln -s /etc/nginx/sites-available/myproject /etc/nginx/sites-enabled/

# 测试 Nginx 配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

### 第十步：配置 SSL 证书（HTTPS）

```bash
# 如果有域名，获取 Let's Encrypt 证书
sudo certbot --nginx -d 你的域名.com -d www.你的域名.com

# 如果没有域名，使用自签名证书（仅用于测试）
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/myproject-selfsigned.key \
    -out /etc/ssl/certs/myproject-selfsigned.crt

# 然后修改 Nginx 配置使用自签名证书
sudo nano /etc/nginx/sites-available/myproject
```

### 第十一步：配置 Systemd 服务

```bash
# 创建 Daphne 服务配置
sudo nano /etc/systemd/system/myproject-daphne.service
```

**服务配置内容：**

```ini
[Unit]
Description=Daphne ASGI server for myproject
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
```

```bash
# 启动并启用服务
sudo systemctl daemon-reload
sudo systemctl enable myproject-daphne
sudo systemctl start myproject-daphne

# 查看服务状态
sudo systemctl status myproject-daphne

# 查看日志
sudo journalctl -u myproject-daphne -f
```

### 第十二步：配置防火墙

```bash
# 允许必要端口
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS

# 启用防火墙
sudo ufw enable

# 查看状态
sudo ufw status
```

---

## 🔍 验证部署

### 1. 检查服务状态

```bash
# Daphne 服务
sudo systemctl status myproject-daphne

# Nginx 服务
sudo systemctl status nginx

# PostgreSQL 服务
sudo systemctl status postgresql

# Redis 服务
sudo systemctl status redis-server
```

### 2. 测试访问

在浏览器中访问：
- `http://你的服务器IP` 或 `https://你的域名.com`
- `https://你的域名.com/admin`（管理后台）

### 3. 运行安全检查

```bash
cd ~/myproject
source venv/bin/activate

# Django 部署检查
python manage.py check --deploy

# 依赖包安全检查
safety check

# 代码安全扫描
bandit -r . --exclude .git,venv
```

---

## 📝 日常维护

### 重启服务

```bash
# 重启 Daphne
sudo systemctl restart myproject-daphne

# 重启 Nginx
sudo systemctl restart nginx
```

### 查看日志

```bash
# Daphne 日志
sudo journalctl -u myproject-daphne -f

# Nginx 日志
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### 更新代码

```bash
cd ~/myproject
git pull origin main
source venv/bin/activate
pip install -r requirements-production.txt
python manage.py migrate
python manage.py collectstatic --noinput
sudo systemctl restart myproject-daphne
```

### 数据库备份

```bash
# 备份数据库
sudo -u postgres pg_dump myprojectdb > backup_$(date +%Y%m%d_%H%M%S).sql

# 恢复数据库
sudo -u postgres psql myprojectdb < backup_20240227_120000.sql
```

---

## ⚠️ 常见问题

### 1. 端口被占用

```bash
# 查看占用端口的进程
sudo netstat -tlnp | grep :8000

# 杀死进程
sudo kill -9 PID
```

### 2. 权限问题

```bash
# 修改文件所有者
sudo chown -R django:django /home/django/myproject

# 修改目录权限
sudo chmod -R 755 /home/django/myproject
```

### 3. WebSocket 连接失败

检查 Nginx 配置中的 `proxy_set_header Upgrade` 和 `Connection` 设置

### 4. 数据库连接失败

```bash
# 检查 PostgreSQL 是否运行
sudo systemctl status postgresql

# 检查数据库用户权限
sudo -u postgres psql
\l  # 列出数据库
\du  # 列出用户
```

---

## 🔐 安全建议

1. **定期更新系统**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **配置 SSH 密钥认证**
   ```bash
   # 禁用密码登录
   sudo nano /etc/ssh/sshd_config
   # 设置: PasswordAuthentication no
   sudo systemctl restart sshd
   ```

3. **配置 fail2ban 防止暴力破解**
   ```bash
   sudo apt install fail2ban
   sudo systemctl enable fail2ban
   sudo systemctl start fail2ban
   ```

4. **定期备份数据库**

5. **监控服务器资源使用情况**

---

## 📞 技术支持

如有问题，请检查：
1. 服务日志：`sudo journalctl -u myproject-daphne -f`
2. Nginx 日志：`sudo tail -f /var/log/nginx/error.log`
3. Django 日志：查看项目目录下的日志文件
