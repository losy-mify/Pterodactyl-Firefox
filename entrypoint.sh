#!/bin/bash
# ================= 配置区域 =================
VNC_PASS="AkiRa13218*#"
RESOLUTION="1400x875x24"   
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
PROFILE_DIR="$HOME/.mozilla/firefox/custom_profile.default"
mkdir -p $XDG_CACHE_HOME $XDG_CONFIG_HOME $XDG_DATA_HOME
mkdir -p $HOME/.vnc "$PROFILE_DIR"

# 5. 注入配置 (user.js)
cat > "$PROFILE_DIR/user.js" <<EOF
user_pref("general.smoothScroll", false);
user_pref("layout.frame_rate", 20);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("browser.tabs.animate", false);
user_pref("layers.acceleration.disabled", true);
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");
# 强制全局缩放 80%
user_pref("layout.css.devPixelsPerPx", "0.8");
# 👇 新增：跳过首次启动的欢迎页和引导
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "about:blank");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.messaging-system.whatsNewPanel.enabled", false);
user_pref("doh-rollout.doneFirstRun", true);
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);
EOF

# 6. 配置 Fluxbox (强制全屏修复版)
mkdir -p $HOME/.fluxbox
cat > $HOME/.fluxbox/init <<EOF
session.screen0.toolbar.visible: false
session.screen0.defaultDeco: NONE
session.screen0.fullMaximization: true
EOF

# 👇 修改了这里：增加了 Position 和 Dimensions 强制填满屏幕
cat > $HOME/.fluxbox/apps <<EOF
[app] (class=Firefox)
  [Deco] {NONE}
  [Maximized] {yes}
  [Position] (UPPERLEFT) {0 0}
  [Dimensions] {100% 100%} 
EOF

# 7. 设置密码
x11vnc -storepasswd "$VNC_PASS" $HOME/.vnc/passwd

# 8. 启动服务
echo "🖥️ Starting Xvfb ($RESOLUTION)..."
rm -f /tmp/.X0-lock
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

echo "🦊 Starting Firefox (Forcing Custom Profile)..."
sleep 3
while true; do
    # 强制指定 Profile 路径
    firefox --profile "$PROFILE_DIR" --no-remote --display=:0 --new-instance
    echo "Firefox restarting..."
    sleep 3
done
