--Copyright
--[[
*******************************************************************************
Fizzle_Fuze's Surviving Mars Mods
Copyright (c) 2022 Fizzle Fuze Enterprises (mods@fizzlefuze.com)
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.
    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
  If your software can interact with users remotely through a computer
network, you should also make sure that it provides a way for users to
get its source.  For example, if your program is a web application, its
interface could display a "Source" link that leads users to an archive
of the code.  There are many ways you could offer source, and different
solutions will be better for different programs; see section 13 for the
specific requirements.
  You should also get your employer (if you work as a programmer) or school,
if any, to sign a "copyright disclaimer" for the program, if necessary.
For more information on this, and how to apply and follow the GNU AGPL, see
<https://www.gnu.org/licenses/>.
*******************************************************************************
--]]

local DEBUG = false
local AutoBalance = false
local OffloadToMechs = false
local LowLoadOnly = false
local ShowWarnings = false
local DepotCount = 0
local MechCount = {}
local Extra = {}
local MaxStorage = {}
local UpdatedDepots = {}
local ModName = CurrentModDef.title
local DelayMax = 2
local Delay = DelayMax

for _, Resource in ipairs(AllResourcesList) do
  table.insert_unique(Extra, Resource)
  table.insert_unique(MaxStorage, Resource)
  table.insert_unique(MechCount, Resource)
end

local function LogMsg(msg, t, sev, flushlogs) -- t as type

  t = t or "ERR"
  sev = sev or "STD"
  msg = tostring(msg)

  --only flush errors and warnings by default
  if not flushlogs then
    if sev == "ERR" or sev == "WARN" then
      flushlogs = flushlogs or true
    end
  end

  if not msg then 
    print(ModName, "CRIT ERR: Could not log error message!")
  end

  if (DEBUG and t == "DBG") or not t == "DBG" then
    print(ModName, sev, t, ": ", msg)
  end

  if flushlogs then
    FlushLogFile()
  end
end

local function Warn(id, p1)

  if not ShowWarnings then return end

  local title
  local text
  local icon
  local params

  if id == "NotEnoughResources" then

    params = {
      priority = "Important",
      expiration = 100000
    }

    id = "NotEnoughResources"
    title = T(tostring(p1).. " shortage!") 
    text = "Not enough "..tostring(p1).." to add to depot.\nTry removing extra depots."
    icon = CurrentModPath.."warning.png"

  end

  AddCustomOnScreenNotification(id, title, text, icon, function () return end, params)

end

local function UpdateOptions()
  AutoBalance = CurrentModOptions:GetProperty("AutoBalance")
  OffloadToMechs = CurrentModOptions:GetProperty("OffloadToMechs")
  LowLoadOnly = CurrentModOptions:GetProperty("LowLoadOnly")
  ShowWarnings = CurrentModOptions:GetProperty("ShowWarnings")
  DelayMax = CurrentModOptions:GetProperty("Delay")
  Delay = DelayMax
  BalanceDepots()
end

function OnMsg.ApplyModOptions(id)
  if id == CurrentModId then
    UpdateOptions()
  end
end


