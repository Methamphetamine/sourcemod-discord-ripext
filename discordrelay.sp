#pragma semicolon 1

//Just for debuging discord->server messages
//#define DEBUG 1

#define PLUGIN_NAME         "Discord Relay (Ripetx) Edit"
#define PLUGIN_AUTHOR       "log-ical & Buddy"
#define PLUGIN_DESCRIPTION  "Discord and Server interaction"
#define PLUGIN_VERSION      "0.8.1"
#define PLUGIN_URL          "https://github.com/IsThatLogic/sp-discordrelay"

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <discord>
#include <colors>
#include <geoip>
#undef REQUIRE_EXTENSIONS
#include <ripext>

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
}

DiscordBot g_dBot;

enum struct playerData
{
	int userid;
	char avatarurl[256];
}

playerData playersdata[MAXPLAYERS + 1];

#define GREEN "#008000"
#define RED "#ff2222"
#define YELLOW "#daa520"

bool maptimer = false;

ConVar g_cvmsg_textcol; char g_msg_textcol[32];
ConVar g_cvmsg_varcol; char g_msg_varcol[32];

ConVar g_cvSteamApiKey; char g_sSteamApiKey[128];
ConVar g_cvDiscordBotToken; char g_sDiscordBotToken[128];
ConVar g_cvDiscordWebhook; char g_sDiscordWebhook[256];
ConVar g_cvRCONWebhook; char g_sRCONWebhook[256];

ConVar g_cvDiscordServerId; char g_sDiscordServerId[64];
ConVar g_cvChannelId; char g_sChannelId[64];
ConVar g_cvRCONChannelId; char g_sRCONChannelId[64];

ConVar g_cvSBPPAvatar; char g_sSBPPAvatar[64];

ConVar g_cvServerToDiscord; //requires discord bot key
ConVar g_cvDiscordToServer; //requires discord webhook
ConVar g_cvServerToDiscordAvatars; //requires steam api key
ConVar g_cvRCONDiscordToServer; //requires discord bot key
ConVar g_cvPrintRCONResponse;

ConVar g_cvServerMessage;
ConVar g_cvConnectMessage; 
ConVar g_cvDisconnectMessage; 
ConVar g_cvMapChangeMessage; 
ConVar g_cvMessage; 
ConVar g_cvHideExclamMessage; 

ConVar g_cvPrintSBPPBans;
ConVar g_cvPrintSBPPComms;

char lCommbanTypes[][] = {
    "",
    "muted",
    "gagged",
    "silenced"
};

char CommbanTypes[][] = {
    "",
    "Muted",
    "Gagged",
    "Silenced"
};

char sCommbanTypes[][] = {
    "",
    "Mute",
    "Gag",
    "Silence"
};

