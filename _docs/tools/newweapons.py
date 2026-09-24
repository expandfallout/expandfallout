"""
Write SWEPs for weapon models that shipped with content but no weapon.

Each is generated from a DONOR - an existing weapon using a model from the same
pack and category directory - so the view/world offsets, hold type and race
overrides are the ones already known to position that pack's models correctly.
Only identity and ballistics are overridden.

Stats follow the conventions in `_docs/reference/06_weapons_data.md` and the
weapon's role in Fallout. They are a starting point, not canon: nothing in the
dumps carries numbers for these, because the weapons were never written.
"""
import os, re

W = "garrysmod/addons/falloutrp_weapons/lua/weapons"
V = "models/%s/fallout/weapons/view/%s/%s"
Wd = "models/%s/fallout/weapons/world/%s/%s"

# name: (donor, view, world, PrintName, Type, Category, ammo, dmg, clip,
#        delay, shots, cone, recoil, auto)
SPEC = {
"ls_colt357": ("ls_32_pistol",
  V % ("catmop","pistols","v_colt357.mdl"), Wd % ("catmop","pistols","w_colt357.mdl"),
  "Colt .357", "Revolver", "LS-Fallout: Pistols", "357Magnum", 34, 6, 0.3, 1, 0.03, 0.7, "false"),
"ls_flare_gun": ("ls_32_pistol",
  V % ("catmop","pistols","v_flaregun.mdl"), Wd % ("catmop","pistols","w_flaregun.mdl"),
  "Flare Gun", "Pistol", "LS-Fallout: Pistols", "20Gauge", 15, 1, 1.2, 1, 0.05, 0.4, "false"),
"ls_sonic_emitter": ("ls_32_pistol",
  V % ("catmop","pistols","v_sonicemitter.mdl"), Wd % ("catmop","pistols","w_sonicemitter.mdl"),
  "Sonic Emitter", "Energy", "LS-Fallout: Energy", "ElectronChargePack", 45, 10, 0.6, 1, 0.02, 0.3, "false"),
"ls_detonator": ("ls_32_pistol",
  V % ("catmop","pistols","detonator.mdl"), Wd % ("catmop","pistols","detonator.mdl"),
  "Detonator", "Other", "LS-Fallout: Other", "none", 0, 0, 1, 0, 0, 0, "false"),
"ls_laser_detonator": ("ls_32_pistol",
  V % ("catmop","pistols","laserdetonator.mdl"), Wd % ("catmop","pistols","laserdetonator.mdl"),
  "Laser Detonator", "Other", "LS-Fallout: Other", "none", 0, 0, 1, 0, 0, 0, "false"),
"ls_infiltrator": ("ls_ak112",
  V % ("catmop","rifle","v_infiltrator.mdl"), Wd % ("catmop","rifle","w_infiltrator.mdl"),
  "Infiltrator", "Rifle", "LS-Fallout: Rifles", "556mm", 26, 24, 0.11, 1, 0.03, 0.1, "true"),
"ls_railway_rifle": ("ls_ak112",
  V % ("catmop","rifle","v_railwayrifle.mdl"), Wd % ("catmop","rifle","railwayrifle.mdl"),
  "Railway Rifle", "Heavy", "LS-Fallout: Heavy", "5mm", 60, 8, 0.9, 1, 0.04, 0.9, "false"),
"ls_alien_atomizer": ("ls_10mm_pistol",
  V % ("roadkill","pistol","v_alien_atomizer.mdl"), Wd % ("roadkill","pistol","w_alien_atomizer.mdl"),
  "Alien Atomizer", "Energy", "LS-Fallout: Energy", "EnergyCell", 35, 20, 0.25, 1, 0.02, 0.3, "true"),
"ls_asval": ("ls_ak47",
  V % ("roadkill","rifles","v_asval.mdl"), Wd % ("roadkill","rifles","w_asval.mdl"),
  "AS VAL", "Rifle", "LS-Fallout: Rifles", "308", 32, 20, 0.11, 1, 0.03, 0.2, "true"),
"ls_caws": ("ls_riot_shotgun",
  V % ("roadkill","shotgun","v_caws.mdl"), Wd % ("roadkill","shotgun","w_caws.mdl"),
  "CAWS", "Shotgun", "LS-Fallout: Shotguns", "12Gauge", 11, 10, 0.3, 7, 0.06, 0.5, "true"),
"ls_jackhammer": ("ls_riot_shotgun",
  V % ("roadkill","shotgun","v_jackhammer.mdl"), Wd % ("roadkill","shotgun","w_jackhammer.mdl"),
  "Jackhammer", "Shotgun", "LS-Fallout: Shotguns", "12Gauge", 11, 12, 0.25, 7, 0.06, 0.5, "true"),
"ls_50_smg": ("ls_lockwood",
  "models/rhys/fallout/weapons/view/50_smg/models/50smg.mdl",
  "models/rhys/fallout/weapons/world/50_smg/models/w_50smg.mdl",
  ".50 SMG", "SMG", "LS-Fallout: SMGs", "50MG", 28, 21, 0.12, 1, 0.04, 0.6, "true"),
"ls_g11": ("ls_lockwood",
  "models/rhys/fallout/weapons/view/g11/models/g11.mdl",
  "models/rhys/fallout/weapons/world/g11/models/w_g11.mdl",
  "G11", "Rifle", "LS-Fallout: Rifles", "556mm", 24, 50, 0.08, 1, 0.03, 0.1, "true"),
"ls_smmg": ("ls_lockwood",
  "models/rhys/fallout/weapons/view/smmg/v_smmg.mdl",
  "models/rhys/fallout/weapons/world/smmg/w_smachinegun.mdl",
  "Silenced Machine Gun", "Heavy", "LS-Fallout: Heavy", "556mm", 20, 100, 0.09, 1, 0.04, 0.1, "true"),
"ls_spas": ("ls_lockwood",
  "models/rhys/fallout/weapons/view/spas/v_spas.mdl",
  "models/rhys/fallout/weapons/world/spas/spas.mdl",
  "SPAS-12", "Shotgun", "LS-Fallout: Shotguns", "12Gauge", 12, 8, 0.5, 8, 0.07, 0.8, "false"),
"ls_storm_drum": ("ls_lockwood",
  "models/rhys/fallout/weapons/view/storm/models/v_stormdrum.mdl",
  "models/rhys/fallout/weapons/world/stormdrum/models/w_stormdrum.mdl",
  "Storm Drum", "Shotgun", "LS-Fallout: Shotguns", "12Gauge", 10, 20, 0.25, 6, 0.08, 0.6, "true"),
"ls_uzi": ("ls_navy_revolver",
  "models/rhys/fallout/weapons/view/uzi/models/v_uzi.mdl",
  "models/rhys/fallout/weapons/world/uzi/models/w_uzi.mdl",
  "Uzi", "SMG", "LS-Fallout: SMGs", "9mm", 15, 32, 0.08, 1, 0.04, 0.3, "true"),
}

