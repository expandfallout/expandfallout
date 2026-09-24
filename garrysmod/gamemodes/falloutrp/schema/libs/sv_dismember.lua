--[[
	Dismemberment, server side: the roll, the corpse and what falls out of it.

	One hook, on `PlayerDeath`. Everything here happens once, to the body of
	somebody who has already died - there is no per-shot work, and a weapon
	that never kills anybody never costs anything.

	THE CORPSE IS THIS SCHEMA'S, NOT THE ENGINE'S.

	Three bodies exist in this codebase and only one of them is any use here:

	    client.ixRagdoll        Helix's knockout body. `GM:PlayerDeath`
	                            REMOVES it a moment after we would edit it
	    GetRagdollEntity()      the engine's, from `client:CreateRagdoll()` -
	                            DELETED by the engine on the next respawn, so
	                            a dismembered arm lasted five seconds and
	                            usually less
	    ix.corpse               ours: it belongs to nobody, survives the
	                            respawn and lasts `corpseLife`

	Taking limbs off the second one is why "no body appears when you kill
	people so there is no dismemberment" was true and looked like two separate
	faults. See `sh_corpse.lua`.

	AND A HEADSHOT DECAPITATES RATHER THAN DROPPING A HEAD. The head comes off
	the body and that is all that happens; getting one means holding E on a
	body that still HAS one, which is Phoenix's "Head Collection Time" and the
	reason a head is worth having.
]]

if (not SERVER) then return end


--[[
	A burst of blood, and a pool under it.

	`util.Effect("bloodspray")` rather than a particle system: the stock effect
	cannot be missing, where a `.pcf` can be - and `amount` emitters at slightly
	different positions read as one wound opening rather than as one puff.

	The decal is what makes it look like something happened AFTERWARDS. A limb
	that comes off in a shower of red and leaves clean floor behind reads as a
	glitch; the stain is most of the effect.
]]
function ix.dismember.Gore(position, amount)
	for _ = 1, amount do
		local effect = EffectData()

		effect:SetOrigin(position + VectorRand() * 6)
		effect:SetNormal(VectorRand():GetNormalized())
		effect:SetMagnitude(6)
		effect:SetScale(3)

		util.Effect("bloodspray", effect)
	end

	local trace = util.TraceLine({
		start = position,
		endpos = position - Vector(0, 0, 160),
		mask = MASK_SOLID_BRUSHONLY
	})

	if (trace.Hit) then
		util.Decal("Blood", trace.HitPos + trace.HitNormal,
			trace.HitPos - trace.HitNormal)
	end
end

--- One of the gib pack's sounds at a position, or nothing if it is missing.
local function Noise(kind, position, level, pitch)
	local path = ix.dismember.Sound(kind)

	if (not path) then return end

	sound.Play(path, position, level or 75, pitch or math.random(90, 110))
end

--------------------------------------------------------------------------------
-- Pieces
--------------------------------------------------------------------------------

--[[
	One gib, thrown out of the wound.

	`COLLISION_GROUP_DEBRIS` so a pile of them cannot block a doorway or be
	stood on, and `SafeRemoveEntityDelayed` so the world is not slowly filling
	up with organs - `dismemberGibLife` is exactly Phoenix's "Gib Time".
]]
local function SpawnGib(model, position, life)
	local gib = ents.Create("prop_physics")

	if (not IsValid(gib)) then return end

	gib:SetModel(model)
	gib:SetPos(position + VectorRand() * 4)
	gib:SetAngles(AngleRand())
	gib:Spawn()
	gib:Activate()
	gib:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

	local physics = gib:GetPhysicsObject()

	if (IsValid(physics)) then
		physics:Wake()
		physics:SetVelocity(VectorRand() * 90 + Vector(0, 0, 60))
		physics:AddAngleVelocity(VectorRand() * 200)
	end

	SafeRemoveEntityDelayed(gib, life)
end

--------------------------------------------------------------------------------
-- What is left to pick up
--------------------------------------------------------------------------------

--[[
	Human Flesh, named after whoever it came off.

	CUT OFF A BODY, NOT BLOWN OFF ONE. It used to fall out of a severed arm,
	which made meat a by-product of shooting somebody in the elbow. Taking a
	head is deliberate, it takes three seconds, and you have to stand over
	somebody to do it - so that is where the meat comes from now, and
	`ix.corpse.TakeHead` is the only caller.

	The data goes in AT CREATION rather than being set afterwards:
	`ix.item.Spawn` hands its fifth argument to `ix.item.Instance`, which writes
	it into the row and copies it onto the item BEFORE the callback runs - so
	the thing on the ground is already "Vault Dweller's Flesh" the first time
	anybody looks at it, rather than saying "Human Flesh" until something made
	it look again.
]]
function ix.dismember.DropFlesh(character, position, label)
	if (not ix.item.list.humanflesh) then return end

	--[[
		A NAME OR A LABEL, whichever the caller has. A corpse knows what it was
		("NCR - Trooper") and not necessarily who, which is the same anonymity
		the head carries and for the same reason.
	]]
	local name = character and character:GetName() or label

	if (not name or name == "") then return end

	ix.item.Spawn("humanflesh", position, function(item, entity)
		if (not IsValid(entity)) then return end

		local physics = entity:GetPhysicsObject()

		if (IsValid(physics)) then
			physics:Wake()
			physics:SetVelocity(VectorRand() * 40 + Vector(0, 0, 50))
		end
	end, angle_zero, {
		owner = name,
		charID = character and character:GetID() or nil,
		taken = os.time()
	})
