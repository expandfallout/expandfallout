--[[
	The teleport door tool.

	    left click    on a door, then anywhere - the door now sends you there
	    right click   on a door - it stops being a teleport
	    reload        on a door - set who may use it, from the panel

	WHO MAY USE IT IS WHO MAY LOCK IT. The faction list set here is the same
	list `CanPlayerAccessDoor` answers with, so the factions allowed through a
	teleport are exactly the ones who can turn its lock with `ix_keys`. That is
	"lock the tp with keys like a door" with no second lock and no second list
	that could disagree with the first.

	A DESTINATION IS A POSITION, NOT ANOTHER DOOR. Linking two doors sounds
	tidier and is worse: it makes every teleport two-way whether or not anybody
	wanted that, it breaks when one of the pair is deleted, and it cannot send
	somebody to the middle of a room. Two clicks, a door and a spot.

	A PROP WORKS AS WELL AS A DOOR, with one condition attached.

	A door the map made has a `MapCreationID` and is there every restart. A prop
	you spawned has neither, so its teleport is remembered by the prop's MODEL
	and POSITION - which means it survives exactly as long as the prop does.
	Make the prop permanent with the permaprop tool and the teleport is
	permanent with it; leave it and both are gone at the next restart, like
	anything else dropped on the floor. The tool says so when you make one.
]]

TOOL.Category = "Fallout RP"
TOOL.Name = "#tool.fo_teleport.name"

TOOL.ClientConVar = {
	name = "",
	factions = "",

	--[[
		The colour the name is written in, as three convars because that is
		what a `Color` control on a tool panel writes to. Default white, which
		reads on every background this map has.
	]]
	colourr = "255",
	colourg = "255",
	colourb = "255",

	--[[
		One way or two.

		A two-way pair is two ordinary links that name each other, so this
		changes what the SECOND click means and nothing else: a position for a
		one-way teleport, and the far door or prop for a two-way one.
	]]
	twoway = "0",

	--[[
		What it costs, or 0 for one that is not for sale.

		A priced teleport is bought with `/buydoor` and belongs to whoever
		bought it until they `/selldoor` it - or until somebody blows the lock
		off, when the breaching charge exists.
	]]
	price = "0"
}

--[[
	Called again after the convar table is declared: Helix runs
	`CreateConVars()` BEFORE including this file, so anything declared here
	would otherwise never be created. See `24-devtools.md`.
]]
TOOL:CreateConVars()

if (CLIENT) then
	language.Add("tool.fo_teleport.name", "Teleport Door")
	language.Add("tool.fo_teleport.desc", "Doors that put you somewhere else.")
	language.Add("tool.fo_teleport.0",
		"Left click a door, then click where it should send you. Right click "
		.. "a door to undo it. Reload to set its factions.")
end

--[[
	The three colour convars as the plain triple a link stores.

	Read as numbers and clamped here rather than trusted, because a convar is a
	string somebody can set to anything from the console.
]]
function TOOL:Colour()
	local function channel(name)
		return math.Clamp(math.floor(tonumber(self:GetClientInfo(name)) or 255),
			0, 255)
	end

	return {channel("colourr"), channel("colourg"), channel("colourb")}
end

function TOOL:Allowed()
	local client = self:GetOwner()

	if (not IsValid(client)) then return false end

	if (not ix.admin.Can(client, "door.edit")) then
		client:Notify("You cannot edit doors.")

		return false
	end

	return true
end

