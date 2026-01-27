#!/bin/bash

# ================= 配置区域 =================
# 在这里修改你的密码！
VNC_PASS="AkiRa13218*#"
# ===========================================

# 1. 强制将所有配置路径指向 /home/container
export HOME=/home/container
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export DISPLAY=:0

# 禁用 Firefox 沙盒 (防止崩溃)
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1

# 2. 确保配置目录存在
mkdir -p $XDG_CACHE_HOME $XDG_CONFIG_HOME $XDG_DATA_HOME

# 3. 设置 VNC 密码文件
# 创建密码存放目录
mkdir -p $HOME/.vnc
# 将密码写入文件 (x11vnc 专用格式)
x11vnc -storepasswd "$VNC_PASS" $HOME/.vnc/passwd

# 4. 启动虚拟屏幕
echo "🖥️ Starting Xvfb..."
Xvfb :0 -screen 0 1280x720x16 &
sleep 2

# 5. 启动窗口管理器
echo "🪟 Starting Fluxbox..."
fluxbox &

# 6. 启动 VNC 服务器 (内部监听 5900)
# 【关键修改】去掉了 -nopw，改成了 -rfbauth 使用密码文件
echo "🔗 Starting internal x11vnc with PASSWORD..."
x11vnc -display :0 -forever -rfbauth $HOME/.vnc/passwd -listen localhost -xkb -rfbport 5900 &
sleep 2

# 7. 启动 noVNC 网页代理
# 使用 $SERVER_PORT 变量 (自动适配面板端口)
CURRENT_PORT=${SERVER_PORT:-25830}
echo "🌐 Starting noVNC Web Server on port $CURRENT_PORT..."

# 监听外部端口，转发到内部 5900
websockify --web /usr/share/novnc $CURRENT_PORT localhost:5900 &

# 8. 启动 Firefox
echo "🦊 Starting Firefox..."
while true; do
    firefox --no-remote --display=:0
    echo "Firefox 崩溃或关闭，3秒后重启..."
    sleep 3
done
