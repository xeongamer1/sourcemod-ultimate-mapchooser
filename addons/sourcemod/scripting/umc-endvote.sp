/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                             Ultimate Mapchooser - End of Map Vote                             *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
 
#pragma semicolon 1

#include <sourcemod>
#include <umc-core>
#include <umc_utils>
#include <umc-endvote>

#undef REQUIRE_PLUGIN
#include <mapchooser>

//Auto update
#include <updater>
#if AUTOUPDATE_DEV
    #define UPDATE_URL "http://www.ccs.neu.edu/home/steell/sourcemod/ultimate-mapchooser/dev/updateinfo-umc-endvote.txt"
#else
    #define UPDATE_URL "http://www.ccs.neu.edu/home/steell/sourcemod/ultimate-mapchooser/updateinfo-umc-endvote.txt"
#endif

//Plugin Information
public Plugin:myinfo =
{
    name        = "[UMC] End of Map Vote",
    author      = "Steell",
    description = "Extends Ultimate Mapchooser to allow End of Map Votes.",
    version     = PL_VERSION,
    url         = "http://forums.alliedmods.net/showthread.php?t=134190"
};

//Changelog:
/*
3.3.2 (3/4/2012)
Updated UMC Logging functionality
Added ability to view the current mapcycle of all modules
*/

        ////----CONVARS-----/////
new Handle:cvar_filename             = INVALID_HANDLE;
new Handle:cvar_scramble             = INVALID_HANDLE;
new Handle:cvar_vote_time            = INVALID_HANDLE;
new Handle:cvar_strict_noms          = INVALID_HANDLE;
new Handle:cvar_runoff               = INVALID_HANDLE;
new Handle:cvar_runoff_sound         = INVALID_HANDLE;
new Handle:cvar_runoff_max           = INVALID_HANDLE;
new Handle:cvar_vote_allowduplicates = INVALID_HANDLE;
new Handle:cvar_vote_threshold       = INVALID_HANDLE;
new Handle:cvar_fail_action          = INVALID_HANDLE;
new Handle:cvar_runoff_fail_action   = INVALID_HANDLE;
new Handle:cvar_endvote              = INVALID_HANDLE;
new Handle:cvar_extend_rounds        = INVALID_HANDLE;
new Handle:cvar_extend_frags         = INVALID_HANDLE;
new Handle:cvar_extend_time          = INVALID_HANDLE;
new Handle:cvar_extensions           = INVALID_HANDLE;
new Handle:cvar_start_frags          = INVALID_HANDLE;
new Handle:cvar_start_time           = INVALID_HANDLE;
new Handle:cvar_start_rounds         = INVALID_HANDLE;
new Handle:cvar_vote_mem             = INVALID_HANDLE;
new Handle:cvar_vote_type            = INVALID_HANDLE;
new Handle:cvar_vote_startsound      = INVALID_HANDLE;
new Handle:cvar_vote_endsound        = INVALID_HANDLE;
new Handle:cvar_vote_catmem          = INVALID_HANDLE;
new Handle:cvar_vote_roundend        = INVALID_HANDLE;
new Handle:cvar_flags                = INVALID_HANDLE;
new Handle:cvar_delay                = INVALID_HANDLE;
        ////----/CONVARS-----/////

//Mapcycle KV
new Handle:map_kv = INVALID_HANDLE;
new Handle:umc_mapcycle = INVALID_HANDLE;

//Memory queues. Used to store the previously played maps.
new Handle:vote_mem_arr    = INVALID_HANDLE;
new Handle:vote_catmem_arr = INVALID_HANDLE;

//Timers
new Handle:vote_timer = INVALID_HANDLE; //Timer which handles end-of-map vote based off of time
                                        //remaining.

//Limit Cvars
new Handle:cvar_maxrounds = INVALID_HANDLE; //Round limit cvar
new Handle:cvar_fraglimit = INVALID_HANDLE; //Frag limit cvar
new Handle:cvar_winlimit  = INVALID_HANDLE; //Win limit cvar

//Used to hold original values for the limit cvars, in order to reset them to the correct value when
//the map changes.
//new maxrounds_mem;
//new fraglimit_mem;
//new bool:catch_change = false; //Flag used to ignore changes to the limit cvars.

//Flags
new bool:timer_alive;      //Is the time-based vote timer ticking?
new bool:vote_enabled;     //Are we able to run a vote? Means that the timer is running.
new bool:vote_roundend;    //Are we going to start a vote when this round is over?
new bool:vote_completed;   //Has an end of map vote been completed?

//Keeps track of the time before the end-of-map vote starts.
new Float:vote_delaystart;

//Counts the rounds.
new round_counter = 0;

//Counts how many times each team has won.
#define MAXTEAMS 10
new team_wincounts[MAXTEAMS];

//Counts the number of available extensions.
new extend_counter;

//Sounds to be played at the start and end of votes.
new String:vote_start_sound[PLATFORM_MAX_PATH], String:vote_end_sound[PLATFORM_MAX_PATH],
    String:runoff_sound[PLATFORM_MAX_PATH];
    
    
/* Forwards */
new Handle:time_update_forward  = INVALID_HANDLE;
new Handle:round_update_forward = INVALID_HANDLE;
new Handle:win_update_forward   = INVALID_HANDLE;
new Handle:frag_update_forward  = INVALID_HANDLE;
new Handle:time_tick_forward    = INVALID_HANDLE;
new Handle:round_tick_forward   = INVALID_HANDLE;
new Handle:win_tick_forward     = INVALID_HANDLE;
new Handle:frag_tick_forward    = INVALID_HANDLE;


