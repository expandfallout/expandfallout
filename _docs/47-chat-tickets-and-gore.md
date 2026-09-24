# 47 — Admin chat, tickets, dismemberment and `/advert`

Three unrelated things asked for together. Phoenix are the reference for the
first and the third; the middle one is modelled on the admin-popup addon in
`extra files/adminpopups/` and on SAM's report queue, neither of whose code is
used.

---

## Admin chat and tickets

```
!a  /asay  @<text>       staff talking to staff
!report  !help  @<text>  a player asking for one
!tickets                 show every open one again
!ticketclose <n>         close one by number
/ticketstats             who has been answering them
```

### `@` forks on who typed it

Every admin mod in this game binds `@` to admin chat, and every player who has
run one types `@` when they want help. So it is one key with two meanings: a
staff member's `@` is admin chat, and everybody else's opens a ticket. That is
SAM's behaviour and it is what people already expect; the alternative is a
player typing `@help me` into a channel they cannot read the answers in.

Admin chat is a **chat class**, not a net message, so `CanHear` — asked once
per listener on the server — *is* the permission check. The message never
exists for anybody without `admin.chat`, rather than being sent to everybody
and hidden by the client. A hidden message is a message somebody can read.

### One ticket per player

Keyed by SteamID64, and that single fact is why the rest is short. A second
`@` from the same person is another **line** on the ticket they already have,
so a panicking player cannot bury the queue and staff read one growing card
instead of six identical ones. The cooldown is on **opening**, not on adding —
somebody with an open ticket can always say more, which is a conversation.

| | |
|---|---|
| `ticketsEnabled` | whether `/report` works at all |
| `ticketTimeout` | seconds before an unanswered one closes itself (600) |
| `ticketCooldown` | seconds between opening one and the next (30) |
| `ticketMaxLength` | longest single line (200) |
| `ticketMaxLines` | how many lines one ticket may hold (6) |

Claiming **restarts** the timeout rather than stopping it: claimed is not
answered. A claim is exclusive and first-come, because two staff walking into
the same report is the failure the whole system exists to prevent — and it dies
with the claimer, so a ticket held by somebody who disconnected goes back in
the queue instead of being locked for ever.

### The buttons run this schema's own commands

`GOTO`, `BRING`, `RETURN`, `FREEZE`, `REPLY`, `CLAIM`/`CLOSE`. The addon this
is modelled on shells out to `ulx goto`; these go through `ix.command.Send`, so
a click obeys the same rank overrides, the same immunity check and the same
audit log as typing it, and there is still exactly one place where "may I
teleport to this person" is decided.

The target is always the reporter's `STEAM_0:` id — `ix.util.FindPlayer` reads
that format directly, and a character *name* would find the wrong person the
moment two people are called Doc.

### You have to ask for the mouse

**This is a Garry's Mod constraint, not an oversight.** A panel only receives
mouse input while the cursor is visible, and the cursor is only visible for a
**popup** — which takes the mouse away from the game for as long as it exists.
A ticket card that did that would stop you playing until you closed it.

So the cards are drawn without one, and become clickable when you ask:

```
bind F7 ix_tickets        toggle the cursor on and off
bind F8 ix_ticket_claim   claim the oldest, no cursor needed
```

The cursor is released automatically when the last card goes, so claiming the
only ticket and walking away cannot leave somebody unable to turn their head.
The cards are also clickable for free whenever the cursor is already up for
something else — the inventory, the scoreboard, any menu.

The addon this came from shipped `adminpopups_claimtop` for exactly this reason
and never said why.

### Dismissing is not closing

The `x` on a card takes it off **one** screen and leaves the ticket open for
everybody else; `!tickets` brings them all back. `ix_ticket_popups 0` puts
tickets in chat instead of on screen, for a staff member who is playing rather
than moderating.

### `/ticketstats`

Four numbers per staff member, saved across map changes in
`data/helix/falloutrp/ticketstats.txt`.

| | |
|---|---|
| CLAIMED | how many they took |
| CLOSED | how many they finished |
| AVERAGE WAIT | how long the reporter waited before somebody claimed it |
| LAST CLAIM | when they last took one |

**Claimed and closed are separate on purpose.** Somebody who claims eleven and
closes two is either being pulled away constantly or is hoarding the queue, and
one number that added them together would hide both — the gap is the
interesting part, and a row where it is wide is drawn in amber.

The server stores the **total** wait rather than a running average, because
totals can be added to and averages cannot: a running average has to be
re-weighted on every claim, and one arithmetic mistake there is a statistic
nobody can ever check. It is divided once, in the window.

`/ticketstatsclear` wipes it, superadmin only — a bad month is a thing somebody
might want to make disappear, so it is its own permission and its own log line.

### Permissions

| | |
|---|---|
| `admin.chat` | see and use admin chat |
| `ticket.claim` | see, claim and close tickets |
| `ticket.stats` | see who has been answering them |

---

## Bodies

**There was no corpse to dismember, and that is why none of this was visible.**
Garry's Mod deletes the death ragdoll the moment the player respawns:
`GM:DoPlayerDeath` calls `client:CreateRagdoll()` and the engine removes that
entity on the next `Player:Spawn`. With a five-second `spawnTime` — and this
schema's spawn-point menu, which respawns you the instant you pick one — a body
was gone before anybody walked over to it. "No body appears when you kill
people" was not a fault in the dismemberment; the engine's corpse is a death
animation, not a thing in the world.

So the engine's is suppressed through `ShouldSpawnClientRagdoll` — the hook
Helix already asks — and the schema makes its **own**, which belongs to nobody,
survives the respawn, and lasts `corpseLife`.

Three bodies exist in this codebase and only one of them is any use:

| | |
|---|---|
| `client.ixRagdoll` | Helix's knockout body. `GM:PlayerDeath` **removes** it |
| `GetRagdollEntity()` | the engine's. Deleted on the next respawn |
| `ix.corpse` | ours. Nobody's, and it stays |

### The performance dial

| | |
|---|---|
| `corpseLife` | seconds a body lasts (180) |
| `corpseMax` | how many exist at once; the **oldest** goes first (24) |
| `dismemberGibLife` | the same for gibs, which are cheaper and far more numerous (30) |

A clock alone bounds nothing — thirty people dying in ninety seconds is thirty
`prop_ragdoll`s regardless of how long each was going to last — so there is a
count as well. Turn both down on a full server.

### The body used to fly, and arrive late

