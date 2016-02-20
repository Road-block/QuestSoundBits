local _G = getfenv(0)
QuestSoundBitsDB = QuestSoundBitsDB or {}
local defaults = {
  ["Complete"] = true,
  ["Objective"] = true,
  ["Progress"] = false
}
local soundBits = {
  ["Alliance"] = {
    ["Progress"] = "Sound\\Creature\\Peasant\\PeasantWhat3.wav", -- more work?
    ["Objective"] = "Sound\\Creature\\Peasant\\PeasantReady1.wav", -- ready to work
    ["Complete"] = "Interface\\AddOns\\QuestSoundBits\\Peasant_job_done.mp3", -- job's done
  },
  ["Horde"] = {
  --["Progress"] = "Sound\\Creature\\Peon\\PeonWhat4.wav", -- something need doing?
    ["Progress"] = "Sound\\Creature\\Peon\\PeonYes3.wav", -- work work
    ["Objective"] = "Sound\\Creature\\Peon\\PeonReady1.wav", -- ready to work
    ["Complete"] = "Sound\\Creature\\Peon\\PeonBuildingComplete1.wav", -- work complete
  }
}
local prio = {
  ["Complete"] = 3,
  ["Objective"] = 2,
  ["Progress"] = 1
}
local verbose = {
  ["Complete"] = "Quest Completion: ",
  ["Objective"] = "Objective Completion: ",
  ["Progress"] = "Objective Progress: "
}
-- Deformat the global announce patterns to turn them into captures, anchor start / end
local tProgress = {}
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_ADD_FOUND_SII,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_ADD_ITEM_SII,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_ADD_KILL_SII,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
local tObjective = {}
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_OBJECTIVE_COMPLETE_S,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_UNKNOWN_COMPLETE,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
-- useless for our purpose at this point, only CHAT_MSG_SYSTEM at quest turn-in uses this pattern
local qComplete = "^"..string.gsub(string.gsub(ERR_QUEST_COMPLETE_S,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$"

local CopyTable
local completedCache, queueMessage, p_faction = {}, nil, nil
local Speak = function(self,elapsed)
  self.sinceLast = self.sinceLast + elapsed
  if self.sinceLast > self.interval then
    p_faction = p_faction or (UnitFactionGroup("player"))
    self.sinceLast = 0
    if queueMessage and prio[queueMessage] then
      PlaySoundFile(soundBits[p_faction][queueMessage])
      queueMessage = nil
    end
    self:Hide()
  end
end
CopyTable = function(t,copied)
  copied = copied or {}
  local copy = {}
  copied[t] = copy
  for k,v in pairs(t) do
    if type(v) == "table" then
      if copied[v] then
        copy[k] = copied[v]
      else
        copy[k] = CopyTable(v,copied)
      end
    else
      copy[k] = v
    end
  end
  return copy
end
local Print = function(msg)
  if not DEFAULT_CHAT_FRAME:IsVisible() then
    FCF_SelectDockFrame(DEFAULT_CHAT_FRAME)
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffE59400QuestSoundBits: |r"..msg)
end
local help = function()
  Print("/qsb complete")
  Print("    toggles Quest Completion sound")
  Print("/qsb objective")
  Print("    toggles Objective Completion sound")
  Print("/qsb progress")
  Print("    toggles Objective Progress sound")
  Print("/qsb status")
  Print("    print current settings")
end
local timer = CreateFrame("Frame")
timer:Hide()
timer.sinceLast, timer.interval = 0, 1
timer:SetScript("OnUpdate", function()
  Speak(this,arg1)
  end)
local Listen = function(alertType)
  if not timer:IsVisible() then
    timer:Show()
  end
  if queueMessage == nil or (prio[queueMessage] < prio[alertType]) then
    queueMessage = alertType
  end
end
local events = CreateFrame("Frame")
events:SetScript("OnEvent",function() 
    if events[event]~=nil then return events[event](this,event,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) end
  end)
events:RegisterEvent("VARIABLES_LOADED")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events.PLAYER_ALIVE = function(self,event)
  p_faction = (UnitFactionGroup("player"))
  self:RegisterEvent("UI_INFO_MESSAGE")
  self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
end
events.PLAYER_ENTERING_WORLD = events.PLAYER_ALIVE
events.UI_INFO_MESSAGE = function(self,event,message)
  if self.variablesLoaded == nil then return end
  -- completion doesn't fire a UI_INFO_MESSAGE in 1.12.1 but keep it because "who knows" maybe down the road
  if self.config["Complete"] and string.find(message,qComplete) then 
    Listen("Complete")
    return
  else
    for _,objPattern in ipairs(tObjective) do
      if self.config["Objective"] and string.find(message,objPattern) then
        Listen("Objective")
        return
      end
    end
    for _,pgPattern in ipairs(tProgress) do
      local s,e,objective,have,need = string.find(message,pgPattern)
      if s then
        have,need = tonumber(have),tonumber(need)
        if have == need then
          if self.config["Objective"] then Listen("Objective") end
          return
        elseif have < need then
          if self.config["Progress"] then Listen("Progress") end
          return
        end
      end
    end
  end
end
events.UNIT_QUEST_LOG_CHANGED = function(self,event,unitid)
  if unitid and unitid == "player" then
    self:RegisterEvent("QUEST_LOG_UPDATE")
  end
end
events.QUEST_LOG_UPDATE = function(self,event)
  if self.variablesLoaded == nil then return end
  self:UnregisterEvent("QUEST_LOG_UPDATE")
  local numQuests = GetNumQuestLogEntries()
  local questLogTitleText, questLevel, questTag, isHeader, isCollapsed, isComplete 
  if numQuests > 0 then
    for i=1,numQuests,1 do 
      questLogTitleText, questLevel, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
      completedCache[questLogTitleText] = completedCache[questLogTitleText] or {}
      if (isComplete and isComplete > 0) and not isHeader then
        if completedCache[questLogTitleText]["completed"] == nil then
          completedCache[questLogTitleText]["completed"] = true
          if self.config["Complete"] then Listen("Complete") end
          return
        end
      end
    end
  end
end
events.VARIABLES_LOADED = function(self,event)
  if not next(QuestSoundBitsDB) then
    QuestSoundBitsDB = CopyTable(defaults)
  end
  self.config = QuestSoundBitsDB
  self.variablesLoaded = true
end
SlashCmdList["QUESTSOUNDBITS"] = function(msg)
  if msg==nil or msg=="" then
    help()
  else
    local msg_l = strlower(msg)
    local ON, OFF = "|cff008000ON|r", "|cffFF1919OFF|r"
    if msg_l == "complete" then
      QuestSoundBitsDB["Complete"] = not QuestSoundBitsDB["Complete"]
      Print(verbose["Complete"]..(QuestSoundBitsDB["Complete"] and ON or OFF))
    elseif msg_l == "objective" then
      QuestSoundBitsDB["Objective"] = not QuestSoundBitsDB["Objective"]
      Print(verbose["Objective"]..(QuestSoundBitsDB["Objective"] and ON or OFF))
    elseif msg_l == "progress" then
      QuestSoundBitsDB["Progress"] = not QuestSoundBitsDB["Progress"]
      Print(verbose["Progress"]..(QuestSoundBitsDB["Progress"] and ON or OFF))
    elseif msg_l == "status" then
      for k,v in pairs(QuestSoundBitsDB) do
        Print(verbose[k]..(v and ON or OFF))
      end
    else
      help()
    end
  end
end
SLASH_QUESTSOUNDBITS1 = "/questsoundbits"
SLASH_QUESTSOUNDBITS2 = "/questsounds"
SLASH_QUESTSOUNDBITS3 = "/qsb"