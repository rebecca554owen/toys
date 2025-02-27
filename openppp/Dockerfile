FROM ghcr.io/rebecca554owen/openppp2:base AS builder

COPY --from=ghcr.io/rebecca554owen/openppp2:boost /opt/boost /opt/boost
COPY --from=ghcr.io/rebecca554owen/openppp2:jemalloc /opt/jemalloc /opt/jemalloc
COPY --from=ghcr.io/rebecca554owen/openppp2:openssl /opt/openssl /opt/openssl

WORKDIR /opt
ENV THIRD_PARTY_LIBRARY_DIR=/opt

RUN git clone --depth=1 https://github.com/liulilittle/openppp2.git $THIRD_PARTY_LIBRARY_DIR/openppp2 && \
    sed -i 's|SET(THIRD_PARTY_LIBRARY_DIR /root/dev)|SET(THIRD_PARTY_LIBRARY_DIR '"$THIRD_PARTY_LIBRARY_DIR"')|' $THIRD_PARTY_LIBRARY_DIR/openppp2/CMakeLists.txt && \
    cd $THIRD_PARTY_LIBRARY_DIR/openppp2 && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc)

FROM ubuntu:latest

WORKDIR /opt

COPY --from=builder /opt/openppp2/bin /opt

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dnsutils \
    iptables \
    iproute2 \
    iputils-ping \
    lsof \
    net-tools \
    netperf \
    tzdata \
    unzip \
    vim && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    chmod +x /opt/ppp && \
    rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/opt/ppp"]
