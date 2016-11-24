--//Core//--

local addon, ns = ...
-- Make the core functions available to layouts
_G[addon] = ns

local eF = CreateFrame("Frame", "eventFrame", UIParent)
eF:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eF:RegisterEvent("GROUP_ROSTER_UPDATE")
eF:RegisterEvent("PLAYER_ENTERING_WORLD")
eF:RegisterEvent("UNIT_PET")
eF:RegisterEvent("PLAYER_REGEN_DISABLED")
eF:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Create our Databases
ns.DB = {
	players = {},
	pets = {},
	rank = {},
}

ns.moduleDB = {}
ns.moduleDBtotal = {}

function eF:addUnitToDB(unit, owner)
	local guid = UnitGUID(unit)
	if not guid or guid == "" then return end
	local unitType = select(1, strsplit("-", guid))
	local name, realm = UnitName(unit)
	if not name or name == "Unknown" then return end
	
	if unitType == "Player" then
		local realm = realm and realm ~= "" and "-"..realm or ""
		
		-- Create the player key in ns.DB.players
		if not ns.DB.players[name..realm] then
			ns.DB.players[name..realm] = {
				["class"] = select(1, UnitClass(unit)),
				["classcolor"] = RAID_CLASS_COLORS[select(2, UnitClass(unit))],
			}
			-- Insert player names into ns.DB.rank
			ns.DB.rank[#ns.DB.rank+1] = name..realm
		end
	elseif unitType == "Pet" or unitType == "Vehicle" then
		--Create the pet key in ns.DB.pets
		if not ns.DB.pets[name] then
			ns.DB.pets[name] = { 
				["owner"] = owner,
			}
		end
	end
end
 
function eF:UpdateWatchedPlayers()
	-- Delete old table
	if ns.cleanOnGrpChange == true then	
		for k in pairs(ns.DB.players) do
			ns.DB.players[k] = nil
		end
	end
 
	-- Insert player name
	eF:addUnitToDB("player")

	-- Insert playerpet name
	if UnitExists("playerpet") then
		eF:addUnitToDB("playerpet", UnitName("player"))
	end
 
	-- Insert party members & pets
	local isInGroup = IsInGroup("player")
	if isInGroup then
		for i=1, GetNumSubgroupMembers() do
			eF:addUnitToDB("party"..i)
			if UnitExists("partypet"..i) then
				eF:addUnitToDB(("partypet"..i), UnitName("party"..i))
			end
		end
	end

	-- Insert raid members & pets
	local isInRaid = IsInRaid("player")
	if isInRaid then
		for i=1, GetNumGroupMembers() do
			eF:addUnitToDB("raid"..i)
			if UnitExists("raidpet"..i) then
				eF:addUnitToDB(("raidpet"..i), UnitName("raid"..i))
			end
		end
	end
 
	-- Delete Data of "old" players
--	ns.resetData()
end

-- Upate on certain events
eF.GROUP_ROSTER_UPDATE = eF.UpdateWatchedPlayers
eF.UNIT_PET = eF.UpdateWatchedPlayers

-- Create the variable "ns.activeModule" and set it to module priority #1
ns.activeModule = ""
for k, v in pairs(ns.modulepriority) do
	if v == 1 then
		ns.activeModule = k
	end
end

-- Upon entering the woröd, i.e. after Loading Screen, 
-- update the Watched Players and call the update functions for layouts
function eF.PLAYER_ENTERING_WORLD()
	eF:UpdateWatchedPlayers()
	if ns.UpdateLogin then
		ns:UpdateLogin()
	end
	if ns.UpdateLayout then
		ns:UpdateLayout()
	end
end

--Sortfunction; sort the rank table after highes values on top for the viewed/active module
function ns.sortByModule(a, b)
	if ns.moduleDBtotal[ns.activeModule] and ns.moduleDBtotal[ns.activeModule] > 0 then
		return (ns.moduleDB[ns.activeModule][a] or 0) > (ns.moduleDB[ns.activeModule][b] or 0)
	end
end

-- Combat time tracking for * per second calculation
function eF.PLAYER_REGEN_DISABLED()
	ns.startCombatTime = GetTime()
end

function eF.PLAYER_REGEN_ENABLED()
	ns.totalCombatTime = ns.totalCombatTime + GetTime() - ns.startCombatTime
	ns.startCombatTime = nil
end

ns.startCombatTime = 0
--ns.currentCombatTime = 0
ns.totalCombatTime = 0
function eF.COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17)
--	ns.curCombatTime = ns.combatTotalTime
--	ns.combatTime = ns.totalCombatTime + (ns.startCombatTime and (GetTime() - ns.startCombatTime) or 0)
	-- Check if user exist in DB before gathering data
	if not ns.DB.players[arg5] then return end
	for module, vars in pairs(ns.datamodules) do
		-- Check if module is activated
		if vars["activated"] == true then
			-- Type = eg "SPELL_DAMAGE_PERIODIC", args = eg arg12
			for type, args in pairs(vars["strings"]) do
				-- If we find a type defined from modules
				if string.find(arg2, type) then
					-- Return the arguments defined from modules to determine the right value
					local value
					for _, arg in pairs(args) do
						if arg == "arg6" then
							value = arg6
						elseif arg == "arg7" then
							value = arg7
						elseif arg == "arg8" then
							value = arg8
						elseif arg == "arg9" then
							value = arg9
						elseif arg == "arg10" then
							value = arg10
						elseif arg == "arg11" then
							value = arg11
						elseif arg == "arg12" then
							value = arg12
						elseif arg == "arg13" then
							value = arg13
						elseif arg == "arg14" then
							value = arg14
						elseif arg == "arg15" then
							value = arg15
						elseif arg == "arg16" then
							value = arg16
						elseif arg == "arg17" then
							value = arg17
						end
					end

					if value == -1 or nil then
						value = 0
					end
						-- add values to DB
					if not ns.moduleDB[module] then
					ns.moduleDB[module] = {}
					end
					if not ns.moduleDB[module][arg5] then
						ns.moduleDB[module][arg5] = value
					else
						ns.moduleDB[module][arg5] = ns.moduleDB[module][arg5] + (value or 0)
					end

					if not ns.moduleDBtotal[module] then
						ns.moduleDBtotal[module] = value
					else
						ns.moduleDBtotal[module] = ns.moduleDBtotal[module] + (value or 0)
					end

					-- Update the layout
					if ns.UpdateLayout then
						ns:UpdateLayout()
					end
				end
			end
		end
	end
end

-- Resettingfunction (reset all collected data)
function ns.resetData()
	for module, _ in pairs(ns.datamodules) do
		if ns.moduleDB[module] then
			for k, v in pairs(ns.moduleDB[module]) do
				ns.moduleDB[module][k] = nil
			end
		end
	end
	
	for k, v in pairs(ns.moduleDBtotal) do
		ns.moduleDBtotal[k] = nil
	end
	
	-- Clear rank-table
	for k, v in ipairs(ns.DB.rank) do 
		ns.DB.rank[v] = nil
	end
	
	ns.totalCombatTime = 0
	
	-- Also let the layout reset things, if the function axists
	if ns.layoutSpecificReset then
		ns.layoutSpecificReset()
	end
end

eF:SetScript("OnEvent", function(self, event, ...)  
	if(self[event]) then
		self[event](self, event, ...)
	else
		print("StyleMeter debug: "..event)
	end 
end)