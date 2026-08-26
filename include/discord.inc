#if defined _discord_included
	#endinput
#endif
#define _discord_included

#include <ripext>

// ==========================================
// TYPEDEFS
// ==========================================

typedef DiscordGuildsRetrieve = function void (DiscordBot bot, char[] id, char[] name, char[] icon, bool owner, int permissions, any data);
typedef DiscordGuildsRetrievedAll = function void (DiscordBot bot, ArrayList id, ArrayList name, ArrayList icon, ArrayList owner, ArrayList permissions, any data);
typedef DiscordGuildChannelsRetrieve = function void (DiscordBot bot, char[] guild, DiscordChannel Channel, any data);
typedef DiscordGuildChannelsRetrieveAll = function void (DiscordBot bot, char[] guild, ArrayList Channels, any data);
typedef DiscordGuildGetRoles = function void (DiscordBot bot, char[] guild, RoleList Roles, any data);

typeset OnChannelMessage { 
	function void(DiscordBot bot, DiscordChannel channel, DiscordMessage message);
};

typedef OnGetReactions = function void (DiscordBot bot, ArrayList Users, char[] channelID, const char[] messageID, const char[] emoji, any data);
typedef OnMessageSent = function void(DiscordBot bot, char[] channel, DiscordMessage message, any data);
typedef OnMessageDeleted = function void(DiscordBot bot, any data);
typedef OnGetMembers = function void(DiscordBot bot, char[] guild, Handle hMemberList);

// ==========================================
// METHODMAPS
// ==========================================

methodmap Role < Handle {
	public void GetID(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "id", buffer, maxlength);
	}
	public void GetName(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "name", buffer, maxlength);
	}
	public int GetColor() {
		return JsonObjectGetInt(view_as<JSONObject>(this), "color");
	}
	public int GetPosition() {
		return JsonObjectGetInt(view_as<JSONObject>(this), "position");
	}
	public int GetPermissions() {
		return JsonObjectGetInt(view_as<JSONObject>(this), "permissions");
	}
	public bool Hoist() {
		return JsonObjectGetBool(view_as<JSONObject>(this), "hoist");
	}
	public bool Managed() {
		return JsonObjectGetBool(view_as<JSONObject>(this), "managed");
	}
	public bool Mentionable() {
		return JsonObjectGetBool(view_as<JSONObject>(this), "mentionable");
	}
};

methodmap RoleList < Handle {
	property int Size {
		public get() {
			return view_as<JSONArray>(this).Length;
		}
	}
	public Role GetRole(int i) {
		return view_as<Role>(view_as<JSONArray>(this).Get(i));
	}
	public Role Get(int i) {
		return this.GetRole(i);
	}
};

methodmap DiscordUser < Handle {
	public void GetID(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "id", buffer, maxlength);
	}
	public void GetUsername(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "username", buffer, maxlength);
	}
	public void GetDiscriminator(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "discriminator", buffer, maxlength);
	}
	public int GetDiscriminatorInt() {
		char buffer[16];
		this.GetDiscriminator(buffer, sizeof(buffer));
		return StringToInt(buffer);
	}
	public void GetAvatar(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "avatar", buffer, maxlength);
	}
	public bool IsVerified() {
		return JsonObjectGetBool(view_as<JSONObject>(this), "verified");
	}
	public void GetEmail(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "email", buffer, maxlength);
	}
	public bool IsBot() {
		return JsonObjectGetBool(view_as<JSONObject>(this), "bot");
	}
};

methodmap DiscordMessage < Handle {
	public void GetID(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "id", buffer, maxlength);
	}
	public bool IsPinned() {
		return JsonObjectGetBool(view_as<JSONObject>(this), "pinned");
	}
	public DiscordUser GetAuthor() {
		JSONObject obj = view_as<JSONObject>(this);
		if (!obj.HasKey("author")) {
			return null;
		}
		JSON author = obj.Get("author");
		return view_as<DiscordUser>(author);
	}
	public void GetContent(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "content", buffer, maxlength);
	}
	public void GetChannelID(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "channel_id", buffer, maxlength);
	}
};

enum {
	GUILD_TEXT = 0,
	DM,
	GUILD_VOICE,
	GROUP_DM,
	GUILD_CATEGORY
};

