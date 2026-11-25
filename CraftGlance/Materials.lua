local _, addon = ...

local function validCount(value)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == "number"
        and value >= 0 and value < math.huge
end

local function ingredientsFrom(slots)
    local ingredients, ordered, incomplete = {}, {}, false
    if type(slots) ~= "table" then return ordered, true end
    for _, slot in ipairs(slots) do
        local basic = Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Basic
        if slot.required == true or (basic and slot.required ~= false) then
            local options = slot.reagents or {}
            local reagent = options[1]
            local required = slot.quantityRequired
            if #options ~= 1 or not reagent or not (reagent.itemID or reagent.currencyID)
                or not validCount(required) or required < 1 or required ~= math.floor(required) then
                incomplete = true
            else
                local key = reagent.itemID and ("i" .. reagent.itemID) or ("c" .. reagent.currencyID)
                local ingredient = ingredients[key]
                if not ingredient then
                    ingredient = {reagent = reagent, itemID = reagent.itemID, currencyID = reagent.currencyID, required = 0}
                    ingredients[key] = ingredient
                    ordered[#ordered + 1] = ingredient
                end
                ingredient.required = ingredient.required + required
            end
        end
    end
    return ordered, incomplete
end

-- Count repeated ingredients once, against the combined requirement.
function addon.ReadMaterials(slots, getOwned, getName)
    local ordered, incomplete = ingredientsFrom(slots)
    local shortages = {}
    for _, ingredient in ipairs(ordered) do
        local owned = getOwned(ingredient.reagent)
        if not validCount(owned) then
            incomplete = true
        elseif owned < ingredient.required then
            shortages[#shortages + 1] = {
                name = getName(ingredient.reagent),
                missing = ingredient.required - owned,
            }
        end
    end
    return shortages, incomplete
end

local function identify(ingredient)
    if ingredient.itemID then
        local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(ingredient.itemID)
        return name or ("Item #" .. ingredient.itemID), addon.GetBagCount(ingredient.itemID)
    end
    local currency = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(ingredient.currencyID)
    return currency and currency.name or ("Currency #" .. ingredient.currencyID), nil
end

local function allocate(plan, ingredient, remaining, currentBank)
    for _, source in ipairs(ingredient.sources) do
        local takeFrom = source.location == "bank" and source.isCurrent
        if takeFrom == currentBank and (currentBank or not source.isCurrent)
            and source.scanned and validCount(source.count) and source.count > 0 and remaining > 0 then
            local count = math.min(remaining, source.count)
            local action = {itemID = ingredient.itemID, currencyID = ingredient.currencyID,
                name = ingredient.name, count = count, source = source}
            local list = currentBank and plan.pickups or plan.transfers
            list[#list + 1] = action
            remaining = remaining - count
        end
    end
    return remaining
end

local function itemText(item)
    return item.count .. " " .. item.name
end

local function observedAt(source)
    if source.live then return "observed now" end
    if validCount(source.updatedAt) and date then return "recorded " .. date("%d %b %H:%M", source.updatedAt) end
    return "recorded inventory"
end

function addon.BuildRecipePlan(slots)
    local ingredients, incomplete = ingredientsFrom(slots)
    local plan = {ingredients = ingredients, incomplete = incomplete, pickups = {}, transfers = {}, acquire = {}}
    local crafts = math.huge
    for _, ingredient in ipairs(ingredients) do
        ingredient.name, ingredient.bags = identify(ingredient)
        ingredient.sources = ingredient.itemID and addon.GetSources(ingredient.itemID) or {}
        if validCount(ingredient.bags) then
            ingredient.missingOne = math.max(0, ingredient.required - ingredient.bags)
            crafts = math.min(crafts, math.floor(ingredient.bags / ingredient.required))
        else
            plan.incomplete = true
        end
    end
    if #ingredients == 0 then plan.incomplete = true end
    if not plan.incomplete then plan.craftNow, plan.target = crafts, crafts + 1 end
    for _, ingredient in ipairs(ingredients) do
        if validCount(ingredient.bags) then
            ingredient.missingNext = math.max(0, ingredient.required * (plan.target or 1) - ingredient.bags)
            local remaining = allocate(plan, ingredient, ingredient.missingNext, true)
            remaining = allocate(plan, ingredient, remaining, false)
            if remaining > 0 then
                plan.acquire[#plan.acquire + 1] = {itemID = ingredient.itemID, currencyID = ingredient.currencyID,
                    name = ingredient.name, count = remaining}
            end
        end
    end
    if plan.incomplete then
        plan.action = "Check the recipe's required reagent choices and available inventory before planning a craft."
        return plan
    end
    local lines, unscanned = {}, false
    for _, item in ipairs(plan.pickups) do
        lines[#lines + 1] = "Withdraw " .. itemText(item) .. " from your bank (" .. observedAt(item.source) .. ")."
    end
    for _, item in ipairs(plan.transfers) do
        local source = item.source
        lines[#lines + 1] = "Get " .. itemText(item) .. " from " .. source.name .. "-" .. source.realm
            .. "'s " .. source.location .. " (" .. observedAt(source) .. ")."
    end
    for _, item in ipairs(plan.acquire) do lines[#lines + 1] = "Acquire " .. itemText(item) .. "." end
    for _, ingredient in ipairs(ingredients) do
        for _, source in ipairs(ingredient.sources) do
            if not source.scanned then unscanned = true end
        end
    end
    if unscanned then lines[#lines + 1] = "Unscanned inventories may contain more materials. Visit the bank to record it." end
    plan.action = table.concat(lines, "\n")
    return plan
end
