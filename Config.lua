
local ADDON_NAME, Data = ...


local buildMajor = tonumber(GetBuildInfo():match"^(%d+)%.")
if buildMajor == 2 then
  Data.WOW_VERSION = "BCC"
elseif buildMajor == 1 then
  Data.WOW_VERSION = "Classic"
end

function Data:IsBCC()
  return Data.WOW_VERSION == "BCC"
end
function Data:IsClassic()
  return Data.WOW_VERSION == "Classic"
end


Data.CHAT_COMMAND    = "pt"
Data.ADDON_PREFIX    = "ProxyTalksie"
Data.HEARTBEAT_EVENT = "ProxyTalksie Heartbeat"


Data.PAIR_REQUEST_TIMEOUT   = 2*60
Data.PAIR_ESTABLISH_TIMEOUT = 5
Data.HEARTBEAT_PERIOD       = 20
Data.HEARTBEAT_TIMEOUT      = 55


Data.OP_CODES = {
  ["PAIR_REQUEST"] = 1,
  ["PAIR_ESTABLISH"] = 2,
  ["UNPAIR"] = 3,
  ["RELAY"] = 4,
  ["HEARTBEAT"] = 5,
}


Data.UNSUPPRESSED_CHANNELS = {
  ["WHISPER"]       = true,
  ["EMOTE"]         = true,
  ["RAID_WARNING"]  = true,
  ["INSTANCE_CHAT"] = true,
  ["BATTLEGROUND"]  = true,
  ["AFK"]           = true,
  ["DND"]           = true,
}



-- How spread out options are in interface options
local OPTIONS_DIVIDER_HEIGHT = 3

local OPTION_DEFAULTS = {
  profile = {
    
    Proxy = {
      Channels = {
        SAY     = true,
        YELL    = true,
        PARTY   = false,
        RAID    = false,
        GUILD   = false,
        OFFICER = false,
      },
      
      ChannelCategories = {
        server = false,
        custom = true,
      },
      
      RestrictedChannels = "world\nlfg",
      
      prefix = "%s: ",
    },
    
    Talksie = {
      suppressChat = false,
    },
    
    DEBUG = {
      MENU = false,
    },
  },
}

function Data:GetDefaultOptions()
  return OPTION_DEFAULTS
end




local function GetOptionTableHelpers(Options, defaultOrder, Addon)
  local GUI = {}
  
  local order = defaultOrder or 99
  function GUI.Order(inc)
    order = order + (inc and inc or 0) + 1
    return order
  end
  
  function GUI.CreateHeader(name)
    Options.args["divider " .. GUI.Order()] = {name = name, order = GUI.Order(-1), type = "header"}
  end
  
  function GUI.CreateDivider(count)
    for i = 1, count or OPTIONS_DIVIDER_HEIGHT do
      Options.args["divider " .. GUI.Order()] = {name = "", order = GUI.Order(-1), type = "description"}
    end
  end
  function GUI.CreateNewline()
    GUI.CreateDivider(1)
  end
  function GUI.CreateDescription(desc, fontSize)
    Options.args["description" .. GUI.Order()] = {name = desc, fontSize = fontSize or "large", order = GUI.Order(-1), type = "description"}
  end
  function GUI.CreateToggle(key, name, desc, inline)
    if type(key) ~= "table" then key = {key} end
    Options.args["toggle " .. table.concat(key, ".")] = {
      name      = name,
      desc      = desc,
      order     = GUI.Order(),
      type      = "toggle",
      descStyle = inline and "inline" or nil,
      set       = function(info, val)        Addon:SetOption(val, unpack(key)) end,
      get       = function(info)      return Addon:GetOption(unpack(key))      end,
    }
  end
  function GUI.CreateInput(key, name, desc, multiline)
    if type(key) ~= "table" then key = {key} end
    Options.args["input " .. table.concat(key, ".")] = {
      name      = name,
      desc      = desc,
      order     = GUI.Order(),
      type      = "input",
      multiline = multiline,
      set       = function(info, val)        Addon:SetOption(val, unpack(key)) end,
      get       = function(info)      return Addon:GetOption(unpack(key))      end,
    }
  end
  function GUI.CreateExecute(key, name, desc, func)
    Options.args["execute " .. key] = {
      name  = name,
      desc  = desc,
      order = GUI.Order(),
      type  = "execute",
      func  = func,
    }
  end
  
  return GUI
end


