--[[
	The stations, and the main-menu playlist.

	Phoenix's `plugins/radio` keeps a list of stations, each a list of songs
	with a name and a sound path, plus physical radio props, a broadcaster
	and a `/broadcast` channel. This is the first part of that: the stations
	themselves, as data, read by the F1 menu's RADIO tab (`cl_radio.lua`)
	and by nothing else yet. Every path below was listed from
	`phoenix_sound_content` on this server; nothing is guessed.

	SHARED so a server-side radio prop can read the same lists later. Only
	the client plays anything.
]]

ix.radio = ix.radio or {}
ix.radio.stations = ix.radio.stations or {}
ix.radio.byID = ix.radio.byID or {}

local BASE = "phoenix/music/"

--- "mus_fo1_city_of_the_dead" -> "City Of The Dead".
local function Title(file)
	local name = string.gsub(file, "%.mp3$", "")

	name = string.gsub(name, "^mus_fo%d_", "")
	name = string.gsub(name, "^mos_fo%d_", "")
	name = string.gsub(name, "^mus_", "")
	name = string.gsub(name, "_", " ")

	return string.gsub(name, "(%a)([%w']*)", function(first, rest)
		return string.upper(first) .. rest
	end)
end

local function Songs(folder, files)
	local out = {}

	for _, entry in ipairs(files) do
		local file, title = entry, nil

		if (istable(entry)) then file, title = entry[1], entry[2] end

		out[#out + 1] = {path = BASE .. folder .. "/" .. file,
			name = title or Title(file)}
	end

	return out
end

