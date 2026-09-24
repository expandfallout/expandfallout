"""
Convert Phoenix's race definitions into this schema's.

Their races live in `schema/libs/races/<group>/sh_race_<name>.lua`, and a single
file can hold SEVERAL races - the securitron file also defines "oea". So the
unit of work is a `local RACE = {}` ... `nut.races.list[RACE.class] = RACE`
block, not a file.

WHAT IS CARRIED AND WHAT IS NOT.

Data fields are carried verbatim: the models, skins, hulls, scale, health,
resistance and so on are facts about the race and convert mechanically.

FUNCTION fields are NOT - `OnSpawn`, `OnMelee`, `OnDeath`, `OnThink` and the
rest are bodies full of `nut.` calls against systems this schema does not have.
The project rule is to exclude rather than ship anything still holding a `nut.`
call, because it fails at the moment somebody triggers it rather than at load.
They are listed in the generated header so nothing is lost silently.

`startingGear` is dropped for the same reason the human race drops it: their
lists name items that do not exist here, and a spawn hook handed an item ID
that resolves to nothing is a runtime error rather than a missing pistol.

ANIMATION TABLES ARE CARRIED, and the first version of this missed them
entirely. Each of their race files ends with its own animation set and a
registration:

    nut.anim.giantant = { useADV = true, normal = { ... } }
    nut.anim.setModelClass("models/fallout/giantant.mdl", "giantant")

That is pure data in exactly the shape `ix.anim` already uses, so it converts
with a rename. Dropping it left every non-human race falling back to Half-Life
2 player animations - a super mutant stood with its arms out and did not move
its legs, which is what prompted this.
"""

import io, os, re, sys

SRC = (os.environ.get("FALLOUT_SCRAPE_ROOT", "<scrape root>") + "/lastest_client_scrape/"
       "gamemodes/fallout/schema/libs/races")
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))
OUT = ROOT + "/gamemodes/falloutrp/schema/races"
ADDONS = ROOT + "/addons"

# Fields this schema's ix.races.Register understands, in the order they read
# best in a file.
DATA_FIELDS = [
    "name", "class", "description", "defaultFaction",
    "animationModel", "hideBody",
    "genders", "races", "defaultModels", "skins", "heads",
    "hairs", "beards", "faceSkins", "headSubMaterials", "raceBodygroups",
    "genderCanColorHair", "hairBoost", "muscles", "broadShoulders",
    "scale", "baseHealth", "resistance", "jumpBoost",
    "hasHunger", "hasRadiation", "canEquipWeapons", "canEquipArmors",
    "chemWhitelist", "chemBlacklist", "noSelectRaces", "noInjector",
    "viewOffset", "hull", "raceColor", "editorAnimation", "spawnMessage",
]

FUNCTION_FIELDS = ["OnSpawn", "OnDeath", "OnThink", "OnMelee", "OnLand",
                   "OnFootStep", "OnAnimEvent", "OnClear", "CustomKeys",
                   "overridePunch", "startingGear", "emotes", "voiceLines",
                   "painSounds", "deathSounds", "footstepSounds",
                   "foodSteps", "ragdollOverride"]




# `nut.anim.<name> = { ... }` blocks and their setModelClass calls. Taken from
# the WHOLE FILE rather than per RACE block, because the animation table sits
# after the last race in the file and is shared by every race in it.
ANIM_TABLE = re.compile(r"^nut\.anim\.(\w+)\s*=\s*\{", re.M)
ANIM_CLASS = re.compile(
    r'nut\.anim\.setModelClass\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\)')


def animations(text):
    """Return (converted table sources, [(model, class)]) for one file."""
    tables = []

    for m in ANIM_TABLE.finditer(text):
        name = m.group(1)
        i = text.index("{", m.start())
        depth, j, n = 0, i, len(text)

        while j < n:
            c = text[j]
            if c in "\"'":
                q = c
                j += 1
                while j < n:
                    if text[j] == "\\":
                        j += 2
                        continue
                    if text[j] == q:
                        break
                    j += 1
            elif c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    tables.append((name, text[i:j + 1]))
                    break
            j += 1

    classes = [(m.group(1), m.group(2)) for m in ANIM_CLASS.finditer(text)]

    return tables, classes

def installed_models():
    have = set()
    for addon in os.listdir(ADDONS):
        root = os.path.join(ADDONS, addon, "models")
        if not os.path.isdir(root):
            continue
        for dirpath, dirs, files in os.walk(root):
            for f in files:
                if f.lower().endswith(".mdl"):
                    p = os.path.join(dirpath, f).replace("\\", "/")
                    have.add(p[p.lower().rfind("/models/") + 1:].lower())
    return have


