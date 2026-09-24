AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

--[[
	The server half of a wastelander. Everything VJ needs to know is set
	here; everything that makes one THIS wastelander comes from the preset
	`ix.npc.Dress` writes onto it after it spawns.
]]

ENT.Model = {"models/phoenix/humans/animations.mdl"}
ENT.StartHealth = 100
ENT.HullType = HULL_HUMAN
ENT.BloodColor = VJ.BLOOD_COLOR_RED

--- A preset says which; hostile until one does.
ENT.VJ_NPC_Class = {"CLASS_FO_HOSTILE"}

--[[
	THE MOVEMENT BLENDS ARE DRIVEN HERE, NOT BY VJ, and this is the whole
	reason these NPCs stood still with everything else about them right.

	Every walk and run on this model is a nine-way blend on `move_x` and
	`move_y`; there is not one plain travelling sequence among its 667. An
	engine NPC takes its move speed from the sequence it is PLAYING, so
	those two parameters do not merely choose which cycle is shown - they
	decide whether the NPC has any ground speed at all. At rest they select
	the cycle in the middle of the blend, which is the idle, and the idle
	travels nowhere.

	VJ HAS A MODE FOR EXACTLY THIS and it is the one to use. I turned it
	off on the theory that `VJ.GetMoveDirection` cannot start the NPC off,
	because it returns false unless `IsMoving()` is already true and an NPC
	with no ground speed cannot be moving. That was wrong. `IsMoving` asks
	the NAVIGATOR whether a goal is active, not whether the body has
	travelled - it is true from the instant the walk task begins, one think
	before any of this matters.

	Driving the parameters by hand instead cost three things that only this
	flag switches on:

	  - `OverrideMoveFacing` turns the NPC to face its own waypoint. Without
	    it nothing does, and they walked around without looking where they
	    were going.
	  - A path that fails as FAIL_NO_ROUTE_ILLEGAL does not throw the
	    schedule away, which is the exemption VJ wrote for models that move
	    like this one. Without it they re-planned constantly, which is the
	    "random and dumb" wandering.
	  - The parameters are set ONLY while the navigator has somewhere to be.
	    Keying them off which sequence is playing looks equivalent and is
	    not: a standing NPC in a sequence that shares an activity with a
	    walk got pointed at a stale waypoint, so it played a travelling
	    blend, with a travelling ground speed, while the engine was not
	    moving it anywhere. That is walking in place, exactly.

	`ix.npc.Anims` still decides WHICH blend plays and `OnThink` still puts
	the standing pose right. What travels is VJ's again.

	The one thing it does not cover is `WalkItself`, which steps the body
	by hand once the engine has failed to path, and so is never "moving" as
	far as the navigator is concerned. VJ would zero the two parameters on
	every think of that, so the flag is switched off for exactly as long as
	the stepping lasts and handed back afterwards (`OnThink`).
]]
ENT.UsePoseParameterMovement = true

--[[
	NEVER BREAK OFF, which is the difference between a wastelander and a
	soldier and, as it turns out, the whole of "they just stand there and
	shoot me".

	VJ starts a chase in exactly one place, `MaintainAlertBehavior`, and
	that returns immediately while `TakingCoverT` is in the future. Three of
	its own behaviours keep pushing that forward, and in a real firefight
	they never stop:

	  - RETREAT. Inside `Weapon_RetreatDistance` (150) it backs away and
	    sets the timer two seconds on, every think. Walk up to one and it
	    can never chase again while you stand there.
	  - COMBAT DAMAGE RESPONSE. Every time it is SHOT it hides behind
	    something or runs to a covered spot, and sets the timer three to
	    five seconds on. Shooting at it is what stops it coming for you.
	  - The cover schedule that follows sets it five seconds on again.

	Together they are a wedge: the more of a fight it is in, the less it
	moves, and what movement is left is away from you, which is exactly
	what "sometimes move but not towards you" was.

	Both are off. These are raiders and mercenaries, not a fireteam; they
	walk into your shotgun. `npcTakeCover` puts the tactics back for anyone
	who wants them.
]]
ENT.Weapon_RetreatDistance = 0
ENT.CombatDamageResponse = false

