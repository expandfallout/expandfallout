# 54 - NPCs

Hostile and friendly people, in the schema's own armour with the schema's own
guns, spawned by pods that only exist while somebody is near. Three parts;
`libs/sh_npc.lua` is the shape of all of them.

## Presets

A preset is what an NPC *is*: name, race and gender, health, accuracy, side,
the guns it may carry (one is picked per NPC), the armour it wears (one piece
per slot, the last ticked for a slot winning), the chance it drops its gun,
the chance it drops each piece of armour, and a **loot** list — anything at
all, each with its own percentage. Kept in `ix.data` ("npcpresets", global), cleaned on the way in
(`ix.npc.Clean`), synced to every client.

The editor — **`/npcpresets`**, `fo_npcpresets`, or the button in the
spawner tool — is `derma/cl_npcpresets.lua`: presets on the left with NEW,
DUPLICATE and DELETE, the fields on the right, SAVE at the bottom. Guns and
armour are searchable tick lists, because there are 685 pieces of armour.
`npc.manage` for all of it. A server with no presets is seeded with a
"Wastelander" carrying the first pistol it finds.

**Sides.** VJ decides friend and foe by class lists. *Hostile* NPCs share
`CLASS_FO_HOSTILE` and fight everybody; *friendly* ones carry
`CLASS_PLAYER_ALLY`; a **faction** side gives the NPC `CLASS_FO_<FACTION>` and
every player of that faction is given the same class when their character
loads (`sv_npc.lua`, `PlayerLoadedCharacter`), so NCR troopers hold the gate
for NCR characters, shoot everybody else, and two factions' pods fight each
other.

**Walking where the map has no AI nodes.** An engine NPC paths on a map's node
graph and will not move one unit without it, and some maps ship none at all:
`rp_utah` packs a **16-byte, zero-node** graph inside its own BSP and contains
not one `info_node`. A map's packed archive is added to the front of the
filesystem search path, so that empty graph is handed over and a real one in
`maps/graphs/` is never read. The map cannot be repaired either — renaming the
packed entry works, and changing a byte of a BSP changes its checksum, so every
client is refused with *"your map differs from the server's"*. It was tried,
and that is exactly what happened.

**And a graph on the disk is not a graph that can route.** This is the harder
lesson and it cost several rounds. `rp_utah_a` carries a real 8192-node graph
that the engine accepts, `/npcnodes` reads it happily, and `NavSetGoalPos`
across two thousand units still answers **false**. Whether a map has a node
*file* and whether the pathfinder can build a route between two real places are
different questions, and only the second one matters. `/npcroute` asks the
second: it tries to route from an NPC to points every 64 units (128 or 256 on a
long test) along the line to you, and prints how far it routes cleanly, where it
first refuses, whether your exact spot routes, whether the floor directly under
you does, and what you are standing on. That separates three failures which
look identical from across a room. A refusal part way is a gap in the graph: a
drop, a fence, or no nodes. Every step routing but not your spot, while the
floor under you does, is you standing on something the graph does not know
about. Nothing routing at all is a graph the engine never really loaded,
whatever the file says. The first version tried powers of two and then jumped
to the player, so on a 977-unit test it saw 512 route, your spot refuse, and
nothing in between - and called that "disconnected pieces" when the data said
no such thing.

