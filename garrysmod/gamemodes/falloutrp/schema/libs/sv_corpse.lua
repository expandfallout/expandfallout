--[[
	Making the body, keeping it, and cutting the head off it.

	`ix.corpse.list` is every body currently standing in the world, oldest
	first, so the limit can throw the front of it away without sorting.
]]

if (not SERVER) then return end

util.AddNetworkString("ixCorpseNew")
util.AddNetworkString("ixCorpseAsk")

ix.corpse.list = ix.corpse.list or {}

--------------------------------------------------------------------------------
-- Instead of the engine's
--------------------------------------------------------------------------------

--[[
	NO ENGINE RAGDOLL. Helix's `GM:DoPlayerDeath` calls `client:CreateRagdoll`,
	and that entity is deleted by the engine on the next `Player:Spawn` - so
	leaving it in would mean two bodies for five seconds and then none.

	This is the hook Helix already asks (`hook.Run("ShouldSpawnClientRagdoll",
	client) != false`), so answering it is the supported way to say no rather
	than a removal race.
]]
hook.Add("ShouldSpawnClientRagdoll", "ixCorpse", function(client)
	if (not ix.config.Get("corpseEnabled", true)) then return end

	return false
end)

--------------------------------------------------------------------------------
-- Keeping the count down
--------------------------------------------------------------------------------

local function Forget(corpse)
	for index, other in ipairs(ix.corpse.list) do
		if (other == corpse) then
			table.remove(ix.corpse.list, index)

			return
		end
	end
end

