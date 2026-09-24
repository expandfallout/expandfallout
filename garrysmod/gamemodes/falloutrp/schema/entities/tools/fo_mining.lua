--[[
	The ore node placer.

	    left click    place a node, or apply the panel to the one you hit
	    right click   remove the one you are pointing at
	    reload        move the soft spot, for testing

	Phoenix's `miningrockplacer` does the first two; the third is ours and is
	worth the line, because the soft spot is the part somebody tuning this
	system wants to see move.

	SERVER ONLY, like every tool here - the client's click is predicted and can
	fire more than once for one press, so anything that spawns must happen at
	the end that only sees it once. See `fo_zone.lua` for the longer note,
	including why the convars are created by hand.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.fo_mining.name"

TOOL.ClientConVar = {
	ore = "iron",
	amount = "25",
	respawn = "600"
}

--[[
	Called again after the convar table is declared: Helix runs
	`CreateConVars()` BEFORE including this file, so anything declared here
	would otherwise never be created. See `24-devtools.md`.
]]
TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.fo_mining.name", "Ore Node Placer")
	language.Add("tool.fo_mining.desc",
		"Place ore nodes for people to mine.")
	language.Add("tool.fo_mining.0",
		"Left click to place or update. Right click to remove. Reload moves "
		.. "the soft spot.")
end

function TOOL:Allowed()
	local client = self:GetOwner()

	if (not IsValid(client)) then return false end

	if (not ix.admin.Can(client, "mining.edit")) then
		client:Notify("You cannot place ore nodes.")

		return false
	end

	return true
end

--- What the panel is asking for, validated against the live ore list.
function TOOL:Settings()
	local id = string.lower(string.Trim(self:GetClientInfo("ore") or ""))
	local ore = ix.mining.Get(id)

	if (not ore) then ore = ix.mining.Fallback() end

	return ore and ore.id or "iron",
		math.Clamp(tonumber(self:GetClientInfo("amount")) or 25, 1, 100000),
		math.Clamp(tonumber(self:GetClientInfo("respawn")) or 600, 10, 86400)
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end
	if (trace.HitSky or not trace.Hit) then return false end

	local client = self:GetOwner()
	local ore, amount, respawn = self:Settings()
	local entity = trace.Entity

	--- Pointing at one that exists means "make it this instead".
	if (IsValid(entity) and entity:GetClass() == "ix_orenode") then
		local ok, why = ix.mining.Update(client, entity, ore, amount, respawn)

		client:Notify(ok and "Node updated." or why)

		return ok
	end

	--[[
		Stood off the surface it was placed on, and turned to face it, which is
		Phoenix's arithmetic: the model's origin is at its base, so it is
		pushed along the normal rather than dropped at the hit position.
	]]
	local angles = trace.HitNormal:Angle()

	angles.pitch = angles.pitch + 90

	local position = trace.HitPos - trace.HitNormal + angles:Up() * 5

	local ok, why = ix.mining.Add(client, position, angles, ore, amount,
		respawn)

	if (not ok) then
		client:Notify(why)

		return false
	end

	client:Notify(string.format("Placed a %s node with %s in it.", ore,
		ix.mining.FormatAmount(amount)))

	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local entity = trace.Entity

	if (not IsValid(entity) or entity:GetClass() ~= "ix_orenode") then
		client:Notify("That is not an ore node.")

		return false
	end

	local ok, why = ix.mining.Remove(client, entity)

	client:Notify(ok and "Removed." or why)

	return ok
end

function TOOL:Reload(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local entity = trace.Entity

	if (not IsValid(entity) or entity:GetClass() ~= "ix_orenode") then
		return false
	end

	entity:MoveSoftSpot()

	self:GetOwner():Notify("Soft spot moved.")

	return true
end

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Left click to place a node or apply these settings to "
			.. "one you are pointing at. Right click removes it."
	})

	--[[
		THE ORE LIST IS LIVE. It comes from the server and is edited in
		`/MiningConfig`, so the dropdown is built when the panel is opened
		rather than from anything in this file.
	]]
	local ores = {}

	for _, ore in ipairs(ix.mining.ores or {}) do
		ores[ore.name] = {fo_mining_ore = ore.id}
	end

	panel:AddControl("ComboBox", {
		Label = "Ore",
		MenuButton = 0,
		Options = ores
	})

	panel:NumSlider("Kilogrammes in it", "fo_mining_amount", 1, 500, 0)
	panel:NumSlider("Seconds to come back", "fo_mining_respawn", 10, 7200, 0)

	panel:Help("Nodes are saved with the map. The ores themselves - what they "
		.. "give, how hard they are, what colour and skin they use - are in "
		.. "/MiningConfig.")
end