public void OnPluginStart()
{
    // Keys/Tokens
    g_cvSteamApiKey = CreateConVar("discrelay_steamapikey", "", "Your Steam API key (needed for discrelay_servertodiscordavatars)");
    g_cvDiscordBotToken = CreateConVar("discrelay_discordbottoken", "", "Your discord bot key (needed for discrelay_discordtoserver)");
    g_cvDiscordWebhook = CreateConVar("discrelay_discordwebhook", "", "Webhook for discord channel (needed for discrelay_servertodiscord)");

    // IDs
    g_cvDiscordServerId = CreateConVar("discrelay_discordserverid", "", "Discord Server Id, required for discord to server");
    g_cvChannelId = CreateConVar("discrelay_channelid", "", "Channel Id for discord to server (This channel would be the one where the plugin check for messages to send to the server)");
    g_cvRCONChannelId = CreateConVar("discrelay_rcon_channelid", "", "Channel ID where rcon commands should be sent");
    g_cvRCONWebhook = CreateConVar("discrelay_rcon_webhook", "", "Webhook for rcon reponses, required for discrelay_rcon_printreponse");

    // Switches
    g_cvServerToDiscord = CreateConVar("discrelay_servertodiscord", "1", "Enables messages sent in the server to be forwarded to discord");
    g_cvDiscordToServer = CreateConVar("discrelay_discordtoserver", "1", "Enables messages sent in discord to be forwarded to server (discrelay_discordtoserver and discrelay_discordbottoken need to be set)");
    g_cvServerToDiscordAvatars = CreateConVar("discrelay_servertodiscordavatars", "1", "Changes webhook avatar to clients steam avatar (discrelay_servertodiscord needs to set to 1, and steamapi key needs to be set)");
    g_cvRCONDiscordToServer = CreateConVar("discrelay_rcon_enabled", "0", "Enables RCON functionality");
    g_cvPrintRCONResponse = CreateConVar("discrelay_rcon_printreponse", "1", "Prints reponse from command (discrelay_rcon_webhook required)");

    // Message Switches
    g_cvServerMessage = CreateConVar("discrelay_servermessage", "1", "Prints server say commands to discord (discrelay_servertodiscord needs to set to 1)");
    g_cvConnectMessage = CreateConVar("discrelay_connectmessage", "1", "relays client connection to discord (discrelay_servertodiscord needs to set to 1)");
    g_cvDisconnectMessage = CreateConVar("discrelay_disconnectmessage", "1", "relays client disconnection messages to discord (discrelay_servertodiscord needs to set to 1)");
    g_cvMapChangeMessage = CreateConVar("discrelay_mapchangemessage", "1", "relays map changes to discord (discrelay_servertodiscord needs to set to 1)");
    g_cvMessage = CreateConVar("discrelay_message", "1", "relays client messages to discord (discrelay_servertodiscord needs to set to 1)");
    g_cvHideExclamMessage = CreateConVar("discrelay_hideexclammessage", "1", "Hides any message that begins with !");

    // Customization
    g_cvmsg_textcol = CreateConVar("discrelay_msg_textcol", "{default}", "text color of discord to server text (refer to github for support, the ways you can chose colors depends on game)");
    g_cvmsg_varcol = CreateConVar("discrelay_msg_varcol", "{default}", "variable color of discord to server text (refer to github for support, the ways you can chose colors depends on game)");
    
    // SBPP Customization
    g_cvPrintSBPPBans = CreateConVar("discrelay_printsbppbans", "0", "Prints bans to channel that webhook points to, sbpp must be installed for this to function");
    g_cvPrintSBPPComms = CreateConVar("discrelay_printsbppcomms", "0", "Prints comm bans to channel that webhook pints to, sbpp must be installed for this to function");
    g_cvSBPPAvatar = CreateConVar("discrelay_sbppavatar", "", "Image url the webhook will use for profile avatar for sourcebans++ functions, leave blank for default discord avatar");
    
    AutoExecConfig(true, "discordrelay");

    GetConVarString(g_cvSteamApiKey, g_sSteamApiKey, sizeof(g_sSteamApiKey));
    GetConVarString(g_cvDiscordWebhook, g_sDiscordWebhook, sizeof(g_sDiscordWebhook));
    GetConVarString(g_cvRCONWebhook, g_sRCONWebhook, sizeof(g_sRCONWebhook));

    GetConVarString(g_cvDiscordServerId, g_sDiscordServerId, sizeof(g_sDiscordServerId));
    GetConVarString(g_cvChannelId, g_sChannelId, sizeof(g_sChannelId));
    GetConVarString(g_cvRCONChannelId, g_sRCONChannelId, sizeof(g_sRCONChannelId));

    GetConVarString(g_cvmsg_textcol, g_msg_textcol, sizeof(g_msg_textcol));
    GetConVarString(g_cvmsg_varcol, g_msg_varcol, sizeof(g_msg_varcol));

    GetConVarString(g_cvSBPPAvatar, g_sSBPPAvatar, sizeof(g_sSBPPAvatar));

    g_cvSteamApiKey.AddChangeHook(OnDiscordRelayCvarChanged);
    g_cvDiscordBotToken.AddChangeHook(OnDiscordRelayCvarChanged);
    g_cvDiscordWebhook.AddChangeHook(OnDiscordRelayCvarChanged);
    g_cvRCONWebhook.AddChangeHook(OnDiscordRelayCvarChanged);

    g_cvDiscordServerId.AddChangeHook(OnDiscordRelayCvarChanged);
    g_cvChannelId.AddChangeHook(OnDiscordRelayCvarChanged);
    g_cvRCONChannelId.AddChangeHook(OnDiscordRelayCvarChanged);

    g_cvmsg_textcol.AddChangeHook(OnDiscordRelayCvarChanged);
    g_cvmsg_varcol.AddChangeHook(OnDiscordRelayCvarChanged);

    g_cvSBPPAvatar.AddChangeHook(OnDiscordRelayCvarChanged);

    if(g_cvDiscordToServer.BoolValue || g_cvRCONDiscordToServer.BoolValue) {
        CreateTimer(1.0, Timer_CreateBot);
    }
}

