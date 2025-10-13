<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\User;
use App\Services\TelegramService;

class UpdateExpiredUsers extends Command
{
    protected $signature = 'xboard:updateExpiredUsers';
    protected $description = '处理到期用户';

    public function __construct()
    {
        parent::__construct();
    }

    public function handle()
    {
        $this->updateExpiredUsers();
    }

    private function updateExpiredUsers()
    {
        $expiredUsers = User::where('expired_at', '<', time())->get();
        $batchSize = 50; // 每批处理50个用户

        foreach ($expiredUsers->chunk($batchSize) as $batch) {
            $TGmessage = "📮 到期用户处理报告\n";
            $batchHasUpdates = false;

            foreach ($batch as $user) {
                if ($user->plan_id === null && $user->group_id === null && $user->u === 0 && $user->d === 0 && $user->transfer_enable === 0) {
                    continue;
                }

                $user->update([
                    'plan_id' => null,
                    'group_id' => null,
                    'u' => 0,
                    'd' => 0,
                    'transfer_enable' => 0,
                    'expired_at' => 0
                ]);

                $TGmessage .= "邮箱: `{$user->email}`\n";
                $batchHasUpdates = true;
            }

            if ($batchHasUpdates) {
                $TGmessage .= "\n✅ 本批次处理完成，共处理 {$batch->count()} 个用户";
                $telegramService = new TelegramService();
                $telegramService->sendMessageWithAdmin($TGmessage);
            }
        }
    }
}
