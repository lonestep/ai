# Django + Python Web 项目

基于最新 Django 5.0.6 和 Python 3.10 的全栈 Web 项目，整合了前后端，支持开发和生产环境部署。

## 🚀 项目特性

- ✅ Django 5.0.6（最新稳定版）
- ✅ Django REST Framework（RESTful API）
- ✅ Django Channels 4.3.2（WebSocket 实时通信）
- ✅ 前后端分离架构
- ✅ React 18 前端（集成在模板中）
- ✅ SQLite 数据库（可轻松切换到 PostgreSQL/MySQL）
- ✅ CORS 跨域支持
- ✅ 环境变量管理
- ✅ 开发/生产环境配置
- ✅ 静态文件处理（WhiteNoise）
- ✅ 生产级 Gunicorn/Daphne 服务器
- ✅ 实时数据同步

## 📁 项目结构

```
ai/
├── manage.py                 # Django 管理脚本
├── requirements.txt          # Python 依赖
├── .env                      # 环境变量配置
├── .gitignore               # Git 忽略文件
├── WEBSOCKET.md             # WebSocket 使用说明
├── start.bat               # Windows 启动脚本
├── start.sh                # Linux/Mac 启动脚本
├── start_with_websocket.bat  # WebSocket 启动脚本 (Windows)
├── start_with_websocket.sh   # WebSocket 启动脚本 (Linux/Mac)
├── run_production.sh       # 生产环境启动脚本
├── collectstatic.sh        # 静态文件收集脚本
├── myproject/              # 项目配置
│   ├── __init__.py
│   ├── settings.py         # Django 设置
│   ├── urls.py             # URL 路由
│   ├── wsgi.py             # WSGI 配置
│   └── asgi.py             # ASGI 配置 (WebSocket)
├── api/                    # API 应用
│   ├── models.py           # 数据模型
│   ├── serializers.py      # REST 序列化器
│   ├── views.py            # API 视图
│   └── urls.py             # API 路由
├── websocket/              # WebSocket 应用
│   ├── consumers.py        # WebSocket 消费者
│   ├── routing.py          # WebSocket 路由
│   └── signals.py          # 信号处理
├── frontend/               # 前端应用
│   └── urls.py             # 前端路由
└── templates/              # 模板文件
    └── index.html          # React 前端 (集成 WebSocket)
```

## 🛠 快速开始

### 1. 安装依赖

```bash
pip install -r requirements.txt
```

### 2. 配置环境变量

复制 `.env.example` 为 `.env` 并配置：

```bash
cp .env.example .env
```

默认配置已可以运行开发环境。

### 3. 数据库迁移

```bash
python manage.py migrate
```

### 4. 创建管理员账号（可选）

```bash
python manage.py createsuperuser
```

### 5. 启动开发服务器

#### 普通开发服务器（不支持 WebSocket）

**Windows:**
```bash
start.bat
```

**Linux/Mac:**
```bash
chmod +x start.sh
./start.sh
```

或直接运行：
```bash
python manage.py runserver 127.0.0.1:8000
```

#### WebSocket 服务器（支持实时通信）

**Windows:**
```bash
start_with_websocket.bat
```

**Linux/Mac:**
```bash
chmod +x start_with_websocket.sh
./start_with_websocket.sh
```

或直接运行 Daphne：
```bash
daphne myproject.asgi:application -b 127.0.0.1 -p 8000
```

服务器将在 `http://127.0.0.1:8000` 启动

> ⚠️ **注意**: 如需使用 WebSocket 功能，必须使用 Daphne 启动服务器

## 📱 访问应用

- **前端应用**: http://127.0.0.1:8000/
- **API 接口**: http://127.0.0.1:8000/api/
- **管理后台**: http://127.0.0.1:8000/admin/
- **健康检查**: http://127.0.0.1:8000/health/

## 🔧 API 端点

### REST API 接口

- `GET /api/info/` - API 信息
- `GET /api/items/` - 获取所有项目
- `POST /api/items/` - 创建新项目
- `GET /api/items/{id}/` - 获取单个项目
- `PUT /api/items/{id}/` - 更新项目
- `PATCH /api/items/{id}/` - 部分更新项目
- `DELETE /api/items/{id}/` - 删除项目

### WebSocket 端点

- `ws://127.0.0.1:8000/ws/items/` - 项目实时更新
- `ws://127.0.0.1:8000/ws/chat/` - 聊天功能

> 📖 **详细说明**: 请查看 [WEBSOCKET.md](./WEBSOCKET.md) 了解 WebSocket 的详细使用方法

## 🚢 生产部署

### 1. 配置生产环境

编辑 `.env` 文件：

```env
DEBUG=False
SECRET_KEY=your-secure-secret-key
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
```

### 2. 收集静态文件

```bash
python manage.py collectstatic --noinput
```

### 3. 启动生产服务器

```bash
chmod +x run_production.sh
./run_production.sh
```

或使用 Gunicorn：

```bash
gunicorn myproject.wsgi:application --bind 0.0.0.0:8000 --workers 4
```

## 🎨 开发功能

前端页面包含完整的 CRUD 功能：
- ✅ 查看所有项目
- ✅ 添加新项目
- ✅ 删除项目
- ✅ API 健康检查显示

## 📦 技术栈

- **后端**: Django 5.0.6, Django REST Framework 3.15.1
- **前端**: React 18（通过 CDN 引入）
- **数据库**: SQLite3（可切换到 PostgreSQL/MySQL）
- **服务器**: Gunicorn（生产）, 开发服务器（开发）
- **静态文件**: WhiteNoise 6.6.0
- **跨域**: django-cors-headers 4.3.1

## 🔐 安全建议

生产环境请务必：
1. 修改 `SECRET_KEY` 为强密码
2. 设置 `DEBUG=False`
3. 配置 `ALLOWED_HOSTS` 为实际域名
4. 使用 HTTPS
5. 配置数据库密码
6. 使用防火墙保护服务器

## 📝 开发调试

### 查看日志

开发模式下，日志直接输出到控制台。

### 清理数据库

```bash
rm db.sqlite3
python manage.py migrate
```

### 创建新迁移

```bash
python manage.py makemigrations
python manage.py migrate
```

## 🔒 生产环境安全部署

### 安全配置文档

- **[SECURITY.md](./SECURITY.md)** - 生产环境安全配置和部署指南
- **[production_settings.py](./production_settings.py)** - 完整的生产环境安全配置示例
- **[.env.production](./.env.production)** - 生产环境环境变量模板

### 快速部署

**Linux/Mac:**
```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File deploy.ps1
```

### 安装生产环境依赖

```bash
pip install -r requirements-production.txt
```

### 安全检查

部署前请运行安全检查：

```bash
# Django 安全检查
python manage.py check --deploy

# 依赖包漏洞扫描
safety check

# Python 代码安全扫描
bandit -r .
```

### 安全检查清单

部署前请确保：
- ✅ `DEBUG = False`
- ✅ `SECRET_KEY` 已更改且不在代码中
- ✅ `ALLOWED_HOSTS` 已正确配置
- ✅ HTTPS 已启用
- ✅ 使用 PostgreSQL/MySQL 而不是 SQLite
- ✅ 敏感信息使用环境变量
- ✅ 依赖包已更新到最新版本
- ✅ 配置了错误监控和日志
- ✅ 设置了文件上传限制
- ✅ 配置了速率限制

详见 [SECURITY.md](./SECURITY.md) 获取完整的安全配置指南。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License
