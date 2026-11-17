--=====================================================================================
-- RND | Remove Nameplate Debuffs! - core.lua
-- Author: DonnieDice
-- RGX Mods Collection - RealmGX Community Project
--
-- One RGXAddon declaration owns everything the framework already provides: the saved
-- settings (RGX database, adopting the old flat table), the options panel, /rnd, the
-- minimap button, the nameplate event and the enforcement timer. What stays here is the
-- nameplate work itself.
--=====================================================================================

local RGX = _G.RGXFramework
if type(RGX) ~= "table" or type(RGX.RequireContract) ~= "function" then
    error("RemoveNameplateDebuffs requires RGX-Framework 2.19.0 or newer with the RGX contract compatibility handshake. Update RGX-Framework.", 0)
end
RGX:RequireContract("RemoveNameplateDebuffs", 1, "2.19.0")

RND = RND or {}

local ADDON_NAME = "RemoveNameplateDebuffs"
local ICON_PATH = "|TInterface/AddOns/RemoveNameplateDebuffs/media/icon:16:16|t"
local MINIMAP_ICON_TEXTURE = "Interface\\AddOns\\RemoveNameplateDebuffs\\media\\icon"

-- Chat prefix with orange R, N, D in [RND]
local CHAT_PREFIX = ICON_PATH .. " - |cffffffff[|r|cffff7d00RND|r|cffffffff]|r"

RND.addonName = ADDON_NAME

local function Metadata(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON_NAME, field) or nil
end
RND.version = tostring(Metadata("Version") or "unknown"):gsub("^v", "")

-- Settings live in the RGX database (RND.db, created by the declaration below).
function RND:IsEnabled()
    return self.db == nil or self.db.enabled ~= false
end

function RND:Say(message)
    print(CHAT_PREFIX .. " " .. message)
end

-- Hide debuffs on a specific nameplate
function RND:HideNameplateDebuffs(unitId)
    if not self:IsEnabled() then
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unitId)

    -- Ensure nameplate and UnitFrame are valid and not forbidden
    if not nameplate or not nameplate.UnitFrame then
        return
    end

    -- Use pcall to handle forbidden nameplates gracefully
    local success, err = pcall(function()
        if nameplate.UnitFrame:IsForbidden() then
            return
        end

        local unitFrame = nameplate.UnitFrame

        -- Standard Blizzard BuffFrame
        -- (No ClearAllPoints here: restore must be a pure inverse of hide,
        -- and some clients only re-lay aura frames when the plate is rebuilt.)
        if unitFrame.BuffFrame then
            unitFrame.BuffFrame:SetAlpha(0)
            unitFrame.BuffFrame:Hide()
        end

        -- Nameplate frames with a BuffFrame
        if unitFrame.ExtraIconFrame then
            unitFrame.ExtraIconFrame:SetAlpha(0)
            unitFrame.ExtraIconFrame:Hide()
        end

        -- Nameplate frames with an AuraWidget
        if unitFrame.AuraWidget then
            unitFrame.AuraWidget:SetAlpha(0)
            unitFrame.AuraWidget:Hide()
        end

        -- Nameplate frames with an Auras container
        if unitFrame.Auras then
            unitFrame.Auras:SetAlpha(0)
            unitFrame.Auras:Hide()
        end

        -- Nameplate frames with Debuffs/Buffs containers
        if unitFrame.Debuffs then
            unitFrame.Debuffs:SetAlpha(0)
            unitFrame.Debuffs:Hide()
        end
        if unitFrame.Buffs then
            unitFrame.Buffs:SetAlpha(0)
            unitFrame.Buffs:Hide()
        end

        -- Nameplate frames with an AuraIconRegion
        if unitFrame.AuraIconRegion then
            unitFrame.AuraIconRegion:SetAlpha(0)
            unitFrame.AuraIconRegion:Hide()
        end

        -- Additional generic frames that might contain debuffs
        if unitFrame.auras then
            unitFrame.auras:SetAlpha(0)
            unitFrame.auras:Hide()
        end

        -- Check for any frame with "debuff" or "buff" in the name (case insensitive)
        for key, frame in pairs(unitFrame) do
            if type(key) == "string" and type(frame) == "table" then
                local lowerKey = string.lower(key)
                if (string.find(lowerKey, "debuff") or string.find(lowerKey, "buff") or string.find(lowerKey, "aura")) then
                    if frame.SetAlpha then
                        frame:SetAlpha(0)
                    end
                    if frame.Hide then
                        frame:Hide()
                    end
                end
            end
        end
    end)

    if not success and self.L then
        -- Silent fail - nameplates can be forbidden in certain situations
    end
