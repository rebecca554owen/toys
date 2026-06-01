# 多阶段构建 - 下载阶段
FROM ubuntu:22.04 AS downloader

# 构建参数
ARG VERSION=latest
ARG TARGETARCH

# 设置工作目录
WORKDIR /tmp

# 安装下载工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    file \
    jq \
    unzip \
    wget && \
    rm -rf /var/lib/apt/lists/*

# 下载和准备二进制文件
RUN set -ex && \
    api_url="https://api.github.com/repos/rebecca554owen/toys/releases" && \
    if [ "${VERSION}" = "latest" ]; then \
        release_url="${api_url}/latest"; \
    else \
        release_url="${api_url}/tags/${VERSION}"; \
    fi && \
    wget -qO release.json "${release_url}" && \
    jq -e '.tag_name' release.json >/dev/null && \
    case "${TARGETARCH}" in \
        amd64) \
            normal_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-amd64.zip")' release.json | head -n1)" && \
            io_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-amd64-io-uring.zip")' release.json | head -n1)" && \
            simd_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-amd64-simd.zip")' release.json | head -n1)" && \
            io_simd_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-amd64-io-uring-simd.zip")' release.json | head -n1)" && \
            tc_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-amd64-tc.zip")' release.json | head -n1)" && \
            tc_io_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-amd64-tc-io-uring.zip")' release.json | head -n1)" && \
            tc_simd_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-amd64-tc-simd.zip")' release.json | head -n1)" && \
            tc_io_simd_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-amd64-tc-io-uring-simd.zip")' release.json | head -n1)" ;; \
        arm64) \
            normal_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-aarch64.zip" or . == "openppp2-linux-arm64.zip")' release.json | head -n1)" && \
            io_asset="$(jq -r '.assets[]?.name | select(. == "openppp2-linux-aarch64-io-uring.zip" or . == "openppp2-linux-arm64-io-uring.zip")' release.json | head -n1)" && \
            simd_asset="" && \
            io_simd_asset="" && \
            tc_asset="" && \
            tc_io_asset="" && \
            tc_simd_asset="" && \
            tc_io_simd_asset="" ;; \
        *) \
            echo "不支持的架构: ${TARGETARCH}" && \
            exit 1 ;; \
    esac && \
    [ -n "${normal_asset}" ] || { echo "未找到 ${TARGETARCH} 对应的标准安装包"; exit 1; } && \
    normal_url="$(jq -r --arg name "${normal_asset}" '.assets[]? | select(.name == $name) | .browser_download_url' release.json)" && \
    wget -q "${normal_url}" -O normal.zip && \
    if [ -n "${io_asset}" ]; then io_url="$(jq -r --arg name "${io_asset}" '.assets[]? | select(.name == $name) | .browser_download_url' release.json)"; wget -q "${io_url}" -O io.zip; fi && \
    if [ -n "${simd_asset}" ]; then simd_url="$(jq -r --arg name "${simd_asset}" '.assets[]? | select(.name == $name) | .browser_download_url' release.json)"; wget -q "${simd_url}" -O normal_simd.zip; fi && \
    if [ -n "${io_simd_asset}" ]; then io_simd_url="$(jq -r --arg name "${io_simd_asset}" '.assets[]? | select(.name == $name) | .browser_download_url' release.json)"; wget -q "${io_simd_url}" -O io_simd.zip; fi && \
    if [ -n "${tc_asset}" ]; then tc_url="$(jq -r --arg name "${tc_asset}" '.assets[]? | select(.name == $name) | .browser_download_url' release.json)"; wget -q "${tc_url}" -O tc.zip; fi && \
    if [ -n "${tc_io_asset}" ]; then tc_io_url="$(jq -r --arg name "${tc_io_asset}" '.assets[]? | select(.name == $name) | .browser_download_url' release.json)"; wget -q "${tc_io_url}" -O tc_io.zip; fi && \
    if [ -n "${tc_simd_asset}" ]; then tc_simd_url="$(jq -r --arg name "${tc_simd_asset}" '.assets[]? | select(.name == $name) | .browser_download_url' release.json)"; wget -q "${tc_simd_url}" -O tc_simd.zip; fi && \
    if [ -n "${tc_io_simd_asset}" ]; then tc_io_simd_url="$(jq -r --arg name "${tc_io_simd_asset}" '.assets[]? | select(.name == $name) | .browser_download_url' release.json)"; wget -q "${tc_io_simd_url}" -O tc_io_simd.zip; fi && \
    # 处理正常版本
    if file normal.zip | grep -q "Zip archive data"; then \
        unzip normal.zip -d /opt && \
        rm normal.zip; \
    else \
        echo "正常版本ZIP文件损坏或格式错误" && \
        exit 1; \
    fi && \
    # 处理io版本（如果存在）
    if [ -f io.zip ]; then \
        if file io.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/io && \
            unzip io.zip -d /opt/io/ && \
            rm io.zip; \
        else \
            echo "IO版本ZIP文件损坏，已忽略" && \
            rm -f io.zip; \
        fi; \
    fi && \
    # 处理tc版本（如果存在）
    if [ -f tc.zip ]; then \
        if file tc.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/tc && \
            unzip tc.zip -d /opt/tc/ && \
            rm tc.zip; \
        else \
            echo "TC版本ZIP文件损坏，已忽略" && \
            rm -f tc.zip; \
        fi; \
    fi && \
    # 处理tc-io版本（如果存在）
    if [ -f tc_io.zip ]; then \
        if file tc_io.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/tc-io && \
            unzip tc_io.zip -d /opt/tc-io/ && \
            rm tc_io.zip; \
        else \
            echo "TC-IO版本ZIP文件损坏，已忽略" && \
            rm -f tc_io.zip; \
        fi; \
    fi && \
    # 处理simd版本（如果存在）
    if [ -f normal_simd.zip ]; then \
        if file normal_simd.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/simd && \
            unzip normal_simd.zip -d /opt/simd/ && \
            rm normal_simd.zip; \
        else \
            echo "SIMD版本ZIP文件损坏，已忽略" && \
            rm -f normal_simd.zip; \
        fi; \
    fi && \
    # 处理io-simd版本（如果存在）
    if [ -f io_simd.zip ]; then \
        if file io_simd.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/io-simd && \
            unzip io_simd.zip -d /opt/io-simd/ && \
            rm io_simd.zip; \
        else \
            echo "IO-SIMD版本ZIP文件损坏，已忽略" && \
            rm -f io_simd.zip; \
        fi; \
    fi && \
    # 处理tc-simd版本（如果存在）
    if [ -f tc_simd.zip ]; then \
        if file tc_simd.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/tc-simd && \
            unzip tc_simd.zip -d /opt/tc-simd/ && \
            rm tc_simd.zip; \
        else \
            echo "TC-SIMD版本ZIP文件损坏，已忽略" && \
            rm -f tc_simd.zip; \
        fi; \
    fi && \
    # 处理tc-io-simd版本（如果存在）
    if [ -f tc_io_simd.zip ]; then \
        if file tc_io_simd.zip | grep -q "Zip archive data"; then \
            mkdir -p /opt/tc-io-simd && \
            unzip tc_io_simd.zip -d /opt/tc-io-simd/ && \
            rm tc_io_simd.zip; \
        else \
            echo "TC-IO-SIMD版本ZIP文件损坏，已忽略" && \
            rm -f tc_io_simd.zip; \
        fi; \
    fi && \
    rm -f release.json

# 多阶段构建 - 运行阶段
FROM ubuntu:22.04

# 设置工作目录
WORKDIR /opt

# 环境变量
ENV ENABLE_IO=false
ENV ENABLE_SIMD=false
ENV ENABLE_TC=false
ENV ENABLE_BYPASS=false
ENV BYPASS_COUNTRY=CN
ENV BYPASS_IPLIST_PATH=/opt/ip.txt
ENV BYPASS_REFRESH=true
ENV BYPASS_PULL_ON_START=true

# 安装运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    dnsutils \
    iptables \
    iproute2 \
    iputils-ping \
    libatomic1 \
    liburing2 \
    libbpf0 \
    libunwind8 \
    lsof \
    net-tools && \
    rm -rf /var/lib/apt/lists/*

# 从下载阶段复制二进制文件
COPY --from=downloader /opt/ /opt/

# 复制启动脚本并设置执行权限
COPY openppp/entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

# 设置入口点
ENTRYPOINT ["/opt/entrypoint.sh"]