function Data:MakeOptionsTable(title, Addon, L)
  local Options = {
    name = title,
    type = "group",
    args = {}
  }
  local GUI = GetOptionTableHelpers(Options, nil, Addon)
  
  
  GUI.CreateDescription(L["Proxy and Talksie configuration can be adjusted in the categories to the left."])
  GUI.CreateDivider()
  GUI.CreateDescription(L["Usage:"] .. " /pt", "medium")
  
  GUI.CreateDivider(10)
  GUI.CreateExecute("ListLinks", L["List active links"], nil, function() Addon:ListLinks() end)
  GUI.CreateNewline()
  GUI.CreateExecute("UnpairAll", L["Unpair all"], nil, function() Addon:UnpairAll() end)
  
  return Options
end


function Data:MakeProxyOptionsTable(title, Addon, L)
  local Options = {
    name = title,
    type = "group",
    args = {}
  }
  local GUI = GetOptionTableHelpers(Options, nil, Addon)
  
  
  GUI.CreateDescription(L["Allowed Channels"], "medium")
  GUI.CreateNewline()
  GUI.CreateToggle({"Proxy", "Channels", "SAY"}    , CHAT_MSG_SAY)
  GUI.CreateToggle({"Proxy", "Channels", "YELL"}   , CHAT_MSG_YELL)
  GUI.CreateNewline()
  GUI.CreateToggle({"Proxy", "Channels", "PARTY"}  , CHAT_MSG_PARTY)
  GUI.CreateToggle({"Proxy", "Channels", "RAID"}   , CHAT_MSG_RAID)
  GUI.CreateNewline()
  GUI.CreateToggle({"Proxy", "Channels", "GUILD"}  , CHAT_MSG_GUILD)
  GUI.CreateToggle({"Proxy", "Channels", "OFFICER"}, CHAT_MSG_OFFICER)
  GUI.CreateNewline()
  GUI.CreateToggle({"Proxy", "Channels", "server"} , L["Server Channels"], L["This refers to custom channels which are owned by Blizzard. Some examples are the General and Trade channels."])
  GUI.CreateToggle({"Proxy", "Channels", "custom"} , L["Custom Channels"], L["This referes to player-created custom channels, like World chat."])
  
  GUI.CreateNewline()
  GUI.CreateInput({"Proxy", "RestrictedChannels"}, L["Restricted Custom Channels"], L["You will not post messages in any custom channel listed here. List one channel per line."], true)
  GUI.CreateDivider()
  GUI.CreateInput({"Proxy", "prefix"}, L["Prefix"], L["This text will appear at the start of messages you say while serving as a proxy. %s will be replaced with the Talksie's name."])
  
  return Options
end


function Data:MakeTalksieOptionsTable(title, Addon, L)
  local Options = {
    name = title,
    type = "group",
    args = {}
  }
  local GUI = GetOptionTableHelpers(Options, nil, Addon)
  
  
  GUI.CreateToggle({"Talksie", "suppressChat"}, L["Suppress Chat"], L["Enabling this option will prevent chat messages from being sent on most channels while you are a Talksie."])
  
  return Options
end


function Data:MakeDebugOptionsTable(title, Addon, L)
  local Options = {
    name = title,
    type = "group",
    args = {}
  }
  local GUI = GetOptionTableHelpers(Options, nil, Addon)
  
  return Options
end



function Data:Init(Addon, L)
  StaticPopupDialogs[("%s_CONFIRM_PAIR_REQUEST"):format(ADDON_NAME:upper())] =
  {
    text         = L["%s is requesting to proxy chat through you. Would you like to allow this?\n(Configure Proxy settings with: /pt config)"],
    button1      = YES,
    button2      = NO,
    timeout      = Data.PAIR_REQUEST_TIMEOUT,
    whileDead    = 1,
    hideOnEscape = 1,
    OnAccept = function(self, target)
      Addon.TentativeTalksies[target] = Addon:ScheduleTimer(function() Addon:Printf(L["Pair attempt with %s has timed out"], target) end, Data.PAIR_ESTABLISH_TIMEOUT)
      Addon:SendProxyConfirmation(target)
    end,
  }
  
  StaticPopupDialogs[("%s_CHANNEL_CHAT_PROMPT"):format(ADDON_NAME:upper())] =
  {
    text         = L["Click to post hardware-locked messages"],
    button1      = OKAY,
    button2      = NO,
    timeout      = Data.PAIR_REQUEST_TIMEOUT,
    whileDead    = 1,
    hideOnEscape = 1,
    OnAccept = function(self)
      for _, func in ipairs(Addon.ChannelQueue) do
        func()
      end
      wipe(Addon.ChannelQueue)
    end,
  }
end


