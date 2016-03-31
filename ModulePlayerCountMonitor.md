# Purpose #

> The Player Count Monitoring module is used to watch the amount of players on the server in realtime and then, if the amount of players is out of the current map's defined range and an action is specified, change the map to something which will support the current amount of players.

> Player Count Monitoring uses the same map and map group options as the [Player Limits module](ModulePlayerLimits.md) to define it's range of valid players. While it is not necessary to run Player Count Monitoring with the Player Limits module, it is recommended.


# List of CVars #

> The list of cvars for Player Count Monitoring is located in **cfg/sourcemod/umc-playercountmonitor.cfg**.
```
// Allows a map to appear in the vote more than once. This should be enabled if you want the same map in different categories to be distinct.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_umc_playerlimit_allowduplicates "1"

// Specifies how many slots in a vote are disabled to prevent accidental voting.
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "5.000000"
sm_umc_playerlimit_blockslots "0"

// File to use for Ultimate Mapchooser's map rotation.
// -
// Default: "umc_mapcycle.txt"
sm_umc_playerlimit_cyclefile "umc_mapcycle.txt"

// Time in seconds before the plugin will check to see if the current number of players is within the map's bounds.
// -
// Default: "240.0"
// Minimum: "0.000000"
sm_umc_playerlimit_delay "240.0"

// Adds a "Don't Change" option to votes.
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_umc_playerlimit_dontchange "1"

// Specifies how long a vote should be available for.
// -
// Default: "20"
// Minimum: "10.000000"
sm_umc_playerlimit_duration "20"

// Sound file (relative to sound folder) to play at the completion of a vote.
// -
// Default: ""
sm_umc_playerlimit_endsound ""

// Specifies what action to take if the vote doesn't reach the set theshold.
//  0 - Do Nothing,
//  1 - Perform Runoff Vote
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_umc_playerlimit_failaction "0"

// Specifies how many past map groups to exclude from Player Count Monitor votes.
// -
// Default: "0"
// Minimum: "0.000000"
sm_umc_playerlimit_groupexclude "0"

// Specifies how many past maps to exclude from Player Count Monitor votes.
// -
// Default: "3"
// Minimum: "0.000000"
sm_umc_playerlimit_mapexclude "3"

// Specifies what action to take when the number of players on the server is more than what the current map allows.
//  0 - Do Nothing,
//  1 - Pick a map, change to it,
//  2 - Pick a map, run a yes/no vote to change,
//  3 - Run a full mapvote, change to the winner.
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "3.000000"
sm_umc_playerlimit_maxaction "0"

// Specifies whether vote menu items are displayed in a random order.
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_umc_playerlimit_menuscrambled "0"

// Specifies what action to take when the number of players on the server is less than what the current map allows.
//  0 - Do Nothing,
//  1 - Pick a map, change to it,
//  2 - Pick a map, run a yes/no vote to change,
//  3 - Run a full mapvote, change to the winner.
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "3.000000"
sm_umc_playerlimit_minaction "0"

// Specifies whether the number of nominated maps appearing in the vote for a map group should be limited by the group's "maps_invote" setting.
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_umc_playerlimit_nominate_strict "0"

// Specifies what action to take if the runoff vote reaches the maximum amount of runoffs and the set threshold has not been reached.
//  0 - Do Nothing,
//  1 - Change Map to Winner
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_umc_playerlimit_runoff_failaction "0"

// Specifies the maximum number of maps to appear in a runoff vote.
//  1 or 0 sets no maximum.
// -
// Default: "0"
// Minimum: "0.000000"
sm_umc_playerlimit_runoff_max "0"

// If specified, this sound file (relative to sound folder) will be played at the beginning of a runoff vote. If not specified, it will use the normal vote start sound.
// -
// Default: ""
sm_umc_playerlimit_runoff_sound ""

// Specifies a maximum number of runoff votes to run for a vote.
//  0 disables runoff votes.
// -
// Default: "0"
// Minimum: "0.000000"
sm_umc_playerlimit_runoffs "0"

// Sound file (relative to sound folder) to play at the start of a vote.
// -
// Default: ""
sm_umc_playerlimit_startsound ""

// If the winning option has less than this percentage of total votes, a vote will fail and the action specified in "sm_umc_playerlimits_failaction" cvar will be performed.
// -
// Default: ".50"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_umc_playerlimit_threshold ".50"

// Controls vote type:
//  0 - Maps,
//  1 - Groups,
//  2 - Tiered Vote (vote for a group, then vote for a map from the group).
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "2.000000"
sm_umc_playerlimit_type "0"

// Specifies when to change the map after an action is taken due to too many or too little players.
//  0 - Change instantly,
//  1 - Change at the end of the round
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "1.000000"
sm_umc_playerlimit_voteaction "0"
```