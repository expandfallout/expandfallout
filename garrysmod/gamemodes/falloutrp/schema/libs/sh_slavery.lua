--[[
	Slave collars.

	Phoenix's: an explosive collar with a GPS tracker, worn on the neck, armed
	by its owner and then GIVEN to somebody - the act of handing an armed collar
	over is the act of enslaving them. It counts down, and when the count
	reaches zero it falls off and is destroyed. Somebody else can try to defuse
	it, and getting that wrong sets it off.

	WHAT THEIR CODE ACTUALLY DID, since only the shared half is in the scrape:

	    wearCollar(true)   sets `enslaved` on the player, writes the item id on
	                       the character, force-equips it and starts a one
	                       second timer for `time` repetitions
	    the timer          decrements `time` by one and writes it back to the
	                       item every second
	    at zero            the collar comes off and is removed - so their
	                       countdown FREES you, and the explosion is a separate
	                       thing their server file triggers

	TWO THINGS ARE DELIBERATELY NOT THEIRS:

	    the clock          theirs writes item data sixty times a minute per
	                       collar, and item data is a database write and a
	                       network message. This keeps a DEADLINE and reads the
	                       clock instead - and it is `os.time`, because
	                       `CurTime` restarts at zero on every map load and a
	                       collar is meant to outlive one
	    who can see it     theirs keeps the time on the item, which is
	                       networked to the person holding it. A collar is
	                       around somebody's NECK - the whole point is that
	                       other people can look at it - so the deadline is a
	                       netvar on the wearer as well

	The mine, the vendor and the SlaveBoy 2000 that sells people to them are a
	later job. This is the collar itself.
]]

ix.slavery = ix.slavery or {}

--- The one item that is a collar. Kept here so nothing has to guess the name.
ix.slavery.item = "armor_misc_slavecollar"

ix.config.Add("slaveCollarMaxTime", 1200,
	"Seconds a slave collar runs for once it goes on.", nil, {
	data = {min = 60, max = 99999},
	category = "Slavery"
})

ix.config.Add("slaveCollarExplodeTime", 10,
	"Seconds between a collar being triggered and it going off.", nil, {
	data = {min = 1, max = 300},
	category = "Slavery"
})

ix.config.Add("slaveCollarDamage", 50,
	"Damage a slave collar does when it goes off.", nil, {
	data = {min = 1, max = 1000},
	category = "Slavery"
})

ix.config.Add("slaveCollarDisarmIntelligence", 15,
	"Intelligence needed to defuse a slave collar.", nil, {
	data = {min = 0, max = 30},
	category = "Slavery"
})

ix.config.Add("slaveCollarDisarmTime", 10,
	"Seconds it takes to defuse a slave collar.", nil, {
	data = {min = 1, max = 120},
	category = "Slavery"
})

--[[
	THE TRACKER AND THE LEASH. The SlaveBoy can mark where one of yours is
	for a while - a point on the screen only you see - and a collar within
	range of its owner is a collar that stays quiet: past `slaveProximity`
	units from them it counts down on its own, the way it does when it is
	triggered. Zero turns the leash off.
]]
ix.config.Add("slaveLocateCooldown", 30,
	"Seconds between uses of the SlaveBoy's tracker.", nil, {
	data = {min = 1, max = 600},
	category = "Slavery"
})

ix.config.Add("slaveLocateTime", 30,
	"Seconds a located slave stays marked on the owner's screen.", nil, {
	data = {min = 5, max = 300},
	category = "Slavery"
})

ix.config.Add("slaveProximity", 4000,
	"How far a slave may get from their owner before the collar triggers. "
	.. "0 turns the leash off.", nil, {
	data = {min = 0, max = 20000},
	category = "Slavery"
})

--------------------------------------------------------------------------------
-- Reading the state
--------------------------------------------------------------------------------

--- Is this person wearing a live collar.
function ix.slavery.Is(target)
	if (not IsValid(target) or not target:IsPlayer()) then return false end

	return target:GetNetVar("enslaved", false) == true
end

--[[
	Seconds left on somebody's collar.

	`os.time`, on both ends. A netvar holding a deadline needs no updates at
	all - it is sent once and stays true - which is the whole reason it is a
	deadline rather than a remaining time.
]]
function ix.slavery.Remaining(target)
	if (not ix.slavery.Is(target)) then return 0 end

	return math.max(target:GetNetVar("collarUntil", 0) - os.time(), 0)
end

--- The character id of whoever put it on, or nil.
function ix.slavery.OwnerID(target)
	if (not ix.slavery.Is(target)) then return end

	local id = target:GetNetVar("collarOwner", 0)

	return id > 0 and id or nil
end

--- Seconds until a triggered collar goes off, or nil if it has not been.
function ix.slavery.Fuse(target)
	if (not ix.slavery.Is(target)) then return end

	local at = target:GetNetVar("collarFuse", 0)

	if (at <= 0) then return end

	return math.max(at - os.time(), 0)
end

--- mm:ss, the way the collar's own icon writes it.
function ix.slavery.FormatTime(seconds)
	return string.FormattedTime(math.max(seconds, 0), "%02i:%02i")
end

--------------------------------------------------------------------------------
-- The menu entries
--------------------------------------------------------------------------------

--[[
	CHECKING THE TIME IS NOT AN ACTION. It is a look at something that is
	already networked, so it has no `OnRun` and never troubles the server - the
	name of the entry IS the answer, counting down while the menu is open.
]]
ix.interact.Add("slaveCollarCheck", {
	name = function(target)
		local fuse = ix.slavery.Fuse(target)

		if (fuse) then
			return "Collar: ARMED - " .. ix.slavery.FormatTime(fuse)
		end

		return "Collar: " .. ix.slavery.FormatTime(ix.slavery.Remaining(target))
	end,

	order = 30,

	canSee = function(target)
		return ix.slavery.Is(target)
	end,

	--- Nothing. Closing the menu is the whole interaction.
	callback = function()
		return false
	end
})

ix.interact.Add("slaveCollarDiffuse", {
	name = "Diffuse Collar",
	order = 31,

	canSee = function(target)
		if (not ix.slavery.Is(target)) then return false end
		if (ix.slavery.Is(LocalPlayer())) then return false end

		return not ix.restrain.Is(LocalPlayer())
	end,

	OnCanRun = function(client, target)
		if (not ix.slavery.Is(target)) then return false end

		if (ix.slavery.Is(client)) then
			return false, "Your own collar is rather more pressing."
		end

		if (ix.restrain.Is(client)) then
			return false, "Your hands are tied."
		end

		if (ix.slavery.Fuse(target)) then
			return false, "It is already counting down."
		end

		return true
	end,

	OnRun = function(client, target)
		ix.slavery.BeginDiffuse(client, target)
	end
})

--[[
	SETTING ONE OFF IS NOT IN THIS MENU, and that is deliberate.

	It was: an entry called "Trigger Collar" that appeared when you owned the
	collar you were looking at. Phoenix reach it through the SlaveBoy 2000
	instead - a handheld that lists everybody you own - and theirs is the better
	design for a reason worth writing down: triggering a collar is the one thing
	you do to a slave that does NOT require you to be stood in front of them.
	Putting it on a menu you can only open by holding E on somebody made the
	threat weaker than it is meant to be, because walking away from your captor
	made you safe.

	`items/sh_slaveboy.lua` is the handheld, `derma/cl_slaveboy.lua` is its
	screen, and the two net messages behind it are at the bottom of
	`sv_slavery.lua`.
]]
