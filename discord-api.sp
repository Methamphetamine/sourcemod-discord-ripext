#pragma semicolon 1
#pragma dynamic 50000

#define PLUGIN_VERSION "2.0.0-ripext"

#include <sourcemod>
#include <ripext>
#include "discord.inc"

public Plugin myinfo = {
    name = "Discord API (RIPEXT)",
    author = "Deathknife / Ripext Port",
    description = "Discord API using REST in Pawn",
    version = PLUGIN_VERSION,
    url = ""
};

StringMap hRateLimit = null;
StringMap hRateReset = null;
StringMap hRateLeft = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("DiscordBot.GetToken", Native_DiscordBot_Token_Get);
    CreateNative("DiscordBot.SendMessage", Native_DiscordBot_SendMessage);
    CreateNative("DiscordBot.SendMessageToChannelID", Native_DiscordBot_SendMessageToChannel);
    CreateNative("DiscordChannel.SendMessage", Native_DiscordChannel_SendMessage);
    CreateNative("DiscordBot.DeleteMessageID", Native_DiscordBot_DeleteMessageID);
    CreateNative("DiscordBot.DeleteMessage", Native_DiscordBot_DeleteMessage);
    CreateNative("DiscordBot.StartTimer", Native_DiscordBot_StartTimer);
    CreateNative("DiscordBot.GetGuilds", Native_DiscordBot_GetGuilds);
    CreateNative("DiscordBot.GetGuildChannels", Native_DiscordBot_GetGuildChannels);
    CreateNative("DiscordBot.GetGuildRoles", Native_DiscordBot_GetGuildRoles);
    CreateNative("DiscordBot.AddReactionID", Native_DiscordBot_AddReaction);
    CreateNative("DiscordBot.DeleteReactionID", Native_DiscordBot_DeleteReaction);
    CreateNative("DiscordBot.GetReactionID", Native_DiscordBot_GetReaction);
    CreateNative("DiscordBot.GetGuildMembers", Native_DiscordBot_GetGuildMembers);
    CreateNative("DiscordBot.GetGuildMembersAll", Native_DiscordBot_GetGuildMembersAll);
    CreateNative("DiscordWebHook.Send", Native_DiscordWebHook_Send);
    CreateNative("DiscordUser.GetID", Native_DiscordUser_GetID);
    CreateNative("DiscordUser.GetUsername", Native_DiscordUser_GetUsername);
    CreateNative("DiscordUser.GetDiscriminator", Native_DiscordUser_GetDiscriminator);
    CreateNative("DiscordUser.GetAvatar", Native_DiscordUser_GetAvatar);
    CreateNative("DiscordUser.IsVerified", Native_DiscordUser_IsVerified);
    CreateNative("DiscordUser.GetEmail", Native_DiscordUser_GetEmail);
    CreateNative("DiscordUser.IsBot", Native_DiscordUser_IsBot);
    CreateNative("DiscordMessage.GetID", Native_DiscordMessage_GetID);
    CreateNative("DiscordMessage.IsPinned", Native_DiscordMessage_IsPinned);
    CreateNative("DiscordMessage.GetAuthor", Native_DiscordMessage_GetAuthor);
    CreateNative("DiscordMessage.GetContent", Native_DiscordMessage_GetContent);
    CreateNative("DiscordMessage.GetChannelID", Native_DiscordMessage_GetChannelID);
    RegPluginLibrary("discord-api");
    return APLRes_Success;
}

public void OnPluginStart() {
    hRateLeft = new StringMap();
    hRateReset = new StringMap();
    hRateLimit = new StringMap();
}

// ==========================================
// HELPERS
// ==========================================
stock void BuildAuthHeader(HTTPRequest request, DiscordBot Bot) {
    char token[196];
    view_as<JSONObject>(Bot).GetString("token", token, sizeof(token));
    char buffer[256];
    FormatEx(buffer, sizeof(buffer), "Bot %s", token);
    request.SetHeader("Authorization", buffer);
}

stock void UpdateRateLimits(HTTPResponse response, const char[] route) {
    char xRateLimit[16], xRateLeft[16], xRateReset[32];
    bool hasLimit = response.GetHeader("X-RateLimit-Limit", xRateLimit, sizeof(xRateLimit));
    bool hasLeft = response.GetHeader("X-RateLimit-Remaining", xRateLeft, sizeof(xRateLeft));
    bool hasReset = response.GetHeader("X-RateLimit-Reset", xRateReset, sizeof(xRateReset));
    
    if(hasLimit && hasLeft && hasReset) {
        int reset = StringToInt(xRateReset);
        hRateReset.SetValue(route, reset);
        hRateLeft.SetValue(route, StringToInt(xRateLeft));
        hRateLimit.SetValue(route, StringToInt(xRateLimit));
    }
}

stock bool CheckRateLimit(const char[] route) {
    int time = GetTime();
    int resetTime;
    int defLimit = 1;
    hRateLimit.GetValue(route, defLimit);
    if(!hRateReset.GetValue(route, resetTime)) {
        hRateReset.SetValue(route, time + 5);
        hRateLeft.SetValue(route, defLimit - 1);
        return true;
    }
    if(time > resetTime) {
        hRateLeft.SetValue(route, defLimit - 1);
        return true;
    }
    int left;
    hRateLeft.GetValue(route, left);
    if(left <= 0) return false;
    left--;
    hRateLeft.SetValue(route, left);
    return true;
}

stock void SendDiscordGet(DiscordBot bot, const char[] endpoint, const char[] route, HTTPRequestCallback callback, any data) {
    if (!CheckRateLimit(route)) {
        DataPack dp = new DataPack();
        dp.WriteCell(bot);
        dp.WriteString(endpoint);
        dp.WriteString(route);
        dp.WriteCell(callback);
        dp.WriteCell(data);
        CreateTimer(1.0, RetryDiscordGet, dp);
        return;
    }
    
    static char url[256];
    FormatEx(url, sizeof(url), "https://discord.com/api/%s", endpoint);
    
    HTTPRequest request = new HTTPRequest(url);
    if (request == null) {
        //LogError("[DISCORD] Failed to create HTTPRequest for %s", endpoint);
        
        if (data != 0) {
            delete view_as<Handle>(data);
        }
        return;
    }
    
    if (bot != null) {
        BuildAuthHeader(request, bot);
    }
    
    request.Timeout = 30;
    
    request.Get(callback, data);
}

// ==========================================
// RETRY TIMER (если сработал rate limit)
// ==========================================
public Action RetryDiscordGet(Handle timer, any datapack) {
    DataPack dp = view_as<DataPack>(datapack);
    dp.Reset();
    
    DiscordBot bot = dp.ReadCell();
    
    char endpoint[256];
    dp.ReadString(endpoint, sizeof(endpoint));
    
    char route[128];
    dp.ReadString(route, sizeof(route));
    
    HTTPRequestCallback callback = dp.ReadCell();
    any data = dp.ReadCell();
    
    delete dp;
    
    SendDiscordGet(bot, endpoint, route, callback, data);
    return Plugin_Stop;
}

