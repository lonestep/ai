# WebSocket 调试指南

## 🔍 当前状态

服务器已重启，已添加详细的调试日志。

## 📝 问题排查步骤

### 1. 打开 WebSocket 测试工具

在浏览器中打开：`f:/src/codebuddy/ai/test_websocket.html`

### 2. 测试 WebSocket 连接

1. 点击"连接"按钮
2. 查看日志输出
3. 如果连接成功，点击"发送 fetch_items"

### 3. 打开主应用

在浏览器中打开：http://127.0.0.1:8000/

在两个不同的浏览器窗口或标签页中打开同一个地址。

### 4. 测试实时同步

1. 在第一个窗口添加一个项目
2. 观察第二个窗口是否自动更新
3. 查看 Daphne 控制台窗口的日志输出

## 📊 预期的日志输出

### Daphne 服务器日志

当 WebSocket 连接时：
```
INFO     WebSocket connecting: specific.channel.name
INFO     WebSocket connected: specific.channel.name
```

当创建/删除项目时：
```
INFO     Item created: 项目名称
INFO     Sending to channel layer: {'id': 1, 'name': '项目名称', ...}
INFO     Message sent to channel layer
INFO     Received item_update event: {'type': 'item.update', 'data': {...}}
INFO     Sent item_update message to client
```

### 浏览器控制台日志

按 F12 打开开发者工具，查看 Console：

连接成功时：
```
WebSocket 已连接
```

收到消息时：
```
收到 WebSocket 消息: {type: "item_updated", data: {...}}
```

## 🐛 可能的问题和解决方案

### 问题 1: WebSocket 连接失败

**症状**：
- 页面显示红色连接状态
- 浏览器控制台显示错误

**解决方案**：
1. 检查 Daphne 服务器是否正在运行
2. 检查 8000 端口是否被占用
3. 查看浏览器控制台的具体错误信息

### 问题 2: 信号未触发

**症状**：
- 创建/删除项目时 Daphne 控制台没有日志输出
- WebSocket 已连接但收不到更新

**解决方案**：
1. 确保 websocket 应用已在 settings.py 的 INSTALLED_APPS 中
2. 确保 signals.py 在 apps.py 的 ready() 方法中被导入
3. 重启服务器确保信号被注册

### 问题 3: 消息未广播到所有客户端

**症状**：
- 一个窗口创建项目，另一个窗口未收到更新
- Daphne 日志显示消息已发送但客户端未收到

**解决方案**：
1. 确保两个窗口都成功连接到 WebSocket
2. 检查 channel_layer 配置
3. 确认两个窗口连接到同一个组 ('items')

## 🧪 测试检查清单

- [ ] Daphne 服务器正在运行
- [ ] 测试工具可以成功连接
- [ ] 测试工具可以发送和接收消息
- [ ] 主应用显示绿色连接状态
- [ ] 在一个窗口添加项目
- [ ] 另一个窗口自动更新
- [ ] 操作通知正确显示
- [ ] Daphne 控制台有相应的日志输出

## 🔧 重启服务器命令

如果需要重启服务器：

```powershell
# 停止所有 Daphne 进程
taskkill /F /IM daphne.exe

# 启动新的服务器（带详细日志）
cd f:/src/codebuddy/ai
daphne myproject.asgi:application -b 127.0.0.1 -p 8000 -v 2
```

## 📱 测试方法

### 方法 1: 使用测试工具
1. 打开 `test_websocket.html`
2. 点击"连接"
3. 在另一个标签页打开主应用 http://127.0.0.1:8000/
4. 在主应用添加项目
5. 查看测试工具是否收到消息

### 方法 2: 双窗口测试
1. 在浏览器窗口 A 打开 http://127.0.0.1:8000/
2. 在浏览器窗口 B 打开 http://127.0.0.1:8000/
3. 在窗口 A 添加项目
4. 观察窗口 B 是否自动更新

### 方法 3: 查看服务器日志
1. 找到 Daphne 控制台窗口
2. 观察实时日志输出
3. 创建/删除项目时查看是否有相应的日志

## 📞 下一步

如果问题仍然存在，请提供以下信息：

1. Daphne 控制台的完整日志输出
2. 浏览器控制台的错误信息
3. WebSocket 连接状态（绿色/红色）
4. 创建/删除项目时是否收到通知

这些信息将帮助进一步诊断问题。