So the NPC walks itself (`WalkItself`, `npcWalkWhenStuck`) once the engine has
been given its three chances and failed all of them: a
short step **once a server frame**, straight at an enemy it can see, while
further off than its chase distance. Once a frame and not once a think: VJ
thinks about fifteen times a second, the client draws between the positions the
server sends it, and a server that holds still between steps gives it nothing
to draw - fifteen visible jumps a second, which is what "it moves but really
laggy" was. The stepping is driven from the `Think` hook over `ix.npc.walkers`
instead, four or five times as often and a quarter of the distance each time. It sweeps its own hull ahead and refuses to enter anything
solid, and it requires ground under the far end of each step, which is what
keeps it off ledges and out of the void. It is **on**, and it is gated on failure rather than on the map: `ENT:Chase`
asks the engine for a path three different ways and measures whether the body
actually moved, and only when all three have failed does the hand-stepping
start. On a map that can path, the third failure never arrives and none of this
ever runs. The earlier gate asked `ix.npc.MapHasNodes`, which reads the node
count out of the `.ain` - a fair question about the file and the wrong question
about the map, which is how NPCs ended up standing still on a map with a
perfectly good graph they could not route on. Checking only whether the
engine was moving the NPC *at that instant* was not enough - an NPC the engine
is about to move, or has just finished moving, is not moving right now, so the
hand-stepping ran in the gaps between the engine's own steps. Two things moving
one body looks precisely like that, and a body moved while it is off the ground
ends up under the map. It now also refuses to move an NPC that is not standing
on something, and a step may rise or fall by a stair's height and no more, so a
step off the lip of anything cannot drop it. A preset set to *Hold* opts out
entirely. It cannot go round a corner
and it stops at the first wall between you and it. That is the honest limit of
moving without a path.

**Taking cover** is `npcTakeCover`, and it is off. VJ's humans hide when shot
at and back away when crowded, and both of those block chasing for seconds at
a time, so an NPC in a real firefight essentially never closes. Off, they walk
into your shotgun, which is what a raider does. On, they fight like a fireteam
and will not come for you while the shooting lasts.

**Facing where they walk** is `npcShootOnTheMove`, and it is off. VJ's humans
can keep the body turned at their target while moving along a path
(`Weapon_CanMoveFire`), which a trained soldier does and a wastelander looks
ridiculous doing. The nine-way blends make it plain, because the animation
honestly plays the sideways cycle it is asked for: the NPC really is
crab-walking, and a strafe cycle is slower than a run, which is the whole of
"they walk around without looking where they're going" and "they walk slowly
and don't run". Off, they turn to face their path, close at a run, and shoot
when they arrive. The capability is set alongside the flag in `Dress`, because
VJ grants `CAP_MOVE_SHOOT` at spawn from that same flag.

**Behaviour** is a preset field, and the interesting part is that VJ decides
both "how far will it shoot" and "how close will it come" with the *same*
number. `Weapon_MaxDistance` is the range a human fires from, and it chases
only while the enemy is further off than that. So no single value gives what
everybody actually wants, which is an NPC that runs at you **and** shoots on
the way: set it high and it plants its feet the moment it can see you, set it
low and it sprints into your face before firing a shot. Both were tried and
both were reported as bugs - "it doesn't chase me" at 1200, arm's length at
350.

The schema already decides for itself whether a weapon may fire, in
`NPC_CanFire`, so the two are pulled apart. `Weapon_MaxDistance` is now only
the distance the NPC **closes to** and comes from the behaviour; the distance
it will **shoot** from is the `npcFireDistance` config (2500), never lower
than the first. An advancing NPC runs at you from across the map and shoots
the whole way in.

So **Hold** is a sentry: 3500, further than it will ever see, so it never
closes. **Advance** is 250, near enough to be in your face. **Patrol** is
Advance plus `IdleAlwaysWander`, so it also wanders its post when nothing is
happening. New presets advance. VJ retreats below 150, so there is a hundred
units of dead band between closing and backing off and they do not oscillate.
All three still take cover, strafe and chase somebody who breaks line of
sight, and all of that needs the map to have AI nodes.

## Spawners

Everything placed with the tool or `/npcspawn` lands in the placer's **undo**
list under the preset's name, so Z and the Q menu's undo tab take it back. A
single NPC is undone like any entity. A spawner is undone through
`ix.npc.Remove`, because its pod is only the visible half: the record is saved
to disk, and a pod deleted on its own comes back on the next restart with its
NPCs. `SetCreator` is deliberately not used, because VJ reads the creator's
`vj_npc_spawn_guard` setting and would turn a player's NPCs into sentries that
never chase.

