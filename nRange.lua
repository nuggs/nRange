local _, class = UnitClass("player");
if (class == "MONK" or class == "WARLOCK") then
--[[
    The MIT License (MIT)

    Copyright (c) 2015-2018 Anthony "Turncoat Tony" Goins

    Permission is hereby granted, free of charge, to any person obtaining a copy of
    this software and associated documentation files (the "Software"), to deal in
    the Software without restriction, including without limitation the rights to
    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
    the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]--

NRANGE_VERSION = "0.9.8.5";

nRange_Communication = false;  -- Some people had issues, can set to true if you want
local nRange_TimeSinceLastUpdate = 0;
local nRange_UpdateInterval = 0.2;
local CLEAR, COOLDOWN, INRANGE, OUTRANGE = -1, 1, 2, 3;
local nRange_IconSet = false;
local string_format, square = string.format, sqrt;

-- Probably move this to it's own file
local YARDS = "yard"

nRange_Data = {};

local nRange_ClassInfo = {
    active      = false,    -- Do we have a teleport active
    cooldown    = false,    -- Set true if on cooldown
    teleName    = nil,      -- Set the name of the teleport
    summName    = nil,      -- Set the name of the summon
    teleport    = nil,      -- This gets set to the spell ID for the teleport spell depending on class
    summon      = nil,      -- Same as above but with the summon spell
    buff        = nil,      -- spell ID for the buff if the class uses one.
    message     = nil,      -- message to display, don't change
    icon        = nil,      -- spell icon for displaying that shit
    distance    = true,     -- Enable distance tracking
    locked      = true,     -- obviously used for frame locking, keep true as the default unless you like errors when you click it
    showicon    = true      -- Show the icon or not
};

--[[
    Information about the current portal.
    Astrolabe (c) James Carrothers
]]--
local nRange_Teleport = {
    facing      = 0,
    range       = 0,        -- trying something
    inside      = false,
    ping = {
        x       = 0,
        y       = 0,
        bx      = 0,
        by      = 0
    },
    offset = {
        x       = 0,
        y       = 0
    }
};

local MinimapSize = {
    indoor = {
        [0] = 300, -- scale
        [1] = 240, -- 1.25
        [2] = 180, -- 5/3
        [3] = 120, -- 2.5
        [4] = 80,  -- 3.75
        [5] = 50,  -- 6
    },
    outdoor = {
        [0] = 466 + 2/3, -- scale
        [1] = 400,       -- 7/6
        [2] = 333 + 1/3, -- 1.4
        [3] = 266 + 2/6, -- 1.75
        [4] = 200,       -- 7/3
        [5] = 133 + 1/3, -- 3.5
    },
};

local function nRange_Reset()
    nRange_Data.active = false;
    nRange_ClassInfo.active = false;
    ReloadUI();
end

StaticPopupDialogs["RESET_NRANGE"] = {
    text = "Click reset to reset while you reset your reset.",
    button1 = "Reset", OnAccept = nRange_Reset, timeout = 0, whileDead = 1,
};

nRange_Help = {
    "|cff00ffffnRange " ..GAME_VERSION_LABEL.. ":|r |cFF008B8B" ..NRANGE_VERSION.."|r",
    "  |cFF008B8B/nrange reset|r" .. "   - |cff00ffffReset nRange to it's default settings|r",
    "  |cFF008B8B/nrange lock|r" .. "     - |cff00ffffLock nRange|r",
    "  |cFF008B8B/nrange unlock|r" .. " - |cff00ffffUnlock nRange|r",
    "  |cFF008B8B/nrange icon|r" .. "    - |cff00ffffEnable or disable icons|r",
    "  |cFF008B8B/nrange communication|r" .. " - |cff00ffffEnable or disable addon communication(enable if you can please)|r",
};

local nRange = CreateFrame("Frame", "nRange", UIParent);
nRange:SetWidth(200);
nRange:SetHeight(40);

local nRangeText = nRange:CreateFontString(nRange, "ARTWORK", "GameFontNormal");
local nRangeDistance = nRange:CreateFontString(nRange, "ARTWORK", "GameFontNormal");
local function nRange_CreateTexture()
    nRangeTexture = nRange:CreateTexture(nil, "BACKGROUND");
    nRangeTexture:SetTexture(nil);
    nRangeTexture:SetAllPoints(nRange);
    nRange.texture = nRangeTexture;
    nRangeText:SetAllPoints(nRange);
    nRangeText:SetFont("Fonts\\ARIALN.TTF", 14, "OUTLINE");
    if nRange_ClassInfo.distance == true then
        nRangeDistance:SetAllPoints(nRange);
        nRangeDistance:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE");
        nRangeDistance:SetPoint("BOTTOM", 0, -40);
    end
    nRange:SetMovable(false);
    nRange:EnableMouse(false);
end

local function nRange_CreateIcon()
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

local function nRange_Disable()
    DisableAddOn("nRange");
    ReloadUI();
end

local function nRange_Lock()
    nRange:SetMovable(false);
    nRange:EnableMouse(false);
    nRange_ClassInfo.locked = true;
    nRangeTexture:SetTexture(nil);
    DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00fffflocked|r");
end

local function nRange_Unlock()
    nRange:SetMovable(true); nRange:EnableMouse(true);
    nRange_ClassInfo.locked = false;
    nRangeTexture:SetTexture(0, 0, 1, .5);
    nRange:Show();
    DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffunlocked|r");
end

local function nRange_SetMessage(message_type)
    local name = nRange_ClassInfo.teleport;
    if message_type == COOLDOWN then
        nRange_ClassInfo.message = name .. ": On Cooldown!";
        nRangeText:SetTextColor(1, 0, 0);
    elseif message_type == INRANGE then
        nRange_ClassInfo.message = name .. ": In Range!";
        if nRange_ClassInfo.distance == false then
            nRangeText:SetTextColor(0, 1, 0);
        end
    elseif message_type == OUTRANGE then
        nRange_ClassInfo.message = name .. ": Out of Range";
        if nRange_ClassInfo.distance == true then
            nRangeText:SetTextColor(1, 0, 0);
        end
    elseif message_type == CLEAR then
        nRange_ClassInfo.message = nil;
        nRangeIconTex:SetTexture(nil);
        nRange_IconSet = false;
    end
    nRangeText:SetText(nRange_ClassInfo.message);
end

local function nRange_Clear()
    nRange_ClassInfo.active = false;
    nRange_Data.active = false;
    nRange_SetMessage(CLEAR);
    nRangeIconTimer:SetText(nil);

    if nRange_ClassInfo.locked == true then
        nRange:Hide();
    end
end

local function nRange_SetClass()
    if class == "WARLOCK" then
        local _, _, icon = GetSpellInfo(48020);
        nRange_ClassInfo.teleport = GetSpellInfo(48020);
        nRange_ClassInfo.summon = GetSpellInfo(48018);
        nRange_ClassInfo.buff = GetSpellInfo(48018);
        nRange_ClassInfo.icon = icon;
    elseif class == "MONK" then
        local _, _, icon = GetSpellInfo(119996);
        nRange_ClassInfo.teleport = GetSpellInfo(119996);
        nRange_ClassInfo.summon = GetSpellInfo(101643);
        nRange_ClassInfo.icon = icon;
    end
    nRange_CreateIcon();
end

local function nRange_GetDistance()
    local x, y

    if nRange_Teleport.inside then
        x = (nRange_Teleport.ping.x + nRange_Teleport.offset.x) * MinimapSize.indoor[Minimap:GetZoom()]
        y = (nRange_Teleport.ping.y + nRange_Teleport.offset.y) * MinimapSize.indoor[Minimap:GetZoom()]
    else
        x = (nRange_Teleport.ping.x + nRange_Teleport.offset.x) * MinimapSize.outdoor[Minimap:GetZoom()]
        y = (nRange_Teleport.ping.y + nRange_Teleport.offset.y) * MinimapSize.outdoor[Minimap:GetZoom()]
    end
    nRange_Teleport.range = square(x * x + y * y);

    if nRange_Teleport.range > 100 and class == "MONK" then nRange_Clear(); end
end

local function nRange_GetCooldown()
    local name = nRange_ClassInfo.teleport;
    local _, duration = GetSpellCooldown(name);
    if duration and duration > 1.5 then
        nRange_ClassInfo.cooldown = true;
    else
        nRange_ClassInfo.cooldown = false;
        nRangeIconTimer:SetText(nil);
    end
end

local function nRange_UpdateCooldown()
    local name = nRange_ClassInfo.teleport;
    local start, duration = GetSpellCooldown(name);
    local cooldown, r, g, b = floor(start + duration - GetTime() + .5), 0, 0, 1;
    if cooldown > 16 then
        r, g, b = 0, 1, 0;
    elseif cooldown > 8 then
        r, g, b = 1, 1, 0;
    else
        r, g, b = 1, 0, 0;
    end

    if start > 0 and duration > 0 then
        nRangeIconTimer:SetTextColor(r, g, b);
        nRangeIconTimer:SetText(cooldown);
    else
        nRangeIconTimer:SetText(nil);
    end
end

local function nRange_SetDistanceColor(distance)
    if distance < 25 then
        nRangeText:SetTextColor(0, 1, 0);
    elseif distance > 25 and distance < 40 then
        nRangeText:SetTextColor(1, .50, 0);
    elseif distance >= 40 then
        nRangeText:SetTextColor(1, 0, 0);
    end
end

local function nRange_InRange()
    if class == "MONK" then
        if nRange_Teleport.range <= 40 then
            return true;
        else
            return false;
        end
    else
        local usable, _ = IsUsableSpell(nRange_ClassInfo.teleport);
        if (not usable) then
            return false
        else
            return true
        end
    end
end

local function nRange_IsActive()
    if class == "WARLOCK" then
        local buff = UnitBuff("player", nRange_ClassInfo.buff)
        if buff then
            if nRange_ClassInfo.active == false then
                nRange_ClassInfo.active = true;
                nRange:Show();
            end
            return true;
        else
            nRange_Clear();
            return false;
        end
    elseif class == "MONK" then
        local buff = UnitBuff("player", nRange_ClassInfo.summon)
        if buff then
            nRange_ClassInfo.active = true;
            nRange:Show();
            return true;
        else
            nRange_Clear();
            return false
        end
    end
end

function nRange:ADDON_LOADED(name)
    if (name == "nRange") then
        if nRange_Data.x == nil then
            nRange_Data.x = 0;
        end
        if nRange_Data.y == nil then
            nRange_Data.y = 0;
        end
        if nRange_Data.Anchor == nil then
            nRange_Data.Anchor = "CENTER";
        end
        if nRange_Data.showicon == nil then
            nRange_Data.showicon = nRange_ClassInfo.showicon;
        end

        if nRange_Data.active == nil then
            nRange_Data.active = false;
            nRange_ClassInfo.active = false;
        end

        if nRange_Data.communication == nil then
            nRange_Data.communication = false
        end

        nRange_ClassInfo.showicon = nRange_Data.showicon;
        nRange_Communication = nRange_Data.communication

        nRange_CreateTexture();
        nRange:ClearAllPoints();
        nRange:SetPoint(nRange_Data.Anchor, nRange_Data.x, nRange_Data.y);
        nRange:SetToplevel(true);
    end
end

function nRange:PLAYER_LOGIN()
    nRange:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    nRange:RegisterEvent("PLAYER_DEAD");
    nRange:RegisterEvent("ZONE_CHANGED_NEW_AREA");

    nRange_SetClass();
    nRange_Clear();
    nRange_IsActive()

    -- Check if we're murican or not
    if GetLocale() ~= "enUS" then
        YARDS = "meter"
    end

    nRange:UnregisterEvent("PLAYER_LOGIN");
end

-- Astrolabe
function nRange:MINIMAP_UPDATE_ZOOM()
    local Minimap = Minimap;
    local curZoom = Minimap:GetZoom();

    if (GetCVar("minimapZoom") == GetCVar("minimapInsideZoom")) then
        if (curZoom < 2) then
            Minimap:SetZoom(curZoom + 1);
        else
            Minimap:SetZoom(curZoom - 1);
        end
    end

    if ((GetCVar("minimapZoom") + 0) == Minimap:GetZoom()) then
        nRange_Teleport.inside = true;
    else
        nRange_Teleport.inside = false;
    end
    Minimap:SetZoom(curZoom);
end

function PingMinimap()
    Minimap:PingLocation(0,0);
    local newX, newY = Minimap:GetPingPosition();
    local offX = nRange_Teleport.ping.x - newX;
    local offY = nRange_Teleport.ping.y - newY;

    nRange_Teleport.offset.x = nRange_Teleport.offset.x + offX;
    nRange_Teleport.offset.y = nRange_Teleport.offset.y + offY;
    nRange_Teleport.ping.x = newX;
    nRange_Teleport.ping.y = newY;
end

function nRange:UNIT_SPELLCAST_SUCCEEDED(unitID, spellName, _, _, _)
    if unitID == "player" and spellName == nRange_ClassInfo.summon or (spellName == nRange_ClassInfo.teleport and class == "MONK") then
        if ((nRange_ClassInfo.distance == true and nRange_ClassInfo.active == false) or (nRange_ClassInfo.distance == true and class == "MONK")) then
    DEFAULT_CHAT_FRAME:AddMessage("Testing inside");
            nRange_Teleport.facing = GetPlayerFacing();
            nRange_Teleport.ping.x = 0;
            nRange_Teleport.ping.y = 0;
            nRange_Teleport.offset.x = 0;
            nRange_Teleport.offset.y = 0;
    PingMinimap();
        end
        nRange_ClassInfo.active, nRange_Data.active = true, true;
        nRange:Show();
    end
end

function nRange:PLAYER_DEAD()
    nRange_Clear();
end

function nRange:ZONE_CHANGED_NEW_AREA()
    if class == "MONK" then nRange_Clear();
    elseif (nRange_IsActive() == false and nRange_ClassInfo.active == true) then
        nRange_Clear();
    end
end

function nRange_OnUpdate(self, elapsed)
    nRange_TimeSinceLastUpdate = nRange_TimeSinceLastUpdate + elapsed;
    if nRange_ClassInfo.active == true and nRange_ClassInfo.cooldown == true then
        nRange_UpdateCooldown();
    end
    while (nRange_TimeSinceLastUpdate > nRange_UpdateInterval) do
        if (nRange_IsActive() == true and nRange_ClassInfo.active == true) then
            if (nRange_ClassInfo.distance == true) then
                local x, y = Minimap:GetPingPosition()
                nRange_Teleport.ping.x = x;
                nRange_Teleport.ping.y = y;
                local distance = nRange_Teleport.range;
                nRange_GetDistance();

                if (((distance - 1) >= 0) and ((distance - 1) < 1)) then
                    nRangeDistance:SetText(string_format("%d "..YARDS.." away", distance));
                else
                    nRangeDistance:SetText(string_format("%d "..YARDS.."s away", distance));
                end
                nRange_SetDistanceColor(distance);
            end

            if (nRange_IconSet == false and nRange_ClassInfo.showicon) then
                nRangeIconTex:SetTexture(nRange_ClassInfo.icon);
                nRange_IconSet = true;
            end
            nRange_GetCooldown();
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
SlashCmdList['NRANGE'] = function(msg)
    cmd, arg1 = strsplit(" ", msg)

    if (cmd == 'lock') then
        nRange_Lock();
    elseif (cmd == 'unlock') then
        nRange_Unlock();
    elseif (cmd == 'reset') then
        StaticPopup_Show("RESET_NRANGE");
    elseif (cmd == 'icon') then
        if arg1 == 'enable' then
            if (nRange_ClassInfo.showicon == true) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffIcons are already enabled|r");
            else
                nRange_ClassInfo.showicon = true;
                DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffIcons enabled|r");
            end
        elseif arg1 == 'disable' then
            if (nRange_ClassInfo.showicon == false) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffIcons are already disabled|r");
            else
                nRange_ClassInfo.showicon = false;
                DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffIcons disabled|r");
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange icon: |cff00ffffEnable or disable|r");
        end
    elseif cmd == 'communication' then
        if arg1 == 'enable' then
            if nRange_Communication == true then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffAddon communication is already enabled|r");
            else
                nRange_Communication = true;
                nRange_Data.communication = true;
                DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffAddon communication enabled|r");
            end
        elseif arg1 == 'disable' then
            if (nRange_Communication == false) then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffAddon communication is already disabled|r");
            else
                nRange_Communication = false;
                nRange_Data.communication = false;
                DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange: |cff00ffffAddon communication disabled|r");
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnRange communication: |cff00ffffEnable or disable|r");
        end
    else
        for _, help in ipairs(nRange_Help) do
            DEFAULT_CHAT_FRAME:AddMessage(help);
        end
    end
end
SLASH_NRANGE1 = '/nrange'
SLASH_NRANGE2 = '/nr'
else
    nRange_Communication = false;
end
