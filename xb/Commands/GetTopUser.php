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
        if (!$message->is_private) return;

        // 延续使用 StatisticalService 统计方式，从redis获取流量数据。
        $statService = new StatisticalService();
        $statService->setStartAt(strtotime('today'));
        $todayTraffics = $statService->getStatUser();
        $mergedRecords = [];
        foreach ($todayTraffics as $record) {
            $userId = $record['user_id'];
            $traffic = $record['u'] + $record['d'];
            $mergedRecords[$userId] = ($mergedRecords[$userId] ?? 0) + $traffic;
        }
        arsort($mergedRecords);
        $limit = isset($message->args[0]) ? intval($message->args[0]) : 3;
        $topUsers = array_slice($mergedRecords, 0, $limit, true);

        // 动态生成标题和内容
        $text = "🚥今日流量排行Top{$limit}用户\n———————————————————————\n";
        $rank = 1;
        foreach (array_keys($topUsers) as $userId) {
            $user = User::find($userId);
            $totalTraffic = Helper::trafficConvert($mergedRecords[$userId]);
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