methodmap DiscordChannel < Handle {
	public DiscordChannel() {
		JSONObject hObj = new JSONObject();
		return view_as<DiscordChannel>(hObj);
	}
	public native void SendMessage(DiscordBot Bot, char[] message, OnMessageSent fCallback=INVALID_FUNCTION, any data=0);
	public void GetGuildID(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "guild_id", buffer, maxlength);
	}
	public void GetID(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "id", buffer, maxlength);
	}
	public void GetName(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "name", buffer, maxlength);
	}
	property int Position {
		public get() {
			return JsonObjectGetInt(view_as<JSONObject>(this), "position");
		}
	}
	property bool IsPrivate {
		public get() {
			return JsonObjectGetBool(view_as<JSONObject>(this), "is_private");
		}
	}
	public void GetTopic(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "topic", buffer, maxlength);
	}
	public void GetLastMessageID(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "last_message_id", buffer, maxlength);
	}
	public void SetLastMessageID(const char[] id) {
		view_as<JSONObject>(this).SetString("last_message_id", id);
	}
	property int Type {
		public get() {
			return JsonObjectGetInt(view_as<JSONObject>(this), "type");
		}
	}
	property int Bitrate {
		public get() {
			return JsonObjectGetInt(view_as<JSONObject>(this), "bitrate");
		}
	}
	property int UserLimit {
		public get() {
			return JsonObjectGetInt(view_as<JSONObject>(this), "user_limit");
		}
	}
	property bool IsText {
		public get() {
			return this.Type == GUILD_TEXT;
		}
	}
};

methodmap MessageEmbed < Handle {
	public MessageEmbed() {
		JSONObject hObj = new JSONObject();
		return view_as<MessageEmbed>(hObj);
	}
	public bool GetColor(char[] buffer, int maxlength) {
		int colorInt = view_as<JSONObject>(this).GetInt("color");
		if (colorInt == 0) return false;
		Format(buffer, maxlength, "#%06X", colorInt);
		return true;
	}
	public void SetColor(const char[] color) {
		int colorInt = 0;
		char cleanColor[16];
		strcopy(cleanColor, sizeof(cleanColor), color);
		ReplaceString(cleanColor, sizeof(cleanColor), "#", "", false);
		
		if (cleanColor[0] != '\0') {
			colorInt = StringToInt(cleanColor, 16);
		}
		
		view_as<JSONObject>(this).SetInt("color", colorInt);
	}
	public bool GetTitle(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("title", buffer, maxlength);
	}
	public void SetTitle(const char[] title) {
		view_as<JSONObject>(this).SetString("title", title);
	}
	public bool GetTitleLink(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("title_link", buffer, maxlength);
	}
	public void SetTitleLink(const char[] title_link) {
		view_as<JSONObject>(this).SetString("title_link", title_link);
	}
	public bool GetImage(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("image_url", buffer, maxlength);
	}
	public void SetImage(const char[] image_url) {
		view_as<JSONObject>(this).SetString("image_url", image_url);
	}
	public bool GetAuthor(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("author_name", buffer, maxlength);
	}
	public void SetAuthor(const char[] name, const char[] icon_url, const char[] url) {
		JSONObject obj = view_as<JSONObject>(this);
		JSONObject author = new JSONObject();
		
		if(!StrEqual(name, "")) author.SetString("name", name);
		if(!StrEqual(icon_url, "")) author.SetString("icon_url", icon_url);
		if(!StrEqual(url, "")) author.SetString("url", url);
		
		obj.Set("author", author);
		delete author;
	}
	public bool GetAuthorLink(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("author_link", buffer, maxlength);
	}
	public void SetAuthorLink(const char[] author_link) {
		view_as<JSONObject>(this).SetString("author_link", author_link);
	}
	public bool GetAuthorIcon(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("author_icon", buffer, maxlength);
	}
	public void SetAuthorIcon(const char[] author_icon) {
		view_as<JSONObject>(this).SetString("author_icon", author_icon);
	}
	public bool GetThumb(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("thumb_url", buffer, maxlength);
	}
	public void SetThumb(const char[] thumb_url) {
		view_as<JSONObject>(this).SetString("thumb_url", thumb_url);
	}
	public bool GetFooter(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("footer", buffer, maxlength);
	}
	public void SetFooter(const char[] text, const char[] icon_url) {
		JSONObject obj = view_as<JSONObject>(this);
		JSONObject footer = new JSONObject();
		
		if(!StrEqual(text, "")) footer.SetString("text", text);
		if(!StrEqual(icon_url, "")) footer.SetString("icon_url", icon_url);
		
		obj.Set("footer", footer);
		delete footer;
	}
	public bool GetFooterIcon(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("footer_icon", buffer, maxlength);
	}
	public void SetFooterIcon(const char[] footer_icon) {
		view_as<JSONObject>(this).SetString("footer_icon", footer_icon);
	}
	property Handle Fields {
		public get() {
			return view_as<JSONObject>(this).Get("fields");
		}
		public set(Handle value) {
			view_as<JSONObject>(this).Set("fields", view_as<JSON>(value));
		}
	}
	public void AddField(const char[] name, const char[] value, bool inline) {
		JSONObject obj = view_as<JSONObject>(this);
		
		if(!obj.HasKey("fields")) {
			JSONArray fields = new JSONArray();
			obj.Set("fields", fields);
			delete fields;
		}
		
		JSONArray fields = view_as<JSONArray>(obj.Get("fields"));
		JSONObject field = new JSONObject();
		
		if (StrEqual(name, "")) {
			field.SetString("name", "\u200B");
		} else {
			field.SetString("name", name);
		}
		
		field.SetString("value", value);
		field.SetBool("inline", inline);
		
		fields.Push(field);
		delete field;
		delete fields;
	}
	public bool GetDescription(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("description", buffer, maxlength);
	}
	public void SetDescription(const char[] description) {
		view_as<JSONObject>(this).SetString("description", description);
	}
	public bool GetURL(char[] buffer, int maxlength) {
		return view_as<JSONObject>(this).GetString("url", buffer, maxlength);
	}
	public void SetURL(const char[] url) {
		view_as<JSONObject>(this).SetString("url", url);
	}
};

