#!/bin/bash

# 1. 强制将所有配置路径指向 /home/container (避开只读系统锁)
export HOME=/home/container
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export DISPLAY=:0

# 2. 确保配置目录存在
mkdir -p $XDG_CACHE_HOME $XDG_CONFIG_HOME $XDG_DATA_HOME

# 3. 启动虚拟屏幕 (1280x720)
echo "🖥️ Starting Xvfb..."
Xvfb :0 -screen 0 1280x720x16 &
sleep 2

# 4. 启动窗口管理器 (防崩溃)
echo "🪟 Starting Fluxbox..."
fluxbox &

# 5. 启动 VNC 服务器 (内部使用)
# 注意：改为监听 localhost:5900，不让外部直接连 VNC 了
echo "🔗 Starting internal x11vnc..."
x11vnc -display :0 -forever -nopw -listen localhost -xkb -rfbport 5900 &
sleep 2

# 6. 启动 noVNC 网页代理 (核心步骤)
# 监听 5800 端口，把它转换成网页，指向内部的 5900
echo "🌐 Starting noVNC Web Server on port 5800..."
# --web 指定网页文件位置，5800 是对外端口，localhost:5900 是目标
websockify --web /usr/share/novnc 5800 localhost:5900 &

# 7. 启动 Firefox (无限循环保活)
echo "🦊 Starting Firefox..."
while true; do
    firefox --no-remote --display=:0
    echo "Firefox 崩溃或关闭，3秒后重启..."
    sleep 3
done
