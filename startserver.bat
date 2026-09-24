@echo off
title Fallout RP (dev)

REM ===========================================================================
REM  Fallout RP : development server launcher
REM
REM  Engine settings live in garrysmod/cfg/server.cfg, which srcds executes
REM  automatically. Only startup arguments belong in this file.
REM
REM  %~dp0 is this file's own folder, so the server still starts correctly
REM  if the project is moved or copied elsewhere.
REM ===========================================================================

REM  -console          run in the console window instead of the GUI
REM  -condebug         mirror all console output to garrysmod/console.log
REM  -tickrate 16      server simulation rate. GMod's default is 66; this is a
REM                    deliberate override. Tickrate can ONLY be set here, not
REM                    in server.cfg. The sv_min/maxcmdrate and updaterate
REM                    values in cfg/server.cfg are matched to it - change both
REM                    together or clients get clamped to a mismatched rate.
REM  +maxplayers 5     dev slot count; raise it in here, not in server.cfg
REM  +gamemode         our schema, NOT "helix" - loading helix directly errors
REM  +map              rp_utah_a, the patched local copy of workshop 2974325085
REM
REM  WORKSHOP CONTENT
REM  srcds does not download individual workshop addons - only a COLLECTION,
REM  and only with a Steam Web API key. Both arguments below are required
REM  together; either one alone does nothing:
REM
REM    -authkey <key>                    from steamcommunity.com/dev/apikey
REM    +host_workshop_collection <id>    the collection holding the map
REM
REM  Clients joining then download the same collection automatically, so no
REM  resource.AddWorkshop call is needed for anything in it.
REM
REM  Your own collection id goes below. Anything clients need has to be
REM  IN that collection - the map, and every content addon the server mounts
REM  by junction - or they join to a working map with missing models. The list
REM  is in _docs/09-content-map.md.

REM  ---------------------------------------------------------------------
REM  THIS RUNS AS-IS. Every addon the server mounts is already in
REM  garrysmod\addons as a real folder, so the line below boots a complete
REM  server with no setup at all.
REM
REM  What you do NOT get without a Steam Web API key: players who join will
REM  not download the workshop content, so they will see missing models and
REM  errors. To fix that, get a key at steamcommunity.com/dev/apikey, then
REM  comment out the first line below and uncomment the second, replacing the
REM  placeholder with your key. The two arguments are required together -
REM  either one on its own does nothing.
REM  ---------------------------------------------------------------------

"%~dp0srcds.exe" -console -condebug -tickrate 16 +maxplayers 5 +gamemode falloutrp +map rp_utah_a

REM  "%~dp0srcds.exe" -console -condebug -tickrate 16 +maxplayers 5 +host_workshop_collection YOUR_COLLECTION_ID +gamemode falloutrp +map rp_utah_a

REM  If the server exits or fails to boot, hold the window open so the error
REM  is readable instead of the console vanishing.
echo.
echo Server has stopped.
pause