--[[
	AND IT RELOADS WHERE IT STANDS.

	With `Weapon_FindCoverOnReload` a VJ human more than 650 units from its
	enemy does not reload at all: it starts a schedule to run to cover
	first, and only reloads in that schedule's FINISH handler. The weapon
	state is set to RELOADING with no time limit, so nothing puts it back if
	the schedule never finishes - no cover found, no route to it, or
	anything at all replacing the schedule, which a chase does. The NPC then
	stands at zero rounds, reloading for good, unable to fire and skipped by
	every combat behaviour, because all of them want a READY weapon. That is
	the empty-gun statue in the report: clip 0, weapon state 2, nothing
	fired for a minute.

	Off, the reload is a gesture played where it stands, with a timer that
	refills the clip when the animation ends. `OnThink` keeps a watchdog on
	the state anyway, because "reloading, with no time limit" is a state
	worth never trusting.
]]
ENT.Weapon_FindCoverOnReload = false

ENT.SightDistance = 6500
ENT.SightAngle = 170
ENT.TurningSpeed = 24
ENT.CanOpenDoors = true

--[[
	EYES AT HEAD HEIGHT. The animation model's `$eyeposition` is 0 0 0 -
	its eyes are at its feet - and an NPC looks out from its eyes, so every
	line of sight ran along the ground and stopped at the first pebble.
	That was "a very small aggro range" and nobody ever shooting. The
	engine's view offset is set to a standing head.
]]
ENT.ixEyeHeight = 64

--- They stand where they are put; the pod is their post.
ENT.FollowPlayer = false
ENT.IdleAlwaysWander = false
ENT.CallForHelp = true
ENT.CallForHelpDistance = 1500

--- A wastelander without a gun still stands and fights with what it has.
ENT.Weapon_UnarmedBehavior = false

--[[
	NO FISTS WITH A RIFLE. VJ's humans punch whoever gets close, whatever
	they hold, with the melee table - which on this model is a delta swing
	that shows as nothing: "it starts punching you". A gun is fired at any
	range, and a melee weapon strikes through the weapon itself.
]]
ENT.HasMeleeAttack = false
--[[
	Set for real in `ix.npc.Dress` from `npcShootOnTheMove`; false here so
	VJ never grants the move-and-shoot capability at spawn only for it to
	be taken away a moment later.
]]
ENT.Weapon_CanMoveFire = false
ENT.Weapon_Strafe = false
ENT.Weapon_MaxDistance = 3500

--[[
	NO VJ CORPSE EXTRAS AND NO VJ WEAPON DROP. The body is the schema's -
	`OnCreateDeathCorpse` hands VJ's ragdoll to `ix.corpse` with the recipe
	the NPC was drawn with - and what it drops is the schema's ITEM, by
	the preset's chance, not a VJ SWEP a player could pick up and hold.
]]
ENT.HasDeathAnimation = false
ENT.DropWeaponOnDeath = false

local BASE = "npc_vj_human_base"

--------------------------------------------------------------------------------
-- Animations
--------------------------------------------------------------------------------

--[[
	WHAT THE ENGINE IS TOLD, AND WHAT VJ PLAYS ITSELF. See `ix.npc.Anims`.

	The engine drives idle, walking, running and crouching through
	`TranslateActivity` and takes an ACTIVITY back - a number - so those are
	answered with activities this model actually has. VJ plays attacks,
	reloads and melee through its own player, which takes a sequence NAME
	when the sequence has no activity, so those are answered by name in
	VJ's `AnimTbl_*` tables.

	Both are set whenever the weapon changes, and `TranslateActivity` is
	answered from our table BEFORE VJ's, so it does not matter whether VJ
	has rebuilt its own table yet - the first version's T-pose was every
	NPC asking the engine for an ACT_IDLE this model does not have.
]]
function ENT:ApplyAnims()
	local anims = ix.npc.Anims(self, self:GetActiveWeapon())

	self.ixAnims = anims.activities

	self.AnimationTranslations = self.AnimationTranslations or {}

	for act, activity in pairs(anims.activities) do
		self.AnimationTranslations[act] = activity
	end

	--- Stance, gesture, reload; see `ix.npc.Anims` for why they are split so.
	self.AnimTbl_WeaponAttack = anims.attack
	self.AnimTbl_WeaponAttackCrouch = anims.crouchAttack
	self.AnimTbl_WeaponAttackGesture = anims.gesture and {anims.gesture} or false
	self.AnimTbl_WeaponReload = anims.reload
	self.AnimTbl_WeaponReloadCovered = anims.reload
	self.AnimTbl_MeleeAttack = anims.attack

	self.ixIdleSequence = anims.idleSequence
	self.ixAimSequence = anims.aimSequence
	self.ixStanding = anims.standing
	self.ixStandingActs = anims.standingActs
	self.ixTravelling = anims.travelling
	self.ixTravellingActs = anims.travellingActs
	self.ixWalkSequence = anims.walkSequence