public Action Timer_CreateBot(Handle timer)
{
    GetConVarString(g_cvDiscordBotToken, g_sDiscordBotToken, sizeof(g_sDiscordBotToken));
    if(g_sDiscordBotToken[0]){
        if(g_dBot) {
#if defined DEBUG
            LogError("Bot handle already exists returning");
#endif
            return Plugin_Continue;
        }
        g_dBot = new DiscordBot(g_sDiscordBotToken);
        CreateTimer(1.0, Timer_GetGuildList, _, TIMER_FLAG_NO_MAPCHANGE);
#if defined DEBUG
        LogError("Creating bot with TOKEN = '%s'.\nCreating GetGuildList Timer", g_sDiscordBotToken);
#endif
    }
    else{
        //temp fix for bot being created with token that doesn't exist yet
        CreateTimer(5.0, Timer_CreateBot);
        LogError("Failed to create bot with Bot Token : %s", g_sDiscordBotToken);
    }
    
    return Plugin_Stop;
}


public void OnDiscordRelayCvarChanged(ConVar convar, char[] oldValue, char[] newValue)
{
    g_cvSteamApiKey.GetString(g_sSteamApiKey, sizeof(g_sSteamApiKey));
    g_cvDiscordBotToken.GetString(g_sDiscordBotToken, sizeof(g_sDiscordBotToken));
    g_cvDiscordWebhook.GetString(g_sDiscordWebhook, sizeof(g_sDiscordWebhook));
    g_cvRCONWebhook.GetString(g_sRCONWebhook, sizeof(g_sRCONWebhook));
    g_cvDiscordServerId.GetString(g_sDiscordServerId, sizeof(g_sDiscordServerId));
    g_cvChannelId.GetString(g_sChannelId, sizeof(g_sChannelId));
    g_cvRCONChannelId.GetString(g_sRCONChannelId, sizeof(g_sRCONChannelId));
    g_cvmsg_textcol.GetString(g_msg_textcol, sizeof(g_msg_textcol));
    g_cvmsg_varcol.GetString(g_msg_varcol, sizeof(g_msg_varcol));
    g_cvSBPPAvatar.GetString(g_sSBPPAvatar, sizeof(g_sSBPPAvatar));
}

public void OnClientPutInServer(int client)
{
    if(!IsValidClient(client))
       return;
    
    playersdata[client].userid = GetClientUserId(client);
    
    if(g_cvServerToDiscordAvatars.BoolValue)
    {
        SteamAPIRequest(client);
    }
    else {
        if(g_cvConnectMessage.BoolValue) {
            PrintToDiscord(client, GREEN, "connected");
        }
    }
}

public void OnMapStart()
{   
    //prevents failed webhook error on server startup
    if(!g_sDiscordWebhook[0])
        return;
    if(maptimer)
        return;
    maptimer = true;
    CreateTimer(5.0, mapstarttimer);
    CreateTimer(4.0, Timer_MapStart);
    if(g_cvDiscordToServer.BoolValue) {
        CreateTimer(2.0, Timer_CreateBot);
    }
}

public void OnMapEnd() {
    if(g_dBot != null) {
        g_dBot.StopListeningToChannelID(g_sChannelId);
        g_dBot.StopListeningToChannelID(g_sRCONChannelId);
        g_dBot.StopListening();
        delete g_dBot;
        g_dBot = null;
    }
}

public Action Timer_MapStart(Handle timer)
{
    char buffer[64];
    //GetCurrentMap(buffer, sizeof(buffer));
    GetCurrentMapLower(buffer, sizeof(buffer));
    GetMapName(buffer, buffer, sizeof(buffer));
    PrintToDiscordMapChange(buffer, YELLOW);
    
    return Plugin_Stop;
}

