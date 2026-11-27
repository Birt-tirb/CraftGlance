-- Panel behavior with a simulated Forever UI. Run from the repository root.
local addon, widgets, timers = {}, {}, {}
local recipe, ready, linked, npc = nil, true, false, false
local filtered, filterChanges, schematicReads = false, 0, 0
local bags, bank, unknown, bankOpen = 0, 4, false, false
local bankKnown, altBags, iconAvailable = true, 0, true
local altBankKnown, altBank = false, 0
local bankStale, altBankStale, altBagsStale = false, false, false
local inCombat = false
local positionUpdates = 0
local lastSearch
local materialMetadataReady = true
local extraOwners, secondBags = 0, 0
local function noop() end
local cornerNames = {"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner"}
local atlasInfo = {}
for _, name in ipairs({"Profession-Background-Overview", "Profession-Background-Template2"}) do
    atlasInfo[name] = {file = "FixtureBackground", width = 800, height = 1000,
        leftTexCoord = 0.125, rightTexCoord = 0.375, topTexCoord = 0.25, bottomTexCoord = 0.75}
end
for _, name in ipairs(cornerNames) do
    atlasInfo["Fixture" .. name] = {file = "FixtureBorder", width = 64,
        height = name:find("Top", 1, true) and 64 or 32,
        leftTexCoord = 0.125, rightTexCoord = 0.375, topTexCoord = 0.25, bottomTexCoord = 0.75}
end