The **NPC Spawner** tool (`entities/tools/fo_npcspawn.lua`) places a pod: a
preset, how many, respawn time, spawn radius, and the two distances that
decide whether its NPCs exist at all. Left click places, right click removes
the nearest, reload rewrites the nearest with the panel. The panel's **mode**
picks what a left click makes: a group spawner, a **single NPC** that stays at
that spot and comes back when killed (a spawner of one with a sixteen-unit
radius), or **one NPC once** with no pod behind it. Pods are records in
`ix.data` ("npcspawners", per map) and `ix_npcspawner` entities made from
them on load; with the tool out they draw as a ring at the spawn radius with a
line saying what they are set to and how they are doing.

**This is the optimisation.** `ix.npc.Tick`, once a second per pod: a player
within the **wake** radius and the pod's NPCs come into being, a beat apart;
nobody within the **sleep** radius for the sleep delay and they are removed.
Dead ones come back after the respawn time, one at a time. `npcMaxAlive` (60)
caps the server, and a lowered count sends the extra away. `/npcclear`
removes every spawner NPC; `/npcspawn <preset>` puts one down with no pod.

## The NPC

`entities/entities/npc_fo_human/` — a VJ Base human (`npc_vj_human_base`)
on the schema's own animation model, `models/phoenix/humans/animations.mdl`.
Why VJ: the creature packs this server mounts are VJ SNPCs, so relationships,
weapons and corpses already fit, and VJ's human base is the one that takes a
player model and a weapon it has never seen and does something sensible.

**Armour.** An NPC has no character, so `sh_bodyparts.lua` grew
`ix.fallout.SpecParts` and `RecipeFromSpec`: the same parts `GetBodyParts`
composes for a character, from a spec — race, gender, a random ethnicity,
hair and beard, a hair colour, and the preset's armour resolved per slot.
`ix.npc.Dress` composes it on the server and puts it on the NPC as a net var;
`cl_npc.lua` bone-merges it on with the same `BuildRecipe` that draws players
and corpses. When the NPC dies, VJ's ragdoll is handed to
**`ix.corpse.Adopt`** with that recipe, so the body is dressed, cut and swept
like anybody's.

**Guns.** `ix.npc.RegisterWeapons`, on `InitializedPlugins` on both realms,
makes **one VJ weapon per weapon item** — `weapon_vj_fo_<item>` on
`weapon_vj_base` — reading the item's `ls_base` SWEP for the world model,
damage, shots, magazine, fire delay, sound and hold type. Grenades and
anything VJ has no hold type for are skipped. The weapon carries the SWEP's
Phoenix hold type and attack and reload sequence names, which is what the
NPC animates with. They are NPC-only and never dropped as SWEPs; what an NPC
drops is the **item**, by the preset's chance (a third of it per piece of
armour).

**Animations.** The animation model is a player model with Phoenix's own
sequence names, and its activities are a mess: the aimed idles have none,
the NPC walk and run are proper (`mtwalk_npc` is ACT_WALK, `mtrun_npc`
ACT_RUN), and the standing idle's activity is shared by three sequences, one
of which is a crucifixion. `ix.npc.Anims` therefore answers two different
askers two different ways:

- **the engine** drives idle, walking, running and crouching through
  `TranslateActivity` and takes a *number* — those get activities the model
  has, checked on the model with `SelectWeightedSequence`. The raised aim of
  a hold type ("2haaim") has no activity, but its nine-way walk blend
  ("2haaim_walk") has one and the cycle at the centre of that blend *is* the
  raised aim — so an alerted NPC standing still is put on the walk blend and
  aims, and its aim-walk, aim-run and crouch resolve the same way
  (`AimActivity`, tried by name at run time). VJ's own
  `TranslateActivity` answers first — it is where an alerted NPC decides to
  fire while it walks — and whatever number it answers is put through the
  NPC's table once more, which catches the activities VJ hands back raw
  (an alerted idle is ACT_IDLE_ANGRY). The shared idle is corrected every
  think (`OnThink`): an idle that landed on the crucifixion is put onto
  `mtidle`, which has the *same* activity, so the engine sees nothing to undo.
