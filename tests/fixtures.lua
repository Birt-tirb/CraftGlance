-- Panel behavior with a simulated Forever UI. Run from the repository root.
local addon, widgets, timers = {}, {}, {}
local recipe, ready, linked, npc = nil, true, false, false
local filtered, filterChanges, schematicReads = false, 0, 0
local bags, bank, unknown, bankOpen = 0, 4, false, false
local bankKnown, altBags, iconAvailable = true, 0, true
local inCombat = false
local positionUpdates = 0
local lastSearch
local function noop() end

local function widget(kind, name, parent)
    local frame = {kind = kind, parent = parent, shown = true, enabled = true, scripts = {}, events = {}}
    for _, key in ipairs({"SetJustifyH", "SetJustifyV", "SetFrameLevel", "SetBackdrop",
        "SetBackdropColor", "SetBackdropBorderColor", "SetAutoFocus", "SetMaxLetters",
        "SetHitRectInsets", "EnableMouseWheel", "EnableMouse", "ClearFocus", "SetTexCoord", "SetAllPoints"}) do frame[key] = noop end
    function frame:SetPoint(...) self.point = {...} end
    function frame:ClearAllPoints() self.point = nil end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetWidth(width) self.width = width end
    function frame:SetHeight(height) self.height = height end
    function frame:GetWidth() return self.width or 1200 end
    function frame:GetHeight() return self.height or 700 end
    function frame:GetLeft() return 100 end
    function frame:GetRight() return 1000 end
    function frame:GetEffectiveScale() return 1 end
    function frame:GetFrameLevel() return 1 end
    function frame:SetText(value)
        self.text = value
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    function frame:GetText() return self.text or "" end
    function frame:GetStringHeight() return 12 end
    function frame:SetFontObject(value) self.fontObject = value end
    function frame:SetTextColor(...) self.color = {...} end
    function frame:SetColorTexture(...) self.color = {...} end
    function frame:SetTexture(value) self.texture = value end
    function frame:GetAttribute(key) return self.attributes and self.attributes[key] end
    function frame:SetAttribute(key, value)
        self.attributes = self.attributes or {}
        self.attributes[key] = value
    end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:HookScript(event, callback)
        local previous = self.scripts[event]
        self.scripts[event] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetShown(shown)
        if self.shown == shown then return end
        local previous = {}
        for _, current in ipairs(widgets) do previous[current] = current:IsVisible() end
        self.shown = shown
        for _, current in ipairs(widgets) do
            local visible = current:IsVisible()
            if visible ~= previous[current] then
                local callback = current.scripts[visible and "OnShow" or "OnHide"]
                if callback then callback(current) end
            end
        end
    end
    function frame:Show() self:SetShown(true) end
    function frame:Hide() self:SetShown(false) end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function frame:SetEnabled(value) self.enabled = value end
    function frame:SetChecked(value) self.checked = value end
    function frame:GetChecked() return self.checked end
    function frame:SetScrollChild(child) self.scrollChild = child end
    function frame:SetVerticalScroll(value) self.scroll = value end
    function frame:GetVerticalScroll() return self.scroll or 0 end
    function frame:GetVerticalScrollRange() return 200 end
    function frame:CreateFontString() return widget("FontString", nil, self) end
    function frame:CreateTexture() return widget("Texture", nil, self) end
    function frame:Click()
        assert(self:IsVisible() and self.enabled, "Control must be available")
        if self.scripts.OnClick then self.scripts.OnClick(self) end
    end
    widgets[#widgets + 1] = frame
    if name then _G[name] = frame end
    return frame
end

function CreateFrame(kind, name, parent)
    local frame = widget(kind, name, parent)
    if kind == "CheckButton" then frame.Text = frame:CreateFontString() end
    return frame
end
function hooksecurefunc(object, method, callback)
    local previous = object[method]
    object[method] = function(...)
        local result = previous(...)
        callback(...)
        return result
    end
end
function GetServerTime() return 1000 end
function InCombatLockdown() return inCombat end
function SetUIPanelAttribute(frame, key, value) frame:SetAttribute("UIPanelLayout-" .. key, value) end
function UpdateUIPanelPositions() positionUpdates = positionUpdates + 1 end
SlashCmdList = {}
C_Timer = {After = function(_, callback) timers[#timers + 1] = callback end}
Enum = {CraftingReagentType = {Basic = 0, Optional = 1}}
C_Item = {
    GetItemInfo = function() return "Linen Cloth" end,
    GetItemIconByID = function() if iconAvailable then return 132911 end end,
}
C_TradeSkillUI = {
    IsTradeSkillReady = function() return ready end,
    IsTradeSkillLinked = function() return linked end,
    IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return npc end,
    GetRecipeSchematic = function(id)
        schematicReads = schematicReads + 1
        return {reagentSlotSchematics = {{reagentType = 0, required = true,
            quantityRequired = id == 3275 and 1 or 2, reagents = {{itemID = 2589}}}}}
    end,
    GetOnlyShowMakeableRecipes = function() return filtered end,
    SetOnlyShowMakeableRecipes = function(value) filtered, filterChanges = value, filterChanges + 1 end,
}
function addon.GetBagCount() if unknown then return nil end; return bags end
function addon.GetSources()
    return {
        {name = "Ari", realm = "Normal", isCurrent = true, location = "bags",
            count = addon.GetBagCount(), scanned = not unknown, live = true, updatedAt = 1000},
        {name = "Ari", realm = "Normal", isCurrent = true, location = "bank",
            count = bankKnown and bank or nil, scanned = bankKnown, updatedAt = 880},
        {name = "Bea", realm = "Normal", isCurrent = false, location = "bags",
            count = altBags, scanned = true, updatedAt = 820},
        {name = "Bea", realm = "Normal", isCurrent = false, location = "bank", scanned = false},
    }
end
function addon.GetMaterialList(query)
    lastSearch = query
    if query ~= "" and query ~= "linen" and query ~= "2589" then return {} end
    return {{name = "Linen Cloth", itemID = 2589, bags = addon.GetBagCount(), sources = addon.GetSources()}}
end
function addon.GetScanSummary()
    return {bankOpen = bankOpen, characterCount = 2, bank = {scanned = bankKnown, updatedAt = 880}}
end
assert(loadfile("CraftGlance/Materials.lua"))("CraftGlance", addon)
assert(loadfile("CraftGlance/Panel.lua"))("CraftGlance", addon)

local function flush()
    local attempts = 0
    while #timers > 0 do
        attempts = attempts + 1
        assert(attempts < 30, "Panel refresh must settle")
        table.remove(timers, 1)()
    end
end
local function event(name)
    for _, frame in ipairs(widgets) do
        if frame.events[name] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, name) end
    end
    flush()
end
local function expect(value, absent)
    local labels = {}
    for _, frame in ipairs(widgets) do
        if frame.kind == "FontString" and frame:IsVisible() and frame.text then labels[#labels + 1] = frame.text end
    end
    local output = table.concat(labels, "\n")
    assert(output:find(value, 1, true), "Missing visible text: " .. value .. "\n" .. output)
    if absent then assert(not output:find(absent, 1, true), "Unexpected visible text: " .. absent) end
end
local function control(caption)
    for _, frame in ipairs(widgets) do
        if frame.kind == "Button" and frame.text == caption then return frame end
    end
    error("No button " .. caption)
end
local function materialRow()
    for _, frame in ipairs(widgets) do
        if frame:IsVisible() and frame.itemID == 2589 and frame.cells then return frame end
    end
    error("No visible Linen Cloth row")
end
local function expectCells(need, bagCount, bankCount, altCount)
    local row = materialRow()
    for index, value in ipairs({need, bagCount, bankCount, altCount}) do
        assert(row.cells[index].text == value, "Unexpected material column " .. index .. ": " .. row.cells[index].text)
    end
    return row
end

event("ADDON_LOADED")
assert(not CraftGlancePanel, "Wait for the native profession window")
UIParent = widget("Frame")
UIParent:SetSize(1920, 1080)
ProfessionsFrame = widget("Frame", nil, UIParent)
ProfessionsFrame:SetAttribute("UIPanelLayout-extraWidth", 17)
local page, form = widget("Frame", nil, ProfessionsFrame), nil
form = widget("Frame", nil, page)
ProfessionsFrame.CraftingPage, page.SchematicForm = page, form
function form:GetRecipeInfo() return recipe end
local nativeSelections = 0
function form:Init(value) nativeSelections = nativeSelections + 1; recipe = value end
local create, createAll = widget("Button", nil, page), widget("Button", nil, page)
local createHandler = function() end
create:SetScript("OnClick", createHandler)
createAll:SetScript("OnClick", createHandler)

event("TRADE_SKILL_SHOW")
expect("Select a recipe")
assert(not control("This Recipe").enabled and control("All Materials").enabled, "Default to This Recipe")
assert(CraftGlancePanel.point[2] == ProfessionsFrame, "Dock beside the profession window")
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 360 + 55,
    "Reserve native layout space for the expanded profession attachment")
BankFrame = widget("Frame", nil, UIParent)
function BankFrame:GetRight() return 1200 end
event("BANKFRAME_OPENED")
assert(CraftGlancePanel.point[1] == "TOPLEFT" and CraftGlancePanel.point[2] == ProfessionsFrame
    and CraftGlancePanel.point[3] == "TOPRIGHT", "Opening the bank keeps the profession attachment stable")
BankFrame:Hide()
event("BANKFRAME_CLOSED")
assert(CraftGlancePanel.point[1] == "TOPLEFT" and CraftGlancePanel.point[2] == ProfessionsFrame,
    "Return beside the profession when the bank closes")
form:Init({recipeID = 3275, name = "Linen Bandage", learned = true})
flush()
expect("Craft now: 0")
expect("Materials in your bags only")
local material = expectCells("1", "0", "4", "?")
assert(material.title.text == "Linen Cloth" and material.icon.texture == 132911,
    "Show the native item icon and a separate material name")
assert(material.cells[2].color[1] == 1, "Insufficient bag stock has the shortage color")
expect("Your bank: 4 (2m ago)")
expect("Next craft  #1")
expect("Pick up 1 Linen Cloth from your bank.")
expect("Bea - bank: not scanned")
assert(filterChanges == 0, "Reading recipes must preserve the native filter")

bags, bank, bankOpen = 2, 2, true
addon.InventoryChanged()
flush()
expect("Craft now: 2")
expect("Bank open - live counts")
expectCells("1", "2", "2", "?")
assert(materialRow().cells[2].color[1] == 0.48, "Sufficient bags have the ready color")
expect("Your bank: 2")
expect("Next craft  #3")
altBags = 3
addon.InventoryChanged()
flush()
expectCells("1", "2", "2", "3+")
expect("Bea - bags: 3 (3m ago)")
bankKnown, bankOpen = false, false
addon.InventoryChanged()
flush()
expectCells("1", "2", "?", "3+")
expect("Your bank: not scanned")
expect("Open your bank to scan it")
bankKnown = true
addon.InventoryChanged()
flush()
control("All Materials"):Click()
local search, filter
for _, frame in ipairs(widgets) do
    if frame.kind == "EditBox" then search = frame end
    if frame.kind == "CheckButton" then filter = frame end
end
search:SetText("linen")
flush()
assert(lastSearch == "linen", "Search text reaches inventory")
expect("Find your materials")
expectCells("-", "2", "2", "3+")
search:SetText("absent")
flush()
expect("No recorded material matches.", "Your bank: 2")

form:Init({recipeID = 3276, name = "Heavy Linen Bandage", learned = true})
flush()
expect("Heavy Linen Bandage")
expect("Craft now: 1", "No recorded material matches.")
assert(nativeSelections == 2 and not control("This Recipe").enabled, "Preserve selection and restore recipe view")
unknown = true
addon.InventoryChanged()
flush()
expect("Check reagent choices")
expectCells("2", "?", "2", "3+")
control("All Materials"):Click()
search:SetText("2589")
flush()
expectCells("-", "?", "2", "3+")
iconAvailable = false
addon.InventoryChanged()
flush()
assert(materialRow().icon.texture == 134400, "An uncached icon uses the game fallback")

control("-"):Click()
assert(CraftGlancePanel:GetHeight() == 36 and not search:IsVisible() and not filter:IsVisible())
assert(CraftGlancePanel:GetWidth() == 184 and ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 184 + 55,
    "Collapse reserves only the compact attachment width")
assert(not control("This Recipe"):IsVisible(), "Collapse hides contents")
control("+"):Click()
expectCells("-", "?", "2", "3+")
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 360 + 55)
filter:SetChecked(true)
filter:Click()
flush()
assert(filtered and filterChanges == 1, "An explicit filter click delegates to the native API")
filtered = false
event("TRADE_SKILL_LIST_UPDATE")
assert(not filter:GetChecked() and filterChanges == 1, "Mirror native menu changes")

control("This Recipe"):Click()
linked = true
event("TRADE_SKILL_DATA_SOURCE_CHANGED")
expect("Open your own profession to compare materials.")
assert(not filter:IsVisible())
linked, npc = false, true
event("TRADE_SKILL_DATA_SOURCE_CHANGED")
expect("Open your own profession to compare materials.")
npc, ready = false, false
local previousReads = schematicReads
event("TRADE_SKILL_DATA_SOURCE_CHANGED")
expect("Waiting for your profession's recipes.")
assert(schematicReads == previousReads, "Avoid schematics while the profession loads")
ready, unknown = true, false
page:Hide()
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17, "Hiding restores the original native reservation")
page:Show()
flush()
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 360 + 55,
    "Reopening restores the attachment reservation")
assert(positionUpdates > 0, "Update the native panel layout after reservation changes")
inCombat = true
page:Hide()
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 360 + 55,
    "Defer protected layout changes during combat")
inCombat = false
event("PLAYER_REGEN_ENABLED")
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17,
    "Restore the original reservation after combat even while the profession stays hidden")
page:Show()
flush()
assert(not control("This Recipe").enabled and control("All Materials").enabled)
assert(create.scripts.OnClick == createHandler and createAll.scripts.OnClick == createHandler,
    "Native Create and Create All keep their handlers")
print("CraftGlance panel selection, inventory, search and native controls passed")
