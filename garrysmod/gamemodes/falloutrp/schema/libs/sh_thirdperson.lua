--[[
	Third person.

	THE ADDON, NOT HELIX'S. `addons/simplethirdperson` is edunad's Simple
	Thirdperson (Apache 2.0, and its LICENSE ships next to it) - the one that
	was asked for by name. It is a self-contained `lua/autorun` file with no
	dependencies, so it is within the addon rules in `02-server-setup.md`: what
	those rules forbid is a Lua addon whose dependencies are missing.

	WHAT IT HAS THAT HELIX'S DOES NOT: a settings menu on the context wheel,
	shoulder view with its own offsets, smoothing on every axis, collision that
	can be forced on or off server-side, and server convars that cap how far
	anybody may push the camera - `simple_thirdperson_maxdistance` and the rest.
	That last part is the reason a server owner cares which one is installed.

	SO HELIX'S IS TURNED OFF, and left registered. Two third person cameras
	both writing `CalcView` is one camera fighting itself; theirs only acts when
	`thirdperson` is on, so the config being false is the whole of the fix. It
	is still in the developer terminal, and turning it on is how a server drops
	the addon and goes back to the built-in one.

	This file is then two things: the switch, and `/thirdperson`, because `stp`
	is a console command nobody discovers.
]]

--[[
	Left OFF, which is Helix's own default - and said explicitly rather than
	left alone, because an earlier version of this file turned it ON and a
	server that ran that version has the value saved.
]]
ix.config.SetDefault("thirdperson", false)

if (ix.config.stored.thirdperson) then
	ix.config.ForceSet("thirdperson", false)
end

--[[
	THE LIMITS, FORCED ON EVERYBODY.

	The addon's own convars are `FCVAR_REPLICATED`, so the SERVER's value is
	the one every client obeys - which is the whole reason this addon was
	picked over Helix's. Set here rather than in `server.cfg` because a convar
	in a config file is one nobody finds when the camera behaves oddly, and
	because these numbers belong with the rest of the schema's decisions.

	    shoulder view       clamped to 1 in every direction, which is the
	                        addon's way of saying "off" - the over-the-shoulder
	                        offset is what lets somebody peer round a corner
	                        their character cannot see round
	    pitch, yaw, right   the same, so the camera cannot be swung out sideways
	                        or under the floor
	    up                  1 to 25, a little headroom and no more
	    distance            -185 to 185, so it can be pushed back to a useful
	                        third person and no further

	`game.ConsoleCommand` rather than `SetValue`, because these are created by
	the addon in `lua/autorun` and that runs BEFORE the gamemode - the ConVar
	objects exist, but writing them through the console is what replicates the
	change to clients already connected.
]]
if (SERVER) then
	local LIMITS = {
		simple_thirdperson_shoulder_maxdist = 1,
		simple_thirdperson_shoulder_mindist = 1,
		simple_thirdperson_shoulder_maxup = 1,
		simple_thirdperson_shoulder_minup = 1,
		simple_thirdperson_shoulder_maxright = 1,
		simple_thirdperson_shoulder_minright = 1,

		simple_thirdperson_maxpitch = 1,
		simple_thirdperson_minpitch = 1,
		simple_thirdperson_maxright = 1,
		simple_thirdperson_minright = 1,
		simple_thirdperson_maxyaw = 1,
		simple_thirdperson_minyaw = 1,

		simple_thirdperson_maxup = 25,
		simple_thirdperson_minup = 1,
		simple_thirdperson_maxdistance = 185,
		simple_thirdperson_mindistance = -185
	}

	--[[
		Applied on a short delay AND on every map start, because the addon's
		`lua/autorun` file is what creates the convars and a value written for
		one that does not exist yet is dropped silently.
	]]
	local function ApplyLimits()
		for name, value in pairs(LIMITS) do
			if (not ConVarExists(name)) then continue end

			game.ConsoleCommand(string.format("%s %s\n", name,
				tostring(value)))
		end
	end

	timer.Simple(5, ApplyLimits)

	--- And for anybody joining later, in case a convar was changed by hand.
	hook.Add("PlayerInitialSpawn", "ixThirdPersonLimits", function()
		timer.Simple(1, ApplyLimits)
	end)
end

if (SERVER) then
	util.AddNetworkString("ixThirdPerson")
end

--[[
	The toggle is a CLIENT convar the addon owns, so the command asks the
	client to run the addon's own command rather than reaching into it. Same
	shape as `/Crosshair`.
]]
ix.command.Add("ThirdPerson", {
	description = "Turn your third person camera on or off.",

	OnRun = function(self, client)
		net.Start("ixThirdPerson")
		net.Send(client)
	end
})

ix.command.Add("ThirdPersonMenu", {
	description = "Open the third person settings.",

	OnRun = function(self, client)
		net.Start("ixThirdPerson")
			net.WriteBool(true)
		net.Send(client)
	end
})

if (CLIENT) then
	net.Receive("ixThirdPerson", function()
		--[[
			`net.ReadBool` on a message that carried nothing answers false,
			which is exactly the plain toggle - so both commands are one
			message and one receiver.
		]]
		if (net.ReadBool()) then
			RunConsoleCommand("simple_thirdperson_menu")

			return
		end

		if (not ConVarExists("simple_thirdperson_enabled")) then
			LocalPlayer():Notify("Third person is not installed on this "
				.. "server.")

			return
		end

		RunConsoleCommand("stp")
	end)

	--- The same toggle under this schema's own prefix, for a bind.
	concommand.Add("fo_thirdperson", function()
		RunConsoleCommand("stp")
	end)
end