//TODO:
//  -Test round trigger in CSS
//  -Edit cvar descriptions so that they actually fit.


//************************************************************************************************//
//                                        SOURCEMOD EVENTS                                        //
//************************************************************************************************//

//Called before the plugin loads, sets up our natives.
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    RegPluginLibrary("mapchooser");

    CreateNative("HasEndOfMapVoteFinished", Native_CheckVoteDone);
    CreateNative("EndOfMapVoteEnabled", Native_EndOfMapVoteEnabled);
    
    RegPluginLibrary("umc-endvote");
    
    return APLRes_Success;
}


//Called when the plugin is finished loading.
public OnPluginStart()
{
    cvar_delay = CreateConVar(
        "sm_umc_endvote_roundend_delaystart",
        "0",
        "Delays the vote by the number of seconds specified for votes that are triggered by mp_maxrounds or mp_winlimit.",
        0, true, 0.0
    );
    
    cvar_flags = CreateConVar(
        "sm_umc_endvote_adminflags",
        "",
        "Specifies which admin flags are necessary for a player to participate in a vote. If empty, all players can participate."
    );

    cvar_vote_roundend = CreateConVar(
        "sm_umc_endvote_onroundend",
        "0",
        "Determines whether End of Map Votes should be delayed until the end of the round in which they were triggered.",
        0, true, 0.0, true, 1.0
    );

    cvar_fail_action = CreateConVar(
        "sm_umc_endvote_failaction",
        "0",
        "Specifies what action to take if the vote doesn't reach the set theshold.\n 0 - Do Nothing,\n 1 - Perform Runoff Vote",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_fail_action = CreateConVar(
        "sm_umc_endvote_runoff_failaction",
        "0",
        "Specifies what action to take if the runoff vote reaches the maximum amount of runoffs and the set threshold has not been reached.\n 0 - Do Nothing,\n 1 - Change Map to Winner",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_max = CreateConVar(
        "sm_umc_endvote_runoff_max",
        "0",
        "Specifies the maximum number of maps to appear in a runoff vote.\n 1 or 0 sets no maximum.",
        0, true, 0.0
    );

    /*cvar_vote_flags = CreateConVar(
        "sm_umc_endvote_adminflags",
        "",
        "String of admin flags required for players to be able to vote in end-of-map\nvotes. If no flags are specified, all players can vote."
    );*/

    cvar_vote_allowduplicates = CreateConVar(
        "sm_umc_endvote_allowduplicates",
        "1",
        "Allows a map to appear in the vote more than once. This should be enabled if you want the same map in different categories to be distinct.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_vote_threshold = CreateConVar(
        "sm_umc_endvote_threshold",
        "0",
        "If the winning option has less than this percentage of total votes, a vote will fail and the action specified in \"sm_umc_endvote_failaction\" cvar will be performed.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff = CreateConVar(
        "sm_umc_endvote_runoffs",
        "0",
        "Specifies a maximum number of runoff votes to run for any given vote.\n 0 = unlimited.",
        0, true, 0.0
    );
    
    cvar_runoff_sound = CreateConVar(
        "sm_umc_endvote_runoff_sound",
        "",
        "If specified, this sound file (relative to sound folder) will be played at the beginning of a runoff vote. If not specified, it will use the normal vote start sound."
    );
    
    cvar_vote_catmem = CreateConVar(
        "sm_umc_endvote_groupexclude",
        "0",
        "Specifies how many past map groups to exclude from the end of map vote.",
        0, true, 0.0
    );
    
    cvar_vote_startsound = CreateConVar(
        "sm_umc_endvote_startsound",
        "",
        "Sound file (relative to sound folder) to play at the start of an end-of-map vote."
    );
    
    cvar_vote_endsound = CreateConVar(
        "sm_umc_endvote_endsound",
        "",
        "Sound file (relative to sound folder) to play at the completion of an end-of-map vote."
    );
    
    cvar_strict_noms = CreateConVar(
        "sm_umc_endvote_nominate_strict",
        "0",
        "Specifies whether the number of nominated maps appearing in the vote for a map group should be limited by the group's \"maps_invote\" setting.",
        0, true, 0.0, true, 1.0
    );

    cvar_extend_rounds = CreateConVar(
        "sm_umc_endvote_extend_roundstep",
        "5",
        "Specifies how many more rounds each extension adds to the round limit.",
        0, true, 1.0
    );

    cvar_extend_time = CreateConVar(
        "sm_umc_endvote_extend_timestep",
        "15",
        "Specifies how many more minutes each extension adds to the time limit.",
        0, true, 1.0
    );

    cvar_extend_frags = CreateConVar(
        "sm_umc_endvote_extend_fragstep",
        "10",
        "Specifies how many more frags each extension adds to the frag limit.",
        0, true, 1.0
    );

    cvar_extensions = CreateConVar(
        "sm_umc_endvote_extends",
        "0",
        "Number of extensions allowed each map.\n 0 disables the Extend Map option.",
        0, true, 0.0
    );

    cvar_endvote = CreateConVar(
        "sm_umc_endvote_enabled",
        "1",
        "Specifies if Ultimate Mapchooser should run an end of map vote.",
        0, true, 0.0, true, 1.0
    );

    cvar_vote_type = CreateConVar(
        "sm_umc_endvote_type",
        "0",
        "Controls end of map vote type:\n 0 - Maps,\n 1 - Groups,\n 2 - Tiered Vote (vote for a group, then vote for a map from the group).",
        0, true, 0.0, true, 2.0
    );

    cvar_start_time = CreateConVar(
        "sm_umc_endvote_starttime",
        "6",
        "Specifies when to start the vote based on time remaining in minutes.",
        0, true, 1.0
    );

    cvar_start_rounds = CreateConVar(
        "sm_umc_endvote_startrounds",
        "2",
        "Specifies when to start the vote based on rounds remaining. Use 0 on TF2 to start vote during bonus round time",
        0, true, 0.0
    );

    cvar_start_frags = CreateConVar(
        "sm_umc_endvote_startfrags",
        "10",
        "Specifies when to start the vote based on frags remaining.",
        0, true, 1.0
    );

    cvar_vote_time = CreateConVar(
        "sm_umc_endvote_duration",
        "20",
        "Specifies how long a vote should be available for.",
        0, true, 10.0
    );

    cvar_filename = CreateConVar(
        "sm_umc_endvote_cyclefile",
        "umc_mapcycle.txt",
        "File to use for Ultimate Mapchooser's map rotation."
    );

    cvar_vote_mem = CreateConVar(
        "sm_umc_endvote_mapexclude",
        "4",
        "Specifies how many past maps to exclude from the end of map vote. 1 = Current Map Only",
        0, true, 0.0
    );

    cvar_scramble = CreateConVar(
        "sm_umc_endvote_menuscrambled",
        "0",
        "Specifies whether vote menu items are displayed in a random order.",
        0, true, 0.0, true, 1.0
    );

    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "umc-endvote");

    //Set up our "timers" for the end-of-map vote.
    cvar_maxrounds = FindConVar("mp_maxrounds");
    cvar_fraglimit = FindConVar("mp_fraglimit");
    cvar_winlimit  = FindConVar("mp_winlimit");
    
    if (cvar_maxrounds != INVALID_HANDLE || cvar_winlimit != INVALID_HANDLE)
    {
        HookEvent("round_end",                Event_RoundEnd); //Generic
        HookEventEx("game_round_end",         Event_RoundEnd); //Hidden: Source, Neotokyo
        HookEventEx("teamplay_win_panel",     Event_RoundEndTF2); //TF2
        HookEventEx("arena_win_panel",        Event_RoundEndTF2); //TF2
        HookEventEx("teamplay_restart_round", Event_TFRestartRound); //TF2    
        HookEventEx("round_win",                Event_RoundEnd); //Nuclear Dawn
    }
    
    //Hook score.
    if (cvar_fraglimit != INVALID_HANDLE)
        HookEvent("player_death", Event_PlayerDeath);
    
    //Hook all necessary cvar changes
    HookConVarChange(cvar_vote_mem,   Handle_VoteMemoryChange);
    HookConVarChange(cvar_endvote,    Handle_VoteChange);
    HookConVarChange(cvar_start_time, Handle_TriggerChange);
    //HookConVarChange(cvar_runoff,     Handle_RunoffChange);
    
#if UMC_DEBUG
    HookConVarChange(cvar_filename, Handle_MapCycleFileChange);
#endif
    
    //Initialize our memory arrays
    new numCells = ByteCountToCells(MAP_LENGTH);
    vote_mem_arr    = CreateArray(numCells);
    vote_catmem_arr = CreateArray(numCells);
    
    //Load the translations file
    LoadTranslations("ultimate-mapchooser.phrases");

    time_update_forward = CreateGlobalForward(
        "UMC_EndVote_OnTimeTimerUpdated", ET_Ignore, Param_Cell
    );
    round_update_forward = CreateGlobalForward(
        "UMC_EndVote_OnRoundTimerUpdated", ET_Ignore, Param_Cell
    );
    win_update_forward = CreateGlobalForward(
        "UMC_EndVote_OnWinTimerUpdated", ET_Ignore, Param_Cell, Param_Cell
    );
    frag_update_forward = CreateGlobalForward(
        "UMC_EndVote_OnFragTimerUpdated", ET_Ignore, Param_Cell, Param_Cell
    );
    time_tick_forward = CreateGlobalForward(
        "UMC_EndVote_OnTimeTimerTicked", ET_Ignore, Param_Cell
    );
    round_tick_forward = CreateGlobalForward(
        "UMC_EndVote_OnRoundTimerTicked", ET_Ignore, Param_Cell
    );
    win_tick_forward = CreateGlobalForward(
        "UMC_EndVote_OnWinTimerTicked", ET_Ignore, Param_Cell, Param_Cell
    );
    frag_tick_forward = CreateGlobalForward(
        "UMC_EndVote_OnFragTimerTicked", ET_Ignore, Param_Cell, Param_Cell
    );

#if AUTOUPDATE_ENABLE
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
#endif
}


#if AUTOUPDATE_ENABLE
//Called when a new API library is loaded. Used to register UMC auto-updating.
public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}
#endif