def value_at(s, i):
    """Read one Lua value starting at i, returning (text, end index)."""
    while i < len(s) and s[i] in " \t":
        i += 1
    if i >= len(s):
        return None, i
    if s[i] == "{":
        depth, j = 0, i
        while j < len(s):
            if s[j] == "{":
                depth += 1
            elif s[j] == "}":
                depth -= 1
                if depth == 0:
                    return s[i:j + 1], j + 1
            j += 1
        return None, i
    j = s.find("\n", i)
    if j == -1:
        j = len(s)
    return s[i:j].strip().rstrip(","), j


def blocks(text):
    """Split a file into its individual RACE definitions."""
    out = []
    for m in re.finditer(r"local RACE = \{\}", text):
        start = m.end()
        end = text.find("local RACE = {}", start)
        out.append(text[start:end if end != -1 else len(text)])
    return out


def convert(block):
    fields = {}
    for name in DATA_FIELDS + FUNCTION_FIELDS:
        m = re.search(r"^\s*RACE\.%s\s*=\s*" % name, block, re.M)
        if not m:
            continue
        val, _ = value_at(block, m.end())
        if val is not None:
            fields[name] = val
    return fields


def collect_animations():
    """Every `nut.anim.<class>` table in the whole race tree, by class name.

    Gathered across ALL files rather than per race, because the tables and the
    registrations that use them are not in the same file: `sh_race_deathclaw`
    defines the `deathclaw` table and `sh_race_deathclaw_alpha` registers
    against it. Carrying them per file either dropped those registrations or
    left them depending on alphabetical load order, which is luck rather than
    design.
    """
    out = {}

    for dirpath, dirs, files in os.walk(SRC):
        for f in sorted(files):
            if not f.startswith("sh_race_"):
                continue
            text = io.open(os.path.join(dirpath, f),
                           encoding="utf-8", errors="replace").read()
            for name, body in animations(text)[0]:
                out.setdefault(name, body)

    return out


