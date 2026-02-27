"""
生产环境安全配置

将此文件的内容合并到 settings.py 中，或者作为参考进行安全配置
"""

# ============================================================================
# 🔐 基础安全配置
# ============================================================================

# 1. 必须使用强随机密钥
# SECRET_KEY 应该从环境变量中读取，不要硬编码
# SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY')

# 2. 关闭调试模式
# DEBUG = False

# 3. 配置允许的主机
# ALLOWED_HOSTS = ['yourdomain.com', 'www.yourdomain.com', 'api.yourdomain.com']

# ============================================================================
# 🛡️ HTTPS 和 SSL 配置
# ============================================================================

# 强制使用 HTTPS
SECURE_SSL_REDIRECT = True
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# Cookie 安全设置
SESSION_COOKIE_SECURE = True  # 仅通过 HTTPS 传输 session cookie
CSRF_COOKIE_SECURE = True     # 仅通过 HTTPS 传输 CSRF cookie
SESSION_COOKIE_HTTPONLY = True  # 防止 JavaScript 访问 session cookie
CSRF_COOKIE_HTTPONLY = True     # 防止 JavaScript 访问 CSRF cookie

# Cookie SameSite 设置（防止 CSRF）
SESSION_COOKIE_SAMESITE = 'Lax'
CSRF_COOKIE_SAMESITE = 'Lax'

# ============================================================================
# 🔒 安全头配置
# ============================================================================

# 内容安全策略（CSP）
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
X_FRAME_OPTIONS = 'DENY'  # 防止点击劫持

# HSTS（HTTP Strict Transport Security）
# 告诉浏览器只能通过 HTTPS 访问
SECURE_HSTS_SECONDS = 31536000  # 1 年
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# ============================================================================
# 👤 认证安全
# ============================================================================

# 密码验证器
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
        'OPTIONS': {
            'min_length': 12,  # 最小密码长度
        }
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# 会话设置
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
SESSION_COOKIE_AGE = 1209600  # 2 周
SESSION_EXPIRE_AT_BROWSER_CLOSE = False

# ============================================================================
# 🌐 CORS 安全配置
# ============================================================================

# 严格限制 CORS 允许的来源
CORS_ALLOWED_ORIGINS = [
    "https://yourdomain.com",
    "https://www.yourdomain.com",
]

# 如果使用 cookie，需要设置
# CORS_ALLOW_CREDENTIALS = True

# ============================================================================
# 📡 REST API 安全
# ============================================================================

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.SessionAuthentication',
        'rest_framework.authentication.TokenAuthentication',  # 如果使用 token 认证
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',  # 默认要求认证
    ],
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': '100/day',     # 匿名用户每天 100 次请求
        'user': '1000/day',    # 认证用户每天 1000 次请求
    },
}

# ============================================================================
# 🗄️ 数据库安全
# ============================================================================

# 不要使用 SQLite 生产环境，改用 PostgreSQL 或 MySQL
# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.postgresql',
#         'NAME': os.environ.get('DB_NAME'),
#         'USER': os.environ.get('DB_USER'),
#         'PASSWORD': os.environ.get('DB_PASSWORD'),
#         'HOST': os.environ.get('DB_HOST', 'localhost'),
#         'PORT': os.environ.get('DB_PORT', '5432'),
#         'OPTIONS': {
#             'sslmode': 'require',  # 强制 SSL
#         },
#     }
# }

# ============================================================================
# 🔍 日志和监控
# ============================================================================

# 生产环境日志配置
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'filters': {
        'require_debug_false': {
            '()': 'django.utils.log.RequireDebugFalse',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
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
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': False,
        },
        'django.request': {
            'handlers': ['mail_admins'],
            'level': 'ERROR',
            'propagate': True,
        },
        'security': {
            'handlers': ['console', 'file'],
            'level': 'WARNING',
            'propagate': False,
        },
    },
}

# 管理员通知
ADMINS = [
    ('Admin Name', 'admin@yourdomain.com'),
]

MANAGERS = ADMINS

# ============================================================================
# 🌍 文件上传安全
# ============================================================================

# 限制上传文件大小
DATA_UPLOAD_MAX_MEMORY_SIZE = 10485760  # 10 MB
FILE_UPLOAD_MAX_MEMORY_SIZE = 10485760  # 10 MB
DATA_UPLOAD_MAX_NUMBER_FIELDS = 1000

# 限制允许的文件扩展名
# 需要实现自定义验证器或在模型中限制

# ============================================================================
# 🚫 错误页面
# ============================================================================

# 生产环境不显示详细错误信息
DEBUG_PROPAGATE_EXCEPTIONS = False

# 自定义错误页面
# 创建 templates/404.html, 500.html 等

# ============================================================================
# 🔐 WebSocket 安全
# ============================================================================

# 如果使用 WebSocket，确保：
# 1. 使用 WSS（WebSocket Secure）而不是 WS
# 2. 实现 WebSocket 认证
# 3. 限制连接速率

# ============================================================================
# 📦 其他安全建议
# ============================================================================

# 1. 使用防火墙限制访问
# 2. 定期更新依赖包
# 3. 使用安全扫描工具（如 bandit, safety）
# 4. 配置自动备份
# 5. 实现速率限制（使用 django-ratelimit）
# 6. 使用 CDN 保护静态文件
# 7. 配置监控和告警

# ============================================================================
# 📋 安全检查清单
# ============================================================================

# 部署前检查：
# - [ ] DEBUG = False
# - [ ] SECRET_KEY 已更改且安全存储
# - [ ] ALLOWED_HOSTS 已正确配置
# - [ ] HTTPS 已启用
# - [ ] 数据库密码已设置
# - [ ] 管理员账号已创建且密码安全
# - [ ] 日志已配置
# - [ ] 错误页面已自定义
# - [ ] CORS 已正确配置
# - [ ] 文件上传已限制
# - [ ] 依赖包已更新
# - [ ] 备份策略已制定
