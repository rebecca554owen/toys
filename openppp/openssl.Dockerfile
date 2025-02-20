FROM ghcr.io/rebecca554owen/openppp2:base AS openssl-builder

# 设置工作目录与base镜像一致
WORKDIR /opt

# 设置OpenSSL版本号变量
ARG OPENSSL_VERSION=3.4.0

# 下载并构建OpenSSL
RUN curl -L https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz -o openssl-${OPENSSL_VERSION}.tar.gz \
    && tar zxvf openssl-${OPENSSL_VERSION}.tar.gz \
    && rm openssl-${OPENSSL_VERSION}.tar.gz \
    && mv openssl-${OPENSSL_VERSION} openssl \
    && cd openssl \
    && ./Configure \
    && make -j$(nproc) \
    && cd ..