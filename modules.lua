--//Modules//--
--[[
Module config file
de/activate modules or create additional modules
]]

local addon, ns = ...

ns.datamodules = {
	["Damage"] = {
		["activated"] = true,
		["strings"] = {
			["SWING_DAMAGE"] = {
				"arg12", --damage swing
			--	"arg13", --overdamage swing
			},
			["RANGE_DAMAGE"] = {
				"arg15", --damage range
			--	"arg16", --overdamage range
			},
			["SPELL_DAMAGE"] = {
				"arg15", --damage spell
			--	"arg16", --overdamage spell
			},
			["SPELL_PERIODIC_DAMAGE"] = {
				"arg15", --damage spell
				--"arg16", --overdamage spell
			},
		},
	},
	["Heal"] = {
		["activated"] = true,
		["strings"] = {
			["_HEAL"] = {
				"arg15", --heal
			},
		},
	},
	["Absorb"] = {
		["activated"] = true,
		["strings"] = {
			["SWING_MISSED"] = {
				"arg14", --absorb swing
			},
			["RANGE_MISSED"] = {
				"arg17", --absorb range
			},
			["SPELL_MISSED"] = {
				"arg17", --absorb spell
			},
		},
	},
}

ns.utilitymodules = {}