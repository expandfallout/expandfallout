--[[
	Doing the mugging, and what it costs the person who does it.

	`sh_mugging.lua` holds the numbers and the menu entry; this is the act. It
	is a stared action like every other timed thing done to a person in this
	schema, so looking away stops it.

	THE ORDER AT THE END IS DELIBERATE: the caps move first, then the mark,
	then the telling. Anything that throws after the money has moved has
	already done the part the two of them care about, and anything that throws
	before it has taken nothing - which is the same rule the cap stash learned
	(gotcha 12's neighbour: do the thing, then the bookkeeping).
]]

if (not SERVER) then return end

util.AddNetworkString("ixMugged")

--[[
	Cooldowns live on the PLAYER, not the character.

	They are about the person doing it rather than the character sheet, they
	are short, and they are meant to stop a mugging becoming a tap you can
	stand there turning - none of which is worth a database write. A relog
	clearing them is fine; relogging to mug somebody twice is a lot of effort
	for one extra go.
]]
local function Cooling(client, key, notice)
	local until_ = client[key] or 0

	if (until_ <= CurTime()) then return false end

	return true, string.format(notice, math.ceil(until_ - CurTime()))
end

--[[
	Everything that has to be true before a mugging can start.

	One function, because the menu entry asks it to decide whether to offer the
	option and `Begin` asks it again a moment later - and the second answer is
	the one that counts.
]]
function ix.mugging.CanMug(client, target)
	if (not IsValid(client) or not IsValid(target)) then return false end

	if (not ix.restrain.Is(target)) then
		return false, "They are not restrained."
	end

	if (ix.restrain.Is(client)) then
		return false, "Your own hands are tied."
	end

	if (client.ixMugBusy) then return false, "You are already busy." end

	local waiting, why = Cooling(client, "ixMugNext",
		"You cannot mug anybody for another %d seconds.")

	if (waiting) then return false, why end

	waiting, why = Cooling(target, "ixMuggedNext",
		"They have been robbed too recently - %d seconds.")

	if (waiting) then return false, why end

	return true
end

--[[
	Rob them.

	The victim is told what is happening as it starts, which is Phoenix's
	behaviour for the zip tie and is right for the same reason: being robbed is
	a thing you are meant to be able to react to, not something you discover
	afterwards by looking at your caps.
]]
function ix.mugging.Begin(client, target)
	local ok, why = ix.mugging.CanMug(client, target)

	if (not ok) then
		if (why) then client:Notify(why) end

		return false
	end

	local time = ix.config.Get("mugTime", 5)

	client.ixMugBusy = true

	client:SetAction("Mugging", time)
	target:SetAction("You are being robbed", time)

	target:Notify("[ ! ] You are being robbed!")
	target:EmitSound("phoenix/ui/nv/ui_popup_messagewindow.mp3", 70)

	ix.chat.Send(client, "me", "starts going through the person's pockets.")

	client:DoStaredAction(target, function()
		client.ixMugBusy = nil

		if (not IsValid(client) or not IsValid(target)) then return end

		client:SetAction()
		target:SetAction()

		--[[
			CHECKED AGAIN, because five seconds is long enough for somebody to
			have been cut free, killed, or robbed by the person stood next to
			you.
		]]
		local allowed, reason = ix.mugging.CanMug(client, target)

		if (not allowed) then
			if (reason) then client:Notify(reason) end

			return
		end

		ix.mugging.Finish(client, target)
	end, time, function()
		client.ixMugBusy = nil

		if (IsValid(client)) then
			client:SetAction()
			client:Notify("You stopped robbing them.")
		end

		if (IsValid(target)) then target:SetAction() end
	end)

	return true
end

--[[
	The money, the mark, and the blue line.
]]
function ix.mugging.Finish(client, target)
	local theirs = target:GetCharacter()
	local ours = client:GetCharacter()

	if (not theirs or not ours) then return false end

	--- What they are worth, capped by what they are actually carrying.
	local wanted = ix.mugging.Amount(theirs)
	local taken = math.min(wanted, theirs:GetMoney())

	if (taken > 0) then
		theirs:SetMoney(theirs:GetMoney() - taken)
		ours:SetMoney(ours:GetMoney() + taken)
	end

	client:EmitSound("phoenix/ui/nv/ui_items_bottlecaps_0"
		.. math.random(4) .. ".mp3", 70)

	--[[
		THE MUGGER IS MARKED, not the victim. See the header of
		`sh_mugging.lua`: the victim is owed a reason to kill somebody, and the
		mark is what makes that reason enforceable.

		Marked BY the victim, so the log reads as what happened rather than as
		an admin action - `ix.pk.Mark` writes whoever is passed here into it.
	]]
	local seconds = ix.config.Get("mugPKTime", 30)

	if (seconds > 0) then
		ix.pk.Mark(target, client, seconds, "mugged " .. theirs:GetName())
	end

	--[[
		The blue line, to the victim alone.

		THE MUGGER IS SENT, NOT THEIR NAME. `GetCharacterName` is the
		recognition hook and it only exists on the CLIENT - it answers "what do
		*I* know this person as" - so composing the sentence here would name
		somebody the victim has never been introduced to. The client builds it
		and describes a stranger as a stranger.

		A PK reason you cannot act on is not much of a reason; one that hands
		out a name nobody gave you is a different system entirely.
	]]
	net.Start("ixMugged")
		net.WriteEntity(client)
		net.WriteUInt(taken, 32)
	net.Send(target)

	if (taken > 0) then
		client:Notify(string.format("You take %s.",
			ix.points.FormatCaps(taken)))
		target:Notify(string.format("They take %s off you.",
			ix.points.FormatCaps(taken)))
	else
		client:Notify("They have nothing worth taking.")
		target:Notify("They find nothing on you.")
	end

	client.ixMugNext = CurTime() + ix.config.Get("mugCooldown", 60)
	target.ixMuggedNext = CurTime() + ix.config.Get("muggedCooldown", 60)

	ix.log.Add(client, "mug", target:Name(), taken)

	hook.Run("PlayerMugged", client, target, taken)

	return true
end

ix.log.AddType("mug", function(client, name, amount)
	return string.format("%s mugged %s for %s.", client:Name(), name,
		ix.points.FormatCaps(amount))
end, FLAG_DANGER)