end

function ENT:SetAnimationTranslations(wepHoldType)
	self:ApplyAnims()
end

--[[
	VJ FIRST, THEN OURS. VJ's own translation is where an alerted NPC
	decides to fire while it walks - it turns ACT_RUN into ACT_RUN_AIM and
	sets its attack state on the way - and it hands some activities back
	raw, without looking in the table (an alerted idle comes back as
	ACT_IDLE_ANGRY, which this model does not have). So VJ answers first,
	and whatever number it answers with is put through our table once
	more. The first version answered before VJ and an NPC backing away from
	a close enemy never fired a shot while it did.
]]
function ENT:TranslateActivity(act)
	local result = baseclass.Get(BASE).TranslateActivity(self, act)

	--[[
		AN ARMED NPC WITH AN ENEMY AIMS. VJ turns a plain idle into an
		angry one only while its own `Alerted` flag is set, and that is a
		state with a timeout of its own, so an NPC shooting at somebody was
		not always flagged with it - and a plain idle on this model is the
		unarmed one, arms at the sides. Having an enemy is the honest test.
	]]
	if (result == ACT_IDLE and self.ixAimSequence
	and IsValid(self:GetActiveWeapon()) and IsValid(self:GetEnemy())) then
		result = ACT_IDLE_ANGRY
	end

	local ours = isnumber(result) and self.ixAnims and self.ixAnims[result]

	return ours or result
end

function ENT:OnWeaponChange(newWeapon, oldWeapon, invSwitch)
	self:ApplyAnims()
end

