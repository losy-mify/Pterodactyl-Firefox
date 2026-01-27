#!/bin/bash

# ================= 配置区域 =================
VNC_PASS="MySecretPassword"   # 你的密码
RESOLUTION="1024x768x16"      # 分辨率
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

# 3. Firefox 必须参数 (禁用沙盒)
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1
# 性能优化参数
export MOZ_GFX_SPOOF_GL_VENDOR="Mesa"
export MOZ_GFX_SPOOF_GL_RENDERER="llvmpipe"
export MOZ_WEBRENDER=0
export MOZ_ACCELERATED=0

# 4. 初始化目录
mkdir -p $XDG_CACHE_HOME $XDG_CONFIG_HOME $XDG_DATA_HOME
mkdir -p $HOME/.vnc

# 5. 【配置核心】注入 user.js 和 userChrome.css
FF_PROFILE_DIR="$HOME/.mozilla/firefox/custom_profile.default"
mkdir -p "$FF_PROFILE_DIR/chrome" # 新建 chrome 目录存放样式文件

# (A) 写入 profiles.ini
cat > $HOME/.mozilla/firefox/profiles.ini <<EOF
[General]
StartWithLastProfile=1

[Profile0]
Name=Default
IsRelative=1
Path=custom_profile.default
Default=1
EOF

# (B) 写入 user.js (性能优化 + 允许修改界面)
cat > "$FF_PROFILE_DIR/user.js" <<EOF
// --- 核心优化 ---
user_pref("general.smoothScroll", false);
user_pref("layout.frame_rate", 20);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("browser.tabs.animate", false);
user_pref("image.animation_mode", "none");
user_pref("layers.acceleration.disabled", true);
user_pref("gfx.webrender.all", false);
user_pref("gfx.webrender.software", true);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", true);
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");

// --- 【关键】允许加载自定义 CSS 样式 ---
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
EOF

# (C) 写入 userChrome.css (隐藏那个该死的黄条)
cat > "$FF_PROFILE_DIR/chrome/userChrome.css" <<EOF
/* 隐藏 '安全沙盒已禁用' 的警告条 */
notification-message[value="sandbox-disabled"],
.notification-message[value="sandbox-disabled"] {
    display: none !important;
    visibility: hidden !important;
}

/* 如果上面的没生效，这一条会隐藏顶部所有系统级通知 */
#global-notificationbox {
    display: none !important;
}
EOF

# 6. 设置密码
x11vnc -storepasswd "$VNC_PASS" $HOME/.vnc/passwd

# 7. 启动服务
echo "🖥️ Starting Xvfb ($RESOLUTION)..."
Xvfb :0 -screen 0 $RESOLUTION &
sleep 2

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
    firefox --no-remote --display=:0
    echo "Firefox restart..."
    sleep 3
done