function ix.radio.Register(id, name, blurb, songs)
	local station = {id = id, name = name, blurb = blurb, songs = songs}

	if (ix.radio.byID[id]) then
		for index, other in ipairs(ix.radio.stations) do
			if (other.id == id) then ix.radio.stations[index] = station end
		end
	else
		ix.radio.stations[#ix.radio.stations + 1] = station
	end

	ix.radio.byID[id] = station

	return station
end

ix.radio.Register("newvegas", "Radio New Vegas",
	"Mr. New Vegas, and the Mojave's own songbook.", Songs("radio/nv", {
	"mus_aint_that_a_kick_in_the_head.mp3", "mus_american_swing.mp3",
	"mus_big_iron.mp3", "mus_blue_moon.mp3", "mus_blues_for_you.mp3",
	"mus_cobwebs_and_rainbows.mp3", "mus_goin_under.mp3",
	"mus_hallo_mister_x.mp3", "mus_happy_times.mp3",
	"mus_heartaches_by_the_number.mp3", "mus_home_on_the_wastes.mp3",
	"mus_im_movin_out.mp3", "mus_im_so_blue.mp3",
	"mus_in_the_shadow_of_the_valley.mp3", "mus_its_a_sin.mp3",
	"mus_its_a_sin_to_tell_a_lie.mp3", "mus_jazz_blues_gt.mp3",
	"mus_jazz_club_blues.mp3", "mus_jingle_jangle_jingle.mp3",
	"mus_joe_cool.mp3", "mus_johnny_guitar.mp3", "mus_lazy_day_blues.mp3",
	"mus_lets_ride_into_the_sunset_together.mp3", "mus_lone_star.mp3",
	"mus_love_me_as_though_no_tomorrow.mp3", "mus_mad_about_the_boy.mp3",
	"mus_manhattan.mp3", "mus_roundhouse_rock.mp3", "mus_sit_and_dream.mp3",
	"mus_sleepy_town_blues.mp3", "mus_slow_bounce.mp3", "mus_slow_sax.mp3",
	"mus_somethings_gotta_give.mp3", "mus_stars_of_the_midnight_range.mp3",
	"mus_strahlende_trompete.mp3", "mus_streets_of_new_reno.mp3",
	"mus_von_spanien_nach_s_damerika.mp3",
	"mus_where_have_you_been_all_my_life.mp3", "mus_why_dont_you_do_right.mp3"
}))

ix.radio.Register("gnr", "Galaxy News Radio",
	"Three Dog's playlist, out of the Capital Wasteland.", Songs("radio/fo3", {
	"mos_fo3_rhythm_for_you.mp3", "mus_fo3_a_wonderful_guy.mp3",
	"mus_fo3_anything_goes.mp3", "mus_fo3_boogie_man.mp3",
	"mus_fo3_butcher_pete.mp3", "mus_fo3_civilization.mp3",
	"mus_fo3_crazy_he_calls_me.mp3", "mus_fo3_easy_living.mp3",
	"mus_fo3_fox_boggie.mp3", "mus_fo3_happy_times.mp3",
	"mus_fo3_i_dont_want_to_set_the_world_on_fire.mp3",
	"mus_fo3_im_tickled_pink.mp3",
	"mus_fo3_into_each_life_some_rain_must_fall.mp3",
	"mus_fo3_jazzy_interlude.mp3", "mus_fo3_jolly_days.mp3",
	{"mus_fo3_lets go sunning.mp3", "Let's Go Sunning"}, "mus_fo3_maybe.mp3",
	"mus_fo3_mighty_mighty_man.mp3", "mus_fo3_swing_doors.mp3",
	"mus_fo3_way_back_home.mp3"
}))

ix.radio.Register("diamondcity", "Diamond City Radio",
	"Travis, the Commonwealth, and everything Magnolia will not sing.",
	Songs("radio/fo4", {
	{"bettyhutton_hesademon.mp3", "Betty Hutton - He's A Demon, He's A Devil, He's A Doll"},
	{"bettyhutton_itsaman.mp3", "Betty Hutton - It's A Man"},
	{"bigmaybelle_wholelottashakingoinon.mp3", "Big Maybelle - Whole Lotta Shakin' Goin' On"},
	{"billieholiday_crazyhecallsme.mp3", "Billie Holiday - Crazy He Calls Me"},
	{"billieholiday_easyliving.mp3", "Billie Holiday - Easy Living"},
	{"billywardandthedominoes_sixtyminuteman.mp3", "Billy Ward - Sixty Minute Man"},
	{"bingcrosby_accentuatethepositive.mp3", "Bing Crosby - Accentuate The Positive"},
	{"bingcrosby_pistolpackinmama.mp3", "Bing Crosby - Pistol Packin' Mama"},
	{"bobcrosby_dearheartsandgentlepeople.mp3", "Bob Crosby - Dear Hearts And Gentle People"},
	{"bobcrosby_happytimes.mp3", "Bob Crosby - Happy Times"},
	{"bobcrosby_waybackhome.mp3", "Bob Crosby - Way Back Home"},
	{"coleporter_anythinggoes.mp3", "Cole Porter - Anything Goes"},
	{"connieallen_rocket69.mp3", "Connie Allen - Rocket 69"},
	{"dannykaye_civilization.mp3", "Danny Kaye - Civilization"},
	{"dion_thewanderer.mp3", "Dion - The Wanderer"},
	{"ellafitzgerald_intoeachlife.mp3", "Ella Fitzgerald - Into Each Life Some Rain Must Fall"},
	{"ellafitzgerald_undecided.mp3", "Ella Fitzgerald - Undecided"},
	{"eltonbritt_uraniumfever.mp3", "Elton Britt - Uranium Fever"},
	{"frankiecarle_onemoretomorrow.mp3", "Frankie Carle - One More Tomorrow"},
	{"johnnymercer_personality.mp3", "Johnny Mercer - Personality"},
	{"louisjordan_keepaknockin.mp3", "Louis Jordan - Keep A Knockin'"},
	{"natkingcole_orangecoloredsky.mp3", "Nat King Cole - Orange Colored Sky"},
	{"raysmith_rightbehindyoubaby.mp3", "Ray Smith - Right Behind You, Baby"},
	{"roybrown_goodrockintonight.mp3", "Roy Brown - Good Rockin' Tonight"},
	{"roybrown_mightymightyman.mp3", "Roy Brown - Mighty Mighty Man"},
	{"sheldonallman_crawloutthroughthefallout.mp3", "Sheldon Allman - Crawl Out Through The Fallout"},
	{"skeeterdavis_theendoftheworld.mp3", "Skeeter Davis - The End Of The World"},
	{"texbeneke_awonderfulguy.mp3", "Tex Beneke - A Wonderful Guy"},
	{"thefivestars_atombombbaby.mp3", "The Five Stars - Atom Bomb Baby"},
	{"theinkspots_idontwanttoset.mp3", "The Ink Spots - I Don't Want To Set The World On Fire"},
	{"theinkspots_itsalloverbutthecrying.mp3", "The Ink Spots - It's All Over But The Crying"},
	{"theinkspots_maybe.mp3", "The Ink Spots - Maybe"},
	{"thethreesuns_worryworryworry.mp3", "The Three Suns - Worry, Worry, Worry"},
	{"warrensmith_uraniumrock.mp3", "Warren Smith - Uranium Rock"},
	{"wynoniegarris_grandmaplaysthenumbers.mp3", "Wynonie Harris - Grandma Plays The Numbers"}
}))

ix.radio.Register("wasteland", "Old World Frequencies",
	"No voices, no songs - the scores of the first two wars.",
	Songs("radio/fo1", {
	"mus_fo1_acolytesofthenewgod.mp3", "mus_fo1_atraderslife.mp3",
	"mus_fo1_cityoflostangels.mp3", "mus_fo1_cityofthedead.mp3",
	"mus_fo1_desertwind.mp3", "mus_fo1_flameoftheancientworld.mp3",
	"mus_fo1_followerscredo.mp3", "mus_fo1_industrialjunk.mp3",
	"mus_fo1_metallicmonks.mp3", "mus_fo1_moribundworld.mp3",
	"mus_fo1_radiationstorm.mp3", "mus_fo1_secondchance.mp3",
	"mus_fo1_thevaultofthefuture.mp3", "mus_fo1_undergroundtrouble.mp3",
	"mus_fo1_vatsofgoo.mp3"
}))

do
	local station = ix.radio.byID.wasteland

	for _, song in ipairs(Songs("radio/fo2", {
		"mus_fo2_arroyo.mp3", "mus_fo2_modoc.mp3", "mus_fo2_newreno.mp3",
		"mus_fo2_redding.mp3", "mus_fo2_sanfrancisco.mp3",
		"mus_fo2_vaultcity.mp3", "mus_fo2_worldmap1.mp3", "mus_fo2_worldmap2.mp3"
	})) do
		station.songs[#station.songs + 1] = song
	end
end

--[[
	What the main menu plays: the title themes. Phoenix's menu had a list
	saved to a JSON file the player could add to; this is the list, and the
	player picks from it or lets it shuffle.
]]
ix.radio.themes = Songs("themes", {
	{"mus_maintheme.mp3", "Fallout 3 - Main Theme"},
	{"falloutnv_theme.mp3", "Fallout: New Vegas - Main Theme"},
	{"f4nv_theme.mp3", "Fallout 4: New Vegas - Main Theme"},
	{"mus_special_maintheme.mp3", "Fallout 4 - Main Theme"},
	{"mus_special_51_maintheme.mp3", "Fallout 76 - Main Theme"},
	{"mus_special_wastelanders_maintheme.mp3", "Fallout 76 - Wastelanders"},
	{"mus_special_steeldawn_maintheme.mp3", "Fallout 76 - Steel Dawn"},
	{"mus_special_bos_maintheme.mp3", "Fallout 76 - Brotherhood of Steel"},
	{"mus_76_special_maintheme_nuka.mp3", "Fallout 76 - Nuka-World"},
	{"mus_76_special_maintheme_bluemoon.mp3", "Fallout 76 - Once In A Blue Moon"},
	{"mus_76_special_mainmenu_thepitt.mp3", "Fallout 76 - The Pitt"},
	{"mus_76_special_mainmenu_atlantic_city.mp3", "Fallout 76 - Atlantic City"},
	{"mus_76_special_mainmenu_invaders.mp3", "Fallout 76 - Invaders From Beyond"},
	{"mus_76_special_mainmenu_storm.mp3", "Fallout 76 - Storm"},
	{"mus_76_special_mainmenu_zetan.mp3", "Fallout 76 - Zetan"},
	{"resurgence_of_hope.mp3", "Resurgence Of Hope"}
})
