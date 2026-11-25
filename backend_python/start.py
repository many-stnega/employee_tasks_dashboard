#!/usr/bin/env python3
"""Run the dashboard application and Telegram bot together in one container."""
import signal
import subprocess
import sys
import time


def main() -> int:
    processes = []
    stopping = False

    def stop(signum, frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    try:
        processes.append(subprocess.Popen([
            sys.executable, "-m", "gunicorn",
            "--bind", "0.0.0.0:8000",
            "--workers", "2",
            "--access-logfile", "-",
            "--error-logfile", "-",
            "backend_python.web_app:app",
        ]))
        processes.append(subprocess.Popen([sys.executable, "/app/backend_python/bot.py"]))
        while not stopping:
            exited = [(process, process.poll()) for process in processes]
            exited = [(process, status) for process, status in exited if status is not None]
            if exited:
                for process, status in exited:
                    print(f"Child process {process.args!r} exited with status {status}.", file=sys.stderr)
                return 1
            time.sleep(0.25)
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for process in processes:
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
