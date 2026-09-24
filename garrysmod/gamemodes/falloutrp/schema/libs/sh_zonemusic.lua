--[[
	Music by zone.

	A zone - any of the four kinds in `sh_zones.lua` - can carry a `music`
	property: a station from `sh_radio.lua`, one song, or nothing. Stand in
	it and the client plays it under everything else, quietly, and it fades
	when you leave. THE SMALLEST ZONE AROUND YOU THAT HAS MUSIC WINS, so a
	shop drawn inside a town with no music of its own keeps the town's.

	Set with the Zone Music tool (`fo_zonemusic`), or when a zone is made
	with the Zone Editor, or by hand in Helix's own area editor, where it is
	a plain text field.

	THE VALUE IS ONE STRING:

	    ""                        nothing
	    station:newvegas          a station, shuffled
	    song:phoenix/music/...    one file, on repeat

	A string because Helix types and networks area properties one at a
	time, and because the tool panel that sets it is a convar.

	`sh_zonemusic` SORTS BEFORE `sh_zones`, so nothing of `ix.zones` is read
	at file scope here; every use is inside a function.
]]

ix.zonemusic = ix.zonemusic or {}
ix.zones = ix.zones or {}

local function Register()
	if (not ix.area or not ix.area.AddProperty) then return end

	ix.area.AddProperty("music", ix.type.string, "")
end

Register()

hook.Add("SetupAreaProperties", "ixZoneMusic", Register)

--- The title of a song by its path, or the path when it is not on a list.
function ix.zonemusic.SongName(path)
	for _, station in ipairs(ix.radio.stations or {}) do
		for _, song in ipairs(station.songs or {}) do
			if (song.path == path) then return song.name end
		end
	end

	for _, song in ipairs(ix.radio.themes or {}) do
		if (song.path == path) then return song.name end
	end

	return path
end

--[[
	What a value means. Returns "station" and the station, or "song" and
	`{path, name}`, or nothing for nothing and for a station the server no
	longer has.
]]
function ix.zonemusic.Resolve(value)
	if (not isstring(value) or value == "") then return nil end

	local kind, rest = string.match(value, "^(%a+):(.+)$")

	if (kind == "station") then
		local station = ix.radio.byID and ix.radio.byID[rest]

		if (station) then return "station", station end
	elseif (kind == "song" and rest ~= "") then
		return "song", {path = rest, name = ix.zonemusic.SongName(rest)}
	end

	return nil
end

--- For a notice: "station Radio New Vegas", "song Big Iron", "nothing".
function ix.zonemusic.Describe(value)
	local kind, what = ix.zonemusic.Resolve(value)

	if (not kind) then return "nothing" end

	return kind .. " " .. what.name
end

--[[
	Every choice the tools offer, as `{value, name}`. The names are what a
	tool panel's combo box sorts by, hence the dash on "None" - it puts
	nothing at the top, above the songs and the stations.
]]
function ix.zonemusic.Options()
	local out = {{value = "", name = "- None -"}}

	for _, station in ipairs(ix.radio.stations or {}) do
		out[#out + 1] = {value = "station:" .. station.id,
			name = "Station: " .. station.name}
	end

	for _, station in ipairs(ix.radio.stations or {}) do
		for _, song in ipairs(station.songs or {}) do
			out[#out + 1] = {value = "song:" .. song.path,
				name = string.format("Song: %s - %s", station.name, song.name)}
		end
	end

	for _, song in ipairs(ix.radio.themes or {}) do
		out[#out + 1] = {value = "song:" .. song.path,
			name = "Theme: " .. song.name}
	end

	return out
end

--- The music at a position: the smallest zone around it that has any.
function ix.zonemusic.At(position)
	local bestID, bestValue, bestVolume

	for _, entry in ipairs(ix.zones.At(position)) do
		local value = entry.area.properties and entry.area.properties.music

		if (not isstring(value) or value == "") then continue end

		local volume = ix.zones.Volume(entry.area)

		if (not bestVolume or volume < bestVolume) then
			bestID, bestValue, bestVolume = entry.id, value, volume
		end
	end

	return bestID, bestValue or ""
end

--- The smallest zone around a position, music or not.
local function Smallest(position)
	local best, bestVolume

	for _, entry in ipairs(ix.zones.At(position)) do
		local volume = ix.zones.Volume(entry.area)

		if (not bestVolume or volume < bestVolume) then
			best, bestVolume = entry.id, volume
		end
	end

	return best
end

--[[
	The zone a tool means: the one under the crosshair, else the one the
	holder is standing in. A zone has no surface, so pointing at its floor
	is what pointing at it means, and standing in it is the fallback for a
	zone whose floor is the map's void.
]]
function ix.zonemusic.Target(client, hitPosition)
	local id = hitPosition and Smallest(hitPosition)

	if (not id and IsValid(client)) then
		id = Smallest(client:GetPos() + client:OBBCenter())
	end

	return id
end
