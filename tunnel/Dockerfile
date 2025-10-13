# 使用 nginx:alpine-slim 作为基础镜像
FROM nginx:alpine-slim

# 设置工作目录为 /etc/nginx
WORKDIR /etc/nginx

# 将本地的 tunnel 目录复制到容器的 /etc/nginx 目录
COPY ./tunnel /etc/nginx

# 将本地的 entrypoint.sh 脚本复制到容器的根目录
COPY ./tunnel/entrypoint.sh /entrypoint.sh

# 为 entrypoint.sh 脚本添加可执行权限
RUN chmod +x /entrypoint.sh

# 设置容器的入口点为 entrypoint.sh 脚本
ENTRYPOINT ["/entrypoint.sh"]

# 设置容器启动时默认执行的命令，启动 nginx 并保持前台运行
CMD ["nginx", "-g", "daemon off;"]
