#!/bin/bash
# ================= 配置区域 =================
VNC_PASS="AkiRa13218*#"
RESOLUTION="1400x875x24"   
# ===========================================

# 0. 必须杀掉进程，否则 user.js 改了也不生效
echo "🔪 Killing old processes..."
pkill -9 firefox
pkill -9 Xvfb
pkill -9 fluxbox
pkill -9 x11vnc
rm -f /tmp/.X0-lock
sleep 2

# 1. 设置中文环境 (这是你最初有效的设置)
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8

# 2. 基础路径
export HOME=/home/container
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export DISPLAY=:0

# 3. Firefox 优化
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1
export MOZ_GFX_SPOOF_GL_VENDOR="Mesa"
export MOZ_GFX_SPOOF_GL_RENDERER="llvmpipe"

# 4. 初始化目录
# ⚠️ 回归到你原来的文件夹名，找回之前的状态
PROFILE_DIR="$HOME/.mozilla/firefox/custom_profile.default"
mkdir -p $XDG_CACHE_HOME $XDG_CONFIG_HOME $XDG_DATA_HOME
mkdir -p $HOME/.vnc "$PROFILE_DIR"

# 5. 注入 profiles.ini (确保 Firefox 认得这个路径)
mkdir -p "$HOME/.mozilla/firefox"
cat > "$HOME/.mozilla/firefox/profiles.ini" <<EOF
[General]
StartWithLastProfile=1

[Profile0]
Name=Default
IsRelative=1
Path=custom_profile.default
Default=1
EOF

# 6. 注入 user.js (在原有基础上只加缩放和去广告)
# 注意：这里去掉了强制下载语言包的逻辑，信任系统环境
cat > "$PROFILE_DIR/user.js" <<EOF
// --- 关键：全局缩放 80% ---
user_pref("layout.css.devPixelsPerPx", "0.8");

// --- 语言设置 (配合系统变量) ---
user_pref("intl.locale.requested", "zh-CN");
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");
user_pref("intl.locale.matchOS", true);

// --- 去除欢迎页和杂项 ---
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "about:blank");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("general.smoothScroll", false);
user_pref("browser.tabs.animate", false);
EOF

# 7. 强制全屏 (通过 xulstore.json)
cat > "$PROFILE_DIR/xulstore.json" <<EOF
{
  "chrome://browser/content/browser.xhtml": {
    "main-window": {
      "screenX": "0",
      "screenY": "0",
      "width": "1400",
      "height": "875",
      "sizemode": "maximized"
    }
  }
}
EOF

# 8. 配置 Fluxbox
mkdir -p $HOME/.fluxbox
cat > $HOME/.fluxbox/init <<EOF
session.screen0.toolbar.visible: false
session.screen0.defaultDeco: NONE
session.screen0.fullMaximization: true
EOF

cat > $HOME/.fluxbox/apps <<EOF
[app] (name=.*)
  [Deco] {NONE}
  [Maximized] {yes}
  [Position] (UPPERLEFT) {0 0}
  [Dimensions] {100% 100%} 
EOF

# 9. 启动服务
x11vnc -storepasswd "$VNC_PASS" $HOME/.vnc/passwd

echo "🖥️ Starting Xvfb ($RESOLUTION)..."
Xvfb :0 -screen 0 $RESOLUTION -ac &
sleep 3

echo "🪟 Starting Fluxbox..."
fluxbox &
sleep 2

echo "🔗 Starting x11vnc..."
x11vnc -display :0 -forever -rfbauth $HOME/.vnc/passwd \
    -listen localhost -xkb -rfbport 5900 \
    -ncache 10 -nap &
sleep 2

CURRENT_PORT=${SERVER_PORT:-25830}
echo "🌐 Starting noVNC on port $CURRENT_PORT..."
websockify --web /usr/share/novnc $CURRENT_PORT localhost:5900 &

echo "🦊 Starting Firefox (Restored Profile)..."
sleep 3
while true; do
    # 指回原来的 Profile 目录
    firefox --profile "$PROFILE_DIR" --no-remote --display=:0 --new-instance
    echo "Firefox restarting..."
    sleep 3
done
