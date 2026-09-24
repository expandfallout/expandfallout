"""
Resolve game asset paths against the server's real search path.

GMod mounts garrysmod/ plus every folder in garrysmod/addons/, so a path like
"models/ammo/missile.mdl" could live in any of them. This answers "does this
asset exist, and which addon provides it" without booting the server - which
matters here.

Usage:
    python resolve_asset.py models/ammo/missile.mdl materials/sprites/beam_laser.vmt
    python resolve_asset.py --swep addons/falloutrp_weapons/lua/weapons
    python resolve_asset.py --search missile          find candidates by name

Note the search path is CASE-INSENSITIVE here; GMod is too on Windows but not
on Linux, so mismatched case will work locally and break on a Linux host.
"""

import os
import re
import sys
import glob

ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))


def build_index():
    """Map every mountable asset path -> the addon (or 'garrysmod') providing it."""
    index = {}
    roots = [("garrysmod", ROOT)]

    addons = os.path.join(ROOT, "addons")
    if os.path.isdir(addons):
        for name in sorted(os.listdir(addons)):
            path = os.path.join(addons, name)
            if os.path.isdir(path):
                roots.append((name, path))

    for label, base in roots:
        for sub in ("models", "materials", "sound", "particles", "maps"):
            top = os.path.join(base, sub)
            if not os.path.isdir(top):
                continue
            for dirpath, _, filenames in os.walk(top):
                rel = os.path.relpath(dirpath, base).replace("\\", "/").lower()
                for fn in filenames:
                    index.setdefault(rel + "/" + fn.lower(), label)
    return index


def resolve(index, path):
    p = path.replace("\\", "/").lower().lstrip("/")
    # sound paths are often written without the "sound/" prefix
    return index.get(p) or index.get("sound/" + p)


def check_sweps(index, directory):
    """Verify ViewModel/WorldModel on every SWEP in a directory."""
    missing = 0
    total = 0
    pattern = os.path.join(directory, "**", "*.lua")

    for f in sorted(glob.glob(pattern, recursive=True)):
        src = open(f, encoding="utf-8", errors="replace").read()
        for m in re.finditer(r'SWEP\.(ViewModel|WorldModel)\s*=\s*"([^"]+)"', src):
            total += 1
            if not resolve(index, m.group(2)):
                missing += 1
                print("  MISSING %-12s %-42s %s" % (
                    m.group(1), m.group(2), os.path.basename(f)))

    print("\n%d model references, %d missing" % (total, missing))


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return

    index = build_index()
    print("indexed %d assets across the search path\n" % len(index))

    if args[0] == "--swep":
        check_sweps(index, os.path.join(ROOT, "..", args[1])
                    if not os.path.isabs(args[1]) else args[1])
        return

    if args[0] == "--search":
        needle = args[1].lower()
        hits = [(p, a) for p, a in index.items() if needle in p]
        for p, a in sorted(hits)[:40]:
            print("  %-64s %s" % (p, a))
        print("\n%d matches (showing up to 40)" % len(hits))
        return

    for path in args:
        owner = resolve(index, path)
        print("  %-58s %s" % (path, owner or "*** MISSING ***"))


if __name__ == "__main__":
    main()
