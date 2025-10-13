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
## 2.aapanel + docker 全挂载部署说明
### 文件目录结构
```
/www
├── app/
│   └── Console/
│       ├── Kernel.php                # 核心调度文件（需覆盖以激活插件命令）
│       └── Commands/
│           ├── updateExpiredUsers.php            # 用户订阅状态维护（5分钟周期）
│           ├── getServerTodayRealTimeRank.php    # 实时流量排行统计（每小时） 
│           ├── getTopUsers.php                   # 用户流量排行统计（每小时）
│           ├── getServerYesterdayRank.php        # 昨日流量排行统计（每日8:00）
│           └── sendDailyReport.php               # 运营报表生成（每日8:30）
```

## 3.手动执行测试命令是否生效

### 用户订阅状态相关
`docker compose run -it --rm xboard php artisan xboard:updateExpiredUsers`  # 手动执行用户订阅状态更新（每5分钟）

### 实时数据统计
`docker compose run -it --rm xboard php artisan xboard:getServerTodayRealTimeRank`  # 获取当日服务器实时流量排行（每小时）
`docker compose run -it --rm xboard php artisan xboard:getTopUsers`                 # 获取用户流量使用排行（每小时）

### 每日定时任务
`docker compose run -it --rm xboard php artisan xboard:getServerYesterdayRank`  # 获取昨日服务器流量排行（每日8:00）
`docker compose run -it --rm xboard php artisan xboard:sendDailyReport`         # 发送每日运营报表（每日8:30）
