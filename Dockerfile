# ============================================================================
# 阶段1: 占位构建器阶段
# ============================================================================
FROM alpine:3.18 AS builder
RUN echo "KasmVNC will be installed via APK in the final stage." && mkdir -p /tmp

# ============================================================================
# 阶段2: 最终运行时镜像 (基于 Alpine 3.18 LTS)
# ============================================================================
FROM alpine:3.18

# 镜像元数据
LABEL org.opencontainers.image.title="Firefox with KasmVNC (Alpine 3.18)"
LABEL org.opencontainers.image.description="Stable Firefox browser with KasmVNC web access on Alpine 3.18 LTS"
LABEL org.opencontainers.image.licenses="MIT"

# 1. 更新源并分步安装系统包，确保每步成功
RUN apk update && apk add --no-cache \
    bash \
    supervisor \
    xvfb \
    fluxbox \
    coreutils \
    findutils \
    file \
    wget \
    ca-certificates \
    && rm -rf /var/cache/apk/* && echo "✅ 核心系统包安装完成"

# 2. 安装X11图形库
RUN apk add --no-cache \
    libx11 \
    libxext \
    libxi \
    libxrandr \
    libxfixes \
    libxdamage \
    libxcursor \
    libxtst \
    && echo "✅ X11图形库安装完成"

# 3. 安装字体
RUN apk add --no-cache \
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    && echo "✅ 基础字体安装完成"

# 4. 安装编码与网络库
RUN apk add --no-cache \
    libjpeg-turbo \
    libpng \
    libwebp \
    openssl \
    nettle \
    && echo "✅ 编码与网络库安装完成"

# 5. 安装VNC核心库
# 注释掉原有的安装命令，因为KasmVNC APK包已自带依赖
RUN echo "跳过单独安装 libvncserver/libvncclient，KasmVNC APK包已包含必要库。" && \
    echo "✅ 已跳过VNC库安装步骤"

# 6. 安装Firefox及其额外字体
RUN apk add --no-cache \
    firefox \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata \
    && echo "✅ Firefox及额外字体安装完成"

# 7. 安装KasmVNC官方预编译包 (专为 Alpine 3.18 构建)
# 注意：此URL对应 v1.4.0，架构为 x86_64。如需其他版本或ARM架构，请对应修改。
RUN wget -q https://github.com/kasmtech/KasmVNC/releases/download/v1.4.0/kasmvncserver_alpine_318_1.4.0_x86_64.apk -O /tmp/kasmvnc.apk && \
    apk add --allow-untrusted /tmp/kasmvnc.apk && \
    rm /tmp/kasmvnc.apk && \
    echo "✅ KasmVNC (Alpine 3.18专用版) 安装完成"

# 8. 设置语言环境
RUN apk add --no-cache locales && \
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && \
    echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen && \
    locale-gen en_US.UTF-8 en_GB.UTF-8 && \
    rm -rf /var/cache/apk/* && \
    echo "✅ 语言环境设置完成"

# 9. 创建目录结构
RUN mkdir -p \
    /var/log/supervisor \
    /etc/supervisor/conf.d \
    /root/.vnc \
    /root/.fluxbox \
    /root/.mozilla \
    /data \
    /data/downloads \
    /data/bookmarks \
    /data/cache \
    /data/config \
    /data/tmp \
    /data/backups \
    && chmod -R 777 /data && \
    echo "✅ 目录结构创建完成"

# 10. 复制配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
COPY init-storage.sh /usr/local/bin/init-storage.sh
COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/*.sh && \
    echo "✅ 配置文件复制完成"

# 11. 创建Firefox配置模板
RUN mkdir -p /etc/firefox/template && \
    cat > /etc/firefox/template/prefs.js << 'EOF'
user_pref("browser.cache.disk.parent_directory", "/data/cache");
user_pref("browser.download.dir", "/data/downloads");
user_pref("browser.download.folderList", 2);
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.bookmarks.file", "/data/bookmarks/bookmarks.html");
user_pref("dom.storage.default_quota", 5242880);
user_pref("dom.storage.enabled", true);
user_pref("dom.indexedDB.enabled", true);
user_pref("intl.accept_languages", "en-US, en");
user_pref("font.language.group", "en-US");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.page", 0);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
EOF

# 12. 设置Fluxbox
RUN echo '[begin] (fluxbox)' > /root/.fluxbox/menu && \
    echo '[exec] (Firefox) {firefox}' >> /root/.fluxbox/menu && \
    echo '[exec] (Terminal) {xterm}' >> /root/.fluxbox/menu && \
    echo '[separator]' >> /root/.fluxbox/menu && \
    echo '[exit] (Exit)' >> /root/.fluxbox/menu && \
    echo '[end]' >> /root/.fluxbox/menu && \
    echo 'firefox &' > /root/.fluxbox/startup && \
    echo 'exec fluxbox' >> /root/.fluxbox/startup

# 13. 暴露端口
EXPOSE 5901
EXPOSE 7860

# 15. 数据卷
VOLUME ["/data"]

# 17. 启动入口
ENTRYPOINT ["/usr/local/bin/start.sh"]
