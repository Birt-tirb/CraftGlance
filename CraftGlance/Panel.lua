local _, addon = ...
local api = C_TradeSkillUI
local events = CreateFrame("Frame")
local panel, form, body, scroll, filter, search, headline, summary, scanText
local collapse, recipeTab, materialsTab, hero, recipeName, recipeIcon, stockSummary, stockNote
local view, collapsed = "recipe", false
local queued, lastRecipe, baseExtra, reservedExtra
local rows = {}
local width, compactWidth, dockGap = 400, 200, 55
local rowWidth = width - 44
local colors = {
    text = {1, 0.97, 0.90}, muted = {0.76, 0.76, 0.72},
    good = {0.48, 0.87, 0.52}, short = {1, 0.57, 0.42}, bank = {0.53, 0.77, 1},
}

local function text(parent, style, x, y, value, textWidth)
    local label = parent:CreateFontString(nil, "OVERLAY", style)
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(textWidth or width - 28)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(value or "")
    return label
end

local function tint(label, color)
    label:SetTextColor(unpack(color))
end

local function button(parent, caption, x, y, buttonWidth, callback)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(buttonWidth, 25)
    control:SetPoint("TOPLEFT", x, y)
    control:SetText(caption)
    control:SetScript("OnClick", callback)
    return control
end

local function background(parent, r, g, b, a)
    local texture = parent:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function itemIcon(itemID)
    if itemID and C_Item then
        local icon = C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
        if icon then return icon end
        if C_Item.GetItemInfoInstant then
            icon = select(5, C_Item.GetItemInfoInstant(itemID))
            if icon then return icon end
        end
    end
    return 134400
end

local function age(timestamp)
    if not timestamp then return "not scanned" end
    local seconds = math.max(0, GetServerTime() - timestamp)
    if seconds < 60 then return "just scanned" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "m ago" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. "h ago" end
    return math.floor(seconds / 86400) .. "d ago"
end

-- Show full holdings rather than allocating a single item to the next craft.
local function owners(sources)
    local result, byKey = {}, {}
    for _, source in ipairs(sources or {}) do
        local key = source.guid or ((source.name or "Character") .. ":" .. (source.realm or ""))
        local owner = byKey[key]
        if not owner then
            owner = {name = source.isCurrent and "You" or (source.name or "Character"),
                isCurrent = source.isCurrent, total = 0}
            result[#result + 1], byKey[key] = owner, owner
        end
        owner[source.location] = source
        if source.scanned and source.count then owner.total = owner.total + source.count end
        if not source.scanned then owner.unknown = true end
    end
    local visible = {}
    for _, owner in ipairs(result) do
        if owner.isCurrent or owner.total > 0 or owner.unknown then visible[#visible + 1] = owner end
    end
    return visible
end

local function countText(source)
    -- GetSources omits scanned zero holdings on alts, but always includes unknowns.
    if not source then return "0" end
    if not source.scanned or source.count == nil then return "Not scanned" end
    return tostring(source.count)
end

local function ownerAge(owner)
    local labels = {}
    for _, location in ipairs({"bags", "bank"}) do
        local source = owner[location]
        if source and source.scanned then
            labels[#labels + 1] = (location == "bags" and "Bags " or "Bank ") ..
                (source.live and "live" or age(source.updatedAt))
        end
    end
    return table.concat(labels, "  |  ")
end

local function renderOwners(row, sources, top, required)
    local holdings = owners(sources)
    for index, owner in ipairs(holdings) do
        local line = row.stockRows[index]
        if not line then
            line = CreateFrame("Frame", nil, row)
            line.divider = line:CreateTexture(nil, "BORDER")
            line.divider:SetHeight(1)
            line.divider:SetPoint("TOPLEFT", 10, 4)
            line.divider:SetPoint("TOPRIGHT", -10, 4)
            line.divider:SetColorTexture(0.39, 0.30, 0.17, 0.8)
            line.owner = text(line, "GameFontHighlight", 10, -2, "", 151)
            line.bags = text(line, "GameFontHighlight", 166, -2, "", 68)
            line.bank = text(line, "GameFontHighlight", 240, -2, "", 106)
            line.bags:SetJustifyH("CENTER"); line.bank:SetJustifyH("CENTER")
            line.detail = text(line, "GameFontHighlightSmall", 10, -22, "", rowWidth - 20)
            tint(line.detail, colors.muted)
            row.stockRows[index] = line
        end
        line:ClearAllPoints(); line:SetPoint("TOPLEFT", 0, -top); line:SetWidth(rowWidth)
        line.divider:SetShown(index > 1)
        line.owner:SetText(owner.name)
        line.bags:SetText(countText(owner.bags)); line.bank:SetText(countText(owner.bank))
        tint(line.owner, colors.text)
        tint(line.bags, owner.bags and not owner.bags.scanned and colors.muted or colors.text)
        tint(line.bank, owner.bank and not owner.bank.scanned and colors.muted or colors.text)
        if owner.isCurrent and required and owner.bags and owner.bags.scanned then
            tint(line.bags, owner.bags.count >= required and colors.good or colors.short)
        end
        if owner.bank and owner.bank.scanned and (owner.bank.count or 0) > 0 then tint(line.bank, colors.bank) end
        line.detail:SetText(ownerAge(owner))
        local height = math.max(20, line.owner:GetStringHeight() + 5,
            line.bags:GetStringHeight() + 5, line.bank:GetStringHeight() + 5)
        line.detail:ClearAllPoints(); line.detail:SetPoint("TOPLEFT", 10, -height)
        if line.detail:GetText() ~= "" then height = height + line.detail:GetStringHeight() + 6 end
        line:SetHeight(height); line:Show()
        top = top + height + 8
    end
    for index = #holdings + 1, #row.stockRows do row.stockRows[index]:Hide() end
    return top
end

local function scrollMaterials(_, delta)
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() - delta * 35)))
end

