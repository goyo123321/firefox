# 阶段1: 构建器 - 仅准备静态资产
FROM alpine:3.20 as builder

# 安装临时构建工具
RUN apk add --no-cache git openssl && \
    mkdir -p /assets/novnc

# 克隆 noVNC 及其依赖
ARG NOVNC_VERSION=1.4.0
ARG WEBSOCKIFY_VERSION=v0.11.0

RUN git clone --depth 1 --branch v${NOVNC_VERSION} \
    https://github.com/novnc/noVNC.git /assets/novnc && \
    git clone --depth 1 --branch ${WEBSOCKIFY_VERSION} \
    https://github.com/novnc/websockify /assets/novnc/utils/websockify

# 生成自签名SSL证书
RUN mkdir -p /assets/novnc/utils/ssl && \
    cd /assets/novnc/utils/ssl && \
    openssl req -newkey rsa:2048 -nodes -keyout self.key \
        -x509 -days 3650 -out self.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    cat self.key self.crt > self.pem && \
    rm self.key self.crt

# 清理不需要的文件
RUN cd /assets/novnc && \
    rm -rf .git* test *.md docs utils/websockify/.git* && \
    find . -name "*.css" -type f -exec gzip -k {} \; && \
    find . -name "*.js" -type f -exec gzip -k {} \; && \
    find . -name "*.html" -type f -exec gzip -k {} \;

# 阶段2: 最终运行时镜像
FROM alpine:3.20

LABEL org.opencontainers.image.title="Firefox with noVNC - Local Storage at /data/firefox" \
      org.opencontainers.image.description="Firefox browser with noVNC, VNC password support, and persistent local storage at /data/firefox/" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="1.0.0" \
      maintainer="your-email@example.com"

# 创建非root用户
RUN addgroup -g 1000 -S appuser && \
    adduser -u 1000 -S appuser -G appuser && \
    mkdir -p /data/firefox && \
    chown -R appuser:appuser /data/firefox

# 设置环境变量
ENV DISPLAY=:99 \
    DISPLAY_WIDTH=1280 \
    DISPLAY_HEIGHT=720 \
    VNC_PORT=5900 \
    NOVNC_PORT=5800 \
    VNC_PASSWORD="" \
    LANG=en_US.UTF-8 \
    TZ=UTC \
    FIREFOX_PROFILE_DIR=/data/firefox \
    FIREFOX_DOWNLOAD_DIR=/data/firefox/downloads \
    FIREFOX_LOCAL_STORAGE=/data/firefox/storage

# 安装运行时依赖
RUN apk update && apk add --no-cache \
    bash \
    su-exec \
    tzdata \
    firefox \
    fluxbox \
    xvfb \
    x11vnc \
    supervisor \
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata \
    font-noto \
    font-noto-cjk \
    curl \
    gzip && \
    rm -rf /var/cache/apk/* && \
    mkdir -p \
        /var/log/supervisor \
        /etc/supervisor/conf.d \
        /home/appuser/.vnc \
        /home/appuser/.fluxbox && \
    chown -R appuser:appuser /home/appuser /var/log/supervisor

# 从构建器复制静态资产
COPY --from=builder --chown=appuser:appuser /assets/novnc /opt/novnc

# 复制配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
COPY fluxbox-init /home/appuser/.fluxbox/init

# 创建必要的目录结构
RUN mkdir -p ${FIREFOX_PROFILE_DIR} && \
    mkdir -p ${FIREFOX_DOWNLOAD_DIR} && \
    mkdir -p ${FIREFOX_LOCAL_STORAGE} && \
    # 设置noVNC默认跳转页面
    echo '<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=vnc.html"></head><body></body></html>' > /opt/novnc/index.html && \
    echo 'OK' > /opt/novnc/health && \
    # 设置权限
    chown -R appuser:appuser /opt/novnc ${FIREFOX_PROFILE_DIR} && \
    chmod +x /usr/local/bin/start.sh && \
    chmod 644 /opt/novnc/*.html /opt/novnc/*.js /opt/novnc/*.css 2>/dev/null || true

# 暴露端口
EXPOSE 7860 5900

# 声明数据卷（专门为Firefox数据）
VOLUME /data/firefox

# 切换为非root用户
USER appuser

# 工作目录
WORKDIR /home/appuser

# 启动入口
ENTRYPOINT ["/usr/local/bin/start.sh"]
