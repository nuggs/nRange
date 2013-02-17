--[[
	nRange - Teleport range checker for warlocks and monks.

	Copyright © 2013 Anthony Goins <turncoat@imightstabyou.com>

	This work is free. You can redistribute it and/or modify it under the
	terms of the Do What The Fuck You Want To Public License, Version 2,
	as published by Sam Hocevar. See the COPYING file for more details.
	
	This program is free software. It comes without any warranty, to
     * the extent permitted by applicable law. You can redistribute it
     * and/or modify it under the terms of the Do What The Fuck You Want
     * To Public License, Version 2, as published by Sam Hocevar. See
     * http://www.wtfpl.net/ for more details.
]]--

-- Version of the script, this will eventually use chat_msg_addon for version checking
NRANGE_VERSION = "0.1.4"

-- Slow down the update calls, we don't need to do so many
local nRange_TimeSinceLastUpdate = 0;
local nRange_UpdateInterval = 0.2;
local CLEAR, COOLDOWN, INRANGE, OUTRANGE = -1, 1, 2, 3;
local nRange_IconSet = false;

-- We'll store our settings within this
nRange_Data = {};

-- Spell information, class based since this works for monks and warlocks
local nRange_ClassInfo = {
	class		= nil,		-- Store class name for conditionals
	active		= false,	-- Do we have a teleport active
	cooldown	= false,	-- Set true if on cooldown
	teleport	= nil,		-- This gets set to the spell ID for the teleport spell depending on class
	summon		= nil,		-- Same as above but with the summon spell
	message		= nil,		-- message to display, don't change
	icon		= nil,		-- spell icon for displaying that shit
	locked		= true		-- obviously used for frame locking, keep true as the default unless you like errors when you click it
};

-- dialog for disabling addon if you're not on a warlock or monk
StaticPopupDialogs["DISABLE_NRANGE"] = {
	text = "This addon only supports Warlocks and Monks, press accept to disable for this character.",
	button1 = "Accept", OnAccept = nRange_Disable, timeout = 0, whileDead = 1,
};

-- Help information
nRange_Help = {
	"|cff00ffffnRange " ..GAME_VERSION_LABEL.. ":|r |cFF008B8B" ..NRANGE_VERSION.."|r",
	"  |cFF008B8B/nrange reset|r" .. "   - |cff00ffffReset nRange to it's default settings|r",
	"  |cFF008B8B/nrange lock|r" .. "     - |cff00ffffLock nRange|r",
	"  |cFF008B8B/nrange unlock|r" .. " - |cff00ffffUnlock nRange|r",
};

-- Create our addon frame
local nRange = CreateFrame("Frame", "nRange", UIParent);
nRange:SetWidth(200);
nRange:SetHeight(30);

local nRangeText = nRange:CreateFontString(nRange, "ARTWORK", "GameFontNormal");
local function nRange_CreateTexture()
	nRangeTexture = nRange:CreateTexture(nil, "BACKGROUND");
	nRangeTexture:SetTexture(nil);
	nRangeTexture:SetAllPoints(nRange);
	nRange.texture = nRangeTexture;
	nRangeText:SetAllPoints(nRange);
	nRangeText:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE");
	nRange:SetMovable(false);
	nRange:EnableMouse(false);
end

-- create our icon and texture and whatnot
function nRange_CreateIcon()
	nRangeIcon = CreateFrame("Frame", "nRange_Icon", nRange);
	nRangeIcon:SetFrameStrata("BACKGROUND");
	nRangeIcon:SetWidth(30);
	nRangeIcon:SetHeight(30);

	nRangeIconTex = nRangeIcon:CreateTexture(nil, "BACKGROUND");
	nRangeIconTex:SetTexture(nil); -- We'll set the texture later
	nRangeIconTex:SetAllPoints(nRangeIcon);
	nRangeIcon.texture = nRangeIconTex;
	nRangeIcon:SetPoint("LEFT",-25,0);

	nRangeIconTimer = nRangeIcon:CreateFontString(nil, "OVERLAY");
	nRangeIconTimer:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE");
	nRangeIconTimer:SetTextColor(0,1,0);
	nRangeIconTimer:SetShadowColor(0,0,0);
	nRangeIconTimer:SetShadowOffset(1, -1);
	nRangeIconTimer:SetPoint("CENTER", nRangeIcon, "CENTER", 1, 0);
	nRangeIconTimer:SetText(nil);
end

-- Disable the UI if not on a warlock or monk
local function nRange_Disable()
	DisableAddOn("nRange");
	ReloadUI();
end

-- Lock the frame
local function nRange_Lock()
	nRange:SetMovable(false);
	nRange:EnableMouse(false);
	nRange_ClassInfo.locked = true;
	nRangeTexture:SetTexture(nil);
	DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00fffflocked|r");
end

