#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ppp-macos-bench.py - PPP 链路压力测试

用法:
  python3 ppp-macos-bench.py --rounds 5000 --size 1 \
      --proxy http://127.0.0.1:7899 --host 192.168.100.10:8081

默认:
  --rounds 1000
  --size 10
  --proxy http://127.0.0.1:7899
  --host 192.168.100.10:8081
"""
import argparse, json, statistics, sys, time

def progress_bar(current, total, bar_len=40):
    """Simple terminal progress bar."""
    frac = current / total
    filled = int(bar_len * frac)
    bar = '=' * filled + '-' * (bar_len - filled)
    pct = frac * 100
    sys.stdout.write(f'\r[{bar}] {pct:5.1f}% {current}/{total}')
    sys.stdout.flush()

def curl_once(proxy, url, size_mb, timeout=30):
    """执行单次 curl 走代理，返回 (ok, bytes, time_s, exit_code)。"""
    import subprocess
    expected = size_mb * 1048576
    cmd = ["curl", "-s", "-o", "/dev/null", "-m", str(timeout),
           "-w", "code=%{http_code} time=%{time_total} size=%{size_download}",
           "-x", proxy, url]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 10)
        if r.returncode != 0:
            return False, 0, 0, r.returncode
        code, time_s, size = "", 0, 0
        for kv in r.stdout.strip().split():
            if "=" in kv:
                k, v = kv.split("=", 1)
                if k == "code": code = v
                elif k == "time": time_s = float(v)
                elif k == "size": size = int(v)
        ok = (code == "200" and size >= expected)
        return ok, size, time_s, 0
    except subprocess.TimeoutExpired:
        return False, 0, 0, -1

def main():
    ap = argparse.ArgumentParser(description="PPP 链路压力测试")
    ap.add_argument("--rounds", type=int, default=1000)
    ap.add_argument("--size", type=int, default=10)
    ap.add_argument("--proxy", default="http://127.0.0.1:7899")
    ap.add_argument("--host", default="192.168.100.10:8081")
    ap.add_argument("--timeout", type=int, default=30)
    ap.add_argument("--interval", type=int, default=100)
    ap.add_argument("--json", help="结果写 JSON 文件")
    args = args = ap.parse_args()

    url = f"http://{args.host}/backend/garbage.php?ckSize={args.size}"

    # 预检
    ok, _, _, _ = curl_once(args.proxy, f"http://{args.host}/backend/garbage.php?ckSize=1", 1)
    if not ok:
        print(f"ERROR: proxy {args.proxy} unreachable", file=sys.stderr)
        sys.exit(1)

    print(f"PPP Link Bench")
    print(f"rounds={args.rounds} size={args.size}MB proxy={args.proxy} host={args.host}")
    print()

    start = time.time()
    ok_count = 0
    fail_count = 0
    total_bytes = 0
    times = []
    bar_len = 30

    for i in range(1, args.rounds + 1):
        ok, size, t, ec = curl_once(args.proxy, url, args.size, args.timeout)
        elapsed = time.time() - start
        if ok:
            ok_count += 1
            total_bytes += size
            times.append(t)
            mbps = (size / 1048576) / t if t > 0 else 0
            status = "OK"
        else:
            fail_count += 1
            mbps = 0
            status = "FAIL"

        frac = i / args.rounds
        filled = int(bar_len * frac)
        bar = '=' * filled + '-' * (bar_len - filled)
        avg_mbps = (total_bytes / 1048576) / elapsed if elapsed > 0 else 0

        avg_time = elapsed / i if i > 0 else 0
        eta = avg_time * (args.rounds - i)

        sys.stdout.write(
            f'\r[{bar}] {frac*100:5.1f}% {i}/{args.rounds} | '
            f'{status} {t*1000:.0f}ms {mbps:.1f}MB/s | '
            f'OK={ok_count} FAIL={fail_count} avg={avg_mbps:.1f}MB/s | '
            f'{elapsed:.0f}s ETA {eta:.0f}s'
        )
        sys.stdout.flush()

    print()  # newline

    elapsed = time.time() - start
    print()
    print("RESULT")
    print(f"rounds={args.rounds}")
    print(f"ok={ok_count}")
    print(f"fail={fail_count}")
    print(f"bytes={total_bytes}")
    print(f"time={elapsed:.0f}s")

    if args.json:
        result = {
            "rounds": args.rounds,
            "size_mb": args.size,
            "proxy": args.proxy,
            "host": args.host,
            "ok": ok_count,
            "fail": fail_count,
            "total_bytes": total_bytes,
            "elapsed_s": round(elapsed, 1),
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        with open(args.json, "w") as f:
            json.dump(result, f, indent=2)
        print(f"Saved: {args.json}")

    sys.exit(0 if fail_count == 0 else 1)

if __name__ == "__main__":
    main()