--[[
	The faction list from the panel, as uniqueIDs.

	Written as a comma-separated list of unique IDs rather than picked from a
	menu, because a tool panel is a set of convars and a multi-select is not
	one of them. `/doorfactions` is the friendlier way in and takes names.

	Anything that is not a faction is dropped and SAID SO - silently ignoring a
	typo would leave somebody certain they had let the NCR in.
]]
function TOOL:FactionList()
	local text = self:GetClientInfo("factions") or ""
	local out, bad = {}, {}

	for _, piece in ipairs(string.Explode(",", text)) do
		piece = string.lower(string.Trim(piece))

		if (piece == "") then continue end

		if (ix.faction.teams[piece]) then
			out[#out + 1] = piece
		else
			bad[#bad + 1] = piece
		end
	end

	return out, bad
end

function TOOL:LeftClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()

	--[[
		A door or a prop. Anything with a model can carry one.

		The earlier version refused everything but a map door, on the grounds
		that a prop has no `MapCreationID` to key the link by. That is true and
		it is not a reason to refuse - a prop link is keyed by the prop's model
		and position instead, and lives as long as the prop does. See the
		header.
	]]
	if (not IsValid(self.linkDoor)) then
		local entity = trace.Entity

		if (not IsValid(entity)) then
			client:Notify("Click a door or a prop first.")

			return false
		end

		if (entity:IsPlayer() or entity:IsWeapon() or entity:IsNPC()) then
			client:Notify("Not that.")

			return false
		end

		if (not entity:IsDoor() and (entity:GetModel() or "") == "") then
			client:Notify("That has no model to remember it by.")

			return false
		end

		self.linkDoor = entity

		--[[
			Where on it was clicked, pushed out along the surface normal.

			A two-way pair needs an exit for each side, and the obvious one is
			just outside the face you clicked - a step back from the door
			rather than inside the frame. Kept even in one-way mode because the
			mode can be changed between the two clicks.
		]]
		self.linkHit = trace.HitPos + trace.HitNormal * 32 + Vector(0, 0, 4)
		self.linkAngles = Angle(0, trace.HitNormal:Angle().y, 0)

		ix.doors.SendPending(client, entity)

		client:Notify(self:GetClientInfo("twoway") == "1"
			and "Now click the door or prop at the other end."
			or "Now click where it should send you.")

		return true
	end

	if (not IsValid(self.linkDoor)) then
		self.linkDoor = nil

		return false
	end

	local list, bad = self:FactionList()
	local name = string.Trim(self:GetClientInfo("name") or "")

	--[[
		TWO-WAY: the second click is the far END, not a destination.

		Each side is given the other's doorstep as its exit, and then the two
		records are told about each other so the locks move together. Anything
		that already worked on a one-way teleport works on either half of this
		without knowing pairs exist.
	]]
	if (self:GetClientInfo("twoway") == "1") then
		local far = trace.Entity

		if (not IsValid(far) or far == self.linkDoor) then
			client:Notify("Click the door or prop at the other end.")

			return false
		end

		if (far:IsPlayer() or far:IsWeapon() or far:IsNPC()) then
			client:Notify("Not that.")

			return false
		end

		local farHit = trace.HitPos + trace.HitNormal * 32 + Vector(0, 0, 4)
		local farAngles = Angle(0, trace.HitNormal:Angle().y, 0)

		local price = tonumber(self:GetClientInfo("price")) or 0

		local colour = self:Colour()

		local ok, why = ix.doors.SetLink(client, self.linkDoor, farHit,
			farAngles, name, list, price, colour)

		if (not ok) then
			client:Notify(why)

			return false
		end

		ok, why = ix.doors.SetLink(client, far, self.linkHit, self.linkAngles,
			name, list, price, colour)

		if (not ok) then
			client:Notify(why)

			return false
		end

		ix.doors.SetPair(self.linkDoor, far)

		self.linkDoor = nil

		ix.doors.SendPending(client, nil)

		client:Notify("Linked both ways. Locking one locks the other.")

		return true
	end

	--[[
		Dropped two units off the floor and facing the way the placer was
		looking - so somebody arrives standing up, out of the ground, pointing
		into the room rather than at the wall they came through.
	]]
	local position = trace.HitPos + Vector(0, 0, 2)
	local angles = Angle(0, client:EyeAngles().y, 0)

	--[[
		The name and the faction list go in with the link, not after it.

		A prop link keeps its factions inside its own record, so setting them
		afterwards would mean writing the record twice - and the version that
		did that wrote the second one before the first had been given an id.
	]]
	local ok, why = ix.doors.SetLink(client, self.linkDoor, position, angles,
		name, list, tonumber(self:GetClientInfo("price")) or 0, self:Colour())

	if (not ok) then
		client:Notify(why)

		return false
	end

	if (#bad > 0) then
		client:Notify("Not a faction, ignored: " .. table.concat(bad, ", "))
	end

	self.linkDoor = nil

	ix.doors.SendPending(client, nil)

	client:Notify(#list > 0
		and ("Linked, for " .. table.concat(list, ", ") .. ".")
		or "Linked. Anybody may use it.")

	return true
end

function TOOL:RightClick(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()

	--- Right click also cancels a link in progress; that is the commoner need.
	if (IsValid(self.linkDoor)) then
		self.linkDoor = nil

		ix.doors.SendPending(client, nil)

		client:Notify("Cancelled.")

		return true
	end

	local ok, why = ix.doors.ClearLink(client, trace.Entity)

	if (not ok) then
		client:Notify(why)

		return false
	end

	client:Notify("It is an ordinary door again.")

	return true
end

--[[
	Reload sets the NAME and the faction list on whatever is under the
	crosshair, teleport or not.

	Both, because they are the two things the panel holds and somebody
	adjusting one is usually looking at the other - having to re-link a
	teleport to rename it would mean clicking the destination again to change
	one word.

	The name is only written where there is somewhere to write it: an ordinary
	door has no name of ours, so on one of those this sets the factions and
	says so.
]]
function TOOL:Reload(trace)
	if (CLIENT) then return true end
	if (not self:Allowed()) then return false end

	local client = self:GetOwner()
	local entity = trace.Entity

	if (not IsValid(entity)) then
		client:Notify("Point at a door or a teleport.")

		return false
	end

	local list, bad = self:FactionList()
	local name = string.Trim(self:GetClientInfo("name") or "")

	if (#bad > 0) then
		client:Notify("Not a faction, ignored: " .. table.concat(bad, ", "))
	end

	local link = ix.doors.Link(entity)

	--[[
		A BLANK NAME KEEPS THE OLD ONE rather than skipping the whole write.

		This used to be `if (link and name ~= "")`, so the only way to change a
		teleport's colour, price or faction list was to retype its name at the
		same time - and getting that wrong renamed a door somebody had bought.
		The name is now the thing that is optional, which is what "leave it
		blank to leave it alone" means everywhere else in these tools.
	]]
	if (link) then
		local ok, why = ix.doors.SetLink(client, entity, link.position,
			link.angles, name ~= "" and name or link.name, list,
			tonumber(self:GetClientInfo("price")) or 0, self:Colour())

		if (not ok) then
			client:Notify(why)

			return false
		end

		client:Notify(string.format("Updated '%s'%s.",
			name ~= "" and name or (link.name ~= "" and link.name or "teleport"),
			#list > 0 and (", for " .. table.concat(list, ", ")) or ""))

		return true
	end

	local ok, why = ix.doors.SetFactions(client, entity, list)

	if (not ok) then
		client:Notify(why)

		return false
	end

	client:Notify(#list > 0
		and ("Set for " .. table.concat(list, ", ") .. ".")
		or "Faction list cleared.")

	return true
end

function TOOL:Holster()
	if (CLIENT) then return end
	if (not IsValid(self.linkDoor)) then return end

	self.linkDoor = nil

	ix.doors.SendPending(self:GetOwner(), nil)
end

function TOOL.BuildCPanel(panel)
	panel:AddControl("Header", {
		Description = "Click a door or a prop, then click the destination. "
			.. "Reload on one to rename it and set who may use it."
	})

	panel:CheckBox("Two way", "fo_teleport_twoway")
	panel:Help("One way: click a door, then click where it sends you. Two "
		.. "way: click a door, then click the door at the other end - they "
		.. "send you to each other and lock together.")

	panel:TextEntry("Name shown on the door", "fo_teleport_name")

	--[[
		The colour that name is written in.

		`AddControl("Color", ...)` is the stock tool colour picker; it writes
		the three convars this tool declares. Alpha is off because the sign is
		drawn with a shadow behind it and a half transparent name over a bright
		wall is unreadable - which is the one thing a name has to be.
	]]
	panel:AddControl("Color", {
		Label = "Colour of that name",
		Red = "fo_teleport_colourr",
		Green = "fo_teleport_colourg",
		Blue = "fo_teleport_colourb",
		ShowAlpha = 0,
		ShowHSV = 1,
		ShowRGB = 1,
		Multiplier = 255
	})

	panel:Help("The colour is set when you link a teleport, and Reload "
		.. "applies it to one that already exists along with the name.")
	panel:TextEntry("Factions (comma separated)", "fo_teleport_factions")
	panel:NumSlider("Price in caps (0 = not for sale)", "fo_teleport_price",
		0, 100000, 0)
	panel:Help("A priced teleport belongs to whoever buys it with /buydoor "
		.. "and is theirs to lock. /selldoor sells it back.")

	--[[
		The list of unique IDs, printed. Nobody knows them by heart and the
		alternative is guessing at the faction's display name, which is not the
		same string.
	]]
	local ids = {}

	for uniqueID in pairs(ix.faction.teams) do
		ids[#ids + 1] = uniqueID
	end

	table.sort(ids)

	panel:Help("Leave the factions blank to let anybody through.")
	panel:Help("A teleport on a PROP lasts as long as the prop does - make "
		.. "the prop permanent with the permaprop tool or both are gone at "
		.. "the next restart.")
	panel:Help("Factions: " .. table.concat(ids, ", "))
end
