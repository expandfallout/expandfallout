"""
Write a frame and a blueprint for every weapon, and item the melee ones.

    python _docs/tools/genblueprints.py

Reads `blueprints.py`, which reads the installed weapons - nothing here is a
list to maintain. Three folders are written and pruned:

    items/weapons/    the 41 melee weapons, which were never items
    items/frame/      one frame per weapon
    items/blueprint/  one blueprint per weapon

ICONS ARE GROUPED, NOT IDENTICAL. Phoenix give every blueprint the same sheet
of paper and every component the same lump, and 518 identical icons is an
inventory you have to read one tooltip at a time. There is no per-weapon
receiver prop in any installed pack, so the icon cannot be the weapon - but it
can say what KIND of weapon: a model per weapon type, and a tint per type, and
a second tint band inside each type so a pistol frame is not indistinguishable
from every other pistol frame. That is the same answer the chems and the
materials already use for shared models.
"""
import io
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from blueprints import roster, recipe          # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))
SCHEMA = ROOT + "/gamemodes/falloutrp/schema"

#[[
#   Type names that are not types.
#
#   `meleearts_blund_policebaton` is a typo in the addon's own folder name and
#   `meleearts_classic_supersledge` names an era rather than a kind. Both are
#   read straight off the folder, so both are corrected here rather than in the
#   roster - the roster reports what is installed, and this is where what is
#   installed gets tidied.
#]]
NORMALISE = {"Blund": "Blunt", "Classic": "Blunt", "Marksman": "Sniper"}

#[[
#   A model and a colour per weapon type.
#
#   Every path here was checked against disk by `resolve()` below before this
#   file was written, and the generator refuses to write if any of them stops
#   existing. The two-wastelands paper models are deliberately absent: that
#   pack nests its content at `models/models/...` and the path the game wants
#   is not the one the file tree reads like. See `sh_bench.lua`.
#]]
J = "models/mosi/fallout4/props/junk/"
MODKIT = "models/roadkill/fallout/clutter/junk/modkit_%s.mdl"

#[[
#   Three groups, not fifteen.
#
#   The models were named directly rather than derived: every pistol uses the
#   sheet the 5.56 pistol had, everything else that shoots uses the AK47's, and
#   everything melee uses the baseball bat's for both the blueprint and the
#   frame. Revolvers count as pistols - they are handguns, and a revolver
#   blueprint that looked like a rifle's would be the odd one out for no
#   reason anybody could name.
#
#   FRAMES ARE CHOSEN BY SIZE, not by type: a modkit is a modkit, and how big
#   it is is the only thing the icon can honestly say about it. Melee is the
#   exception, keeping the wooden component the baseball bat frame used.
#]]
PISTOLS = ("Pistol", "Revolver")
MELEE_TYPES = ("Blade", "Blunt", "Spear", "Unarmed")

BLUEPRINT_PISTOL = J + "blueprint.mdl"
BLUEPRINT_OTHER = J + "schematic.mdl"
BLUEPRINT_MELEE = J + "burntmagazine.mdl"
FRAME_MELEE = J + "components/wood.mdl"

#[[
#   The border colour per type, which is now the ONLY thing distinguishing one
#   frame or blueprint from another - the models are shared by hundreds. Drawn
#   as an edge rather than a corner swatch; see `items/base/sh_frame.lua`.
#]]
COLORS = {
    "Pistol":    (200, 170, 90),
    "Revolver":  (190, 140, 70),
    "SMG":       (170, 170, 120),
    "Rifle":     (150, 160, 190),
    "Shotgun":   (180, 120, 90),
    "Sniper":    (120, 150, 170),
    "Heavy":     (140, 140, 150),
    "Energy":    (110, 200, 200),
    "Explosive": (200, 110, 90),
    "Grenade":   (190, 130, 80),
    "Blade":     (200, 200, 210),
    "Blunt":     (170, 130, 90),
    "Spear":     (160, 150, 110),
    "Unarmed":   (180, 150, 120),
    "Other":     (160, 160, 160),
}


def frame_size(weapon, kind):
    """How much room a frame takes.

    Pistols are 1x1 and everything else is 2x1. Nothing is 3x1 any more: a
    three-square frame is a third of a row of the inventory for a component you
    carry several of, and the size was never carrying information the icon did
    not already carry better.
    """
    if kind in PISTOLS:
        return 1, 1

    return 2, 1


