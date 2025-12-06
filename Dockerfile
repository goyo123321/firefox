# 第一阶段：构建阶段 (Builder) - 安装所有软件
FROM alpine:latest AS builder

RUN apk add --no-cache \
    firefox-esr \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    bash \
    ttf-dejavu \
    && rm -rf /var/cache/apk/*

# 第二阶段：运行阶段 (Runner) - 创建最精简的运行时镜像
FROM alpine:latest

# 1. 安装最基础的运行时依赖
RUN apk add --no-cache \
    bash \
    libstdc++ \
    gcompat \
    ttf-dejavu \
    && rm -rf /var/cache/apk/*

# 2. 从 builder 阶段精确复制必需的文件
# 2.1 复制 Firefox
COPY --from=builder /usr/bin/firefox-esr /usr/bin/firefox-esr
COPY --from=builder /usr/lib/firefox-esr/ /usr/lib/firefox-esr/
COPY --from=builder /usr/share/firefox-esr/ /usr/share/firefox-esr/

# 2.2 复制 Xvfb 和 x11vnc
COPY --from=builder /usr/bin/xvfb-run /usr/bin/xvfb-run
COPY --from=builder /usr/bin/xvfb /usr/bin/xvfb
COPY --from=builder /usr/bin/x11vnc /usr/bin/x11vnc
# 复制 x11vnc 的关键库
COPY --from=builder /usr/lib/libvncserver.so* /usr/lib/

# 2.3 复制 noVNC 和 websockify
COPY --from=builder /usr/share/novnc/ /usr/share/novnc/
COPY --from=builder /usr/bin/websockify /usr/bin/websockify
COPY --from=builder /usr/lib/python3.11/site-packages/websockify/ /usr/lib/python3.11/site-packages/websockify/

# 2.4 复制 Supervisor
COPY --from=builder /usr/bin/supervisord /usr/bin/supervisord
COPY --from=builder /usr/lib/python3.11/site-packages/supervisor/ /usr/lib/python3.11/site-packages/supervisor/
# 尝试复制默认配置（可选，会被项目配置覆盖）
COPY --from=builder /etc/supervisord.conf /etc/supervisord.conf 2>/dev/null || echo "Info: 默认 supervisord.conf 不存在，将使用项目配置"

# 2.5 【可选/兜底】复制常用库目录（确保兼容性，但体积大）
# 如果取消注释，能解决大部分库缺失错误，但会显著增加镜像体积
# COPY --from=builder /usr/lib/ /usr/lib/

# 3. 创建用户、目录和符号链接（关键：这是一个完整的 RUN 指令）
RUN adduser -D -u 1000 firefoxuser \
    && mkdir -p /home/firefoxuser/.mozilla/firefox/default-release \
    && mkdir -p /etc/supervisor/conf.d \
    && chown -R firefoxuser:firefoxuser /home/firefoxuser \
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 4. 切换用户和工作目录
USER firefoxuser
WORKDIR /home/firefoxuser

# 5. 复制你项目中的配置文件（这些会覆盖或补充上面的文件）
COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
COPY --chown=firefoxuser:firefoxuser firefox-prefs.js ./
RUN chmod +x ./refresh.sh

# 6. 暴露端口并设置启动命令
EXPOSE 7860
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
