--[[
	Armour test bots.

	A bot is a REAL PLAYER, and that is the entire point of doing it this way.

	The first attempt at this was a scripted entity that carried its own copy of
	the armour rules, and it was the wrong shape: it could only ever tell you
	how THAT entity resisted damage, not how the armour system behaves. A bot
	goes through every real path instead - `PlayerLoadout`, the composed body in
	`cl_bodyparts.lua`, `ix.armor.Equip`, `ScalePlayerDamage` - so what you shoot
	is what a player wearing the same suit would be.

	HELIX ALREADY MAKES BOTS PLAYABLE. `GM:PlayerInitialSpawn` gives any bot a
	real character, a random faction, a model and a non-saving inventory:

	    if (client:IsBot()) then
	        local character = ix.char.New({...}, botID, client, ...)
	        character.isBot = true
	        ...
	        character:Setup()
	        client:Spawn()
	                            -- core/hooks/sv_hooks.lua

	which is what makes this possible at all. Without a character a player is
	invulnerable (`PlayerShouldTakeDamage` returns `GetCharacter() != nil`) and
	is spawned no-draw, locked and not solid.

	THE BOT IS CREATED BEFORE ITS CHARACTER EXISTS. Our `hook.Add` listener runs
	before `GM:PlayerInitialSpawn` - Helix's hook order ends with `hook.ixCall`,
	which runs `hook.Add` listeners and only then the gamemode method - so the
	character is not there yet when we first see the bot. Hence the deferred
	setup below rather than doing it inline.
]]

if (not SERVER) then return end

util.AddNetworkString("ixFODevDummy")
util.AddNetworkString("ixFODevDummyClear")

ix.armor.dummyBots = ix.armor.dummyBots or {}

--[[
	Requests waiting for a bot to appear.

	`RunConsoleCommand("bot")` gives no handle back - the fake client arrives
	later, through `PlayerInitialSpawn` - so what we want done to it is queued
	here and claimed by the next bot that shows up. A queue rather than a single
	slot so clicking twice quickly produces two correctly dressed bots.
]]
local pending = {}

--[[
	Stand still and stay put.

	`Freeze` rather than `MOVETYPE_NONE`: a frozen bot still has gravity applied
	up to the point it is frozen, so it settles onto the floor instead of
	hovering wherever it was placed. Bots in sandbox have no behaviour of their
	own, so nothing tries to walk it away afterwards.
]]
local function Immobilise(bot)
	bot:Freeze(true)
	bot:SetNoTarget(true)
end

