# 🚀 部署准备完成

## ✅ 已完成的准备工作

1. **项目文件已检查** - 所有必需文件已就绪
2. **项目代码已压缩** - `project_deploy.zip` 已创建
3. **部署脚本已生成** - `deploy-now.ps1` 已准备

## 📋 快速部署步骤

### 第一步：上传文件（在 PowerShell 中执行）

```powershell
cd d:\src\codebuddy

scp -o StrictHostKeyChecking=no .env.domain root@1.14.208.141:/home/django/
scp -o StrictHostKeyChecking=no nginx-domain.conf root@1.14.208.141:/home/django/
scp -o StrictHostKeyChecking=no setup-domain-https.sh root@1.14.208.141:/home/django/
scp -o StrictHostKeyChecking=no quick-deploy-with-https.sh root@1.14.208.141:/home/django/
scp -o StrictHostKeyChecking=no project_deploy.zip root@1.14.208.141:/home/django/
```

**密码**: [请查看安全配置文件]

### 第二步：SSH 登录并部署

```powershell
ssh root@1.14.208.141
```

登录后执行：

```bash
cd /home/django
chmod +x setup-domain-https.sh quick-deploy-with-https.sh
unzip -q project_deploy.zip -d /home/django/myproject
rm project_deploy.zip
chown -R django:django /home/django/myproject
sudo bash quick-deploy-with-https.sh
```

### 第三步：监控部署（在另一个 PowerShell 窗口）

```powershell
ssh root@1.14.208.141
tail -f /home/django/deploy.log
```

### 第四步：访问应用

- 🌐 **应用首页**: https://bluepivot.net
- 🔧 **管理后台**: https://bluepivot.net/admin

---

## 📖 相关文档

| 文档 | 说明 |
|------|------|
| `QUICK_DEPLOY.txt` | 快速部署命令集 |
| `DEPLOY_GUIDE.md` | 完整部署指南 |
| `DEPLOY_STEPS.md` | 详细部署步骤 |
| `SECURITY.md` | 安全配置指南 |
| `WEBSOCKET.md` | WebSocket 配置 |

---

## ⚙️ 服务器信息

- **IP 地址**: 1.14.208.141
- **域名**: bluepivot.net
- **用户**: root
- **密码**: [请查看安全配置文件]
- **项目目录**: /home/django/myproject

---

## 📊 部署检查清单

- [ ] 域名 bluepivot.net 已解析到 1.14.208.141
- [ ] 服务器防火墙已开放 22, 80, 443 端口
- [ ] 已准备好服务器密码
- [ ] 项目文件已压缩为 project_deploy.zip
- [ ] 所需配置文件已准备好

---

## 🎯 部署脚本会自动完成的操作

1. ✅ 安装 Python, Nginx, PostgreSQL, Redis, Certbot
2. ✅ 创建项目用户 (django)
3. ✅ 配置 Python 虚拟环境
4. ✅ 安装 Python 依赖包
5. ✅ 配置 PostgreSQL 数据库
6. ✅ 生成安全的 SECRET_KEY 和密码
7. ✅ 配置 Nginx
8. ✅ 获取并配置 SSL 证书 (Let's Encrypt)
9. ✅ 配置 Systemd 服务
10. ✅ 运行数据库迁移
11. ✅ 收集静态文件
12. ✅ 启动所有服务
13. ✅ 配置防火墙
14. ✅ 配置 SSL 自动续期

**预计部署时间**: 10-20 分钟

---

## 🔧 部署后验证命令

```bash
# 检查服务状态
sudo systemctl status nginx
sudo systemctl status myproject-daphne
sudo systemctl status postgresql
sudo systemctl status redis-server

# 查看日志
sudo journalctl -u myproject-daphne -f
sudo tail -f /var/log/nginx/error.log

# 检查端口监听
sudo netstat -tlnp | grep -E ':(80|443|8000)'
```

---

## 📝 常用维护命令

### 重启服务
```bash
sudo systemctl restart myproject-daphne nginx
```

### 更新代码
```bash
cd /home/django/myproject
source venv/bin/activate
git pull
pip install -r requirements-production.txt
python manage.py migrate
python manage.py collectstatic --noinput
sudo systemctl restart myproject-daphne
```

### 备份数据库
```bash
sudo -u postgres pg_dump myprojectdb > backup_$(date +%Y%m%d).sql
```

### 恢复数据库
```bash
sudo -u postgres psql myprojectdb < backup_20250227.sql
```

---

## 🐛 故障排除

### 问题 1: SSH 连接失败
检查网络连接和密码是否正确

### 问题 2: 域名未解析
使用 `nslookup bluepivot.net` 检查，等待 DNS 生效

### 问题 3: SSL 证书获取失败
确保域名已正确解析，80 端口已开放

### 问题 4: 服务无法启动
```bash
sudo journalctl -u myproject-daphne -n 50
sudo tail -n 50 /var/log/nginx/error.log
```

---

## 📞 需要帮助?

查看以下文档获取更多帮助：
- `DEPLOY_GUIDE.md` - 完整部署指南
- `DEPLOY_STEPS.md` - 详细步骤说明
- `SECURITY.md` - 安全配置
- `WEBSOCKET.md` - WebSocket 配置

---

## 🎉 准备就绪!

所有准备工作已完成，现在可以开始部署了！

建议按照 `QUICK_DEPLOY.txt` 中的步骤执行部署。

祝部署顺利！🚀
