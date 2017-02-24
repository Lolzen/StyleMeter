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

ns.moduleDB, ns.moduleDBtotal = {}, {}

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
			}
			-- Insert player names into ns.DB.rank
			ns.DB.rank[#ns.DB.rank+1] = name..realm
			-- Keep track of differen per second calculation values per module
			for module in pairs(ns.module) do
				if not ns.DB.players[name..realm][module] then
					ns.DB.players[name..realm][module] = {
						["combatTime"] = 0,
						["amount"] = 0,
						["previous_timestamp"] = 0,
					}
				end
			end
		end
	elseif unitType == "Pet" or unitType == "Creature" then
		local realm = realm and realm ~= "" and "-"..realm or ""
		local ownerguid = UnitGUID(owner)

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

function eF.checkParameterValues(self, t, p, ...)
	local value
	if string.match(t[p], "arg(%d+)") then
		value = select(string.match(t[p], "arg(%d+)"), ...)
	else
		value = t[p]
	end
	return value
end

function eF.COMBAT_LOG_EVENT_UNFILTERED(self, event, ...)
	local timeStamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
	-- Check if user exist in DB before gathering data
	if ns.DB.players[sourceName] or ns.DB.pets[sourceGUID] then
		local unitType = select(1, strsplit("-", sourceGUID))
		for module, vars in pairs(ns.module) do
			-- eventTypeString = eg "SPELL_DAMAGE_PERIODIC"
			for eventTypeString, params in pairs(vars) do
				-- If we find a eventType defined from modules
				if string.find(eventType, eventTypeString) then
					-- Return the arguments defined from modules to determine the right amount, spellName, etc.
					-- Do this dynamically for parameters which can be different in some situations (dispel amount should be 1, Auto Attack has no spellName, etc.)
					local amount = eF:checkParameterValues(params, "amount", ...)
					local spellName = eF:checkParameterValues(params, "spellName", ...)

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
						if ns.DB.players[sourceName][module].amount then
							ns.DB.players[sourceName][module].amount = timeStamp - ns.DB.players[sourceName][module].previous_timestamp
							if ns.DB.players[sourceName][module].amount < 3.5 then
								ns.DB.players[sourceName][module].combatTime = ns.DB.players[sourceName][module].combatTime + ns.DB.players[sourceName][module].amount
							else
								ns.DB.players[sourceName][module].combatTime = ns.DB.players[sourceName][module].combatTime + 3.5
							end
							ns.DB.players[sourceName][module].previous_timestamp = timeStamp
						end
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
						-- Also calculate pet combatTime per player
						if ns.DB.players[ns.DB.pets[sourceGUID].owner][module].amount then
							ns.DB.players[ns.DB.pets[sourceGUID].owner][module].amount = timeStamp - ns.DB.players[ns.DB.pets[sourceGUID].owner][module].previous_timestamp
							ns.DB.players[ns.DB.pets[sourceGUID].owner][module].combatTime = ns.DB.players[ns.DB.pets[sourceGUID].owner][module].combatTime + ns.DB.players[ns.DB.pets[sourceGUID].owner][module].amount
							ns.DB.players[ns.DB.pets[sourceGUID].owner][module].previous_timestamp = timeStamp
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
		ns.moduleDBtotal[module] = nil
		-- Reset the combatTime
		for name, v in pairs(ns.DB.players) do
			ns.DB.players[name][module].combatTime = 0
		end
	end

	-- Clear rank-table
	for k, v in ipairs(ns.DB.rank) do 
		ns.DB.rank[v] = nil
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