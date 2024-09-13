# 使用指定的基础镜像作为构建阶段的基础镜像，该镜像包含了所有必要的构建环境和依赖项
FROM ghcr.io/rebecca554owen/openppp2:base AS builder

# 复制构建依赖
COPY --from=ghcr.io/rebecca554owen/openppp2:boost /opt/boost /opt/boost
COPY --from=ghcr.io/rebecca554owen/openppp2:jemalloc /opt/jemalloc /opt/jemalloc
COPY --from=ghcr.io/rebecca554owen/openppp2:openssl /opt/openssl /opt/openssl
