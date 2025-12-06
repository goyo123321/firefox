# 使用 Alpine 作为基础镜像
FROM alpine:latest

# 1. 安装绝对最小化的必要包
# 使用 --no-cache 并在同一层清理，避免缓存文件增加体积
RUN apk add --no-cache \
    # 核心应用
    firefox-esr \
    # 图形显示与远程访问（最小集）
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    # 基础系统工具
    bash \
    # 可选：更小的字体包，如果网页显示异常可以换回 ttf-freefont
    ttf-dejavu \
    && rm -rf /var/cache/apk/* \
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 2. 创建用户
RUN adduser -D -u 1000 firefoxuser \
    && mkdir -p /home/firefoxuser/.mozilla/firefox/default-release \
    && chown -R firefoxuser:firefoxuser /home/firefoxuser

USER firefoxuser
WORKDIR /home/firefoxuser

# 3. 复制配置文件
COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
COPY --chown=firefoxuser:firefoxuser firefox-prefs.js ./
RUN chmod +x ./refresh.sh

EXPOSE 7860
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
