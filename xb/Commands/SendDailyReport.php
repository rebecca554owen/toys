<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\User;
use App\Models\Order;
use App\Models\Payment;
use App\Services\TelegramService;

class SendDailyReport extends Command
{
    protected $signature = 'xboard:sendDailyReport';
    protected $description = '生成并发送昨日财报';

    public function __construct()
    {
        parent::__construct();
    }

    public function handle()
    {
        $this->sendDailyReport();
    }

    private function sendDailyReport()
    {
        $startOfDay = strtotime('yesterday');
        $endOfDay = strtotime('today');

        $newOrders = Order::where('created_at', '>=', $startOfDay)
            ->where('created_at', '<', $endOfDay)
            ->where('type', 1)
            ->whereNotIn('status', [0, 2])
            ->get();

        $renewOrders = Order::where('created_at', '>=', $startOfDay)
            ->where('created_at', '<', $endOfDay)
            ->where('type', 2)
            ->whereNotIn('status', [0, 2])
            ->get();

        $upgradeOrders = Order::where('created_at', '>=', $startOfDay)
            ->where('created_at', '<', $endOfDay)
            ->where('type', 3)
            ->whereNotIn('status', [0, 2])
            ->get();

        $payments = Payment::where('enable', 1)->distinct()->get(['id', 'name']);
        $paymentSummary = '';

        foreach ($payments as $payment) {
            $orders = Order::where('payment_id', $payment->id)
                ->where('created_at', '>=', $startOfDay)
                ->where('created_at', '<', $endOfDay)
                ->whereNotIn('status', [0, 2])
                ->get();
            $totalAmount = $orders->sum('total_amount') / 100;
            if ($totalAmount > 0) {
                $paymentSummary .= "通过【{$payment->name}】收款 {$orders->count()} 笔，共计： {$totalAmount} 元\n";
            }
        }

        if ($paymentSummary == '') {
            $manualOrders = Order::where('callback_no', 'manual_operation')
                ->where('created_at', '>=', $startOfDay)
                ->where('created_at', '<', $endOfDay)
                ->whereNotIn('status', [0, 2])
                ->get();
            $totalManualAmount = $manualOrders->sum('total_amount') / 100;
            if ($totalManualAmount >= 0) {
                $paymentSummary = "通过【手动操作】收款 {$manualOrders->count()} 笔，共计： {$totalManualAmount} 元\n";
            }
        }

        $totalOrderAmount = Order::where('created_at', '>=', $startOfDay)
            ->where('created_at', '<', $endOfDay)
            ->whereNotIn('status', [0, 2])
            ->sum('total_amount') / 100;

        $dayRegisterTotal = User::where('created_at', '>=', $startOfDay)
            ->where('created_at', '<', $endOfDay)
            ->count();

        $expiredUsersTotal = User::where('expired_at', '>=', $startOfDay)
            ->where('expired_at', '<', $endOfDay)
            ->count();

        $message = "📋 昨日财报\n";
        $message .= "———————————\n";
        $message .= "1）用户：\n";
        $message .= "昨日注册用户数： {$dayRegisterTotal} 人\n";
        $message .= "昨日到期用户数： {$expiredUsersTotal} 人\n\n";
        $message .= "2）订单：\n";
        $message .= "新购订单： {$newOrders->count()} 个，共计 " . ($newOrders->sum('total_amount') / 100) . " 元\n";
        $message .= "续费订单： {$renewOrders->count()} 个，共计 " . ($renewOrders->sum('total_amount') / 100) . " 元\n";
        $message .= "升级订单： {$upgradeOrders->count()} 个，共计 " . ($upgradeOrders->sum('total_amount') / 100) . " 元\n\n";
        $message .= $paymentSummary;
        $message .= "\n总收入： {$totalOrderAmount} 元\n";

        if ($totalOrderAmount > 0 || $paymentSummary != '') {
            $telegramService = new TelegramService();
            $telegramService->sendMessageWithAdmin($message);
        }
    }
}