public Action mapstarttimer(Handle timer)
{
    maptimer = false;
    
    return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
    if(!IsValidClient(client))
        return;
    if(!g_cvDisconnectMessage.BoolValue)
        return;
    PrintToDiscord(client, RED, "disconnected");
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    if(g_cvHideExclamMessage.BoolValue) {
        if(!strncmp(sArgs, "!", 1) || !strncmp(sArgs, "/", 1)) { 
            return;
        }
    }
    char buffer[128];
    //this might be unsafe
    //max amount of char in message is 127 so this should be fine
    strcopy(buffer, sizeof(buffer), sArgs);
    if(StrContains(buffer, "@", false) != -1)
    {
        ReplaceString(buffer, sizeof(buffer), "@", "＠");
    }
    PrintToDiscordSay(client, buffer);
}

public void SBPP_OnBanPlayer(int admin, int target, int time, const char[] reason)
{
    if(!g_cvPrintSBPPBans.BoolValue)
        return;
    DiscordWebHook hook = new DiscordWebHook(g_sDiscordWebhook);
    hook.SlackMode = false;

    hook.SetAvatar(g_sSBPPAvatar);
    
    hook.SetUsername("Player Banned");
    
    MessageEmbed Embed = new MessageEmbed();
    
    Embed.SetColor("#FF0000");
    
    char bsteamid[65];
    char bplayerName[512];
    GetClientAuthId(target, AuthId_SteamID64, bsteamid, sizeof(bsteamid), false);
    Format(bplayerName, sizeof(bplayerName), "[%N](https://www.steamcommunity.com/profiles/%s)", target, bsteamid);
    //Banned Player Link Embed


    char asteamid[65];
    char aplayerName[512];
    if(!IsValidClient(admin))
    {
        Format(aplayerName, sizeof(aplayerName), "Penis NeGrow");
    }
    else{
    GetClientAuthId(admin, AuthId_SteamID64, asteamid, sizeof(asteamid), false);
    Format(aplayerName, sizeof(aplayerName), "[%N](https://www.steamcommunity.com/profiles/%s)", admin, asteamid);
    //Admin Link Embed
    }

    char banMsg[512];
    Format(banMsg, sizeof(banMsg), "%s has been banned by %s", bplayerName, aplayerName);
    Embed.AddField("", banMsg, false);


    Embed.AddField("Reason: ", reason, true);
    char sTime[16];
    IntToString(time, sTime, sizeof(sTime));
    Embed.AddField("Length: ", sTime, true);

    char CurrentMap[64];
    //GetCurrentMap(CurrentMap, sizeof(CurrentMap));
    GetCurrentMapLower(CurrentMap, sizeof(CurrentMap));
    GetMapName(CurrentMap, CurrentMap, sizeof(CurrentMap));
    Embed.AddField("Map: ", CurrentMap, true);
    char sRealTime[32];
    FormatTime(sRealTime, sizeof(sRealTime), "%m-%d-%Y %I:%M:%S", GetTime());  
    Embed.AddField("Time: ", sRealTime, true);

    char hostname[64];
    GetHostName(hostname, sizeof(hostname));
    Embed.SetFooter(hostname, g_sSBPPAvatar);

    Embed.SetTitle("SourceBans");
    
    hook.Embed(Embed);

    hook.Send();
    delete Embed;
    delete hook;
}
public void SourceComms_OnBlockAdded(int admin, int target, int time, int type, char[] reason)
{
    if(!g_cvPrintSBPPComms.BoolValue)
        return;
    if(type>3)
        return;
    DiscordWebHook hook = new DiscordWebHook(g_sDiscordWebhook);
    hook.SlackMode = true;

    hook.SetAvatar(g_sSBPPAvatar);
    
    char usrname[32];
    Format(usrname, sizeof(usrname), "Player %s", CommbanTypes[type]);
    hook.SetUsername(usrname);
    
    MessageEmbed Embed = new MessageEmbed();
    
    Embed.SetColor("#6495ED");
    
    char bsteamid[65];
    char bplayerName[512];
    GetClientAuthId(target, AuthId_SteamID64, bsteamid, sizeof(bsteamid), false);
    Format(bplayerName, sizeof(bplayerName), "[%N](https://www.steamcommunity.com/profiles/%s)", target, bsteamid);
    //Banned Player Link Embed


    char asteamid[65];
    char aplayerName[512];
    if(!IsValidClient(admin))
    {
        Format(aplayerName, sizeof(aplayerName), "Penis NeGrow");
    }
    else{
    GetClientAuthId(admin, AuthId_SteamID64, asteamid, sizeof(asteamid), false);
    Format(aplayerName, sizeof(aplayerName), "[%N](https://www.steamcommunity.com/profiles/%s)", admin, asteamid);
    //Admin Link Embed
    }

    char banMsg[512];
    Format(banMsg, sizeof(banMsg), "%s has been %s by %s", bplayerName, lCommbanTypes[type], aplayerName);
    Embed.AddField("", banMsg, false);


    Embed.AddField("Reason: ", reason, true);
    char sTime[16];
    IntToString(time, sTime, sizeof(sTime));
    Embed.AddField("Length: ", sTime, true);

    Embed.AddField("Type: ", sCommbanTypes[type], true);
    char CurrentMap[64];
    //GetCurrentMap(CurrentMap, sizeof(CurrentMap));
    GetCurrentMapLower(CurrentMap, sizeof(CurrentMap));
    GetMapName(CurrentMap, CurrentMap, sizeof(CurrentMap));
    Embed.AddField("Map: ", CurrentMap, true);
    char sRealTime[32];
    FormatTime(sRealTime, sizeof(sRealTime), "%m-%d-%Y %I:%M:%S", GetTime()); 
    Embed.AddField("Time: ", sRealTime, true);

    char hostname[64];
    GetHostName(hostname, sizeof(hostname));
    Embed.SetFooter(hostname, g_sSBPPAvatar);

    Embed.SetTitle("SourceComms");
    
    hook.Embed(Embed);

    hook.Send();
    delete Embed;
    delete hook;
}


