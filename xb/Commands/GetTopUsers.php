<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\User;
use App\Services\TelegramService;
use App\Services\StatisticalService;
use App\Utils\Helper;

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
        // 统计今日排行数据
        $statService = new StatisticalService();
        $statService->setStartAt(strtotime('today'));
        $statService->setEndAt(strtotime('tomorrow'));
        $limit = 3;
        $topUsers = $statService->getRanking('user_consumption_rank', $limit);

        // 生成 Telegram 消息
        $message = "🚥今日流量排行Top{$limit}用户\n";
        $message .= "—————————————\n";
        $rank = 1;
        foreach ($topUsers as $userStat) {
            $user = User::find($userStat->user_id);
            $totalTraffic = Helper::trafficConvert($userStat->total);
            $email = $user ? $user->email : '未知';
            $message .= "{$rank}. ID: {$userStat->user_id}，邮箱: {$email}，今日流量: {$totalTraffic}\n";
            $rank++;
        }

        // 发送 Telegram 消息
        $telegramService = new TelegramService();
        $telegramService->sendMessageWithAdmin($this->escapeMarkdown($message));
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
     
}