-- unlock the frame...
local function nRange_Unlock()
	nRange:SetMovable(true); nRange:EnableMouse(true);
	nRange_ClassInfo.locked = false;
	nRangeTexture:SetTexture(0, 0, 1, .5);
	nRange:Show();
	DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffunlocked|r");
end

-- set the message of cooldown or whatever
local function nRange_SetMessage(message_type)
	local name = nRange_ClassInfo.teleport;
	if (message_type == COOLDOWN) then
		nRange_ClassInfo.message = name .. ": On Cooldown!";
		nRangeText:SetTextColor(1, 0, 0);
	elseif (message_type == INRANGE) then -- In range
		nRange_ClassInfo.message = name .. ": In Range!";
		nRangeText:SetTextColor(0, 1, 0);
	elseif (message_type == OUTRANGE) then -- Out of range
		nRange_ClassInfo.message = name .. ": Out of Range!";
		nRangeText:SetTextColor(1, 0, 0);
	elseif (message_type == CLEAR) then -- This is for when we clear the portal
		nRange_ClassInfo.message = nil;
		nRangeIconTex:SetTexture(nil);
		nRange_IconSet = false;
	end
	nRangeText:SetText(nRange_ClassInfo.message);
end

-- clear our stuff out
local function nRange_Clear()
	nRange_ClassInfo.active = false;
	nRange_SetMessage(CLEAR);
	nRangeIconTimer:SetText(nil);
	if (nRange_ClassInfo.locked == true) then
		nRange:Hide();
	end
end

-- Set the proper spells depending on class
local function nRange_SetClass()
	if (select(2,UnitClass("player")) == "WARLOCK") then
		local _, _, icon = GetSpellInfo(48020);
		nRange_ClassInfo.teleport = GetSpellInfo(48020);
		nRange_ClassInfo.summon = GetSpellInfo(48018);
		nRange_ClassInfo.icon = icon;
		nRange_ClassInfo.class = "warlock";
	elseif (select(2,UnitClass("player")) == "MONK") then
		local _, _, icon = GetSpellInfo(119996);
		nRange_ClassInfo.teleport = GetSpellInfo(119996);
		nRange_ClassInfo.summon = GetSpellInfo(119052); --101643
		nRange_ClassInfo.icon = icon;
		nRange_ClassInfo.class = "monk";
	end
	-- Create the icon stuff here, after we have our spell icons
	nRange_CreateIcon();
end

-- Check the cooldown of the spell
local function nRange_GetCooldown()
	local name = nRange_ClassInfo.teleport;
	local _, duration = GetSpellCooldown(name);
	if (duration and duration > 1.5) then
		nRange_ClassInfo.cooldown = true;
	else
		nRange_ClassInfo.cooldown = false;
		nRangeIconTimer:SetText(nil);
	end
end

-- Updates the cooldown timer on the spell icon
local function nRange_UpdateCooldown()
	local name = nRange_ClassInfo.teleport;
	local start, duration = GetSpellCooldown(name);
	local cooldown, r, g, b = floor(start + duration - GetTime() + 1), 0, 0, 1;
	if (cooldown > 16) then
		r, g, b = 0, 1, 0;
	elseif (cooldown > 8) then
		r, g, b = 1, 1, 0;
	else
		r, g, b = 1, 0, 0;
	end

	if (start > 0 and duration > 0) then
		nRangeIconTimer:SetTextColor(r, g, b);
		nRangeIconTimer:SetText(cooldown);
		return;
	else
		nRangeIconTimer:SetText(nil);
		return;
	end
end

-- Check if we're in range
local function nRange_InRange()
	-- lmao, we have to check if our pet is in range since transcendence uses pets.
	if (nRange_ClassInfo.class == "monk") then
		local name = nRange_ClassInfo.teleport;
		local inRange, unit = 0, "pet";
		inRange = IsSpellInRange(name, unit);
		if (inRange == 1) then
			return true;
		else
			return false;
		end
	elseif (nRange_ClassInfo.class == "warlock") then -- We can check if the spell is usable for warlocks.
		local usable, nomana = IsUsableSpell(nRange_ClassInfo.teleport);
		if (not usable and not nomana) then
			return false
		else
			return true
		end
	end
end

-- Check if our spell is active and if not set active to false
local function nRange_IsActive()
	if (nRange_ClassInfo.class == "warlock") then -- Here we can just check if they still have the active aura
		local buff = UnitBuff("player", "Demonic Circle: Summon"); 
		if (buff) then
			if (nRange_ClassInfo.active == false) then
				nRange_ClassInfo.active = true;
				nRange:Show();
			end
			return true;
		else
			nRange_Clear();
			return false;
		end
	elseif (nRange_ClassInfo.class == "monk") then
		local guid = UnitGUID("pet");
		-- We have a pet out, check and see if active is set, if not set it
		if (guid ~= nil and UnitInVehicle("player") == false) then
			if (nRange_ClassInfo.active == false) then
				nRange_ClassInfo.active = true;
				nRange:Show();
			end
			return true;
		else -- It's not active any longer, let's set it to false
			nRange_Clear();
			return false
		end
	end
