--//Core//--

local addon, ns = ...
-- Make the core functions available to layouts
_G[addon] = ns

local eF = CreateFrame("Frame", "eventFrame", UIParent)
eF:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
eF:RegisterEvent("GROUP_ROSTER_UPDATE")
eF:RegisterEvent("PLAYER_ENTERING_WORLD")
eF:RegisterEvent("UNIT_PET")	
eF:RegisterEvent("PLAYER_REGEN_ENABLED")
eF:RegisterEvent("ADDON_LOADED")

-- Create our databases and configs
function eF:ADDON_LOADED(event, addon)
	if addon == "StyleMeter" then
		-- DBs
		if StyleMeterDB == nil then
			StyleMeterDB = {
				DB = {
					players = {},
					guids = {},
					rank = {},
				},
				data = {
					overall = {},
					current = {},
				},
			}	
			ns.DB = StyleMeterDB.DB
			ns.data = StyleMeterDB.data
		else
			ns.DB = StyleMeterDB.DB
			ns.data = StyleMeterDB.data
		end
	end
end

-- module (data) & plugin (feature) databases
ns.module = {}
ns.plugin = {}

function eF:addUnitToDB(unit, owner)
	local guid = UnitGUID(unit)
--	if not guid or guid == "" then return end
	local unitType = select(1, strsplit("-", guid))
	-- the default Blizzard UI defines GetUnitName(unit, showServerName) which only returns the unit name, 
	-- but for characters from another server appends the server name (showServerName==true) or "(*)" (if showServerName==false).
	local name = GetUnitName(unit, true)
	if not name or name == "Unknown" then return end
	
	if unitType == "Player" then
		-- Create the player key in ns.DB.players
		if not ns.DB.players[name] then
			ns.DB.players[name] = {
				["class"] = select(1, UnitClass(unit)),
				["classcolor"] = RAID_CLASS_COLORS[select(2, UnitClass(unit))],
				["gatherdata"] = true,
			}
			-- Insert player names into ns.DB.rank
			if not ns.DB.rank[name] then
				table.insert(ns.DB.rank, name)
			end
			-- Insert guid in ns.DB.guids
			if not ns.DB.guids[guid] then
				ns.DB.guids[guid] = {
					["name"] = name,
				}
			end
			-- Keep track of different per second calculation values per module
			for module in pairs(ns.module) do
				for mode in pairs(ns.data) do
					if not ns.data[mode][name] then
						ns.data[mode][name] = {}
					end
					if not ns.data[mode][name][module] then
						ns.data[mode][name][module] = {
							-- SpellDB
							spells = {},
							-- Total amount of [module]
							total = 0,
							-- Combat time values
							combatTime = 0,
							amount = 0,
							previous_timestamp = 0,
						}
					end
				end
			end
		end
	elseif unitType == "Pet" then
		--if pets are registered first.. we need to create the PlayerDB
		for module in pairs(ns.module) do
			for mode in pairs(ns.data) do
				if not ns.data[mode][owner] then
					ns.data[mode][owner] = {}
				end
				if not ns.data[mode][owner][module] then
					ns.data[mode][owner][module] = {
						-- SpellDB
						spells = {},
						-- Total amount of [module]
						total = 0,
						-- Combat time values
						combatTime = 0,
						amount = 0,
						previous_timestamp = 0,
					}
				end
			end
		end
		-- Insert pet guid in ns.DB.guids
		if not ns.DB.guids[guid] then
			ns.DB.guids[guid] = {
				["name"] = owner,
			}
		end
	end
end

function eF:removeUnitFromDatatracking(unit, owner)
	local name = GetUnitName(unit, true)
	if not name or name == "Unknown" then return end
	
	-- Remove the player key in ns.DB.players and pet key in ns.DB.pets
	if ns.DB.players[name] then
		ns.DB.players[name].gatherdata = false
	end
end
 
