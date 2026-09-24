--[[
	The war point placer.

	A war point is the ground one faction defends and the other has to come and
	take. There is one per faction, it is placed once and kept, and the capture
	entity only exists while a war is actually running - see `sh_war.lua`.

	WHY A TOOL AND NOT A COMMAND: because placing one is a job you do while
	walking around a map looking at doorways, and a command that takes a faction
	name means typing the name every time. The tool remembers which faction it
	is set to; left click puts that faction's point where you are looking, right
	click reads back whose point you are standing on, and reload clears one.

	`/warpointset` still exists and does the same thing. This is the fast path.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.warpoint.name"

TOOL.ClientConVar = {
	["faction"] = ""
}

--[[
	CALLED AGAIN, DELIBERATELY - the same reason `lootable.lua` gives. Helix
	builds the TOOL and calls `CreateConVars()` BEFORE including this file, so
	the convar above would never exist and `GetClientInfo` would read an empty
	string for ever.
]]
TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.warpoint.name", "War Point Placer")
	language.Add("tool.warpoint.desc", "Set where each faction defends.")
	language.Add("tool.warpoint.0",
		"Left: place for the chosen faction   Right: whose is this?   "
		.. "Reload: clear it")
end

--- Superadmin, matching the lootable tool: this is level design, not moderation.
local function CanUse(client)
	return IsValid(client) and client:IsSuperAdmin()
end

--[[
	WHAT THE CLIENT KNOWS ABOUT POINTS: which factions have one, and nothing
	else.

	`ix.war.points` is positions, and it is the SERVER's. The panel below reads
	`ix.war.hasPoint` - a set of ids sent to staff along with the war queue -
	because where a war point is is not something a client needs to hold until
	somebody asks to see it.
]]

--- The faction the tool is set to, as its table, or nil.
local function Chosen(self)
	local id = self:GetClientInfo("faction")

	if (id == "") then return nil end

	return ix.faction.teams[id]
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not CanUse(client)) then return false end

	local faction = Chosen(self)

	if (not faction) then
		client:Notify("Pick a faction on the tool first.")

		return false
	end

	ix.war.points[faction.uniqueID] = {
		position = trace.HitPos + trace.HitNormal * 4,

		--[[
			Turned to face the placer rather than to the surface normal, so a
			flag on a wall does not lie on its side.
		]]
		angles = Angle(0, (client:GetPos() - trace.HitPos):Angle().y, 0)
	}

	ix.war.Save()

	--[[
		SHOWN, NOT JUST SAVED. A war point is invisible between wars, so
		without this the tool would give no sign it had done anything - the
		marker is a client-side ghost that lasts a few seconds.
	]]
	ix.war.ShowPoints(client)

	client:Notify(string.format("%s's war point is set.", faction.name))
	ix.log.Add(client, "warPoint", faction.name)

	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not CanUse(client)) then return false end

	--[[
		WHOSE POINT AM I LOOKING AT - answered by distance, because there is
		nothing to click on. Anything within a few metres counts, which is
		about the size of the capture box a war spawns here.
	]]
	local nearest, best

	for uniqueID, record in pairs(ix.war.points) do
		local distance = trace.HitPos:DistToSqr(record.position)

		if (not best or distance < best) then
			best = distance
			nearest = uniqueID
		end
	end

	if (not nearest or best > 400 * 400) then
		client:Notify("No war point near there.")

		ix.war.ShowPoints(client)

		return false
	end

	local faction = ix.faction.teams[nearest]

	client:ConCommand("warpoint_faction " .. nearest)
	client:Notify(string.format("That is %s's. The tool is now set to them.",
		faction and faction.name or nearest))

	ix.war.ShowPoints(client)

	return true
end

function TOOL:Reload(trace)
	if (CLIENT) then return true end

	local client = self:GetOwner()

	if (not CanUse(client)) then return false end

	for uniqueID, record in pairs(ix.war.points) do
		if (trace.HitPos:DistToSqr(record.position) < 400 * 400) then
			ix.war.points[uniqueID] = nil
			ix.war.Save()

			local faction = ix.faction.teams[uniqueID]

			client:Notify(string.format("%s has no war point now.",
				faction and faction.name or uniqueID))

			return true
		end
	end

	client:Notify("No war point near there.")

	return false
end