methodmap DiscordWebHook < Handle {
    public DiscordWebHook(const char[] url) {
        JSONObject mp = new JSONObject();
        mp.SetString("__url", url);
        JSONObject data = new JSONObject();
        mp.Set("__data", data);
        delete data;
        return view_as<DiscordWebHook>(mp);
    }
    
    public void GetUrl(char[] buffer, int maxlength) {
        view_as<JSONObject>(this).GetString("__url", buffer, maxlength);
    }
    
    property bool SlackMode {
        public get() {
            return JsonObjectGetBool(view_as<JSONObject>(this), "__slack", false);
        }
        public set(bool value) {
            view_as<JSONObject>(this).SetBool("__slack", value);
        }
    }
    
    property Handle Data {
        public get() {
            return view_as<JSONObject>(this).Get("__data");
        }
        public set(Handle value) {
            view_as<JSONObject>(this).Set("__data", view_as<JSON>(value));
        }
    }
    
    // ==========================================
    // ИСПРАВЛЕННЫЕ СЕТТЕРЫ/ГЕТТЕРЫ (без двойной вложенности)
    // ==========================================
    public bool GetContent(char[] buffer, int maxlength) {
        JSONObject data = view_as<JSONObject>(this.Data);
        bool success = data.GetString("content", buffer, maxlength);
        delete data;
        return success;
    }
    
    public void SetContent(const char[] content) {
        JSONObject data = view_as<JSONObject>(this.Data);
        data.SetString("content", content);
        delete data;
    }
    
    public bool GetUsername(char[] buffer, int maxlength) {
        JSONObject data = view_as<JSONObject>(this.Data);
        bool success = data.GetString("username", buffer, maxlength);
        delete data;
        return success;
    }
    
    public void SetUsername(const char[] name) {
        JSONObject data = view_as<JSONObject>(this.Data);
        data.SetString("username", name);
        delete data;
    }
    
    public bool GetAvatar(char[] buffer, int maxlength) {
        JSONObject data = view_as<JSONObject>(this.Data);
        bool success = data.GetString("avatar_url", buffer, maxlength);
        delete data;
        return success;
    }
    
    public void SetAvatar(const char[] icon_url) {
        JSONObject data = view_as<JSONObject>(this.Data);
        data.SetString("avatar_url", icon_url);
        delete data;
    }
    
    property bool tts {
        public get() {
            JSONObject data = view_as<JSONObject>(this.Data);
            bool value = JsonObjectGetBool(data, "tts", false);
            delete data;
            return value;
        }
        public set(bool value) {
            JSONObject data = view_as<JSONObject>(this.Data);
            data.SetBool("tts", value);
            delete data;
        }
    }
    
    public void Embed(MessageEmbed Object) {
        JSONObject data = view_as<JSONObject>(this.Data);
        JSONArray hArray = null;
        if(data.HasKey("embeds")) {
            hArray = view_as<JSONArray>(data.Get("embeds"));
        } else {
            hArray = new JSONArray();
            data.Set("embeds", hArray);
        }
        hArray.Push(view_as<JSON>(Object));
        delete hArray;
        delete data;
    }
    
    public native void Send();
};