--[[
	WHAT IT IS STANDING IN, decided here rather than asked of the engine.

	Two things went wrong by leaving it to activities. Three sequences share
	the standing-idle activity and one of them is somebody hanging on a
	cross, so an idle NPC sometimes hung in the air. And an armed one that
	should have been holding its aim landed on the hold type's LOWERED pose
	instead - gun down, which read as "still holstered" while it shot.

	So every think: if the NPC is standing in one of a known short list of
	standing poses, and it is not the one it should be in, it is put into
	that one at the same cycle. Nothing outside that list is touched, so a
	walk, a reload and a swing all run to their end; and the aim is a pose
	the gesture-based attacks layer over (gotcha 36).
]]
function ENT:OnThink()
	--- Kept, in case anything of VJ's puts the default back.
	if (self:GetViewOffset().z < 8) then self:SetEyes() end

	--[[
		THE STEPPING IS NOT DONE HERE. VJ thinks about fifteen times a
		second, and a position moved fifteen times a second is fifteen
		visible jumps a second: the client interpolates between the
		positions the server sends, and there is nothing to interpolate
		when the server holds still between them. It steps from the
		server's own frame instead - see `ix.npc.walkers` in `sv_npc.lua` -
		which is a few times smaller a step, several times more often.
	]]
	if (ix.npc and ix.npc.walkers) then ix.npc.walkers[self] = true end

	--[[
		AND THE ENGINE IS KEPT TOLD. VJ pins an enemy back to neutral every
		time it drops one (`ResetEnemy` does it with a priority of ten), and
		the engine will not build enemy memory for anything it does not
		hate - so the NPC ends up chasing a last known position that was
		never recorded, which is the map origin. One comparison a think; it
		writes only when the answer is wrong. See `ix.npc.Relate`.
	]]
	local target = self:GetEnemy()

	if (IsValid(target) and self:Disposition(target) ~= D_HT) then
		self:AddEntityRelationship(target, D_HT, 10)
	end

	--[[
		AND A RELOAD THAT NEVER ENDS IS ENDED. VJ sets the weapon state to
		RELOADING with no time limit and relies on an animation timer to put
		it back; every path that skips that timer leaves the NPC holding an
		empty gun for good, and a weapon that is not READY is skipped by
		every one of VJ's combat behaviours. Four seconds is longer than any
		reload this model has.
	]]
	if (self.GetWeaponState and self:GetWeaponState() == VJ.WEP_STATE_RELOADING) then
		self.ixReloadingSince = self.ixReloadingSince or CurTime()

		if (CurTime() - self.ixReloadingSince > 4) then
			local held = self:GetActiveWeapon()

			if (IsValid(held) and held.SetClip1) then held:SetClip1(held:GetMaxClip1()) end

			self:SetWeaponState()

			self.ixReloadingSince = nil
			self.ixReloadsFixed = (self.ixReloadsFixed or 0) + 1
		end
	else
		self.ixReloadingSince = nil
	end

	self:Chase(target)

	local walkingItself = (self.ixWalkingUntil or 0) > CurTime()

	--- The stepping has stopped, so VJ has the legs back; see `WalkItself`.
	if (not walkingItself and self.ixHandsOffLegs) then
		self.UsePoseParameterMovement = true
		self.ixHandsOffLegs = nil
	end

	--[[
		STANDING OR MOVING, for the gestures. Every shot and every reload on
		this model is a two-way blend on the pose parameter `standing`: 100
		plays the version made for standing still (`2hrattack7_stand`), 0
		the version made for walking (`2hrattack7_move`). Nothing on the
		server, in Helix or in VJ ever sets it, so it sat at the 0 end and a
		wastelander holding its ground fired and reloaded with the arms of
		one on the move. It is set here from what the body is actually doing.
	]]
	self:SetPoseParameter("standing", (walkingItself or self:IsMoving()) and 0 or 100)

	--- A step of its own is a movement; leave the pose alone while it walks.
	if (walkingItself) then return end

	--[[
		Alerted is a STATE with a timeout, not a fact about right now, and
		a reloading NPC is not "ready" - both were in this test and both
		let an NPC in a firefight fall back to the unarmed idle. What
		matters is that it has a gun out and something to point it at.
	]]
	local aiming = self.ixAimSequence and IsValid(self:GetActiveWeapon())
		and (IsValid(self:GetEnemy()) or self.Alerted)
		and self:GetWeaponState() ~= VJ.WEP_STATE_HOLSTERED
	local wanted = (aiming and self.ixAimSequence) or self.ixIdleSequence

	if (not wanted or self:IsMoving()) then return end

	local current = self:GetSequenceName(self:GetSequence())

	if (current == wanted or not self:ixMayCorrect()) then return end

	local cycle = self:GetCycle()

	self:ResetSequence(wanted)
	self:SetCycle(cycle)
end

