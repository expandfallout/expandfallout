
-- The shared init file. You'll want to fill out the info for your schema and include any other files that you need.

-- Schema info
Schema.name = "Fallout RP"
Schema.author = ""
Schema.description = "A Fallout roleplay schema for the Mojave wasteland."

--[[
	Logo.

	Helix's character menu draws a centred IMAGE here when this points at a
	valid material, and falls back to the schema name and description as text
	when it does not - which is what is showing now.

	Phoenix uses a logo image in exactly this position, so dropping a material
	in and setting this path is all that is needed to match it:

	    Schema.logo = "phoenix/logo.png"
]]
-- Schema.logo = "falloutrp/logo.png"

-- Additional files that aren't auto-included should be included here. Note that ix.util.Include will take care of properly
-- using AddCSLuaFile, given that your files have the proper naming scheme.

-- You could technically put most of your schema code into a couple of files, but that makes your code a lot harder to manage -
-- especially once your project grows in size. The standard convention is to have your miscellaneous functions that don't belong
-- in a library reside in your cl/sh/sv_schema.lua files. Your gamemode hooks should reside in cl/sh/sv_hooks.lua. Logical
-- groupings of functions should be put into their own libraries in the libs/ folder. Everything in the libs/ folder is loaded
-- automatically.
ix.util.Include("cl_schema.lua")
ix.util.Include("sv_schema.lua")

--[[
	Currency: caps, written as a SUFFIX.

	`ix.currency.Set` only feeds Helix's formatter, which builds
	"<symbol><amount> <singular|plural>" - so it can produce "c250 caps" but
	never "250c". Caps are written with a trailing c, so the formatter itself is
	replaced.

	`ix.currency.symbol` and the singular/plural are still set, because other
	code reads them directly for labels and entity names.
]]
ix.currency.Set("c", "cap", "caps")

function ix.currency.Get(amount)
	return amount .. "c"
end

--[[
	Inventory dimensions.

	Helix defaults to 6x4. Phoenix uses 10x7, which with slots scaled to fit
	gives the wide shallow grid their menu is built around.

	NOTE: an inventory is created at its size when the CHARACTER is created, so
	this only affects new characters. Existing ones keep 6x4.
]]
ix.config.SetDefault("inventoryWidth", 10)
ix.config.SetDefault("inventoryHeight", 7)

--[[
	Fallout UI.

	Order matters: the theme defines the palette, fonts and draw primitives that
	the other two read at load time. The skin reaches into Helix's own derma
	skin and restyles every stock panel that paints through derma's skin
	dispatch; cl_panels patches Helix's own registered panels, which do not;
	the HUD replaces Helix's bars entirely.
]]
ix.util.Include("fallout_ui/cl_theme.lua")
ix.util.Include("fallout_ui/cl_widgets.lua")
ix.util.Include("fallout_ui/cl_skin.lua")
ix.util.Include("fallout_ui/cl_panels.lua")
ix.util.Include("fallout_ui/cl_customizer.lua")
ix.util.Include("fallout_ui/cl_creation.lua")
ix.util.Include("fallout_ui/cl_menu.lua")
ix.util.Include("fallout_ui/cl_hud.lua")

ix.util.Include("cl_hooks.lua")
ix.util.Include("sh_hooks.lua")
ix.util.Include("sv_hooks.lua")

-- You'll need to manually include files in the meta/ folder, however.
ix.util.Include("meta/sh_character.lua")
ix.util.Include("meta/sh_player.lua")

--[[
	Races.

	Helix auto-loads `attributes/`, `factions/`, `classes/` and `items/` but
	knows nothing about races, so the directory is loaded explicitly. This is
	safe here because `libs/` is included BEFORE this file - see
	`core/libs/sh_plugin.lua`, which runs IncludeDir("libs") first and
	sh_schema.lua last - so `ix.races` exists by now.

	`Schema.folder` rather than a literal "falloutrp": the folder is whatever
	the gamemode is running as, and a rename should not silently load nothing.
]]
ix.races.LoadFromDir(Schema.folder .. "/schema/races")

if (CLIENT and ix.fallout and ix.fallout.CreateTrace) then
	ix.fallout.CreateTrace("load: sh_schema.lua, races = "
		.. table.Count(ix.races.list))
end
