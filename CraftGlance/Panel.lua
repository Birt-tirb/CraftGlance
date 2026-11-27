local _, addon = ...
local api = C_TradeSkillUI
local events = CreateFrame("Frame")
local panel, form, body, scroll, filter, search, headline, summary, scanText
local collapse, recipeTab, materialsTab, hero, recipeName, recipeIcon, stockSummary, stockNote
local tableHeader, needHeader
local view, collapsed = "recipe", false
local queued, lastRecipe, baseExtra, reservedExtra
local refreshErrorLogged = false
local rows = {}
local width, compactWidth, dockGap = 400, 200, 55
local rowWidth = width - 44
local maxPanelHeight = 560
local borderCollapsed = false
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

local function singleLine(label)
    label:SetWordWrap(false)
    label:SetNonSpaceWrap(false)
    return label
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
                fullName = source.name or "Character",
                isCurrent = source.isCurrent}
            result[#result + 1], byKey[key] = owner, owner
        end
        owner[source.location] = source
    end
    return result
end

local function countText(source)
    if not source or not source.scanned or source.count == nil then return "Not scanned" end
    return tostring(source.count) .. (source.stale and "*" or "")
end

local function scrollMaterials(_, delta)
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll() - delta * 35)))
end

local function sourceDetail(label, source)
    if source and source.scanned and source.stale then
        return label .. ": " .. tostring(source.count) .. " (last observed " .. age(source.updatedAt) .. "; rescan needed)"
    end
    return label .. ": " .. countText(source) ..
        (source and source.scanned and (" (" .. (source.live and "live" or age(source.updatedAt)) .. ")") or "")
end

local function renderOwners(row, sources, required)
    local holdings = owners(sources)
    for index, owner in ipairs(holdings) do
        local line = row.stockRows[index]
        if not line then
            line = CreateFrame("Frame", nil, row)
            line.divider = line:CreateTexture(nil, "BORDER")
            line.divider:SetHeight(1)
            line.divider:SetPoint("TOPLEFT", 0, 0)
            line.divider:SetPoint("TOPRIGHT", 0, 0)
            line.divider:SetColorTexture(0.39, 0.30, 0.17, 0.8)
            line.owner = singleLine(text(line, "GameFontHighlight", 0, -3, "", 64))
            line.bags = singleLine(text(line, "GameFontHighlight", 68, -3, "", 40))
            line.bank = singleLine(text(line, "GameFontHighlightSmall", 112, -3, "", 64))
            line.bags:SetJustifyH("CENTER"); line.bank:SetJustifyH("CENTER")
            line:EnableMouse(true); line:EnableMouseWheel(true)
            line:SetScript("OnMouseWheel", scrollMaterials)
            line:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                local holding = self.holding
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(holding.isCurrent and ("You - " .. holding.fullName) or holding.fullName)
                GameTooltip:AddLine(sourceDetail("Bags", holding.bags), 0.9, 0.9, 0.9, true)
                GameTooltip:AddLine(sourceDetail("Bank", holding.bank), 0.9, 0.9, 0.9, true)
                GameTooltip:Show()
            end)
            line:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            row.stockRows[index] = line
        end
        line.holding = owner
        line:ClearAllPoints(); line:SetPoint("TOPLEFT", 180, -4 - (index - 1) * 24)
        line:SetSize(rowWidth - 180, 24)
        line.divider:SetShown(index > 1)
        line.owner:SetText(owner.name)
        line.bags:SetText(countText(owner.bags)); line.bank:SetText(countText(owner.bank))
        tint(line.owner, colors.text)
        tint(line.bags, owner.bags and (not owner.bags.scanned or owner.bags.stale) and colors.muted or colors.text)
        tint(line.bank, owner.bank and (not owner.bank.scanned or owner.bank.stale) and colors.muted or colors.text)
        if owner.isCurrent and required and owner.bags and owner.bags.scanned then
            tint(line.bags, owner.bags.count >= required and colors.good or colors.short)
        end
        if owner.bank and owner.bank.scanned and not owner.bank.stale and (owner.bank.count or 0) > 0 then tint(line.bank, colors.bank) end
        line:Show()
    end
    for index = #holdings + 1, #row.stockRows do row.stockRows[index]:Hide() end
    return math.max(1, #holdings) * 24 + 8
end

local function fitBackground()
    -- Crop shorter views from one fixed-height background so its header rule
    -- stays beneath the tabs instead of moving with the material list height.
    local referenceHeight = collapsed and panel:GetHeight() or maxPanelHeight
    for _, layer in ipairs({
        {panel.Bg, "Profession-Background-Overview", 23},
        {panel.InsetBg, "Profession-Background-Template2", 24},
    }) do
        local texture, atlas, inset = unpack(layer)
        local info = C_Texture.GetAtlasInfo(atlas)
        if info and (info.file or info.filename) then
            local fraction = math.max(0, math.min(1, (panel:GetHeight() - inset) / (referenceHeight - inset)))
            texture:SetTexture(info.file or info.filename)
            texture:SetHorizTile(false); texture:SetVertTile(false)
            texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord,
                info.topTexCoord + (info.bottomTexCoord - info.topTexCoord) * fraction)
        end
    end
