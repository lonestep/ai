# WebSocket 服务器运行状态

## ✅ 当前状态

**Daphne ASGI 服务器已成功启动**

- 🟢 服务器地址: `http://127.0.0.1:8000`
- 🟢 WebSocket 端点: `ws://127.0.0.1:8000/ws/items/`
- 🟢 健康检查: `http://127.0.0.1:8000/health/`

## 🎯 验证 WebSocket 连接

### 1. 打开页面
在浏览器中访问: http://127.0.0.1:8000/

### 2. 检查连接状态
在页面顶部查看 WebSocket 状态指示器：
- 🟢 **绿色圆点** + "WebSocket: 已连接" = 成功
- 🔴 **红色圆点** + "WebSocket: 未连接" = 失败

### 3. 测试实时功能
1. 添加一个新项目
2. 如果是绿色连接状态，数据会自动更新
3. 如果看到右上角弹出通知，说明 WebSocket 工作正常

## 🔍 浏览器控制台检查

1. 按 `F12` 打开开发者工具
2. 切换到 `Console` (控制台) 标签
3. 查看以下日志：

**成功连接时的日志:**
```
WebSocket 已连接
收到 WebSocket 消息: {type: "items_list", items: [...]}
```

**失败时的日志:**
```
WebSocket 连接失败
WebSocket 已断开
```

## 📊 WebSocket 功能

### 实时同步功能
- ✅ 添加项目后，所有连接的客户端自动更新
- ✅ 删除项目后，所有连接的客户端自动更新
- ✅ 无需手动刷新页面
- ✅ 自动显示操作通知

### 自动重连
- WebSocket 断开后自动在 5 秒后重连
- 服务器重启后客户端会自动重新连接

## 🚀 停止服务器

如需停止服务器，关闭 Daphne 控制台窗口或在命令行执行:
```bash
taskkill /F /IM daphne.exe
```

## 🔄 重启服务器

如需重启服务器:
```bash
# 1. 停止当前服务器
taskkill /F /IM daphne.exe

# 2. 重新启动
cd f:/src/codebuddy/ai
daphne myproject.asgi:application -b 127.0.0.1 -p 8000
```

或使用启动脚本:
```bash
cd f:/src/codebuddy/ai
run_daphne.bat
```

## 📝 注意事项

1. **开发服务器 vs Daphne 服务器**
   - `python manage.py runserver` - 不支持 WebSocket
   - `daphne myproject.asgi:application` - 支持 WebSocket

2. **端口占用**
   - 确保 8000 端口未被其他程序占用
   - 如遇端口冲突，可使用其他端口（如 8001）

3. **连接状态**
   - 如果显示红色，检查 Daphne 服务器是否正在运行
   - 打开浏览器控制台查看详细错误信息

## 🎓 相关文档

- [WEBSOCKET.md](./WEBSOCKET.md) - WebSocket 详细使用说明
- [README.md](./README.md) - 项目完整文档
