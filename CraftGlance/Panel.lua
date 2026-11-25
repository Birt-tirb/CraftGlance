local _, addon = ...
local api = C_TradeSkillUI
local events = CreateFrame("Frame")
local panel, form, body, scroll, filter, search, headline, summary, scanText
local collapse, recipeTab, materialsTab
local view, collapsed = "recipe", false
local queued, lastRecipe
local rows = {}
local width = 326

local function text(parent, style, x, y, value, textWidth)
    local label = parent:CreateFontString(nil, "OVERLAY", style)
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(textWidth or width - 28)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(value or "")
    return label
end

local function button(parent, caption, x, y, buttonWidth, callback)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(buttonWidth, 24)
    control:SetPoint("TOPLEFT", x, y)
    control:SetText(caption)
    control:SetScript("OnClick", callback)
    return control
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
            local who = source.isCurrent and "You" or source.name
            if source.realm and not source.isCurrent then who = who .. " (" .. source.realm .. ")" end
            local location = source.location == "bank" and "bank" or "bags"
            if source.scanned == false then
                lines[#lines + 1] = who .. " - " .. location .. " needs scanning"
            elseif source.count and source.count > 0 then
                lines[#lines + 1] = ("%s - %s: %d (%s)"):format(
                    who, location, source.count, age(source.updatedAt))
            end
        end
    end
    return table.concat(lines, "\n")
end

local function renderRows(entries)
    local top = 3
    for index, entry in ipairs(entries) do
        local row = rows[index]
        if not row then
            row = CreateFrame("Frame", nil, body)
            row.title = text(row, "GameFontNormal", 0, 0, "", width - 52)
            row.detail = text(row, "GameFontHighlightSmall", 0, 0, "", width - 52)
            row.detail:SetTextColor(0.78, 0.79, 0.77)
            rows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -top)
        row:SetWidth(width - 44)
        row.title:SetText(entry.title)
        row.detail:ClearAllPoints()
        row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)
        row.detail:SetText(entry.detail or "")
        local height = row.title:GetStringHeight() + row.detail:GetStringHeight() + 21
        row:SetHeight(height)
        row:Show()
        top = top + height
    end
    for index = #entries + 1, #rows do rows[index]:Hide() end
    body:SetHeight(math.max(top, 1))
end

local function position()
    if not panel then return end
    local frame = ProfessionsFrame
    local anchor = frame
    local bank = BankFrame
    if bank and bank:IsShown() and (bank:GetRight() or 0) > (frame:GetRight() or 0) then
        anchor = bank
    end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 57, -45)
    local available = UIParent:GetWidth() * UIParent:GetEffectiveScale() / anchor:GetEffectiveScale() - (anchor:GetRight() or 0)
    if available < width + 65 and (frame:GetLeft() or 0) > width + 8 then
        panel:ClearAllPoints()
        panel:SetPoint("TOPRIGHT", frame, "TOPLEFT", -8, -45)
    end
    panel:SetHeight(collapsed and 36 or math.max(440, math.min(650, frame:GetHeight() - 45)))
    collapse:SetText(collapsed and "+" or "-")
end

local function scanStatus()
    local state = addon.GetScanSummary()
    if not state then return "Log in to scan this character." end
    local bank = state.bank or {}
    local line = state.bankOpen and "Bank open - counts updating" or
        (bank.scanned and ("Your bank saved " .. age(bank.updatedAt)) or "Your bank needs a scan - open a bank.")
    return line .. "\n" .. (state.characterCount or 1) .. " character(s) recorded. Log in on alts to scan bags."
end

