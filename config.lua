--[[====================
===		Config   	 ===
====================]]--
-- configuration file
-- to do: split core options and layout options

local addon, ns = ...

--[Settings]--
ns.modulepriority = {				-- determines the priority order of modules and custom modules
	["Damage"] = 1,
	["Heal"] = 2,
	["Absorb"] = 3,
}
ns.solo_hide = false				-- gathers no data, until in a group or raid [true/false]
ns.cleanOnGrpChange = false			-- Purge data gathered, from players that left the raid/group [true/false]
--ns.width = 250
--ns.height = 90

-- tempPets contains all temporary summoned pets, which will be added to the summoners/owners damage
ns.tempPets = {
	--Death knight
	["Risen Ghoul"] = true,
	--Druid
	["Treant"] = true,
	--Mage
	["Water Elemental"] = true,
	--Priest
	["Shadowfiend"] = true,
	["Mindbender"] = true,
	["Shadowy Apartion"] = true, --WoW doesn't declare the owner so this is still bugged from client
	--Shaman
	["Spirit Wolf"] = true,
	["Fire Elemental"] = true,
	["Earth Elemental"] = true,
}
