--[[
	Changing a character's race after creation.

	Phoenix have `/charsetrace` and it is the command an admin reaches for most
	on a schema with forty-four of them: somebody picks wrong, somebody is
	turned into a ghoul in a story, somebody's race is retired.

	IT DOES NOT JUST SET THE FIELD. A race decides the model, the hull, the
	view offset, the base health and the animation set, so changing it and
	leaving the player standing there gives a character whose race says one
	thing and whose body says another. Everything derived is rebuilt, and the
	player is respawned to pick it all up.
]]

if (not SERVER) then return end

--[[
	Change a character's race, and rebuild everything that follows from it.

	ONE IMPLEMENTATION, because there are now two ways in: `/charsetrace` and
	a race injector (`sh_raceinject.lua`). The rules below are the interesting
	part of both, and two copies of them would drift the first time one was
	corrected.

	Returns `true, race` or `false, reason`.
]]
function ix.races.Apply(target, class)
	if (not IsValid(target)) then return false, "Nobody there." end

	local character = target:GetCharacter()

	if (not character) then return false, "They have no character." end

	class = string.lower(string.Trim(class or ""))

	local race = ix.races.Get(class)

	if (not race) then
		return false, string.format("No race with the class '%s'.", class)
	end

	character:SetRace(class)

	--[[
		The gender has to be one this race actually has.

		Most creature races are male-only - it is how their model sets are
		built - so a female character turned into a securitron would ask for a
		model that does not exist and get nothing at all.
	]]
	local genders = ix.races.GetGenders(class)

	if (not genders[character:GetGender()]) then
		for gender, enabled in pairs(genders) do
			if (enabled) then
				character:SetGender(gender)

				break
			end
		end
	end

	--[[
		Respawned rather than merely re-modelled. Hull, view offset and base
		health are all applied on spawn, and a race change that leaves a player
		crouching inside their own collision box is worse than one that costs
		them a respawn.

		PUT BACK WHERE THEY WERE STANDING. `Spawn` sends them to a spawn point,
		which is right for dying and wrong for this: a race injector taken in a
		cave should not be a free trip to the town square, and an admin fixing
		somebody's race should not move them. The position is taken before and
		restored on the next frame, because `PlayerLoadout` and the spawn point
		selection both run after `Spawn` returns and would overwrite an
		immediate `SetPos`.
	]]
	if (target:Alive()) then
		local position = target:GetPos()
		local angles = target:EyeAngles()
		local health = target:Health()

		target:Spawn()

		timer.Simple(0, function()
			if (not IsValid(target)) then return end

			target:SetPos(position)
			target:SetEyeAngles(angles)

			--[[
				And the health they had, clamped to what the NEW race can
				carry - races have different base health, and a radroach with
				a super mutant's hit points is not what anybody meant.
			]]
			target:SetHealth(math.Clamp(health, 1, target:GetMaxHealth()))
		end)
	end

	if (character.ApplyBodyState) then
		character:ApplyBodyState()
	end

	--[[
		SAVED EXPLICITLY.

		`SetRace` is one of Helix's generated setters: it writes `self.vars`
		and networks the change, and it does not touch the database. Without
		this the character is the new race until the server restarts and then
		quietly is not, which is the worst of both - it looks like it worked.
	]]
	character:Save()

	return true, race
end

ix.log.AddType("charSetRace", function(client, name, from, to)
	return string.format("%s changed %s's race from %s to %s.",
		client:Name(), name, from, to)
end, FLAG_WARNING)

--[[
	The list, for when somebody has forgotten what a race is called.

	Separate from the viewer window because a chat command answers faster than
	a menu when you already know roughly what you are looking for.
]]

--[[
	The commands for this library live in `sh_commands.lua`.
	They have to be declared on both realms or the chatbox cannot
	see them - see the header there.
]]
