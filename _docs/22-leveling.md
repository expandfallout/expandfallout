# 22 - Levelling

Ported from Phoenix's `leveling` plugin ("Leveling 2.0"). Library
`schema/libs/sh_leveling.lua`, server half `sv_leveling.lua`, popups
`cl_leveling.lua`, spending UI in `schema/derma/cl_special.lua`.

---

## The curve

Everything lives in character **data** — `level`, `XP`, `skillPoints`,
`respecs` — which is their choice and is kept: `SetData` is `isLocal` in Helix
and none of it needs to reach anyone but the owner.

```lua
level <= 50   (92 + level * 2) * (level - 1) + 200      quadratic
level >  50   requiredXP(50) + floor(1.22 ^ level)      exponential
```

Cumulative, not per-level. Steady to 50, then a wall:

| Level | Total XP | Step |
|---|---|---|
| 1 | 200 | — |
| 5 | 608 | 108 |
| 25 | 3,608 | 188 |
| 50 | 9,608 | 288 |
| **51** | **34,979** | **25,371** |
| 52 | 40,561 | 5,582 |

50 is the intended soft cap and the respec gate — the same number on purpose.

Note the step *shrinks* at 52. That is inherent to their formula, not a port
error: level 51 adds the whole `1.22^51` on top of the level-50 total, and
every level after adds only the difference from the one before.

---

## What was reconstructed

Their `sv_plugin.lua` is in no scrape, so how XP is granted, how a level-up is
detected and what a level awards are all worked out from what the other halves
assume. The client expects two net messages (an int plus a mute flag; and a
bare level-up), the shared half reads four data fields and two configs.

**Nothing in the scrape says what a level gives you.** A `skillPoints` counter
that nothing ever increments is not a system, so levels award points through
`skillPointsPerLevel` (default 1). That number is mine, not theirs.

**Levelling up is a loop, not a test.** One large award — a quest, an admin
command, the Golden Apple — can cross several thresholds at once, and a system
that only checked `>= next` would swallow every level but the first. Capped at
100 iterations so a corrupt XP value cannot spin the server.

One notification per batch: crossing three levels should feel like one good
moment, not three panels fighting for the same corner.

---

## The look

Both popups match `derma/cl_getxp.lua` and `cl_getlevel.lua` exactly — 256×64,
no background, `x = 64`, `y = ScrH()/2 - 64` (XP) and `- 100` (level up),
`UI_Medium`, palette primary, 1px expensive shadow, fade in over 2s then out
over 2s after a 4s hold, sounds through `CreateSound` at 0.6 volume.

**The XP popup accumulates rather than stacking.** A second award while one is
on screen adds to the number already showing. That is theirs, and it is what
keeps a firefight from filling the screen with little labels.

The **XP bar sits under the whole menu**, not in a tab — where Phoenix put it.
Their Paint is reproduced including the `w + 6` on the backing rect, which
overhangs the outline by six pixels on the right; it is in their code and is
what makes the bar read as sitting under the frame rather than inside it. The
label is total XP against the next level's total, as theirs is.

Sized to the window rather than their fixed 896, so it still lines up at any
size `fo_menu_width` allows.

---

## Spending and respec

The SPECIAL tab was deliberately read-only "until skill points and RESPEC
exist". They exist, so it is not any more.

A `+` box appears beside an attribute **only where a point could actually go** —
there has to be one to spend and the attribute has to have room. A button that
refuses when clicked would be the looks-interactive-but-is-not problem the tab
was avoiding.

Because the rows are *drawn* (shared with the creation screen through
`ix.fallout.DrawSpecialRow`) rather than built from child panels, clickable
areas are recorded during `Paint` and tested in `OnMousePressed`. That is the
trade for sharing the renderer.

The server re-checks everything. In particular it reads the **raw** attribute,
not `ix.special.Get` — that applies radiation and hunger modifiers, so a
starving player would appear to have room they do not have, and would lose the
point the moment they ate.

**Respec** is level 50+, first one free if configured, then
`respecCost + used * respecExtraCost` with `used` clamped at 5. It zeroes every
attribute and hands back the creation allowance plus one point per level — what
the character would have had if they had never spent anything. Shown only when
available; when it is not, the reason is drawn instead, because "you must be
level 50" is more use than a greyed-out button.

---

## Notes

- Helix has **no `HasMoney`, `TakeMoney` or `SetAttribute`**. Money is a
  registered char var with only `GetMoney`/`SetMoney`, and the attribute setter
  is `SetAttrib`. All three were wrong on the first pass here.
- Their config is spelled `Respect Cost`. The typo is theirs; the name is
  corrected here since nothing reads it by that string.
- Kill XP is players only and never for suicide.
- The **Golden Apple** now works, and grants XP rather than setting the level.
  Setting `level` directly — which is what theirs did — skips every level in
  between, and points are awarded per level *crossed*, so a player would arrive
  at 50 with nothing to spend.

`CharSetLevel` and `CharAddXP` are admin commands. `CharSetLevel` sets the XP to
match, as theirs does: setting one without the other leaves a character who
instantly re-levels or can never level again.

## The XP popup holds while XP keeps arriving

Phoenix's `cl_getxp.lua` queues its fade-out once, when the panel opens:

```lua
self:AlphaTo(255, 2)
self:AlphaTo(0, 2, 4, function() self:Remove() end)
```

`AlphaTo` with a delay is a queued animation, not a timer, so that fade fires
four seconds after the **first** award no matter what lands afterwards — a long
fight ends with the counter fading out while it is still climbing. Their
`increaseXP` updates the number and does nothing about it.

Here every award restarts the hold. `PANEL:Hold` calls `Stop` to clear the
queued animation, brings the alpha back up (an award landing mid-fade finds the
panel part-way transparent), and re-queues. Timings are still theirs: 2s in, 4s
held, 2s out — with a 0.15s recover for the second and later awards, since a
second slow fade-in on an already-visible panel reads as a flicker.

`Open` goes through `Hold` rather than queueing its own fade first: the `Stop`
would cancel the fade it had just queued.

## Where XP comes from

| Source | Config | Default |
|---|---|---|
| killing a player | `xpPerKill` | 2 |
| killing an NPC | `xpPerNPCKill` | 1 |
| opening a container nobody has looted | `xpPerContainer` | 5 |

Only the first of these existed until recently, which meant a levelling system
whose only reachable source was PvP — on a server being tested alone, XP that
never arrives looks exactly like XP that is broken.

Container XP is paid **for the find, not for the carrying** — once, the first
time anyone opens it. The first version paid per item taken, which is the wrong
shape twice over: it paid for clicking rather than for searching, and it paid
nothing at all for opening a full crate you had no room for.

Once per container, because freshness is the container's state — the second
person to reach a crate is not paid for somebody else's find. Set
`xpPerContainer` to 0 to turn it off.

`OnNPCKilled` covers engine NPCs and scripted entities on an NPC base. It does
**not** cover nextbots. If a creature pack using them is added later it needs
its own death hook rather than this one quietly not firing.

Nothing is muted. The panel plays its chime only when it **opens** —
`IncreaseXP` deliberately does not — so a burst of kills or a container emptied
item by item is one sound and a running total.

### `fo_xp_report`

"I am not getting any XP" has four possible causes — no source fired, the
multiplier is zero, the character has none, or the popup is broken — and no way
to tell them apart from in front of the screen. The command prints every source
and its value, the multiplier, the character's level and progress, and then
**grants 1 XP**, so if no `+1` appears on the left the popup is the problem and
not the maths.
