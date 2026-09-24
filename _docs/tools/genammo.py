import io, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ammo import AMMO

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))
OUT = ROOT + "/gamemodes/falloutrp/schema/items/ammo"
WEAPONS = ROOT + "/addons/falloutrp_weapons/lua/weapons"


def installed(path):
    """Is this model on disk, following the addon junctions?"""
    path = path.replace("\\", "/").lstrip("/").lower()

    for base in (ROOT, ROOT + "/addons"):
        if base == ROOT:
            if os.path.isfile(os.path.join(base, path)):
                return True
            continue

        if not os.path.isdir(base):
            continue

        for addon in os.listdir(base):
            if os.path.isfile(os.path.join(base, addon, path)):
                return True

    return False


# ------------------------------------------------------- what the guns fire --
#
# THE WEAPONS ARE THE AUTHORITY. `ITEM.ammo` has to match `SWEP.Primary.Ammo`
# exactly: rounds go into the player's pool under that name, so a typo puts
# them somewhere no weapon can reach - the item is consumed, the counter does
# not move, and nothing errors anywhere. That is unfindable from in game, so it
# is caught here.
fired = {}

if os.path.isdir(WEAPONS):
    for f in sorted(os.listdir(WEAPONS)):
        if not f.endswith(".lua"):
            continue

        text = io.open(os.path.join(WEAPONS, f), encoding="utf-8",
                       errors="replace").read()
        match = re.search(r'Primary\.Ammo\s*=\s*"([^"]*)"', text)

        if match and match.group(1).lower() not in ("none", ""):
            fired.setdefault(match.group(1), []).append(f[:-4])

problems, notes = [], []
seen = set()

for entry in AMMO:
    aid, name, ammo, rounds, price, model, w, h, desc = entry

    if aid in seen:
        problems.append("duplicate ammo id: %s" % aid)

    seen.add(aid)

    if fired and ammo not in fired:
        problems.append("'%s' names ammo type '%s', which no weapon fires"
                        % (aid, ammo))

    if not installed(model):
        problems.append("'%s' names model '%s', which is not installed"
                        % (aid, model))

    if rounds < 1:
        problems.append("'%s' is worth %d rounds" % (aid, rounds))

# The other direction: a weapon whose ammo nothing sells is a weapon that
# cannot be reloaded. Reported rather than fatal - a cut weapon is allowed to
# outlive its ammo.
have = {e[2] for e in AMMO}

for ammo in sorted(fired):
    if ammo not in have:
        notes.append("no item sells '%s', fired by %s"
                     % (ammo, ", ".join(sorted(fired[ammo])[:4])))

if problems:
    print("REFUSING TO WRITE - %d problem(s):" % len(problems))

    for p in problems:
        print("   " + p)

    raise SystemExit(1)

# ---------------------------------------------------------------------- write
os.makedirs(OUT, exist_ok=True)

wanted = set()

for aid, name, ammo, rounds, price, model, w, h, desc in AMMO:
    L = []
    L.append("--[[")
    L.append("\t%s." % name)
    L.append("")
    L.append("\tGENERATED FILE. The roster is `_docs/tools/ammo.py`; edit it")
    L.append("\tthere and run `_docs/tools/genammo.py`.")
    L.append("]]")
    L.append("")
    L.append('ITEM.name = "%s"' % name)
    L.append('ITEM.description = "%s"' % desc.replace('"', "'"))
    L.append('ITEM.model = "%s"' % model)
    L.append("")
    L.append("--[[")
    L.append("\tThe pool these go into, and it is the WEAPON's name for it -")
    L.append("\t`SWEP.Primary.Ammo`, spelled exactly. Fired by:")
    L.append("\t%s." % ", ".join(sorted(fired.get(ammo, ["nothing"]))[:6]))
    L.append("]]")
    L.append('ITEM.ammo = "%s"' % ammo)
    L.append("ITEM.rounds = %d" % rounds)
    L.append("")
    L.append("ITEM.price = %d" % price)
    L.append("")
    L.append("ITEM.width = %d" % w)
    L.append("ITEM.height = %d" % h)
    L.append("")

    io.open(os.path.join(OUT, "sh_ammo_" + aid + ".lua"), "w",
            encoding="utf-8", newline="").write("\n".join(L))
    wanted.add("sh_ammo_" + aid + ".lua")

removed = []

for f in sorted(os.listdir(OUT)):
    if f.endswith(".lua") and f not in wanted:
        os.remove(os.path.join(OUT, f))
        removed.append(f)

print("wrote %d ammo items covering %d of the %d ammo types in use"
      % (len(AMMO), len(have & set(fired)), len(fired)))

if removed:
    print("removed %d stale file(s): %s" % (len(removed), ", ".join(removed)))

for n in notes:
    print("   NOTE: " + n)
