#!/bin/bash
echo "========================================"
echo "Django Channels WebSocket 启动脚本"
echo "========================================"
echo ""

echo "[1/3] 检查依赖..."
pip install -r requirements.txt

echo ""
echo "[2/3] 收集静态文件..."
python manage.py collectstatic --noinput

echo ""
echo "[3/3] 启动 Daphne ASGI 服务器..."
echo ""
echo "WebSocket 服务器将在 http://127.0.0.1:8000 启动"
echo "支持 HTTP 和 WebSocket 连接"
echo "按 Ctrl+C 停止服务器"
echo ""

daphne myproject.asgi:application -b 0.0.0.0 -p 8000
