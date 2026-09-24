import io, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from materials import MATERIALS

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))
#[[
#   The folder name IS the base name. `ix.item.LoadFromDir` loads
#   `items/base/sh_material.lua` as `base_material`, then loads every file in
#   `items/<folder>/` with base `base_<folder>` - so the folder has to be
#   `material`, singular, or every item in it inherits from a base that does
#   not exist and loses its stacking, its paint and its split.
#]]
OUT = ROOT + "/gamemodes/falloutrp/schema/items/material"

_addons = None


def installed(path):
    global _addons

    p = path.replace("\\", "/").lstrip("/").lower()

    if os.path.isfile(os.path.join(ROOT, p)):
        return True

    if _addons is None:
        base = ROOT + "/addons"
        _addons = ([os.path.join(base, d) for d in os.listdir(base)]
                   if os.path.isdir(base) else [])

    for addon in _addons:
        if os.path.isfile(os.path.join(addon, p)):
            return True

    return False


# ------------------------------------------------------- sanity checks ------
#
# Each of these is a failure that is silent or nearly so in game:
#
#   - a duplicate id means the second file silently replaces the first
#   - an id that ALSO exists as an item somewhere else under `items/` is the
#     same collision across two folders, and it is worse: `ix.item.Load` takes
#     the uniqueID from the filename after `sh_`, `LoadFromDir` loads folders
#     first and root files last, and `ix.item.Register` reuses the table for an
#     id it has already seen - so the two definitions MERGE, and the survivor
#     is a hybrid nobody wrote with whichever base got there first. The fusion
#     core was in this roster and hand-written at `items/sh_junk_fusioncore.lua`
#     at the same time, and the result was the hand-written item's fields
#     sitting on `base_material`
#   - a missing model draws the ERROR checkerboard and nothing says why
#   - a stack size below 1 makes an item that removes itself on being touched
#   - two non-stacking items sharing a model and no tint are indistinguishable
#     in an inventory, which is the thing the tint exists to prevent

problems, notes = [], []
seen = set()
byModel = {}

for entry in MATERIALS:
    fid, name, category, model, stack, w, h, tint, desc = entry[:9]

    if fid in seen:
        problems.append("duplicate id: %s" % fid)

    seen.add(fid)

    if not installed(model):
        problems.append("'%s' names model '%s', which is not installed"
                        % (fid, model))

    if w < 1 or h < 1:
        problems.append("'%s' is %dx%d" % (fid, w, h))

    byModel.setdefault(model, []).append((fid, tint))

#  Every item defined outside this folder, by the uniqueID it will register as.
elsewhere = {}
ITEMS = ROOT + "/gamemodes/falloutrp/schema/items"

for folder, _dirs, files in os.walk(ITEMS):
    if os.path.abspath(folder) == os.path.abspath(OUT):
        continue

    #  `items/base/` is the one folder that cannot collide: those register with
    #  a `base_` prefix.
    if os.path.basename(folder) == "base":
        continue

    for f in files:
        if f.startswith("sh_") and f.endswith(".lua"):
            elsewhere[f[3:-4]] = os.path.join(folder, f)

for entry in MATERIALS:
    fid = entry[0]

    if fid in elsewhere:
        problems.append("'%s' is also defined at %s - both register as the "
                        "same item" % (fid, elsewhere[fid].replace("\\", "/")))

for model, users in sorted(byModel.items()):
    if len(users) < 2:
        continue

    untinted = [fid for fid, tint in users if not tint]

    if len(untinted) > 1:
        notes.append("%d items share %s with no tint: %s"
                     % (len(untinted), model.rsplit("/", 1)[-1],
                        ", ".join(untinted[:6])))

if problems:
    print("REFUSING TO WRITE - %d problem(s):" % len(problems))

    for p in problems:
        print("   " + p)

    raise SystemExit(1)

# --------------------------------------------------------------- write ------
os.makedirs(OUT, exist_ok=True)

wanted = set()
stacking = 0

for entry in MATERIALS:
    fid, name, category, model, stack, w, h, tint, desc = entry[:9]

    #  The tenth field is optional and only the ores have one.
    bodygroup = entry[9] if len(entry) > 9 else None

    L = []
    L.append("--[[")
    L.append("\t%s." % name)
    L.append("")
    L.append("\tGENERATED FILE. The roster is `_docs/tools/materials.py`;")
    L.append("\tedit it there and run `_docs/tools/genmaterials.py`.")
    L.append("]]")
    L.append("")
    L.append('ITEM.name = "%s"' % name)
    L.append('ITEM.description = "%s"' % desc.replace('"', "'"))
    L.append('ITEM.model = "%s"' % model)
    L.append('ITEM.category = "%s"' % category)
    L.append("")

    if stack:
        stacking += 1

        L.append("ITEM.isStackable = true")
    else:
        L.append("--[[")
        L.append("\tONE OF A KIND. Not a quantity of a substance - a specific")
        L.append("\tobject, and two of them sharing a slot would be a lie")
        L.append("\tabout what is in the room.")
        L.append("]]")
        L.append("ITEM.isStackable = false")

    if w != 1 or h != 1:
        L.append("")
        L.append("ITEM.width = %d" % w)
        L.append("ITEM.height = %d" % h)

    if tint:
        L.append("")
        L.append("--- Corner marker; this model is shared with other items.")
        L.append("ITEM.tint = Color(%s)" % tint)

    if bodygroup is not None:
        L.append("")
        L.append("--[[")
        L.append("\tWhich look this one wears. The seven ores are one model")
        L.append("\twith five bodygroups on it; `libs/sh_itembodygroup.lua`")
        L.append("\tis what applies it, because Helix supports a skin and")
        L.append("\tnothing else.")
        L.append("]]")
        L.append("ITEM.bodygroups = {[0] = %d}" % bodygroup)

    L.append("")

    io.open(os.path.join(OUT, "sh_" + fid + ".lua"), "w",
            encoding="utf-8", newline="").write("\n".join(L))

    wanted.add("sh_" + fid + ".lua")

removed = []

for f in sorted(os.listdir(OUT)):
    if f.endswith(".lua") and f not in wanted:
        os.remove(os.path.join(OUT, f))
        removed.append(f)

print("wrote %d materials, %d stackable, %d one of a kind"
      % (len(MATERIALS), stacking, len(MATERIALS) - stacking))

if removed:
    print("removed %d stale file(s): %s" % (len(removed), ", ".join(removed)))

for n in notes:
    print("   NOTE: " + n)
