# Radio, menu music, and the Perks tab

## The character menu's music

Helix's character menu plays Half-Life 2's second song. `libs/cl_music.lua`
replaces `ixCharMenu:PlayMusic` on the registered panel table — so every menu
made from then on asks it instead — and adds `derma/cl_musicplayer.lua` to
the menu when it is created: song name, previous / play-pause / next, shuffle
or in order, ON/OFF, and a list to pick from. The list is the sixteen title themes
(`ix.radio.themes` in `libs/sh_radio.lua`, every one listed from the disk)
**followed by every station's songs** — Phoenix's menu list had Sinatra and
Marty Robbins beside the themes, and so does this. Phoenix's player did the same at the same corner of their menu.

Client convars, saved: `fo_menu_music` (1), `fo_menu_shuffle` (1),
`fo_menu_volume` (0.5), `fo_menu_track` (the last song, picked up next time).
The music stops when the menu goes.

## The RADIO tab

Phoenix's `plugins/radio` keeps stations as lists of songs, plus physical
radios, a broadcaster and `/broadcast`. This is the first part of that: the
stations (`libs/sh_radio.lua`, shared so a radio prop can read them later),
the F1 menu's RADIO tab (`derma/cl_radio.lua`) and the playback
(`libs/cl_radio.lua`).

| station | songs | from |
|---|---|---|
| Radio New Vegas | 39 | `music/radio/nv` |
| Galaxy News Radio | 20 | `music/radio/fo3` |
| Diamond City Radio | 35 | `music/radio/fo4`, named by artist |
| Old World Frequencies | 23 | `music/radio/fo1` and `fo2` — the scores, no voices |

TUNE a station and it plays in the background, a random song after another,
until OFF — and again next session, because the choice is a saved convar
(`fo_radio_station`, `fo_radio_volume`). It goes quiet while the character
menu is up, which has music of its own. `fo_radio_next` / `fo_radio_off` from
the console.

## The PERKS tab

`derma/cl_perks.lua` is the place, not the perks — a tab so the menu has its
shape before the system does. What was read of Phoenix's is in
[52-perks.md](52-perks.md).

## Music by zone

The same station lists feed `libs/sh_zonemusic.lua`: a zone can be set to a
station, a song or nothing, with the Zone Music tool. It plays under the radio
and under the menu music, at its own volume. See
[34-world.md](34-world.md#music).