SIMPLE = {
  "PrintName": 3, "Type": 4, "Category": 5,
}

def setfield(src, field, value):
    pattern = r'(SWEP\.%s\s*=\s*)("(?:[^"]*)"|[^\r\n]+?)(\s*--.*)?$' % re.escape(field)
    if not re.search(pattern, src, re.M):
        return src, False
    return re.sub(pattern, lambda m: m.group(1) + value + (m.group(3) or ""),
                  src, count=1, flags=re.M), True

made, failed = [], []
for name, s in sorted(SPEC.items()):
    (donor, view, world, printname, wtype, category, ammo,
     dmg, clip, delay, shots, cone, recoil, auto) = s
    dp = os.path.join(W, donor + ".lua")
    if not os.path.exists(dp):
        failed.append((name, "donor %s missing" % donor)); continue

    src = open(dp, encoding="utf-8", errors="replace").read()
    src = ('-- Written for a model that shipped with content but no weapon.\n'
           '-- Generated from %s; see _docs/03-weapons.md.\n' % donor) + src

    for field, value in (
        ("Gun", '"%s"' % name.replace("ls_", "")),
        ("PrintName", '"%s"' % printname),
        ("Type", '"%s"' % wtype),
        ("Category", '"%s"' % category),
        ("ViewModel", '"%s"' % view),
        ("WorldModel", '"%s"' % world),
        ("Spawnable", "true"),
        ("AdminSpawnable", "true"),
        ("Primary.Ammo", '"%s"' % ammo),
        ("Primary.Damage", str(dmg)),
        ("Primary.ClipSize", str(clip)),
        ("Primary.DefaultClip", str(clip)),
        ("Primary.Delay", str(delay)),
        ("Primary.NumShots", str(shots)),
        ("Primary.Cone", str(cone)),
        ("Primary.Recoil", str(recoil)),
        ("Primary.Automatic", auto),
    ):
        src, _ = setfield(src, field, value)

    open(os.path.join(W, name + ".lua"), "w", encoding="utf-8", newline="\n").write(src)
    made.append((name, printname, donor))

print("wrote %d weapons\n" % len(made))
for n, p, d in made:
    print("  %-24s %-24s from %s" % (n, p, d))
for n, why in failed:
    print("  FAILED %s: %s" % (n, why))
