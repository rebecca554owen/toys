<?php

namespace App\Plugins\Telegram\Commands;

use App\Plugins\Telegram\Telegram;
use App\Models\User; 

class Start extends Telegram {
    public $command = '/start';
    public $description = '显示用户引导菜单';

    public function handle($message, $match = []) {
        if (!$message->is_private) return;
        $telegramService = $this->telegramService;
        
        // 发送欢迎消息
        $text = "🎉 欢迎使用 " . admin_setting('app_name', 'XBoard') . " 机器人\n\n";
        $text .= "📋 可用命令：\n";
        $text .= "`/bind <订阅地址>` - 绑定 Telegram \n";
        $text .= "`/traffic` - 查询账户流量使用情况\n";
        $text .= "`/getlatesturl` - 获取最新站点地址\n";
        $text .= "`/unbind` - 解除 Telegram 账号绑定\n";
        
        // 检查用户是否为管理员或员工
        $user = User::where('telegram_id', $message->chat_id)->first();
        if ($user && ($user->is_admin || $user->is_staff)) {
            $text .= "\n👮 管理员命令：\n";
            $text .= "`#reply <工单ID>` - 快速回复工单\n";
            $text .= "`/top <数量>` - 查询指定数量的流量排行\n";
        }
        
        $text .= "\n📌 请直接发送上述命令进行操作";
        $telegramService->sendMessage(
            $message->chat_id,
            $text,
            'markdown'
        );
    }
}