end

local function renderRows(entries)
    local top, hasMaterials = 0, false
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
            row.icon:SetSize(20, 20); row.icon:SetPoint("TOPLEFT", 4, -4)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.title = singleLine(text(row, "GameFontNormal", 30, -7, "", 110))
            row.requirement = singleLine(text(row, "GameFontHighlight", 145, -7, "", 28))
            row.requirement:SetJustifyH("CENTER")
            row.note = singleLine(text(row, "GameFontHighlightSmall", 30, -28, "", 144))
            row.detail = text(row, "GameFontHighlight", 12, -40, "", rowWidth - 24)
            row.stockRows = {}
            row:EnableMouse(true)
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", scrollMaterials)
            row:SetScript("OnEnter", function(self)
                if not GameTooltip or not self.itemID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self.itemID)
                if self.required then GameTooltip:AddLine("Per craft: " .. self.required, 0.9, 0.9, 0.9) end
                if self.missingOne and self.missingOne > 0 then
                    GameTooltip:AddLine("Missing to craft: " .. self.missingOne, 1, 0.57, 0.42)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            rows[index] = row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -top)
        row:SetWidth(rowWidth); row.itemID, row.required, row.missingOne = entry.itemID, entry.required, entry.missingOne
        local material = entry.kind == "material"
        hasMaterials = hasMaterials or material
        row.icon:SetShown(material)
        row.cardTop:SetShown(material); row.cardBottom:SetShown(material)
        row.requirement:SetShown(material and entry.required ~= nil)
        row.title:ClearAllPoints(); row.title:SetPoint("TOPLEFT", material and 30 or 4, material and -7 or -8)
        row.title:SetWidth(material and (entry.required and 110 or 144) or rowWidth - 8)
        row.title:SetWordWrap(not material); row.title:SetText(entry.title)
        row.detail:SetShown(not material); row.note:Hide()
        local height
        if material then
            row.icon:SetTexture(itemIcon(entry.itemID))
            row.requirement:SetText(entry.required and tostring(entry.required) or "")
            tint(row.requirement, colors.text)
            height = renderOwners(row, entry.sources, entry.required)
            if entry.missingOne and entry.missingOne > 0 then
                row.note:SetText("Missing: " .. entry.missingOne)
                tint(row.note, colors.short); row.note:Show()
                height = math.max(height, 46)
            end
        else
            for _, line in ipairs(row.stockRows) do line:Hide() end
            row.detail:ClearAllPoints(); row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -10)
            row.detail:SetText(entry.detail or ""); tint(row.detail, colors.text)
            height = row.title:GetStringHeight() + row.detail:GetStringHeight() + 28
        end
        row:SetHeight(height); row:Show(); top = top + height + 4
    end
    for index = #entries + 1, #rows do rows[index]:Hide() end
    body:SetHeight(math.max(top, 1))
    -- Fit short lists, then keep the window bounded and scroll longer lists.
    local listTop = view == "recipe" and 190 or 166
    panel:SetHeight(math.min(maxPanelHeight, math.max(280, listTop + 69 + body:GetHeight())))
    fitBackground()
    tableHeader:SetShown(hasMaterials)
    needHeader:SetShown(hasMaterials and view == "recipe")
    scroll:UpdateScrollChildRect()
    local range = math.max(0, math.floor(scroll:GetVerticalScrollRange()))
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), range))
    ScrollFrame_OnScrollRangeChanged(scroll, 0, range)
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

local function updateBorder()
    if borderCollapsed == collapsed then return end
    local border = panel.NineSlice
    NineSliceUtil.ApplyLayoutByName(border, "ButtonFrameTemplateNoPortrait")
    if collapsed then
        -- Preserve the native outer border; shorten only the corners' inner tails.
        for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner"}) do
            local piece = border[key]
            local info = C_Texture.GetAtlasInfo(piece:GetAtlas())
            if info and (info.file or info.filename) then
                local upper = key == "TopLeftCorner" or key == "TopRightCorner"
                local keep = math.min(info.height, upper and 40 or 20)
                local span = (info.bottomTexCoord - info.topTexCoord) * keep / info.height
                local top = upper and info.topTexCoord or info.bottomTexCoord - span
                local bottom = upper and info.topTexCoord + span or info.bottomTexCoord
                piece:SetTexture(info.file or info.filename)
                piece:SetTexCoord(info.leftTexCoord, info.rightTexCoord, top, bottom)
                piece:SetSize(info.width, keep)
            end
        end
    end
    borderCollapsed = collapsed
