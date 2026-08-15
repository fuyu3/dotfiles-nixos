#!/usr/bin/env python3

import json
import os
import socket
import sys
import threading
import time
from pathlib import Path

SPEED = 1.0
POLL_HZ = 60
CTL_SOCKET = Path("/tmp/canvasd.sock")

BLACKLIST_CLASSES = {
    "kitty-dropterm",
    "spotify",
}

def _socket_path() -> str:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not sig:
        raise RuntimeError(
            "HYPRLAND_INSTANCE_SIGNATURE não definido.\n"
            "Execute o daemon dentro do Hyprland."
        )

    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    return f"{xdg}/hypr/{sig}/.socket.sock"


def _ipc(msg: str) -> bytes:
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(_socket_path())

        s.sendall(msg.encode())
        s.shutdown(socket.SHUT_WR)

        chunks = []

        while True:
            chunk = s.recv(4096)

            if not chunk:
                break

            chunks.append(chunk)

    return b"".join(chunks)


def _ipc_json(cmd: str):
    return json.loads(_ipc(f"j/{cmd}"))


def move_window(addr: str, x: int, y: int):
    lua = (
        "eval "
        "hl.dispatch("
        "hl.dsp.window.move({"
        f"x = {x}, "
        f"y = {y}, "
        "relative = false, "
        f'window = "address:{addr}"'
        "})"
        ")"
    )

    return _ipc(lua).decode(errors="replace").strip()


def cursor_pos():
    data = _ipc_json("cursorpos")
    return int(data["x"]), int(data["y"])


def floating_windows():
    clients = _ipc_json("clients")
    active = _ipc_json("activeworkspace")

    ws_id = active["id"]

    return [
    c
    for c in clients
    if (
        c.get("floating")
        and c.get("workspace", {}).get("id") == ws_id
        and c.get("class", "") not in BLACKLIST_CLASSES
    )
]


class PanState:
    def __init__(self):
        self.active = False
        self.last_x = 0
        self.last_y = 0
        self.lock = threading.Lock()

    def start(self, x, y):
        with self.lock:
            self.last_x = x
            self.last_y = y
            self.active = True

    def stop(self):
        with self.lock:
            self.active = False

    def consume_delta(self, x, y):
        with self.lock:
            dx = x - self.last_x
            dy = y - self.last_y

            self.last_x = x
            self.last_y = y

            return dx, dy


class CanvasDaemon:
    def __init__(self):
        self.running = True
        self.pan = PanState()

    def _handle(self, cmd):
        if cmd == "pan-start":
            try:
                x, y = cursor_pos()
                self.pan.start(x, y)

                print(
                    f"[canvasd] pan iniciado em ({x}, {y})",
                    flush=True,
                )

            except Exception as e:
                print(
                    f"[canvasd] erro ao iniciar pan: {e}",
                    file=sys.stderr,
                    flush=True,
                )

        elif cmd == "pan-stop":
            self.pan.stop()
            print("[canvasd] pan parado", flush=True)

        elif cmd == "stop":
            self.running = False

    def _ctl_server(self):
        if CTL_SOCKET.exists():
            CTL_SOCKET.unlink()

        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as srv:
            srv.bind(str(CTL_SOCKET))
            srv.listen(8)
            srv.settimeout(1.0)

            while self.running:
                try:
                    conn, _ = srv.accept()

                except socket.timeout:
                    continue

                with conn:
                    cmd = conn.recv(64).decode().strip()

                    self._handle(cmd)

                    conn.sendall(b"ok\n")

        if CTL_SOCKET.exists():
            CTL_SOCKET.unlink()

    def _pan_loop(self):
        interval = 1.0 / POLL_HZ

        while self.running:
            if not self.pan.active:
                time.sleep(interval)
                continue

            try:
                cx, cy = cursor_pos()

                dx, dy = self.pan.consume_delta(cx, cy)

                if dx == 0 and dy == 0:
                    time.sleep(interval)
                    continue

                dx = int(dx * SPEED)
                dy = int(dy * SPEED)

                windows = floating_windows()

                if not windows:
                    time.sleep(interval)
                    continue

                print(
                    f"[canvasd] Δ({dx:+}, {dy:+}) × {len(windows)}",
                    flush=True,
                )

                for w in windows:
                    addr = w["address"]

                    ox = w["at"][0]
                    oy = w["at"][1]

                    nx = ox + dx
                    ny = oy + dy

                    try:
                        move_window(addr, nx, ny)

                    except Exception as e:
                        print(
                            f"[canvasd] erro ao mover {addr}: {e}",
                            file=sys.stderr,
                            flush=True,
                        )

            except Exception as e:
                print(
                    f"[canvasd] erro no loop: {e}",
                    file=sys.stderr,
                    flush=True,
                )

            time.sleep(interval)

    def run(self):
        print("[canvasd] iniciado", flush=True)

        threading.Thread(
            target=self._ctl_server,
            daemon=True,
        ).start()

        try:
            self._pan_loop()

        except KeyboardInterrupt:
            pass

        finally:
            self.running = False

            if CTL_SOCKET.exists():
                CTL_SOCKET.unlink()

            print("[canvasd] encerrado", flush=True)


def ctl_send(cmd):
    if not CTL_SOCKET.exists():
        sys.exit("canvasd não está rodando.")

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(str(CTL_SOCKET))

        s.sendall(cmd.encode())

        return s.recv(64).decode().strip()


CMDS = {"pan-start", "pan-stop", "ping", "stop"}

if __name__ == "__main__":
    args = sys.argv[1:]

    if not args:
        CanvasDaemon().run()

    elif args[0] in CMDS:
        print(ctl_send(args[0]))

    else:
        print(
            f"uso: canvasd.py [{'|'.join(sorted(CMDS))}]",
            file=sys.stderr,
        )

        sys.exit(1)