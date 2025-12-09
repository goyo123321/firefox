#!/bin/bash
set -e

# 设置时区
if [ -n "${TZ}" ]; then
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
    echo ${TZ} > /etc/timezone
fi

# 设置VNC密码（如果提供）
if [ -n "${VNC_PASSWORD}" ]; then
    mkdir -p /root/.vnc
    echo -n "${VNC_PASSWORD}" | mkpasswd -m sha-256 -s > /root/.vnc/passwd
    chmod 600 /root/.vnc/passwd
    echo "VNC密码已设置。"
fi

# 启动supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
