-- RND behaviour against a mocked game and the framework's real database code:
--  * one RGXAddon declaration owns settings, options, /rnd, the minimap button, the nameplate event and the timer;
--  * a player's existing flat saved variables are adopted (disabled / hidden / silent preferences survive);
--  * enabling and disabling hides and restores the auras already on screen, from the panel, the minimap and /rnd;
--  * nothing is written to the framework's own saved variables (no second copy of the settings).
local FW = os.getenv("RGXFW_PATH") or "../RGX-Framework"
local function check(c, m) if not c then error("CHECK FAILED: " .. m, 2) end end
local function read(p) local f = assert(io.open(p)); local s = f:read("*a"); f:close(); return s end

local forever = io.open("RemoveNameplateDebuffs_Forever.toc") ~= nil
local name = forever and "RemoveNameplateDebuffs_Forever" or "RemoveNameplateDebuffs"
local sv = forever and "RNDForeverSettings" or "RNDSettings"
local toc = read(name .. ".toc")
check(toc:find("## SavedVariables: " .. sv, 1, true), "the TOC declares " .. sv)
check(not toc:find("options.lua", 1, true), "no separate options file: the declaration owns the panel")

-- Mocked game ----------------------------------------------------------------------------------------------
local function frame()
    local f = { alpha = 1, shown = true, scripts = {} }
    function f:SetAlpha(v) self.alpha = v end
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    function f:IsShown() return self.shown end
    function f:HookScript() end
    function f:SetScript(e, fn) self.scripts[e] = fn end
    function f:RegisterEvent() end
    function f:IsForbidden() return false end
    return f
