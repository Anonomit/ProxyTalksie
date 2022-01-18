
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
  ["PAIR_REQUEST"]   = 1,
  ["PAIR_ESTABLISH"] = 2,
  ["UNPAIR"]         = 3,
  ["RELAY"]          = 4,
  ["HEARTBEAT"]      = 5,
  ["VERSION"]        = 6,
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



function Data:MakeDefaultOptions()
  return {
    profile = {
      
      Proxy = {
        Channels = {
          SAY     = false,
          YELL    = false,
          PARTY   = true,
          RAID    = true,
          GUILD   = true,
          OFFICER = false,
        },
        
        ChannelCategories = {
          server = false,
          custom = true,
        },
        
        restrictedChannels = "world\nlfg",
        
        prefix = "%s: ",
      },
      
      Talksie = {
        suppressChat = false,
      },
      
      Debug = {
        menu = false,
      },
    },
  }
end





local function GetOptionTableHelpers(Options, Addon)
  local defaultInc = 1000
  local order      = 1000
  
  local GUI = {}
  
  function GUI:GetOrder()
    return order
  end
  function GUI:SetOrder(newOrder)
    order = newOrder
  end
  function GUI:Order(inc)
    self:SetOrder(self:GetOrder() + (inc or defaultInc))
    return self:GetOrder()
  end
  
  function GUI:CreateEntry(key, name, desc, widgetType, order)
    key = widgetType .. "_" .. (key or "")
    Options.args[key] = {name = name, desc = desc, type = widgetType, order = order or self:Order()}
    return Options.args[key]
  end
  
  function GUI:CreateHeader(name)
    local option = self:CreateEntry(self:Order(), name, nil, "header", self:Order(0))
  end
  
  function GUI:CreateDescription(desc, fontSize)
    local option = self:CreateEntry(self:Order(), desc, nil, "description", self:Order(0))
    option.fontSize = fontSize or "large"
  end
  function GUI:CreateDivider(count)
    for i = 1, count or 3 do
      self:CreateDescription("", "small")
    end
  end
  function GUI:CreateNewline()
    return self:CreateDivider(1)
  end
  
  function GUI:CreateToggle(keys, name, desc, disabled)
    if type(keys) ~= "table" then keys = {keys} end
    local option = self:CreateEntry(table.concat(keys, "."), name, desc, "toggle")
    option.disabled = disabled
    option.set      = function(info, val)        Addon:SetOption(val, unpack(keys)) end
    option.get      = function(info)      return Addon:GetOption(unpack(keys))      end
    return option
  end
  function GUI:CreateRange(keys, name, desc, min, max, step, disabled)
    if type(keys) ~= "table" then keys = {keys} end
    local option = self:CreateEntry(table.concat(keys, "."), name, desc, "range")
    option.disabled = disabled
    option.min      = min
    option.max      = max
    option.step     = step
    option.set      = function(info, val)        Addon:SetOption(val, unpack(keys)) end
    option.get      = function(info)      return Addon:GetOption(unpack(keys))      end
    return option
  end
  function GUI:CreateInput(keys, name, desc, multiline, disabled)
    if type(keys) ~= "table" then keys = {keys} end
    local option = self:CreateEntry(table.concat(keys, "."), name, desc, "input")
    option.multiline = multiline
    option.disabled  = disabled
    option.set       = function(info, val)        Addon:SetOption(val, unpack(keys)) end
    option.get       = function(info)      return Addon:GetOption(unpack(keys))      end
    return option
  end
  function GUI:CreateExecute(key, name, desc, func)
    local option = self:CreateEntry(key, name, desc, "execute")
    option.func = func
    return option
  end
  
  return GUI
end


function Data:MakeOptionsTable(title, Addon, L)
  local Options = {
    name = title,
    type = "group",
    args = {}
  }
  local GUI = GetOptionTableHelpers(Options, Addon)
  
  
  GUI:CreateDivider()
  GUI:CreateDescription(L["Proxy and Talksie configuration can be adjusted in the categories to the left."])
  GUI:CreateDivider()
  GUI:CreateDescription(L["Usage:"] .. " /" .. Data.CHAT_COMMAND, "medium")
  
  GUI:CreateDivider(10)
  GUI:CreateExecute("ListLinks", L["List active links"], nil, function() Addon:ListLinks() end)
  GUI:CreateNewline()
  GUI:CreateExecute("UnpairAll", L["Unpair all"], nil, function() Addon:UnpairAll() end)
  
  return Options
end


function Data:MakeProxyOptionsTable(title, Addon, L)
  local Options = {
    name = title,
    type = "group",
    args = {}
  }
  local GUI = GetOptionTableHelpers(Options, Addon)
  
  
  GUI:CreateDescription(L["Allowed Channels"], "medium")
  GUI:CreateNewline()
  GUI:CreateToggle({"Proxy", "Channels", "SAY"}    , CHAT_MSG_SAY)
  GUI:CreateToggle({"Proxy", "Channels", "YELL"}   , CHAT_MSG_YELL)
  GUI:CreateNewline()
  GUI:CreateToggle({"Proxy", "Channels", "PARTY"}  , CHAT_MSG_PARTY)
  GUI:CreateToggle({"Proxy", "Channels", "RAID"}   , CHAT_MSG_RAID)
  GUI:CreateNewline()
  GUI:CreateToggle({"Proxy", "Channels", "GUILD"}  , CHAT_MSG_GUILD)
  GUI:CreateToggle({"Proxy", "Channels", "OFFICER"}, CHAT_MSG_OFFICER)
  GUI:CreateNewline()
  GUI:CreateToggle({"Proxy", "Channels", "server"} , L["Server Channels"], L["This refers to custom channels which are owned by Blizzard. Some examples are the General and Trade channels."])
  GUI:CreateToggle({"Proxy", "Channels", "custom"} , L["Custom Channels"], L["This referes to player-created custom channels, like World chat."])
  
  GUI:CreateNewline()
  GUI:CreateInput({"Proxy", "restrictedChannels"}, L["Restricted Custom Channels"], L["You will not post messages in any custom channel listed here. List one channel per line."], true)
  GUI:CreateDivider()
  GUI:CreateInput({"Proxy", "prefix"}, L["Prefix"], L["This text will appear at the start of messages you say while serving as a proxy. %s will be replaced with the Talksie's name."])
  
  return Options
end


function Data:MakeTalksieOptionsTable(title, Addon, L)
  local Options = {
    name = title,
    type = "group",
    args = {}
  }
  local GUI = GetOptionTableHelpers(Options, Addon)
  
  
  GUI:CreateToggle({"Talksie", "suppressChat"}, L["Suppress Chat"], L["Enabling this option will prevent chat messages from being sent on most channels while you are a Talksie."])
  
  return Options
end


function Data:MakeDebugOptionsTable(title, Addon, L)
  local Options = {
    name = title,
    type = "group",
    args = {}
  }
  local GUI = GetOptionTableHelpers(Options, Addon)
  
  return Options
end



function Data:Init(Addon, L)
  StaticPopupDialogs[("%s_CONFIRM_PAIR_REQUEST"):format(ADDON_NAME:upper())] =
  {
    text         = L["%s is requesting to proxy chat through you. Would you like to allow this?\n(Configure Proxy settings with: /%s config)"],
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


