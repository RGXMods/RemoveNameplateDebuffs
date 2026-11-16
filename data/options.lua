-- RND options use framework UI, brand and launcher owners. The existing flat
-- SavedVariables table is the sole settings owner; no second profile database.
local RND = assert(_G.RND, "RND: core.lua must load before options.lua")
local RGX = assert(_G.RGXFramework, "RND: RGX-Framework is required")

function RND:OpenOptions()
    if not self.panel then
        if not self.initialized then self:InitializeSettings() end
        local UI, Design = RGX:GetUI(), RGX:GetDesign()
        self.brand = Design:RegisterBrand(self.addonName, {
            primary = { 1, 125 / 255, 0 },
            accent = { 1, 0.82, 0 },
        }, "framework")
        self.panel = self.brand:Build(function()
            return UI:CreateOptionsPanel({
                addonName = self.addonName,
                addonBrand = self.brand,
                title = "Remove Nameplate Debuffs!" .. (self.addonName:find("_Forever", 1, true) and " (Forever)" or ""),
                icon = "Interface\\AddOns\\" .. self.addonName .. "\\media\\icon",
                version = self.version,
                hideTabRow = true,
                tabs = { { text = "Settings", content = function(page)
                    local storage = self:GetSettings()
                    page:Section("Behavior")
                    page:Toggle("Remove nameplate debuffs", storage, "enabled", true,
                        function(value) self:SetSetting("enabled", value) end)
                    page:Section("Feedback")
                    page:Toggle("Show welcome message", storage, "showWelcome", true,
                        function(value) self:SetSetting("showWelcome", value) end)
                    page:Toggle("Show minimap icon", storage, "minimapIconEnabled", true,
                        function(value) self:SetSetting("minimapIconEnabled", value) end)
                end } },
            })
        end)
    end
    self.panel:Open()
end
