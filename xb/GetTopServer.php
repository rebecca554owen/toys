<?php

namespace App\Plugins\Telegram\Commands;

use App\Plugins\Telegram\Telegram;
use App\Models\User;
use App\Utils\Helper;
use App\Services\StatisticalService;

class GetTopServer extends Telegram { 
    public $command = '/tops'; 
    public $description = '查询今日节点流量排行（默认前3名）';

    public function handle($message, $match = []) {
        $telegramService = $this->telegramService;
        if (!$message->is_private) return;

        $statService = new StatisticalService();
        $statService->setStartAt(strtotime('today'));
        $statService->setEndAt(strtotime('tomorrow'));
        
        // 获取用户输入的排行数量参数
        $limit = isset($message->args[0]) ? intval($message->args[0]) : 3;
        
        // 修改统计类型为服务器流量排行
        $topServers = $statService->getRanking('server_traffic_rank', $limit);
        
        // 修改排行榜生成逻辑
        $text = "🚥今日节点流量排行Top{$limit}\n———————————————————————\n";
        $rank = 1;
        foreach ($topServers as $serverStat) {
            $totalTraffic = Helper::trafficConvert($serverStat->u + $serverStat->d);
            $text .= "{$rank}. 节点ID: `{$serverStat->server_id}`，类型: `{$serverStat->server_type}`，流量: `{$totalTraffic}`\n";
            $rank++;
        }

        $telegramService->sendMessage($message->chat_id, $text, 'markdown');
    }
}