public void PrintToDiscord(int client, const char[] color, const char[] msg, any ...)
{
    if(!g_cvServerToDiscord.BoolValue)
        return;
    if(!g_cvMessage.BoolValue)
        return;
    
    char clientName[36];
    
    if(!client || !IsClientConnected(client))
        return;
        
    GetClientName(client, clientName, 36);
    
    DiscordWebHook hook = new DiscordWebHook(g_sDiscordWebhook);
    
    hook.SlackMode = false;
    
    char gIp[48], gCountry[46];
    GetClientIP(client, gIp, sizeof(gIp), true);
    GeoipCountry(gIp, gCountry, sizeof(gCountry));
    Format(gCountry, sizeof(gCountry), "(%s)", gCountry);

    if(g_cvServerToDiscordAvatars.BoolValue)
        hook.SetAvatar(playersdata[client].avatarurl);
    
    char steamid1[64];
    GetClientAuthId(client, AuthId_Steam2, steamid1, sizeof(steamid1), false);
    char buffer[128];
    Format(buffer, 128, "%s [%s]", clientName, steamid1);
    hook.SetUsername(buffer);
    
    MessageEmbed Embed = new MessageEmbed();
    
    Embed.SetColor(color);
    
    char steamid[65];
    char playerName[512];
    GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid), false);
    Format(playerName, sizeof(playerName), "[%N](https://www.steamcommunity.com/profiles/%s)", client, steamid);

    char desc[512];
    Format(desc, sizeof(desc, "**%s** %s %s", playerName, msg, gCountry);
    Embed.SetDescription(desc);
    
    hook.Embed(Embed);

    hook.Send();
    delete Embed;
    delete hook;
}

public void PrintToDiscordSay(int client, const char[] msg, any ...)
{
    if(!g_cvServerToDiscord.BoolValue)
        return;

    DiscordWebHook hook = new DiscordWebHook(g_sDiscordWebhook);

    hook.SlackMode = false;

    if(!IsValidClient(client))
    {
        if(!g_cvServerMessage.BoolValue)
            return;
        hook.SetContent(msg);
        //we will just assume that if it isn't a valid client then it must be the server
        hook.SetUsername("Penis NeGrow");
        hook.Send();
        return;
    }
    
    char clientName[32];
    GetClientName(client, clientName, 32);

    if(g_cvServerToDiscordAvatars.BoolValue)
        hook.SetAvatar(playersdata[client].avatarurl);

    hook.SetContent(msg);

    char steamid[64];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), false);
    char buffer[128];
    Format(buffer, 128, "%s [%s]", clientName, steamid);
    hook.SetUsername(buffer);

    hook.Send();
    delete hook;
}

