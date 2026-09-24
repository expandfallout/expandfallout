--[[
	Taking a capturable workbench.

	    press E      told what it costs, and nothing happens
	    press E again  the capture starts, and everyone who cares is told
	    stand there  a bar at the bottom of the screen counts it down
	    walk away    it stops, and the progress is gone

	TWO PRESSES, DELIBERATELY. The first is a warning and does nothing at all.
	Starting a fight is not something to do by walking into a prop and holding
	the use key out of habit, and a confirmation you have to mean is the
	cheapest way to make the decision a decision. Phoenix start capturing on
	the first press; the person who finds out afterwards is the one who did not
	want to.

	IT ANNOUNCES ITSELF. The holder is told the moment somebody starts, because
	a capture nobody can contest is just a timer. That is the whole of "you
	will be KOS" - not a flag on the character, but the fact that the people
	who own the thing now know your name and where you are standing.

	PROGRESS IS NOT SAVED. A capture is a thing you are doing right now; it
	lives on the record in memory and dies with a disconnect, a death, a map
	change or a step too far. Only the RESULT - who holds it - is written down.
]]

if (not SERVER) then return end

util.AddNetworkString("ixBenchCapture")

--- How long a warning stands before you have to read it again.
local WARN_TIME = 12

--- How far you may drift from a bench before the capture drops.
local CAPTURE_RANGE = 150

--------------------------------------------------------------------------------
-- Talking to the person doing it
--------------------------------------------------------------------------------

--[[
	Start, update or stop the bar on somebody's screen.

	One message with a length of zero means stop, so the client needs no second
	netstring and cannot end up showing a bar for a capture that has ended.
]]
local function SendBar(client, name, length, finish)
	if (not IsValid(client)) then return end

	net.Start("ixBenchCapture")
		net.WriteString(name or "")
		net.WriteUInt(math.Clamp(math.floor(length or 0), 0, 600), 16)
		net.WriteFloat(finish or 0)
	net.Send(client)
end

