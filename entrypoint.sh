#!/bin/bash
# ================= 配置区域 =================
VNC_PASS="AkiRa13218*#"
RESOLUTION="1400x875x24"   
# ===========================================

# 0. ⚠️【关键】清理战场：强制杀掉所有旧进程，防止后台残留干扰
echo "🔪 Killing old processes..."
pkill -9 firefox
pkill -9 Xvfb
pkill -9 fluxbox
pkill -9 x11vnc
rm -f /tmp/.X0-lock
sleep 2

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

# 3. Firefox 优化变量
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1
export MOZ_GFX_SPOOF_GL_VENDOR="Mesa"
export MOZ_GFX_SPOOF_GL_RENDERER="llvmpipe"

# 4. 初始化目录 & 定义配置路径
# 我们改个名字 "clean_profile"，避开之前的缓存干扰
PROFILE_DIR="$HOME/firefox_clean_profile"
rm -rf "$PROFILE_DIR" # 删掉旧的，每次都重新生成，保证纯净
mkdir -p "$PROFILE_DIR"
mkdir -p $HOME/.vnc $HOME/.fluxbox

# 5. 注入 user.js (强制配置)
# 这里的设置将控制缩放和跳过欢迎页
cat > "$PROFILE_DIR/user.js" <<EOF
// --- 核心：全局缩放 80% ---
user_pref("layout.css.devPixelsPerPx", "0.8");

// --- 核心：跳过所有欢迎页、导入向导、升级提示 ---
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "about:blank");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.uitour.enabled", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.fullscreen.autohide", false);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// --- 性能优化 ---
user_pref("general.smoothScroll", false);
user_pref("browser.tabs.animate", false);
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");
EOF

# 6. 注入 xulstore.json (强制窗口大小)
# 这是 Firefox 存储窗口大小的文件，我们直接伪造它，让 Firefox 以为上次就是全屏关闭的
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

# 7. 配置 Fluxbox (作为保底)
# 强制让所有窗口都最大化，不再区分应用名
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

# 8. 启动服务
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

echo "🦊 Starting Firefox (Clean Profile)..."
sleep 3
while true; do
    # 必须指向我们刚才创建的 clean_profile
    firefox --profile "$PROFILE_DIR" --no-remote --display=:0 --new-instance
    echo "Firefox restarting..."
    sleep 3
done