public void PrintToDiscordMapChange(const char[] map, const char[] color)
{
    if(!g_cvServerToDiscord.BoolValue)
        return;
    if(!g_cvMapChangeMessage.BoolValue)
        return;
    DiscordWebHook hook = new DiscordWebHook(g_sDiscordWebhook);
    
    hook.SlackMode = false;
    hook.SetUsername("Смена карты");
    
    char buffer[512];
    Format(buffer, sizeof(buffer), "%d/%d", GetOnlinePlayers(), GetMaxHumanPlayers());
    
    char desc[1024];
    Format(desc, sizeof(desc), "**Карта:** %s\n**Игроки:** %s", map, buffer);
    
    MessageEmbed Embed = new MessageEmbed();
    Embed.SetColor(color);
    Embed.SetDescription(desc);
    
    hook.Embed(Embed);
    hook.Send();
    delete Embed;
    delete hook;
}

public Action Timer_GetGuildList(Handle timer)
{
    ParseGuilds();
#if defined DEBUG
    LogError("Calling ParseGuilds Function");
#endif

    return Plugin_Stop;
}

stock void ParseGuilds()
{	
    g_dBot.GetGuilds(GuildList);
#if defined DEBUG
    LogError("Calling GetGuilds on g_dBot handle");
#endif
}

public void GuildList(DiscordBot bot, char[] id, char[] name, char[] icon, bool owner, int permissions, any data)
{
    g_dBot.GetGuildChannels(id, ChannelList, INVALID_FUNCTION);
#if defined DEBUG
    LogError("Calling GetGuildChannels on g_dBot handle");
#endif
}

public void ChannelList(DiscordBot bot, const char[] guild, DiscordChannel chl, any data)
{
    if(StrEqual(guild, g_sDiscordServerId))
    {
        if(g_dBot == null || chl == null)
        {
#if defined DEBUG
            LogError("Bot or Channel invalid");
#endif
            return;
        }
        if(g_dBot.IsListeningToChannel(chl))
        {
#if defined DEBUG
            LogError("Returning ChannelList function. Bot already listening to channel");
#endif
            return;
        }
        char id[20];
        chl.GetID(id, sizeof(id));
        if(g_cvDiscordToServer.BoolValue) {
            if(StrEqual(id, g_sChannelId))
            {
                g_dBot.StartListeningToChannel(chl, OnDiscordMessageSent);
#if defined DEBUG
            LogError("Calling StartListeningToChannel on g_dBot handle for message channel");
#endif
            }
        }
        if(g_cvRCONDiscordToServer.BoolValue)
        {
            if(StrEqual(id, g_sRCONChannelId))
            {
                g_dBot.StartListeningToChannel(chl, OnDiscordMessageSent);
#if defined DEBUG
            LogError("Calling StartListeningToChannel on g_dBot handle for RCON channel");
#endif
            }
        }
    }
}

public void OnDiscordMessageSent(DiscordBot bot, DiscordChannel chl, DiscordMessage discordmessage)
{
#if defined DEBUG
    LogError("Discord message sent");
#endif
    DiscordUser author = discordmessage.GetAuthor();
    
    if(author == null || author.IsBot())
    {
#if defined DEBUG
        LogError("Message from bot or no author, returning");
#endif
        return;
    }
    
    char id[20];
    chl.GetID(id, sizeof(id));
        
    if(StrEqual(id, g_sChannelId))
    {
        char message[512];
        char discorduser[32];
        discordmessage.GetContent(message, sizeof(message));
        author.GetUsername(discorduser, sizeof(discorduser));
    
        CPrintToChatAll("%s[%sDiscord%s] %s%s%s: %s", g_msg_textcol, g_msg_varcol, g_msg_textcol, g_msg_varcol, discorduser, g_msg_textcol, message);
        
#if defined DEBUG
        LogError("Printing message '%s' from '%s' to server chat", message, discorduser);
#endif
    }
    
    if(StrEqual(id, g_sRCONChannelId))
    {
#if defined DEBUG
        LogError("RCON channel detected! Processing RCON command");
#endif
        
        char message[512];
        discordmessage.GetContent(message, sizeof(message));
        
#if defined DEBUG
        LogError("RCON command received: %s", message);
#endif
        
        if(g_cvPrintRCONResponse.BoolValue)
        {
#if defined DEBUG
            LogError("PrintRCONResponse is enabled, executing command with response");
#endif
            
            char Response[2048];
            char fResponse[2054];
            ServerCommandEx(Response, sizeof(Response), message);
            
#if defined DEBUG
            LogError("Command executed, response length: %d", strlen(Response));
#endif
            
            Format(fResponse, sizeof(fResponse), "``` %s ```", Response);
            DiscordWebHook hook = new DiscordWebHook(g_sRCONWebhook);
            hook.SlackMode = false;
            hook.SetContent(fResponse);
            hook.SetUsername("DeCrow");
            hook.Send();
            delete hook;
        }
        else
        {
#if defined DEBUG
            LogError("PrintRCONResponse is disabled, executing command without response");
#endif
            ServerCommand(message);
        }
    }
}

