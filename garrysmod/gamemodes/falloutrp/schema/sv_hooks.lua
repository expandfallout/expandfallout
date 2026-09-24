-- Serverside schema hooks.

ix.fallout = ix.fallout or {}

--[[
	Player model, scale, hull and view offset - all four from the RACE.

	THIS WAS HARDCODED TO THE HUMAN and it is why a super mutant was invisible.

	Every faction's `FACTION.models` is the human animation carrier, because
	that is what the faction generator writes, so Helix gives EVERY character
	`models/phoenix/humans/animations.mdl` at spawn whatever race they are.
	That model has no mesh - it is 301 New Vegas sequences and a skeleton -
	and `cl_bodyparts.lua` only bone-merges a body onto a player whose model
	is THEIR OWN race's carrier. A super mutant's is
	`models/fallout/supermutant.mdl`, so the test failed, no parts were built,
	and there was nothing to see at all.

	Nothing anywhere set the model from the race. `/charsetrace` respawns and
	its comment says the hull and view offset are "applied on spawn", which
	was true of the function below and true only for humans.

	This is Phoenix's own order, from `sh_races.lua` line 967: model, scale,
	view offset, hull. Base health is not here - `characterMeta:ApplyBodyState`
	in `sv_radiation.lua` already owns it, and two places setting max health
	is how a race change silently reverts.
]]

local ANIMATION_MODEL = "models/phoenix/humans/animations.mdl"

--[[
	The model a character should actually be wearing.

	Body armour can replace it: `ITEM.replaceAnimModel` is how a Power Armour
	frame becomes a different skeleton rather than a mesh merged onto a human
	one. That override is NOT persisted - see below.
]]
function ix.fallout.GetAnimationModel(character)
	if (not character) then return ANIMATION_MODEL end

	if (ix.armor) then
		local body = ix.armor.GetEquipped(character).body

		if (body and body.replaceAnimModel) then
			return body.replaceAnimModel
		end
	end

	return (ix.races and ix.races.GetAnimationModel(character:GetRace()))
		or ANIMATION_MODEL
end

local function ApplyProportions(client)
	if (not IsValid(client) or not client:Alive()) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	local class = character:GetRace()
	local model = ix.fallout.GetAnimationModel(character)

	--[[
		THE CHARACTER'S OWN MODEL VAR IS CORRECTED TOO, and only to the race's
		carrier - never to an armour override, which has to come off again.

		Without this the fix would only hold while the player is alive: the
		var is what Helix re-applies on every spawn, what the character select
		screen previews, and what is written to the database. A character
		created before this existed carries the human carrier in that field
		for ever, so this is also what repairs them - on their next spawn,
		with no command to run.
	]]
	local raceModel = (ix.races and ix.races.GetAnimationModel(class))
		or ANIMATION_MODEL

	if (string.lower(character:GetModel() or "") ~= string.lower(raceModel)) then
		character:SetModel(raceModel)
	end

	if (string.lower(client:GetModel() or "") ~= string.lower(model)) then
		client:SetModel(model)
	end

	--[[
		Armour can make you taller. `ITEM.playerHeight` is a multiplier, set by
		35 Power Armour suits at 1.1 or 1.2, and it multiplies the race scale
		rather than replacing it - so a suit makes any race proportionally
		taller instead of making every race the same height.

		Only the MODEL is scaled. The collision hull and view offset stay at
		the race's values on purpose: a taller hull would catch on door frames
		the suit visually fits through, and Phoenix scale theirs the same way.
	]]
	local height = ix.armor and ix.armor.GetHeightMultiplier(character) or 1
	local scale = (ix.races and ix.races.GetScale(class) or 1) * height

	client:SetModelScale(scale, 0)

	local hull = ix.races and ix.races.GetHull(class)
	local view = ix.races and ix.races.GetViewOffsets(class)

	if (hull and hull.normal and hull.ducked) then
		client:SetHull(Vector(-hull.normal.x, -hull.normal.y, 0),
			Vector(hull.normal.x, hull.normal.y, hull.normal.z))
		client:SetHullDuck(Vector(-hull.ducked.x, -hull.ducked.y, 0),
			Vector(hull.ducked.x, hull.ducked.y, hull.ducked.z))
	end

	if (view and view.normal and view.ducked) then
		client:SetViewOffset(view.normal)
		client:SetViewOffsetDucked(view.ducked)
	end
