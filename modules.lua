--//Modules//--
--[[
Module config file
de/activate modules or create additional modules
]]

local addon, ns = ...

ns.modules = {
	["CombatModules"] = {
		["Damage"] = {
			["activated"] = true,
			["name"] = "damage",
			["strings"] = {
				["SWING_DAMAGE"] = {
					"arg12", --damage swing
					"arg13", --overdamage swing
				},
				["RANGE_DAMAGE"] = {
					"arg15", --damage range
					"arg16", --overdamage range
				},
				["SPELL_DAMAGE"] = {
					"arg15", --damage spell
					"arg16", --overdamage spell
				},
			},
		},
	},
}