// ==========================================
// SEND MESSAGE
// ==========================================
public void Native_DiscordBot_SendMessage(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    DiscordChannel channel = GetNativeCell(2);
    char message[2048]; GetNativeString(3, message, sizeof(message));
    Function fCallback = GetNativeCell(4);
    any data = GetNativeCell(5);
    
    char channelID[32]; channel.GetID(channelID, sizeof(channelID));
    SendMessageStart(bot, channelID, message, plugin, fCallback, data);
}

public void Native_DiscordBot_SendMessageToChannel(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    char channelID[32]; GetNativeString(2, channelID, sizeof(channelID));
    char message[2048]; GetNativeString(3, message, sizeof(message));
    Function fCallback = GetNativeCell(4);
    any data = GetNativeCell(5);
    SendMessageStart(bot, channelID, message, plugin, fCallback, data);
}

public void Native_DiscordChannel_SendMessage(Handle plugin, int numParams) {
    DiscordChannel channel = GetNativeCell(1);
    DiscordBot bot = GetNativeCell(2);
    char message[2048];
    GetNativeString(3, message, sizeof(message));
    Function fCallback = GetNativeCell(4);
    any data = GetNativeCell(5);
    
    char channelID[32];
    channel.GetID(channelID, sizeof(channelID));
    SendMessageStart(bot, channelID, message, plugin, fCallback, data);
}

static void SendMessageStart(DiscordBot bot, const char[] channelID, const char[] message, Handle plugin, Function fCallback, any data) {
    char endpoint[64], route[64];
    FormatEx(endpoint, sizeof(endpoint), "channels/%s/messages", channelID);
    FormatEx(route, sizeof(route), "channels/%s/messages", channelID);
    
    DataPack dp = new DataPack();
    dp.WriteCell(bot);
    dp.WriteString(channelID);
    dp.WriteString(message);
    dp.WriteString(endpoint);
    dp.WriteString(route);
    dp.WriteCell(plugin);
    dp.WriteFunction(fCallback);
    dp.WriteCell(data);
    
    if(!CheckRateLimit(route)) {
        CreateTimer(1.0, RetrySendMessage, dp);
        return;
    }
    
    char url[256];
    FormatEx(url, sizeof(url), "https://discord.com/api/%s", endpoint);
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) {
        CreateTimer(2.0, RetrySendMessage, dp);
        return;
    }
    
    BuildAuthHeader(request, bot);
    request.Timeout = 30;
    
    JSONObject body = new JSONObject();
    body.SetString("content", message);
    
    request.Post(view_as<JSON>(body), OnSendMessageComplete, dp);
}

public Action RetrySendMessage(Handle timer, any datapack) {
    DataPack dp = view_as<DataPack>(datapack);
    dp.Reset();
    
    DiscordBot bot = dp.ReadCell();
    char channelID[32]; dp.ReadString(channelID, sizeof(channelID));
    char message[2048]; dp.ReadString(message, sizeof(message));
    char endpoint[64]; dp.ReadString(endpoint, sizeof(endpoint));
    char route[64]; dp.ReadString(route, sizeof(route));
    Handle plugin = dp.ReadCell();
    Function fCallback = dp.ReadFunction();
    any data = dp.ReadCell();
    
    dp.Reset();
    dp.WriteCell(bot);
    dp.WriteString(channelID);
    dp.WriteString(message);
    dp.WriteString(endpoint);
    dp.WriteString(route);
    dp.WriteCell(plugin);
    dp.WriteFunction(fCallback);
    dp.WriteCell(data);
    
    JSONObject body = new JSONObject();
    body.SetString("content", message);
    
    char url[256];
    FormatEx(url, sizeof(url), "https://discord.com/api/%s", endpoint);
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) {
        delete body;
        CreateTimer(2.0, RetrySendMessage, dp);
        return Plugin_Stop;
    }
    
    BuildAuthHeader(request, bot);
    request.Timeout = 30;
    request.Post(view_as<JSON>(body), OnSendMessageComplete, dp);
    
    return Plugin_Stop;
}

public void OnSendMessageComplete(HTTPResponse response, any value) {
    DataPack dp = view_as<DataPack>(value);
    dp.Reset();
    
    DiscordBot bot = dp.ReadCell();
    char channelID[32]; dp.ReadString(channelID, sizeof(channelID));
    char message[2048]; dp.ReadString(message, sizeof(message));
    char endpoint[64]; dp.ReadString(endpoint, sizeof(endpoint));
    char route[64]; dp.ReadString(route, sizeof(route));
    Handle plugin = dp.ReadCell();
    Function func = dp.ReadFunction();
    any pluginData = dp.ReadCell();
    
    UpdateRateLimits(response, route);
    
    if(response.Status == HTTPStatus_TooManyRequests || response.Status == HTTPStatus_InternalServerError) {
        dp.Reset();
        dp.WriteCell(bot);
        dp.WriteString(channelID);
        dp.WriteString(message);
        dp.WriteString(endpoint);
        dp.WriteString(route);
        dp.WriteCell(plugin);
        dp.WriteFunction(func);
        dp.WriteCell(pluginData);
        
        CreateTimer(2.0, RetrySendMessage, dp);
        return;
    }
    
    delete dp;
    
    if(response.Status != HTTPStatus_OK && response.Status != HTTPStatus_Created) {
        return;
    }
    
    if(func != INVALID_FUNCTION) {
        Handle fForward = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);
        AddToForward(fForward, plugin, func);
        Call_StartForward(fForward);
        Call_PushCell(bot);
        Call_PushString(channelID); 
        Call_PushCell(0);
        Call_PushCell(pluginData);
        Call_Finish();
        delete fForward;
    }
}

public void Native_DiscordBot_StartTimer(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    DiscordChannel channel = GetNativeCell(2);
    Function func = GetNativeCell(3);
    
    JSONObject hObj = new JSONObject();
    hObj.Set("bot", view_as<JSON>(bot));
    hObj.Set("channel", view_as<JSON>(channel));
    
    Handle fwd = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    AddToForward(fwd, plugin, func);
    
    hObj.SetInt("callback", view_as<int>(fwd));
    
    GetMessages(hObj);
}

public void GetMessages(Handle hObject) {
    JSONObject hObj = view_as<JSONObject>(hObject);
    
    JSON botJson = hObj.Get("bot");
    DiscordBot bot = view_as<DiscordBot>(botJson);
    
    JSON channelJson = hObj.Get("channel");
    DiscordChannel channel = view_as<DiscordChannel>(channelJson);
    
    char channelID[32];
    channel.GetID(channelID, sizeof(channelID));
    
    char lastMessage[64];
    channel.GetLastMessageID(lastMessage, sizeof(lastMessage));
    
    char url[256];
    FormatEx(url, sizeof(url), "https://discord.com/api/channels/%s/messages?limit=100&after=%s", channelID, lastMessage);
    
    char route[128];
    FormatEx(route, sizeof(route), "channels/%s", channelID);
    
    if(!CheckRateLimit(route)) {
        CreateTimer(1.0, GetMessagesDelayed, hObject);
        return;
    }
    
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) {
        CreateTimer(2.0, GetMessagesDelayed, hObject);
        return;
    }
    
    if(bot != null) {
        BuildAuthHeader(request, bot);
    }
    request.Timeout = 30;
    
    request.Get(OnGetMessageCallback, hObject);
}

