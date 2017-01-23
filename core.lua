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

function eF.COMBAT_LOG_EVENT_UNFILTERED(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, ...)
	-- Check if user exist in DB before gathering data
	if ns.DB.players[arg5] or ns.DB.pets[arg4] then
		local unitType = select(1, strsplit("-", arg4))
		for module, vars in pairs(ns.module) do
			-- eventType = eg "SPELL_DAMAGE_PERIODIC", args = eg arg12
			for eventType, args in pairs(vars["strings"]) do
				-- If we find a eventType defined from modules
				if string.find(arg2, eventType) then
					-- Return the arguments defined from modules to determine the right value
					for _, argument in pairs(args) do
						-- Every argument after arg9 would be arg1, arg2 [...] if we use select('#', ...) therefore, 
						-- just substract the 9 args we have used before, so we get the actual argument.
						-- this is still not the perfect solution as the actual 9 arguments between [event] and [...] are not
						-- accessable from plugins, which is not the goal, but it's a start.
						local value = select(string.match(argument, "arg(%d+)") -9, ...)

						if type(value) ~= "string" then
							if value == -1 or value == nil then
								value = 0
							end
						end

						-- as SWING and SPELL have different arguments, on auto attacks arg13 (#4 after starting counting from ...) is a number value,
						-- otherwise we can be sure it is our desired spell/ability string. Therefore Let's check that.
						local spellName
						if type(select(4, ...)) == "string" then
							spellName = select(4, ...)
						else
							spellName = "Auto Attack"
						end

						-- add values to DB
						if unitType == "Player" then
							-- Players
							if not ns.moduleDB[module][arg5] then
								ns.moduleDB[module][arg5] = value
							else
								ns.moduleDB[module][arg5] = ns.moduleDB[module][arg5] + (value or 0)
							end
							-- track the individual spell or ability numbers too
							if not ns.DB.spells[module][arg5] then
								ns.DB.spells[module][arg5] = {}
							end
							if not ns.DB.spells[module][arg5][spellName] then
								ns.DB.spells[module][arg5][spellName] = value
							else
								ns.DB.spells[module][arg5][spellName] = ns.DB.spells[module][arg5][spellName] + (value or 0)
							end
							-- Calculate individual combatTime per player, inspired by TinyDPS (thanks Sideshow!)
							ns.DB.players[arg5].amount = arg1 - (ns.DB.players[arg5].previous_timestamp or 0)
							if ns.DB.players[arg5].amount < 3.5 then
								ns.DB.players[arg5].combatTime = ns.DB.players[arg5].combatTime + (ns.DB.players[arg5].amount or 0)
							else
								ns.DB.players[arg5].combatTime = ns.DB.players[arg5].combatTime + 3.5
							end
							ns.DB.players[arg5].previous_timestamp = arg1
						elseif unitType == "Pet" or unitType == "Creature" then
							-- Pets
							if not ns.moduleDB[module][ns.DB.pets[arg4].owner] then
								ns.moduleDB[module][ns.DB.pets[arg4].owner] = value
							else
								ns.moduleDB[module][ns.DB.pets[arg4].owner] = ns.moduleDB[module][ns.DB.pets[arg4].owner] + (value or 0)
							end
							-- track the pets as spell in the overview
							if not ns.DB.spells[module][ns.DB.pets[arg4].owner] then
								ns.DB.spells[module][ns.DB.pets[arg4].owner] = {}
							end
							if not ns.DB.spells[module][ns.DB.pets[arg4].owner][arg5] then
								ns.DB.spells[module][ns.DB.pets[arg4].owner][arg5] = value
							else
								ns.DB.spells[module][ns.DB.pets[arg4].owner][arg5] = ns.DB.spells[module][ns.DB.pets[arg4].owner][arg5] + (value or 0)
							end
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
				elseif string.find(arg2, "SPELL_SUMMON") then
					--Create the pet key in ns.DB.pets
					if not ns.DB.pets[arg8] then
						ns.DB.pets[arg8] = {
							["name"] = arg9,
							["owner"] = arg5,
							["ownerguid"] = arg4,
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

-- Slashcommands to report data
local channel, wname
local paste = function(self)
	SendChatMessage("StyleMeter report for : ["..ns.activeModule.."]", channel, nil, wname)
	for i=1, 5, 1 do
		local curModeVal = ns.moduleDB[ns.activeModule][ns.DB.rank[i]] or 0
		if i and ns.moduleDB[ns.activeModule][ns.DB.rank[i]] then
			SendChatMessage(string.format("%d. %s: %d (%.0f%%) [%s]", i, ns.DB.rank[i], curModeVal, curModeVal / ns.moduleDBtotal[ns.activeModule] * 100, ns.DB.players[ns.DB.rank[i]].class), channel, nil, wname)
		end
	end
end

SLASH_STYLEMETER1 = "/sm"
SlashCmdList["STYLEMETER"] = function(cmd)
	local variable, name = cmd:match("^(%S*)%s*(.-)$") 
	variable = string.lower(variable)
	if variable and variable == "s" then
		channel = "SAY"
		paste()
	elseif variable and variable == "p" then
		channel = "PARTY"
		paste()
	elseif variable and variable == "g" then
		channel = "GUILD"
		paste()
	elseif variable and variable == "ra" then
		channel = "RAID"
		paste()
		elseif variable and variable == "i" then
		channel = "INSTANCE"
		paste()
	elseif variable == "w" and name ~= "" then
		channel = "WHISPER"
		wname = name
		paste()
	else
		ChatFrame1:AddMessage("|cff5599ffStyleMeter:|r Valid commands: s/p/i/g/ra/w [name]")
	end
end

eF:SetScript("OnEvent", function(self, event, ...)  
	if(self[event]) then
		self[event](self, event, ...)
	else
		print("StyleMeter debug: "..event)
	end 
end)