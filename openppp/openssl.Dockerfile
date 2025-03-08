FROM ghcr.io/rebecca554owen/openppp2:base AS openssl-builder

WORKDIR /opt

ARG OPENSSL_VERSION=3.4.0

RUN curl -L https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz -o openssl-${OPENSSL_VERSION}.tar.gz \
    && tar zxvf openssl-${OPENSSL_VERSION}.tar.gz \
    && rm openssl-${OPENSSL_VERSION}.tar.gz \
    && mv openssl-${OPENSSL_VERSION} openssl \
    && cd openssl \
    && ./Configure \
    && make -j$(nproc) \
    && cd ..