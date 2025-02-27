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
        $telegramService = $this->telegramService;

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
        $text = "🚥今日流量排行Top{$limit}用户\n—————————————\n";
        $rank = 1;
        foreach ($topUsers as $userStat) {
            $user = User::find($userStat->user_id);
            $totalTraffic = Helper::trafficConvert($userStat->total);
            $emailParts = explode('@', $user->email);
            $localPart = $emailParts[0];
            $visibleLength = floor(strlen($localPart) / 2);
            $maskedLocal = substr($localPart, 0, $visibleLength) . str_repeat('*', strlen($localPart) - $visibleLength);
            
            $text .= "{$rank}. ID: `{$user->id}`，邮箱: `{$maskedLocal}@{$emailParts[1]}`，今日流量: `{$totalTraffic}`\n";
            $rank++;
        }

        $telegramService->sendMessage($message->chat_id, $text, 'markdown');
    }
}