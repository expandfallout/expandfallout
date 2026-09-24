--[[
	The stash, server side: finding the one that belongs to a character.

	See `sh_stash.lua` for what a stash is and why the box does not own it.

	MADE THE FIRST TIME IT IS OPENED, not when a character is created. Most
	characters never touch one, and an inventory row per character per stash
	system is a table nobody asked for - this way the database holds exactly as
	many as have been used.
]]

if (not SERVER) then return end

ix.stash = ix.stash or {}

--[[
	Characters whose stash is being fetched right now.

	`ix.inventory.New` and `ix.inventory.Restore` are DATABASE QUERIES with
	callbacks, so two E presses a frame apart both find no inventory and both
	create one - and the second overwrites the first's id, orphaning everything
	in it. Keyed by character id, cleared in the callback.
]]
ix.stash.loading = ix.stash.loading or {}

--[[
	The stash inventory for a character, handed to a callback.

	The callback gets nil when there is no character, when the database refuses
	or when the character logged out mid-query - every caller has to handle
	that anyway, so there is no error path that needs a second argument.
]]
function ix.stash.For(character, callback)
	if (not character) then
		callback(nil)

		return
	end

	local id = character:GetID()

	if (ix.stash.loading[id]) then
		callback(nil, "Still opening. Try again in a moment.")

		return
	end

	local width, height = ix.stash.Size()
	local invType = ix.stash.InventoryType(width, height)
	local invID = tonumber(character:GetData("stash", 0)) or 0

	--- Already in memory, which is the case for every open after the first.
	local inventory = invID > 0 and ix.inventory.Get(invID)

	if (inventory) then
		callback(inventory)

		return
	end

	ix.stash.loading[id] = true

	local function Done(result)
		ix.stash.loading[id] = nil

		if (result) then
			result.vars.isBag = true
			result.vars.isContainer = true

			--- Which character this belongs to; `ix.stash.OwnerOf` reads it.
			result.vars.stashOwner = id
		end

		callback(result)
	end

	--[[
		A character with an id restores; one without is given a new inventory.

		RESTORED AT THE CONFIGURED SIZE rather than the size it was made at.
		Helix takes the grid from the arguments here, so raising `stashWidth`
		makes every existing stash bigger the next time it is opened, which is
		what an admin raising it means by it.
	]]
	if (invID > 0) then
		ix.inventory.Restore(invID, width, height, function(restored)
			Done(restored or ix.inventory.Get(invID))
		end)

		return
	end

	ix.inventory.New(0, invType, function(created)
		if (not created) then
			Done(nil)

			return
		end

		--[[
			WRITTEN BEFORE THE CALLBACK RUNS. If the character were saved after
			the window opened, a crash in between would leave an inventory full
			of things with nothing pointing at it - and the next open would
			make a second one.
		]]
		character:SetData("stash", created:GetID())

		Done(created)
	end)
end

--- Who a stash inventory belongs to, or nil if it is not a stash.
function ix.stash.OwnerOf(inventory)
	return inventory and inventory.vars and inventory.vars.stashOwner
end

--[[
	Open one for somebody standing at a box.

	The reach check is the caller's - the entity has already done a use trace
	by the time this runs - so this is only about whether there is a character
	and an inventory to show them.
]]
function ix.stash.Open(client, entity)
	if (not IsValid(client) or not IsValid(entity)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	ix.stash.For(character, function(inventory, reason)
		if (not IsValid(client) or client:GetCharacter() ~= character) then
			return
		end

		if (not inventory) then
			client:Notify(reason or "Your stash could not be opened.")

			return
		end

		if (not IsValid(entity)) then return end

		--[[
			ANY EXISTING CONTEXT IS TORN DOWN FIRST, and this is not tidiness.

			Helix keeps ONE storage context per inventory and reuses it - see
			`ix.storage.Open`, which only builds one if there is not one there
			already. The context remembers the ENTITY it was opened at, and
			that entity is what `DoStaredAction` waits for you to keep looking
			at. So a stash opened in one town and then walked away from leaves
			a context pointing at a box on the other side of the map, and every
			later open silently never completes.

			Worse, a context whose receiver never sent `ixStorageClose` - a
			disconnect, a crash, a window closed by something else - counts as
			IN USE, and `ix.storage.Open` refuses the second person. On a shared
			container that is a nuisance; on the box holding your own things it
			is a lockout.

			Both are fixed by the same line, and it is safe here in a way it
			would not be on a faction storage: a stash has exactly one legal
			user, so anybody holding it open is this same character.
		]]
		if (inventory.storageInfo) then
			ix.storage.Close(inventory)
		end

		ix.storage.Open(client, inventory, {
			name = "Stash",
			entity = entity,
			searchTime = ix.config.Get("stashOpenTime", 0.25),

			--[[
				`bMultipleUsers` is deliberately LEFT OFF.

				Two people at the same box are looking at two different
				inventories, so there is nothing to share and no second user to
				allow. What it would do is let one character open their own
				stash twice - once at each of two boxes - and two open windows
				onto one grid is how an item gets duplicated.
			]]
			OnPlayerClose = function()
				if (IsValid(entity)) then
					entity:EmitSound("phoenix/ui/nv/itm_bottle_up_02.mp3", 60,
						90, 0.4)
				end
			end
		})
	end)
end
