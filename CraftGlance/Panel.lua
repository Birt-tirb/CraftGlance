local _, addon = ...
local api = C_TradeSkillUI
local events = CreateFrame("Frame")
local panel, form, filter, title, status, detail
local queued, moved = false, false
local width = 216

local function nameOf(reagent)
    if reagent.itemID then
        return C_Item.GetItemInfo(reagent.itemID) or ("Item #" .. reagent.itemID)
    end
    local currency = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
    return currency and currency.name or ("Currency #" .. reagent.currencyID)
end

local function owned(reagent)
    if ProfessionsUtil and ProfessionsUtil.GetReagentQuantityInPossession then
        local transaction = form:GetTransaction()
        local bagsOnly = transaction and transaction.ShouldUseCharacterInventoryOnly
            and transaction:ShouldUseCharacterInventoryOnly()
        return ProfessionsUtil.GetReagentQuantityInPossession(reagent, bagsOnly or false)
    end
    if reagent.itemID then
        return C_Item.GetItemCount(reagent.itemID, true, false, true)
    end
    local currency = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
    return currency and currency.quantity
end

local function font(style)
    local text = panel:CreateFontString(nil, "OVERLAY", style)
    text:SetWidth(width - 28)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    return text
end

local function position()
    if moved then return end
    local frame = ProfessionsFrame
    local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local right, left = frame:GetRight(), frame:GetLeft()
    panel:ClearAllPoints()
    if right and (right + width + 64) * scale <= UIParent:GetWidth() then
        panel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 59, -48)
    elseif left and left > width + 8 then
        panel:SetPoint("TOPRIGHT", frame, "TOPLEFT", -6, -48)
    else
        panel:SetPoint("BOTTOMRIGHT", form, "BOTTOMRIGHT", -12, 42)
    end
end

local function show(recipe, headline, description, ready)
    title:SetText(recipe)
    status:SetText(headline)
    if ready then status:SetTextColor(0.48, 0.9, 0.52)
    else status:SetTextColor(1, 0.82, 0.42) end
    detail:SetText(description)
    panel:SetHeight(70 + title:GetStringHeight() + status:GetStringHeight() + detail:GetStringHeight())
    panel:Show()
end

local function refresh()
    if not panel or not ProfessionsFrame.CraftingPage:IsVisible() then return end
    if api.IsTradeSkillLinked() or api.IsTradeSkillGuild() then
        panel:Hide()
        return
    end
    position()
    filter:SetChecked(api.GetOnlyShowMakeableRecipes())
    if not api.IsTradeSkillReady() then
        show("Recipes", "Loading recipes.", "")
        return
    end
    local recipe = form:GetRecipeInfo()
    if not recipe or not recipe.recipeID or not form:IsVisible() then
        local message = filter:GetChecked() and "Clear the filter to see all recipes." or "Choose a recipe from the list."
        show("Recipes", "No recipe selected", message)
        return
    end
    if not recipe.learned then
        show(recipe.name, "Recipe not learned", "Learn this recipe to craft it.")
        return
    end
    local level = form.GetCurrentRecipeLevel and form:GetCurrentRecipeLevel()
    local schematic = api.GetRecipeSchematic(recipe.recipeID, false, level)
    local count = api.GetCraftableCount(recipe.recipeID)
    if not schematic or not schematic.reagentSlotSchematics or type(count) ~= "number" then
        show(recipe.name, "Material data unavailable", "See the recipe for its requirements.")
        return
    end
    if count > 0 then
        show(recipe.name, "Can craft " .. count, "Materials ready.", true)
        return
    end
    local missing, incomplete = addon.ReadMaterials(schematic.reagentSlotSchematics, owned, nameOf)
    local lines = {}
    for _, part in ipairs(missing) do
        lines[#lines + 1] = part.missing .. " � " .. part.name
    end
    if incomplete then lines[#lines + 1] = "Check reagent choices in the recipe." end
    if #missing > 0 then
        show(recipe.name, "Missing for one craft", table.concat(lines, "\n"))
    elseif incomplete then
        show(recipe.name, "Cannot craft yet", table.concat(lines, "\n"))
    else
        show(recipe.name, "Cannot craft yet", "Materials ready. Check the recipe's tools, location or cooldown.")
    end
end

local function schedule()
    if queued or not panel or not ProfessionsFrame.CraftingPage:IsVisible() then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        refresh()
    end)
end

local function attach()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if panel or not page or not page.SchematicForm then return end
    form = page.SchematicForm
    panel = CreateFrame("Frame", "CraftGlancePanel", page, "BackdropTemplate")
    panel:SetSize(width, 130)
    panel:SetFrameLevel(page:GetFrameLevel() + 15)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) moved = true; self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 13, insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    panel:SetBackdropColor(0.075, 0.055, 0.042, 0.97)
    panel:SetBackdropBorderColor(0.67, 0.51, 0.29)
    local brand = font("GameFontNormalSmall")
    brand:SetPoint("TOPLEFT", 14, -12)
    brand:SetText("CraftGlance")
    title = font("GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 0, -5)
    status = font("GameFontNormal")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    detail = font("GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -4)
    filter = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    filter:SetSize(23, 23)
    filter:SetPoint("BOTTOMLEFT", 9, 6)
    filter.Text:SetText("Craftable only")
    filter:SetHitRectInsets(0, -92, 0, 0)
    filter:SetScript("OnClick", function(self)
        api.SetOnlyShowMakeableRecipes(self:GetChecked() and true or false)
        schedule()
    end)
    page:HookScript("OnShow", schedule)
    form:HookScript("OnShow", schedule)
    form:HookScript("OnHide", schedule)
    hooksecurefunc(form, "Init", schedule)
    position()
    schedule()
end

for _, event in ipairs({
    "ADDON_LOADED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE",
    "TRADE_SKILL_DATA_SOURCE_CHANGED", "BAG_UPDATE_DELAYED",
    "CURRENCY_DISPLAY_UPDATE", "GET_ITEM_INFO_RECEIVED", "UI_SCALE_CHANGED",
    "DISPLAY_SIZE_CHANGED", "SPELL_UPDATE_COOLDOWN",
}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function()
    if not panel then attach() end
    schedule()
end)
