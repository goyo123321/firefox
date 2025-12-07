#!/bin/bash
set -e

echo "===== Firefox + noVNC 容器启动 ====="
echo "启动时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 设置默认环境变量
: ${VNC_PASSWORD:=alpine}
: ${NOVNC_PORT:=6901}
: ${VNC_PORT:=5901}
: ${DISPLAY_WIDTH:=1280}
: ${DISPLAY_HEIGHT:=720}
: ${DISPLAY_DEPTH:=24}

echo "=== 配置信息 ==="
echo "• noVNC端口: ${NOVNC_PORT}"
echo "• VNC端口: ${VNC_PORT}"
echo "• 分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH}"

# 创建必要的目录
mkdir -p ~/.fluxbox /var/log

# 检查Firefox
if ! command -v firefox > /dev/null 2>&1; then
    echo "• 检查到Firefox未安装，正在安装..."
    apk add --no-cache firefox 2>/dev/null || true
fi

# VNC密码处理 - 使用expect脚本完全绕过交互问题
if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "none" ] && [ "$VNC_PASSWORD" != "off" ]; then
    echo "• 设置VNC密码..."
    
    # 创建目录
    mkdir -p ~/.vnc
    
    # 使用expect创建密码文件，完全模拟交互
    cat > /tmp/create_vnc_passwd.exp << EOF
#!/usr/bin/expect -f
set password [lindex \$argv 0]
set password_file [lindex \$argv 1]
spawn x11vnc -storepasswd \$password \$password_file
expect "Enter VNC password:"
send "\$password\r"
expect "Verify password:"
send "\$password\r"
expect eof
EOF
    
    chmod +x /tmp/create_vnc_passwd.exp
    
    if /tmp/create_vnc_passwd.exp "$VNC_PASSWORD" ~/.vnc/passwd 2>&1 | grep -v "stty"; then
        if [ -f ~/.vnc/passwd ] && [ -s ~/.vnc/passwd ]; then
            chmod 600 ~/.vnc/passwd
            VNC_AUTH_OPT="-passwdfile ~/.vnc/passwd"
            echo "✓ VNC密码文件创建成功"
        else
            echo "⚠ 密码文件创建失败，使用无密码连接"
            VNC_AUTH_OPT="-nopw"
        fi
    else
        echo "⚠ expect脚本执行失败，尝试备用方案..."
        # 备用方案：使用简单的密码文件
        echo "$VNC_PASSWORD" > ~/.vnc/passwd_plain
        # 尝试另一种方法
        echo -e "$VNC_PASSWORD\n$VNC_PASSWORD\n" | x11vnc -storepasswd - ~/.vnc/passwd_alt 2>&1 | grep -v "stty" || true
        
        if [ -f ~/.vnc/passwd_alt ]; then
            mv ~/.vnc/passwd_alt ~/.vnc/passwd
            chmod 600 ~/.vnc/passwd
            VNC_AUTH_OPT="-passwdfile ~/.vnc/passwd"
        else
            echo "⚠ 所有密码设置方法都失败，使用无密码连接"
            VNC_AUTH_OPT="-nopw"
        fi
    fi
    
    rm -f /tmp/create_vnc_passwd.exp
else
    echo "• VNC密码: 未设置 (无密码连接)"
    VNC_AUTH_OPT="-nopw"
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
command=Xvfb :0 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x${DISPLAY_DEPTH} -ac +extension GLX +render -noreset
autorestart=true
startretries=5
stdout_logfile=/var/log/xvfb.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/xvfb.err.log
stderr_logfile_maxbytes=1MB

[program:fluxbox]
command=fluxbox
autorestart=true
environment=DISPLAY=:0
startretries=5
stdout_logfile=/var/log/fluxbox.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/fluxbox.err.log
stderr_logfile_maxbytes=1MB

[program:x11vnc]
command=x11vnc -display :0 -forever -shared -rfbport ${VNC_PORT} ${VNC_AUTH_OPT} -noxdamage
autorestart=true
startretries=5
stdout_logfile=/var/log/x11vnc.log
stdout_logfile_maxbytes=1MB
stderr_logfile=/var/log/x11vnc.err.log
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

# 创建Fluxbox配置
echo "• 创建Fluxbox桌面配置..."
mkdir -p ~/.fluxbox
cat > ~/.fluxbox/init << 'EOF'
session.screen0.toolbar.visible: false
session.screen0.fullMaximization: false
background: none
[begin] (fluxbox)
[exec] (Firefox) {firefox --display=:0 --no-remote --new-instance}
[end]
EOF

# 设置noVNC首页
if [ -f /usr/share/novnc/vnc.html ]; then
    cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html
elif [ -f /usr/share/webapps/novnc/vnc.html ]; then
    cp /usr/share/webapps/novnc/vnc.html /usr/share/novnc/index.html
fi

echo "=== 启动完成 ==="
echo "• 访问地址: http://<主机IP>:${NOVNC_PORT}"
echo "• VNC服务器端口: ${VNC_PORT}"
echo "• 显示分辨率: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
if [ "$VNC_AUTH_OPT" = "-nopw" ]; then
    echo "• VNC认证: 无密码"
else
    echo "• VNC认证: 密码已启用"
fi
echo "================================"

# 启动所有服务
echo "• 启动Supervisor管理所有服务..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