Helix's `CreateServerRagdoll` is written for a knockout, and got three things
wrong for a corpse: the angle was `EyeAngles()` with **pitch and roll**, so
somebody who died looking at the floor left a body standing on its face; the
velocity was the player's **in full, on every physics bone**, so a player killed
sprinting threw a corpse across the room and one killed mid-jump sailed off; and
it set no owner either way.

The corpse is built directly now — yaw only, and a third of the momentum, which
reads as a body that dropped where it was hit and still has some weight to it.
The bones are still posed from the player's own skeleton, which is the part
worth keeping: the corpse lands in the shape the person was standing in.

**And the clients are told the moment it exists.** The visible body was found by
a half-second poll, so it appeared up to half a second after the person did —
which reads as the corpse lagging behind the death. The poll stays as the
fallback for a client that was not connected, or not in the PVS, when the
message went out.

### Why a body was there and still invisible

`fo_corpse` listed two bodies, with positions, while the screen showed empty
floor. The corpses were never the problem.

**`models/phoenix/humans/animations.mdl` has no visible mesh.** Every character
in this schema wears it: it is an animation carrier, 301 New Vegas sequences
and a skeleton, and the visible person is *composed at render time* from meshes
bone-merged onto it — that is what `cl_bodyparts.lua` exists to do. A ragdoll
of a player therefore inherits the skeleton, the physics and the death pose,
and draws absolutely nothing. Helix's own death ragdoll had exactly the same
problem, which is why nobody on this server had ever seen a body.

So `BuildBody` was split: `ix.fallout.BuildParts(entity, character)` composes a
body onto **anything wearing that skeleton**, and the corpse became a client of
it. A corpse is now dressed in the same armour and wears the same face as the
living player was, because it is the same function.

Two consequences worth knowing:

- **A character that is not loaded still gets a body.** `GetBodyParts(nil)`
  answers with the default body rather than an empty list, so somebody who
  logged off leaves a plain corpse instead of an invisible one. Being slightly
  wrong about what a dead stranger was wearing beats a body nobody can find.
- **A body remembers what it has lost.** The visible mesh is built on the
  client and not necessarily at the moment of death — somebody who walks round
  the corner two minutes later builds it then, from nothing but the entity.
  Bone scaling lives on each entity, so the server keeps `ixCorpseGone`, a
  bitfield of hitgroups, and a late-built body is as ruined as it should be.
  `ix.dismember.Hide` scales the bones on the ragdoll **and every mesh merged
  onto it**, because an arm hidden only on the ragdoll is an arm still hanging
  there in full view.

### When there is still no body

```
fo_corpse          the settings, the last death, and everything lying about
fo_corpse spawn    make one of yourself where you stand, without dying
```

"No body appears" has four causes that look identical from in front of the
screen — the hook never ran, the config is off, the player had no character, or
the ragdoll failed — so `ix.corpse.last` records which of them happened to the
last person who died and `fo_corpse` reads it out. `fo_corpse spawn` runs the
whole creation path with no death, no respawn and no hook ordering involved: a
body on the floor means the ragdoll is fine and the problem is upstream.

Two failures are caught by name because neither has any other symptom:

- **`CreateServerRagdoll` returned nothing** — logged with `ErrorNoHalt`.
- **The model has no ragdoll data.** `prop_ragdoll` spawns happily for a model
  compiled without `$collisionjoints`: a valid entity with zero physics
  objects, which lands on the floor as nothing anybody notices. Half the races
  here wear models built for NPCs, so this is worth catching by name rather
  than discovering as "bodies do not appear for supermutants".

### Taking a head

**Hold E on a body for `corpseHeadTime` seconds.** That is what Phoenix's "Head
Collection Time" config was for, and it is the only way to get one — for a
faction head and for a named one alike.

**Reaching for a body keeps it.** Thirty seconds is not long, and a corpse that
vanishes halfway through three seconds of sawing fails *silently* —
`DoStaredAction` cancels on an invalid entity without saying why. Starting the
job pushes the body's clock out past the end of it.

It sounds and looks like something while it happens: a wet cut when you start,
a splat and a spray of blood when the head comes free.

**Meat comes off the head, not off an arm, and goes where the head goes.** The
first version put the flesh on the ground while the head went into the bag, on
the theory that the head is what you came for — in practice a piece of meat
lying under a corpse is a piece of meat nobody notices, and the report was that
decapitating gave no flesh at all. Human Flesh used to fall out of a
severed limb, which made it a by-product of shooting somebody in the elbow.
Taking a head is deliberate, takes three seconds, and needs you standing over
somebody — so that is the only butchery in this game, and it is where the meat
comes from. It lands on the ground rather than in your bag: the head is what you
came for, and a second item quietly appearing in an inventory is a thing people
do not notice. A timed action with
silence behind it reads as a menu rather than as work, and a head that simply
vanishes between frames reads as a rendering fault rather than as something you
did.

The head is named after what the body **was**, never who it was:

```
NCR - Trooper Head
```

A severed head that names its owner is evidence that identifies itself; one
that names a faction and a rank is a message, which is what people actually put
on a spike. The item supports both — `label` for one cut off a body, `owner`
for the named head a permanent kill drops — and `label` wins, because unmarked
is the safe reading to be wrong in.

A body says which it is when you look at it: *"Hold E to take the head"*, or
*"The head is gone."* The tooltip comes from the client `PopulateEntityInfo`
hook rather than an `ENT:` method, because a corpse has to be a plain
`prop_ragdoll` — `CreateServerRagdoll` is what copies the model, the bodygroups
and the death pose.

A permanent kill **beheads the body too**. Without that a PK yields two heads:
the named one it drops, and an unmarked one anybody could cut off the corpse
afterwards. One death, one head.

---

## Dismemberment

A killing blow to a limb has a chance of removing it from the body: the bones
are scaled to nothing so the arm is *gone* rather than limp, and gibs are
thrown out of the wound.

| | |
|---|---|
| a head | comes **off**, and is destroyed — no item drops |
| an arm or a leg | drops a piece of Human Flesh |
| a torso hit | spills organs, and nothing survives to carry |

**A headshot decapitates; it does not drop a head.** Shooting one off destroys
it, and the body is then marked so nobody can hold E on it and cut off a head
that is lying in three pieces on the floor. The head you can carry is the one
you took the trouble to walk over and take — that is the difference between a
trophy and loot.

### Why limbs never came off

Phoenix roll on the hitgroup of the **killing blow** and nothing else, which
reads well and is almost never seen: a limb does reduced damage, so a limb shot
is the *least* likely shot to be the one that kills. Whole evenings of testing
produced no limbs at all, and the reasonable conclusion was that dismemberment
was broken rather than that it was rare.

