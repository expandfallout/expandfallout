--[[
	The lootable tool.

	Placing containers through the configurer means a dialog per crate, and a
	map needs dozens. This is the fast path: pick a table and a model once,
	then left-click your way around the map.

	    left click    place a lootable here
	    right click   copy the settings off the one you are pointing at
	    reload        remove the one you are pointing at

	Right click is the important one. Getting a crate's table and model onto
	the tool by pointing at it means you can match an existing container
	without remembering what it was set to - and it is how you fix a batch you
	placed with the wrong table.

	SUPERADMIN ONLY, checked server-side in every one of the three actions.
	`TOOL.AllowedCVar` and the spawnmenu category only decide who SEES it.
]]

--[[
	Helix's tool base is missing most of what the toolgun calls. It is
	completed once, on the metatable, in `libs/sh_toolfix.lua` - so nothing is
	needed here and every tool benefits, not just this one.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.lootable.name"

TOOL.ClientConVar = {
	["table"] = "",
	["model"] = "models/props_junk/wood_crate001a.mdl",
	["respawn"] = "600",
	--- 0 is no lock; 1 to 5 are the levels in `sh_lockpick.lua`.
	["lock"] = "0",
	--[[
		Empty means "work it out from the model", which is right nearly every
		time - see `libs/sh_lootsound.lua`. This is the override for when it
		is not.
	]]
	["sound"] = ""
}

--[[
	CALLED AGAIN, DELIBERATELY.

	Helix builds the TOOL and calls `CreateConVars()` BEFORE including this
	file - see `HandleEntityInclusion` in `core/libs/sh_plugin.lua`, where
	`create(niceName)` runs and only then is the file included. At that point
	`ClientConVar` is still the empty default, so none of the three convars
	above would exist and every `GetClientInfo` below would read an empty
	string.

	Calling it here, after they are declared, is what actually creates them.
]]
TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.lootable.name", "Lootable Placer")
	language.Add("tool.lootable.desc", "Place loot containers.")
	language.Add("tool.lootable.0",
		"Left: place   Right: copy settings from one   Reload: remove one")
end

--[[
	One gate, used by all three actions.

	Superadmin rather than admin: a lootable is world content that persists to
	the map's data file, and placing them is a level-design job rather than a
	moderation one.
]]
local function CanUse(client)
	return IsValid(client) and client:IsSuperAdmin()
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not CanUse(client)) then return false end

	local name = self:GetClientInfo("table")

	if (name == "" or not ix.loot.Get(name)) then
		client:Notify("Set a loot table on the tool first - see /lootconfig.")
		return false
	end

	local model = self:GetClientInfo("model")

	if (not util.IsValidModel(model)) then
		model = "models/props_junk/wood_crate001a.mdl"
	end

	local entity = ix.loot.Spawn({
		position = trace.HitPos + trace.HitNormal * 8,
		--[[
			Turned to face the placer, so a row of crates put down while
			walking all face the same way rather than each facing its own
			surface normal.
		]]
		angles = Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0),
		model = model,
		lootTable = name,
		respawn = math.max(tonumber(self:GetClientInfo("respawn")) or 600, 0),
		lock = math.Clamp(tonumber(self:GetClientInfo("lock")) or 0, 0, 5),
		sound = self:GetClientInfo("sound")
	})

	if (not IsValid(entity)) then return false end

	ix.log.Add(client, "lootPlace", name)

	return true
end

--[[
	Copy the settings off an existing container onto the tool.
]]
function TOOL:RightClick(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not CanUse(client)) then return false end

	local entity = trace.Entity

	if (not IsValid(entity) or entity:GetClass() ~= "ix_lootable") then
		return false
	end

	client:ConCommand("lootable_table " .. entity:GetLootTable())
	client:ConCommand("lootable_model " .. entity:GetModel())

	if (entity.ixLootData) then
		if (entity.ixLootData.respawn) then
			client:ConCommand("lootable_respawn " .. entity.ixLootData.respawn)
		end

		client:ConCommand("lootable_sound " .. (entity.ixLootData.sound or ""))
		client:ConCommand("lootable_lock " .. (entity.ixLootData.lock or 0))
	end

	client:Notify("Copied: " .. (entity:GetLootTable() ~= ""
		and entity:GetLootTable() or "no table"))

	return true
