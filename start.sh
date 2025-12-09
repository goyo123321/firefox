#!/bin/bash

# 设置英文语言环境
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8

# 设置环境变量
export DISPLAY=${DISPLAY:-:99}
export DISPLAY_WIDTH=${DISPLAY_WIDTH:-1280}
export DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-720}
export VNC_PASSWORD=${VNC_PASSWORD:-admin}
export VNC_PORT=${VNC_PORT:-5900}
export NOVNC_PORT=${NOVNC_PORT:-7860}
export DATA_DIR=${DATA_DIR:-/data}

# 确保挂载的/data目录存在并有正确权限
if [ ! -d "$DATA_DIR" ]; then
    echo "Creating data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
    chmod 755 "$DATA_DIR"
fi

# 在/data目录下创建子目录结构
mkdir -p "$DATA_DIR/downloads"
mkdir -p "$DATA_DIR/firefox-profile"
mkdir -p "$DATA_DIR/config"
mkdir -p "$DATA_DIR/logs"

# 创建字体缓存
if [ ! -f "$DATA_DIR/config/fonts.cache" ]; then
    echo "Generating font cache..."
    fc-cache -f -v
    touch "$DATA_DIR/config/fonts.cache"
fi

# 创建VNC密码文件（如果不存在）
if [ ! -f /root/.vnc/passwd ]; then
    mkdir -p /root/.vnc
    x11vnc -storepasswd "$VNC_PASSWORD" /root/.vnc/passwd
    echo "VNC password set to: $VNC_PASSWORD"
fi

# 如果/data/firefox-profile中有配置文件，使用它
if [ -d "$DATA_DIR/firefox-profile" ] && [ "$(ls -A $DATA_DIR/firefox-profile)" ]; then
    echo "Using Firefox profile from $DATA_DIR/firefox-profile"
    rm -rf /root/.mozilla
    ln -sf "$DATA_DIR/firefox-profile" /root/.mozilla
fi

# 启动Xvfb（虚拟显示服务器）
Xvfb $DISPLAY -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24 -ac +extension GLX +render -noreset &

# 等待Xvfb启动
sleep 2

# 启动Fluxbox窗口管理器
fluxbox &

# 启动Firefox
firefox --display=$DISPLAY &

# 启动x11vnc VNC服务器
x11vnc -display $DISPLAY -forever -shared -rfbauth /root/.vnc/passwd -rfbport $VNC_PORT -bg -noxdamage -noxrecord -noxfixes -nopw -wait 5 -shared -permitfiletransfer -tightfilexfer &

# 启动noVNC WebSocket代理
/opt/novnc/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NOVNC_PORT &

# 启动Supervisor来管理进程
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# 保持容器运行
echo "======================================="
echo "Container is running!"
echo "======================================="
echo "Access noVNC at: http://localhost:${NOVNC_PORT}"
echo "VNC password: ${VNC_PASSWORD}"
echo ""
echo "Data directory mounted at: ${DATA_DIR}"
echo "  - Downloads: ${DATA_DIR}/downloads"
echo "  - Firefox profile: ${DATA_DIR}/firefox-profile"
echo "  - Config: ${DATA_DIR}/config"
echo "  - Logs: ${DATA_DIR}/logs"
echo "======================================="

# 进入无限循环保持容器运行
while true; do
    sleep 3600
done
