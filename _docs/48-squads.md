# Squads

Phoenix's `plugins/squads` is forty-four shared lines and a HUD: a squad is a
name, a leader and a set of players, made with `/squadcreate`, left with
`/squadleave`, handed on with `/squadpromote`, and gone the moment the server
restarts. Inviting, kicking and "force to squad" hang off their hold-E menu,
with every check on the client.

This keeps that shape — the same commands, the same corner of the screen, the
same marks over people's heads — and does the rest properly.

| | |
|---|---|
| `schema/libs/sh_squad.lua` | rules, ranks, colours, the chat class, every command, the hold-E entries, logs |
| `schema/libs/sv_squad.lua` | the squads, saving them, invites, every change |
| `schema/libs/cl_squad.lua` | the HUD list, the markers, the invitation card, the binds |
| `schema/derma/cl_squad.lua` | the window (`/squad`) |

## What a squad is

```lua
{
    id = 3, name = "Rangers", color = 5, created = os.time(),
    leader = 42,                          -- a character id
    officers = {[17] = true},
    members = {[42] = true, [17] = true, [58] = true},
    names = {[42] = "Vault Dweller", ...},    -- for people who are offline
    levels = {[42] = 12, ...}
}
```

**People are character ids, never players or Steam ids.** A player is one
character at a time and a character is one person, so switching character
leaves the squad behind on the one that joined it — the only answer that does
not put a Legion officer in an NCR squad because somebody has two characters.

**It lasts.** Squads are saved (`ix.data`, key `squads`, schema-wide) on every
change and loaded the way every other persistent table here is — `LoadData`,
`PostLoadData`, and a ten-second timer for a reload that fires neither. A
member who logs off stays a member and is listed as *offline*; a squad with
nobody left in it is deleted. JSON turns numeric keys into strings, so every
character-id key is turned back into a number on the way in.

**Three ranks.** A leader, officers, members.

| can | member | officer | leader |
|---|---|---|---|
| leave, talk in `/sq` | yes | yes | yes |
| invite | | yes | yes |
| kick | | members | anybody |
| promote, demote, hand the squad on, rename, colour, disband | | | yes |

`/squadpromote` lifts a member to officer and an officer to leader (the old
leader becomes an officer). When a leader leaves or is removed, the squad goes
to an officer who is online, then any officer, then a member who is online,
then anybody.

**Squad mates know each other.** `IsCharacterRecognized` answers *yes* for two
characters in one squad, on both sides, and nothing else — anybody not in the
same squad falls through to the recognition plugin as before. Names in `/sq`
and on the HUD are therefore always real names.

## Commands

```
/squadcreate <name>       form one; you lead it
/squadleave               out
/squaddisband             gone, everybody out (leader)
/squadinvite <player>     an invitation, open for squadInviteTime seconds
/squadaccept              take it
/squaddecline             refuse it
/squadkick <player>       remove somebody
/squadpromote <player>    member -> officer, officer -> leader
/squaddemote <player>     officer -> member (leader)
/squadleader <player>     hand it over (leader)
/squadrename <name>       (leader)
/squadcolor <1-10>        (leader; /squadcolour works too)
/squad                    the window
/sq <text>                squad chat; /squadsay too

/forcesquad [name]        the person you are LOOKING AT, into the squad you
                          name or into your own          (squad.force)
/forcesquadremove         the person you are looking at, out of theirs
```

Every command body is in `sv_squad.lua` and answers with a sentence for the
person who typed it; nil means it worked and they have already been told. The
definitions are shared so the chatbox lists them.

Names are three to twenty-four characters, trimmed, single-spaced, no control
characters, unique case-insensitively.

**The force commands take whoever you are looking at**, which is what was
asked for and is also the right shape: staff sorting out a squad are stood in
front of the people involved. Size does not apply to a forced join. Both say
what happened in staff chat through `ix.admin.Announce`, so `~forcesquad` is
the silent form like every other moderation command, and both are logged
(`squadForce`).

## Holding E on somebody

Inviting is on the hold-E menu, where Phoenix put it — and so are kicking,
promoting and demoting, so a leader stood next to their squad never needs the
chat. `canSee` decides what is drawn from the client's copy of its own squad;
`OnCanRun` is the same function the command runs, on the server. See
`sh_interact.lua` for the menu itself.

