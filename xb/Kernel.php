<?php

namespace App\Console;

use App\Utils\CacheKey;
use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;
use Illuminate\Support\Facades\Cache;

class Kernel extends ConsoleKernel
{
    /**
     * The Artisan commands provided by your application.
     *
     * @var array
     */
    protected $commands = [
        //
    ];

    /**
     * Define the application's command schedule.
     *
     * @param \Illuminate\Console\Scheduling\Schedule $schedule
     * @return void
     */
    protected function schedule(Schedule $schedule)
    {
        Cache::put(CacheKey::get('SCHEDULE_LAST_CHECK_AT', null), time());
        // v2board
        $schedule->command('xboard:statistics')->dailyAt('0:10')->onOneServer();
        // check
        $schedule->command('check:order')->everyMinute()->onOneServer();
        $schedule->command('check:commission')->everyMinute()->onOneServer();
        $schedule->command('check:ticket')->everyMinute()->onOneServer();
        // reset
        $schedule->command('reset:traffic')->daily()->onOneServer();
        $schedule->command('reset:log')->daily()->onOneServer();
        // send
        $schedule->command('send:remindMail')->dailyAt('11:30')->onOneServer();
        // horizon metrics
        $schedule->command('horizon:snapshot')->everyFiveMinutes()->onOneServer();
        // backup Timing
        if (env('ENABLE_AUTO_BACKUP_AND_UPDATE', false)) {
            $schedule->command('backup:database', ['true'])->daily()->onOneServer();
        }
        // 自定义插件任务，按每分钟、每5分钟、每小时、每天执行
        // 更新过期用户状态，每5分钟执行
        $schedule->command('xboard:updateExpiredUsers')->everyFiveMinutes()->onOneServer();  
        // 获取服务器今日流量实时排名，每小时执行
        $schedule->command('xboard:getServerTodayRealTimeRank')->hourly()->onOneServer();
        // 获取流量消耗最多的用户，每小时执行
        $schedule->command('xboard:getTopUsers')->hourly()->onOneServer();
        // 获取服务器昨日流量排名，每天8:00执行
        $schedule->command('xboard:getServerYesterdayRank')->dailyAt('8:00')->onOneServer();
        // 发送每日报告，每天8:30执行
        $schedule->command('xboard:sendDailyReport')->dailyAt('8:30')->onOneServer();  

    }

    /**
     * Register the commands for the application.
     *
     * @return void
     */
    protected function commands()
    {
        $this->load(__DIR__ . '/Commands');

        require base_path('routes/console.php');
    }
}