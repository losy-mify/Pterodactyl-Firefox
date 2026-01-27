FROM alpine:latest

# 1. 安装软件：新增了 font-noto-cjk (中文/日文/韩文核心字体) 和 font-noto-emoji (表情包)
RUN apk add --no-cache \
    firefox \
    xvfb \
    x11vnc \
    fluxbox \
    bash \
    busybox-extras \
    novnc \
    websockify \
    python3 \
    dbus \
    ttf-dejavu \
    font-noto-cjk \
    font-noto-emoji

# 2. 生成 machine-id (防闪退)
RUN dbus-uuidgen > /etc/machine-id

# 3. 修复 noVNC 入口
RUN if [ ! -f /usr/share/novnc/index.html ]; then cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html; fi

# 4. 创建用户
RUN adduser -D -h /home/container container

# 5. 设置环境
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

# 6. 复制脚本
COPY --chown=container:container entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 7. 启动
CMD ["/bin/bash", "/entrypoint.sh"]
