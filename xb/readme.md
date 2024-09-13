# xboard 插件使用指南
## 1.docker compose 部署方式，推荐使用
 挂载php插件示例
```
  xboard:
    image: ghcr.io/cedar2025/xboard:latest
    volumes:
      - ./.env:/www/.env 
      - ./.docker/.data/:/www/.docker/.data/
      - ./Kernel.php:/www/app/Console/Kernel.php # 覆盖Kernel.php文件，激活新增插件命令，修改定时在次文件内修改。
      - ./Commands/updateExpiredUsers.php:/www/app/Console/Commands/updateExpiredUsers.php # everyFiveMinutes 每5分钟修改到期用户为无订阅。
      - ./Commands/getServerTodayRealTimeRank.php:/www/app/Console/Commands/getServerTodayRealTimeRank.php # hourly() 每1小时获取当日实时流量排行前三。
      - ./Commands/getTopUsers.php:/www/app/Console/Commands/getTopUsers.php # hourly() 每1小时获取用户排行
      - ./Commands/getServerYesterdayRank.php:/www/app/Console/Commands/getServerYesterdayRank.php # dailyAt('8:00') 每天8:00报送昨日已用流量排行前三。
      - ./Commands/sendDailyReport.php:/www/app/Console/Commands/sendDailyReport.php # dailyAt('8:30') 每天8:30报送昨日财报。

```
## 2.aapanel + docker 全挂载的，直接把文件放到相应的位置即可，/www 为站点目录。
```
/www/app/Console/Kernel.php
/www/app/Console/Commands/* 
```

## 3.手动执行测试命令是否生效  

`docker compose run -it --rm xboard php artisan xboard:updateExpiredUsers`
`docker compose run -it --rm xboard php artisan xboard:getServerTodayRealTimeRank`
`docker compose run -it --rm xboard php artisan xboard:getTopUsers`
`docker compose run -it --rm xboard php artisan xboard:getServerYesterdayRank`
`docker compose run -it --rm xboard php artisan xboard:sendDailyReport`