- **VJ** plays attacks, reloads and melee through its own player, and the
  split matters: every attack and reload on this model is a **delta**
  sequence, the recoil alone, made to be layered over an aim (gotcha 36).
  So VJ's "attack animation" (`AnimTbl_WeaponAttack`) is the aim **stance**
  — as an *activity*, the aim blend's, which is what the engine already
  plays for an alerted idle, so VJ's "is my attack animation still the
  current one" check holds and it keeps firing; a sequence *name* there went
  through VJ's sequence schedule, which the engine kept taking back, and
  nobody fired — and the weapon's own `AttackAnim` is the **firing
  gesture** (`AnimTbl_WeaponAttackGesture`, `vjges_vjseq_` prefixed), which
  the VJ weapon base plays on every shot. Reloads are gestures too. A melee
  weapon is the other way about: its swings are the attack, as gestures.

**When a generated weapon may fire** is the schema's answer, not VJ's. VJ lets
a human's weapon fire only while its attack *animation* is the body's current
one — `WeaponAttackState == FIRE_STAND and VJ.IsCurrentAnim(owner,
owner.WeaponAttackAnim)` — which is fair for a model whose attacks are
whole-body sequences and impossible for one whose attacks are deltas layered
over an aim the engine's idle keeps reclaiming. Nothing ever fired under it,
with the stance given as a sequence name or as an activity. The generated
weapon's `NPC_CanFire` keeps every other test VJ makes — the weapon ready and
the enemy in range (`CanFireWeapon`), ammo in the clip, the enemy inside the
firing cone — and drops only the animation coupling. The cone is measured off
the body's forward rather than VJ's `GetHeadDirection`, since the NPC is told
to face its enemy while it shoots and this skeleton's head bone is not the one
VJ assumes. A melee weapon only asks whether the enemy is within reach.

`fo_npc_report`, looking at an NPC, prints its current sequence, activity,
ideal activity, weapon, hold type and the whole translation table, and for
movement: whether it is moving, **the ground speed of the sequence it is
playing**, both movement pose parameters, its capability bits and its current
schedule. A ground speed of zero on a walk is the whole story. It also says
why the NPC has no enemy, which is four questions that look identical from
across a room: whether you are in its relationship list, what it is disposed
to think of you, whether it can **see** you, and whether you are inside its
**view cone**. Its alert state narrows that on its own - `false` is nothing at
all, `1` is "heard something but has never seen an enemy", `true` is "has seen
one" - so a `1` that never becomes `true` while you stand in front of it is a
sight problem, not a relationship one. It is
**read-only**: an earlier version called `NavSetGoalPos` for its path test,
which does not ask whether a route exists so much as set the NPC's goal to that
position - so looking at an NPC threw away whatever it was doing and sent it at
whoever ran the command, and reading the report twice while testing was itself
breaking the walking it reported on. A diagnostic that changes what it measures
is worse than none. The path test lives in `/npcwalk`, which is asking for the
NPC to be sent somewhere anyway. It also asks
the engine to build a route from the NPC to whoever ran the command
(`NavSetGoalPos`) and prints whether it could: **a false there is a map with
no usable AI nodes**, which no amount of animation work will ever fix.
`/npcwalk` orders the NPC in front of you to walk to you and says the same
thing in one sentence, which separates "the AI chose not to" from "it cannot".

**`/npcnodes`** answers the question after that one: *which* graph the engine
can see. A map's `.ain` can be packed inside its BSP, and a map's pak goes to
the FRONT of the filesystem search path when it loads, so the packed copy is
handed over first and a file placed in `maps/graphs/` is never read - the same
precedence that makes Nodegraph Editor refuse to edit such a map in place, and
completely invisible from in game. The command opens the path the engine would
open, in the engine's own search order, and prints the size and header of
whatever comes back. A byte count that is not the file you copied in means the
packed graph won. A format number other than 37, or a map version that is not
the running map's, means the engine will throw the graph away at load and
rebuild it from the map's `info_node` entities, of which most maps have none.

