--[[
	NPCs: presets, spawners, and the schema's guns in their hands.

	Three parts, and this file is the shape of all of them:

	    A PRESET is what an NPC is: a name, a race and gender, health,
	    accuracy, whose side it is on, the armour it wears and the guns it
	    carries - all of them the schema's own items - and what it drops.
	    Kept in `ix.data` ("npcpresets"), edited in a window
	    (`derma/cl_npcpresets.lua`), synced to every client.

	    A SPAWNER is a pod placed with the NPC Spawner tool: a preset, how
	    many, how fast they come back, and how close a player has to be
	    for any of them to exist at all. `sv_npc.lua`, `ix_npcspawner`.

	    THE NPC is `npc_fo_human`, a VJ Base human on the schema's own
	    animation model, dressed by the same body-part recipes a player and
	    a corpse are drawn with, holding a VJ weapon GENERATED from the
	    schema's weapon item - model, damage, sound, fire rate, hold type.

	WHY VJ. The creature packs this server mounts are VJ SNPCs, so their
	relationships, their weapons and their corpses already fit; and VJ's
	human base is the only one that takes a player model and a weapon it
	has never seen and does something sensible with both.

	OPTIMISATION IS THE SPAWNER'S JOB: nothing exists until a player is
	within its wake radius, everything of its goes away once nobody has
	been within its sleep radius for a while, and `npcMaxAlive` caps the
	server. VJ's own per-NPC cost is what it is; the number of NPCs is ours.
]]

ix.npc = ix.npc or {}
ix.npc.presets = ix.npc.presets or {}
ix.npc.weapons = ix.npc.weapons or {}
--- [item unique id] = the world model the client draws in the hand
ix.npc.weaponModels = ix.npc.weaponModels or {}

if (SERVER) then
	util.AddNetworkString("ixNPCPresets")
	util.AddNetworkString("ixNPCPresetSave")
	util.AddNetworkString("ixNPCPresetDelete")
	util.AddNetworkString("ixNPCEditor")
end

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

ix.config.Add("npcEnabled", true, "Whether NPC spawners spawn anything.", nil,
	{category = "NPCs"})

ix.config.Add("npcMaxAlive", 60,
	"The most spawner NPCs alive at once, server-wide.", nil, {
	data = {min = 1, max = 300}, category = "NPCs"})

ix.config.Add("npcWakeRadius", 3000,
	"Default wake radius for a new spawner: a player this close brings its NPCs "
	.. "into being.", nil, {data = {min = 500, max = 10000}, category = "NPCs"})

ix.config.Add("npcSleepRadius", 4500,
	"Default sleep radius for a new spawner: with nobody this close for the "
	.. "sleep delay, its NPCs are removed.", nil, {
	data = {min = 500, max = 15000}, category = "NPCs"})

ix.config.Add("npcSleepAfter", 45,
	"Default seconds a spawner waits with nobody near before removing its NPCs.",
	nil, {data = {min = 5, max = 900}, category = "NPCs"})

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("npc.manage",
		"Place NPC spawners and edit NPC presets", "Staff")
end

--------------------------------------------------------------------------------
-- Sides
--------------------------------------------------------------------------------

