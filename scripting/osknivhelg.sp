#include <sourcemod>
#include <sdktools>
#include <sdktools_gamerules>
#include <cstrike>

char adminstr[1024];
char error[255];
Handle knivhelg = null;

ConVar adminPointsEnabled;

public Plugin myinfo = {
	name = "OSKnivHelg",
	author = "Pintuz",
	description = "OldSwedes Kniva en admin helg plugin",
	version = "0.02",
	url = "https://github.com/Pintuzoft/OSKnivHelg"
}

public void OnPluginStart ( ) {
    HookEvent ( "player_death", Event_PlayerDeath );
    adminPointsEnabled = CreateConVar ( "osknivhelg_admin_points_enabled", "1", "Enable admin points" );
    RegConsoleCmd ( "sm_ktop", Command_KnifeTop, "Shows the top 10 knife kills" );
    AutoExecConfig ( true, "osknivhelg" );
}

public void OnMapStart ( ) {
    checkConnection ( );
    fetchAdminStr ( );
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
    bool teamKill;
    int points = 5;

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

    teamKill = isTeamKill ( attacker, victim );

    if ( adminPointsEnabled.BoolValue && isPlayerAdmin ( victim_authid ) ) {
        points = 10;
    }

    isAttackerAdmin = isPlayerAdmin ( attacker_authid );
    isVictimAdmin = isPlayerAdmin ( victim_authid );

    addKnifeEvent ( attacker_name, attacker_authid, victim_name, victim_authid, points, teamKill );
    if ( teamKill ) {
        fixPoints ( victim_name, victim_authid, true, points );
        fixPoints ( attacker_name, attacker_authid, false, points );        
    } else {
        fixPoints ( attacker_name, attacker_authid, true, points );
    }
    PrintToChatCustom ( attacker_name, isAttackerAdmin, victim_name, isVictimAdmin, points, teamKill );
}


/* END of EVENTS */

/* COMMANDS*/
public Action Command_KnifeTop ( int client, int args ) {
    checkConnection ( );
    DBStatement stmt;
    char name[64];
    char steamid[32];
    char sid[32];
    int points;
    int i;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "select name,steamid,points from userstats order by points desc limit 10;", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x07] (error: %s)", error);
        return Plugin_Handled;
    }

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x08] (error: %s)", error);
        return Plugin_Handled;
    }

    GetClientAuthId ( client, AuthId_Steam2, steamid, sizeof ( steamid ) );
    if ( ! isValidSteamID ( steamid ) ) {
        steamid = "STEAM_9:9:9";
    }
    PrintToChat ( client, " \x04[OSKnivHelg]: Leaderboard:" );
    i = 1;
    while ( SQL_FetchRow ( stmt ) ) {
        SQL_FetchString ( stmt, 0, name, sizeof(name) );
        SQL_FetchString ( stmt, 1, sid, sizeof(sid) );
        points = SQL_FetchInt ( stmt, 2 );
        if ( StrContains ( steamid, sid, false ) ) {
            PrintToChat ( client, "  \x04%d. %s: %dp", i, name, points );
        } else {
            PrintToChat ( client, "  \x09%d. %s: %dp", i, name, points );
        }
        i++;
    }
    PrintToChat ( client, " \x04[OSKnivHelg]: Full stats: https://oldswedes.se/knivhelg" );
    return Plugin_Handled;
}

/* METHODS */
 

public void PrintToChatCustom ( char attacker[64], bool isAttackerAdmin, char victim[64], bool isVictimAdmin, int points, bool isTeamKill ) {
    char aAdmin[16];
    char vAdmin[16];
    if ( isAttackerAdmin ) {
        aAdmin = "\x08(admin) ";
    } else {
        aAdmin = "";
    }

    if ( isVictimAdmin ) {
        vAdmin = "\x08(admin) ";
    } else {
        vAdmin = "";
    }

    if ( isTeamKill ) {
        PrintToChatAll ( " \x04[OSKnivHelg]\x01: \x07%s %s\x01(-%dp) knife-TeamKilled \x06%s %s \x01(%dp)", attacker, aAdmin, points, victim, vAdmin, points );        
    } else { 
        PrintToChatAll ( " \x04[OSKnivHelg]\x01: \x06%s %s\x01(%dp) knifed \x07%s %s", attacker, aAdmin, points, victim, vAdmin );
    }
}

