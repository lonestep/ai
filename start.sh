#!/bin/bash
echo "========================================"
echo "Django 项目启动脚本"
echo "========================================"
echo ""

echo "[1/2] 检查依赖..."
pip install -r requirements.txt

echo ""
echo "[2/2] 启动开发服务器..."
echo ""
echo "服务器将在 http://127.0.0.1:8000 启动"
echo "按 Ctrl+C 停止服务器"
echo ""

python manage.py runserver 0.0.0.0:8000
