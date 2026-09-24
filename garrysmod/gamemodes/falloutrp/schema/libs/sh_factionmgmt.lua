--[[
	Running a faction from inside it.

	Phoenix's `factionmanagement` plugin, which is the reason their classes are
	worth having: an admin is not in the room when somebody gets promoted, so
	the people above you in your own faction do it. Hold C, right click a
	player, and what you may do to them is what your class says you may.

	    INVITE      NCO+ (rank 2), on anyone not already in your faction
	    KICK        Officer+ (rank 3), on a member you outrank
	    SET CLASS   anyone, on a member you outrank, to a class below your own
	    RENAME      anyone, on a member you outrank

	OUTRANK MEANS STRICTLY ABOVE. Two officers cannot demote each other, and
	nobody can act on themselves - `Rank(a) > Rank(b)` is false for equals, so
	that falls out rather than being special-cased.

	THIS AND `/charsetclass` ARE THE ONLY WAYS TO CHANGE CLASS. Helix let
	anyone in a faction take any of its classes, through the Classes tab and
	through the plain `/becomeclass` command; `cl_special.lua` removes the tab
	and `sh_classrank.lua` removes the command, and this replaces both.

	A FACTION LEAD CANNOT MINT ANOTHER LEAD. The menu offers only classes
	STRICTLY below your own rank and ranks stop at 4, so the highest anybody
	can hand out is officer. The top of every ladder comes from an admin, and
	that falls out of the rank comparison rather than needing a rule.

	SHARED. `properties.Add` needs `Filter` on the client to decide whether the
	option is drawn and `Receive` on the server to act, and they are one
	registration - so this file runs on both, and every rule is checked twice:
	once to show the option, once to honour it. The client half is a
	convenience and the server half is the authority, which is why the checks
	are written once, in functions, and called from both.
]]

ix.factionmgmt = ix.factionmgmt or {}

--- The rank of a player's current class, or 0 if they have none.
function ix.factionmgmt.GetRank(client)
	if (not IsValid(client) or not client:IsPlayer()) then return 0 end

	local character = client:GetCharacter()

	if (not character) then return 0 end

	local info = ix.class.list[character:GetClass()]

	return info and (info.rank or 1) or 0
end

function ix.factionmgmt.SameFaction(client, target)
	if (not IsValid(client) or not IsValid(target)) then return false end

	local a, b = client:GetCharacter(), target:GetCharacter()

	if (not a or not b) then return false end

	return a:GetFaction() == b:GetFaction()
end

--[[
	Strictly above, and never yourself.

	`client == target` is checked explicitly rather than left to the
	comparison. Your rank is never above your own so it would be false anyway,
	but a future change to "or equal" would silently let people rename
	themselves through a menu meant for managing other people.
]]
function ix.factionmgmt.Outranks(client, target)
	if (client == target) then return false end

	return ix.factionmgmt.GetRank(client) > ix.factionmgmt.GetRank(target)
end

--[[
	The default faction to drop somebody into when they are kicked.

	A race can name its own - a super mutant kicked out of Unity is not a
	Wastelander - and Wastelanders is the fallback because it is the one
	faction with no whitelist.
]]
function ix.factionmgmt.GetHomeFaction(character)
	local race = ix.races and ix.races.GetCharacterRace(character)
	local home = race and race.defaultFaction

	if (home and home ~= "" and ix.faction.teams[home]) then
		return ix.faction.teams[home]
	end

	return ix.faction.teams.wastelanders
end