public Action GetMessagesDelayed(Handle timer, any data) {
    GetMessages(view_as<Handle>(data));
    return Plugin_Stop;
}

public void OnGetMessageCallback(HTTPResponse response, any value) {
    Handle hObj = view_as<Handle>(value);
    JSONObject hObjJson = view_as<JSONObject>(hObj);
    
    JSON botJson = hObjJson.Get("bot");
    DiscordBot Bot = view_as<DiscordBot>(botJson);
    
    JSON channelJson = hObjJson.Get("channel");
    DiscordChannel channel = view_as<DiscordChannel>(channelJson);
    
    int fwdInt = hObjJson.GetInt("callback");
    Handle fwd = view_as<Handle>(fwdInt);
    
    if(response.Status != HTTPStatus_OK) {
        if(response.Data != null) {
            delete view_as<Handle>(response.Data);
        }
        //LogError("[DISCORD] GetMessages failed with status %d", response.Status);
        CreateTimer(Bot.MessageCheckInterval, CheckMessageTimer, hObj);
        return;
    }
    
    JSON data = response.Data;
    if(data == null) {
        //LogError("[DISCORD] GetMessages returned null data");
        CreateTimer(Bot.MessageCheckInterval, CheckMessageTimer, hObj);
        return;
    }
    
    JSONArray hJson = view_as<JSONArray>(data);
    
    if(!Bot.IsListeningToChannel(channel) || fwd == null || GetForwardFunctionCount(fwd) == 0) {
        if(fwd != null) {
            delete fwd;
        }
        delete hObj;
        delete hJson;
        return;
    }
    
    for(int i = hJson.Length - 1; i >= 0; i--) {
        JSONObject hObject = view_as<JSONObject>(hJson.Get(i));
        
        char channelID[32];
        hObject.GetString("channel_id", channelID, sizeof(channelID));
        
        if(!Bot.IsListeningToChannelID(channelID)) {
            delete hObject;
            continue;
        }
        
        char id[32];
        hObject.GetString("id", id, sizeof(id));
        
        if(i == 0) {
            channel.SetLastMessageID(id);
        }
        
        if(fwd != null && GetForwardFunctionCount(fwd) > 0) {
            Call_StartForward(fwd);
            Call_PushCell(Bot);
            Call_PushCell(channel);
            Call_PushCell(view_as<DiscordMessage>(hObject));
            Call_Finish();
        }
        delete hObject;
    }
    
    delete hJson;
    CreateTimer(Bot.MessageCheckInterval, CheckMessageTimer, hObj);
}

public int Native_DiscordWebHook_Send(Handle plugin, int numParams) {
    DiscordWebHook hook = GetNativeCell(1);
    SendWebHook(hook);
    return view_as<int>(hook);
}

public void SendWebHook(DiscordWebHook hook) {
    if(!JsonObjectGetBool(view_as<JSONObject>(hook), "__selfCopy", false)) {
        hook = view_as<DiscordWebHook>(JsonDeepCopy(view_as<JSONObject>(hook)));
        if(hook == null) {
            //LogError("[DISCORD] Failed to copy webhook");
            return;
        }
        view_as<JSONObject>(hook).SetBool("__selfCopy", true);
    }
    
    JSONObject hJson = view_as<JSONObject>(hook.Data);
    if(hJson == null) {
    	delete hook;
    	return;
    }
    
    view_as<JSONObject>(hook).Remove("__data");
    
    char url[256];
    hook.GetUrl(url, sizeof(url));
    
    if(hook.SlackMode) {
        if(StrContains(url, "/slack") == -1) {
            Format(url, sizeof(url), "%s/slack", url);
        }
        
        RenameJsonObject(hJson, "content", "text");
        RenameJsonObject(hJson, "embeds", "attachments");
        
        if(hJson.HasKey("attachments")) {
            JSONArray hAttachments = view_as<JSONArray>(hJson.Get("attachments"));
            if(hAttachments != null) {
            for(int i = 0; i < hAttachments.Length; i++) {
                    JSONObject hEmbed = view_as<JSONObject>(hAttachments.Get(i));
                    if(hEmbed.HasKey("fields")) {
                        JSONArray hFields = view_as<JSONArray>(hEmbed.Get("fields"));
                        if(hFields != null) {
                            for(int j = 0; j < hFields.Length; j++) {
                                JSONObject hField = view_as<JSONObject>(hFields.Get(j));
                                RenameJsonObject(hField, "name", "title");
                                RenameJsonObject(hField, "inline", "short");
                            }
                        }
                    }
                }
            }
        }
    }
    
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) {
        //LogError("[DISCORD] Failed to create HTTP request for webhook");
        delete hJson;
        delete hook;
        return;
    }
    
    request.Timeout = 30;
    request.Post(hJson, OnWebHookComplete, hook);
}

public void OnWebHookComplete(HTTPResponse response, any value) {
    DiscordWebHook hook = view_as<DiscordWebHook>(value);
    if(hook != null) {
        delete hook;
    }
    
    if(response.Status != HTTPStatus_OK && response.Status != HTTPStatus_NoContent) {
        //LogError("[DISCORD] Webhook request failed with status %d", response.Status);
    }
}

public void Native_DiscordBot_GetGuildChannels(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    char guild[32];
    GetNativeString(2, guild, sizeof(guild));
    Function fCallback = GetNativeCell(3);
    Function fCallbackAll = GetNativeCell(4);
    any data = GetNativeCell(5);
    
    DataPack dp = new DataPack();
    dp.WriteCell(bot);
    dp.WriteString(guild);
    dp.WriteCell(plugin);
    dp.WriteFunction(fCallback);
    dp.WriteFunction(fCallbackAll);
    dp.WriteCell(data);
    
    GetGuildChannelsSendRequest(bot, guild, dp);
}

static void GetGuildChannelsSendRequest(DiscordBot bot, char[] guild, DataPack dp) {
    char route[64];
    FormatEx(route, sizeof(route), "guilds/%s/channels", guild);
    
    if(!CheckRateLimit(route)) {
        CreateTimer(1.0, GetGuildChannelsDelayed, dp);
        return;
    }
    
    char url[256];
    FormatEx(url, sizeof(url), "https://discord.com/api/guilds/%s/channels", guild);
    
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) {
        CreateTimer(2.0, GetGuildChannelsDelayed, dp);
        return;
    }
    if(bot != null) BuildAuthHeader(request, bot);
    request.Timeout = 30;
    
    request.Get(GetGuildChannelsCallback, dp);
}

