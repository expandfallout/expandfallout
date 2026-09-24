-- Shared schema hooks.

-- Disable entity driving.
function Schema:CanDrive(client, entity)
	return false
end

--[[
	New Vegas player animations.

	Helix's stock GM:TranslateActivity maps activities to HL2MP enums and, when
	a weapon is lowered, to the *_PASSIVE set - which are empty-handed poses.
	Longsword still draws the gun at the hand bone regardless, so you get a
	floating weapon beside an open hand. That's the third-person problem.

	models/phoenix/humans/animations.mdl carries a full New Vegas animation set
	with distinct lowered / raised / ironsighted poses per weapon hold type,
	indexed by SWEP.NVHoldType. This hook drives it.

	Helix overrides hook.Call so Schema functions run before GM ones and a
	non-nil return wins, which is why overriding here works without touching
	the framework. Returning nil falls through to Helix's normal handling, so
	any model without a registered advanced set behaves exactly as before.
]]

-- Sprinting is a schema concept, not an activity, so it's checked directly.
local SPRINT_SPEED_SQR = 12500

-- Maps GMod's hold types onto the branches the New Vegas tree actually has.
--
-- The tree only defines normal / fist / pistol / smg / shotgun / ar2 / melee /
-- grenade. Anything else - physguns, tools, crowbars, cameras, the keys SWEP -
-- found no branch, so TranslateActivity bailed and those items fell back to
-- HL2 activities on a model that has none of them. That's why everything that
-- isn't a gun looked broken.
local HOLDTYPE_TRANSLATOR = {
	[""] = "normal",
	physgun = "smg",
	crossbow = "shotgun",
	rpg = "shotgun",
	slam = "normal",
	melee2 = "melee",

	-- "passive" is what Helix's keys SWEP uses, and it means "carrying
	-- something that isn't a weapon". The source mapped it to smg, which put
	-- your hands up in a firing grip while holding a keyring. Arms at your
	-- sides is the right read.
	passive = "normal",

	knife = "melee",
	duel = "pistol",
	camera = "smg",
	magic = "normal",
	revolver = "pistol",
	fist = "fist",
	normal = "normal"
}

--[[
	Which string key an airborne activity means.

	BUILT RATHER THAN WRITTEN OUT, because half of these enums do not exist in
	every build - `ACT_MP_JUMP_LAND` is not a global in GMod at all - and a nil
	key in a table constructor is an error at load, which would take the whole
	schema down rather than one animation.
]]
local JUMP_KEYS = {}

for name, key in pairs({
	ACT_MP_JUMP = "jump",
	ACT_MP_JUMP_START = "jump",
	ACT_MP_JUMP_FLOAT = "jump",
	ACT_JUMP = "jump",
	ACT_GLIDE = "jump",
	ACT_MP_JUMP_LAND = "land",
	ACT_LAND = "land"
}) do
	local enum = _G[name]

	if (isnumber(enum)) then
		JUMP_KEYS[enum] = key
	end
end

local function GetHoldType(weapon)
	if not IsValid(weapon) then
		return "normal"
	end

	-- NVHoldType is the New Vegas set ("1hp", "2ha", "2hr", "2hh", "2hl",
	-- "2hmo"). Every Longsword weapon declares one and they index the tree
	-- directly, so no translation is needed for them.
	if weapon.NVHoldType then
		return weapon.NVHoldType
	end

	local holdType = weapon.HoldType

	if not holdType and weapon.GetHoldType then
		holdType = weapon:GetHoldType()
	end

	holdType = holdType or "normal"

	return HOLDTYPE_TRANSLATOR[holdType] or holdType
end

--[[
	Attack / reload / jump gestures for New Vegas models.

	My first attempt checked `event == PLAYER_ATTACK1`, which never matched:
	DoAnimationEvent receives PLAYERANIMEVENT_* constants, not the PLAYER_*
	ones passed to Player:SetAnimation. So nothing was suppressed and the gun
	kept flinging overhead.

	The real fix isn't suppression anyway. Each weapon declares its own New
	Vegas animations - SWEP.AttackAnim ("2haattackloop"), SWEP.AttackAnimIS for
	ironsighted, SWEP.ReloadAnim ("2hareloads") - and those play as a GESTURE
	layered over the current pose, leaving the aim intact. Falling through to
	the engine instead picked the nearest matching sequence, which on this
	model is a melee swing.

	Gesture slot 6 is used to match the source's convention and stay clear of
	the engine's own slots.
]]
local GESTURE_SLOT_WEAPON = 6