--[[
	The tool panel.

	Every faction, in the order the scoreboard shows them, with the ones that
	already have a point marked - "who still needs one" is the question this
	tool exists to answer and a plain list does not.
]]
function TOOL.BuildCPanel(panel)
	panel:Help("Set where each faction defends during a war. Superadmin only.")

	--[[
		THE FACTIONS IN A DECLARED WAR FIRST, then everybody else.

		The tool exists to put ground under a war that has been declared, so
		the two factions that need it are the two at the top of the list rather
		than two of forty-five in alphabetical order. They are marked, so it is
		obvious that the order means something.
	]]
	local list = panel:ComboBox("Faction", "warpoint_faction")

	local function Fill(combo)
		combo:Clear()

		local waiting, order = {}, {}

		for _, entry in ipairs(ix.war.queue or {}) do
			for _, index in ipairs({entry.attacker, entry.defender}) do
				local data = ix.faction.indices[index]

				if (data and not waiting[data.uniqueID]) then
					waiting[data.uniqueID] = true
					order[#order + 1] = data
				end
			end
		end

		local function Add(faction, bWaiting)
			combo:AddChoice(string.format("%s%s%s",
				bWaiting and "* " or "", faction.name,
				(ix.war.hasPoint or {})[faction.uniqueID] and "   (set)"
					or (bWaiting and "   (NEEDS ONE)" or "")),
				faction.uniqueID)
		end

		for _, faction in ipairs(order) do
			Add(faction, true)
		end

		for _, faction in ipairs(ix.faction.indices) do
			if (faction.isDefault or waiting[faction.uniqueID]) then continue end

			Add(faction, false)
		end
	end

	--[[
		THE CONVAR IS SET BY HAND, and this is the whole reason the list could
		be opened and read but not chosen from.

		`DComboBox` READS a convar and never writes one. Look at `ChooseOption`
		in `lua/vgui/dcombobox.lua`:

		    -- self:ConVarChanged( self.Data[ index ] )

		commented out, in the shipped game. `CheckConVarChanges` goes the other
		way - it watches the convar and updates the box's text - so a combo box
		wired to a convar shows what the convar says and changes nothing when
		you click it. Every tool panel in this schema that offers a list has to
		set its own convar in `OnSelect`.

		`OnMenuOpened` IS a real method, but it fires AFTER the menu has been
		built from the current choices (`dcombobox.lua:232`), so refilling the
		list there never affects the menu you are looking at - only the next
		one. That is why the refill is on a timer below instead.
	]]
	list.OnSelect = function(_, _, _, data)
		RunConsoleCommand("warpoint_faction", data or "")
	end

	Fill(list)

	--[[
		Refilled on a timer rather than on open, so a war declared while the
		menu is up sorts itself to the top without the tool being reselected.
	]]
	list.Think = function(self)
		if ((self.ixNext or 0) > CurTime()) then return end

		self.ixNext = CurTime() + 1

		--- Not while it is open, or the entry under the cursor moves.
		if (IsValid(self.Menu)) then return end

		local chosen = GetConVarString("warpoint_faction")

		Fill(self)

		--[[
			The text is redrawn from the convar rather than remembered, because
			the label carries "(set)" and "(NEEDS ONE)" and both change.
		]]
		for _, faction in ipairs(ix.faction.indices) do
			if (faction.uniqueID ~= chosen) then continue end

			self:SetValue(faction.name)

			break
		end
	end

	panel:Button("Show every point for 15 seconds", "warpoint_show")

	--[[
		WHO IS WAITING, which is the reason this tool is open.

		A declared war names the two factions whose ground has to be ready
		before `/startwar` will do anything, and they are the two nobody can
		pick out of a list of forty-five. Marked with whether each already has
		a point.
	]]
	local queue = panel:Help("")

	local function Refresh()
		if (not IsValid(queue)) then return end

		local lines = {}

		for _, entry in ipairs(ix.war.queue or {}) do
			local attacker = ix.faction.indices[entry.attacker]
			local defender = ix.faction.indices[entry.defender]

			if (not attacker or not defender) then continue end

			local function Mark(data)
				return string.format("%s%s", data.name,
					(ix.war.hasPoint or {})[data.uniqueID] and ""
						or " (NO POINT)")
			end

			lines[#lines + 1] = string.format("%s  vs  %s   [%s]",
				Mark(attacker), Mark(defender),
				entry.approved and "approved" or "waiting on staff")
		end

		queue:SetText(#lines > 0
			and ("Declared wars:\n" .. table.concat(lines, "\n"))
			or "No wars are declared. Points can still be placed in advance.")
	end

	Refresh()

	--[[
		The queue arrives over the network and can change while the menu is
		open, so this reads it again on a timer rather than once. Half a second
		is slow enough to cost nothing and fast enough that an approval made in
		chat is visible by the time somebody looks back at the tool.
	]]
	queue.Think = function(self)
		if ((self.ixNext or 0) > CurTime()) then return end

		self.ixNext = CurTime() + 0.5

		Refresh()
	end

	panel:Help("Left: place for the chosen faction.  Right: whose point is "
		.. "this, and set the tool to them.  Reload: clear one.")
end