--[[
	The classes somebody may put a member into: their own faction's, below
	their own rank, that the target's race fits.

	RANK IS THE WHOLE RULE. You may hand out anything below where you stand,
	which makes a lead able to appoint officers, an officer able to appoint
	NCOs, and nobody able to appoint their own equal.

	The race lock is the one thing rank does not override, and it is not a
	permission: a class locked to securitrons is not something a human gets
	promoted into. That half is public character data, so the client can
	answer it too and the option is simply not drawn.
]]
function ix.factionmgmt.GetAssignableClasses(client, target)
	local out = {}
	local character = client:GetCharacter()
	local targetCharacter = target and target:GetCharacter()

	if (not character or not targetCharacter) then return out end

	local rank = ix.factionmgmt.GetRank(client)

	for _, info in ipairs(ix.class.list) do
		if (info.faction ~= character:GetFaction()) then continue end
		if ((info.rank or 1) >= rank) then continue end
		if (info.index == targetCharacter:GetClass()) then continue end

		--[[
			The race check is asked of the TARGET, and it is not negotiable by
			rank: a class locked to securitrons is not something a human can be
			promoted into. This half is public data, so the client can answer
			it too.
		]]
		if (info.races and not table.HasValue(info.races,
		targetCharacter:GetRace())) then
			continue
		end

		out[#out + 1] = info
	end

	return out
end

--------------------------------------------------------------------------------
-- The four permissions, each in one place so both realms ask the same question
--------------------------------------------------------------------------------

function ix.factionmgmt.CanInvite(client, target)
	if (not IsValid(target) or not target:IsPlayer()) then return false end
	if (client == target) then return false end
	if (not target:GetCharacter() or not client:GetCharacter()) then return false end
	if (ix.factionmgmt.SameFaction(client, target)) then return false end

	return ix.factionmgmt.GetRank(client) >= 2
end

function ix.factionmgmt.CanKick(client, target)
	if (not IsValid(target) or not target:IsPlayer()) then return false end
	if (not ix.factionmgmt.SameFaction(client, target)) then return false end
	if (not ix.factionmgmt.Outranks(client, target)) then return false end

	return ix.factionmgmt.GetRank(client) >= 3
end

function ix.factionmgmt.CanManage(client, target)
	if (not IsValid(target) or not target:IsPlayer()) then return false end

	return ix.factionmgmt.SameFaction(client, target)
		and ix.factionmgmt.Outranks(client, target)
end

--------------------------------------------------------------------------------
-- The confirmation prompt
--------------------------------------------------------------------------------

--[[
	A yes/no the SERVER asks and the client answers.

	Helix ships `client:RequestString` and nothing for a plain confirmation, so
	this is the missing half. Invites go to the person being invited and kicks
	go back to the person doing the kicking, which is why it takes a target
	rather than always asking whoever pressed the button.

	The pending answer is keyed by a rolling id and stored against the player
	being asked, so a reply cannot be forged for somebody else's prompt or
	replayed for one already answered.
]]
if (SERVER) then
	util.AddNetworkString("ixFactionConfirm")

	local nextID = 0

	function ix.factionmgmt.Confirm(client, text, callback)
		if (not IsValid(client)) then return end

		nextID = nextID + 1

		client.ixConfirms = client.ixConfirms or {}
		client.ixConfirms[nextID] = callback

		local id = nextID

		net.Start("ixFactionConfirm")
			net.WriteUInt(id, 16)
			net.WriteString(text)
		net.Send(client)

		--[[
			Dropped after a minute whether or not it was answered. A callback
			holding a player and a character is a reference that would
			otherwise live as long as the session.
		]]
		timer.Simple(60, function()
			if (IsValid(client) and client.ixConfirms) then
				client.ixConfirms[id] = nil
			end
		end)
	end

	net.Receive("ixFactionConfirm", function(length, client)
		local id = net.ReadUInt(16)
		local accepted = net.ReadBool()
		local callback = client.ixConfirms and client.ixConfirms[id]

		if (not callback) then return end

		--[[
			Cleared BEFORE the callback runs, not after. The callback moves
			characters between factions and can error; clearing afterwards
			would leave a prompt that can be answered again.
		]]
		client.ixConfirms[id] = nil

		callback(client, accepted)
	end)
else
	net.Receive("ixFactionConfirm", function()
		local id = net.ReadUInt(16)
		local text = net.ReadString()

		Derma_Query(text, "Faction", "Accept", function()
			net.Start("ixFactionConfirm")
				net.WriteUInt(id, 16)
				net.WriteBool(true)
			net.SendToServer()
		end, "Decline", function()
			net.Start("ixFactionConfirm")
				net.WriteUInt(id, 16)
				net.WriteBool(false)
			net.SendToServer()
		end)
	end)
end

--------------------------------------------------------------------------------
-- Moving somebody, which invite and kick both do
--------------------------------------------------------------------------------

if (SERVER) then
	--[[
		The transfer itself.

		`SetClass(0)` and then a respawn, because a class belongs to one
		faction - `CLASS.faction` names it - so carrying one across is a state
		the class system says cannot exist. `sh_classrank.lua` reconciles on
		the way back in and picks the new faction's default, or the class their
		race fits if the faction is one of the creature ones.

		SAVED EXPLICITLY, for the same reason `/charsetrace` is: `SetFaction`
		writes `self.vars` and networks it without touching the database, so
		without this the move holds until the next restart and then quietly
		does not.

		THE WHITELIST IS NOT GRANTED. Being invited into a faction is not
		permission to create more characters in it - that stays
		`/plywhitelist`, the same split `/charsetfaction` keeps.
	]]
	function ix.factionmgmt.Transfer(target, faction)
		local character = target:GetCharacter()

		if (not character or not faction) then return false end

		character:SetFaction(faction.index)

		if (character.SetClass) then
			character:SetClass(0)
		end

		character:Save()

		if (target:Alive()) then
			target:Spawn()
		end

		return true
	end
end

--------------------------------------------------------------------------------
-- The context menu entries
--------------------------------------------------------------------------------
--
-- `Order` puts them together at the bottom of the menu, below Sandbox's own.
-- `Filter` runs on the client and decides whether the row is drawn; `Receive`
-- runs on the server and is the one that counts.

properties.Add("ixFactionInvite", {
	MenuLabel = "Invite into faction",
	MenuIcon = "icon16/group_add.png",
	Order = 8001,
	PrependSpacer = true,

	Filter = function(self, target)
		return ix.factionmgmt.CanInvite(LocalPlayer(), target)
	end,

	Action = function(self, target)
		self:MsgStart()
			net.WriteEntity(target)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local target = net.ReadEntity()

		if (not ix.factionmgmt.CanInvite(client, target)) then return end

		local faction = ix.faction.indices[client:GetCharacter():GetFaction()]

		if (not faction) then return end

		--[[
			THE INVITED PERSON IS ASKED, not told. A faction change costs them
			their class and respawns them, which is not something somebody
			else should be able to do to a character without consent.
		]]
		ix.factionmgmt.Confirm(target, string.format(
			"%s has invited you to join %s.\nAccept?",
			client:GetCharacter():GetName(), faction.name),
		function(_, accepted)
			if (not accepted) then
				if (IsValid(client)) then
					client:Notify("They declined.")
				end

				return
			end

			--[[
				Re-checked on the way back. The prompt is open for up to a
				minute, and in that time either of them can change faction,
				be demoted, or disconnect.
			]]
			if (not IsValid(client) or not IsValid(target)
			or not ix.factionmgmt.CanInvite(client, target)) then
				if (IsValid(target)) then
					target:Notify("That invitation is no longer valid.")
				end

				return
			end

			ix.factionmgmt.Transfer(target, faction)

			target:Notify("You are now part of " .. faction.name .. ".")
			client:Notify(target:GetCharacter():GetName()
				.. " joined " .. faction.name .. ".")
		end)

		client:Notify("Invitation sent.")
	end
})

properties.Add("ixFactionKick", {
	MenuLabel = "Kick from faction",
	MenuIcon = "icon16/group_delete.png",
	Order = 8002,

	Filter = function(self, target)
		return ix.factionmgmt.CanKick(LocalPlayer(), target)
	end,

	Action = function(self, target)
		self:MsgStart()
			net.WriteEntity(target)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local target = net.ReadEntity()

		if (not ix.factionmgmt.CanKick(client, target)) then return end

		local faction = ix.faction.indices[client:GetCharacter():GetFaction()]

		if (not faction) then return end

		--[[
			The KICKER is asked, not the target. There is nothing to consent to
			on the other end, and a misclick in a context menu should not cost
			somebody their faction.
		]]
		ix.factionmgmt.Confirm(client, string.format(
			"Kick %s out of %s?", target:GetCharacter():GetName(), faction.name),
		function(_, accepted)
			if (not accepted) then return end

			if (not IsValid(client) or not IsValid(target)
			or not ix.factionmgmt.CanKick(client, target)) then
				return
			end

			local home = ix.factionmgmt.GetHomeFaction(target:GetCharacter())

			if (not home) then return end

			ix.factionmgmt.Transfer(target, home)

			target:Notify("You have been removed from " .. faction.name .. ".")
			client:Notify("Removed from " .. faction.name .. ".")
		end)
	end
})

properties.Add("ixFactionSetClass", {
	MenuLabel = "Set class",
	MenuIcon = "icon16/user_edit.png",
	Order = 8003,

	Filter = function(self, target)
		if (not ix.factionmgmt.CanManage(LocalPlayer(), target)) then
			return false
		end

		--[[
			Hidden rather than shown-and-empty when there is nothing to give.
			An NCO managing an enlisted member has exactly one class below
			their own rank, and if the member already holds it the menu would
			otherwise open on an empty list.
		]]
		return #ix.factionmgmt.GetAssignableClasses(LocalPlayer(), target) > 0
	end,

	Action = function(self, target)
		local classes = ix.factionmgmt.GetAssignableClasses(LocalPlayer(), target)

		if (#classes == 0) then return end

		local frame = vgui.Create("ixFOFrame")

		frame:SetSize(math.Round(360 * ix.fallout.GetFontScale()),
			math.Round(150 * ix.fallout.GetFontScale()))
		frame:Center()
		frame:MakePopup()
		frame:SetTitle("SET CLASS")

		local label = frame:Add("ixFOLabel")

		label:Dock(TOP)
		label:SetTall(math.Round(22 * ix.fallout.GetFontScale()))
		label:SetText(target:GetName())

		local combo = frame:Add("DComboBox")

		combo:Dock(TOP)
		combo:SetTall(math.Round(24 * ix.fallout.GetFontScale()))
		combo:SetSortItems(false)
		combo:SetValue(classes[1].name)

		for _, info in ipairs(classes) do
			combo:AddChoice(info.name, info.uniqueID)
		end

		local confirm = frame:Add("ixFOButton")

		confirm:Dock(BOTTOM)
		confirm:SetText("CONFIRM")
		confirm:SetContentAlignment(5)

		confirm.DoClick = function()
			local _, uniqueID = combo:GetSelected()

			--[[
				Nothing picked means the first one, because the combo box shows
				it as the value before it has been opened - so confirming what
				is on screen has to do what it says.
			]]
			uniqueID = uniqueID or classes[1].uniqueID

			self:MsgStart()
				net.WriteEntity(target)
				net.WriteString(uniqueID)
			self:MsgEnd()

			frame:Remove()
		end
	end,

	Receive = function(self, length, client)
		local target = net.ReadEntity()
		local uniqueID = net.ReadString()

		if (not ix.factionmgmt.CanManage(client, target)) then return end

		--[[
			The list is rebuilt on the server rather than trusting the id.
			Everything that decides what is in it - rank, faction, race, grants
			- lives here, and a client that sent an id of its own choosing has
			to fail this lookup.
		]]
		local chosen

		for _, info in ipairs(ix.factionmgmt.GetAssignableClasses(client, target)) do
			if (info.uniqueID == uniqueID) then
				chosen = info
				break
			end
		end

		if (not chosen) then
			client:Notify("You cannot set them to that.")
			return
		end

		local character = target:GetCharacter()

		--[[
			SAVED EXPLICITLY. `SetClass` writes `self.vars` and networks it
			without touching the database, so a promotion made here would hold
			until the next restart and then quietly not have happened.
		]]
		character:SetClass(chosen.index)
		character:Save()

		target:Notify("You are now " .. chosen.name .. ".")
		client:Notify(character:GetName() .. " is now " .. chosen.name .. ".")
	end
})

properties.Add("ixFactionRename", {
	MenuLabel = "Rename",
	MenuIcon = "icon16/textfield_rename.png",
	Order = 8004,

	Filter = function(self, target)
		return ix.factionmgmt.CanManage(LocalPlayer(), target)
	end,

	Action = function(self, target)
		self:MsgStart()
			net.WriteEntity(target)
		self:MsgEnd()
	end,

	Receive = function(self, length, client)
		local target = net.ReadEntity()

		if (not ix.factionmgmt.CanManage(client, target)) then return end

		local character = target:GetCharacter()
		local old = character:GetName()

		client:RequestString("Rename", "A new name for " .. old, function(text)
			text = string.Trim(text or "")

			--[[
				Re-checked, and re-fetched. The dialog is open for as long as
				they leave it open, and in that time the target can change
				faction, be promoted past them, or disconnect.
			]]
			if (not IsValid(client) or not IsValid(target)
			or not ix.factionmgmt.CanManage(client, target)) then
				return
			end

			local current = target:GetCharacter()

			if (not current or current:GetID() ~= character:GetID()) then return end

			if (#text < 2 or #text > 70) then
				client:Notify("A name has to be between 2 and 70 characters.")
				return
			end

			current:SetName(text)
			current:Save()

			target:Notify("Your name is now " .. text .. ".")
			client:Notify(old .. " is now " .. text .. ".")
		end, old)
	end
})
