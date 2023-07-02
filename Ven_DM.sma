/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <cstrike>
#include <fakemeta>
#include <hamsandwich>
#include <engine>

#define PLUGIN "Ven DM"
#define VERSION "1.5"
#define AUTHOR "Arheisel"

// team ids 
#define UNASSIGNED 0 
#define TS 1 
#define CTS 2 
#define AUTO_TEAM 5 

#define MAX_PLAYERS    32

#define cs_set_user_team_fast(%1,%2)    set_pdata_int(%1, 114, _:%2)

#define IsPlayer(%1)    ( 1 <= %1 <= g_iMaxPlayers )

new const killSound[] = "fvox/bell.wav"
new const winSound[] = "misc/hlmusic.mp3"

new g_iMaxPlayers
new CsTeam:g_iResetTeam[MAX_PLAYERS+1]

new GGWeapon[MAX_PLAYERS+1]
new bool:gg_countKills = true


public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR)
		
	register_cvar("sv_dm", "1")
	register_cvar("dm_gungame", "0")
	register_cvar("dm_health_reward", "25")
	register_cvar("dm_respawn_delay", "1.0")
	register_cvar("dm_version", VERSION, FCVAR_SERVER)

	register_clcmd("say","on_Chat")
	register_clcmd("say_team","on_Chat")
	
	register_event( "TeamInfo", "event_team_info", "a" );
	
	register_message(get_user_msgid("Radar"), "radar_block")
	
	RegisterHam(Ham_TakeDamage, "player", "Player_TakeDamage_Pre")
	RegisterHam(Ham_TakeDamage, "player", "Player_TakeDamage_Post", 1)
	RegisterHam(Ham_Killed, "player", "Player_Killed", 1)
	RegisterHam(Ham_Spawn, "player", "fwHamPlayerSpawnPost", 1)
	
	register_touch("weaponbox", "player", "BlockPickup")
         register_touch("armoury_entity", "player", "BlockPickup")
	register_touch("weapon_shield", "player", "BlockPickup")
	
	g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
	precache_sound(killSound)
	precache_sound(winSound)
}

public client_putinserver(id){
    GGWeapon[id] = 0
}

public BlockPickup(weapon, id)
{
    if (get_cvar_num("dm_gungame") == 1)
             return PLUGIN_HANDLED;

    return PLUGIN_CONTINUE;
} 

public on_Chat(id)
{
	if ( !get_cvar_num("sv_dm") )
	{
		return PLUGIN_CONTINUE
	}

	new szSaid[32]
	read_args(szSaid, 31) 

	if (equali(szSaid,"^"/respawn^"") || equali(szSaid,"^"respawn^""))
	{
		spawn_func(id)
	}
	
	return PLUGIN_CONTINUE
}

public event_team_info()
{
	new id = read_data( 1 );
	
	new team[12];
	read_data( 2, team, sizeof team - 1 );
	
	if((team[0] == 'T' || team[0] == 'C') && !is_user_alive(id))
	{
		spawn_func(id)
	}
    
}

public radar_block() {
    return PLUGIN_HANDLED
}

public Player_TakeDamage_Pre(id, iInflictor, iAttacker)
{
	if(get_cvar_num("sv_dm") && IsPlayer( iAttacker ) && id != iAttacker )
	{
		new CsTeam:iTeam = cs_get_user_team(id)
		if( iTeam == cs_get_user_team(iAttacker) )
		{
			cs_set_user_team_fast(id, iTeam == CS_TEAM_T ? CS_TEAM_CT : CS_TEAM_T)
			g_iResetTeam[id] = iTeam
		}
	}
}

public Player_TakeDamage_Post(id)
{
	static iTeam
	if(get_cvar_num("sv_dm") && ( iTeam = g_iResetTeam[id] ) )
	{
		cs_set_user_team_fast(id, iTeam)
		g_iResetTeam[id] = CS_TEAM_UNASSIGNED
	}
}

