--[[
	What a body says when you look at it.

	`ix.corpse` IS DECLARED HERE TOO - `libs/` is included alphabetically and
	every `cl_` file runs before every `sh_` one, so this loads before
	`sh_corpse.lua` (gotcha 26).

	THE HOOK RATHER THAN THE ENTITY. A corpse is a plain `prop_ragdoll` - it
	has to be, because `CreateServerRagdoll` is what copies the model, the
	bodygroups and the death pose - so there is no `ENT:OnPopulateEntityInfo`
	to write. Helix falls back to `hook.Run("PopulateEntityInfo", entity, panel)`
	for exactly this case; see `core/derma/cl_tooltip.lua`.
]]

if (not CLIENT) then return end

ix.corpse = ix.corpse or {}

--------------------------------------------------------------------------------
-- Giving a body something to look like
--------------------------------------------------------------------------------

--[[
	A CORPSE IS INVISIBLE UNTIL SOMETHING DRAWS IT, and that is this file's job
	rather than a fault in the corpse.

	`models/phoenix/humans/animations.mdl` has no visible mesh - it is an
	animation carrier, and every character in this schema wears one. The
	visible person is COMPOSED at render time from meshes bone-merged onto that
	skeleton (`cl_bodyparts.lua`). A ragdoll of a player therefore inherits the
	skeleton, the physics and the death pose, and draws absolutely nothing.

	Which is exactly what "no body appears when you kill people" was, all the
	way through: `fo_corpse` listed two bodies with positions while the screen
	showed empty floor.

	The parts are built by `ix.fallout.BuildRecipe`, from the same list that
	dresses a living player, so a corpse is dressed in the same armour and
	wears the same face - and a bone scaled to nothing by a dismemberment takes
	the merged mesh with it, so a headless corpse is headless for free.
]]
local rendered = {}

local function Clear(corpse)
	for _, part in ipairs(rendered[corpse] or {}) do
		if (IsValid(part)) then part:Remove() end
	end

	rendered[corpse] = nil
end

--[[
	The parts this file made for a body.

	`cl_dismember.lua` needs them to scale a limb away on each one, and asking
	the engine for a ragdoll's children does not reliably include clientside
	models parented to it - which is a hand left floating where an arm was.
]]
function ix.corpse.Parts(corpse)
	return rendered[corpse] or {}
end

--[[
	WHAT A BODY LOOKS LIKE IS THE SERVER'S TO SAY.

	The first version looked the character up in `ix.char.loaded` and built
	from it, falling back to the human default body when it was not there.
	That fallback is what put pink human arms on a dead gecko, and a human
	head - with a `Bip01 Spine2` the super mutant skeleton does not have - on
	a dead super mutant, where the unmatched bone sat sixty units from the
	corpse's origin and drew as a spike out of the neck. A bot's character, or
	a player's after they leave, is exactly the case where the lookup fails.

	So the server composes the part list at death, from the same
	`ix.fallout.Recipe` a living player is drawn from, and sends it with the
	body. A client that finds a body it has no recipe for - it was out of
	range, or arrived later - asks for it rather than guessing, and until the
	answer comes the body draws nothing.
]]
local recipes = {}
local pending = {}

local function Build(corpse)
	Clear(corpse)

	local recipe = recipes[corpse]

	if (not recipe) then return false end

	rendered[corpse] = ix.fallout.BuildRecipe(corpse, recipe, true)

	--[[
		THE CARRIER IS LEFT DRAWN, and a version of this hid it.

		`animations.mdl` does have a mesh - 385 KB of vertex data - but its
		bodygroup defaults to the blank option, so it draws nothing. A probe on
		a Phoenix corpse reads `nodraw false` and `bodygroups 0:model=0/2`:
		they leave it alone, and so does this. A creature's carrier IS the
		body, and the recipe leaves out any part that would draw it twice.

		NOTHING IS RE-APPLIED HERE either. A body built late gets its
		collapsed limbs from the `manipulate_bone` entity the server parented
		to it, the same way a body built on time does.
	]]

	return true
end

