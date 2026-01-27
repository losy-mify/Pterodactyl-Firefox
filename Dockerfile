FROM alpine:latest

# 1. 安装软件：增加了 novnc, websockify, dbus(修复报错)
# python3 是 websockify 运行需要的
RUN apk add --no-cache \
    firefox \
    xvfb \
    x11vnc \
    fluxbox \
    bash \
    busybox-extras \
    ttf-dejavu \
    font-noto-cjk \
    novnc \
    websockify \
    python3 \
    dbus

# 2. 【关键修复】生成 machine-id，解决 Firefox 闪退/黑屏问题
# 因为构建时是 Root 权限，我们直接写入系统文件，这样运行时就不用写了（避开只读锁）
RUN dbus-uuidgen > /etc/machine-id

# 3. 修正 noVNC 的入口文件，让你打开网页不用输文件名
# 如果 /usr/share/novnc 下没有 index.html，就把 vnc.html 复制一份过去
RUN if [ ! -f /usr/share/novnc/index.html ]; then cp /usr/share/novnc/vnc.html /usr/share/novnc/index.html; fi

# 4. 创建用户 (模拟面板环境)
RUN adduser -D -h /home/container container

# 5. 设置默认用户
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

# 6. 复制启动脚本
COPY --chown=container:container entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 7. 启动指令
CMD ["/bin/bash", "/entrypoint.sh"]