local function renderRows(entries)
    local top = 0
    for index, entry in ipairs(entries) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", nil, body)
            row.background = background(row, 0, 0, 0, 0)
            row.cardTop = row:CreateTexture(nil, "BORDER")
            row.cardTop:SetHeight(1)
            row.cardTop:SetPoint("TOPLEFT", 0, 0)
            row.cardTop:SetPoint("TOPRIGHT", 0, 0)
            row.cardTop:SetColorTexture(0.57, 0.43, 0.24, 0.8)
            row.cardBottom = row:CreateTexture(nil, "BORDER")
            row.cardBottom:SetHeight(1)
            row.cardBottom:SetPoint("BOTTOMLEFT", 0, 0)
            row.cardBottom:SetPoint("BOTTOMRIGHT", 0, 0)
            row.cardBottom:SetColorTexture(0.57, 0.43, 0.24, 0.8)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(36, 36); row.icon:SetPoint("TOPLEFT", 10, -12)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.title = text(row, "GameFontNormalLarge", 56, -12, "", rowWidth - 68)
            row.requirement = text(row, "GameFontHighlight", 56, -36, "", rowWidth - 68)
            row.note = text(row, "GameFontHighlight", 10, 0, "", rowWidth - 20)
            row.headers = CreateFrame("Frame", nil, row); row.headers:SetSize(rowWidth, 20)
            row.headerDivider = row.headers:CreateTexture(nil, "BORDER")
            row.headerDivider:SetHeight(1)
            row.headerDivider:SetPoint("BOTTOMLEFT", 9, 0)
            row.headerDivider:SetPoint("BOTTOMRIGHT", -9, 0)
            row.headerDivider:SetColorTexture(0.62, 0.48, 0.27, 0.6)
            text(row.headers, "GameFontNormal", 10, 0, "Character", 150)
            local bagHeader = text(row.headers, "GameFontNormal", 166, 0, "Bags", 68)
            local bankHeader = text(row.headers, "GameFontNormal", 240, 0, "Bank", 106)
            bagHeader:SetJustifyH("CENTER"); bankHeader:SetJustifyH("CENTER")
            row.detail = text(row, "GameFontHighlight", 12, -40, "", rowWidth - 24)
            row.stockRows = {}
            row:EnableMouse(true)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", scrollMaterials)
            row:SetScript("OnEnter", function(self)
                if not GameTooltip or not self.itemID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self.itemID); GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            rows[index] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -top)
        row:SetWidth(rowWidth); row.itemID = entry.itemID
        local material = entry.kind == "material"
        row.icon:SetShown(material); row.headers:SetShown(material)
        row.cardTop:SetShown(material); row.cardBottom:SetShown(material); row.headerDivider:SetShown(material)
        row.requirement:SetShown(material and entry.required ~= nil)
        row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT", material and 56 or 12, -12)
        row.title:SetWidth(rowWidth - (material and 68 or 24)); row.title:SetText(entry.title)
        row.detail:SetShown(not material); row.note:Hide()
        local height
        if material then
            row.icon:SetTexture(itemIcon(entry.itemID))
            local titleBottom = math.max(33, row.title:GetStringHeight() + 18)
            row.requirement:ClearAllPoints(); row.requirement:SetPoint("TOPLEFT", 56, -titleBottom)
            row.requirement:SetText(entry.required and ("Per craft: " .. entry.required) or "")
            tint(row.requirement, colors.text)
            local headingTop = math.max(60, titleBottom + (entry.required and 29 or 8))
            row.headers:ClearAllPoints(); row.headers:SetPoint("TOPLEFT", 0, -headingTop)
            height = renderOwners(row, entry.sources, headingTop + 24, entry.required)
            if entry.missingOne and entry.missingOne > 0 then
                row.note:ClearAllPoints(); row.note:SetPoint("TOPLEFT", 10, -height)
                row.note:SetText("Missing to craft: " .. entry.missingOne)
                tint(row.note, colors.short); row.note:Show()
                height = height + row.note:GetStringHeight() + 12
            end
            height = height + 5
        else
            for _, line in ipairs(row.stockRows) do line:Hide() end
            row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -10)
            row.detail:SetText(entry.detail or ""); tint(row.detail, colors.text)
            height = row.title:GetStringHeight() + row.detail:GetStringHeight() + 34
        end
        row:SetHeight(height); row:Show(); top = top + height + 12
    end
    for index = #entries + 1, #rows do rows[index]:Hide() end
    body:SetHeight(math.max(top, 1))
