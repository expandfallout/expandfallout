import io, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from factions import FACTIONS

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))
OUT = ROOT + "/gamemodes/falloutrp/schema/factions"

ANIM = "models/phoenix/humans/animations.mdl"


# --------------------------------------------------------------- icon mapping
# The pack's own names, where they differ from our faction ids. Verified
# against the installed pack rather than guessed - this script prints any
# faction that ends up on a fallback.
ICON_ALIASES = {
    "creatures": "creature",
    "monsters": "monster",
    "outcasts": "outcast",
    "robots": "robot",
    "wastelanders": "wastelander",
    "greatkhans": "gk",
    "gunrunners": "gr",
    "zetan": "zeta",
    "childrenofatom": "cotc",
    "taloncompany": "talon",
    "cit": "institute",
    "railroad": "institute",
    "deathclaws": "creature",
    "sok": "kaga",
    "marketdistrict": "goodneighbor",
    "vangraffs": "outlaws",
    "raiders": "jackals",
    "powdergangers": "outlaws",
    "boomers": "vault_34",
    "whiteglove": "paradise",
    "omertas": "onyx",
    "chairmen": "sierra",
    "kings": "guardsman",
    "regulators": "wardens",
    "atomcats": "robco",
}

ICON_DIR = (ROOT + "/addons/phoenix_faction_icons_3520608245"
            "/materials/phoenix/faction_icons")

AVAILABLE = ({f[:-4].lower() for f in os.listdir(ICON_DIR)
              if f.lower().endswith(".png")}
             if os.path.isdir(ICON_DIR) else set())

fallbacks = []


def icon_for(fid):
    name = ICON_ALIASES.get(fid, fid)

    if not AVAILABLE or name in AVAILABLE:
        return name

    fallbacks.append(fid)

    return "default1"

# --------------------------------------------------------------- sanity checks
seen_id, seen_global = set(), set()
for fid, glob, name, colour, desc, races, flags in FACTIONS:
    if fid in seen_id:
        raise SystemExit("duplicate faction id: %s" % fid)
    if glob in seen_global:
        raise SystemExit("duplicate faction global: FACTION_%s" % glob)
    seen_id.add(fid)
    seen_global.add(glob)

defaults = [f[0] for f in FACTIONS if "default" in f[6]]
if len(defaults) != 1:
    raise SystemExit("exactly one faction must be default, got %s" % defaults)

# every race a faction names has to exist, or character creation offers a race
# that cannot be built
RACES = ROOT + "/gamemodes/falloutrp/schema/races"
known = {f[3:-4] for f in os.listdir(RACES)} if os.path.isdir(RACES) else set()
missing = {}
for fid, glob, name, colour, desc, races, flags in FACTIONS:
    for r in (races or []):
        if known and r not in known:
            missing.setdefault(r, []).append(fid)

if missing:
    print("NOTE: factions name races that do not exist yet:")
    for r, who in sorted(missing.items()):
        print("   %-22s wanted by %s" % (r, ", ".join(who)))

# ---------------------------------------------------------------------- write
os.makedirs(OUT, exist_ok=True)
written = 0

for fid, glob, name, colour, desc, races, flags in FACTIONS:
    L = []
    L.append("--[[")
    L.append("\t%s." % name)
    L.append("")
    L.append("\tGENERATED FILE. The roster is `_docs/tools/factions.py`; edit it")
    L.append("\tthere and run `_docs/tools/genfactions.py`.")
    L.append("]]")
    L.append("")
    L.append('FACTION.name = "%s"' % name)
    L.append('FACTION.description = "%s"' % desc.replace('"', "'"))
    L.append("FACTION.color = Color(%d, %d, %d)" % colour)
    L.append("FACTION.isDefault = %s"
             % ("true" if "default" in flags else "false"))
    L.append("")

    if "creature" in flags:
        L.append("--[[")
        L.append("\tNot a person. Marked so the spawn system and anything else")
        L.append("\tthat assumes a human character can tell the difference.")
        L.append("]]")
        L.append("FACTION.isCreature = true")
        L.append("")

    L.append("--[[")
    L.append("\tTHE ARRAY FORM MATTERS. Phoenix write this as a keyed table:")
    L.append("")
    L.append("\t    FACTION.models = { [\"models/...\"] = true }")
    L.append("")
    L.append("\tand Helix's `ix.faction.LoadFromDir` iterates with `pairs` and")
    L.append("\tprecaches the VALUE. Fed `true` it silently skips precaching and")
    L.append("\tcharacter creation breaks with no error at all.")
    L.append("]]")
    L.append("FACTION.models = {")
    L.append('\t"%s"' % ANIM)
    L.append("}")

    if races:
        L.append("")
        L.append("--- Which races may join. Anything unlisted is human only.")
        L.append("FACTION.races = {")
        for i, r in enumerate(races):
            L.append('\t"%s"%s' % (r, "," if i < len(races) - 1 else ""))
        L.append("}")

    L.append("")
    L.append("--[[")
    L.append("\tThe icon, from `phoenix_faction_icons`.")
    L.append("")
    L.append("\tTheir file names do not match our faction ids - the pack has")
    L.append("\t`creature`, `outcast` and `gk` where we have `creatures`,")
    L.append("\t`outcasts` and `greatkhans` - so the generator maps the ones")
    L.append("\tthat differ. A faction with nothing suitable in the pack gets")
    L.append("\tone of their numbered defaults rather than naming a material")
    L.append("\tthat does not exist, which draws as a purple checkerboard.")
    L.append("]]")
    L.append('FACTION.icon = "phoenix/faction_icons/%s.png"' % icon_for(fid))
    L.append("")
    L.append("FACTION_%s = FACTION.index" % glob)
    L.append("")

    io.open(os.path.join(OUT, "sh_" + fid + ".lua"), "w",
            encoding="utf-8", newline="").write("\n".join(L))
    written += 1

# the skeleton's leftovers, replaced by wastelanders and the real roster
for stale in ("sh_citizen.lua", "sh_police.lua"):
    p = os.path.join(OUT, stale)
    if os.path.isfile(p):
        os.remove(p)
        print("removed skeleton faction: %s" % stale)

print("wrote %d factions (%d from Phoenix, %d new)"
      % (written, 33, written - 33))

if not AVAILABLE:
    print("NOTE: no faction icon pack installed; icons are declared only")
elif fallbacks:
    print("%d faction(s) have nothing suitable and use a default: %s"
          % (len(fallbacks), ", ".join(fallbacks)))
else:
    print("every faction resolved to a real icon")
