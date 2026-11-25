local _, addon = ...

-- Count a repeated ingredient once, against the combined requirement.
function addon.ReadMaterials(slots, getOwned, getName)
    local ingredients, ordered, shortages = {}, {}, {}
    local incomplete = false
    for _, slot in ipairs(slots) do
        local basic = slot.reagentType == Enum.CraftingReagentType.Basic
        if slot.required == true or (basic and slot.required ~= false) then
            local options = slot.reagents or {}
            local reagent = options[1]
            local required = slot.quantityRequired
            if #options ~= 1 or not reagent or not (reagent.itemID or reagent.currencyID)
                or type(required) ~= "number" or required < 1 then
                incomplete = true
            else
                local key = reagent.itemID and ("i" .. reagent.itemID) or ("c" .. reagent.currencyID)
                local ingredient = ingredients[key]
                if not ingredient then
                    ingredient = {reagent = reagent, required = 0}
                    ingredients[key] = ingredient
                    ordered[#ordered + 1] = ingredient
                end
                ingredient.required = ingredient.required + required
            end
        end
    end
    for _, ingredient in ipairs(ordered) do
        local owned = getOwned(ingredient.reagent)
        if type(owned) ~= "number" then
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