local function widget(kind, name, parent)
    local frame = {kind = kind, parent = parent, shown = true, enabled = true, scripts = {}, events = {}, points = {}}
    for _, key in ipairs({"SetJustifyH", "SetJustifyV", "SetFrameLevel", "SetBackdrop",
        "SetBackdropColor", "SetBackdropBorderColor", "SetAutoFocus", "SetMaxLetters",
        "SetHitRectInsets", "EnableMouse", "ClearFocus", "SetAllPoints", "SetHorizTile", "SetVertTile"}) do frame[key] = noop end
    function frame:SetPoint(...)
        local point = {...}
        self.point = point
        local relative, y = self.parent, 0
        if type(point[2]) == "table" then
            relative = point[2]
            y = point[5] or 0
        elseif type(point[2]) == "number" then
            y = point[3] or 0
        end
        self.points[point[1]] = {relative = relative, y = y}
    end
    function frame:ClearAllPoints() self.point, self.points = nil, {} end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetClipsChildren(value) self.clipsChildren = value end
    function frame:SetWidth(width) self.width = width end
    function frame:SetHeight(height) self.height = height end
    function frame:GetWidth() return self.width or 1200 end
    function frame:GetHeight()
        if self.height then return self.height end
        local top = self.points.TOPLEFT or self.points.TOPRIGHT or self.points.TOP
        local bottom = self.points.BOTTOMLEFT or self.points.BOTTOMRIGHT or self.points.BOTTOM
        if top and bottom and top.relative == bottom.relative and top.relative then
            return math.max(0, top.relative:GetHeight() + top.y - bottom.y)
        end
        return 700
    end
    function frame:GetParent() return self.parent end
    function frame:SetParent(parent) self.parent = parent end
    function frame:GetLeft() return 100 end
    function frame:GetRight() return 1000 end
    function frame:GetEffectiveScale() return 1 end
    function frame:GetFrameLevel() return 1 end
    function frame:SetID(value) self.id = value end
    function frame:GetID() return self.id end
    function frame:SetText(value)
        self.text = value
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    function frame:GetText() return self.text or "" end
    function frame:GetStringHeight() return 12 end
    function frame:SetMaxLines(value) self.maxLines = value end
    function frame:SetWordWrap(value) self.wordWrap = value end
    function frame:SetNonSpaceWrap(value) self.nonSpaceWrap = value end
    function frame:SetFontObject(value) self.fontObject = value end
    function frame:SetFont(...) self.font = {...}; return true end
    function frame:GetFont() return unpack(self.font or {"Fonts\\FRIZQT__.TTF", 14, ""}) end
    function frame:SetTextColor(...) self.color = {...} end
    function frame:SetColorTexture(...) self.color = {...} end
    function frame:SetTexture(value) self.texture = value end
    function frame:SetAtlas(value) self.atlas = value end
    function frame:GetAtlas() return self.atlas end
    function frame:SetTexCoord(...) self.texCoord = {...} end
    function frame:GetAttribute(key) return self.attributes and self.attributes[key] end
    function frame:SetAttribute(key, value)
        self.attributes = self.attributes or {}
        self.attributes[key] = value
    end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:GetScript(event) return self.scripts[event] end
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
    function frame:SetVerticalScroll(value)
        local offset = math.max(0, math.min(value, self:GetVerticalScrollRange()))
        if offset == self:GetVerticalScroll() then return end
        self.scroll = offset
        if self.scripts.OnVerticalScroll then self.scripts.OnVerticalScroll(self, offset) end
    end
    function frame:GetVerticalScroll() return self.scroll or 0 end
    function frame:GetVerticalScrollRange()
        return self.scrollChild and math.max(0, self.scrollChild:GetHeight() - self:GetHeight()) or 0
    end
    function frame:UpdateScrollChildRect() end
    function frame:EnableMouseWheel(value) self.mouseWheel = value end
    function frame:Wheel(delta)
        assert(self:IsVisible() and self.mouseWheel and self.scripts.OnMouseWheel,
            "Visible reagent rows must handle the mouse wheel")
        self.scripts.OnMouseWheel(self, delta)
    end
    function frame:CreateFontString(_, _, style)
        local label = widget("FontString", nil, self)
        label.fontObject = style
        return label
    end
    function frame:CreateTexture() return widget("Texture", nil, self) end
    function frame:Click()
        assert(self:IsVisible() and self.enabled, "Control must be available")
        if self.scripts.OnClick then self.scripts.OnClick(self) end
    end
    widgets[#widgets + 1] = frame
    if name then _G[name] = frame end
    return frame
end

function CreateFrame(kind, name, parent, template)
    local frame = widget(kind, name, parent)
    frame.template = template
    if kind == "CheckButton" then frame.Text = frame:CreateFontString() end
    if template == "DefaultPanelTemplate" then
        frame.TitleContainer = widget("Frame", nil, frame)
        frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
        frame.Bg = frame:CreateTexture()
        frame.TopTileStreaks = frame:CreateTexture()
        frame.NineSlice = widget("Frame", nil, frame)
        for _, name in ipairs(cornerNames) do frame.NineSlice[name] = frame.NineSlice:CreateTexture() end
    elseif template == "PanelTopTabButtonTemplate" then
        frame.Text = frame:CreateFontString()
    elseif template == "UIPanelScrollFrameTemplate" then
        frame.ScrollBar = widget("Slider", nil, frame)
    end
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
function SetTextureWithAddressModeOptions(texture, value) texture:SetTexture(value) end
C_Texture = {GetAtlasInfo = function(atlas) return assert(atlasInfo[atlas], "Unknown fixture atlas") end}
NineSliceUtil = {}
function NineSliceUtil.ApplyLayoutByName(frame, name)
    assert(name == "ButtonFrameTemplateNoPortrait", "Use the native profession border layout")
    for _, key in ipairs(cornerNames) do
        local piece, atlas = frame[key], "Fixture" .. key
        local info = C_Texture.GetAtlasInfo(atlas)
        piece:SetAtlas(atlas); piece:SetTexture(info.file); piece:SetSize(info.width, info.height)
        piece:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
        piece:ClearAllPoints()
        local upper = key:find("Top", 1, true)
        piece:SetPoint(key:upper():gsub("CORNER", ""), frame, key:upper():gsub("CORNER", ""),
            key:find("Left", 1, true) and -8 or 8, upper and 16 or -8)
    end
end
function PanelTemplates_TabResize(frame, _, width) frame:SetWidth(width) end
function PanelTemplates_SelectTab(frame) frame:SetEnabled(false) end
function PanelTemplates_DeselectTab(frame) frame:SetEnabled(true) end
function ScrollFrame_OnScrollRangeChanged(frame, _, verticalRange)
    frame.ScrollBar:SetShown(not frame.scrollBarHideable or verticalRange > 0)
end
GameTooltip = {lines = {}, shown = false}
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:IsOwned(frame) return self.owner == frame end
function GameTooltip:IsShown() return self.shown end
function GameTooltip:SetCurrencyByID(id) self.lines = {"Currency " .. id} end
function GameTooltip:SetText(value) self.lines = {value} end
function GameTooltip:AddLine(value) self.lines[#self.lines + 1] = value end
function GameTooltip:SetItemByID(itemID) self.itemID = itemID; self.lines = {"Item " .. itemID} end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false end
SlashCmdList = {}
C_Timer = {After = function(_, callback) timers[#timers + 1] = callback end}
Enum = {CraftingReagentType = {Basic = 0, Optional = 1}}
C_Item = {
    GetItemInfo = function(itemID) return itemID == 2592 and "Wool Cloth" or "Linen Cloth" end,
    GetItemIconByID = function() if iconAvailable then return 132911 end end,
}
C_TradeSkillUI = {
    IsTradeSkillReady = function() return ready end,
    IsTradeSkillLinked = function() return linked end,
    IsTradeSkillGuild = function() return false end,
    IsNPCCrafting = function() return npc end,
    GetRecipeSchematic = function(id)
        schematicReads = schematicReads + 1
        if id == 9999 then
            return {reagentSlotSchematics = {
                {reagentType = 0, required = true, quantityRequired = 1, reagents = {{itemID = 2589}}},
                {reagentType = 0, required = true, quantityRequired = 1, reagents = {{itemID = 2592}}},
            }}
        end
        return {reagentSlotSchematics = {{reagentType = 0, required = true,
            quantityRequired = id == 3275 and 1 or 2, reagents = {{itemID = 2589}}}}}
    end,
    GetOnlyShowMakeableRecipes = function() return filtered end,
    SetOnlyShowMakeableRecipes = function(value) filtered, filterChanges = value, filterChanges + 1 end,
}
function addon.GetBagCount(itemID)
    if unknown then return nil end
    return itemID == 2592 and secondBags or bags
end
function addon.GetSources(itemID)
    local sources = {
        {guid = "Player-A", name = "Ari", realm = "Normal", isCurrent = true, location = "bags",
            count = addon.GetBagCount(itemID), scanned = not unknown, live = true, updatedAt = 1000},
        {guid = "Player-A", name = "Ari", realm = "Normal", isCurrent = true, location = "bank",
            count = bankKnown and bank or nil, scanned = bankKnown, stale = bankStale, updatedAt = 880},
        {guid = "Player-B", name = "Bea", realm = "Normal", isCurrent = false, location = "bags",
            count = altBags, scanned = true, stale = altBagsStale, updatedAt = 820},
        {guid = "Player-B", name = "Bea", realm = "Normal", isCurrent = false, location = "bank",
            count = altBankKnown and altBank or nil, scanned = altBankKnown, stale = altBankStale, updatedAt = 760},
    }
    for index = 1, extraOwners do
        sources[#sources + 1] = {guid = "Player-Extra" .. index, name = "Alt" .. index,
            realm = "Normal", isCurrent = false, location = "bags", count = 1, scanned = true, updatedAt = 700}
    end
    return sources
end
function addon.GetMaterialList(query)
    lastSearch = query
    if not materialMetadataReady then return {} end
    if query ~= "" and query ~= "linen" and query ~= "2589" then return {} end
    return {{name = "Linen Cloth", itemID = 2589, bags = addon.GetBagCount(), sources = addon.GetSources()}}
end
function addon.GetScanSummary()
    return {bankOpen = bankOpen, characterCount = 2 + extraOwners,
        bank = {scanned = bankKnown, stale = bankStale, updatedAt = 880}}
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
local function dispatch(name, ...)
    for _, frame in ipairs(widgets) do
        if frame.events[name] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, name, ...) end
    end
end
local function event(name, ...)
    dispatch(name, ...)
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
    for _, removed in ipairs({"Next craft", "Pick up ", "Get 1 "}) do
        assert(not output:find(removed, 1, true), "Obsolete pickup instruction: " .. removed)
    end
end
local function control(caption)
    for _, frame in ipairs(widgets) do
        if frame.kind == "Button" and frame.text == caption then return frame end
    end
    error("No button " .. caption)
end
local function materialRow(itemID)
    itemID = itemID or 2589
    for _, frame in ipairs(widgets) do
        if frame:IsVisible() and frame.itemID == itemID and frame.cardTop then return frame end
    end
    error("No visible material row for " .. itemID)
end
local function expectOwner(name, bagCount, bankCount, itemID)
    local row = materialRow(itemID)
    for _, owner in ipairs(widgets) do
        if owner.parent == row and owner.holding and owner:IsVisible() and owner.owner.text == name then
            assert(owner.bags.text == bagCount, name .. " bag stock: " .. tostring(owner.bags.text))
            assert(owner.bank.text == bankCount, name .. " bank stock: " .. tostring(owner.bank.text))
            return owner
        end
    end
    error("Missing owner " .. name)
end
local function expectTooltip(owner, ...)
    owner.scripts.OnEnter(owner)
    local contents = table.concat(GameTooltip.lines, "\n")
    assert(GameTooltip.shown and GameTooltip.owner == owner, "Hover shows source details")
    for _, value in ipairs({...}) do
        assert(contents:find(value, 1, true), "Missing tooltip detail: " .. value .. "\n" .. contents)
    end
    owner.scripts.OnLeave(owner)
    assert(not GameTooltip.shown, "Leaving the row hides source details")
end
local function expectFits()
    assert(CraftGlanceScroll:GetVerticalScrollRange() == 0, "Short material lists fit without scrolling")
    assert(not CraftGlanceScroll.ScrollBar:IsVisible(), "Hide the scrollbar when all materials fit")
    assert(CraftGlancePanel:GetHeight() < ProfessionsFrame:GetHeight() - 45,
        "Short material lists shrink the attachment below the full profession height")
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
assert(CraftGlancePanel.template == "DefaultPanelTemplate"
    and CraftGlancePanel.TitleText == CraftGlancePanel.TitleContainer.TitleText,
    "Use the native profession frame and its title container")
assert(control("This Recipe").template == "PanelTopTabButtonTemplate", "Use native profession-style tabs")
assert(CraftGlancePanel.point[2] == ProfessionsFrame, "Dock beside the profession window")
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 400 + 55,
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
expect("From your bags only")
expect("Known stock: 4 crafts")
expect("Banks / alts need scanning")
local material = materialRow()
assert(material.requirement.text == "1")
local ownStock = expectOwner("You", "0", "4")
expectOwner("Bea", "0", "Not scanned")
assert(material.title.text == "Linen Cloth" and material.icon.texture == 132911,
    "Show the native item icon and a separate material name")
assert(material.icon:GetWidth() == 20 and material.title.fontObject == "GameFontNormal"
    and not material.title.wordWrap and not material.title.nonSpaceWrap,
    "Use a compact reagent icon with a single-line material name")
assert(ownStock.point[2] == 180 and ownStock.point[3] + ownStock.owner.point[3] == material.title.point[3],
    "The first character and material name share the same horizontal line")
for _, separator in ipairs({material.cardTop, material.cardBottom}) do
    assert(separator:IsVisible() and separator:GetHeight() == 1, "Material cards have visible divider lines")
end
local tableHeader
for _, frame in ipairs(widgets) do
    if frame.kind == "FontString" and frame.text == "Material" then tableHeader = frame.parent end
end
assert(tableHeader and tableHeader:IsVisible() and tableHeader.divider:IsVisible()
    and not material.headers and not material.headerDivider,
    "Use one sticky table header instead of repeated headers in each material")
assert(not ownStock.divider:IsVisible() and expectOwner("Bea", "0", "Not scanned").divider:IsVisible(),
    "Draw an owner divider only between character rows")
assert(ownStock.bags.color[1] == 1, "Insufficient bag stock has the shortage color")
expectTooltip(ownStock, "You - Ari", "Bags: 0 (live)", "Bank: 4 (2m ago)")
expect("Missing: 1", "Bank: 4 (2m ago)")
assert(filterChanges == 0, "Reading recipes must preserve the native filter")
expectFits()
CraftGlanceScroll:SetVerticalScroll(0)
material:Wheel(-1)
assert(CraftGlanceScroll:GetVerticalScroll() == 0, "Wheeling a list that fits does not move it")

bags, bank, bankOpen = 2, 2, true
addon.InventoryChanged()
flush()
expect("Craft now: 2")
expect("Your bank: live")
ownStock = expectOwner("You", "2", "2")
assert(ownStock.bags.color[1] == 0.48, "Sufficient bags have the ready color")
assert(not materialRow().note:IsVisible(), "Hide the shortage note once one craft is covered")
altBags = 9
addon.InventoryChanged()
flush()
expectOwner("You", "2", "2")
expectOwner("Bea", "9", "Not scanned")
expect("Known stock: 13 crafts")
expectTooltip(expectOwner("Bea", "9", "Not scanned"), "Bea", "Bags: 9 (3m ago)", "Bank: Not scanned")
altBankKnown, altBank = true, 7
addon.InventoryChanged()
flush()
expectOwner("Bea", "9", "7")
expect("Known stock: 20 crafts")
bankStale = true
addon.InventoryChanged()
flush()
expect("Known stock: 18 crafts")
expect("Banks / alts need scanning")
expect("Your bank: rescan needed", "Your bank: live")
local staleStock = expectOwner("You", "2", "2*")
expectTooltip(staleStock, "Bank: 2 (last observed 2m ago; rescan needed)")
assert(staleStock.bank.color[1] == 0.76, "Last-observed bank stock uses the muted color")
bankStale, altBankStale = false, true
addon.InventoryChanged()
flush()
expect("Known stock: 13 crafts")
expectOwner("Bea", "9", "7*")
expectTooltip(expectOwner("Bea", "9", "7*"), "Bank: 7 (last observed 4m ago; rescan needed)")
altBagsStale = true
addon.InventoryChanged(); flush()
local staleBags = expectOwner("Bea", "9*", "7*")
assert(staleBags.bags.color[1] == 0.76)
expectTooltip(staleBags, "Bags: 9 (last observed 3m ago; rescan needed)")
expect("Known stock: 4 crafts")
altBagsStale, altBankStale, altBags, altBank = false, false, 0, 0
addon.InventoryChanged()
flush()
expectOwner("Bea", "0", "0")
expect("Known stock: 4 crafts")
expect("Recorded bags, banks and alts", "Banks / alts need scanning")
bankKnown = false
addon.InventoryChanged()
flush()
expectOwner("Bea", "0", "0")
expect("Banks / alts need scanning")
altBags = 9
altBankKnown, altBank = false, 0
bankKnown, bankOpen = false, false
addon.InventoryChanged()
flush()
expectOwner("You", "2", "Not scanned")
expectOwner("Bea", "9", "Not scanned")
expect("Open your bank to scan it")

form:Init({recipeID = 9999, name = "Two-material recipe", learned = true})
flush()
expect("Craft now: 0")
expect("Wool Cloth")
expect("Missing: 1")
local second = materialRow(2592)
assert(second.requirement.text == "1" and second.note:IsVisible(), "Each ingredient keeps its own need and shortage")
assert(second:GetHeight() == materialRow():GetHeight(), "A shortage fits in the spare material column without a taller two-owner row")
expectOwner("You", "0", "Not scanned", 2592)
expectOwner("Bea", "9", "Not scanned", 2592)
expectFits()

extraOwners = 24
addon.InventoryChanged()
flush()
assert(CraftGlancePanel:GetHeight() == ProfessionsFrame:GetHeight() - 45,
    "Cap a long stock list at the profession window height")
local overflow = CraftGlanceScroll:GetVerticalScrollRange()
assert(overflow > 0 and CraftGlanceScroll.ScrollBar:IsVisible(), "Real overflow enables the native scrollbar")
assert(tableHeader.parent == CraftGlancePanel and tableHeader:IsVisible(), "The shared headings stay outside the scrolling rows")
materialRow():Wheel(-1)
local wheelPosition = CraftGlanceScroll:GetVerticalScroll()
assert(wheelPosition > 0, "Wheeling over a reagent moves an overflowing list down")
expectOwner("Bea", "9", "Not scanned"):Wheel(1)
assert(CraftGlanceScroll:GetVerticalScroll() < wheelPosition, "Wheeling over a character moves the same list up")
CraftGlanceScroll:SetVerticalScroll(overflow - 1)
materialRow(2592):Wheel(-1)
assert(CraftGlanceScroll:GetVerticalScroll() == overflow, "Wheel scrolling stops at the actual list bottom")
CraftGlanceScroll:SetVerticalScroll(0)
materialRow():Wheel(1)
assert(CraftGlanceScroll:GetVerticalScroll() == 0, "Wheel scrolling stops at the list top")

CraftGlanceScroll:SetVerticalScroll(overflow)
extraOwners = 0
addon.InventoryChanged()
flush()
expectFits()
assert(CraftGlanceScroll:GetVerticalScroll() == 0, "A refreshed short list clamps a previous scroll offset")
form:Init({recipeID = 3275, name = "Linen Bandage", learned = true})
flush()
expect("Craft now: 2")
expectFits()
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
expectOwner("You", "2", "2")
expectOwner("Bea", "9", "Not scanned")
assert(not materialRow().requirement:IsVisible() or materialRow().requirement.text == "", "Material search has no recipe requirement")
expectFits()
extraOwners = 24
addon.InventoryChanged()
flush()
assert(CraftGlanceScroll:GetVerticalScrollRange() > 0 and CraftGlanceScroll.ScrollBar:IsVisible(),
    "All Materials also scrolls only when its recorded owners overflow")
materialRow():Wheel(-1)
assert(CraftGlanceScroll:GetVerticalScroll() > 0, "Mouse wheel works in an overflowing material search")
extraOwners = 0
addon.InventoryChanged()
flush()
expectFits()
assert(CraftGlanceScroll:GetVerticalScroll() == 0, "Shorter search results restore the unscrolled compact list")
materialMetadataReady = false
event("GET_ITEM_INFO_RECEIVED", 2589, false)
expect("No recorded material matches.")
assert(not material.cardTop:IsVisible() and not tableHeader:IsVisible(),
    "A recycled empty-result card hides material separators")
materialMetadataReady = true
event("GET_ITEM_INFO_RECEIVED", 2589, true)
expectOwner("You", "2", "2")
expectOwner("Bea", "9", "Not scanned")
assert(materialRow().cardTop:IsVisible(), "Loaded item metadata refreshes the open material list")
search:SetText("absent")
flush()
expect("No recorded material matches.", "Linen Cloth")

form:Init({recipeID = 3276, name = "Heavy Linen Bandage", learned = true})
flush()
expect("Heavy Linen Bandage")
expect("Craft now: 1", "No recorded material matches.")
assert(nativeSelections == 4 and not control("This Recipe").enabled, "Preserve selection and restore recipe view")
unknown = true
addon.InventoryChanged()
flush()
expect("Check reagent choices")
expectOwner("You", "Not scanned", "2")
expectOwner("Bea", "9", "Not scanned")
control("All Materials"):Click()
search:SetText("2589")
flush()
expectOwner("You", "Not scanned", "2")
expectOwner("Bea", "9", "Not scanned")
iconAvailable = false
addon.InventoryChanged()
flush()
assert(materialRow().icon.texture == 134400, "An uncached icon uses the game fallback")

control("-"):Click()
assert(CraftGlancePanel:GetHeight() == 52 and not search:IsVisible() and not filter:IsVisible())
assert(not CraftGlancePanel.InsetBg:IsVisible(), "Collapse hides the native inset background")
for _, key in ipairs(cornerNames) do
    local piece, info = CraftGlancePanel.NineSlice[key], C_Texture.GetAtlasInfo("Fixture" .. key)
    local upper = key:find("Top", 1, true)
    local keep = upper and 40 or 20
    local span = (info.bottomTexCoord - info.topTexCoord) * keep / info.height
    assert(piece:GetWidth() == info.width and piece:GetHeight() == keep,
        "Shorten only the inner tail of a collapsed native corner")
    assert(piece.texCoord[1] == info.leftTexCoord and piece.texCoord[2] == info.rightTexCoord
        and piece.texCoord[3] == (upper and info.topTexCoord or info.bottomTexCoord - span)
        and piece.texCoord[4] == (upper and info.topTexCoord + span or info.bottomTexCoord),
        "Keep upper corners' top pixels and lower corners' bottom pixels")
    assert(piece.point[4] == (key:find("Left", 1, true) and -8 or 8)
        and piece.point[5] == (upper and 16 or -8), "Retain the native outer border anchors")
end
assert(CraftGlancePanel:GetWidth() == 200 and ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 200 + 55,
    "Collapse reserves only the compact attachment width")
assert(not control("This Recipe"):IsVisible(), "Collapse hides contents")
control("+"):Click()
expectOwner("You", "Not scanned", "2")
expectOwner("Bea", "9", "Not scanned")
assert(CraftGlancePanel.InsetBg:IsVisible())
for _, key in ipairs(cornerNames) do
    local piece, info = CraftGlancePanel.NineSlice[key], C_Texture.GetAtlasInfo("Fixture" .. key)
    assert(piece:GetAtlas() == "Fixture" .. key and piece:GetWidth() == info.width and piece:GetHeight() == info.height
        and piece.texCoord[1] == info.leftTexCoord and piece.texCoord[2] == info.rightTexCoord
        and piece.texCoord[3] == info.topTexCoord and piece.texCoord[4] == info.bottomTexCoord,
        "Expansion restores the native corner atlas, dimensions and full texture")
end
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 400 + 55)
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
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 400 + 55,
    "Reopening restores the attachment reservation")
assert(positionUpdates > 0, "Update the native panel layout after reservation changes")
inCombat = true
page:Hide()
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17 + 400 + 55,
    "Defer protected layout changes during combat")
