"""
The roster behind every frame, blueprint and melee weapon item.

Nothing here is typed out. The weapons already exist - 218 of them as items and
41 more as melee SWEPs that were never itemised - so the roster is READ from
what is installed rather than maintained beside it. A weapon added to the
schema tomorrow gets a frame and a blueprint by running the generator again,
and a weapon removed stops having them, with no list to keep in step.

Three sources:

  * `schema/items/weapons/*.lua`   name, model, class and size, already right
  * `meleearts2_fallout` SWEPs     PrintName and class for the 41 melee ones
  * the melee world models on disk  matched to those by name

The melee SWEPs point their `WorldModel` at `w_crowbar` and their `ViewModel`
at a `c_` hands model, so neither is usable as an item icon. The real world
models are in the fallout packs under `weapons/world/melee/`, and they are
matched by NAME - `meleearts_blade_fireaxe` finds `w_fireaxe.mdl`. A melee
weapon with no model found is reported and skipped rather than written with a
missing path, because a missing model is an ERROR checkerboard with nothing in
the console to say why.
"""
import io
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))
SCHEMA = ROOT + "/gamemodes/falloutrp/schema"
MELEE_LUA = ROOT + "/addons/meleearts2_fallout/lua/weapons"
RANGED_LUA = ROOT + "/addons/falloutrp_weapons/lua/weapons"


def _read(path):
    return io.open(path, encoding="utf-8", errors="replace").read()


def _field(text, key):
    m = re.search(r'%s\s*=\s*"([^"]*)"' % re.escape(key), text)
    return m.group(1) if m else None


def _number(text, key, default):
    m = re.search(r"%s\s*=\s*(\d+)" % re.escape(key), text)
    return int(m.group(1)) if m else default


# ------------------------------------------------------ the ranged 218 ------
def _types():
    """`SWEP.Type` for every ranged weapon, keyed by class.

    The weapon knows what it is - Pistol, Rifle, Energy, Heavy - and that is a
    far better grouping for icons than anything derivable from the item. It is
    read from the SWEP rather than restated, so a weapon retyped tomorrow gets
    the right icon by rerunning the generator.
    """
    out = {}

    if not os.path.isdir(RANGED_LUA):
        return out

    for f in os.listdir(RANGED_LUA):
        if not f.endswith(".lua"):
            continue

        out[f[:-4]] = _field(_read(os.path.join(RANGED_LUA, f)),
                             "SWEP.Type") or "Other"

    return out


def ranged():
    """Every weapon that is already an item."""
    out = []
    folder = SCHEMA + "/items/weapons"
    types = _types()

    for f in sorted(os.listdir(folder)):
        if not (f.startswith("sh_") and f.endswith(".lua")):
            continue

        uniqueID = f[3:-4]

        #[[
        #   The melee items in this folder are OURS - written by the generator
        #   from the SWEPs on the last run. Reading them back would make every
        #   melee weapon appear twice, once from the item and once from the
        #   SWEP, and the duplicate check would refuse to write anything at
        #   all. The SWEP is the source; this folder is an output.
        #]]
        if uniqueID.startswith("meleearts_"):
            continue

        text = _read(os.path.join(folder, f))

        out.append({
            "id": uniqueID,
            "name": _field(text, "ITEM.name") or uniqueID,
            "model": _field(text, "ITEM.model"),
            "class": _field(text, "ITEM.class"),
            "width": _number(text, "ITEM.width", 2),
            "height": _number(text, "ITEM.height", 2),
            "category": _field(text, "ITEM.weaponCategory") or "primary",
            "type": types.get(_field(text, "ITEM.class") or "", "Other"),
            "melee": False,
        })

    return out


# ------------------------------------------------------- the melee 41 ------
#[[
#   Melee SWEPs whose name does not lead to their model.
#
#   Every one of these was found by hand and each is a real mismatch rather
#   than a guess: `machetegladius` is the gladius, `policebaton` is the baton,
#   the gauntlets share one model because only one gauntlet model shipped. The
#   laser katana has no model at all in any installed pack, so it borrows the
#   Chinese officer sword - a plain sword shape is a better lie than an ERROR
#   checkerboard.
#]]
ALIASES = {
    "machetegladius": "gladius",
    "policebaton": "baton",
    "dresscane": "cane",
    "tribalspear": "knifespear",
    "laserkatana": "chineseofficer",
    "bladedgauntlet": "mantisgauntlet",
    "deathclawgauntlet": "mantisgauntlet",
    "yaoguaigauntlet": "mantisgauntlet",
    "boxinggloves": "vgloves",
    "brassknuckles": "powerfist",
    "spikedknuckles": "powerfist",
}


