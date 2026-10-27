#!@@PYTHON@@
"""Shared private D-Bus for terminal and Launch Services entry points."""
import fcntl
import os
from pathlib import Path
import stat
import subprocess
import sys

macos = Path(__file__).resolve().parent
binary = macos / "zathura-bin"
resources = macos.parent / "Resources"
args = [str(binary), "--plugins-dir", str(macos.parents[2] / "libexec/plugins")]
if os.environ.get("ZATHURA_SYNCTEX_EDITOR"):
    args += ["--synctex-editor-command", os.environ["ZATHURA_SYNCTEX_EDITOR"]]
args += sys.argv[1:]
os.environ["PATH"] = "@@HOMEBREW_PREFIX@@/bin:" + os.environ.get("PATH", "/usr/bin:/bin")
os.environ["XDG_DATA_DIRS"] = "@@HOMEBREW_PREFIX@@/share:" + os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")

# Informational commands do not need a session bus.
if not any(arg in ("--help", "-h", "--version", "-v") for arg in sys.argv[1:]):
    # Registration needs the user's GUI session, not Homebrew's install sandbox.
    try:
        subprocess.run([
            "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
            "-f", str(macos.parent.parent),
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        pass
    runtime = Path("/tmp") / f"zathura-{os.getuid()}-homebrew"
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
    os.environ["DBUS_SESSION_BUS_ADDRESS"] = address

os.execv(binary, args)