methodmap DiscordGuildUser < Handle {
	public DiscordUser GetUser() {
		return view_as<DiscordUser>(view_as<JSONObject>(this).Get("user"));
	}
	public void GetNickname(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "nick", buffer, maxlength);
	}
	public Handle GetRoles() {
		return view_as<JSONObject>(this).Get("roles");
	}
	public void GetJoinedAt(char[] buffer, int maxlength) {
		JsonObjectGetString(view_as<JSONObject>(this), "joined_at", buffer, maxlength);
	}
	public bool IsDeaf() {
		return JsonObjectGetBool(view_as<JSONObject>(this), "deaf");
	}
	public bool IsMute() {
		return JsonObjectGetBool(view_as<JSONObject>(this), "mute");
	}
};

methodmap DiscordBot < StringMap {
	public DiscordBot(const char[] token) {
		JSONObject json = new JSONObject();
		json.SetString("token", token);
		return view_as<DiscordBot>(json);
	}
	public void StopListening() {
		JSONObject obj = view_as<JSONObject>(this);
		if(obj.HasKey("listeningChannels")) {
			JSON arr = obj.Get("listeningChannels");
			delete arr;
			obj.Remove("listeningChannels");
		}
	}
	property float MessageCheckInterval {
		public get() {
			return JsonObjectGetFloat(view_as<JSONObject>(this), "messageInterval", 3.0);
		}
		public set(float value) {
			view_as<JSONObject>(this).SetFloat("messageInterval", value);
		}
	}
	public native void StartTimer(DiscordChannel Channel, OnChannelMessage fCallback);
	public Handle GetListeningChannels() {
		JSONObject obj = view_as<JSONObject>(this);
		if(!obj.HasKey("listeningChannels")) {
			return null;
		}
		return obj.Get("listeningChannels");
	}
	public bool IsListeningToChannel(DiscordChannel Channel) {
		char id[32];
		Channel.GetID(id, sizeof(id));
		Handle hChannels = this.GetListeningChannels();
		if(hChannels == null) return false;
		
		JSONArray arr = view_as<JSONArray>(hChannels);
		for(int i = 0; i < arr.Length; i++) {
			JSON temp = arr.Get(i);
			DiscordChannel tempChannel = view_as<DiscordChannel>(temp);
			static char tempID[32];
			tempChannel.GetID(tempID, sizeof(tempID));
			if(StrEqual(id, tempID, false)) {
				delete temp;
				delete arr;
				return true;
			}
			delete temp;
		}
		delete arr;
		return false;
	}
	public bool IsListeningToChannelID(const char[] id) {
		Handle hChannels = this.GetListeningChannels();
		if(hChannels == null) return false;
		
		JSONArray arr = view_as<JSONArray>(hChannels);
		for(int i = 0; i < arr.Length; i++) {
			JSON temp = arr.Get(i);
			DiscordChannel tempChannel = view_as<DiscordChannel>(temp);
			static char tempID[32];
			tempChannel.GetID(tempID, sizeof(tempID));
			if(StrEqual(id, tempID, false)) {
				delete temp;
				delete arr;
				return true;
			}
			delete temp;
		}
		delete arr;
		return false;
	}
	public void StopListeningToChannel(DiscordChannel Channel) {
		char id[32];
		Channel.GetID(id, sizeof(id));
		Handle channels = this.GetListeningChannels();
		if(channels == null) return;
		
		JSONArray arr = view_as<JSONArray>(channels);
		static char tempID[32];
		for(int i = 0; i < arr.Length; i++) {
			JSON temp = arr.Get(i);
			DiscordChannel tempChannel = view_as<DiscordChannel>(temp);
			tempChannel.GetID(tempID, sizeof(tempID));
			if(StrEqual(id, tempID, false)) {
				arr.Remove(i);
				i--;
			}
			delete temp;
		}
		delete arr;
	}
	public void StopListeningToChannels() {
		Handle channels = this.GetListeningChannels();
		if(channels == null) return;
		
		JSONArray arr = view_as<JSONArray>(channels);
		for(int i = 0; i < arr.Length; i++) {
			arr.Remove(i);
			i--;
		}
		delete arr;
	}
	public void StopListeningToChannelID(const char[] id) {
		Handle channels = this.GetListeningChannels();
		if(channels == null) return;
		
		JSONArray arr = view_as<JSONArray>(channels);
		for(int i = 0; i < arr.Length; i++) {
			JSON temp = arr.Get(i);
			DiscordChannel tempChannel = view_as<DiscordChannel>(temp);
			static char tempID[32];
			tempChannel.GetID(tempID, sizeof(tempID));
			if(StrEqual(id, tempID, false)) {
				arr.Remove(i);
				i--;
			}
			delete temp;
		}
		delete arr;
	}
	public DiscordChannel GetListeningChannelByID(const char[] id) {
		Handle channels = this.GetListeningChannels();
		if(channels == null) return null;
		JSONArray arr = view_as<JSONArray>(channels);
		for(int i = 0; i < arr.Length; i++) {
			JSON temp = arr.Get(i);
			DiscordChannel tempChannel = view_as<DiscordChannel>(temp);
			static char tempID[32];
			tempChannel.GetID(tempID, sizeof(tempID));
			if(StrEqual(id, tempID, false)) {
				delete arr;
				return tempChannel;
			}
			delete temp;
		}
		delete arr;
		return null;
	}
	public void StartListeningToChannel(DiscordChannel Channel, OnChannelMessage fCallback) {
		if(this.IsListeningToChannel(Channel)) return;
		
		Handle channels = this.GetListeningChannels();
		if(channels == null) {
			JSONArray arr = new JSONArray();
			view_as<JSONObject>(this).Set("listeningChannels", arr);
			channels = arr;
		}
		
		JSONArray arr = view_as<JSONArray>(channels);
		arr.Push(view_as<JSON>(Channel));
		delete arr;
		
		this.StartTimer(Channel, fCallback);
	}
	public native void AddReactionID(const char[] channel, const char[] messageid, const char[] emoji);
	public void AddReaction(DiscordChannel channel, const char[] messageid, const char[] emoji) {
		char channelid[64];
		channel.GetID(channelid, sizeof(channelid));
		this.AddReactionID(channelid, messageid, emoji);
	}
	public native void DeleteReactionID(const char[] channel, const char[] messageid, const char[] emoji, const char[] user);
	public void DeleteReaction(DiscordChannel channel, const char[] messageid, const char[] emoji, const char[] user) {
		char chid[64];
		channel.GetID(chid, sizeof(chid));
		this.DeleteReactionID(chid, messageid, emoji, user);
	}
	public void DeleteReactionSelf(DiscordChannel channel, const char[] messageid, const char[] emoji) {
		this.DeleteReaction(channel, messageid, emoji, "@me");
	}
	public void DeleteReactionAll(DiscordChannel channel, const char[] messageid, const char[] emoji) {
		this.DeleteReaction(channel, messageid, emoji, "@all");
	}
	public void DeleteReactionSelfID(const char[] channel, const char[] messageid, const char[] emoji) {
		this.DeleteReactionID(channel, messageid, emoji, "@me");
	}
	public void DeleteReactionAllID(const char[] channel, const char[] messageid, const char[] emoji) {
		this.DeleteReactionID(channel, messageid, emoji, "@all");
	}
	public native void GetReactionID(const char[] channel, const char[] messageid, const char[] emoji, OnGetReactions fCallback=INVALID_FUNCTION, any data=0);
	public void GetReaction(DiscordChannel channel, const char[] messageid, const char[] emoji, OnGetReactions fCallback=INVALID_FUNCTION, any data=0) {
		char id[64];
		channel.GetID(id, sizeof(id));
		this.GetReactionID(id, messageid, emoji, fCallback, data);
	}
	public native void GetToken(char[] token, int maxlength);
	public native void SendMessage(DiscordChannel channel, char[] message, OnMessageSent fCallback=INVALID_FUNCTION, any data=0);
	public native void SendMessageToChannelID(char[] channel, char[] message, OnMessageSent fCallback=INVALID_FUNCTION, any data=0);
	public native void DeleteMessageID(char[] channel, char[] message, OnMessageDeleted fCallback=INVALID_FUNCTION, any data=0);
	public native void DeleteMessage(DiscordChannel channel, DiscordMessage message, OnMessageDeleted fCallback=INVALID_FUNCTION, any data=0);
	public native void GetGuilds(DiscordGuildsRetrieve fCallback = INVALID_FUNCTION, DiscordGuildsRetrievedAll fCallbackAll = INVALID_FUNCTION, any data=0);
	public native void GetGuildChannels(char[] guild, DiscordGuildChannelsRetrieve fCallback = INVALID_FUNCTION, DiscordGuildChannelsRetrieveAll fCallbackAll = INVALID_FUNCTION, any data=0);
	public native void GetGuildMembers(char[] guild, OnGetMembers fCallback, int limit=250, char[] afterUserID="");
	public native void GetGuildMembersAll(char[] guild, OnGetMembers fCallback, int perPage=250, char[] afterUserID="");
	public native void GetGuildRoles(char[] guild, DiscordGuildGetRoles fCallback, any data);
};

