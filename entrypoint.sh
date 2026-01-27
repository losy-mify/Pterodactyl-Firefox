#!/bin/bash

# ================= 配置区域 =================
VNC_PASS="AkiRa13218*#"   # 你的密码
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

# 3. Firefox 性能优化参数 (针对容器环境的底层优化)
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1
export MOZ_GFX_SPOOF_GL_VENDOR="Mesa"
export MOZ_GFX_SPOOF_GL_RENDERER="llvmpipe"
export MOZ_WEBRENDER=0
export MOZ_ACCELERATED=0

# 4. 初始化目录
mkdir -p $XDG_CACHE_HOME $XDG_CONFIG_HOME $XDG_DATA_HOME
mkdir -p $HOME/.vnc

# 5. 注入性能优化配置 (user.js) - 核心修改区域
FF_PROFILE_DIR="$HOME/.mozilla/firefox/custom_profile.default"
mkdir -p "$FF_PROFILE_DIR"

cat > $HOME/.mozilla/firefox/profiles.ini <<EOF
[General]
StartWithLastProfile=1

[Profile0]
Name=Default
IsRelative=1
Path=custom_profile.default
Default=1
EOF

# --- 写入极速配置 ---
cat > "$FF_PROFILE_DIR/user.js" <<EOF
// === 基础性能 ===
user_pref("general.smoothScroll", false);      // 关闭平滑滚动
user_pref("layout.frame_rate", 15);            // 限制帧率为15，降低CPU占用
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("browser.tabs.animate", false);
user_pref("image.animation_mode", "none");
user_pref("layers.acceleration.disabled", true);
user_pref("gfx.webrender.all", false);
user_pref("gfx.webrender.software", true);
user_pref("browser.cache.disk.enable", false); // 关闭硬盘缓存，减少IO
user_pref("browser.cache.memory.enable", true);
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");

// === 极速/省流核心配置 (修改部分) ===
user_pref("permissions.default.image", 2);           // 2=禁止加载所有图片
user_pref("network.prefetch-next", false);           // 禁止预加载链接
user_pref("browser.display.use_document_fonts", 0);  // 0=强制使用系统字体(不下载网页字体)
user_pref("javascript.enabled", true);               // 保持JS开启
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
# 使用循环确保崩溃自动重启
while true; do
    firefox --no-remote --display=:0
    echo "Firefox restart..."
    sleep 3
done
