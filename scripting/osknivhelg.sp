#include <sourcemod>
#include <sdktools>
#include <sdktools_gamerules>
#include <cstrike>

char error[255];
Handle knivhelg = null;
int adminPoints = 10;
int userPoints = 5;

public Plugin myinfo = {
	name = "OSKnivHelg",
	author = "Pintuz",
	description = "OldSwedes Kniva en admin helg plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSKnivHelg"
}

public void OnPluginStart ( ) {
    HookEvent ( "round_start", Event_RoundStart );
    HookEvent ( "player_death", Event_PlayerDeath );
    databaseConnect ( );
    populateAdminTable ( );
    RegConsoleCmd ( "sm_admintable", Command_AdminTable );
    AutoExecConfig ( true, "osknivhelg" );
}


/* EVENTS */
public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    if ( isFirstRound ( ) ) {
        populateAdminTable ( );
    }
}

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

    if ( ! StrContains ( weapon, "knife", false ) ) {
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

    if ( ! isValidSteamID ( victim_authid ) || ! isValidSteamID ( attacker_authid ) ) {
        return;
    }

    int points = userPoints;
    if ( isAdmin ( attacker_authid ) || isAdmin ( victim_authid ) ) {
        points = adminPoints;
    }

    addKnifeEvent ( attacker_name, attacker_authid, victim_name, victim_authid, points );
    PrintToChatAll ( "[OSKnivHelg]: %s knifed %s and got %d points!", attacker_name, victim_name, points );
}


/* END of EVENTS */

/* COMMANDS*/
public Action Command_AdminTable ( int client, int args ) {
    PrintToConsoleAll ( "Command_AdminTable!" )
    populateAdminTable ( );
    return Plugin_Handled;
}


/* METHODS */

public bool isValidSteamID ( char authid[32] ) {
    return true;
//    return ( StrContains ( authid, "STEAM_0" ) || StrContains ( authid, "STEAM_1" ) );
}

public void addKnifeEvent ( char attacker_name[64], char attacker_authid[32], char victim_name[64], char victim_authid[32], int points ) {
    databaseConnect ( )
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "insert into event (attacker,attackerid,victim,victimid,points) values (?,?,?,?,?)", error, sizeof(error) ) ) == null ) {
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

public bool isAdmin ( char authid[32] ) {
    databaseConnect ( )
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "select count(*) from admin where authid = ?", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x08] (error: %s)", error);
        return false;
    }
    SQL_BindParamString ( stmt, 0, authid, false );
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x03] (error: %s)", error);
    }
    int count = 0;
    if ( SQL_FetchRow ( stmt ) ) {
        count = SQL_FetchInt ( stmt, 0 );
    }
    delete stmt;
    return ( count > 0 );
}

public void databaseConnect ( ) {
    if ( ( knivhelg = SQL_Connect ( "knivhelg", true, error, sizeof(error) ) ) != null ) {
        PrintToServer ( "[OSKnivHelg]: Connected to knivhelg database!" );
    } else {
        PrintToServer ( "[OSKnivHelg]: Failed to connect to knivhelg database! (error: %s)", error );
    }
}

/* read admins from sourcebans and put them into knivhelg */
public void populateAdminTable ( ) {
    char name[64];
    char authid[32];
    DBStatement stmt = null;
    checkConnection ( );
    cleanAdminTable ( );
    Database sourcebans = SQL_Connect ( "sourcebans", true, error, sizeof(error) );
    stmt = SQL_PrepareQuery ( sourcebans, "select user,authid from sb_admins where aid != 0", error, sizeof(error) );
    SQL_Execute ( stmt );
    while ( SQL_FetchRow ( stmt ) ) {
        SQL_FetchString ( stmt, 0, name, sizeof(name) );
        SQL_FetchString ( stmt, 1, authid, sizeof(authid) );
        PrintToConsoleAll ( "[OSKnivHelg]: Found admin: %s (steamid: %s)", name, authid );
        addAdmin ( name, authid );
    }
    if ( stmt != null ) {
        CloseHandle ( stmt );
    }
    delete sourcebans;
}

public void checkConnection ( ) {
    if ( knivhelg == null || knivhelg == INVALID_HANDLE ) {
        databaseConnect ( );
    }
}

public void addAdmin ( char name[64], char authid[32] ) {
    DBStatement stmt = null;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "insert into admin (name,steamid) values (?,?)", error, sizeof(error) ) ) == null ) {
        PrintToServer("[OSKnivHelg]: Failed to query[0x06] (error: %s)", error);
        return;
    }
    PrintToConsoleAll ( "[OSKnivHelg]: Adding admin: %s (steamid: %s)", name, authid );
    SQL_BindParamString ( stmt, 0, name, false );
    SQL_BindParamString ( stmt, 1, authid, false );
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x01] (error: %s)", error);
    }
    if ( stmt != null ) {
        CloseHandle ( stmt );
    }    
}

public void cleanAdminTable ( ) {
    if ( ! SQL_FastQuery ( knivhelg, "delete from admin" ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x02] (error: %s)", error);
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

public bool isFirstRound ( ) {
    return ( ( GetTeamScore ( CS_TEAM_T ) + GetTeamScore ( CS_TEAM_CT ) ) <= 0 );
}