// ==========================================
// COMPATIBILITY STOCKS (for old code)
// ==========================================

stock int JsonObjectGetInt(JSONObject hElement, const char[] key) {
	if(!hElement.HasKey(key)) return 0;
	return hElement.GetInt(key);
}

stock bool JsonObjectGetString(JSONObject hElement, const char[] key, char[] buffer, int maxlength) {
	if(!hElement.HasKey(key)) return false;
	return hElement.GetString(key, buffer, maxlength);
}

stock bool JsonObjectGetBool(JSONObject hElement, const char[] key, bool defaultvalue=false) {
	if(!hElement.HasKey(key)) return defaultvalue;
	return hElement.GetBool(key);
}

stock float JsonObjectGetFloat(JSONObject hElement, const char[] key, float defaultValue=0.0) {
	if(!hElement.HasKey(key)) return defaultValue;
	return hElement.GetFloat(key);
}

stock bool RenameJsonObject(JSONObject hJson, const char[] key, const char[] toKey) {
	if(!hJson.HasKey(key)) return false;
	JSON hObject = hJson.Get(key);
	if(hObject == null) return false;
	hJson.Set(toKey, hObject);
	hJson.Remove(key);
	delete hObject;
	return true;
}

// ==========================================
// SHARED PLUGIN
// ==========================================

