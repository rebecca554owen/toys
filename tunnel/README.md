# Nginx TLS 隧道使用指南

## 1. 安装 Docker

### 常规安装
```bash
curl -fsSL https://get.docker.com | bash -s docker && systemctl start docker && systemctl enable docker
```

### 国内服务器安装（使用阿里云镜像）
```bash
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun && systemctl start docker && systemctl enable docker
```

## 2. 配置隧道入口

根据服务器位置（国内/国外）修改配置文件：
```bash
vim stream/tunnel.conf
```

## 3. 启动服务

在项目目录下执行以下命令启动服务：
```bash
docker compose up -d
```