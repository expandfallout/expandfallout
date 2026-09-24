--[[
	An addon put `GetInventory` on the Entity metatable, and it shadowed every
	scripted entity that has one.

	`fallout_snpcs_remastered/lua/autorun/vj_f3r_meta.lua` line 184 does

	    local ENT = FindMetaTable("Entity")

	and then defines six methods on it - `InFront`, `DoFlameDamage`,
	`FindInventoryItem`, `GetInventory`, `RemoveFromInventory` and
	`AddToInventory`. Five of those collide with nothing. The sixth is the name
	Helix's container entity uses.

	A METATABLE METHOD WINS OVER THE SENT'S OWN. So `ix_container:GetInventory`
	- `ix.item.inventories[self:GetID()]`, the right answer - was never called;
	`self:GetInventory()` reached the addon's version instead, which returns
	`self.tbl_Inventory`, which is nil on anything that is not a VJ NPC.

	    if (inventory and ...) then      -- ix_container:Use
	        ...
	    end                              -- no else, no message

	so pressing E on a crate did nothing at all, with every diagnostic
	reporting the container healthy - because everything except that one
	expression WAS healthy.

	IT COST FIVE ROUNDS, and the thing that found it was `debug.getinfo` on the
	method itself. Reading the codebase could not have found it: the file that
	broke this is not in the gamemode, is not a plugin, and is loaded from
	`lua/autorun` before the gamemode exists. See `07-gotchas.md`.

	It is also why the FACTION storage started working when its `Use` stopped
	calling `self:GetInventory()` and used `ix.factionStorage.ResolveInventory`
	instead - that fix worked, but not for the reason given at the time.

	THE ADDON'S METHOD IS KEPT, NOT DELETED. Its own NPCs call it and removing
	it would break them. What is restored is the PRECEDENCE: an entity class
	that defines its own `GetInventory` gets its own, and everything else still
	gets the addon's.
]]

local entityMeta = FindMetaTable("Entity")

if (not entityMeta or not entityMeta.GetInventory) then return end

--[[
	Guarded against running twice. A schema refresh re-includes this file, and
	wrapping the wrapper would add a layer of indirection per refresh.
]]
if (entityMeta.ixInventoryFixed) then return end

entityMeta.ixInventoryFixed = true

local addonGetInventory = entityMeta.GetInventory

function entityMeta:GetInventory(...)
	--[[
		The class's OWN method, looked up on the registered SENT table rather
		than on the entity - `self.GetInventory` is this function, and asking
		the entity would recurse for ever.

		`scripted_ents.GetStored` gives the table the class was registered
		with. Anything that does not define one - every prop, every VJ NPC -
		finds nothing here and falls through, which is the whole point.
	]]
	local stored = scripted_ents.GetStored(self:GetClass() or "")
	local own = stored and stored.t and stored.t.GetInventory

	if (own and own ~= entityMeta.GetInventory) then
		return own(self, ...)
	end

	return addonGetInventory(self, ...)
end

--[[
	Named so `fo_ui_report` and anything else auditing the schema can see that
	this was patched, rather than it being an invisible change to a metatable
	somebody else owns.
]]
ix.fallout = ix.fallout or {}
ix.fallout.patchedMeta = ix.fallout.patchedMeta or {}
ix.fallout.patchedMeta["Entity:GetInventory"] =
	"deferred to the entity class, shadowed by fallout_snpcs_remastered"

--[[
	Report every method any addon has put on the Entity metatable that a
	scripted entity in this schema also defines.

	This is the general form of the bug, and it is silent by construction: the
	shadowing method usually returns nil rather than erroring, so the symptom
	is a feature that quietly does nothing.
]]
concommand.Add("fo_meta_report", function(client)
	local function Line(text)
		if (IsValid(client)) then
			client:ChatPrint(text)
		end

		MsgC(Color(200, 200, 200), text .. "\n")
	end

	local clashes = 0

	for name, stored in pairs(scripted_ents.GetList() or {}) do
		for method in pairs(stored.t or {}) do
			if (not isfunction(entityMeta[method])) then continue end
			if (not isfunction(stored.t[method])) then continue end

			local meta = debug.getinfo(entityMeta[method], "S")
			local own = debug.getinfo(stored.t[method], "S")

			if (meta and own and meta.short_src ~= own.short_src) then
				clashes = clashes + 1

				Line(string.format("  %s:%s", name, method))
				Line(string.format("      class %s:%d",
					own.short_src, own.linedefined))
				Line(string.format("      meta  %s:%d",
					meta.short_src, meta.linedefined))
			end
		end
	end

	Line(string.format(
		"[falloutrp] %d entity method(s) shadowed by the Entity metatable",
		clashes))
end)