public void GetGuildChannelsCallback(HTTPResponse response, any value) {
	DataPack dp = view_as<DataPack>(value);
	dp.Reset();
	DiscordBot bot = dp.ReadCell();
	char guild[32];
	dp.ReadString(guild, sizeof(guild));
	Handle plugin = dp.ReadCell();
	Function func = dp.ReadFunction();
	Function funcAll = dp.ReadFunction();
	any pluginData = dp.ReadCell();
	
	char route[64];
	FormatEx(route, sizeof(route), "guilds/%s/channels", guild);
	UpdateRateLimits(response, route);
	
	if(response.Status != HTTPStatus_OK) {
		if(response.Data != null) {
			delete view_as<Handle>(response.Data);
		}
		
		if(response.Status == HTTPStatus_TooManyRequests || response.Status == HTTPStatus_InternalServerError) {
			delete dp;
			
			DataPack newDp = new DataPack();
			newDp.WriteCell(bot);
			newDp.WriteString(guild);
			newDp.WriteCell(plugin);
			newDp.WriteFunction(func);
			newDp.WriteFunction(funcAll);
			newDp.WriteCell(pluginData);
			
			GetGuildChannelsSendRequest(bot, guild, newDp);
			return;
		}
		delete dp;
		return;
	}
	
	JSON data = response.Data;
	JSONArray hJson = view_as<JSONArray>(data);
	
	Handle fForward = INVALID_HANDLE;
	Handle fForwardAll = INVALID_HANDLE;
	if(func != INVALID_FUNCTION) {
		fForward = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);
		AddToForward(fForward, plugin, func);
	}
	if(funcAll != INVALID_FUNCTION) {
		fForwardAll = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);
		AddToForward(fForwardAll, plugin, funcAll);
	}
	
	ArrayList alChannels = null;
	if(funcAll != INVALID_FUNCTION) alChannels = new ArrayList();
	
	for(int i = 0; i < hJson.Length; i++) {
		JSONObject hObject = view_as<JSONObject>(hJson.Get(i));
		DiscordChannel Channel = view_as<DiscordChannel>(hObject);
		
		if(fForward != INVALID_HANDLE) {
			Call_StartForward(fForward);
			Call_PushCell(bot);
			Call_PushString(guild);
			Call_PushCell(Channel);
			Call_PushCell(pluginData);
			Call_Finish();
		}
		
		if(fForwardAll != INVALID_HANDLE) {
			alChannels.Push(Channel);
		} else {
			delete Channel;
		}
	}
	
	if(fForwardAll != INVALID_HANDLE) {
		Call_StartForward(fForwardAll);
		Call_PushCell(bot);
		Call_PushString(guild);
		Call_PushCell(alChannels);
		Call_PushCell(pluginData);
		Call_Finish();
		
		for(int i = 0; i < alChannels.Length; i++) {
			Handle hChannel = view_as<Handle>(alChannels.Get(i));
			delete hChannel;
		}
		delete alChannels;
		delete fForwardAll;
	}
	
	if(fForward != INVALID_HANDLE) delete fForward;
	delete hJson;
	delete dp;
}

public void Native_DiscordBot_AddReaction(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    char channel[32];
    GetNativeString(2, channel, sizeof(channel));
    char msgid[64];
    GetNativeString(3, msgid, sizeof(msgid));
    char emoji[128];
    GetNativeString(4, emoji, sizeof(emoji));
    AddReaction(bot, channel, msgid, emoji);
}

public void AddReaction(DiscordBot bot, char[] channel, char[] messageid, char[] emoji) {
    char url[256];
    FormatEx(url, sizeof(url), "https://discord.com/api/channels/%s/messages/%s/reactions/%s/@me", channel, messageid, emoji);
    
    char route[128];
    FormatEx(route, sizeof(route), "channels/%s/messages/reactions", channel);
    
    if(!CheckRateLimit(route)) {
        DataPack dp = new DataPack();
        dp.WriteCell(bot);
        dp.WriteString(channel);
        dp.WriteString(messageid);
        dp.WriteString(emoji);
        CreateTimer(1.0, AddReactionDelayed, dp);
        return;
    }
    
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) {
        DataPack dp = new DataPack();
        dp.WriteCell(bot);
        dp.WriteString(channel);
        dp.WriteString(messageid);
        dp.WriteString(emoji);
        CreateTimer(2.0, AddReactionDelayed, dp);
        return;
    }
    if(bot != null) BuildAuthHeader(request, bot);
    request.Timeout = 30;
    
    DataPack dp = new DataPack();
    dp.WriteCell(bot);
    dp.WriteString(channel);
    dp.WriteString(messageid);
    dp.WriteString(emoji);
    
    request.Put(null, AddReactionCallback, dp);
}

public void Native_DiscordBot_GetGuildRoles(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    char guild[32];
    GetNativeString(2, guild, sizeof(guild));
    Function fCallback = GetNativeCell(3);
    any data = GetNativeCell(4);
    
    Handle fwd = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_Cell);
    AddToForward(fwd, plugin, fCallback);
    
    DataPack dp = new DataPack();
    dp.WriteCell(bot);
    dp.WriteString(guild);
    dp.WriteCell(fwd);
    dp.WriteCell(data);
    
    char endpoint[256];
    FormatEx(endpoint, sizeof(endpoint), "guilds/%s/roles", guild);
    
    char route[128];
    FormatEx(route, sizeof(route), "guilds/%s/roles", guild);
    
    dp.WriteString(endpoint);
    dp.WriteString(route);
    
    SendDiscordGet(bot, endpoint, route, OnGetGuildRolesComplete, dp);
}

public void OnGetGuildRolesComplete(HTTPResponse response, any datapack) {
    DataPack dp = view_as<DataPack>(datapack);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char guild[32];
    dp.ReadString(guild, sizeof(guild));
    Handle fwd = dp.ReadCell();
    any data1 = dp.ReadCell();
    char endpoint[256];
    dp.ReadString(endpoint, sizeof(endpoint));
    char route[128];
    dp.ReadString(route, sizeof(route));
    
    UpdateRateLimits(response, route);
    
    if(response.Status != HTTPStatus_OK) {
        if(response.Data != null) {
            delete view_as<Handle>(response.Data);
        }
        
        if(response.Status == HTTPStatus_TooManyRequests || response.Status == HTTPStatus_InternalServerError) {
            dp.Reset();
            dp.WriteCell(bot);
            dp.WriteString(guild);
            dp.WriteCell(fwd);
            dp.WriteCell(data1);
            dp.WriteString(endpoint);
            dp.WriteString(route);
            CreateTimer(2.0, GetGuildRolesRetry, dp);
            return;
        }
        delete dp;
        if(fwd != null) delete fwd;
        return;
    }
    
    JSONArray hJson = view_as<JSONArray>(response.Data);
    
    if(fwd != null) {
        Call_StartForward(fwd);
        Call_PushCell(bot);
        Call_PushString(guild);
        Call_PushCell(view_as<RoleList>(hJson));
        Call_PushCell(data1);
        Call_Finish();
        delete fwd;
    }
    
    delete hJson;
    delete dp;
}