//************************************************************************************************//
//                                           GAME EVENTS                                          //
//************************************************************************************************//

//Called after all config files were executed.
public OnConfigsExecuted()
{
    //Set initial values for cvar value storage.
    //maxrounds_mem = GetConVarInt(cvar_maxrounds);
    //fraglimit_mem = GetConVarInt(cvar_fraglimit);
    
    //Votes are not enabled.
    vote_enabled = false;
    vote_roundend = false;
    vote_completed = false;
    
    //No timer is setup so delay is undefined
    vote_delaystart = -1.0;
    
    //Set the amount of remaining extensions allowed for the map.
    extend_counter = 0;
    
    //No rounds have finished yet.
    round_counter = 0;
    
    //Reset the stored team scores.
    for (new i = 0; i < MAXTEAMS; i++)
        team_wincounts[i] = 0;
        
    new bool:mapcycleLoaded = ReloadMapcycle();
    
    //Make end-of-map vote timers if...
    //    ...the mapcycle was loaded successfully AND
    //    ...the end-of-map vote cvar is enabled AND
    //    ...the timer is not currently alive.
    if (mapcycleLoaded && GetConVarBool(cvar_endvote) && !timer_alive)
        MakeVoteTimer();
    
    //Setup vote sounds.
    SetupVoteSounds();
    
    //Grab the name of the current map.
    decl String:mapName[MAP_LENGTH];
    GetCurrentMap(mapName, sizeof(mapName));
    
    decl String:groupName[MAP_LENGTH];
    UMC_GetCurrentMapGroup(groupName, sizeof(groupName));
    
    if (mapcycleLoaded && StrEqual(groupName, INVALID_GROUP, false))
    {
        KvFindGroupOfMap(umc_mapcycle, mapName, groupName, sizeof(groupName));
    }
    
    //Add the map to all the memory queues.
    new mapmem = GetConVarInt(cvar_vote_mem);
    new catmem = GetConVarInt(cvar_vote_catmem);
    AddToMemoryArray(mapName, vote_mem_arr, mapmem);
    AddToMemoryArray(groupName, vote_catmem_arr, (mapmem > catmem) ? mapmem : catmem);
    
    if (mapcycleLoaded)
        RemovePreviousMapsFromCycle();
}


