#!/bin/bash
# ================= 配置区域 =================
VNC_PASS="AkiRa13218*#"
RESOLUTION="1400x875x24"   
# ===========================================

# 0. 清理旧进程 (确保配置生效)
echo "🔪 Killing old processes..."
pkill -9 firefox
pkill -9 Xvfb
pkill -9 fluxbox
pkill -9 x11vnc
rm -f /tmp/.X0-lock
sleep 2

# 1. 设置系统语言环境
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

# 4. 初始化目录
PROFILE_DIR="$HOME/firefox_clean_profile"
# 为了保险，这次我们不删除整个文件夹，只覆盖配置，防止下载的数据丢失
# 但如果中文依然无效，你可以手动把下一行前面的 # 去掉，强制重置
# rm -rf "$PROFILE_DIR" 
mkdir -p "$PROFILE_DIR"
mkdir -p $HOME/.vnc $HOME/.fluxbox

# 5. 注入 user.js (强制配置)
# 👇 重点修改了这里：加入了强制中文界面的指令
cat > "$PROFILE_DIR/user.js" <<EOF
// --- 核心：全局缩放 80% ---
user_pref("layout.css.devPixelsPerPx", "0.8");

// --- 核心：语言设置 (强制中文) ---
user_pref("intl.locale.requested", "zh-CN");
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");
user_pref("intl.locale.matchOS", false);

// --- 核心：跳过欢迎页 ---
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
EOF

# 6. 注入 xulstore.json (强制窗口大小)
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

# 7. 配置 Fluxbox
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

echo "🦊 Starting Firefox (Final Version)..."
sleep 3
while true; do
    firefox --profile "$PROFILE_DIR" --no-remote --display=:0 --new-instance
    echo "Firefox restarting..."
    sleep 3
done
