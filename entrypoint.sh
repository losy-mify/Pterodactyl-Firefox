#!/bin/bash
# ================= 配置区域 =================
VNC_PASS="AkiRa13218*#"
RESOLUTION="1400x875x24"
# ===========================================

# 0. 强力清理旧进程
echo "🔪 Killing old processes..."
pkill -9 firefox 2>/dev/null
pkill -9 Xvfb 2>/dev/null
pkill -9 fluxbox 2>/dev/null
pkill -9 x11vnc 2>/dev/null
pkill -9 websockify 2>/dev/null
rm -f /tmp/.X0-lock
rm -f /tmp/.X11-unix/X0
sleep 2

# 1. 设置系统语言变量
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8

# 2. 准备目录
export HOME=/home/container
export DISPLAY=:0
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share

# 性能优化环境变量
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1
export MOZ_DISABLE_RDD_SANDBOX=1
export LIBGL_ALWAYS_SOFTWARE=1
export MOZ_X11_EGL=1

# 定义配置文件夹
PROFILE_DIR="$HOME/firefox_zh_final"
mkdir -p "$PROFILE_DIR/extensions"
mkdir -p $HOME/.vnc $HOME/.fluxbox

# 3. 下载中文语言包（多重备选方案）
echo "🔍 Detecting Firefox version for Language Pack..."
FF_VERSION_FULL=$(firefox --version 2>/dev/null)
FF_VERSION=$(echo "$FF_VERSION_FULL" | awk '{print $3}')

if [ -z "$FF_VERSION" ]; then
    echo "⚠️ Cannot detect Firefox version"
    FF_VERSION="128.0"
fi

echo "🎯 Detected Version: $FF_VERSION"

LANG_FILE="$PROFILE_DIR/extensions/langpack-zh-CN@firefox.mozilla.org.xpi"

echo "⬇️ Downloading Chinese Language Pack..."
download_success=false

# 方法1: Mozilla 官方 releases
if [ "$download_success" = false ]; then
    LANG_URL="https://releases.mozilla.org/pub/firefox/releases/$FF_VERSION/linux-x86_64/xpi/zh-CN.xpi"
    if wget --timeout=15 --tries=2 --no-check-certificate -q -O "$LANG_FILE" "$LANG_URL" 2>/dev/null; then
        if [ -f "$LANG_FILE" ] && [ -s "$LANG_FILE" ]; then
            echo "✅ 中文语言包已下载: Mozilla releases"
            download_success=true
        fi
    fi
fi

# 方法2: Mozilla addons（备用固定版本）
if [ "$download_success" = false ]; then
    echo "⚠️ Trying alternative source..."
    LANG_URL="https://addons.mozilla.org/firefox/downloads/file/4391895/zh_cn_language_pack-128.0.xpi"
    if wget --timeout=15 --tries=2 --no-check-certificate -q -O "$LANG_FILE" "$LANG_URL" 2>/dev/null; then
        if [ -f "$LANG_FILE" ] && [ -s "$LANG_FILE" ]; then
            echo "✅ 中文语言包已下载: Mozilla addons"
            download_success=true
        fi
    fi
fi

# 方法3: 检查系统自带语言包
if [ "$download_success" = false ]; then
    echo "⚠️ Checking system language pack..."
    SYSTEM_LANG=$(find /usr/lib*/firefox*/langpacks/ -name "zh-CN*.xpi" 2>/dev/null | head -n1)
    if [ -f "$SYSTEM_LANG" ]; then
        cp "$SYSTEM_LANG" "$LANG_FILE"
        echo "✅ 使用系统语言包: $SYSTEM_LANG"
        download_success=true
    fi
fi

if [ "$download_success" = false ]; then
    echo "⚠️ 语言包下载失败，将使用 Firefox 内置语言设置"
    rm -f "$LANG_FILE"
fi

# 4. 注入 user.js（中文 + 缩放 0.8 + 性能优化）
cat > "$PROFILE_DIR/user.js" <<'EOF'
// === 1. 缩放设置 (80%) ===
user_pref("layout.css.devPixelsPerPx", "0.8");

// === 2. 语言设置（强制中文）===
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.enabledScopes", 15);
user_pref("extensions.langpacks.signatures.required", false);
user_pref("intl.locale.requested", "zh-CN");
user_pref("intl.locale.matchOS", false);
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");
user_pref("intl.regional_prefs.use_os_locales", false);
user_pref("general.useragent.locale", "zh-CN");

// === 3. 界面净化 ===
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "about:blank");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.uitour.enabled", false);
user_pref("browser.newtabpage.enabled", false);

// === 4. 性能优化 ===
user_pref("general.smoothScroll", false);
user_pref("browser.tabs.animate", false);
user_pref("toolkit.cosmeticAnimations.enabled", false);
user_pref("layers.acceleration.disabled", true);
user_pref("webgl.disabled", true);
user_pref("gfx.canvas.azure.backends", "skia");

// === 5. 进程与内存控制 ===
user_pref("dom.ipc.processCount", 2);
user_pref("browser.sessionstore.max_tabs_undo", 1);
user_pref("browser.sessionhistory.max_entries", 5);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.capacity", 51200);

// === 6. 禁用后台服务 ===
user_pref("browser.safebrowsing.malware.enabled", false);
user_pref("browser.safebrowsing.phishing.enabled", false);
user_pref("browser.safebrowsing.downloads.enabled", false);
user_pref("extensions.pocket.enabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);

// === 7. 网络优化 ===
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.speculative-parallel-limit", 0);

// === 8. 视觉优化 ===
user_pref("image.animation_mode", "none");
user_pref("layout.frame_rate", 20);
EOF

# 5. 窗口设置（全屏记忆）
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

# 6. Fluxbox 配置（无边框全屏）
cat > $HOME/.fluxbox/init <<EOF
session.screen0.toolbar.visible: false
session.screen0.defaultDeco: NONE
session.screen0.fullMaximization: true
EOF

cat > $HOME/.fluxbox/apps <<EOF
[app] (class=Firefox)
  [Deco] {NONE}
  [Maximized] {yes}
  [Dimensions] {100% 100%}
EOF

# 7. 设置 VNC 密码
x11vnc -storepasswd "$VNC_PASS" $HOME/.vnc/passwd

# 8. 启动 Xvfb
echo "🖥️ Starting Xvfb ($RESOLUTION)..."
Xvfb :0 -screen 0 $RESOLUTION -ac &
sleep 3

# 9. 启动 Fluxbox
echo "🪟 Starting Fluxbox..."
fluxbox &
sleep 2

# 10. 启动 x11vnc
echo "🔗 Starting x11vnc..."
x11vnc -display :0 -forever -rfbauth $HOME/.vnc/passwd \
    -listen localhost -xkb -rfbport 5900 \
    -ncache 10 -nap &
sleep 2

# 11. 启动 noVNC
CURRENT_PORT=${SERVER_PORT:-25830}
echo "🌐 Starting noVNC on port $CURRENT_PORT..."
websockify --web /usr/share/novnc $CURRENT_PORT localhost:5900 &

# 12. 启动 Firefox（保活循环）
echo "🦊 Starting Firefox (Chinese + Zoom 0.8)..."
sleep 3

while true; do
    firefox --profile "$PROFILE_DIR" --no-remote --display=:0 --new-instance --width 1400 --height 875
    echo "⚠️ Firefox restarting..."
    sleep 3
done
