-- SETTINGS --
-- Change the '= true' part to '= false' to disable sounds for the specific event: 
-- Quest Completion, Objective Completion, Objective Progress
local SETTINGS = {
  ["Complete"] = true,
  ["Objective"] = true,
  ["Progress"] = true,
}
-- SETTINGS END --
-- DO NOT EDIT ANYTHING BELOW THIS LINE --


-- Deformat the global announce patterns to turn them into captures, anchor start / end
local tProgress = {}
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_ADD_FOUND_SII,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_ADD_ITEM_SII,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_ADD_KILL_SII,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
local tObjective = {}
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_OBJECTIVE_COMPLETE_S,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
table.insert(tProgress,"^"..string.gsub(string.gsub(ERR_QUEST_UNKNOWN_COMPLETE,"%%%d?%$?s", "(.+)"),"%%%d?%$?d","(%%d+)").."$")
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

local lastAlertTime, lastAlert, p_faction = nil, "_", nil
local Speak = function(alertType)
  local now = GetTime()
  p_faction = p_faction or (UnitFactionGroup("player"))
  lastAlertTime = lastAlertTime or (now - 1.5)
  if (alertType ~= lastAlert) or ((now - lastAlertTime) >= 1) then
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
end
events.PLAYER_ENTERING_WORLD = events.PLAYER_ALIVE
events.UI_INFO_MESSAGE = function(self,event,message)
  if SETTINGS["Complete"] and string.find(message,qComplete) then
    Speak("Complete")
  else
    for _,objPattern in ipairs(tObjective) do
      if SETTINGS["Objective"] and string.find(message,objPattern) then
        Speak("Objective")
        break
      end
    end
    for _,pgPattern in ipairs(tProgress) do
      local s,e,objective,have,need = string.find(message,pgPattern)
      if s then
        have,need = tonumber(have),tonumber(need)
        if have == need then
          if SETTINGS["Objective"] then Speak("Objective") end
          break
        elseif have < need then
          if SETTINGS["Progress"] then Speak("Progress") end
          break
        end
      end
    end
  end
end