end

local function position()
    if not panel then return end
    local frame = ProfessionsFrame
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", dockGap, -45)
    panel:SetWidth(collapsed and compactWidth or width)
    maxPanelHeight = math.max(500, math.min(700, frame:GetHeight() - 45))
    panel:SetHeight(collapsed and 52 or maxPanelHeight)
    fitBackground()
    collapse:ClearAllPoints()
    collapse:SetPoint("TOPRIGHT", -5, -3)
    collapse:SetText(collapsed and "+" or "-")
    panel.InsetBg:SetShown(not collapsed)
    updateBorder()
    reserveSpace(panel:IsVisible())
end

local function scanStatus()
    local state = addon.GetScanSummary()
    if not state then return "Log in to record your inventory." end
    local bank = state.bank or {}
    local line
    if bank.stale then
        line = "Your bank: rescan needed"
    elseif bank.scanned then
        line = state.bankOpen and "Your bank: live" or ("Your bank: " .. age(bank.updatedAt))
    else
        line = "Open your bank to scan it"
    end
    return (state.characterCount or 1) .. " characters  |  " .. line
end

local function setRecipeHeader(name, icon)
    recipeName:SetText(name or "")
    recipeIcon:SetTexture(icon or 134400)
    recipeIcon:SetShown(name ~= nil)
    recipeName:SetShown(name ~= nil)
end

