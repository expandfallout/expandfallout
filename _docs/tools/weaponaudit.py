"""
Audit every SWEP's models: missing, placeholder, or real.

`resolve_asset.py --swep` already answers "does this model exist". That is not
the same question as "is this the RIGHT model": a weapon pointing at
`models/weapons/w_pistol.mdl` resolves perfectly and is still an HL2 placeholder
standing in for a Fallout gun.

So this classifies rather than just checks:

    MISSING      the path does not resolve at all
    PLACEHOLDER  it resolves, but to stock HL2/Source content
    OK           it resolves to Fallout content

and, for anything not OK, searches the mounted content for a model whose name
looks like the weapon, so the candidates are on screen next to the problem.

Usage:
    python weaponaudit.py                     # audit + suggestions
    python weaponaudit.py --missing-only      # just the problems
    python weaponaudit.py --csv out.csv       # for bulk editing
"""

import os
import re
import sys
import csv

ROOT = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))

WEAPON_DIRS = [
    os.path.join(ROOT, "addons", "falloutrp_weapons", "lua", "weapons"),
    os.path.join(ROOT, "addons", "longsword_base", "lua", "weapons"),
]

#[[
#   What counts as a placeholder.
#
#   Stock Source content mounted by every install. A Fallout weapon pointing at
#   any of these is unfinished, however cleanly the path resolves.
#]]
PLACEHOLDER_ADDONS = {"garrysmod"}

PLACEHOLDER_PATTERNS = [
    r"^models/weapons/[vw]_(pist|rif|shot|smg|ar2|crossbow|crowbar|grenade|"
    r"physcannon|rpg|slam|stunstick|bugbait|357|annabelle)",
    r"^models/props_c17/",
    r"^models/error\.mdl$",
    r"^models/hunter/",
    r"^models/dav0r/",
    r"^models/kali/",
]


def build_index():
    """Map every mountable asset path -> the addon providing it."""
    index = {}
    roots = [("garrysmod", ROOT)]

    addons = os.path.join(ROOT, "addons")
    if os.path.isdir(addons):
        for name in sorted(os.listdir(addons)):
            path = os.path.join(addons, name)
            if os.path.isdir(path):
                roots.append((name, path))

    for label, base in roots:
        top = os.path.join(base, "models")
        if not os.path.isdir(top):
            continue
        for dirpath, _, filenames in os.walk(top):
            rel = os.path.relpath(dirpath, base).replace("\\", "/").lower()
            for fn in filenames:
                if fn.lower().endswith(".mdl"):
                    index.setdefault(rel + "/" + fn.lower(), label)
    return index


def classify(index, path):
    if not path:
        return "NONE", None

    p = path.replace("\\", "/").lower().lstrip("/")
    owner = index.get(p)

    if not owner:
        return "MISSING", None

    for pattern in PLACEHOLDER_PATTERNS:
        if re.search(pattern, p):
            return "PLACEHOLDER", owner

    if owner in PLACEHOLDER_ADDONS:
        return "PLACEHOLDER", owner

    return "OK", owner


def tokens(name):
    """Words from a weapon's file name, for matching against model names."""
    name = re.sub(r"^ls_", "", name)
    return [t for t in re.split(r"[_\s]+", name) if len(t) > 2]


def suggest(index, weapon, limit=4):
    """Models whose path contains the weapon's distinguishing words."""
    words = tokens(weapon)
    if not words:
        return []

    scored = []
    for path, owner in index.items():
        if owner in PLACEHOLDER_ADDONS:
            continue
        hits = sum(1 for w in words if w in path)
        if hits:
            # Prefer view/world models over props, and more word hits.
            bonus = 1 if re.search(r"/[vw]_|/view/|/world/", path) else 0
            scored.append((hits + bonus, path, owner))

    scored.sort(reverse=True)
    return scored[:limit]


def parse(path):
    src = open(path, encoding="utf-8", errors="replace").read()

    def find(field):
        m = re.search(r'SWEP\.%s\s*=\s*"([^"]*)"' % field, src)
        return m.group(1) if m else None

    return {
        "name": find("PrintName"),
        "base": find("Base"),
        "view": find("ViewModel"),
        "world": find("WorldModel"),
    }


def main():
    args = sys.argv[1:]
    missing_only = "--missing-only" in args
    csv_path = None
    if "--csv" in args:
        csv_path = args[args.index("--csv") + 1]

    index = build_index()
    print("indexed %d models" % len(index))

    rows = []
    for directory in WEAPON_DIRS:
        if not os.path.isdir(directory):
            continue
        for fn in sorted(os.listdir(directory)):
            if not fn.endswith(".lua"):
                continue
            weapon = fn[:-4]
            info = parse(os.path.join(directory, fn))

            vstate, vowner = classify(index, info["view"])
            wstate, wowner = classify(index, info["world"])

            rows.append({
                "weapon": weapon,
                "printname": info["name"] or "",
                "view": info["view"] or "",
                "viewstate": vstate,
                "world": info["world"] or "",
                "worldstate": wstate,
                "owner": vowner or wowner or "",
            })

    def bad(r):
        return r["viewstate"] in ("MISSING", "PLACEHOLDER") \
            or r["worldstate"] in ("MISSING", "PLACEHOLDER")

    problems = [r for r in rows if bad(r)]

    print("\n%d weapons, %d with a missing or placeholder model\n"
          % (len(rows), len(problems)))

    for r in (problems if missing_only else rows):
        if not missing_only and not bad(r):
            continue
        print("  %-30s %s" % (r["weapon"], r["printname"]))
        for kind in ("view", "world"):
            state = r[kind + "state"]
            if state != "OK":
                print("      %-6s %-11s %s" % (kind, state, r[kind] or "(unset)"))
        for score, path, owner in suggest(index, r["weapon"]):
            print("      candidate  %-58s %s" % (path, owner))
        print()

    counts = {}
    for r in rows:
        for kind in ("view", "world"):
            counts[r[kind + "state"]] = counts.get(r[kind + "state"], 0) + 1
    print("totals:", ", ".join("%s=%d" % kv for kv in sorted(counts.items())))

    if csv_path:
        with open(csv_path, "w", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(rows)
        print("wrote", csv_path)

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
