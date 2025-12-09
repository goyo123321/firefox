#!/bin/bash

# 设置中文字体环境
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8

# 设置环境变量
export DISPLAY=${DISPLAY:-:99}
export DISPLAY_WIDTH=${DISPLAY_WIDTH:-1280}
export DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-720}
export VNC_PASSWORD=${VNC_PASSWORD:-admin}
export VNC_PORT=${VNC_PORT:-5900}
export NOVNC_PORT=${NOVNC_PORT:-7860}

# 创建字体缓存（确保字体被正确识别）
if [ ! -f /root/.fonts.cache ]; then
    echo "Generating font cache..."
    fc-cache -f -v
    touch /root/.fonts.cache
fi

# 创建VNC密码文件
if [ ! -f /root/.vnc/passwd ]; then
    mkdir -p /root/.vnc
    x11vnc -storepasswd "$VNC_PASSWORD" /root/.vnc/passwd
    echo "VNC password set to: $VNC_PASSWORD"
fi

# 启动Xvfb（虚拟显示服务器）
Xvfb $DISPLAY -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24 -ac +extension GLX +render -noreset &

# 等待Xvfb启动
sleep 2

# 启动Fluxbox窗口管理器
fluxbox &

# 启动Firefox（无头模式）
firefox --display=$DISPLAY &

# 启动x11vnc VNC服务器
x11vnc -display $DISPLAY -forever -shared -rfbauth /root/.vnc/passwd -rfbport $VNC_PORT -bg -noxdamage -noxrecord -noxfixes -nopw -wait 5 -shared -permitfiletransfer -tightfilexfer &

# 启动noVNC WebSocket代理
/opt/novnc/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT &

# 启动Supervisor来管理进程
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# 保持容器运行
echo "Container is running. Access noVNC at: http://localhost:$NOVNC_PORT"
echo "VNC password: $VNC_PASSWORD"

# 输出进程状态
ps aux

# 进入无限循环保持容器运行
while true; do
    sleep 3600
done
