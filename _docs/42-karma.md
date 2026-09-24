# Karma

What a character is known for, and what their faction is known for. Phoenix's
`karma` plugin — the fifty title levels, the three alignments and the eleven
faction bands are theirs, unchanged.

| | |
|---|---|
| `schema/libs/sh_karma.lua` | the titles, the bands, the arithmetic, the configs |
| `schema/libs/sv_karma.lua` | earning it, storing it, networking it |
| `schema/libs/cl_karma.lua` | the title under somebody's name |
| dev terminal → **KARMA** | what each faction hands out |
| `/fm` → members | the faction's band, and every member's title |

---

## Two numbers, both only ever going up

A character has **good** karma and **bad** karma. Nothing subtracts from
either.

| | |
|---|---|
| the **ratio** | `(good − bad) / (good + bad)`, −1 to 1 — *what you are* |
| the **total** | `good + bad` — *how much you are it*, and what the title level counts |

That is better than one score, and it is why Phoenix did it this way: somebody
who has done a great deal of both is a **notorious figure**, where a single
score would read +50 −50 = "has never done anything".

**Alignment** is the ratio: above +0.3 good, below −0.3 evil, and a wide
neutral band in between so one bad day does not make somebody a villain.
**Level** is the total against a ladder that costs `100 + 15 × (level − 1)`
per step — 100 for the first, 835 for the fiftieth, about 23,000 for all of
them. The title is `titles[level][alignment]`: a level 18 with good alignment
is a *Wasteland Savior*, and the same level leaning the other way is a
*Wasteland Destroyer*.

`ix.karma.Ratio` guards the divide. Phoenix's does not, so a character with no
karma divides zero by zero and gets a NaN — which compares false against
everything and falls through every branch of their own `getKarmaData`.

## Where it comes from

| | |
|---|---|
| **passive** | every `karmaTimer` (60s), each faction gives its members its own `passive` pair |
| **a kill** | the killer takes the **victim's faction's** `kill` pair |

So what a killing is worth is decided by *who was killed*: set the Fiends to be
worth good karma to kill and the NCR to be worth bad, and the wasteland's
opinion of each faction is a pair of numbers rather than a rule in code.

Suicide and same-faction kills pay nothing — the first is the first thing
anybody would try, and the second pays out a number meant for outsiders.

**Both pairs are per faction and both are in the dev terminal.** Phoenix keep
them in the faction file (`FACTION.karma = {kill = {1, 5}, passive = {5, 1}}`);
ours are **generated** by `genfactions.py`, so anything written into them by
hand is lost the next time that runs. They live in the save instead, seeded
once from `FACTION.karma` if a hand-written faction happens to carry it.

## The faction's own karma

Accumulated **as its members earn it, while they are in it** — not recomputed
from the current roster, which would erase everything anybody who ever left had
done for it. That is the difference between a total and a reputation.

The band is the ratio as a percentage against eleven fixed steps, from
*Wasteland Angels* at +100 down to *Wasteland Devils* at −100, and it is shown
above the roster in `/fm` in the colour of its own ratio (red through green).
Every member's title and their two numbers are on their row, which is where
"who is dragging us down" has an answer.

The roster carries karma for members who are **offline** too: an unloaded
character's karma is in the same `data` column the class is read from, so it
costs nothing to include.

## Seeing it

The title appears in four places, all gated the same way:

| | |
|---|---|
| the look-at box | title and level under their name, in the colour of their own mix |
| the tab menu | the same, after the name - and the **name itself** is hidden until you know them |
| the YOU tab | your own numbers in full, because nobody else's screen shows them to you |
| the tab menu, per faction | the faction's icon and band |

**Earning karma makes a sound and nothing else.** There was a notice in the
corner and it was wrong: a kill already fills that corner, karma is a slow
thing rather than an event, and "+1 good, +5 bad" turns a reputation into a
scoreboard. The tone rises or falls; that is the whole feedback. Passive karma
is silent regardless.

### The faction icons

Phoenix's five (`phoenix/hud/karma_*.png`) on the faction header, with the band
name and percentage beside them. The **milestones are configurable** -
`karmaIconVeryGood` (60), `karmaIconGood` (20), `karmaIconBad` (-20),
`karmaIconVeryBad` (-60), as percentages of good karma - because "how good does
a faction have to be before it looks like a saint" is a judgement about a
server rather than a fact.

**The colour slides between them.** The hue runs red to yellow to green across
the whole range, and the brightness rises with how far through its own band a
faction is: two points below the next milestone looks nearly like the next one,
and the icon then steps. The icon says what you are; the shade says how nearly
you are the next thing.

### The YOU tab

Level and experience, karma, radiation, hunger and thirst, race, height, weight
and age. Helix's own information panel lists faction, class, money and the
attribute bars, which is what a stock Helix character *has* - everything this
schema added was missing from the one screen a player opens to find out about
their own character. `CreateCharacterInfo` and `UpdateCharacterInfo` are its
own hooks for exactly that.

**Only for people you recognise**, which is `karmaNeedsRecognition` and is
Phoenix's behaviour. A reputation belongs to a *name*: reading "Wasteland
Savior" off a stranger in a gas mask is knowing something about somebody you
have never met.

Recognition is asked the way the recognition plugin asks it —
`character:DoesRecognize`, plus the `IsPlayerRecognized` hook. **Not**
`GetCharacterName`, which looks like the obvious way and is backwards: that
hook returns a name only when somebody is **not** recognised, and nil when they
are.

`/karma` prints the numbers for yourself; staff can read anybody's.
`/charsetkarma <player> <good> <bad>` sets them.

## Settings

| Config | Default | |
|---|---|---|
| `karmaEnabled` | on | off leaves every number where it is and stops handing more out — a pause, not a reset |
| `karmaTimer` | 60 | seconds between passive karma |
| `karmaNeedsRecognition` | on | only show a title for people you know |
| `karmaNotify` | on | play the rising/falling tone when karma changes. There is never a notice |
| `karmaIconVeryGood` / `Good` / `Bad` / `VeryBad` | 60 / 20 / -20 / -60 | where the scoreboard icon steps, as a percentage |

The passive tick is **one timer for everybody**, and it rebuilds itself when
the interval changes: `ix.config.Add` takes a callback in Helix but does not
pass one through for a schema config, so the tick checks the number itself.
