# 15 — Decisions log

Choices that were made deliberately, with the reasoning. **Check here before
changing something that looks odd** — several of these look wrong until you
know why.

---

## Framework and sourcing

**Helix, not NutScript.** The user's call: Helix is more actively maintained
and better optimised. The scrapes are a NutScript server and are reference
only.

**We do not fork Helix.** Phoenix forked NutScript to add race and appearance
character vars. Helix's `ix.char.RegisterVar` does the same job from schema
code, so we get the result without maintaining a fork. If you find yourself
editing `gamemodes/helix/`, stop and find the schema-side seam.

**Weapon files stay byte-identical to source** where possible. Fixes go in the
base or the compat layer instead, so the arsenal stays diffable against future
scrapes. Exceptions are documented in-file (category retag, the APW's reload
events, the Wattz's scope offset, one path typo).

**Phoenix's melee base over the workshop one.** The workshop Melee Arts 2 ships
a *newer* `dangumeleebase` (516 vs 503 lines, 343 lines of divergence), but
Phoenix's 41 Fallout weapons are written against **theirs** — they added a
blocking system and removed throwing. Consequence: the workshop addon can't be
junctioned (competing base), so its content was copied instead.

---

## Server configuration

**Tickrate 16.** User's decision, reaffirmed after we found it makes weapons
fire ~33% faster than their 12-tick reference server. Not a bug; a consequence
of delays rounding up to whole ticks.

**Rates pinned to the tickrate.** `sv_min/maxcmdrate` and `updaterate` all 16.
A *minimum* of 30 on a 16-tick server is incoherent — clients would negotiate a
rate the server never delivers.

**RCON disabled** (empty password) while `sv_lan 1`. Empty is the safe default,
not an oversight.

**Hostname is ASCII.** The em dash the user originally wanted renders as
`Fallout RP` — confirmed by reading the live window title.

---

## Weapons

**Fire rates left alone.** Measured on both realms: everything fires *slower*
than configured, rounds-per-shot ≤ 1. The logic and data are byte-identical to
the live Phoenix scrape. Any change here is **tuning, not a fix** — don't
"correct" it without being asked.

**One tracer spawn site, server-side.** Spawning in both realms and relying on
the prediction filter to dedupe gave two tracers per shot, which reads as
double fire rate. The latency cost is one ping; the earlier "delay" complaint
was the `CurTime()` animation clock, not the network.

**`SWEP.Type` and `SWEP.Category` deliberately disagree.** `Type` is the
ballistic class the dismemberment plugin keys off; `Category` is browsing.
Binoculars are `Type = Sniper` but `Category = Other`. Don't "fix" it.

**Spawnmenu categories come from the originals**, not from `SWEP.Type` — the
original taxonomy groups all 50 Uniques together and splits Plasma from Energy,
which is better for browsing.

**`ls_heavy_plasma_repeater` removed.** Its model is in none of the 76 addons.
An ERROR prop in the spawnmenu is worse than absence.

**`ls_thor_projectile` left alone.** No weapon references it. Writing behaviour
for a weapon that doesn't exist is invented work.

---

## Animations

**Default lowered pose is a file-local, not a SWEP field.** `CalculateSpread`
branches on `if self.LoweredPos` to pick walk vs run speed for movement spread.
Setting the field would silently make 57 weapons less accurate on the move — a
balance change disguised as an animation fix.

**`passive → normal` in the hold-type translator**, differing from Phoenix (who
used `smg`). `passive` is what Helix's keys SWEP uses, and hands-at-sides is
the right read for a keyring.

**Raise moved from R to F.** Helix binds it to `IN_RELOAD`, colliding with
reloading and disturbing melee mid-swing. Phoenix's own binding is
unrecoverable (server-only file), so F is our choice. Driven by
`PlayerBindPress` — **not** `PlayerSwitchFlashlight`, which never fires because
Helix doesn't grant flashlight permission.

**`Schema:DoAnimationEvent` never falls through on an advanced model.** Helix's
version indexes `client.ixAnimTable` unchecked and crashes for our class.

---

## Compatibility layer

**Aliases and stubs over editing weapons.** Seven weapons call NutScript
systems; aliasing covers them and the other 169 if they hit the same paths.

**`nut.psyker` is deliberately absent.** Weapons guard on it before use, so
leaving it nil lets the guard work correctly and the feature skip cleanly. A
stub that *lied* about the system existing would be worse.

**Stubs are scaffolding.** Delete each as its real system is built.

---

## Content and provenance

**Junctions for content, copies for Lua.** Junctions reference several GB with
zero duplication and stay in sync. Anything we patch is copied instead.

**Never junction a Lua-bearing addon without its dependencies.** Learned by
junctioning a 2.5 GB SNPC pack for one 4 KB material and getting ~150 VJ Base
errors. Copy the asset instead.

**Longsword's provenance is an open release blocker.** It's *"a lightweight
weapon base by vin"*, recovered from a client-side scrape, not obtained from
its author. Fine for local development; must be settled before going public.
Recorded in the addon's README and the release checklist.

---

## Documentation

**Weighted toward *why* and *what went wrong*.** A future session can read the
code to see what exists; what it can't recover is that `LookupAttachment`
returns 0, that `CurTime()` lies at low tickrate, or that the fire rate is
already correct.

**Tools live in `_docs/tools/`, not session temp.** `luacheck.py` was
originally in a session-scoped folder and would have been lost.
