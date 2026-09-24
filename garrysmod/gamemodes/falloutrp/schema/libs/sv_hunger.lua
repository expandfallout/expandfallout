--[[
	Hunger and thirst - the server half.

	The setters and the drain loop. `applyHunger` and `applyThirst` were in
	their `sv_plugin.lua`, which no scrape contains, so what those did is
	reconstructed from what the tier tables declare: SPECIAL modifiers, and an
	`hpRegen` on the top hunger tier.

	WHERE THE MODIFIERS LAND. Nowhere here. The SPECIAL changes are read in
	`ix.special.Get`, the single point every consumer already goes through -
	the same arrangement radiation uses, and for the same reason: applying them
	at the point they change would mean finding every reader.

	What this file does apply is the health regeneration, because that is a
	thing that happens over time rather than a value someone reads.
]]

if (not SERVER) then return end

util.AddNetworkString("ixAlcoholEffect")

local characterMeta = ix.meta.character

--[[
	Both setters clamp. Food that would take you past full is not wasted
	silently - it simply tops you up, which is what a player expects.
]]
function characterMeta:SetHunger(value)
	self:SetData("hunger", math.Clamp(math.Round(value or 0, 3), 0, 100))
end

function characterMeta:SetThirst(value)
	self:SetData("thirst", math.Clamp(math.Round(value or 0, 3), 0, 100))
end

function characterMeta:AddHunger(value)
	self:SetHunger(self:GetHunger() + (value or 0))
end

function characterMeta:AddThirst(value)
	self:SetThirst(self:GetThirst() + (value or 0))
end

--[[
	Re-apply what the meters currently do.

	Only speed is pushed here, and only because the Agility modifier from
	thirst feeds it - `ix.special.Apply` reads the attribute, and the attribute
	is where the modifier is applied. Without this the tier change would not
	take hold until the next spawn.
]]
function characterMeta:ApplyHungerThirst()
	local client = self:GetPlayer()

	if (not IsValid(client)) then return end

	if (ix.special and ix.special.Apply) then
		ix.special.Apply(client)
	end
end

--[[
	The drain loop.

	One timer for everyone rather than a think per player. The rate depends on
	what you are doing, and the three cases are theirs:

	    running -> hungerDrainRunning     (0.03)
	    moving  -> hungerDrainMoving      (0.02)
	    still   -> hungerDrainIdle        (0.01)

	`IsSprinting` rather than a speed comparison, because armour and a dead
	fusion core both change what "fast" means - a player pinned to walk speed
	in an unpowered suit is still working hard.
]]
local function Drain(client, character)
	local moving = client:GetVelocity():Length2D() > 5
	local running = moving and client:IsSprinting()

	local hunger, thirst

	if (running) then
		hunger = ix.config.Get("hungerDrainRunning", 0.03)
		thirst = ix.config.Get("thirstDrainRunning", 0.03)
	elseif (moving) then
		hunger = ix.config.Get("hungerDrainMoving", 0.02)
		thirst = ix.config.Get("thirstDrainMoving", 0.02)
	else
		hunger = ix.config.Get("hungerDrainIdle", 0.01)
		thirst = ix.config.Get("thirstDrainIdle", 0.01)
	end

	local beforeHunger = ix.hunger.GetHungerTier(character:GetHunger())
	local beforeThirst = ix.hunger.GetThirstTier(character:GetThirst())

	character:AddHunger(-hunger)
	character:AddThirst(-thirst)

	local afterHunger = ix.hunger.GetHungerTier(character:GetHunger())
	local afterThirst = ix.hunger.GetThirstTier(character:GetThirst())

	--[[
		Only re-applied and announced when a tier actually CHANGES.

		The meters move every single tick, so reacting to the value would mean
		recomputing speed and spamming notifications once a second forever.
		The tier is the thing that matters and it changes rarely.
	]]
	if (afterHunger ~= beforeHunger or afterThirst ~= beforeThirst) then
		character:ApplyHungerThirst()

		if (afterHunger ~= beforeHunger) then
			client:NotifyLocalized("hungerTier", afterHunger.name)
		end

		if (afterThirst ~= beforeThirst) then
			client:NotifyLocalized("thirstTier", afterThirst.name)
		end
	end

	--[[
		Being well fed heals you, slowly. `hpRegen` is declared on the top
		hunger tier only, and is applied per tick rather than per second, so it
		follows the tick rate rather than drifting from it.
	]]
	local regen = afterHunger.hpRegen

	if (regen and regen > 0 and client:Health() < client:GetMaxHealth()) then
		client:SetHealth(math.min(client:Health() + regen, client:GetMaxHealth()))
	end
end

local nextTick = 0

hook.Add("Think", "ixHungerThirst", function()
	if (CurTime() < nextTick) then return end

	nextTick = CurTime() + ix.config.Get("hungerTickRate", 1)

	for _, client in ipairs(player.GetAll()) do
		if (not IsValid(client) or not client:Alive()) then continue end

		--[[
			Test bots are skipped. They exist to be shot at, and a target that
			slowly starves to death on its own is a target that changes what it
			is measuring.
		]]
		if (client.ixDummyBot) then continue end

		local character = client:GetCharacter()

		if (not character or not ix.hunger.HasHunger(character)) then continue end

		Drain(client, character)
	end
end)

--[[
	Fed and watered on a new character.

	`GetHunger` defaults to 100, so this is only about being explicit: without
	it a character's first save writes nothing, and anything reading the raw
	data rather than the getter sees nil.
]]
hook.Add("OnCharacterCreated", "ixHungerThirst", function(client, character)
	character:SetHunger(100)
	character:SetThirst(100)
end)

--[[
	The commands for this library live in `sh_commands.lua`.
	They have to be declared on both realms or the chatbox cannot
	see them - see the header there.
]]