function eF:UpdateWatchedPlayers()
	-- Delete Players/Pets that aren't in group/raid anymore and stop gathering data on them
	for k in pairs(ns.DB.players) do
		if k ~= UnitName("Player") then
			if IsInGroup("player") and not IsInRaid("player") then
				if not UnitInParty(k) then
					eF:removeUnitFromDatatracking(k)
				end
			elseif IsInRaid("player") then
				if not UnitInRaid(k) then
					eF:removeUnitFromDatatracking(k)
				end
			else
				eF:removeUnitFromDatatracking(k)
			end
		end
	end

	-- Insert player name
	eF:addUnitToDB("player")

	-- Insert playerpet name
	if UnitExists("playerpet") then
		eF:addUnitToDB("playerpet", UnitName("player"))
	end

	-- Insert party members & pets
	if IsInGroup("player") then
		for i=1, GetNumSubgroupMembers() do
			eF:addUnitToDB("party"..i)
			if UnitExists("partypet"..i) then
				eF:addUnitToDB("partypet"..i, UnitName("party"..i))
			end
		end
	end

	-- Insert raid members & pets
	if IsInRaid("player") then
		for i=1, GetNumGroupMembers() do
			eF:addUnitToDB("raid"..i)
			if UnitExists("raidpet"..i) then
				eF:addUnitToDB("raidpet"..i, UnitName("raid"..i))
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
	-- display cfg
	-- Select Damage as the standard module and Hybrid as the standard mode if they aren't set yet
	-- else use the saved vars
	if StyleMetercfg == nil then
		StyleMetercfg = {
			displaymodule = "Damage",
			displaymode = "Hybrid",
		}
		ns.switchModule("Damage")
		ns.switchMode("Hybrid")
	else
		ns.switchModule(StyleMetercfg.displaymodule)
		ns.switchMode(StyleMetercfg.displaymode)
	end
	if ns.UpdateLayout then
		ns:UpdateLayout()
	end
end

function eF.PLAYER_REGEN_ENABLED()
	-- Reset every current data if we leave battle
	for name in pairs(ns.data.current) do
		if not ns.module[name] then
			if ns.data.current[name] then
				for module in pairs(ns.module) do
					ns.data.current[name][module].spells = {}
					ns.data.current[name][module].total = 0
					ns.data.current[name][module].combatTime = 0
					ns.data.current[name][module].amount = 0
					ns.data.current[name][module].previous_timestamp = 0
					ns.data.current[module] = 0
				end
			end
		end
	end
	-- Update the layout
	if ns.UpdateLayout then
		ns:UpdateLayout()
	end
end

-- Return the correct arguments or values related to the parameters from modules
function eF.checkParameterValues(self, t, p, ...)
	if string.match(t[p], "arg(%d+)") then
		return p, select(string.match(t[p], "arg(%d+)"), ...)
	else
		return p, t[p]
	end
end

-- Throttle updating
-- This is done to prevent multiple updates within a single fragment of a second (especially in raids)
-- The lower the value, the more CPU heavy it will get
local last_ts = 0
function eF.isThrottled(self, timeStamp)
	if timeStamp - last_ts < 0.5 then
		return true
	else
		last_ts = timeStamp
		return false
	end
end

function eF.getClogName(self, guid)
	return ns.DB.guids[guid].name
end

function eF.COMBAT_LOG_EVENT_UNFILTERED(self, event)
	local timeStamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
