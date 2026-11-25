local addon, frames = {}, {}
local player = {guid = "Player-A", name = "Ari", realm = "Normal", faction = "Alliance", realmID = 1}
local clock, bankVisible, flags = 1000, false, nil
local containers = {[0] = {{itemID = 2589, stackCount = 7}}, [5] = {{itemID = 2592, stackCount = 3}},
    [6] = {{itemID = 2589, stackCount = 2}}, [15] = {{itemID = 2589, stackCount = 100}}}
local unavailable, purchased, infoLoading = nil, {6}, false
Enum = {CraftingReagentType = {Basic = 0, Optional = 1}, BankType = {Character = 0, Account = 2}, BagIndex = {ReagentBag = 5}}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
function issecretvalue() return false end
function GetServerTime() return clock end
function GetCurrentRegion() return 3 end
function GetRealmID() return player.realmID end
function GetRealmName() return player.realm end
function UnitName() return player.name end
function UnitGUID() return player.guid end
function UnitFactionGroup() return player.faction end
function CreateFrame()
    local frame = {events = {}}
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(_, fn) self.handler = fn end
    frames[#frames + 1] = frame
    return frame
end
C_Container = {
    GetContainerNumSlots = function(id)
        if unavailable == id then error("inaccessible") end
        return #(containers[id] or {})
    end,
    GetContainerItemInfo = function(id, slot)
        if infoLoading and id == 6 then return nil end
        return containers[id] and containers[id][slot]
    end,
    GetContainerItemID = function(id, slot)
        local item = containers[id] and containers[id][slot]
        return item and item.itemID
    end,
    GetBagName = function(id) return "Container " .. id end,
}
C_Item = {
    GetItemInfo = function(id) return ({[2589] = "Linen Cloth", [2592] = "Wool Cloth"})[id] end,
    GetItemCount = function(id, bank, uses, reagent, account)
        flags = {bank, uses, reagent, account}
        local result = 0
        for bag = 0, 5 do
            for _, item in ipairs(containers[bag] or {}) do
                if item.itemID == id then result = result + item.stackCount end
            end
        end
        return result
    end,
}
C_Bank = {
    CanViewBank = function(kind) return bankVisible and kind == Enum.BankType.Character end,
    FetchPurchasedBankTabIDs = function(kind)
        assert(kind == Enum.BankType.Character, "Never duplicate a shared account bank on characters")
        return purchased
    end,
    FetchPurchasedBankTabData = function() return {{ID = 6, name = "Crafting"}} end,
    FetchNumPurchasedBankTabs = function() return 1 end,
}
local function event(name)
    for _, frame in ipairs(frames) do if frame.events[name] then frame.handler(frame, name, "CraftGlance") end end
end
local function loadModules()
    addon, frames = {}, {}
    assert(loadfile("CraftGlance/Inventory.lua"))("CraftGlance", addon)
    assert(loadfile("CraftGlance/Materials.lua"))("CraftGlance", addon)
    event("ADDON_LOADED")
    event("PLAYER_LOGIN")
end
local function item(id, count)
    return {reagentType = 0, quantityRequired = count, reagents = {{itemID = id}}}
end
local function character(guid, name, bagCount, bankCount, scope)
    CraftGlanceDB.characters[guid] = {
        guid = guid, name = name, realm = scope or "Normal", ruleset = scope and "3:2" or "3:1", faction = "Alliance",
        bags = {scanned = true, updatedAt = 900, items = {[2589] = bagCount}},
        bank = {scanned = true, updatedAt = 800, items = {[2589] = bankCount}},
    }
end
loadModules()
assert(addon.GetBagCount(2589) == 7)
assert(flags[1] == false and flags[2] == false and flags[3] == false and flags[4] == false, "Bag counts exclude all banks")
assert(addon.GetBagCount(2592) == 3, "Include the reagent bag")
local saved = CraftGlanceDB.characters[player.guid]
assert(saved.bags.containers[5].stacks[1].itemID == 2592)
assert(not saved.bank.scanned and not addon.ScanBank(), "A closed bank cannot be scanned")
bankVisible = true
event("BANKFRAME_OPENED")
assert(saved.bank.items[2589] == 2 and saved.bank.containers[6].name == "Crafting")
bankVisible = false
event("BANKFRAME_CLOSED")
containers[6] = {}
clock = 1100
event("BAG_UPDATE_DELAYED")
assert(saved.bank.items[2589] == 2 and saved.bank.updatedAt == 1000, "Closing a bank preserves its snapshot")
bankVisible = true
event("BANKFRAME_OPENED")
assert(saved.bank.items[2589] == 2 and saved.bank.updatedAt == 1000, "Zero-capacity async bank tabs retain the prior snapshot")
containers[6], infoLoading = {{itemID = 2589, stackCount = 8}}, true
event("PLAYERBANKSLOTS_CHANGED")
assert(saved.bank.items[2589] == 2 and saved.bank.updatedAt == 1000,
    "A known item whose info is loading cannot become an empty bank slot")
infoLoading = false
purchased = {}
event("BANK_TABS_CHANGED")
assert(saved.bank.items[2589] == 2, "A transient empty tab list retains previous bank containers")
purchased = {6}
bankVisible, unavailable = true, 6
event("BANKFRAME_OPENED")
assert(saved.bank.items[2589] == 2 and saved.bank.updatedAt == 1000, "Partial scans retain a complete previous snapshot")
unavailable = nil
event("BANKFRAME_CLOSED")
character("Player-B", "Bea", 1, 2)
character("Player-C", "PvPAlt", 100, 100, "PvP")
local plan = addon.BuildRecipePlan({item(2589, 4), item(2589, 3)})
assert(plan.craftNow == 1 and plan.target == 2 and plan.ingredients[1].required == 7)
assert(plan.ingredients[1].missingOne == 0 and plan.ingredients[1].missingNext == 7)
assert(plan.pickups[1].count == 2, "Prioritize own bank")
assert(#plan.transfers == 2 and plan.transfers[1].count == 1 and plan.transfers[2].count == 2)
assert(plan.acquire[1].count == 2, "Only acquire the residual after available transfers")
assert(plan.action:find("Withdraw 2 Linen Cloth", 1, true) and plan.action:find("Acquire 2 Linen Cloth", 1, true))
local list = addon.GetMaterialList("linen")
assert(#list == 1 and list[1].total == 12, "Account bank and other rulesets cannot inflate totals")
local choices = item(2589, 1)
choices.reagents[2] = {itemID = 2592}
assert(addon.BuildRecipePlan({choices}).incomplete and addon.BuildRecipePlan({choices}).craftNow == nil)
C_CurrencyInfo = {GetCurrencyInfo = function() return {name = "Token", quantity = 100} end}
local currencyPlan = addon.BuildRecipePlan({{required = true, quantityRequired = 3, reagents = {{currencyID = 10}}}})
assert(currencyPlan.incomplete and currencyPlan.craftNow == nil, "Currency requirements do not imply an item-inventory craft count")
local shortages = addon.ReadMaterials({item(2589, 4), item(2589, 3)}, function() return 5 end, function() return "Linen Cloth" end)
assert(shortages[1].missing == 2, "Existing repeated-ingredient behavior stays intact")
loadModules()
assert(CraftGlanceDB.characters[player.guid].bank.items[2589] == 2, "Reload does not erase a bank snapshot")
assert(addon.GetScanSummary().characterCount == 2)
local originalGUID, originalName = player.guid, player.name
player.guid, player.name = "Player-D", "Dee"
purchased = {}
loadModules()
bankVisible = true
event("BANKFRAME_OPENED")
local fresh = CraftGlanceDB.characters[player.guid]
assert(not fresh.bank.scanned and fresh.bank.updatedAt == nil,
    "A newly observed character with a purchased tab awaiting its ID remains unscanned")
local idAPI = C_Bank.FetchPurchasedBankTabIDs
C_Bank.FetchPurchasedBankTabIDs = nil
event("BANK_TABS_CHANGED")
assert(fresh.bank.scanned and fresh.bank.items[2589] == 8,
    "Tab data supplies IDs if the dedicated ID API is missing")
C_Bank.FetchPurchasedBankTabIDs = idAPI
player.guid, player.name = originalGUID, originalName
print("CraftGlance inventory persistence and recipe planning passed")
