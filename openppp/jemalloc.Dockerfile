FROM ghcr.io/rebecca554owen/openppp2:base AS jemalloc-builder

# 设置工作目录与base镜像一致
WORKDIR /opt

# 设置jemalloc版本号变量
ARG JEMALLOC_VERSION=5.3.0

# 下载并构建jemalloc
RUN curl -L https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-${JEMALLOC_VERSION}.tar.bz2 -o jemalloc-${JEMALLOC_VERSION}.tar.bz2 \
    && tar xjf jemalloc-${JEMALLOC_VERSION}.tar.bz2 \
    && rm jemalloc-${JEMALLOC_VERSION}.tar.bz2 \
    && mv jemalloc-${JEMALLOC_VERSION} jemalloc \
    && cd jemalloc \
    && ./autogen.sh --with-jemalloc-prefix=je_ \
    && make -j$(nproc) \
    && cd ..