end

local function reserveSpace(visible)
    local frame = ProfessionsFrame
    if not frame or not SetUIPanelAttribute or not UpdateUIPanelPositions then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local extra = (baseExtra or 0) + (visible and ((collapsed and compactWidth or width) + dockGap) or 0)
    if reservedExtra == extra then return end
    reservedExtra = extra
    SetUIPanelAttribute(frame, "extraWidth", extra)
    UpdateUIPanelPositions(frame)
end

local function position()
    if not panel then return end
    local frame = ProfessionsFrame
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", dockGap, -45)
    panel:SetWidth(collapsed and compactWidth or width)
    panel:SetHeight(collapsed and 52 or math.max(500, math.min(700, frame:GetHeight() - 45)))
    collapse:ClearAllPoints()
    collapse:SetPoint("TOPRIGHT", -5, -3)
    collapse:SetText(collapsed and "+" or "-")
    panel.InsetBg:SetShown(not collapsed)
    -- Keep full-size native corner art inside the compact title bar.
    panel:SetClipsChildren(collapsed)
    reserveSpace(panel:IsVisible())
end

local function scanStatus()
    local state = addon.GetScanSummary()
    if not state then return "Log in to record your inventory." end
    local bank = state.bank or {}
    local line = state.bankOpen and "Your bank: live" or
        (bank.scanned and ("Your bank: " .. age(bank.updatedAt)) or "Open your bank to scan it")
    return (state.characterCount or 1) .. " characters recorded\n" .. line
end

local function setRecipeHeader(name, icon)
    recipeName:SetText(name or "")
    recipeIcon:SetTexture(icon or 134400)
    recipeIcon:SetShown(name ~= nil)
    recipeName:SetShown(name ~= nil)
end

