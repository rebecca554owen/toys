# 项目结构说明

## 目录结构
- miaospeed
  - Dockerfile: 定义miaospeed容器的构建配置
  - install.sh: 安装脚本，自动安装Nginx及相关依赖

- openppp
  - Dockerfile: 定义openppp容器的构建配置
  - base.Dockerfile: 基础镜像定义文件，包含通用依赖和工具
  - boost.Dockerfile: Boost库的Dockerfile，用于编译需要Boost支持的应用程序
  - jemalloc.Dockerfile: Jemalloc内存分配器的Dockerfile，优化内存使用
  - openssl.Dockerfile: OpenSSL库的Dockerfile，提供加密功能
  - install.sh: 安装脚本，自动安装依赖和编译工具链

- tunnel
  - Dockerfile: 定义Nginx隧道容器的构建配置
  - docker-compose.yaml: 容器编排配置文件，定义服务部署方式
  - entrypoint.sh: 容器启动脚本，处理环境变量并生成Nginx配置
  - nginx.conf: Nginx主配置文件，定义全局参数和stream模块配置
  - README.md: 项目说明文档，包含安装和使用指南

