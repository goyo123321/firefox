VNC_PASSWORD# firefox

# Ultra-Lightweight Firefox with noVNC

一个基于Alpine的轻量级Docker镜像，提供支持VNC密码保护的Firefox浏览器，并可通过noVNC在网页中访问。

## 快速开始
```bash
# 克隆仓库
git clone https://github.com/goyo123321/lightweight-firefox-novnc.git
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

version: '3.8'

services:
  firefox:
    image: ghcr.io/goyo123321/test-firefox:latest  # 镜像名
    container_name: firefox
    restart: unless-stopped
    ports:
      - "${NOVNC_PORT:-7860}:7860"  # noVNC web界面
      - "${VNC_PORT:-5900}:5900"    # VNC服务器端口
    environment:
      - VNC_PASSWORD=${VNC_PASSWORD:-changeme}
      - DISPLAY_WIDTH=${DISPLAY_WIDTH:-1280}
      - DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-720}
      - NOVNC_PORT=${NOVNC_PORT:-7860}
      - VNC_PORT=${VNC_PORT:-5900}
      - DATA_DIR=/data  # 明确设置数据目录
    shm_size: "${SHM_SIZE:-1gb}"
    volumes:
      # 挂载Firefox配置文件目录（对应脚本中的FIREFOX_DATA_DIR）
      - firefox_data:/data/firefox
      # 挂载下载目录
      - ./downloads:/data/downloads

volumes:
  firefox_data:
```
# .env 文件内容示例
  ```bash
   # .env 文件内容示例
   VNC_PASSWORD=your_very_strong_password_here # 务必修改！
   DISPLAY_WIDTH=1280
   DISPLAY_HEIGHT=720
   NOVNC_PORT=7860
   VNC_PORT=5900
   SHM_SIZE=1g
   ```
   

启动后，通过浏览器访问 http://你的服务器IP:7860 即可。

卷挂载说明

镜像预设了两个重要的卷挂载点，确保数据持久化：

1. 脚本会在/data/firefox中存储Firefox配置
2. 脚本会创建/data/downloads目录用于下载
3. 脚本会正确设置X11显示和VNC配置