public Player_Killed(id, iKiller)
{
	if(get_cvar_num("sv_dm"))
	{
		spawn_func( id )
		if(IsPlayer( iKiller ) && iKiller!= id )
		{
			set_user_health(iKiller, min(get_user_health(iKiller) +  get_cvar_num("dm_health_reward"), 100))
			
			if(get_cvar_num("dm_gungame") == 1 && gg_countKills){
				client_cmd(iKiller,"spk %s", killSound)
				
				GGWeapon[iKiller]++
				player_resetWeapons(iKiller)
				
				if(GGWeapon[iKiller] >= 24)
				{
					gg_countKills = false
					new parm[1]
					parm[0]=iKiller
					set_task(0.2,"reset_gg",99, parm, 1)
				}
			}
		}
		
		
	}
}

public reset_gg(parm[1]){
	new id = parm[0]
	
	new szName[32]
	get_user_name(id, szName, charsmax(szName))
	
	set_hudmessage(0, 255, 0, -1.0, -1.0)
	show_hudmessage(0, "Player %s has Won this round!", szName)
	
	client_cmd(0,"mp3 play sound/%s", winSound)
	
	new players[32] , num , iPlayer;
	
	get_players( players , num )
    
	for( new i = 0 ; i < num ; i++ )
	{
		iPlayer = players[ i ]
		GGWeapon[iPlayer] = 0
	}
	
	set_task(5.0, "reenable_kills", 99)
	
}

public reenable_kills(){
	gg_countKills = true
	server_cmd("sv_restartround 1")
}

public spawn_func(id)
{
	new parm[1]
	parm[0] = id
	
	/* Spawn the player twice to avoid the HL engine bug */
	set_task(get_cvar_float("dm_respawn_delay") + 0.5,"player_spawn",72,parm,1)
	set_task(get_cvar_float("dm_respawn_delay") + 0.7,"player_spawn",72,parm,1)
}

public player_spawn(parm[1])
{
	spawn(parm[0])
}

public fwHamPlayerSpawnPost(id) {
	if (is_user_alive(id)) {
		new parm[1]
		parm[0] = id
		set_task(0.2,"player_giveitems",id,parm,1)
	}
}

public player_giveitems(parm[1])
{
	new id = parm[0]
	
	protect(id)
	
	//to avoid running the function twice
	strip_user_weapons(id)
	
	cs_set_user_armor( id, 100, CsArmorType:CS_ARMOR_VESTHELM )
	give_item(id, "weapon_knife")
	
	if(get_cvar_num("dm_gungame") == 0)
	{
		new wpnList[32] = 0, number = 0, bool:foundGlock = false, bool:foundUSP = false 
		get_user_weapons(id,wpnList,number)
		
		/* Determine if the player already has a pistol */
		for (new i = 0;i < number;i++)
		{ 
			if (wpnList[i] == CSW_GLOCK18) 
				foundGlock = true 
			if (wpnList[i] == CSW_USP) 
				foundUSP = true 
		}
		
		/* Give a T his/her pistol */
		if ( get_user_team(id)==TS && !foundGlock )
		{
			give_item(id,"weapon_glock18")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
		}
		/* Give a CT his/her pistol */
		else if ( get_user_team(id)==CTS && !foundUSP )
		{
			give_item(id,"weapon_usp")
			give_item(id,"ammo_45acp")
			give_item(id,"ammo_45acp")
		}
	
		player_giverandomweapon(id, -1)
	}
	else
	{
		player_giverandomweapon(id, GGWeapon[id])	
	}
}

public player_resetWeapons(id){ //Gungame Only
	
	strip_user_weapons(id)
	
	give_item(id, "weapon_knife")
	player_giverandomweapon(id, GGWeapon[id])
}



public protect(id) // This is the function for the task_on godmode
{
	new Float:FFTime = get_cvar_float("mp_freezetime")
	new FTime = get_cvar_num("mp_freezetime")
	new SPShell = 25
	set_user_godmode(id, 1)

	if(get_user_team(id) == 1)
	{
		set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, SPShell)
	}
	
	if(get_user_team(id) == 2)
	{
		set_user_rendering(id, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, SPShell)
	}
	
	
	set_hudmessage(255, 1, 1, -1.0, -1.0, 0, 6.0, FFTime, 0.1, 0.2, 4)
	show_hudmessage(id, "Spawn Protection is enabled for %d second(s)", FTime)
	
	new parm[1]
	parm[0]=id
	set_task(FFTime, "sp_off", id, parm, 1)
}
//----------------------------------------------------------//
public sp_off(parm[1]) // This is the function for the task_off godmode
{
	new id = parm[0]
	
	if(!is_user_connected(id))
	{
		return PLUGIN_HANDLED
	}
	
	else
	{
		set_user_godmode(id, 0)
		set_user_rendering(id, kRenderFxGlowShell, 0, 0,0, kRenderNormal, 25)
		return PLUGIN_HANDLED
	}
}

