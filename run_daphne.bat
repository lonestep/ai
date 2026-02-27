@echo off
echo Starting Daphne WebSocket server...
cd /d "%~dp0"
daphne myproject.asgi:application -b 127.0.0.1 -p 8000