def frame_model(weapon, kind):
    """Which modkit sheet a frame uses.

    STILL CHOSEN BY THE WEAPON'S SIZE, not by the frame's, which is why this is
    no longer the same question as `frame_size`. The frames are all 2x1 now, so
    deriving the model from the frame's width would have made every one of them
    the medium modkit - a minigun's frame and a hunting rifle's drawn
    identically, with nothing left to tell them apart.
    """
    if kind in PISTOLS:
        return MODKIT % "sml"

    area = weapon["width"] * weapon["height"]

    return MODKIT % ("med" if area <= 4 else "lrg")


def models_for(weapon, kind):
    """Frame model, blueprint model, blueprint size."""
    if kind in MELEE_TYPES:
        return FRAME_MELEE, BLUEPRINT_MELEE, (2, 1)

    frame = frame_model(weapon, kind)

    if kind in PISTOLS:
        return frame, BLUEPRINT_PISTOL, (1, 1)

    return frame, BLUEPRINT_OTHER, (2, 1)


FRAME_DIR = SCHEMA + "/items/frame"
PRINT_DIR = SCHEMA + "/items/blueprint"
WEAPON_DIR = SCHEMA + "/items/weapons"

_addons = None


def installed(path):
    """Is this model actually on disk, in the schema or any addon?"""
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


def band(weapon, base):
    """A stable shade of the type's colour, one per weapon.

    Deterministic from the id so it never changes between runs, and kept
    NARROW - the point is to tell two pistol frames apart at a glance, not to
    lose the fact that they are both pistol frames.
    """
    h = 0

    for ch in weapon["id"]:
        h = (h * 31 + ord(ch)) % 997

    shift = (h % 5 - 2) * 18

    return tuple(max(min(c + shift, 255), 40) for c in base)


def lua(lines, path):
    io.open(path, "w", encoding="utf-8", newline="").write("\n".join(lines)
                                                           + "\n")


def header(title):
    return [
        "--[[",
        "\t%s." % title,
        "",
        "\tGENERATED FILE. The roster is read from the installed weapons by",
        "\t`_docs/tools/blueprints.py`; run `_docs/tools/genblueprints.py`.",
        "]]",
        "",
    ]