So damage to each limb is now remembered while somebody is alive
(`ScalePlayerDamage` is the one hook handed a hitgroup), and on death any limb
that took `dismemberLimbDamage` is a **candidate**. That is Fallout's own rule —
limbs are crippled by what they have taken — and it means emptying a magazine
into somebody's legs does what everybody expects. The killing blow's limb goes
to the front of the queue whatever it took; the calibre's chance still decides
each one, and a death takes at most two limbs off before it stops being a death
and starts being a joke.

### One name, two meanings — and four faults

`ixCorpse` was set to `true` on a body and to *the body* on the player who left
it. Two different facts under one name, and the guard on the corpse-damage hook
read

```lua
if (not target.ixCorpse) then return end
```

which therefore **passed on any living player who had died once before**.
Everything behind that guard then ran on somebody who was standing up: limb
damage accumulated on them, their bones were scaled away, gibs were thrown out
of them and their physics objects were frozen.

- *"parts come out of someone not dead yet"* — the gibs
- *"a player goes invisible"* — a limb scaled to nothing on a live player
- *"corpses randomly T-pose"* — frozen physics on a player entity
- *"the body gets stuck"* — the same

Four unrelated-looking faults, one bug. The player's field is `ixCorpseBody`
now, the damage hook checks `IsPlayer()` as well as the flag, and every entry
point in `sv_dismember.lua` refuses a player outright — it is cheaper to refuse
in one place than to trust every caller for ever.

**Bone manipulation survives a respawn**, so everybody the bug reached kept a
scaled-away arm for the rest of the session. `PlayerSpawn` now clears every bone
scale and unfreezes the physics object unconditionally, because "did we scale
this player" is exactly the kind of bookkeeping that was wrong to begin with.

### Nothing hangs from a frozen arm

`EnableMotion(false)` on a dismembered limb's physics object makes it **static**,
and a ragdoll with a static arm hangs off it. "The body gets stuck mid air" was
not stuck — it was hanging from a limb nobody could see.

The physics is left entirely alone now. Every bone in the limb is scaled to
nothing, so it draws at a single point wherever its root is, and the root is
held by the shoulder, which never moved. An invisible arm that still has weight
is what every gore mod in this game ships; a body hanging from one is not.

### The stretched limb is the physics, not the mesh

A "dismembered" arm drew as a long cone from the shoulder to a hand still
sitting where it had always been. Two guesses at the mesh were wrong; the cause
is underneath it.

**A ragdoll's animation bones are driven by its physics objects** — one per limb
segment — and bone manipulation is applied on top of that. Scaling the upper arm
to nothing while the forearm's physics object is still out at arm's length
leaves the mesh spanning between a collapsed shoulder and a hand that never
moved. That is the cone, exactly.

So the physics is collapsed too: every physics object belonging to the limb is
moved to the **joint**, given zero velocity and frozen. That is what actually
takes the limb out of the world — the mesh then has nothing left to stretch
towards.

**And the twist bones were the rest of it.** Legs came off cleanly while arms
stretched, every time — and only arms have them. `Bip01 LUpArmTwistBone` and
`Bip01 L ForeTwist` are children of the upper arm and forearm, and a great many
of an arm's vertices are weighted to them. Phoenix's own limb table leaves them
out, so an arm scaled away left every twist-weighted vertex exactly where it
was, and the mesh stretched between a collapsed shoulder and geometry that had
not moved. A leg has no twist bones, which is precisely why legs looked right
the whole time.

Both spellings are listed — the bone dump in Phoenix's plugin gives
`Bip01 LUpArmTwistBone` with no space and `Bip01 L ForeTwist` with one, which is
the sort of inconsistency that survives a decade of model exports. `LookupBone`
answers nil for the ones a model does not have, so listing both costs nothing.

**And then the names stopped.** With the twist bones added there were still
fragments of mesh floating where some *other* bone nobody had written down held
a handful of vertices. Every model in this schema is a different export, so the
list was never going to be finished — there is always one more helper bone.

So the limb is asked of the **skeleton** instead: the root of the limb is looked
up once, and every bone whose parent chain passes through it is collapsed with
it. That is exhaustive by construction — twist bones, fingers, helper bones,
face bones on a head, and whatever the next model happens to carry. The written
bone lists survive only to identify a hit and to place the gibs.

The same descendant set answers the physics question, so a hand's physics object
is caught by the shoulder being its ancestor rather than by anybody having typed
`Bip01 L Hand`. And it is run per entity — a body and each mesh bone-merged onto
it have their own bone indices for the same names, and a glove that was not told
is a fragment left hanging where an arm used to be.

**And one line of my own made it worse.** A skin-coloured sliver lay on the
ground beside every body, for arms and legs alike. The physics collapse gathered
each limb's physics objects *at the joint* — and `GetBonePosition` on a ragdoll
one frame old answers with **the entity's own origin** when the bones have not
been set up yet. `BonePosition` in the same file had guarded against exactly
that since the first version; this call did not. So every arm and leg was jammed
down at the corpse's feet, and the collapsed mesh drew there.

It was never needed, and neither was freezing: a frozen physics object is
static and a body hangs from it — see *Nothing hangs from a frozen arm* above.
The physics of a removed limb is left entirely alone now. What the eye sees is
settled by the bones, in *The fragment was the hand's own skeleton* below.

**And a glove has no shoulder.** What was left, once everything above was
fixed, was hands and feet — floating where the arms and legs had been. The
meshes that make up a body are separate models, and an armour piece for the
hands carries `Bip01 L Hand` and the finger bones and *nothing above them*.
Looking up `Bip01 L UpperArm` on it answers nil, so the collapse found no root
and did nothing at all to that part.

Every name in the limb's list is tried now, most proximal first, and each one
the entity actually has is collapsed along with its descendants: on a whole body
the first name catches everything and the rest are already done; on a glove the
first two are missing and the hand is where it starts. That also covers a part
whose bone hierarchy has not been set up yet, where the descendant walk finds
nothing and each named bone is scaled on its own.

**Settled by reading Phoenix's own client.** `_docs/tools/fo_phoenix_probe.lua`
is a read-only clientside probe; run next to one of their corpses with both legs
gone it printed:

```
[BODY] prop_ragdoll  models/phoenix/humans/animations.mdl
    nodraw   false     bodygroups 0:model=0/2
      MANIPULATED  Bip01 L Thigh   scale 0 0 0
      MANIPULATED  Bip01 L Calf    scale 0 0 0
      MANIPULATED  Bip01 L Foot    scale 0 0 0
      MANIPULATED  Bip01 L Toe0    scale 0 0 0
      ...and the same four on the right
      8 bone(s) manipulated in total.

[child] models/roadkill/fallout/player/female/defaultbody.mdl
    effects  EF_BONEMERGE EF_PARENT_ANIMATES EF_BONEMERGE_FASTCULL
      left leg   Bip01 L Thigh   scale 1 1 1
      0 bone(s) manipulated in total.
```