//Called when a player dies. Used for end-of-map vote based on frags.
public Event_PlayerDeath(Handle:evnt, String:name[], bool:dontBroadcast)
{
    new fraglimit = GetConVarInt(cvar_fraglimit);
    if (vote_enabled && fraglimit > 0)
    {
        new fragger = GetClientOfUserId(GetEventInt(evnt, "attacker"));
        
        if (!fragger)
            return;
            
        new startfrags = GetConVarInt(cvar_start_frags);
        new frags = GetClientFrags(fragger) + 1;
    
        if (frags >= (fraglimit - startfrags))
        {
            LogUMCMessage("Frag limit triggered end of map vote.");
            DestroyTimers();
            SetupMapVote();
        }
        
        //Call the frag timer forward.
        Call_StartForward(frag_tick_forward);
        Call_PushCell(float(fraglimit - GetConVarInt(cvar_start_frags) - frags));
        Call_PushCell(fragger);
        Call_Finish();
    }
}


//Called if the the amount of map time left is changed at any point.
//Needed to update our vote timer.
public OnMapTimeLeftChanged()
{
    //Update the end-of-map vote timer if...
    //    ...we haven't already completed an RTV.
    if (vote_enabled)
    {
        DEBUG_MESSAGE("Timeleft Changed")
        UpdateTimers();
    }
}


//Called when a round ends.
public Event_RoundEnd(Handle:evnt, const String:name[], bool:dontBroadcast)
{
    if (vote_roundend)
    {
        vote_roundend = false;
        StartMapVoteRoundEnd();
    }
    
    new winner = GetEventInt(evnt, "winner");
    
    //Do nothing if there wasn't a winning team.
    if (winner == 0 || winner == 1)
        return;
    
    if (winner >= MAXTEAMS)
        SetFailState("Mod exceeded maximum team count - please file a bug report.");
    
    //Update the round "timer"
    round_counter++;
    team_wincounts[winner]++;
    
    if (vote_enabled) 
    {
        CheckWinLimit(team_wincounts[winner], winner);
        CheckMaxRounds(round_counter);
    }
}


//Called when a round ends in tf2.
public Event_RoundEndTF2(Handle:evnt, const String:name[], bool:dontBroadcast)
{
    if (vote_roundend)
    {
        vote_roundend = false;
        StartMapVoteRoundEnd();
    }

    new bluescore = GetEventInt(evnt, "blue_score");
    new redscore  = GetEventInt(evnt, "red_score");
    
    if (GetEventInt(evnt, "round_complete") == 1 || StrEqual(name, "arena_win_panel"))
    {
        round_counter++;
        
        if (vote_enabled)
        {
            CheckMaxRounds(round_counter);
            
            new winningTeam = GetEventInt(evnt, "winning_team");
            
            switch (winningTeam)
            {
                case 3:
                    CheckWinLimit(bluescore, winningTeam);
                case 2:
                    CheckWinLimit(redscore, winningTeam);
                default:
                    return;
            }
        }
    }
}