end

--------------------------------------------------------------------------------
-- Taking the limb off
--------------------------------------------------------------------------------

--[[
	Scale the limb's bones to nothing, and say whether this body has them.

	THE RETURN VALUE IS THE CREATURE CHECK. A model with no `Bip01 L Forearm`
	is not a human, and the honest answer to "take its left arm off" is that
	there is no such arm - so nothing else happens either: no gibs, no meat, no
	sound. A deathclaw shot in what Source calls its left arm is simply dead.

	`vector_origin` rather than a small number: a bone scaled to zero collapses
	its children with it, which is why the finger bones are listed but the
	fingertips are not.
]]
--[[
	Take a limb off a body, and this is where two attempts went wrong.

	SCALING BONES IS NOT ENOUGH ON A RAGDOLL, and that is the whole of the
	"stretched limb" problem. A ragdoll's animation bones are driven by its
	PHYSICS OBJECTS - one per limb segment - and bone manipulation is applied
	on top of that. So scaling the upper arm to nothing while the forearm's
	physics object is still out at arm's length leaves the mesh spanning
	between a collapsed shoulder and a hand that is exactly where it always
	was: a long thin cone with a hand on the end, which is what the screenshot
	showed.

	So the physics is collapsed too. Every physics object belonging to the
	limb is moved to the JOINT and frozen, which is what actually removes the
	limb from the world - the mesh has nothing left to stretch towards.

	AND THE WHOLE CHAIN IS SCALED, not just the root. The version that scaled
	only the top bone was an attempt to fix the stretch by assuming Source
	inherits bone scale; it does not do so reliably through `EF_BONEMERGE`, and
	a partial collapse is a guaranteed stretch rather than a possible one.
]]
local function HideBones(ragdoll, limb)
	if (not limb.bones) then return true end

	--[[
		THE SKELETON SAYS WHAT THE LIMB IS, not the list.

		`ix.dismember.CollapseLimb` walks the bone hierarchy from the joint, so
		every bone hanging off it goes - including the ones nobody named. See
		the note on it in `sh_dismember.lua`; the written lists survive as the
		places to START from, and for identifying a hit.
	]]
	--[[
		THE HITGROUP IS PASSED so `CollapseLimb` can decline: limb geometry is
		left alone unless `dismemberHideLimbs` is on. It still answers with the
		bone set, because the creature check - does this model have a human
		skeleton - is the same question either way.
	]]
	local bones = ix.dismember.CollapseLimb(ragdoll, limb, hitgroup)

	if (not bones) then return false end

	--[[
		AND THE PHYSICS IS LEFT ALONE, which took three attempts to arrive at.

		The first version gathered the limb's physics objects at the joint,
		using a joint position from `GetBonePosition` - which answers with the
		ENTITY'S OWN ORIGIN on a ragdoll whose bones are not set up yet, so
		every arm and leg was jammed at the corpse's feet and drew as a sliver
		on the ground.

		The second only froze them with `EnableMotion(false)`, which is worse:
		a frozen physics object is STATIC, so a ragdoll with a frozen arm hangs
		off it. That is "the body still gets stuck mid air" - it was not stuck,
		it was hanging from a limb nobody could see.

		Neither is needed. Every bone in the limb is scaled to nothing, so it
		draws at a single point wherever its root is - and its root is held by
		the shoulder, which never moved. An invisible arm with weight is what
		every gore mod in this game ships; a body hanging from one is not.
	]]

	return true
end

--[[
	WRITE IT DOWN ON THE BODY, as a bitfield of hitgroups.

	A corpse's visible mesh is built on the CLIENT and not necessarily at the
	moment of death - somebody who walks round the corner two minutes later
	builds it then, from nothing but the entity. Bone scaling set at death is
	on the ragdoll, and a mesh bone-merged onto it afterwards has to be told
	separately what is missing, or an arm that was shot off grows back for
	everybody who arrives late.

	A bitfield rather than a list because there are seven hitgroups and this
	has to fit in a networked integer.
]]
local function Remember(ragdoll, hitgroup)
	ragdoll:SetNWInt("ixCorpseGone", bit.bor(
		ragdoll:GetNWInt("ixCorpseGone", 0), bit.lshift(1, hitgroup)))
end

