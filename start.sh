#!/bin/bash
set -e

# 设置语言环境
export LANG=${LANG:-en_US.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}

echo "========================================="
echo "Starting Ultra-Lightweight Firefox noVNC"
echo "========================================="
echo "Display: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "VNC Port: ${VNC_PORT}"
echo "noVNC Port: ${NOVNC_PORT}"
echo "Fonts: Minimal set (DejaVu + misc)"
echo "========================================="

# 设置VNC密码
if [ -n "${VNC_PASSWORD}" ] && [ "${VNC_PASSWORD}" != "changeme" ]; then
    echo "Setting VNC password..."
    mkdir -p /root/.vnc
    x11vnc -storepasswd "${VNC_PASSWORD}" /root/.vnc/passwd 2>/dev/null || true
    chmod 600 /root/.vnc/passwd
else
    echo "WARNING: Using default VNC password 'changeme'"
    echo "         Set VNC_PASSWORD environment variable to secure your instance"
    mkdir -p /root/.vnc
    x11vnc -storepasswd "changeme" /root/.vnc/passwd 2>/dev/null || true
    chmod 600 /root/.vnc/passwd
fi

# 设置权限
chown -R root:root /root/.vnc 2>/dev/null || true
chmod -R 700 /root/.vnc 2>/dev/null || true

# 清理旧日志
rm -f /var/log/supervisor/*.log 2>/dev/null || true

echo "Starting supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
