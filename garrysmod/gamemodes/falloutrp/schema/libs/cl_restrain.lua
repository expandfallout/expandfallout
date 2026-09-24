--[[
	Two small things a restrained person's searcher must not see, and one
	everybody should.

	    the caps row     `ix.storage.Sync` fills `info.data.money` from the
	                     character behind the inventory it is opening, and the
	                     panel that shows a number also has the button that
	                     takes it. Searching somebody would then be mugging
	                     them, which is a separate system with limits of its
	                     own that this would walk straight around
	    the label        Phoenix drew "Restrained" in red on the character
	                     info; here that is Helix's `PopulateCharacterInfo`,
	                     which fills the tooltip you get looking at somebody

	The money wrap is the same trick `cl_trash.lua` uses and for the same
	reason - Helix has no hook between the storage panel and its money row - so
	it is written the same way rather than cleverly: wrap once, guarded, and
	no-op for exactly one inventory id.
]]

if (not CLIENT) then return end

ix.restrain = ix.restrain or {}

--- Which inventory is a search, told to us as it opens. 0 is "none".
ix.restrain.searchID = ix.restrain.searchID or 0

net.Receive("ixRestrainSearch", function()
	ix.restrain.searchID = net.ReadUInt(32)
end)

local function WrapMoney()
	local PANEL = vgui.GetControlTable("ixStorageView")

	if (not PANEL) then return false end
	if (PANEL.ixRestrainMoney) then return true end

	PANEL.ixRestrainMoney = true

	for _, name in ipairs({"SetLocalMoney", "SetStorageMoney"}) do
		local original = PANEL[name]

		if (not original) then continue end

		PANEL[name] = function(self, ...)
			if (self.GetStorageID and ix.restrain.searchID > 0
			and self:GetStorageID() == ix.restrain.searchID) then
				return
			end

			return original(self, ...)
		end
	end

	return true
end

--[[
	There is no "derma is ready" hook, so this is the same retry the bin uses.
	`ixStorageView` is registered when Helix includes its derma, which may be
	after this file.
]]
if (not WrapMoney()) then
	timer.Create("ixRestrainMoneyWrap", 1, 10, function()
		if (WrapMoney()) then timer.Remove("ixRestrainMoneyWrap") end
	end)
end

--[[
	"RESTRAINED", under their name.

	`PopulateCharacterInfo` is Helix's hook for the tooltip that appears when
	you look at somebody, and it is a `hook.Add` on a `GM:` method that already
	exists - so this must NOT return anything, or the description row that
	their own method adds never runs. See gotcha 9.
]]
hook.Add("PopulateCharacterInfo", "ixRestrain", function(client, character,
	container)
	local kindID = ix.restrain.Kind(client)

	if (not kindID) then return end

	local kind = ix.restrain.kinds[kindID]
	local row = container:AddRow("restrained")

	row:SetText(kind.label)
	row:SetBackgroundColor(Color(160, 30, 30))
	row:SizeToContents()
end)
