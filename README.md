#  自用脚本
## autocheck.sh，适用于 Lightsail 检查流量超出自动关机脚本
```
bash <(curl -Ls https://raw.githubusercontent.com/rebecca554owen/toys/main/sh/autocheck.sh)
```
## bbr.sh，适用于 vps 加速
```
bash <(curl -Ls https://raw.githubusercontent.com/rebecca554owen/toys/main/sh/bbr.sh)
```
## get-py.py 适用于自动下载Python
```
bash <(curl -Ls https://raw.githubusercontent.com/rebecca554owen/toys/main/sh/get-py.sh)
```
## ppp.sh 适用于openppp2安装
```
bash <(curl -Ls https://raw.githubusercontent.com/rebecca554owen/toys/main/sh/ppp.sh)
```
## v2bx.sh 适用于v2bx配置生成
```
bash <(curl -Ls https://raw.githubusercontent.com/rebecca554owen/toys/main/sh/v2bx.sh) \
  CoreType=xray \
  ApiHost=api.example.com \
  ApiKey=your_api_key \
  NodeID=1 \
  NodeType=shadowsocks
```
## compose.yaml 适用于openppp2 默认版（AMD64 默认开启 SIMD）
```
mkdir openppp2
cd openppp2
curl -Ls https://raw.githubusercontent.com/rebecca554owen/toys/main/compose.yaml
docker compose up -d
```
## compose.amd64-optimized.yaml 适用于openppp2 IO 版（IO_URING + SIMD）
```
mkdir openppp2
cd openppp2
curl -Lo compose.amd64-optimized.yaml https://raw.githubusercontent.com/rebecca554owen/toys/main/compose.amd64-optimized.yaml
docker compose -f compose.amd64-optimized.yaml up -d
```
## compose.tc.yaml 适用于openppp2 TC/SYSNAT 版（仅推荐 Linux 宿主机）
```
mkdir openppp2
cd openppp2
curl -Lo compose.tc.yaml https://raw.githubusercontent.com/rebecca554owen/toys/main/compose.tc.yaml
docker compose -f compose.tc.yaml up -d
```
### openppp2 compose 自动分流
compose 示例默认开启 `ENABLE_BYPASS=true`，容器会使用镜像内置默认值拉取 `CN` IP 列表到 `/opt/ip.txt`，启动客户端时自动追加 `--bypass=/opt/ip.txt` 和 `--virr=/opt/ip.txt<CN`。如需覆盖默认值，可额外设置 `BYPASS_COUNTRY`、`BYPASS_IPLIST_PATH`、`BYPASS_REFRESH`、`BYPASS_PULL_ON_START`。

## miaospeed 后端docker run 一键启动
```
docker run -d --name miaospeed-koipy --restart always --network host airportr/miaospeed:latest server -bind [::]:8766 -mtls -connthread 64 -token fulltclash -ipv6
```
## miaospeed 后端docker-compose 启动
```
mkdir miaospeed
cd miaospeed
curl -Ls https://raw.githubusercontent.com/rebecca554owen/toys/main/miaospeed/docker-compose.yaml
docker compose up -d
```
## Koipy 黑名单列表
```
https://raw.githubusercontent.com/rebecca554owen/toys/main/invireBlacklistDomain.txt
```
```
https://raw.githubusercontent.com/rebecca554owen/toys/main/invireBlacklistURL.txt
```
## clash-verge-rec.js 适用于mihomo-patry
```
https://raw.githubusercontent.com/rebecca554owen/toys/main/clash-verge-rec.js
```
## yaml.yaml 适用于mihomo-patry
```
https://raw.githubusercontent.com/rebecca554owen/toys/main/yaml.yaml
```
## 1Panel 迁移工具脚本
使用仓库根目录的 `sh.sh` 自动下载并安装 1Panel 迁移工具，先执行核心升级，可按提示选择是否升级站点。
```
bash <(curl -Ls https://raw.githubusercontent.com/rebecca554owen/toys/main/sh.sh)
```
