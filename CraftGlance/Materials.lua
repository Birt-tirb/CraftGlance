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

local function knownStock(ingredient)
    local total = validCount(ingredient.bags) and ingredient.bags or 0
    local unknown = not validCount(ingredient.bags)
    for _, source in ipairs(ingredient.sources) do
        -- Current bags are already counted from the live bag-only query above.
        if not (source.isCurrent and source.location == "bags") then
            if source.scanned and validCount(source.count) then
                total = total + source.count
            else
                unknown = true
            end
        end
    end
    return total, unknown
end

function addon.BuildRecipePlan(slots)
    local ingredients, incomplete = ingredientsFrom(slots)
    local plan = {ingredients = ingredients, incomplete = incomplete, stockUnknown = incomplete}
    local crafts, stockCrafts = math.huge, math.huge
    for _, ingredient in ipairs(ingredients) do
        ingredient.name, ingredient.bags = identify(ingredient)
        ingredient.sources = ingredient.itemID and addon.GetSources(ingredient.itemID) or {}
        if validCount(ingredient.bags) then
            ingredient.missingOne = math.max(0, ingredient.required - ingredient.bags)
            crafts = math.min(crafts, math.floor(ingredient.bags / ingredient.required))
        else
            plan.incomplete = true
        end
        ingredient.knownTotal, ingredient.unknown = knownStock(ingredient)
        plan.stockUnknown = plan.stockUnknown or ingredient.unknown
        stockCrafts = math.min(stockCrafts, math.floor(ingredient.knownTotal / ingredient.required))
    end
    if #ingredients == 0 then plan.incomplete = true end
    if plan.incomplete then
        plan.stockUnknown = true
        plan.message = "Check the recipe's required reagent choices and available inventory."
    else
        plan.craftNow, plan.craftWithKnownStock = crafts, stockCrafts
    end
    return plan
end
