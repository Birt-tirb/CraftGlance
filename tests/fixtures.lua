-- Small stand-ins for the Forever UI. Run from the repository root with Lua 5.1.
local addon = {}
assert(loadfile("CraftGlance/Materials.lua"))("CraftGlance", addon)
Enum = {CraftingReagentType = {Basic = 0, Optional = 1}}
local items, counts, recipe, slots, count, filtered, ready = {}, {}, nil, {}, 0, false, true
local currency, linked = {}, false
local displayed, frames, timers = {}, {}, {}
local function noop() end
local function newWidget()
    local widget = {shown = true, scripts = {}, hooks = {}}
    for _, name in ipairs({"SetSize", "SetPoint", "ClearAllPoints", "SetClampedToScreen",
        "SetMovable", "EnableMouse", "RegisterForDrag", "SetBackdrop", "SetBackdropColor",
        "SetBackdropBorderColor", "SetJustifyH", "SetJustifyV", "SetWidth", "SetHeight",
        "SetFrameLevel", "SetTextColor", "SetHitRectInsets", "RegisterEvent"}) do
        widget[name] = noop
    end
    function widget:SetText(value) self.text = value end
    function widget:GetStringHeight() return 12 end
    function widget:GetEffectiveScale() return 1 end
    function widget:GetWidth() return 1920 end
    function widget:GetLeft() return 50 end
    function widget:GetRight() return 800 end
    function widget:GetFrameLevel() return 1 end
    function widget:Hide() self.shown = false end
    function widget:Show() self.shown = true end
    function widget:IsVisible() return self.shown end
    function widget:SetChecked(value) self.checked = value end
    function widget:GetChecked() return self.checked end
    function widget:SetScript(event, fn) self.scripts[event] = fn end
    function widget:HookScript(event, fn) self.hooks[event] = fn end
    function widget:CreateFontString()
        local label = newWidget()
        displayed[#displayed + 1] = label
        return label
    end
    return widget
end
function CreateFrame(kind, name)
    local frame = newWidget()
    if kind == "CheckButton" then frame.Text = newWidget() end
    if name then _G[name] = frame end
    frames[#frames + 1] = frame
    return frame
end
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
function hooksecurefunc(object, key, fn) object.hooks[key] = fn end
UIParent = newWidget()
C_Item = {GetItemCount = function(id) return counts[id] end,
    GetItemInfo = function(id) return items[id] end}
C_CurrencyInfo = {GetCurrencyInfo = function(id) return currency[id] end}
C_TradeSkillUI = {
    GetRecipeSchematic = function() return {reagentSlotSchematics = slots} end,
    GetCraftableCount = function() return count end,
    IsTradeSkillGuild = function() return false end,
    IsTradeSkillLinked = function() return linked end,
    IsTradeSkillReady = function() return ready end,
    GetOnlyShowMakeableRecipes = function() return filtered end,
    SetOnlyShowMakeableRecipes = function(value) filtered = value end,
}
assert(loadfile("CraftGlance/Panel.lua"))("CraftGlance", addon)
local function event(name)
    frames[1].scripts.OnEvent(frames[1], name)
    while #timers > 0 do table.remove(timers, 1)() end
end
event("ADDON_LOADED")
assert(#frames == 1, "Wait for the profession UI")
ProfessionsFrame = newWidget()
local page, form = newWidget(), newWidget()
ProfessionsFrame.CraftingPage, page.SchematicForm = page, form
function form:GetRecipeInfo() return recipe end
function form:GetTransaction() return {} end
local function item(id, required, optional)
    return {reagentType = optional and 1 or 0, reagents = {{itemID = id}},
        quantityRequired = required}
end
local function check(head, body)
    event("BAG_UPDATE_DELAYED")
    assert(displayed[3].text == head, tostring(displayed[3].text))
    assert(displayed[4].text == body, tostring(displayed[4].text))
end
check("No recipe selected", "Choose a recipe from the list.")
recipe = {learned = true, name = "Linen Bandage", recipeID = 3275}
slots, items[2589], counts[2589] = {item(2589, 1)}, "Linen Cloth", 0
check("Missing for one craft", "1 � Linen Cloth")
counts[2589], count = 5, 5
check("Can craft 5", "Materials ready.")
count = 0
slots = {item(2589, 4), item(2589, 3), item(1206, 1, true)}
check("Missing for one craft", "2 � Linen Cloth")
currency[10] = {quantity = 2, name = "Token"}
slots[4] = {required = true, quantityRequired = 3, reagents = {{currencyID = 10}}}
check("Missing for one craft", "2 � Linen Cloth\n1 � Token")
slots = {item(2589, 2)}
slots[1].reagents[2] = {itemID = 2600}
check("Cannot craft yet", "Check reagent choices in the recipe.")
slots = {}
check("Cannot craft yet", "Materials ready. Check the recipe's tools, location or cooldown.")
recipe.learned = false
check("Recipe not learned", "Learn this recipe to craft it.")
ready = false
check("Loading recipes.", "")
ready, recipe = true, nil
local filter = frames[3]
filter:SetChecked(true)
filter.scripts.OnClick(filter)
assert(filtered)
check("No recipe selected", "Clear the filter to see all recipes.")
filtered = false
event("TRADE_SKILL_LIST_UPDATE")
assert(not filter:GetChecked(), "Follow changes from the native Filter menu")
linked = true
event("TRADE_SKILL_DATA_SOURCE_CHANGED")
assert(not CraftGlancePanel.shown, "Hide another player's data")
linked = false
event("TRADE_SKILL_DATA_SOURCE_CHANGED")
assert(CraftGlancePanel.shown)
print("CraftGlance material, filter and panel fixtures passed")