//Called when the game is restarted in tf2.
public Event_TFRestartRound(Handle:evnt, const String:name[], bool:dontBroadcast)
{
    round_counter = 0;
    
    if (cvar_maxrounds != INVALID_HANDLE)
    {
        //Update our vote warnings.
        Call_StartForward(round_update_forward);
        Call_PushCell(GetConVarInt(cvar_maxrounds) - GetConVarInt(cvar_start_rounds));
        Call_Finish();
    }
    
    for (new i = 0; i < MAXTEAMS; i++)
        team_wincounts[i] = 0;
        
    if (cvar_winlimit != INVALID_HANDLE)
    {
        Call_StartForward(win_update_forward);
        Call_PushCell(GetConVarInt(cvar_winlimit) - GetConVarInt(cvar_start_rounds));
        Call_PushCell(0);
        Call_Finish();
    }
}


//Called at the end of a map.
public OnMapEnd()
{
    //Vote timer is not running
    timer_alive = false;
    vote_timer = INVALID_HANDLE;
}


//************************************************************************************************//
//                                              SETUP                                             //
//************************************************************************************************//

//Parses the mapcycle file and returns a KV handle representing the mapcycle.
Handle:GetMapcycle()
{
    //Grab the file name from the cvar.
    decl String:filename[PLATFORM_MAX_PATH];
    GetConVarString(cvar_filename, filename, sizeof(filename));
    
    //Get the kv handle from the file.
    new Handle:result = GetKvFromFile(filename, "umc_rotation");
    
    //Log an error and return empty handle if...
    //    ...the mapcycle file failed to parse.
    if (result == INVALID_HANDLE)
    {
        LogError("SETUP: Mapcycle failed to load!");
        return INVALID_HANDLE;
    }
    
    //Success!
    return result;
}


//Sets up the vote sounds.
SetupVoteSounds()
{
    //Grab sound files from cvars.
    GetConVarString(cvar_vote_startsound, vote_start_sound, sizeof(vote_start_sound));
    GetConVarString(cvar_vote_endsound, vote_end_sound, sizeof(vote_end_sound));
    GetConVarString(cvar_runoff_sound, runoff_sound, sizeof(runoff_sound));
    
    //Gotta cache 'em all!
    CacheSound(vote_start_sound);
    CacheSound(vote_end_sound);
    CacheSound(runoff_sound);
}


//Sets up timers for an end-of-map vote.
MakeVoteTimer()
{
    //A vote has not been completed if we're making a new timer.
    vote_completed = false;
    
    //The end-of-map vote is now enabled.
    vote_enabled = true;
    
    //Make the end-of-map vote timer.
    if (timer_alive)
    {
        DEBUG_MESSAGE("Killing timer. (MakeVoteTimer)")
        timer_alive = false;
        KillTimer(vote_timer);
        vote_timer = INVALID_HANDLE;
    }
    DEBUG_MESSAGE("*MakeVoteTimer*")
    vote_timer = MakeTimer();
    
    UpdateOtherTimers();
}


//Updates the non-mp_timelimit "timers."
UpdateOtherTimers()
{
    new start;
    
    if (cvar_maxrounds != INVALID_HANDLE)
    {
        start = GetConVarInt(cvar_maxrounds) - GetConVarInt(cvar_start_rounds) - round_counter;
        if (start > 0)
            LogUMCMessage("End of map vote will appear after %i more rounds.", start);
            
        //Update our vote warnings.
        //UpdateVoteWarnings(.round=warnings_round_enabled, .frag=warnings_frag_enabled);
        Call_StartForward(round_update_forward);
        Call_PushCell(start);
        Call_Finish();
    }
    
    if (cvar_winlimit != INVALID_HANDLE)
    {
        new winScore;
        new winTeam = GetWinningTeam(winScore);
        start = GetConVarInt(cvar_winlimit) - GetConVarInt(cvar_start_rounds) - winScore;
        DEBUG_MESSAGE("Cvar (mp_winlimit): %i, Cvar (startrounds): %i, WinnerScore: %i", GetConVarInt(cvar_winlimit), GetConVarInt(cvar_start_rounds), winScore)
        if (start > 0)
            LogUMCMessage("End of map vote will appear after %i more wins.", start);
        
        //Update our vote warnings.
        //UpdateVoteWarnings(.round=warnings_round_enabled, .frag=warnings_frag_enabled);
        Call_StartForward(win_update_forward);
        Call_PushCell(start);
        Call_PushCell(winTeam);
        Call_Finish();
    }
    
    if (cvar_fraglimit != INVALID_HANDLE)
    {
        new fragCount;
        new topFragger = GetTopFragger(fragCount);
        start = GetConVarInt(cvar_fraglimit) - GetConVarInt(cvar_start_frags) - fragCount;
        if (start > 0)
            LogUMCMessage("End of map vote will appear after %i more frags.", start);
            
        //Update our vote warnings.
        //UpdateVoteWarnings(.round=warnings_round_enabled, .frag=warnings_frag_enabled);
        Call_StartForward(frag_update_forward);
        Call_PushCell(start);
        Call_PushCell(topFragger);
        Call_Finish();
    }
}


//Reloads the mapcycle. Returns true on success, false on failure.
bool:ReloadMapcycle()
{
    if (umc_mapcycle != INVALID_HANDLE)
    {
        CloseHandle(umc_mapcycle);
        umc_mapcycle = INVALID_HANDLE;
    }
    if (map_kv != INVALID_HANDLE)
    {
        CloseHandle(map_kv);
        map_kv = INVALID_HANDLE;
    }
    umc_mapcycle = GetMapcycle();
    
    return umc_mapcycle != INVALID_HANDLE;
}


