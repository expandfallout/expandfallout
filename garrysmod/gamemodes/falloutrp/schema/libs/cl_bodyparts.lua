--[[
	Player body rendering.

	Why this exists: models/phoenix/humans/animations.mdl carries the 301 New
	Vegas sequences, and a race that uses it has no body of its own to show.

	IT DOES HAVE A MESH, though this file said for a long time that it did not.
	`animations.vvd` is 385 KB - a whole human body. It is invisible in
	practice because the parts merged onto it are the same body in the same
	place, so it is hidden INSIDE them rather than absent - and the difference
	matters the moment anything moves its bones. See `cl_corpse.lua`, where a
	dismemberment made it visible for eight rounds of debugging.

	That's deliberate on Phoenix's part, not a broken asset. Their human race
	declares:

	    RACE.animationModel = "models/phoenix/humans/animations.mdl"
	    RACE.hideBody       = true
	    RACE.defaultModels  = { male = ".../male/defaultbody.mdl", ... }
	    RACE.heads / hairs / beards / skins / faceSkins = ...

	The visible character is COMPOSED at render time from separate meshes
	bone-merged onto that skeleton, which is also how armour replaces body
	parts (ITEM.bodyType, ITEM.takesBody) without needing a model per
	combination.

	The part list now comes from `ix.races` and the character's own appearance
	vars rather than the hardcoded human male pair this started as, and it is
	composed in `sh_bodyparts.lua` so the server can compose it too - a body
	is drawn from a recipe the server sent, not from a character this client
	may never have had. This file only builds the entities.
]]

ix.fallout = ix.fallout or {}

--[[
	Set a part's skin, but only to one it actually has.

	Ethnicity is a skin index 0-4 on the shared BODY mesh. The head is a
	separate model and does not necessarily carry the same five - Phoenix
	varies the head by ethnicity through facemap SUBMATERIALS (`RACE.faceSkins`)
	rather than through skins, so a head may well have exactly one.

	`SetSkin` past the end of a model's skin family is not a no-op in the
	engine; it is a documented way to get corrupt rendering and, on some
	models, to take the client down. Bounds-checked rather than trusted.
]]
function ix.fallout.ApplyPartSkin(part, skin)
	if (not IsValid(part) or not skin or skin <= 0) then return end

	local count = part.SkinCount and part:SkinCount() or 0

	if (skin < count) then
		part:SetSkin(skin)
	end
end

--[[
	THE ANIMATION MODEL IS PER RACE, NOT ONE CONSTANT.

	This file was written when `human` was the only race, so it compared every
	player's model against the human carrier and built parts only for a match.
	With forty-four races that is a test almost nobody passes: a super mutant's
	model is `models/fallout/supermutant.mdl`, the comparison failed, no parts
	were built at all, and what you saw was the bare animation carrier - a body
	with no head and no hair, which is exactly how it looked.

	`RaceAnimationModel` asks the character's own race instead, and falls back
	to the human one for a character created before races existed.
]]
local ANIMATION_MODEL = ix.fallout.animationModel

--[[
	Is this model ANY race's animation carrier?

	The preview panels need the same answer as the world does, and asking "is it
	the human one" was the bug in both places. Published on `ix.fallout` so
	there is one definition rather than two that drift.
]]
function ix.fallout.IsAnimationModel(model)
	model = string.lower(model or "")

	if (model == ANIMATION_MODEL) then return true end

	for _, race in pairs(ix.races and ix.races.list or {}) do
		if (race.animationModel and string.lower(race.animationModel) == model) then
			return true
		end
	end

	return false
end

local function RaceAnimationModel(character)
	local race = character and ix.races and ix.races.GetCharacterRace(character)

	return string.lower(race and race.animationModel or ANIMATION_MODEL)
end

-- [player] = { clientside models }
local rendered = {}

-- What each player was last built from, so a rebuild happens on change rather
-- than every poll.
local signatures = {}

local function ClearBody(client)
	local parts = rendered[client]

	if not parts then return end

	for _, part in ipairs(parts) do
		if IsValid(part) then part:Remove() end
	end

	rendered[client] = nil
	signatures[client] = nil
end