Four facts, none of which had been guessed correctly:

- **Exactly zero.** Not a thousandth — that was an invention to dodge a
  singular matrix which was never the problem.
- **Every bone of the limb**, thigh through toe, not just the root.
- **On the carrier ragdoll only.** The visible body mesh is *never touched* —
  zero manipulated bones on it. Every version of this that scaled the meshes as
  well was applying the collapse a second time in each mesh's own space, and
  that is where the shard came from.
- **The carrier is left drawn.** `nodraw false`. It has a mesh, but its
  bodygroup defaults to the blank option (`0:model=0/2`), so it draws nothing —
  which is why hiding it was unnecessary, and a `SetNoDraw` parent is a parent
  whose bones the engine has less reason to set up.

The meshes follow because they carry **`EF_PARENT_ANIMATES`**, which makes a
parent's bone *setup* — manipulations and all — drive a bone-merged child. This
schema was missing that flag entirely until recently, which is why the earliest
attempts had to touch the meshes to see anything happen at all, and why touching
them then became the artifact.

`dismemberHideLimbs` is on, and `fo_dismember_report` now prints each mesh's
effect flags, nodraw state, every manipulated bone by name with its world
position, and every physics object of the ragdoll — the same lines the Phoenix
probe prints, so the two servers compare line for line.

**Two contracts, not one.** `BuildParts(entity, character, bCorpse)`:

| | |
|---|---|
| living player | `EF_BONEMERGE`, nothing else — the contract that has never failed |
| corpse | `EF_BONEMERGE \| EF_BONEMERGE_FASTCULL \| EF_PARENT_ANIMATES`, then `Spawn()` — Phoenix's corpse parts exactly |

Living players had the corpse contract for two rounds and T-posed on every
jump. Phoenix's living parts *do* carry all three flags plus a render override,
and adding the render override here did not stop the T-pose — so something else
in this schema's animation path interacts with those flags, and until it is
found players keep the contract that works. Neither kind gets a render override:
Phoenix's corpse parts have none.

**No client-side bone manipulation at all.** A bone manipulation set on the
server is carried to every client — late joiners and PVS arrivals included — by
the `manipulate_bone` entity the engine parents to the ragdoll. Every earlier
version also re-applied it on the client, from a net message and again on every
mesh rebuild, which put a **second** `manipulate_bone` on every corpse where a
Phoenix corpse has one. Two writers to one bone table was a variable they do
not have. The net message, the client receiver and the rebuild re-apply are all
gone.

`fo_dismember_report` and the Phoenix probe now both print `RESULT` lines: every
bone whose **final** `GetBoneMatrix` scale is not one, on the carrier and on
each mesh. `GetManipulateBoneScale` says what an entity was told;
`GetBoneMatrix` says what it drew with after the merge. A mesh that was never
told anything but reads scale zero on the thigh is one the merge is collapsing;
one that reads scale one on a body whose carrier reads zero is the shard, named.

**And one missing effect flag, which Phoenix have had all along.**

`plugins/armorv2/cl_plugin.lua` is their body-part renderer, and every mesh it
merges — on a living player and on a ragdoll alike — is created like this:

```lua
mdlEnt:SetParent(client)
mdlEnt:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL,
    EF_PARENT_ANIMATES))
mdlEnt:Spawn()
```

This schema used `EF_BONEMERGE` on its own, which is **half the contract**: it
merges the *skeleton*, so the mesh follows the animation. `EF_PARENT_ANIMATES`
is what makes the parent's bone **setup** drive the child — and a bone
manipulation is part of a bone setup.

That was two of the three faults behind the artifact:

- scaling a limb's bones on the corpse **did not reach** the meshes drawn on it,
  so the arm stayed exactly where it was;
- scaling each mesh separately instead applied a **second** collapse in that
  mesh's own space, and the geometry gathered somewhere off in the air — the
  hand hanging off the end of the arm.

Six rounds went into those two symptoms as if they were separate problems. They
were one flag. The bones are scaled on the body now and on nothing else, which
is also exactly what Phoenix do: the only `ManipulateBoneScale` anywhere in
their entire client scrape is the one that makes a character fatter or thinner.

**The gibs were never the problem.** They were changed for a round on the
reasoning that a proximity scan found nothing else near a corpse — which is not
a diagnosis, it is changing what a thing looks like because it is the only thing
you can see. They are back.

Two things the scan did settle:

- **`manipulate_bone` is Garry's Mod's own.** It is the entity the engine makes
  to network an entity's bone manipulations, so one appears parented to anything
  whose bones have been scaled — the corpse, and the viewmodel of anybody
  holding a weapon. No model, no bones, and it read as a mystery child with a
  `?` for four reports running.
- **A part with no model was being built.** `ClientsideModel("")` answers with a
  perfectly valid entity that draws nothing; an empty string in the part list is
  skipped now.

Body parts *can* still be orphaned — a `ClientsideModel` parented to an entity
is unparented rather than removed when that entity goes, and draws with no bone
setup. `ix.fallout.SweepBodyParts` clears any carrying `ixBodyPart` whose parent
has gone. That was not what the fragments were, but it is a real leak and the
tracking tables cannot catch it: a leak is by definition a part nothing holds a
reference to.

Two smaller notes from getting there:

- **The whole chain is scaled, not just the root.** An earlier attempt scaled
  only the top bone, assuming Source inherits bone scale; it does not carry
  reliably through `EF_BONEMERGE`, and a partial collapse is a *guaranteed*
  stretch rather than a possible one.
- **The wound position is measured before the limb goes.** Collapsing the
  physics moves the very bones the blood and gibs are placed from.

### The fragment was the hand's own skeleton

With the flags right, the bones scaled on the carrier only, no client-side
manipulation, and the final matrices reading the same as a Phoenix corpse's, a
pale five-spiked fan still lay where each hand had been and a thin spike where
each leg had been. The screenshots had been saying what it was all along: five
spikes from one palm.

Scaling a bone to zero collapses its vertices onto the bone's **origin**, and
the origin stays where the bone was. The scale is applied per bone after the
hierarchy is built, so children do not inherit it: `Bip01 L Toe0` reads scale
zero eight units past the foot on this server and on Phoenix alike, and
`animations.phy` names fifteen solids that do not include it, so nothing but
the hierarchy put it there. A removed limb is therefore a *skeleton of points*
with every triangle that spanned two of them stretched between them. A leg is
four points nearly in a line. A hand is a wrist and fifteen finger joints
spread across the palm, with the palm still spanning them: the fan, one spike
per finger.

