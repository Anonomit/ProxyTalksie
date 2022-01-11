
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


Data.RESTRICTED_CUSTOM_CHANNELS = {
  ["world"] = true,
}



-- How spread out options are in interface options
local OPTIONS_DIVIDER_HEIGHT = 3

local OPTION_DEFAULTS = {
  profile = {
    
    SAY     = true,
    YELL    = true,
    PARTY   = false,
    RAID    = false,
    GUILD   = false,
    OFFICER = false,
    
    Server = false,
    Custom = true,
    
    RestrictedChannels = "world\nlfg",
    
    prefix = "%s: ",
    
    DEBUG = {
      MENU = false,
    },
  },
}

function Data:GetDefaultOptions()
  return OPTION_DEFAULTS
end




local function GetOptionTableHelpers(Options, defaultOrder)
  local Helpers = {}
  
  local order = defaultOrder or 99
  function Helpers.Order(inc)
    order = order + (inc and inc or 0) + 1
    return order
  end
  
  function Helpers.CreateHeader(name)
    Options.args["divider" .. Helpers.Order()] = {name = name, order = Helpers.Order(-1), type = "header"}
  end
  
  function Helpers.CreateDivider(count)
    for i = 1, count or OPTIONS_DIVIDER_HEIGHT do
      Options.args["divider" .. Helpers.Order()] = {name = "", order = Helpers.Order(-1), type = "description"}
    end
  end
  function Helpers.CreateNewline()
    Helpers.CreateDivider(1)
  end
  function Helpers.CreateDescription(desc, fontSize)
    Options.args["description" .. Helpers.Order()] = {name = desc, fontSize = fontSize or "large", order = Helpers.Order(-1), type = "description"}
  end
  
  return Helpers
end


function Data:MakeOptionsTable(Addon, L)
  local Options = {
    type = "group",
    args = {}
  }
  
  local Helpers           = GetOptionTableHelpers(Options)
  local Order             = Helpers.Order
  local CreateHeader      = Helpers.CreateHeader
  local CreateDivider     = Helpers.CreateDivider
  local CreateNewline     = Helpers.CreateNewline
  local CreateDescription = Helpers.CreateDescription
  
  
  local db = Addon:GetDB()
  
  
  local function CreateToggle(key, name, desc)
    Options.args[key] = {
      name  = name,
      desc  = desc,
      order = Order(),
      type  = "toggle",
      set   = function(info, val)        Addon:GetDB()[key] = val end,
      get   = function(info)      return Addon:GetDB()[key]       end,
    }
  end
  
  
  CreateDescription(L["Allowed Channels"])
  CreateNewline()
  CreateToggle("SAY"    , CHAT_MSG_SAY)
  CreateToggle("YELL"   , CHAT_MSG_YELL)
  CreateNewline()
  CreateToggle("PARTY"  , CHAT_MSG_PARTY)
  CreateToggle("RAID"   , CHAT_MSG_RAID)
  CreateNewline()
  CreateToggle("GUILD"  , CHAT_MSG_GUILD)
  CreateToggle("OFFICER", CHAT_MSG_OFFICER)
  CreateNewline()
  CreateToggle("Server" , L["Server Channels"])
  CreateToggle("Custom" , L["Custom Channels"])
  CreateNewline()
  
  
  
  Options.args["RestrictedChannels"] = {
    name      = L["Restricted Custom Channels"],
    desc      = L["You will not post messages in any custom channel listed here. List one channel per line."],
    order     = Order(),
    type      = "input",
    multiline = true,
    set       = function(info, val)        Addon:GetDB().RestrictedChannels = val:lower() end,
    get       = function(info)      return Addon:GetDB().RestrictedChannels               end,
  }
  
  CreateDivider(5)
  
  Options.args["Prefix"] = {
    name      = L["Prefix"],
    desc      = L["This text will appear at the start of messages you say while serving as a proxy. %s will be replaced with the Talksie's name"],
    order     = Order(),
    type      = "input",
    set       = function(info, val)        Addon:GetDB().prefix = val end,
    get       = function(info)      return Addon:GetDB().prefix       end,
  }
  
  
  return Options
end



function Data:Init(Addon, L)
  StaticPopupDialogs[("%s_CONFIRM_PAIR_REQUEST"):format(ADDON_NAME:upper())] =
  {
    text         = L["%s is requesting to proxy chat through you. Would you like to allow this?"],
    button1      = YES,
    button2      = NO,
    timeout      = Data.PAIR_REQUEST_TIMEOUT,
    whileDead    = 1,
    hideOnEscape = 1,
    OnAccept = function(self, target)
      Addon.TentativeTalksies[target:lower()] = Addon:ScheduleTimer(function() Addon:Printf(L["Pair attempt with %s has timed out"], target) end, Data.PAIR_ESTABLISH_TIMEOUT)
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