local function refresh()
    if not panel or not panel:IsVisible() then return end
    position()
    for _, widget in ipairs({recipeTab, materialsTab, scroll, headline, summary, scanText}) do
        widget:SetShown(not collapsed)
    end
    if collapsed then search:Hide(); filter:Hide(); return end
    local linked = (api.IsTradeSkillLinked and api.IsTradeSkillLinked()) or
        (api.IsTradeSkillGuild and api.IsTradeSkillGuild()) or
        (api.IsNPCCrafting and api.IsNPCCrafting())
    search:SetShown(view == "materials")
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", 14, view == "materials" and -188 or -163)
    scroll:SetPoint("BOTTOMRIGHT", -30, 92)
    recipeTab:SetEnabled(view ~= "recipe")
    materialsTab:SetEnabled(view ~= "materials")
    scanText:SetText(scanStatus())
    local supportsFilter = type(api.GetOnlyShowMakeableRecipes) == "function"
        and type(api.SetOnlyShowMakeableRecipes) == "function"
    filter:SetShown(supportsFilter and not linked)
    if supportsFilter then filter:SetChecked(api.GetOnlyShowMakeableRecipes()) end
    if view == "materials" then
        headline:SetText("All Materials")
        headline:SetTextColor(1, 0.82, 0.35)
        summary:SetText("Search by item name or ID. Bank and alt counts are saved observations.")
        local entries = {}
        for _, material in ipairs(addon.GetMaterialList(search:GetText()) or {}) do
            entries[#entries + 1] = {
                title = material.name .. "  |  Bags " .. (material.bags == nil and "?" or material.bags),
                detail = sourceLines(material.sources),
            }
        end
        if #entries == 0 then
            entries[1] = {title = "No recorded material matches.", detail = "Try an item name or ID. Visit a bank and log in on your alts to record more."}
        end
        renderRows(entries)
        return
    end
    if linked then
        headline:SetText("Your recipes")
        summary:SetText("Open your own profession to compare your materials.")
        renderRows({})
        return
    end
    if api.IsTradeSkillReady and not api.IsTradeSkillReady() then
        headline:SetText("Recipe loading")
        summary:SetText("Waiting for your profession's recipes.")
        renderRows({})
        return
    end
    local recipe = form:GetRecipeInfo()
    if not recipe or not recipe.recipeID or not form:IsVisible() then
        headline:SetText("Select a recipe")
        summary:SetText("Click a recipe in the crafting window.")
        renderRows({})
        return
    end
    local recipeLevel = form.GetCurrentRecipeLevel and form:GetCurrentRecipeLevel()
    local schematic = api.GetRecipeSchematic(recipe.recipeID, false, recipeLevel)
    if not schematic or not schematic.reagentSlotSchematics then
        headline:SetText("Recipe loading")
        summary:SetText("Waiting for the recipe's material requirements.")
        renderRows({})
        return
    end
    local plan = addon.BuildRecipePlan(schematic.reagentSlotSchematics)
    headline:SetText(plan.craftNow and ("Craft now: " .. plan.craftNow) or "Check reagent choices")
    headline:SetTextColor(plan.craftNow and plan.craftNow > 0 and 0.55 or 1, 0.85, 0.48)
    summary:SetText(recipe.name .. "\nFrom your bags. Tools, location and cooldowns still apply.")
    local entries = {}
    for _, ingredient in ipairs(plan.ingredients) do
        local details = ("Need %d  |  Bags %s\nMissing for one craft: %s\nFor one beyond current bags: %s"):format(
            ingredient.required, ingredient.bags == nil and "?" or ingredient.bags,
            ingredient.missingOne == nil and "?" or ingredient.missingOne,
            ingredient.missingNext == nil and "?" or ingredient.missingNext)
        local sources = sourceLines(ingredient.sources)
        if sources ~= "" then details = details .. "\n" .. sources end
        entries[#entries + 1] = {title = ingredient.name, detail = details}
    end
    entries[#entries + 1] = {title = "For one more craft", detail = plan.action or "Review this recipe's reagents."}
    if not recipe.learned then
        entries[#entries + 1] = {title = "Recipe not learned", detail = "Learn the recipe before crafting it."}
    end
    renderRows(entries)
end

local function schedule()
    if queued or not panel then return end
    queued = true
    C_Timer.After(0.05, function() queued = false; refresh() end)
end
addon.RefreshPanel = schedule
addon.InventoryChanged = schedule

local function attach()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if panel or not page or not page.SchematicForm then return end
    form = page.SchematicForm
    panel = CreateFrame("Frame", "CraftGlancePanel", page, "BackdropTemplate")
    panel:SetSize(width, 560)
    panel:SetFrameLevel(page:GetFrameLevel() + 5)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14, insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    panel:SetBackdropColor(0.07, 0.055, 0.035, 0.98)
    panel:SetBackdropBorderColor(0.62, 0.48, 0.24)
    text(panel, "GameFontNormal", 14, -13, "CraftGlance", width - 60)
    collapse = button(panel, "-", width - 40, -7, 28, function()
        collapsed = not collapsed; refresh()
    end)
    recipeTab = button(panel, "This Recipe", 14, -42, 139, function()
        view = "recipe"; scroll:SetVerticalScroll(0); refresh()
    end)
    materialsTab = button(panel, "All Materials", 160, -42, 151, function()
        view = "materials"; scroll:SetVerticalScroll(0); refresh()
    end)
    headline = text(panel, "GameFontHighlightLarge", 14, -82, "")
    summary = text(panel, "GameFontHighlightSmall", 14, -111, "")
    search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetPoint("TOPLEFT", 21, -153)
    search:SetSize(width - 46, 25)
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnTextChanged", function()
        if view == "materials" then scroll:SetVerticalScroll(0); schedule() end
    end)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    search:SetText("")
    search:Hide()
    scroll = CreateFrame("ScrollFrame", "CraftGlanceScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -163)
    scroll:SetPoint("BOTTOMRIGHT", -30, 92)
    body = CreateFrame("Frame", nil, scroll)
    body:SetSize(width - 44, 1)
    scroll:SetScrollChild(body)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local value = self:GetVerticalScroll() - delta * 30
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), value)))
    end)
    filter = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    filter:SetSize(23, 23)
    filter:SetPoint("BOTTOMLEFT", 10, 65)
    filter.Text:SetText("Craftable only")
    filter:SetHitRectInsets(0, -105, 0, 0)
    filter:SetScript("OnClick", function(self)
        api.SetOnlyShowMakeableRecipes(self:GetChecked() == true); schedule()
    end)
    scanText = text(panel, "GameFontHighlightSmall", 14, 0, "", width - 28)
    scanText:ClearAllPoints()
    scanText:SetPoint("BOTTOMLEFT", 14, 12)
    scanText:SetTextColor(0.68, 0.69, 0.66)
    page:HookScript("OnShow", function() view = "recipe"; schedule() end)
    form:HookScript("OnShow", schedule)
    form:HookScript("OnHide", schedule)
    if type(form.Init) == "function" then
        hooksecurefunc(form, "Init", function()
            local recipe = form:GetRecipeInfo()
            if recipe and recipe.recipeID ~= lastRecipe then
                lastRecipe = recipe.recipeID; view = "recipe"; scroll:SetVerticalScroll(0)
            end
            schedule()
        end)
    end
    panel:HookScript("OnShow", schedule)
    position()
    schedule()
end

for _, event in ipairs({
    "ADDON_LOADED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD",
    "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "SPELL_UPDATE_COOLDOWN",
}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function()
    if not panel then attach() end
    schedule()
end)
SLASH_CRAFTGLANCE1 = "/craftglance"
SLASH_CRAFTGLANCE2 = "/cg"
SlashCmdList.CRAFTGLANCE = function()
    attach()
    if panel and ProfessionsFrame:IsShown() then collapsed = false; refresh()
    else print("CraftGlance: open a crafting profession and select a recipe.") end
end
