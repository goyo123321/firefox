# 多阶段构建以减小最终镜像大小
# 阶段1: 构建noVNC
FROM alpine:latest as novnc-builder

RUN apk add --no-cache git && \
    git clone --depth 1 https://github.com/novnc/noVNC.git /tmp/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /tmp/novnc/utils/websockify

# 阶段2: 最终镜像
FROM alpine:latest

LABEL org.opencontainers.image.title="Lightweight Firefox with noVNC"
LABEL org.opencontainers.image.description="Ultra-lightweight Firefox browser with noVNC web access and VNC password support"
LABEL org.opencontainers.image.vendor="Your Name"
LABEL org.opencontainers.image.licenses="MIT"

# 安装最小化软件包 + 最小字体集
RUN apk add --no-cache \
    firefox \
    xvfb \
    x11vnc \
    supervisor \
    bash \
    fluxbox \
    # 最小字体集 - 解决方框问题
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    && rm -rf /var/cache/apk/*

# 创建必要的目录
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d /root/.vnc

# 从构建阶段复制noVNC
COPY --from=novnc-builder /tmp/novnc /opt/novnc

# 复制配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh

# 设置权限
RUN chmod +x /usr/local/bin/start.sh

# 设置默认noVNC首页
RUN echo '<html><head><meta http-equiv="refresh" content="0;url=vnc.html"></head><body></body></html>' > /opt/novnc/index.html

# 暴露端口
EXPOSE 7860 5900

# 设置环境变量
ENV DISPLAY=:99
ENV DISPLAY_WIDTH=1280
ENV DISPLAY_HEIGHT=720
ENV VNC_PASSWORD=admin123
ENV VNC_PORT=5900
ENV NOVNC_PORT=7860
ENV LANG=en_US.UTF-8

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD netstat -an | grep :${NOVNC_PORT} > /dev/null 2>&1 || exit 1

# 启动服务
CMD ["/usr/local/bin/start.sh"]
