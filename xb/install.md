# Xboard 内测 new 分支的安装步骤  
变更日志：重写了新后台，去掉了webman nginx supervisor 等服务，换成了 octane 去掉了大量的依赖包。  
原本是xboard里边集成了进程守护，加上redis两个服务。  
现在新分支三个服务，一个是 web 主服务，一个是 horizon 进程守护服务，一个是 redis 。  

`现在的版本并不适合生产，想要尝鲜的可以同学，跟我下面的步骤操作部署体验`  

## 1.首先克隆仓库文件 
```bash
git clone -b new --depth 1 https://github.com/cedar2025/Xboard
```

## 2.其次进入仓库目录 
```bash
cd Xboard
```
再次提前准备 .env 文件，复制 .env.example 并重命名为 .env
```bash
cp .env.example .env
```

## 3.接下来写入docker-compose.yaml文件
```yaml
services:
  web:
    # build: .
    image: ghcr.io/rebecca554owen/xboard:latest
    volumes:
      - ./:/www/
      - redis-socket:/run/redis-socket
    environment:
      - docker=true
    depends_on:
      - redis
    network_mode: host
    command: php artisan octane:start --server="swoole" --port=8000
    restart: on-failure
  horizon:
    # build: .
    image: ghcr.io/rebecca554owen/xboard:latest
    volumes:
      - ./:/www/
      - redis-socket:/run/redis-socket
    restart: on-failure
    network_mode: host
    command: php artisan horizon
    depends_on:
      - redis
  redis:
    build: 
      context: .docker/services/redis
    restart: on-failure
    volumes:
      - ./.docker/.data/redis:/data/ # 挂载redis持久化数据
      - redis-socket:/run/redis-socket
volumes:
  redis-socket:
```

## 4. 初始化项目
接着输入依赖安装命令（pull镜像应该可以省略）
```bash
docker compose run -it --rm web composer install
```

执行初始化命令，连接到数据库
```bash
docker compose run -it --rm web php artisan xboard:install
```
安装完毕，输入启动命令
```bash
docker compose up -d
``` 

## 5. 访问项目
Nginx 自行反向代理 `http://127.0.0.1:8000` 打开浏览器访问自己的 Nginx 站点，即可看到项目运行。