`ix.dismember.Gather` runs before the scaling. It reads every non-physics
bone's position in its parent's frame and sets `ManipulateBonePosition` to the
negative, so fingers sit on the wrist, toes on the ankle, and twist bones on
the shoulder and elbow. Physics bones cannot be moved that way — thigh, calf,
foot, upper arm, forearm and hand are placed by their physics objects — so
what remains is one point per physics object, three for an arm, and triangles
between points on a line have no area to draw.

**The offsets come from the model file.** The first version read them off the
ragdoll's bone matrices on the server, and for a bone with no physics object
those are the reference pose at the entity origin: the toe read 38 units from
its own foot and was moved 38 units the wrong way — the report showed
`offset 38.4 -1.1 -4.4` and a toe 43 units from the foot. What the client uses
for such a bone is its bind-pose local position, `mstudiobone_t.pos` in the
.mdl, and a position manipulation is added to it in the **parent's frame**:
that toe's bind position plus the offset written comes to 42.96 units, and it
was 42.96 units from the foot. `ix.dismember.BindPose` reads the bone table out
of the .mdl once per model — `file.Open` in the `GAME` path, bone count at 156,
table at 160, 216 bytes a bone, position at +32 — and the offset is the
negative of that position. A file that does not read as a v44–49 model answers
nil and the limb is scaled without gathering, which is what it was before.

`fo_dismember_report` prints the offsets alongside the scales now
(`MANIPULATED ... offset x y z`), so a report shows whether a body was
gathered as well as collapsed. Phoenix do nothing of the kind — their limb
table leaves the thumb and twist bones out altogether — and the corpses their
probe read were in power armour, or had lost legs only, where the collapse is
close to a line to begin with.

### A body is drawn from a recipe, not from a character

A dead gecko had pink human arms. A dead super mutant had a skin-coloured
spike out of its neck. Both were the same fault: the client drew a corpse
from `ix.char.loaded[id]`, and when the character was not there — a bot's
never is on a client, and a player's leaves with them — it fell back to the
**human default body**. The human `head.mdl` carries a `Bip01 Spine2` the
super mutant skeleton does not have; an unmatched bone on a merged mesh is
computed from the mesh's own root, which sits at the carrier's origin, so it
landed fifty-nine units from a lying corpse's pelvis and the neck stretched
to it (gotcha 27d).

The part list now lives in `libs/sh_bodyparts.lua` — `GetBodyParts`,
`GetArmorParts`, `GetHairColor` and `ix.fallout.Recipe` — so the **server**
composes it at the moment of death from the same function that dresses the
living player, and sends it with the body (`ixCorpseNew` carries the entity
index and the recipe). A client that finds a labelled ragdoll it has no
recipe for asks with `ixCorpseAsk`, twice a second at most, and draws nothing
until the answer comes. `cl_bodyparts.lua` only builds entities now:
`BuildParts(entity, character)` is `BuildRecipe(entity, Recipe(character))`.

The recipe for a corpse leaves out any part whose model **is** the carrier —
a gecko's or a securitron's `defaultModels` name the animation model itself,
and a second copy merged onto a ragdoll that already draws it flickers
against the first.

### A machine comes apart all at once

A robot is a race `ix.armor.raceKinds` calls `robot`, and its body
(`corpse.ixRobot`, `ixCorpseRobot` on the net) has no limbs to take, no head
to cut and no meat: `Apply`, `Behead` and `Headpop` refuse it, the tooltip
says *Nothing to take from a machine*, and every hit on it goes into one
total. At `dismemberGibDamage` — the same threshold that bursts a torso —
`ix.dismember.Explode` fires the base game's explosion effect, throws eight
`models/gibs/metal_gib*.mdl` and removes the body. Its blood colour is set to
`BLOOD_COLOR_MECH` so nothing else sprays meat from it either.

A **permanent kill** of one still leaves the named head: `sv_pk.lua` asks
`ix.corpse.CanBehead(corpse)` — not a robot, and a `Bip01 Head` to scale —
and where that answers no, or there is no body at all, `ix.corpse.DropHead`
puts the named head on the floor where they died. That is the one way a head
still reaches the floor at the moment of death.

### Hitboxes that say nothing

A hitgroup is a number on each hitbox from when the model was compiled, and
the creature models were compiled for NPCs: every one of a super mutant's
fifty-three hitboxes is group 0, so a bullet in its head was "generic" — no
headshot multiplier, no head damage on record, no headpop. The gecko's are
numbered 101–109, VJ Base's way of writing the standard seven.

`ix.dismember.Hitgroup(entity, hitgroup, position)` places a generic hit by
the nearest bone in `ix.dismember.boneGroups` — the bone-list twin of
`HitgroupAt`, which does the same from a corpse's physics — and folds 101–107
back onto 1–7. A hitgroup the model did name is never changed. It is read in
`ScalePlayerDamage` (limb damage), at death (`LastHitGroup` plus the recorded
damage position), in `sv_rarity.lua` (the calibre profile) and in
`sv_armor.lua`, which also applies the base game's ×2 to a head it did not
call one, because `GM:ScalePlayerDamage` will not see one to double.

Decapitating a super mutant by hand always worked — that path never asked
the hitboxes anything.

### One burst per person

Killing the same player over and over on a spawn was a gib fountain.
`dismemberCooldown` (10 s) is checked at the top of the death roll: the body
is still made, but within the cooldown nothing is thrown and nothing comes
off. Shooting a corpse is not affected — a body only has so many limbs.

**And a body only takes damage from weapons.** A ragdoll the solver cannot
settle — the securitron's, mostly, and Phoenix's has the same habit — hits the
floor hard enough to hurt itself, and a body that counted crush damage against
its own threshold blew itself up. Crush, fall, vehicle, drowning and physgun
damage are ignored outright, and what is left has to come from a player or an
NPC.

**And the body is deaf for its first second.** It appears in the same frame
and the same place the person died, and whatever is still leaving the barrel
lands on it — which was a securitron "blowing up immediately" and gibs from a
spawn-kill the cooldown had already refused. Corpse damage is ignored for one
second after `ixCorpseBorn`. A robot also has its own threshold,
`dismemberRobotDamage` (250), because a five-hundred-hit-point machine that
goes up at a torso's 120 is one the killing burst finishes.

### What a creature's body says