--[[
	Dress a bot and put it where it was asked for.

	The armour goes into the bot's REAL inventory and is equipped through
	`ix.armor.Equip`, so every rule applies - slot conflicts, race restrictions,
	the power armour helmet dependency. If a piece cannot legally be worn the
	bot simply is not wearing it, which is itself worth knowing.
]]
local function Setup(bot, request)
	if (not IsValid(bot)) then return end

	local character = bot:GetCharacter()

	if (not character) then return end

	--[[
		Remembered on the bot, so every later respawn puts it back here rather
		than at a map spawn point. Set before the move, so a bot that dies
		during setup still knows where it belongs.
	]]
	bot.ixDummyPos = request.position
	bot.ixDummyAngles = request.angles

	bot:SetPos(request.position)
	bot:SetEyeAngles(request.angles)
	bot:SetHealth(bot:GetMaxHealth())

	Immobilise(bot)

	local inventory = character:GetInventory()

	if (not inventory or #(request.pieces or {}) < 1) then return end

	--[[
		A WHOLE SET, not one piece.

		The bot section used to spawn exactly one armour, which is right for
		"what does 50% damage resistance feel like" and useless for "what does
		this actual loadout stop" - the thing being tested is usually the SUM,
		and a helmet on its own is not a build. `pieces` is a list of
		uniqueIDs, and the presets simply pass a list of one.
	]]
	local order = {}

	for _, uniqueID in ipairs(request.pieces) do
		local itemTable = ix.item.list[uniqueID]

		if (not itemTable) then continue end

		--[[
			A power armour helmet needs the suit, so the suit goes in first
			when one was not asked for explicitly. Without this the helmet is
			refused and the bot stands there in its underwear, looking like a
			bug rather than the rule it is.
		]]
		if (itemTable.isPA and itemTable.bodyType ~= "body") then
			local suit = request.suit
				or ix.armor.FindMatchingSuit(uniqueID)

			if (suit and not table.HasValue(order, suit)) then
				order[#order + 1] = suit
			end
		end

		if (not table.HasValue(order, uniqueID)) then
			order[#order + 1] = uniqueID
		end
	end

	if (#order < 1) then return end

	for _, uniqueID in ipairs(order) do
		inventory:Add(uniqueID)
	end

	--[[
		Equipped on the next tick: `inventory:Add` is asynchronous - the item
		instance does not exist until the database write comes back - so
		iterating immediately finds nothing to equip.
	]]
	timer.Simple(0.5, function()
		if (not IsValid(bot)) then return end

		local inv = bot:GetCharacter() and bot:GetCharacter():GetInventory()

		if (not inv) then return end

		for _, uniqueID in ipairs(order) do
			for item in ix.inventory.Each(inv) do
				if (item.uniqueID == uniqueID and not item:GetData("equip")) then
					ix.armor.Equip(bot, item)

					break
				end
			end
		end
	end)
end

hook.Add("PlayerInitialSpawn", "ixArmorDummyBot", function(client)
	if (not client:IsBot()) then return end

	local request = table.remove(pending, 1)

	if (not request) then return end

	client.ixDummyBot = true
	ix.armor.dummyBots[client] = true

	--[[
		Deferred, because Helix builds the bot's character in its own
		`PlayerInitialSpawn` - which runs after this listener. Half a second is
		well clear of that and of the `Sync` it schedules at 0.33.
	]]
	timer.Simple(0.6, function()
		Setup(client, request)
	end)
end)

--[[
	Back on its feet, in the same place.

	Helix respawns players from `GM:PlayerDeathThink`, which needs a `deathTime`
	netvar and a client that is actually running death-think - neither of which
	can be relied on for a bot, so a dead test bot simply stayed dead.

	The respawn is therefore explicit, and the position is restored with it: a
	target that comes back at the map's spawn point is no more use than one
	that does not come back at all. `ixDummyPos` is recorded when the bot is
	placed and never changes, so it returns to where you put it rather than to
	where it happened to be killed.
]]
ix.config.Add("dummyRespawnTime", 3,
	"How long a test bot takes to get back up, in seconds.", nil, {
	data = {min = 1, max = 60},
	category = "Armor"
})

hook.Add("PlayerDeath", "ixArmorDummyBot", function(client)
	if (not client.ixDummyBot) then return end

	timer.Simple(ix.config.Get("dummyRespawnTime", 3), function()
		if (IsValid(client) and client.ixDummyBot and not client:Alive()) then
			client:Spawn()
		end
	end)
end)

hook.Add("PlayerSpawn", "ixArmorDummyBot", function(client)
	if (not client.ixDummyBot) then return end

	--[[
		Deferred a frame because `PlayerLoadout` runs after this and sets the
		player up - including the model - and moving it before that is finished
		gets undone.
	]]
	timer.Simple(0, function()
		if (not IsValid(client)) then return end

		if (client.ixDummyPos) then
			client:SetPos(client.ixDummyPos)

			if (client.ixDummyAngles) then
				client:SetEyeAngles(client.ixDummyAngles)
			end
		end

		Immobilise(client)
	end)
end)

--[[
	Ask for a bot.

	Returns `false, reason` on refusal rather than notifying, matching the rest
	of `ix.armor`.
]]
function ix.armor.SpawnDummyBot(client, pieces, suitID)
	if (not IsValid(client)) then return false, "@dummyNoSlots" end

	--- One id or a list of them; every caller past this point has a list.
	if (isstring(pieces)) then pieces = {pieces} end

	pieces = pieces or {}

	--[[
		Slots are the one hard limit. `RunConsoleCommand("bot")` on a full
		server fails silently, leaving a queued request that the next real
		player to join would claim - so this is checked rather than attempted.
	]]
	if (player.GetCount() >= game.MaxPlayers()) then
		return false, "@dummyNoSlots"
	end

	local trace = client:GetEyeTrace()

	if (not trace.Hit) then return false, "@dummyNoSpot" end

	pending[#pending + 1] = {
		pieces = pieces,
		suit = suitID,
		position = trace.HitPos + trace.HitNormal * 8,
		angles = Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0)
	}

	RunConsoleCommand("bot")

	return true
end

--- Remove every test bot. The other half of a spawn button.
function ix.armor.ClearDummyBots()
	local removed = 0

	pending = {}

	for _, client in ipairs(player.GetAll()) do
		if (client.ixDummyBot or (client:IsBot() and ix.armor.dummyBots[client])) then
			ix.armor.dummyBots[client] = nil
			client:Kick("Test bot cleared")
			removed = removed + 1
		end
	end

	return removed
end

--[[
	Both handlers re-check admin from scratch. The panel decides what to offer;
	this decides what happens, and a net message can arrive without the panel
	ever being opened.
]]
local nextSpawn = {}

net.Receive("ixFODevDummy", function(length, client)
	if (not IsValid(client) or not client:IsAdmin()) then
		ix.log.Add(client, "devTerminalDenied")
		return
	end

	if ((nextSpawn[client] or 0) > RealTime()) then return end

	nextSpawn[client] = RealTime() + 0.5

	--[[
		A LIST, capped at the number of slots there are. Anything that is not
		a registered armour is dropped rather than refused: the message can
		arrive from anything, and one bad id should not lose the rest of a
		loadout somebody just picked.
	]]
	local count = math.min(net.ReadUInt(8), #ix.armor.slots)
	local pieces = {}

	for _ = 1, count do
		local uniqueID = net.ReadString()
		local itemTable = ix.item.list[uniqueID]

		if (itemTable and itemTable.isArmor) then
			pieces[#pieces + 1] = uniqueID
		end
	end

	local suitID = net.ReadString()

	if (suitID == "") then suitID = nil end

	local success, reason = ix.armor.SpawnDummyBot(client, pieces, suitID)

	if (not success) then
		client:NotifyLocalized(string.sub(reason, 2))
		return
	end

	ix.log.Add(client, "devDummySpawn",
		#pieces > 0 and table.concat(pieces, ", ") or "nothing")
end)

net.Receive("ixFODevDummyClear", function(length, client)
	if (not IsValid(client) or not client:IsAdmin()) then
		ix.log.Add(client, "devTerminalDenied")
		return
	end

	local removed = ix.armor.ClearDummyBots()

	client:NotifyLocalized("dummyCleared", removed)
	ix.log.Add(client, "devDummyClear", removed)
end)

hook.Add("PlayerDisconnected", "ixArmorDummyBot", function(client)
	nextSpawn[client] = nil
	ix.armor.dummyBots[client] = nil
end)

ix.log.AddType("devDummySpawn", function(client, uniqueID)
	return string.format("%s spawned a test bot wearing %s.", client:Name(), uniqueID)
end, FLAG_NORMAL)

ix.log.AddType("devDummyClear", function(client, amount)
	return string.format("%s removed %d test bots.", client:Name(), amount)
end, FLAG_NORMAL)
