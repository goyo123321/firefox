#!/bin/bash
set -e

# 创建VNC密码文件（如果设置了密码）
if [ -n "$VNC_PASSWORD" ]; then
    echo "设置VNC密码..."
    mkdir -p ~/.vnc
    echo "$VNC_PASSWORD" | x11vnc -storepasswd -
    
    # 创建加密的密码文件
    x11vnc -storepasswd "$VNC_PASSWORD" ~/.vnc/passwd 2>/dev/null
    
    VNC_PASSWD_OPT="-passwdfile ~/.vnc/passwd"
else
    echo "警告：未设置VNC_PASSWORD环境变量，VNC连接将不需要密码"
    VNC_PASSWD_OPT=""
fi

# 更新Supervisor配置中的端口
echo "配置noVNC端口：${NOVNC_PORT}"
echo "配置VNC端口：${VNC_PORT}"

# 生成动态的Supervisor配置文件
cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true

[program:xvfb]
command=Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}
autorestart=true

[program:fluxbox]
command=fluxbox
autorestart=true
environment=DISPLAY=:0

[program:x11vnc]
command=x11vnc -display :0 -forever -shared -rfbport ${VNC_PORT} ${VNC_PASSWD_OPT} -noxdamage
autorestart=true

[program:novnc]
command=websockify --web /usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT}
autorestart=true
EOF

# 设置Fluxbox配置
mkdir -p ~/.fluxbox
cat > ~/.fluxbox/init << EOF
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: false
background: none
[begin] (fluxbox)
[exec] (Firefox) {firefox --display=:0 --no-remote --new-instance}
[end]
EOF

echo "================================"
echo "Firefox + noVNC 容器已启动"
echo "noVNC Web访问: http://<host>:${NOVNC_PORT}"
echo "VNC服务器端口: ${VNC_PORT}"
if [ -n "$VNC_PASSWORD" ]; then
    echo "VNC密码: ${VNC_PASSWORD}"
else
    echo "警告：VNC连接未设置密码"
fi
echo "================================"

# 启动Supervisor
exec /usr/bin/supervisord -c /etc/supervisord.conf
