--[[
	Blueprints: learning them, and the admin's edits to what they cost.

	See `sh_blueprint.lua` for what is stored where and why.
]]

if (not SERVER) then return end

util.AddNetworkString("ixBlueprintSync")
util.AddNetworkString("ixBlueprintSet")
util.AddNetworkString("ixBlueprintFrame")
util.AddNetworkString("ixBlueprintKnown")

local RECIPE_KEY = "blueprintrecipes"
local FRAME_KEY = "blueprintframes"

--- Guarded like every other save here; see `sv_bench.lua`.
local loaded = false

function ix.blueprint.Save()
	if (not loaded) then return end

	ix.data.Set(RECIPE_KEY, ix.blueprint.recipes, false, true)
	ix.data.Set(FRAME_KEY, ix.blueprint.frames, false, true)
end

function ix.blueprint.Load()
	if (loaded) then return end

	ix.blueprint.recipes = ix.data.Get(RECIPE_KEY, {}, false, true) or {}
	ix.blueprint.frames = ix.data.Get(FRAME_KEY, {}, false, true) or {}
	loaded = true

	--[[
		Sizes are applied once here and again to every client on join. They
		change the ITEM TABLE, so the change has to happen after items load and
		before anything is placed in a grid.
	]]
	ix.blueprint.ApplySizes()

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d blueprint(s), %d edited recipe(s), %d resized "
		.. "frame(s)\n", #ix.blueprint.All(),
		table.Count(ix.blueprint.recipes), table.Count(ix.blueprint.frames)))
end

hook.Add("LoadData", "ixBlueprint", ix.blueprint.Load)
hook.Add("PostLoadData", "ixBlueprint", ix.blueprint.Load)
timer.Simple(10, ix.blueprint.Load)

--------------------------------------------------------------------------------
-- Learning
--------------------------------------------------------------------------------

--[[
	Teach a character a weapon. Returns `true`, or `false, reason`.

	The one place that writes the learned table, so "already knows it" is
	answered once and the blueprint item cannot be consumed for nothing.
]]
function ix.blueprint.Learn(client, weapon)
	local character = client and client:GetCharacter()

	if (not character) then return false, "No character." end

	if (not weapon or not ix.item.list[weapon]) then
		return false, "That blueprint is for something that no longer exists."
	end

	local known = table.Copy(ix.blueprint.Known(client))

	if (known[weapon]) then return false, "You already know this." end

	known[weapon] = true

	character:SetData(ix.blueprint.KEY, known)

	ix.blueprint.SendKnown(client)

	ix.log.Add(client, "blueprintLearn", weapon)

	return true
end

--- Make a character forget one. Admin only, through `/blueprintforget`.
function ix.blueprint.Forget(client, weapon)
	local character = client and client:GetCharacter()

	if (not character) then return false end

	local known = table.Copy(ix.blueprint.Known(client))

	if (not known[weapon]) then return false end

	known[weapon] = nil

	character:SetData(ix.blueprint.KEY, known)
	ix.blueprint.SendKnown(client)

	return true
end

--------------------------------------------------------------------------------
-- Talking to the client
--------------------------------------------------------------------------------

--[[
	A character's own learned list.

	`SetData` networks to the owner already, but the bench window has to be
	able to rebuild the moment something is learned rather than on its next
	poll - and this is the message that says so.
]]
function ix.blueprint.SendKnown(client)
	local known = ix.blueprint.Known(client)
	local names = {}

	for weapon in pairs(known) do names[#names + 1] = weapon end

	table.sort(names)

	net.Start("ixBlueprintKnown")
		net.WriteUInt(#names, 16)

		for _, weapon in ipairs(names) do
			net.WriteString(weapon)
		end
	net.Send(client)
end

--[[
	The edited recipes and frame sizes.

	Only the OVERRIDES are sent; the defaults are in a Lua file both realms
	already have. Sending all 259 recipes to every client on join would be a
	large message carrying information the client can read off disk.
]]
function ix.blueprint.SendAll(client)
	net.Start("ixBlueprintSync")
		net.WriteTable(ix.blueprint.recipes)
		net.WriteTable(ix.blueprint.frames)
	if (IsValid(client)) then net.Send(client) else net.Broadcast() end
end

hook.Add("PlayerLoadedCharacter", "ixBlueprint", function(client)
	timer.Simple(1, function()
		if (not IsValid(client)) then return end

		ix.blueprint.SendAll(client)
		ix.blueprint.SendKnown(client)
	end)
end)

--------------------------------------------------------------------------------
-- The configurer
--------------------------------------------------------------------------------

net.Receive("ixBlueprintSet", function(length, client)
	if (not client:IsAdmin()) then return end

	local weapon = net.ReadString()
	local recipe = net.ReadTable()

	if (not ix.item.list[weapon]) then return end

	--[[
		Rebuilt rather than trusted. The message is reachable by anybody who
		can send a netstring, and what arrives has to end up as the same shape
		the generator writes - `{item, amount}` pairs of things that exist.
	]]
	local input = {}

	for _, entry in ipairs(recipe.input or {}) do
		local uniqueID = entry.item or entry[1]
		local amount = math.Clamp(math.floor(tonumber(entry.amount
			or entry[2] or 1) or 1), 1, 999)

		if (isstring(uniqueID) and ix.item.list[uniqueID]) then
			input[#input + 1] = {uniqueID, amount}
		end
	end

	ix.blueprint.recipes[weapon] = {
		time = math.Clamp(math.floor(tonumber(recipe.time) or 60), 1, 3600),
		xp = math.Clamp(math.floor(tonumber(recipe.xp) or 0), 0, 1000),
		input = input
	}

	ix.blueprint.Save()
	ix.blueprint.SendAll()

	client:Notify(string.format("Saved the %s blueprint.",
		ix.item.list[weapon].name))

	ix.log.Add(client, "blueprintConfig", weapon)
end)

net.Receive("ixBlueprintFrame", function(length, client)
	if (not client:IsAdmin()) then return end

	local weapon = net.ReadString()
	local width = net.ReadUInt(4)
	local height = net.ReadUInt(4)

	if (not ix.blueprint.Frame(weapon)) then return end

	ix.blueprint.frames[weapon] = {
		math.Clamp(width, 1, 8), math.Clamp(height, 1, 8)
	}

	ix.blueprint.ApplySizes()
	ix.blueprint.Save()
	ix.blueprint.SendAll()

	client:Notify(string.format("%s frame is now %dx%d.",
		ix.item.list[weapon].name, ix.blueprint.frames[weapon][1],
		ix.blueprint.frames[weapon][2]))
end)

ix.log.AddType("blueprintLearn", function(client, weapon)
	return string.format("%s learned the %s blueprint.", client:Name(),
		weapon)
end)

ix.log.AddType("blueprintConfig", function(client, weapon)
	return string.format("%s edited the %s blueprint.", client:Name(), weapon)
end)