`ix.corpse.Label` is faction and class. Every creature and machine in the
Creatures faction starts as the default *Wasteland Creature*, which on a body
read as a label that forgot what it was; when the class is a faction's
default and the race is a creature or a machine, the race name stands in —
**Creatures - Super Mutant**. A creature put in a real faction with a real
class keeps that, because then the class is the rank.

### Shooting a body that is already dead

The first thing anybody does with a dismemberment system is empty a magazine
into a corpse, and until now that did nothing: limbs only came off in the
instant somebody died, which is both the hardest moment to aim in and the one
nobody is watching.

**A ragdoll has no hitgroups** — `LastHitGroup` is a player thing, and a shot at
a corpse gives you a position and nothing else. So the nearest physics bone is
found, translated to an animation bone, and walked *up* its parents until one of
them is a bone this library knows, which is what makes a hit on a finger count
as a hit on the arm. A damage position further out than a body is wide is
discarded rather than answered — explosions and scripted damage report the world
origin, and "nearest bone to a point two thousand units away" is a wrong answer
delivered with confidence.

The threshold and the calibre's chance are the same ones a living limb uses, and
a failed roll keeps the damage so the next burst rolls again.

### Destroying the head

A body's head can be shot off where it lies. The head is not a flesh limb —
nothing is dropped for it — so the limb path threw head damage away, which was
"you cannot destroy the head". Damage to a corpse's head is counted on its own
(`dismemberHeadDamage`, 50) and enough of it bursts the head with no roll, the
way the torso bursts. A body kept for a named trophy (`ixCorpsePK`) keeps its
head, for the same reason a permanent kill's does at death.

### Destroying the torso

A chest and a stomach have no bones to scale — there is no way to remove
somebody's chest and leave a body behind — so a shot to either was recognised,
found not to be a limb, and dropped. That was "you cannot destroy the chest".

Both torso hitgroups now share **one** counter, and `dismemberGibDamage` (120) of
it bursts the corpse: every gib the limbs and the torso between them define,
thrown at once, and the body is gone. There is nothing left to cut a head off,
which is the cost of emptying a magazine into a body you might have wanted
something from.

**No chance roll on the torso.** A limb comes off or it does not, which is a
calibre's business; a body shot to pieces is shot to pieces, and a roll here
would mean emptying two magazines into a corpse and being told nothing happened.

Recognising a torso hit needed `hitBones` — bones that belong to a limb but are
never scaled, there only so a shot that lands on one can be traced back to the
part it belongs to.

### Bodies against walls

Posing every physics object from the player's skeleton is what makes a corpse
land in the shape the person was standing in, and it is also what wedges one
into geometry when somebody dies with their back to a wall: an arm bone half a
foot inside brickwork is a penetration the solver cannot resolve, so the body
sticks, jitters, or is fired across the room.

A bone position `util.IsInWorld` refuses is left where the ragdoll put it — a
slightly wrong pose beats a body in a wall — and every physics object is woken
after placement, because one that starts asleep inside geometry stays there.

### A long fall takes both legs

No roll. Everything else here is a chance, because a bullet may or may not tear
something off; a body that hit the ground hard enough to die of it did not
*maybe* break its legs.

**The damage type is recorded in `EntityTakeDamage`, not `ScalePlayerDamage`** —
and that was the bug in the first version. `ScalePlayerDamage` is part of the
BULLET path: it exists to scale damage by where on the body it landed, so a
fall, which has no hitgroup, never fires it. The rule was reading whatever the
last bullet had been, which for somebody who walked off a cliff without being
shot first was nothing at all.

### Headpop

A fatal headshot bursts the head: gore, a splat, and the head is **gone** —
nothing survives and nothing drops. There is **no roll**: a killing blow to
the head bursts it whatever delivered it. It rolled on the calibre's chance
for a while, and "sometimes a headshot does nothing" read as a bug every
single time.