--- Oldest first, until there is room. Called before a new one is made.
local function MakeRoom()
	local limit = ix.config.Get("corpseMax", 24)

	while (#ix.corpse.list >= limit) do
		local oldest = table.remove(ix.corpse.list, 1)

		if (IsValid(oldest)) then oldest:Remove() end
	end
end

--------------------------------------------------------------------------------
-- Making one
--------------------------------------------------------------------------------

--[[
	How much of the player's momentum the body keeps.

	Helix's `CreateServerRagdoll` gives EVERY physics bone the player's full
	velocity, which is right for a body that fell over and wrong for one that
	was killed: a player who died sprinting, or mid-fall, threw a corpse across
	the room, and one killed mid-jump sailed off. A third reads as a body that
	dropped where it was hit and still has some weight to it.
]]
local MOMENTUM = 0.3

--[[
	The body, from the player, at the moment they died.

	NOT `CreateServerRagdoll`, and this is the third thing that function got
	wrong for a corpse rather than for a knockout:

	    the ANGLE was `EyeAngles()` - pitch and roll included - so somebody
	    who died looking at the floor left a body standing on its face
	    the VELOCITY was the player's, in full, on every bone
	    and it set no `player` net var either way

	The bones are still posed from the player's own skeleton, which is the part
	worth keeping: the corpse lands in the shape the person was standing in.

	The identity is put on as NET VARS rather than plain fields, because the
	client draws the tooltip and reads whether the head is still there.
]]
--[[
	WHAT HAPPENED TO THE LAST BODY, in one string.

	"No body appears" has four possible causes that look identical from in
	front of the screen - the hook never ran, the config is off, the player had
	no character, or the ragdoll failed to spawn - and guessing between them
	from a description is how two rounds of this were spent. `fo_corpse` reads
	this out.
]]
ix.corpse.last = ix.corpse.last or "nobody has died yet"

function ix.corpse.Create(client)
	local character = client:GetCharacter()

	if (not character) then
		ix.corpse.last = client:Name() .. ": no character, so no body"

		return
	end

	MakeRoom()

	local corpse = ents.Create("prop_ragdoll")

	if (IsValid(corpse)) then
		corpse:SetModel(client:GetModel())
		corpse:SetSkin(client:GetSkin())

		for index = 0, client:GetNumBodyGroups() - 1 do
			corpse:SetBodygroup(index, client:GetBodygroup(index))
		end

		--- Yaw only. A corpse is lying on the ground, not aiming at it.
		local angles = client:EyeAngles()

		angles.p = 0
		angles.r = 0

		corpse:SetPos(client:GetPos())
		corpse:SetAngles(angles)
		corpse:Spawn()
		corpse:Activate()
		corpse:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		local velocity = client:GetVelocity() * MOMENTUM

		for index = 0, corpse:GetPhysicsObjectCount() - 1 do
			local physics = corpse:GetPhysicsObjectNum(index)

			if (IsValid(physics)) then
				local bone = corpse:TranslatePhysBoneToBone(index)

				if (bone) then
					local position, bang = client:GetBonePosition(bone)

					--[[
						A BONE THAT IS INSIDE A WALL IS NOT POSED.

						Posing every physics object from the player's skeleton
						is what makes a corpse land in the shape the person was
						standing in - and it is also what wedges one into
						geometry when somebody dies with their back against a
						wall: an arm bone half a foot inside brickwork is a
						penetration the solver cannot resolve, and the body
						sticks, jitters, or is fired across the room.

						`util.IsInWorld` is the cheap half of the question.
						Anything it refuses is left where the ragdoll put it,
						which is a slightly wrong pose rather than a body stuck
						in a wall.
					]]
					if (position and util.IsInWorld(position)) then
						physics:SetPos(position)
						physics:SetAngles(bang)
					end
				end

				physics:SetVelocity(velocity)

				--[[
					AWAKE, so the solver can push it out of anything it
					landed in. A physics object that starts asleep inside
					geometry stays there - this is most of what "the body gets
					stuck near a wall" was.
				]]
				physics:Wake()
			end
		end
	end

	if (not IsValid(corpse)) then
		--[[
			LOUD, because this is the one failure with no other symptom. A
			model with no ragdoll data would land here, and the only sign
			anywhere else would be a wasteland with no corpses in it.
		]]
		ix.corpse.last = client:Name() .. ": CreateServerRagdoll failed ("
			.. client:GetModel() .. ")"

		ErrorNoHalt("[falloutrp] " .. ix.corpse.last .. "\n")

		return
	end

	--[[
		A MODEL WITH NO RAGDOLL DATA IS THE OTHER SILENT FAILURE.

		`prop_ragdoll` spawns happily for a model that was never compiled with
		`$collisionjoints` - it is a valid entity with zero physics objects,
		which lands on the floor as nothing anybody notices. Half the races in
		this schema wear models built for NPCs, so this is worth catching by
		name rather than discovering as "bodies do not appear for supermutants".
	]]
	if (corpse:GetPhysicsObjectCount() < 1) then
		ix.corpse.last = client:Name() .. ": " .. client:GetModel()
			.. " has no ragdoll data"

		corpse:Remove()

		return
	end

	--[[
		`ixCorpse` MEANS "THIS ENTITY IS A BODY" AND NOTHING ELSE.

		It used to mean that on a ragdoll and "the body this player left" on a
		player, which are two different things under one name - and the check
		`if (not target.ixCorpse) then return end` therefore passed on any
		living player who had died once before.

		Everything that check guarded then ran on a person who was standing up:
		limb damage accumulated on them, their bones were scaled away, gibs
		were thrown out of them and their physics objects were frozen. "Parts
		come out of someone not dead yet", "a player goes invisible", the
		T-posing and the players stuck in mid-air were all one bug wearing four
		faces.

		The player's field is `ixCorpseBody` now. A body is `ixCorpse`; the
		thing a player left behind is a body, not a corpse-ness.
	]]
	corpse.ixCorpse = true
	corpse.ixCharacterID = character:GetID()
	corpse.ixCorpseBorn = CurTime()

	--[[
		WHAT IT LOOKS LIKE, DECIDED HERE. The client used to look the
		character up and fall back to the human default body when it could
		not - which dressed dead geckos and super mutants as people, because
		a bot's character is never loaded on a client. The recipe is composed
		on this side from the same function that draws the living player, and
		goes out with the body; `ixCorpseAsk` answers anybody who finds a body
		they were not told about.
	]]
	corpse.ixRecipe = ix.fallout.Recipe(character, client:GetModel())

	--[[
		A MACHINE IS A BODY THAT COMES APART DIFFERENTLY. No limbs to take,
		no head to cut off, no meat: enough damage blows the whole thing up,
		and that is all that can be done to it. Robots are the races
		`ix.armor.raceKinds` calls robots - the same list that decides what
		they can wear.
	]]
	if (ix.corpse.IsRobot(character)) then
		corpse.ixRobot = true
		corpse:SetNWBool("ixCorpseRobot", true)
		corpse:SetBloodColor(BLOOD_COLOR_MECH)
	end

	corpse:SetNWString("ixCorpseLabel", ix.corpse.Label(character))
	corpse:SetNWBool("ixCorpseHeadless", false)

	--[[
		AND WHOSE IT IS, so the client can compose a visible body onto it.

		The model this ragdoll wears is `animations.mdl` - a skeleton with NO
		MESH - so without this the corpse is a set of physics that draws
		nothing. `cl_corpse.lua` reads the id, finds the character and
		bone-merges the same parts a living player is made of.

		The ID rather than the part list: the client already has every loaded
		character, and a list of model paths would be a second copy of
		`GetBodyParts` to keep in step.
	]]
	corpse:SetNWInt("ixCorpseChar", character:GetID())

	ix.corpse.list[#ix.corpse.list + 1] = corpse

	corpse:CallOnRemove("ixCorpse", Forget)

	--[[
		A DEADLINE, NOT A TIMER, because the deadline can be moved.

		`SafeRemoveEntityDelayed` fires once and cannot be argued with, and the
		body has to survive somebody who started cutting its head off with two
		seconds left on the clock - which is a real case at thirty seconds and
		a three second job. One sweep reads every deadline; anything can push
		one out.
	]]
	corpse.ixCorpseDie = CurTime() + ix.config.Get("corpseLife", 30)

	--[[
		AND THE CLIENTS ARE TOLD NOW, rather than found by the poll.

		`cl_corpse.lua` composes the visible body, and it looks for new corpses
		twice a second - which is a body that appears up to half a second after
		the person did, and reads as the corpse lagging behind the death. The
		poll stays as the fallback for a client that was not connected, or not
		in the PVS, when this went out - and such a client asks for the recipe.
	]]
	ix.corpse.Tell(corpse)

	ix.corpse.last = string.format("%s: body #%d, %s, for %ds",
		client:Name(), corpse:EntIndex(), tostring(corpse:GetPos()),
		ix.config.Get("corpseLife", 30))

	return corpse
end

--[[
	A BODY SOMEBODY ELSE MADE. VJ makes its own ragdoll when one of its NPCs
	dies; this takes that ragdoll in as one of ours - the recipe the NPC was
	drawn with, a label, the list, the deadline - so it is composed, cut and
	swept exactly like a player's. It has no character behind it, and
	everything that asks for one (`ixCharacterID`) finds none.
]]
function ix.corpse.Adopt(corpse, recipe, label, robot)
	if (not IsValid(corpse)) then return end

	corpse.ixCorpse = true
	corpse.ixNPC = true
	corpse.ixCorpseBorn = CurTime()
	corpse.ixRecipe = recipe or {parts = {}, hair = {r = 60, g = 40, b = 25}}

	if (robot) then
		corpse.ixRobot = true
		corpse:SetNWBool("ixCorpseRobot", true)
		corpse:SetBloodColor(BLOOD_COLOR_MECH)
	end

	corpse:SetNWString("ixCorpseLabel", label or "Unknown")
	corpse:SetNWBool("ixCorpseHeadless", false)

	ix.corpse.list[#ix.corpse.list + 1] = corpse

	corpse:CallOnRemove("ixCorpse", Forget)

	corpse.ixCorpseDie = CurTime() + ix.config.Get("corpseLife", 30)

	ix.corpse.Tell(corpse)

	return corpse
end

--- The body and its recipe, to everybody or to the one who asked.
function ix.corpse.Tell(corpse, receiver)
	net.Start("ixCorpseNew")
		net.WriteUInt(corpse:EntIndex(), 13)
		net.WriteTable(corpse.ixRecipe or {})

	if (receiver) then net.Send(receiver) else net.Broadcast() end
end

--- Whether a character's race is one of the machines.
function ix.corpse.IsRobot(character)
	if (not character or not ix.armor or not ix.armor.raceKinds) then
		return false
	end

	return ix.armor.raceKinds[character:GetRace()] == "robot"
end

--[[
	A client that found a body it has no recipe for. Twice a second at most
	per client, because the poll that sends this runs that often on every
	body at once.
]]
net.Receive("ixCorpseAsk", function(_, client)
	if ((client.ixCorpseAsked or 0) > CurTime()) then return end

	client.ixCorpseAsked = CurTime() + 0.5

	local corpse = Entity(net.ReadUInt(13))

	if (IsValid(corpse) and corpse.ixCorpse and corpse.ixRecipe) then
		ix.corpse.Tell(corpse, client)
	end
end)

hook.Add("PlayerDeath", "ixCorpse", function(client)
	if (not ix.config.Get("corpseEnabled", true)) then
		ix.corpse.last = "corpseEnabled is off"

		return
	end

	--[[
		Stored on the player for one frame so `sv_dismember.lua` can find it -
		it works a frame later, because the engine's own corpse used to need
		that, and this is the body it should be taking limbs off.
	]]
	client.ixCorpseBody = ix.corpse.Create(client)
end)

--[[
	One sweep for every body, once a second.

	A second's slack on a thirty second corpse is not worth a timer each, and a
	single loop over at most `corpseMax` entries is cheaper than the timers it
	replaces.
]]
timer.Create("ixCorpseSweep", 1, 0, function()
	for index = #ix.corpse.list, 1, -1 do
		local corpse = ix.corpse.list[index]

		if (not IsValid(corpse)) then
			table.remove(ix.corpse.list, index)
		elseif (corpse.ixCorpseDie and CurTime() >= corpse.ixCorpseDie) then
			corpse:Remove()
		end
	end
end)

--[[
	Give a body longer, because somebody is doing something with it.

	Never shortens: a body two seconds from vanishing is pushed out, and one
	with a minute left is left alone.
]]
function ix.corpse.Keep(corpse, seconds)
	if (not IsValid(corpse)) then return end

	corpse.ixCorpseDie = math.max(corpse.ixCorpseDie or 0,
		CurTime() + seconds)
end

--------------------------------------------------------------------------------
-- Taking the head
--------------------------------------------------------------------------------

--[[
	Whether there is one on this body to take.

	Three ways there is not: it was blown off, somebody has already taken it,
	or the body is not one of ours - a ragdoll spawned from the Q menu has no
	head to speak of in the sense that matters, which is that nobody died.
]]
function ix.corpse.HasHead(corpse)
	if (not IsValid(corpse) or not corpse.ixCorpse) then return false end
	if (corpse.ixRobot) then return false end

	return not corpse:GetNWBool("ixCorpseHeadless", false)
end

--[[
	Whether a head can be cut off this body at all - which is to say whether
	it is a body with a human head on a human neck. A machine has neither,
	and a creature model without a `Bip01 Head` has nothing to scale away.
	`sv_pk.lua` asks this to decide whether a permanent kill's head has to be
	cut off the body or is simply left at the death.
]]
function ix.corpse.CanBehead(corpse)
	if (not IsValid(corpse) or not corpse.ixCorpse or corpse.ixRobot) then
		return false
	end

	return corpse:LookupBone("Bip01 Head") ~= nil
end

--[[
	A named head on the ground, for a permanent kill whose body cannot give
	one up - a robot, or a race with no head to cut. The one way a head still
	reaches the floor at the moment of death; every other head is cut off a
	body by hand.
]]
function ix.corpse.DropHead(position, name)
	if (not ix.item.list[ix.corpse.headItem]) then return end

	ix.item.Spawn(ix.corpse.headItem, position + Vector(0, 0, 8), nil,
		angle_zero, {owner = name, taken = os.time()})
end

--[[
	Take it off, and mark the body.

	The bones are hidden by the same function a headshot uses, so a body whose
	head was cut off and a body whose head was shot off look identical - which
	they should, and which means there is one piece of code that knows how to
	remove a head.
]]
function ix.corpse.TakeHead(client, corpse)
	if (not ix.corpse.HasHead(corpse)) then return false end

	local character = client:GetCharacter()

	if (not character) then return false end

	--[[
		A PERMANENTLY KILLED BODY CARRIES A NAME, and its head is the named
		one - "Vault Dweller's Head" rather than "NCR - Trooper Head".

		This is the whole of what a permanent kill leaves behind now. It used
		to drop the head on the floor at the moment of death, which meant the
		trophy appeared whether or not anybody was there to take it, and could
		be picked up by somebody who had nothing to do with the kill. Now it
		has to be cut off a body, like every other head - the body just says
		whose it is.
	]]
	local label = corpse:GetNWString("ixCorpseLabel", "Unknown")
	local named = corpse:GetNWString("ixCorpsePK", "")

	corpse:SetNWBool("ixCorpseHeadless", true)

	if (ix.dismember and ix.dismember.Behead) then
		ix.dismember.Behead(corpse)
	end

	--[[
		INTO THEIR HANDS IF IT FITS, onto the floor if it does not.

		A three second job that silently fails because a bag is full is worse
		than one that puts the head at your feet, and the head is a world item
		anyway - `ix.pk` has been dropping them on the ground since long before
		this existed.
	]]
	local data = named ~= "" and {owner = named, taken = os.time()}
		or {label = label, taken = os.time()}

	local inventory = character:GetInventory()

	local where = corpse:LocalToWorld(corpse:OBBCenter())

	--[[
		INTO THEIR HANDS IF IT FITS, onto the floor if it does not - for both.

		The first version put the flesh on the ground while the head went into
		the bag, on the theory that the head is what you came for. In practice
		a piece of meat lying under a corpse is a piece of meat nobody notices,
		and the report was that decapitating gave no flesh at all. Both go the
		same way now.
	]]
	local function Give(uniqueID, itemData, note)
		if (inventory and inventory:Add(uniqueID, 1, itemData)) then
			return note .. " and bag it."
		end

		ix.item.Spawn(uniqueID, where + Vector(0, 0, 8), nil, angle_zero,
			itemData)

		return note .. ". It would not fit in your bag."
	end

	local said = Give(ix.corpse.headItem, data, "You cut off the head")

	--[[
		AND A PIECE OF THEM. Cutting a head off is the only butchery in this
		game, so it is where meat comes from - it used to fall out of a severed
		arm, which made Human Flesh a by-product of shooting somebody in the
		elbow rather than something anybody chose to do.
	]]
	if (ix.config.Get("dismemberFlesh", true) and ix.item.list.humanflesh) then
		Give("humanflesh", named ~= ""
			and {owner = named, taken = os.time()}
			or {label = label, taken = os.time()}, "flesh")
	end

	client:Notify(said)

	ix.log.Add(client, "corpseHead", label)

	return true
end

--------------------------------------------------------------------------------
-- Holding E on one
--------------------------------------------------------------------------------

--[[
	`KeyPress` rather than `PlayerUse`.

	`PlayerUse` fires every frame the key is held, so starting a three second
	action from it starts a new one sixty-six times a second. `KeyPress` is the
	moment the key went down, which is exactly once, and `DoStaredAction` then
	owns the rest: it cancels if the player looks away, moves out of reach or
	lets go, which is the same contract the implants and the restraints use.
]]
hook.Add("KeyPress", "ixCorpse", function(client, key)
	if (key ~= IN_USE) then return end
	if (not client:GetCharacter() or not client:Alive()) then return end
	if (client.ixCorpseBusy) then return end

	local corpse = client:GetEyeTrace().Entity

	if (not IsValid(corpse) or not corpse.ixCorpse) then return end

	if (client:GetPos():DistToSqr(corpse:GetPos()) > 128 * 128) then return end

	if (not ix.corpse.HasHead(corpse)) then
		client:Notify(corpse.ixRobot and "There is nothing to take from a machine."
			or "This one has no head left.")

		return
	end

	local time = ix.config.Get("corpseHeadTime", 3)

	client.ixCorpseBusy = true

	client:SetAction("Taking the head...", time)

	--[[
		AND THE BODY WAITS. Thirty seconds is not long, and a corpse that
		disappears halfway through three seconds of sawing fails silently -
		`DoStaredAction` cancels on an invalid entity without saying why.
	]]
	ix.corpse.Keep(corpse, time + 5)

	--[[
		IT SOUNDS LIKE SOMETHING WHILE IT HAPPENS, which is the other half of
		an action with a timer on it: `SetAction` draws a bar, and a bar with
		silence behind it reads as a menu rather than as work.
	]]
	if (ix.dismember and ix.dismember.Sound) then
		local wet = ix.dismember.Sound("tear")

		if (wet) then corpse:EmitSound(wet, 65, math.random(80, 95)) end
	end

	--[[
		THE FIFTH ARGUMENT IS THE REACH, and leaving it off would have been a
		quiet bug: `DoStaredAction` traces 96 units by default, while the check
		above allows 128. A body you were told you could reach that cancels
		itself the moment the timer starts is worse than one you cannot reach
		at all, because there is nothing on screen to explain it.
	]]
	client:DoStaredAction(corpse, function()
		client.ixCorpseBusy = nil

		client:SetAction()

		--[[
			THE HEAD COMES OFF WITH A NOISE AND A MESS. Without it the body
			simply loses its head between frames, which reads as a rendering
			fault rather than as something you did.
		]]
		if (ix.corpse.TakeHead(client, corpse) and ix.dismember) then
			local neck = corpse:LocalToWorld(corpse:OBBCenter())

			if (ix.dismember.Gore) then ix.dismember.Gore(neck, 5) end

			local splat = ix.dismember.Sound("splat")

			if (splat) then sound.Play(splat, neck, 75, math.random(90, 105)) end
		end
	end, time, function()
		client.ixCorpseBusy = nil

		client:SetAction()
	end, 128)
end)

--------------------------------------------------------------------------------
-- Finding out why there is no body
--------------------------------------------------------------------------------

--[[
	`fo_corpse` - the settings, the last death, and everything lying about.
	`fo_corpse spawn` - make one of yourself where you stand, without dying.

	The second is the important half: it runs the whole creation path with no
	death, no respawn and no hook ordering involved, so an empty result means
	the ragdoll itself is the problem and a body on the floor means it is not.
]]
concommand.Add("fo_corpse", function(client, _, arguments)
	local function Say(text)
		if (IsValid(client)) then client:ChatPrint(text) else print(text) end
	end

	if (IsValid(client) and not client:IsSuperAdmin()) then return end

	if (arguments[1] == "spawn" and IsValid(client)) then
		local corpse = ix.corpse.Create(client)

		Say(IsValid(corpse) and ("Made one: " .. ix.corpse.last)
			or ("Nothing was made: " .. ix.corpse.last))

		return
	end

	Say(string.format("corpseEnabled %s  corpseLife %ds  corpseMax %d  "
		.. "headTime %ds",
		tostring(ix.config.Get("corpseEnabled", true)),
		ix.config.Get("corpseLife", 180), ix.config.Get("corpseMax", 24),
		ix.config.Get("corpseHeadTime", 3)))

	Say("last death: " .. tostring(ix.corpse.last))

	--[[
		Whether the meat item registered at all. `DropFlesh` returns silently
		when it did not, which is indistinguishable from "the config is off"
		and from "the code never ran" - and all three were guessed at once.
	]]
	Say("humanflesh item: " .. (ix.item.list.humanflesh and "registered"
		or "MISSING") .. ", dismemberFlesh "
		.. tostring(ix.config.Get("dismemberFlesh", true)))

	local count = 0

	for _, corpse in ipairs(ix.corpse.list) do
		if (IsValid(corpse)) then
			count = count + 1

			local named = corpse:GetNWString("ixCorpsePK", "")
			local hurt = {}

			for hitgroup, amount in pairs(corpse.ixLimbDamage or {}) do
				hurt[#hurt + 1] = string.format("%d:%d", hitgroup, amount)
			end

			Say(string.format("  #%d %s%s  %ds left  gone %d  limbs[%s]%s",
				corpse:EntIndex(),
				corpse:GetNWString("ixCorpseLabel", "?"),
				named ~= "" and ("  PK:" .. named) or "",
				math.floor(math.max((corpse.ixCorpseDie or 0) - CurTime(), 0)),
				corpse:GetNWInt("ixCorpseGone", 0),
				table.concat(hurt, " "),
				corpse:GetNWBool("ixCorpseHeadless", false)
					and "  [headless]" or ""))
		end
	end

	Say(string.format("%d body/bodies in the world.", count))
end)

ix.log.AddType("corpseHead", function(client, label)
	return string.format("%s took a head from a %s body.", client:Name(),
		label)
end)
