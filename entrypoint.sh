#!/bin/bash

# 1. 强制将所有配置路径指向 /home/container
export HOME=/home/container
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export DISPLAY=:0

# 【新增】解决 Firefox 崩溃/Tab Crash 问题的关键参数
# 禁用沙盒模式，因为非特权容器无法创建命名空间
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1

# 2. 确保配置目录存在
mkdir -p $XDG_CACHE_HOME $XDG_CONFIG_HOME $XDG_DATA_HOME

# 3. 启动虚拟屏幕
echo "🖥️ Starting Xvfb..."
Xvfb :0 -screen 0 1280x720x16 &
sleep 2

# 4. 启动窗口管理器
echo "🪟 Starting Fluxbox..."
fluxbox &

# 5. 启动 VNC 服务器 (内部监听 5900)
echo "🔗 Starting internal x11vnc..."
x11vnc -display :0 -forever -nopw -listen localhost -xkb -rfbport 5900 &
sleep 2

# 6. 启动 noVNC 网页代理 (关键修改位置！)
# 使用 $SERVER_PORT 变量，如果变量不存在则默认使用 25830
CURRENT_PORT=${SERVER_PORT:-25830}
echo "🌐 Starting noVNC Web Server on port $CURRENT_PORT..."

# 监听 $CURRENT_PORT，并转发到内部的 5900
websockify --web /usr/share/novnc $CURRENT_PORT localhost:5900 &

# 7. 启动 Firefox
echo "🦊 Starting Firefox..."
while true; do
    firefox --no-remote --display=:0
    echo "Firefox 崩溃或关闭，3秒后重启..."
    sleep 3
done