--	if string.find(eventType, "_ABSORBED") then
--		print(...)
--	end
	
	-- Check if user exist in DB before gathering data	
	if ns.DB.players[sourceName] and ns.DB.players[sourceName].gatherdata == true then
		if string.find(eventType, "_SUMMON") then
			-- Create the pet key in ns.DB.pets
			if not ns.DB.guids[destGUID] then
				ns.DB.guids[destGUID] = {
					["name"] = sourceName,
				}
			end
		end
		--if pets are registered first.. we need to create the PlayerDB
		for module in pairs(ns.module) do
			for mode in pairs(ns.data) do
				if not ns.data[mode][sourceName] then
					ns.data[mode][sourceName] = {}
				end
				if not ns.data[mode][sourceName][module] then
					ns.data[mode][sourceName][module] = {
						-- SpellDB
						spells = {},
						-- Total amount of [module]
						total = 0,
						-- Combat time values
						combatTime = 0,
						amount = 0,
						previous_timestamp = 0,
					}
				end
			end
		end
	end
	
	if ns.DB.guids[sourceGUID] then
		local cLogName = eF:getClogName(sourceGUID)
		
		for module, vars in pairs(ns.module) do
			-- eventTypeString = eg "SPELL_DAMAGE_PERIODIC"	
			for eventTypeString, params in pairs(vars) do
				-- If we find a eventType defined from modules
				if string.find(eventType, eventTypeString) then
					-- Return the arguments defined from modules to determine the right amount, spellName, etc.
					-- Do this dynamically for parameters which can be different in some situations (dispel amount should be 1, Auto Attack has no spellName, etc.)
					local spellID, spellName, spellSchool, amount, over, school, resitsed, blocked, aborbed, critical, glancing, crushing, isOffHand
					-- Damage
					if string.find(eventTypeString, "_DAMAGE") then
						if string.match(params["spellId"], "arg(%d+)") then
							spellID = select(string.match(params["spellId"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						else
							spellID = params["spellId"]
						end
						if string.match(params["spellName"], "arg(%d+)") then
							spellName = select(string.match(params["spellName"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						else
							spellName = params["spellName"]
						end
						if string.match(params["spellSchool"], "arg(%d+)") then
							spellSchool = select(string.match(params["spellSchool"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						else
							spellSchool = params["spellSchool"]
						end
						amount = select(string.match(params["amount"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						over = select(string.match(params["overkill"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						school = select(string.match(params["school"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						resisted = select(string.match(params["resisted"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						blocked = select(string.match(params["blocked"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						absorbed = select(string.match(params["absorbed"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						critical = select(string.match(params["critical"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						glancing = select(string.match(params["glancing"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						crushing = select(string.match(params["crushing"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						isOffHand = select(string.match(params["isOffHand"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
					-- Heal
					elseif string.find(eventTypeString, "_HEAL") then
						if string.match(params["spellId"], "arg(%d+)") then
							spellID = select(string.match(params["spellId"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						else
							spellID = params["spellId"]
						end
						if string.match(params["spellName"], "arg(%d+)") then
							spellName = select(string.match(params["spellName"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						else
							spellName = params["spellName"]
						end
						if string.match(params["spellSchool"], "arg(%d+)") then
							spellSchool = select(string.match(params["spellSchool"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						else
							spellSchool = params["spellSchool"]
						end
						amount = select(string.match(params["amount"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						over = select(string.match(params["overheal"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						absorbed = select(string.match(params["absorbed"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
						critical = select(string.match(params["critical"], "arg(%d+)"), CombatLogGetCurrentEventInfo())
					end

					local cLogSpell
					local unitType = select(1, strsplit("-", sourceGUID))
					if unitType == "Player" then
						cLogSpell = spellName
					elseif unitType == "Pet" or "Creature" then
						cLogSpell = sourceName
					end
					
					for mode in pairs(ns.data) do
						-- Add values to ns.data					
						-- Fill in the spellNames in ns.data[mode][sourceName][module].spells and create the keys
						if not ns.data[mode][cLogName][module].spells[cLogSpell] then
							ns.data[mode][cLogName][module].spells[cLogSpell] = {
								["spellID"] = spellID,
								["spellSchool"] = spellSchool or 1,
								["amount"] = amount,
							--	["overkill"] = overkill,
								["school"] = school,
							--	["resisted"] = resisted,
							--	["blocked"] = blocked,
							--	["absorbed"] = ansorbed,
							--	["critical"] = critical,
							--	["glancing"] = glancing,
							--	["crushing"] = crushing,
							--	["isOffHand"] = isOffHand,
							}
						else
						--	ns.data[mode][sourceName][module].spells[spellName].spellID = spellID
						--	ns.data[mode][sourceName][module].spells[spellName].spellSchool = spellSchool
							ns.data[mode][cLogName][module].spells[cLogSpell].amount = ns.data[mode][cLogName][module].spells[cLogSpell].amount + amount
						--	ns.data[mode][sourceName][module].spells[spellName].overkill = overkill
						--	ns.data[mode][sourceName][module].spells[spellName].school = school
						--	ns.data[mode][sourceName][module].spells[spellName].resisted = resisted
						--	ns.data[mode][sourceName][module].spells[spellName].blocked = blocked
						--	ns.data[mode][sourceName][module].spells[spellName].absorbed = ansorbed
						--	ns.data[mode][sourceName][module].spells[spellName].critical = critical
						--	ns.data[mode][sourceName][module].spells[spellName].glancing = glancing
						--	ns.data[mode][sourceName][module].spells[spellName].crushing = crushing
						--	ns.data[mode][sourceName][module].spells[spellName].isOffHand = isOffHand
						end

						-- Total amount of player (and pet)
						ns.data[mode][cLogName][module].total = ns.data[mode][cLogName][module].total + amount

						-- Calculate individual combatTime per player (and pet), inspired by TinyDPS (thanks Sideshow!)
						ns.data[mode][cLogName][module].amount = timeStamp - ns.data[mode][cLogName][module].previous_timestamp
						if ns.data[mode][cLogName][module].amount < 3.5 then
							ns.data[mode][cLogName][module].combatTime = ns.data[mode][cLogName][module].combatTime + ns.data[mode][cLogName][module].amount
						else
							ns.data[mode][cLogName][module].combatTime = ns.data[mode][cLogName][module].combatTime + 3.5
						end
						ns.data[mode][cLogName][module].previous_timestamp = timeStamp

						-- Totals as a numeric value
						if not ns.data[mode][module] then
							ns.data[mode][module] = amount
						else
							ns.data[mode][module] = ns.data[mode][module] + amount
						end
					end

					-- Update the layout
					if ns.UpdateLayout and eF:isThrottled(timeStamp) == false then
						ns:UpdateLayout()
					end
				end
			end
		end
	end
end

--//#core functions available to layouts and/or plugins#//--
-- Resettingfunction (reset all collected data)
function ns.resetData()
	for name in pairs(ns.data.current) do
		if not ns.module[name] then
			if ns.data.current[name] then
				for module in pairs(ns.module) do
					for mode in pairs(ns.data) do
						ns.data[mode][name][module].spells = {}
						ns.data[mode][name][module].total = 0
						ns.data[mode][name][module].combatTime = 0
						ns.data[mode][name][module].amount = 0
						ns.data[mode][name][module].previous_timestamp = 0
						ns.data[mode][module] = 0
					end
				end
			end
		end
	end

	-- Clear rank-table
	ns.DB.rank = {}
	
	-- clear saved vars and reinitiate an empty DB
	-- also call eF:UpdateWatchedPlayers()
	StyleMeterDB = {
		DB = {
			players = {},
			guids = {},
			rank = {},
		},
		data = {
			overall = {},
			current = {},
		},
	}
	ns.DB = StyleMeterDB.DB
	ns.data = StyleMeterDB.data
	eF:UpdateWatchedPlayers()
end

-- shortInteger value
function ns.siValue(val)
	if val >= 1e6 then
		return ('%.1f'):format(val / 1e6):gsub('%.', 'm')
	elseif val >= 1e4 then
		return ("%.1f"):format(val / 1e3):gsub('%.', 'k')
	else
		return math.floor(val)
	end
end

-- Search a table for a specific entry
-- see https://stackoverflow.com/questions/33510736/check-if-array-contains-specific-value
function ns.contains(table, val)
	for i=1, #table do
		if table[i] == val then 
			return true
		end
	end
	return false
end

-- Seach a table for a specific entry and return it's index number
-- see https://scriptinghelpers.org/questions/10051/is-there-a-way-to-remove-a-value-from-a-table-without-knowing-its-index
-- under Linear Search
function ns.tablefind(tab,el)
	for index, value in pairs(tab) do
		if value == el then
			return index
		end
	end
end

function ns.resetCurData()
	-- Reset current data on demand
	for name in pairs(ns.data.current) do
		if not ns.module[name] then
			if ns.data.current[name] then
				for module in pairs(ns.module) do
					ns.data.current[name][module].spells = {}
					ns.data.current[name][module].total = 0
					ns.data.current[name][module].combatTime = 0
					ns.data.current[name][module].amount = 0
					ns.data.current[name][module].previous_timestamp = 0
					ns.data.current[module] = 0
				end
			end
		end
	end
end

-- Determine if any partymember is in Combat
local inCombat = {}
function ns.checkPartyCombat()
	for name in pairs(ns.data.current) do
		if UnitExists(name) then
			if UnitAffectingCombat(name) then	
				if not ns.contains(inCombat, name) then
					table.insert(inCombat, name)
				end
			else
				if ns.contains(inCombat, name) then
					table.remove(inCombat, ns.tablefind(inCombat, name))
				end
			end		
		end
	end
	if table.getn(inCombat) > 0 then
		return true
	else
		return false
	end
end

local dotsRunning = {}
local lasttime = 0
function ns.checkDotsRunning()
	local seconds = GetTime()
	for name in pairs(ns.data.overall) do
		if UnitExists(name) then
		--print(seconds - lasttime)
			if ((seconds - lasttime) < 5) then	
				if not ns.contains(dotsRunning, name) then
					table.insert(dotsRunning, name)
				end
			else
				if ns.contains(dotsRunning, name) then
					table.remove(dotsRunning, ns.tablefind(dotsRunning, name))
				end
			end		
			lasttime = GetTime()
		end
	end
	if table.getn(dotsRunning) > 0 then
		return true
	else
		ns:resetCurData()
		return false
	end
end

-- Dynamic sorting function
-- Sort the rank table in redards to mode
-- This function is intended to sort collected data from top to bottom (1, 2, 3,..)
-- call this whenever you want to update information to be updated with ranks in mind (e.g. sort Statusbars)
function ns.sortRank()
	if ns.activeMode == "Current" then
		sort(ns.DB.rank, function(a, b) return ns.data.current[a][ns.activeModule].total > ns.data.current[b][ns.activeModule].total end)
	elseif ns.activeMode == "Overall" then
		sort(ns.DB.rank, function(a, b) return ns.data.overall[a][ns.activeModule].total > ns.data.overall[b][ns.activeModule].total end)
	elseif ns.activeMode == "Hybrid" then
		if ns.checkPartyCombat() == true then
			sort(ns.DB.rank, function(a, b) return ns.data.current[a][ns.activeModule].total > ns.data.current[b][ns.activeModule].total end)
		else
			sort(ns.DB.rank, function(a, b) return ns.data.overall[a][ns.activeModule].total > ns.data.overall[b][ns.activeModule].total end)
		end
	end
end

-- Determine the correct mode values
-- Current: Current fight
-- Overall: All fights
-- Hybrid: switch btween current and Overall dependent on inFight situation
function ns.getModeData(num)
	if ns.DB.rank[num] then
		if ns.activeMode == "Current" then
			return ns.data.current[ns.DB.rank[num]][ns.activeModule].total, ns.data.current[ns.activeModule]
		elseif ns.activeMode == "Overall" then
			return ns.data.overall[ns.DB.rank[num]][ns.activeModule].total, ns.data.overall[ns.activeModule]
		elseif ns.activeMode == "Hybrid" then
			--if (ns.data.current[ns.activeModule] and ns.data.current[ns.activeModule] > 0) then
			if ns.checkPartyCombat() == true then
				return ns.data.current[ns.DB.rank[num]][ns.activeModule].total, ns.data.current[ns.activeModule]
			else
				--if (ns.data.current[ns.activeModule] and ns.data.current[ns.activeModule] > 0) then
				--	ns.resetCurData()
				--end
				-- call ns.sortRank so the display is not borked
				--ns.sortRank()
				return ns.data.overall[ns.DB.rank[num]][ns.activeModule].total, ns.data.overall[ns.activeModule]
			end
		end
	end
end

-- Get The correct combatTime and spells used
-- return the values in regards to selected mode
function ns.getTimeAndSpells(num)
	if ns.DB.rank[num] then
		if ns.activeMode == "Current" then
			return ns.data.current[ns.DB.rank[num]][ns.activeModule].combatTime, ns.data.current[ns.DB.rank[num]][ns.activeModule].spells
		elseif ns.activeMode == "Overall" then
			return ns.data.overall[ns.DB.rank[num]][ns.activeModule].combatTime, ns.data.overall[ns.DB.rank[num]][ns.activeModule].spells
		elseif ns.activeMode == "Hybrid" then
			if ns.checkPartyCombat() == true then
			--if (ns.data.current[ns.activeModule] and ns.data.current[ns.activeModule] > 0) then
				return ns.data.current[ns.DB.rank[num]][ns.activeModule].combatTime, ns.data.current[ns.DB.rank[num]][ns.activeModule].spells
			else
				return ns.data.overall[ns.DB.rank[num]][ns.activeModule].combatTime, ns.data.overall[ns.DB.rank[num]][ns.activeModule].spells
			end
		end
	end
end

function ns.switchModule(module)
	if module ~= nil then
		ns.activeModule = module
	end

	-- Sort Rank table
	ns.sortRank()
end

function ns.switchMode(mode)
	if mode ~= nil then
		ns.activeMode = mode
	end
	
	-- Sort Rank table
	ns.sortRank()
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