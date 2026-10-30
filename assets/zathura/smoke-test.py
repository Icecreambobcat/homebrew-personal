#!/usr/bin/env python3
"""Open and render each backend in a disposable app with its own settings and bus."""
import ast
import os
import re
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

app, fixtures, brew = map(Path, sys.argv[1:])
def run(*args):
    return subprocess.check_output([str(a) for a in args], text=True, stderr=subprocess.STDOUT, timeout=10)

with tempfile.TemporaryDirectory(prefix="zathura-smoke-", dir=os.environ.get("HOMEBREW_TEST_PATH")) as temporary:
    root = Path(temporary)
    isolated = root / "Zathura Smoke.app"
    shutil.copytree(app, isolated, symlinks=True)
    resources = isolated / "Contents/Resources"
    runtime = root / "runtime"
    launcher = resources / "launcher.py"
    launcher.write_text(launcher.read_text().replace(
        'Path("/tmp") / f"zathura-{os.getuid()}"', f"Path({str(runtime)!r})"))
    info = isolated / "Contents/Info.plist"
    data = plistlib.loads(info.read_bytes())
    data["CFBundleIdentifier"] = f"org.pwmt.zathura.smoke{os.getpid()}"
    info.write_bytes(plistlib.dumps(data))
    run("/usr/bin/codesign", "--force", "--deep", "--sign", "-", isolated)
    (root / "zathurarc").write_text("set database null\nset synctex false\n")
    # Generate DjVu and comic fixtures locally; no network or personal files.
    ppm = root / "test.ppm"
    ppm.write_bytes(b"P6\n16 16\n255\n" + bytes([200, 20, 40]) * 256)
    djvu = root / "test.djvu"
    run(brew / "opt/djvulibre/bin/c44", ppm, djvu)
    comic = root / "test.cbz"
    with zipfile.ZipFile(comic, "w") as archive:
        archive.write(fixtures / "test.png", "page.png")
    address = f"unix:path={runtime / 'bus'}"
    try:
        for document in (fixtures / "test.pdf", djvu, fixtures / "test.ps", comic):
            with tempfile.TemporaryFile(mode="w+") as log:
                process = subprocess.Popen(
                    [str(isolated / "Contents/MacOS/zathura"), "--log-level=debug",
                     "-c", str(root), "-d", str(root), "--cache-dir", str(root), str(document)],
                    stdout=log, stderr=log)
                try:
                    deadline = time.monotonic() + 20
                    while time.monotonic() < deadline:
                        log.seek(0)
                        output = log.read()
                        if process.poll() is not None:
                            raise AssertionError(f"Viewer exited {process.returncode}: {output}")
                        if "Emitting signal for page" in output:
                            filename = run(brew / "bin/gdbus", "call", "--address", address,
                                           "--dest", f"org.pwmt.zathura.PID-{process.pid}",
                                           "--object-path", "/org/pwmt/zathura",
                                           "--method", "org.freedesktop.DBus.Properties.Get",
                                           "org.pwmt.zathura", "filename")
                            opened = ast.literal_eval(filename[filename.index("<") + 1:filename.rindex(">")])
                            assert Path(opened).resolve() == document.resolve(), filename
                            assert "could not open document" not in output, output
                            print(f"PASS open/render {document.suffix}", flush=True)
                            break
                        time.sleep(0.1)
                    else:
                        raise AssertionError(f"No completed render for {document}\n{output}")
                finally:
                    if process.poll() is None:
                        process.terminate()
                    process.wait(timeout=5)
    finally:
        if (runtime / "bus").exists():
            daemon = run(brew / "bin/gdbus", "call", "--address", address,
                         "--dest", "org.freedesktop.DBus", "--object-path", "/org/freedesktop/DBus",
                         "--method", "org.freedesktop.DBus.GetConnectionUnixProcessID", "org.freedesktop.DBus")
            os.kill(int(re.search(r"uint32 (\d+)", daemon)[1]), 15)
        shutil.rmtree(runtime, ignore_errors=True)