public Action GetGuildRolesRetry(Handle timer, any datapack) {
    DataPack dp = view_as<DataPack>(datapack);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char guild[32];
    dp.ReadString(guild, sizeof(guild));
    Handle fwd = dp.ReadCell();
    any data1 = dp.ReadCell();
    char endpoint[256];
    dp.ReadString(endpoint, sizeof(endpoint));
    char route[128];
    dp.ReadString(route, sizeof(route));
    
    delete dp;
    
    DataPack dp2 = new DataPack();
    dp2.WriteCell(bot);
    dp2.WriteString(guild);
    dp2.WriteCell(fwd);
    dp2.WriteCell(data1);
    dp2.WriteString(endpoint);
    dp2.WriteString(route);
    
    SendDiscordGet(bot, endpoint, route, OnGetGuildRolesComplete, dp2);
    return Plugin_Stop;
}

// ==========================================
// MISSING HELPERS & TIMERS
// ==========================================
public Action CheckMessageTimer(Handle timer, any data) {
    GetMessages(view_as<Handle>(data));
    return Plugin_Stop;
}

public Action SendGetMembers(Handle timer, any data) {
    GetMembers(view_as<JSONObject>(data));
    return Plugin_Stop;
}

stock Handle JsonDeepCopy(JSONObject obj) {
    char buffer[8192];
    if(obj.ToString(buffer, sizeof(buffer))) {
        return JSONObject.FromString(buffer);
    }
    return null;
}

// ==========================================
// MISSING NATIVES (User & Message wrappers)
// ==========================================
public int Native_DiscordBot_Token_Get(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    char buffer[196];
    view_as<JSONObject>(bot).GetString("token", buffer, sizeof(buffer));
    SetNativeString(2, buffer, GetNativeCell(3));
    return 0;
}

public int Native_DiscordUser_GetID(Handle plugin, int numParams) {
    DiscordUser user = GetNativeCell(1);
    char buffer[32]; user.GetID(buffer, sizeof(buffer));
    SetNativeString(2, buffer, GetNativeCell(3)); return 0;
}
public int Native_DiscordUser_GetUsername(Handle plugin, int numParams) {
    DiscordUser user = GetNativeCell(1);
    char buffer[32]; user.GetUsername(buffer, sizeof(buffer));
    SetNativeString(2, buffer, GetNativeCell(3)); return 0;
}
public int Native_DiscordUser_GetDiscriminator(Handle plugin, int numParams) {
    DiscordUser user = GetNativeCell(1);
    char buffer[16]; user.GetDiscriminator(buffer, sizeof(buffer));
    SetNativeString(2, buffer, GetNativeCell(3)); return 0;
}
public int Native_DiscordUser_GetAvatar(Handle plugin, int numParams) {
    DiscordUser user = GetNativeCell(1);
    char buffer[128]; user.GetAvatar(buffer, sizeof(buffer));
    SetNativeString(2, buffer, GetNativeCell(3)); return 0;
}
public int Native_DiscordUser_IsVerified(Handle plugin, int numParams) {
    Handle hUser = GetNativeCell(1);
    return hUser != null && view_as<DiscordUser>(hUser).IsVerified() ? 1 : 0;
}
public int Native_DiscordUser_GetEmail(Handle plugin, int numParams) {
    DiscordUser user = GetNativeCell(1);
    char buffer[128]; user.GetEmail(buffer, sizeof(buffer));
    SetNativeString(2, buffer, GetNativeCell(3)); return 0;
}
public int Native_DiscordUser_IsBot(Handle plugin, int numParams) {
    Handle hUser = GetNativeCell(1);
    return hUser != null && view_as<DiscordUser>(hUser).IsBot() ? 1 : 0;
}
public int Native_DiscordMessage_GetID(Handle plugin, int numParams) {
    DiscordMessage msg = GetNativeCell(1);
    char buffer[32]; msg.GetID(buffer, sizeof(buffer));
    SetNativeString(2, buffer, GetNativeCell(3)); return 0;
}
public int Native_DiscordMessage_IsPinned(Handle plugin, int numParams) {
    Handle hMsg = GetNativeCell(1);
    return hMsg != null && view_as<DiscordMessage>(hMsg).IsPinned() ? 1 : 0;
}
public int Native_DiscordMessage_GetAuthor(Handle plugin, int numParams) {
    return view_as<int>(view_as<DiscordMessage>(GetNativeCell(1)).GetAuthor());
}
public int Native_DiscordMessage_GetContent(Handle plugin, int numParams) {
    DiscordMessage msg = GetNativeCell(1);
    char buffer[2048]; msg.GetContent(buffer, sizeof(buffer));
    SetNativeString(2, buffer, GetNativeCell(3)); return 0;
}
public int Native_DiscordMessage_GetChannelID(Handle plugin, int numParams) {
    DiscordMessage msg = GetNativeCell(1);
    char buffer[32]; msg.GetChannelID(buffer, sizeof(buffer));
    SetNativeString(2, buffer, GetNativeCell(3)); return 0;
}

// ==========================================
// GUILDS & MEMBERS (RipExt Port)
// ==========================================
public void Native_DiscordBot_GetGuilds(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    Function fCallback = GetNativeCell(2);
    Function fCallbackAll = GetNativeCell(3);
    any data = GetNativeCell(4);
    
    DataPack dp = new DataPack();
    dp.WriteCell(bot); dp.WriteCell(plugin);
    dp.WriteFunction(fCallback); dp.WriteFunction(fCallbackAll); dp.WriteCell(data);
    GetGuildsSendRequest(bot, dp);
}

static void GetGuildsSendRequest(DiscordBot bot, DataPack dp) {
    char url[256], route[64];
    FormatEx(url, sizeof(url), "https://discord.com/api/users/@me/guilds");
    FormatEx(route, sizeof(route), "users/@me/guilds");
    
    if(!CheckRateLimit(route)) { CreateTimer(1.0, GetGuildsDelayed, dp); return; }
    
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) { CreateTimer(2.0, GetGuildsDelayed, dp); return; }
    
    BuildAuthHeader(request, bot);
    request.Timeout = 30;
    request.Get(GetGuildsCallback, dp);
}

public Action GetGuildsDelayed(Handle timer, any data) {
    DataPack dp = view_as<DataPack>(data);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    GetGuildsSendRequest(bot, dp);
    return Plugin_Stop;
}