def _melee_models():
    """Every melee model installed, keyed by a squashed name.

    World models first and view models only as a fallback: several of the
    unarmed weapons shipped a `view/melee` gauntlet and no world model at all,
    and a gauntlet is the same geometry either way.
    """
    found = {}

    for base, _, files in os.walk(ROOT + "/addons"):
        low = base.replace("\\", "/").lower()

        if ("/weapons/world/melee" not in low
                and "/weapons/view/melee" not in low):
            continue

        world = "/weapons/world/melee" in low

        for f in files:
            if not f.lower().endswith(".mdl"):
                continue

            path = os.path.join(base, f).replace("\\", "/")
            path = "models/" + path.split("/models/", 1)[1]

            key = re.sub(r"[^a-z0-9]", "", f.lower()[:-4])

            #[[
            #   A world model always wins, whatever order the walk found
            #   things in - `setdefault` alone would let a view model claim
            #   the name first and keep it.
            #]]
            for candidate in ([key[1:], key] if key.startswith("w")
                              else [key]):
                if candidate and (world or candidate not in found):
                    if world:
                        found[candidate] = path
                    else:
                        found.setdefault(candidate, path)

    return found


def melee():
    """The melee SWEPs, matched to a world model by name."""
    if not os.path.isdir(MELEE_LUA):
        return [], ["the melee addon is not installed"]

    models = _melee_models()
    out, problems = [], []

    for folder in sorted(os.listdir(MELEE_LUA)):
        shared = os.path.join(MELEE_LUA, folder, "shared.lua")

        if not os.path.isfile(shared):
            continue

        text = _read(shared)
        name = _field(text, "SWEP.PrintName") or folder

        # meleearts_blade_fireaxe -> fireaxe
        stem = folder.split("_")[-1]
        key = re.sub(r"[^a-z0-9]", "", stem.lower())
        model = models.get(ALIASES.get(key, key)) or models.get(key)

        #[[
        #   Last resort: a model whose name CONTAINS this one. `fireaxeunique`
        #   is the fire axe; `cleaver_unique` is the cleaver. Longest match
        #   wins so `spear` does not beat `knifespear`.
        #]]
        if not model:
            hits = sorted((k for k in models if key in k or k in key),
                          key=len, reverse=True)

            if hits:
                model = models[hits[0]]

        if not model:
            problems.append("%s: no melee world model matching '%s'"
                            % (folder, stem))
            continue

        #[[
        #   Size from the weapon's own strength rating, which the melee base
        #   already grades 1-6 for exactly this - "small, medium, heavy".
        #   Guessing from the name would disagree with the weapon itself.
        #]]
        strength = _number(text, "SWEP.Strength", 3)
        width, height = (2, 2) if strength <= 2 else (
            (3, 2) if strength <= 4 else (4, 2))

        out.append({
            "id": folder,
            "name": name,
            "model": model,
            "class": folder,
            "width": width,
            "height": height,
            "category": "secondary" if strength <= 2 else "primary",
            "type": folder.split("_")[1].capitalize(),
            "melee": True,
        })

    return out, problems


# ------------------------------------------------------------ the whole -----
def roster():
    """Everything that gets a frame and a blueprint."""
    weapons = ranged()
    more, problems = melee()

    return weapons + more, problems


#[[
#   What a blueprint costs by default.
#
#   Derived from the weapon rather than written per weapon: 259 hand-written
#   recipes would be 259 chances to typo an item id, and every one of them is
#   editable in `/benchconfig` afterwards anyway. This only has to be sensible.
#
#   The frame is always one of the weapon's OWN frame - that is the whole point
#   of frames - plus materials scaled by how big the thing is.
#]]
COMMON = {
    "primary": [("mat_steel", 4), ("mat_screws", 2), ("mat_springs", 2)],
    "secondary": [("mat_steel", 2), ("mat_screws", 2)],
    "equipment": [("mat_steel", 2), ("mat_circuitry", 1)],
    "equipment2": [("mat_steel", 2), ("mat_circuitry", 1)],
}

MELEE_EXTRA = [("mat_wood", 2), ("mat_duct_tape", 1)]
ENERGY_EXTRA = [("mat_circuitry", 2), ("mat_crystal", 1)]


def recipe(weapon):
    """The default cost and time for one weapon's blueprint."""
    parts = [("frame_" + weapon["id"], 1)]
    parts += COMMON.get(weapon["category"], COMMON["primary"])

    if weapon["melee"]:
        parts += MELEE_EXTRA
    elif "energy" in weapon["id"] or "laser" in weapon["id"] \
            or "plasma" in weapon["id"]:
        parts += ENERGY_EXTRA

    area = max(weapon["width"] * weapon["height"], 1)

    return {
        "input": parts,
        "time": min(30 + area * 10, 600),
        "xp": 10 + area * 2,
    }
