--//Core//--

local addon, ns = ...

local eF = CreateFrame("Frame", "eventFrame", UIParent)
eF:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eF:RegisterEvent("GROUP_ROSTER_UPDATE")
eF:RegisterEvent("PLAYER_ENTERING_WORLD")
eF:RegisterEvent("UNIT_PET")
eF:RegisterEvent("CHAT_MSG_ADDON")

-- In the guidDB is stored all player and pet information
ns.guidDB = {
	players = {},
	pets = {},
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
				["rank"] = 0,
				["SMUser"] = 0,
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
--	for _, guid in pairs(ns.guidDB.players) do
--		ns.guidDB.rank[#ns.guidDB.rank+1] = guid.name
--	end
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
	if ns.modules[module] == true and ns.guidDB.players[module[amount]] then
		return (ns.players[module[a]] > ns.players[module[b]])
	end
end

eF:SetScript("OnEvent", function(self, event, ...)  
	if(self[event]) then
		self[event](self, event, ...)
	else
		print("StyleMeter debug: "..event)
	end 
end)


function eF.COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17)
	if ns.guidDB.players[arg4] then --check if user exist in guidDB before gathering data
		if ns.modules[CombatModules[Damage[activated]]] then
			print("module recognized")
		end
--		for i=1, #ns.modules["CombatModules"] do
--			print("test")
--			print(arg12)
--			if ns.modules[i[activated]] == true then --check if module is activated
--				if string.find(arg2, ns.modules[i[strings]]) then
--					if not ns.guidDB.players[arg4[ns.modules[name]]] then
--						tinsert(ns.guidDB.players[arg4[ns.modules[name]]], ns.modules[i["value"]])	
--					end
--					ns.guidDB.players[arg4[ns.modules[i[name]]]] = ns.guidDB.players[arg4[ns.modules[i[name]]]] + ns.modules[i["value"]]
--					print(ns.modules[i["value"]])
--				end
--			end
--		end
	end	
end


-- Resettingfunction (reset all collected data)
function ns.resetData()
	if ns.curData then
		for k in pairs(ns.curData) do
			ns.curData[k] = nil
		end
	end
	
	if ns.dmgData then
		for k in pairs(ns.dmgData) do
			ns.dmgData[k] = nil
		end
	end

	if ns.overdmgData then
		for k in pairs(ns.overdmgData) do
			ns.overdmgData[k] = nil
		end
	end

	if ns.dmgtakenData then
		for k in pairs(ns.dmgtakenData) do
			ns.dmgtakenData[k] = nil
		end
	end

	if ns.healData then
		for k in pairs(ns.healData) do
			ns.healData[k] = nil
		end
	end

	if ns.overhealData then
		for k in pairs(ns.overhealData) do
			ns.overhealData[k] = nil
		end
	end

	if ns.absorbData then
		for k in pairs(ns.absorbData) do
			ns.absorbData[k] = nil
		end
	end

	if ns.deathData then
		for k in pairs(ns.deathData) do
			ns.deathData[k] = nil
		end
	end

	if ns.dispelData then
		for k in pairs(ns.dispelData) do
			ns.dispelData[k] = nil
		end
	end

	if ns.interruptData then
		for k in pairs(ns.interruptData) do
			ns.interruptData[k] = nil
		end
	end

	if ns.combatTotalTime then
		ns.combatTotalTime = 0
	end

	if ns.layoutSpecificReset then
		ns.layoutSpecificReset()
	end
	
	-- Clear rank-table
--	for k in ipairs(ns.guidDB.rank) do 
--		ns.guidDB.rank[k] = nil 
--	end
end