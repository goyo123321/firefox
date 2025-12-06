FROM alpine:latest

RUN apk add --no-cache \
    firefox-esr \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    bash \
    ttf-freefont \
    && rm -rf /var/cache/apk/* \
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

# 创建用户和配置目录（但不预装插件）
RUN adduser -D -u 1000 firefoxuser \
    && mkdir -p /home/firefoxuser/.mozilla/firefox/default-release \
    && chown -R firefoxuser:firefoxuser /home/firefoxuser

USER firefoxuser
WORKDIR /home/firefoxuser

# 仅复制必要的配置文件，不再复制或下载 .xpi 文件
COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
COPY --chown=firefoxuser:firefoxuser firefox-prefs.js /home/firefoxuser/.mozilla/firefox/default-release/user.js

RUN chmod +x ./refresh.sh

EXPOSE 7860
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
