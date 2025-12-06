FROM alpine:latest

RUN apk add --no-cache \
    firefox-esr \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    supervisor \
    bash \
    curl \
    wget \
    ttf-freefont \
    && rm -rf /var/cache/apk/* \
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html

RUN adduser -D -u 1000 firefoxuser \
    && mkdir -p /home/firefoxuser/.mozilla/extensions \
    && chown -R firefoxuser:firefoxuser /home/firefoxuser

USER firefoxuser
WORKDIR /home/firefoxuser

RUN wget -q -O /tmp/auto_refresh.xpi \
    "https://addons.mozilla.org/firefox/downloads/file/4278596/auto_refresh_page-2.3.0.xpi" \
    && mv /tmp/auto_refresh.xpi /home/firefoxuser/.mozilla/extensions/auto_refresh_page@browser.extensions.com.xpi

COPY --chown=firefoxuser:firefoxuser supervisord.conf /etc/supervisor/conf.d/
COPY --chown=firefoxuser:firefoxuser refresh.sh ./
COPY --chown=firefoxuser:firefoxuser firefox-prefs.js /home/firefoxuser/.mozilla/firefox/default-release/user.js

RUN chmod +x ./refresh.sh

EXPOSE 7860

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