**The gun in the hand** is drawn where a player's is: the schema's SWEP base
draws a human's weapon at the animation model's `weapon` attachment, turned
-90 about its up and scaled 0.85. `ix.npc.HandPose` answers that for an NPC
and `cl_npc.lua` draws a **clientside model** of the weapon there every
frame, from `PostDrawOpaqueRenderables`; the VJ weapon entity itself draws
nothing. The entity is the wrong thing to draw: the engine attaches it to an
`anim_attachment_RH` this skeleton does not have and bone-merges it against
bones it does not share, and every way of drawing it came out in the ground
or flickering at the hip. The model comes from the `ixWeaponModel` net var.
`fo_npc_weaponpose ox oy oz ax ay az [scale]` still moves every NPC gun live.
The weapon **entity** is moved to the hand as well, by VJ's own
custom-position feature (`WorldModel_UseCustomPosition`, bone
`Bip01 R Hand`), and its `OnGetBulletPos` answers the hand too: VJ's own
lookup knows muzzle attachments and `ValveBiped` hands, found neither, and
fired every shot from the eyes with a warning each time.

**Armour on an NPC stops damage.** A preset's pieces were worn, drawn and
dropped and protected nothing, because damage resistance lives in
`ScalePlayerDamage`, which fires for players and nothing else: a raider in
metal armour died as fast as a naked one. `Dress` sums the very numbers a
player wearing the same pieces would have (`ix.armor.GetSetDR`) once, into
`ixHeadDR` and `ixBodyDR`, and an `EntityTakeDamage` listener applies them.
The hit is placed at the nearest known bone to where the damage says it
landed, since an NPC has no `LastHitGroup`.

**`/npcignore`** makes NPCs unable to see you, and back again. Placing a
spawner means standing in the middle of whatever it spawns, and a raider does
not know a toolgun from a rifle. It sets the engine's own `FL_NOTARGET`, which
every NPC checks before anything else, so it works on the Fallout SNPCs and
anything else installed, not only these. It lasts until it is turned off, and
survives a respawn.

## Found the first time out

- **T-posing and not moving, twice.** First the NPC's `Init` filled VJ's
  translation table before VJ had made it, and an error in `Init` is an NPC
  with no AI. Then the translations answered ACT_IDLE with nothing — the aimed
  idles have no activity — and an engine idle with no sequence is a T-pose.
  Idle is an activity the model has now, corrected onto the right sequence
  every think; see *Animations*.
- **No gender buttons.** `RACE.genders` is a set, not a list, and `ipairs`
  over a set is nothing. `ix.npc.Genders` turns it into a list, male first.
- **A tiny aggro range, and nobody shooting.** The animation model's
  `$eyeposition` is 0 0 0: an NPC looks out from its eyes, and its eyes were
  at its feet, so every line of sight ran along the ground and stopped at the
  first pebble. The NPC sets the engine's view offset to a standing head
  (`ixEyeHeight`, 64) and keeps it there.
- **Not moving at all.** The walk and run cycles are nine-way blends picked
  by `move_x`/`move_y`, and the centre cycle is the idle, with no motion in
  it. With VJ's pose-parameter movement off — a round's guess at "weird"
  movement — the engine played the centre cycle, read a ground speed of
  nothing, and stood still on every path. On, and not optional (gotcha 35).
  Beyond that, a VJ human with a gun *holds its ground* while it can see
  you and shoot; it moves to chase when it loses you, and chasing needs AI
  nodes on the map — a map without a nodegraph has NPCs that shoot from
  where they stand and walk only in straight lines. (`ai_nodes 1` printing
  only "Displaying: HUMAN_HULL" and drawing nothing is a map with no nodes.)
- **A walk blend as the idle.** The only standing aim this model gives an
  activity to is a walk blend, and the alerted idle had been mapped to it
  because the aim proper has none. A walk blend as an idle walks on the spot
  the moment anything hands it a direction, and carries a ground speed the
  engine acts on while believing the NPC is standing still. The idle is the
  idle now, armed or not; the raised aim is put on by `OnThink`. And VJ's
  own "attack animation" for a gun is `false` - every value it could be given
  was either a walk blend or something VJ could not see was already playing,
  so it restarted it five times a second. Firing is the schema's decision and
  the recoil is a gesture, so the stance had nothing left to do but harm.
