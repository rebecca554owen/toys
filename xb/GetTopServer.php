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
        // 检查用户权限
        if (!$message->is_private) return;
        $user = User::where('telegram_id', $message->chat_id)->first();
        if ($user && ($user->is_admin || $user->is_staff)) {
            // 管理员或员工可以执行命令
        } else {
            // 普通用户，不发送消息
            return;
        }

        // 初始化统计服务
        $statService = new StatisticalService();
        $statService->setStartAt(strtotime('today'));
        $statService->setEndAt(strtotime('tomorrow'));
        
        // 获取用户输入的排行数量参数
        $limit = isset($message->args[0]) ? intval($message->args[0]) : 3;
        
        // 修改统计类型为服务器流量排行
        $topServers = $statService->getRanking('server_traffic_rank', $limit);
        
        // 修改排行榜生成逻辑
        $text = "🚥今日节点流量排行Top{$limit}\n";
        $text .= "—————————————\n";
        $rank = 1;
        foreach ($topServers as $serverStat) {
            $totalTraffic = Helper::trafficConvert($serverStat->u + $serverStat->d);
            $text .= "{$rank}. 节点ID: {$serverStat->server_id}，类型: {$serverStat->server_type}，流量: {$totalTraffic}\n";
            $rank++;
        }

        $this->telegramService->sendMessage($message->chat_id, $text);
    }
}