--- Where a limb is, for the gibs and the drop. Falls back to the body.
local function BonePosition(ragdoll, name)
	local index = name and ragdoll:LookupBone(name)

	if (index) then
		local position = ragdoll:GetBonePosition(index)

		--[[
			`GetBonePosition` ANSWERS WITH THE ENTITY'S OWN POSITION when the
			bone has not been set up yet, which on a ragdoll one tick old is
			common - and a "position" that is really the origin puts every gib
			in the same place. Treated as no answer.
		]]
		if (position and position ~= ragdoll:GetPos()) then return position end
	end

	return ragdoll:LocalToWorld(ragdoll:OBBCenter())
end

--[[
	Take the head off a body, and nothing else.

	`sv_corpse.lua` calls this when somebody cuts one off by hand, so a body
	whose head was CUT off and one whose head was SHOT off look identical -
	which they should, and which means there is exactly one piece of code that
	knows which bones a head is made of.
]]
function ix.dismember.Behead(ragdoll)
	if (not IsValid(ragdoll) or ragdoll:IsPlayer()) then return false end
	if (ragdoll.ixRobot) then return false end

	local limb = ix.dismember.Limb(HITGROUP_HEAD)

	if (not limb or not HideBones(ragdoll, limb)) then return false end

	ragdoll:SetNWBool("ixCorpseHeadless", true)

	Remember(ragdoll, HITGROUP_HEAD)


	return true
end

--[[
	HEADPOP: a fatal headshot bursts the head.

	The one piece of dismemberment everybody already knows the name of, and it
	is deliberately not the same code path as a limb: nothing survives, nothing
	drops, and the body is marked headless so nobody can walk over and cut off
	a head that is no longer there.

	It never happens to a PERMANENT KILL - see `sv_dismember`'s death hook.
	A PK'd body has to keep its head, because that head is the one with a name
	on it and destroying it with the shot that earned it would take the trophy
	away from the person who won it.
]]
function ix.dismember.Headpop(ragdoll)
	if (not IsValid(ragdoll) or ragdoll:IsPlayer()) then return false end
	if (ragdoll.ixRobot) then return false end

	local limb = ix.dismember.Limb(HITGROUP_HEAD)

	if (not limb or not HideBones(ragdoll, limb)) then return false end

	Remember(ragdoll, HITGROUP_HEAD)

	ragdoll:SetNWBool("ixCorpseHeadless", true)

	local wound = BonePosition(ragdoll, "Bip01 Neck")
	local bleeds = ragdoll:GetBloodColor() ~= BLOOD_COLOR_MECH
		and ragdoll:GetBloodColor() ~= DONT_BLEED

	if (bleeds) then
		--- Twice a limb's worth, because this is the loud one.
		ix.dismember.Gore(wound, 8)

		for _, gib in ipairs(limb.gibs or {}) do
			SpawnGib(gib.model, wound, ix.config.Get("dismemberGibLife", 30))
		end
	end

	Noise("splat", wound, 85, math.random(85, 100))


	return true
end

--[[
	Do it: bones, gibs, blood, and whatever is left to carry.

	Written as its own function rather than inside the hook because
	`/testdismember` calls it too, and a thing that can only be seen by killing
	somebody is a thing nobody tests.
]]
--- Whether this body has already lost that limb. See `Remember`.
function ix.dismember.Gone(ragdoll, hitgroup)
	return bit.band(ragdoll:GetNWInt("ixCorpseGone", 0),
		bit.lshift(1, hitgroup)) ~= 0
end

