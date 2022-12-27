#include <sourcemod>
#include <sdktools>
#include <sdktools_gamerules>
#include <cstrike>

char error[255];
Handle knivhelg = null;

public Plugin myinfo = {
	name = "OSKnivHelg",
	author = "Pintuz",
	description = "OldSwedes Kniva en admin helg plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSKnivHelg"
}

public void OnPluginStart ( ) {
    HookEvent ( "player_death", Event_PlayerDeath );
    databaseConnect ( );
    AutoExecConfig ( true, "osknivhelg" );
}


/* EVENTS */
 
public void Event_PlayerDeath ( Event event, const char[] name, bool dontBroadcast ) {
    int victim_id = GetEventInt(event, "userid");
    int attacker_id = GetEventInt(event, "attacker");
    int victim = GetClientOfUserId(victim_id);
    int attacker = GetClientOfUserId(attacker_id);

    if ( ! playerIsReal ( victim ) || 
         ! playerIsReal ( attacker ) ||
         victim == attacker ) {
        return;
    }
    char weapon[32];
    GetEventString ( event, "weapon", weapon, sizeof(weapon) );

    if ( ! stringContains ( weapon, "KNIFE" ) ){
        return;
    }
    if ( isWarmup ( ) ) {
        PrintToChatAll ( "[OSKnivHelg]: Its warmup so knife doesnt count!" );
        return;
    }
    char victim_name[64];
    char attacker_name[64];
    char victim_authid[32];
    char attacker_authid[32];
    GetClientName ( victim, victim_name, sizeof ( victim_name ) );
    GetClientName ( attacker, attacker_name, sizeof ( attacker_name ) );
    GetClientAuthId ( victim, AuthId_Steam2, victim_authid, sizeof ( victim_authid ) );
    GetClientAuthId ( attacker, AuthId_Steam2, attacker_authid, sizeof ( attacker_authid ) );
    int points = getPoints ( attacker_authid, victim_authid );
    
    //if ( ! isValidSteamID ( victim_authid ) || ! isValidSteamID ( attacker_authid ) ) {
    //    return;
    //}

    addKnifeEvent ( attacker_name, attacker_authid, victim_name, victim_authid, points );
    PrintToChatAll ( "[OSKnivHelg]: %s knifed %s and got %d points!", attacker_name, victim_name, points );
}


/* END of EVENTS */

/* COMMANDS*/


/* METHODS */
 

public int getPoints ( char attacker_authid[32], char victim_authid[32] ) {
    checkConnection ();
    DBStatement stmt;
    int apoints;
    int vpoints;
    
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "select ifnull((select points from user where steamid = ?),1) as apoints,ifnull((select points from user where steamid = ?),1) as vpoints;", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x01] (error: %s)", error);
        return 0;
    }
    SQL_BindParamString ( stmt, 0, attacker_authid, false );
    SQL_BindParamString ( stmt, 1, victim_authid, false );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x01] (error: %s)", error);
        return 0;
    }
    if ( SQL_FetchRow ( stmt ) ) {
        apoints = SQL_FetchInt ( stmt, 0 );
        vpoints = SQL_FetchInt ( stmt, 1 );
    }
    
    if ( stmt != null ) {
        delete stmt;
    }

    if ( apoints == 1 || vpoints == 1 ) {
        return 1;
    } else if ( apoints > vpoints ) {
        return apoints;
    } else {
        return vpoints;
    }

}
 
public bool stringContains ( char string[32], char match[32] ) {
    return ( StrContains ( string, match, false ) != -1 );
}

public bool isValidSteamID ( char authid[32] ) {
    return true;
//    return ( StrContains ( authid, "STEAM_0" ) || StrContains ( authid, "STEAM_1" ) );
}

public void addKnifeEvent ( char attacker_name[64], char attacker_authid[32], char victim_name[64], char victim_authid[32], int points ) {
    databaseConnect ( )
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "insert into event (stamp,attacker,attackerid,victim,victimid,points) values (now(),?,?,?,?,?)", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x07] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, attacker_name, false );
    SQL_BindParamString ( stmt, 1, attacker_authid, false );
    SQL_BindParamString ( stmt, 2, victim_name, false );
    SQL_BindParamString ( stmt, 3, victim_authid, false );
    SQL_BindParamInt ( stmt, 4, points );
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x04] (error: %s)", error);
    }
    delete stmt;
}
 
public void databaseConnect ( ) {
    if ( ( knivhelg = SQL_Connect ( "knivhelg", true, error, sizeof(error) ) ) != null ) {
        PrintToServer ( "[OSKnivHelg]: Connected to knivhelg database!" );
    } else {
        PrintToServer ( "[OSKnivHelg]: Failed to connect to knivhelg database! (error: %s)", error );
    }
}

public void checkConnection ( ) {
    if ( knivhelg == null || knivhelg == INVALID_HANDLE ) {
        databaseConnect ( );
    }
}
 
/* return true if player is real */
public bool playerIsReal ( int player ) {
    return ( IsClientInGame ( player ) &&
             ! IsClientSourceTV ( player ) );
}

/* isWarmup */
public bool isWarmup ( ) {
    if ( GameRules_GetProp ( "m_bWarmupPeriod" ) == 1 ) {
        return true;
    } 
    return false;
}
 