inCombat = false
event("PLAYER_REGEN_ENABLED")
assert(ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth") == 17,
    "Restore the original reservation after combat even while the profession stays hidden")
page:Show()
flush()
assert(not control("This Recipe").enabled and control("All Materials").enabled)

-- A malformed recipe/inventory refresh must not escape, spin, or leave stale rows.
local buildPlan, getSchematic = addon.BuildRecipePlan, C_TradeSkillUI.GetRecipeSchematic
local getMaterials, getSummary = addon.GetMaterialList, addon.GetScanSummary
local originalPrint, loggedErrors = print, {}
print = function(message) loggedErrors[#loggedErrors + 1] = tostring(message) end
local function expectFallback()
    expect("Recipe loading", "Craft now:")
    expect("Unable to read materials. Select a recipe to try again.")
    assert(CraftGlancePanel:IsVisible() and control("-"):IsVisible(), "The failed panel remains collapsible")
    assert(not CraftGlanceScroll:IsVisible() and not tableHeader:IsVisible(), "Fallback hides previous material data")
    assert(#timers == 0, "A failed refresh never schedules its own retry")
end
addon.BuildRecipePlan = function() error("fixture bad recipe") end
addon.RefreshPanel(); addon.RefreshPanel(); addon.RefreshPanel()
assert(#timers == 1, "Error handling preserves refresh debouncing")
flush()
expectFallback()
addon.RefreshPanel(); flush()
expectFallback()
assert(#loggedErrors == 1 and loggedErrors[1]:find("fixture bad recipe", 1, true), "Log a refresh error once")
control("-"):Click()
assert(CraftGlancePanel:GetHeight() == 52 and control("+"):IsVisible(), "Collapse still works after a failed recipe")
control("+"):Click()
expectFallback()
addon.BuildRecipePlan = buildPlan
addon.RefreshPanel(); flush()
expect("Craft now: 1")
expectOwner("You", "2", "2")

C_TradeSkillUI.GetRecipeSchematic = function() return true end
addon.RefreshPanel(); flush()
expectFallback()
C_TradeSkillUI.GetRecipeSchematic = getSchematic
addon.BuildRecipePlan = function() return {ingredients = false} end
addon.RefreshPanel(); flush()
expectFallback()
addon.BuildRecipePlan = buildPlan
addon.RefreshPanel(); flush()
expect("Craft now: 1")

addon.GetMaterialList = function() error("fixture bad material list") end
control("All Materials"):Click()
expectFallback()
addon.GetMaterialList = getMaterials
addon.RefreshPanel(); flush()
expect("Find your materials")
expectOwner("You", "2", "2")
altBags, altBankKnown, altBank = 0, true, 0
addon.RefreshPanel(); flush()
expectOwner("Bea", "0", "0")
altBags, altBankKnown = 9, false
control("This Recipe"):Click()
addon.GetScanSummary = function() error("fixture bad scan summary") end
addon.RefreshPanel(); flush()
expectFallback()
addon.GetScanSummary = getSummary
addon.RefreshPanel(); flush()
expect("Craft now: 1")
assert(#loggedErrors == 1, "Different malformed data cannot flood the chat log")

page:Hide()
addon.BuildRecipePlan = function() error("hidden panels must not read recipes") end
local readsBeforeHidden = schematicReads
addon.RefreshPanel(); flush()
assert(schematicReads == readsBeforeHidden and #loggedErrors == 1, "Hidden panels return before reading APIs")
addon.BuildRecipePlan = buildPlan
page:Show(); flush()
print = originalPrint
expect("Craft now: 1")
local currencyInfo, balance, mixed = C_CurrencyInfo, 100, false
C_CurrencyInfo = {GetCurrencyInfo = function() return {name = "Token", quantity = balance, iconFileID = 2468} end}
C_TradeSkillUI.GetRecipeSchematic = function(id)
    if id == 10000 then
        schematicReads = schematicReads + 1
        local slots = {{required = true, quantityRequired = 3, reagents = {{currencyID = 10}}}}
        if mixed then slots[2] = {required = true, quantityRequired = 1, reagents = {{itemID = 2589}}} end
        return {reagentSlotSchematics = slots}
    end
    return getSchematic(id)
end
form:Init({recipeID = 10000, name = "Currency recipe", learned = true})
flush()
expect("Craft now: 33"); expect("Known stock: 33 crafts")
expect("Bags and owned currency", "From your bags only")
expect("Owned: 100")
local tokenRow
for _, widget in ipairs(widgets) do
    if widget.currencyID == 10 and widget:IsVisible() then tokenRow = widget end
end
assert(tokenRow and tokenRow.icon.texture == 2468 and tokenRow.requirement.text == "3")

balance = 1
local readsBeforeCurrency = schematicReads
dispatch("CURRENCY_DISPLAY_UPDATE", 10, 2)
dispatch("CURRENCY_DISPLAY_UPDATE", 10, 1)
assert(#timers == 1, "Currency changes share a debounced refresh")
flush()
expect("Craft now: 0"); expect("Known stock: 0 crafts")
expect("Owned: 1"); expect("Missing: 2")
balance = 0
event("CURRENCY_DISPLAY_UPDATE", 10, 0)
expect("Owned: 0"); expect("Missing: 3")
expect("Craft now: 0"); expect("Known stock: 0 crafts")
balance = nil
event("CURRENCY_DISPLAY_UPDATE", 10)
expect("Owned: unknown", "Owned: 0"); expect("Check reagent choices", "Known stock:")
assert(schematicReads == readsBeforeCurrency + 3)
mixed, balance = true, 6
event("CURRENCY_DISPLAY_UPDATE", 10, 6)
expect("Owned: 6"); expect("Craft now: 2")
expectOwner("You", "2", "2")

C_CurrencyInfo, C_TradeSkillUI.GetRecipeSchematic = currencyInfo, getSchematic
form:Init({recipeID = 3276, name = "Heavy Linen Bandage", learned = true})
flush()
expect("Craft now: 1"); expect("From your bags only", "Owned:")
assert(create.scripts.OnClick == createHandler and createAll.scripts.OnClick == createHandler,
    "Native Create and Create All keep their handlers")

-- Exercise native scrollbar changes as well as the wheel. A search with sparse
-- holdings must expose every scanned zero while allocating just a viewport of widgets.
local catalogue = {}
for materialIndex = 1, 100 do
    local sources = {}
    for ownerIndex = 1, 12 do
        local name = "Alt" .. ownerIndex
        local owned = ownerIndex == (materialIndex - 1) % 12 + 1 and materialIndex or 0
        for _, location in ipairs({"bags", "bank"}) do
            sources[#sources + 1] = {guid = name, name = name, location = location,
                count = location == "bags" and owned or 0, scanned = true}
        end
    end
    catalogue[materialIndex] = {name = "Reagent " .. materialIndex, itemID = 10000 + materialIndex, sources = sources}
end
addon.GetMaterialList = function(query)
    if query == "none" then return {} end
    if query == "last" then return {catalogue[100]} end
    return catalogue
end
control("All Materials"):Click()
local visited, visitedCount = {}, 0
local function inspectViewport()
    local ownersAllocated, cardsAllocated = 0, 0
    local height = CraftGlanceScroll:GetHeight()
    for _, widget in ipairs(widgets) do
        if widget.cardTop then cardsAllocated = cardsAllocated + 1 end
        if widget.holding then
            ownersAllocated = ownersAllocated + 1
            if widget:IsVisible() then
                local item = widget.parent.itemID - 10000
                local owner = tonumber(widget.owner.text:match("^Alt(%d+)$"))
                local expected = owner == (item - 1) % 12 + 1 and item or 0
                assert(widget.bags.text == tostring(expected) and widget.bank.text == "0",
                    "Recycled owner widgets display the current item's holdings")
                local key = item .. ":" .. owner
                if not visited[key] then visited[key] = true; visitedCount = visitedCount + 1 end
            end
        end
    end
    assert(ownersAllocated <= math.ceil(height / 24) + 2, "Owner allocation is bounded by the viewport")
    assert(cardsAllocated <= 4, "A sparse catalogue recycles material cards")
end
local limit = CraftGlanceScroll:GetVerticalScrollRange()
local hoveredOwner = expectOwner("Alt1", "1", "0", 10001)
hoveredOwner.scripts.OnEnter(hoveredOwner)
CraftGlanceScroll:SetVerticalScroll(24)
assert(not GameTooltip.shown or GameTooltip.lines[1] == hoveredOwner.holding.fullName,
    "Scrolling rebinds or clears a stationary owner tooltip")
hoveredOwner.scripts.OnLeave(hoveredOwner)
local hoveredMaterial = materialRow(10001)
hoveredMaterial.scripts.OnEnter(hoveredMaterial)
CraftGlanceScroll:SetVerticalScroll(limit)
assert(not GameTooltip.shown or GameTooltip.itemID == hoveredMaterial.itemID,
    "A recycled material card cannot keep the previous item's tooltip")
hoveredMaterial.scripts.OnLeave(hoveredMaterial)
for offset = 0, limit, math.floor(CraftGlanceScroll:GetHeight() - 24) do
    CraftGlanceScroll:SetVerticalScroll(offset)
    inspectViewport()
end
CraftGlanceScroll:SetVerticalScroll(limit)
inspectViewport()
assert(visitedCount == 1200, "All 100 materials and all twelve scanned owners are reachable")
expectTooltip(expectOwner("Alt12", "0", "0", 10100), "Alt12", "Bank: 0")
search:SetText("none"); flush()
expect("No recorded material matches.", "Reagent 100")
assert(CraftGlanceScroll:GetVerticalScroll() == 0 and not tableHeader:IsVisible())
search:SetText("last"); flush()
expect("Reagent 100", "No recorded material")
expectOwner("Alt4", "100", "0", 10100)
control("This Recipe"):Click()
expect("Heavy Linen Bandage", "Reagent 100")
expectOwner("You", "2", "2")
addon.GetMaterialList = getMaterials
print("CraftGlance panel selection, inventory, search and native controls passed")