function ix.dismember.Apply(ragdoll, hitgroup, character)
	--[[
		NEVER A PLAYER. Nothing in this file has any business scaling the bones
		of somebody who is alive, and the one time it happened the symptom was
		four unrelated-looking faults at once. It is cheaper to refuse here
		than to trust every caller for ever.
	]]
	if (not IsValid(ragdoll) or ragdoll:IsPlayer()) then return false end

	--- A machine has no limbs to take; it comes apart all at once or not at all.
	if (ragdoll.ixRobot) then return false end

	local limb = ix.dismember.Limb(hitgroup)

	if (not limb) then return false end

	--- Twice is not more dismembered; it is two sets of gibs for one arm.
	if (ix.dismember.Gone(ragdoll, hitgroup)) then return false end

	--[[
		WHERE THE WOUND IS, ASKED FIRST. `HideBones` gathers the limb's physics
		at the joint, which moves the very bones this reads - so measuring
		afterwards would put the blood and the gibs wherever the collapse
		happened to land.
	]]
	local wound = BonePosition(ragdoll, limb.bones and limb.bones[1]
		or (limb.gibs and limb.gibs[1] and limb.gibs[1].bone))

	if (not HideBones(ragdoll, limb)) then return false end

	Remember(ragdoll, hitgroup)

	--[[
		A SYNTH DOES NOT SPRAY MEAT. Blood colour is the one property every
		model carries that already answers "is there flesh in here", so a robot
		loses the arm and nothing else happens - no organs, no food.
	]]
	local bleeds = ragdoll:GetBloodColor() ~= BLOOD_COLOR_MECH
		and ragdoll:GetBloodColor() ~= DONT_BLEED

	local life = ix.config.Get("dismemberGibLife", 30)

	if (bleeds) then
		for _, gib in ipairs(limb.gibs or {}) do
			SpawnGib(gib.model, BonePosition(ragdoll, gib.bone), life)
		end

		ix.dismember.Gore(wound, 4)
	end

	--[[
		BONE FIRST, THEN MEAT. Two sounds a beat apart is what a limb coming
		off sounds like; one is a thud that could be anything.
	]]
	Noise("snap", wound, 75)

	timer.Simple(0.08, function()
		if (IsValid(ragdoll)) then Noise("tear", wound, 75) end
	end)

	--[[
		THE CLIENTS ARE NOT TOLD SEPARATELY, and they used to be.

		A bone manipulation set here is carried to every client by the
		`manipulate_bone` entity the engine parents to the ragdoll - late
		joiners and PVS arrivals included. Earlier versions also sent a net
		message so the client would apply it again itself, which put a second
		`manipulate_bone` on every corpse where Phoenix's have one. Two writers
		to one bone table was a variable they do not have; it is gone.
	]]

	--[[
		A HEAD THAT IS GONE IS GONE. The flag is what stops somebody holding E
		on the body afterwards and cutting off a head that is lying in three
		pieces on the floor - and it is a net var, so the tooltip says "the
		head is gone" before they try.

		NOTHING IS DROPPED. Shooting a head off destroys it; the head you can
		carry is the one you took the trouble to cut off a whole body. That is
		the difference between a trophy and loot.
	]]
	if (hitgroup == HITGROUP_HEAD) then
		ragdoll:SetNWBool("ixCorpseHeadless", true)
	end

	if (not bleeds) then return true end

	----------------------------------------------------------- what is left ---

	return true
end

--------------------------------------------------------------------------------
-- What each limb took
--------------------------------------------------------------------------------

--[[
	Damage per hitgroup, while somebody is alive.

	`ScalePlayerDamage` is the only hook handed a hitgroup, which is why the
	armour resistance lives on it too. NOTHING IS RETURNED: returning true here
	means "this damage does not apply", and a bookkeeping listener that
	accidentally answered would make everybody invulnerable.
]]
hook.Add("ScalePlayerDamage", "ixDismember", function(client, hitgroup, info)
	--- Placed by bone where the model did not say; see `Hitgroup`.
	hitgroup = ix.dismember.Hitgroup(client, hitgroup, info:GetDamagePosition())

	if (not ix.dismember.Limb(hitgroup)) then return end

	client.ixLimbDamage = client.ixLimbDamage or {}
	client.ixLimbDamage[hitgroup] = (client.ixLimbDamage[hitgroup] or 0)
		+ info:GetDamage()
end)

--[[
	WHAT KILLED THEM, and `ScalePlayerDamage` is the wrong hook to ask.

	That hook is part of the BULLET path - it exists to scale damage by where
	on the body it landed - and a fall has no hitgroup, so it never fires for
	one. The fall-damage rule was therefore reading a damage type that was
	always whatever the last bullet had been, which for somebody who walked off
	a cliff without being shot first was nothing at all.

	`EntityTakeDamage` fires for every kind of damage there is. Recorded here
	and read a frame after death; `PlayerDeath` is not handed the damage.
]]
hook.Add("EntityTakeDamage", "ixDismemberType", function(target, damageInfo)
	if (not target:IsPlayer()) then return end

	target.ixLastDamage = damageInfo:GetDamageType()

	--- And where, so a death on a model with no hitgroups can still be placed.
	target.ixLastDamagePos = damageInfo:GetDamagePosition()
end)

--[[
	A new body has taken nothing yet, and is not a permanent kill yet either.
]]
hook.Add("PlayerSpawn", "ixDismember", function(client)
	client.ixLimbDamage = nil
	client.ixLastDamage = nil
	client.ixPermakilled = nil

	--[[
		AND ANY DAMAGE THIS LIBRARY LEFT ON THEM IS UNDONE.

		Bone manipulation is not cleared by a respawn - it lives on the entity -
		so while the `ixCorpse` name collision above was live, every player who
		was shot after having died once kept a scaled-away arm or leg for the
		rest of the session, and a frozen physics object with it. The bug is
		gone; the people it happened to are not.

		This costs one loop over a hundred-odd bones on each spawn and it makes
		the fault self-healing rather than something a server owner has to know
		to reconnect for. It is deliberately unconditional: "did we scale this
		player" is exactly the kind of bookkeeping that was wrong in the first
		place.
	]]
	for bone = 0, (client:GetBoneCount() or 0) - 1 do
		if (client:GetManipulateBoneScale(bone) ~= Vector(1, 1, 1)) then
			client:ManipulateBoneScale(bone, Vector(1, 1, 1))
		end
	end

	local physics = client:GetPhysicsObject()

	if (IsValid(physics) and not physics:IsMoveable()) then
		physics:EnableMotion(true)
	end
end)

