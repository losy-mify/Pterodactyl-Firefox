FROM alpine:latest

# 1. 安装软件：Firefox, Xvfb(虚拟屏), x11vnc(远程连接), Fluxbox(窗口管理), Bash
RUN apk add --no-cache \
    firefox \
    xvfb \
    x11vnc \
    fluxbox \
    bash \
    busybox-extras \
    ttf-dejavu \
    font-noto-cjk  # 安装中文字体，防止网页乱码

# 2. 创建用户 (模拟面板环境)
RUN adduser -D -h /home/container container

# 3. 设置默认用户
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

# 4. 复制启动脚本
COPY --chown=container:container entrypoint.sh /entrypoint.sh
# 给脚本执行权限 (这一步很重要)
RUN chmod +x /entrypoint.sh

# 5. 启动指令
CMD ["/bin/bash", "/entrypoint.sh"]
