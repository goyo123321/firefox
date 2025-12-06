# 使用 Debian Slim 作为基础镜像
FROM debian:12-slim

# 安装最小化必要组件
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    firefox-esr \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    # 相比 Alpine，Debian 下 Firefox 的图形依赖更简洁
    libgtk-3-0 \
    libx11-xcb1 \
    libxtst6 \
    # 中文字体支持（可选，可移除）
    fonts-wqy-microhei \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    # 为 noVNC 创建快捷方式
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 创建应用程序用户
RUN useradd -m -u 1000 -s /bin/bash firefoxuser
USER firefoxuser
WORKDIR /home/firefoxuser

# 复制配置文件
COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
COPY --chown=firefoxuser:firefoxuser firefox-prefs.js ./
RUN chmod +x ./refresh.sh

# 暴露 Hugging Face Spaces 默认端口
EXPOSE 7860

# 启动 Supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
