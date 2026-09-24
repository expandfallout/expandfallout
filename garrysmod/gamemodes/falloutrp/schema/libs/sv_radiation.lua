--[[
	Radiation - the server half.

	`addRadiation` is ported line for line from their `sh_plugin.lua`, which
	the scrape did capture. `applyRadiationDebuffs` was NOT captured - it lived
	in `sv_plugin.lua`, and glua-steal never retrieves server files - so it is
	reconstructed from what the debuff table declares and what the rest of
	their code assumes of it.

	WHERE THE PENALTIES LAND

	`health` reduces MAXIMUM health, and is recomputed from the race's base
	rather than subtracted from the current maximum. Subtracting would compound
	every time the tier was reapplied, and a player who crossed 80 rads twice
	would end up with less health than one who crossed it once.

	`special` penalties are not applied here at all. They are read in
	`ix.special.Get`, which is the single point every consumer already goes
	through - applying them anywhere else would mean chasing down each caller.
]]

if (not SERVER) then return end

util.AddNetworkString("ixRadiation:Update")

local characterMeta = ix.meta.character

function characterMeta:SetRadiation(amount)
	if (not amount or amount < 0) then
		amount = 0
	end

	self:SetData("radiation", amount)
end

--[[
	THE ONE PLACE MAXIMUM HEALTH IS DECIDED.

	Renamed from `ApplyBodyState` when chems arrived, because it stopped
	being about radiation. It sets max health ABSOLUTELY from every source at
	once - the race's base, the radiation tier, and any `HP` buff - and that is
	the only way this can work: a second writer would win or lose depending on
	which ran last, and a Buffout wearing off would restore a ceiling that
	ignored the player's rads.

	The same reasoning `ix.special.Apply` carries for movement speed. One
	function decides, everything else asks it to run again.

	Only maximum health is set here; see the header for why the SPECIAL
	penalties are not.
]]
function characterMeta:ApplyBodyState()
	local client = self:GetPlayer()

	if (not IsValid(client)) then return end

	local tier = ix.radiation.GetTier(self:GetRadiation())
	local base = ix.races and ix.races.GetBaseHealth(self:GetRace()) or 100
	local buffed = ix.buff and ix.buff.Get(client, "HP") or 0
	local maximum = math.max(base + (tier.health or 0) + buffed, 1)

	client:SetMaxHealth(maximum)

	--[[
		Current health follows the ceiling down, or a player at full health
		who crosses 80 rads would sit above their own maximum - which reads as
		a bug and, in some HUDs, draws a bar past its end.
	]]
	if (client:Health() > maximum) then
		client:SetHealth(maximum)
	end

	--[[
		Speed is recomputed because the Agility penalty feeds it. Without this
		the debuff would not take hold until the next spawn or attribute
		change.
	]]
	if (ix.special and ix.special.Apply) then
		ix.special.Apply(client)
	end
end

--[[
	Take on radiation. Ported exactly, including the parts that look odd:

	- the gate is `positive and not (takesRad or isCloud)`, so a rad CLOUD
	  irradiates something otherwise immune
	- `isCloud` also bypasses resistance entirely - your gear does not help
	- `math.ceil` after resistance means anything that survives is at least
	  1 rad, so even 90% resistance only slows exposure
	- the damage test uses the UNCLAMPED sum, so once you are at 100 every
	  further point of exposure hurts you again
	- negative amounts (radaway) skip both the resistance maths and the
	  network update
]]
function characterMeta:AddRadiation(amount, bCloud)
	if (not amount or amount == 0) then return end

	local current = self:GetRadiation()
	local bPositive = amount > 0

	if (bPositive and not (self:TakesRadiation() or bCloud)) then return end

	if (not bCloud and bPositive) then
		local resistance = self:GetRadiationResistance()

		amount = math.ceil(amount * (1 - resistance / 100))
	end

	if (amount == 0) then return end

	local total = current + amount

	self:SetRadiation(math.Clamp(total, 0, 100))

	if (total >= 100) then
		local client = self:GetPlayer()

		if (IsValid(client) and client:Alive()) then
			client:TakeDamage(client:GetMaxHealth() * 0.10,
				game.GetWorld(), game.GetWorld())
		end
	end

	self:ApplyBodyState()

	if (amount < 0) then return end

	local client = self:GetPlayer()

	if (IsValid(client)) then
		net.Start("ixRadiation:Update")
			net.WriteFloat(amount)
		net.Send(client)
	end
end

--[[
	Reapplied on spawn and on character load, because maximum health is set by
	the gamemode on both and would otherwise come back at the race's base with
	the radiation penalty quietly dropped.
]]
local function Reapply(client)
	timer.Simple(0, function()
		if (not IsValid(client)) then return end

		local character = client:GetCharacter()

		if (character) then
			character:ApplyBodyState()
		end
	end)
end

hook.Add("PostPlayerLoadout", "ixRadiationApply", Reapply)
hook.Add("PlayerLoadedCharacter", "ixRadiationApply", Reapply)

--[[
	Admin command.

	There is no radiation SOURCE yet - Phoenix's came from their `areas`
	plugin's trigger volumes and from consumables, neither of which is ported.
	Without a way to hand out rads the whole system is unreachable and
	untestable, so this exists to reach it.
]]

--[[
	The commands for this library live in `sh_commands.lua`.
	They have to be declared on both realms or the chatbox cannot
	see them - see the header there.
]]

--[[
	APPLIED BEFORE THE LOADOUT SETS HEALTH. Helix's `GM:PlayerLoadout` sets a
	spawning player's health to their saved value or to their MAXIMUM - and
	the maximum, on a freshly spawned player entity, is the engine's 100
	until `ApplyBodyState` has run. Nothing ran it at spawn, so a securitron
	with five hundred hit points spawned with a hundred of them and only the
	ceiling said otherwise. `hook.Add` listeners run before the gamemode's
	own method, so this sets the ceiling first and Helix fills to it.
]]
hook.Add("PlayerLoadout", "ixBodyState", function(client)
	local character = client:GetCharacter()

	if (character and character.ApplyBodyState) then
		character:ApplyBodyState()
	end
end)
