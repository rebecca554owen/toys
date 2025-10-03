<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Services\TelegramService;
use App\Services\StatisticalService;
use App\Utils\Helper;

class GetServerYesterdayRank extends Command
{
    protected $signature = 'xboard:getServerYesterdayRank';
    protected $description = '获取昨日节点流量排行';

    public function __construct()
    {
        parent::__construct();
    }

    public function handle()
    {
        $this->getServerYesterdayRank();
    }

    private function getServerYesterdayRank()
    {
        $statService = new StatisticalService();
        $statService->setStartAt(strtotime('yesterday'));
        $statService->setEndAt(strtotime('today'));
        $limit = 3;
        $topServers = $statService->getRanking('server_traffic_rank', $limit);

        $message = "🚥昨日节点流量排行Top{$limit}\n";
        $message .= "—————————————\n";
        $rank = 1;
        foreach ($topServers as $serverStat) {
            $totalTraffic = Helper::trafficConvert($serverStat->u + $serverStat->d);
            $message .= "{$rank}. 节点ID: {$serverStat->server_id}，类型: {$serverStat->server_type}，流量: {$totalTraffic}\n";
            $rank++;
        }

        $telegramService = new TelegramService();
        $telegramService->sendMessageWithAdmin($message);
    }
}
