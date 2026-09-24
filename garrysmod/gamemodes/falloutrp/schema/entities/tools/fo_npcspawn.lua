--[[
	The NPC spawner tool.

	    left click    put a spawner down where you are pointing, with the
	                  panel's settings - a group, a single NPC that stays
	                  and comes back, or one NPC once, depending on the
	                  panel's mode
	    right click   remove the spawner nearest where you are pointing
	    reload        write the panel's settings onto the nearest spawner

	A spawner is a preset (what spawns), a count, a respawn time, a spawn
	radius, and the two distances that decide whether its NPCs exist at all
	- see `libs/sh_npc.lua`. The presets themselves are made in the editor
	the panel's button opens. Everything happens on the server, like every
	tool here; see `fo_zone.lua` for why the convars are created by hand.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.fo_npcspawn.name"

TOOL.ClientConVar = {
	preset = "",
	mode = "spawner",
	count = "2",
	respawn = "60",
	radius = "128",
	wake = "3000",
	sleep = "4500",
	sleepafter = "45"
}

TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.fo_npcspawn.name", "NPC Spawner")
	language.Add("tool.fo_npcspawn.desc", "Pods that spawn NPCs when players come near.")
	language.Add("tool.fo_npcspawn.0",
		"Left click to place a spawner. Right click to remove one. Reload to "
		.. "apply the panel to the nearest one.")
end

function TOOL:Allowed()
	local client = self:GetOwner()

	if (not IsValid(client)) then return false end

	if (not ix.admin.Can(client, "npc.manage")) then
		client:Notify("You cannot place NPC spawners.")

		return false
	end

	return true
end

function TOOL:Settings()
	return {
		preset = self:GetClientInfo("preset") or "",
		count = tonumber(self:GetClientInfo("count")),
		respawn = tonumber(self:GetClientInfo("respawn")),
		radius = tonumber(self:GetClientInfo("radius")),
		wake = tonumber(self:GetClientInfo("wake")),
		sleep = tonumber(self:GetClientInfo("sleep")),
		sleepAfter = tonumber(self:GetClientInfo("sleepafter"))
	}
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local settings = self:Settings()

	if (not ix.npc.presets[settings.preset]) then
		client:Notify("Pick a preset in the tool panel first.")

		return false
	end

	if (not trace.Hit) then return false end

	local mode = self:GetClientInfo("mode") or "spawner"

	--- One, now, and never again.
	if (mode == "once") then
		local npc = ix.npc.SpawnAt(trace.HitPos + Vector(0, 0, 8),
			ix.npc.presets[settings.preset])

		if (not npc) then
			client:Notify("Nothing spawned: the server is at its NPC cap, or NPCs are off.")

			return false
		end

		ix.npc.GiveUndo(client, npc, ix.npc.presets[settings.preset].name)

		client:Notify(string.format("Spawned a %s.", ix.npc.presets[settings.preset].name))

		return true
	end

	--- One, at this spot, for good: a spawner of one that does not wander.
	if (mode == "single") then
		settings.count = 1
		settings.radius = 16
	end

	local record = ix.npc.Create(trace.HitPos + Vector(0, 0, 4), settings)

	ix.npc.GiveSpawnerUndo(client, record, ix.npc.presets[record.preset].name)

	client:Notify(string.format("Spawner #%d placed: %d x %s.", record.id,
		record.count, ix.npc.presets[record.preset].name))
	ix.log.Add(client, "npcSpawner", "placed", ix.npc.presets[record.preset].name)

	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local record = ix.npc.Nearest(trace.HitPos, 160)

	if (not record) then
		client:Notify("No spawner near there.")

		return false
	end

	local preset = record.preset and ix.npc.presets[record.preset]

	ix.npc.Remove(record.id)

	client:Notify(string.format("Spawner #%d removed.", record.id))
	ix.log.Add(client, "npcSpawner", "removed", preset and preset.name or nil)

	return true
end

function TOOL:Reload(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local record = ix.npc.Nearest(trace.HitPos, 160)

	if (not record) then
		client:Notify("No spawner near there.")

		return false
	end

	local settings = self:Settings()

	if (not ix.npc.presets[settings.preset]) then
		client:Notify("Pick a preset in the tool panel first.")

		return false
	end

	ix.npc.Update(record, settings)

	client:Notify(string.format("Spawner #%d updated: %d x %s.", record.id,
		record.count, ix.npc.presets[record.preset].name))
	ix.log.Add(client, "npcSpawner", "updated", ix.npc.presets[record.preset].name)

	return true
end

--------------------------------------------------------------------------------
-- The panel
--------------------------------------------------------------------------------

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Left click to place a spawner with these settings. Right "
			.. "click removes the nearest one, reload rewrites it with these "
			.. "settings. Spawners are drawn while this tool is out."
	})

	local button = panel:Button("Open the preset editor", "fo_npcpresets")

	button:SetTall(28)

	local presets = {}

	for _, preset in ipairs(ix.npc.PresetList and ix.npc.PresetList() or {}) do
		presets[preset.name] = {fo_npcspawn_preset = preset.id}
	end

	if (table.IsEmpty(presets)) then
		presets["- no presets yet -"] = {fo_npcspawn_preset = ""}
	end

	panel:AddControl("ComboBox", {
		Label = "Preset",
		MenuButton = 0,
		Options = presets
	})

	panel:AddControl("ComboBox", {
		Label = "Mode",
		MenuButton = 0,
		Options = {
			["Group spawner"] = {fo_npcspawn_mode = "spawner"},
			["Single NPC, stays and respawns"] = {fo_npcspawn_mode = "single"},
			["One NPC, once"] = {fo_npcspawn_mode = "once"}
		}
	})

	panel:NumSlider("How many", "fo_npcspawn_count", 1, 12, 0)
	panel:NumSlider("Respawn after (s)", "fo_npcspawn_respawn", 5, 3600, 0)
	panel:NumSlider("Spawn radius", "fo_npcspawn_radius", 16, 1024, 0)

	panel:Help("Where they exist")
	panel:NumSlider("Wake distance", "fo_npcspawn_wake", 300, 15000, 0)
	panel:NumSlider("Sleep distance", "fo_npcspawn_sleep", 300, 20000, 0)
	panel:NumSlider("Sleep after (s)", "fo_npcspawn_sleepafter", 5, 900, 0)

	panel:Help("A player within the wake distance and the NPCs exist; nobody "
		.. "within the sleep distance for the sleep delay and they are removed. "
		.. "The sleep distance should be larger than the wake distance.")
end

--[[
	The preset list changes under the panel; rebuild it when it does.

	`TOOL` IS A LOADING-TIME GLOBAL: Helix sets it while this file is
	included and takes it away after, so a hook that runs later has to hold
	its own reference to the table.
]]
if (CLIENT) then
	local tool = TOOL

	hook.Add("NPCPresetsChanged", "ixNPCSpawnPanel", function()
		local panel = controlpanel.Get("fo_npcspawn")

		if (not IsValid(panel)) then return end

		panel:ClearControls()
		tool.BuildCPanel(panel)
	end)
end
