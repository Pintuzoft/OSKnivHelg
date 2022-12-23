#include <sourcemod>
#include <sdktools>
#include <cstrike>

char error[255];
Database knivhelg;

public Plugin myinfo = {
	name = "OSKnivHelg",
	author = "Pintuz",
	description = "OldSwedes Kniva en admin helg plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSKnivHelg"
}



public void OnPluginStart ( ) {
    HookEvent ( "round_start", Event_RoundStart );
//    HookEvent ( "round_end", Event_RoundEnd );
    HookEvent ( "player_death", Event_PlayerDeath );
    databaseConnect ( );
    populateAdminTable ( );
    RegConsoleCmd ( "sm_admintable", Command_AdminTable );
    AutoExecConfig ( true, "osknivhelg" );
}


/* EVENTS */
public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {

}

public void Event_PlayerDeath ( Event event, const char[] name, bool dontBroadcast ) {
    if ( ! isWarmup ( ) ) {
        return;
    }
    int victim_id = GetEventInt(event, "userid");
    int attacker_id = GetEventInt(event, "attacker");
    int victim = GetClientOfUserId(victim_id);
    int attacker = GetClientOfUserId(attacker_id);

    
    
}


/* END of EVENTS */

/* COMMANDS*/
public Action Command_AdminTable ( int client, int args ) {
    populateAdminTable ( );
    return Plugin_Handled;
}


/* METHODS */

public void databaseConnect ( ) {
    //knivhelg = SQL_Connect ( "knivhelg", true, error, sizeof(error) );
}

public void populateAdminTable ( ) {
    char name[64];
    char authid[32];
    PrintToConsoleAll ( "0:" );
    Database sourcebans = SQL_Connect ( "sourcebans", true, error, sizeof(error) );
    PrintToConsoleAll ( "1:" );
    DBStatement stmt = SQL_PrepareQuery ( sourcebans, "select user,authid from sb_admins where aid != 0", error, sizeof(error) );
    PrintToConsoleAll ( "2:" );
    SQL_Execute ( stmt );
    PrintToConsoleAll ( "3:" );
    while ( SQL_FetchRow ( stmt ) ) {
    PrintToConsoleAll ( "4:" );
        SQL_FetchString ( stmt, 0, name, sizeof(name) );
    PrintToConsoleAll ( "5:" );
        SQL_FetchString ( stmt, 1, authid, sizeof(authid) );
    PrintToConsoleAll ( "6:" );
        PrintToChatAll ( "Found admin: %s (steamid: %s)", name, authid );
    PrintToConsoleAll ( "7:" );
    }
    PrintToConsoleAll ( "8:" );
    if ( stmt != null ) {
    PrintToConsoleAll ( "9:" );
        CloseHandle ( stmt );
    }
    PrintToConsoleAll ( "10:" );
    delete sourcebans;
}


/* return true if player is real */
public bool playerIsReal ( int player ) {
    return ( IsClientInGame ( player ) &&
             !IsClientSourceTV ( player ) );
}

/* isWarmup */
public bool isWarmup ( ) {
    if ( GameRules_GetProp ( "m_bWarmupPeriod" ) == 1 ) {
        return true;
    } 
    return false;
}