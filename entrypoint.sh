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

# 5. 启动 VNC 服务器
# 监听 5800 端口 (面板默认)，无密码
echo "🔗 Starting VNC on port 5800..."
x11vnc -display :0 -forever -nopw -listen 0.0.0.0 -xkb -rfbport 5800 &

# 6. 启动 Firefox (无限循环保活)
echo "🦊 Starting Firefox..."
while true; do
    # --no-remote 允许复用，--kiosk 可以全屏模式(可选)
    firefox --no-remote --display=:0
    echo "Firefox 崩溃或关闭，3秒后重启..."
    sleep 3
done
