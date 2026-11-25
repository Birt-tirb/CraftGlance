local _, addon = ...
local api = C_TradeSkillUI
local events = CreateFrame("Frame")
local panel, form, body, scroll, filter, search, headline, summary, scanText
local collapse, recipeTab, materialsTab, hero, recipeName, recipeIcon, columns
local view, collapsed = "recipe", false
local queued, lastRecipe, baseExtra, reservedExtra
local rows = {}
local width, compactWidth, dockGap = 360, 184, 55
local rowWidth = width - 44
local columnX = {154, 194, 234, 274}
local colors = {
    text = {0.92, 0.89, 0.81}, muted = {0.68, 0.70, 0.70},
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

local function sourceLines(sources)
    local lines = {}
    for _, source in ipairs(sources or {}) do
        if source.location ~= "bags" or not source.isCurrent then
            local who = source.isCurrent and "Your bank" or
                ((source.name or "Character") .. " - " .. source.location)
            if source.scanned == false then
                lines[#lines + 1] = who .. ": not scanned"
            elseif source.count and source.count > 0 then
                lines[#lines + 1] = ("%s: %d (%s)"):format(who, source.count, age(source.updatedAt))
            end
        end
    end
    return table.concat(lines, "\n")
end

local function totals(sources)
    local bankCount, altCount, hasAlt, altUnknown = nil, 0, false, false
    for _, source in ipairs(sources or {}) do
        if source.isCurrent and source.location == "bank" then
            if source.scanned then bankCount = source.count end
        elseif not source.isCurrent then
            hasAlt = true
            if source.scanned and source.count ~= nil then altCount = altCount + source.count
            else altUnknown = true end
        end
    end
    local altText = "-"
    if hasAlt then
        altText = altUnknown and (altCount > 0 and (altCount .. "+") or "?") or tostring(altCount)
    end
    return bankCount == nil and "?" or tostring(bankCount), altText
end

local function quantity(value)
    return value == nil and "?" or tostring(value)
end

local function nextAction(plan)
    if plan.incomplete then return plan.action end
    local lines = {}
    for _, item in ipairs(plan.pickups or {}) do
        lines[#lines + 1] = ("Pick up %d %s from your bank."):format(item.count, item.name)
    end
    for _, item in ipairs(plan.transfers or {}) do
        lines[#lines + 1] = ("Get %d %s from %s's %s."):format(
            item.count, item.name, item.source.name, item.source.location)
    end
    for _, item in ipairs(plan.acquire or {}) do
        lines[#lines + 1] = ("You need %d more %s."):format(item.count, item.name)
    end
    for _, ingredient in ipairs(plan.ingredients or {}) do
        for _, source in ipairs(ingredient.sources or {}) do
            if not source.scanned then
                lines[#lines + 1] = "Unscanned bags or banks may hold more."
                return table.concat(lines, "\n")
            end
        end
    end
    return table.concat(lines, "\n")
end

local function renderRows(entries)
    local top = 0
    for index, entry in ipairs(entries) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", nil, body)
            row.background = background(row, 1, 1, 1, 0.035)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(30, 30)
            row.icon:SetPoint("TOPLEFT", 9, -10)
            row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            row.title = text(row, "GameFontNormal", 48, -10, "", 102)
            row.detail = text(row, "GameFontHighlightSmall", 10, -50, "", rowWidth - 20)
            tint(row.detail, colors.muted)
            row.cells = {}
            for column, x in ipairs(columnX) do
                local cell = text(row, "GameFontHighlight", x, -16, "", 38)
                cell:SetJustifyH("CENTER")
                row.cells[column] = cell
            end
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                if not GameTooltip or not self.itemID then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:AddLine("CraftGlance: Need is for one craft. Craft now uses bags only.", 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine("Bank and alt counts are last observed. ? means not scanned; + means more inventories need scanning.", 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            rows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -top)
        row:SetWidth(rowWidth)
        row.itemID = entry.itemID
        row.title:ClearAllPoints()
        row.detail:ClearAllPoints()
        row.title:SetText(entry.title)
        local material = entry.kind == "material"
        row.icon:SetShown(material)
        for _, cell in ipairs(row.cells) do cell:SetShown(material) end
        if material then
            row.detail:SetFontObject("GameFontHighlightSmall")
            tint(row.detail, colors.muted)
            row.icon:SetTexture(itemIcon(entry.itemID))
            row.title:SetPoint("TOPLEFT", 48, -10)
            row.title:SetWidth(102)
            row.detail:SetPoint("TOPLEFT", 10, -math.max(47, row.title:GetStringHeight() + 19))
            row.detail:SetText(entry.detail or "")
            local bankCount, altCount = totals(entry.sources)
            local values = {entry.required and tostring(entry.required) or "-", quantity(entry.bags), bankCount, altCount}
            for column, value in ipairs(values) do
                row.cells[column]:SetText(value)
                tint(row.cells[column], colors.text)
            end
            if entry.bags ~= nil and entry.required then
                tint(row.cells[2], entry.bags >= entry.required and colors.good or colors.short)
            end
            if bankCount ~= "?" and tonumber(bankCount) > 0 then tint(row.cells[3], colors.bank) end
            row:SetHeight(math.max(47, row.title:GetStringHeight() + 19) +
                ((entry.detail and entry.detail ~= "") and row.detail:GetStringHeight() + 11 or 7))
            row.background:SetColorTexture(1, 1, 1, index % 2 == 1 and 0.045 or 0.015)
        else
            row.title:SetPoint("TOPLEFT", 12, -12)
            row.title:SetWidth(rowWidth - 24)
            row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -8)
            row.detail:SetFontObject("GameFontHighlight")
            row.detail:SetText(entry.detail or "")
            tint(row.detail, colors.text)
            row:SetHeight(row.title:GetStringHeight() + row.detail:GetStringHeight() + 34)
            row.background:SetColorTexture(0.65, 0.48, 0.19, entry.kind == "action" and 0.14 or 0.04)
        end
        row:Show()
        top = top + row:GetHeight() + 7
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
    panel:SetHeight(collapsed and 36 or math.max(500, math.min(700, frame:GetHeight() - 45)))
    collapse:ClearAllPoints()
    collapse:SetPoint("TOPRIGHT", -8, -7)
    collapse:SetText(collapsed and "+" or "-")
    reserveSpace(panel:IsVisible())
end

local function scanStatus()
    local state = addon.GetScanSummary()
    if not state then return "Log in to record your inventory." end
    local bank = state.bank or {}
    local line = state.bankOpen and "Bank open - live counts" or
        (bank.scanned and ("Bank saved " .. age(bank.updatedAt)) or "Open your bank to scan it")
    return line .. "  |  " .. (state.characterCount or 1) .. " character(s)\nLog into alts to record their bags and banks."
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
    for _, widget in ipairs({recipeTab, materialsTab, scroll, hero, scanText, columns}) do
        widget:SetShown(not collapsed)
    end
    if collapsed then search:Hide(); filter:Hide(); recipeIcon:Hide(); recipeName:Hide(); return end
    local linked = (api.IsTradeSkillLinked and api.IsTradeSkillLinked()) or
        (api.IsTradeSkillGuild and api.IsTradeSkillGuild()) or
        (api.IsNPCCrafting and api.IsNPCCrafting())
    search:SetShown(view == "materials")
    recipeTab:SetEnabled(view ~= "recipe")
    materialsTab:SetEnabled(view ~= "materials")
    scanText:SetText(scanStatus())
    local supportsFilter = type(api.GetOnlyShowMakeableRecipes) == "function"
        and type(api.SetOnlyShowMakeableRecipes) == "function"
    filter:SetShown(supportsFilter and not linked)
    if supportsFilter then filter:SetChecked(api.GetOnlyShowMakeableRecipes()) end
    if view == "materials" then
        setRecipeHeader(nil)
        headline:SetText("Find your materials")
        tint(headline, colors.text)
        summary:SetText("Search recorded bags, banks and characters.")
        hero:ClearAllPoints(); hero:SetPoint("TOPLEFT", 14, -78)
        hero:SetHeight(69)
        columns:ClearAllPoints(); columns:SetPoint("TOPLEFT", 14, -192)
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 14, -215); scroll:SetPoint("BOTTOMRIGHT", -30, 93)
        local entries = {}
        for _, material in ipairs(addon.GetMaterialList(search:GetText()) or {}) do
            entries[#entries + 1] = {kind = "material", title = material.name, itemID = material.itemID,
                bags = material.bags, sources = material.sources, detail = sourceLines(material.sources)}
        end
        if #entries == 0 then entries[1] = {title = "No recorded material matches.",
            detail = "Try a name or item ID. Visit banks and log into alts to record more."} end
        renderRows(entries)
        return
    end
    hero:ClearAllPoints(); hero:SetPoint("TOPLEFT", 14, -129); hero:SetHeight(68)
    columns:ClearAllPoints(); columns:SetPoint("TOPLEFT", 14, -211)
    scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", 14, -234); scroll:SetPoint("BOTTOMRIGHT", -30, 93)
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
    setRecipeHeader(recipe.name, recipe.icon or recipe.iconID)
    local plan = addon.BuildRecipePlan(schematic.reagentSlotSchematics)
    headline:SetText(plan.craftNow and ("Craft now: " .. plan.craftNow) or "Check reagent choices")
    tint(headline, plan.craftNow and plan.craftNow > 0 and colors.good or colors.short)
    summary:SetText("Materials in your bags only")
    local entries = {}
    for _, ingredient in ipairs(plan.ingredients) do
        entries[#entries + 1] = {kind = "material", title = ingredient.name, itemID = ingredient.itemID,
            required = ingredient.required, bags = ingredient.bags, sources = ingredient.sources,
            detail = sourceLines(ingredient.sources)}
    end
    entries[#entries + 1] = {kind = "action", title = plan.target and ("Next craft  #" .. plan.target) or "Next craft",
        detail = nextAction(plan) or "Review the required reagents."}
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
    panel = CreateFrame("Frame", "CraftGlancePanel", page, "BackdropTemplate")
    panel:SetSize(width, 560)
    panel:SetFrameLevel(page:GetFrameLevel() + 5)
    panel:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = {left = 3, right = 3, top = 3, bottom = 3}})
    panel:SetBackdropColor(0.055, 0.055, 0.048, 0.99)
    panel:SetBackdropBorderColor(0.62, 0.48, 0.24)
    text(panel, "GameFontNormal", 14, -13, "CraftGlance", compactWidth - 50)
    collapse = button(panel, "-", width - 38, -7, 26, function() collapsed = not collapsed; refresh() end)
    recipeTab = button(panel, "This Recipe", 14, -42, 158, function() view = "recipe"; scroll:SetVerticalScroll(0); refresh() end)
    materialsTab = button(panel, "All Materials", 180, -42, 166, function() view = "materials"; scroll:SetVerticalScroll(0); refresh() end)
    recipeIcon = panel:CreateTexture(nil, "ARTWORK")
    recipeIcon:SetSize(36, 36); recipeIcon:SetPoint("TOPLEFT", 16, -80)
    recipeIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    recipeName = text(panel, "GameFontNormalLarge", 62, -82, "", width - 80)
    hero = CreateFrame("Frame", nil, panel)
    hero:SetSize(width - 28, 68)
    hero.background = background(hero, 0.16, 0.19, 0.14, 0.6)
    headline = text(hero, "GameFontHighlightLarge", 12, -11, "", width - 52)
    summary = text(hero, "GameFontHighlight", 12, -39, "", width - 52)
    tint(summary, colors.muted)
    hero:EnableMouse(true)
    hero:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Craft now uses bags only")
        GameTooltip:AddLine("Bank and alt stock help you plan pickups. Required tools, location and cooldowns still apply.", 0.9, 0.9, 0.9, true)
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
    columns = CreateFrame("Frame", nil, panel)
    columns:SetSize(rowWidth, 18)
    local materialLabel = text(columns, "GameFontHighlightSmall", 9, 0, "Material", 140)
    tint(materialLabel, colors.muted)
    for index, caption in ipairs({"Need", "Bags", "Bank", "Alts"}) do
        local label = text(columns, "GameFontHighlightSmall", columnX[index], 0, caption, 38)
        label:SetJustifyH("CENTER"); tint(label, colors.muted)
    end
    scroll = CreateFrame("ScrollFrame", "CraftGlanceScroll", panel, "UIPanelScrollFrameTemplate")
    body = CreateFrame("Frame", nil, scroll); body:SetSize(rowWidth, 1); scroll:SetScrollChild(body)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 35)))
    end)
    filter = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    filter:SetSize(23, 23); filter:SetPoint("BOTTOMLEFT", 10, 65)
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
