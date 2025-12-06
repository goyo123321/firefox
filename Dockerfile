# ==================== 单阶段构建 ====================
# 基于Alpine Linux，所有操作在此镜像内完成
FROM alpine:latest

# 1. 安装所有必要的软件包
# 使用一个RUN指令安装所有包，并立即清理缓存，以最小化镜像层体积
RUN apk add --no-cache \
    # 浏览器核心
    firefox \
    # 可选：添加其他语言包，如 firefox-lang-zh-cn
    firefox-lang-en \
    # Alpine运行Firefox的关键：glibc兼容层
    libc6-compat \
    # 虚拟显示、VNC服务器和Web VNC
    xvfb \
    x11vnc \
    novnc \
    websockify \
    # 轻量级窗口管理器 (比fluxbox更小)
    jwm \
    # 进程管理和初始化系统
    supervisor \
    dumb-init \
    # 基础字体
    ttf-freefont \
    # 可选：中文字体支持 (根据需要取消注释)
    # wqy-zenhei \
    # 用于健康检查和调试的小工具
    busybox-extras \
    && rm -rf /tmp/* /var/tmp/* \
    # 为noVNC创建便捷访问链接（通常novnc包会做，这里确保一下）
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html 2>/dev/null || true

# 2. 创建非特权用户和必要的目录结构
RUN adduser -D -u 1000 firefox-user \
    && mkdir -p /home/firefox-user/.mozilla \
    && mkdir -p /home/firefox-user/Downloads \
    && chown -R firefox-user:firefox-user /home/firefox-user

# 3. 复制配置文件（这些文件需要你提前准备在构建上下文中）
# 3.1 Supervisor 进程管理配置
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
# 3.2 JWM 窗口管理器配置
COPY jwmrc /etc/jwm/jwmrc

# 4. 设置健康检查（检查noVNC的Web服务是否就绪）
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:6080/ || exit 1

# 5. 声明运行时端口
EXPOSE 6080

# 6. 设置工作目录和用户
WORKDIR /home/firefox-user
USER firefox-user

# 7. 使用dumb-init作为入口点，由Supervisor管理所有后台进程
ENTRYPOINT ["dumb-init", "--"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
