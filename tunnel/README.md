# this nginx tls tunnel 
1.安装docker
```
curl -fsSL https://get.docker.com | bash -s docker && systemctl start docker && systemctl enable docker
```
1.1国内及机器安装
```
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun && systemctl start docker && systemctl enable docker
```
2.修改隧道入口配置，国内/国外机器
```
vim stream/tunnel.conf
```
3.然后在目录执行启动命令。 
```
docker compose up -d
```
