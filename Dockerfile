# ============================================================================
# 阶段1: 构建器 - 下载并提取预编译的KasmVNC
# 使用预编译包替代源码编译，避免编译失败，构建速度更快、更稳定。
# ============================================================================
FROM alpine:latest AS builder

# 安装下载和提取工具
RUN apk add --no-cache wget xz

# 定义 KasmVNC 版本和架构（可前往 https://github.com/kasmtech/KasmVNC/releases 查看最新版）
ARG KASMVNC_VERSION="1.0.1"
ARG KASMVNC_ARCH="linux_x86_64"

# 下载、验证并提取官方预编译的二进制包
RUN cd /tmp && \
    wget -q https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_${KASMVNC_ARCH}.tar.xz && \
    echo "下载完成，正在提取文件..." && \
    mkdir -p /opt/kasmvnc && \
    tar -xJf kasmvncserver_${KASMVNC_ARCH}.tar.xz -C /opt/kasmvnc --strip-components=1 && \
    rm kasmvncserver_${KASMVNC_ARCH}.tar.xz && \
    echo "KasmVNC v${KASMVNC_VERSION} 预编译包已就绪."

# ============================================================================
# 阶段2: 最终运行时镜像
# ============================================================================
FROM alpine:latest

# 镜像元数据
LABEL org.opencontainers.image.title="Firefox with KasmVNC"
LABEL org.opencontainers.image.description="Lightweight Firefox browser accessible via high-performance KasmVNC web client"
LABEL org.opencontainers.image.licenses="MIT"

# 安装所有运行时依赖
RUN apk add --no-cache \
    firefox \
    xvfb \
    supervisor \
    bash \
    fluxbox \
    # 基础字体集
    font-misc-misc \
    font-cursor-misc \
    ttf-dejavu \
    ttf-droid \
    ttf-freefont \
    ttf-liberation \
    ttf-inconsolata \
    # 系统工具
    file \
    findutils \
    coreutils \
    # KasmVNC运行时依赖的X11库
    libjpeg-turbo \
    libpng \
    libwebp \
    libxtst \
    libx11 \
    libxext \
    libxi \
    libxrandr \
    libxfixes \
    libxdamage \
    libxcursor \
    # 网络和安全库
    openssl \
    nettle \
    # 清理缓存以减小镜像体积
    && rm -rf /var/cache/apk/*

# 设置英文语言环境
RUN apk add --no-cache locales \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.UTF-8 en_GB.UTF-8 \
    && rm -rf /var/cache/apk/*

# 创建必要的目录结构
RUN mkdir -p \
    /var/log/supervisor \
    /etc/supervisor/conf.d \
    /root/.vnc \
    /root/.fluxbox \
    /data \
    /data/downloads \
    /data/bookmarks \
    /data/cache \
    /data/config \
    /data/tmp \
    && chmod -R 777 /data

# 从构建器阶段复制已下载的KasmVNC二进制文件
COPY --from=builder /opt/kasmvnc/ /usr/local/

# 创建KasmVNC的符号链接以便在PATH中直接使用，并确保网页资源目录存在
RUN ln -sf /usr/local/bin/kasmvncserver /usr/bin/ && \
    ln -sf /usr/local/bin/kasmvncpasswd /usr/bin/ && \
    mkdir -p /usr/local/share/kasmvnc/web

# 复制所有本地配置文件
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start.sh /usr/local/bin/start.sh
COPY init-storage.sh /usr/local/bin/init-storage.sh
COPY backup.sh /usr/local/bin/backup.sh
COPY restore.sh /usr/local/bin/restore.sh
RUN chmod +x /usr/local/bin/*.sh

# 创建Firefox配置模板，将数据目录指向持久化存储
RUN mkdir -p /etc/firefox/template && \
    cat > /etc/firefox/template/prefs.js << 'EOF'
// Firefox preferences for containerized environment
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

# 设置一个极简的Fluxbox菜单
RUN echo '[begin] (fluxbox)' > /root/.fluxbox/menu && \
    echo '[exec] (Firefox) {firefox}' >> /root/.fluxbox/menu && \
    echo '[exec] (Terminal) {xterm}' >> /root/.fluxbox/menu && \
    echo '[separator]' >> /root/.fluxbox/menu && \
    echo '[exit] (Exit)' >> /root/.fluxbox/menu && \
    echo '[end]' >> /root/.fluxbox/menu

# 暴露网络端口
# KasmVNC RFB协议端口 (用于传统VNC客户端)
EXPOSE 5901
# KasmVNC WebSocket端口 (用于网页客户端访问)
EXPOSE 7860

# 声明数据卷，用于持久化用户数据
VOLUME ["/data"]

# 容器启动入口为自定义脚本
ENTRYPOINT ["/usr/local/bin/start.sh"]
