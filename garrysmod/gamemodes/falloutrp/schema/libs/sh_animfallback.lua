--[[
	Animation classes Phoenix never registered.

	Each of their race files carries its own animation set and registers it
	against the model it belongs to, and `genraces.py` carries all of that
	across. Four models are not covered that way, and were T-posing and
	spasming because of it.

	THE FIRST VERSION OF THIS FILE GUESSED, AND GOT TWO OF THREE WRONG.

	It reasoned from what the creature IS - a behemoth is a super mutant, both
	models ship in the same pack, so point `supermutant.mdl` at `behemoth`.
	That is a story about Fallout, not about the file. An animation class is a
	table of SEQUENCE NAMES and Helix plays them by name; the behemoth set is
	20% present on the super mutant model, so four sequences in five resolved
	to nothing and the model fell back to sequence 0, which in these packs is
	the reference pose. That is the T-pose, and the spasm was it flicking
	between a name that exists and one that does not.

	THESE ARE MEASURED. `_docs/tools/mdlseq.py` reads the sequence table out of
	the .mdl, follows `$includemodel`, and scores every class by how much of it
	the model actually has:

	    models/fallout/supermutant.mdl          supermutant  73%   (behemoth 20%)
	    models/roadkill_fallout/robots/
	        securitron.mdl                      securitron   77%   (robobrain 6%)
	    models/fallout_4/actors/powerarmor/
	        powerarmorframe.mdl                 f4pa         46%   (nothing else >0)
	    models/fallout/dogvicious.mdl           dog          31%

	Re-run it with `python _docs/tools/mdlseq.py --match` after touching any of
	this; 27-31% is what a CORRECT creature registration scores, because the
	tables carry entries for weapon types these models never hold.

	THE SETS WERE ALREADY HERE. `supermutant`, `securitron` and `f4pa` are
	three of the four classes in `libs/sh_anims.lua`, written out in full and
	registered against nothing - so the animations for a super mutant had been
	sitting in the schema unused the whole time. Phoenix have the same tables
	and no `setModelClass` for them either; theirs presumably lives in a
	server-only file, which is the half of their codebase no scrape contains.

	`dogvicious.mdl` is the one inference left, and it is a safe one: its
	sequence table is IDENTICAL to `dogskin.mdl`, which Phoenix register to
	`dog` themselves. Not similar - identical, 51 names, no difference either
	way.

	Registered late so a race file that defines its own always wins:
	`SetModelClass` overwrites, and a real set is better than an inferred one.
]]

--[[
	`[model] = class`. The class has to already exist - `supermutant`,
	`securitron` and `f4pa` come from `sh_anims.lua` and `dog` from a race
	file, so this must run after both.
]]
local FALLBACKS = {
	--[[
		Super mutants, nightkin and Frank Horrigan all share this model, so
		this one line covers three races. Its own file holds a single sequence
		(`ragdoll`); the 97 real ones come from
		`models/fallout/supermutant_animations.mdl` through `$includemodel`,
		which is why reading the model named by the race said it had no
		animations at all.
	]]
	["models/fallout/supermutant.mdl"] = "supermutant",

	--- Both securitron races, House's and the executive chassis.
	["models/roadkill_fallout/robots/securitron.mdl"] = "securitron",

	--[[
		Not a race - the Power Armour frame, which body armour swaps a player
		onto through `ITEM.replaceAnimModel`. Without this a character in the
		F4 frame reverts to whatever their race's class was, on a skeleton that
		has none of its sequences.
	]]
	["models/fallout_4/actors/powerarmor/powerarmorframe.mdl"] = "f4pa",

	--- The Legion mongrel. Same sequences as `dogskin.mdl`, which uses `dog`.
	["models/fallout/dogvicious.mdl"] = "dog"
}

local function ApplyFallbacks()
	local applied, skipped = 0, {}

	for model, class in pairs(FALLBACKS) do
		--[[
			Only applied if the class is actually defined. Pointing a model at
			a class that does not exist is worse than leaving it alone, because
			the animation system then has nothing at all to fall back to.
		]]
		if (ix.anim[class]) then
			ix.anim.SetModelClass(model, class)
			applied = applied + 1
		else
			skipped[#skipped + 1] = class
		end
	end

	if (#skipped > 0) then
		MsgC(Color(255, 200, 100), string.format(
			"[falloutrp] %d animation fallback(s) applied, %d skipped - no such "
			.. "class: %s\n", applied, #skipped, table.concat(skipped, ", ")))
	end

	return applied
end

--[[
	On a timer rather than at file scope.

	`libs/` is included before the races are, so at load time the `dog` class
	does not exist yet - the same ordering trap that `cl_buff.lua` sits in. A
	zero timer runs after everything has been included.
]]
timer.Simple(0, ApplyFallbacks)

--[[
	And again on a refresh, where the race files re-register their own classes
	and would otherwise win permanently.
]]
hook.Add("OnReloaded", "ixAnimFallback", function()
	timer.Simple(0, ApplyFallbacks)
end)
