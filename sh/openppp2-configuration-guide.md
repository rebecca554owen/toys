# OpenPPP2 配置指南

## 快速开始

### 服务端配置
1. **部署准备**：选择合适的服务器并建立连接
2. **下载安装**：获取 OpenPPP2 压缩包并解压
3. **配置文件修改**（`appsettings.json`）：
   - **SNIProxy 功能**：如无需此功能，请删除 `cdn` 参数
   - **虚拟内存**：服务器内存 ≥256MB 且磁盘 I/O 性能良好时，建议删除 `vmem` 参数
   - **并发设置**：多核服务器建议将 `concurrent` 值设为 CPU 线程数
   - **IP 绑定配置**：
     - 使用所有 IP 地址：`"ip": {"interface": "::", "public": "::"}`
     - 使用特定 IP：填写具体的 IP 地址
     - 特殊路由场景：interface 设为 `"::"`，public 设为公网 IP
     - 仅使用 IPv4：将所有 `"::"` 替换为 `"0.0.0.0"`
   - **端口设置**：修改 `tcp.listen.port` 和 `udp.listen.port`
   - **WebSocket**：如无需 WebSocket 连接，可删除整个 `websocket` 参数块
   - **日志配置**：设置 `server.log` 为日志路径，或设为 `"/dev/null"` 禁用日志
4. **启动服务**：
   - 添加执行权限：`chmod +x`
   - 后台运行：`screen -S openppp2 ./openppp2`

### 客户端配置
1. **虚拟内存**：PC 或 eMMC 存储设备建议删除 `vmem` 参数
2. **UDP 服务器地址**：设置 `udp.static.server`，支持以下格式：
   - `IP:PORT`（如 `192.168.1.100:20000`）
   - `DOMAIN:PORT`（如 `example.com:20000`）
   - `DOMAIN[IP]:PORT`（如 `example.com[192.168.1.100]:20000`）
3. **客户端标识**：`client.guid` 必须全局唯一，建议使用 UUID 格式
4. **服务端连接地址**：配置 `client.server`，格式为 `ppp://地址:端口/`
5. **带宽限制**：删除 `client.bandwidth` 参数可解除带宽限制
6. **端口映射**：如无需内网穿透功能，删除 `mappings` 参数

## 客户端命令行参数

- **TUN 网关**：Windows 系统 TUN 网关应设置为 `x.x.x.0` 格式
- **静态 UDP**：添加 `--tun-static=yes` 参数可分离 UDP 流量传输
- **QUIC 控制**：`--block-quic=yes` 会完全禁用 QUIC 协议流量

## 核心配置参数详解

### 通用参数（服务端/客户端共用）

#### 并发与内存
- `concurrent`：连接并发数量，建议设为 CPU 核心数
- `vmem`：虚拟内存配置
  - `size`：虚拟文件大小（单位：KB）
  - `path`：虚拟文件存储路径

#### 加密安全
- `key`：加密与流量混淆参数
  - `kf/kx/kl/kh`：密钥帧生成参数，影响加密强度
  - `protocol/transport`：加密算法（需符合 OpenSSL 3.2.0 规范）
  - `protocol-key/transport-key`：对应加密密钥
  - `masked`：启用类似 WebSocket 的掩码机制
  - `plaintext`：将流量转换为可打印文本（增加体积）
  - `delta-encode`：启用差分编码算法（增加 CPU 消耗）
  - `shuffle-data`：打乱二进制数据顺序（增加 CPU 消耗）

#### 网络配置
- `ip`：网络接口绑定
  - `public`：服务端公网 IP 地址
  - `interface`：监听接口 IP 地址
- `tcp`：TCP 连接参数
  - `inactive.timeout`：空闲连接超时时间（秒）
  - `listen.port`：TCP 监听端口
  - `connect.timeout`：连接超时时间
- `udp`：UDP 连接参数
  - `inactive.timeout`：UDP 端口空闲超时
  - `dns.timeout`：DNS 查询超时
  - `dns.redirect`：DNS 重定向地址（默认 `0.0.0.0` 不重定向）
  - `static`：静态 UDP 配置（需配合 `--tun-static` 使用）
    - `keep-alived`：UDP 端口保活时间范围 `[min, max]`
    - `dns/quic/icmp`：启用对应协议的 UDP 传输
    - `server`：UDP 服务器地址（格式同上）

### 服务端专属参数

- `cdn`：启用 SNIProxy 功能，指定需要代理的端口（如 `[80, 443]`）
- `server`：服务端运行配置
  - `log`：连接日志存储路径
  - `node`：节点标识符（多节点部署时需唯一）
  - `subnet`：启用客户端子网互通功能
  - `mapping`：启用反向代理/端口映射功能
  - `backend`：控制面板地址
  - `backend-key`：控制面板认证密钥

### 客户端专属参数

- `client`：客户端配置
  - `guid`：全局唯一客户端标识
  - `server`：服务端连接地址（`ppp://` 或 `ws://` 协议）
  - `bandwidth`：带宽限制（单位：kbps）
  - `reconnections.timeout`：重连超时时间
  - `paper-airplane.tcp`：启用内核级网络加速（可能触发反作弊软件警告）
  - `http-proxy`：本地 HTTP 代理配置
    - `bind`：代理监听 IP
    - `port`：代理监听端口
  - `mappings`：端口映射规则（类似 FRP 功能）
    - `local-ip/port`：本地服务地址和端口
    - `protocol`：传输协议（tcp/udp）
    - `remote-ip/port`：远程映射地址和端口