<?php

namespace App\Plugins\Telegram\Commands;

use App\Plugins\Telegram\Telegram;
use App\Models\User;
use App\Utils\Helper;
use App\Services\StatisticalService;
class GetTopUser extends Telegram {
    public $command = '/top';
    public $description = '查询今日流量排行用户信息（默认前3名）';

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
        $topUsers = $statService->getRanking('user_consumption_rank', $limit);
        
        // 生成排行榜文本
        $text = "🚥今日流量排行Top{$limit}用户\n";
        $text .= "—————————————\n";
        $rank = 1;
        foreach ($topUsers as $userStat) {
            $user = User::find($userStat->user_id);
            $totalTraffic = Helper::trafficConvert($userStat->total);
            $email = $user ? $user->email : '未知';
            $text .= "{$rank}. ID: {$userStat->user_id}，邮箱: {$email}，今日流量: {$totalTraffic}\n";
            $rank++;
        }

        $this->telegramService->sendMessage($message->chat_id, $text);
    }
}
