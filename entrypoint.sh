#!/bin/bash

# ================= 配置区域 =================
VNC_PASS="AkiRa13218*#"   # 你的密码
RESOLUTION="1024x768x16"      # 分辨率
# ===========================================

# 1. 设置中文环境 (防止乱码)
export LANG=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh
export LC_ALL=zh_CN.UTF-8

# 2. 基础路径配置
export HOME=/home/container
export XDG_CACHE_HOME=$HOME/.cache
export XDG_CONFIG_HOME=$HOME/.config
export XDG_DATA_HOME=$HOME/.local/share
export DISPLAY=:0

# 3. Firefox 底层环境优化
export MOZ_DISABLE_CONTENT_SANDBOX=1
export MOZ_FAKE_NO_SANDBOX=1
export MOZ_GFX_SPOOF_GL_VENDOR="Mesa"
export MOZ_GFX_SPOOF_GL_RENDERER="llvmpipe"
export MOZ_WEBRENDER=0
export MOZ_ACCELERATED=0

# 4. 初始化目录
mkdir -p $XDG_CACHE_HOME $XDG_CONFIG_HOME $XDG_DATA_HOME
mkdir -p $HOME/.vnc

# 5. 【核心优化】创建并锁定 Firefox 配置文件
# 使用自定义路径，不依赖默认的 profiles.ini，确保 100% 生效
FF_PROFILE_DIR="$HOME/firefox_profile"

# 每次启动前清理旧配置，防止缓存堆积导致卡顿
rm -rf "$FF_PROFILE_DIR"
mkdir -p "$FF_PROFILE_DIR"

# 写入极速 user.js 配置
cat > "$FF_PROFILE_DIR/user.js" <<EOF
// === 1. 防卡死核心 (针对 Discord/重型网页) ===
user_pref("dom.ipc.processCount", 1);            // 【救命】强制单进程模式，防止内存爆炸
user_pref("webgl.disabled", true);               // 【救命】彻底禁用 WebGL，防止 CPU 模拟 3D 导致卡死
user_pref("layers.acceleration.disabled", true); // 禁用硬件加速
user_pref("dom.webgpu.enabled", false);          // 禁用 WebGPU

// === 2. 极速省流 (视觉阉割) ===
user_pref("permissions.default.image", 2);       // 禁止加载图片 (2=Block All)
user_pref("browser.display.use_document_colors", false); // 强制高对比度(黑白)，去除网页背景色
user_pref("browser.display.use_document_fonts", 0);      // 强制使用系统字体 (不下载网页字体)
user_pref("image.animation_mode", "none");       // 禁止 GIF 动图

// === 3. 性能参数调优 ===
user_pref("layout.frame_rate", 10);              // 【降级】帧率限制为 10fps，大幅降低 CPU 占用
user_pref("general.smoothScroll", false);        // 关闭平滑滚动
user_pref("toolkit.cosmeticAnimations.enabled", false); // 关闭界面动画
user_pref("browser.tabs.animate", false);
user_pref("gfx.webrender.all", false);
user_pref("gfx.webrender.software", true);
user_pref("browser.cache.disk.enable", false);   // 关闭硬盘缓存，减少 IO 读写
user_pref("browser.cache.memory.enable", true);  // 仅使用内存缓存
user_pref("javascript.enabled", true);           // 保持 JS 开启 (否则 Discord 无法运行)
user_pref("intl.accept_languages", "zh-CN, zh, en-US, en");

// === 4. 网络静默优化 ===
user_pref("network.prefetch-next", false);               // 禁止预加载链接
user_pref("network.http.speculative-parallel-limit", 0); // 禁止推测性连接
user_pref("network.dns.disablePrefetch", true);          // 禁止 DNS 预解析
EOF

# 6. 设置 VNC 密码
x11vnc -storepasswd "$VNC_PASS" $HOME/.vnc/passwd

# 7. 启动服务序列
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

echo "🦊 Starting Firefox (Optimized Mode)..."
# 循环守护进程
while true; do
    # 【关键】启动时指定 -profile 参数，强制加载我们生成的优化配置
    firefox --no-remote --display=:0 -profile "$FF_PROFILE_DIR"
    
    echo "Firefox crashed or closed. Restarting in 3 seconds..."
    sleep 3
done
