# 53 - Vehicles

Phoenix drove **LVS** (Blu's vehicle framework, workshop 2912816023), and so
does this. Two halves:

- **`garrysmod/addons/falloutrp_vehicles/`** — sixteen LVS vehicle
  definitions, `lvs_fo_*`, one folder each, and the helper that builds them.
- **the schema** — `libs/sh_vehicles.lua`, `sv_vehicles.lua`, `cl_vehicles.lua`,
  `items/base/sh_vehicle.lua`, `items/vehicle/` — the items that deploy them
  and the rules about owning one.

## The vehicles

| item / class | model | on |
|---|---|---|
| Buggy `lvs_fo_buggy` | Roadkill `buggy.mdl` | wheeldrive, wheel bones |
| Highwayman `lvs_fo_highwayman` | Roadkill `highwayman.mdl` | wheeldrive, wheel bones |
| Junk Car `lvs_fo_junkcar` | Roadkill `car01.mdl` | wheeldrive, box; `Grill` says front |
| Chariot `lvs_fo_chariot` | Roadkill `chariot.mdl` | wheeldrive, box |
| Hermes `lvs_fo_hermes` | Roadkill `hermes.mdl` | wheeldrive, box |
| Classic Truck `lvs_fo_classictruck` | Galang `classictruck01nw.mdl` | wheeldrive, box |
| Fuel Truck `lvs_fo_fueltruck` | Galang `classictanktruck.mdl` | wheeldrive, box |
| Fusion Flea `lvs_fo_fusionflea` | Galang `fusionflea.mdl` | wheeldrive, box, electric |
| Humvee `lvs_fo_humvee` | Sentry `humvee_fo3.mdl` | wheeldrive, jeep rig; driver's MG |
| APC `lvs_fo_apc` | Sentry `apc_fo4.mdl` | wheeldrive, jeep rig; gunner MG |
| Chimera Tank `lvs_fo_chimera` | Sentry `tank_fo4.mdl` | wheeldrive, jeep rig; fixed cannon |
| NCR Sherman `lvs_fo_ncr_sherman` | LVS `sherman_lvs.mdl` | **LVS's own Sherman**, renamed |
| Vertibird `lvs_fo_vertibird` | Sentry `vb02.mdl` | helicopter; rotors on the prop hubs; door MG |
| Zetan Saucer `lvs_fo_ufo` | Galang `zetaufo.mdl` | helicopter; one hidden rotor |

Not in the list: Galang's two **military trucks** (plain and NCR). They are
static props built long along Y, and a vehicle whose body faces sideways
fights LVS every tick - the NCR one "freaked out" on the road. They need a
recompile with a ninety-degree yaw before they can drive; the models are still
mounted.

Plus six LVS accessories as items — petrol and diesel jerrycans, the vehicle
ammo crate, turbo, supercharger, mine — which are put down and forgotten.

### Where the numbers come from

Phoenix's definitions are in the scrape (`addons/nwb_additions`), but only
their client halves; the server files with the wheel and seat positions are
not. So **positions are read from the model when it spawns**
(`lua/autorun/sh_falloutrp_vehicles.lua`, `FOVehicles.Build`):

- **attachments `wheel_fl` .. `wheel_rr`** — the Source jeep rig; LVS's own
  `AddWheelsUsingRig` reads them and works out which way the rig faces. The
  three Sentry models have them, and `vehicle_driver_eyes` for the seat.
- **named bones** — Roadkill's buggy and Highwayman have `WheelFL` and
  friends; the definition names them and the wheels go where the bones are.
- **nothing** — a static prop: four wheels under the corners of the bounding
  box.

**Wheels are models with rims.** Half-Life 2's tyres are tyres and nothing
else ("hollow"), so wheels come from the LVS car pack, which is mounted for
the Sherman anyway — the Kübelwagen wheel on cars, the Willys on the buggy,
the M5 halftrack wheel on trucks, the R75 motorcycle wheel on the chariot —
and Galang's own wheel on the Fusion Flea (`FOVehicles.WHEELS`, picked by the
definition's `wheel`). Roadkill's bone-rigged cars turned out to have the
wheel bones and no wheels on them, so bone-placed wheels get the model too,
hung from the hub at the model's radius; only the jeep-rigged Sentry models,
whose meshes carry their own wheels, keep theirs hidden. Digger's wheels are
thin along X and take a yaw of 0 on the left and 180 on the right, as LVS's
own definitions do; the Flea's and the R75 are thin along Y and take a
quarter turn more.

**Seats are set in game.** The guesses are wrong on half the vehicles and
there is no way to see a seat from here, so staff place them:
`/vehicleseat driver` while standing where the driver should sit and looking
at the vehicle stores that position and facing in the vehicle's frame,
`/vehicleseat add` appends a passenger, `/vehicleseat view` puts the driver's
first-person view where the asker's eyes are, `clear` forgets the class,
`show` prints it. The vehicle is respawned on the spot so the result is seen at
once. Kept per class in `ix.data` ("vehicleseats"); the helper's
`FOVehicles.SeatOverride` reads it when a vehicle is built, and what is set
there beats the definition. Once a set is right, its numbers belong in the
definition — and the first round's do: the buggy, chariot, classic truck,
Fusion Flea, Hermes, Highwayman, Humvee, junk car and saucer carry the
measured seats now, and so do the fuel truck and the Vertibird. A stored set
that matches its definition can be forgotten with `/vehicleseat clear`.

**The fuel truck's cab is at +X**, unlike the classic truck it was assumed to
share a layout with (its measured yaw was 3, the classic truck's -176); a
round of driving it backwards said so.

**The facing came from the same numbers.** The driver's yaw in the vehicle's
frame is which way the model's front points: the buggy, chariot, classic
truck and Hermes measured ±177 — their fronts are **-X**, which is why the
chariot drove backwards — and say `forwardYaw = 180`; the Flea and the saucer
measured 0, the Highwayman and junk car -90, the Humvee 90 (its rig's).

**Seated players sit.** Helix picks a seated player's animation from
`ix.anim.<class>.vehicle[<seat class>]`, and the schema's table had a hold
type called "vehicle" instead, so everybody in an LVS seat played the crouch
idle standing up through the roof. It is keyed by seat class now:
prisoner pods (every LVS seat) and chairs play `sit`, the jeep `drive_jeep`.
And the schema's own `Schema:TranslateActivity` — which answers before
Helix's for these models and never looked at seats — reads that table first
for anybody in a vehicle (gotcha 34).

**Seats are typed in.** Every box-guessed vehicle has an explicit `driver` and
`passengers` in its `Build` table, worked out from each mesh's roof profile
(where the cab is, which end is the front); the jeep-rigged ones sit at the
rig's `vehicle_driver_eyes`. The Highwayman is told its front is at -Y
(`forwardYaw = -90`): its mesh is long along X and its idle pose turns it a
quarter turn, which the Roadkill models that were built along Y also do — that
is what made them come out facing +X.

Every guess has an override in the definition's `Build` table (`driver`,
`passengers`, `radius`, `forwardYaw`, `forwardSign`, `axleInset`, `track` and
so on), and **`fo_vehicle_report`** in the server console, looking at a
vehicle, prints the box, the bones, the attachments, the seats and where the
wheels came from — paste that back and the numbers get tuned by hand.

**Orientation is the risk.** Decoding the models' idle poses shows several
were built long along Y and turned ninety degrees by their idle animation
(Roadkill's buggy, chariot, Hermes, and the Vertibird come out facing +X, as
LVS needs). The Sentry Humvee, APC and tank read as facing +Y after their
turn, and the two Galang military trucks are static props built along Y. For
those, `FOVehicles.Frame` faces the wheels along the long axis and hands LVS a
`ForwardAngle` for the axles, which is what LVS's own rig method does for a
rotated rig — the wheels roll the right way, but the third-person camera
and the exhaust follow the entity's own axes. If one of them drives sideways
in testing it needs a recompile with a yaw, not more Lua.

### Flying one

The controls are LVS's, from its own key table, and two of them were read as
the aircraft flying backwards:

- **W / S** are the throttle, up and down. **A / D** yaw. **Shift** holds a
  hover. **Ctrl** toggles third person, **Alt** (held) is free look, **R**
  starts the engine.
- **Pitch and roll are the mouse.** LVS is pull-to-dive: mouse forward lifts
  the nose, and a helicopter with its nose up climbs *backwards* — "press W
  to go up and I move up and back", "it flies backwards". The Fallout aircraft
  flip that axis (`FOVehicles.HeliInput`, wrapped round LVS's own input), so
  the mouse pushes forward to dive; `fo_flight_invert 0` in the console is
  LVS's own feel back, per player.
- **Third person** in LVS keeps the mouse on the stick, so the camera is
  nailed behind the aircraft and free look only swings it to a fixed front
  view that snaps back when released. With free look held in third person,
  the Fallout aircraft hand the mouse to the camera instead — a car's orbit
  (`LVS:CalcView`) — and hold their attitude meanwhile; the keys still steer.
- **It rested nose-high and took off that way.** LVS holds attitude: thrust
  is along the airframe's own up, from a point straight above the mass
  centre, so nothing rights the airframe but the pilot. A helicopter that
  rests level never notices; the Vertibird sits on a tail wheel, lifted off
  nose-up, and its thrust pointed back — it climbed away tail first, "like
  the cars did". `FOVehicles.Level`, through LVS's own
  `PhysicsSimulateOverride`, eases both aircraft back to level — but **only
  below 400 units a second**, with no stick input, and the wheels off the
  ground. Righting it at any speed meant a nose held down for level flight
  was pushed back up the moment the mouse stopped, and the thing would only
  ever climb, and **nothing in it steps**. That version switched on and off
  at three hard limits, a speed, an angle and a stick deadzone, and
  `PhysicsSimulate` runs several times a tick: an airframe sitting near any
  of them was kicked on one step and not the next, which is what "unstable
  and very shaky" was. Every term fades, and the correction is proportional
  to the pitch so it goes to nothing as the nose comes level.
- **Turn rate is input over damping, and both were changed at once.** The
  first pass halved `TurnRate*` and near-tripled `ForceAngleDampingMultiplier`
  for weight; LVS settles a turn where the input balances the damping, so the
  Vertibird ended at about nine degrees a second — a ten-second about-turn,
  which is "I can't turn and I fly into a wall". The rates are LVS's own now
  and only the damping is raised. Note `TurnRatePitch` and `TurnRateRoll`
  *divide* the mouse before they multiply the result, so a small number buys a
  twitchy stick and a weak one together. The damping is the other half of
  that trade and it took three passes to place: 2.5 was steady and would not
  turn, 1.5 turned well and wallowed, 2 is both.
- **The camera cannot be moved freely while the mouse is the stick.** That is
  LVS's direct input: it pins the pilot's eye angles every tick so the mouse
  goes to pitch and roll. **Hold Alt** (free look) to look around, in first
  or third person. `lvs_mouseaim 1` is LVS's other scheme, fly-where-you-look
  — the mouse aims, the aircraft follows, and the camera is free — and none
  of the above applies to it.

### Guns

`FOVehicles.MachineGun(self, seat, opts)` and `FOVehicles.Cannon` are
LVS bullet weapons firing from a named attachment when the model has one
(`main_muzzle` on the APC, `main_muzzle_l/r` on the tank) and from a spot in
front of the seat otherwise. The Humvee's gun is the driver's; the APC's and
the Vertibird's belong to seat 2, which is made the gunner seat.

**The Vertibird's front is +X, and it was its `spin` sequence facing it +Y.**
The wings are wider than it is long, so the helper first took the wings for
the length; fixed, it still faced the wrong way, and the reason was the
sequence: its `spin` (the props) has no root-bone data, so playing it drew
the whole airframe in the model's raw pose, nose along +Y, while the hull and
every seat measured against the idle stayed put (gotcha 33). It plays its
idle now and the props are turned by hand on the client — `ixSpinBones` in
its shared file, `FOVehicles.SpinBones` from LVS's `OnFrame`, about the hub
bones' own shafts — decoded from the model's own `spin` animation: both hubs
turn about their **local Y** (pitch in `ManipulateBoneAngles` terms), the same
way round in their own frames, which is opposite ways in the world. The first
guess, roll, had the blades tumbling through the nacelles. Its seats are
measured now, and its pilot looks out from
somewhere other than the seat: a seat placed by standing in it puts the
first-person view at that seat's own eye height, low in the cockpit, so the
driver's view is placed separately — `driverEye` in the definition, or
`/vehicleseat view` stood where the eyes should be — and `FOVehicles.View`,
every vehicle's `CalcViewOverride`, moves the first-person view there. The
command also stores the way the asker was looking, and `FOVehicles.ViewAngles`
(every vehicle's `CalcViewDriver`) turns the first-person view that way,
because LVS's direct-input cockpit view is pinned dead ahead. It is for
aircraft only — a car's driver looks out of the seat — and it takes the
nearest aircraft rather than the one in view, since the cockpit glass is
rarely a place the airframe is in view from. Third person and passengers are
untouched. (`/vehicleseat` finds the
Vertibird now: the look-up walks the parent chain and, when the trace passes
through a model as this one's does, takes the nearest vehicle the line of
sight crosses.)

**Crashes count.** LVS's own collision damage wants a change of speed above
a thousand units a second and then dents the engine a little. Every ground
vehicle gets `FOVehicles.Collision` as its `OnCollision`: above `crash.hull`
(520 by default) the hull takes the excess as damage, and LVS blows a dead
hull up itself after its fire trail. The fuel truck says
`crash = {hull = 320, explode = 520, blast = 480, ...}`: a hard enough crash
destroys it on the spot, and a blast hurts everything within the radius. A
definition can say `crash = false`.

**Turrets turn on bones.** The Chimera and the APC carry `main_yaw` and
`main_pitch` bones with the muzzle attachments hanging off them, but no pose
parameters for LVS's own turret system. `FOVehicles.Aim`, from each one's
`OnTick`, turns those bones toward whatever the seat's occupant is looking at
with `ManipulateBoneAngles` (networked by the engine), and the muzzle follows
the bone. The yaw is measured from the vehicle's **own** front
(`ixVehicleForward`), not the entity's: the Sentry tank's rig faces +Y after
its idle pose, and a turret turned by the entity's yaw pointed ninety degrees
away from where the driver looked. The pitch axis and the two signs are per
model, in the `turret` table, and were guessed; `pitchAxis = "r"` or a
`pitchSign = -1` is the fix if a gun looks the wrong way. **Shells fly along
the occupant's aim** (`FOVehicles.Occupant`, seat 1 the driver, seat N the
N-1th passenger pod), not the entity's axis — the first Chimera shell left
from the model's original front however the turret was turned — and the
APC's gunner is found by pod index, since the wheeldrive base has no gunner
seat of its own.

## Owning one

- **Deploy** (right-click the item) shows a **ghost** of the vehicle that
  follows your aim and turns with J and K — the same placement flow as a crop
  plot or a workbench (`cl_deploy.lua`) — and a left click puts it there, if
  it is within reach and the whole box fits. That is when the item is
  **consumed**; right click cancels and keeps it. The vehicle is
  the item now, owned by your character; the item's name and your name are
  net vars on it, and the HUD says whose it is when you look at one. One of
  ours spawned from the **sandbox menu** is tracked the same way, owned by
  whoever spawned it (`PlayerSpawnedSENT`), so it can be packed like any other.
- **Only the owner drives** (`vehicleOwnerOnly`; staff with `vehicle.manage`
  too). LVS asks `LVS.CanPlayerDrive` on entry and on the seat switcher;
  passengers ride freely. LVS's own lock (key 1 while driving) works on top.
- **`/vehiclepack`** folds the vehicle you are looking at back into the item,
  while it is empty and not wrecked. **`/vehicles`** says where yours are.
  **`/vehicleremove`** (staff) removes one and returns it to its owner.
- **Left with nobody in it** for `vehicleDespawnEmpty` seconds (3600) it is
  **removed**, item and all — the sweep runs every thirty seconds. A destroyed
  vehicle is gone with its wreck (`DeleteOnExplode`), and a restart clears the
  map. Nothing is refunded; a vehicle you want to keep is one you pack up.
- **Caps**: `vehicleMaxPerPlayer` (1) and `vehicleMaxTotal` (24). That, and
  nothing standing empty, is the optimisation.

## Two things found the first time out

- **`SetupBones` does not exist on the server.** The helper's throwaway
  posed copy called it, every `Build` died on the spot, and every Fallout
  vehicle came out with no seats and no wheels while LVS's own Sherman (whose
  `OnSpawn` is Blu's) worked. The server's bone cache is filled by `Spawn`.
- **The driver's body sat in the turret.** LVS hides a seated player inside an
  armoured car with `SetNoDraw`, and the schema's bone-merged body parts are
  drawn by the engine on their own. `cl_bodyparts.lua` now gives the parts the
  player's flag every half second.

The Vertibird turns slower and is damped harder than LVS's small helicopters
(`TurnRate*` down, `ForceAngleDampingMultiplier` 2.5) because it is a big
airframe and the first numbers made it twitch; its eight cabin seats are typed
in, two rows of two either side of the centreline. Its props turn by bone
manipulation on the client (see above; the `spin` sequence is the one thing
it must not play). The orbital drop drone
(`sh_orbital.lua`) flies the same model's `vb02_fly` variant, gear up, which the
Trailblaze junction brought in. The saucer is turned and damped the same way,
harder still — at its size the first numbers had it wallowing "all over the
place".

## Content

Five junctions were added to `garrysmod/addons/` (see `02-server-setup.md`):
`lvs_framework_2912816023`, `lvs_cars_3027255911` (the Sherman and its base),
`phoenix_vehicle_content_3495732900` (Roadkill's and Galang's models),
`divide_trailblaze_1_3665625103` (the Sentry models) and
`divide_trailblaze_2_3665637618` (their materials). **Clients need the same
five workshop ids on the collection.**
