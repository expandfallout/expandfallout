--[[
	The live editor, client side: applying what the server sends.

	EVERY OVERRIDE IS APPLIED HERE TOO, and that is not cosmetic. A weapon's
	damage, spread and ironsight position are read on the CLIENT for prediction
	and the viewmodel; an item's description is built on the client; a faction's
	colour is drawn on the client. An override that reached only the server
	would give a rifle that feels wrong and hits right.

	See `sh_live.lua` for the store and `derma/cl_liveedit.lua` for the window.
]]

if (not CLIENT) then return end

--[[
	DECLARED HERE, BECAUSE `cl_` LOADS BEFORE `sh_`.

	`ix.util.IncludeDir` walks the folder in file.Find order, which is
	alphabetical - so every `cl_` file in `libs/` runs BEFORE `sh_live.lua`,
	the file that creates `ix.live`. Without these two lines the function at
	the bottom of this file was `function (nil).ToggleSights()`, which is an
	error at file scope.

	AND AN ERROR AT FILE SCOPE TAKES THE WHOLE DIRECTORY WITH IT (gotcha 23):
	`IncludeDir` has no pcall, so everything alphabetically after this file was
	never included on the client at all - `cl_rarity.lua` and its weapon
	descriptions, every `sh_` library the client needs, the live editor's own
	kinds. One missing line presented as five unrelated features being broken.

	Every other `cl_` file in this schema that touches an `ix` table does the
	same; this was the one that did not.
]]
ix.live = ix.live or {}
ix.combat = ix.combat or {}

net.Receive("ixLiveSync", function()
	ix.live.overrides = net.ReadTable() or {}
	ix.combat.settings = net.ReadTable() or {}
	ix.live.tabOrder = net.ReadTable() or {}

	--[[
		EVERYTHING BACK, THEN EVERYTHING ON AGAIN.

		A reset is an override that is simply ABSENT from the next sync, and
		applying a store that lacks an entry does nothing - so without the
		restore the client would keep the edited number for the rest of the
		session while the server had already put it back. See
		`ix.live.RestoreAll`.
	]]
	if (not ix.live.ApplyAll) then
		--[[
			The shared half is missing, which means `sh_live.lua` did not load.
			Said once, plainly, rather than erroring on every sync - a client
			in this state has bigger problems and the console should say which.
		]]
		ErrorNoHalt("[falloutrp] live overrides arrived but sh_live.lua is "
			.. "not loaded - check the console for an earlier include error\n")

		return
	end

	ix.live.RestoreAll()
	ix.live.ApplyAll()

	if (IsValid(ix.gui.liveEdit)) then
		ix.gui.liveEdit:Rebuild()
	end
end)

net.Receive("ixLiveOpen", function()
	if (IsValid(ix.gui.liveEdit)) then
		ix.gui.liveEdit:Remove()
	end

	vgui.Create("ixFOLiveEdit")
end)

--[[
	The ironsight editor is the WEAPON BASE's, not ours.

	`longsword_ironsighteditor` toggles it: hold the gun, hold a movement key,
	and the sights move. It already exists, it already works, and writing a
	second one would be a worse copy - so the live editor's EDIT SIGHTS button
	runs it and then reads the numbers back off the weapon.

	This wrapper exists so the window has one function to call and one place to
	explain what happens next, since the base prints its state to console and
	says nothing on screen.
]]
function ix.live.ToggleSights()
	local client = LocalPlayer()
	local weapon = IsValid(client) and client:GetActiveWeapon()

	if (not IsValid(weapon) or not weapon.IsLongsword) then
		client:Notify("Hold the weapon you want to aim first.")

		return false
	end

	--[[
		A TOGGLE, so which way it is about to go decides what to say.

		The state is a networked bool the server sets, which means it is a
		round trip behind - the value read here is the state BEFORE this press,
		and the message describes its opposite.
	]]
	local wasOpen = client:GetNWBool("longsword_ironsighteditor", false)

	RunConsoleCommand("longsword_ironsighteditor")

	if (wasOpen) then
		client:Notify("Ironsight editor closed. Nothing was saved - press "
			.. "SAVE SIGHTS to keep what you moved.")

		return false
	end

	--[[
		The base's own controls, named rather than guessed at: `+attack` and
		`+attack2` choose which of the two you are moving, WASD move it in the
		plane, `+use` and `+menu` move it in and out, and the two modifiers
		change the step from 0.1 to 0.5 or to 0.001.
	]]
	client:Notify("Ironsight editor open. LEFT CLICK for position, RIGHT "
		.. "CLICK for angle; WASD to move, USE and the context key for the "
		.. "third axis. Shift is coarse and Ctrl is fine. Then SAVE SIGHTS.")

	return true
end
