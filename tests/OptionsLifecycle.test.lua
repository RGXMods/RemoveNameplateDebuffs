-- Real addon lifecycle, framework events/timers/minimap/compartment and bound
-- toggle controls. Options shell, game frames and brand renderer are mocked.
local FW = os.getenv("RGXFW_PATH") or "../RGX-Framework"
local ROOT = os.getenv("RND_SOURCE_ROOT") or "."
local function read(p)
    local f = assert(io.open(p)); local s = f:read("*a"); f:close(); return s
end
local f = io.open(ROOT .. "/RemoveNameplateDebuffs_Forever.toc")
local forever = f ~= nil
if f then f:close() end
local name = forever and "RemoveNameplateDebuffs_Forever" or "RemoveNameplateDebuffs"
local key = forever and "RNDForeverSettings" or "RNDSettings"
local function copy(t)
    if type(t) ~= "table" then return t end
    local out = {}; for k, v in pairs(t) do out[k] = copy(v) end; return out
end
local function noop() end
local function boot(saved, backup)
    local env = setmetatable({}, { __index = _G }); env._G = env
    local methods = {}
    local frame
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:HookScript(event, fn)
        local previous = self.scripts[event]
        self.scripts[event] = function(...) if previous then previous(...) end; fn(...) end
    end
    function methods:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function methods:Hide() self.shown = false end
    function methods:IsShown() return self.shown end
    function methods:GetParent() return self.parent end
    function methods:GetCenter() return 0, 0 end
    function methods:GetWidth() return rawget(self, "width") or 120 end
    function methods:GetHeight() return rawget(self, "height") or 20 end
    function methods:GetScale() return 1 end
    methods.GetEffectiveScale, methods.GetFrameLevel = methods.GetScale, methods.GetScale
    function methods:SetWidth(v) self.width = v end
    function methods:SetHeight(v) self.height = v end
    function methods:SetSize(w, h) self.width, self.height = w, h end
    function methods:SetChecked(v) self.checked = v end
    function methods:GetChecked() return self.checked end
    function methods:SetAlpha(v) self.alpha = v end
    function methods:IsForbidden() return false end
    function methods:CreateTexture() return frame(self) end
    function methods:CreateFontString() return frame(self) end
    frame = function(parent)
        return setmetatable({ parent = parent, scripts = {}, shown = true, alpha = 1 }, {
            __index = function(_, k)
                if type(k) == "string" and (k:sub(1, 1) == "_" or k == "icon" or k == "ring" or k == "backgroundTexture") then return nil end
                if methods[k] then return methods[k] end
                if type(k) == "string" and k:match("^[A-Z]") then return noop end
                return nil
            end,
        })
    end
    env.CreateFrame = function(_, n, parent)
        local made = frame(parent); if n then env[n] = made end; return made
    end
    env.UIParent, env.Minimap = frame(), frame()
    env.GameTooltip = frame(); env.GameTooltip.shown = false
    env.SlashCmdList = {}
    env.GetLocale = function() return "enUS" end
    env.IsControlKeyDown, env.InCombatLockdown = function() return false end, function() return false end
    env.GetTimePreciseSec = function() return 0 end
    local messages, errors, menu = {}, {}, {}
    env.print = function(message) messages[#messages + 1] = message end
    env.geterrorhandler = function() return function(err) errors[#errors + 1] = err end end
    env.AddonCompartmentFrame = { RegisterAddon = function(_, data) menu[#menu + 1] = data end }
    local aura = frame()
    local plate = { UnitFrame = { unit = "nameplate1", BuffFrame = aura, IsForbidden = function() return false end } }
    env.C_NamePlate = {
        GetNamePlateForUnit = function() return plate end,
        GetNamePlates = function() return { plate } end,
    }
    local UI, modules, slash, globalDB = {}, {}, nil, copy(backup) or {}
    local Design = { Unpack = function() return 1, 0.5, 0 end }
    function Design:RegisterBrand(_, colors)
        return { Build = function(_, fn) return fn() end, colors = colors }
    end
    local RGX = {
        eventFrame = frame(), API = { CanAccessValue = function() return true end, CanAccessTable = function() return true end },
        RegisterModule = function(_, n, m) modules[n] = m end,
        GetMinimap = function() return modules.minimap end,
        GetUI = function() return UI end,
        GetDesign = function() return Design end,
        GetDB = function() return globalDB end,
        RegisterSlashCommand = function(_, _, fn) slash = fn end,
        Print = noop, Debug = noop, Error = function(_, err) errors[#errors + 1] = err end,
    }
    env.RGXFramework = RGX
    local function load(text, path, ...)
        local chunk = assert(loadstring(text, "@" .. path)); setfenv(chunk, env); return chunk(...)
    end
    for _, file in ipairs({ "core/systems/runtime.lua", "core/systems/events.lua", "libraries/minimap/minimap.lua" }) do
        load(read(FW .. "/" .. file), file, "RGX-Framework", RGX)
    end
    load(read(FW .. "/libraries/ui/controls.lua"), "real-controls", "RGX-Framework", UI)
    local rows, opened = {}, 0
    function UI:CreateOptionsPanel(opts)
        local panel, page = {}, {}
        function page:Section() end
        function page:Toggle(label, storage, field, default, change)
            rows[field] = UI:CreateToggle(env.UIParent, {
                label = label, storage = storage, key = field, default = default, onChange = change,
            })
        end
        function panel:Open() opened = opened + 1; self:Refresh() end
        function panel:InvalidateAllTabs() self.dirty = true end
        function panel:Refresh()
            if not self.built or self.dirty then
                opts.tabs[1].content(page); self.built, self.dirty = true, false
            end
        end
        return panel
    end
    env[key] = copy(saved)
    -- Old source's declarative wrapper is intentionally not a fake working
    -- panel: the regression must still fail when no launcher/flat owner exists.
    env.RGXAddon = noop
    for line in read(ROOT .. "/" .. name .. ".toc"):gmatch("[^\r\n]+") do
        if not line:match("^%s*#") and line:match("%.lua%s*$") then
            local path = line:gsub("\\", "/"):gsub("%s+$", "")
            load(read(ROOT .. "/" .. path), path, name, {})
        end
    end
    RGX:FireEvent("ADDON_LOADED", name)
    RGX:FireEvent("PLAYER_LOGIN")
    local addon = env.RND
    return {
        env = env, addon = addon, aura = aura, menu = menu, errors = errors,
        messages = messages, backup = globalDB, slash = function(msg) env.SlashCmdList.RND(msg) end,
        opened = function() return opened end,
        click = function(field, value)
            local row = assert(rows[field], "missing option " .. field)
            row.check:SetChecked(value); row.check.scripts.OnClick(row.check)
        end,
    }
end

local test = boot({ enabled = false, showWelcome = false, firstRun = false, minimapIconEnabled = false })
assert(#test.errors == 0, table.concat(test.errors, "\n"))
assert(type(test.addon.OpenOptions) == "function", "settings have a callable launcher")
assert(#test.menu == 1 and not test.addon.minimapButton.frame:IsShown(), "hidden icon still has one real framework compartment entry")
test.menu[1].func(nil, { buttonName = "LeftButton" })
assert(test.opened() == 1 and test.addon:GetSetting("enabled") == false, "compartment opens settings without enabling suppression")
test.click("enabled", true)
assert(test.aura.alpha == 0 and test.env[key].enabled == true, "panel enabling reaches suppression and SavedVariables")
test.click("enabled", false)
assert(test.aura.alpha == 1 and test.aura:IsShown(), "panel disabling immediately restores visible auras")
assert(test.backup.RGXAddonBackups[name].enabled == false, "panel edits update durable backup too")
test.click("minimapIconEnabled", true)
assert(test.addon.minimapButton.frame:IsShown(), "panel shows the minimap button")
test.click("minimapIconEnabled", false)
assert(not test.addon.minimapButton.frame:IsShown() and #test.menu == 1, "hiding icon keeps options accessible from menu")
local count = #test.messages
test.click("showWelcome", false); test.addon:DisplayWelcomeMessage()
assert(#test.messages == count, "panel can silence welcome output")
test.slash(""); test.slash("options")
assert(test.opened() == 3, "both slash launchers open settings")
test.menu[1].func(nil, { buttonName = "RightButton" })
assert(test.addon:GetSetting("enabled") == true and test.aura.alpha == 0, "right-click preserves quick toggle")
test.addon.minimapButton.frame.scripts.OnClick(test.addon.minimapButton.frame, "LeftButton")
assert(test.opened() == 4, "actual minimap click opens options")
test.click("enabled", false)
local reload = boot(test.env[key])
assert(reload.addon:GetSetting("enabled") == false and reload.addon:GetSetting("showWelcome") == false
    and reload.addon:GetSetting("minimapIconEnabled") == false, "flat false values survive a new session")
local recovered = boot({ activeProfile = "Old", profiles = { Old = { enabled = false, showWelcome = false } } })
assert(recovered.addon:GetSetting("enabled") == false and recovered.addon:GetSetting("showWelcome") == false,
    "profile-only preferences recover when flat values are absent")
local explicit = boot({ enabled = false, activeProfile = "Old", profiles = { Old = { enabled = true } } })
assert(explicit.addon:GetSetting("enabled") == false and explicit.env[key].profiles.Old.enabled == true,
    "explicit flat false wins without deleting old profile data")
assert(test.addon:SetSetting("enabled", "Off") == false, "invalid types cannot corrupt a setting")
local backed = boot(nil, { RGXAddonBackups = { [name] = {
    enabled = false, minimapIconEnabled = false, showWelcome = false, firstRun = false,
} } })
assert(backed.addon:GetSetting("enabled") == false and backed.addon:GetSetting("minimapIconEnabled") == false,
    "existing backup recovery still preserves disabled and hidden preferences")
for _, session in ipairs({ test, reload, recovered, explicit, backed }) do
    assert(#session.errors == 0, table.concat(session.errors, "\n"))
end
print("OptionsLifecycle OK: " .. name)