--[[
	A short string identifying the exact set of parts.

	Appearance can change without the model changing - the model is the same
	animation skeleton for every human - so there is nothing on the entity to
	compare. This is what makes "did anything change?" answerable.
]]
local function Signature(character)
	if (not character) then return "none" end

	local signature = {
		character:GetRace(),
		character:GetGender(),
		character:GetEthnicity(),
		character:GetHair(),
		character:GetBeard(),
		character:GetHairColor()
	}

	--[[
		Armour belongs in the signature, or equipping something would not
		rebuild the body: the player model never changes here - it is the same
		animation skeleton throughout - so a change in what is WORN is
		invisible unless it is named.
	]]
	local client = character:GetPlayer()

	if (IsValid(client) and ix.armor) then
		for _, slot in ipairs(ix.armor.slots) do
			signature[#signature + 1] = client:GetNW2String("ixArmor_" .. slot, "")
		end
	end

	return table.concat(signature, "/")
end

--[[
	Compose a body onto ANYTHING that wears this skeleton.

	Pulled out of `BuildBody` because a CORPSE needs exactly the same thing: a
	dead player is a `prop_ragdoll` wearing `animations.mdl`, which has no
	visible mesh either, so a body left lying about was a set of physics with
	nothing to draw. That is not a dismemberment bug and it is not a corpse
	bug - it is this file's contract, and the corpse simply was not a client of
	it yet. See `cl_corpse.lua`.

	`entity` is a player or a ragdoll; `character` may be nil, in which case
	`GetBodyParts` answers with the default body rather than nothing - a body
	whose owner has logged off is still a body.
]]
--[[
	How a part draws, and this is Phoenix's `nut.armor.render` line for line.

	THE T-POSE ON JUMPING CAME FROM NOT HAVING THIS. `EF_BONEMERGE_FASTCULL`
	stops the child setting up the parent's bones every frame - that is what
	"fast" means - and `EF_PARENT_ANIMATES` only tells it to assume the parent
	is animating. Neither makes the part's own bones current before it is
	drawn by the engine's default path. So on a frame where the parent switched
	sequence - a jump - the merged mesh drew against stale bone matrices and
	came out at reference pose for a frame or two.

	Drawing the part OURSELVES from a render override forces `SetupBones` on
	the part, and with `EF_PARENT_ANIMATES` set that sets up the parent too,
	every frame the part is on screen. Phoenix assign this to every living
	player's part in `nut.armor:setupModel`; this schema had the three flags
	and not the draw, which is half of their contract again.

	The parent checks are theirs as well: a part of somebody dormant, hidden or
	noclipping is not drawn, because a body floating where an admin is
	invisibly standing is worse than no body.
]]
--- Not assigned at present; see `BuildParts` for why. Kept for the day it is.
function ix.fallout.RenderPart(part)
	local parent = part:GetParent()

	if (not IsValid(parent) or parent:IsDormant() or parent:GetNoDraw()) then
		return
	end

	if (parent:IsPlayer() and parent:GetMoveType() == MOVETYPE_NOCLIP
	and not parent:InVehicle()) then
		return
	end

	part:DrawModel()
end

--[[
	`bCorpse` chooses between two contracts, both read off Phoenix's client.

	    a living player   EF_BONEMERGE, and nothing else
	    a corpse          EF_BONEMERGE | EF_BONEMERGE_FASTCULL |
	                      EF_PARENT_ANIMATES, then Spawn()

	Living players had the corpse contract for two rounds and T-posed on every
	jump. Phoenix's living parts DO carry all three flags and a render
	override, so something else in this schema's animation path interacts
	with them; until that is found, players keep the contract that has never
	failed. A corpse is the one place the extra flags are required, because
	they are what make the parent's bone scaling reach the merged mesh.

	Neither gets a render override. Phoenix's corpse parts have none; their
	player parts do, and adding one here did not stop the T-pose, so it is not
	the missing piece and it is not kept as one.
]]
function ix.fallout.BuildParts(entity, character, bCorpse)
	return ix.fallout.BuildRecipe(entity, ix.fallout.Recipe(character), bCorpse)
end

--[[
	The same, from a RECIPE rather than a character - see `sh_bodyparts.lua`.

	A living player is drawn from their character, which every client has. A
	body is drawn from a recipe the server composed at the moment of death,
	because the character behind a body is exactly the thing a client may not
	have: a bot's is never loaded here, and a player's leaves with them. The
	old fallback for that case was the human default body, which is what put
	pink arms on a dead gecko and a human head - with a `Bip01 Spine2` the
	super mutant skeleton does not have - on a dead super mutant, where the
	unmatched bone sat sixty units from the corpse's origin and drew as a spike
	out of the neck.
]]
function ix.fallout.BuildRecipe(entity, recipe, bCorpse)
	local parts = {}
	local hairColor = recipe and recipe.hair or color_white

	for _, entry in ipairs(recipe and recipe.parts or {}) do
		-- Tolerate both shapes: the race path yields tables, the no-race
		-- fallback is a plain list of paths.
		local model = istable(entry) and entry.model or entry

		--[[
			A PART WITH NO MODEL IS NOT A PART.

			`ClientsideModel("")` answers with a perfectly valid entity that
			has no model and no bones, and one of those was found parented to
			every corpse - it draws nothing, it is skipped by every bone
			operation, and it exists only to be confusing. An empty string in
			the part list means the appearance var pointed at nothing, which is
			a thing to skip rather than to build.
		]]
		local part = (isstring(model) and model ~= "")
			and ClientsideModel(model, RENDERGROUP_OPAQUE) or nil

		if IsValid(part) then
			--[[
				OURS, AND SAYS SO. The sweep below removes body parts that have
				lost their parent, and it has to be able to tell one from every
				other clientside model in the game - a viewmodel, a preview, a
				prop somebody else made.
			]]
			part.ixBodyPart = true

			part:SetParent(entity)

			--[[
				THREE EFFECTS AND A SPAWN, WHICH IS PHOENIX'S EXACTLY.

				`plugins/armorv2/cl_plugin.lua`, in both the living-player path
				and the ragdoll one:

				    mdlEnt:SetParent(client)
				    mdlEnt:AddEffects(bit.bor(EF_BONEMERGE,
				        EF_BONEMERGE_FASTCULL, EF_PARENT_ANIMATES))
				    mdlEnt:Spawn()

				`EF_BONEMERGE` alone was what this had, and it is only half the
				contract: it merges the SKELETON, so the mesh follows the
				animation. `EF_PARENT_ANIMATES` is what makes the parent's bone
				SETUP drive the child - and a bone manipulation is part of a
				bone setup.

				That is the whole of the dismemberment artifact. Scaling a
				limb's bones on the corpse did not reach the meshes drawn on
				it, so the arm stayed exactly where it was; scaling the meshes
				separately instead applied a second collapse in each mesh's own
				space, and the geometry gathered somewhere off in the air. Six
				rounds went into the two halves of that and the answer was one
				missing flag that Phoenix have had all along.

				`EF_BONEMERGE_FASTCULL` culls the part against the PARENT's
				bounds instead of computing its own, which is theirs too and
				is free.
			]]
			if (bCorpse) then
				part:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL,
					EF_PARENT_ANIMATES))
				part:Spawn()
			else
				part:AddEffects(EF_BONEMERGE)
			end

			part:SetMoveType(MOVETYPE_NONE)
			part:SetNoDraw(false)

			if (istable(entry)) then
				ix.fallout.ApplyPartSkin(part, entry.skin)

				--[[
					Armour bodygroups. Many pieces ship variants on one mesh -
					a helmet with the visor up or down - and the item picks
					which. Bounds are not checked the way skins are because
					`SetBodygroup` clamps on its own; a skin past the end of
					the family does not.
				]]
				for id, value in pairs(entry.bodyGroups or {}) do
					if (isnumber(id)) then
						part:SetBodygroup(id, value)
					end
				end

				--[[
					Hair and beard are untextured meshes tinted at render time,
					which is how one model serves every hair colour.

					The tint needs COLOUR MODULATION rather than an entity
					colour: these textures are dark enough that male hair wants
					roughly five times the modulation to reach the chosen shade,
					and `SetColor` cannot go past white.

					`RenderOverride` is where that goes. The engine calls it in
					place of the entity's normal render, so `DrawModel` inside
					it draws the mesh once and nothing re-enters.

					Do NOT do this from `PostPlayerDraw` instead. These parts are
					PARENTED to the player, so calling `DrawModel` on one from
					inside the player's draw re-enters the player render path,
					fires PostPlayerDraw again, and recurses until GMod cuts it
					off with "We are 10 layers deep, runaway infinite loop?".
				]]
				if (entry.hair) then
					local color = hairColor
					local boost = math.Clamp(entry.boost or 1, 0.1, 16)

					part.ixColor = color
					part.ixBoost = boost

					part.RenderOverride = function(this)
						local parent = this:GetParent()

						--- The same parent checks as `RenderPart`.
						if (not IsValid(parent) or parent:IsDormant()
						or parent:GetNoDraw()) then
							return
						end

						render.SetColorModulation(color.r / 255 * boost,
							color.g / 255 * boost, color.b / 255 * boost)
						this:DrawModel()
						render.SetColorModulation(1, 1, 1)
					end
				end
			end

			parts[#parts + 1] = part
		end
	end

	return parts
end

local function BuildBody(client)
	ClearBody(client)

	local character = client:GetCharacter()

	rendered[client] = ix.fallout.BuildParts(client, character)
	signatures[client] = Signature(character)
end

local function NeedsBody(client)
	if (not IsValid(client) or not client:IsPlayer()) then return false end
	if (not client:Alive() or client:IsDormant()) then return false end

	local character = client:GetCharacter()

	if (not character) then return false end

	--[[
		Still a model comparison, but against THIS character's race. A race
		whose body is its own model - Liberty Prime, with `hideBody = false` -
		has nothing to merge on, and the comparison correctly excludes it
		because its player model is not a carrier.
	]]
	return string.lower(client:GetModel() or "") == RaceAnimationModel(character)
end

-- Rebuild when a player's model changes or they (re)spawn. Polling on a timer
-- rather than a hook because model changes arrive as a networked var with no
-- dedicated clientside event.
timer.Create("ixFalloutBodyParts", 0.5, 0, function()
	for _, client in player.Iterator() do
		local parts = rendered[client]

		if NeedsBody(client) then
			-- Rebuild if we have nothing, if a part got culled, or if the
			-- character's appearance changed under us.
			local ok = parts ~= nil

			if ok then
				for _, part in ipairs(parts) do
					if not IsValid(part) then ok = false break end
				end
			end

			if (ok and signatures[client] ~= Signature(client:GetCharacter())) then
				ok = false
			end

			if not ok then
				BuildBody(client)
			end

			--[[
				HIDDEN WITH THE PLAYER. LVS hides a driver inside an armoured
				car with `SetNoDraw`, and the engine draws these parts on their
				own, so a hidden player's body sat in plain view in the turret.
				The parts follow the player's flag.
			]]
			local hidden = client:GetNoDraw()

			for _, part in ipairs(rendered[client] or {}) do
				if (IsValid(part) and part:GetNoDraw() ~= hidden) then
					part:SetNoDraw(hidden)
				end
			end
		elseif parts then
			ClearBody(client)
		end
	end

	-- Drop entries for players who left.
	for client in pairs(rendered) do
		if not IsValid(client) then
			ClearBody(client)
		end
	end

	ix.fallout.SweepBodyParts()
end)

--[[
	REMOVE BODY PARTS THAT HAVE LOST THEIR BODY.

	A `ClientsideModel` parented to an entity does NOT go when that entity does.
	It is unparented and left exactly where it was, with no bones set up - which
	draws as a flat sliver of skin lying on the ground. Two of those were found
	sitting in the world by `fo_dismember_report`, and they are what every
	screenshot of a "fragment" beside a corpse was.

	The tables above cannot catch these, because a leak is by definition a part
	nothing has a reference to any more: an entry keyed on an entity that has
	been removed, a build that raced a removal, a menu that was closed mid-
	frame. So the world itself is asked instead. `ixBodyPart` is what makes that
	safe - it is only ever set by `BuildParts`, so nothing else in the game is
	touched.

	Clientside entities have an entity index of -1, which is how they are told
	apart from everything the server knows about.
]]
function ix.fallout.SweepBodyParts()
	local removed = 0

	for _, entity in ipairs(ents.GetAll()) do
		if (IsValid(entity) and entity.ixBodyPart
		and entity:EntIndex() == -1 and not IsValid(entity:GetParent())) then
			entity:Remove()

			removed = removed + 1
		end
	end

	return removed
end


hook.Add("EntityRemoved", "ixFalloutBodyParts", function(entity)
	if entity:IsPlayer() then
		ClearBody(entity)
	end
end)

-- Reloading the schema shouldn't leak clientside models.
hook.Add("OnReloaded", "ixFalloutBodyParts", function()
	for client in pairs(rendered) do
		ClearBody(client)
	end
end)

--[[
	STEALTH.

	Phoenix's implementation exactly, from `nut.armor:stealthGlimmer`. It is a
	MATERIAL swap on the body parts, not an alpha fade:

	    moving faster than Stealth Shimmer Velocity -> "cpthazama/cloak"
	    otherwise                                   -> "phoenix/shared/invis"

	`cloak` is a Refract shader, so movement distorts the scene behind you
	rather than tinting you - you are visible as a ripple, which is the point.
	Standing still swaps to `invis` and you disappear outright.

	Two things drop the material entirely, making you fully visible: holding a
	weapon that is not in `ix.armor.validStealthWeapons`, and being in a
	vehicle. Both are theirs.

	Note `Length()`, not `Length2D()` - falling counts as movement here,
	because theirs does.
]]
local STEALTH_CLOAK = "cpthazama/cloak"
local STEALTH_INVIS = "phoenix/shared/invis"

function ix.fallout.GetStealthMaterial(client)
	if (not IsValid(client) or not ix.armor.IsStealthed(client)) then
		return ""
	end

	if (client:InVehicle()) then return "" end

	local weapon = client:GetActiveWeapon()

	if (IsValid(weapon) and ix.armor
	and not ix.armor.validStealthWeapons[weapon:GetClass()]) then
		return ""
	end

	local threshold = ix.config.Get("stealthShimmerVelocity", 5)

	return client:GetVelocity():Length() > threshold
		and STEALTH_CLOAK or STEALTH_INVIS
end

--[[
	Applied per frame rather than on the rebuild path.

	Stealth changes with velocity and with what you are holding, neither of
	which changes the SET of parts - so routing it through the signature would
	either rebuild the whole body every frame you moved, or never update at
	all.

	`SetMaterial` is only called when the value actually changes. It is not
	free, and this runs for every rendered player every frame.
]]
--[[
	EVERY PLAYER, NOT JUST THE ONES WITH A BUILT BODY.

	This iterated `rendered` and it is what left a character permanently
	invisible with no shimmer on it. Cloak, then do anything that drops the
	body - die, respawn, change race, walk far enough away to go dormant - and
	`ClearBody` removes the entry. The player entity keeps the material it was
	last given, this loop no longer visits them to take it off, and nothing
	ever will. The material is not part of the body; it outlives it.

	So the loop is driven by the player list and the material is CLEARED as
	deliberately as it is set. `GetStealthMaterial` returns "" for anybody not
	cloaked, which makes every frame self-healing: whatever went wrong, one
	pass puts it right.
]]
--- Counts passes of the loop below, so `fo_stealth` can say whether it runs.
local thinkPasses = 0

hook.Add("Think", "ixFalloutStealth", function()
	thinkPasses = thinkPasses + 1

	for _, client in player.Iterator() do
		if (not IsValid(client)) then continue end

		local material = ix.fallout.GetStealthMaterial(client)

		--[[
			WHAT WE SET IS REMEMBERED ON THE ENTITY. `GetMaterial()` CANNOT BE
			READ BACK FROM A CLIENTSIDE MODEL, AND THAT WAS THE BUG.

			`Entity:SetMaterial` on a `ClientsideModel` applies the override
			properly - the mesh really does draw with it. `Entity:GetMaterial`
			does NOT read that back: it returns the networked material field,
			which only the server writes, and for a clientside entity nothing
			ever does. It answers "" for ever.

			So the guard `part:GetMaterial() ~= material` was:

			    cloaking    "" ~= "phoenix/shared/invis"  ->  true, applied
			    uncloaking  "" ~= ""                      ->  FALSE, no clear

			Cloaking worked, uncloaking silently did nothing, and the player
			stayed invisible with every other piece of state correctly saying
			they were not cloaked. It is also why four rounds of diagnostics
			reported the materials as already empty - they were reading the
			same lie - and why `fo_unstealth_client` fixed it: it set the
			material unconditionally.

			A Lua field is the truth instead. It is ours, it is written where
			the material is written, and a freshly built part has none - so a
			body rebuilt while cloaked gets the material on the next pass
			rather than being assumed to have it.
		]]
		if (client.ixStealthMaterial ~= material) then
			client.ixStealthMaterial = material

			--[[
				THE CARRIER GETS IT TOO, not just the parts merged onto it. The
				human carrier has no mesh that renders, so cloaking only the
				parts looked right - but a creature race's carrier is a real
				model, and cloaking the merged body while leaving the player
				opaque would hide the clothes and not the mutant.
			]]
			client:SetMaterial(material)
		end

		for _, part in ipairs(rendered[client] or {}) do
			if (IsValid(part) and part.ixStealthMaterial ~= material) then
				part.ixStealthMaterial = material

				part:SetMaterial(material)
			end
		end
	end
end)

--[[
	`PlayerSpawn` is a SERVER hook and never fired here, so the clear it was
	supposed to do never happened. Removed rather than moved: the loop above
	reapplies from a tracked field that a respawn does not touch, so there is
	nothing left for it to fix.
]]

--[[
	The bind.

	Phoenix register this as a settings-menu bind pointing at a `toggleStealth`
	concommand. Helix has no equivalent bind registry, so the concommand is
	what is offered and the player binds it themselves:

	    bind x toggleStealth

	Named exactly as theirs so anyone coming from that server can reuse the
	binds they already have.
]]
concommand.Add("toggleStealth", function()
	net.Start("ixArmorStealthToggle")
	net.SendToServer()
end)

--[[
	The client half of `fo_stealth`. See `sv_armor.lua` for why this exists.

	A separate command name rather than the same one, because a concommand
	registered on both realms runs the client's and never reaches the server.
]]
local function ClientReport()
	local client = LocalPlayer()
	local parts = rendered[client] or {}
	local materials = {}

	for _, part in ipairs(parts) do
		if (IsValid(part)) then
			--[[
				The tracked field, NOT `GetMaterial()` - that always answers ""
				on a clientside model whatever is actually drawn, which is what
				made every earlier report of this useless.
			]]
			materials[#materials + 1] = "'"
				.. tostring(part.ixStealthMaterial or "") .. "'"
		end
	end

	chat.AddText(Color(255, 200, 100), "[client] ",
		Color(255, 255, 255),
		"stealthState=" .. tostring(client:GetNW2Int("ixStealthState", 0))
		.. "  IsStealthed=" .. tostring(ix.armor and ix.armor.IsStealthed(client))
		.. "  wants='" .. tostring(ix.fallout.GetStealthMaterial(client)) .. "'")

	chat.AddText(Color(255, 200, 100), "[client] ",
		Color(255, 255, 255),
		"player material='" .. tostring(client.ixStealthMaterial or "")
		.. "'  model=" .. tostring(client:GetModel())
		.. "  parts=" .. #parts)

	chat.AddText(Color(255, 200, 100), "[client] ",
		Color(255, 255, 255),
		"part materials: "
		.. (#materials > 0 and table.concat(materials, " ") or "none"))

	--[[
		Whether the Think loop is alive at all. Every explanation so far has
		assumed it is; if this number stops climbing, that assumption was the
		bug and nothing downstream of it matters.
	]]
	chat.AddText(Color(255, 200, 100), "[client] ",
		Color(255, 255, 255),
		"stealth think passes since load: " .. tostring(thinkPasses))
end

concommand.Add("fo_stealth_client", ClientReport)

--[[
	The server asks for the client's half so `fo_stealth` is ONE command.

	Two commands meant two pastes and a chance of getting only one, which is
	how this bug survived a round: the diagnostic existed and was never run.
]]
net.Receive("ixStealthReport", ClientReport)

--[[
	The escape hatch. Clears the material off the player and every part
	regardless of what any state says, so somebody stuck invisible can play
	while the cause is still being found.
]]
concommand.Add("fo_unstealth_client", function()
	local client = LocalPlayer()

	client.ixStealthMaterial = nil

	client:SetMaterial("")

	for _, part in ipairs(rendered[client] or {}) do
		if (IsValid(part)) then
			part.ixStealthMaterial = nil

			part:SetMaterial("")
		end
	end

	chat.AddText("Cleared the stealth material locally. If you are still "
		.. "invisible, it was never the material.")
end)
