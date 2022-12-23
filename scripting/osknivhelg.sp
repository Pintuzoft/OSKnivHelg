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
    HookEvent ( "round_end", Event_RoundEnd );
    HookEvent ( "player_death", Event_PlayerDeath );
    databaseConnect ( );
    populateAdminTable ( );
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


/* METHODS */

public void databaseConnect ( ) {
    knivhelg = SQL_Connect ( "knivhelg", true, error, sizeof(error) );
}

public void populateAdminTable ( ) {
    Handle query;
    char name[64];
    char authid[32];
    Database sourcebans = SQL_Connect ( "sourcebans", true, error, sizeof(error) );
    DBStatement stmt = SQL_PrepareQuery ( sourcebans, "select user,authid from sb_admins where aid != 0", error, sizeof(error) );
    SQL_Execute ( stmt );
    while ( SQL_FetchRow ( stmt ) ) {
        SQL_FetchString ( stmt, 0, name, sizeof(name) );
        SQL_FetchString ( stmt, 1, authid, sizeof(authid) );
        
    }
    if ( stmt != null ) {
        CloseHandle ( stmt );
    }
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