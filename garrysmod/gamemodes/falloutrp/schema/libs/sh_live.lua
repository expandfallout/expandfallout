--[[
	The live editor: changing the schema's numbers without a restart.

	`/LiveEdit` opens a window onto the things this schema is MADE of - every
	weapon's damage and spread, every armour's resistance, every chem's effect,
	every race's health and speed, every faction's details - and changes them on
	the spot, for everybody, saved.

	WHY AN OVERRIDE STORE RATHER THAN EDITING FILES

	Everything here lives in code: an armour is a Lua file, a race is a Lua
	file, a weapon is a SWEP table from an addon. Editing those from in game
	would mean writing Lua from Lua, and the schema would then have two sources
	of truth that disagree the moment somebody pulls an update.

	So the files stay the files, and this keeps a small table of DIFFERENCES:

	    ix.live.overrides[kind][id][field] = value

	applied over the top on load and whenever one changes. The base value is
	remembered the first time a field is touched, so RESET is exact rather than
	a guess - and a field nobody has edited is not in the store at all, which
	means an update to a weapon pack is picked up normally.

	WHAT A "KIND" IS

	One editable subject - weapons, armour, chems, races, factions - described
	by four things:

	    List     everything of that kind, for the middle column
	    Target   where one subject's fields actually live. A weapon's damage is
	             on the SWEP table; an armour's resistance is on the item table
	    fields   what may be edited, with bounds and a note. The window is BUILT
	             from this, the same way the crosshair menu is built from its
	             settings table - a new field is one line here
	    OnApply  anything that has to happen after a write. Weapons need their
	             live instances updated; a race needs everybody wearing it
	             respawned

	Nothing about the UI is written per kind. See `derma/cl_liveedit.lua`.
]]

ix.live = ix.live or {}

--- `[kind][id][field] = value`. What differs from the files.
ix.live.overrides = ix.live.overrides or {}

--[[
	`[kind][id][field] = value` - what it was BEFORE the first override.

	Captured at the moment a field is first written, on whichever realm is
	doing the writing, and never saved: it is the file's own value, so it comes
	back from the file on the next load. Saving it would mean a stale base
	surviving an update to the thing it describes.
]]
ix.live.base = ix.live.base or {}

--------------------------------------------------------------------------------
-- Reading and writing a field by path
--------------------------------------------------------------------------------

--[[
	`Primary.Damage` is two lookups, not one key.

	Weapon fields live in nested tables and armour fields do not, so every path
	is treated as dotted - a key with no dot in it is a path of one.
]]
--[[
	A TARGET IS A TABLE **OR AN ENTITY**, and the difference cost a fix.

	`istable(weapon)` is FALSE for a weapon somebody is holding: an entity is
	userdata with a metatable, and its fields are reached through `__index` into
	its own table. Guarding the two functions below with `istable` therefore
	made every write to a live weapon a silent no-op that returned false - so
	`weapons.GetStored` got the new damage, every weapon spawned afterwards got
	it, and the rifle in your hands kept the old numbers for ever.

	It errored nowhere and reported nothing, which is why it read as "live
	editing does not work on guns".

	Indexing an entity works exactly as indexing a table does, in both
	directions - `weapon.Primary.Damage = 40` is a normal write into the
	entity's table - so the only thing that had to change is which values are
	allowed through.
]]
local function Indexable(target)
	if (istable(target)) then return true end

	--- A removed weapon is still an entity and indexing one throws outright.
	return isentity(target) and IsValid(target)
end