//
RemovePreviousMapsFromCycle()
{
    map_kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(umc_mapcycle, map_kv);
    FilterMapcycleFromArrays(map_kv, vote_mem_arr, vote_catmem_arr, GetConVarInt(cvar_vote_catmem));
}


//************************************************************************************************//
//                                          CVAR CHANGES                                          //
//************************************************************************************************//

#if UMC_DEBUG
public Handle_MapCycleFileChange(Handle:convar, const String:oldVal[], const String:newVal[])
{
    if (!StrEqual(oldVal, newVal))
    {
        DEBUG_MESSAGE("sm_umc_endvote_cyclefile -- value has been changed from \"%s\" to \"%s\"", oldVal, newVal)
    }
}
#endif


//Called when the cvar for the maximum number of rounds has been changed. Used for end-of-map vote
//based on rounds.
public Handle_MaxroundsChange(Handle:convar, const String:oldVal[], const String:newVal[])
{
    new start = StringToInt(newVal) - GetConVarInt(cvar_start_rounds) - round_counter;
    new old = StringToInt(oldVal);
    
    //Log
    if (start > 0)
        LogUMCMessage("End of map vote will appear after %i more rounds.", start);
    else if (old > 0)
        LogUMCMessage("End of map vote round trigger disabled.");
        
    //UpdateVoteWarnings(.round=warnings_round_enabled);
    Call_StartForward(round_update_forward);
    Call_PushCell(start);
    Call_Finish();
        
    //Store the new value to change the cvar to when the map ends if...
    //    ...the flag to bypass this action is set to False.
    //if (!catch_change)
    //    maxrounds_mem = StringToInt(newVal);
}


//Called when the cvar for the win limit has been changed. Used for end-of-map vote based on rounds.
public Handle_WinlimitChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
    new winScore;
    new winningTeam = GetWinningTeam(winScore);
    new start = StringToInt(newVal) - GetConVarInt(cvar_start_rounds) - winScore;
    new old = StringToInt(oldVal);
    
    //Log
    if (start > 0)
        LogUMCMessage("End of map vote will appear after %i more wins.", start);
    else if (old > 0)
        LogUMCMessage("End of map vote round trigger disabled.");
        
    Call_StartForward(win_update_forward);
    Call_PushCell(start);
    Call_PushCell(winningTeam);
    Call_Finish();
}


//Called when the cvar for the maximum number of frags has been changed. Used for end-of-map vote
//based on frags.
public Handle_FraglimitChange(Handle:convar, const String:oldVal[], const String:newVal[])
{
    new newlimit = StringToInt(newVal);
    if (newlimit > 0)
    {
        LogUMCMessage("End of map vote will appear after %i frags.",
            StringToInt(newVal) - GetConVarInt(cvar_start_frags));
    }
    else if (StringToInt(oldVal) > 0)
        LogUMCMessage("End of map vote frag trigger disabled.");
    
    new topFrags;
    new topFragger = GetTopFragger(topFrags);
    
    Call_StartForward(frag_update_forward);
    Call_PushCell(float(newlimit - GetConVarInt(cvar_start_frags) - topFrags));
    Call_PushCell(topFragger);
    Call_Finish();

    //Store the new value to change the cvar to when the map ends if...
    //    ...the flag to bypass this action is set to False.
    //if (!catch_change)
    //    fraglimit_mem = StringToInt(newVal);
}


//Reset all modified cvars to the stored values.
/*RestoreCvars()
{
    SetConVarInt(cvar_maxrounds, maxrounds_mem);
    SetConVarInt(cvar_fraglimit, fraglimit_mem);
}*/


//Called when the number of excluded previous maps from end-of-map votes has changed.
public Handle_VoteMemoryChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
    //Trim the memory array for end-of-map votes.
        //We pass 1 extra to the argument in order to account for the current map, which should 
        //always be excluded.
    TrimArray(vote_mem_arr, StringToInt(newValue));
}


//Called when the cvar which enabled end-of-map votes has changed.
public Handle_VoteChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
    //Regardless of the change, destroy all existing end-of-map vote timers.
    DestroyTimers();
    vote_enabled = false;
    
    //Make new timers if...
    //    ...the new value of the cvar is 1.
    if (StringToInt(newValue) == 1)
        MakeVoteTimer();
}


//Called when the cvar which specifies the time trigger for the end-of-round vote is changed.
public Handle_TriggerChange(Handle:convar, const String:oldVal[], const String:newVal[])
{
    //Update all necessary timers.
    DEBUG_MESSAGE("*TriggerChange*")
    UpdateTimers();
}


//************************************************************************************************//
//                                             NATIVES                                            //
//************************************************************************************************//

// native HasEndOfMapVoteFinished();
public Native_CheckVoteDone(Handle:plugin, numParams)
{
    return vote_completed;
}


// native EndOfMapVoteEnabled();
public Native_EndOfMapVoteEnabled(Handle:plugin, numParams)
{
    return vote_enabled;
}


//************************************************************************************************//
//                                         END OF MAP VOTE                                        //
//************************************************************************************************//

//Fetches the index of the winning team.
GetWinningTeam(&score)
{
    new wincount;
    new max = team_wincounts[0];
    new winning = 0;
    for (new i = 1; i < MAXTEAMS; i++)
    {
        wincount = team_wincounts[i];
        if (wincount > max)
        {
            max = wincount;
            winning = i;
        }
    }
    score = max;
    return winning;
}