--[[
	A STEP AT A TIME, WHERE THE MAP HAS NO NODES TO WALK ON.

	The engine will not move an NPC a single unit without a node graph, and
	some maps ship none - see `ix.npc` for why this one cannot be given one.
	So the NPC walks itself, and the rules are deliberately timid, because
	moving an NPC by hand is how you end up with one inside a wall:

	  - only when the engine is not already moving it, so a map WITH nodes
	    is never interfered with,
	  - only toward an enemy it can actually see, and only while further off
	    than the distance it wants to fight from,
	  - never into anything solid: the whole hull is swept ahead first,
	  - never off a ledge: there must be ground under the far end of the
	    step, which is also what keeps it out of the void.

	It cannot go round a corner and it stops at the first wall. That is the
	honest limit of moving without a path, and it is still better than a
	wastelander rooted to the spot.
]]
function ENT:WalkItself()
	--[[
		THE MAP DECIDES, NOT THE MOMENT. Asking only `IsMoving` was wrong:
		an NPC that the engine is about to move, or has just finished
		moving, is not moving right now, so this stepped in between the
		engine's own steps - which is two things moving one body, and looks
		exactly like it. On a map with a node graph none of this should ever
		run, and now none of it does.
	]]
	if (not ix.config.Get("npcWalkWhenStuck", true)) then return end

	--[[
		ONLY ONCE THE ENGINE HAS BEEN GIVEN ITS THREE CHANCES AND FAILED ALL
		OF THEM. The old gate was "does this map have a node graph", which
		read the `.ain` off the disk - and a graph on the disk is not the
		same thing as a graph that can route. This map has 8192 nodes and
		`NavSetGoalPos` still answers false across two thousand units, so
		that gate was letting a wastelander stand and watch somebody walk
		away because a FILE existed.

		`ixChaseStuck` only reaches three after `ENT:Chase` has asked for a
		path straight at the enemy, a path to somewhere that can see them,
		and a path to their position, and measured that none of the three
		moved the body an inch. That is a fact about this NPC and this spot,
		not a fact about the map.
	]]
	if ((self.ixChaseStuck or 0) < 3) then return end
	if (self.ixHoldsGround or self:IsMoving()) then return end

	--- Never move a body that is already in the air; that is how they end up under the map.
	if (not self:IsOnGround()) then return end

	local enemy = self:GetEnemy()

	if (not IsValid(enemy) or not self:Visible(enemy)) then return end

	local from = self:GetPos()
	local flat = enemy:GetPos() - from

	flat.z = 0

	if (flat:Length() <= (self.ixChaseDistance or 250)) then return end

	flat:Normalize()

	--[[
		FrameTime, not a clamp on CurTime: this runs once a server frame
		now, and the distance covered has to be the same whatever the
		server's frame rate is, or the NPC walks at a speed that depends on
		how busy the server happens to be.
	]]
	local now = CurTime()
	local elapsed = math.Clamp(now - (self.ixLastStep or now), 0, 0.1)

	self.ixLastStep = now

	local step = flat * (ix.config.Get("npcWalkSpeed", 55) * elapsed)

	if (step:Length() < 0.1) then return end

	--- Nothing solid in the way, measured with the body's own hull.
	local mins, maxs = self:OBBMins(), self:OBBMaxs()
	local lift = Vector(0, 0, 18)
	local ahead = util.TraceHull({
		start = from + lift,
		endpos = from + step + lift,
		mins = Vector(mins.x, mins.y, 0),
		maxs = Vector(maxs.x, maxs.y, math.max(maxs.z - 18, 8)),
		filter = self,
		mask = MASK_NPCSOLID
	})

	if (ahead.Hit) then return end

	--- And ground to put its feet on, which is what stops it walking off things.
	local landing = from + step
	local ground = util.TraceLine({
		start = landing + lift,
		endpos = landing - Vector(0, 0, 40),
		filter = self,
		mask = MASK_NPCSOLID
	})

	--[[
		A STEP, NOT A DROP. Without this the landing was accepted wherever
		the downward trace found floor, so a step off the lip of anything
		put the body straight down at the bottom of it - "falling through
		the map". A step may rise or fall by a stair's height and no more.
	]]
	if (not ground.Hit or math.abs(ground.HitPos.z - from.z) > 18) then return end

	self:SetPos(ground.HitPos)

	--- Look like it, too.
	if (self.ixWalkSequence) then
		local sequence = self:LookupSequence(self.ixWalkSequence)

		if (sequence and sequence >= 0 and self:GetSequence() ~= sequence) then
			self:ResetSequence(sequence)
		end
	end

	--[[
		Its own step, so its own blend - and VJ keeps its hands off it.
		VJ zeroes these on every think the NAVIGATOR is idle, and a body
		walked by hand never gives the navigator anything to do, so the walk
		kept collapsing to the idle at the centre of the blend ten times a
		second. Its pose-parameter movement is switched off for exactly as
		long as this stepping lasts; `OnThink` hands it back.
	]]
	self:SetPoseParameter("move_x", 1)
	self:SetPoseParameter("move_y", 0)

	self.UsePoseParameterMovement = false
	self.ixHandsOffLegs = true

	--- Long enough to outlast a VJ think, so the pose is left alone while walking.
	self.ixWalkingUntil = now + 0.2
end

