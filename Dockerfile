# 第一阶段：构建Firefox
FROM alpine:edge AS firefox-builder
WORKDIR /tmp

# 安装Firefox及依赖
RUN apk update && \
    apk add --no-cache \
    firefox \
    ttf-freefont \
    dbus

# 第二阶段：构建最终镜像
FROM alpine:edge
WORKDIR /root

# 安装依赖
RUN apk update && \
    apk add --no-cache \
    bash \
    fluxbox \
    xvfb \
    x11vnc \
    supervisor \
    novnc \
    websockify \
    ttf-freefont \
    sudo \
    font-noto-cjk \
    tigervnc  # 提供vncpasswd命令

# 从第一阶段复制Firefox
COPY --from=firefox-builder /usr/lib/firefox /usr/lib/firefox
COPY --from=firefox-builder /usr/bin/firefox /usr/bin/firefox
RUN ln -s /usr/lib/firefox/firefox /usr/local/bin/firefox && \
    ln -s /usr/lib/firefox/firefox /usr/bin/firefox

# 复制配置文件
COPY entrypoint.sh /entrypoint.sh

# 设置权限和准备
RUN chmod +x /entrypoint.sh && \
    mkdir -p /usr/share/novnc && \
    cp -r /usr/share/webapps/novnc/* /usr/share/novnc/ 2>/dev/null || true

# 暴露端口
EXPOSE ${NOVNC_PORT:-6901} ${VNC_PORT:-5901}

# 环境变量
ENV VNC_PASSWORD=alpine
ENV NOVNC_PORT=6901
ENV VNC_PORT=5901
ENV DISPLAY_WIDTH=1280
ENV DISPLAY_HEIGHT=720
ENV DISPLAY_DEPTH=24

# 启动脚本
ENTRYPOINT ["/entrypoint.sh"]
