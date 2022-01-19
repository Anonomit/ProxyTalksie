

local ADDON_NAME, Data = ...

local Addon = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceHook-3.0", "AceTimer-3.0")
ProxyTalksie = Addon
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

local AceConfig         = LibStub"AceConfig-3.0"
local AceConfigDialog   = LibStub"AceConfigDialog-3.0"
local AceConfigRegistry = LibStub"AceConfigRegistry-3.0"
local AceDB             = LibStub"AceDB-3.0"
local AceDBOptions      = LibStub"AceDBOptions-3.0"
local AceSerializer     = LibStub"AceSerializer-3.0"

local SemVer            = LibStub"SemVer"



local ENABLED = true


function Addon:Toggle()
  ENABLED = not ENABLED
end



function Addon:GetDB()
  return self.db
end
function Addon:GetDefaultDB()
  return self.dbDefault
end
function Addon:GetProfile()
  return self:GetDB().profile
end
function Addon:GetDefaultProfile()
  return self:GetDefaultDB().profile
end
local function GetOption(self, db, ...)
  local val = db
  for _, key in ipairs{...} do
    val = val[key]
  end
  return val
end
function Addon:GetOption(...)
  return GetOption(self, self:GetProfile(), ...)
end
function Addon:GetDefaultOption(...)
  return GetOption(self, self:GetDefaultProfile(), ...)