function Schema:DoAnimationEvent(client, event, data)
	local class = ix.anim.GetModelClass(string.lower(client:GetModel() or ""))
	local animData = class and ix.anim[class]

	-- Not an advanced set: let Helix and the engine do their normal thing.
	if not animData or not animData.useADV then
		return
	end

	local weapon = client:GetActiveWeapon()

	if not IsValid(weapon) then
		return
	end

	-- Fall back to the unarmed tree rather than returning nil.
	--
	-- Returning nil here hands the event to Helix's GM:DoAnimationEvent, which
	-- indexes client.ixAnimTable without checking it - and that's nil for our
	-- model, because Helix never set it up for a class we registered ourselves.
	-- Result: "attempt to index local 'animation' (a nil value)" every time a
	-- melee weapon raised its block. On an advanced model we always handle the
	-- event ourselves and never fall through.
	local tree = animData[GetHoldType(weapon)] or animData.normal

	if not tree then
		return ACT_INVALID
	end

	local ironSights =
		weapon.GetIronSights and weapon:GetIronSights() or false

	local sequence, enum

	if event == PLAYERANIMEVENT_ATTACK_PRIMARY then
		sequence = (ironSights and weapon.AttackAnimIS)
			or (not ironSights and weapon.AttackAnim)
			or tree.attack
		enum = ACT_VM_PRIMARYATTACK

	elseif event == PLAYERANIMEVENT_ATTACK_SECONDARY then
		sequence = (ironSights and weapon.AttackAnimIS)
			or (not ironSights and weapon.AttackAnim)
			or tree.attack2
		enum = ACT_VM_SECONDARYATTACK

	elseif event == PLAYERANIMEVENT_RELOAD then
		sequence = weapon.ReloadAnim or tree.reload
		enum = ACT_VM_RELOAD

	elseif event == PLAYERANIMEVENT_JUMP then
		sequence = istable(tree.jump)
			and (ironSights and tree.jump[2] or tree.jump[1])
			or tree.jump
		enum = ACT_INVALID

		client.m_bJumping = true
		client.m_flJumpStartTime = CurTime()

	elseif event == PLAYERANIMEVENT_CANCEL_RELOAD then
		client:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)
		return ACT_INVALID
	else
		return
	end

	if istable(sequence) then
		sequence = sequence[math.random(#sequence)]
	end

	if isstring(sequence) then
		sequence = client:LookupSequence(sequence)
	end

	if not sequence or sequence <= 0 then
		-- Nothing usable. What to do depends on the event:
		--
		-- ATTACK: suppress. The engine's substitute on this model is a melee
		-- swing, which is the arm-over-the-head bug. 53 weapons declare no
		-- AttackAnim, so this path is common.
		--
		-- RELOAD / JUMP: fall through and let the engine try. Returning
		-- ACT_INVALID here cancels the animation outright, which is why third
		-- person showed no reload motion at all - worse than a rough one.
		if event == PLAYERANIMEVENT_ATTACK_PRIMARY
			or event == PLAYERANIMEVENT_ATTACK_SECONDARY then
			return ACT_INVALID
		end

		return
	end

	client:AnimResetGestureSlot(GESTURE_SLOT_WEAPON)
	client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_WEAPON, sequence, 0, true)

	return enum
end

function Schema:TranslateActivity(client, act)
	if CLIENT and client:IsDormant() then
		return
	end

	local class = ix.anim.GetModelClass(string.lower(client:GetModel()))
	local animData = class and ix.anim[class]

	-- Only handle the advanced (New Vegas) sets. Anything else - stock citizen
	-- models, metrocops, whatever - falls through to Helix untouched.
	if not animData or not animData.useADV then
		return
	end

	--[[
		SEATED, BEFORE ANYTHING ABOUT WEAPONS. Helix's own translator reads
		`ix.anim.<class>.vehicle[<seat class>]` for a player in a vehicle -
		but this hook answers first for these models, and it never looked,
		so everybody in an LVS seat played the standing idle up through the
		roof of the buggy. The seat's class picks the sequence; every LVS
		seat is a prisoner pod.
	]]
	if client:InVehicle() then
		local vehicle = client:GetVehicle()
		local seatClass = IsValid(vehicle)
			and (vehicle.IsChair and vehicle:IsChair() and "chair" or vehicle:GetClass())
			or nil
		local entry = seatClass and animData.vehicle and animData.vehicle[seatClass]
		local name = istable(entry) and entry[1] or entry

		if isstring(name) then
			local sequence = client:LookupSequence(name)

			if sequence and sequence > 0 then
				if client.ixLastAnim ~= "seated" then
					client.ixLastAnim = "seated"
					client:ResetSequenceInfo()
				end

				client:SetSequence(sequence)

				return client:GetSequenceActivity(sequence)
			end
		end
	end

	local weapon = client:GetActiveWeapon()
	local holdType = GetHoldType(weapon)
	local tree = animData[holdType]

	if not tree then
		return
	end

	-- Walking fast enough counts as running; the model has no separate
	-- fast-walk pose.
	if act == ACT_MP_WALK and client:GetVelocity():Length2DSqr() > SPRINT_SPEED_SQR then
		act = ACT_MP_RUN
	end

	--[[
		THE T-POSE IN MID-AIR, and it was here the whole time.

		The tree stores jumping under the STRING key `jump` - every hold type
		has one - and this function only ever looked up `tree[act]`. Helix's
		`CalcMainActivity` hands `HandlePlayerJumping` the wheel while you are
		off the ground, and that asks for `ACT_MP_JUMP`; nothing in the tree is
		keyed by that number, so this returned nil, Helix mapped it to an HL2MP
		jump activity, and the New Vegas model has none of those. Sequence 0 on
		these models is the reference pose - the T-pose - and landing put the
		activity back to one that resolves, which is why it fixed itself.

		Anything already keyed by the activity itself still wins: a few sets
		have a real `[ACT_LAND]` entry and it is more specific than this.
	]]
	local key = JUMP_KEYS[act]
	local entry = tree[act] or (key and tree[key])

	--[[
		A TREE WITHOUT THE KEY BORROWS THE UNARMED ONE. `fist` had no `jump`
		at all, so every jump with the hands out returned nil from here, fell
		to Helix's HL2MP translation, and the model answered that with
		sequence 0 - the reference pose. The trees carry their own jumps now,
		but a key nobody wrote is still better answered with the unarmed pose
		than with a T-pose.
	]]
	if not entry and animData.normal and animData.normal ~= tree then
		entry = animData.normal[act] or (key and animData.normal[key])
	end

	if not entry then
		return
	end

	local animToUse, actNum

	if istable(entry) then
		-- {[1] = lowered, [2] = raised, [3] = ironsighted}
		local raised = client:IsWepRaised()
		local ironSights =
			IsValid(weapon)
			and weapon.GetIronSights
			and weapon:GetIronSights()
			or false

		if raised and ironSights and entry[3] then
			animToUse, actNum = entry[3], 3
		elseif raised and entry[2] then
			animToUse, actNum = entry[2], 2
		elseif entry[1] then
			animToUse, actNum = entry[1], 1
		end
	else
		animToUse, actNum = entry, 1
	end

	-- Lets plugins substitute an animation - this is the seam the armor system
	-- uses for power armour and injured poses.
	local forced = hook.Run("GetForcedAnimation", client, holdType, animData, act, animToUse, actNum)

	if forced ~= nil then
		animToUse = forced
	end

	if not animToUse then
		return
	end

	-- Reset sequence info when the activity actually changes, otherwise the
	-- model keeps playing at the previous sequence's rate.
	if client.ixLastAnim ~= act then
		client.ixLastAnim = act
		client:ResetSequenceInfo()
	end

	if isstring(animToUse) then
		-- The advanced set stores SEQUENCE NAMES, but TranslateActivity has to
		-- return an ACTIVITY. Look the sequence up, apply it directly, and hand
		-- back the activity it maps to so the engine stays consistent.
		--
		-- Not every name in the tree exists in the model - "2hrpassive" and
		-- "sprint_2ha" are both referenced but absent, verified by reading the
		-- .mdl. Falling straight through on a miss drops that pose to HL2
		-- animations mid-stride, which reads as a glitch. Try the other
		-- variants for this activity first, then the normal tree.
		local candidates = {animToUse}

		if istable(entry) then
			for i = 1, 3 do
				if isstring(entry[i]) then
					candidates[#candidates + 1] = entry[i]
				end
			end
		end

		local fallback = animData.normal and animData.normal[act]

		if istable(fallback) then
			fallback = fallback[1]
		end

		if isstring(fallback) then
			candidates[#candidates + 1] = fallback
		end

		for _, name in ipairs(candidates) do
			local sequence = client:LookupSequence(name)

			if sequence and sequence > 0 then
				client:SetSequence(name)

				return client:GetSequenceActivity(sequence)
			end
		end

		return
	end

	return animToUse
end