public void GetGuildsCallback(HTTPResponse response, any value) {
    DataPack dp = view_as<DataPack>(value);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    Handle plugin = dp.ReadCell();
    Function func = dp.ReadFunction();
    Function funcAll = dp.ReadFunction();
    any pluginData = dp.ReadCell();
    
    char route[64]; 
    FormatEx(route, sizeof(route), "users/@me/guilds");
    UpdateRateLimits(response, route);
    
    if(response.Status != HTTPStatus_OK) {
        if(response.Data != null) {
            delete view_as<Handle>(response.Data);
        }
        
        if(response.Status == HTTPStatus_TooManyRequests || response.Status == HTTPStatus_InternalServerError) {
            dp.Reset();
            dp.WriteCell(bot); 
            dp.WriteCell(plugin);
            dp.WriteFunction(func); 
            dp.WriteFunction(funcAll); 
            dp.WriteCell(pluginData);
            GetGuildsSendRequest(bot, dp); 
            return;
        }
        delete dp; 
        return;
    }
    
    JSON data = response.Data;
    if(data == null) { 
        delete dp; 
        return; 
    }
    
    JSONArray hJson = view_as<JSONArray>(data);
    Handle fForward = INVALID_HANDLE, fForwardAll = INVALID_HANDLE;
    
    if(func != INVALID_FUNCTION) {
        fForward = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_String, Param_String, Param_Cell, Param_Cell, Param_Cell);
        AddToForward(fForward, plugin, func);
    }
    
    ArrayList alId = null, alName = null, alIcon = null, alOwner = null, alPermissions = null;
    if(funcAll != INVALID_FUNCTION) {
        fForwardAll = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
        AddToForward(fForwardAll, plugin, funcAll);
        alId = new ArrayList(ByteCountToCells(32));
        alName = new ArrayList(ByteCountToCells(64));
        alIcon = new ArrayList(ByteCountToCells(128));
        alOwner = new ArrayList();
        alPermissions = new ArrayList();
    }
    
    for(int i = 0; i < hJson.Length; i++) {
        JSONObject hObject = view_as<JSONObject>(hJson.Get(i));
        char id[32], name[64], icon[128];
        hObject.GetString("id", id, sizeof(id));
        hObject.GetString("name", name, sizeof(name));
        hObject.GetString("icon", icon, sizeof(icon));
        
        if(fForward != INVALID_HANDLE) {
            Call_StartForward(fForward);
            Call_PushCell(bot); Call_PushString(id); Call_PushString(name); Call_PushString(icon);
            Call_PushCell(hObject.GetBool("owner")); Call_PushCell(hObject.GetInt("permissions")); Call_PushCell(pluginData);
            Call_Finish();
        }
        if(fForwardAll != INVALID_HANDLE) {
            alId.PushString(id); alName.PushString(name); alIcon.PushString(icon);
            alOwner.Push(hObject.GetBool("owner")); alPermissions.Push(hObject.GetInt("permissions"));
        }
        delete hObject;
    }
    
    if(fForwardAll != INVALID_HANDLE) {
        Call_StartForward(fForwardAll);
        Call_PushCell(bot); Call_PushCell(alId); Call_PushCell(alName); Call_PushCell(alIcon);
        Call_PushCell(alOwner); Call_PushCell(alPermissions); Call_PushCell(pluginData);
        Call_Finish();
        delete alId; delete alName; delete alIcon; delete alOwner; delete alPermissions; delete fForwardAll;
    }
    if(fForward != INVALID_HANDLE) {
        delete fForward;
    }
    
    delete hJson;
    delete dp;
}

public void Native_DiscordBot_GetGuildMembers(Handle plugin, int numParams) {
    _GetGuildMembersHelper(plugin, numParams, false);
}

public void Native_DiscordBot_GetGuildMembersAll(Handle plugin, int numParams) {
    _GetGuildMembersHelper(plugin, numParams, true);
}

static void _GetGuildMembersHelper(Handle plugin, int numParams, bool autoPaginate) {
    #pragma unused numParams 
    
    DiscordBot bot = GetNativeCell(1);
    
    char guild[32], afterID[32];
    GetNativeString(2, guild, sizeof(guild));
    
    Function fCallback = GetNativeCell(3);
    int limit = GetNativeCell(4);
    GetNativeString(5, afterID, sizeof(afterID));
    
    JSONObject hData = new JSONObject();
    hData.Set("bot", view_as<JSON>(bot));
    hData.SetString("guild", guild);
    hData.SetInt("limit", limit);
    hData.SetString("afterID", afterID);
    hData.SetBool("autoPaginate", autoPaginate);
    
    // Создаём forward и сохраняем как int (такой же трюк, как в старом коде)
    Handle fwd = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_Cell);
    AddToForward(fwd, plugin, fCallback);
    hData.SetInt("callback", view_as<int>(fwd));
    
    GetMembers(hData);
}

static void GetMembers(JSONObject hData) {
    JSON botJson = hData.Get("bot");
    DiscordBot bot = view_as<DiscordBot>(botJson);
    char guild[32], afterID[32];
    hData.GetString("guild", guild, sizeof(guild));
    int limit = hData.GetInt("limit");
    hData.GetString("afterID", afterID, sizeof(afterID));
    
    char url[256], route[128];
    if(StrEqual(afterID, "")) FormatEx(url, sizeof(url), "https://discord.com/api/guilds/%s/members?limit=%i", guild, limit);
    else FormatEx(url, sizeof(url), "https://discord.com/api/guilds/%s/members?limit=%i&after=%s", guild, limit, afterID);
    FormatEx(route, sizeof(route), "guilds/%s/members", guild);
    
    if(!CheckRateLimit(route)) { CreateTimer(1.0, SendGetMembers, hData); return; }
    
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) { CreateTimer(2.0, SendGetMembers, hData); return; }
    
    BuildAuthHeader(request, bot);
    request.Timeout = 30;
    request.Get(OnGetMembersCallback, hData);
}

public void OnGetMembersCallback(HTTPResponse response, any value) {
    JSONObject hData = view_as<JSONObject>(value);
    JSON botJson = hData.Get("bot");
    DiscordBot bot = view_as<DiscordBot>(botJson);
    Handle fwd = view_as<Handle>(hData.GetInt("callback"));
    char guild[32];
    hData.GetString("guild", guild, sizeof(guild));
    
    char route[128]; FormatEx(route, sizeof(route), "guilds/%s/members", guild);
    UpdateRateLimits(response, route);
    
    if(response.Status != HTTPStatus_OK) {
        if(response.Data != null) {
            delete view_as<Handle>(response.Data);
        }
        
        if(response.Status == HTTPStatus_TooManyRequests || response.Status == HTTPStatus_InternalServerError) {
            GetMembers(hData);
            return;
        }
        delete hData;
        if(fwd != null) delete fwd;
        return;
    }
    
    JSON data = response.Data;
    if(data != null && fwd != null) {
        Call_StartForward(fwd);
        Call_PushCell(bot);
        Call_PushString(guild);
        Call_PushCell(data);
        Call_Finish();
    }
    
    if(hData.GetBool("autoPaginate") && data != null) {
        JSONArray hJson = view_as<JSONArray>(data);
        int size = hJson.Length;
        int limit = hData.GetInt("limit");
        
        if(size == limit && size > 0) {
            JSONObject hLast = view_as<JSONObject>(hJson.Get(size - 1));
            JSONObject userObj = view_as<JSONObject>(hLast.Get("user"));
            char lastID[32];
            
            if(userObj != null) {
                userObj.GetString("id", lastID, sizeof(lastID));
                delete userObj;
            }
            
            hData.SetString("afterID", lastID);
            delete hLast;
            delete hJson;
            GetMembers(hData);
            return;
        }
        
        delete hJson;
    }
    else if (data != null) {
        delete data;
    }
    
    delete hData;
    if(fwd != null) delete fwd;
}