//Fetches the index of the winning team.
GetTopFragger(&score)
{
    new fragcount;
    new max = team_wincounts[0];
    new winning = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;
        
        fragcount = GetClientFrags(i);
        if (fragcount > max)
        {
            max = fragcount;
            winning = i;
        }
    }
    score = max;
    return winning;
}


//Starts a vote if the given score is high enough.
CheckWinLimit(winner_score, winning_team)
{
    if (cvar_winlimit != INVALID_HANDLE)
    {
        new winlimit = GetConVarInt(cvar_winlimit);
        if (winlimit > 0)
        {
            if (winner_score >= (winlimit - GetConVarInt(cvar_start_rounds)))
            {
                LogUMCMessage("Win limit triggered end of map vote.");
                DestroyTimers();
                StartMapVoteRoundEnd();
            }
            
            //Call the forward
            Call_StartForward(win_tick_forward);
            Call_PushCell(winlimit - GetConVarInt(cvar_start_rounds) - winner_score);
            Call_PushCell(winning_team);
            Call_Finish();
        }
    }
}


//Starts a vote if the given round count is high enough
CheckMaxRounds(round_count)
{
    if (cvar_maxrounds != INVALID_HANDLE)
    {
        new maxrounds = GetConVarInt(cvar_maxrounds);
        if (maxrounds > 0)
        {
            new startRounds = GetConVarInt(cvar_start_rounds);
            DEBUG_MESSAGE("Determining if mp_maxrounds trigger has been reached. MR: %i, T: %i, C: %i", maxrounds, startRounds, round_count)
            if (round_count >= (maxrounds - startRounds))
            {
                LogUMCMessage("Round limit triggered end of map vote.");
                DestroyTimers();
                StartMapVoteRoundEnd();
            }
            
            Call_StartForward(round_tick_forward);
            Call_PushCell(maxrounds - GetConVarInt(cvar_start_rounds) - round_counter);
            Call_Finish();
        }
    }
}


//Makes the timer which will activate the end-of-map vote at a certain time.
Handle:MakeTimer()
{
    DEBUG_MESSAGE("*MakeTimer*")
    new Handle:result = INVALID_HANDLE;
    if (SetTimerTriggerTime())
    {
        //Make the timer
        result = CreateTimer(
            1.0,
            Handle_MapVoteTimer,
            INVALID_HANDLE,
            TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT
        );
        
        timer_alive = result != INVALID_HANDLE;
        
        if (!timer_alive)
        {
            LogError(
                "End of map timer could not be created. Please file a bug report with the author."
            );
        }
#if UMC_DEBUG
        else
            DEBUG_MESSAGE("Making timer.")
#endif
    }
    else
    {
        timer_alive = false;
        
        //Log message
        LogUMCMessage("Unable to create end of map vote time-trigger, trigger time already passed.");
    }
    return result;
}


//Called when the end-of-vote timer (vote_timer) is finished.
public Action:Handle_MapVoteTimer(Handle:timer)
{
    //Handle vote warnings if...
    //    ...vote warnings are enabled.
    Call_StartForward(time_tick_forward);
    Call_PushCell(RoundFloat(vote_delaystart));
    Call_Finish();

    //Continue ticking if...
    //    ...there is still time left on the counter.
    if (vote_delaystart > 0)
    {
        //DEBUG_MESSAGE("Tick %.f", vote_delaystart)
        //Tick another second off the timer counter.
        vote_delaystart--;
        return Plugin_Continue;
    }
    
    //If there isn't time left on the timer...
    
    //The timer is no longer alive.
    timer_alive = false;
    vote_timer = INVALID_HANDLE;
    vote_delaystart = -1.0;
    
    //Start the end-of-map vote.
    SetupMapVote();
    
    return Plugin_Stop;
}


//Sets the time trigger for the end of map timer.
bool:SetTimerTriggerTime()
{
    //Get current timeleft.
    new timeleft, Float:triggertime, Float:starttime;
    GetMapTimeLeft(timeleft);
    
    if (timeleft <= 0)
        return false;
    
    starttime = GetConVarFloat(cvar_start_time) * 60;
    
    //Duration until the vote starts.
    triggertime = timeleft - starttime;
    
    DEBUG_MESSAGE("*SetTimerTriggerTime* -- TimeLeft: %i   StartTime: %f   TriggerTime: %f", timeleft, starttime, triggertime)   
    
    new bool:result;
    
    //Make the timer if...
    //    ...the time to start the vote hasn't already passed.
    if (timeleft >= 0 && starttime > 0 && triggertime > 0)
    {
        //Setup counter until the end-of-map vote triggers.
        vote_delaystart = triggertime - 1;
        result = true;
        
        LogUMCMessage("End of map vote will appear after %.f seconds", triggertime);
    }
    else //Otherwise...
    {
        //Never trigger the vote.
        vote_delaystart = -1.0;
        result = false;
    }
    
    //Update Vote Warnings if vote warnings are enabled.
    Call_StartForward(time_update_forward);
    Call_PushCell(RoundToFloor(triggertime));
    Call_Finish();
    
    return result;
}