def main():
    weapons, problems = roster()

    for p in problems:
        print("   NOTE: " + p)

    # ------------------------------------------------------- sanity ------
    bad = []

    for model in (BLUEPRINT_PISTOL, BLUEPRINT_OTHER, BLUEPRINT_MELEE,
                  FRAME_MELEE, MODKIT % "lrg", MODKIT % "med",
                  MODKIT % "sml"):
        if not installed(model):
            bad.append("'%s' is not installed" % model)

    seen = set()

    for w in weapons:
        if w["id"] in seen:
            bad.append("duplicate weapon id: " + w["id"])

        seen.add(w["id"])

        if not w["model"] or not installed(w["model"]):
            bad.append("%s names model '%s', which is not installed"
                       % (w["id"], w["model"]))

    if bad:
        print("REFUSING TO WRITE - %d problem(s):" % len(bad))

        for b in bad:
            print("   " + b)

        raise SystemExit(1)

    for folder in (FRAME_DIR, PRINT_DIR, WEAPON_DIR):
        os.makedirs(folder, exist_ok=True)

    frames, sheets, melee = set(), set(), set()

    for w in weapons:
        kind = NORMALISE.get(w["type"], w["type"])
        frameModel, sheetModel, sheetSize = models_for(w, kind)
        frameW, frameH = frame_size(w, kind)
        tint = band(w, COLORS.get(kind, COLORS["Other"]))

        # ------------------------------------------------ the melee item ----
        if w["melee"]:
            L = header(w["name"])
            L.append('ITEM.name = "%s"' % w["name"])
            L.append('ITEM.description = "%s."' % w["name"])
            L.append('ITEM.model = "%s"' % w["model"])
            L.append('ITEM.category = "Weapons"')
            L.append('ITEM.class = "%s"' % w["class"])
            L.append("")
            L.append("ITEM.width = %d" % w["width"])
            L.append("ITEM.height = %d" % w["height"])
            L.append("")
            L.append('ITEM.weaponCategory = "%s"' % w["category"])

            name = "sh_" + w["id"] + ".lua"

            lua(L, os.path.join(WEAPON_DIR, name))
            melee.add(name)

        # ----------------------------------------------------- the frame ----
        L = header(w["name"] + " frame")
        L.append('ITEM.name = "%s Frame"' % w["name"])
        L.append('ITEM.description = "The frame of a %s. Useless on its '
                 'own."' % w["name"])
        L.append('ITEM.model = "%s"' % frameModel)
        L.append("")
        L.append("ITEM.width = %d" % frameW)
        L.append("ITEM.height = %d" % frameH)
        L.append("")
        L.append("--- Which weapon this builds; read by `ix.blueprint`.")
        L.append('ITEM.weapon = "%s"' % w["id"])
        L.append("")
        L.append("--- Shared model, so the BORDER says which kind this is.")
        L.append("ITEM.tint = Color(%d, %d, %d)" % tint)

        name = "sh_frame_" + w["id"] + ".lua"

        lua(L, os.path.join(FRAME_DIR, name))
        frames.add(name)

        # ------------------------------------------------- the blueprint ----
        L = header(w["name"] + " blueprint")
        L.append('ITEM.name = "%s Blueprint"' % w["name"])
        L.append('ITEM.description = "Plans for building a %s."' % w["name"])
        L.append('ITEM.model = "%s"' % sheetModel)
        L.append("")
        L.append("ITEM.width = %d" % sheetSize[0])
        L.append("ITEM.height = %d" % sheetSize[1])
        L.append("")
        L.append("--- Which weapon it teaches; read by `ix.blueprint`.")
        L.append('ITEM.weapon = "%s"' % w["id"])
        L.append("")
        L.append("ITEM.tint = Color(%d, %d, %d)" % tint)

        name = "sh_blueprint_" + w["id"] + ".lua"

        lua(L, os.path.join(PRINT_DIR, name))
        sheets.add(name)

    # ------------------------------------------------------- pruning -----
    #[[
    #   Only files this generator OWNS are removed. `items/weapons` holds 218
    #   hand-measured ranged weapons as well, and pruning everything unwanted
    #   there would delete all of them on the first run.
    #]]
    removed = 0

    for folder, wanted, owned in (
            (FRAME_DIR, frames, lambda f: f.startswith("sh_frame_")),
            (PRINT_DIR, sheets, lambda f: f.startswith("sh_blueprint_")),
            (WEAPON_DIR, melee, lambda f: f.startswith("sh_meleearts_"))):
        for f in sorted(os.listdir(folder)):
            if f.endswith(".lua") and owned(f) and f not in wanted:
                os.remove(os.path.join(folder, f))
                removed += 1

    # -------------------------------------------------- the defaults ----
    #[[
    #   The starting recipe for every weapon, written as LUA rather than
    #   derived again at runtime.
    #
    #   The derivation lives in `blueprints.recipe` and exists once. Writing it
    #   out means the server and every client read the same numbers from the
    #   same file - two implementations of the same formula in two languages is
    #   two chances for them to disagree about what a weapon costs, and the one
    #   that disagrees quietly is the client, which would offer crafts the
    #   server then refuses.
    #]]
    D = header("Default blueprint recipes")
    D.append("ix.blueprint = ix.blueprint or {}")
    D.append("")
    D.append("--- `[weapon] = {input = {{item, amount}, ...}, time, xp}`.")
    D.append("ix.blueprint.defaults = {")

    for w in sorted(weapons, key=lambda x: x["id"]):
        r = recipe(w)
        parts = ", ".join('{"%s", %d}' % (i, n) for i, n in r["input"])

        D.append('	["%s"] = {time = %d, xp = %d, input = {%s}},'
                 % (w["id"], r["time"], r["xp"], parts))

    D.append("}")

    lua(D, SCHEMA + "/libs/sh_blueprintdefaults.lua")

    print("%d weapons: %d frames, %d blueprints, %d melee items"
          % (len(weapons), len(frames), len(sheets), len(melee)))

    if removed:
        print("removed %d stale file(s)" % removed)

    counts = {}

    for w in weapons:
        kind = NORMALISE.get(w["type"], w["type"])
        counts[kind] = counts.get(kind, 0) + 1

    print("by type: " + ", ".join("%s %d" % kv
                                  for kv in sorted(counts.items())))


if __name__ == "__main__":
    main()
