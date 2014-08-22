if (nRange_Communication == false) then return; end
local _, class = UnitClass("player");
if (class == "MONK" or class == "WARLOCK") then
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

	 Thanks to Hydra(http://tukui.org) for the write up on SendAddonMessage and CHAT_MSG_ADDON.
]]--
-- Some stuff...
local nComm_Cache = {};
local CACHE_MAX = 5;
local string_format = string.format;

nComm = CreateFrame("Frame");

-- Check if they can be added to the cache, doubles as awesome
function nComm:CheckCache(player)
	for i = #nComm_Cache, 1, -1 do
		if (nComm_Cache[#nComm_Cache] == player) then
			return true;
		end
	end
	return false;
end

-- Adds them to the cache
function nComm:AddCache(player)
	local cache_max = CACHE_MAX;
	if (cache_max > 0) then
		if (self:CheckCache(player) == false) then
			if (#nComm_Cache > cache_max ) then
				tremove(nComm_Cache, 1);
			end
			nComm_Cache[#nComm_Cache + 1] = player;
		end
	end
end

--[[
	This function is modified from Deadly Boss Mods, as such this is released under the
	Creative Commons Attribution-Noncommercial-Share Alike 3.0 License.
	http://www.deadlybossmods.com
]]--
function nComm:SendMessage(prefix, message)
	if (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance()) then
		SendAddonMessage(prefix, message, "INSTANCE_CHAT");
	else
		if (IsInRaid()) then
			SendAddonMessage(prefix, message, "RAID");
		elseif (IsInGroup(LE_PARTY_CATEGORY_HOME)) then
			SendAddonMessage(prefix, message, "PARTY");
		else
			if (IsInGuild()) then
				SendAddonMessage(prefix, message, "GUILD");
			end
		end
	end
end -- end dbm stuff

function nComm:PLAYER_ENTERING_WORLD()
	self:SendMessage("nRangeSV", NRANGE_VERSION);
end

function nComm:RAID_ROSTER_UPDATE()
	self:SendMessage("nRangeSV", NRANGE_VERSION);
end

function nComm:PARTY_MEMBERS_CHANGED()
	self:SendMessage("nRangeSV", NRANGE_VERSION);
end

function nComm:CHAT_MSG_ADDON(prefix, message, channel, sender)
	local state, msg = string_format(prefix, sender), string_format(message, sender);

	if (state == "nRangeSV") then
		if (msg == NRANGE_VERSION) then
			return; -- Nothing to do
		elseif (msg < NRANGE_VERSION and not self:CheckCache(sender)) then
			self:SendMessage("nRangeRV", "Your addon is outdated, current version is at least: " .. NRANGE_VERSION);
			self:AddCache(sender);
		elseif (msg > NRANGE_VERSION) then
		--elseif (msg > NRANGE_VERSION and nRange_Data.notified == false) then -- enable if there's complaints.
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffn|cFF008B8BRange: |rnRange is outdated, current version is at least: |cffff0000" .. msg .. "|r");
			--nRange_Data.notified = true;
		end
	elseif (state == "nRangeRV") then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffn|cFF008B8BRange: |r" .. msg);
		self:AddCache(sender);
	elseif (state == "nRangeWM") then
		RaidNotice_AddMessage(RaidBossEmoteFrame, message, ChatTypeInfo["RAID_WARNING"]);
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffn|cFF008B8BRange: |r" .. msg);
	elseif (state == "nRangeSM") then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffn|cFF008B8BRange: |r" .. msg);
	end
end

nComm:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end);
nComm:RegisterEvent("PLAYER_ENTERING_WORLD");
nComm:RegisterEvent("RAID_ROSTER_UPDATE");
nComm:RegisterEvent("PARTY_MEMBERS_CHANGED");
nComm:RegisterEvent("CHAT_MSG_ADDON");
RegisterAddonMessagePrefix("nRangeSV");
RegisterAddonMessagePrefix("nRangeRV");
RegisterAddonMessagePrefix("nRangeSM");
RegisterAddonMessagePrefix("nRangeWM");
end