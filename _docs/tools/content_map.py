"""
Regenerate _docs/09-content-map.md by scanning phoenixsourceaddons/.

Run this if addons are added, removed or updated. The `lua` column is the
safety-critical one - see _docs/02-server-setup.md for why junctioning a
Lua-bearing addon without its dependencies breaks the server.

Usage:  python content_map.py
"""

import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.abspath(os.path.join(HERE, "..", ".."))
SOURCE = os.path.abspath(os.path.join(PROJECT, "..", "phoenixsourceaddons"))
INSTALLED = os.path.join(PROJECT, "garrysmod", "addons")
OUT = os.path.join(HERE, "..", "09-content-map.md")

HEADER = """# 09 - Content addon map

The extracted workshop addons in `phoenixsourceaddons/`. This is the asset
source for everything; when a model or sound is missing this table is where to
look before searching the whole tree.

**The `lua` column is the safety-critical one.** Never junction an addon with
Lua unless its dependencies are installed too - see `02-server-setup.md`.
If you need one asset from a Lua-bearing addon, copy that asset instead.

Regenerate this table with `tools/content_map.py` if the folder changes.

| Addon | GB | lua | contains | installed |
|---|---|---|---|---|
"""


def scan():
    installed = set(os.listdir(INSTALLED)) if os.path.isdir(INSTALLED) else set()
    rows = []

    for addon in sorted(os.listdir(SOURCE)):
        root = os.path.join(SOURCE, addon)
        if not os.path.isdir(root):
            continue

        lua = 0
        size = 0
        kinds = set()

        for dirpath, _, filenames in os.walk(root):
            for fn in filenames:
                try:
                    size += os.path.getsize(os.path.join(dirpath, fn))
                except OSError:
                    pass

                if fn.endswith(".lua"):
                    lua += 1
                elif fn.endswith(".mdl"):
                    kinds.add("models")
                elif fn.endswith((".vmt", ".vtf")):
                    kinds.add("materials")
                elif fn.endswith((".wav", ".mp3", ".ogg")):
                    kinds.add("sound")
                elif fn.endswith(".bsp"):
                    kinds.add("MAP")
                elif fn.endswith(".pcf"):
                    kinds.add("particles")

        rows.append((addon, size / 1e9, lua,
                     ",".join(sorted(kinds)) or "-", addon in installed))
    return rows


def main():
    rows = scan()

    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(HEADER)
        for addon, gb, lua, kinds, inst in rows:
            f.write("| `%s` | %.2f | %s | %s | %s |\n" % (
                addon, gb, ("**%d**" % lua) if lua else "0", kinds,
                "yes" if inst else ""))

        total = sum(r[1] for r in rows)
        with_lua = sum(1 for r in rows if r[2])
        f.write("\n**Total: %.1f GB across %d addons. %d carry Lua.**\n"
                % (total, len(rows), with_lua))

    print("wrote %s: %d addons, %d with Lua"
          % (os.path.basename(OUT), len(rows), sum(1 for r in rows if r[2])))


if __name__ == "__main__":
    main()