--- Once per body every two seconds at most; the answer is an `ixCorpseNew`.
local function Ask(corpse)
	if ((corpse.ixCorpseAsked or 0) > CurTime()) then return end

	corpse.ixCorpseAsked = CurTime() + 2

	net.Start("ixCorpseAsk")
		net.WriteUInt(corpse:EntIndex(), 13)
	net.SendToServer()
end

--[[
	THE SERVER SAYS SO, and the poll below is only the safety net.

	A body found by a half-second poll is a body that appears up to half a
	second after the person did, which reads as the corpse lagging behind the
	death. This arrives with it.

	The retry is because the entity may not have reached this client yet when
	the message does, and its network variables land a moment after the
	entity itself. The recipe waits under the index until then.
]]
local function Arrive(index, attempt)
	local corpse = Entity(index)

	if (IsValid(corpse) and corpse:GetNWString("ixCorpseLabel", "") ~= "") then
		recipes[corpse] = pending[index] or recipes[corpse]
		pending[index] = nil

		Build(corpse)

		return
	end

	if (attempt > 8) then
		pending[index] = nil

		return
	end

	timer.Simple(0.1, function() Arrive(index, attempt + 1) end)
end

net.Receive("ixCorpseNew", function()
	local index = net.ReadUInt(13)

	pending[index] = net.ReadTable()

	Arrive(index, 1)
end)

--[[
	Every half second, not every frame.

	There is no client event for "a ragdoll finished arriving with its network
	variables set" - `NetworkEntityCreated` fires before they land, so a corpse
	built from it has no label. A poll is the honest answer and it is cheap:
	this looks at ragdolls, of which there are at most `corpseMax`.
]]
timer.Create("ixCorpseBodies", 0.5, 0, function()
	for corpse in pairs(rendered) do
		if (not IsValid(corpse)) then Clear(corpse) end
	end

	for _, corpse in ipairs(ents.FindByClass("prop_ragdoll")) do
		if (corpse:GetNWString("ixCorpseLabel", "") == "") then continue end
		if (rendered[corpse]) then continue end

		if (recipes[corpse]) then
			Build(corpse)
		else
			Ask(corpse)
		end
	end
end)

--- Parts are entities of ours; a corpse removed must not leave them behind.
hook.Add("EntityRemoved", "ixCorpse", function(entity)
	if (rendered[entity]) then Clear(entity) end

	recipes[entity] = nil
end)

--------------------------------------------------------------------------------
-- What it says
--------------------------------------------------------------------------------

hook.Add("PopulateEntityInfo", "ixCorpse", function(entity, container)
	--[[
		`ixCorpse` IS A SERVER FIELD and does not exist here, so the net var is
		what identifies one. A ragdoll with no label is a prop somebody spawned
		and has nothing to say.
	]]
	local label = entity:GetNWString("ixCorpseLabel", "")

	if (label == "") then return end

	local title = container:AddRow("name")

	title:SetImportant()
	title:SetText("Body")
	title:SizeToContents()

	local who = container:AddRow("corpse")

	--[[
		A PERMANENTLY KILLED BODY SAYS WHOSE IT IS, and it is the only kind
		that does.

		Every other corpse is deliberately anonymous - a faction and a rank,
		never a name - because a head that identifies its owner is evidence
		rather than a message. This one is the exception on purpose: the named
		head is the trophy for a permanent kill, and a trophy nobody can find
		is not a trophy. Their friends knowing where to look is the point.
	]]
	local named = entity:GetNWString("ixCorpsePK", "")

	who:SetText(named ~= "" and (named .. "  (" .. label .. ")") or label)
	who:SizeToContents()

	--[[
		AND WHETHER THERE IS ANYTHING LEFT TO TAKE, which is the only thing
		worth walking over for. A body whose head is gone says so rather than
		letting somebody hold E on it for three seconds to find out.
	]]
	local action = container:AddRow("corpseAction")

	if (entity:GetNWBool("ixCorpseRobot", false)) then
		action:SetText("Nothing to take from a machine.")
	elseif (entity:GetNWBool("ixCorpseHeadless", false)) then
		action:SetText("The head is gone.")
	else
		action:SetText("Hold E to take the head.")
		action:SetBackgroundColor(ix.config.Get("color"))
	end

	action:SizeToContents()
end)
