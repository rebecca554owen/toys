<?php

namespace App\Plugins\Telegram\Commands;

use App\Plugins\Telegram\Telegram;
use App\Models\User;
use App\Utils\Helper;
use App\Services\StatisticalService;

class GetTopUser extends Telegram {
    public $command = '/top';
    public $description = '查询今日用户流量排行（默认前3名）';

    public function handle($message, $match = []) {
        $telegramService = $this->telegramService;
        if (!$message->is_private) return;

        $statService = new StatisticalService();
        $statService->setStartAt(strtotime('today'));
        $statService->setEndAt(strtotime('tomorrow'));
        
        // 获取用户输入的排行数量参数
        $limit = isset($message->args[0]) ? intval($message->args[0]) : 3;
        $topUsers = $statService->getRanking('user_consumption_rank', $limit);
        
        // 生成排行榜文本
        $text = "🚥今日用户流量排行Top{$limit}\n———————————————————————\n";
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