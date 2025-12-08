VNC_PASSWORD# firefox

# Ultra-Lightweight Firefox with noVNC

一个基于Alpine的轻量级Docker镜像，提供支持VNC密码保护的Firefox浏览器，并可通过noVNC在网页中访问。

## 快速开始
```bash
# 克隆仓库
git clone https://github.com/YOUR-USERNAME/lightweight-firefox-novnc.git
cd lightweight-firefox-novnc

# 复制环境变量文件并修改密码
cp .env.example .env
# 编辑 .env 文件，设置你的 VNC_PASSWORD

# 使用 Docker Compose 启动
docker-compose up -d

docker-compose.yml：用于一键部署和运行，配置了端口、环境变量和卷挂载。
```
# 设置环境变量
DISPLAY=:99

DISPLAY_WIDTH=1280

DISPLAY_HEIGHT=720

VNC_PASSWORD=admin

VNC_PORT=5900

NOVNC_PORT=7860

LANG=en_US.UTF-8

```yaml
version: '3.8'
services:
  firefox:
    build: .
    container_name: lightweight-firefox
    restart: unless-stopped
    ports:
      - "${NOVNC_PORT:-7860}:7860"
      - "${VNC_PORT:-5900}:5900"
    environment:
      - VNC_PASSWORD=${VNC_PASSWORD:-admin123}
      - DISPLAY_WIDTH=${DISPLAY_WIDTH:-1280}
      - DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-720}
    shm_size: "${SHM_SIZE:-1gb}"
    volumes:
      # 持久化Firefox配置（如书签、插件）
      - firefox_profile:/root/.mozilla
      # 挂载下载目录：容器内的 /root/Downloads 对应宿主机的 ./downloads 目录
      - ./downloads:/root/Downloads

volumes:
  firefox_profile:
```

启动后，通过浏览器访问 http://你的服务器IP:7860 即可。

卷挂载说明

镜像预设了两个重要的卷挂载点，确保数据持久化：

· 下载目录：容器内的 /root/Downloads 自动挂载到宿主机的 ./downloads 目录。你所有通过Firefox下载的文件都会保存在这里。
· Firefox配置：容器内的 /root/.mozilla 挂载到Docker管理卷，用于保存你的书签、扩展和浏览历史。
