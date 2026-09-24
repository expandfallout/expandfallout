--[[
	Every command this schema adds.

	COLLECTED HERE BECAUSE COMMANDS MUST BE SHARED.

	Helix never networks `ix.command.list`; a client only knows a command
	exists if the definition ran on the client too. Every one of these was
	originally declared inside a `sv_` file behind

	    if (not SERVER) then return end

	which works - the command runs - and means the chatbox autocomplete cannot
	see it, so typing `/charsetrace` offered no completion and no description.
	Helix's own commands are all in `core/sh_commands.lua` for exactly this
	reason.

	The `OnRun` bodies are unchanged and are still only ever called on the
	server: Helix's command router runs them there. A shared definition is
	safe, and it is the only way the client learns the name, the arguments and
	the description.

	Each block below names the library it belongs to, since the implementation
	it calls still lives with that system.
]]


--------------------------------------------------------------------------------
-- Levelling  (`sv_leveling.lua`)
--------------------------------------------------------------------------------

ix.command.Add("CharSetLevel", {
	description = "Set a character's level.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.number},

	OnRun = function(self, client, target, level)
		local character = target:GetCharacter()

		if (not character) then return "@invalidArg", 1 end

		level = math.max(math.Round(level), 1)

		character:SetLevel(level)
		character:SetXP(ix.leveling.RequiredXP(level))

		return string.format("%s is now level %d.", target:Name(), level)
	end
})

ix.command.Add("CharAddXP", {
	description = "Give a character XP, levelling them up if it is enough.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.number},

	OnRun = function(self, client, target, amount)
		local character = target:GetCharacter()

		if (not character) then return "@invalidArg", 1 end

		character:AddXP(amount)

		return string.format("%s now has %d XP (level %d).",
			target:Name(), character:GetXP(), character:GetLevel())
	end
})

--------------------------------------------------------------------------------
-- Radiation  (`sv_radiation.lua`)
--------------------------------------------------------------------------------

ix.command.Add("CharSetRads", {
	description = "Set a character's radiation level, 0 to 100.",
	adminOnly = true,
	arguments = {
		ix.type.player,
		ix.type.number
	},

	OnRun = function(self, client, target, amount)
		local character = target:GetCharacter()

		if (not character) then
			return "@invalidArg", 1
		end

		amount = math.Clamp(math.Round(amount), 0, 100)

		character:SetRadiation(amount)
		character:ApplyBodyState()

		local tier = ix.radiation.GetTier(amount)

		return string.format("%s is now at %d rads (%s).",
			target:Name(), amount, tier.name)
	end
})

ix.command.Add("CharAddRads", {
	description = "Add radiation to a character, applying their resistance.",
	adminOnly = true,
	arguments = {
		ix.type.player,
		ix.type.number
	},

	OnRun = function(self, client, target, amount)
		local character = target:GetCharacter()

		if (not character) then
			return "@invalidArg", 1
		end

		character:AddRadiation(amount)

		return string.format("%s is now at %d rads.",
			target:Name(), character:GetRadiation())
	end
})

--------------------------------------------------------------------------------
-- Hunger and thirst  (`sv_hunger.lua`)
--------------------------------------------------------------------------------

ix.command.Add("CharSetHunger", {
	description = "Set a character's hunger, 0 to 100.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.number},

	OnRun = function(self, client, target, amount)
		local character = target:GetCharacter()

		if (not character) then return "@invalidArg", 1 end

		character:SetHunger(amount)
		character:ApplyHungerThirst()

		return string.format("%s is now at %d%% hunger (%s).", target:Name(),
			character:GetHunger(), ix.hunger.GetHungerTier(character:GetHunger()).name)
	end
})

ix.command.Add("CharSetThirst", {
	description = "Set a character's thirst, 0 to 100.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.number},

	OnRun = function(self, client, target, amount)
		local character = target:GetCharacter()

		if (not character) then return "@invalidArg", 1 end

		character:SetThirst(amount)
		character:ApplyHungerThirst()

		return string.format("%s is now at %d%% thirst (%s).", target:Name(),
			character:GetThirst(), ix.hunger.GetThirstTier(character:GetThirst()).name)
	end
})

--------------------------------------------------------------------------------
-- Addiction  (`sv_addiction.lua`)
--------------------------------------------------------------------------------

ix.command.Add("CharCureAddictions", {
	description = "Cure every addiction a character has.",
	adminOnly = true,
	arguments = {ix.type.player},

	OnRun = function(self, client, target)
		if (not target:GetCharacter()) then return "@invalidArg", 1 end

		local cured = ix.addiction.Cure(target)

		return string.format("Cured %d addiction(s) on %s.", cured, target:Name())
	end
})

--------------------------------------------------------------------------------
-- Races  (`sv_racecommand.lua`)
--------------------------------------------------------------------------------

ix.command.Add("CharSetRace", {
	description = "Change a character's race.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.string},

	OnRun = function(self, client, target, class)
		local character = target:GetCharacter()

		if (not character) then return "@invalidArg", 1 end

		local previous = character:GetRace()

		--[[
			THE RULES ARE IN `ix.races.Apply` - the gender fix, the respawn,
			the body-state rebuild and the explicit save. A race injector goes
			through the same function, and this command is now only the
			permission check and the sentence it prints. See
			`sv_racecommand.lua`.
		]]
		local ok, result = ix.races.Apply(target, class)

		if (not ok) then
			return result .. " Use /classnameviewer to see them."
		end

		ix.log.Add(client, "charSetRace", target:Name(), previous,
			string.lower(string.Trim(class)))

		return string.format("%s is now a %s (was %s).",
			target:Name(), result.name, previous ~= "" and previous or "nothing")
	end
})

ix.command.Add("CharRaceList", {
	description = "List every race class name.",
	adminOnly = true,

	OnRun = function(self, client)
		local names = {}

		for class, race in pairs(ix.races.list) do
			names[#names + 1] = string.format("%s (%s)", class, race.name)
		end

		table.sort(names)

		client:ChatPrint(table.concat(names, ", "))

		return string.format("%d races.", #names)
	end
})

--------------------------------------------------------------------------------
-- Faction spawns  (`sv_spawns.lua`)
--------------------------------------------------------------------------------

ix.command.Add("FactionSpawnAdd", {
	description = "Add a spawn point for a faction where you are standing.",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.string},

	OnRun = function(self, client, faction, name)
		local target = ix.faction.teams[faction]

		if (not target) then
			return "No faction with the uniqueID '" .. faction ..
				"'. Use /classnameviewer to see them."
		end

		local index = ix.spawns.Add(faction, name, client:GetPos(),
			client:EyeAngles())

		return string.format("Added spawn %d for %s: %s.",
			index, target.name, name)
	end
})

ix.command.Add("FactionSpawnRemove", {
	description = "Remove one of a faction's spawn points by number.",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.number},

	OnRun = function(self, client, faction, index)
		if (not ix.spawns.Remove(faction, math.floor(index))) then
			return "That faction has no spawn point with that number."
		end

		return string.format("Removed spawn %d from %s.",
			math.floor(index), faction)
	end
})

