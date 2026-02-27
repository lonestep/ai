#!/usr/bin/env python
"""
🔒 Django 安全检查脚本

运行此脚本检查项目配置的安全问题
"""

import os
import sys
from pathlib import Path

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent))

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'myproject.settings')

import django
django.setup()

from django.conf import settings

# ============================================================================
# 安全检查项
# ============================================================================

class SecurityCheck:
    def __init__(self):
        self.issues = []
        self.warnings = []
        self.passed = []

    def add_issue(self, check, message):
        self.issues.append((check, message))

    def add_warning(self, check, message):
        self.warnings.append((check, message))

    def add_passed(self, check, message):
        self.passed.append((check, message))

    def check_debug_mode(self):
        """检查是否在调试模式"""
        check_name = "DEBUG 模式"
        if settings.DEBUG:
            self.add_issue(check_name,
                          "[FAIL] DEBUG = True - 生产环境必须设置为 False")
        else:
            self.add_passed(check_name, "[PASS] DEBUG = False")

    def check_secret_key(self):
        """检查 SECRET_KEY"""
        check_name = "SECRET_KEY"
        if 'django-insecure' in settings.SECRET_KEY:
            self.add_issue(check_name,
                          "[FAIL] SECRET_KEY 使用默认值 - 请生成新的密钥")
        else:
            self.add_passed(check_name, "[PASS] SECRET_KEY 已配置")

    def check_allowed_hosts(self):
        """检查 ALLOWED_HOSTS"""
        check_name = "ALLOWED_HOSTS"
        if not settings.ALLOWED_HOSTS:
            self.add_warning(check_name,
                           "[WARN] ALLOWED_HOSTS 为空 - 生产环境需要配置")
        else:
            self.add_passed(check_name, f"[PASS] ALLOWED_HOSTS: {settings.ALLOWED_HOSTS}")

    def check_https(self):
        """检查 HTTPS 配置"""
        check_name = "HTTPS 配置"
        if hasattr(settings, 'SECURE_SSL_REDIRECT'):
            if settings.SECURE_SSL_REDIRECT:
                self.add_passed(check_name, "[PASS] SECURE_SSL_REDIRECT = True")
            else:
                self.add_warning(check_name,
                               "[WARN] SECURE_SSL_REDIRECT 未启用")
        else:
            self.add_warning(check_name, "[WARN] SECURE_SSL_REDIRECT 未配置")

    def check_database(self):
        """检查数据库配置"""
        check_name = "数据库配置"
        db_backend = settings.DATABASES['default']['ENGINE']
        if 'sqlite' in db_backend.lower():
            self.add_warning(check_name,
                           "[WARN] 使用 SQLite - 生产环境建议使用 PostgreSQL/MySQL")
        else:
            self.add_passed(check_name, f"[PASS] 使用 {db_backend}")

    def check_static_files(self):
        """检查静态文件配置"""
        check_name = "静态文件配置"
        if hasattr(settings, 'STATIC_ROOT') and settings.STATIC_ROOT:
            self.add_passed(check_name, f"[PASS] STATIC_ROOT: {settings.STATIC_ROOT}")
        else:
            self.add_warning(check_name, "[WARN] STATIC_ROOT 未配置")

    def check_logging(self):
        """检查日志配置"""
        check_name = "日志配置"
        if hasattr(settings, 'LOGGING') and settings.LOGGING:
            self.add_passed(check_name, "[PASS] 日志已配置")
        else:
            self.add_warning(check_name, "[WARN] 日志未配置")

    def check_session_security(self):
        """检查会话安全"""
        check_name = "会话安全"
        checks = []

        if hasattr(settings, 'SESSION_COOKIE_SECURE'):
            if settings.SESSION_COOKIE_SECURE:
                checks.append("SESSION_COOKIE_SECURE")
            else:
                self.add_warning(check_name,
                               "[WARN] SESSION_COOKIE_SECURE 未启用")

        if hasattr(settings, 'SESSION_COOKIE_HTTPONLY'):
            if settings.SESSION_COOKIE_HTTPONLY:
                checks.append("SESSION_COOKIE_HTTPONLY")
            else:
                self.add_warning(check_name,
                               "[WARN] SESSION_COOKIE_HTTPONLY 未启用")

        if checks:
            self.add_passed(check_name, f"[PASS] {', '.join(checks)}")

    def check_csrf(self):
        """检查 CSRF 配置"""
        check_name = "CSRF 配置"
        if hasattr(settings, 'CSRF_COOKIE_SECURE'):
            if settings.CSRF_COOKIE_SECURE:
                self.add_passed(check_name, "[PASS] CSRF_COOKIE_SECURE = True")
            else:
                self.add_warning(check_name, "[WARN] CSRF_COOKIE_SECURE 未启用")

    def check_installed_apps(self):
        """检查已安装的应用"""
        check_name = "已安装应用"
        apps_to_check = [
            'channels',  # WebSocket
            'rest_framework',  # REST API
            'corsheaders',  # CORS
        ]

        for app in apps_to_check:
            if app in settings.INSTALLED_APPS:
                self.add_passed(check_name, f"[PASS] {app} 已安装")

    def run_all_checks(self):
        """运行所有安全检查"""
        print("=" * 60)
        print("[安全检查] Django 安全检查")
        print("=" * 60)
        print()

        self.check_debug_mode()
        self.check_secret_key()
        self.check_allowed_hosts()
        self.check_https()
        self.check_database()
        self.check_static_files()
        self.check_logging()
        self.check_session_security()
        self.check_csrf()
        self.check_installed_apps()

    def print_results(self):
        """打印检查结果"""
        print("\n" + "=" * 60)
        print("[检查结果] 检查结果")
        print("=" * 60)

        if self.issues:
            print("\n[关键问题] 关键问题:")
            for check, message in self.issues:
                print(f"  {message}")

        if self.warnings:
            print("\n[警告] 警告:")
            for check, message in self.warnings:
                print(f"  {message}")

        if self.passed:
            print("\n[通过] 通过的检查:")
            for check, message in self.passed:
                print(f"  {message}")

        print("\n" + "=" * 60)
        print(f"[总计] 总计: {len(self.passed)} 通过, {len(self.warnings)} 警告, {len(self.issues)} 问题")
        print("=" * 60)

        if self.issues:
            print("\n[失败] 发现关键问题，请修复后再部署到生产环境")
            return False
        elif self.warnings:
            print("\n[警告] 发现警告，建议在生产环境修复")
            return True
        else:
            print("\n[成功] 所有检查通过！")
            return True


# ============================================================================
# 主程序
# ============================================================================

if __name__ == '__main__':
    checker = SecurityCheck()
    checker.run_all_checks()
    success = checker.print_results()

    sys.exit(0 if success else 1)