--[[
	Whether the sequence playing now is one the NPC travels on: named in its
	hold type's tree, or sharing an ACTIVITY with one that is. The second
	half is what catches the blends no list could name - see `ix.npc.Anims`.

	Nothing is driven from this any more; the pose parameters are VJ's
	again (see `UsePoseParameterMovement` at the top). It answers the
	report, and it is the same question the standing/travelling split in
	`ix.npc.Anims` is built on: a pose the NPC travels on is never a pose to
	correct it out of.
]]
function ENT:ixTravels()
	local sequence = self:GetSequence()

	if (self.ixTravelling and self.ixTravelling[self:GetSequenceName(sequence)]) then
		return true
	end

	local act = self:GetSequenceActivity(sequence)

	return (self.ixTravellingActs and act and self.ixTravellingActs[act]) == true
end

--[[
	AN ENEMY IS NEVER WRITTEN OFF AS UNREACHABLE.

	The engine keeps a list of entities it has decided it cannot get to, and
	`TASK_GET_PATH_TO_ENEMY` refuses BEFORE trying anything when the enemy is
	on it. The list is meant to be self-clearing: an entry expires on its own
	and is thrown out the moment the entity moves more than about 120 units
	from where it was written down.

	VJ never lets it expire. The first time a path fails the engine raises
	COND_ENEMY_UNREACHABLE, `MaintainAlertBehavior` sees that and re-writes
	the entry with a fresh two seconds, and from then on it re-writes it
	every two seconds because it is now reading its own note back. One failed
	path and the NPC will never again attempt to walk to that player. Worse,
	`RememberUnreachable` calls `ForceChooseNewEnemy` on the way past, so
	each re-write also DROPS the enemy - which is where the reports full of
	`enemy nil` were coming from.

	The engine still raises the condition, which is transient and fine; what
	stops here is the note that makes it permanent. `Chase` handles a genuine
	unreachable by pathing to the enemy's POSITION instead, which is a task
	that does not consult this list at all.
]]
function ENT:RememberUnreachable()
end

--[[
	KEEPING THE AIM ON THEM, and letting it go when they are gone.

	The aiming itself belongs to the model. The engine plays the aim-yaw and
	head layers on every sequence (they are AUTOPLAY in the model), and
	`2hraim` brings its own pitch layer with it as an autolayer, all of
	them driven by pose parameters. VJ drives those parameters here, but
	only while its weapon attack state is set - VJ's record of its OWN
	attack animation, which a gun on this model no longer has (see
	`ix.npc.Anims`). The schema sets that state when it fires and VJ clears
	it on the next reload, chase or pause, so the aim froze wherever it last
	pointed and stayed there, twisted, through the walk that followed and
	the wandering after the fight.

	So it tracks whenever there is somebody to track, and eases back to
	straight ahead when there is not, or when VJ asks for a reset. The sums
	are VJ's own - the angle to the target's aim point less the NPC's
	facing, wrapped to a half turn - and the sign matches the model:
	`2hraimpitch` blends from its down pose at +90 to its up pose at -90,
	so a positive pitch aims down, as Source's does. Roll is left alone;
	nothing on this model wants it.
]]
function ENT:UpdatePoseParamTracking(resetPoses)
	if (not self.HasPoseParameterLooking) then return end

	local enemy = self:GetEnemy()
	local pitch, yaw = 0, 0

	if (not resetPoses and IsValid(enemy)) then
		local eyes = self:EyePos()
		local at = self.GetAimPosition and self:GetAimPosition(enemy, eyes) or enemy:BodyTarget(eyes)
		local toward = (at - eyes):Angle()
		local facing = self:GetAngles()

		pitch = math.NormalizeAngle(toward.p - facing.p)
		yaw = math.NormalizeAngle(toward.y - facing.y)
	end

	local names = self.PoseParameterLooking_Names or {}
	local speed = self.PoseParameterLooking_TurningSpeed or 10

	for _, pose in ipairs(names.pitch or {}) do
		self:SetPoseParameter(pose, math.ApproachAngle(self:GetPoseParameter(pose), pitch, speed))
	end

	for _, pose in ipairs(names.yaw or {}) do
		self:SetPoseParameter(pose, math.ApproachAngle(self:GetPoseParameter(pose), yaw, speed))
	end

	self.UpdatedPoseParam = true