public SharedPlugin __pl_discordapi = {
	name = "discord-api",
	file = "discord-api.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_discordapi_SetNTVOptional() {
	MarkNativeAsOptional("DiscordBot.StartTimer");
	MarkNativeAsOptional("DiscordBot.AddReactionID");
	MarkNativeAsOptional("DiscordBot.DeleteReactionID");
	MarkNativeAsOptional("DiscordBot.GetReactionID");
	MarkNativeAsOptional("DiscordBot.GetToken");
	MarkNativeAsOptional("DiscordBot.SendMessage");
	MarkNativeAsOptional("DiscordBot.SendMessageToChannelID");
	MarkNativeAsOptional("DiscordBot.DeleteMessageID");
	MarkNativeAsOptional("DiscordBot.DeleteMessage");
	MarkNativeAsOptional("DiscordBot.GetGuilds");
	MarkNativeAsOptional("DiscordBot.GetGuildChannels");
	MarkNativeAsOptional("DiscordBot.GetGuildMembers");
	MarkNativeAsOptional("DiscordBot.GetGuildMembersAll");
	MarkNativeAsOptional("DiscordBot.GetGuildRoles");
	MarkNativeAsOptional("DiscordChannel.SendMessage");
	MarkNativeAsOptional("DiscordWebHook.Send");
}
#endif
