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
local itemMetadata = {
    [2589] = {name = "Linen Cloth", reagent = true},
    [2592] = {name = "Wool Cloth", reagent = true},
    [1251] = {name = "Linen Bandage", reagent = false},
    [9001] = {name = "Linen Armor", reagent = false},
    [9002] = {name = "Unclassified item"},
    [9003] = {},
}
local loadRequests = {}
C_Item = {
    GetItemInfo = function(id)
        local metadata = itemMetadata[id] or {}
        local info = {[1] = metadata.name, [17] = metadata.reagent}
        return unpack(info, 1, 17)
    end,
    RequestLoadItemDataByID = function(id) loadRequests[id] = (loadRequests[id] or 0) + 1 end,
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
local function event(name, ...)
    for _, frame in ipairs(frames) do if frame.events[name] then frame.handler(frame, name, ...) end end
end
local function loadModules()
    addon, frames = {}, {}
    assert(loadfile("CraftGlance/Inventory.lua"))("CraftGlance", addon)
    assert(loadfile("CraftGlance/Materials.lua"))("CraftGlance", addon)
    event("ADDON_LOADED", "CraftGlance")
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
assert(plan.craftNow == 1 and plan.ingredients[1].required == 7)
assert(plan.ingredients[1].missingOne == 0 and plan.ingredients[1].knownTotal == 12)
assert(plan.craftWithKnownStock == 1 and not plan.stockUnknown)
assert(plan.target == nil and plan.action == nil and plan.pickups == nil and plan.transfers == nil and plan.acquire == nil,
    "The stock model does not prescribe an extra craft or partial transfers")
local list = addon.GetMaterialList("linen")
assert(#list == 1 and list[1].total == 12, "Account bank and other rulesets cannot inflate totals")
local choices = item(2589, 1)
choices.reagents[2] = {itemID = 2592}
local choicePlan = addon.BuildRecipePlan({choices})
assert(choicePlan.incomplete and choicePlan.craftNow == nil and choicePlan.craftWithKnownStock == nil
    and choicePlan.message and choicePlan.stockUnknown)
C_CurrencyInfo = {GetCurrencyInfo = function() return {name = "Token", quantity = 100} end}
local currencyPlan = addon.BuildRecipePlan({{required = true, quantityRequired = 3, reagents = {{currencyID = 10}}}})
assert(currencyPlan.incomplete and currencyPlan.craftNow == nil and currencyPlan.craftWithKnownStock == nil,
    "Currency requirements do not imply an item-inventory craft count")
local shortages = addon.ReadMaterials({item(2589, 4), item(2589, 3)}, function() return 5 end, function() return "Linen Cloth" end)
assert(shortages[1].missing == 2, "Existing repeated-ingredient behavior stays intact")
local originalSources = addon.GetSources
local stockSources = {
    {guid = player.guid, name = player.name, isCurrent = true, location = "bags", count = 4, scanned = true},
    {guid = player.guid, name = player.name, isCurrent = true, location = "bank", count = 0, scanned = true},
    {guid = "Player-B", name = "Bea", isCurrent = false, location = "bags", count = 9, scanned = true, updatedAt = 900},
    {guid = "Player-B", name = "Bea", isCurrent = false, location = "bank", scanned = false},
}
containers[0][1].stackCount = 4
addon.GetSources = function() return stockSources end
plan = addon.BuildRecipePlan({item(2589, 1)})
assert(plan.craftNow == 4 and plan.craftWithKnownStock == 13)
assert(plan.ingredients[1].knownTotal == 13 and plan.ingredients[1].missingOne == 0)
assert(plan.stockUnknown and plan.ingredients[1].unknown, "Unscanned alt banks remain explicitly unknown")
assert(plan.ingredients[1].sources[3].count == 9 and stockSources[3].count == 9,
    "The owner list retains all nine alt items rather than requesting one")
stockSources[1].count = 400
assert(addon.BuildRecipePlan({item(2589, 1)}).ingredients[1].knownTotal == 13,
    "Current bag snapshots cannot double-count or override the live bag quantity")
containers[0][1].stackCount = 2
stockSources = {
    {isCurrent = true, location = "bags", count = 2, scanned = true},
    {isCurrent = true, location = "bank", count = 9, scanned = true, updatedAt = 900},
}
plan = addon.BuildRecipePlan({item(2589, 5)})
assert(plan.craftNow == 0 and plan.ingredients[1].missingOne == 3)
assert(plan.ingredients[1].knownTotal == 11 and plan.craftWithKnownStock == 2 and not plan.stockUnknown,
    "A missing-three recipe still displays the full nine-bank stock")
addon.GetSources = originalSources
plan = addon.BuildRecipePlan({item(2589, 1), item(2592, 2)})
assert(plan.craftNow == 1 and plan.craftWithKnownStock == 1, "The scarcest ingredient limits craft counts")
containers[0][1].stackCount = 7
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
for _, entry in ipairs({{1251, 40}, {9001, 1}, {9002, 5}, {9003, 6}, {9004, 1}}) do
    containers[0][#containers[0] + 1] = {itemID = entry[1], stackCount = entry[2]}
end
loadModules()
local inventory = CraftGlanceDB.characters[player.guid].bags.items
local beforeLinen = inventory[2589]
list = addon.GetMaterialList("linen")
assert(#list == 1 and list[1].itemID == 2589,
    "A matching name cannot include finished bandages or equipment without the crafting-reagent flag")
assert(#addon.GetMaterialList("1251") == 0 and #addon.GetMaterialList("9001") == 0,
    "An exact item ID cannot bypass crafting-material filtering")
assert(#addon.GetMaterialList("9002") == 0 and #addon.GetMaterialList("9003") == 0,
    "An unknown flag or uncached item stays hidden until confirmed")
assert(loadRequests[9002] == 1 and loadRequests[9003] == 1,
    "Repeated searches request missing item metadata once while pending")
itemMetadata[9002] = {name = "Linen Thread", reagent = true}
local refreshes = 0
addon.InventoryChanged = function() refreshes = refreshes + 1 end
event("ITEM_DATA_LOAD_RESULT", 9002, true)
assert(refreshes == 1 and #addon.GetMaterialList("9002") == 1,
    "Loaded crafting metadata refreshes the list without rescanning or losing stock")
itemMetadata[9003] = {name = "Quest Item", reagent = false}
event("GET_ITEM_INFO_RECEIVED", 9003, true)
assert(#addon.GetMaterialList("9003") == 0, "Loaded non-materials remain excluded")
local apiInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = nil
assert(#addon.GetMaterialList("9004") == 0, "An unavailable metadata API never admits untagged items")
C_Item.GetItemInfo = apiInfo
assert(inventory[1251] == 40 and inventory[9001] == 1 and inventory[2589] == beforeLinen,
    "Display filtering never deletes saved inventory observations")
assert(addon.BuildRecipePlan({item(2589, 1)}).craftNow == 7,
    "The materials-list filter leaves selected-recipe bag counts unchanged")
print("CraftGlance inventory persistence and recipe planning passed")