end

--[[
	CLOSE THE DISTANCE, and do not ask the cover timers for permission.

	This starts VJ'S OWN chase schedule - the same `SCHEDULE_ALERT_CHASE`,
	the same `TASK_GET_PATH_TO_ENEMY` and `TASK_RUN_PATH` - and nothing here
	is hand-rolled movement. What it skips is the queue of guards in
	`MaintainAlertBehavior` that a firefight keeps re-arming; see the note
	on `Weapon_RetreatDistance` at the top of this file. VJ still runs its
	own chase whenever those guards happen to be clear, and starting a
	schedule that is already running is a no-op, so the two do not fight.

	The cooldown is here because asking for a path is not free and a failed
	one should not be asked for sixty times a second.
]]
function ENT:Chase(enemy)
	if (self.ixHoldsGround or not self.SCHEDULE_ALERT_CHASE) then return end

	if (not IsValid(enemy)) then
		self.ixChaseCheck = nil

		return
	end

	local now = CurTime()
	local distance = self:GetPos():Distance(enemy:GetPos())

	--- Close enough. Standing still and shooting is the right answer here.
	if (distance <= (self.ixChaseDistance or 250)) then
		self.ixChaseCheck = nil

		return
	end

	--[[
		And where somebody has asked for the tactics back (`npcTakeCover`),
		they win: taking cover is worth nothing if something walks the NPC
		straight back out of it. With the tactics off, which is the default,
		there is no timer here to respect.
	]]
	if (self.CombatDamageResponse and (self.TakingCoverT or 0) > now) then return end

	--- Never cancel a reload that has gone looking for somewhere to do it.
	if (self.CurrentScheduleName == "SCHEDULE_COVER_RELOAD") then return end

	--[[
		DID THE LAST ONE ACTUALLY MOVE IT? A chase that starts and then
		stands there is the failure every other check was hiding: the task
		can fail to find a route, the schedule has no fail handler, and so
		the NPC sits in SCHEDULE_ALERT_CHASE at a standstill while every
		test of "is it already chasing" answers yes. Anything calling
		`StopMoving` part way through leaves it in the same state, and a
		gesture reload does exactly that, every reload.

		So a chase is looked at again shortly after it is asked for, and one
		that moved nothing counts against the METHOD rather than against the
		NPC.
	]]
	local stalled = false

	if (self.ixChaseCheck and now > self.ixChaseCheck) then
		self.ixChaseCheck = nil

		--[[
			MEASURED AS GROUND COVERED, not as `IsMoving`. That answers "does
			the navigator have a goal", and a wander is a goal - so an NPC
			pottering about near its post while ignoring the player counted
			as a chase that worked, the counter was reset every time, and
			the escalation below never once ran. Distance from where the
			chase began cannot be misread that way.
		]]
		local moved = self.ixChaseWhere
			and self:GetPos():DistToSqr(self.ixChaseWhere) > (24 * 24)

		--[[
			Ground the NPC covered ITSELF is not the engine agreeing to path.
			Without this the hand-stepping switched itself off: it moved the
			body, the body having moved reset this counter, the counter being
			low is what stops the hand-stepping, and the NPC lurched forward
			a foot every few seconds instead of walking.
		]]
		if (moved and (self.ixWalkingUntil or 0) > now) then moved = false end

		if (moved) then
			self.ixChaseStuck = 0
		else
			stalled = true
			self.ixChaseStuck = (self.ixChaseStuck or 0) + 1

			--- That method moved nothing from here, so the next one gets a turn.
			self.ixChaseMethod = ((self.ixChaseMethod or 0) + 1) % 3
		end
	end

	if (not stalled) then
		if (self:IsMoving()) then return end
		if ((self.ixNextChase or 0) > now) then return end
		if (self.CurrentScheduleName == "SCHEDULE_ALERT_CHASE") then return end
	end

	self.ixNextChase = now + 0.5
	self.ixChaseCheck = now + 0.4
	self.ixChaseWhere = self:GetPos()

	--- Kept for the report, so a reading taken up close still says whether it chases.
	self.ixChaseAt = now
	self.ixChaseFrom = distance

	--[[
		THREE WAYS TO GET THERE, all of them the engine's own, tried in turn
		as each is shown not to work. Straight at the enemy is the best path
		and the fussiest: it wants a route to the spot they are standing on,
		which a sparse node graph often cannot give. A line-of-sight chase
		only wants a node that can SEE them. Walking to their position as a
		plain goal is the least particular of the three, and it is the one
		that hands back the pathfinder's own answer - worth keeping, because
		if that says no then the map's nodes do not join these two places
		and no amount of AI will.
	]]
	--[[
		ALL THREE, ALWAYS, IN TURN. Skipping to the position method whenever
		the engine had written the enemy off looked sensible and made things
		worse: on this map that method is the one that fails, and the other
		two were what had been working intermittently. Nothing here knows in
		advance which of the three a given map and a given spot will answer,
		so it keeps asking each of them.
	]]
	--[[
		AND THE ONE THAT WORKED GOES FIRST NEXT TIME. The stall counter used
		to pick the method, and a chase that moved reset the counter to zero
		- so after every success it went back to "straight at you", which on
		this map is the one that never works, and spent a second failing that
		and another failing the second before reaching the one that had just
		succeeded. A method now keeps its turn for as long as it keeps moving
		the body; only a stall hands over to the next.
	]]
	local attempt = self.ixChaseMethod or 0

	self.ixChaseTried = attempt

	if (attempt == 0) then
		self:SCHEDULE_ALERT_CHASE(false)
	elseif (attempt == 1) then
		self:SCHEDULE_ALERT_CHASE(true)
	else
		--[[
			AS FAR TOWARD THEM AS THE GRAPH GOES, and then look again.
			`/npcroute` on this map routed every step it tried toward the
			player and refused only the player's own spot: the graph reaches
			almost all the way and not the last stretch. Asking for the exact
			spot alone threw all of that away. So the full distance is asked
			for first, then three quarters, a half and a quarter of it, and
			the NPC goes to the furthest that builds; the next attempt starts
			from nearer and asks again. Whatever the graph cannot reach at
			the end is short, straight and in plain sight, which is the one
			case the hand-stepping is good at.
		]]
		local from = self:GetPos()
		local goal = enemy:GetPos()
		local reach

		self.ixChaseShare = 0

		for _, share in ipairs({1, 0.75, 0.5, 0.25}) do
			local point = from + (goal - from) * share

			if (self:NavSetGoalPos(point)) then
				reach = point
				self.ixChaseShare = share

				break
			end
		end

		self.ixChaseRoute = self.ixChaseShare == 1

		if (reach) then
			self:SetLastPosition(reach)
			self:SCHEDULE_GOTO_POSITION("TASK_RUN_PATH")
		end
	end
