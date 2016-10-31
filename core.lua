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
	--local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-",guid)
	local unitType = select(1, strsplit("-", guid))
	--print(unitType)
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
		--		["rank"] = 0,
		--		["SMUser"] = 0,
			--	print(name..realm)
			}
		end
	elseif unitType == "Pet" or unitType == "Vehicle" then
		if not ns.guidDB.pets[guid] then
			ns.guidDB.pets[guid] = {
				["name"] = name, 
				["owner"] = owner,
			--	print(name.." "..owner)
			}
		end
	end
end
 
function eF:UpdateWatchedPlayers()
	-- Delete old table
	if ns.cleanOnGrpChange == true then	
		for k in pairs(ns.guidDB) do
			ns.guidDB[k] = nil
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
	ns.resetData()

	-- Insert player names into rank-table
	for _, guid in pairs(ns.guidDB.players) do
		ns.guidDB.rank[#ns.guidDB.rank+1] = guid.name
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
	if ns.guidDB.players[arg4] then --check if user exist in guidDB before gathering data
		for module, vars in pairs(ns.datamodules) do
			if vars["activated"] == true then --check if module is activated
				for type, args in pairs(vars["strings"]) do --taype = , args = eg arg12
					if string.find(arg2, type) then --if we find a type
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
							ns.moduleDB[module] = {[arg5] = value}
						end
						ns.moduleDB[module][arg5] = ns.moduleDB[module][arg5] + value
						
						if not ns.moduleDBtotal[module] then
							ns.moduleDBtotal[module] = value
						end
						ns.moduleDBtotal[module] = ns.moduleDBtotal[module] + value

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
	for k, v in pairs(ns.moduleDB) do
		ns.moduleDB[v] = 0
	end
	
	for k, v in pairs(ns.moduleDBtotal) do
		ns.moduleDBtotal[k] = 0
	end

	if ns.layoutSpecificReset then
		ns.layoutSpecificReset()
	end
	
	-- Clear rank-table
--	for k, v in ipairs(ns.guidDB.rank) do 
	--	print(v)
--		ns.guidDB.rank[v] = nil 
--	end
end

eF:SetScript("OnEvent", function(self, event, ...)  
	if(self[event]) then
		self[event](self, event, ...)
	else
		print("StyleMeter debug: "..event)
	end 
end)