// ==========================================
// STUBS FOR DELETE / REACTION (Basic Implementation)
// ==========================================
public void Native_DiscordBot_DeleteMessageID(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    char channel[32], message[64];
    GetNativeString(2, channel, sizeof(channel));
    GetNativeString(3, message, sizeof(message));
    Function fCallback = GetNativeCell(4);
    any data = GetNativeCell(5);
    
    DataPack dp = new DataPack();
    dp.WriteCell(bot); dp.WriteString(channel); dp.WriteString(message);
    dp.WriteCell(plugin); dp.WriteFunction(fCallback); dp.WriteCell(data);
    DeleteMessageDoRequest(bot, channel, message, dp);
}

public void Native_DiscordBot_DeleteMessage(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    DiscordChannel channel = GetNativeCell(2);
    DiscordMessage message = GetNativeCell(3);
    Function fCallback = GetNativeCell(4);
    any data = GetNativeCell(5);
    
    char chId[32], msgId[64];
    channel.GetID(chId, sizeof(chId));
    message.GetID(msgId, sizeof(msgId));
    
    DataPack dp = new DataPack();
    dp.WriteCell(bot);
    dp.WriteString(chId);
    dp.WriteString(msgId);
    dp.WriteCell(plugin);
    dp.WriteFunction(fCallback);
    dp.WriteCell(data);
    
    DeleteMessageDoRequest(bot, chId, msgId, dp);
}

static void DeleteMessageDoRequest(DiscordBot bot, const char[] channel, const char[] message, DataPack dp) {
    char url[256], route[128];
    FormatEx(url, sizeof(url), "https://discord.com/api/channels/%s/messages/%s", channel, message);
    FormatEx(route, sizeof(route), "channels/%s/messages", channel);
    
    if(!CheckRateLimit(route)) { CreateTimer(1.0, DeleteMessageDelayed, dp); return; }
    
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) { CreateTimer(2.0, DeleteMessageDelayed, dp); return; }
    
    BuildAuthHeader(request, bot);
    request.Timeout = 30;
    request.Delete(OnDeleteMessageComplete, dp);
}

public Action DeleteMessageDelayed(Handle timer, any data) {
    DataPack dp = view_as<DataPack>(data);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char channel[32], message[64];
    dp.ReadString(channel, sizeof(channel)); dp.ReadString(message, sizeof(message));
    DeleteMessageDoRequest(bot, channel, message, dp);
    return Plugin_Stop;
}

public void OnDeleteMessageComplete(HTTPResponse response, any value) {
    DataPack dp = view_as<DataPack>(value);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char channel[32], message[64];
    dp.ReadString(channel, sizeof(channel)); dp.ReadString(message, sizeof(message));
    Handle plugin = dp.ReadCell();
    Function func = dp.ReadFunction();
    any pluginData = dp.ReadCell();
    delete dp;
    
    char route[128]; FormatEx(route, sizeof(route), "channels/%s/messages", channel);
    UpdateRateLimits(response, route);
    
    if(response.Status == HTTPStatus_TooManyRequests || response.Status == HTTPStatus_InternalServerError) {
        DataPack newDp = new DataPack();
        newDp.WriteCell(bot); newDp.WriteString(channel); newDp.WriteString(message);
        newDp.WriteCell(plugin); newDp.WriteFunction(func); newDp.WriteCell(pluginData);
        DeleteMessageDoRequest(bot, channel, message, newDp);
        return;
    }
    
    if(func != INVALID_FUNCTION) {
        Handle fForward = CreateForward(ET_Ignore, Param_Cell, Param_Cell);
        AddToForward(fForward, plugin, func);
        Call_StartForward(fForward); Call_PushCell(bot); Call_PushCell(pluginData); Call_Finish();
        delete fForward;
    }
}

public Action AddReactionDelayed(Handle timer, any data) {
    DataPack dp = view_as<DataPack>(data);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char channel[64], messageid[64], emoji[64];
    dp.ReadString(channel, sizeof(channel)); dp.ReadString(messageid, sizeof(messageid)); dp.ReadString(emoji, sizeof(emoji));
    AddReaction(bot, channel, messageid, emoji);
    delete dp;
    return Plugin_Stop;
}

public void AddReactionCallback(HTTPResponse response, any value) {
    DataPack dp = view_as<DataPack>(value);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char channel[64], messageid[64], emoji[64];
    dp.ReadString(channel, sizeof(channel)); dp.ReadString(messageid, sizeof(messageid)); dp.ReadString(emoji, sizeof(emoji));
    delete dp;
    
    char route[128]; FormatEx(route, sizeof(route), "channels/%s/messages/reactions", channel);
    UpdateRateLimits(response, route);
    
    if(response.Status != HTTPStatus_NoContent && response.Status != HTTPStatus_OK) {
        if(response.Status == HTTPStatus_TooManyRequests || response.Status == HTTPStatus_InternalServerError) {
            AddReaction(bot, channel, messageid, emoji);
            return;
        }
        //LogError("[DISCORD] Couldn't Add Reaction - Status %d", response.Status);
    }
}

public void Native_DiscordBot_DeleteReaction(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    char channel[32], msgid[64], emoji[128], user[128];
    GetNativeString(2, channel, sizeof(channel));
    GetNativeString(3, msgid, sizeof(msgid));
    GetNativeString(4, emoji, sizeof(emoji));
    GetNativeString(5, user, sizeof(user));
    DeleteReaction(bot, channel, msgid, emoji, user);
}

public void DeleteReaction(DiscordBot bot, const char[] channel, const char[] messageid, const char[] emoji, const char[] userid) {
    char url[256], route[128];
    if(StrEqual(userid, "@all")) {
        FormatEx(url, sizeof(url), "https://discord.com/api/channels/%s/messages/%s/reactions/%s", channel, messageid, emoji);
    } else {
        FormatEx(url, sizeof(url), "https://discord.com/api/channels/%s/messages/%s/reactions/%s/%s", channel, messageid, emoji, userid);
    }
    FormatEx(route, sizeof(route), "channels/%s/messages/reactions", channel);
    
    if(!CheckRateLimit(route)) {
        DataPack dp = new DataPack();
        dp.WriteCell(bot); dp.WriteString(channel); dp.WriteString(messageid); dp.WriteString(emoji); dp.WriteString(userid);
        CreateTimer(1.0, DeleteReactionDelayed, dp);
        return;
    }
    
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) {
        DataPack dp = new DataPack();
        dp.WriteCell(bot); dp.WriteString(channel); dp.WriteString(messageid); dp.WriteString(emoji); dp.WriteString(userid);
        CreateTimer(2.0, DeleteReactionDelayed, dp);
        return;
    }
    
    BuildAuthHeader(request, bot);
    request.Timeout = 30;
    
    DataPack dp = new DataPack();
    dp.WriteCell(bot); dp.WriteString(channel); dp.WriteString(messageid); dp.WriteString(emoji); dp.WriteString(userid);
    request.Delete(DeleteReactionCallback, dp);
}

