import io, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from chems import CHEMS, ADDICTIONS

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "garrysmod"))
OUT = ROOT + "/gamemodes/falloutrp/schema/items/aid"
ADDONS = ROOT + "/addons"

# ---------------------------------------------------------------- model check
have = set()
for root, dirs, files in os.walk(ADDONS):
    key = root.replace("\\", "/")
    i = key.find("/models/")
    if i == -1:
        continue
    for f in files:
        if f.endswith(".mdl"):
            have.add((key[i + 1:] + "/" + f).lower())

missing = sorted({c[2] for c in CHEMS if c[2].lower() not in have})
if missing:
    print("MISSING MODELS:")
    for m in missing:
        print("   ", m)
    raise SystemExit(1)
print("all %d models resolve" % len({c[2] for c in CHEMS}))

# ------------------------------------------------------------ addiction check
used = {c[4]["addiction"] for c in CHEMS if c[4].get("addiction")}
unknown = sorted(used - set(ADDICTIONS))
if unknown:
    raise SystemExit("addictions with no withdrawal defined: %s" % unknown)
unused = sorted(set(ADDICTIONS) - used)
if unused:
    print("note: withdrawal defined but no chem causes it: %s" % unused)

# --------------------------------------------------------------- registration
lines = []
lines.append("--[[")
lines.append("\tWhat withdrawal from each chem does.")
lines.append("")
lines.append("\tRegistered centrally rather than on the items, because an")
lines.append("\taddiction is not owned by one item - five kinds of Mentats share")
lines.append("\tone, and Jet and Ultrajet share another. Putting the withdrawal on")
lines.append("\tthe item would mean five copies of it, and five chances for them to")
lines.append("\tdisagree about what Mentats withdrawal costs.")
lines.append("")
lines.append("\tEFFECTS ARE CUMULATIVE. Severity 3 carries the entries for 1 and 2")
lines.append("\tas well, so three identical -15 Speed steps read as -15, -30, -45 -")
lines.append("\twhich is exactly how Phoenix write Jet, as three separate -15s.")
lines.append("")
lines.append("\t`interval` is how long WITHOUT A DOSE before severity climbs a step.")
lines.append("\tTaking the chem again resets it to zero, which is the whole shape of")
lines.append("\tan addiction: free while you feed it, expensive when you cannot.")
lines.append("")
lines.append("\t`timedClear` addictions burn out on their own once you have gone a")
lines.append("\tstep past the top. The rest need Fixer or Addictol.")
lines.append("")
lines.append("\tGENERATED FILE - see `_docs/25-chems.md`.")
lines.append("]]")
lines.append("")
lines.append("if (not ix.addiction) then return end")
lines.append("")

for name in sorted(ADDICTIONS):
    d = ADDICTIONS[name]
    lines.append("ix.addiction.Register({")
    lines.append('\tname = "%s",' % name)
    lines.append('\tlabel = "%s",' % d["label"])
    lines.append("\tinterval = %d," % d["interval"])
    lines.append("\ttimedClear = %s," % ("true" if d["timed"] else "false"))
    lines.append("\teffects = {")
    for step in sorted(d["effects"]):
        entries = ", ".join('{stat = "%s", value = %d}' % (s, v)
                            for s, v in d["effects"][step])
        lines.append("\t\t[%d] = {%s}," % (step, entries))
    lines[-1] = lines[-1].rstrip(",")
    lines.append("\t},")
    if d.get("screen"):
        lines.append("\tscreen = {")
        for step in sorted(d["screen"]):
            names = ", ".join('"%s"' % e for e in d["screen"][step])
            lines.append("\t\t[%d] = {%s}," % (step, names))
        lines[-1] = lines[-1].rstrip(",")
        lines.append("\t},")
    lines.append("\tmessages = {")
    for step in sorted(d["messages"]):
        lines.append('\t\t[%d] = "%s",' % (step, d["messages"][step]))
    lines[-1] = lines[-1].rstrip(",")
    lines.append("\t}")
    lines.append("})")
    lines.append("")

path = ROOT + "/gamemodes/falloutrp/schema/libs/sh_addictionlist.lua"
io.open(path, "w", encoding="utf-8", newline="").write("\n".join(lines))
print("wrote %s (%d addictions)" % (os.path.basename(path), len(ADDICTIONS)))

# --------------------------------------------------------------------- items
os.makedirs(OUT, exist_ok=True)
for uid, name, model, desc, f in CHEMS:
    L = []
    L.append("--[[")
    L.append("\t%s." % name)
    L.append("")
    L.append("\tGENERATED FILE. The roster is `_docs/tools/chems.py`; edit it")
    L.append("\tthere and run `_docs/tools/genchems.py`.")
    L.append("]]")
    L.append("")
    L.append('ITEM.name = "%s"' % name)
    L.append('ITEM.description = "%s"' % desc.replace('"', '\\"'))
    L.append('ITEM.model = "%s"' % model)
    L.append("")
    if f.get("sound"):
        L.append('ITEM.effectSound = "%s"' % f["sound"])
    if f.get("aidID"):
        L.append('ITEM.aidID = "%s"' % f["aidID"])
    if f.get("heal"):
        L.append("ITEM.heal = %d" % f["heal"])
    if f.get("radiation"):
        L.append("ITEM.radiation = %d" % f["radiation"])
    if f.get("cures"):
        L.append("ITEM.cures = true")
    if f.get("mechanical"):
        # Usable by a race whose `canUseChems` is off - a robot takes a repair
        # kit and refuses everything else. See items/base/sh_aid.lua.
        L.append("ITEM.mechanical = true")
    if f.get("healTime"):
        L.append("ITEM.healTime = %d" % f["healTime"])
    if f.get("useEffect"):
        L.append('ITEM.useEffect = "%s"' % f["useEffect"])
    if f.get("tint"):
        r, g, b = f["tint"]
        L.append("")
        L.append("--[[")
        L.append("\tThis chem shares a model with another. The marker on its")
        L.append("\ticon is how the two are told apart in an inventory.")
        L.append("]]")
        L.append("ITEM.tint = Color(%d, %d, %d)" % (r, g, b))
    if f.get("buffs"):
        L.append("")
        L.append("ITEM.buffs = {")
        for i, (stat, value, dur) in enumerate(f["buffs"]):
            comma = "," if i < len(f["buffs"]) - 1 else ""
            L.append('\t{stat = "%s", value = %d, duration = %d}%s'
                     % (stat, value, dur, comma))
        L.append("}")
    if f.get("addiction"):
        L.append("")
        L.append('ITEM.addictionName = "%s"' % f["addiction"])
        L.append("ITEM.addictionChance = %d" % f["chance"])
    L.append("")
    io.open(os.path.join(OUT, "sh_" + uid[4:] + ".lua"), "w",
            encoding="utf-8", newline="").write("\n".join(L))

by_model = {}
for uid, name, model, desc, f in CHEMS:
    by_model.setdefault(model, []).append((uid, f.get("tint")))

# Two chems on one model must not also share a marker, or the icon
# cannot tell them apart - which is the whole reason tints exist.
for model, entries in sorted(by_model.items()):
    if len(entries) < 2:
        continue
    seen = {}
    for uid, tint in entries:
        key = tint or "none"
        if key in seen:
            raise SystemExit("%s and %s share %s and the same marker"
                             % (seen[key], uid, model.rsplit("/", 1)[-1]))
        seen[key] = uid

shared = sum(1 for e in by_model.values() if len(e) > 1)
print("wrote %d chem items to items/aid/" % len(CHEMS))
print("%d models shared by more than one chem, all distinguishable" % shared)
