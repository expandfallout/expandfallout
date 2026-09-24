import io, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from classes import CLASSES, describe
from factions import FACTIONS

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))
OUT = ROOT + "/gamemodes/falloutrp/schema/classes"
RACES = ROOT + "/gamemodes/falloutrp/schema/races"

RANKS = {1: "enlisted / member",
         2: "NCO / manager",
         3: "officer / senior",
         4: "lead"}

# ------------------------------------------------------------- sanity checks --
#
# Every one of these is a failure the server reports either badly or not at
# all, so they are caught here instead:
#
#   - a class naming a faction that does not exist is `Class 'x' does not have
#     a valid faction!` at load, which is at least loud
#   - two classes sharing a uniqueID is silent; `LoadFromDir` skips the second
#   - two defaults in one faction is silent and picks by load order
#   - a class naming a race its faction does not allow can never be taken by
#     anybody, and nothing anywhere says so

byid = {f[0]: f for f in FACTIONS}
known_races = ({f[3:-4] for f in os.listdir(RACES)}
               if os.path.isdir(RACES) else set())

seen, defaults, problems = set(), {}, []

for faction, cid, name, rank, races, flags in CLASSES:
    if faction not in byid:
        problems.append("class '%s' names faction '%s', which does not exist"
                        % (cid, faction))
        continue

    if cid in seen:
        problems.append("duplicate class id: %s" % cid)

    seen.add(cid)

    if rank not in RANKS:
        problems.append("class '%s' has rank %r, expected 1-4" % (cid, rank))

    if "default" in flags:
        defaults.setdefault(faction, []).append(cid)

    # The faction's own race list, where it has one. No list means human only,
    # which is what `FACTION.races` absent means to the character creator.
    allowed = byid[faction][5] or ["human"]

    for r in (races or []):
        if known_races and r not in known_races:
            problems.append("class '%s' names race '%s', which does not exist"
                            % (cid, r))
        elif r not in allowed:
            problems.append("class '%s' names race '%s', which faction '%s' "
                            "does not allow - nobody could ever take it"
                            % (cid, r, faction))

for f in FACTIONS:
    got = defaults.get(f[0], [])

    if len(got) == 0:
        problems.append("faction '%s' has no default class - a character "
                        "joining it gets none at all" % f[0])
    elif len(got) > 1:
        problems.append("faction '%s' has %d default classes (%s) - Helix "
                        "picks whichever loads first"
                        % (f[0], len(got), ", ".join(got)))

if problems:
    print("REFUSING TO WRITE - %d problem(s):" % len(problems))

    for p in problems:
        print("   " + p)

    raise SystemExit(1)

# ----------------------------------------------------------------- write ------
os.makedirs(OUT, exist_ok=True)

wanted = set()
written = 0

for faction, cid, name, rank, races, flags in CLASSES:
    fac = byid[faction]
    L = []

    L.append("--[[")
    L.append("\t%s." % name)
    L.append("")
    L.append("\tGENERATED FILE. The roster is `_docs/tools/classes.py`; edit")
    L.append("\tit there and run `_docs/tools/genclasses.py`.")
    L.append("]]")
    L.append("")
    L.append('CLASS.name = "%s"' % name)
    L.append('CLASS.description = "%s"'
             % describe(fac[2], cid, rank).replace('"', "'"))
    L.append("CLASS.faction = FACTION_%s" % fac[1])
    L.append("CLASS.isDefault = %s"
             % ("true" if "default" in flags else "false"))
    L.append("")
    L.append("--[[")
    L.append("\tThe rung. 1 enlisted, 2 NCO, 3 officer, 4 lead.")
    L.append("")
    L.append("\tPhoenix carry this as four booleans set on about half their")
    L.append("\tclasses; one ordered number says the same thing and can be")
    L.append("\tcompared, which is what `sh_classrank.lua` needs to gate the")
    L.append("\ttop of a ladder behind a grant.")
    L.append("]]")
    L.append("CLASS.rank = %d" % rank)

    if "unique" in flags:
        L.append("")
        L.append("--- One at a time. There is only one of these in the world.")
        L.append("CLASS.limit = 1")

    if races:
        L.append("")
        L.append("--[[")
        L.append("\tRace-locked. This is not a rank somebody is promoted into,")
        L.append("\tit is a different creature, so a character of any other")
        L.append("\trace is refused by `sh_classrank.lua`.")
        L.append("]]")
        L.append("CLASS.races = {")

        for i, r in enumerate(races):
            L.append('\t"%s"%s' % (r, "," if i < len(races) - 1 else ""))

        L.append("}")

    L.append("")
    L.append("CLASS_%s = CLASS.index" % cid.upper())
    L.append("")

    path = os.path.join(OUT, "sh_" + cid + ".lua")
    wanted.add("sh_" + cid + ".lua")

    io.open(path, "w", encoding="utf-8", newline="").write("\n".join(L))
    written += 1

# Anything left from a previous run whose class has since been renamed or
# dropped. A stale file still loads, still takes a class index and still shows
# up in the class name viewer, so it is removed rather than left.
removed = []

for f in sorted(os.listdir(OUT)):
    if f.endswith(".lua") and f not in wanted:
        os.remove(os.path.join(OUT, f))
        removed.append(f)

phoenix = 25
print("wrote %d classes across %d factions" % (written, len(defaults)))
print("   %d race-locked, %d unique, %d factions Phoenix never had classes for"
      % (sum(1 for c in CLASSES if c[4]),
         sum(1 for c in CLASSES if "unique" in c[5]),
         len(defaults) - phoenix))

if removed:
    print("removed %d stale class file(s): %s"
          % (len(removed), ", ".join(removed)))