public void fetchAdminStr ( ) {
    char buf[32];
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "select steamid from admin;", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x09] (error: %s)", error);
        return;
    }

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x10] (error: %s)", error);
        return;
    }
    adminstr = "";
    while ( SQL_FetchRow ( stmt ) ) {
        SQL_FetchString ( stmt, 0, buf, sizeof(buf) );
        Format ( adminstr, sizeof(adminstr), "%s;%s", adminstr, buf );
    } 
    PrintToServer ( "[OSKnivHelg]: adminstr: %s", adminstr );

    if ( stmt != null ) {
        delete stmt;
    }
}

public void fixPoints ( char name[64], char authid[32], bool increase, int points ) {
    checkConnection ();
    char query[255];
    DBStatement stmt;
    if ( increase ) {
        Format ( query, sizeof(query), "insert into userstats (name,steamid,points) values (?,?,?) on duplicate key update points = points + ?;" );
    } else {
        Format ( query, sizeof(query), "insert into userstats (name,steamid,points) values (?,?,?) on duplicate key update points = points - ?;" );
    }
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, query, error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x02] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, name, false );
    SQL_BindParamString ( stmt, 1, authid, false );
    if ( increase ) {
        SQL_BindParamInt ( stmt, 2, points );
    } else {
        SQL_BindParamInt ( stmt, 2, -points );
    }
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
    ReplaceString ( authid, sizeof(authid), "STEAM_0", "STEAM_1" );
    return ( StrContains ( adminstr, authid, false ) != -1 );
}
 
public bool stringContains ( char string[32], char match[32] ) {
    return ( StrContains ( string, match, false ) != -1 );
}

public bool isValidSteamID ( char authid[32] ) {
    if ( stringContains ( authid, "STEAM_0" ) ) {
        return true;
    } else if ( stringContains ( authid, "STEAM_1" ) ) {
        return true;
    }
    return false;
}

public void addKnifeEvent ( char attacker_name[64], char attacker_authid[32], char victim_name[64], char victim_authid[32], int points, bool isTeamKill ) {
    checkConnection ( )
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( knivhelg, "insert into event (stamp,attacker,attackerid,victim,victimid,points,type) values (now(),?,?,?,?,?,?)", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( knivhelg, error, sizeof(error) );
        PrintToServer("[OSKnivHelg]: Failed to prepare query[0x01] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 0, attacker_name, false );
    SQL_BindParamString ( stmt, 1, attacker_authid, false );
    SQL_BindParamString ( stmt, 2, victim_name, false );
    SQL_BindParamString ( stmt, 3, victim_authid, false );
    SQL_BindParamInt ( stmt, 4, points );
    if ( isTeamKill ) {
        SQL_BindParamInt ( stmt, 5, 1 );
    } else {
        SQL_BindParamInt ( stmt, 5, 0 );
    }
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( knivhelg, error, sizeof(error));
        PrintToServer("[OSKnivHelg]: Failed to query[0x02] (error: %s)", error);
    }
    if ( stmt != null ) {
        delete stmt;
    }
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
 
/* IS TEAMKILL */
public bool isTeamKill ( int attacker, int victim ) {
    if ( GetClientTeam ( attacker ) == GetClientTeam ( victim ) ) {
        return true;
    }
    return false;
}

/* return true if player is real */
public bool playerIsReal ( int player ) {
    return ( player > 0 &&
             IsClientInGame ( player ) &&
             ! IsClientSourceTV ( player ) );
}

/* isWarmup */
public bool isWarmup ( ) {
    if ( GameRules_GetProp ( "m_bWarmupPeriod" ) == 1 ) {
        return true;
    } 
    return false;
}
 