end

function TOOL:Reload(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not CanUse(client)) then return false end

	local entity = trace.Entity

	if (not IsValid(entity) or entity:GetClass() ~= "ix_lootable") then
		return false
	end

	--[[
		`RemovePlaced`, not `Remove` - this is a deliberate deletion, and it is
		the only kind that should drop the container's saved record. The entity
		on its own no longer erases anything.
	]]
	ix.loot.RemovePlaced(entity)
	client:Notify("Removed a lootable.")

	return true
end

--[[
	The tool panel.

	The table list is built from `ix.loot.tables`, the same mirror the
	configurer uses, so a table authored a moment ago is selectable here
	without a reconnect.
]]
function TOOL.BuildCPanel(panel)
	panel:Help("Place loot containers. Superadmin only.")

	local combo = panel:ComboBox("Loot table", "lootable_table")

	--[[
		THE SAME TWO FIXES THE WAR POINT PLACER NEEDS, and for the same reasons
		- see `warpoint.lua`, which explains both at length.

		    a combo box READS its convar and never writes one, so choosing a
		    table did nothing at all until this set it here

		    `OnMenuOpened` fires after the menu is built, so refilling there
		    never affects the list you just opened
	]]
	local function Fill(self)
		self:Clear()

		for _, name in ipairs(ix.loot.GetNames()) do
			self:AddChoice(name, name)
		end
	end

	combo.OnSelect = function(_, _, value, data)
		RunConsoleCommand("lootable_table", data or value or "")
	end

	--[[
		Refilled on a timer because the list is EMPTY on a fresh client until
		the server syncs the loot tables, and a box filled once at load would
		stay empty for the session.
	]]
	combo.Think = function(self)
		if ((self.ixNext or 0) > CurTime()) then return end

		self.ixNext = CurTime() + 1

		if (IsValid(self.Menu)) then return end

		if (#(ix.loot.GetNames() or {}) ~= (self.ixCount or -1)) then
			self.ixCount = #ix.loot.GetNames()

			Fill(self)
			self:SetValue(GetConVarString("lootable_table"))
		end
	end

	Fill(combo)

	panel:TextEntry("Model", "lootable_model")
	panel:NumSlider("Respawn (seconds)", "lootable_respawn", 0, 86400, 0)

	--[[
		THE LOCK, if it has one.

		Containers placed with a level above None come out of the ground shut
		and stay shut until somebody picks them - and lock themselves again
		when their loot respawns. See `sh_lockpick.lua`.
	]]
	local locks = panel:ComboBox("Lock", "lootable_lock")

	locks:AddChoice("None - opens on E", 0)

	for _, level in ipairs(ix.lockpick.levels) do
		locks:AddChoice(level.name, level.id)
	end

	locks.OnSelect = function(_, _, _, data)
		RunConsoleCommand("lootable_lock", tostring(data or 0))
	end

	--[[
		The sound set. Blank is the normal answer: the model decides, and a
		locker gets a locker. This is here for the container whose model does
		not say what it is.
	]]
	local sounds = panel:ComboBox("Sound set", "lootable_sound")

	sounds:AddChoice("(from the model)", "")

	for _, key in ipairs(ix.loot.GetSoundSetNames()) do
		sounds:AddChoice(ix.loot.soundSets[key].name, key)
	end

	sounds.OnSelect = function(_, _, _, data)
		RunConsoleCommand("lootable_sound", data or "")
	end

	panel:Help("Left: place.  Right: copy settings from a placed one.  " ..
		"Reload: remove one.")

	panel:Button("Open the loot configurer", "fo_loot_config")
end
