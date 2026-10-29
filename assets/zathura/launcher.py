#!@@PYTHON@@
"""Prepare runtime environment for the native viewer without replacing it."""
import fcntl
import os
from pathlib import Path
import stat
import subprocess
import sys

resources = Path(__file__).resolve().parent
app = resources.parent.parent
os.environ["ZATHURA_PLUGIN_PATH"] = "@@PLUGINS@@"
os.environ["PATH"] = "@@HOMEBREW_PREFIX@@/bin:" + os.environ.get("PATH", "/usr/bin:/bin")
os.environ["XDG_DATA_DIRS"] = "@@HOMEBREW_PREFIX@@/share:" + os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")

if not any(arg in ("--help", "-h", "--version", "-v") for arg in sys.argv[1:]):
    runtime = Path("/tmp") / f"@@RUNTIME@@-{os.getuid()}"
    runtime.mkdir(mode=0o700, exist_ok=True)
    info = runtime.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        sys.exit(f"Unsafe runtime directory: {runtime}")
    address = f"unix:path={runtime / 'bus'}"
    with (runtime / "bus.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            alive = subprocess.run([
                "@@GDBUS@@", "call", "--address", address,
                "--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus",
                "--method", "org.freedesktop.DBus.Peer.Ping",
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5).returncode == 0
        except subprocess.TimeoutExpired:
            alive = False
        if not alive:
            subprocess.run([
                "@@DBUS@@", f"--config-file={resources / 'session.conf'}",
                f"--address={address}", "--fork",
            ], check=True, timeout=5)
        registration = runtime / "registered-app"
        if not registration.exists() or registration.read_text() != str(app):
            try:
                result = subprocess.run([
                    "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                    "-f", str(app),
                ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
                if result.returncode == 0:
                    registration.write_text(str(app))
            except (OSError, subprocess.TimeoutExpired):
                pass
    os.environ["DBUS_SESSION_BUS_ADDRESS"] = address

# NUL delimiters preserve spaces, newlines and non-UTF-8 filesystem paths.
for key in ("PATH", "XDG_DATA_DIRS", "ZATHURA_PLUGIN_PATH", "DBUS_SESSION_BUS_ADDRESS"):
    if key in os.environ:
        sys.stdout.buffer.write(os.fsencode(f"{key}={os.environ[key]}") + b"\0")
sys.stdout.buffer.write(b"\0")