- **Correcting the pose out from under the engine's own walk.** The standing
  list is built from the whole of a hold type's tree, and that includes its
  walk and run blends - so the correction was allowed to pull the NPC out of
  the very sequence the engine had just given it to move with. `2hraim` has
  no ground speed, and an engine NPC with no ground speed does not advance:
  route planned, walk started, pose yanked back to a standing aim, stall.
  The two lists are made **disjoint** now, in `ix.npc.Anims`, rather than by
  asking whether the NPC happens to be moving at the instant it is asked -
  which it is not, reliably, in the gaps between the engine's own steps.
- **Moving slowly, weirdly, and seemingly at random**, once the map finally
  had nodes. The same trap as the lowered gun, one layer down. The movement
  blends are matched by name against the hold type's tree, and
  `2hraim_walk_passive1`, `2` and `4` are not in it while `2hraim_walk` is -
  yet all five share ACT_GESTURE_RANGE_ATTACK_SMG2 and the engine picks among
  them by weight. Land on an unnamed one and the blend was treated as "not
  travelling", so its pose parameters were zeroed, the blend collapsed to the
  cycle at its centre (the idle, which travels nowhere), and the ground speed
  went with it. The NPC crawled, could not reach the waypoints it had been
  given, and re-pathed over and over, which is what "random and dumb" looked
  like. Matched by activity as well now (`ENT:ixTravels`).
- **Walking on the spot, and the round of guesses that got there.** This
  model has no travelling sequence: every walk and run among its 667 is a
  nine-way blend on `move_x`/`move_y`, and the cycle at the centre of each is
  the idle. An engine NPC takes its ground speed from the sequence it is
  *playing*, so those two parameters decide whether it can move at all, not
  merely what it looks like while it does. That much was right. What was
  wrong was the conclusion: that VJ's `UsePoseParameterMovement` could not
  start the NPC off, because it sets the parameters from
  `VJ.GetMoveDirection`, which returns nothing until `IsMoving()` is true.
  **`IsMoving` asks the navigator whether a goal is active, not whether the
  body has travelled.** It is true from the instant the walk task begins, one
  think before any of it matters, and there was never a deadlock to break.

  Driving the parameters by hand instead cost three things that only that
  flag switches on, and each one was reported as its own bug:

  1. `OverrideMoveFacing` turns the NPC to face its own waypoint. Nothing
     else does, so they walked around without looking where they were going.
  2. A path that fails as FAIL_NO_ROUTE_ILLEGAL no longer throws the whole
     schedule away — VJ wrote that exemption for models that move like this
     one. Without it they re-planned constantly: "random and dumb".
  3. The parameters are set **only while the navigator has somewhere to be**.
     Keying them off which sequence is playing looks equivalent and is not: a
     standing NPC in a sequence that merely *shares an activity* with a walk
     got pointed at a stale waypoint, played a travelling blend, and carried
     a travelling ground speed while the engine was moving it nowhere. That
     is walking in place, exactly, and it is what the hand-rolled version
     was for.

  The flag is on and `MoveBlend` is gone. `ix.npc.Anims` still decides which
  blend plays and `OnThink` still puts the standing pose right; what travels
  is VJ's again. The one case it cannot cover is `WalkItself`, which moves
  the body itself on maps with no node graph and so is never "moving" as far
  as the navigator is concerned — that sets the two parameters on its own.