local function Resolve(target, path, bCreate)
	local parts = string.Explode(".", path)
	local node = target

	for index = 1, #parts - 1 do
		local child = node[parts[index]]

		--- `Primary` on a weapon entity is a plain table, whatever holds it.
		if (not Indexable(child)) then
			--[[
				MADE, WHEN WRITING, IF IT IS NOT THERE.

				Fifty-four of the two hundred weapons in this arsenal have no
				`SWEP.Spread` table of their own - they inherit the whole thing
				from `ls_base` when the entity is made. Refusing to write into a
				table that does not exist yet meant every spread edit on those
				weapons was stored, synced and drawn while doing nothing at all.

				An empty table is the right thing to leave behind: `table.Inherit`
				fills in every key it does not have from the base, and
				`BuildBaseCachedData` falls back to the same numbers again, so
				only the key being written changes.
			]]
			if (not bCreate) then return nil end

			child = {}
			node[parts[index]] = child
		end

		node = child
	end

	return node, parts[#parts]
end

function ix.live.Read(target, path)
	if (not Indexable(target)) then return nil end

	local node, key = Resolve(target, path)

	return node and node[key]
end

function ix.live.Write(target, path, value)
	if (not Indexable(target)) then return false end

	local node, key = Resolve(target, path, true)

	if (not node) then return false end

	node[key] = value

	return true
end

--[[
	The SPECIAL fields a chem gets, built rather than written out.

	`ITEM.buffs` is a LIST of `{stat, value, duration}`, so a chem's Strength
	bonus is not a value at a path - it is an entry that may or may not be in a
	list. Each field below reads and writes that list itself, which is what
	`field.Read` and `field.Write` exist for.

	The stat codes are `ix.buff`'s - the short ones a chem declares - and the
	duration is shared by every buff on one chem, which is true of every chem in
	the roster and of every chem in the games.
]]
function ix.live.BuffFields()
	local stats = {
		{code = "STR", name = "STR while it lasts"},
		{code = "PER", name = "PER while it lasts"},
		{code = "END", name = "END while it lasts"},
		{code = "CHR", name = "CHR while it lasts"},
		{code = "INT", name = "INT while it lasts"},
		{code = "AGL", name = "AGL while it lasts"},
		{code = "LCK", name = "LCK while it lasts"},
		{code = "DR", name = "Damage resistance while it lasts"},
		{code = "SPD", name = "Run speed while it lasts"},
		{code = "RADRES", name = "Rad resistance while it lasts"},

		--[[
			THE THREE THAT ARE NOT SPECIAL, and every one of them is read
			somewhere: DMG by the damage hook, HP by the health cap, STEALTH by
			the detection check. They are here because the question was "what
			does this chem do", and leaving out the three that Psycho, Med-X
			and a Stealth Boy are built from would have answered a different
			one.
		]]
		{code = "DMG", name = "Damage dealt while it lasts"},
		{code = "HP", name = "Maximum health while it lasts"},
		{code = "STEALTH", name = "Stealth while it lasts"}
	}

	local out = {}

	for _, stat in ipairs(stats) do
		out[#out + 1] = {
			key = "buff." .. stat.code,
			name = stat.name,
			kind = "number",
			min = -50, max = 100, decimals = 0, default = 0,
			note = stat.code == "STR"
				and "0 removes the buff entirely. The duration below is shared "
					.. "by every stat on this chem"
				or nil,

			Read = function(target)
				for _, buff in ipairs(target.buffs or {}) do
					if (buff.stat == stat.code) then return buff.value or 0 end
				end

				return 0
			end,

			Write = function(target, value)
				target.buffs = target.buffs or {}

				value = tonumber(value) or 0

				for index, buff in ipairs(target.buffs) do
					if (buff.stat ~= stat.code) then continue end

					--[[
						ZERO REMOVES IT. A buff of nothing still costs the
						chem an entry, still shows in the description and
						still blocks a second dose through `aidID`, so it is
						not the same as not having one.
					]]
					if (value == 0) then
						table.remove(target.buffs, index)
					else
						buff.value = value
					end

					return true
				end

				if (value == 0) then return true end

				--- A new one borrows the duration of whatever is already there.
				local duration = 60

				for _, buff in ipairs(target.buffs) do
					duration = buff.duration or duration

					break
				end

				target.buffs[#target.buffs + 1] = {
					stat = stat.code, value = value, duration = duration
				}

				return true
			end
		}
	end

	--- One duration for the whole chem; see the note above.
	out[#out + 1] = {
		key = "buff.duration",
		name = "Seconds the buffs last",
		kind = "number",
		min = 0, max = 7200, decimals = 0, default = 60,
		note = "0 makes them permanent until death, which is what an implant "
			.. "is",

		Read = function(target)
			for _, buff in ipairs(target.buffs or {}) do
				return buff.duration or 0
			end

			return 0
		end,

		Write = function(target, value)
			for _, buff in ipairs(target.buffs or {}) do
				buff.duration = math.max(tonumber(value) or 0, 0)
			end

			return true
		end
	}

	return out
end

--------------------------------------------------------------------------------
-- The kinds
--------------------------------------------------------------------------------

--- `[id] = kind`, filled by `ix.live.Register` below.
ix.live.kinds = ix.live.kinds or {}
ix.live.order = ix.live.order or {}

function ix.live.Register(kind)
	ix.live.kinds[kind.id] = kind

	if (not table.HasValue(ix.live.order, kind.id)) then
		ix.live.order[#ix.live.order + 1] = kind.id
	end
end

function ix.live.Kind(id)
	return ix.live.kinds[id]
end

--[[
	THE FIELDS FOR ONE SUBJECT.

	Almost every kind has the same fields for everything in it - a rifle and a
	pistol are both weapons and both have a damage - so `kind.fields` is
	normally just a list.

	SPECIAL is the exception, and it is the reason this exists: its subjects
	are the seven attributes, and Endurance's settings have nothing to do with
	Luck's. A kind may therefore give a FUNCTION of the subject instead, and
	everything that walks a kind's fields comes through here rather than
	touching `kind.fields` directly.
]]
function ix.live.Fields(kind, id)
	if (not kind) then return {} end

	if (isfunction(kind.fields)) then return kind.fields(id) or {} end

	return kind.fields or {}
end

--- One field by key, or nil. The lookup four separate places were repeating.
function ix.live.Field(kind, id, key)
	for _, entry in ipairs(ix.live.Fields(kind, id)) do
		if (entry.key == key) then return entry end
	end
end

--- Every kind in the order they were registered, for the left column.
function ix.live.Sections()
	local out = {}

	for _, id in ipairs(ix.live.order) do
		if (ix.live.kinds[id]) then out[#out + 1] = ix.live.kinds[id] end
	end

	return out
end

--------------------------------------------------------------------------------
-- Applying
--------------------------------------------------------------------------------

--[[
	Clean one value for one field, or nil when it cannot be used.

	The same job `ix.crosshair.Clean` does and for the same reason: the value
	arrives from a window, and a number field that accepted "12a" would store a
	string into a table something else multiplies by.
]]
function ix.live.Clean(field, value)
	if (not field) then return nil end

	if (field.kind == "bool") then
		return value and true or false
	elseif (field.kind == "number") then
		local number = tonumber(value)

		if (not number) then return nil end

		if (field.decimals == 0) then number = math.Round(number) end

		return math.Clamp(number, field.min or -100000, field.max or 100000)
	elseif (field.kind == "vector" or field.kind == "colour"
	or field.kind == "angle") then
		if (not istable(value)) then return nil end

		return {
			tonumber(value[1]) or 0,
			tonumber(value[2]) or 0,
			tonumber(value[3]) or 0
		}
	elseif (field.kind == "choice") then
		for _, choice in ipairs(field.choices and field.choices() or {}) do
			if (choice == value) then return value end
		end

		return nil
	elseif (field.kind == "items") then
		--[[
			A SET OF ITEM IDS, `{[uniqueID] = true}`. Either shape is taken -
			a set, or a list of ids - and only ids of items that exist and
			pass the field's filter survive. Empty is a value, not a
			failure: it is how a list is taken off.
		]]
		if (not istable(value)) then return nil end

		local out = {}

		for k, v in pairs(value) do
			local id = (isstring(k) and v) and k or (isstring(v) and v) or nil
			local itemTable = id and ix.item.list[id]

			if (itemTable and (not field.filter or field.filter(itemTable))) then
				out[id] = true
			end
		end

		return out
	end

	return tostring(value)
end

--[[
	What a field is set to right now - the override, or the file's own value.

	Everything drawing a field asks this rather than reading the target, so a
	vector comes back as a plain table on both realms and a colour is three
	numbers whether it came from a `Color` or from the save (which is JSON, and
	JSON has no Color - gotcha 13's cousin).
]]
function ix.live.Value(kindID, id, field)
	local stored = (ix.live.overrides[kindID] or {})[id]

	if (stored and stored[field.key] ~= nil) then return stored[field.key] end

	local kind = ix.live.Kind(kindID)
	local target = kind and kind.Target and kind.Target(id)

	--[[
		A FIELD MAY READ ITSELF. Some settings are not one value in one place -
		a chem's SPECIAL buff lives in a list of `{stat, value, duration}` - and
		a field that provides `Read` and `Write` is edited like any other while
		doing whatever it takes underneath.
	]]
	local value

	if (field.Read and target) then
		value = field.Read(target)
	elseif (target) then
		value = ix.live.Read(target, field.key)
	end

	--[[
		A FIELD THAT IS NOT SET IS NOT NECESSARILY OFF.

		`RACE.hasRadiation` is nil on almost every race and MEANS TRUE -
		`ix.races.TakesRadiation` reads `~= false` - so a switch showing nil as
		off told every human they were radiation-proof. `default` is what the
		code does when the field is absent.
	]]
	if (value == nil and field.default ~= nil) then
		value = field.default
	end

	if (field.kind == "vector") then
		if (isvector(value)) then return {value.x, value.y, value.z} end

		return istable(value) and value or {0, 0, 0}
	end

	--[[
		AN ANGLE IS NOT A VECTOR, and the weapon base cares.

		`SWEP.IronSightsPos` is a Vector and `SWEP.IronSightsAng` is an Angle,
		and the base adds to each with its own type - so writing a Vector into
		the angle is an error every frame the weapon is out, exactly as writing
		a plain table was. Three numbers either way; the type is the point.
	]]
	if (field.kind == "angle") then
		if (isangle(value)) then return {value.p, value.y, value.r} end

		return istable(value) and value or {0, 0, 0}
	end

	if (field.kind == "colour") then
		if (IsColor(value)) then return {value.r, value.g, value.b} end

		return istable(value) and value or {255, 255, 255}
	end

	if (field.kind == "number") then return tonumber(value) or 0 end
	if (field.kind == "bool") then return value == true end

	return value
end

--[[
	Turn a stored value into whatever the target expects.

	A vector field is written back as a real `Vector` and a colour as a real
	`Color`, because the code reading them does vector arithmetic on one and
	hands the other to `surface.SetDrawColor`.
]]
local function ToTarget(field, value)
	if (field.kind == "vector" and istable(value)) then
		return Vector(value[1] or 0, value[2] or 0, value[3] or 0)
	end

	if (field.kind == "angle" and istable(value)) then
		return Angle(value[1] or 0, value[2] or 0, value[3] or 0)
	end

	if (field.kind == "colour" and istable(value)) then
		return Color(value[1] or 255, value[2] or 255, value[3] or 255)
	end

	return value
end

--[[
	Write one override into the live tables.

	`bStore` is false when this is a reset - the value is put back and the
	override is dropped rather than recorded.
]]
function ix.live.Apply(kindID, id, key, value)
	local kind = ix.live.Kind(kindID)

	if (not kind) then return false end

	local field = ix.live.Field(kind, id, key)

	if (not field) then return false end

	local target = kind.Target and kind.Target(id)

	if (not target) then return false end

	--[[
		THE BASE IS REMEMBERED BEFORE THE FIRST WRITE, and only then - a second
		edit must not record the first edit as the base, or RESET would put
		back a number somebody typed rather than the one the file has.
	]]
	ix.live.base[kindID] = ix.live.base[kindID] or {}
	ix.live.base[kindID][id] = ix.live.base[kindID][id] or {}

	if (ix.live.base[kindID][id][key] == nil) then
		--[[
			SOME TARGETS REMEMBER THEIR OWN EDITS, and for those "what it is
			now" is the wrong thing to record.

			A SWEP table, an item and a race are rebuilt from their files on
			every boot, so reading the current value gives the file's value and
			RESET works. `ix.config` does not: it SAVES, so after one restart
			the current value IS the edited one, the base recorded on the next
			`ApplyAll` was the edit, and RESET put the edit back - which is
			exactly "I changed a SPECIAL stat and cannot change it back".

			A field may therefore say what its own untouched value is. For a
			config that is `ix.config.stored[key].default`, which Helix keeps
			alongside the value precisely so the difference can be told.
		]]
		if (field.Base) then
			ix.live.base[kindID][id][key] = field.Base(target)
		end
	end

	if (ix.live.base[kindID][id][key] == nil) then
		--[[
			READ IT THE SAME WAY THE EDITOR DOES. A field with its own `Read`
			does not live at `key` on the target - a chem's SPECIAL buff is in
			a list and a SPECIAL tuning number is in `ix.config` - so reading
			the path would record nil as the base and RESET would put nothing
			back.
		]]
		local current

		if (field.Read) then
			current = field.Read(target)
		else
			current = ix.live.Read(target, key)
		end

		--[[
			`false` cannot be stored as "no base recorded", so a boolean base
			is boxed. Anything else keeps its own type.
		]]
		ix.live.base[kindID][id][key] = current == nil and "\0none" or current
	end

	--[[
		CONVERTED ONCE, AND `OnApply` IS GIVEN THE CONVERTED VALUE.

		A vector arrives here as a plain `{x, y, z}` - that is what the window
		sends, and what the store holds, because the save is JSON and JSON has
		no Vector. `ToTarget` turns it back into a real one before it is
		written.

		`OnApply` used to be handed the RAW value, and the weapon kind writes
		it straight onto every weapon of that class already in the world - so
		an ironsight edit put a table where the base expected a Vector and
		every frame of `GetOffset` threw

		    bad argument #1 to '__add' (Vector expected, got table)

		until the weapon was put away. It was invisible for as long as writing
		to a live weapon was silently doing nothing at all; fixing that made it
		fire. One conversion, one value, both users of it.
	]]
	local final = ToTarget(field, value)
	local written

	if (field.Write) then
		written = field.Write(target, final) ~= false
	else
		written = ix.live.Write(target, key, final)
	end

	if (written and kind.OnApply) then
		kind.OnApply(id, key, final)
	end

	return written
end

--- Put one field back to what the file says, and forget the override.
function ix.live.Reset(kindID, id, key)
	local base = ((ix.live.base[kindID] or {})[id] or {})[key]
	local kind = ix.live.Kind(kindID)
	local target = kind and kind.Target and kind.Target(id)

	local field = ix.live.Field(kind, id, key)

	--[[
		A FIELD THAT WAS NEVER THERE IS PUT BACK BY REMOVING IT.

		`"\0none"` is how "there was nothing here" is stored, because nil
		cannot be a table value - and Reset used to see it and do nothing at
		all, leaving the number somebody typed sitting in the SWEP table until
		the next restart. RESET said it had reset and had not.

		Almost no weapon writes `AmmoPerShot`, `NumShots` or the spread
		modifiers: they inherit them from `ls_base` when the entity is made, so
		the honest original is an ABSENT KEY rather than a number, and writing
		nil is what hands the field back to that inheritance.
	]]
	if (target and base ~= nil) then
		local value = base ~= "\0none" and base or nil

		if (field and field.Write) then
			field.Write(target, value)
		else
			ix.live.Write(target, key, value)
		end

		if (kind.OnApply) then kind.OnApply(id, key, value) end
	end

	if (ix.live.overrides[kindID] and ix.live.overrides[kindID][id]) then
		ix.live.overrides[kindID][id][key] = nil

		if (not next(ix.live.overrides[kindID][id])) then
			ix.live.overrides[kindID][id] = nil
		end
	end
end

--[[
	PUT EVERY REMEMBERED BASE BACK, then apply what the store says.

	This is what makes RESET work on a CLIENT. A reset removes the override on
	the server and syncs; the client's copy of the store then simply LACKS that
	entry - and applying a store that lacks an entry does nothing at all, so the
	edited number stayed in the item table until the next map load, and the
	window read it back and reported that nothing had happened.

	The value it should go back to is in `ix.live.base`, captured the first time
	it was written. The bases are cleared as they are restored, so the next
	`Apply` captures a fresh one - otherwise a field edited, reset and edited
	again would remember a base from two edits ago.
]]
function ix.live.RestoreAll()
	for kindID, subjects in pairs(ix.live.base) do
		local kind = ix.live.Kind(kindID)

		if (not kind) then continue end

		for id, fields in pairs(subjects) do
			local target = kind.Target and kind.Target(id)

			if (not target) then continue end

			for key, base in pairs(fields) do
				--- Absent is a value: see `Reset` for why nil is written.
				local value = base ~= "\0none" and base or nil
				local field = ix.live.Field(kind, id, key)

				if (field and field.Write) then
					field.Write(target, value)
				else
					ix.live.Write(target, key, value)
				end

				--[[
					AND THE SAME `OnApply` AN EDIT GETS.

					Putting the number back into the SWEP table is only half of it:
					`OnApply` is what carries a change to the weapons already in the
					world and rebuilds their cache. Without it a RESET fixed the
					table nobody was reading and left the gun in your hands exactly
					as you had tuned it - the menu showed the original numbers, the
					sights did not move, and typing those same numbers in by hand
					worked, which is as confusing as this system gets.

					A restore is an apply of the old value, so it takes the same path.
				]]
				if (kind.OnApply) then
					kind.OnApply(id, key, value)
				end
			end
		end
	end

	ix.live.base = {}
end

--[[
	Everything in the store, applied to the live tables.

	Run after the store is loaded on the server, and after every sync on the
	client. Anything naming a subject that no longer exists is skipped rather
	than dropped - a weapon pack that is temporarily uninstalled should not
	silently lose its numbers.
]]
function ix.live.ApplyAll()
	local applied = 0

	for kindID, subjects in pairs(ix.live.overrides) do
		local kind = ix.live.Kind(kindID)

		if (not kind) then continue end

		for id, fields in pairs(subjects) do
			for key, value in pairs(fields) do
				--[[
					One at a time, and one failure is one field. This runs at
					boot over everything anybody has ever edited, so a single
					weapon from an uninstalled pack, or a kind whose `OnApply`
					throws, must not stop the other ninety.
				]]
				local ok, err = pcall(ix.live.Apply, kindID, id, key, value)

				if (not ok) then
					ErrorNoHalt(string.format(
						"[falloutrp] live edit %s/%s/%s threw: %s\n",
						kindID, id, key, tostring(err)))
				elseif (err) then
					applied = applied + 1
				end
			end
		end
	end

	return applied
end

--------------------------------------------------------------------------------
-- Asking what actually happened
--------------------------------------------------------------------------------

--[[
	`fo_live` - every override, and whether the target agrees with it.

	Live editing has now failed twice for reasons that were invisible from the
	window: an override that was stored, synced and drawn while the thing it
	described was never written (`istable` on a weapon entity), and an override
	whose RESET put back the wrong number (a config that saves itself). In both
	cases the editor looked right and the game did not, and there was no way to
	ask which of the two was lying.

	This is that question. For every stored override it prints what the store
	says, what the target says right now, and whether they match - on whichever
	realm you run it, because "the server has it and the client does not" is
	itself one of the answers.

	`fo_live weapon` narrows it to one kind.
]]
local function Report(filter)
	local prefix = SERVER and "SERVER" or "CLIENT"
	local plain, good, bad = Color(200, 200, 190), Color(120, 220, 120),
		Color(255, 120, 100)

	MsgC(Color(255, 200, 60), string.format(
		"\n-- live edits, %s --\n\n", prefix))

	local total, wrong = 0, 0

	for kindID, subjects in SortedPairs(ix.live.overrides) do
		if (filter and filter ~= "" and filter ~= kindID) then continue end

		local kind = ix.live.Kind(kindID)

		if (not kind) then
			MsgC(bad, string.format("  %s - NO SUCH KIND\n", kindID))

			continue
		end

		for id, fields in SortedPairs(subjects) do
			local target = kind.Target and kind.Target(id)

			MsgC(plain, string.format("  %s / %s%s\n", kindID, id,
				target and "" or "   <- TARGET DOES NOT EXIST"))

			for key, stored in SortedPairs(fields) do
				total = total + 1

				local field = ix.live.Field(kind, id, key)
				local actual

				if (field and target) then
					actual = field.Read and field.Read(target)
						or ix.live.Read(target, key)
				end

				--[[
					Compared as text. A vector is a table, a bool is a bool,
					and the point of the line is whether a human would call
					them the same - not whether Lua would.
				]]
				local want = istable(stored) and table.concat(stored, ", ")
					or tostring(stored)
				local have = istable(actual) and table.concat(actual, ", ")
					or tostring(actual)
				local same = want == have

				if (not same) then wrong = wrong + 1 end

				MsgC(same and good or bad, string.format(
					"      %-26s store %-12s target %-12s %s\n",
					key, want, have, same and "ok" or "MISMATCH"))
			end
		end
	end

	MsgC(Color(255, 200, 60), string.format(
		"\n  %d field(s), %d not applied to the target\n", total, wrong))

	if (SERVER) then
		MsgC(plain, string.format("  %d weapon(s) have combat settings\n",
			table.Count(ix.combat.settings or {})))
	end

	MsgC(plain, "  run it on the other realm too - an override that is right "
		.. "on one and wrong\n  on the other is a sync problem, not an "
		.. "apply problem\n\n")
end

concommand.Add("fo_live", function(client, _, arguments)
	--- Anybody may look on their own client; the server console is the server.
	if (SERVER and IsValid(client) and not client:IsSuperAdmin()) then return end

	Report(arguments and arguments[1])
end)

--- Whether anything has been changed about one subject, for the list.
function ix.live.IsEdited(kindID, id)
	local subjects = ix.live.overrides[kindID]

	return subjects ~= nil and subjects[id] ~= nil
end