public player_giverandomweapon(id, wnum)
{
	new int:rnum = 0
	
	if(wnum == -1)
	{
		rnum = random(17)
	}
	else
	{
		rnum = wnum
	}
	
	switch (rnum)
	{
		case  0:
		{
			give_item(id,"weapon_ak47")
			give_item(id,"ammo_762nato")
			give_item(id,"ammo_762nato")
			give_item(id,"ammo_762nato")
		}
		case 1:
		{
			give_item(id,"weapon_m4a1")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
		}
		case 2:
		{
			give_item(id,"weapon_sg552")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
		}
		case 3:
		{
			give_item(id,"weapon_aug")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
		}
		case 4:
		{
			give_item(id,"weapon_galil")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
		}
		case 5:
		{
			give_item(id,"weapon_famas")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
		}
		case 6:
		{
			give_item(id,"weapon_m249")
			give_item(id,"ammo_556natobox")
			give_item(id,"ammo_556natobox")
		}
		case 7:
		{
			give_item(id,"weapon_mp5navy")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
		}
		case 8:
		{
			give_item(id,"weapon_ump45")
			give_item(id,"ammo_45acp")
			give_item(id,"ammo_45acp")
			give_item(id,"ammo_45acp")
		}
		case 9:
		{
			give_item(id,"weapon_tmp")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
		}
		case 10:
		{
			give_item(id,"weapon_mac10")
			give_item(id,"ammo_45acp")
			give_item(id,"ammo_45acp")
			give_item(id,"ammo_45acp")
			give_item(id,"ammo_45acp")
		}
		case  11:
		{
			give_item(id,"weapon_p90")
			give_item(id,"ammo_57mm")
			give_item(id,"ammo_57mm")
			give_item(id,"ammo_57mm")
		}
		case  12:
		{
			give_item(id,"weapon_g3sg1")
			give_item(id,"ammo_762nato")
			give_item(id,"ammo_762nato")
			give_item(id,"ammo_762nato")
		}
		case 13:
		{
			give_item(id,"weapon_sg550")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
			give_item(id,"ammo_556nato")
		}
		case 14:
		{
			give_item(id,"weapon_awp")
			give_item(id,"ammo_338magnum")
			give_item(id,"ammo_338magnum")
			give_item(id,"ammo_338magnum")
		}
		case  15:
		{
			give_item(id,"weapon_scout")
			give_item(id,"ammo_762nato")
			give_item(id,"ammo_762nato")
			give_item(id,"ammo_762nato")
		}
		case 16:
		{
			give_item(id,"weapon_xm1014")
			give_item(id,"ammo_buckshot")
			give_item(id,"ammo_buckshot")
			give_item(id,"ammo_buckshot")
			give_item(id,"ammo_buckshot")
		}		
		case 17:
		{
			give_item(id,"weapon_m3")
			give_item(id,"ammo_buckshot")
			give_item(id,"ammo_buckshot")
			give_item(id,"ammo_buckshot")
			give_item(id,"ammo_buckshot")
		}
		case 18:
		{
			give_item(id,"weapon_deagle")
			give_item(id,"ammo_50ae")
			give_item(id,"ammo_50ae")
			give_item(id,"ammo_50ae")
			give_item(id,"ammo_50ae")
		}
		case 19:
		{
			give_item(id,"weapon_fiveseven")
			give_item(id,"ammo_57mm")
			give_item(id,"ammo_57mm")
			give_item(id,"ammo_57mm")
			give_item(id,"ammo_57mm")
		}
		case 20:
		{
			give_item(id,"weapon_glock18")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
		}
		case 21:
		{
			give_item(id,"weapon_usp")
			give_item(id,"ammo_45acp")
			give_item(id,"ammo_45acp")
			give_item(id,"ammo_45acp")
			give_item(id,"ammo_45acp")
		}
		case 22:
		{
			give_item(id,"weapon_elite")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
			give_item(id,"ammo_9mm")
		}
	}
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