end
local aura = frame()
local plate = { UnitFrame = { unit = "nameplate1", BuffFrame = aura, IsForbidden = function() return false end } }
_G.C_NamePlate = { GetNamePlateForUnit = function() return plate end, GetNamePlates = function() return { plate } end }
_G.C_AddOns = { GetAddOnMetadata = function(_, field) return field == "Version" and "v9.9.9" or nil end }
_G.GameTooltip = frame()
_G.SetCVar = function() end
_G.GetLocale = function() return "enUS" end
local said = {}
_G.print = function(m) said[#said + 1] = m end
_G.CreateFrame = function() return frame() end
_G.SlashCmdList = {}
_G.UnitName = function() return "Tester" end
_G.GetRealmName = function() return "Realm" end
_G.StaticPopup_Show = function() end

local contract
local afterCalls = {}
_G.RGXFramework = {
    RequireContract = function(_, ...) contract = { ... } return true end,
    After = function(_, delay, fn) afterCalls[#afterCalls + 1] = { delay, fn } end,
}
_G.RGXFrameworkDB = {}

local decl
_G.RGXAddon = function(addonName, opts)
    check(decl == nil, "exactly one declaration")
    decl = opts; opts.name = addonName
    return opts.table
end

-- Real framework database when its source is next to this repository (local runs). Addon CI has no framework
-- checkout, so there the settings are a plain table with defaults and the adoption checks are skipped; the
-- framework's own CI covers the migration (profile-persistence-check).
local DBRGX
do
    local f = io.open(FW .. "/core/systems/database.lua")
    if f then
        f:close()
        DBRGX = { _databases = {} }
        function DBRGX:Print() end function DBRGX:Error() end function DBRGX:Debug() end
        assert(loadfile(FW .. "/core/systems/database.lua"))("RGX-Framework", DBRGX)
    end
end
local function newDB(defaults, flat)
    if DBRGX then return DBRGX:NewDatabase(decl.dbName, defaults, { legacyFlat = decl.legacyFlat }) end
    return setmetatable({}, { __index = defaults })
end

local function boot(saved)
    decl, contract = nil, nil
    said, afterCalls = {}, {}
    aura.alpha, aura.shown = 1, true
    _G.RND = nil
    _G[sv] = saved
    for _, path in ipairs({ "data/locales.lua", "data/core.lua" }) do
        assert(loadfile(path))(name, {})
    end
    check(decl, "core.lua declares the addon")
    local RND = _G.RND
    RND.db = newDB(decl.db)
    RND.panel = { opened = 0, Open = function(self) self.opened = self.opened + 1 end,
                  InvalidateAllTabs = function() end, Refresh = function() end }
    local hidden = {}
    RND.minimapButton = { SetVisible = function(_, v) hidden[#hidden + 1] = v; RND.db.minimapIconEnabled = v end }
    return RND, hidden
end

-- Declaration shape -----------------------------------------------------------------------------------------
local RND, hidden = boot(nil)
check(contract and contract[1] == name and contract[2] == 1 and contract[3] == "2.19.0", "the contract handshake names 2.19.0")
check(decl.dbName == sv and decl.legacyFlat == true, "settings use the RGX database and adopt the old flat table")
check(decl.table == RND and RND.addonName == name, "the declaration wraps the RND table")
check(type(decl.slash) == "table" and decl.slash[1] == "rnd" and type(decl.slash.handler) == "function", "/rnd is declared")
check(decl.minimap.enabledKey == "minimapIconEnabled" and decl.minimap.angleKey == "minimapAngle" and decl.minimap.defaultAngle == 220,
    "the minimap button stores its angle and visibility in the settings")
check(type(decl.on.NAME_PLATE_UNIT_ADDED) == "function" and type(decl.on.login) == "function", "nameplate and login triggers are declared")
check(decl.every.enforce and decl.every.enforce[1] == 0.5, "the enforcement timer is declared")
check(RND.version == "9.9.9", "the version comes from the TOC")

local cards = decl.options.General[1].cards
local toggles = {}
for _, card in ipairs(cards) do for _, control in ipairs(card.controls) do toggles[control.toggle] = control end end
check(toggles.enabled and toggles.showWelcome and toggles.minimapIconEnabled, "the panel has all three settings")
check(type(toggles.enabled.onChange) == "function" and type(toggles.minimapIconEnabled.onChange) == "function",
    "enabling and the minimap icon take effect the moment they flip")
check(decl.db.enabled == true and decl.db.showWelcome == true and decl.db.minimapIconEnabled == true, "defaults: on, welcome, icon shown")

-- No second copy of the settings ---------------------------------------------------------------------------
local locales = read("data/locales.lua")
check(not locales:find("SETTINGS_RESTORED", 1, true), "no 'restored from backup' message")
local source = read("data/core.lua")
check(not source:find("Backup", 1, true) and not source:find("RGXAddonBackups", 1, true), "no backup code")
check(not source:find("RNDSettings = ", 1, true), "no hand-rolled settings table")

-- Adoption of a player's existing flat settings -------------------------------------------------------------
if DBRGX then
    RND = boot({ enabled = false, showWelcome = false, firstRun = false, minimapIconEnabled = false, minimapAngle = 100 })
    check(RND.db.enabled == false and RND.db.showWelcome == false and RND.db.minimapIconEnabled == false and RND.db.minimapAngle == 100,
        "disabled, silent and hidden preferences survive the move to the RGX database")
    check(_G[sv].profiles and _G[sv].profiles.Default.enabled == false, "they live in the Default profile")
    RND.db.enabled = true
    check(RND.db.enabled == true and _G[sv].profiles.Default.enabled == true, "later changes write the profile")

    -- The mixed table needs the framework release that applies flat choices once (raw.flatAdopted); an older
    -- published framework keeps the profile defaults, so that check waits for the release.
    local mixedFixed = read(FW .. "/core/systems/database.lua"):find("flatAdopted", 1, true) ~= nil
    if not mixedFixed then
        io.write("note: this framework predates the mixed-table migration; that check skipped\n")
    end
    if mixedFixed then
    -- The table the previous Forever build left behind: the player's choices flat, defaults in the Default profile.
    RND = boot({
        enabled = false, minimapIconEnabled = false, showWelcome = true, minimapAngle = 220, firstRun = false,
        global = {}, char = {}, activeProfile = "Default",
        profiles = { Default = { enabled = true, minimapIconEnabled = true, showWelcome = true, minimapAngle = 220,
                                 firstRun = true, currentProfile = "Default" } },
    })
    check(RND.db.enabled == false and RND.db.minimapIconEnabled == false and RND.db.firstRun == false,
        "a table with flat choices and default profiles keeps the player's choices")
    RND.db.enabled = true
    local reloaded = newDB(decl.db)
    check(reloaded.enabled == true, "a later edit survives the next session")
    end
else
    io.write("note: framework source not found (" .. FW .. "); settings-adoption checks skipped\n")
end

-- A real switch stores the new value, then calls onChange(addon, value).
local function flip(RND, key, value)
    RND.db[key] = value
    toggles[key].onChange(RND, value)
end

-- Hiding and restoring ---------------------------------------------------------------------------------------
RND, hidden = boot(nil)
decl.on.NAME_PLATE_UNIT_ADDED(RND, "nameplate1")
check(aura.alpha == 0 and not aura:IsShown(), "a new nameplate's auras are hidden while enabled")
RND:SetEnabled(false)
check(RND.db.enabled == false and aura.alpha == 1 and aura:IsShown(), "disabling stores the choice and restores the auras at once")
decl.on.NAME_PLATE_UNIT_ADDED(RND, "nameplate1")
check(aura.alpha == 1, "a new nameplate is left alone while disabled")
decl.every.enforce[2](RND)
check(aura.alpha == 1, "the timer leaves auras alone while disabled")
flip(RND, "enabled", true)
check(aura.alpha == 0, "the panel toggle hides the auras the moment it flips on")
decl.every.enforce[2](RND); check(aura.alpha == 0, "the timer keeps them hidden")
flip(RND, "enabled", false)
check(aura.alpha == 1 and aura:IsShown(), "the panel toggle restores them the moment it flips off")

-- Minimap ---------------------------------------------------------------------------------------------------
RND, hidden = boot(nil)
decl.minimap.onRightClick()
check(RND.db.enabled == false and aura.alpha == 1, "right-click toggles removal")
decl.minimap.onRightClick()
check(RND.db.enabled == true and aura.alpha == 0, "right-click toggles it back")
said = {}
decl.minimap.onCtrlRight()
check(RND.db.minimapIconEnabled == false and hidden[#hidden] == false and #said == 1, "Ctrl+right-click hides the icon and says how to bring it back")
flip(RND, "minimapIconEnabled", true)
check(hidden[#hidden] == true, "the panel toggle shows the button")
local lines = decl.minimap.tooltip.getLines()
check(lines[1].right:find("Enabled", 1, true), "the tooltip shows the status")

-- Slash -----------------------------------------------------------------------------------------------------
RND, hidden = boot(nil)
local function slash(text) decl.slash.handler(RND, text) end
slash(""); slash("options")
check(RND.panel.opened == 2, "/rnd and /rnd options open the panel")
slash("off"); check(RND.db.enabled == false and aura.alpha == 1, "/rnd off disables and restores")
slash("on"); check(RND.db.enabled == true and aura.alpha == 0, "/rnd on enables and hides")
slash("icon off"); check(RND.db.minimapIconEnabled == false and hidden[#hidden] == false, "/rnd icon off hides the button")
slash("icon on"); check(RND.db.minimapIconEnabled == true and hidden[#hidden] == true, "/rnd icon on shows it")
slash("welcome off"); check(RND.db.showWelcome == false, "/rnd welcome off")
slash("welcome on"); check(RND.db.showWelcome == true, "/rnd welcome on")
said = {}; slash("status"); check(#said >= 5, "/rnd status prints the settings")
said = {}; slash("help"); check(#said >= 9, "/rnd help lists the commands")
said = {}; slash("bogus"); check(#said == 1, "an unknown command is answered")
check(next(_G.RGXFrameworkDB) == nil, "nothing was written to the framework's saved variables")

-- Welcome -----------------------------------------------------------------------------------------------------
RND = boot({ showWelcome = true, firstRun = true })
said = {}; decl.on.login(RND)
check(#said == 3 and RND.db.firstRun == false, "login greets and shows the community message once")
said = {}; decl.on.login(RND)
check(#said == 2, "the community message does not repeat")
RND.db.showWelcome = false
said = {}; decl.on.login(RND)
check(#said == 0, "the welcome message can be silenced")
check(next(_G.RGXFrameworkDB) == nil, "still nothing in the framework's saved variables")

io.write("Rnd OK: " .. name .. "\n")
