--[[
	Orbital drops.

	Every so often a beacon lands on one of the drop sites placed with the
	`fo_point` tool. It sits there counting down, visible as a red dome and a
	timer on the screen of anybody inside it, and when it runs out a cargo
	craft flies in and drops a container of loot. The container is worth
	fighting over and disappears after a few minutes.

	PORTED FROM PHOENIX'S `orbital_drops`, as closely as this server can carry.
	Their shape, their timings and their configuration, all of which the scrape
	did capture:

	    Orbital Event Timer      3600   how often one happens
	    Orbital Beacon Time       300   how long the beacon counts down
	    Orbital Self Destruct     300   how long the container lasts
	    Orbital Minimum Players    30   below this, nothing happens
	    beacon -> 15 seconds -> drone -> drop at 58% of its pass

	    radius 640 for the dome and the PVP warning
	    render distance 2500 for the dome

	WHAT COULD NOT BE CARRIED, and why:

	    models/roadkill/fallout/vehicle/cargobot.mdl   not on this server
	    models/galang/.../airdroppedcontainer.mdl      not on this server
	    fx/orbital/*.wav, fallout/orbit/standby.wav    not on this server
	    HL1/fvox/blip.wav, flatline.wav                needs HL1 mounted

	Checked with `_docs/tools/resolve_asset.py`, not assumed. The substitutes
	are the nearest thing the installed packs do have, and the cargobot is the
	interesting one: Phoenix drive theirs off a `dropoff` ANIMATION and drop
	the crate at cycle 0.58. `models/fallout/vertibird.mdl` has two sequences,
	`idle` and `spin` - `mdlseq.py` says so - so there is no dropoff to play
	and the flight is scripted instead, dropping at the same 58% of the same
	length of time. What a player sees is the same thing.

	THE DROP SITES ARE THE ONES ALREADY PLACED. `ix.points` has held an
	`orbital` type since the point tool was written, described at the time as
	"a marker with a name and a position, placed now so the map work can happen
	before the drop system exists". This is that system, and it reads that
	list.
]]

ix.orbital = ix.orbital or {}

--- Phoenix's numbers, unchanged.
ix.orbital.radius = 640
ix.orbital.renderDistance = 2500

--- Beacon to drone, in seconds. Theirs, in `nut_orbital_beacon`.
ix.orbital.launchDelay = 15

--- How long the cargo craft's pass takes, and how far through it drops.
ix.orbital.flightTime = 14
ix.orbital.dropAt = 0.58

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

ix.config.Add("orbitalEnabled", true,
	"Whether orbital drops happen on their own.", nil, {
	category = "Orbital Drops"
})

ix.config.Add("orbitalInterval", 3600,
	"Seconds between orbital drops.", nil, {
	data = {min = 60, max = 99999},
	category = "Orbital Drops"
})

ix.config.Add("orbitalBeaconTime", 300,
	"How long a beacon counts down before the drop arrives.", nil, {
	data = {min = 10, max = 99999},
	category = "Orbital Drops"
})

ix.config.Add("orbitalDespawn", 300,
	"How long the container lasts before it self destructs.", nil, {
	data = {min = 10, max = 1200},
	category = "Orbital Drops"
})

--[[
	Phoenix's own default is 30, which on a server with fewer than thirty
	people on means orbital drops never happen at all. Kept as theirs rather
	than quietly lowered - it is a real decision about when the event is worth
	running - and `/orbital` forces one regardless, which is how you test it.
]]
ix.config.Add("orbitalMinPlayers", 30,
	"How many people have to be on before a drop happens by itself.", nil, {
	data = {min = 1, max = 128},
	category = "Orbital Drops"
})

--[[
	Which loot table fills the container.

	AN ORDINARY LOOTABLE WITH A DIFFERENT TABLE, and nothing else. Phoenix
	hardcode theirs as `{table = "Orbital_Looter", count = 4}` and the `count`
	was carried across at first - four passes over the table into one
	container. That is a second way of saying "make it generous", on top of the
	table itself, and it made the contents of a drop a function of two numbers
	in two different screens.

	One number in one screen: build the table to be worth flying out for. The
	container is a lootable, the table decides what is in it, and there is
	nothing else to tune.

	A config rather than a hardcoded name because loot tables here are made in
	game through the loot configurer, so there is no name this file could know
	is real - and one that did not exist would be a container that opens empty
	with nothing to say why.
]]
ix.config.Add("orbitalLootTable", "Orbital",
	"The loot table an orbital container is filled from.", nil, {
	category = "Orbital Drops"
})

--[[
	THE ONE ADDITION TO THEIRS.

	Phoenix announce nothing: their beacon is the announcement, and you have to
	be within 640 units to see the countdown at all. That works on a server
	where everybody has learned where the sites are. Until this one has, an
	unannounced drop on a large map is one nobody finds - so it says where, and
	it is a config so it can be turned off once the sites are common knowledge.
]]
ix.config.Add("orbitalAnnounce", true,
	"Whether a beacon landing is announced in chat.", nil, {
	category = "Orbital Drops"
})

--------------------------------------------------------------------------------
-- Permissions
--------------------------------------------------------------------------------

if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("orbital.force",
		"Call an orbital drop by hand", "World")
end

--------------------------------------------------------------------------------
-- Models and sounds
--------------------------------------------------------------------------------

--[[
	Kept in one table so a server with different content has one place to
	change - and so the substitutions above are visible as a list rather than
	scattered through three files.
]]
ix.orbital.assets = {
	--- Theirs. Base Half-Life 2, so it is here.
	beacon = "models/Items/grenadeAmmo.mdl",

	--[[
		Stands in for `cargobot.mdl`. Sentry's flying Vertibird (gear up,
		`spin` for the blades) from the Trailblaze pack, which the vehicles
		brought in; it replaced the creature pack's small static one.
	]]
	drone = "models/sentry/vertibirds/vb02_fly.mdl",

	--[[
		Stands in for `airdroppedcontainer.mdl`.

		The doubled `models/models/` is not a typo: the two-wastelands pack
		nests its content one folder deeper than its own root, so that IS the
		path, and `resolve_asset.py` confirms it.
	]]
	container = "models/models/fallout/lonesomemilitarycrate.mdl",

	standby = "phoenix/ui/nv/menu_beep.mp3",
	blip = "phoenix/ui/nv/menu_beep.mp3",
	authorized = "phoenix/ui/76/ui_discover_region_01.mp3",
	launch = "phoenix/ui/76/ui_questupdate_01.mp3",

	--- Theirs, both base Half-Life 2.
	destroyed = "npc/manhack/gib.wav",
	opened = "vehicles/atv_ammo_open.wav",

	rotor = "vj_fallout/vertibird/vertibird_blades_a_lp.wav"
}
