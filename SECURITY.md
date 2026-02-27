# 🔒 生产环境安全部署指南

本文档详细说明将 Django 项目部署到生产环境所需的安全改进。

---

## 📋 目录

1. [基础安全配置](#基础安全配置)
2. [HTTPS 和 SSL](#https-和-ssl)
3. [数据库安全](#数据库安全)
4. [API 安全](#api-安全)
5. [文件和静态文件](#文件和静态文件)
6. [监控和日志](#监控和日志)
7. [安全检查清单](#安全检查清单)

---

## 🎯 基础安全配置

### 1. 关闭调试模式

**生产环境必须关闭 DEBUG**

```python
# settings.py
DEBUG = False
```

### 2. 配置 SECRET_KEY

**不要将 SECRET_KEY 硬编码到代码中**

```bash
# 生成新的 SECRET_KEY
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

```bash
# .env 文件（不要提交到 Git）
SECRET_KEY=your-generated-secret-key-here
DEBUG=False
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
```

### 3. 配置 ALLOWED_HOSTS

```python
# settings.py
ALLOWED_HOSTS = [
    'yourdomain.com',
    'www.yourdomain.com',
]
```

---

## 🔒 HTTPS 和 SSL

### 1. 使用 Let's Encrypt 免费证书

```bash
# 安装 Certbot
sudo apt-get install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# 自动续期
sudo certbot renew --dry-run
```

### 2. 强制 HTTPS

```python
# settings.py
SECURE_SSL_REDIRECT = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# Cookie 安全
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = True
```

### 3. 安全头配置

```python
# settings.py
SECURE_HSTS_SECONDS = 31536000  # 1 年
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = 'DENY'
```

---

## 🗄️ 数据库安全

### 1. 使用 PostgreSQL 替代 SQLite

**SQLite 不适合生产环境**

```bash
# 安装 PostgreSQL
sudo apt-get install postgresql postgresql-contrib

# 创建数据库
sudo -u postgres createdb myproject

# 创建用户
sudo -u postgres createuser --interactive
```

```python
# settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME'),
        'USER': os.environ.get('DB_USER'),
        'PASSWORD': os.environ.get('DB_PASSWORD'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
        'OPTIONS': {
            'sslmode': 'require',  # 强制 SSL
        },
    }
}
```

### 2. 数据库备份

```bash
# 每日备份脚本
#!/bin/bash
BACKUP_DIR="/var/backups/django"
DATE=$(date +%Y%m%d_%H%M%S)
pg_dump -U dbuser -h localhost myproject > $BACKUP_DIR/myproject_$DATE.sql
```

---

## 🌐 API 安全

### 1. 添加认证

```bash
pip install djangorestframework-simplejwt
```

```python
# settings.py
INSTALLED_APPS += [
    'rest_framework.authtoken',
]

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework.authentication.TokenAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}
```

### 2. 速率限制

```bash
pip install django-ratelimit
```

```python
# settings.py
INSTALLED_APPS += ['django_ratelimit']

REST_FRAMEWORK = {
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/day',
        'user': '1000/day',
    },
}
```

### 3. CORS 配置

```python
# settings.py
CORS_ALLOWED_ORIGINS = [
    "https://yourdomain.com",
    "https://www.yourdomain.com",
]
CORS_ALLOW_CREDENTIALS = False  # 除非必需
```

---

## 📁 文件和静态文件

### 1. 使用 CDN 或对象存储

**不要直接使用本地存储服务生产文件**

```bash
pip install django-storages[boto3]
```

```python
# settings.py
INSTALLED_APPS += ['storages']

DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
AWS_STORAGE_BUCKET_NAME = 'your-bucket-name'
AWS_S3_REGION_NAME = 'us-east-1'
AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
```

### 2. 文件上传限制

```python
# settings.py
DATA_UPLOAD_MAX_MEMORY_SIZE = 10485760  # 10 MB
FILE_UPLOAD_MAX_MEMORY_SIZE = 10485760  # 10 MB
DATA_UPLOAD_MAX_NUMBER_FIELDS = 1000
```

### 3. 限制文件类型

```python
# models.py
from django.core.validators import FileExtensionValidator

class Document(models.Model):
    file = models.FileField(
        upload_to='documents/',
        validators=[FileExtensionValidator(['pdf', 'doc', 'docx'])]
    )
```

---

## 📊 监控和日志

### 1. 配置日志

```python
# settings.py
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': '/var/log/django/django.log',
            'maxBytes': 1024 * 1024 * 10,  # 10 MB
            'backupCount': 10,
            'formatter': 'verbose',
        },
        'mail_admins': {
            'level': 'ERROR',
            'class': 'django.utils.log.AdminEmailHandler',
            'filters': ['require_debug_false'],
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': False,
        },
        'django.request': {
            'handlers': ['mail_admins'],
            'level': 'ERROR',
            'propagate': True,
        },
    },
}
```

### 2. 设置错误通知

```python
# settings.py
ADMINS = [
    ('Admin Name', 'admin@yourdomain.com'),
]

MANAGERS = ADMINS

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD')
```

### 3. 使用监控工具

```bash
# 安装 Sentry
pip install sentry-sdk

# settings.py
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration

sentry_sdk.init(
    dsn="your-sentry-dsn",
    integrations=[DjangoIntegration()],
    traces_sample_rate=1.0,
)
```

---

## ✅ 安全检查清单

### 部署前必检

- [ ] `DEBUG = False`
- [ ] `SECRET_KEY` 已更改且不在代码中
- [ ] `ALLOWED_HOSTS` 已正确配置
- [ ] HTTPS 已启用
- [ ] SSL 证书已配置
- [ ] 数据库使用 PostgreSQL/MySQL
- [ ] 数据库密码已设置
- [ ] 敏感信息使用环境变量
- [ ] 管理员账号已创建且密码安全
- [ ] 错误页面已自定义（404, 500）
- [ ] CORS 已正确配置
- [ ] 文件上传已限制
- [ ] 日志已配置
- [ ] 依赖包已更新到最新版本

### 安全扫描

```bash
# 检查依赖包漏洞
pip install safety
safety check

# Python 代码安全扫描
pip install bandit
bandit -r .

# Django 安全检查
python manage.py check --deploy
```

### 定期维护

- [ ] 每周更新依赖包
- [ ] 每月检查安全公告
- [ ] 每日备份数据库
- [ ] 监控服务器日志
- [ ] 定期审查访问日志

---

## 🚀 生产环境部署脚本

### Nginx 配置示例

```nginx
# /etc/nginx/sites-available/myproject
upstream myproject {
    server 127.0.0.1:8000;
}

server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    # 重定向到 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com www.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;

    # 安全头
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    location /static/ {
        alias /path/to/staticfiles/;
        expires 30d;
    }

    location /media/ {
        alias /path/to/media/;
        expires 30d;
    }

    location / {
        proxy_pass http://myproject;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Systemd 服务配置

```ini
# /etc/systemd/system/daphne.service
[Unit]
Description=Daphne ASGI server
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/path/to/project
ExecStart=/path/to/venv/bin/daphne myproject.asgi:application -b 127.0.0.1 -p 8000 -v 2
Restart=always

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
sudo systemctl start daphne
sudo systemctl enable daphne
sudo systemctl status daphne
```

---

## 📚 参考资源

- [Django 官方安全文档](https://docs.djangoproject.com/en/5.0/topics/security/)
- [OWASP Django 安全检查表](https://owasp.org/www-project-django-security-cheat-sheet/)
- [Django 部署指南](https://docs.djangoproject.com/en/5.0/howto/deployment/)

---

## 🆘 安全事件响应

如果发现安全问题：

1. **立即评估威胁级别**
2. **隔离受影响的系统**
3. **收集证据和日志**
4. **通知相关团队**
5. **修复漏洞**
6. **测试修复**
7. **重新部署**
8. **总结经验教训**
