--//panel//--

local addon, ns = ...

ns.panel = CreateFrame("Frame", "StyleMeterPanel")
ns.panel.name = addon
InterfaceOptions_AddCategory(ns.panel)

local title = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("|cff5599ff"..addon.."|r")

local about = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
about:SetText("Highly customizable, modular Damage Meter with custom Layout support")

local version = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
version:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 5, -20)
version:SetText("|cff5599ffVersion:|r "..GetAddOnMetadata("StyleMeter", "Version"))

local author = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
author:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -8)
author:SetText("|cff5599ffAuthor:|r Lolzen")

local github = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
github:SetPoint("TOPLEFT", author, "BOTTOMLEFT", 0, -8)
github:SetText("|cff5599ffGithub:|r https://github.com/Lolzen/StyleMeter")

local philosophy = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
philosophy:SetPoint("TOPLEFT", github, "BOTTOMLEFT", 0, -8)
philosophy:SetText("|cff5599ffPhilosophy:|r The Philosophy of StyleMeter is based on 3 Golden Rules:")

local rule1 = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
rule1:SetPoint("TOPLEFT", philosophy, "BOTTOMLEFT", 20, -8)
rule1:SetText("|cff5599ff* Highly customizable|r")

local rule2 = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
rule2:SetPoint("TOPLEFT", rule1, "BOTTOMLEFT", 0, -8)
rule2:SetText("|cff5599ff* Easy to customize|r")

local rule3 = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
rule3:SetPoint("TOPLEFT", rule2, "BOTTOMLEFT", 0, -8)
rule3:SetText("|cff5599ff* Extendable through modules|r")

local credit_header = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
credit_header:SetPoint("TOPLEFT", rule3, "BOTTOMLEFT", -20, -30)
credit_header:SetText("|cff5599ffCredits:|r")

local credit_names = ns.panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
credit_names:SetPoint("TOPLEFT", credit_header, "BOTTOMLEFT", -0, -8)
credit_names:SetText("|cffffffffPhanx & Zork, FizzleMizz & Tosaido, Sideshow|r")

--[[
local creditnames = {
	["Phanx & Zork"] = {["Reason"] = "Helped me getting plugins & Layouts working the way i intended it", ["Source"] = "http://www.wowinterface.com/forums/showthread.php?t=54765",},
	["Fizzlemizz & Tosaido"] = {["Reason"] = "Helped me getting the modules working", ["Source"] = "http://www.wowinterface.com/forums/showthread.php?t=54915",},
	["SideShow"] = {["Reason"] = "I've got his permission to use the DPS calc method from his Addon TinyDPS", ["Source"] = "PM @ WoWInterface",},
}
]]