end
local function SetOption(self, db, val, ...)
  local keys = {...}
  local lastKey = table.remove(keys, #keys)
  local tbl = db
  for _, key in ipairs(keys) do
    tbl = tbl[key]
  end
  tbl[lastKey] = val
end
function Addon:SetOption(val, ...)
  return SetOption(self, self:GetProfile(), val, ...)
end
function Addon:ResetOption(...)
  return self:SetOption(val, self:GetDefaultOptions(...))
end


function Addon:FixName(name)
  name = name:sub(1, 1):upper() .. name:sub(2, #name):lower()
  name = name:match"[^%-]*"
  return name
end

function Addon:IsInSameGuild(player)
  if IsInGuild() then
    GuildRoster()
    for i = 1, GetNumGuildMembers() do
      local name = GetGuildRosterInfo(i)
      if not name then break end
      if self:FixName(name) == player then
        return true
      end
    end
  end
  return false
end


function Addon:PrintUsage()
  self:Printf(L["Usage:"])
  self:Printf("  /%s config", Data.CHAT_COMMAND)
  self:Printf("    %s", L["Open options"])
  self:Printf("  /%s pair %s", Data.CHAT_COMMAND, L["PlayerName"])
  self:Printf("    %s", L["Send a request to pair with a Proxy"])
  self:Printf("  /%s unpair [%s]", Data.CHAT_COMMAND, L["PlayerName"])
  self:Printf("    %s %s", L["Unpair"], L["PlayerName"])
  self:Printf("  /%s list", Data.CHAT_COMMAND)
  self:Printf("    %s", L["List active links"])
end

function Addon:ListLinks()
  local proxies = 0
  local talksies = 0
  for name in pairs(self.Proxies) do
    proxies = proxies + 1
  end
  for name in pairs(self.Proxies) do
    talksies = talksies + 1
  end
  if proxies == 0 and talksies == 0 then
    self:Printf(L["You have no active links."])
  else
    self:Printf(L["Proxies:"] .. (proxies == 0 and " 0" or ""))
    for name in pairs(self.Proxies) do
      self:Printf("  %s", name)
    end
    self:Printf(L["Talksies:"] .. (talksies == 0 and " 0" or ""))
    for name in pairs(self.Proxies) do
      self:Printf("  %s", name)
    end
  end
end

function Addon:ParseChatCommand(input)
  local command, target = self:GetArgs(input, 2)
  command = command and command:lower() or nil
  if command == "pair" then
    if not target then
      return false
    end
    target = self:FixName(target)
    if self.Proxies[target] then
      self:Printf(L["%s is already an active Proxy."], target)
    else
      self:Printf(L["Sending pair request to %s"], target)
      self.TentativeProxies[target] = self:ScheduleTimer(function() self:Printf(L["Pair attempt with %s has timed out"], target) end, Data.PAIR_REQUEST_TIMEOUT)
      self:SendProxyRequest(target)
    end
    return true
  elseif command == "unpair" then
    self:Unpair(target)
    return true
  elseif command == "config" or command == "options" then
    self:OpenConfig(ADDON_NAME, true)
    return true
  elseif command == "list" or command == "links" then
    self:ListLinks()
    return true
  end
  return false
end

function Addon:OnChatCommand(input)
  if not self:ParseChatCommand(input) then
    self:PrintUsage()
  end
end

function Addon:Unpair(target)
  local proxyTargets   = {}
  local talksieTargets = {}
  if target then
    proxyTargets[self:FixName(target)]   = true
    talksieTargets[self:FixName(target)] = true
  else
    for name, time in pairs(self.Proxies) do
      proxyTargets[name] = true
    end
    for name, time in pairs(self.Talksies) do
      talksieTargets[name] = true
    end
  end
  for target in pairs(proxyTargets) do
    if self.Proxies[target] then
      self:Printf(L["Unpaired with %s. Proxy: %s. Talksie: %s."], target, target, self.me)
    end
    self.Proxies[target] = nil
    self:SendUnpairProxy(target)
  end
  for target in pairs(talksieTargets) do
    if self.Talksies[target] then
      self:Printf(L["Unpaired with %s. Proxy: %s. Talksie: %s."], target, self.me, target)
    end
    self.Talksies[target] = nil
    self:SendUnpairTalksie(target)
  end
end

function Addon:SendProxyRequest(target)
  self:SendAddonMessage("PAIR_REQUEST", {proxy = target, talksie = self.me}, target)
end

function Addon:SendProxyConfirmation(target)
  self:SendAddonMessage("PAIR_ESTABLISH", {proxy = self.me, talksie = target}, target)
end


function Addon:SendTalksieConfirmation(target)
  self:SendAddonMessage("PAIR_ESTABLISH", {proxy = target, talksie = self.me}, target)
end

function Addon:SendUnpairProxy(target)
  self:SendAddonMessage("UNPAIR", {proxy = target, talksie = self.me}, target)
end

function Addon:SendUnpairTalksie(target)
  self:SendAddonMessage("UNPAIR", {proxy = self.me, talksie = target}, target)
end


function Addon:SendAddonMessage(op, msg, target)
  local data = AceSerializer:Serialize(Data.OP_CODES[op], tostring(self.Version), msg)
  self:SendCommMessage(Data.ADDON_PREFIX, data, "WHISPER", target)
end


function Addon:HandleComm_PairEstablished(sender, proxy, talksie)
  if self:TimeLeft(self.TentativeProxies[sender]) > 0 then
    if proxy == sender and talksie == self.me then
      self:Printf(L["Link established. Paired to %s. Proxy: %s. Talksie: %s."], sender, sender, self.me)
      self.Proxies[sender] = GetTime()
      self:CancelTimer(self.TentativeProxies[sender])
      self:SendTalksieConfirmation(sender, Data.PAIR_ESTABLISH_TIMEOUT)
    end
  end
  if self:TimeLeft(self.TentativeTalksies[sender]) > 0 then
    if proxy == self.me and talksie == sender then
      self:Printf(L["Link established. Paired to %s. Proxy: %s. Talksie: %s."], sender, self.me, sender)
      self.Talksies[sender] = GetTime()
      self:CancelTimer(self.TentativeTalksies[sender])
    end
  end
end

function Addon:HandleComm_Unpair(target)
  if self.Proxies[target] then
    if proxy == target and talksie == self.me then
      self:UnpairProxy(target)
    end
  end
  if self.Talksies[target] then
    if proxy == self.me and talksie == target then
      self:UnpairTalksie(target)
    end
  end
end

function Addon:HandleComm_Relay(sender, msg, channel, target)
  if target then
    target = target:lower()
  end
  
  if self.Talksies[sender] then
    local validChannel = false
    local hardwareRequired = false
    if channel == "PARTY" and self:GetOption("Proxy", "Channels", "PARTY") and UnitInParty(sender) then
      validChannel = true
    elseif channel == "RAID" and self:GetOption("Proxy", "Channels", "RAID") and UnitInRaid(sender) then
      validChannel = true
    elseif channel == "GUILD" and self:GetOption("Proxy", "Channels", "GUILD") then
      if self:IsInSameGuild(sender) then
        validChannel = true
      end
    elseif channel == "OFFICER" and self:GetOption("Proxy", "Channels", "OFFICER") then
      if self:IsInSameGuild(sender) then
        validChannel = true
      end
    elseif IsInInstance() then
      if channel == "SAY" and self:GetOption("Proxy", "Channels", "SAY") then
        validChannel = true
      elseif channel == "YELL" and self:GetOption("Proxy", "Channels", "YELL") then
        validChannel = true
      end
    end
    if not validChannel then
      hardwareRequired = true
      if channel == "SAY" and self:GetOption("Proxy", "Channels", "SAY") then
        validChannel = true
      elseif channel == "YELL" and self:GetOption("Proxy", "Channels", "YELL") then
        validChannel = true
      elseif channel == "CHANNEL" then
        local isRestricted = false
        for restrictedChannel in (self:GetOption("Proxy", "restrictedChannels") .. "\n"):gmatch"([^\n]+)" do
          if target == restrictedChannel:lower() then
            isRestricted = true
          end
        end
        if not isRestricted then
          local custom = true
          for _, channel in ipairs{EnumerateServerChannels()} do
            if target == channel:lower() then
              custom = false
              break
            end
          end
          if custom and self:GetOption("Proxy", "ChannelCategories", "custom") or not custom and self:GetOption("Proxy", "ChannelCategories", "server") then
            local channels = {GetChannelList()}
            for i = 1, #channels, 3 do
              local id, name, disabled = channels[i], channels[i+1], channels[i+2]
              if target == name:lower() then
                if not disabled then
                  validChannel = id
                end
                break
              end
            end
          end
        end
      end
    end
    
    local func = function() self.hooks.SendChatMessage(("%s%s"):format(self:GetOption("Proxy", "prefix"):format(sender), msg), channel, nil, validChannel) end
    
    if validChannel then
      if hardwareRequired then
        table.insert(self.ChannelQueue, func)
        StaticPopup_Show(("%s_CHANNEL_CHAT_PROMPT"):format(ADDON_NAME:upper()))
      else
        func()
      end
    end
  end
end


function Addon:OnCommReceived(pre, data, channel, sender)
  if not self:GetOption("Debug", "enabled") then return end
  if pre ~= Data.ADDON_PREFIX then return end
  if channel ~= "WHISPER" then return end
  local success, op, version, msg = AceSerializer:Deserialize(data)
  if not success then return end
  
  sender = self:FixName(sender)
  local Version = SemVer(version)
  if not (Version ^ self.Version) then
    if Version < self.Version then
      if op ~= Data.OP_CODES["VERSION"] then
        self:SendAddonMessage("VERSION", nil, sender)
      end
    elseif Version > self.Version then
      self:Printf(L["Incompatible version detected. Please update to version %s or newer to use %s with %s"], tostring(Version), ADDON_NAME, sender)
    end
    return
  end
  
  if op == Data.OP_CODES["PAIR_REQUEST"] then
    StaticPopup_Show(("%s_CONFIRM_PAIR_REQUEST"):format(ADDON_NAME:upper()), sender, Data.CHAT_COMMAND, sender)
  elseif op == Data.OP_CODES["PAIR_ESTABLISH"] then
    self:HandleComm_PairEstablished(sender, msg.proxy, msg.talksie)
  elseif op == Data.OP_CODES["UNPAIR"] then
    self:HandleComm_Unpair(sender)
  elseif op == Data.OP_CODES["RELAY"] then
    self:HandleComm_Relay(sender, msg.msg, msg.channel, msg.target)
  elseif op == Data.OP_CODES["HEARTBEAT"] then
    if self.Proxies[sender] then
      self.Proxies[sender] = GetTime()
    end
    if self.Talksies[sender] then
      self.Talksies[sender] = GetTime()
    end
  end
end


function Addon:UnpairProxy(target)
  self.Proxies[target] = nil
  self:Printf(L["Unpaired with %s. Proxy: %s. Talksie: %s."], target, target, self.me)
end
function Addon:UnpairTalksie(target)
  self.Talksies[target] = nil
  self:Printf(L["Unpaired with %s. Proxy: %s. Talksie: %s."], target, self.me, target)
end

function Addon:UnpairAll()
  for target in pairs(self.Proxies) do
    self:UnpairProxy(target)
  end
  for target in pairs(self.Talksies) do
    self:UnpairTalksie(target)
  end
end


function Addon:Relay(proxy, msg, channel, target)
  self:SendAddonMessage("RELAY", {msg = msg, channel = channel, target = target}, proxy)
end

function Addon:OnSendChatMessage(...)
  if not self:GetOption("Debug", "enabled") then return end
  local msg, channel, language, customChannel = ...
  if customChannel and type(customChannel) == "number" then
    local channels = {GetChannelList()}
    for i = 1, #channels, 3 do
      local id, name, disabled = channels[i], channels[i+1], channels[i+2]
      if customChannel == id then
        if not disabled then
          customChannel = name
        end
        break
      end
    end
  end
  local proxies = 0
  for proxy in pairs(self.Proxies) do
    self:Relay(proxy, msg, channel, customChannel)
    proxies = proxies + 1
  end
  if not Data.UNSUPPRESSED_CHANNELS[channel] then
    if proxies > 1 then
      self:Printf(L["Message relayed to Proxies."])
    elseif proxies > 0 then
      self:Printf(L["Message relayed to Proxy."])
    end
  end
  if proxies <= 0 or Data.UNSUPPRESSED_CHANNELS[channel] or not self:GetOption("Talksie", "suppressChat") then
    self.hooks.SendChatMessage(...)
  end
end

function Addon:OnHeartbeat()
  if not self:GetOption("Debug", "enabled") then return end
  for target, time in pairs(self.Proxies) do
    self:SendAddonMessage("HEARTBEAT", nil, target)
    if GetTime() - time > Data.HEARTBEAT_TIMEOUT then
      self:UnpairProxy(target)
    end
  end
  for target, time in pairs(self.Talksies) do
    self:SendAddonMessage("HEARTBEAT", nil, target)
    if GetTime() - time > Data.HEARTBEAT_TIMEOUT then
      self:UnpairTalksie(target)
    end
  end
end




function Addon:CreateHooks()
  self:RegisterComm(Data.ADDON_PREFIX, "OnCommReceived")
  
  self:ScheduleRepeatingTimer(function() self:OnHeartbeat() end, Data.HEARTBEAT_PERIOD)
  
  self:RawHook(nil, "SendChatMessage", "OnSendChatMessage", true)
end



function Addon:OpenConfig(category, expandSection)
  InterfaceAddOnsList_Update()
  InterfaceOptionsFrame_OpenToCategory(category)
  
  if expandSection then
    -- Expand config if it's collapsed
    local i = 1
    while _G["InterfaceOptionsFrameAddOnsButton"..i] do
      local frame = _G["InterfaceOptionsFrameAddOnsButton"..i]
      if frame.element then
        if frame.element.name == ADDON_NAME then
          if frame.element.hasChildren and frame.element.collapsed then
            if _G["InterfaceOptionsFrameAddOnsButton"..i.."Toggle"] and _G["InterfaceOptionsFrameAddOnsButton"..i.."Toggle"].Click then
              _G["InterfaceOptionsFrameAddOnsButton"..i.."Toggle"]:Click()
              break
            end
          end
          break
        end
      end
      
      i = i + 1
    end
  end
end
function Addon:MakeDefaultFunc(category)
  return function()
    self:GetDB():ResetProfile()
    self:InitDB()
    self:Printf(L["Profile reset to default."])
    AceConfigRegistry:NotifyChange(category)
  end
end
function Addon:CreateOptionsCategory(categoryName, options)
  local category = ADDON_NAME
  if categoryName then
    category = ("%s.%s"):format(category, categoryName)
  end
  AceConfig:RegisterOptionsTable(category, options)
  local Panel = AceConfigDialog:AddToBlizOptions(category, categoryName, categoryName and ADDON_NAME or nil)
  Panel.default = self:MakeDefaultFunc(category)
  return Panel
end

function Addon:CreateOptions()
  self:CreateOptionsCategory(nil, Data:MakeOptionsTable(ADDON_NAME, self, L))
  
  self:CreateOptionsCategory("Proxy"   , Data:MakeProxyOptionsTable(L["Proxy Configuration"], self, L))
  self:CreateOptionsCategory("Talksie" , Data:MakeTalksieOptionsTable(L["Talksie Configuration"], self, L))
  self:CreateOptionsCategory("Profiles", AceDBOptions:GetOptionsTable(self.db))
  
  if self:GetOption("Debug", "menu") then
    self:CreateOptionsCategory("Debug" , Data:MakeDebugOptionsTable("Debug", self, L))
  end
end


function Addon:InitDB()
  local configVersion = SemVer(self:GetOption"version" or tostring(self.Version))
  -- Update data schema here
  
  self:SetOption(tostring(self.Version), "version")
end


function Addon:OnInitialize()
  self.db        = AceDB:New(("%sDB"):format(ADDON_NAME)        , Data:MakeDefaultOptions(), true)
  self.dbdefault = AceDB:New(("%sDB_Default"):format(ADDON_NAME), Data:MakeDefaultOptions(), true)
  
  self:RegisterChatCommand(Data.CHAT_COMMAND, "OnChatCommand", true)
end

function Addon:OnEnable()
  self.Version = SemVer(GetAddOnMetadata(ADDON_NAME, "Version"))
  self:InitDB()
  self:GetDB().RegisterCallback(self, "OnProfileChanged", "InitDB")
  self:GetDB().RegisterCallback(self, "OnProfileCopied" , "InitDB")
  self:GetDB().RegisterCallback(self, "OnProfileReset"  , "InitDB")
  
  
  self.me = UnitName"player"
  
  self.TentativeProxies  = {}
  self.TentativeTalksies = {}
  self.Proxies           = {}
  self.Talksies          = {}
  self.ChannelQueue      = {}
  
  
  Data:Init(self, L)
  
  self:CreateOptions()
  self:CreateHooks()
end

function Addon:OnDisable()
end