end

--[[
	Whether the pose the NPC is in now is one it may be moved out of: named
	in its hold type's tree, or sharing an ACTIVITY with one that is. The
	second half is what catches the poses no list could name - see
	`ix.npc.Anims`. Its own method so the report can print the same answer
	the correction acts on.
]]
function ENT:ixMayCorrect()
	local sequence = self:GetSequence()

	if (self.ixStanding and self.ixStanding[self:GetSequenceName(sequence)]) then
		return true
	end

	local act = self:GetSequenceActivity(sequence)

	return (self.ixStandingActs and act and self.ixStandingActs[act]) == true
end

--------------------------------------------------------------------------------
-- Living and dying
--------------------------------------------------------------------------------

function ENT:Init()
	self:ApplyAnims()
	self:SetEyes()
end

function ENT:SetEyes()
	local offset = Vector(0, 0, self.ixEyeHeight or 64)

	self:SetViewOffset(offset)
	self:SetSaveValue("m_vDefaultEyeOffset", offset)
end

function ENT:OnDeath(dmginfo, hitgroup, status)
	if (status ~= "Init" or self.ixDied) then return end

	self.ixDied = true

	if (ix.npc and ix.npc.OnDeath) then ix.npc.OnDeath(self, dmginfo:GetAttacker()) end
end

function ENT:OnCreateDeathCorpse(dmginfo, hitgroup, corpse)
	if (ix.npc and ix.npc.OnCorpse) then ix.npc.OnCorpse(self, corpse) end
end
