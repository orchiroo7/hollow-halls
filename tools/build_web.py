"""Export the 2.5D game for the web, into docs/, ready to commit.

Use this rather than calling Godot directly, because of the last step.

GitHub Pages serves everything with `Cache-Control: max-age=600`, so for ten
minutes after a push a browser that has already been to the site will keep
running the *old* build. While debugging that is maddening: you push a fix,
reload, and watch the bug still happen.

So after exporting, this stamps the game data's URL with a hash of its own
contents - `index.pck?v=<hash>` - which changes whenever the game does, and a
changed URL is never a cache hit. The engine's own index.js and index.wasm keep
their names, which is fine: they only change when the Godot version does.

That leaves index.html itself, which Pages also caches for ten minutes. When you
want the newest build *right now*, load the page with any query string you have
not used before:

    https://orchiroo7.github.io/hollow-halls/?v=7

Fresh HTML, which then points at the fresh pack. A private tab works too.

    python tools/build_web.py            # find Godot on PATH, or $GODOT
    python tools/build_web.py --godot "C:/path/to/godot.exe"
"""

import argparse
import hashlib
import io
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "hollow_halls_25d")
OUT = os.path.join(ROOT, "docs")


def find_godot(explicit):
    for candidate in [explicit, os.environ.get("GODOT"), shutil.which("godot"),
                      shutil.which("godot.exe")]:
        if candidate and (os.path.isfile(candidate) or shutil.which(candidate)):
            return candidate
    sys.exit("Could not find Godot. Pass --godot <path>, or set the GODOT "
             "environment variable, or put it on your PATH.")


def export(godot):
    print("exporting with", godot)
    result = subprocess.run(
        [godot, "--headless", "--path", PROJECT, "--export-release", "Web"],
        cwd=PROJECT)
    if result.returncode != 0:
        sys.exit("Godot's export failed (exit %d)." % result.returncode)


def stamp():
    """Point index.html at index.pck?v=<hash of the pack>."""
    pack = os.path.join(OUT, "index.pck")
    page = os.path.join(OUT, "index.html")
    digest = hashlib.md5(open(pack, "rb").read()).hexdigest()[:10]

    html = io.open(page, encoding="utf-8").read()
    needle = '"executable":"index"'
    if needle not in html:
        sys.exit("index.html does not look like a Godot shell - did the export "
                 "format change? Not stamping it.")
    html = html.replace(needle, '"mainPack":"index.pck?v=%s",%s' % (digest, needle), 1)
    io.open(page, "w", encoding="utf-8", newline="\n").write(html)
    print("stamped the pack as index.pck?v=%s (%d KB)"
          % (digest, os.path.getsize(pack) / 1024))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--godot", help="path to the Godot editor binary")
    args = ap.parse_args()
    export(find_godot(args.godot))
    stamp()
    print("\ndocs/ is ready. To publish:")
    print("    git add -A && git commit -m \"rebuild\" && git push")


if __name__ == "__main__":
    main()