| entry | shown when |
|---|---|
| Invite to squad | you are an officer or the leader and they are in no squad of yours |
| Kick from squad | they are in your squad and rank below you |
| Make squad officer / leader | you lead and they are a member / an officer |
| Demote to squad member | you lead and they are an officer |

## Invitations

`ix.squad.invites[characterID] = {squad, from, fromID, expires}`, memory
only. One open invitation per person; a second from the same squad while one
is open is refused, and one from another squad replaces it. Somebody already in
a squad has to leave it first — an invitation does not move people, which is
what `/forcesquad` is for.

The invited player gets a line in chat and **a card at the top of the screen**
with the two commands and a count-down. Not a popup: a popup takes the mouse,
and somebody asked into a squad is usually in the middle of something. The
card waits; `/squadaccept`, `fo_squad_accept` on a key, or the window's buttons
answer it. Being put in any squad clears it.

## The HUD

Client convars, saved:

```
fo_squad_hud 1          the list
fo_squad_hud_x 0.01     where it sits, as fractions of the screen
fo_squad_hud_y 0.32
fo_squad_markers 1      the marks over squad mates' heads
```

The list is the squad's name in its colour with a rule under it, then one row
per person, leader first: their level in a box of the colour, their name with
★ for the leader and ☆ for an officer, a health bar, and **how far away they
are in metres** — which is what a list in the corner is for. Somebody offline
is grey and says so; somebody dead has a red bar and says DOWN.

Over every squad mate's head: **a point the size of how far away they are.**
Text does not scale with distance, so a name over somebody two hills away was
as big as one over somebody beside you. The point is a triangle drawn at a size
that shrinks from 600 to 2,500 units; the name is drawn smaller past 600 but
**always drawn**, because a callout needs it; only the health bar goes with
distance, shown up close where it can be read. Not on yourself.

The list and the card use fonts of their own (`ixSquadTitle`, `ixSquadName`,
`ixSquadSmall`, `ixSquadMarker`, `ixSquadMarkerFar`), scaled with the screen
and rebuilt when the resolution changes. The first version drew names in
`UI_Bold`, which is a heading size, and the bar ran through the letters.

`fo_squad_hud_y` defaults below the ticket cards' corner so staff in a squad
see both.

## The window

`/squad`, or `fo_squad_menu` on a key. Rows are people, with what a row offers
depending on who is looking — a leader sees PROMOTE / DEMOTE / LEADER / KICK,
an officer sees KICK on members. The bottom bar has INVITE (a name, or part of
one), RENAME, the colour (cycles through the ten), LEAVE and DISBAND, the last
two behind a confirmation. Not in a squad, the window is a name box and
CREATE, plus ACCEPT / DECLINE when an invitation is waiting.

The window can act on somebody who is **offline**, which a player-name command
cannot: everything it does goes through one message, `ixSquadAct`, with an
action name and a character id, dispatched on the server to the same function
the command would have run. There is no second permission check to get out of
step.

## Colours

Ten, by index, so the save is a number and a leader picks from a list that all
reads well on the HUD: Amber, Ember, Rust, Moss, Pip, Sky, Violet, Rose, Bone,
Steel. A new squad takes the next one along from its id. `ix.squad.ColorOf`
answers safely for a bad index.

## Hooks for later

`SquadCreated(squad, client)`, `SquadDeleted(squad)`,
`SquadMemberAdded(squad, id, client)`, `SquadMemberRemoved(squad, id, name)`
on the server; `SquadUpdated` on the client whenever `ix.squad.mine` changes.
Phoenix's *Natural Leader* and *Concentrate Fire* perks read the squad and its
leader; `ix.squad.Get(client)`, `ix.squad.Rank(client)`, `ix.squad.Same(a, b)`
and `ix.squad.Online(squad)` are what those will want.

## Settings

| | |
|---|---|
| `squadEnabled` | the switch (creating; existing squads are left alone) |
| `squadMaxSize` | people per squad (8); a forced join ignores it |
| `squadInviteTime` | seconds an invitation stays open (30) |

Permission: `squad.force` (Staff).

Logs: `squadCreate`, `squadDisband`, `squadJoin`, `squadLeave`, `squadKick`,
`squadRank`, `squadForce`.
