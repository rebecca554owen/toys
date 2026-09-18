#!/usr/bin/env python3
"""
Concurrent HTTP server for PPP benchmark testing.
Serves static files from a directory with threading support.
Strips query parameters to support cache-busting during benchmarks.

Usage:
    python3 http_server.py [port] [directory]

Defaults:
    port = 9091
    directory = /tmp

On start, any process already listening on the port is force-killed
(SIGKILL), then this server binds it.
"""

import http.server
import os
import signal
import socket
import socketserver
import subprocess
import sys
import time


class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class QuietRequestHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        if "?" in self.path:
            self.path = self.path.split("?")[0]
        super().do_GET()

    def do_HEAD(self):
        if "?" in self.path:
            self.path = self.path.split("?")[0]
        super().do_HEAD()


def _pids_on_port(port):
    try:
        out = subprocess.check_output(
            ["lsof", "-nP", "-iTCP:%d" % port, "-sTCP:LISTEN", "-t"],
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return []
    return [int(p) for p in out.split() if p.strip().isdigit()]


def force_free_port(port, retries=8):
    for _ in range(retries):
        pids = _pids_on_port(port)
        if not pids:
            return True
        for pid in pids:
            if pid == os.getpid():
                continue
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            except PermissionError:
                # try lsof+xargs as fallback (may still fail if not owner)
                subprocess.call(
                    "lsof -ti tcp:%d | xargs -r kill -9" % port,
                    shell=True,
                )
        time.sleep(0.25)
    return not _pids_on_port(port)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 9091
    directory = sys.argv[2] if len(sys.argv) > 2 else "/tmp"

    if not force_free_port(port):
        print(
            "ERROR: port %d still in use after force-kill "
            "(need root? try osascript kill)" % port,
            file=sys.stderr,
        )
        sys.exit(1)

    os.chdir(directory)
    try:
        server = ThreadedHTTPServer(("127.0.0.1", port), QuietRequestHandler)
    except OSError as exc:
        # Non-root often cannot see/kill a root listener via lsof.
        print(
            "ERROR: cannot bind 127.0.0.1:%d (%s).\n"
            "Port is likely held by root. Force-free with osascript:\n"
            "  osascript -e 'do shell script \"lsof -ti tcp:%d | xargs -r kill -9\" "
            "user name \"admin\" password \"<password>\" "
            "with administrator privileges'" % (port, exc, port),
            file=sys.stderr,
        )
        sys.exit(1)
    print("Serving on 127.0.0.1:%d from %s (pid %d)" % (port, directory, os.getpid()))

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")
        server.shutdown()


if __name__ == "__main__":
    main()