--[[
	WHOSE SIDE. VJ decides friend and foe by class lists: two things that
	share a class are allies, and `CLASS_PLAYER_ALLY` is friendly to every
	player. A preset is on one of three kinds of side:

	    hostile     enemies of everybody; allied with each other
	    friendly    friends of everybody
	    a faction   allied with that faction's NPCs AND its players, who
	                are given the same class when their character loads -
	                so NCR troopers hold the gate for NCR characters and
	                shoot at everybody else, and two factions' pods fight
]]
function ix.npc.Sides()
	local out = {
		{id = "hostile", name = "Hostile to everyone"},
		{id = "friendly", name = "Friendly to everyone"}
	}

	for _, faction in ipairs(ix.faction.indices or {}) do
		if (not faction.isDefault) then
			out[#out + 1] = {id = faction.uniqueID, name = faction.name}
		end
	end

	return out
end

--[[
	What it does with an enemy it can see, which is a choice VJ makes with
	one number and a flag rather than a behaviour tree:

	  hold     it shoots from where it stands, out to its full range. VJ
	           only walks a human toward an enemy that is FURTHER than
	           `Weapon_MaxDistance`, so a long range is a sentry.
	  advance  a short range, so anything further is walked down first. It
	           closes, then holds and shoots.
	  patrol   the same, and it wanders its post when nothing is happening
	           (`IdleAlwaysWander`).

	All three still take cover, strafe and chase somebody who breaks line
	of sight; that is VJ's, and it needs the map to have AI nodes.
]]
--[[
	WALKING WITHOUT A NODE GRAPH.

	Engine NPCs path on a map's AI nodes, and a map with none - rp_utah
	packs an empty graph and has not one `info_node` in it - can never move
	one, whatever its AI decides. The map cannot be fixed either: its graph
	is packed inside the BSP, and editing a BSP changes its checksum, which
	makes every client fail to join with "your map differs from the
	server's".

	So on those maps the NPC walks itself: a short step a think, straight at
	what it is fighting, refusing to step into anything solid or off any
	ledge. It is deliberately stupid - it cannot go round a corner, and it
	stops dead at the first wall between it and you - but a wastelander that
	closes across open ground beats one rooted to the spot. Where a map DOES
	have nodes the engine moves the NPC and none of this runs.
]]
--[[
	AND A LAST RESORT FOR WHEN THE ENGINE SIMPLY WILL NOT.

	This used to be gated on whether the map had an `.ain` file, which is
	the wrong question: a graph on the disk is not a graph that can route.
	The map under test has 8192 nodes and the engine still answers false to
	a route across two thousand units, so NPCs stood and watched people walk
	away because a file existed.

	It is gated on failure instead. `ENT:Chase` asks the engine for a path
	three different ways and measures whether the body actually moved; only
	when all three have failed does an NPC step toward a VISIBLE enemy by
	hand, on the ground, a stair's height at a time. Nothing here runs on a
	map that can path, because on such a map the third attempt never
	arrives.
]]
ix.config.Add("npcWalkWhenStuck", true,
	"Let NPCs step toward a visible enemy by hand once the engine has failed to path.",
	nil, {category = "NPCs"})

--[[
	DOES THIS MAP HAVE A NODE GRAPH THE ENGINE CAN USE?

	Asked of the file the ENGINE would open, through the engine's own search
	order, so a graph packed inside the BSP is what answers if there is one.
	The third number in an `.ain` is its node count: a map with none ships
	`37, <map version>, 0` in sixteen bytes, and a real one reads in the
	thousands.

	Read once and remembered, because it cannot change without a map change,
	and it is the switch that keeps the hand-walking below from ever running
	on a map that does not need it.
]]
function ix.npc.MapHasNodes()
	if (ix.npc.mapNodes == nil) then
		ix.npc.mapNodes = false

		local handle = file.Open("maps/graphs/" .. game.GetMap() .. ".ain", "rb", "GAME")

		if (handle) then
			handle:ReadLong()
			handle:ReadLong()

			ix.npc.mapNodes = (handle:ReadLong() or 0) > 0

			handle:Close()
		end
	end

	return ix.npc.mapNodes
end

--[[
	FACING WHERE IT IS GOING, or facing what it is shooting at.

	VJ's humans can do both at once: with `Weapon_CanMoveFire` they keep the
	body turned at their target and side-step along the path, which is what
	a trained soldier does and what a wastelander looks ridiculous doing.
	The nine-way blends make it worse to watch, because the animation
	honestly plays the sideways cycle it is being asked for - the NPC really
	is crab-walking, "walking around without looking where they're going",
	and a strafe cycle is slower than a run, which is the rest of "they walk
	slowly and don't run".

	Off, they turn to face their path, close the distance at a run, and
	shoot when they get there. On, they fight the way VJ intends.
]]
ix.config.Add("npcShootOnTheMove", false,
	"Whether NPCs side-step while facing their target instead of facing where they walk.",
	nil, {category = "NPCs"})

--[[
	HOW FAR THEY WILL SHOOT, which VJ does not let you say separately.

	VJ has ONE number, `Weapon_MaxDistance`, and it is both the range a
	human will fire from and the range it will close to: it chases while the
	enemy is further off than that and shoots while it is not. So there is
	no value that gives "runs at you AND shoots on the way". Big, and it
	plants its feet the moment it can see you - which is what "even if I do
	aggro it, it doesn't chase me" was, at 399 units with the number set to
	1200. Small, and it sprints into your face before firing a shot.

	The schema already decides for itself whether the weapon may fire
	(`NPC_CanFire`, below), so the two numbers can be pulled apart:
	`Weapon_MaxDistance` becomes the distance it CLOSES to, from the
	preset's behaviour, and this is the distance it will fire from,
	whichever it happens to be doing. An advancing NPC now runs at you from
	across the map and shoots the whole way in.
]]
--[[
	VJ's humans take cover when they are shot at and back away when you get
	close, and both stop them chasing for seconds at a time - see the note
	on `Weapon_RetreatDistance` in the NPC. Off, they walk into your
	shotgun, which is what a raider does. On, they fight like a fireteam and
	will not close on you while the shooting lasts.
]]
ix.config.Add("npcTakeCover", false,
	"Whether NPCs break off to take cover when shot, and back away up close.",
	nil, {category = "NPCs"})

ix.config.Add("npcFireDistance", 2500,
	"How far NPCs will fire a gun, apart from how close they try to get.",
	nil, {category = "NPCs"})

ix.config.Add("npcWalkSpeed", 55,
	"How fast an NPC walks itself, in units a second, with no AI nodes.", nil,
	{data = {min = 10, max = 200}, category = "NPCs"})

function ix.npc.Behaviours()
	return {
		{id = "advance", name = "Advance - close in, then shoot"},
		{id = "hold", name = "Hold - shoot from where it stands"},
		{id = "patrol", name = "Patrol - wander its post, then close in"}
	}
end

--- Engagement range and wandering, per behaviour.
--[[
	HOW CLOSE IT TRIES TO GET, and whether it wanders when nothing is
	happening. This is VJ's `Weapon_MaxDistance`, which it reads as "chase
	while the enemy is further off than this" - and NOT the range they will
	shoot from any more, which is `npcFireDistance`. See the note there.
]]
function ix.npc.Behaviour(id)
	--- A sentry: 3500 is further than it will ever see, so it never closes.
	if (id == "hold") then return 3500, false end
	if (id == "patrol") then return 150, true end

	--- Advance: run at you until it is nearly on top of you, shooting throughout.
	return 150, false
end

function ix.npc.SideName(id)
	for _, side in ipairs(ix.npc.Sides()) do
		if (side.id == id) then return side.name end
	end

	return id or "?"
end

function ix.npc.ClassesFor(side)
	if (side == "friendly") then return {"CLASS_PLAYER_ALLY", "CLASS_FO_FRIENDLY"} end
	if (not side or side == "hostile") then return {"CLASS_FO_HOSTILE"} end

	return {"CLASS_FO_" .. string.upper(side)}
end

--[[
	AND THE ENGINE HAS TO BE TOLD TOO, which is the half that was missing.

	Everything above tells VJ who is on whose side. VJ then picks targets
	itself and hands them over with `ForceSetEnemy`, so an NPC can be
	shooting at somebody the ENGINE still regards as neutral - and the
	report showed exactly that: a live enemy, in sight, at ninety units,
	with a disposition of D_NU.

	That is not cosmetic. The engine's senses only enter entities it HATES
	into enemy memory, and `TASK_GET_PATH_TO_ENEMY` paths to the enemy's
	last known position out of that memory. No memory, no last known
	position: the task gets the origin of the map, which is why the report's
	waypoint was 0 0 0 and why they would shoot you all day and never take
	a step towards you.

	So the schema states its own relationships to the engine: share a class
	and you are liked, an NPC that allies with players likes them, and
	anybody else is hated. That is the same rule `ClassesFor` and
	`PlayerClasses` already describe, said to the one system that was never
	listening.
]]
function ix.npc.Relate(npc, client)
	if (not IsValid(npc) or not IsValid(client) or not npc.AddEntityRelationship) then
		return
	end

	local mine = npc.VJ_NPC_Class or {}
	local theirs = client.VJ_NPC_Class or {}
	local friendly = false

	for _, class in ipairs(mine) do
		--- VJ's own convention: this class means "on the players' side".
		if (class == "CLASS_PLAYER_ALLY") then friendly = true end

		for _, other in ipairs(theirs) do
			if (class == other) then friendly = true end
		end
	end

	npc:AddEntityRelationship(client, friendly and D_LI or D_HT, 10)
end

--- A player's classes, from their faction.
function ix.npc.PlayerClasses(client)
	local character = IsValid(client) and client:GetCharacter()
	local faction = character and ix.faction.indices[character:GetFaction()]

	if (not faction or faction.isDefault) then return {} end

	return {"CLASS_FO_" .. string.upper(faction.uniqueID)}
end

--------------------------------------------------------------------------------
-- Races and presets
--------------------------------------------------------------------------------

--[[
	The races an NPC can be: the ones on the human animation model, which
	is the skeleton the schema's armour is built for and the one whose
	sequences the NPC's animations name. A deathclaw is a creature pack's
	SNPC and has its own spawner in the spawn menu.
]]
function ix.npc.Races()
	local out = {}

	for id, race in pairs(ix.races and ix.races.list or {}) do
		local model = string.lower(race.animationModel or "")

		if (string.find(model, "phoenix/humans", 1, true) and istable(race.defaultModels)) then
			out[#out + 1] = {id = id, name = race.name or id}
		end
	end

	table.sort(out, function(a, b) return a.name < b.name end)

	return out
end

--[[
	A RACE'S GENDERS, AS A LIST. `RACE.genders` is a set (`{male = true,
	female = true}`), which `ipairs` walks as nothing at all - which is why
	the first editor had no gender buttons. Male first, then the rest.
]]
function ix.npc.Genders(race)
	local genders = ix.races.GetGenders(race)
	local out = {}

	if (istable(genders)) then
		if (#genders > 0) then
			for _, gender in ipairs(genders) do out[#out + 1] = gender end
		else
			for gender, on in pairs(genders) do
				if (on) then out[#out + 1] = gender end
			end
		end
	end

	table.sort(out, function(a, b)
		if (a == "male") then return b ~= "male" end
		if (b == "male") then return false end

		return a < b
	end)

	if (#out == 0) then out[1] = "male" end

	return out
end

function ix.npc.Default()
	return {
		id = "",
		name = "Wastelander",
		race = "human",
		gender = "male",
		health = 100,
		accuracy = 1,
		side = "hostile",
		behaviour = "advance",
		weapons = {},
		armour = {},
		dropWeapon = 25,
		dropArmour = 10,
		loot = {}
	}
end

--- Every item there is, for the loot list.
function ix.npc.AllItems()
	local out = {}

	for uniqueID, itemTable in pairs(ix.item.list) do
		if (not itemTable.isBase) then
			out[#out + 1] = {id = uniqueID, name = itemTable.name or uniqueID,
				slot = itemTable.category}
		end
	end

	table.sort(out, function(a, b) return a.name < b.name end)

	return out
end

--- Any of the schema's weapon items an NPC could be handed.
function ix.npc.WeaponItems()
	local out = {}

	for uniqueID, itemTable in pairs(ix.item.list) do
		if (ix.npc.weapons[uniqueID]) then
			out[#out + 1] = {id = uniqueID, name = itemTable.name or uniqueID}
		end
	end

	table.sort(out, function(a, b) return a.name < b.name end)

	return out
end

function ix.npc.ArmourItems()
	local out = {}

	for uniqueID, itemTable in pairs(ix.item.list) do
		if (itemTable.isArmor and itemTable.bodyType) then
			out[#out + 1] = {id = uniqueID, name = itemTable.name or uniqueID,
				slot = itemTable.bodyType}
		end
	end

	table.sort(out, function(a, b) return a.name < b.name end)

	return out
end

--- A preset as it may be stored: every field checked, nothing extra.
function ix.npc.Clean(preset)
	if (not istable(preset)) then return nil end

	local out = ix.npc.Default()

	out.id = string.sub(string.gsub(tostring(preset.id or ""), "[^%w_]", ""), 1, 32)
	out.name = string.sub(string.Trim(string.gsub(tostring(preset.name or ""), "%c", "")), 1, 32)

	if (out.name == "") then out.name = "Unnamed" end

	out.race = "human"

	for _, race in ipairs(ix.npc.Races()) do
		if (race.id == preset.race) then out.race = race.id end
	end

	local genders = ix.npc.Genders(out.race)

	out.gender = genders[1]

	for _, gender in ipairs(genders) do
		if (gender == preset.gender) then out.gender = gender end
	end

	out.health = math.Clamp(math.Round(tonumber(preset.health) or 100), 1, 5000)
	out.accuracy = math.Clamp(tonumber(preset.accuracy) or 1, 0.2, 3)
	out.dropWeapon = math.Clamp(math.Round(tonumber(preset.dropWeapon) or tonumber(preset.drop) or 0), 0, 100)
	out.dropArmour = math.Clamp(math.Round(tonumber(preset.dropArmour) or 0), 0, 100)
	out.side = "hostile"
	out.behaviour = "advance"

	for _, entry in ipairs(ix.npc.Behaviours()) do
		if (entry.id == preset.behaviour) then out.behaviour = entry.id end
	end

	--- Anything at all, each with its own chance.
	for uniqueID, chance in pairs(istable(preset.loot) and preset.loot or {}) do
		if (ix.item.list[uniqueID]) then
			out.loot[uniqueID] = math.Clamp(math.Round(tonumber(chance) or 0), 0, 100)
		end
	end

	for _, side in ipairs(ix.npc.Sides()) do
		if (side.id == preset.side) then out.side = side.id end
	end

	for uniqueID in pairs(istable(preset.weapons) and preset.weapons or {}) do
		if (ix.npc.weapons[uniqueID]) then out.weapons[uniqueID] = true end
	end

	for uniqueID in pairs(istable(preset.armour) and preset.armour or {}) do
		local itemTable = ix.item.list[uniqueID]

		if (itemTable and itemTable.isArmor and itemTable.bodyType) then
			out.armour[uniqueID] = true
		end
	end

	return out
end

function ix.npc.Preset(id)
	return ix.npc.presets[id]
end

--- Presets sorted by name, for lists.
function ix.npc.PresetList()
	local out = {}

	for _, preset in pairs(ix.npc.presets) do out[#out + 1] = preset end

	table.sort(out, function(a, b) return a.name < b.name end)

	return out
end

--------------------------------------------------------------------------------
-- The schema's guns, as VJ weapons
--------------------------------------------------------------------------------

--[[
	ONE VJ WEAPON PER WEAPON ITEM, made at load on both realms. The
	schema's guns are `ls_base` SWEPs, which know nothing about NPCs; VJ's
	weapon base is made for NPCs and takes a model, a damage, a sound and
	a fire rate. So each weapon item's SWEP is read for those and a
	`weapon_vj_fo_<item>` is registered with them - the same gun, the same
	world model, in an NPC's hands. Grenades and anything without a hold
	type VJ understands are left out.

	The hand the model sits in is `Bip01 R Hand` - the schema's skeleton,
	not ValveBiped - and the offset that makes it sit right is
	`ix.npc.pose`, adjustable live with `fo_npc_weaponpose` because it can
	only be judged by eye.
]]
local HOLD = {
	pistol = "pistol", revolver = "pistol", smg = "smg", ar2 = "ar2",
	shotgun = "shotgun", rpg = "rpg", crossbow = "crossbow", melee = "melee",
	melee2 = "melee2", knife = "melee", fist = "melee", physgun = "smg",
	duel = "pistol", camera = "pistol"
}

--[[
	WHERE THE GUN SITS. The same place a player's does: the schema's SWEP
	base draws a human's weapon at the animation model's `weapon`
	attachment, turned -90 about its up and scaled 0.85. `ix.npc.HandPose`
	answers that for an NPC, and `cl_npc.lua` draws a clientside model of
	the weapon there every frame. The VJ weapon entity itself is never
	drawn: the engine attaches it to an `anim_attachment_RH` this skeleton
	does not have and bone-merges it against bones it does not share, and
	a gun drawn through that was in the ground, then "glitching on his
	side". `fo_npc_weaponpose` moves every NPC gun live for anything the
	eye still disagrees with.
]]
ix.npc.pose = ix.npc.pose or {origin = Vector(0, 0, 0), angle = Vector(-90, 0, 0),
	scale = 0.85}

--- Where an NPC's gun goes: position, angles and scale, or nothing yet.
function ix.npc.HandPose(npc)
	local pose = ix.npc.pose
	local pos, ang
	local id = npc:LookupAttachment("weapon")
	local attachment = (id and id > 0) and npc:GetAttachment(id) or nil

	if (attachment) then
		pos, ang = attachment.Pos, attachment.Ang
	else
		local bone = npc:LookupBone("Bip01 R Hand")

		if (bone) then pos, ang = npc:GetBonePosition(bone) end
	end

	if (not pos or not ang) then return end

	pos = pos + ang:Forward() * pose.origin.x + ang:Right() * pose.origin.y
		+ ang:Up() * pose.origin.z

	local up, right, forward = ang:Up(), ang:Right(), ang:Forward()

	ang:RotateAroundAxis(up, pose.angle.x)
	ang:RotateAroundAxis(right, pose.angle.y)
	ang:RotateAroundAxis(forward, pose.angle.z)

	return pos, ang, pose.scale or 1
end

--- The VJ weapon draws nothing; see `cl_npc.lua`.
local function DrawNothing() end

--[[
	WHERE VJ'S BULLETS LEAVE FROM. VJ's own lookup tries the weapon's
	muzzle attachments and then a `ValveBiped` hand, and this skeleton has
	neither, so every shot left from the eyes with a warning in the console
	each time. The hand, a little forward of it.
]]
local function BulletPos(self)
	local owner = self:GetOwner()

	if (not IsValid(owner)) then return end

	local id = owner:LookupAttachment("weapon")
	local attachment = (id and id > 0) and owner:GetAttachment(id) or nil

	if (attachment) then return attachment.Pos + owner:GetForward() * 12 end

	local bone = owner:LookupBone("Bip01 R Hand")

	if (bone) then return owner:GetBonePosition(bone) end
end

function ix.npc.WeaponClass(uniqueID)
	return "weapon_vj_fo_" .. uniqueID
end

local function BuildWeapon(uniqueID, itemTable, vjBase)
	local swep = itemTable.class and weapons.Get(itemTable.class)

	if (not swep) then return end

	local hold = HOLD[string.lower(swep.HoldType or "")]

	if (not hold) then return end

	local primary = table.Copy(vjBase.Primary or {})
	local source = swep.Primary or {}
	local melee = swep.Base == "ls_base_melee" or hold == "melee" or hold == "melee2"
		or (source.ClipSize == -1)

	primary.Damage = tonumber(source.Damage) or 10
	primary.NumberOfShots = math.max(1, math.Round(tonumber(source.NumShots) or 1))
	primary.ClipSize = math.max(1, tonumber(source.ClipSize) or 10)
	primary.DefaultClip = primary.ClipSize
	primary.Automatic = source.Automatic == true
	primary.Delay = math.max(tonumber(source.Delay) or 0.15, 0.08)
	primary.Ammo = "SMG1"
	primary.TakeAmmo = 1
	primary.Force = 5
	primary.Recoil = 0

	if (source.Sound and source.Sound ~= "") then
		primary.Sound = source.Sound
	end

	local weapon = {
		Base = "weapon_vj_base",
		PrintName = itemTable.name or uniqueID,
		Spawnable = false,
		AdminSpawnable = false,
		MadeForNPCsOnly = true,
		NPC_CanBePickedUp = false,
		HoldType = hold,
		WorldModel = swep.WorldModel or itemTable.model,

		--[[
			THE ENTITY IN THE HAND, NOT AT THE FEET. This is VJ's own
			feature for guns "in the crotch": every think it moves the weapon
			entity to the owner's bone. Drawing is ours (`cl_npc.lua`, on
			the attachment a player's gun uses); this is for the SERVER,
			where the entity's position is where VJ's bullets leave from and
			where its "is my gun poking into cover" trace starts. At the
			feet, that trace hit the ground every time, VJ spent every think
			trying to step out of cover that was not there, and nobody ever
			fired: enemy visible, able to fire, attack state never set.
		]]
		WorldModel_UseCustomPosition = true,
		WorldModel_CustomPositionBone = "Bip01 R Hand",
		WorldModel_CustomPositionOrigin = Vector(0, 0, 0),
		WorldModel_CustomPositionAngle = Vector(0, 0, 0),
		DrawWorldModel = DrawNothing,
		OnGetBulletPos = BulletPos,
		Primary = primary,
		NPC_NextPrimaryFire = melee and 1 or primary.Delay,
		NPC_CustomSpread = 1,
		NPC_FiringDistanceScale = 1,
		NPC_HasReloadSound = true,
		IsMeleeWeapon = melee,

		--[[
			WHEN THIS WEAPON MAY FIRE, and why VJ's own answer cannot be
			used. VJ lets a human's weapon fire only while its attack
			ANIMATION is the body's current one -

			    WeaponAttackState == FIRE_STAND
			      and VJ.IsCurrentAnim(owner, owner.WeaponAttackAnim)

			- which is a fair rule for a model whose attacks are whole-body
			sequences. This model's are deltas: the recoil alone, layered as
			a gesture over an aim that the engine's own idle keeps taking
			back (gotcha 36). That check can never hold here, so nothing
			ever fired, whether the stance was given as a sequence name or
			as an activity.

			This keeps every other test VJ makes - the weapon ready and the
			enemy in range (`CanFireWeapon`), ammo in the clip, and the
			enemy inside the firing cone - and drops only the animation
			coupling. The cone is measured off the body's forward rather
			than VJ's `GetHeadDirection`, because the NPC is told to face
			its enemy while it shoots and this skeleton's head bone is not
			the one VJ assumes.
		]]
		NPC_CanFire = function(self, selfData, owner)
			selfData = selfData or self:GetTable()
			owner = owner or self:GetOwner()

			if (not IsValid(owner)) then return false end

			local enemy = owner:GetEnemy()

			if (not IsValid(enemy)) then return false end

			--- A swing is a gesture too; range is the only question.
			if (selfData.IsMeleeWeapon) then
				return owner:GetPos():Distance(enemy:GetPos())
					<= (selfData.MeleeWeaponDistance or 70) + 24
			end

			--[[
				READY, BUT NOT IN VJ'S RANGE. `CanFireWeapon(true, true)`
				answers "is the weapon usable AND is the enemy inside
				`Weapon_MaxDistance`", and that second half is now the
				distance the NPC is trying to CLOSE to, not the distance it
				may shoot from - asking it here would mean an advancing NPC
				held its fire until it arrived. `(false, false)` is the same
				call without the range test: weapon out, ready, not busy.
			]]
			if (owner.CanFireWeapon and not owner:CanFireWeapon(false, false)) then
				return false
			end

			if (selfData.NPC_StandingOnly and owner:IsMoving()) then return false end
			if (self:Clip1() <= 0) then return false end

			--- The schema's own range, which is not the one it walks by.
			local range = owner:GetPos():Distance(enemy:GetPos())

			if (range > (owner.ixFireDistance or 2500)) then return false end
			if (range < (owner.Weapon_MinDistance or 0)) then return false end

			local from = self:GetPos()
			local at = owner.GetAimPosition and owner:GetAimPosition(enemy, from, 0)
				or enemy:BodyTarget(from)
			local aim = at - from
			local facing = owner:GetForward()

			aim.z = 0
			facing.z = 0
			aim:Normalize()
			facing:Normalize()

			if (facing:Dot(aim) <= (selfData.NPC_FiringCone or 0.6)) then return false end

			--[[
				AND VJ IS TOLD, which is the other half of taking this
				decision off it. Nearly everything a VJ human does WHILE
				shooting hangs off `WeaponAttackState` being FIRE_STAND -
				strafing out of the open, stepping aside when a friend walks
				into the line of fire, giving up a position it cannot shoot
				from. VJ sets that flag in the same branch whose animation
				test can never pass here, so with the flag never set the
				NPC fired from the spot it was standing on and did nothing
				else for the rest of the fight. It fires, so it says so.
			]]
			owner.WeaponAttackState = VJ.WEP_ATTACK_STATE_FIRE_STAND

			return true
		end,
		MeleeWeaponDistance = tonumber(source.Range) or 60,

		--- Ours, and what the NPC needs to animate it.
		ixNPCWeapon = true,
		ixItem = uniqueID,
		ixNVHoldType = swep.NVHoldType,
		ixAttackAnim = swep.AttackAnim,
		ixReloadAnim = swep.ReloadAnim
	}

	local class = ix.npc.WeaponClass(uniqueID)

	--[[
		PRECACHED BY HAND. The engine precaches a weapon's world model when
		it registers the weapon at startup; one registered from Lua after
		that gets no such favour, and a model that is not precached is a
		weapon with no model - invisible in the hand.
	]]
	if (isstring(weapon.WorldModel) and weapon.WorldModel ~= "") then
		util.PrecacheModel(weapon.WorldModel)
	end

	weapons.Register(weapon, class)
	ix.npc.weapons[uniqueID] = class
	ix.npc.weaponModels[uniqueID] = weapon.WorldModel
end

function ix.npc.RegisterWeapons()
	local vjBase = weapons.Get("weapon_vj_base")

	if (not vjBase) then
		if (ix.fallout and ix.fallout.CreateTrace) then
			ix.fallout.CreateTrace("npc: VJ Base is not mounted; no NPC weapons")
		end

		return
	end

	local count = 0

	for uniqueID, itemTable in pairs(ix.item.list) do
		if (itemTable.base == "base_weapons" and itemTable.class) then
			BuildWeapon(uniqueID, itemTable, vjBase)

			if (ix.npc.weapons[uniqueID]) then count = count + 1 end
		end
	end

	if (ix.fallout and ix.fallout.CreateTrace) then
		ix.fallout.CreateTrace("npc: " .. count .. " weapons made for NPCs")
	end
end

hook.Add("InitializedPlugins", "ixNPCWeapons", ix.npc.RegisterWeapons)

--- Move every NPC gun in every hand; for finding the offset by eye.
function ix.npc.SetPose(origin, angle, scale)
	ix.npc.pose.origin = origin
	ix.npc.pose.angle = angle
	ix.npc.pose.scale = scale or ix.npc.pose.scale
end

concommand.Add("fo_npc_weaponpose", function(client, _, args)
	if (IsValid(client) and not client:IsSuperAdmin()) then return end

	local n = {}

	for index = 1, 6 do n[index] = tonumber(args[index]) or 0 end

	ix.npc.SetPose(Vector(n[1], n[2], n[3]), Vector(n[4], n[5], n[6]), tonumber(args[7]))

	print(string.format("[falloutrp] NPC weapon pose: origin %g %g %g angle %g %g %g scale %s",
		n[1], n[2], n[3], n[4], n[5], n[6], tostring(ix.npc.pose.scale)))
end)

--------------------------------------------------------------------------------
-- Animations
--------------------------------------------------------------------------------

--[[
	WHAT THE ENGINE IS TOLD, AND WHAT VJ PLAYS ITSELF.

	The animation model is a player model with Phoenix's sequence names, and
	its activities are a mess: the aimed idles have none, the NPC walk and
	run are proper (`mtwalk_npc` is ACT_WALK, `mtrun_npc` ACT_RUN), and the
	standing idle's activity is shared by three sequences, one of which is
	a crucifixion. So:

	    the ENGINE drives idle, walking, running and crouching through
	    `TranslateActivity` and takes a NUMBER back - those are answered
	    with activities the model has, checked on the model
	    (`SelectWeightedSequence`), and the shared idle is corrected every
	    think by the NPC (`OnThink`)

	    VJ plays attacks, reloads and melee through its own player, which
	    takes a sequence NAME when the sequence has no activity - those
	    are the weapon's own `AttackAnim` and `ReloadAnim`, straight from
	    the schema's SWEP, in VJ's `AnimTbl_*` tables

	Aimed walking and running use the hold type's sequences from
	`ix.anim.falloutHuman` where those carry an activity of their own
	(`2haaim_walk` does), and the NPC walk otherwise.
]]
local IDLE_BY_GENDER = {male = "mtidle", female = "mtidle_female"}

--- The second entry of a set is the raised pose.
local function Raised(set, key)
	local entry = set and set[key]

	if (not istable(entry)) then return nil end

	return entry[2] or entry[1]
end

--- The activity of a named sequence, when it has one the engine can use.
local function Activity(npc, sequence)
	if (not isstring(sequence)) then return nil end

	local id = npc:LookupSequence(sequence)

	if (not id or id < 0) then return nil end

	local act = npc:GetSequenceActivity(id)

	return (act and act > 0) and act or nil
end

--- The first activity of the candidates the model actually has.
local function First(npc, ...)
	for _, act in ipairs({...}) do
		if (isnumber(act) and npc:SelectWeightedSequence(act) >= 0) then return act end
	end
end

local function Sequence(npc, name)
	if (not isstring(name) or name == "") then return nil end

	return npc:LookupSequence(name) >= 0 and name or nil
end

--- The first of several sequence names that carries an activity, as that activity.
local function AimActivity(npc, ...)
	for _, name in ipairs({...}) do
		local act = Activity(npc, name)

		if (act) then return act end
	end
end

--[[
	WHAT THE MODEL CAN DO, read off the model at run time, so a hold type
	nobody thought of still answers with something that exists.

	THE AIM. A hold type's raised idle ("2haaim") carries no activity, and
	the engine wants a number. Its nine-way walk blend ("2haaim_walk") does
	carry one, and the cycle at the CENTRE of that blend is the raised idle
	itself - so an NPC standing still on the walk blend is aiming, and the
	engine can be asked for it by number. That is what every alerted idle,
	walk and run here resolves to; the crouch blends the same way.

	STANCE AND GESTURE. Every attack and reload on this model is a DELTA
	sequence - the recoil alone, made to be layered over an aim by the
	player system - and played as the body's whole animation it shows
	nothing, which was "shooting with the gun pointed at the floor". So VJ's
	"attack animation" is the aim STANCE - as an ACTIVITY, the aim blend's,
	which is what the engine already plays for an alerted idle, so VJ's
	"is my attack animation still the current one" check holds and it
	keeps firing (a sequence NAME there went through VJ's sequence
	schedule, which the engine kept taking back, and nobody fired); the
	weapon's own attack plays as a GESTURE on every shot (VJ's firing
	gesture, which the weapon base plays itself), and the reload is a
	gesture too. A melee
	weapon is the other way about: its swings ARE the attack, as gestures,
	and the weapon says it may strike regardless (`NPC_CanFire`).
]]
function ix.npc.Anims(npc, weapon)
	local anims = ix.anim and ix.anim.falloutHuman
	local armed = IsValid(weapon)
	local hold = armed and (weapon.ixNVHoldType or weapon.HoldType) or nil
	local set = anims and ((hold and anims[hold]) or anims.normal) or {}
	local spec = npc.ixSpec
	local idleSequence = IDLE_BY_GENDER[spec and spec.gender or "male"] or "mtidle"

	if (not Sequence(npc, idleSequence)) then idleSequence = "mtidle" end

	local idle = Activity(npc, idleSequence) or First(npc, ACT_MP_STAND_PRIMARY, ACT_IDLE)
	local walk = First(npc, ACT_WALK, ACT_MP_WALK)
	local run = First(npc, ACT_RUN, ACT_MP_RUN)
	local crouch = First(npc, ACT_MP_CROUCH_IDLE, ACT_CROUCHIDLE)
	local crouchWalk = First(npc, ACT_MP_CROUCHWALK, ACT_WALK_CROUCH)

	local stand = Raised(set, ACT_MP_STAND_IDLE) or "mtidle"
	local crouched = Raised(set, ACT_MP_CROUCH_IDLE) or "sneakmtidle"
	--- The lowered pose of the same hold type: entry one, where the aim is entry two.
	local lowered = istable(set[ACT_MP_STAND_IDLE]) and set[ACT_MP_STAND_IDLE][1] or nil
	local aimStand = AimActivity(npc, stand, stand .. "_walk", stand .. "is_walk", stand .. "_run")
		or idle
	local aimWalk = AimActivity(npc, stand .. "_walk", stand .. "is_walk") or aimStand
	local aimRun = AimActivity(npc, stand .. "_run", stand .. "is_run") or aimWalk
	local aimCrouch = AimActivity(npc, crouched, stand .. "_sneak", stand .. "is_sneak") or crouch

	local activities = {}

	local function Put(act, value)
		if (act and value) then activities[act] = value end
	end

	--[[
		AN IDLE IS A TRUE IDLE, ARMED OR NOT. The only standing aim this
		model gives an activity to is a WALK blend, and the alerted idle was
		mapped to it because the aim proper has none. A walk blend as an
		idle is a body that walks on the spot the moment anything hands it
		a direction, and carries a ground speed the engine will act on
		while believing the NPC is standing still - which is what "walking
		in place" and "walking without looking" were, underneath everything
		else. The idle is the idle; the raised aim is put on by `OnThink`,
		which swaps one standing sequence for another and never touches a
		travelling one.
	]]
	Put(ACT_IDLE, idle)
	Put(ACT_IDLE_ANGRY, idle)
	Put(ACT_COWER, idle)
	Put(ACT_WALK, walk)
	Put(ACT_WALK_AGITATED, aimWalk)
	Put(ACT_WALK_AIM, aimWalk)
	Put(ACT_RUN, run)
	Put(ACT_RUN_AGITATED, aimRun)
	Put(ACT_RUN_AIM, aimRun)
	Put(ACT_RUN_PROTECTED, run)
	Put(ACT_CROUCHIDLE, crouch)
	Put(ACT_COVER_LOW, crouch)
	Put(ACT_WALK_CROUCH, crouchWalk)
	Put(ACT_WALK_CROUCH_AIM, aimCrouch)
	Put(ACT_RUN_CROUCH, crouchWalk)
	Put(ACT_RUN_CROUCH_AIM, aimCrouch)
	Put(ACT_RANGE_ATTACK1, idle)
	Put(ACT_RELOAD, idle)

	local function Gesture(name)
		return Sequence(npc, name) and ("vjges_vjseq_" .. name) or nil
	end

	local swing = armed and weapon.ixAttackAnim or nil
	local stance = Sequence(npc, stand) or idleSequence
	local reload = armed and Gesture(weapon.ixReloadAnim) or nil
	local melee = armed and weapon.IsMeleeWeapon == true
	local attack, gesture

	if (melee) then
		attack = {}

		for _, name in ipairs(istable(set.attack) and set.attack or {}) do
			local one = Gesture(name)

			if (one) then attack[#attack + 1] = one end
		end

		if (#attack == 0 and Gesture(swing)) then attack[1] = Gesture(swing) end
		if (#attack == 0) then attack = {stance} end
	else
		--[[
			NO STANCE FOR VJ TO PLAY, for a gun. Firing is the schema's
			decision (`NPC_CanFire`) and the recoil is a gesture, so VJ's
			"attack animation" had nothing left to do but harm: every value
			it could be given was either a walk blend, or a sequence VJ
			could not see was already playing and so restarted five times
			a second. `false` is a value VJ handles - `PICK` hands it back,
			the translation returns it, and the whole block is skipped. The
			NPC idles, `OnThink` raises the aim, the gesture fires on every
			shot. A melee weapon keeps its swings, above: those ARE its
			attack.
		]]
		attack = false
		gesture = Gesture(swing)
	end

	--[[
		THE SEQUENCES THE NPC MAY BE STANDING IN, and the one it should be.
		Which of these the engine lands on is its own business - several
		share an activity, it picks among them by weight, and an aim
		resolves through a nine-way blend whose name is not the aim's - so
		the NPC corrects itself every think (`OnThink`), and this is the
		list it is allowed to correct FROM.

		EVERY POSE OF THE HOLD TYPE, not a hand-picked few. The first list
		named the idles and the two stances, and the engine simply stood in
		something else: no match, no correction, and the NPC shot with its
		arms down. This is the whole of the hold type's tree and the unarmed
		one beside it, which between them are every pose this model uses for
		standing about. Correcting only happens while the NPC is STILL, so
		the walking blends in here are never cut short.
	]]
	local standing = {}

	local function Learn(value)
		if (istable(value)) then
			for _, entry in pairs(value) do Learn(entry) end
		elseif (Sequence(npc, value)) then
			standing[value] = true
		end
	end

	Learn(set)
	Learn(anims and anims.normal)
	Learn({idleSequence, "mtidle", "mtidle_female", "dynamicidle_nvcrucifiedidle",
		lowered, stand, crouched})

	--[[
		AND EVERY SEQUENCE THAT SHARES AN ACTIVITY WITH ONE OF THOSE, which
		is how the engine found a pose no list of names could have held.
		`2hraim_walk` and four `2hraim_walk_passive*` all carry
		ACT_GESTURE_RANGE_ATTACK_SMG2 between them, and the engine picks
		among them by weight: a shotgun NPC was standing in
		`2hraim_walk_passive1`, a pose with the weapon LOWERED, which is
		the whole of "it shoots with the gun holstered". The activity is
		the family; matching on it catches the four nobody named.
	]]
	local standingActs = {}

	for name in pairs(standing) do
		local act = npc:GetSequenceActivity(npc:LookupSequence(name))

		if (act and act > 0) then standingActs[act] = true end
	end

	--[[
		AND THE ONES IT TRAVELS ON. Every walk and run this model has is a
		nine-way blend on `move_x`/`move_y` - there is not one plain
		travelling sequence in all 667 of them - so the NPC's ground speed
		is whatever those two parameters currently select, and at rest they
		select the cycle in the middle, which is the idle. See the NPC's
		`OnThink` for what is done about that.
	]]
	local travelling = {}

	local function Travels(value)
		if (istable(value)) then
			for _, entry in pairs(value) do Travels(entry) end
		elseif (Sequence(npc, value)) then
			travelling[value] = true
		end
	end

	for _, act in ipairs({ACT_MP_WALK, ACT_MP_RUN, ACT_MP_CROUCHWALK}) do
		Travels(set and set[act])
		Travels(anims and anims.normal and anims.normal[act])
	end

	Travels({"mtwalk", "mtwalk_npc", "mtrun", "mtrun_npc", "sneakmtwalk"})

	--[[
		AND EVERY SEQUENCE SHARING AN ACTIVITY WITH ONE OF THOSE, for the
		same reason the standing poses need it, and with a worse symptom.
		`2hraim_walk` is in the tree; `2hraim_walk_passive1`, `2`, `4` are
		not, and all five carry ACT_GESTURE_RANGE_ATTACK_SMG2 between them,
		so the engine picks among them by weight. Land on one that is not
		named and this NPC's movement blend was treated as "not travelling",
		its pose parameters were zeroed, the blend collapsed to the cycle at
		its centre - the idle, which travels nowhere - and the NPC's ground
		speed went with it. It crawled, could not reach its waypoints, and
		re-pathed over and over: "slow, weird, random and dumb".
	]]
	local travellingActs = {}

	for name in pairs(travelling) do
		local act = npc:GetSequenceActivity(npc:LookupSequence(name))

		if (act and act > 0) then travellingActs[act] = true end
	end

	--[[
		AND A POSE IT TRAVELS ON IS NEVER A POSE TO CORRECT FROM.

		The standing list is built from the whole of the hold type's tree,
		which includes its walk and run blends - so the correction in
		`OnThink` was allowed to pull the NPC out of the very sequence the
		engine had just put it in to walk with. It did, `2hraim` has no
		ground speed, and an engine NPC with no ground speed does not
		advance: the route was planned, the walk began, the pose was yanked
		back to a standing aim, and the whole thing stalled a frame later.
		Every symptom of it - slow, weird, wandering - came from that.

		Standing poses are corrected, travelling poses are left alone, and
		the two lists are made disjoint here rather than by asking whether
		the NPC happens to be moving at the instant it is asked.
	]]
	for name in pairs(travelling) do standing[name] = nil end
	for act in pairs(travellingActs) do standingActs[act] = nil end

	--- The one to play while walking itself; the aim walk when it is armed.
	local walk

	for _, name in ipairs({armed and Raised(set, ACT_MP_WALK) or nil,
	istable(set[ACT_MP_WALK]) and set[ACT_MP_WALK][1] or set[ACT_MP_WALK],
	"mtwalk_npc", "mtwalk"}) do
		if (not walk and Sequence(npc, name)) then walk = name end
	end

	return {
		activities = activities,
		idleSequence = idleSequence,
		--- What it should stand in with a gun out and an enemy: the raised aim.
		aimSequence = armed and Sequence(npc, stand) or nil,
		standing = standing,
		standingActs = standingActs,
		travelling = travelling,
		travellingActs = travellingActs,
		walkSequence = walk,
		attack = attack,
		crouchAttack = melee and attack or false,
		gesture = gesture,
		reload = reload and {reload} or {ACT_RELOAD}
	}
end

--------------------------------------------------------------------------------
-- For looking at one
--------------------------------------------------------------------------------

if (SERVER) then
	concommand.Add("fo_npc_report", function(client)
		if (IsValid(client) and not client:IsSuperAdmin()) then return end

		local npc = IsValid(client) and client:GetEyeTrace().Entity or nil

		if (not IsValid(npc) or npc:GetClass() ~= "npc_fo_human") then
			print("[falloutrp] look at one of the NPCs first")

			return
		end

		local weapon = npc:GetActiveWeapon()

		print(string.format("== %s  health %d/%d  model %s", npc:GetNetVar("ixNPCName", "?"),
			npc:Health(), npc:GetMaxHealth(), npc:GetModel()))
		print(string.format("  sequence %s  activity %s  ideal %s  wanted idle %s",
			npc:GetSequenceName(npc:GetSequence()), tostring(npc:GetActivity()),
			tostring(npc:GetIdealActivity()), tostring(npc.ixIdleSequence)))
		print(string.format("  weapon %s  hold %s  attack %s  reload %s",
			IsValid(weapon) and weapon:GetClass() or "none",
			IsValid(weapon) and tostring(weapon.ixNVHoldType or weapon.HoldType) or "-",
			IsValid(weapon) and tostring(weapon.ixAttackAnim) or "-",
			IsValid(weapon) and tostring(weapon.ixReloadAnim) or "-"))
		--[[
			READ-ONLY, AND IT WAS NOT. This line used to call `NavSetGoalPos`,
			which does not merely ASK whether a route exists - it SETS the
			NPC's goal to that position. So looking at an NPC threw away
			whatever it was doing and sent it at whoever ran the command, and
			reading the report twice while testing was itself breaking the
			walking it was reporting on. A diagnostic that changes what it
			measures is worse than none. The path test lives in `/npcwalk`,
			which is asking for the NPC to be sent somewhere anyway.
		]]
		print(string.format("  moving %s  ground speed %.1f  move_x %.2f  move_y %.2f  waypoint %s",
			tostring(npc:IsMoving()),
			npc:GetSequenceGroundSpeed(npc:GetSequence()),
			npc:GetPoseParameter("move_x"), npc:GetPoseParameter("move_y"),
			tostring(npc:GetCurWaypointPos())))
		print(string.format("  capabilities %d  can move ground %s  schedule %s  travelling pose %s",
			npc:CapabilitiesGet(),
			tostring(bit.band(npc:CapabilitiesGet(), CAP_MOVE_GROUND) ~= 0),
			tostring(npc.CurrentScheduleName),
			tostring(npc.ixTravels and npc:ixTravels() or false)))
		--[[
			AND WHETHER YOU ARE EVEN A TARGET. `/npcignore` sets
			`FL_NOTARGET`, every NPC checks that flag before anything else,
			and an NPC with nobody to fight has nobody to walk towards -
			which reads exactly like "they do not come after you".
		]]
		print(string.format("  accuracy %s  weapon spread %s  map has nodes %s  you are invisible to NPCs %s",
			tostring(npc.Weapon_Accuracy),
			IsValid(weapon) and tostring(weapon.NPC_CustomSpread) or "-",
			tostring(ix.npc.MapHasNodes and ix.npc.MapHasNodes()),
			tostring(IsValid(client) and client:IsFlagSet(FL_NOTARGET) or false)))
		--[[
			AND WHY IT HAS NO ENEMY, which is four separate questions and
			they look identical from across a room. VJ takes a target when
			the entity is in its relationship list, is not disposed friendly
			to it, is VISIBLE, and is inside its VIEW CONE - and its alert
			state says which of those it has managed: `false` is nothing at
			all, `1` is "heard something but has never SEEN an enemy", and
			`true` is "has seen one". A `1` that never becomes `true` while
			you are standing in front of it means sight, not relationships.
		]]
		local sees = IsValid(client) and npc:Visible(client) or false
		local cone = IsValid(client) and npc:IsInViewCone(client:EyePos()) or false
		local disposition = IsValid(client) and npc:Disposition(client) or 0
		local listed = false

		for _, entry in ipairs(npc.RelationshipEnts or {}) do
			if (entry == client) then listed = true end
		end

		print(string.format("  can see you %s  you are in its view cone %s  disposition %d  in its relationship list %s",
			tostring(sees), tostring(cone), disposition, tostring(listed)))

		--[[
			AND WHERE IT THINKS THE ENEMY IS, which is what it walks toward.
			`TASK_GET_PATH_TO_ENEMY` uses the engine's enemy MEMORY, not the
			enemy's actual position, and the engine records memory only for
			entities it hates. A last known position of 0 0 0 beside a live
			enemy means there is no memory at all, and the NPC is walking at
			the map origin.
		]]
		local target = npc:GetEnemy()
		local known = npc:GetEnemyLastKnownPos()
		local unreachable = IsValid(target) and npc:IsUnreachable(target) or false

		print(string.format("  it thinks the enemy is at %s  unreachable %s",
			tostring(known), tostring(unreachable)))

		--[[
			AND WHETHER IT EVER CHASES, which a reading taken from three feet
			away cannot otherwise show: at that range standing still and
			shooting is the correct answer, so every report looked like a
			refusal to move. This is remembered from the last time it
			actually set off.
		]]
		if (npc.ixChaseAt) then
			print(string.format("  last set off after you %.1fs ago, from %.0f units away",
				CurTime() - npc.ixChaseAt, npc.ixChaseFrom or 0))
			local method = ({[0] = "straight at you", [1] = "a spot that can see you",
				[2] = "walk to your position"})[npc.ixChaseTried or 0]

			--- How much of the way the pathfinder would build, the last time it was asked.
			local routed = "not tried yet"

			if (npc.ixChaseRoute ~= nil) then
				local share = npc.ixChaseShare or 0

				routed = share >= 1 and "all the way"
					or share > 0 and string.format("%d%% of the way", math.floor(share * 100))
					or "not at all"
			end

			print(string.format("  stalled chases %d  trying %s  engine could route to you %s",
				npc.ixChaseStuck or 0, tostring(method), routed))
			print(string.format("  stuck reloads cleared %d  fires out to %s  weapon ready %s",
				npc.ixReloadsFixed or 0, tostring(npc.ixFireDistance),
				tostring(npc.CanFireWeapon and npc:CanFireWeapon(false, false))))
		else
			print(string.format("  has never set off after anybody  (closes to %s, cover %s)",
				tostring(npc.ixChaseDistance), tostring(npc.CombatDamageResponse)))
		end

		--- The parameters the aim and the gestures are read from.
		local standing = npc:GetPoseParameter("standing")
		local aimPitch = npc:GetPoseParameter("aim_pitch")
		local aimYaw = npc:GetPoseParameter("aim_yaw")
		local headYaw = npc:GetPoseParameter("head_yaw")

		print(string.format("  standing %.0f  aim pitch %.1f  aim yaw %.1f  head yaw %.1f  VJ drives the legs %s",
			standing, aimPitch, aimYaw, headYaw, tostring(npc.UsePoseParameterMovement)))

		local seen = (npc.EnemyData or {}).VisibleTime or 0

		print(string.format("  field of view %s  look distance %s  last saw an enemy %.1fs ago  detection %s",
			tostring(npc:GetFOV()), tostring(npc:GetMaxLookDistance()),
			CurTime() - seen, tostring(npc.EnemyDetection)))

		print(string.format("  aim sequence %s  alerted %s  weapon state %s  may correct %s",
			tostring(npc.ixAimSequence), tostring(npc.Alerted),
			tostring(npc.GetWeaponState and npc:GetWeaponState()),
			tostring(npc.ixMayCorrect and npc:ixMayCorrect() or false)))
		print(string.format("  stance %s  gesture %s  reload anim %s",
			tostring(istable(npc.AnimTbl_WeaponAttack) and npc.AnimTbl_WeaponAttack[1]),
			tostring(istable(npc.AnimTbl_WeaponAttackGesture) and npc.AnimTbl_WeaponAttackGesture[1]
				or npc.AnimTbl_WeaponAttackGesture),
			tostring(istable(npc.AnimTbl_WeaponReload) and npc.AnimTbl_WeaponReload[1])))
		print("  anim set " .. tostring(npc.AnimModelSet) .. "  classes "
			.. table.concat(npc.VJ_NPC_Class or {}, ", "))
		--[[
			ONE VALUE PER LINE, ON PURPOSE. Every one of these is a call
			into VJ or the engine, and a call in the last argument position
			expands to ALL its return values - zero of them included, which
			is not `nil` but "no argument at all" and kills the whole report
			half way through (gotcha 37). Read into locals first and there
			is no last argument position left to get wrong.
		]]
		--- EVERY one of them, including the two that look harmless.
		local eyes = npc:GetViewOffset()
		local enemy = npc:GetEnemy()
		local weaponState = npc.GetWeaponState and npc:GetWeaponState()
		local canFire = npc.CanFireWeapon and npc:CanFireWeapon(true, false)

		print(string.format("  eyes %s  enemy %s  alerted %s  weapon state %s  can fire %s",
			tostring(eyes), tostring(enemy),
			tostring(npc.Alerted), tostring(weaponState), tostring(canFire)))

		if (IsValid(weapon)) then
			local model = weapon:GetModel()
			local drawn = weapon.GetDrawWorldModel and weapon:GetDrawWorldModel()
			local loaded = util.IsModelLoaded and util.IsModelLoaded(weapon.WorldModel or "")
			local clip = weapon:Clip1()

			print(string.format("  weapon model %s  drawn %s  precached %s  clip %s",
				tostring(model), tostring(drawn), tostring(loaded), tostring(clip)))
		end

		local enemyData = npc.EnemyData or {}
		local enemy = npc:GetEnemy()

		print(string.format("  attack state %s  next attack in %.1f  taking cover for %.1f  enemy visible %s  distance %s",
			tostring(npc.WeaponAttackState), (npc.NextWeaponAttackT or 0) - CurTime(),
			(npc.TakingCoverT or 0) - CurTime(), tostring(enemyData.Visible),
			tostring(enemyData.Distance)))
		print(string.format("  shoot pos %s  centre %s  weapon at %s  bullets from %s",
			tostring(npc:GetShootPos()), tostring(npc:GetPos() + npc:OBBCenter()),
			IsValid(weapon) and tostring(weapon:GetPos()) or "-",
			IsValid(weapon) and weapon.GetBulletPos and tostring((weapon:GetBulletPos())) or "-"))

		--- The two traces VJ makes before it will fire: body to enemy, gun to enemy.
		if (IsValid(enemy) and npc.DoCoverTrace and IsValid(weapon) and weapon.GetBulletPos) then
			local body = (npc:DoCoverTrace(npc:GetPos() + npc:OBBCenter(), enemy:EyePos(), false))
			local gun = (npc:DoCoverTrace(weapon:GetBulletPos(), enemy:EyePos(), false))

			print(string.format("  covered: body %s  gun %s", tostring(body), tostring(gun)))
		end

		for act, value in pairs(npc.ixAnims or {}) do
			print(string.format("  act %d -> %s", act, tostring(value)))
		end
	end)
end
