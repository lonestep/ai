#!/bin/bash
echo "========================================"
echo "生产环境启动脚本"
echo "========================================"
echo ""

# 设置环境变量
export DEBUG=False

# 收集静态文件
echo "收集静态文件..."
python manage.py collectstatic --noinput

# 启动 Gunicorn
echo ""
echo "启动 Gunicorn 服务器..."
echo "生产服务器将在 http://0.0.0.0:8000 运行"
echo ""

gunicorn myproject.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 4 \
    --threads 2 \
    --timeout 30 \
    --access-logfile - \
    --error-logfile - \
    --log-level info