end

-- Resolve the unit token for a nameplate across client flavors
local function GetNameplateUnit(nameplate)
    if nameplate.UnitFrame and nameplate.UnitFrame.unit then
        return nameplate.UnitFrame.unit
    end
    return nameplate.namePlateUnitToken
end

-- Restore debuffs on a specific nameplate (inverse of HideNameplateDebuffs)
function RND:RestoreNameplateDebuffs(unitId)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitId)
    if not nameplate or not nameplate.UnitFrame then return end
    pcall(function()
        if nameplate.UnitFrame:IsForbidden() then return end
        local unitFrame = nameplate.UnitFrame
        local frames = {
            unitFrame.BuffFrame, unitFrame.ExtraIconFrame, unitFrame.AuraWidget,
            unitFrame.Auras, unitFrame.Debuffs, unitFrame.Buffs, unitFrame.AuraIconRegion,
            unitFrame.auras,
        }
        for _, frame in ipairs(frames) do
            if frame then
                frame:SetAlpha(1)
                frame:Show()
            end
        end
        for key, frame in pairs(unitFrame) do
            if type(key) == "string" and type(frame) == "table" then
                local lowerKey = string.lower(key)
                if string.find(lowerKey, "debuff") or string.find(lowerKey, "buff") or string.find(lowerKey, "aura") then
                    if frame.SetAlpha then frame:SetAlpha(1) end
                    if frame.Show then frame:Show() end
                end
            end
        end
    end)
end

-- Restore debuffs on all currently visible nameplates
function RND:RestoreAllNameplateDebuffs()
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        if nameplate and nameplate.UnitFrame then
            local unitId = GetNameplateUnit(nameplate)
            if unitId then self:RestoreNameplateDebuffs(unitId) end
        end
    end
end

function RND:HideAllNameplateDebuffs()
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        if nameplate and nameplate.UnitFrame then
            local unitId = GetNameplateUnit(nameplate)
            if unitId then
                self:HideNameplateDebuffs(unitId)
            end
        end
    end
end

