--[[
	The Q menu permissions.

	SHARED, while everything that enforces them is in `sv_sandbox.lua`. A
	permission registered only on the server is invisible in the rank editor,
	which runs on the client - so seventeen tickboxes were simply missing from
	that screen with nothing to explain their absence.

	The registry itself is `sh_adminbase.lua`, which sorts ahead of this.
]]

do
	local P = ix.admin.RegisterPermission

	P("spawn.prop", "Spawn props from the Q menu", "Spawning")
	P("spawn.weapon", "Spawn or give weapons", "Spawning")
	P("spawn.entity", "Spawn entities", "Spawning")
	P("spawn.npc", "Spawn NPCs", "Spawning")
	P("spawn.vehicle", "Spawn vehicles", "Spawning")
	P("spawn.effect", "Spawn effects", "Spawning")
	P("spawn.ragdoll", "Spawn ragdolls", "Spawning")
	P("spawn.tool", "Use the tool gun", "Spawning")
	P("spawn.physgun", "Pick things up with the physics gun", "Spawning")
	P("spawn.property", "Use the context menu properties", "Spawning")

	--[[
		The tools worth taking away individually. Anything not listed here
		falls back to `spawn.tool` - see `CanTool` in `sv_sandbox.lua`.
	]]
	--[[
		CLEANUP IS THE MOST DESTRUCTIVE BUTTON IN THE GAME and it was ungated.

		`gmod_admin_cleanup` calls `game.CleanUpMap`, which removes every
		entity the map did not create - every lootable, every workbench, every
		faction storage, every capture point, every placed container - and this
		schema keeps an enormous amount of state in entities. The records
		survive, so most of it returns on the next map load, but until then the
		map is empty and anything mid-flight is simply gone.

		`gmod_cleanup` is the smaller one: it removes what YOU spawned, which
		is still a permanent prop disappearing until the next restart.

		Both are `concommand`s in `includes/modules/cleanup.lua` with no hook
		anywhere in them - the admin one's entire check is `pl:IsAdmin()` - so
		the only way to gate them is to replace the command. See
		`sv_sandbox.lua`.
	]]
	P("cleanup.self", "Clean up your own spawned props", "Tools")
	P("cleanup.map", "Clean up the whole map - removes every placed entity",
		"Tools")

	P("tool.remover", "The remover tool", "Tools")
	P("tool.duplicator", "The duplicator", "Tools")
	P("tool.weld", "The weld tool", "Tools")
	P("tool.permaprop", "Make props permanent", "Tools")
end
