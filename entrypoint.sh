#!/bin/bash

# ================= 配置区域 =================
VNC_PASS="AkiRa13218*#"
# 👈 核心修改：宽度 1280 (够宽)，高度 640 (够矮，绝对不出现滚动条)
RESOLUTION="1280x640x24"   
# ===========================================

# 1. 设置中文环境
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8

# 2. 基础路径
export HOME=/home/container
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export DISPLAY=:0

# 3. Firefox 性能与沙箱优化
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1
export MOZ_GFX_SPOOF_GL_VENDOR="Mesa"
export MOZ_GFX_SPOOF_GL_RENDERER="llvmpipe"
export MOZ_WEBRENDER=0
export MOZ_ACCELERATED=0
export MOZ_GMP_SANDBOX=0

# 4. 初始化目录
mkdir -p $XDG_CACHE_HOME $XDG_CONFIG_HOME $XDG_DATA_HOME
mkdir -p $HOME/.vnc $HOME/.mozilla/firefox/custom_profile.default

# 5. 注入配置
cat > $HOME/.mozilla/firefox/profiles.ini <<EOF
[General]
StartWithLastProfile=1
[Profile0]
Name=Default
IsRelative=1
Path=custom_profile.default
Default=1
EOF

cat > "$HOME/.mozilla/firefox/custom_profile.default/user.js" <<EOF
user_pref("general.smoothScroll", false);
user_pref("layout.frame_rate", 20);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("browser.tabs.animate", false);
user_pref("layers.acceleration.disabled", true);
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");
EOF

# 6. 设置密码
x11vnc -storepasswd "$VNC_PASS" $HOME/.vnc/passwd

# 7. 启动服务
echo "🖥️ Starting Xvfb ($RESOLUTION)..."
rm -f /tmp/.X0-lock
Xvfb :0 -screen 0 $RESOLUTION &
sleep 3

echo "🪟 Starting Fluxbox..."
fluxbox &

echo "🔗 Starting optimized x11vnc..."
x11vnc -display :0 -forever -rfbauth $HOME/.vnc/passwd -listen localhost -xkb -rfbport 5900 -ncache 10 -nap &
sleep 2

CURRENT_PORT=${SERVER_PORT:-25830}
echo "🌐 Starting noVNC on port $CURRENT_PORT..."
websockify --web /usr/share/novnc $CURRENT_PORT localhost:5900 &

echo "🦊 Starting Firefox..."
while true; do
    # 👈 对应修改：强制 Firefox 适应 1280x640
    firefox --no-remote --display=:0 --width=1280 --height=640
    echo "Firefox restart..."
    sleep 3
done
