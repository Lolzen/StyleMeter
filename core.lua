--//Core//--

local addon, ns = ...
-- Make the core functions available to layouts
_G[addon] = ns

local eF = CreateFrame("Frame", "eventFrame", UIParent)
eF:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eF:RegisterEvent("GROUP_ROSTER_UPDATE")
eF:RegisterEvent("PLAYER_ENTERING_WORLD")
eF:RegisterEvent("UNIT_PET")

-- Create our databases
ns.DB = {
	players = {},
	pets = {},
	rank = {},
	spells = {},
}

-- module (data) & plugin (feature) databases
ns.module = {}
ns.plugin = {}

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
				["guid"] = guid, 
				["combatTime"] = 0,
				["amount"] = 0,
				["previous_timestamp"] = 0,
			}
			-- Insert player names into ns.DB.rank
			ns.DB.rank[#ns.DB.rank+1] = name..realm
		end
	elseif unitType == "Pet" or unitType == "Creature" then
		local realm = realm and realm ~= "" and "-"..realm or ""
		local ownerguid = UnitGUID(owner) or ""

		-- Create the pet key in ns.DB.pets
		if not ns.DB.pets[guid] then
			ns.DB.pets[guid] = { 
				["name"] = name,
				["owner"] = owner,
				["ownerguid"] = ownerguid,
			}
		end
	end
end
 
function eF:UpdateWatchedPlayers()
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
end

-- Upate on certain events
eF.GROUP_ROSTER_UPDATE = eF.UpdateWatchedPlayers
eF.UNIT_PET = eF.UpdateWatchedPlayers

-- Upon entering the world, i.e. after Loading Screen, 
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

-- Sortfunction; sort the rank table after highes values on top for the viewed/active module
function ns.sortByModule(a, b)
	if ns.moduleDBtotal[ns.activeModule] and ns.moduleDBtotal[ns.activeModule] > 0 then
		return (ns.moduleDB[ns.activeModule][a] or 0) > (ns.moduleDB[ns.activeModule][b] or 0)
	end
end

function eF.COMBAT_LOG_EVENT_UNFILTERED(self, event, ...)
	local timeStamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
	-- Check if user exist in DB before gathering data
	if ns.DB.players[sourceName] or ns.DB.pets[sourceGUID] then
		local unitType = select(1, strsplit("-", sourceGUID))
		for module, vars in pairs(ns.module) do
			-- eventTypeString = eg "SPELL_DAMAGE_PERIODIC"
			for _, eventTypeString in pairs(vars["strings"]) do
				-- If we find a eventType defined from modules
				if string.find(eventType, eventTypeString) then
					-- Return the arguments defined from modules to determine the right value
					-- Unify arguments from SWING and SPELL eventTypes
					local spellId, spellName, spellSchool
					local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
					if type(select(13, ...)) == "string" then
						spellId, spellName, spellSchool = select(12, ...)
						amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = select(15, ...)
					else
						spellId, spellName, spellSchool = 6603, "Auto Attack", 	1
						amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = select(12, ...)
					end

					-- add values to DB
					if unitType == "Player" then
						-- Players
						if not ns.moduleDB[module][sourceName] then
							ns.moduleDB[module][sourceName] = amount
						else
							ns.moduleDB[module][sourceName] = ns.moduleDB[module][sourceName] + amount
						end
						-- track the individual spell or ability numbers too
						if not ns.DB.spells[module][sourceName] then
							ns.DB.spells[module][sourceName] = {}
						end
						if not ns.DB.spells[module][sourceName][spellName] then
							ns.DB.spells[module][sourceName][spellName] = amount
						else
							ns.DB.spells[module][sourceName][spellName] = ns.DB.spells[module][sourceName][spellName] + amount
						end
						-- Calculate individual combatTime per player, inspired by TinyDPS (thanks Sideshow!)
						ns.DB.players[sourceName].amount = timeStamp - ns.DB.players[sourceName].previous_timestamp
						if ns.DB.players[sourceName].amount < 3.5 then
							ns.DB.players[sourceName].combatTime = ns.DB.players[sourceName].combatTime + ns.DB.players[sourceName].amount
						else
							ns.DB.players[sourceName].combatTime = ns.DB.players[sourceName].combatTime + 3.5
						end
						ns.DB.players[sourceName].previous_timestamp = timeStamp
					elseif unitType == "Pet" or unitType == "Creature" then
						-- Pets
						if not ns.moduleDB[module][ns.DB.pets[sourceGUID].owner] then
							ns.moduleDB[module][ns.DB.pets[sourceGUID].owner] = amount
						else
							ns.moduleDB[module][ns.DB.pets[sourceGUID].owner] = ns.moduleDB[module][ns.DB.pets[sourceGUID].owner] + amount
						end
						-- track the pets as spell in the overview
						if not ns.DB.spells[module][ns.DB.pets[sourceGUID].owner] then
							ns.DB.spells[module][ns.DB.pets[sourceGUID].owner] = {}
						end
						if not ns.DB.spells[module][ns.DB.pets[sourceGUID].owner][sourceName] then
							ns.DB.spells[module][ns.DB.pets[sourceGUID].owner][sourceName] = amount
						else
							ns.DB.spells[module][ns.DB.pets[sourceGUID].owner][sourceName] = ns.DB.spells[module][ns.DB.pets[sourceGUID].owner][sourceName] + amount
						end
					end

					if not ns.moduleDBtotal[module] then
						ns.moduleDBtotal[module] = amount
					else
						ns.moduleDBtotal[module] = ns.moduleDBtotal[module] + amount
					end

					-- Update the layout
					if ns.UpdateLayout then
						ns:UpdateLayout()
					end
				elseif string.find(eventType, "SPELL_SUMMON") then
					--Create the pet key in ns.DB.pets
					if not ns.DB.pets[destGUID] then
						ns.DB.pets[destGUID] = {
							["name"] = destName,
							["owner"] = sourceName,
							["ownerguid"] = sourceGUID,
						}
					end
				end
			end
		end
	end
end

-- Resettingfunction (reset all collected data)
function ns.resetData()
	for module, _ in pairs(ns.module) do
		if ns.moduleDB[module] then
			for k, v in pairs(ns.moduleDB[module]) do
				ns.moduleDB[module][k] = nil
			end
		end
		if ns.DB.spells[module] then
		for k, v in pairs(ns.DB.spells[module]) do
				ns.DB.spells[module][k] = nil
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

	-- Reset the combatTime
	for name, v in pairs(ns.DB.players) do
		ns.DB.players[name].combatTime = 0
	end

	-- Also let the layout reset things, if the function exists
	if ns.layoutSpecificReset then
		ns.layoutSpecificReset()
	end
end

ns.siValue = function(val)
	if val >= 1e6 then
		return ('%.1f'):format(val / 1e6):gsub('%.', 'm')
	elseif val >= 1e4 then
		return ("%.1f"):format(val / 1e3):gsub('%.', 'k')
	else
		return val
	end
end

SLASH_STYLEMETER1 = "/sm"
SLASH_STYLEMETER2 = "/stylemeter"
SlashCmdList["STYLEMETER"] = function(self)
	InterfaceOptionsFrame_OpenToCategory("StyleMeter")
	InterfaceOptionsFrame_OpenToCategory("StyleMeter")
end

eF:SetScript("OnEvent", function(self, event, ...)  
	if(self[event]) then
		self[event](self, event, ...)
	else
		print("StyleMeter debug: "..event)
	end 
end)