-- Force Blizzard to rebuild every visible nameplate. Manual fallback only
-- (`/rnd test`): the rebuild visibly blinks all enemy plates, and the
-- automatic disable path no longer needs it because restore is a pure
-- inverse of hide (hide never destroys the aura frame's layout).
function RND:ForceNameplateRefresh()
    SetCVar("nameplateShowEnemies", 0)
    RGX:After(0.3, function()
        SetCVar("nameplateShowEnemies", 1)
    end)
end

-- Test functionality by toggling nameplates
function RND:TestFunctionality()
	if not self.L then
		print(CHAT_PREFIX .. " |cffff0000Error:|r Localization not loaded")
		return
	end

	print(CHAT_PREFIX .. " " .. self.L["TEST_TOGGLING"])

	-- Toggle nameplates off and on to force refresh
	self:ForceNameplateRefresh()
	RGX:After(0.5, function()
		print(CHAT_PREFIX .. " " .. self.L["TEST_COMPLETE"])
	end)
end

-- Display welcome message on player login
function RND:DisplayWelcomeMessage()
    if self.db.showWelcome == false then return end
    if not self.L then
        self:Say("|cffff0000Error:|r Localization not loaded")
        return
    end

    -- Welcome messages matching RGX Mods standard (same format as BLU)
    self:Say("Welcome. " .. self.L["TYPE_HELP"])
    self:Say("|cffffff00Version:|r |cff8080ff" .. self.version .. "|r")

    -- Show community message on first run
    if self.db.firstRun ~= false then
        self:Say(self.L["COMMUNITY_MESSAGE"])
        self.db.firstRun = false
    end
end

-- =====================================================================================
-- Settings changes (panel toggles, minimap clicks and slash commands all land here)
-- =====================================================================================

function RND:RefreshPanel()
    if self.panel then
        self.panel:InvalidateAllTabs()
        self.panel:Refresh()
    end
end

-- Apply the enabled state to the nameplates already on screen (the value is already stored).
function RND:ApplyEnabled(enabled)
    if enabled then
        self:HideAllNameplateDebuffs()
    else
        self:RestoreAllNameplateDebuffs()
    end
end

function RND:SetEnabled(enabled)
    enabled = enabled and true or false
    self.db.enabled = enabled
    self:ApplyEnabled(enabled)
    self:RefreshPanel()
end

-- Show or hide the minimap button (the value is stored by the button; the compartment entry stays).
function RND:ApplyMinimap(show)
    if self.minimapButton then
        self.minimapButton:SetVisible(show and true or false)
    end
end

function RND:SetMinimapShown(show)
    show = show and true or false
    self.db.minimapIconEnabled = show
    self:ApplyMinimap(show)
    self:RefreshPanel()
end

-- Slash command handler
function RND:HandleSlashCommand(args)
    if not self.L then
        self:Say("|cffff0000Error:|r Localization not loaded")
        return
    end

    local command = string.lower(args or "")

    if command == "" or command == "options" then
        if self.panel then self.panel:Open() end
    elseif command == "help" then
        self:ShowHelp()
    elseif command == "on" or command == "enable" then
        self:SetEnabled(true)
        self:Say(self.L["ADDON_ENABLED"])
    elseif command == "off" or command == "disable" then
        self:SetEnabled(false)
        self:Say(self.L["ADDON_DISABLED"])
    elseif command == "test" then
        self:TestFunctionality()
    elseif command == "status" then
        self:ShowStatus()
    elseif command == "welcome on" then
        self.db.showWelcome = true
        self:RefreshPanel()
        self:Say(self.L["WELCOME_ENABLED"] or "Welcome message |cff00ff00enabled|r")
    elseif command == "welcome off" then
        self.db.showWelcome = false
        self:RefreshPanel()
        self:Say(self.L["WELCOME_DISABLED"] or "Welcome message |cffff0000disabled|r")
    elseif command == "icon on" then
        self:SetMinimapShown(true)
        self:Say(self.L["MINIMAP_ICON_SHOWN"] or "Minimap icon |cff00ff00shown|r")
    elseif command == "icon off" then
        self:SetMinimapShown(false)
        self:Say(self.L["MINIMAP_ICON_HIDDEN"] or "Minimap icon |cffff0000hidden|r. Use |cffffffff/rnd icon on|r to show it again.")
    elseif command == "icon" then
        self:ShowHelp()
    else
        self:Say(self.L["ERROR_PREFIX"] .. " " .. self.L["ERROR_UNKNOWN_COMMAND"])
    end
end

-- Show help information
function RND:ShowHelp()
    if not self.L then
        self:Say("|cffff0000Error:|r Localization not loaded")
        return
    end

    self:Say(self.L["HELP_HEADER"])
    self:Say("|cffffffff/rnd|r - Open the options panel")
    self:Say(self.L["HELP_TEST"])
    self:Say(self.L["HELP_ENABLE"])
    self:Say(self.L["HELP_DISABLE"])
    self:Say(self.L["HELP_STATUS"])
    self:Say("|cffffffff/rnd welcome on|r - " .. (self.L["HELP_WELCOME_ON"] or "Enable welcome message"))
    self:Say("|cffffffff/rnd welcome off|r - " .. (self.L["HELP_WELCOME_OFF"] or "Disable welcome message"))
    self:Say("|cffffffff/rnd icon on|r - " .. (self.L["HELP_ICON_ON"] or "Show minimap icon"))
    self:Say("|cffffffff/rnd icon off|r - " .. (self.L["HELP_ICON_OFF"] or "Hide minimap icon"))
end

-- Show current status
function RND:ShowStatus()
    if not self.L then
        self:Say("|cffff0000Error:|r Localization not loaded")
        return
    end

    local on, off = self.L["ENABLED_STATUS"], self.L["DISABLED_STATUS"]
    self:Say(self.L["STATUS_HEADER"])
    self:Say(self.L["STATUS_STATUS"] .. " " .. (self:IsEnabled() and on or off))
    self:Say((self.L["STATUS_WELCOME"] or "Welcome message:") .. " " .. (self.db.showWelcome ~= false and on or off))
    self:Say((self.L["STATUS_MINIMAP"] or "Minimap icon:") .. " " .. (self.db.minimapIconEnabled ~= false and on or off))
    self:Say(string.format(self.L["STATUS_VERSION"], self.version))
end

-- Hook tooltip to prevent showing debuff tooltips from nameplates
local function HookTooltips()
    -- Hook main GameTooltip using OnShow to check the unit
    if GameTooltip then
        GameTooltip:HookScript("OnShow", function(self)
            if RND:IsEnabled() then
                -- Check if tooltip has a unit
                local _, unit = self:GetUnit()
                if unit and string.match(unit, "nameplate") then
                    self:Hide()
                    return
                end

                -- Check if owner is related to a nameplate
                local owner = self:GetOwner()
                if owner and owner:GetParent() then
                    local parent = owner:GetParent()
                    -- Check if the parent is a nameplate buff frame
                    if parent then
                        local parentName = parent:GetName()
                        if parentName and string.match(parentName, "NamePlate") then
                            self:Hide()
                            return
                        end
                        -- Also check if it's a unitframe from a nameplate
                        if parent.unit and string.match(parent.unit, "nameplate") then
                            self:Hide()
                            return
                        end
                    end
                end
            end
        end)
    end

    -- Hook NamePlateTooltip if it exists
    if NamePlateTooltip then
        NamePlateTooltip:HookScript("OnShow", function(self)
            if RND:IsEnabled() then
                self:Hide()
            end
        end)
    end

    -- Hook BuffTooltip if it exists (some addons use this)
    if BuffTooltip then
        BuffTooltip:HookScript("OnShow", function(self)
            if RND:IsEnabled() then
                local owner = self:GetOwner()
                if owner and owner:GetParent() then
                    local parent = owner:GetParent()
                    if parent and parent.unit and string.match(parent.unit, "nameplate") then
                        self:Hide()
                    end
                end
            end
        end)
    end
end

-- =====================================================================================
-- The addon
-- =====================================================================================

RGXAddon(ADDON_NAME, {
    table = RND,
    dbName = "RNDSettings",
    legacyFlat = true, -- players' existing flat settings become the Default profile
    db = {
        enabled = true,
        showWelcome = true,
        firstRun = true,
        minimapIconEnabled = true,
        minimapAngle = 220,
    },

    brand = "ff7d00",
    theme = { primary = { 1, 125 / 255, 0 }, accent = { 1, 0.82, 0 } },
    title = "Remove Nameplate Debuffs!",

    slash = { "rnd", handler = function(self, msg) self:HandleSlashCommand(msg) end },

    minimap = {
        name = "RND_MinimapButton",
        icon = MINIMAP_ICON_TEXTURE,
        defaultAngle = 220,
        angleKey = "minimapAngle",
        enabledKey = "minimapIconEnabled",
        tooltip = {
            title = "|cffff7d00R|r|cffffffffemove|r |cffff7d00N|r|cffffffffameplate|r |cffff7d00D|r|cffffffffebuffs|r|cffff7d00!|r",
            getLines = function()
                return {
                    { left = "|cffffffffStatus|r", right = RND:IsEnabled() and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r" },
                    { left = "|cffff7d00Left-Click|r", right = "|cffffffffOpen options|r" },
                    { left = "|cffff7d00Right-Click|r", right = "|cffffffffToggle debuff removal|r" },
                    { left = "|cff4ecdc4Left-Drag|r", right = "|cffffffffMove around minimap|r" },
                    { left = "|cffe74c3cCtrl+Right-Click|r", right = "|cffffffffHide minimap icon|r" },
                }
            end,
        },
        onRightClick = function() RND:SetEnabled(not RND:IsEnabled()) end,
        onCtrlRight = function()
            RND:SetMinimapShown(false)
            if RND.L then
                RND:Say(RND.L["MINIMAP_ICON_HIDDEN"] or "Minimap icon |cffff0000hidden|r. Use |cffffffff/rnd icon on|r to show it again.")
            end
        end,
        onVisibilityChanged = function() RND:RefreshPanel() end,
    },

    options = {
        General = {
            {
                page = "Settings",
                grid = 2,
                cards = {
                    {
                        card = "Behavior",
                        controls = {
                            { toggle = "enabled", label = "Remove nameplate debuffs",
                              onChange = function(self, enabled) self:ApplyEnabled(enabled) end },
                        },
                    },
                    {
                        card = "Interface",
                        controls = {
                            { toggle = "showWelcome", label = "Show welcome message" },
                            { toggle = "minimapIconEnabled", label = "Show minimap icon",
                              onChange = function(self, show) self:ApplyMinimap(show) end },
                        },
                    },
                },
            },
        },
    },

    on = {
        NAME_PLATE_UNIT_ADDED = function(self, unitId)
            if self:IsEnabled() then self:HideNameplateDebuffs(unitId) end
        end,
        login = function(self)
            self:DisplayWelcomeMessage()
            HookTooltips()
        end,
    },

    -- Continuously enforce removal on frames Blizzard creates later.
    every = {
        enforce = { 0.5, function(self)
            if self:IsEnabled() then self:HideAllNameplateDebuffs() end
        end },
    },
})