ix.command.Add("FactionSpawnList", {
	description = "List every faction spawn point on this map.",
	adminOnly = true,

	OnRun = function(self, client)
		local configured = ix.spawns.GetConfigured()

		if (#configured == 0) then
			return "No faction has spawn points here - everyone uses the " ..
				"map's own."
		end

		for _, faction in ipairs(configured) do
			local team = ix.faction.teams[faction]

			client:ChatPrint(string.format("%s:",
				team and team.name or faction))

			for index, point in ipairs(ix.spawns.Get(faction)) do
				client:ChatPrint(string.format("  %d. %s", index,
					point.name or "Unnamed"))
			end
		end

		return string.format("%d faction(s) with spawn points.", #configured)
	end
})

ix.command.Add("FactionSpawnGoto", {
	description = "Teleport to one of a faction's spawn points.",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.number},

	OnRun = function(self, client, faction, index)
		local point = ix.spawns.Get(faction)[math.floor(index)]

		if (not point) then return "No such spawn point." end

		client:SetPos(point.position)

		return "Teleported to " .. (point.name or "it") .. "."
	end
})

--------------------------------------------------------------------------------
-- The class name viewer  (`sv_classnames.lua`)
--------------------------------------------------------------------------------

ix.command.Add("ClassNameViewer", {
	description = "Open a searchable list of faction, race, class and item IDs.",
	adminOnly = true,

	OnRun = function(self, client)
		net.Start("ixClassNamesOpen")
		net.Send(client)
	end
})

--------------------------------------------------------------------------------
-- Looting  (`sv_loot.lua`)
--------------------------------------------------------------------------------

ix.command.Add("LootConfig", {
	description = "Open the loot configurer.",
	adminOnly = true,

	OnRun = function(self, client)
		--[[
			Synced first. The editor lists tables from its mirror, and an admin
			who has just connected may not have one yet.
		]]
		ix.loot.Sync(client)

		net.Start("ixLootConfigOpen")
		net.Send(client)
	end
})

--------------------------------------------------------------------------------
-- The dev menu  (`sv_devmenu.lua`)
--------------------------------------------------------------------------------

ix.command.Add("DevMenu", {
	description = "Open the developer terminal.",
	adminOnly = true,

	OnRun = function(self, client)
		net.Start("ixFODevOpen")
		net.Send(client)
	end
})

--------------------------------------------------------------------------------
-- Factions
--------------------------------------------------------------------------------

--[[
	Move a character to another faction.

	Helix has no such command of its own - its factions are chosen once, at
	creation, and changed with a whitelist. On a schema with forty-five of them
	and sub-factions on top, an admin needs to be able to just say so.

	Like `/charsetrace`, this is not only a field: the faction decides the
	class, and a class from the old faction makes no sense in the new one.
]]
ix.command.Add("CharSetFaction", {
	description = "Move a character to another faction.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.string},

	OnRun = function(self, client, target, name)
		local character = target:GetCharacter()

		if (not character) then return "@invalidArg", 1 end

		name = string.lower(string.Trim(name))

		local faction = ix.faction.teams[name]

		if (not faction) then
			return "No faction with the uniqueID '" .. name ..
				"'. Use /classnameviewer to see them."
		end

		local previous = ix.faction.indices[character:GetFaction()]

		character:SetFaction(faction.index)

		--[[
			The class is cleared, not carried.

			A class belongs to one faction - `CLASS.faction` names it - so a
			character moved to another faction while still holding a class is
			in a state the class system says cannot exist. Clearing it puts
			them on the faction's default.
		]]
		if (character.SetClass) then
			character:SetClass(0)
		end

		--[[
			THE WHITELIST IS NOT GRANTED HERE, deliberately.

			The first version did, reasoning that a character in a faction
			ought to be allowed to be in it. That is wrong at the level of the
			player: it silently gave them permission to CREATE more characters
			in that faction forever, which survived deleting the one that had
			been moved.

			Moving one character and granting a player standing access are two
			different decisions, and Helix already has a command for the
			second - `/plywhitelist <player> <faction>`. Keeping them separate
			is what makes "you have to be whitelisted by command" true.
		]]

		character:Save()

		if (target:Alive()) then
			target:Spawn()
		end

		ix.log.Add(client, "charSetFaction", target:Name(),
			previous and previous.name or "nothing", faction.name)

		--[[
			WHAT HAPPENED, and nothing else. The reminder about whitelisting
			used to be tacked on here - it is true, it is in the doc, and it is
			not what somebody who has just moved a character needs to read
			every single time.
		]]
		return string.format("%s is now %s (was %s).", target:Name(),
			faction.name, previous and previous.name or "nothing")
	end
})

--[[
	What a faction is part of, and what is part of it.

	Reads the links rather than setting them - `/factionlink` does that - so
	somebody checking a hierarchy does not need the configurator open.
]]
ix.command.Add("FactionTree", {
	description = "Show which factions are grouped under which.",
	adminOnly = true,

	OnRun = function(self, client)
		local roots = ix.faction.GetRoots()

		if (#roots == 0) then
			return "No faction has any sub-factions. Use /factionlink."
		end

		for _, root in ipairs(roots) do
			local team = ix.faction.teams[root]

			client:ChatPrint(string.format("%s (%s)",
				team and team.name or root, root))

			for _, child in ipairs(ix.faction.GetChildren(root)) do
				local sub = ix.faction.teams[child]

				client:ChatPrint(string.format("    %s (%s)",
					sub and sub.name or child, child))
			end
		end

		return string.format("%d faction group(s).", #roots)
	end
})

--[[
	The configurer, which is the same three commands with the roster in front
	of you. Forty-five uniqueIDs is more than anybody should have to remember
	to type `/factionlink` correctly.
]]
ix.command.Add("FactionConfig", {
	description = "Open the sub-faction configurer.",
	adminOnly = true,

	OnRun = function(self, client)
		net.Start("ixFactionTreeOpen")
		net.Send(client)
	end
})

ix.command.Add("FactionLink", {
	description = "Make one faction a sub-faction of another.",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.string},

	OnRun = function(self, client, child, parent)
		local ok, reason = ix.faction.SetParent(string.lower(child),
			string.lower(parent))

		if (not ok) then return reason end

		return string.format("%s is now under %s.", child, parent)
	end
})

ix.command.Add("FactionUnlink", {
	description = "Detach a sub-faction from its parent.",
	adminOnly = true,
	arguments = {ix.type.string},

	OnRun = function(self, client, child)
		local ok, reason = ix.faction.SetParent(string.lower(child), nil)

		if (not ok) then return reason end

		return child .. " is no longer a sub-faction."
	end
})

--------------------------------------------------------------------------------
-- Stealth  (`sh_armor.lua`)
--------------------------------------------------------------------------------

--[[
	The stealth field, for anybody who has not bound the key.

	`toggleStealth` is Phoenix's concommand name and it is kept so binds carried
	over from their server still work - but it has no default key, so on a fresh
	install the only way to cloak in a stealth suit was to know the command
	existed and bind it yourself. This is the same switch with a name the
	chatbox can complete.

	Not admin only, and it needs no arguments: every check that matters is in
	`ix.armor.CanStealth`, which asks what you are wearing.
]]
ix.command.Add("Stealth", {
	description = "Turn your stealth field on or off. Bind: toggleStealth.",

	OnRun = function(self, client)
		if (not client:Alive()) then return "@notNow" end

		local character = client:GetCharacter()

		if (not character or not ix.armor.CanStealth(character)) then
			return "You have nothing that generates a stealth field."
		end

		--[[
			A Stealth Boy runs itself. See `ix.armor.IsChemStealth` - toggling
			against a chem that is still counting down is two things driving
			one switch, and turning it off would only mean the next buff
			refresh turned it back on.
		]]
		if (ix.armor.IsChemStealth(client)) then
			return "The Stealth Boy is running. Wait for it to wear off."
		end

		local enabled = ix.armor.IsStealthed(client)

		if (not enabled) then
			--[[
				The suits' own veto, six of which define one - it is where
				"you need your hands free" lives. Asked before cloaking, never
				after, and the same order the bind uses.
			]]
			for _, item in pairs(ix.armor.GetEquipped(character)) do
				if (item.requestStealth
				and item.requestStealth(item, client, true) == false) then
					return
				end
			end
		end

		ix.armor.SetStealth(client, not enabled)

		return enabled and "Stealth field off." or "Stealth field on."
	end
})

--------------------------------------------------------------------------------
-- Classes  (`sh_classrank.lua`)
--------------------------------------------------------------------------------

--[[
	Put a character in a class. The counterpart to `/charsetfaction`, and it
	works the same way: it sets the field, saves, and that is all.

	There is nothing to grant alongside it. Class is not something a player can
	give themselves - `/becomeclass` is removed and the Classes tab with it, so
	the only two ways into a class are this command and somebody above you in
	your faction using the C menu. See `sh_classrank.lua` for why an earlier
	version of this needed a permission system and this one does not.

	To take a class away, set them to a different one. There is no
	`/classrevoke` for the same reason there is no "un-set faction": the field
	always holds something, so changing it IS the removal.
]]
ix.command.Add("CharSetClass", {
	description = "Put a character in one of their faction's classes.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.string},

	OnRun = function(self, client, target, class)
		local character = target:GetCharacter()

		if (not character) then return "@invalidArg", 1 end

		local wanted = string.lower(class)
		local info

		for _, v in ipairs(ix.class.list) do
			if (v.uniqueID == wanted) then
				info = v
				break
			end
		end

		if (not info) then
			return "No class with the uniqueID '" .. class
				.. "'. Use /classnameviewer to see them."
		end

		if (info.faction ~= character:GetFaction()) then
			return string.format("%s is a %s class; they are in %s.", info.name,
				ix.faction.indices[info.faction]
					and ix.faction.indices[info.faction].name or "another faction",
				ix.faction.indices[character:GetFaction()]
					and ix.faction.indices[character:GetFaction()].name or "none")
		end

		local previous = ix.class.list[character:GetClass()]

		--[[
			SAVED EXPLICITLY, the same reason `/charsetfaction` is: `SetClass`
			is a generated setter that writes `self.vars` and networks it
			without touching the database, so without this the change holds
			until the next restart and then quietly does not - which looks
			exactly like it worked.
		]]
		character:SetClass(info.index)
		character:Save()

		target:Notify("You are now " .. info.name .. ".")

		return string.format("%s is now %s (was %s).",
			character:GetName(), info.name,
			previous and previous.name or "nothing")
	end
})

--------------------------------------------------------------------------------
-- The faction shop  (`sh_shop.lua`, `sv_shop.lua`)
--------------------------------------------------------------------------------

--[[
	The configurer. Everything a faction sells, in one window.

	Admin only, and re-checked at every net handler behind it: having the
	window open is not permission to change anything.
]]
ix.command.Add("ShopConfig", {
	description = "Configure what each faction sells, and to which ranks.",
	adminOnly = true,

	OnRun = function(self, client)
		--[[
			`SendAll`, not a "please open" message.

			The first version sent `ixShopConfigOpen` to the client - a
			netstring whose only receiver is on the SERVER, where it answers
			the panel asking for a refresh. Nothing on the client listened for
			it, so the command sent a message into the void and no window ever
			appeared. The configurer opens when the DATA arrives, which is what
			this sends.
		]]
		ix.shop.SendAll(client)
	end
})

--[[
	What YOUR faction sells, in chat.

	Reads rather than sets, and answers faster than opening the tab when you
	only want to know whether the thing is stocked.
]]
ix.command.Add("ShopList", {
	description = "List what your faction sells.",

	OnRun = function(self, client)
		local character = client:GetCharacter()

		if (not character) then return "@illegalAccess" end

		local faction = ix.faction.indices[character:GetFaction()]

		if (not faction) then return "You are not in a faction." end

		--[[
			`GetFor`, so what this prints is what the Shop tab shows - the
			global entries included. A list that disagreed with the tab would
			be worse than no list.
		]]
		local list = ix.shop.GetFor(faction.uniqueID)
		local count = 0

		for uniqueID, entry in SortedPairs(list) do
			local itemTable = ix.item.list[uniqueID]

			client:ChatPrint(string.format("%s - %s - rank %d - %d in stock",
				itemTable and itemTable.name or uniqueID,
				ix.currency.Get(entry.price or 0), entry.rank or 1,
				entry.stock or 0))

			count = count + 1
		end

		if (count == 0) then
			return "Nothing is for sale to you. An admin uses /shopconfig."
		end

		return string.format("%d thing(s) for sale to you.", count)
	end
})

--------------------------------------------------------------------------------
-- Faction management  (`sv_factionmanage.lua`, `sv_factionstorage.lua`)
--------------------------------------------------------------------------------

--[[
	Your own faction's roster and its deployables.

	NOT ADMIN ONLY. Everybody in a faction may open it; what they can DO in it
	is what their class allows, and the window shows the difference rather than
	refusing at the door - knowing who is above you is most of the point of a
	roster.
]]
ix.command.Add("FactionManagement", {
	description = "Manage your faction's members and deployables.",
	alias = {"fm"},

	OnRun = function(self, client)
		ix.factionManage.Send(client, "", false)
	end
})

--[[
	The same window, for EVERY faction, with a list of them down the side.

	SUPERADMIN. This is every roster on the server, every rank in them and
	every faction's property, and it bypasses the below-your-own-rank rule that
	governs everybody else - which is also the only way a faction's first Lead
	can ever be appointed, since nobody inside it can hand out their own rank.

	The faction argument is a shortcut, not a requirement: with none, the
	window opens on the first faction and offers the rest in a column.
]]
ix.command.Add("AdminFactionManagement", {
	description = "Manage every faction's members and deployables.",
	superAdminOnly = true,
	alias = {"afm"},
	arguments = {bit.bor(ix.type.string, ix.type.optional)},

	OnRun = function(self, client, faction)
		faction = string.lower(string.Trim(faction or ""))

		if (faction ~= "" and not ix.faction.teams[faction]) then
			return "No faction with the uniqueID '" .. faction
				.. "'. Use /classnameviewer to see them."
		end

		ix.factionManage.Send(client, faction, true)
	end
})

--[[
	Make a faction a storage. Admin only - "admins make them for you" - and it
	arrives STOWED, because an admin standing in a menu is not standing where
	the faction wants it.
]]
ix.command.Add("FactionStorageCreate", {
	description = "Create a storage for a faction, at any size.",
	adminOnly = true,
	arguments = {
		ix.type.string,
		ix.type.number,
		ix.type.number,
		bit.bor(ix.type.string, ix.type.optional)
	},

	OnRun = function(self, client, faction, width, height, name)
		faction = string.lower(string.Trim(faction))

		if (not ix.faction.teams[faction]) then
			return "No faction with the uniqueID '" .. faction .. "'."
		end

		local record = ix.factionStorage.Create(faction, name,
			math.floor(width), math.floor(height), 1)

		if (not record) then return "That could not be created." end

		return string.format("Created %s for %s, %dx%d. Their Lead deploys it "
			.. "from /fm.", record.name, ix.faction.teams[faction].name,
			record.width, record.height)
	end
})

ix.command.Add("FactionStorageList", {
	description = "Every faction storage on the server.",
	adminOnly = true,

	OnRun = function(self, client)
		local count = 0

		for _, record in SortedPairs(ix.factionStorage.list) do
			local faction = ix.faction.teams[record.faction]

			client:ChatPrint(string.format(
				"%d - %s - %s - %dx%d - %s",
				record.id, record.name,
				faction and faction.name or record.faction,
				record.width, record.height,
				record.placed and ("on " .. tostring(record.map)) or "stowed"))

			count = count + 1
		end

		if (count == 0) then
			return "There are none. /factionstoragecreate makes one."
		end

		return count .. " storage(s)."
	end
})

--[[
	Destroy one, and everything in it. Superadmin, because it is the only
	action here that cannot be undone - a stow keeps the items, this does not.
]]
ix.command.Add("FactionStorageDestroy", {
	description = "Destroy a faction storage and everything in it.",
	superAdminOnly = true,
	arguments = {ix.type.number},

	OnRun = function(self, client, id)
		local record = ix.factionStorage.Get(math.floor(id))

		if (not record) then return "No storage with that id." end

		local name = record.name

		ix.factionStorage.Destroy(record)

		return "Destroyed " .. name .. " and everything in it."
	end
})

--------------------------------------------------------------------------------
-- Workbenches  (`sh_bench.lua`, `sv_bench.lua`)
--------------------------------------------------------------------------------

--[[
	The creator and configurer. Every kind of bench, in one window.

	Admin only, and re-checked at every net handler behind it: having the
	window open is not permission to write anything into the table.

	`SendAll` with the config flag rather than a "please open" message - the
	window opens when its DATA arrives. `/shopconfig` taught that one the hard
	way; see the note on `ix.bench.SendAll`.
]]
ix.command.Add("BenchConfig", {
	description = "Create and configure workbenches.",
	adminOnly = true,

	OnRun = function(self, client)
		ix.bench.SendAll(client, true)
	end
})

--[[
	Put one down, with the same placement ghost the faction storages use.

	The bench is named rather than picked from a menu, because this is the
	command and the menu is `/benchconfig`. Tab completion is what makes it
	bearable, so the argument is a `ix.type.string` with the ids listed by
	`/benchlist`.
]]
ix.command.Add("BenchPlace", {
	description = "Place a workbench where you are aiming.",
	adminOnly = true,
	arguments = {ix.type.string},

	OnRun = function(self, client, uniqueID)
		uniqueID = string.lower(string.Trim(uniqueID or ""))

		local definition = ix.bench.GetType(uniqueID)

		if (not definition) then
			return "No bench called '" .. uniqueID .. "'. /benchlist shows "
				.. "them."
		end

		--[[
			The GHOST is what places it, not this. The command only tells the
			client to start aiming; `ixBenchPlace` is what arrives afterwards
			with a position, and it checks the permission again - a command
			that placed a bench at the player's feet would be easier to write
			and impossible to aim.
		]]
		net.Start("ixBenchBeginPlacing")
			net.WriteString(uniqueID)
		net.Send(client)
	end
})

--- Remove the one you are looking at, and everything inside it.
ix.command.Add("BenchRemove", {
	description = "Remove the workbench you are looking at.",
	adminOnly = true,

	OnRun = function(self, client)
		local entity = client:GetEyeTrace().Entity

		if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
			return "You are not looking at a workbench."
		end

		if (client:GetPos():Distance(entity:GetPos()) > 250) then
			return "Stand closer to it."
		end

		local record = ix.bench.Get(entity:GetBenchID())

		if (not record) then
			--[[
				An entity with no record is a bench that lost its record, and
				leaving it standing means a prop nobody can open. It goes,
				because there is nothing else it could be.
			]]
			entity:Remove()

			return "That bench had no record. Removed the prop."
		end

		local definition = ix.bench.TypeOf(record)

		ix.bench.Destroy(record)

		return string.format("Removed bench %d (%s) and everything in it.",
			record.id, definition and definition.name or record.bench)
	end
})

--- What kinds exist, and how many of each are out.
ix.command.Add("BenchList", {
	description = "List every kind of workbench.",
	adminOnly = true,

	OnRun = function(self, client)
		local sorted = ix.bench.SortedTypes()

		for _, definition in ipairs(sorted) do
			local mode = ix.bench.GetMode(definition.mode)

			client:ChatPrint(string.format(
				"%s (%s) - %s - %d recipe(s) - %d placed",
				definition.uniqueID, definition.name,
				mode and mode.name or definition.mode,
				#(definition.recipes or {}),
				ix.bench.CountPlaced(definition.uniqueID)))
		end

		if (#sorted == 0) then
			return "No benches yet. /benchconfig makes one."
		end

		return string.format("%d kind(s) of bench.", #sorted)
	end
})

--[[
	Hand a captured bench back to nobody.

	Separate from removing one, because losing the bench and losing who holds
	it are different mistakes to want to undo - and the usual reason to want
	this is a faction that has disbanded holding something nobody can now take
	off them by fighting for it.
]]
ix.command.Add("BenchRelease", {
	description = "Release the workbench you are looking at, so anyone may "
		.. "take it.",
	adminOnly = true,

	OnRun = function(self, client)
		local entity = client:GetEyeTrace().Entity

		if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
			return "You are not looking at a workbench."
		end

		local record = ix.bench.Get(entity:GetBenchID())

		if (not record) then return "That bench has no record." end

		local definition = ix.bench.TypeOf(record)

		if (not definition or not definition.capturable) then
			return "That bench is not one that gets captured."
		end

		if (not record.owner) then return "Nobody holds it." end

		local held = ix.bench.OwnerName(record)

		ix.bench.Release(record)

		return string.format("Released %s - it was held by %s.",
			definition.name, held)
	end
})

--------------------------------------------------------------------------------
-- Administration  (`sh_usergroups.lua`, `sv_adminlog.lua`)
--------------------------------------------------------------------------------

--[[
	The admin menu.

	`player.list` rather than `adminOnly`, because Helix's flag means
	`IsAdmin()` and the whole point of the usergroup ladder is that a helper
	can be trusted with the player list without being trusted with everything
	an admin can do.
]]
ix.command.Add("Admin", {
	description = "Open the administration menu.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.list")
	end,

	OnRun = function(self, client)
		net.Start("ixAdminOpen")
		net.Send(client)
	end
})

--- Go to somebody.
ix.command.Add("PlyGoto", {
	description = "Teleport to a player.",

	--[[
		THE NAME STAFF ACTUALLY TYPE. `!goto` is what every admin mod in this
		game calls it, and a command nobody can guess the name of is a command
		nobody uses - which is how "the admin commands are missing" happens
		when they are all there under longer names.
	]]
	alias = {"Goto", "Tp"},
	arguments = {ix.type.player},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.goto")
	end,

	OnRun = function(self, client, target)
		--[[
			Behind them and slightly up, not on top of them. Arriving inside
			somebody is how a staff member ends up stuck in a wall, and the
			offset costs one vector.
		]]
		client:SetPos(target:GetPos() - target:GetAngles():Forward() * 60
			+ Vector(0, 0, 8))

		ix.admin.Announce(client, string.format("%s went to %s.",
			client:SteamName(), target:Name()))

		ix.log.Add(client, "adminGoto", target:Name(), target:SteamID())

		return "Teleported to " .. target:Name() .. "."
	end
})

--- Bring somebody to you.
ix.command.Add("PlyBring", {
	description = "Teleport a player to you.",
	alias = {"Bring"},
	arguments = {ix.type.player},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.bring")
	end,

	OnRun = function(self, client, target)
		if (not ix.admin.Outranks(client, target)) then
			return "They outrank you."
		end

		--[[
			Where they were is remembered first, so `/return` can undo this.
			Bringing somebody out of a scene and being unable to put them back
			is the complaint that follows every bring.
		]]
		if (ix.admin.RememberPosition) then
			ix.admin.RememberPosition(target)
		end

		target:SetPos(client:GetPos() + client:GetAngles():Forward() * 60
			+ Vector(0, 0, 8))

		ix.admin.Quiet(client, target, client:Name() .. " brought you.")

		ix.admin.Announce(client, string.format("%s brought %s.",
			client:SteamName(), target:Name()))

		ix.log.Add(client, "adminBring", target:Name(), target:SteamID())

		return "Brought " .. target:Name() .. "."
	end
})

--- Remove somebody from the server, with a reason that is written down.
ix.command.Add("PlyKick", {
	description = "Kick a player.",
	alias = {"Kick"},
	arguments = {ix.type.player, bit.bor(ix.type.text, ix.type.optional)},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.kick")
	end,

	OnRun = function(self, client, target, reason)
		if (not ix.admin.Outranks(client, target)) then
			return "They outrank you, or match you."
		end

		reason = reason and string.Trim(reason) or ""

		if (reason == "") then reason = "No reason given." end

		local name = target:Name()

		--[[
			Logged BEFORE the kick, because logging afterwards means logging
			against a player entity that has already gone - and the name and
			SteamID are the whole value of the entry.
		]]
		ix.admin.Announce(client, string.format("%s kicked %s - %s",
			client:SteamName(), name, reason))

		ix.log.Add(client, "adminKick", name, target:SteamID(), reason)

		--[[
			A SILENT KICK STILL KICKS THEM - it just does not sign itself.

			The disconnect reason is the one thing about a kick the player
			always sees, so `~kick` gives them the reason without the name.
			Pretending nothing happened is not available: they are leaving.
		]]
		target:Kick(ix.admin.IsSilent(client)
			and ("Kicked: " .. reason)
			or string.format("Kicked by %s: %s", client:Name(), reason))

		return string.format("Kicked %s - %s", name, reason)
	end
})

--- Read the log from chat, for when the menu is not to hand.
ix.command.Add("Logs", {
	description = "Search the log.",
	arguments = {bit.bor(ix.type.text, ix.type.optional)},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "log.view")
	end,

	OnRun = function(self, client, text)
		local results = ix.adminlog.Search({
			text = text and string.Trim(text) or nil, limit = 20
		})

		for index = #results, 1, -1 do
			local entry = results[index]

			client:ChatPrint(string.format("[%s] %s",
				os.date("%H:%M:%S", entry.time), entry.message))
		end

		return string.format("%d result(s) - /admin has the full search.",
			#results)
	end
})

--[[
	SERVER ONLY, and this file is shared.

	`ix.log.AddType` is defined inside `if (SERVER)` in Helix's `sh_log.lua`,
	so on the client it is nil - and calling it here took the whole schema down
	on load with

	    attempt to call field 'AddType' (a nil value)

	which is why a character load ended on a grey screen: the client never
	finished including the schema. Every other `AddType` in this schema is in a
	`sv_` file that returns early on the client; these were the only three in a
	shared one.
]]
if (SERVER) then
	ix.log.AddType("adminGoto", function(client, name, steamID)
		return string.format("%s teleported to %s (%s).", client:Name(), name,
			steamID)
	end, FLAG_DEV)

	ix.log.AddType("adminBring", function(client, name, steamID)
		return string.format("%s brought %s (%s).", client:Name(), name,
			steamID)
	end, FLAG_DEV)

	ix.log.AddType("adminKick", function(client, name, steamID, reason)
		return string.format("%s kicked %s (%s) - %s", client:Name(), name,
			steamID, reason)
	end, FLAG_DANGER)
end

--------------------------------------------------------------------------------
-- Bans and warnings  (`sh_punish.lua`, `sv_punish.lua`)
--------------------------------------------------------------------------------

--[[
	Ban somebody who is here.

	The length is written the way people write it - `30`, `2h`, `7d`, `0` for
	permanent - and a bare number is MINUTES, which is what every admin mod has
	trained people to expect. Disagreeing with that convention would produce
	very long accidental bans.
]]
ix.command.Add("Ban", {
	description = "Ban a player. Length: 30, 2h, 7d, or 0 for permanent.",
	arguments = {ix.type.player, ix.type.string,
		bit.bor(ix.type.text, ix.type.optional)},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.ban")
	end,

	OnRun = function(self, client, target, length, reason)
		local seconds = ix.punish.ParseLength(length)

		if (not seconds) then
			return "That is not a length. Try 30, 2h, 7d, or 0."
		end

		local ok, why = ix.punish.Ban(client, target:SteamID64(),
			target:Name(), seconds, reason)

		if (not ok) then return why end

		return string.format("Banned %s for %s.", target:Name(),
			ix.punish.FormatLength(seconds))
	end
})

--- The same, for somebody who is not connected.
ix.command.Add("BanID", {
	description = "Ban a SteamID that is not connected.",
	arguments = {ix.type.string, ix.type.string,
		bit.bor(ix.type.text, ix.type.optional)},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.ban")
	end,

	OnRun = function(self, client, steamID, length, reason)
		steamID = string.Trim(steamID)

		--[[
			Both forms are accepted, because an admin copying an id out of the
			log has the STEAM_0 form and one copying it from a Steam profile
			has the 64-bit one. Refusing either would be a papercut in the
			middle of something urgent.
		]]
		if (string.find(steamID, "STEAM_", 1, true)) then
			steamID = util.SteamIDTo64(steamID)
		end

		if (not steamID or #steamID < 17) then
			return "That is not a SteamID."
		end

		local seconds = ix.punish.ParseLength(length)

		if (not seconds) then
			return "That is not a length. Try 30, 2h, 7d, or 0."
		end

		local ok, why = ix.punish.Ban(client, steamID, nil, seconds, reason)

		if (not ok) then return why end

		return string.format("Banned %s for %s.", steamID,
			ix.punish.FormatLength(seconds))
	end
})

ix.command.Add("Unban", {
	description = "Lift a ban.",
	arguments = {ix.type.string},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.ban")
	end,

	OnRun = function(self, client, steamID)
		steamID = string.Trim(steamID)

		if (string.find(steamID, "STEAM_", 1, true)) then
			steamID = util.SteamIDTo64(steamID)
		end

		local ok, name = ix.punish.Unban(client, steamID)

		return ok and ("Unbanned " .. name .. ".") or name
	end
})

ix.command.Add("Bans", {
	description = "List the bans.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.ban")
	end,

	OnRun = function(self, client)
		local count = 0

		for steamID, ban in SortedPairs(ix.punish.bans) do
			local remaining = ix.punish.Remaining(ban)

			client:ChatPrint(string.format("%s (%s) - %s - by %s - %s",
				ban.name, steamID,
				(ban.length or 0) <= 0 and "permanent"
					or (ix.punish.FormatLength(remaining) .. " left"),
				ban.admin, ban.reason))

			count = count + 1
		end

		return count == 0 and "Nobody is banned."
			or string.format("%d ban(s).", count)
	end
})

ix.command.Add("Warn", {
	description = "Warn a player, on the record.",
	arguments = {ix.type.player, ix.type.text},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.warn")
	end,

	OnRun = function(self, client, target, reason)
		local ok, result = ix.punish.Warn(client, target, reason)

		if (not ok) then return result end

		return string.format("Warned %s - that is number %d.", target:Name(),
			result)
	end
})

ix.command.Add("Warns", {
	description = "Read somebody's warnings.",
	arguments = {ix.type.string},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.warn")
	end,

	OnRun = function(self, client, identifier)
		identifier = string.Trim(identifier)

		--[[
			A name OR a SteamID, because the person asking usually has one of
			them and not the other - and which one depends entirely on whether
			the player is standing in front of them.
		]]
		local steamID = identifier

		if (string.find(identifier, "STEAM_", 1, true)) then
			steamID = util.SteamIDTo64(identifier)
		elseif (#identifier < 17) then
			local target = ix.util.FindPlayer(identifier)

			if (not IsValid(target)) then return "Nobody by that name." end

			steamID = target:SteamID64()
		end

		local list = ix.punish.warnings[steamID]

		if (not list or #list == 0) then return "No warnings." end

		for index, warning in ipairs(list) do
			client:ChatPrint(string.format("%d. [%s] %s - by %s", index,
				os.date("%d/%m/%Y", warning.time), warning.reason,
				warning.admin))
		end

		return string.format("%d warning(s).", #list)
	end
})

ix.command.Add("Unwarn", {
	description = "Remove one warning by its number.",
	arguments = {ix.type.string, ix.type.number},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.warn.remove")
	end,

	OnRun = function(self, client, steamID, index)
		steamID = string.Trim(steamID)

		if (string.find(steamID, "STEAM_", 1, true)) then
			steamID = util.SteamIDTo64(steamID)
		end

		local ok, result = ix.punish.RemoveWarning(client, steamID,
			math.floor(index))

		return ok and ("Removed: " .. result) or result
	end
})

--------------------------------------------------------------------------------
-- Zones
--------------------------------------------------------------------------------

--[[
	Claiming ground.

	The area is named rather than taken from where you stand, because the
	interesting case is a lead standing at the edge of two of them, and
	"whichever box I happen to be in" is not a decision anybody can see being
	made. Left empty it does use the one you are in, which is the common case.
]]
ix.command.Add("ClaimArea", {
	description = "Claim the area you are in for your faction.",
	arguments = {bit.bor(ix.type.string, ix.type.optional)},

	OnRun = function(self, client, id)
		id = string.Trim(id or "")

		if (id == "") then
			local position = client:GetPos() + client:OBBCenter()
			local found = ix.zones.Displayed(position)

			if (not found) then return "You are not standing in an area." end

			id = found
		end

		local ok, result = ix.zones.BeginCapture(client, id)

		if (not ok) then return result end

		return string.format("Holding %s - stay in it for %d second(s).", id,
			result)
	end
})

ix.command.Add("UnclaimArea", {
	description = "Give up an area your faction holds.",
	arguments = {bit.bor(ix.type.string, ix.type.optional)},

	OnRun = function(self, client, id)
		id = string.Trim(id or "")

		if (id == "") then
			local position = client:GetPos() + client:OBBCenter()
			local found = ix.zones.Displayed(position)

			if (not found) then return "You are not standing in an area." end

			id = found
		end

		local ok, result = ix.zones.Release(client, id)

		return ok and ("Released. " .. result .. " no longer holds it.")
			or result
	end
})

--[[
	Every claimable area and who holds it.

	Open to everybody. Which ground is whose is exactly the sort of thing the
	whole server is meant to know and argue about; hiding it behind a rank
	would make the claiming pointless.
]]
ix.command.Add("Areas", {
	description = "List the areas and who holds them.",

	OnRun = function(self, client)
		local shown = 0

		for id, area in SortedPairs(ix.area.stored) do
			local zoneType = ix.zones.TypeOf(area)

			if (not zoneType or not zoneType.display) then continue end

			local owner = ix.zones.Owner(area)

			client:ChatPrint(string.format("%s%s - %s", id,
				zoneType.claimable and "" or " (not claimable)",
				owner and ("held by " .. owner.name) or "unclaimed"))

			shown = shown + 1
		end

		return shown == 0 and "There are no areas." or
			string.format("%d area(s).", shown)
	end
})

--[[
	Every zone, including the ones that are not places.

	Admin-side, because a list of radiation clouds and out-of-bounds boxes is a
	map-building tool rather than something in character.
]]
ix.command.Add("Zones", {
	description = "List every zone, including radiation and out of bounds.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "zone.edit")
	end,

	OnRun = function(self, client)
		local shown = 0

		for id, area in SortedPairs(ix.area.stored) do
			local zoneType = ix.zones.TypeOf(area)
			local properties = ix.zones.Properties(area)
			local note = ""

			if (area.type == "radiation") then
				note = string.format(" - %d rad/s",
					tonumber(properties.radiation) or 0)
			elseif (area.type == "outofbounds") then
				note = string.format(" - kills after %ds",
					tonumber(properties.killTime) or 5)
			end

			client:ChatPrint(string.format("%s [%s]%s", id,
				zoneType and zoneType.name or area.type, note))

			shown = shown + 1
		end

		return shown == 0 and "There are no zones." or
			string.format("%d zone(s).", shown)
	end
})

ix.command.Add("ZoneDelete", {
	description = "Delete a zone by name.",
	arguments = {ix.type.string},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "zone.edit")
	end,

	OnRun = function(self, client, id)
		id = string.Trim(id)

		if (not ix.zones.Remove(id)) then
			return "There is no zone called that."
		end

		ix.log.Add(client, "zoneRemove", id)

		return "Deleted '" .. id .. "'."
	end
})

--------------------------------------------------------------------------------
-- Doors
--------------------------------------------------------------------------------

--[[
	Several factions on one door.

	Helix has `/DoorSetFaction`, which sets exactly one and clears it when set
	again. This is the list beside it - see `sh_doors.lua` for why it is a
	layer rather than a change to that.

	Takes a NAME, not a uniqueID. The tool panel takes uniqueIDs because a
	convar is a string and there is nowhere to put a menu; a chat command can
	afford to be friendly, and `ix.util.FindFaction` is what every other
	faction command in Helix uses.
]]
ix.command.Add("DoorFactionAdd", {
	description = "Let another faction use the door you are looking at.",
	arguments = {ix.type.text},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "door.edit")
	end,

	OnRun = function(self, client, name)
		local door = client:GetEyeTrace().Entity

		if (not IsValid(door) or not door:IsDoor()) then
			return "Look at a door."
		end

		local faction = ix.doors.FindFaction(name)

		if (not faction) then
			return "There is no faction by that name, or it matches more "
				.. "than one."
		end

		local list = table.Copy(ix.doors.FactionIDs(door))

		for _, uniqueID in ipairs(list) do
			if (uniqueID == faction.uniqueID) then
				return faction.name .. " is already on it."
			end
		end

		list[#list + 1] = faction.uniqueID

		local ok, why = ix.doors.SetFactions(client, door, list)

		if (not ok) then return why end

		return faction.name .. " may now use that door."
	end
})

ix.command.Add("DoorFactionRemove", {
	description = "Stop a faction using the door you are looking at.",
	arguments = {ix.type.text},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "door.edit")
	end,

	OnRun = function(self, client, name)
		local door = client:GetEyeTrace().Entity

		if (not IsValid(door) or not door:IsDoor()) then
			return "Look at a door."
		end

		local faction = ix.doors.FindFaction(name)

		if (not faction) then
			return "There is no faction by that name, or it matches more "
				.. "than one."
		end

		local list = {}
		local found = false

		for _, uniqueID in ipairs(ix.doors.FactionIDs(door)) do
			if (uniqueID == faction.uniqueID) then
				found = true
			else
				list[#list + 1] = uniqueID
			end
		end

		if (not found) then return faction.name .. " was not on it." end

		local ok, why = ix.doors.SetFactions(client, door, list)

		if (not ok) then return why end

		return faction.name .. " may no longer use that door."
	end
})

ix.command.Add("DoorFactions", {
	description = "Say who may use the door you are looking at.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "door.edit")
	end,

	OnRun = function(self, client)
		local door = client:GetEyeTrace().Entity

		if (not IsValid(door) or not door:IsDoor()) then
			return "Look at a door."
		end

		local factions = ix.doors.Factions(door)
		local link = ix.doors.Link(door)

		if (link) then
			client:ChatPrint(string.format("  teleport to %s%s",
				tostring(link.position),
				link.name ~= "" and (" - '" .. link.name .. "'") or ""))
		end

		if (#factions == 0) then
			return link and "Anybody may use that teleport."
				or "No extra factions on that door."
		end

		for _, faction in ipairs(factions) do
			client:ChatPrint("  " .. faction.name)
		end

		return string.format("%d faction(s) on that door.", #factions)
	end
})

ix.command.Add("DoorTeleportClear", {
	description = "Stop the door you are looking at being a teleport.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "door.edit")
	end,

	OnRun = function(self, client)
		local ok, why = ix.doors.ClearLink(client,
			client:GetEyeTrace().Entity)

		return ok and "It is an ordinary door again." or why
	end
})

--------------------------------------------------------------------------------
-- Points
--------------------------------------------------------------------------------

ix.command.Add("DropPoints", {
	description = "List the orbital drop sites on this map.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "point.edit")
	end,

	OnRun = function(self, client)
		local count = 0

		for id, record in pairs(ix.points.stored) do
			if (record.type ~= "orbital") then continue end

			client:ChatPrint(string.format("  %s - %s at %s", tostring(id),
				record.data.name or "unnamed", tostring(record.position)))

			count = count + 1
		end

		return count == 0 and "No drop sites on this map."
			or string.format("%d drop site(s).", count)
	end
})

ix.command.Add("Points", {
	description = "List every placed point on this map.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "point.edit")
	end,

	OnRun = function(self, client)
		local count = 0

		for id, record in pairs(ix.points.stored) do
			local pointType = ix.points.byID[record.type]

			client:ChatPrint(string.format("  %s - %s%s at %s", tostring(id),
				pointType and pointType.name or record.type,
				record.data.name and (" '" .. record.data.name .. "'") or "",
				tostring(record.position)))

			count = count + 1
		end

		--[[
			Ore nodes are listed alongside, prefixed, because they are the
			other thing somebody places and then wants to delete - and a mined
			out one has no entity to point a tool at. `/pointdelete ore:3`
			removes one; see `ix.points.RemoveByID`.
		]]
		local nodes = 0

		for id, record in pairs(ix.mining.nodes or {}) do
			local ore = ix.mining.Get(record.ore)
			local waiting = (tonumber(record.refillAt) or 0) - os.time()

			client:ChatPrint(string.format("  ore:%s - %s - %s%s at %s",
				tostring(id), ore and ore.name or tostring(record.ore),
				IsValid(record.entity)
					and ix.mining.FormatAmount(record.entity:GetAmount())
					or "mined out",
				waiting > 0 and string.format(", back in %ds", waiting) or "",
				tostring(record.position)))

			nodes = nodes + 1
		end

		if (count == 0 and nodes == 0) then
			return "Nothing placed on this map."
		end

		return string.format("%d point(s), %d ore node(s).", count, nodes)
	end
})

--[[
	Locking a teleport by hand.

	`ix_keys` is the intended way and works on doors and, since `sv_doors.lua`
	wraps it, on props with teleports too. This exists because the keys are an
	item somebody may not be carrying, and because a two-way pair is exactly
	the thing somebody wants to shut from the far end.

	NOT ADMIN-GATED. `ix.doors.SetLocked` asks the same question the keys ask -
	are you allowed through this - so the command cannot do anything the keys
	could not.
]]
ix.command.Add("TpLock", {
	description = "Lock or unlock the teleport you are looking at.",

	OnRun = function(self, client)
		local entity = client:GetEyeTrace().Entity

		if (not IsValid(entity)) then return "Look at a teleport." end

		local link = ix.doors.Link(entity)

		if (not link) then return "That is not a teleport." end

		local state = not ix.doors.Locked(entity)
		local ok, why = ix.doors.BeginLock(client, entity, state)

		if (not ok) then return why end

		return state and "Locking..." or "Unlocking..."
	end
})

--[[
	Buying and selling a teleport.

	Helix already has `/DoorBuy` and `/DoorSell` for its own ownable doors, and
	they are not these: those work on a map door with `ownable` set and store
	the owner in Helix's own door data, while a teleport is a link record that
	can be on a prop. Two names because they are two things, not because one
	was forgotten.
]]
ix.command.Add("BuyDoor", {
	description = "Buy the teleport you are looking at.",

	OnRun = function(self, client)
		local entity = client:GetEyeTrace().Entity

		if (not IsValid(entity)) then return "Look at a teleport." end

		local ok, result = ix.doors.Buy(client, entity)

		if (not ok) then return result end

		return string.format("Bought for %s. Lock it with your keys or "
			.. "/tplock.", ix.points.FormatCaps(result))
	end
})

ix.command.Add("SellDoor", {
	description = "Sell the teleport you own back.",

	OnRun = function(self, client)
		local entity = client:GetEyeTrace().Entity

		if (not IsValid(entity)) then return "Look at a teleport." end

		local ok, result = ix.doors.Sell(client, entity)

		if (not ok) then return result end

		return string.format("Sold. You get %s back.",
			ix.points.FormatCaps(result))
	end
})

--------------------------------------------------------------------------------
-- Orbital drops
--------------------------------------------------------------------------------

--[[
	Call one by hand.

	This is how the system is tested: Phoenix's own `Orbital Minimum Players`
	default is 30, so on anything smaller than a full server nothing ever
	happens on its own. Kept as their number rather than quietly lowered - it
	is a real decision about when the event is worth running.
]]
ix.command.Add("Orbital", {
	description = "Call an orbital drop now, at a random site.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "orbital.force")
	end,

	OnRun = function(self, client)
		local beacon, why = ix.orbital.Start(nil, client)

		if (not beacon) then return why end

		return "A beacon has landed at " .. (beacon.ixSiteName or "a site")
			.. "."
	end
})

ix.command.Add("OrbitalHere", {
	description = "Call an orbital drop at the site you are standing nearest.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "orbital.force")
	end,

	OnRun = function(self, client)
		local best, distance

		for _, site in ipairs(ix.orbital.Sites()) do
			local away = client:GetPos():Distance(site.record.position)

			if (not distance or away < distance) then
				best, distance = site, away
			end
		end

		if (not best) then return "There are no drop sites on this map." end

		local beacon, why = ix.orbital.Start(best, client)

		if (not beacon) then return why end

		return "A beacon has landed at " .. (beacon.ixSiteName or "a site")
			.. "."
	end
})

ix.command.Add("OrbitalCancel", {
	description = "Call off the orbital drop that is happening.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "orbital.force")
	end,

	OnRun = function(self, client)
		if (not IsValid(ix.orbital.active)) then
			return "Nothing is happening."
		end

		ix.orbital.active:Remove()

		ix.log.Add(client, "orbitalCancel")

		return "Called off."
	end
})

ix.command.Add("PointDelete", {
	description = "Delete a placed point by its id, from /points.",
	arguments = {ix.type.string},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "point.edit")
	end,

	OnRun = function(self, client, id)
		local ok, why = ix.points.RemoveByID(client, string.Trim(id))

		return ok and "Deleted." or why
	end
})

--------------------------------------------------------------------------------
-- Player killing
--------------------------------------------------------------------------------

--[[
	Mark somebody for death.

	THE CONFIRMATION IS PHOENIX'S and it is kept. Theirs asks "Do you want to
	toggle PK status on X?" before doing anything, because `/pk` on the wrong
	name costs somebody levels and caps they cannot get back, and the names in
	this game are two words that half the server shares one of.
]]
ix.command.Add("PK", {
	description = "Mark a player for death for a while.",
	arguments = {ix.type.player, bit.bor(ix.type.text, ix.type.optional)},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.pk")
	end,

	OnRun = function(self, client, target, reason)
		if (not ix.admin.Outranks(client, target)) then
			return "They outrank you, or match you."
		end

		local seconds = ix.config.Get("pkDuration", 1800)

		ix.factionmgmt.Confirm(client, string.format(
			"Mark %s for death for %s?", target:Name(),
			ix.bench.FormatTime(seconds)), function(_, accepted)
				--[[
					`ix.factionmgmt.Confirm` answers `(client, accepted)`. The
					client is the person who was asked, which is the same
					`client` this closure already has.
				]]
				if (not accepted or not IsValid(target)) then return end

				local ok, result = ix.pk.Mark(client, target, seconds, reason)

				client:Notify(ok and (target:Name() .. " is marked.")
					or result)
			end)
	end
})

ix.command.Add("PKOff", {
	description = "Take the mark off a player.",
	arguments = {ix.type.player},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.pk")
	end,

	OnRun = function(self, client, target)
		ix.factionmgmt.Confirm(client, string.format(
			"Take the mark off %s?", target:Name()), function(_, accepted)
				if (not accepted or not IsValid(target)) then return end

				local ok, why = ix.pk.Unmark(client, target)

				client:Notify(ok and (target:Name() .. " is no longer marked.")
					or why)
			end)
	end
})

--[[
	Who is marked, and for how long.

	Read-only and behind the same permission, because "who is about to lose
	five levels" is exactly the question somebody asks before deciding whether
	to take the mark off again.
]]
ix.command.Add("PKList", {
	description = "List everybody marked for death.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.pk")
	end,

	OnRun = function(self, client)
		local count = 0

		for _, other in ipairs(player.GetAll()) do
			local character = other:GetCharacter()

			if (not character or not ix.pk.IsActive(character)) then continue end

			local levels, caps = ix.pk.Cost(character)

			client:ChatPrint(string.format("  %s - %s left - would lose %d "
				.. "level(s) and %d caps", other:Name(),
				ix.bench.FormatTime(ix.pk.Remaining(character)), levels, caps))

			count = count + 1
		end

		return count == 0 and "Nobody is marked."
			or string.format("%d marked.", count)
	end
})

--------------------------------------------------------------------------------
-- Farming
--------------------------------------------------------------------------------

--[[
	Take a crop plot back.

	Yours, or anybody who may edit the map furniture. Whatever is growing in it
	is lost - the notice says how much - because a box you can pick up with nine
	ripe crops still in it is a wheelbarrow.
]]
ix.command.Add("FarmRemove", {
	description = "Pick up the crop plot you are looking at.",

	OnRun = function(self, client)
		local plot = ix.farming.LookingAt(client)

		if (not plot) then return "You are not looking at a crop plot." end

		local ok, why = ix.farming.Remove(client, plot)

		return why or (ok and "Picked it up." or "You cannot do that.")
	end
})

--------------------------------------------------------------------------------
-- Mining
--------------------------------------------------------------------------------

--[[
	The ore configurer.

	The window is the client's; this only asks for it, which is the same shape
	every other configurer in this schema uses - the permission is checked here
	and again by the server when the list comes back.
]]
ix.command.Add("MiningConfig", {
	description = "Open the mining configurer.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "mining.edit")
	end,

	OnRun = function(self, client)
		net.Start("ixMiningOpen")
		net.Send(client)
	end
})

--[[
	Every node on this map, with what is left in it.

	`/miningnodes` rather than a report command, because it is the same
	question `/points` answers for the other map furniture.
]]
ix.command.Add("MiningNodes", {
	description = "List every ore node on this map.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "mining.edit")
	end,

	OnRun = function(self, client)
		local count = 0

		for id, record in pairs(ix.mining.nodes) do
			local ore = ix.mining.Get(record.ore)
			local waiting = (tonumber(record.refillAt) or 0) - os.time()

			client:ChatPrint(string.format("  %s - %s - %s of %s%s at %s",
				tostring(id), ore and ore.name or tostring(record.ore),
				ix.mining.FormatAmount(IsValid(record.entity)
					and record.entity:GetAmount() or 0),
				ix.mining.FormatAmount(record.amount),
				waiting > 0 and string.format(" - back in %ds", waiting) or "",
				tostring(record.position)))

			count = count + 1
		end

		return count == 0 and "No ore nodes on this map."
			or string.format("%d node(s).", count)
	end
})

--------------------------------------------------------------------------------
-- The crosshair
--------------------------------------------------------------------------------

--[[
	The crosshair editor, which everybody has.

	NO ACCESS CHECK. Every other configurer in this schema is an admin one and
	this reads like them, but a crosshair is a personal setting saved on the
	player's own machine - see `cl_crosshair.lua` - so there is nothing here to
	protect.

	It goes through the server the same way the rest do rather than being a
	console command, because `/crosshair` is what people will type.
]]
ix.command.Add("Crosshair", {
	description = "Open the crosshair settings.",

	OnRun = function(self, client)
		net.Start("ixCrosshairOpen")
		net.Send(client)
	end
})

--------------------------------------------------------------------------------
-- Inventory grids
--------------------------------------------------------------------------------

--[[
	Put right anything already sitting on top of something else.

	`sv_gridguard.lua` stops new overlaps and cannot undo the ones written
	before it existed - see gotcha 20 for how they got there. This walks every
	loaded inventory and moves the second claimant of a square somewhere free.

	`fo_grid_report` on the client is the other half of this: it says what the
	CLIENT thinks is where, which is how a real overlap is told apart from a
	client drawing a stale view.
]]
ix.command.Add("GridRepair", {
	description = "Move any item sitting on top of another to a free square.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "dev.terminal")
	end,

	OnRun = function(self, client)
		local moved, stuck = ix.gridguard.Repair()

		ix.log.Add(client, "gridRepair", moved, stuck)

		if (moved == 0 and stuck == 0) then
			return "Nothing is overlapping."
		end

		return string.format("Moved %d item(s)%s.", moved,
			stuck > 0 and string.format("; %d had nowhere to go", stuck) or "")
	end
})

--- SERVER ONLY - `ix.log.AddType` is nil on the client. See the note above.
if (SERVER) then
	ix.log.AddType("gridRepair", function(client, moved, stuck)
		return string.format("%s repaired %d overlapping item(s), %d stuck.",
			client:Name(), moved or 0, stuck or 0)
	end)
end

--------------------------------------------------------------------------------
-- Karma
--------------------------------------------------------------------------------

--[[
	What somebody's karma actually is, in numbers.

	The title under their name is deliberately vague - it is a reputation, not
	a readout - so this is the admin view of the same thing, and the one a
	player uses on themselves to see where they stand.
]]
ix.command.Add("Karma", {
	description = "Show a character's karma. Yourself if nobody is named.",
	arguments = {bit.bor(ix.type.player, ix.type.optional)},

	OnRun = function(self, client, target)
		target = target or client

		local character = target:GetCharacter()

		if (not character) then return "@invalidArg", 1 end

		--[[
			ONLY YOUR OWN, unless you are staff. Karma is a number behind a
			reputation, and being able to read everybody's exactly turns a
			thing people gossip about into a leaderboard.
		]]
		if (target ~= client and not ix.admin.Can(client, "dev.terminal")) then
			return "That is their business."
		end

		local good, bad = ix.karma.Of(character)
		local title, level = ix.karma.Describe(good, bad)

		return string.format("%s: %s, karma level %d - %d good, %d bad.",
			character:GetName(), title, level, good, bad)
	end
})

ix.command.Add("CharSetKarma", {
	description = "Set a character's good and bad karma.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.number, ix.type.number},

	OnRun = function(self, client, target, good, bad)
		if (not target:GetCharacter()) then return "@invalidArg", 1 end

		good = math.Clamp(math.floor(good), 0, 1000000)
		bad = math.Clamp(math.floor(bad), 0, 1000000)

		if (not ix.karma.Set(target, good, bad)) then
			return "@invalidArg", 1
		end

		ix.log.Add(client, "karmaSet", target:Name(), good, bad)

		return string.format("%s now has %d good and %d bad karma.",
			target:Name(), good, bad)
	end
})

--------------------------------------------------------------------------------
-- Odds and ends
--------------------------------------------------------------------------------

--[[
	Ammunition, straight into the pool.

	The commonest thing an admin does that had no command: testing a weapon
	means having rounds for it, and the alternative was spawning boxes of ammo
	items and using them one at a time.

	THE TYPES ARE THE WEAPONS' OWN. `ITEM.ammo` on every ammunition item is a
	`SWEP.Primary.Ammo` string, so the list offered here is built from the item
	roster and cannot drift from what a gun will actually draw from - see
	`items/base/sh_ammo.lua`, which explains why a mistyped pool is invisible.
]]
ix.command.Add("Ammo", {
	description = "Ammunition for the gun you are holding. `^` for all of it.",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional),
		bit.bor(ix.type.number, ix.type.optional)
	},

	OnRun = function(self, client, first, amount)
		--[[
			EVERY POOL A WEAPON ON THIS SERVER ACTUALLY DRAWS FROM.

			Built from the ammunition items rather than written out: `ITEM.ammo`
			is a `SWEP.Primary.Ammo` string and the roster is generated FROM the
			weapons, so this list cannot name a pool no gun can reach - see
			`items/base/sh_ammo.lua`, which explains why a mistyped pool is
			invisible.
		]]
		local types = {}

		for _, itemTable in pairs(ix.item.list) do
			if (itemTable.isAmmo and itemTable.ammo) then
				types[string.lower(itemTable.ammo)] = itemTable.ammo
			end
		end

		--[[
			`^` IS EVERYTHING. `/ammo ^` fills every pool, `/ammo ^ 200` fills
			every pool with 200. It is the thing an admin wants before testing
			anything, and typing sixteen commands for it is the reason this
			command existed in the first place.
		]]
		if (first == "^") then
			local given = 0

			for _, name in pairs(types) do
				client:GiveAmmo(math.Clamp(math.floor(amount or 9999), 1,
					9999), name, true)

				given = given + 1
			end

			ix.log.Add(client, "adminAmmo", amount or 9999, "everything")

			return string.format("%d ammo type(s) filled.", given)
		end

		--[[
			NO TYPE MEANS THE GUN IN YOUR HANDS, which is what somebody with a
			rifle out is asking for. A number on its own is that amount for the
			same gun, so `/ammo 30` is a magazine.
		]]
		if (not first or first == "") then
			first = tonumber(first)
		end

		local resolved
		local wanted = tonumber(first)

		if (wanted) then
			--- `/ammo 30` - the first argument was the amount all along.
			amount, first = wanted, nil
		end

		if (first and first ~= "") then
			resolved = types[string.lower(first)]

			if (not resolved) then
				local names = {}

				for _, name in SortedPairs(types) do
					names[#names + 1] = name
				end

				return string.format("No weapon uses '%s'. Types: %s", first,
					table.concat(names, ", "))
			end
		else
			local weapon = client:GetActiveWeapon()

			if (not IsValid(weapon)) then
				return "Hold the gun you want ammunition for, or name a type."
			end

			--[[
				`GetPrimaryAmmoType` is an INDEX; `game.GetAmmoName` turns it
				into the string the pool is keyed by. A weapon with no ammo -
				hands, a melee weapon - answers -1, which has no name.
			]]
			local index = weapon:GetPrimaryAmmoType()

			resolved = index and index >= 0 and game.GetAmmoName(index) or nil

			if (not resolved) then
				return "That weapon does not take ammunition."
			end
		end

		amount = math.Clamp(math.floor(amount or 250), 1, 9999)

		client:GiveAmmo(amount, resolved, true)

		ix.log.Add(client, "adminAmmo", amount, resolved)

		return string.format("%d rounds of %s.", amount, resolved)
	end
})

--[[
	Give somebody their identity, by force.

	Recognition is a thing players hand each other, and there was no way for
	staff to fix it when it went wrong - a name given in a scene nobody can
	repeat, a character remade, a bug. This is the fix, and it is one-way: the
	ADMIN learns who they are looking at.

	It does not tell the other person anything, and it does not make them
	recognise the admin back. Handing somebody else's identity out is not
	something an admin should be able to do to two people at once.
]]
ix.command.Add("ForceID", {
	description = "Learn the identity of whoever you are looking at.",
	adminOnly = true,

	OnRun = function(self, client)
		local target = client:GetEyeTrace().Entity

		if (not IsValid(target) or not target:IsPlayer()) then
			return "You are not looking at anybody."
		end

		local ours = client:GetCharacter()
		local theirs = target:GetCharacter()

		if (not ours or not theirs) then return "@invalidArg", 1 end
		if (ours == theirs) then return "You know who you are." end

		--[[
			`Recognize` is the recognition plugin's own method and returns
			false when it was already known - which is the answer, not a
			failure.
		]]
		if (not ours.Recognize or not ours:Recognize(theirs:GetID())) then
			return string.format("You already know %s.", theirs:GetName())
		end

		ix.log.Add(client, "adminForceID", theirs:GetName())

		return string.format("You now know %s.", theirs:GetName())
	end
})

--[[
	Shut your own faction out of a bench you took, and let them back in.

	A captured bench belongs to the faction that took it, which is right until
	an officer is stood at one with a queue of enlisted troopers emptying its
	output bin. This is that officer's switch, and it answers to WHO TOOK IT
	rather than to rank - who is trusted is not something a rank number knows.

	TEMPORARY BY CONSTRUCTION. It is cleared when the bench changes hands, when
	it is released, and on every restart, because ownership itself is - see
	`ix.bench.Load`. Nobody has to remember to undo it.
]]
ix.command.Add("BenchFactionToggle", {
	description = "Close the workbench you took to your faction, or open it "
		.. "again.",

	OnRun = function(self, client)
		local entity = client:GetEyeTrace().Entity

		if (not IsValid(entity) or entity:GetClass() ~= "ix_workbench") then
			return "You are not looking at a workbench."
		end

		local record = ix.bench.Get(entity:GetBenchID())

		if (not record) then return "That bench has no record." end
		if (not record.owner) then return "Nobody holds it." end

		local character = client:GetCharacter()
		local captured = ix.bench.CapturedBy(record)

		if (not character) then return "@invalidArg", 1 end

		if (captured ~= character:GetID() and not client:IsAdmin()) then
			return "Only whoever took it can do that."
		end

		--[[
			A bench held by one wastelander is already theirs alone, so there
			is nothing to shut out and the switch would be a lie.
		]]
		if (not record.owner.faction) then
			return "That bench is already yours alone."
		end

		if (record.lockedBy) then
			record.lockedBy = nil

			ix.bench.Save()

			return "Your faction may use it again."
		end

		record.lockedBy = character:GetID()

		ix.bench.Save()

		return "Closed to your faction. Only you may use it until it changes "
			.. "hands."
	end
})

if (SERVER) then
	ix.log.AddType("adminAmmo", function(client, amount, ammoType)
		return string.format("%s gave themselves %d %s.", client:Name(),
			amount, ammoType)
	end, FLAG_NORMAL)

	ix.log.AddType("adminForceID", function(client, name)
		return string.format("%s forced the identity of %s.", client:Name(),
			name)
	end, FLAG_WARNING)

	ix.log.AddType("adminSetDesc", function(client, name, from, to)
		return string.format("%s changed %s's description from '%s' to '%s'.",
			client:Name(), name, from, to)
	end, FLAG_WARNING)
end

--[[
	Set somebody's description.

	Descriptions are what a stranger is known BY - see `sh_recognizeinteract.lua`
	- so an admin needs to be able to fix one, and testing whether they show at
	all needs a way to put something there.

	The description is a character var with its own validator, so this writes it
	through `SetDescription` and saves rather than touching the field.
]]
ix.command.Add("CharSetDesc", {
	description = "Set a character's description.",
	adminOnly = true,
	arguments = {ix.type.player, ix.type.text},

	OnRun = function(self, client, target, text)
		local character = target:GetCharacter()

		if (not character) then return "@invalidArg", 1 end

		text = string.Trim(text or "")

		if (text == "") then return "@invalidArg", 2 end

		--[[
			Clamped to the same length the creation screen allows, because a
			description nobody can read the end of is not a description - and
			because it is drawn into a tooltip that has to fit on a screen.
		]]
		text = string.sub(text, 1, 512)

		local previous = character:GetDescription()

		character:SetDescription(text)
		character:Save()

		ix.log.Add(client, "adminSetDesc", target:Name(), previous, text)

		return string.format("%s's description is now: %s", target:Name(),
			text)
	end
})
