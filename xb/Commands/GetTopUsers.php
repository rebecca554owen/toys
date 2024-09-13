<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\User;
use App\Services\TelegramService;
use App\Services\StatisticalService;

class GetTopUsers extends Command
{
    protected $signature = 'xboard:getTopUsers';
    protected $description = '获取今日用户流量排行前3的用户';

    public function __construct()
    {
        parent::__construct();
    }

    public function handle()
    {
        $this->getTopUsers();
    }

    private function getTopUsers()
    {
        // 获取今天的开始时间戳
        $recordAt = strtotime('today');
        
        // 获取今天的用户流量
        $statService = new StatisticalService();
        $statService->setStartAt($recordAt);
        $todayTraffics = $statService->getStatUser();

        // 合并相同用户的流量
        $mergedRecords = [];
        foreach ($todayTraffics as $record) {
            $userId = $record['user_id'];
            $traffic = $record['u'] + $record['d'];
            if (isset($mergedRecords[$userId])) {
                $mergedRecords[$userId] += $traffic;
            } else {
                $mergedRecords[$userId] = $traffic;
            }
        }

        // 将合并后的记录进行排序并获取前三个
        $sortedRecords = collect($mergedRecords)->sortByDesc(function ($traffic) {
            return $traffic;
        })->take(3);

        // 生成 Telegram 消息
        $message = "📊 今日用户流量排行前3名\n";
        $message .= "———————————\n";
        foreach ($sortedRecords as $userId => $totalTraffic) {
            $totalTrafficFormatted = $this->formatBytes($totalTraffic);
            $user = User::find($userId);
            $email = $user ? $this->maskEmail($user->email) : '未知';
            $message .= "用户ID: {$userId}，邮箱: {$email}，流量使用总计：{$totalTrafficFormatted}\n";
        }

        // 发送 Telegram 消息
        $telegramService = new TelegramService();
        $telegramService->sendMessageWithAdmin($this->escapeMarkdown($message));
    }

    private function formatBytes($bytes)
    {
        if ($bytes >= 1024 * 1024 * 1024 * 1024) {
            return round($bytes / (1024 * 1024 * 1024 * 1024), 2) . ' TB';
        } elseif ($bytes >= 1024 * 1024 * 1024) {
            return round($bytes / (1024 * 1024 * 1024), 2) . ' GB';
        } elseif ($bytes >= 1024 * 1024) {
            return round($bytes / (1024 * 1024), 2) . ' MB';
        } else {
            return round($bytes / 1024, 2) . ' KB';
        }
    }

    private function escapeMarkdown($text)
    {
        $escapeChars = ['_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '+', '-', '=', '|', '{', '}', '!'];
        $escapedText = '';
        foreach (str_split($text) as $char) {
            if (in_array($char, $escapeChars)) {
                $escapedText .= '\\' . $char;
            } else {
                $escapedText .= $char;
            }
        }
        return $escapedText;
    }
     
    private function maskEmail($email)
    {
        $emailParts = explode('@', $email);
        $localPart = $emailParts[0];
        $localPartLength = strlen($localPart);
        $maskLength = floor($localPartLength / 2);
        $maskedLocalPart = substr($localPart, 0, $localPartLength - $maskLength) . str_repeat('*', $maskLength);
        return $maskedLocalPart . '@' . $emailParts[1];
    }
}
