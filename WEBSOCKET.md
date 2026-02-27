# WebSocket 功能说明

## ⚠️ 重要说明

**WebSocket 地址 `ws://` 不能直接在浏览器地址栏访问！**

您看到的错误 `ERR_UNKNOWN_URL_SCHEME` 是正常的，因为 WebSocket 协议地址不是用来在浏览器地址栏打开的。

## 📝 正确的 WebSocket 使用方式

### 1. 访问主应用页面
在浏览器地址栏打开：
```
http://127.0.0.1:8000/
```

这个页面会自动建立 WebSocket 连接，无需您手动访问 `ws://` 地址。

### 2. WebSocket 连接状态
在主页面顶部会显示 WebSocket 连接状态：
- 🟢 绿色 = 已连接
- 🔴 红色 = 未连接

### 3. WebSocket 端点说明

| 端点 | 用途 | 使用方式 |
|------|------|----------|
| `/ws/items/` | 项目实时更新 | 前端自动连接 |
| `/ws/chat/` | 聊天功能 | 通过 JavaScript 代码连接 |

## 🚀 启动 WebSocket 服务器

### 方法 1: 使用 Daphne（支持 WebSocket）
```bash
# Windows
start_with_websocket.bat

# Linux/Mac
./start_with_websocket.sh

# 或直接运行
daphne myproject.asgi:application -b 127.0.0.1 -p 8000
```

### 方法 2: 使用开发服务器（不支持 WebSocket）
```bash
python manage.py runserver 127.0.0.1:8000
```

**注意**: Django 开发服务器不支持 WebSocket，使用此方式时 WebSocket 连接会失败。

## 🎯 WebSocket 功能特性

### 实时数据同步
- ✅ 当创建新项目时，所有连接的客户端自动收到更新
- ✅ 当删除项目时，所有连接的客户端自动收到更新
- ✅ 无需刷新页面即可看到最新数据

### 自动重连
- WebSocket 断开连接后，会自动在 5 秒后重试重新连接

### 通知系统
- 操作成功后会显示通知（如"新项目已创建"、"项目已删除"等）

## 🔧 测试 WebSocket 连接

### 浏览器控制台测试
1. 打开 http://127.0.0.1:8000/
2. 按 F12 打开开发者工具
3. 切换到 Console（控制台）标签
4. 查看日志输出：
   - `WebSocket 已连接` - 连接成功
   - `收到 WebSocket 消息:` - 收到实时更新

### 使用 WebSocket 测试工具
可以使用在线工具测试 WebSocket 连接：
- http://www.websocket.org/echo.html
- https://piehost.com/websocket-test-client

连接地址：`ws://127.0.0.1:8000/ws/items/`

## 📊 WebSocket 消息格式

### 客户端发送
```json
{
  "type": "fetch_items"
}
```

### 服务器返回
```json
{
  "type": "items_list",
  "items": [...]
}
```

### 实时更新通知
```json
{
  "type": "item_updated",
  "data": {
    "id": 1,
    "name": "项目名称",
    "action": "created"
  }
}
```

## 🛠 故障排查

### WebSocket 连接失败
1. **检查服务器是否使用 Daphne 启动**
   - `python manage.py runserver` 不支持 WebSocket
   - 必须使用 `daphne` 或 `uvicorn` 等 ASGI 服务器

2. **检查防火墙设置**
   - 确保 8000 端口未被阻止

3. **查看浏览器控制台错误**
   - 按 F12 打开开发者工具
   - 查看 Console 标签中的错误信息

### 如何判断 WebSocket 是否工作？
1. 访问 http://127.0.0.1:8000/
2. 查看页面顶部的 WebSocket 状态指示器
3. 绿色 = 正常工作，红色 = 未连接

## 📚 技术实现

### 后端技术栈
- **Django Channels 4.3.2** - WebSocket 框架
- **Daphne 4.2.1** - ASGI 服务器
- **Redis/MemoryChannel** - 消息队列（开发环境使用内存）

### 前端技术栈
- **原生 WebSocket API** - 浏览器内置支持
- **React Hooks** - 状态管理

## 🎓 学习资源

- [Django Channels 官方文档](https://channels.readthedocs.io/)
- [WebSocket MDN 文档](https://developer.mozilla.org/zh-CN/docs/Web/API/WebSocket)
- [Daphne 官方文档](https://docs.daphneproject.org/)
