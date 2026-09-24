--[[
	Race injector base item.

	Everything in `items/injector/` inherits this, and this inherits
	`base_aid` - a base item may itself have a base, and `items/base/sh_plant.lua`
	does the same thing for the same reason.

	WHAT THAT INHERITANCE BUYS, and why none of it is written again here:

	    Use            take it yourself
	    Inject         five seconds of standing still and staring at somebody
	                   else, with both of you told what is happening
	    CanConsume     the per-race chem whitelists, and the power armour rule
	    the sound      and the screen effect on the person dosed

	So an injector is an aid item whose effect happens to be "you are something
	else now". See `sh_raceinject.lua`.
]]

ITEM.base = "base_aid"

ITEM.name = "Injector"
ITEM.description = "A syringe of something that changes you."
ITEM.model = "models/mosi/fnv/props/health/stimpak.mdl"
ITEM.category = "Injectors"

ITEM.width = 1
ITEM.height = 1

--- The marker other systems key off, rather than a base name.
ITEM.isInjector = true

--- The race class this turns somebody into. See `schema/races/`.
ITEM.race = nil

--[[
	Seconds it lasts, or 0 for permanent.

	A temporary one falls back to `injectorDuration` when this is 0 and
	`temporary` is set, which is how the generated items are written: the
	config is the dial, and an item may still override it.
]]
ITEM.temporary = false
ITEM.duration = 0

ITEM.effectSound = "phoenix/itm/npc_human_using_psycho_01.mp3"
ITEM.injectFlavour = "inject"

--[[
	THE EFFECT.

	`base_aid` calls this with whoever is being dosed - which is not always the
	person holding it, since one can be pushed into somebody else. Everything
	after this point is `ix.raceinject.Begin`'s.
]]
ITEM.effectFunctions = {
	OnConsume = function(item, client)
		if (not SERVER) then return end

		local duration = item.temporary
			and ix.raceinject.Duration(item) or 0

		--[[
			`temporary` is passed as well as the duration, because 0 means two
			different things: a permanent injection, and a temporary one that
			lasts a life. See `ix.raceinject.Duration`.
		]]
		ix.raceinject.Begin(client, item.race, duration, item,
			item.temporary == true)
	end
}

--[[
	INJECTING SOMEBODY ELSE NEEDS THEM RESTRAINED.

	`base_aid` offers Inject to anybody standing still for five seconds, which
	is right for a chem and wrong for this - see `injectorNeedsRestrained`. The
	entry is HIDDEN rather than refused when they are not, because the answer
	never changes while you are looking at them: an entry that always says no
	is an entry that reads as broken.

	Written as a wrap of the base's own `OnCanRun` so the base keeps deciding
	everything else - reach, being alive, the item not being on the floor.
]]
do
	local base = ix.item.base and ix.item.base.base_aid
	local inherited = base and base.functions and base.functions.Inject

	ITEM.functions.Inject = table.Copy(inherited or {})

	local original = ITEM.functions.Inject.OnCanRun

	ITEM.functions.Inject.OnCanRun = function(item)
		if (original and original(item) == false) then return false end

		if (not ix.config.Get("injectorNeedsRestrained", true)) then
			return true
		end

		local client = item.player

		if (not IsValid(client)) then return false end

		local target = client:GetEyeTrace().Entity

		return IsValid(target) and target:IsPlayer()
			and ix.restrain and ix.restrain.Is(target) or false
	end
end

--[[
	The description says which way round it is, because that is the only thing
	that separates the two items made for each race and getting it wrong is not
	something anybody can undo.
]]
function ITEM:GetDescription()
	local description = self.description or ""
	local race = ix.races and ix.races.Get(self.race)

	if (not race) then
		return description .. "\n\n - Whatever was in this has spoiled."
	end

	if (not self.temporary) then
		return description .. "\n\n - Permanent. There is no way back."
	end

	local duration = ix.raceinject and ix.raceinject.Duration(self) or 0

	--- Zero is not "no time"; it is the one-life kind. See `Duration`.
	if (duration <= 0) then
		return description .. "\n\n - Wears off when you die."
	end

	return string.format("%s\n\n - Wears off after %s.", description,
		ix.bench.FormatTime(duration))
end
