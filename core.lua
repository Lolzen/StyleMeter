--//Core//--

local addon, ns = ...
-- Make the core functions available to layouts
_G[addon] = ns

local eF = CreateFrame("Frame", "eventFrame", UIParent)
eF:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eF:RegisterEvent("GROUP_ROSTER_UPDATE")
eF:RegisterEvent("PLAYER_ENTERING_WORLD")
eF:RegisterEvent("UNIT_PET")
eF:RegisterEvent("CHAT_MSG_ADDON")

-- In the guidDB is stored all player and pet information
ns.moduleDB = {}
ns.moduleDBtotal = {}

ns.guidDB = {
	players = {},
	pets = {},
	rank = {},
}

function eF:addUnitToDB(unit, owner)
	local guid = UnitGUID(unit)
	if not guid or guid == "" then return end
	local unitType = select(1, strsplit("-", guid))
	local name, realm = UnitName(unit)
	if not name or name == "Unknown" then return end
	
	if unitType == "Player" then
		local realm = realm and realm ~= "" and "-"..realm or ""
		local _, class, _, _, _ = GetPlayerInfoByGUID(guid)
		
		if not ns.guidDB.players[guid] then
			ns.guidDB.players[guid] = {
				["name"] = name..realm, 
				["class"] = class,
				["classcolor"] = RAID_CLASS_COLORS[class],
				["inRank"] = 0,
		--		["SMUser"] = 0,
			}
		end
		
	elseif unitType == "Pet" or unitType == "Vehicle" then
		if not ns.guidDB.pets[guid] then
			ns.guidDB.pets[guid] = {
				["name"] = name, 
				["owner"] = owner,
			}
		end
	end
end
 
function eF:UpdateWatchedPlayers()
	-- Delete old table
	if ns.cleanOnGrpChange == true then	
		for k in pairs(ns.guidDB.players) do
			ns.guidDB.players[k] = nil
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

	-- Insert player names into rank-table
	for _, guid in pairs(ns.guidDB.players) do
		if guid.inRank == 0 then
			ns.guidDB.rank[#ns.guidDB.rank+1] = guid.name
			guid.inRank = 1
		end
	end
end

-- Upate on certain events
eF.GROUP_ROSTER_UPDATE = eF.UpdateWatchedPlayers
eF.UNIT_PET = eF.UpdateWatchedPlayers

function eF.PLAYER_ENTERING_WORLD()
	eF:UpdateWatchedPlayers()
	if ns.UpdateLayout then
		ns:UpdateLayout()
	end
end

--Sortfunction
function ns.sortByModule(module, a, b)
	for k, v in pairs(ns.moduleDB[module]) do
		--	print(k.." "..v)
		--	if k ~= "total" then
				return (ns.moduleDB[module[a]] > ns.moduleDB[module[b]])
			--end
		end
--	if ns.moduleDB[module] then
		
--	end
end

function eF.COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17)
	-- Check if user exist in guidDB before gathering data
	if ns.guidDB.players[arg4] then
--		if string.find(arg2, "_MISSED") then
--			print("missed "..arg14)
--		end
		for module, vars in pairs(ns.datamodules) do
			-- Check if module is activated
			if vars["activated"] == true then
				-- Type = eg "SPELL_DAMAGE_PERIODIC", args = eg arg12
				for type, args in pairs(vars["strings"]) do
					-- If we find a type defined from modules
					if string.find(arg2, type) then
						local value
						for _, arg in pairs(args) do
							if arg == "arg5" then
								value = arg5
							elseif arg == "arg6" then
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
						
						if not ns.moduleDB[module] then
							ns.moduleDB[module] = {}
						end
						if not ns.moduleDB[module][arg5] then
							ns.moduleDB[module][arg5] = value
						else
							ns.moduleDB[module][arg5] = ns.moduleDB[module][arg5] + value
						end
		
						if not ns.moduleDBtotal[module] then
							ns.moduleDBtotal[module] = value
						else
							ns.moduleDBtotal[module] = ns.moduleDBtotal[module] + value
						end

						if ns.UpdateLayout then
							ns:UpdateLayout()
						end
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

	if ns.layoutSpecificReset then
		ns.layoutSpecificReset()
	end
	
	-- Clear rank-table
	for k, v in ipairs(ns.guidDB.rank) do 
		ns.guidDB.rank[v] = nil
	end
end

eF:SetScript("OnEvent", function(self, event, ...)  
	if(self[event]) then
		self[event](self, event, ...)
	else
		print("StyleMeter debug: "..event)
	end 
end)