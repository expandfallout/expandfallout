--[[
	The black market, client half: the window opens, asks for pages, and
	sends what the person clicked. Everything is decided on the server; see
	`sv_blackmarket.lua`.

	`ix.blackmarket` IS DECLARED HERE TOO: `cl_` files load before `sh_`
	ones (gotcha 26).
]]

if (not CLIENT) then return end

ix.blackmarket = ix.blackmarket or {}

net.Receive("ixMarketOpen", function()
	local terminal = net.ReadEntity()

	if (IsValid(ix.gui.blackmarket)) then ix.gui.blackmarket:Remove() end

	ix.gui.blackmarket = vgui.Create("ixFOBlackMarket")
	ix.gui.blackmarket.terminal = terminal
end)

net.Receive("ixMarketPage", function()
	local tab = net.ReadString()
	local page = net.ReadUInt(16)
	local pages = net.ReadUInt(16)
	local count = net.ReadUInt(16)
	local rows = net.ReadTable()

	if (IsValid(ix.gui.blackmarket)) then
		ix.gui.blackmarket:Receive(tab, page, pages, count, rows)
	end
end)

net.Receive("ixMarketRefresh", function()
	if (IsValid(ix.gui.blackmarket)) then ix.gui.blackmarket:Reload() end
end)

--- A page of a tab, with the filters the window has set.
function ix.blackmarket.Ask(tab, page, filter)
	net.Start("ixMarketAsk")
		net.WriteString(tab)
		net.WriteUInt(math.max(page or 1, 1), 16)
		net.WriteTable(filter or {})
	net.SendToServer()
end

function ix.blackmarket.SendSell(itemID, quantity, price, days, anonymous,
	notes)
	net.Start("ixMarketSell")
		net.WriteUInt(itemID, 32)
		net.WriteUInt(math.Clamp(quantity, 1, 65535), 16)
		net.WriteUInt(math.Clamp(price, 0, 4294967295), 32)
		net.WriteUInt(math.Clamp(days, 1, 255), 8)
		net.WriteBool(anonymous == true)
		net.WriteString(string.sub(notes or "", 1, ix.blackmarket.NOTE or 100))
	net.SendToServer()
end

function ix.blackmarket.SendBuy(id, quantity)
	net.Start("ixMarketBuy")
		net.WriteUInt(id, 32)
		net.WriteUInt(math.Clamp(quantity, 1, 65535), 16)
	net.SendToServer()
end

function ix.blackmarket.SendUnlist(id, quantity)
	net.Start("ixMarketUnlist")
		net.WriteUInt(id, 32)
		net.WriteUInt(math.Clamp(quantity or 0, 0, 65535), 16)
	net.SendToServer()
end

function ix.blackmarket.SendClaim(id)
	net.Start("ixMarketClaim")
		net.WriteUInt(id, 32)
	net.SendToServer()
end