//Update the end-of-map vote timer.
UpdateTimers()
{
    DEBUG_MESSAGE("*UpdateTimers*")
    //Reset the timer if...
    //    ...we haven't already completed a vote.
    //    ...the cvar to run an end-of-round vote is enabled.
    if (timer_alive)
    {
        if (SetTimerTriggerTime())
        {
            LogUMCMessage("Map vote timer successfully updated.");
        }
        else
        {
            DEBUG_MESSAGE("Killing Timer (UpdateTimers)")
            timer_alive = false;
            KillTimer(vote_timer);
            vote_timer = INVALID_HANDLE;
        }
    }
    else //Make a new timer.
    {
        vote_timer = MakeTimer();
    
        if (timer_alive)
            LogUMCMessage("Map vote timer successfully updated.");
    }
}


//Disables all end-of-map vote timers.
DestroyTimers()
{
    LogUMCMessage("End of map vote disabled.");

    //Delete the time trigger if...
    //    ...the timer is alive.
    if (timer_alive)
    {
        DEBUG_MESSAGE("Killing Timer (DestroyTimers)")
        timer_alive = false;
        KillTimer(vote_timer);
        vote_timer = INVALID_HANDLE;
    }
}


//Sets up a map vote.
SetupMapVote()
{
    if (GetConVarBool(cvar_vote_roundend))
        vote_roundend = true;
    else
        StartMapVote();
}


//Starts a map vote due to the round ending.
StartMapVoteRoundEnd()
{
    new Float:delay = GetConVarFloat(cvar_delay);
    if (delay == 0.0)
        StartMapVote();
    else
        CreateTimer(delay, Handle_VoteDelayTimer);
}


//
public Action:Handle_VoteDelayTimer(Handle:timer)
{
    StartMapVote();
    return Plugin_Stop;
}


//Initiates the map vote.
public StartMapVote()
{
    if (!vote_enabled)
    {
        //LogUMCMessage("Cancelling map vote.");
        return;
    }

    //Log a message
    LogUMCMessage("Starting an end of map vote.");
    
    //Log an error and retry vote if...
    //    ...another vote is currently running for some reason.
    if (IsVoteInProgress()) 
    {
        LogUMCMessage("There is a vote already in progress, cannot start a new vote.");
        MakeRetryVoteTimer(StartMapVote);
        return;
    }
    
    vote_enabled = false;
    
    vote_completed = true;
    
    decl String:flags[64];
    GetConVarString(cvar_flags, flags, sizeof(flags));
    
    //Start the UMC vote.
    new bool:result = UMC_StartVote(
        "core",
        map_kv,                                                     //Mapcycle
        umc_mapcycle,                                               //Full mapcycle
        UMC_VoteType:GetConVarInt(cvar_vote_type),                  //Vote Type (map, group, tiered)
        GetConVarInt(cvar_vote_time),                               //Vote duration
        GetConVarBool(cvar_scramble),                               //Scramble
        vote_start_sound,                                           //Start Sound
        vote_end_sound,                                             //End Sound
        GetConVarInt(cvar_extensions) > extend_counter,             //Extend option
        GetConVarFloat(cvar_extend_time),                           //How long to extend the timelimit by,
        GetConVarInt(cvar_extend_rounds),                           //How much to extend the roundlimit by,
        GetConVarInt(cvar_extend_frags),                            //How much to extend the fraglimit by,
        false,                                                      //Don't Change option
        GetConVarFloat(cvar_vote_threshold),                        //Threshold
        ChangeMapTime_MapEnd,                                       //Success Action (when to change the map)
        UMC_VoteFailAction:GetConVarInt(cvar_fail_action),          //Fail Action (runoff / nothing)
        GetConVarInt(cvar_runoff),                                  //Max Runoffs
        GetConVarInt(cvar_runoff_max),                              //Max maps in the runoff
        UMC_RunoffFailAction:GetConVarInt(cvar_runoff_fail_action), //Runoff Fail Action
        runoff_sound,                                               //Runoff Sound
        GetConVarBool(cvar_strict_noms),                            //Nomination Strictness
        GetConVarBool(cvar_vote_allowduplicates),                   //Ignore Duplicates
        flags                                                       //Admin Flags
    );
    
    if (!result)
    {
        LogUMCMessage("Could not start UMC vote.");
    }
}


//************************************************************************************************//
//                                   ULTIMATE MAPCHOOSER EVENTS                                   //
//************************************************************************************************//

//Called when UMC has extended a map.
public UMC_OnMapExtended()
{
    DEBUG_MESSAGE("*Map extended.*")
    UpdateTimers();
    UpdateOtherTimers();
    extend_counter++;
    vote_completed = false;
    vote_enabled = true;
}


//Called when UMC has set a next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[], const String:display[])
{
    DestroyTimers();
    vote_enabled = false;
    vote_roundend = false;
}


//Called when UMC requests that the mapcycle should be reloaded.
public UMC_RequestReloadMapcycle()
{
    if (!ReloadMapcycle())
    {
        DestroyTimers();
        vote_enabled = false;
    }
    else
    {
        RemovePreviousMapsFromCycle();
    }
}


//Called when UMC requests that the mapcycle is printed to the console.
public UMC_DisplayMapCycle(client, bool:filtered)
{
    PrintToConsole(client, "Module: End of Map Vote");
    if (filtered)
    {
        new Handle:filteredMapcycle = UMC_FilterMapcycle(
            map_kv, umc_mapcycle, false, true
        );
        PrintKvToConsole(filteredMapcycle, client);
        CloseHandle(filteredMapcycle);
    }
    else
    {
        PrintKvToConsole(umc_mapcycle, client);
    }
}

