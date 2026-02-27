# Django 项目部署指南

## 项目已准备完成

✅ 所需文件已检查并准备就绪
✅ 项目代码已压缩为 `project_deploy.zip`

## 部署步骤

### 方法一: 手动执行(推荐)

#### 步骤 1: 上传文件到服务器

在 PowerShell 中执行以下命令:

```powershell
# 进入项目目录
cd d:\src\codebuddy

# 上传配置文件
scp -o StrictHostKeyChecking=no .env.domain root@1.14.208.141:/home/django/
scp -o StrictHostKeyChecking=no nginx-domain.conf root@1.14.208.141:/home/django/
scp -o StrictHostKeyChecking=no setup-domain-https.sh root@1.14.208.141:/home/django/
scp -o StrictHostKeyChecking=no quick-deploy-with-https.sh root@1.14.208.141:/home/django/

# 上传项目代码(已压缩)
scp -o StrictHostKeyChecking=no project_deploy.zip root@1.14.208.141:/home/django/
```

**注意**: 执行上述命令时需要输入服务器密码

#### 步骤 2: 在服务器上准备项目

SSH 登录到服务器:

```bash
ssh root@1.14.208.141
# 输入服务器密码
```

执行以下命令:

```bash
# 切换到目录
cd /home/django

# 设置脚本执行权限
chmod +x setup-domain-https.sh
chmod +x quick-deploy-with-https.sh

# 解压项目
unzip -q project_deploy.zip -d /home/django/myproject
rm project_deploy.zip

# 设置权限
chown -R django:django /home/django/myproject
```

#### 步骤 3: 运行部署脚本

```bash
# 使用 sudo 运行部署脚本
sudo ./quick-deploy-with-https.sh
```

**部署脚本会自动完成以下操作**:
- 安装必要软件 (Python, Nginx, PostgreSQL, Redis, Certbot)
- 创建项目用户 (django)
- 配置虚拟环境
- 安装 Python 依赖
- 配置域名和 HTTPS
- 配置 Systemd 服务
- 运行数据库迁移
- 收集静态文件
- 启动服务
- 配置防火墙

**部署时间**: 约 10-20 分钟

#### 步骤 4: 验证部署

```bash
# 检查服务状态
sudo systemctl status nginx
sudo systemctl status myproject-daphne
sudo systemctl status postgresql
sudo systemctl status redis-server

# 查看日志
sudo journalctl -u myproject-daphne -f
sudo tail -f /var/log/nginx/error.log
```

#### 步骤 5: 访问应用

打开浏览器访问:
- 应用首页: https://bluepivot.net
- 管理后台: https://bluepivot.net/admin

---

### 方法二: 使用 SSH 命令远程执行(高级)

如果你想一键完成,可以使用以下命令:

```powershell
# 创建临时脚本变量
$cmd = @"
cd /home/django &&
chmod +x setup-domain-https.sh quick-deploy-with-https.sh &&
unzip -q project_deploy.zip -d /home/django/myproject &&
rm project_deploy.zip &&
chown -R django:django /home/django/myproject &&
sudo bash quick-deploy-with-https.sh
"@

# SSH 执行
ssh -o StrictHostKeyChecking=no root@1.14.208.141 $cmd
```

---

## 部署前准备检查

- [ ] 域名 `bluepivot.net` 已解析到服务器 IP `1.14.208.141`
  - 使用 `nslookup bluepivot.net` 检查
- [ ] 服务器防火墙已开放端口: 22, 80, 443
- [ ] 确保有服务器 root 权限和密码

---

## 常见问题

### 1. SSH 连接失败
确保服务器密码正确,或检查防火墙设置

### 2. 域名未解析
等待 DNS 生效(最多 48 小时),或先使用 IP 地址测试

### 3. SSL 证书获取失败
确保:
- 域名已正确解析到服务器 IP
- 80 端口已开放
- Nginx 正在运行

### 4. 查看部署日志

```bash
# 查看 quick-deploy-with-https.sh 的输出
tail -f /home/django/deploy.log
```

---

## 维护命令

### 重启服务
```bash
sudo systemctl restart myproject-daphne nginx
```

### 更新代码
```bash
cd /home/django/myproject
source venv/bin/activate
pip install -r requirements-production.txt
python manage.py migrate
python manage.py collectstatic --noinput
sudo systemctl restart myproject-daphne
```

### 备份数据库
```bash
sudo -u postgres pg_dump myprojectdb > backup_$(date +%Y%m%d).sql
```

### 查看 Daphne 日志
```bash
sudo journalctl -u myproject-daphne -f
```

### 查看 Nginx 日志
```bash
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

---

## 项目配置信息

- **服务器 IP**: 1.14.208.141
- **域名**: bluepivot.net
- **项目目录**: /home/django/myproject
- **虚拟环境**: /home/django/myproject/venv
- **数据库**: PostgreSQL (myprojectdb)
- **缓存**: Redis
- **Web 服务器**: Nginx
- **应用服务器**: Daphne (ASGI)
- **SSL 证书**: Let's Encrypt (自动续期)

---

## 安全建议

1. 定期更新系统和依赖包
2. 使用强密码
3. 配置防火墙规则
4. 定期备份数据库
5. 监控系统日志
6. 使用 HTTPS

---

## 需要帮助?

查看详细文档:
- `DEPLOY_STEPS.md` - 完整部署步骤
- `SECURITY.md` - 安全配置指南
- `WEBSOCKET.md` - WebSocket 配置

服务器信息:
- IP: 1.14.208.141
- 用户: root
- 密码: [请查看安全配置文件]