public Action DeleteReactionDelayed(Handle timer, any data) {
    DataPack dp = view_as<DataPack>(data);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char channel[64], messageid[64], emoji[64], userid[64];
    dp.ReadString(channel, sizeof(channel)); dp.ReadString(messageid, sizeof(messageid)); 
    dp.ReadString(emoji, sizeof(emoji)); dp.ReadString(userid, sizeof(userid));
    DeleteReaction(bot, channel, messageid, emoji, userid);
    delete dp;
    return Plugin_Stop;
}

public void DeleteReactionCallback(HTTPResponse response, any value) {
    DataPack dp = view_as<DataPack>(value);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char channel[64], messageid[64], emoji[64], userid[64];
    dp.ReadString(channel, sizeof(channel)); dp.ReadString(messageid, sizeof(messageid)); 
    dp.ReadString(emoji, sizeof(emoji)); dp.ReadString(userid, sizeof(userid));
    delete dp;
    
    char route[128]; FormatEx(route, sizeof(route), "channels/%s/messages/reactions", channel);
    UpdateRateLimits(response, route);
    
    if(response.Status != HTTPStatus_NoContent && response.Status != HTTPStatus_OK) {
        if(response.Status == HTTPStatus_TooManyRequests || response.Status == HTTPStatus_InternalServerError) {
            DeleteReaction(bot, channel, messageid, emoji, userid);
            return;
        }
        //LogError("[DISCORD] Couldn't Delete Reaction - Status %d", response.Status);
    }
}

public void Native_DiscordBot_GetReaction(Handle plugin, int numParams) {
    DiscordBot bot = GetNativeCell(1);
    char channel[32], msgid[64], emoji[128];
    GetNativeString(2, channel, sizeof(channel));
    GetNativeString(3, msgid, sizeof(msgid));
    GetNativeString(4, emoji, sizeof(emoji));
    Function fCallback = GetNativeCell(5);
    any data = GetNativeCell(6);
    
    Handle fForward = null;
    if(fCallback != INVALID_FUNCTION) {
        fForward = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String, Param_String, Param_Cell);
        AddToForward(fForward, plugin, fCallback);
    }
    GetReaction(bot, channel, msgid, emoji, fForward, data);
}

public void GetReaction(DiscordBot bot, const char[] channel, const char[] messageid, const char[] emoji, Handle fForward, any data) {
    char url[256], route[128];
    FormatEx(url, sizeof(url), "https://discord.com/api/channels/%s/messages/%s/reactions/%s", channel, messageid, emoji);
    FormatEx(route, sizeof(route), "channels/%s/messages/reactions", channel);
    
    if(!CheckRateLimit(route)) {
        DataPack dp = new DataPack();
        dp.WriteCell(bot); dp.WriteString(channel); dp.WriteString(messageid); dp.WriteString(emoji); 
        dp.WriteCell(fForward); dp.WriteCell(data);
        CreateTimer(1.0, GetReactionDelayed, dp);
        return;
    }
    
    HTTPRequest request = new HTTPRequest(url);
    if(request == null) {
        DataPack dp = new DataPack();
        dp.WriteCell(bot); dp.WriteString(channel); dp.WriteString(messageid); dp.WriteString(emoji); 
        dp.WriteCell(fForward); dp.WriteCell(data);
        CreateTimer(2.0, GetReactionDelayed, dp);
        return;
    }
    
    BuildAuthHeader(request, bot);
    request.Timeout = 30;
    
    DataPack dp = new DataPack();
    dp.WriteCell(bot); dp.WriteString(channel); dp.WriteString(messageid); dp.WriteString(emoji); 
    dp.WriteCell(fForward); dp.WriteCell(data);
    request.Get(GetReactionCallback, dp);
}

public Action GetReactionDelayed(Handle timer, any data) {
    DataPack dp = view_as<DataPack>(data);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char channel[64], messageid[64], emoji[64];
    dp.ReadString(channel, sizeof(channel)); dp.ReadString(messageid, sizeof(messageid)); dp.ReadString(emoji, sizeof(emoji));
    Handle fForward = dp.ReadCell();
    any addData = dp.ReadCell();
    GetReaction(bot, channel, messageid, emoji, fForward, addData);
    delete dp;
    return Plugin_Stop;
}

public void GetReactionCallback(HTTPResponse response, any value) {
    DataPack dp = view_as<DataPack>(value);
    dp.Reset();
    DiscordBot bot = dp.ReadCell();
    char channel[64], messageid[64], emoji[64];
    dp.ReadString(channel, sizeof(channel)); dp.ReadString(messageid, sizeof(messageid)); dp.ReadString(emoji, sizeof(emoji));
    Handle fForward = dp.ReadCell();
    any addData = dp.ReadCell();
    delete dp;
    
    char route[128]; FormatEx(route, sizeof(route), "channels/%s/messages/reactions", channel);
    UpdateRateLimits(response, route);
    
    if(response.Status != HTTPStatus_OK) {
        if(response.Status == HTTPStatus_TooManyRequests || response.Status == HTTPStatus_InternalServerError) {
            GetReaction(bot, channel, messageid, emoji, fForward, addData);
            return;
        }
        if(fForward != null) delete fForward;
        return;
    }
    
    JSON data = response.Data;
    ArrayList alUsers = new ArrayList();
    
    if(data != null) {
        JSONArray hJson = view_as<JSONArray>(data);
        for(int i = 0; i < hJson.Length; i++) {
            JSONObject userObj = view_as<JSONObject>(hJson.Get(i));
            alUsers.Push(JsonDeepCopy(userObj));
            delete userObj;
        }
        delete hJson;
    }
    
    if(fForward != null) {
        Call_StartForward(fForward);
        Call_PushCell(bot);
        Call_PushCell(alUsers);
        Call_PushString(channel);
        Call_PushString(messageid);
        Call_PushString(emoji);
        Call_PushCell(addData);
        Call_Finish();
        delete fForward;
    }
    
    for(int i = 0; i < alUsers.Length; i++) {
        delete view_as<Handle>(alUsers.Get(i));
    }
    delete alUsers;
}

public Action GetGuildChannelsDelayed(Handle timer, any datapack) {
	DataPack dp = view_as<DataPack>(datapack);
	dp.Reset();
	DiscordBot bot = dp.ReadCell();
	char guild[32];
	dp.ReadString(guild, sizeof(guild));
	
	dp.Reset(); 
	GetGuildChannelsSendRequest(bot, guild, dp);
	return Plugin_Stop;
}
