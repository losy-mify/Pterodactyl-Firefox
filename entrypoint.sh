#!/bin/bash

# ================= 配置区域 =================
VNC_PASS="AkiRa13218*#"
RESOLUTION="1024x768x16"
# ===========================================

# 1. 尝试创建 1GB 虚拟内存 (Swap) - 救命关键
# 很多 VPS 内存只有 512MB，不加 Swap 打开 Discord 必死
echo "🧠 Attempting to create Swap file..."
if [ ! -f /swapfile ]; then
    fallocate -l 1G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 2>/dev/null
    chmod 600 /swapfile
    mkswap /swapfile 2>/dev/null
    swapon /swapfile 2>/dev/null
    echo "✅ Swap enabled (if permissions allowed)"
else
    swapon /swapfile 2>/dev/null
    echo "✅ Swap re-enabled"
fi

# 2. 环境变量 - 强制低配模式
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export DISPLAY=:0
export HOME=/home/container
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config

# 【核心】强制软件渲染 & 禁用多进程沙盒
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1
export LIBGL_ALWAYS_SOFTWARE=1       # 强制 Mesa 使用 CPU 渲染
export MOZ_X11_EGL=1                 # 强制使用 X11 EGL
export MOZ_DISABLE_RDD_SANDBOX=1     # 禁用 RDD 沙盒
export ACCESSIBILITY_ENABLED=0       # 禁用无障碍

# 3. 初始化目录
mkdir -p $HOME/.vnc $HOME/firefox_profile

# 4. 写入“核弹级”优化配置
FF_PROFILE_DIR="$HOME/firefox_profile"
rm -rf "$FF_PROFILE_DIR"
mkdir -p "$FF_PROFILE_DIR"

cat > "$FF_PROFILE_DIR/user.js" <<EOF
// === 1. 内存救星：关闭所有后台服务 ===
user_pref("browser.safebrowsing.malware.enabled", false);   // 关闭防恶意软件 (省 RAM)
user_pref("browser.safebrowsing.phishing.enabled", false);  // 关闭防钓鱼 (省 RAM)
user_pref("browser.safebrowsing.downloads.enabled", false); // 关闭下载扫描
user_pref("extensions.pocket.enabled", false);              // 关闭 Pocket
user_pref("datareporting.healthreport.uploadEnabled", false); // 关闭遥测
user_pref("accessibility.force_disabled", 1);               // 【关键】关闭无障碍服务 (防 Linux 卡顿)

// === 2. 进程与渲染阉割 ===
user_pref("dom.ipc.processCount", 1);            // 强制单进程
user_pref("webgl.disabled", true);               // 禁止 WebGL
user_pref("layers.acceleration.disabled", true); // 禁止硬件加速
user_pref("gfx.canvas.azure.backends", "skia");  // 强制使用 Skia 绘图
user_pref("browser.sessionstore.max_tabs_undo", 0); // 不保存关闭的标签页
user_pref("browser.sessionhistory.max_entries", 2); // 几乎不保存历史记录

// === 3. 视觉极简 ===
user_pref("permissions.default.image", 2);       // 禁止图片
user_pref("browser.display.use_document_colors", false); // 黑白模式
user_pref("browser.display.use_document_fonts", 0);      // 系统字体
user_pref("image.animation_mode", "none");

// === 4. 网络与性能 ===
user_pref("network.prefetch-next", false);
user_pref("layout.frame_rate", 10);              // 锁 10 帧
user_pref("javascript.options.baselinejit", true); // 保持 JIT 开启 (否则 Discord JS 跑不动)
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");
EOF

# 5. 启动 VNC 服务
x11vnc -storepasswd "$VNC_PASS" $HOME/.vnc/passwd
Xvfb :0 -screen 0 $RESOLUTION &
sleep 2
fluxbox &
x11vnc -display :0 -forever -rfbauth $HOME/.vnc/passwd -listen localhost -xkb -rfbport 5900 -ncache 10 -nap &
sleep 2

# 6. 启动 noVNC
CURRENT_PORT=${SERVER_PORT:-25830}
websockify --web /usr/share/novnc $CURRENT_PORT localhost:5900 &

# 7. 启动 Firefox (无限循环保活)
echo "🦊 Starting Firefox (Nuclear Mode)..."
# 先清理旧进程
pkill -f firefox
pkill -f firefox-bin

while true; do
    # --purgecaches: 启动时清理缓存
    firefox --no-remote --display=:0 -profile "$FF_PROFILE_DIR" --purgecaches
    echo "⚠️ Firefox exited. Restarting..."
    sleep 3
done