- **Shooting you from where it stands and never taking a step, part two.**
  VJ starts a chase in exactly one place, `MaintainAlertBehavior`, and that
  returns immediately while `TakingCoverT` is in the future. Three of its own
  behaviours keep pushing that timer forward and in a real firefight they
  never stop: it backs away inside `Weapon_RetreatDistance` (150) and sets the
  timer two seconds on every think, it hides or runs for cover every time it
  is **shot** and sets it three to five seconds on, and the cover schedule
  that follows sets it five seconds on again. The more of a fight it is in,
  the less it moves, and what movement is left is *away* from you. Both
  behaviours are off by default (`npcTakeCover` restores them), and the
  schema starts VJ's own `SCHEDULE_ALERT_CHASE` itself in `ENT:Chase` without
  asking those timers for permission. It has three ways to get there, all of
  them the engine's own: straight at the enemy, a node that can merely see
  them, and a plain goal toward their position. Whichever last moved the body
  goes first next time, and only a stall hands over to the next. It used to
  start again from the top after every success, which on this map meant
  failing the two that never work before reaching the one that just had. The
  third asks for the full distance, then three quarters, a half and a quarter,
  and goes to the furthest that builds, because here the graph reaches almost
  all the way to a player and not the last stretch, and asking only for the
  exact spot threw that away. The report prints how much of the way it built.
  Nothing about the movement is
  hand-rolled: same schedule, same tasks, just not vetoed.
- **Three fifths of an animation.** The right pose, and still wrong in ways
  that were hard to name. Two causes, both read off the model. Every shot and
  reload on it is a two-way blend on a pose parameter called `standing`: 100
  plays the version made for standing still, 0 the version made for walking.
  Nothing on the server or in VJ ever set it, so an NPC standing its ground
  fired and reloaded with the version made for walking. It is 100 when still
  and 0 when moving now. And VJ drives the aim parameters only while its own
  weapon-attack state is set, which it clears on every reload and chase, so the
  aim froze wherever it last pointed and stayed twisted through the walk and
  the wandering after the fight. The NPC tracks whoever it is fighting now, and
  eases back to straight ahead otherwise. The aiming itself was never missing:
  the engine plays the aim-yaw and head layers on every sequence, and `2hraim`
  brings its own pitch layer. See gotcha 42.
- **The legs flickering during a hand-walk.** VJ zeroes the movement
  parameters on every think the navigator is idle, and a hand-walked NPC's
  navigator always is, so the walk blend kept collapsing to its idle centre ten
  times a second. `WalkItself` switches VJ's pose-parameter movement off for
  exactly as long as it steps, and `OnThink` hands it back.
- **Chasing sometimes and not other times.** The engine keeps a list of
  entities an NPC has written off as unreachable, and the chase task refuses
  before attempting anything when the enemy is on it. That list clears itself
  on a timer, and clears immediately once the entity moves about 120 units
  from where the note was taken - which is exactly why it worked *sometimes*.
  VJ never lets it expire: one failed path, and `MaintainAlertBehavior`
  re-writes the note every two seconds thereafter, reading its own note back
  each time. It also drops the enemy on every re-write, which is where the
  reports full of `enemy nil` came from. `RememberUnreachable` is a no-op on
  these NPCs, and a genuinely unreachable enemy is chased by pathing to their
  **position**, a task that never consults the list. See gotcha 40.
- **Standing at zero rounds with an empty gun, reloading for good.** Two of
  VJ's own habits, and one of them was made worse by the fix above. A human
  more than 650 units from its enemy does not reload where it stands: it
  starts a schedule to run to cover and reloads in that schedule's finish
  handler, while the weapon state is set to RELOADING **with no time limit**.
  Anything that stops the schedule finishing strands it there, and a chase
  replaces the schedule, so the more eagerly it chased the more certainly it
  ended up unable to shoot. `Weapon_FindCoverOnReload` is off, and `OnThink`
  keeps a four-second watchdog on the state regardless. Separately, VJ calls
  `StopMoving` on every reload that plays as a gesture, which ours all do, so
  `ENT:Chase` checks shortly after each attempt whether the NPC actually
  moved and starts again if not - measured as **ground covered**, because
  `IsMoving` only asks whether the navigator has a goal and a wander is a
  goal, so an NPC pottering about while ignoring the player read as a chase
  that worked. See gotcha 39.