end

-- Handle the fun loading stuff
function nRange:ADDON_LOADED(name)
	-- Set defaults if we don't have any
	if (name == "nRange") then
		if (nRange_Data.x == nil) then
			nRange_Data.x = 0;
		end
		if (nRange_Data.y == nil) then
			nRange_Data.y = 0;
		end
		if (nRange_Data.Anchor == nil) then
			nRange_Data.Anchor = "CENTER";
		end
		nRange_CreateTexture();
		nRange:ClearAllPoints();
		nRange:SetPoint(nRange_Data.Anchor, nRange_Data.x, nRange_Data.y);
		nRange:SetToplevel(true);
	end
end

-- set some additional stuff we couldn't when the addon was loading
function nRange:PLAYER_LOGIN()
	-- Do the usual event registering if we're on a lock or monk, otherwise, disable
	if (select(2,UnitClass("player")) == "WARLOCK") or (select(2,UnitClass("player")) == "MONK") then
		nRange:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		nRange:RegisterEvent("PLAYER_DEAD");
		nRange:RegisterEvent("ZONE_CHANGED_NEW_AREA");
		nRange_SetClass();
		nRange_IsActive();
	else
		StaticPopup_Show("DISABLE_NRANGE");
	end
	nRange:UnregisterEvent("PLAYER_LOGIN");
end

-- Changed from nDemonic, we're checking this now and only comparing unitID and spellName
function nRange:UNIT_SPELLCAST_SUCCEEDED(unitID, spellName, _, _, _)
	-- Check if it's from the player and if it's one of our summoning spells
	if (unitID == "player" or unitID == "pet" and spellName == nRange_ClassInfo.summon) then
		nRange_ClassInfo.active = true;
		nRange:Show();
	end
end

-- Clear the status if we've died.
function nRange:PLAYER_DEAD()
	nRange_Clear();
end

-- Clear it on zone changes if it's inactive(switching instances, battlegrounds and whatnot)
function nRange:ZONE_CHANGED_NEW_AREA()
	if (nRange_IsActive() == false and nRange_ClassInfo.active == true) then
		nRange_Clear();
	end
end

-- Our main update handler, runs ever .2 seconds, cooldown updates every pass.
function nRange_OnUpdate(self, elapsed)
	nRange_TimeSinceLastUpdate = nRange_TimeSinceLastUpdate + elapsed;
	-- We want to be sure that it's active and on cooldown.  We don't want to just update this every pass when there's no reason to
	if (nRange_IsActive() == true and nRange_ClassInfo.active == true and nRange_ClassInfo.cooldown == true) then
		nRange_UpdateCooldown();
	end
	while (nRange_TimeSinceLastUpdate > nRange_UpdateInterval) do
		if (nRange_IsActive() == true and nRange_ClassInfo.active == true) then -- Check if we're active
			if (nRange_IconSet == false) then -- Some hackery because the icon likes to show when it shouldn't.
				nRangeIconTex:SetTexture(nRange_ClassInfo.icon);
				nRange_IconSet = true;
			end
			nRange_GetCooldown(); -- Check if on cooldown.
			if (nRange_ClassInfo.cooldown == true) then
				nRange_SetMessage(COOLDOWN);
			elseif (nRange_InRange() == true) then
				nRange_SetMessage(INRANGE);
			else
				nRange_SetMessage(OUTRANGE);
			end
		end
		nRange_TimeSinceLastUpdate = nRange_TimeSinceLastUpdate - nRange_UpdateInterval;
	end
end

nRange:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end);
nRange:SetScript("OnMouseDown", function(self, button)
	if (nRange_ClassInfo.locked == false) then
		if (button == "LeftButton" and not nRange.isMoving) then
			nRange:StartMoving();
			nRange.isMoving = true;
		end
	end
end)

nRange:SetScript("OnMouseUp", function()
	if (nRange.isMoving) then
		nRange:StopMovingOrSizing();
		nRange.isMoving = false;
		local point, relativeTo, relativePoint, xOfs, yOfs = nRange:GetPoint();
		nRange_Data.x = xOfs;
		nRange_Data.y = yOfs;
		nRange_Data.Anchor = relativePoint;
	end
end)
nRange:SetScript("OnUpdate", nRange_OnUpdate);
nRange:RegisterEvent("PLAYER_LOGIN");
nRange:RegisterEvent("ADDON_LOADED");

-- Slash commands, lol, should make this better.
SlashCmdList['NRANGE'] = function(arg)
	if (arg == 'lock') then
		nRange_Lock();
	elseif (arg == 'unlock') then
		nRange_Unlock();
	elseif (arg == 'reset') then
		--nRange_Reset();
	else
		for _, msg in ipairs(nRange_Help) do
			DEFAULT_CHAT_FRAME:AddMessage(msg);
		end
	end
end
SLASH_NRANGE1 = '/nrange'
SLASH_NRANGE2 = '/nr'