stock void SteamAPIRequest(int client) {
    char url[1024];
    char steamid[64];
    GetClientAuthId(client, AuthId_SteamID64, steamid, sizeof(steamid), false);
    Format(url, sizeof(url), "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s", g_sSteamApiKey, steamid);
    
    HTTPRequest request = new HTTPRequest(url);
    request.Timeout = 10;
    request.Get(SteamResponse_Callback, client);
}

public void SteamResponse_Callback(HTTPResponse response, int client) {
	if (response.Status != HTTPStatus_OK) {
		LogError("SteamAPI request fail, HTTPStatus code %i", response.Status);
		if(g_cvConnectMessage.BoolValue)
			PrintToDiscord(client, GREEN, "connected");
		return;
	}
	
	JSONObject objects = view_as<JSONObject>(response.Data);
	JSON responseJson = objects.Get("response");
	JSONObject Response = view_as<JSONObject>(responseJson);
	JSON playersJson = Response.Get("players");
	JSONArray players = view_as<JSONArray>(playersJson);
	int playerlen = players.Length;
	JSONObject player;
	for (int i = 0; i < playerlen; i++) {
		JSON item = players.Get(i);
		player = view_as<JSONObject>(item);
		player.GetString("avatarmedium", playersdata[client].avatarurl, sizeof(playerData::avatarurl));
	}
	
	if(g_cvConnectMessage.BoolValue)
		PrintToDiscord(client, GREEN, "connected");
		
	delete objects;
}

bool GetMapName(const char[] mapId, char[] mapName, int iLength)
{
    KeyValues kv = new KeyValues("DiscordScoreboard");

    char sFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/discord_maps.cfg");

    if (!FileExists(sFile))
    {
        SetFailState("[GetMapName] \"%s\" not found!", sFile);
        return false;
    }

    kv.ImportFromFile(sFile);

    if (!kv.JumpToKey(mapId, false))
    {
        SetFailState("[GetMapName] Can't find map \"%s\" in \"%s\"!", mapId, sFile);
        delete kv;
        return false;
    }
    kv.GetString(NULL_STRING, mapName, iLength);
    delete kv;
    return true;
}

stock bool IsValidClient(int client)
{
    if (client <= 0)
        return false;
    
    if (client > MaxClients)
        return false;
    
    if (!IsClientConnected(client))
        return false;
    
    if (IsFakeClient(client))
        return false;

    return IsClientInGame(client);
}

stock int GetOnlinePlayers()
{
	int count;
	for(int i = 1; i <= MaxClients; i++)
	{	
		if(IsClientConnected(i) && !IsFakeClient(i) && !IsClientSourceTV(i))
		{
			count++;
		}
	}
	return count;
}

void GetHostName(char[] str, int size)
{
    static Handle hHostName;
    
    if(hHostName == INVALID_HANDLE)
    {
        if( (hHostName = FindConVar("hostname")) == INVALID_HANDLE)
        {
            return;
        }
    }
    GetConVarString(hHostName, str, size);
}

void StrToLower(char[] arg) {
    for (int i = 0; i < strlen(arg); i++) {
        arg[i] = CharToLower(arg[i]);
    }
}

int GetCurrentMapLower(char[] buffer, int buflen) {
    int iBytesWritten = GetCurrentMap(buffer, buflen);
    StrToLower(buffer);
    return iBytesWritten;
}
