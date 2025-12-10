#!/bin/bash
set -e

# 设置默认环境变量
: ${DISPLAY:=":99"}
: ${DISPLAY_WIDTH:="1280"}
: ${DISPLAY_HEIGHT:="720"}
: ${VNC_PORT:="5900"}
: ${NOVNC_PORT:="7860"}
: ${FIREFOX_PROFILE_DIR:="/data/firefox"}
: ${FIREFOX_DOWNLOAD_DIR:="/data/firefox/downloads"}
: ${FIREFOX_LOCAL_STORAGE:="/data/firefox/storage"}
: ${VNC_PASSWORD:="admin"}

# 设置时区
if [ -n "${TZ}" ]; then
    ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime
    echo ${TZ} > /etc/timezone
fi

# 创建必要的目录结构
mkdir -p /home/appuser/.vnc
mkdir -p ${FIREFOX_PROFILE_DIR}
mkdir -p ${FIREFOX_DOWNLOAD_DIR}
mkdir -p ${FIREFOX_LOCAL_STORAGE}

# 设置目录权限
chown -R appuser:appuser ${FIREFOX_PROFILE_DIR} 2>/dev/null || true

# 设置VNC密码
if [ -n "${VNC_PASSWORD}" ]; then
    echo "${VNC_PASSWORD}" | vncpasswd -f > /home/appuser/.vnc/passwd
    chmod 600 /home/appuser/.vnc/passwd
    export X11VNC_ARGS="-rfbauth /home/appuser/.vnc/passwd"
else
    export X11VNC_ARGS="-nopw"
fi

# 生成Firefox用户配置文件
cat > ${FIREFOX_PROFILE_DIR}/user.js << 'EOF'
// 基础配置
user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.folderList", 2);
user_pref("browser.download.dir", "/data/firefox/downloads");
user_pref("browser.download.downloadDir", "/data/firefox/downloads");
user_pref("browser.download.defaultFolder", "/data/firefox/downloads");
user_pref("browser.download.manager.showWhenStarting", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("devtools.everOpened", false);
user_pref("extensions.autoDisableScopes", 14);
user_pref("extensions.enabledScopes", 1);
user_pref("extensions.update.enabled", false);
user_pref("geo.enabled", false);
user_pref("network.cookie.cookieBehavior", 1);
user_pref("places.history.enabled", false);
user_pref("privacy.donottrackheader.enabled", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("security.ssl.require_safe_negotiation", false);
user_pref("signon.rememberSignons", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.rejected", true);

// 本地存储配置
user_pref("browser.cache.disk.parent_directory", "/data/firefox/cache");
user_pref("browser.cache.disk.enable", true);
user_pref("browser.cache.disk.capacity", 1048576);
user_pref("dom.storage.default_quota", 5120);
user_pref("dom.storage.enabled", true);
user_pref("dom.storage.default_bucket_quota", 5242880);

// 语言设置
user_pref("intl.accept_languages", "en-US, en");
user_pref("intl.locale.requested", "en-US");

// 禁用自动更新
user_pref("app.update.silent", false);
user_pref("app.update.staging.enabled", false);
user_pref("browser.search.update", false);
user_pref("extensions.update.enabled", false);
EOF

# 创建prefs.js（如果不存在）
if [ ! -f "${FIREFOX_PROFILE_DIR}/prefs.js" ]; then
    echo '// Firefox preferences' > "${FIREFOX_PROFILE_DIR}/prefs.js"
fi

# 创建扩展目录
mkdir -p "${FIREFOX_PROFILE_DIR}/extensions"
mkdir -p "${FIREFOX_PROFILE_DIR}/storage/default"

# 解压noVNC的gzip静态资源（如果存在）
if [ -f /opt/novnc/vnc.html.gz ]; then
    find /opt/novnc -name "*.gz" -exec gunzip -f {} \;
fi

# 设置日志文件权限
touch /var/log/supervisor/supervisord.log
chown appuser:appuser /var/log/supervisor/supervisord.log 2>/dev/null || true

# 输出启动信息
echo "==========================================="
echo "Firefox with noVNC Container"
echo "==========================================="
echo "Display: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
echo "VNC Port: ${VNC_PORT}"
echo "noVNC Port: ${NOVNC_PORT}"
echo "Firefox Profile: ${FIREFOX_PROFILE_DIR}"
echo "Downloads Directory: ${FIREFOX_DOWNLOAD_DIR}"
echo "Local Storage: ${FIREFOX_LOCAL_STORAGE}"
echo "==========================================="

# 启动supervisor
exec supervisord -c /etc/supervisor/supervisord.conf -n