def main():
    have = installed_models()
    animTables = collect_animations()
    os.makedirs(OUT, exist_ok=True)

    existing = {f[3:-4] for f in os.listdir(OUT)}
    written, skipped, unavailable = 0, [], []
    animated = 0

    for dirpath, dirs, files in os.walk(SRC):
        for f in sorted(files):
            if not f.startswith("sh_race_"):
                continue
            text = io.open(os.path.join(dirpath, f),
                           encoding="utf-8", errors="replace").read()

            for block in blocks(text):
                fields = convert(block)
                cls = fields.get("class", "").strip('"')

                if not cls or "name" not in fields:
                    continue
                if cls == "human":
                    continue          # ours is hand-written and stays

                models = sorted(set(m.lower() for m in re.findall(
                    r'"(models/[^"]+\.mdl)"', block)))
                missing = [m for m in models if m not in have]

                if models and len(missing) == len(models):
                    unavailable.append((cls, missing[0].rsplit("/", 1)[-1]))

                dropped = [k for k in FUNCTION_FIELDS if k in fields]

                L = ["--[[", "\t%s." % fields["name"].strip('"'), ""]
                L.append("\tGENERATED from Phoenix's `libs/races/%s/%s`."
                         % (os.path.basename(dirpath), f))
                L.append("\tRe-run `_docs/tools/genraces.py` rather than editing.")
                if dropped:
                    L.append("")
                    L.append("\tNOT CARRIED ACROSS - these are function fields whose bodies")
                    L.append("\tcall `nut.` APIs this schema does not have, and a function")
                    L.append("\tthat fails when somebody triggers it is worse than one that")
                    L.append("\tis absent:")
                    L.append("")
                    for k in dropped:
                        L.append("\t    %s" % k)
                if models and len(missing) == len(models):
                    L.append("")
                    L.append("\tNO MODELS INSTALLED. Every model this race names is in")
                    L.append("\t`fallout_snpcs_remastered` (workshop 2600347219), which is")
                    L.append("\tnot mounted. `ix.races.Register` filters what is missing, so")
                    L.append("\tthis loads and is simply unusable until that addon is added.")
                elif missing:
                    L.append("")
                    L.append("\t%d of %d models are not installed and are filtered at load."
                             % (len(missing), len(models)))
                L.append("]]")
                L.append("")

                for name in DATA_FIELDS:
                    if name not in fields:
                        continue
                    val = fields[name]
                    # Their tables use ';' as a separator in places. Lua
                    # allows it; ',' is what the rest of this schema uses.
                    #
                    # ORDER MATTERS, AND I HAD IT BACKWARDS. The first
                    # version stripped ';' before a newline and only
                    # then replaced the rest - and since every one of
                    # theirs IS followed by a newline, that DELETED the
                    # separator instead of converting it, producing
                    # `"caucasian" "african"` and four races that would
                    # not parse.
                    val = val.replace(";", ",")
                    # a trailing separator before the brace is legal but untidy
                    val = re.sub(r",(\s*})", r"\1", val)
                    L.append("RACE.%s = %s" % (name, val))
                L.append("")

                # The animation half. Only written into the file that
                # actually defines the table, so a set shared by several races
                # in one source file is not duplicated across their outputs.
                # THE REGISTRATION DECIDES WHICH TABLES TO CARRY, not the
                # race's name.
                #
                # The first version matched a table to a race by name, and the
                # names do not line up: `sh_race_libertyprime.lua` defines
                # `nut.anim.liberty`, `sh_race_mistergutsy.lua` defines
                # `nut.anim.gutsy`. So the SetModelClass line was written and
                # the table it named was not, and Helix threw
                # "'liberty' is not a valid animation class!" at load, which
                # aborted the whole race file.
                #
                # The `setModelClass` calls are the actual dependency: take
                # the ones naming a model this race uses, then carry exactly
                # the tables those name.
                # Registrations for models this race uses, keeping only the
                # ones whose class actually exists somewhere. A registration
                # naming a class nothing defines is what threw
                # "'liberty' is not a valid animation class!" and took the
                # whole race file down with it.
                _, classes = animations(text)

                myclasses = [(mdl, klass) for mdl, klass in classes
                             if mdl.lower() in models and klass in animTables]

                # The tables themselves go in one shared file, so no race file
                # depends on another having loaded first.
                mine = []

                if myclasses:
                    L.append("--[[")
                    L.append("\tThe animation class for this race's model.")
                    L.append("")
                    L.append("\tWithout it the race falls back to Half-Life 2 player")
                    L.append("\tanimations, which is a character standing with its arms out,")
                    L.append("\tsliding rather than walking. The SET itself is in")
                    L.append("\t`libs/sh_raceanims.lua`, which loads first - several races")
                    L.append("\tshare one, and a table defined in a sibling race file would")
                    L.append("\tmake this depend on alphabetical load order.")
                    L.append("]]")

                    for mdl, klass in myclasses:
                        L.append('ix.anim.SetModelClass("%s", "%s")' % (mdl, klass))

                    L.append("")

                io.open(os.path.join(OUT, "sh_" + cls + ".lua"), "w",
                        encoding="utf-8", newline="").write("\n".join(L))
                written += 1
                if myclasses:
                    animated += 1

    # ---------------------------------------------------- shared anim tables
    A = ["--[[",
         "\tEvery animation set the races use.",
         "",
         "\tCarried from Phoenix unchanged - `ix.anim` takes the same shape",
         "\t`nut.anim` did, so these are their tables renamed.",
         "",
         "\tIN ONE FILE, ON PURPOSE. Their sets are shared: the four deathclaws",
         "\tuse one, both centaurs use one, and the table lives in whichever race",
         "\tfile happened to define it first. Carrying them per race made every",
         "\tregistration depend on its sibling having loaded already, which is",
         "\talphabetical luck. `libs/` loads before `races/`, so putting them here",
         "\tmeans a race can register against any set without caring.",
         "",
         "\tGENERATED - re-run `_docs/tools/genraces.py`.",
         "]]",
         "",
         "ix.anim = ix.anim or {}",
         ""]

    for name in sorted(animTables):
        A.append("ix.anim.%s = %s" % (name, animTables[name]))
        A.append("")

    io.open(os.path.join(os.path.dirname(OUT), "libs", "sh_raceanims.lua"),
            "w", encoding="utf-8", newline="").write("\n".join(A))

    print("wrote %d races, %d registering an animation class"
          % (written, animated))
    print("wrote %d animation set(s) to libs/sh_raceanims.lua" % len(animTables))
    if unavailable:
        print()
        print("%d have NO installed models (need workshop 2600347219):"
              % len(unavailable))
        print("   " + ", ".join(sorted(c for c, _ in unavailable)))


if __name__ == "__main__":
    main()
