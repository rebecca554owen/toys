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
## compose.yaml 适用于openppp2
```
mkdir openppp2
cd openppp2
curl -Ls https://raw.githubusercontent.com/rebecca554owen/toys/main/compose.yaml
docker compose up -d
```
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
