#!/bin/bash
echo "Firefox 正在启动..."
echo "请通过Web界面访问，并手动安装 'Auto Refresh Page' 插件。"
exec firefox-esr --display=:99 --kiosk "https://idx.google.com"
