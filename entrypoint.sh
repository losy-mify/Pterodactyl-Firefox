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

# 👇 关键改动：设置全局页面缩放为 80%
cat > "$HOME/.mozilla/firefox/custom_profile.default/user.js" <<EOF
user_pref("general.smoothScroll", false);
user_pref("layout.frame_rate", 20);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("browser.tabs.animate", false);
user_pref("layers.acceleration.disabled", true);
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");

// 👇 设置全局页面缩放为 80%
user_pref("browser.zoom.siteSpecific", false);  // 禁用单独网站缩放记忆
user_pref("browser.zoom.full", true);  // 全页面缩放（包括图片）
user_pref("layout.css.devPixelsPerPx", "1.0");  // 重置为默认
EOF

# 6. 配置 Fluxbox
mkdir -p $HOME/.fluxbox
cat > $HOME/.fluxbox/init <<EOF
session.screen0.toolbar.visible: false
session.screen0.defaultDeco: NONE
session.screen0.fullMaximization: true
EOF

cat > $HOME/.fluxbox/apps <<EOF
[app] (class=Firefox)
  [Deco] {NONE}
  [Maximized] {yes}
EOF

# 7. 创建 content-prefs.sqlite 来设置默认缩放
mkdir -p $HOME/.mozilla/firefox/custom_profile.default
cat > /tmp/set_zoom.sql <<'EOSQL'
CREATE TABLE IF NOT EXISTS prefs (
  id INTEGER PRIMARY KEY,
  groupID INTEGER,
  settingID INTEGER,
  value BLOB,
  timestamp INTEGER
);
CREATE TABLE IF NOT EXISTS groups (
  id INTEGER PRIMARY KEY,
  name TEXT
);
CREATE TABLE IF NOT EXISTS settings (
  id INTEGER PRIMARY KEY,
  name TEXT
);

INSERT OR REPLACE INTO settings (id, name) VALUES (1, 'browser.content.full-zoom');
INSERT OR REPLACE INTO groups (id, name) VALUES (1, 'global');
INSERT OR REPLACE INTO prefs (groupID, settingID, value, timestamp) 
VALUES (1, 1, X'3FE99999A0000000', strftime('%s', 'now') * 1000000);
EOSQL

sqlite3 "$HOME/.mozilla/firefox/custom_profile.default/content-prefs.sqlite" < /tmp/set_zoom.sql
rm /tmp/set_zoom.sql

# 8. 设置密码
x11vnc -storepasswd "$VNC_PASS" $HOME/.vnc/passwd

# 9. 启动 Xvfb
echo "🖥️ Starting Xvfb ($RESOLUTION)..."
rm -f /tmp/.X0-lock
Xvfb :0 -screen 0 $RESOLUTION -ac &
sleep 3

echo "🪟 Starting Fluxbox..."
fluxbox &
sleep 2

# 10. 启动 x11vnc
echo "🔗 Starting x11vnc..."
x11vnc -display :0 -forever -rfbauth $HOME/.vnc/passwd \
    -listen localhost -xkb -rfbport 5900 \
    -ncache 10 -nap &
sleep 2

CURRENT_PORT=${SERVER_PORT:-25830}
echo "🌐 Starting noVNC on port $CURRENT_PORT..."
websockify --web /usr/share/novnc $CURRENT_PORT localhost:5900 &

echo "🦊 Starting Firefox..."
sleep 3
while true; do
    firefox --no-remote --display=:0 --new-instance
    echo "Firefox restarting..."
    sleep 3
done