local function BalanceDepots()

  DepotCount = 0
  UpdatedDepots = {}

  local function CountExtraResources(Depot, ParentHub)

    if not (Depot.class == "UniversalStorageDepot" or Depot.class == "MechanizedDepot") then
      LogMsg("Invalid depot type: "..Depot.class, "DBG", "STD", false)
      return
    end

    LogMsg("Examining depot: "..Depot.handle, "DBG", "STD", false)

    if ParentHub.working and Depot.class == "UniversalStorageDepot" or (Depot.class == "MechanizedDepot" and Depot.working) then
      for _, Resource in ipairs(AllResourcesList) do
        if Depot:HasMember("GetStored_"..Resource) then

          MaxStorage[Resource] = MaxStorage[Resource] + Depot["GetMaxAmount_"..Resource](Depot)                     

          if Depot.class == "MechanizedDepot" and Depot.working and OffloadToMechs then
            MechCount[Resource] = MechCount[Resource] + 1
            LogMsg("SMC: "..MechCount[Resource], "DBG", "STD", false)
          end

          if (Depot["GetStored_"..Resource](Depot) - Depot.desired_amount) > 0 then

            if (Depot.class == "MechanizedDepot" and OffloadToMechs and Depot.working and Depot:HasMember("GetMaxAmount_"..Resource)) or Depot.class == "UniversalStorageDepot" then
              Extra[Resource] = Extra[Resource] + (Depot["GetStored_"..Resource](Depot) - Depot.desired_amount)
            end 

          end
        end
      end
    end
  end



  local function UpdateDepots(Depot, _)

    local DepotType = Depot.class

    if not (DepotType == "UniversalStorageDepot" or DepotType == "MechanizedDepot") then
      LogMsg("Invalid depot type: "..Depot.class, "DBG", "STD", false) -- because we don't want rockets and such
      return
    end

    local Updated = false
    local Ratio = 1

    for _, Resource in ipairs(AllResourcesList) do
      if Depot:HasMember("GetMaxAmount_"..Resource) then

        local DepotMax = Depot["GetMaxAmount_"..Resource](Depot)
        local Target = 0
        LogMsg("USD, OTM, AB, MC = "..DepotType..", "..tostring(OffloadToMechs)..", "..tostring(AutoBalance)..", "..MechCount[Resource], "DBG", "STD", false)

        if DepotType == "UniversalStorageDepot" and (AutoBalance == false or MechCount[Resource] > 0) then
          Target = Depot.desired_amount
        else
          if MechCount[Resource] == 0 then
            Ratio = (DepotMax + 0.0) / MaxStorage[Resource]
          end

          Target = (Extra[Resource] * Ratio) + Depot.desired_amount
          Target = Clamp(Target, 0, DepotMax)

          if Target < 1000 and Extra[Resource] > 1000 then 
            LogMsg("Less than 1 "..Resource.." available for depot. Try removing some extra depots.", "WARN")
            Warn("NotEnoughResources", Resource)
          end
        end

        local Demand = DepotMax - Target
        LogMsg("DEBUG: DH, Demand, Supply, Ratio: "..Depot.handle..", "..Demand..", "..Target..", "..Ratio, "DBG", "STD", false)

        if DepotType == "UniversalStorageDepot" then
          for _ = 1, #UpdatedDepots do

            local ComCenterCount = 0

            for i2 = 1, #Depot.command_centers do
              if Depot.command_centers[i2].entity == "DroneHub" then
                ComCenterCount = ComCenterCount + 1
              end
            end

            if ComCenterCount > 1 and (Depot.demand[Resource]:GetDesiredAmount() <= Demand) then 
              LogMsg("Not overriding lower demand from another sector!", "DBG", "STD", false)
              return
            end
            
          end
        end

        if DepotType == "UniversalStorageDepot" then 
          
          local Request = Depot.demand[Resource]
          if not (Request:GetDesiredAmount() == Demand) then
            Updated = true
            Request:SetDesiredAmount(Demand)
            if Depot.supply[Resource] then
              Depot.supply[Resource]:SetDesiredAmount(Target)
            end
          end
          
        elseif DepotType == "MechanizedDepot" then
          
          if OffloadToMechs then
            if not (Depot.stockpiles[1].supply[Resource]:GetDesiredAmount() == Target) then
              table.insert_unique(UpdatedDepots, Depot.handle)
              LogMsg("UDI, Target, Demand: "..Depot.handle..", "..Target..", "..Demand, "DBG", "STD", false)

              local Stockpile = Depot.stockpiles[1]
              local StockpileMax = Stockpile.supply_request:GetActualAmount() + Stockpile.demand_request:GetActualAmount()
              local StockpileDesire = Target + Stockpile.supply_request:GetTargetAmount() - Depot:GetStoredAmount()
              StockpileDesire = Clamp(StockpileDesire, 0, StockpileMax)
              local RequestDesire = StockpileMax - StockpileDesirea
              Stockpile.supply_request:SetDesiredAmount(StockpileDesire)
              Stockpile.demand_request:SetDesiredAmount(RequestDesire)
            end
          end
          
        else
          LogMsg("Unknown depot type: ".. DepotType)
        end
      end
    end
    
    if Updated then
      table.insert_unique(UpdatedDepots, Depot.handle)
      Updated = false
      LogMsg("UDI: "..Depot.handle, "DBG", "STD", false)
    end
    
  end

  local function BalanceDepotsInHub(DroneHub)

    if DroneHub.lap_time > const.DroneLoadLowThreshold and LowLoadOnly then
      return
    end

    for _, Resource in ipairs(AllResourcesList) do
      MaxStorage[Resource] = 0
      Extra[Resource] = 0
    end

    MapForEach(DroneHub, "hex", DroneHub.work_radius, "UniversalStorageDepot", CountExtraResources, DroneHub)
    MapForEach(DroneHub, "hex", DroneHub.work_radius, "MechanizedDepot", CountExtraResources, DroneHub)

    MapForEach(DroneHub, "hex", DroneHub.work_radius, "UniversalStorageDepot", UpdateDepots, DroneHub)
    MapForEach(DroneHub, "hex", DroneHub.work_radius, "MechanizedDepot", UpdateDepots, DroneHub)

  end

  if UICity then   

    for _, Resource in ipairs(AllResourcesList) do
      MechCount[Resource] = 0   
    end

    MapForEach("map", "DroneHub", BalanceDepotsInHub)
  end

end

function OnMsg.NewHour()

  if Delay > 0 then
    Delay = Delay - 1
  elseif AutoBalance or OffloadToMechs then
    Delay = DelayMax
    BalanceDepots()
  end

end

OnMsg.ModsReloaded = UpdateOptions