end

--[[
	Exposed so equipping armour can re-apply it immediately.

	Without this, putting on a Power Armour suit would not change your height
	until the next spawn - and taking it off would leave you tall.
]]
-- Created here rather than assumed: the table is set up in the `cl_` files,
-- which never run on the server.
ix.fallout = ix.fallout or {}
ix.fallout.ApplyProportions = ApplyProportions

function Schema:PlayerLoadout(client)
	-- Runs after Helix has set the character's model, so the check above sees
	-- the real model rather than whatever they spawned with.
	timer.Simple(0, function()
		ApplyProportions(client)
	end)
end

function Schema:PlayerSpawn(client)
	timer.Simple(0, function()
		ApplyProportions(client)
	end)
end

--[[
	Weapon raise/lower moved from R to F.

	Helix binds it to IN_RELOAD (gamemode/core/hooks/sv_hooks.lua:115): hold R
	for weaponRaiseTime and the weapon toggles. That collides badly with any
	weapon that also wants R - reloading a gun starts a raise timer, and the
	Melee Arts weapons behave oddly because the raise fires mid-swing.

	I checked whether Phoenix rebound it: their binding would have lived in
	NutScript's sv_hooks, which is server-only and therefore absent from every
	scrape. So there's nothing to copy and F is our own choice, per your call.

	F is the flashlight key, which isn't an IN_ enum - it arrives as
	PlayerSwitchFlashlight. Blocking that is fine: Phoenix made the flashlight
	an inventory item (their "flashlight" plugin) rather than a keybind.
]]

-- Swallow IN_RELOAD before Helix sees it. Returning non-nil from a Schema hook
-- stops GM:KeyPress running - but ONLY for reload, so IN_USE (doors, entity
-- interaction) still works normally.
function Schema:KeyPress(client, key)
	if key == IN_RELOAD then
		return true
	end
end

function Schema:KeyRelease(client, key)
	if key == IN_RELOAD then
		-- Clear any timer Helix may have started before this took effect.
		timer.Remove("ixToggleRaise" .. client:SteamID())
		return true
	end
end

-- Phoenix made the flashlight an inventory item (their "flashlight" plugin)
-- rather than a keybind, so the engine flashlight stays off regardless of what
-- the player has bound.
function Schema:PlayerSwitchFlashlight(client, enabled)
	return false
end

--[[
	The raise itself.

	Bound with `bind f fo_toggleraise` - a console command rather than a hook,
	so the key isn't baked in and the player can move it.

	Two earlier attempts are worth not repeating:

	  * PlayerSwitchFlashlight never ran. GMod only fires that hook if the
	    player is permitted a flashlight, and Helix never calls
	    AllowFlashlight. F did nothing AND R was already swallowed, so there
	    was no way to raise a weapon at all.
	  * PlayerBindPress on "impulse 100" did work, but it duplicated this and
	    hijacked whatever the flashlight bind happened to be. Removed.
]]
concommand.Add("fo_toggleraise", function(client)
	if not IsValid(client) or not client:Alive() then
		return
	end

	-- Console commands are client-triggered and spammable, so rate limit.
	if (client.ixNextRaiseToggle or 0) > CurTime() then
		return
	end

	client.ixNextRaiseToggle = CurTime() + 0.2

	if IsValid(client:GetActiveWeapon()) then
		client:ToggleWepRaised()
	end
end)

--[[
	Model and race can both change without a respawn.

	`race` matters more than `model` here: `/charsetrace` sets the race and the
	model follows from it, so listening for the model alone would apply the old
	race's hull to the new race's body.
]]
function Schema:CharacterVarChanged(character, key, oldValue, value)
	if (key ~= "model" and key ~= "race") then
		return
	end

	local client = character:GetPlayer()

	if IsValid(client) then
		timer.Simple(0, function()
			ApplyProportions(client)
		end)
	end
end