--- Everybody who holds this bench, so a capture cannot happen unopposed.
local function Holders(record)
	local out = {}

	if (not record.owner) then return out end

	for _, client in ipairs(player.GetAll()) do
		if (ix.bench.Owns(client, record)) then
			out[#out + 1] = client
		end
	end

	return out
end

--------------------------------------------------------------------------------
-- The capture
--------------------------------------------------------------------------------

function ix.bench.StopCapture(record, reason)
	local capture = record.capture

	if (not capture) then return end

	record.capture = nil

	if (IsValid(capture.client)) then
		SendBar(capture.client, "", 0, 0)

		if (reason) then
			capture.client:Notify(reason)
		end
	end

	ix.bench.Refresh(record)
end

--[[
	Begin taking it. Returns `true`, or `false, reason`.

	The population rule applies here as much as to using one: a bench nobody
	may open is not a bench worth taking on an empty server, and letting it be
	captured anyway would be a way to own the thing before anybody could
	contest it.
]]
function ix.bench.BeginCapture(client, record)
	local definition = ix.bench.TypeOf(record)

	if (not definition or not definition.capturable) then
		return false, "This bench cannot be taken."
	end

	local character = client:GetCharacter()

	if (not character) then return false, "No character." end

	local enough, why = ix.bench.HasPopulation(definition)

	if (not enough) then return false, why end

	if (record.capture) then
		return false, "Somebody is already taking this."
	end

	if (ix.bench.Owns(client, record)) then
		return false, "You already hold this."
	end

	local length = math.Clamp(math.floor(definition.captureTime or 30), 5, 600)

	record.capture = {
		client = client,
		character = character:GetID(),
		length = length,
		finish = CurTime() + length
	}

	SendBar(client, definition.name or "Workbench", length,
		record.capture.finish)

	--[[
		The holder is told, by name and by place. This is the part that makes
		taking one a decision rather than an errand - see the note at the top.
	]]
	for _, holder in ipairs(Holders(record)) do
		holder:Notify(string.format("%s is taking your %s!",
			character:GetName(), definition.name or "workbench"))
	end

	ix.bench.Refresh(record)
	ix.log.Add(client, "benchCaptureStart", definition.name or "a workbench")

	return true
end

--- It ran its time. Hand it over.
local function FinishCapture(record)
	local capture = record.capture
	local client = capture and capture.client
	local definition = ix.bench.TypeOf(record)

	record.capture = nil

	if (not IsValid(client) or not definition) then
		ix.bench.Refresh(record)

		return
	end

	local character = client:GetCharacter()

	if (not character or character:GetID() ~= capture.character) then
		ix.bench.Refresh(record)

		return
	end

	local losers = Holders(record)

	record.owner = ix.bench.CaptureFor(character)

	--[[
		A NEW CAPTURE OPENS IT AGAIN. `lockedBy` is the last holder's decision
		about their own faction, and it has no business surviving the bench
		changing hands - see `/benchfactiontoggle`.
	]]
	record.lockedBy = nil

	SendBar(client, "", 0, 0)

	client:Notify(string.format("%s is yours%s.", definition.name
		or "The workbench", record.owner.faction and " - and your faction's"
		or ""))

	for _, holder in ipairs(losers) do
		if (holder ~= client) then
			holder:Notify(string.format("You have lost the %s.",
				definition.name or "workbench"))
		end
	end

	ix.bench.Refresh(record)
	ix.bench.Save()
	ix.bench.Flush()

	ix.log.Add(client, "benchCaptured", definition.name or "a workbench",
		record.owner.name or "themselves")
end

--[[
	Watched every tick rather than trusted to a timer.

	A timer would have to be cancelled from every place a capture can end -
	death, disconnect, walking off, the bench being removed - and Phoenix's
	own workbench timers open with a validity check and a `timer.Remove`
	because that list is never complete. One loop over the records that already
	exist cannot get out of step with itself.
]]
timer.Create("ixBenchCaptureTick", 0.25, 0, function()
	for _, record in pairs(ix.bench.list) do
		local capture = record.capture

		if (not capture) then continue end

		local client = capture.client
		local character = IsValid(client) and client:GetCharacter()

		if (not IsValid(client) or not client:Alive() or not character
		or character:GetID() ~= capture.character) then
			ix.bench.StopCapture(record)

			continue
		end

		if (not IsValid(record.entity)) then
			ix.bench.StopCapture(record, "The workbench is gone.")

			continue
		end

		if (client:GetPos():Distance(record.entity:GetPos())
		> CAPTURE_RANGE) then
			ix.bench.StopCapture(record, "You moved too far away.")

			continue
		end

		if (capture.finish <= CurTime()) then
			FinishCapture(record)
		end
	end
end)

--------------------------------------------------------------------------------
-- Pressing E
--------------------------------------------------------------------------------

--[[
	What `ENT:Use` does on a capturable bench nobody holds, or somebody else
	does.

	Returns true when it handled the press, so the caller knows not to open the
	window as well.
]]
function ix.bench.UseCapture(client, record)
	local definition = ix.bench.TypeOf(record)

	if (not definition or not definition.capturable) then return false end

	--[[
		NO ADMIN BYPASS HERE, and there was one - it let an admin straight
		through to the window on any unheld bench, on the reasoning that they
		have to be able to look inside one to check it works.

		That made the feature untestable by the only people who can place a
		bench: pressing E as an admin opened the menu and no capture ever
		started, which reads as capturing being broken rather than as being
		skipped. Admins already have a way in that does not touch ownership -
		the C menu's "[ADMIN] Open this bench" - so the bypass bought nothing
		and hid the whole system from the person building it.
	]]
	if (ix.bench.Owns(client, record)) then return false end

	if (record.capture) then
		client:Notify(record.capture.client == client
			and "You are already taking this."
			or "Somebody else is taking this.")

		return true
	end

	--[[
		THE FIRST PRESS ONLY WARNS. It is stored per player per bench and it
		expires, so a warning read a minute ago does not become consent now.
	]]
	client.ixBenchWarned = client.ixBenchWarned or {}

	if ((client.ixBenchWarned[record.id] or 0) < CurTime()) then
		client.ixBenchWarned[record.id] = CurTime() + WARN_TIME

		client:Notify(string.format("Taking this makes you a target - %s will "
			.. "be told who you are. Press E again to start.",
			record.owner and ix.bench.OwnerName(record) or "everyone here"))

		return true
	end

	client.ixBenchWarned[record.id] = nil

	local ok, reason = ix.bench.BeginCapture(client, record)

	if (not ok) then
		client:Notify(reason)
	end

	return true
end

--[[
	Give one back to nobody. Admin only, through `/benchrelease`.

	Separate from removing the bench because losing the thing and losing who
	holds it are different mistakes to want to undo.
]]
function ix.bench.Release(record)
	ix.bench.StopCapture(record)

	record.owner = nil
	record.lockedBy = nil

	ix.bench.Refresh(record)
	ix.bench.Save()
	ix.bench.Flush()
end

ix.log.AddType("benchCaptureStart", function(client, name)
	return string.format("%s started taking %s.", client:Name(), name)
end)

ix.log.AddType("benchCaptured", function(client, name, owner)
	return string.format("%s captured %s for %s.", client:Name(), name, owner)
end)