**A machete counts.** `LastHitGroup` is the bullet path's answer and keeps the
last bullet's for anything else, so a melee kill to the head of somebody shot
in the chest a minute earlier died of the chest wound. A killing blow that was
not a bullet is placed at the nearest bone to where the damage says it landed
(`sh_dismember.lua`'s `Hitgroup`), and the engine's answer is kept only where
that says nothing.

**It never happens to a permanent kill.** A PK'd body has to keep its head,
because that head is the one with a name on it and destroying it with the shot
that earned it would take the trophy away from the person who won it.

### The head is a permanent kill's whole legacy now

A PK no longer drops a head on the floor. It used to spawn "Vault Dweller's Head"
at the moment of death, which gave the trophy to the *ground* rather than to
anybody: it appeared whether or not a soul was there to see it, and could be
picked up by somebody who had nothing to do with the kill.

Now a permanent kill leaves a **body that says whose it is**, and the head has
to be cut off it like every other head — three seconds of standing over
somebody you just killed, in a place where their friends know where to look.
It is the one corpse that shows a name, on purpose: a trophy nobody can find is
not a trophy.

`corpsePKLife` (300s) keeps that body around far longer than the ordinary
thirty, because losing the reward for the rarest event on the server to a timer
while somebody runs back for a knife would be the game taking it away again.

`ix.pk.DropHead` is gone. Keeping a second way to make a head would have meant
two places deciding what a head is called.

### The chance is on the hitgroup profile

Not in the dismemberment library. A profile is already this schema's word for a
**calibre** (`sh_hitgroup.lua`), and Phoenix keep the damage multipliers and
the dismemberment chance on one table for the same reason: they are two halves
of one fact about a weapon. A .308 takes an arm off and a 10mm does not, which
is the same statement as a .308 hitting harder on a head.

```
sniper 100   revolver 100   explosive 100   rifle 80   energy 80
shotgun 50   heavy 50       melee 50        pistol 25  smg 25   default 25
```

Phoenix's numbers, with two changes worth knowing about:

- **A revolver is no longer a pistol.** Phoenix grade one at ×3 on a head and a
  certain dismemberment, next to a pistol's ×1.5 and one-in-four — the widest
  gap between any two of their calibres. Both were mapped onto `pistol` here,
  so a .44 behaved like a 10mm. Defensible while the only difference was a
  damage number; not once a hand cannon is meant to take a head off.
- **Melee has a number at all.** Phoenix have no melee calibre, so a machete
  falls through to their `Rifle` default and dismembers four times out of five,
  which is not a decision anybody made.

`dismemberScale` is a percentage over all of them: 100 is Phoenix exactly, 0 is
off, 200 doubles everything and caps at certain. One number, because what a
server owner wants to say is "less of this", not "edit ten".

### Why it never fires on a deathclaw

The bone names are the **Valve human skeleton** (`Bip01 Head`,
`Bip01 L Forearm`), and `LookupBone` answers nil on a model that does not have
them. That is the whole of the creature check: anything wearing a human
skeleton comes apart and anything else does not, with no list of races to keep
in step with `races/`. If the bones are not found, *nothing* happens — no
gibs, no meat, no sound; a deathclaw shot in what Source calls its left arm is
simply dead.

Robots are excluded separately, on **blood colour**: a synth wearing a human
skeleton loses the arm and nothing else happens.

### Telling the clients

The clients are told **separately**, by entity index. Bone manipulation set on
the server does reach clients on its own, but only once the ragdoll exists
there with its bones set up — and a corpse one tick old is exactly the case
where it does not, which shows up as an arm that is present for a second and
then gone. `net.WriteEntity` is no good for this: it is read back as
`Entity(index)` at the moment the message arrives, so a client that is too
early gets NULL and there is nothing to retry *with*. An index can be looked up
again a tenth of a second later.

### The physics gun on people — two bugs, one symptom

**`OnPhysgunFreeze` was the wrong hook.** The engine physgun only raises it for
something it considers freezable, and a player — whose movement is not
simulated by the physics object the beam is holding — is not. It never fired
once. `KeyPress` on `IN_ATTACK2` catches the gesture instead, and `PhysgunDrop`
asks `client:KeyDown(IN_ATTACK2)` as a second chance; both call one idempotent
function.

**And the drop put `MOVETYPE_WALK` back afterwards, whenever it happened.**
That was the second bug and it is why fixing the first changed nothing.
Right-clicking freezes but does *not* make the physgun let go — the engine only
drops what it managed to freeze — so the beam keeps them, the admin carries on
holding left-click, and the drop arrives **seconds later**, long after the
one-shot timer that set `MOVETYPE_NONE` has fired. `GM:PhysgunDrop` then hands
the player `MOVETYPE_WALK` and they fall out of the air, exactly as if nothing
had been frozen.

So the movetype is re-applied from the drop as well, a frame after it, for
anybody still frozen. Setting it once at freeze time was only ever right if the
drop happened first.

`FL_FROZEN` is the same flag `!freeze` sets, so `!unfreeze` releases them — and
it now routes through `ix.physgun.Release` so it restores the movetype too: a
player left unfrozen and still unable to move is worse than a frozen one,
because nothing on screen says why.

**The freeze asserts itself rather than being set once.** Two flags hold a
player in the air — `FL_FROZEN` and `MOVETYPE_NONE` — and a great many things in
this game set a movetype: the physics gun while it carries somebody,
`GM:PhysgunDrop` on the way out, a respawn, an addon nobody remembered. Each was
chased individually and each time something else turned out to do it too. Four
times a second everybody frozen is put back the way they are meant to be; the
loop is over a table that is empty almost all of the time.

**Picking somebody up again lets them go**, and the beam takes over — they stay
exactly where they were until you move them, so it reads as repositioning rather
than dropping. Right-click freezes them again wherever they now are. The beam has them, so the freeze
has nothing left to do — and leaving it on made the physics gun the one tool
that could not undo its own work: lift a frozen player, move them, drop them,
and they snapped back to frozen because they were never released. Worse,
freezing refuses somebody already frozen, so right-clicking again did nothing
at all. Now: right-click freezes them where they are, picking them up frees
them, and `r` still releases everybody at once from a distance.

`fo_physgun` reports the config, your permissions, who you are holding and
everybody currently frozen — written because the freeze failed twice for two
different reasons and both looked identical: nothing happened.

### Heads on spikes

`ix_headspike` is Phoenix's `nut_playerhead`: a head item that has been
**planted**. Deploying spends the item and the spike can be shot down, because
a warning you can put back in your bag is not a warning. Three Fort pike models
at random, so a row of them along a road is not obviously three copies of one
prop, and it does not move once planted.

The head item itself is unchanged — `items/sh_playerhead.lua` already existed
for `ix.pk`, already carries the owner's name on the instance, and already
carries `bAllowMultiCharacterInteraction` so a trophy can change hands. All
that was added is the `Plant on a Spike` action.

**Human Flesh** lives in `items/food/`, which gives it `base_food` and with it
the eating behaviour, the sustenance and the rads — so cannibalism is not a
system, it is a meal with an unusual name on it. Ten sustenance for ten rads is
a bad trade for anybody with a can of Cram and a good one for somebody two days
into the wasteland, which is exactly when a corpse starts looking like an
option. Neither is worth anything at a vendor: a price would make this a farm,
and somebody would work out that shooting people in the leg pays.

### Testing it

```
/testdismember head        take a limb off the corpse you are looking at
```

No roll, no chance. Tuning gib positions by shooting people until one of them
loses the right arm is not tuning. Permission `dismember.test`.

| | |
|---|---|
| `dismemberEnabled` | the switch |
| `dismemberScale` | percentage over every calibre's chance (100) |
| `dismemberGibLife` | seconds before gibs are removed (30) |
| `dismemberFlesh` | whether a limb drops meat |
| `dismemberLimbDamage` | what a limb must take to be a candidate (40) |
| `dismemberGibDamage` | what a body's torso must take to burst (120) |
| `dismemberCooldown` | seconds after a death before another death of the same person throws gibs or takes limbs (10) |
| `dismemberRobotDamage` | what a robot's body must take before it blows up (250) |
| `headpopEnabled` | whether a fatal headshot bursts the head |
| `corpseEnabled` | whether bodies stay at all |
| `corpseLife` | seconds a body lasts (**30**) |
| `corpseMax` | how many at once; the oldest goes first (24) |
| `corpsePKLife` | seconds a *named* body lasts (300) |
| `corpseHeadTime` | seconds of holding E to take a head |

---

## What staff did, in staff chat

A moderation command that only the target and the log know about is one the
rest of the team finds out about from the target. `!bring bob` now says

```
[STAFF] Alice brought Bob.
```

to everybody with `admin.chat`, and `~bring bob` says nothing to anybody —
which is the whole difference between the two prefixes, and the reason the
silent one is worth having.

It is a **chat class of its own** rather than admin chat, because these are not
somebody talking: the tag is `[STAFF]` and there is no name before the colon,
so a line the server generated cannot be mistaken for a line somebody typed.
Every verb calls `ix.admin.Announce`, which is a no-op for a `~` command — so
silence is decided in one place and a command cannot be quiet for the target
and loud for the team by accident.

Covers the verbs, `goto`, `bring`, `return`, `sethealth`, `setarmour`, `kick`
and `ban` — the same set `~` silences.

---

## Silent commands — the `~` prefix

```
!bring bob     "So-and-so brought you."
~bring bob     nothing at all
```

For watching somebody rather than dealing with them: the moment a player knows
an admin is interested they stop doing the thing, which makes the report
impossible to confirm.

Three rules keep it honest:

- **It is a permission.** `admin.silent`, granted separately — being able to
  act on somebody invisibly is a bigger thing than being able to act on them.
  Without it, `~` runs the command normally and says so.
- **Not every command.** Only the moderation verbs, listed in
  `ix.admin.silent`: goto, bring, return, kick, ban, slay, respawn, freeze,
  ignite, god, strip, blind, sethealth, setarmour and their aliases. `~advert`
  is not a secret advert; it is just an advert. **`warn` is deliberately
  absent** — a warning the player never sees is a note, not a warning.
- **Always logged.** Silent is silent to the *player*. Every one still writes
  its log line, and the line says `[silent]`, because "did they know?" is the
  one question anybody asks the log afterwards.

Every verb notifies its target through `ix.admin.Quiet` rather than calling
`Notify` itself, so silence is one decision in one place — and a verb added
later that forgets to use it is *loud*, which is the safe way round to be
wrong.

A kick or a ban cannot be hidden: they are leaving, and the disconnect reason
is the one thing they always see. `~kick` gives them the reason **without the
name** rather than pretending nothing happened.

---

## `/f` and `/o` — the radio

`libs/sh_factionchat.lua`. **A radio, not a whisper.** `/f hold the gate`
reaches every member of the speaker's faction wherever they are — and it is
also *said*, into a handset: anybody within talking range (`chatRange`) of the
speaker hears it, and anybody within talking range of a member whose radio
just answered hears it there too. `/o` is the officers' channel: members below
`officerChatRank` (3 — enlisted 1, NCO 2, officer 3, lead 4) neither receive
nor send on it, but they can stand next to somebody who does.

**Encrypted comms** is a switch on the faction in the live editor
(`encryptedComms`, off by default). Off, a bystander reads the words. On, a
bystander reads static — the same line with every non-space character replaced
from a fixed glyph set, random per line so it is not a cipher — and only the
faction reads it. The scrambling happens **on the server before anything is
sent**, so a client outside the faction never holds the real text.

How it is built: the two classes, `faction` and `officer`, carry the real
line to the people entitled to it through `CanHear`. `PostPlayerSay` then runs
once for the line and sends a second message — class `comms`, plain or
scrambled — to everybody within range of the speaker or of any receiver who
did not already get the real one. Two sends, one line. Members see
`[FACTION] Name: text` in the faction's team colour; bystanders see
`[COMMS] Name: text` (or `[COMMS, OFFICERS]`), the name going through
recognition the way a spoken line's does, the words greyed when they are
static. Dead people cannot send on either.

Phoenix's version is server-side and not in the client scrape, so this is
built from what it does rather than from how.

**The handset clicks.** A line you sent opens with the transmit chirp, one you
received closes with the answer chirp, and one you only overheard is the same
chirp, quieter — the metropolice radio chirps, base Half-Life 2 content so
every client has them (`ix.factionchat.Chirp`).

| | |
|---|---|
| `factionChatEnabled` | the switch |
| `officerChatRank` | the class rank `/o` needs (3) |

## `/advert`, and the chat switches

The sound is the tick (`phoenix/ui/76/ui_questupdate_01.mp3`), for the sender
and every receiver alike.

```
/advert <text>   /global <text>   everybody on the server hears it
```

```
[GLOBAL]: I have water to trade
[GLOBAL] Vault Dweller says: I have water to trade
```

Whether your name is on it depends on whether they **know** you. That is
Phoenix's rule and it is the right one for a broadcast in a game with
recognition: a stranger's advert is a voice, and a friend's advert is a friend.
Asked the way the recognition plugin asks it — `character:DoesRecognize` plus
the `IsPlayerRecognized` hook — never `GetCharacterName`, which is backwards
and is documented at length in `cl_karma.lua`.

An advert has a **length cap and a delay**. Phoenix have only the cap, which
stops one message being long and does nothing about there being forty of them.
OOC has a delay for exactly this reason and an advert is louder, because it is
in character and people answer it.

### Only `advert` is new

Helix already ships everything else, registered in
`core/libs/sh_chatbox.lua`, and every one of them answers to `!` as well as `/`
because `sh_adminverbs.lua` rewrites the prefix:

```
/w  /whisper     a quarter of the normal range
/y  /yell        twice it
/me  /it         actions
//  /ooc         everybody
[[  /looc        local
```

Writing our own would mean two chat types with the same name and the second one
winning.

| | |
|---|---|
| `advertEnabled` | ours |
| `advertDelay` | seconds between adverts (60) |
| `advertMaxLength` | characters (512) |
| `allowGlobalOOC` | **Helix's own**, already in the config menu |

`allowGlobalOOC` is deliberately **not** re-declared. A second config that also
turned OOC off would leave a server owner with two switches for one thing and
no way to tell which is being obeyed — Helix's `ooc` class reads its own, so
its own is the one that must be set.

### `!ooc` used to say "that command does not exist"

Fixed on the way past, and it is worth knowing why. `/ooc`, `/y`, `/w`, `/me`
and now `/advert` are **chat prefixes**: Helix matches them in `ix.chat.Parse`
inside `GM:PlayerSay`, and registers a command of that name on the **client
only**, purely so the chatbox can autocomplete it. So `ix.command.list` on the
server has no entry for any of them, and the `!` rewrite — which only ever
looked there — refused every chat type in the game.

It now asks `ix.chat.Parse` with `bNoSend` first, which makes it a pure
question: *would this have been a chat type, and what is left after the
prefix?* Only then is it sent. `ic` is the answer when nothing matched, and
sending that would say "/ooc hello" out loud in character — which is exactly
the bug this replaces.

### `/advert`'s sound, and staff skipping the waits

The sound is the base game's chat tick (`common/talk.wav`), for the sender and
every receiver alike, and nothing else — **quieter**: `surface.PlaySound` has no
volume, so it is played through the local player at `fo_advert_volume` (0.35,
per player, 0 is off), at sound level 0 so it does not attenuate. **`chat.bypass`** (Staff) skips the
`/advert` delay and Helix's `/ooc` delay: Helix gates its OOC timer on a CAMI
privilege this schema's ranks never grant, so its `CanSay` is wrapped in
`sh_chat.lua` — for somebody with the permission the last-OOC stamp is cleared
before Helix looks at it.
