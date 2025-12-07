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

# 安装依赖 - 使用正确的包名
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
    tigervnc  # 正确的包名，提供vncpasswd和vncserver

# 从第一阶段复制Firefox
COPY --from=firefox-builder /usr/lib/firefox /usr/lib/firefox
COPY --from=firefox-builder /usr/bin/firefox /usr/bin/firefox

# 修复符号链接问题
RUN if [ -f /usr/bin/firefox ]; then \
        ln -sf /usr/bin/firefox /usr/local/bin/firefox 2>/dev/null || true; \
    elif [ -f /usr/lib/firefox/firefox ]; then \
        ln -sf /usr/lib/firefox/firefox /usr/bin/firefox 2>/dev/null || true; \
        ln -sf /usr/lib/firefox/firefox /usr/local/bin/firefox 2>/dev/null || true; \
    fi

# 复制启动脚本
COPY entrypoint.sh /entrypoint.sh

# 设置权限
RUN chmod +x /entrypoint.sh && \
    mkdir -p /usr/share/novnc && \
    cp -r /usr/share/webapps/novnc/* /usr/share/novnc/ 2>/dev/null || true && \
    mkdir -p /var/log

# 暴露默认端口
EXPOSE 7860 5901

# 启动脚本
ENTRYPOINT ["/entrypoint.sh"]