local function refresh()
    if not panel or not panel:IsVisible() then return end
    position()
    for _, widget in ipairs({recipeTab, materialsTab, scroll, hero, scanText}) do
        widget:SetShown(not collapsed)
    end
    if collapsed then search:Hide(); filter:Hide(); recipeIcon:Hide(); recipeName:Hide(); return end
    local linked = (api.IsTradeSkillLinked and api.IsTradeSkillLinked()) or
        (api.IsTradeSkillGuild and api.IsTradeSkillGuild()) or
        (api.IsNPCCrafting and api.IsNPCCrafting())
    search:SetShown(view == "materials")
    PanelTemplates_SelectTab(view == "recipe" and recipeTab or materialsTab)
    PanelTemplates_DeselectTab(view == "recipe" and materialsTab or recipeTab)
    scanText:SetText(scanStatus())
    local supportsFilter = type(api.GetOnlyShowMakeableRecipes) == "function"
        and type(api.SetOnlyShowMakeableRecipes) == "function"
    filter:SetShown(supportsFilter and not linked)
    if supportsFilter then filter:SetChecked(api.GetOnlyShowMakeableRecipes()) end
    stockSummary:Hide(); stockNote:Hide()
    if view == "materials" then
        setRecipeHeader(nil)
        headline:SetText("Find your materials")
        tint(headline, colors.text)
        summary:SetText("Full stock by character and bank")
        hero:ClearAllPoints(); hero:SetPoint("TOPLEFT", 14, -80)
        hero:SetHeight(69)
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 14, -196); scroll:SetPoint("BOTTOMRIGHT", -30, 85)
        local entries = {}
        for _, material in ipairs(addon.GetMaterialList(search:GetText()) or {}) do
            entries[#entries + 1] = {kind = "material", title = material.name, itemID = material.itemID,
                bags = material.bags, sources = material.sources}
        end
        if #entries == 0 then entries[1] = {title = "No recorded material matches.",
            detail = "Try a name or item ID. Visit banks and log into alts to record more."} end
        renderRows(entries)
        return
    end
    hero:ClearAllPoints(); hero:SetPoint("TOPLEFT", 14, -132); hero:SetHeight(107)
    scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 14, -251); scroll:SetPoint("BOTTOMRIGHT", -30, 85)
    if linked then
        setRecipeHeader(nil)
        headline:SetText("Your recipes")
        summary:SetText("Open your own profession to compare materials.")
        renderRows({})
        return
    end
    if api.IsTradeSkillReady and not api.IsTradeSkillReady() then
        setRecipeHeader(nil)
        headline:SetText("Recipe loading")
        summary:SetText("Waiting for your profession's recipes.")
        renderRows({})
        return
    end
    local recipe = form:GetRecipeInfo()
    if not recipe or not recipe.recipeID or not form:IsVisible() then
        setRecipeHeader(nil)
        headline:SetText("Select a recipe")
        summary:SetText("Click a recipe in the profession window.")
        renderRows({})
        return
    end
    local level = form.GetCurrentRecipeLevel and form:GetCurrentRecipeLevel()
    local schematic = api.GetRecipeSchematic(recipe.recipeID, false, level)
    if not schematic or not schematic.reagentSlotSchematics then
        setRecipeHeader(recipe.name, recipe.icon)
        headline:SetText("Recipe loading")
        summary:SetText("Waiting for the recipe's materials.")
        renderRows({})
        return
    end
    setRecipeHeader(recipe.name, recipe.icon or recipe.iconID or schematic.icon)
    local plan = addon.BuildRecipePlan(schematic.reagentSlotSchematics)
    headline:SetText(plan.craftNow and ("Craft now: " .. plan.craftNow) or "Check reagent choices")
    tint(headline, plan.craftNow and plan.craftNow > 0 and colors.good or colors.short)
    summary:SetText("From your bags only")
    if plan.craftWithKnownStock then
        stockSummary:SetText("Known stock: " .. plan.craftWithKnownStock .. " crafts"); stockSummary:Show()
        stockNote:SetText(plan.stockUnknown and "Some banks or characters still need scanning." or
            "Recorded bags, banks and alts; saved counts may have changed.")
        stockNote:Show()
    end
    local entries = {}
    for _, ingredient in ipairs(plan.ingredients) do
        entries[#entries + 1] = {kind = "material", title = ingredient.name, itemID = ingredient.itemID,
            required = ingredient.required, bags = ingredient.bags, sources = ingredient.sources,
            missingOne = ingredient.missingOne}
    end
    if plan.incomplete then entries[#entries + 1] = {title = "Review this recipe", detail = plan.message} end
    if not recipe.learned then entries[#entries + 1] = {title = "Recipe not learned", detail = "Learn this recipe before crafting it."} end
    renderRows(entries)
end

local function schedule()
    if queued or not panel then return end
    queued = true
    C_Timer.After(0.05, function() queued = false; refresh() end)
end
addon.RefreshPanel, addon.InventoryChanged = schedule, schedule

local function attach()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if panel or not page or not page.SchematicForm then return end
    form = page.SchematicForm
    local registered = UIPanelWindows and UIPanelWindows.ProfessionsFrame
    baseExtra = (ProfessionsFrame.GetAttribute and ProfessionsFrame:GetAttribute("UIPanelLayout-extraWidth")) or
        (registered and registered.extraWidth) or 0
    panel = CreateFrame("Frame", "CraftGlancePanel", page, "DefaultPanelTemplate")
    panel:SetSize(width, 560); panel:SetFrameLevel(page:GetFrameLevel() + 5)
    panel.TitleText = panel.TitleContainer.TitleText
    panel.TitleText:SetText("CraftGlance")
    -- Use the same client art as the native Forever profession frame.
    SetTextureWithAddressModeOptions(panel.Bg, "Profession-Background-Overview")
    panel.TopTileStreaks:Hide()
    panel.InsetBg = panel:CreateTexture(nil, "BACKGROUND", nil, -3)
    panel.InsetBg:SetAtlas("Profession-Background-Template2")
    panel.InsetBg:SetPoint("TOPLEFT", 3, -21)
    panel.InsetBg:SetPoint("BOTTOMRIGHT", -3, 3)
    panel.minTabWidth, panel.maxTabWidth, panel.tabPadding = 180, 180, 0
    collapse = button(panel, "-", width - 32, -3, 26, function() collapsed = not collapsed; refresh() end)
    collapse:SetFrameLevel(panel.TitleContainer:GetFrameLevel() + 1)
    local function tab(caption, x, callback)
        local control = CreateFrame("Button", nil, panel, "PanelTopTabButtonTemplate")
        control:SetPoint("TOPLEFT", x, -34); control:SetText(caption)
        PanelTemplates_TabResize(control, 0, 180); control:SetScript("OnClick", callback)
        return control
    end
    recipeTab = tab("This Recipe", 14, function() view = "recipe"; scroll:SetVerticalScroll(0); refresh() end)
    materialsTab = tab("All Materials", 202, function() view = "materials"; scroll:SetVerticalScroll(0); refresh() end)
    recipeIcon = panel:CreateTexture(nil, "ARTWORK")
    recipeIcon:SetSize(40, 40); recipeIcon:SetPoint("TOPLEFT", 18, -80)
    recipeIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    recipeName = text(panel, "GameFontNormalLarge", 68, -84, "", width - 88)
    hero = CreateFrame("Frame", nil, panel)
    hero:SetSize(width - 28, 107)
    hero.background = background(hero, 0, 0, 0, 0)
    headline = text(hero, "GameFontHighlightLarge", 12, -11, "", width - 52)
    summary = text(hero, "GameFontHighlight", 12, -35, "", width - 52)
    tint(summary, colors.text)
    stockSummary = text(hero, "GameFontNormal", 12, -61, "", width - 52)
    stockNote = text(hero, "GameFontHighlightSmall", 12, -83, "", width - 52); tint(stockNote, colors.muted)
    hero:EnableMouse(true)
    hero:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Craft now uses bags only")
        GameTooltip:AddLine("Known stock includes recorded bags and banks. Saved counts may have changed. Required tools, location and cooldowns still apply.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    hero:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 21, -158); search:SetSize(width - 46, 26)
    search:SetAutoFocus(false); search:SetMaxLetters(80)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    search:SetScript("OnTextChanged", function() if view == "materials" then scroll:SetVerticalScroll(0); schedule() end end)
    search:SetText(""); search:Hide()
    scroll = CreateFrame("ScrollFrame", "CraftGlanceScroll", panel, "UIPanelScrollFrameTemplate")
    body = CreateFrame("Frame", nil, scroll); body:SetSize(rowWidth, 1); scroll:SetScrollChild(body)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", scrollMaterials)
    filter = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    filter:SetSize(23, 23); filter:SetPoint("BOTTOMLEFT", 10, 49)
    filter.Text:SetText("Craftable only"); filter:SetHitRectInsets(0, -105, 0, 0)
    filter:SetScript("OnClick", function(self) api.SetOnlyShowMakeableRecipes(self:GetChecked() == true); schedule() end)
    scanText = text(panel, "GameFontHighlightSmall", 14, 0, "", width - 28)
    scanText:ClearAllPoints(); scanText:SetPoint("BOTTOMLEFT", 14, 15); tint(scanText, colors.muted)
    page:HookScript("OnShow", function() view = "recipe"; schedule() end)
    form:HookScript("OnShow", schedule); form:HookScript("OnHide", schedule)
    if type(form.Init) == "function" then
        hooksecurefunc(form, "Init", function()
            local recipe = form:GetRecipeInfo()
            if recipe and recipe.recipeID ~= lastRecipe then lastRecipe = recipe.recipeID; view = "recipe"; scroll:SetVerticalScroll(0) end
            schedule()
        end)
    end
    panel:HookScript("OnShow", schedule)
    panel:HookScript("OnHide", function() reserveSpace(false) end)
    position(); schedule()
end

for _, event in ipairs({"ADDON_LOADED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, event)
    if not panel then attach() end
    if event == "PLAYER_REGEN_ENABLED" and panel then reserveSpace(panel:IsVisible()) end
    schedule()
end)
SLASH_CRAFTGLANCE1, SLASH_CRAFTGLANCE2 = "/craftglance", "/cg"
SlashCmdList.CRAFTGLANCE = function()
    attach()
    if panel and ProfessionsFrame:IsShown() then collapsed = false; refresh()
    else print("CraftGlance: open a crafting profession and select a recipe.") end
end
