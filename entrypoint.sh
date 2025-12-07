#!/bin/bash
set -e

echo "===== Firefox + noVNC 容器启动 ====="
echo "启动时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 设置默认环境变量
: ${VNC_PASSWORD:=alpine}
: ${NOVNC_PORT:=7860}
: ${VNC_PORT:=5901}
: ${DISPLAY_WIDTH:=1280}
: ${DISPLAY_HEIGHT:=720}
: ${DISPLAY_DEPTH:=24}
: ${DISPLAY_NUM:=1}

echo "=== 配置信息 ==="
echo "• noVNC端口: ${NOVNC_PORT}"
echo "• VNC端口: ${VNC_PORT}"
echo "• 分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}"
echo "• 显示编号: :${DISPLAY_NUM}"

# 创建必要的目录
mkdir -p ~/.fluxbox /var/log ~/.vnc

# 检查Firefox
if ! command -v firefox > /dev/null 2>&1; then
    echo "• 检查到Firefox未安装，正在安装..."
    apk add --no-cache firefox 2>/dev/null || true
fi

# 创建Fluxbox配置
echo "• 创建Fluxbox桌面配置..."
cat > ~/.fluxbox/init << 'EOF'
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: false
background: none
[begin] (fluxbox)
[exec] (Firefox) {firefox --display=:1 --no-remote --new-instance}
[end]
EOF

# 设置noVNC首页
if [ -f /usr/share/novnc/vnc.html ]; then
    cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html
elif [ -f /usr/share/webapps/novnc/vnc.html ]; then
    cp /usr/share/webapps/novnc/vnc.html /usr/share/novnc/index.html
fi

# 创建 X11 启动脚本
cat > /root/.xinitrc << 'EOF'
#!/bin/sh
exec fluxbox
EOF

chmod +x /root/.xinitrc

# VNC密码处理 - 使用 tightvncserver 的密码设置
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "none" ] && [ "$VNC_PASSWORD" != "off" ]; then
    echo "• 设置VNC密码..."
    
    # 设置tightvncserver密码
    echo "$VNC_PASSWORD" > /tmp/vncpass.txt
    echo "$VNC_PASSWORD" >> /tmp/vncpass.txt
    echo "n" >> /tmp/vncpass.txt  # 不设置view-only密码
    
    cat /tmp/vncpass.txt | vncpasswd -f > ~/.vnc/passwd
    chmod 600 ~/.vnc/passwd
    
    # 创建tightvncserver配置文件
    cat > ~/.vnc/config << EOF
geometry=${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}
depth=${DISPLAY_DEPTH}
desktop=Firefox-novnc
localhost
alwaysshared
EOF
    
    echo "✓ VNC密码设置成功"
    VNC_AUTH_OPT=""
else
    echo "• VNC密码: 未设置 (无密码连接)"
    # 对于tightvncserver，无密码需要特殊处理
    VNC_AUTH_OPT="-SecurityTypes None"
fi

echo "• 生成Supervisor配置文件..."

# 动态生成Supervisor配置文件
cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
logfile_maxbytes=1MB
logfile_backups=1
loglevel=info

[program:xvfb]
command=Xvfb :1 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} -ac +extension GLX +render -noreset
autorestart=true
startretries=5
stdout_logfile=/var/log/xvfb.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/xvfb.err.log
stderr_logfile_maxbytes=1MB

[program:fluxbox]
command=fluxbox
autorestart=true
environment=DISPLAY=:1
startretries=5
stdout_logfile=/var/log/fluxbox.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/fluxbox.err.log
stderr_logfile_maxbytes=1MB

[program:vncserver]
command=vncserver :1 -geometry ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} -depth ${DISPLAY_DEPTH} -localhost no -xstartup /root/.xinitrc ${VNC_AUTH_OPT}
autorestart=true
startretries=5
stdout_logfile=/var/log/vncserver.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/vncserver.err.log
stderr_logfile_maxbytes=1MB

[program:novnc]
command=websockify --web /usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT}
autorestart=true
startretries=5
stdout_logfile=/var/log/novnc.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/novnc.err.log
stderr_logfile_maxbytes=1MB
EOF

echo "=== 启动完成 ==="
echo "• 访问地址: http://<主机IP>:${NOVNC_PORT}"
echo "• VNC服务器端口: ${VNC_PORT}"
echo "• 显示分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "none" ] && [ "$VNC_PASSWORD" != "off" ]; then
    echo "• VNC认证: 密码已启用"
else
    echo "• VNC认证: 无密码"
fi
echo "================================"

# 启动所有服务
echo "• 启动Supervisor管理所有服务..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