- **Shooting you from where it stands and never taking a step.** VJ picks its
  own targets and hands them over with `ForceSetEnemy`, which sets the enemy
  and nothing else - so the NPC was shooting at a player the **engine** still
  regarded as neutral. That is not cosmetic. The engine's senses build enemy
  memory only for entities the NPC hates, and `TASK_GET_PATH_TO_ENEMY` walks
  to the last known position out of that memory, so with no memory the chase
  task was handed the map origin. The report showed it plainly: a live enemy
  at ninety units, disposition 4, waypoint `0 0 0`. The schema states its own
  relationships to the engine now (`ix.npc.Relate`) and re-states them while
  an enemy is held, because VJ pins a dropped enemy back to neutral every
  time. See gotcha 38.
- **Standing still through the whole fight.** Not the nodegraph, and not
  VJ's sentry habits either in the end: nearly everything a VJ human does
  *while* shooting - strafing out of the open, stepping aside when a friend
  walks into the line of fire, giving up a position it cannot shoot from -
  hangs off `WeaponAttackState` being FIRE_STAND, and VJ sets that flag in
  the same branch whose animation test can never pass here (see above). The
  schema fires the weapon itself, so it sets the flag itself.
- **Firing with the gun lowered, as if still holstered.** Three causes, one
  after another. Which sequence an armed NPC stands in was left to
  activities, and an aim resolves through a nine-way blend whose name is not
  the aim's, so the engine could stand it anywhere. Then the correction that
  fixed that was allowed to act only on a hand-picked list of a few poses,
  and the engine simply stood in something else: no match, no correction. And
  the test for "should it be aiming" asked VJ's `Alerted`, which is a state
  with a timeout of its own rather than a fact about right now, and required
  the weapon to be `READY`, which a reloading NPC is not.

  So: `OnThink` puts the NPC into the pose it should be in, the aim when it
  has a gun out and an enemy and the plain idle otherwise, whenever it is
  standing in *any* pose from its hold type's tree or the unarmed one, **or
  in any pose sharing an activity with one of those**, and is not moving.
  That last part is what finally caught it: `2hraim_walk` and four
  `2hraim_walk_passive*` share ACT_GESTURE_RANGE_ATTACK_SMG2 and the engine
  picks among them by weight, so a shotgun NPC stood in
  `2hraim_walk_passive1` - weapon lowered - which no list of names was ever
  going to hold. The activity is the family. `TranslateActivity` makes the same call for the activity path,
  turning a plain idle into an angry one whenever there is a weapon and an
  enemy, so both agree. Correcting only while the NPC is still means the
  walking blends in that list are never cut short, and nothing outside it,
  a reload or a swing, is ever interrupted.
- **Punching with a rifle, and firing with the gun on the floor.** VJ's
  humans have a melee attack by default and punch anyone close with the
  melee table — a delta swing here, showing as nothing — so `HasMeleeAttack`
  is off. The gun on the floor was the delta attack played as the body's
  animation; see *Animations*.
- **An invisible gun, then one glitching at the hip.** The engine attaches
  an NPC's weapon to `anim_attachment_RH`, which this skeleton does not have,
  and bone-merges it against bones it does not share; drawing that entity at
  a render origin put it in the ground, and rebuilding its bones first put it
  flickering beside the body. The entity is not drawn at all now; a
  clientside model is, see *The gun in the hand*. `fo_npc_client` (client
  console, looking at the NPC) prints what the client knows about it.
- **Nobody firing, with the enemy in plain sight.** Same cause, other realm:
  the weapon entity at the feet is where VJ's cover trace starts, it hit the
  ground every time, and the NPC spent every think stepping out of cover that
  was not there. The entity is moved to the hand bone now (see *The gun in
  the hand*). `fo_npc_report` prints both cover traces, where the bullets
  leave from and how long until the next attack, so the next such thing is
  a line, not a guess.
- **The search boxes.** Plain `DTextEntry` now, refilling a quarter of a
  second after the last keystroke instead of rebuilding six hundred buttons
  per key. And the lists are a **fixed height that scrolls** — a row sized
  from its grid every frame crunched the window when the grid was rebuilt
  under it.

## What to expect first time

Untested in-game as of writing. The likely tuning: the weapon offset in the
hand, and whether any of the Phoenix sequences an NPC is pointed at need
swapping for ones that read better on an NPC; both are one table each.
