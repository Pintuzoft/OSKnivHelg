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
    HookEvent ( "player_connect", Event_PlayerConnect );
    RegConsoleCmd ( "sm_ktop", Command_KnifeTop, "Shows the top 10 knife kills" );
    databaseConnect ( );
    AutoExecConfig ( true, "osknivhelg" );
}


/* EVENTS */
 
public void Event_PlayerDeath ( Event event, const char[] name, bool dontBroadcast ) {
    int victim_id = GetEventInt(event, "userid");
    int attacker_id = GetEventInt(event, "attacker");
    int victim = GetClientOfUserId(victim_id);
    int attacker = GetClientOfUserId(attacker_id);
    char victim_name[64];
    char attacker_name[64];
    char victim_authid[32];
    char attacker_authid[32];
    char weapon[32];
    bool isAttackerAdmin;
    bool isVictimAdmin;
    bool isAdmin;

    if ( ! playerIsReal ( victim ) || 
         ! playerIsReal ( attacker ) ||
         victim == attacker ) {
        return;
    }
    
    GetEventString ( event, "weapon", weapon, sizeof(weapon) );

    if ( ! stringContains ( weapon, "KNIFE" ) ){
        return;
    }
    if ( isWarmup ( ) ) {
        PrintToChatAll ( "[OSKnivHelg]: Its warmup so knife doesnt count!" );
        return;
    }
    
    GetClientName ( victim, victim_name, sizeof ( victim_name ) );
    GetClientName ( attacker, attacker_name, sizeof ( attacker_name ) );
    GetClientAuthId ( victim, AuthId_Steam2, victim_authid, sizeof ( victim_authid ) );
    GetClientAuthId ( attacker, AuthId_Steam2, attacker_authid, sizeof ( attacker_authid ) );
    
    if ( ! isValidSteamID ( victim_authid ) || ! isValidSteamID ( attacker_authid ) ) {
        return;
    }

    isAttackerAdmin = isPlayerAdmin ( attacker_authid );
    isVictimAdmin = isPlayerAdmin ( attacker_authid );
    isAdmin = ( isAttackerAdmin || isVictimAdmin );

    addKnifeEvent ( attacker_name, attacker_authid, victim_name, victim_authid, isAdmin );
    fixPoints ( attacker_name, attacker_authid, true, isAdmin );
    fixPoints ( victim_name, victim_authid, false, isAdmin );

    PrintToChatAll ( " \x04[OSKnivHelg]: %s%s knifed %s%s and got %d points!", 
                    attacker_name, 
                    (isAttackerAdmin?" (admin)":""), 
                    victim_name, 
                    (isVictimAdmin?" (admin)":""), 
                    (isAdmin?10:5));

}

public void Event_PlayerConnect ( Event event, const char[] name, bool dontBroadcast ) {
    int user_id = GetEventInt(event, "userid");
    char steamid[32];

    if ( ! playerIsReal ( user_id ) ) {
        return;
    }

    GetClientAuthId ( user_id, AuthId_Steam2, steamid, sizeof ( steamid ) );
    if ( ! isValidSteamID ( steamid ) ) {
        return;
    }
    PrintToChat ( user_id, " \x04[OSKnivHelg]: Welcome to OldSwedes KnivHelg! Knifing an admin gives you 10 points, knifing a normal player gives you 5 points. Type !ktop to see the top 10 knifers!" );    
}

/* END of EVENTS */

/* COMMANDS*/
public Action Command_KnifeTop ( int client, int args ) {
    databaseConnect ( );
    DBStatement stmt;
    char name[64];
    int points;
    int i;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "select name,points from userstats order by points desc limit 10;", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x07] (error: %s)", error);
        return Plugin_Handled;
    }

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x08] (error: %s)", error);
        return Plugin_Handled;
    }

    PrintToChat ( client, " \x02[OSKnivHelg]: Leaderboard:" );
    i = 1;
    while ( SQL_FetchRow ( stmt ) ) {
        SQL_FetchString ( stmt, 0, name, sizeof(name) );
        points = SQL_FetchInt ( stmt, 1 );
        PrintToChat ( client, "  \x02#%d. %s - %d", i, name, points );
        i++;
    }
    return Plugin_Handled;
}

/* METHODS */
 
public void fixPoints ( char name[64], char authid[32], bool isAttacker, bool isAdmin ) {
    checkConnection ();
    char query[255];
    DBStatement stmt;
    int points = (isAdmin?10:5);
    
    Format ( query, sizeof(query), "insert into userstats (name,steamid,points) values (?,?,?) on duplicate key update points = points %s ?;", (isAttacker?"+":"-") );
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, query, error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x02] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, name, false );
    SQL_BindParamString ( stmt, 1, authid, false );
    SQL_BindParamInt ( stmt, 2, points );
    SQL_BindParamInt ( stmt, 3, points );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x03] (error: %s)", error);
        return;
    }

    if ( stmt != null ) {
        delete stmt;
    }
}

public bool isPlayerAdmin ( char authid[32] ) {
    checkConnection ();
    DBStatement stmt;
    int acount;
    
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "select count(*) as acount from admin where replace(steamid,'STEAM_0','STEAM_1') = replace(?,'STEAM_0','STEAM_1');", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x05] (error: %s)", error);
        return false;
    }
    SQL_BindParamString ( stmt, 0, authid, false );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x06] (error: %s)", error);
        return false;
    }
    if ( SQL_FetchRow ( stmt ) ) {
        acount = SQL_FetchInt ( stmt, 0 );
    }
    
    if ( stmt != null ) {
        delete stmt;
    }

    if ( acount > 0 ) {
        return true;
    }
    return false;
}
 
public bool stringContains ( char string[32], char match[32] ) {
    return ( StrContains ( string, match, false ) != -1 );
}

public bool isValidSteamID ( char authid[32] ) {
    return ( StrContains ( authid, "STEAM_0" ) || StrContains ( authid, "STEAM_1" ) );
}

public void addKnifeEvent ( char attacker_name[64], char attacker_authid[32], char victim_name[64], char victim_authid[32], int points ) {
    databaseConnect ( )
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "insert into event (stamp,attacker,attackerid,victim,victimid,points) values (now(),?,?,?,?,?)", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error) );
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x01] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, attacker_name, false );
    SQL_BindParamString ( stmt, 1, attacker_authid, false );
    SQL_BindParamString ( stmt, 2, victim_name, false );
    SQL_BindParamString ( stmt, 3, victim_authid, false );
    SQL_BindParamInt ( stmt, 4, points );
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x02] (error: %s)", error);
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
 