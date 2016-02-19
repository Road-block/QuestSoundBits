-- SETTINGS --
-- Change the '= true' part to '= false' to disable sounds for the specific event: 
-- Quest Completion, Objective Completion, Objective Progress
local SETTINGS = {
  ["Complete"] = true,
  ["Objective"] = true,
  ["Progress"] = true
}
-- SETTINGS END --
-- DO NOT EDIT ANYTHING BELOW THIS LINE --

local _G = getfenv(0)
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
local completedCache = {}
local lastAlertTime, lastAlert, p_faction
local Speak = function(alertType)
  local now = GetTime()
  p_faction = p_faction or (UnitFactionGroup("player"))
  local interval = (lastAlertTime == nil) and 10 or (now - lastAlertTime)
  if ( interval >= 1 ) 
  or ( lastAlert == nil )
  or ( (lastAlert ~= nil) and (prio[alertType] > prio[lastAlert]) ) then
    PlaySoundFile(soundBits[p_faction][alertType])
    lastAlert, lastAlertTime = alertType, now
  end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent",function() 
    if events[event]~=nil then return events[event](this,event,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9,arg10,arg11) end
  end)
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events.PLAYER_ALIVE = function(self,event)
  p_faction = (UnitFactionGroup("player"))
  self:RegisterEvent("UI_INFO_MESSAGE")
  self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
end
events.PLAYER_ENTERING_WORLD = events.PLAYER_ALIVE
events.UI_INFO_MESSAGE = function(self,event,message)
  -- completion doesn't fire a UI_INFO_MESSAGE in 1.12.1 but keep it because "who knows" maybe down the road
  if SETTINGS["Complete"] and string.find(message,qComplete) then 
    Speak("Complete")
    return
  else
    for _,objPattern in ipairs(tObjective) do
      if SETTINGS["Objective"] and string.find(message,objPattern) then
        Speak("Objective")
        return
      end
    end
    for _,pgPattern in ipairs(tProgress) do
      local s,e,objective,have,need = string.find(message,pgPattern)
      if s then
        have,need = tonumber(have),tonumber(need)
        if have == need then
          if SETTINGS["Objective"] then Speak("Objective") end
          return
        elseif have < need then
          if SETTINGS["Progress"] then Speak("Progress") end
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
  self:UnregisterEvent("QUEST_LOG_UPDATE")
  local numQuests = GetNumQuestLogEntries()
  local questLogTitleText, questLevel, questTag, isHeader, isCollapsed, isComplete 
  if numQuests > 0 then
    for i=1,numQuests,1 do 
      questLogTitleText, questLevel, questTag, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
      completedCache[questLogTitleText] = completedCache[questLogTitleText] or {}
      completedCache[questLogTitleText]["stored"] = true
      if (isComplete and isComplete > 0) and not isHeader then
        if completedCache[questLogTitleText]["completed"] == nil then
          completedCache[questLogTitleText]["completed"] = true
          Speak("Complete")
          return
        end
      end
    end
  end
end