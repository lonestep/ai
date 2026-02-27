#!/bin/bash
echo "========================================"
echo "收集静态文件用于生产环境"
echo "========================================"
echo ""

python manage.py collectstatic --noinput

echo ""
echo "静态文件收集完成！"
echo "文件已复制到 staticfiles/ 目录"