--[[
	Which limbs are eligible, worst first.

	The killing blow's limb goes to the FRONT whatever it took - a leg that was
	shot off is a leg that was shot off - and everything else has to have taken
	`dismemberLimbDamage`. Deduplicated, because the killing blow is usually
	also the most damaged and dismembering the same arm twice spawns two sets
	of gibs for one arm.
]]
local function Candidates(damage, killing)
	local threshold = ix.config.Get("dismemberLimbDamage", 40)
	local out, seen = {}, {}

	if (ix.dismember.fleshLimbs[killing]) then
		out[#out + 1] = killing
		seen[killing] = true
	end

	local rest = {}

	for hitgroup, amount in pairs(damage or {}) do
		if (ix.dismember.fleshLimbs[hitgroup] and not seen[hitgroup]
		and amount >= threshold) then
			rest[#rest + 1] = {hitgroup = hitgroup, damage = amount}
		end
	end

	table.sort(rest, function(a, b) return a.damage > b.damage end)

	for _, entry in ipairs(rest) do
		out[#out + 1] = entry.hitgroup
	end

	return out
end

--------------------------------------------------------------------------------
-- The roll
--------------------------------------------------------------------------------

--[[
	Which calibre killed them.

	The ITEM, not the weapon - `ix.rarity.HeldItem` is the same lookup the
	damage hook uses, and the item is where a weapon's identity lives. An
	attacker with no item behind their weapon (an admin's spawned SWEP, an NPC,
	a fall) falls through to the default profile, which is what an unlisted
	calibre does everywhere else in this schema.
]]
local function ChanceOf(attacker)
	if (not IsValid(attacker) or not attacker:IsPlayer()) then
		return ix.dismember.Chance("")
	end

	local item = ix.rarity and ix.rarity.HeldItem(attacker,
		attacker:GetActiveWeapon())

	return ix.dismember.Chance(item and item.uniqueID or "")
end

--- How many limbs one death may take off, before it stops being a death.
local MAX_LIMBS = 2

hook.Add("PlayerDeath", "ixDismember", function(victim, inflictor, attacker)
	if (not ix.config.Get("dismemberEnabled", true)) then return end

	--[[
		NOT AGAIN SO SOON. The body is still made - `sv_corpse.lua` has its
		own limit on those - but a person who died ten seconds ago throws no
		gibs and loses no limbs this time. See `dismemberCooldown`.
	]]
	local cooldown = ix.config.Get("dismemberCooldown", 10)

	if (cooldown > 0 and victim.ixDismemberedAt
	and CurTime() - victim.ixDismemberedAt < cooldown) then
		return
	end

	victim.ixDismemberedAt = CurTime()

	--[[
		WHERE THE KILLING BLOW LANDED. `LastHitGroup` is the bullet path's
		answer and keeps the last bullet's for anything else, so a machete
		to the head of somebody shot in the chest a minute ago died of the
		chest wound. Anything that was not a bullet is placed by where the
		damage says it landed, at the nearest bone, and the engine's answer
		is kept only where that says nothing.
	]]
	local last = victim:LastHitGroup()
	local bullet = bit.band(victim.ixLastDamage or 0,
		bit.bor(DMG_BULLET, DMG_BUCKSHOT)) ~= 0

	if (not bullet) then
		local placed = ix.dismember.Hitgroup(victim, HITGROUP_GENERIC, victim.ixLastDamagePos)

		if (placed ~= HITGROUP_GENERIC) then last = placed end
	end

	--- The engine's answer, or the nearest bone's where the model had none.
	local hitgroup = ix.dismember.Hitgroup(victim, last, victim.ixLastDamagePos)
	local chance = ChanceOf(attacker)
	local character = victim:GetCharacter()

	--[[
		READ NOW, USED NEXT FRAME. `PlayerSpawn` clears the damage table, and
		on a server with a short `spawnTime` - or an admin respawning somebody
		on the spot - that can happen before the deferred roll below. Copying
		the reference here costs nothing and removes the race.
	]]
	local damage = victim.ixLimbDamage

	--[[
		A LONG FALL TAKES BOTH LEGS, with no roll at all.

		Everything else here is a chance, because a bullet may or may not tear
		something off. A body that hit the ground hard enough to die of it did
		not maybe break its legs.
	]]
	local fell = bit.band(victim.ixLastDamage or 0, DMG_FALL) ~= 0

	--[[
		A TICK LATER, because the corpse does not exist yet.

		`GM:DoPlayerDeath` creates it and `GM:PlayerDeath` - this hook - runs
		in the same frame, so `GetRagdollEntity` here is a coin toss depending
		on which order the engine happened to call them in. Next frame it is
		always there, and the character is captured above because the player
		may have respawned by then.
	]]
	timer.Simple(0, function()
		if (not IsValid(victim)) then return end

		--[[
			THE ROLL HAPPENS HERE, not in the hook body, because whether this
			was a permanent kill is decided by ANOTHER `PlayerDeath` listener -
			and two listeners on one hook run in `pairs` order, so asking a
			frame later is the only way to ask after both have had their turn.
		]]
		local corpse = victim.ixCorpseBody

		if (not IsValid(corpse)) then return end

		--[[
			THE HEAD FIRST, AND ONLY IF THIS WAS NOT A PERMANENT KILL. A PK'd
			body keeps its head so the named trophy can still be cut off it;
			see `sh_dismember.lua`.
		]]
		--[[
			NO ROLL ON A HEAD. A killing blow to the head bursts it whatever
			delivered it - the calibre's chance is for whether a limb comes
			off, and "sometimes a headshot does nothing" read as a bug every
			single time.
		]]
		if (hitgroup == HITGROUP_HEAD and not victim.ixPermakilled
		and ix.config.Get("headpopEnabled", true)) then
			ix.dismember.Headpop(corpse)
		end

		if (fell) then
			ix.dismember.Apply(corpse, HITGROUP_LEFTLEG, character)
			ix.dismember.Apply(corpse, HITGROUP_RIGHTLEG, character)

			return
		end

		local taken = 0

		for _, limb in ipairs(Candidates(damage, hitgroup)) do
			if (taken >= MAX_LIMBS) then break end

			if (math.random(1, 100) <= chance
			and ix.dismember.Apply(corpse, limb, character)) then
				taken = taken + 1
			end
		end

		--[[
			`ixCorpseBody` IS SET IN THE SAME HOOK, one listener earlier or
			later -
			`sv_corpse.lua` makes the body inside `PlayerDeath` itself while
			this waits a frame, so by now it is always there if it is coming at
			all. `corpseEnabled` off means no body, which means nothing to
			dismember.

			AND IT IS NOT CLEARED AFTERWARDS. `sv_pk.lua` reads the same field
			from its own deferred call to put the dead character's NAME on the
			body, and two `timer.Simple(0)` calls registered from two hook
			listeners run in whichever order the listeners did. The field is
			overwritten on the next death and every reader guards with
			`IsValid`, so leaving it costs nothing.
		]]
	end)
end)

--[[
	Take the whole thing apart.

	The end of a body rather than an injury to one: every gib the limbs and the
	torso between them define, thrown at once, and then the corpse is gone.
	There is nothing left to cut a head off, which is the cost of emptying a
	magazine into a body you might have wanted something from.
]]
function ix.dismember.Gib(ragdoll)
	if (not IsValid(ragdoll) or ragdoll:IsPlayer()) then return false end
	if (ragdoll.ixRobot) then return ix.dismember.Explode(ragdoll) end

	local centre = ragdoll:LocalToWorld(ragdoll:OBBCenter())
	local life = ix.config.Get("dismemberGibLife", 30)

	if (ragdoll:GetBloodColor() ~= BLOOD_COLOR_MECH
	and ragdoll:GetBloodColor() ~= DONT_BLEED) then
		--[[
			EVERY GIB THE WHOLE BODY HAS, not just the torso's - a body that
			bursts should leave the organs AND the pieces of arm, and the
			tables already say which is which.
		]]
		for _, limb in pairs(ix.dismember.limbs) do
			for _, gib in ipairs(limb.gibs or {}) do
				SpawnGib(gib.model, BonePosition(ragdoll, gib.bone), life)
			end
		end

		ix.dismember.Gore(centre, 12)
	end

	Noise("splat", centre, 90, math.random(80, 95))

	ragdoll:Remove()

	return true
end

--[[
	A MACHINE COMES APART ALL AT ONCE.

	There is no arm to shoot off a securitron and no head to cut from one; a
	body that is a chassis takes damage as one thing and, at the same
	threshold that bursts a torso, goes up - a blast, scrap thrown out of it,
	and nothing left. That is the whole of what can be done to a robot's body,
	and it is what "you can explode it as a whole, not each part" asked for.

	The scrap is the base game's metal gibs, which every client has.
]]
function ix.dismember.Explode(ragdoll)
	if (not IsValid(ragdoll) or ragdoll:IsPlayer()) then return false end

	local centre = ragdoll:LocalToWorld(ragdoll:OBBCenter())
	local life = ix.config.Get("dismemberGibLife", 30)

	local effect = EffectData()

	effect:SetOrigin(centre)
	effect:SetScale(1)

	util.Effect("Explosion", effect, true, true)
	util.ScreenShake(centre, 8, 5, 1, 400)

	for _ = 1, 8 do
		SpawnGib(string.format("models/gibs/metal_gib%d.mdl", math.random(1, 5)),
			centre + VectorRand() * 12, life)
	end

	sound.Play(string.format("ambient/explosions/explode_%d.wav",
		math.random(1, 4)), centre, 100, math.random(90, 110))

	ragdoll:Remove()

	return true
end

--------------------------------------------------------------------------------
-- Shooting a body that is already dead
--------------------------------------------------------------------------------

--[[
	Which limb a shot at a corpse landed on.

	`EntityTakeDamage` on a ragdoll gives a POSITION and nothing else - there
	is no hitgroup, because hitgroups belong to players. So the nearest physics
	bone is found, translated to an animation bone, and walked UP its parents
	until one of them is a bone this library knows about. Walking up is what
	makes a hit on a finger count as a hit on the arm.
]]
function ix.dismember.HitgroupAt(ragdoll, position)
	--[[
		A DAMAGE POSITION OF NOWHERE IS NOT A HIT ON THE ARM.

		Explosions, drowning and anything scripted can report the world origin
		or a point nowhere near the body, and "nearest bone to a point two
		thousand units away" is a wrong answer delivered with confidence.
		Anything further out than a body is wide is no answer at all.
	]]
	if (position:DistToSqr(ragdoll:GetPos()) > 200 * 200) then return end

	local best, bestDistance

	for index = 0, ragdoll:GetPhysicsObjectCount() - 1 do
		local physics = ragdoll:GetPhysicsObjectNum(index)

		if (IsValid(physics)) then
			local distance = physics:GetPos():DistToSqr(position)

			if (not bestDistance or distance < bestDistance) then
				best, bestDistance = index, distance
			end
		end
	end

	if (not best) then return end

	local bone = ragdoll:TranslatePhysBoneToBone(best)

	--- Twelve is deeper than any human skeleton; it is a stop, not a limit.
	for _ = 1, 12 do
		if (not bone or bone < 0) then return end

		local group = ix.dismember.boneGroups[ragdoll:GetBoneName(bone)]

		if (group) then return group end

		bone = ragdoll:GetBoneParent(bone)
	end
end

--[[
	A CORPSE CAN STILL BE TAKEN APART, and that is most of what people try.

	Emptying a magazine into a body on the floor is the first thing anybody
	does with a dismemberment system, and until now it did nothing at all -
	limbs only came off in the instant somebody died, which is both the hardest
	moment to aim in and the one nobody is watching.

	The threshold and the calibre's chance are the same ones a living limb
	uses. A failed roll keeps the damage, so the next burst rolls again rather
	than starting over.
]]
hook.Add("EntityTakeDamage", "ixDismember", function(target, damageInfo)
	if (not ix.config.Get("dismemberEnabled", true)) then return end

	--[[
		A BODY, AND NOT A PERSON. `IsPlayer` is checked as well as the flag
		because the flag is exactly what was ambiguous - see `sv_corpse.lua`.
		Two cheap tests against a class of bug that took limbs off people who
		were still walking around.
	]]
	if (target:IsPlayer() or target.ixCorpse ~= true) then return end

	--[[
		THE BURST THAT KILLED THEM KEEPS GOING. A body appears in the same
		frame the person dies, in the same place, and whatever is still
		leaving the barrel lands on it - which was a securitron "blowing up
		immediately" and gibs from a spawn-kill that the death cooldown had
		refused. A body does not take damage for its first second.
	]]
	if (CurTime() - (target.ixCorpseBorn or 0) < 1) then return end

	--[[
		FROM A WEAPON, IN SOMEBODY'S HANDS. A ragdoll that the solver cannot
		settle - the securitron's, mostly, and Phoenix's has the same habit -
		hits the floor hard enough to hurt itself, and a body that counts
		crush damage against its own threshold blows itself up. Crush, fall,
		vehicle and drowning damage are ignored outright, and what is left
		has to come from a player or an NPC.
	]]
	if (damageInfo:IsDamageType(bit.bor(DMG_CRUSH, DMG_FALL, DMG_VEHICLE,
	DMG_DROWN, DMG_PHYSGUN))) then
		return
	end

	local shooter = damageInfo:GetAttacker()

	if (not IsValid(shooter) or not (shooter:IsPlayer() or shooter:IsNPC())) then
		return
	end

	--[[
		A MACHINE HAS NO LIMBS. Every hit on a robot's body goes into one
		total, wherever it landed, and enough of it blows the body up - the
		same threshold that bursts a torso. See `Explode`.
	]]
	if (target.ixRobot) then
		target.ixLimbDamage = target.ixLimbDamage or {}

		local total = (target.ixLimbDamage[HITGROUP_CHEST] or 0)
			+ damageInfo:GetDamage()

		target.ixLimbDamage[HITGROUP_CHEST] = total

		if (ix.corpse and ix.corpse.Keep) then ix.corpse.Keep(target, 10) end

		if (total >= ix.config.Get("dismemberRobotDamage", 250)) then
			ix.dismember.Explode(target)
		end

		return
	end

	--[[
		WHERE THE SHOT LANDED, and a fallback for when nothing says.

		`GetDamagePosition` is the world origin for a good deal of scripted
		damage, and a shooter's eye trace is the honest second guess: they were
		pointing at the body, which is why it took damage.
	]]
	local position = damageInfo:GetDamagePosition()
	local attacker = shooter

	if (position == vector_origin and IsValid(attacker)
	and attacker:IsPlayer()) then
		position = attacker:GetEyeTrace().HitPos
	end

	local hitgroup = ix.dismember.HitgroupAt(target, position)

	if (not hitgroup) then return end

	--[[
		A TORSO CANNOT LOSE A LIMB, so it takes the whole body instead.

		The chest and the stomach have no bones to scale - there is no way to
		remove somebody's chest and leave a body behind - so damage to either
		counts towards ONE total, and enough of it bursts the corpse. That is
		what "you cannot destroy the chest" was: the hitgroup was recognised,
		found not to be a limb, and dropped.
	]]
	local torso = hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH

	--[[
		A HEAD CAN BE SHOT OFF A BODY. It is not a flesh limb - nothing is
		dropped for it - so the limb path below threw head damage away, and
		"you cannot destroy the head" was that. Enough of it bursts the head
		where it lies, with no roll, the way the torso bursts. A body kept
		for a named trophy keeps its head; see `sv_pk.lua`.
	]]
	if (hitgroup == HITGROUP_HEAD) then
		if (ix.dismember.Gone(target, HITGROUP_HEAD)
		or target:GetNWBool("ixCorpseHeadless", false)
		or target:GetNWString("ixCorpsePK", "") ~= "") then
			return
		end

		target.ixLimbDamage = target.ixLimbDamage or {}

		local total = (target.ixLimbDamage[HITGROUP_HEAD] or 0) + damageInfo:GetDamage()

		target.ixLimbDamage[HITGROUP_HEAD] = total

		if (ix.corpse and ix.corpse.Keep) then ix.corpse.Keep(target, 10) end

		if (total >= ix.config.Get("dismemberHeadDamage", 50)) then
			ix.dismember.Headpop(target)
		end

		return
	end

	if (not torso and not ix.dismember.fleshLimbs[hitgroup]) then return end
	if (not torso and ix.dismember.Gone(target, hitgroup)) then return end

	target.ixLimbDamage = target.ixLimbDamage or {}

	--- Both torso hitgroups share one counter; it is one body coming apart.
	local key = torso and HITGROUP_CHEST or hitgroup

	local total = (target.ixLimbDamage[key] or 0) + damageInfo:GetDamage()

	target.ixLimbDamage[key] = total

	--[[
		The body is kept a little longer, because somebody is clearly still
		using it - the same courtesy `ix.corpse.Keep` does for a head.
	]]
	if (ix.corpse and ix.corpse.Keep) then ix.corpse.Keep(target, 10) end

	if (torso) then
		--[[
			NO CHANCE ROLL ON THE TORSO. A limb comes off or it does not, which
			is a calibre's business; a body shot to pieces is shot to pieces,
			and a roll here would mean emptying two magazines into a corpse and
			being told nothing happened.
		]]
		if (total >= ix.config.Get("dismemberGibDamage", 120)) then
			ix.dismember.Gib(target)
		end

		return
	end

	if (total < ix.config.Get("dismemberLimbDamage", 40)) then return end

	if (math.random(1, 100) > ChanceOf(attacker)) then return end

	ix.dismember.Apply(target, hitgroup, nil)
end)

--------------------------------------------------------------------------------
-- Seeing it without dying
--------------------------------------------------------------------------------

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("dismember.test",
		"Test the dismemberment on a corpse", "World")
end

--[[
	`/testdismember head` on the ragdoll you are looking at.

	Tuning gib positions by shooting people until one of them loses the right
	arm is not tuning. This takes the corpse in front of you and removes the
	part you name, with no roll and no chance involved.
]]
ix.command.Add("TestDismember", {
	description = "Take a limb off the corpse you are looking at.",
	arguments = {ix.type.string},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "dismember.test")
	end,

	OnRun = function(self, client, part)
		local groups = {
			head = HITGROUP_HEAD,
			leftarm = HITGROUP_LEFTARM, rightarm = HITGROUP_RIGHTARM,
			leftleg = HITGROUP_LEFTLEG, rightleg = HITGROUP_RIGHTLEG,
			stomach = HITGROUP_STOMACH, chest = HITGROUP_CHEST
		}

		local hitgroup = groups[string.lower(string.Trim(part or ""))]

		if (not hitgroup) then
			return "Name one of: head, leftarm, rightarm, leftleg, rightleg, "
				.. "stomach, chest."
		end

		local target = client:GetEyeTrace().Entity

		if (not IsValid(target) or not target:IsRagdoll()) then
			return "Look at a corpse."
		end

		--[[
			The meat is named after whoever the body belonged to, and a ragdoll
			spawned from the spawnmenu belonged to nobody - so it comes apart
			and leaves nothing behind, which is correct rather than a gap.
		]]
		local owner = target:GetNetVar("player")
		local character = IsValid(owner) and owner:GetCharacter() or nil

		if (not ix.dismember.Apply(target, hitgroup, character)) then
			return "That corpse has no such limb - it is not a human skeleton."
		end

		return "Done."
	end
})
