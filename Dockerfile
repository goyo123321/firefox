# 阶段1: 构建器 - 仅准备静态资产
FROM alpine:latest as builder

# 安装临时构建工具（这些不会进入最终镜像）
RUN apk add --no-cache git openssl

# 克隆 noVNC 及其依赖（主要的静态资产）
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /assets/novnc && \
    git clone --depth 1 https://github.com/novnc/websockify /assets/novnc/utils/websockify

# （可选）在第一阶段生成SSL证书
RUN mkdir -p /assets/novnc/utils/ssl && \
    cd /assets/novnc/utils/ssl && \
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout self.pem -out self.pem -days 3650 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null

# 阶段2: 最终运行时镜像
FROM alpine:latest

LABEL org.opencontainers.image.title="Lightweight Firefox with noVNC"
LABEL org.opencontainers.image.description="Ultra-lightweight Firefox browser with noVNC web access and VNC password support"
LABEL org.opencontainers.image.licenses="MIT"

# 首先更新包管理器
RUN apk update

# 安装所有运行时依赖（分步安装，便于调试）
RUN apk add --no-cache \
    firefox \
    xvfb \
    x11vnc \
    supervisor \
    bash \
    fluxbox \
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata

# 清理缓存
RUN rm -rf /var/cache/apk/*

# 创建必要的目录结构
RUN mkdir -p /var/log/supervisor /etc/supervisor/conf.d /root/.vnc

# 关键优化：从构建器阶段仅复制准备好的静态资产
COPY --from=builder /assets/novnc /opt/novnc

# 复制本地配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

# 设置noVNC默认跳转页面
RUN echo '<html><head><meta http-equiv="refresh" content="0;url=vnc.html"></head><body></body></html>' > /opt/novnc/index.html

# 为Firefox创建默认配置文件（如果/data/firefox没有挂载则使用这个）
RUN mkdir -p /default-firefox-profile && \
    mkdir -p /default-firefox-profile/firefox/default && \
    echo 'pref("intl.accept_languages", "en-US, en");' > /default-firefox-profile/firefox/default/prefs.js && \
    echo '{"HomePage":"about:blank","StartPage":"about:blank"}' > /default-firefox-profile/firefox/default/user.js

# 暴露端口
EXPOSE 7860 5900

# 声明挂载卷 - 现在只需要挂载一个目录
VOLUME /data

# 启动入口
CMD ["/usr/local/bin/start.sh"]