local function refreshContents()
    position()
    for _, widget in ipairs({recipeTab, materialsTab, scroll, hero, scanText, tableHeader}) do
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
    stockSummary:Hide(); stockNote:Hide(); summary:Show()
    if view == "materials" then
        setRecipeHeader(nil)
        headline:SetText("Find your materials")
        tint(headline, colors.text)
        summary:Hide()
        hero:ClearAllPoints(); hero:SetPoint("TOPLEFT", 14, -78); hero:SetHeight(22)
        tableHeader:ClearAllPoints(); tableHeader:SetPoint("TOPLEFT", 14, -144)
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 14, -166); scroll:SetPoint("BOTTOMRIGHT", -30, 69)
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
    hero:ClearAllPoints(); hero:SetPoint("TOPLEFT", 14, -112); hero:SetHeight(44)
    tableHeader:ClearAllPoints(); tableHeader:SetPoint("TOPLEFT", 14, -168)
    scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 14, -190); scroll:SetPoint("BOTTOMRIGHT", -30, 69)
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
        stockNote:SetText(plan.stockUnknown and "Banks / alts need scanning" or "Recorded bags, banks and alts")
        stockNote:Show()
    end
    local entries, hasCurrency = {}, false
    for _, ingredient in ipairs(plan.ingredients) do
        hasCurrency = hasCurrency or ingredient.currencyID ~= nil
        entries[#entries + 1] = {kind = "material", title = ingredient.name, itemID = ingredient.itemID,
            required = ingredient.required, bags = ingredient.bags, sources = ingredient.sources,
            missingOne = ingredient.missingOne}
    end
    if hasCurrency then summary:SetText("Bags and owned currency") end
    if plan.incomplete then entries[#entries + 1] = {title = "Review this recipe", detail = plan.message} end
    if not recipe.learned then entries[#entries + 1] = {title = "Recipe not learned", detail = "Learn this recipe before crafting it."} end
    renderRows(entries)
end

local function refreshFallback()
    -- Avoid inventory/recipe APIs and row rendering while handling their failure.
    for _, row in ipairs(rows) do row:Hide() end
    body:SetHeight(1)
    for _, widget in ipairs({search, filter, scroll, tableHeader, recipeIcon, recipeName, stockSummary, stockNote}) do
        widget:Hide()
    end
    recipeTab:SetShown(not collapsed); materialsTab:SetShown(not collapsed)
    hero:SetShown(not collapsed); scanText:SetShown(not collapsed)
    if collapsed then return end
    panel:SetHeight(280)
    fitBackground()
    hero:ClearAllPoints(); hero:SetPoint("TOPLEFT", 14, -112); hero:SetHeight(44)
    headline:SetText("Recipe loading"); tint(headline, colors.text)
    summary:SetText("Unable to read materials. Select a recipe to try again."); summary:Show()
    scanText:SetText("Inventory details unavailable.")
end

local function refresh()
    if not panel or not panel:IsVisible() then return end
    local ok, err = pcall(refreshContents)
    if not ok then
        refreshFallback()
        if not refreshErrorLogged then
            refreshErrorLogged = true
            print("CraftGlance: material refresh failed; select a recipe to retry. " .. tostring(err))
        end
    end
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
        -- Keep native tab geometry, with the profession frame's quieter brown palette.
        for _, key in ipairs({"LeftActive", "MiddleActive", "RightActive"}) do
            local piece = control[key]
            if piece then
                piece:SetDesaturated(true); piece:SetVertexColor(0.60, 0.43, 0.24); piece:SetAlpha(0.75)
            end
        end
        for _, key in ipairs({"Left", "Middle", "Right"}) do
            local piece = control[key]
            if piece then piece:SetVertexColor(0.90, 0.78, 0.60); piece:SetAlpha(0.75) end
        end
        for _, key in ipairs({"LeftHighlight", "MiddleHighlight", "RightHighlight"}) do
            local piece = control[key]
            if piece then piece:SetAlpha(0.12) end
        end
        return control
    end
    recipeTab = tab("This Recipe", 14, function() view = "recipe"; scroll:SetVerticalScroll(0); refresh() end)
    materialsTab = tab("All Materials", 202, function() view = "materials"; scroll:SetVerticalScroll(0); refresh() end)
    recipeIcon = panel:CreateTexture(nil, "ARTWORK")
    recipeIcon:SetSize(28, 28); recipeIcon:SetPoint("TOPLEFT", 18, -75)
    recipeIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    recipeName = singleLine(text(panel, "GameFontNormalLarge", 56, -80, "", width - 76))
    hero = CreateFrame("Frame", nil, panel)
    hero:SetSize(width - 28, 44)
    hero.background = background(hero, 0, 0, 0, 0)
    headline = singleLine(text(hero, "GameFontHighlightLarge", 0, 0, "", 190))
    summary = text(hero, "GameFontHighlightSmall", 0, -23, "", width - 28)
    tint(summary, colors.muted)
    stockSummary = singleLine(text(hero, "GameFontNormal", 196, -2, "", width - 224))
    stockNote = singleLine(text(hero, "GameFontHighlightSmall", 196, -23, "", width - 224))
    tint(stockNote, colors.muted)
    hero:EnableMouse(true)
    hero:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Craft now uses bags and owned currency")
        GameTooltip:AddLine("Known stock includes recorded bags and banks. Counts marked * are last observed after a failed scan and excluded from Known stock until rescanned. Required tools, location and cooldowns still apply.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    hero:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 21, -108); search:SetSize(width - 46, 26)
    search:SetAutoFocus(false); search:SetMaxLetters(80)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    search:SetScript("OnTextChanged", function() if view == "materials" then scroll:SetVerticalScroll(0); schedule() end end)
    search:SetText(""); search:Hide()
    tableHeader = CreateFrame("Frame", nil, panel); tableHeader:SetSize(rowWidth, 20)
    tableHeader.divider = tableHeader:CreateTexture(nil, "BORDER")
    tableHeader.divider:SetHeight(1)
    tableHeader.divider:SetPoint("BOTTOMLEFT", 0, 0); tableHeader.divider:SetPoint("BOTTOMRIGHT", 0, 0)
    tableHeader.divider:SetColorTexture(0.62, 0.48, 0.27, 0.8)
    singleLine(text(tableHeader, "GameFontNormal", 4, 0, "Material", 136))
    needHeader = singleLine(text(tableHeader, "GameFontNormal", 137, 0, "Need", 44))
    needHeader:SetJustifyH("CENTER")
    singleLine(text(tableHeader, "GameFontNormal", 180, 0, "Character", 64))
    local bagHeader = singleLine(text(tableHeader, "GameFontNormal", 248, 0, "Bags", 40))
    local bankHeader = singleLine(text(tableHeader, "GameFontNormal", 292, 0, "Bank", 64))
    bagHeader:SetJustifyH("CENTER"); bankHeader:SetJustifyH("CENTER")
    tableHeader:EnableMouse(true)
    tableHeader:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Material stock")
        GameTooltip:AddLine("Need is the quantity for one craft. Bags and Bank show each character's full holding, including scanned zeros. Not scanned means that inventory is unknown. * means last observed after a failed scan; excluded from Known stock. Hover a character for scan times.", 0.9, 0.9, 0.9, true)
        GameTooltip:Show()
    end)
    tableHeader:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    scroll = CreateFrame("ScrollFrame", "CraftGlanceScroll", panel, "UIPanelScrollFrameTemplate")
    scroll.scrollBarHideable = true
    body = CreateFrame("Frame", nil, scroll); body:SetSize(rowWidth, 1); scroll:SetScrollChild(body)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", scrollMaterials)
    filter = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    filter:SetSize(23, 23); filter:SetPoint("BOTTOMLEFT", 10, 31)
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
