--[[
	Naming things.

	Phoenix let a bag be named, and a Master Craft or Pearlescent gun - the
	two tiers rare enough that one is worth talking about. So does this:
	RENAME on the right-click menu, a box, and the name is on the item
	wherever the item's name is printed - the label, the tooltip, chat, the
	pickup notice, the bag's window title. The maker's own name is kept in
	the description underneath, because "Lucky" tells you nothing about
	what it fires.

	WHO MAY: whoever holds it. The item has to be in an inventory the asker
	owns - a bag of theirs counts - and be one of the two kinds.
	`CanRenameItem` is a hook for anything else that wants a say.

	THE NAME IS DATA (`customName`), so it travels with the item through
	drops, trades, bags and the market, and a blank takes it off.

	THE RARITY STAYS. `cl_rarity.lua` wraps a weapon's `GetName` to put the
	tier in front, and this wraps it again, in whichever order the two
	`InitializedPlugins` hooks happen to run: the plain name is REPLACED
	inside whatever the other wrap produced, so "Pearlescent R-700" named
	Lucky is "Pearlescent Lucky" either way round.
]]

ix.rename = ix.rename or {}

--- The longest a name may be. Phoenix's box took thirty-two.
ix.rename.maxLength = 32

if (SERVER) then
	util.AddNetworkString("ixItemRename")
end

--- The name somebody gave it, or nil.
function ix.rename.Get(item)
	local name = item and item.GetData and item:GetData("customName")

	if (isstring(name) and name ~= "") then return name end
end

--- Whether this kind of item takes a name at all.
function ix.rename.Can(item)
	if (not item) then return false end

	local override = hook.Run("CanRenameItem", item)

	if (override ~= nil) then return override == true end

	if (item.backpack) then return true end

	if (item.base == "base_weapons" and ix.rarity and ix.rarity.Get) then
		local rarity = ix.rarity.Get(item)

		return rarity == "master" or rarity == "pearlescent"
	end

	return false
end

--[[
	A name as it may be stored: no control characters, one space between
	words, trimmed, and no longer than the cap. Anything else is somebody
	else's problem to look at - a name is shown, never run.
]]
function ix.rename.Clean(text)
	text = tostring(text or "")
	text = string.gsub(text, "%c", "")
	text = string.gsub(text, "%s+", " ")
	text = string.Trim(text)

	return string.sub(text, 1, ix.rename.maxLength)
end

--- What the item's file calls it, translated on the client as Helix does.
local function Plain(item)
	return CLIENT and L(item.name) or item.name
end

--- Put the name and the "was a ..." line onto one item table.
function ix.rename.Wrap(itemTable)
	if (itemTable.ixRenameWrapped) then return end

	itemTable.ixRenameWrapped = true

	local getName = itemTable.GetName

	itemTable.GetName = function(self)
		local name = getName and getName(self) or Plain(self)
		local custom = ix.rename.Get(self)

		if (not custom) then return name end

		local plain = Plain(self)

		if (plain ~= "" and string.find(name, plain, 1, true)) then
			return string.Replace(name, plain, custom)
		end

		return custom
	end

	local describe = itemTable.GetDescription

	itemTable.GetDescription = function(self)
		local base = describe and describe(self) or self.description or ""
		local custom = ix.rename.Get(self)

		if (not custom) then return base end

		return string.format("%s\n\nIts makers called it a %s.", base, Plain(self))
	end
end

--[[
	The menu entry. The click opens a box and sends the answer itself; it
	returns false so Helix does not also run it on the server as an
	inventory action, because the server's half is the receiver below.
]]
function ix.rename.Entry()
	return {
		name = "Rename",
		icon = "icon16/pencil.png",

		OnClick = function(item)
			local current = ix.rename.Get(item) or ""
			local id = item.id

			Derma_StringRequest("Rename",
				"A name for it, or blank to take the name off.", current,
				function(text)
					net.Start("ixItemRename")
						net.WriteUInt(id, 32)
						net.WriteString(ix.rename.Clean(text))
					net.SendToServer()
				end)

			return false
		end,

		OnCanRun = function(item)
			return not IsValid(item.entity) and ix.rename.Can(item)
		end
	}
end

--[[
	Every weapon gets the entry. NOT THE BASE: Helix copies a base into
	each item at registration, so a function added to `base_weapons`
	afterwards reaches nothing - `sh_brand.lua` says so at length.
]]
hook.Add("InitializedPlugins", "ixRename", function()
	for _, itemTable in pairs(ix.item.list) do
		if (itemTable.base == "base_weapons") then
			itemTable.functions = itemTable.functions or {}
			itemTable.functions.Rename = itemTable.functions.Rename
				or ix.rename.Entry()

			ix.rename.Wrap(itemTable)
		end
	end
end)

if (not SERVER) then return end

net.Receive("ixItemRename", function(_, client)
	if ((client.ixRenameNext or 0) > CurTime()) then return end

	client.ixRenameNext = CurTime() + 0.5

	local item = ix.item.instances[net.ReadUInt(32)]
	local name = ix.rename.Clean(net.ReadString())

	if (not item or not client:GetCharacter()) then return end

	if (not ix.rename.Can(item)) then
		client:Notify("That is not something that takes a name.")

		return
	end

	--- Theirs: in an inventory of theirs, or a bag of theirs.
	local owner = item.GetOwner and item:GetOwner() or nil

	if (owner ~= client) then
		client:Notify("That is not yours to name.")

		return
	end

	item:SetData("customName", name ~= "" and name or nil)

	if (name ~= "") then
		client:Notify(string.format("Named it '%s'.", name))
	else
		client:Notify("Took the name off.")
	end

	ix.log.Add(client, "itemRename", item.name, name)
end)

ix.log.AddType("itemRename", function(client, what, name)
	if (name == "") then
		return string.format("%s took the name off a %s.", client:Name(), what)
	end

	return string.format("%s named a %s '%s'.", client:Name(), what, name)
end)
