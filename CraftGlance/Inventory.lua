local _, addon = ...
local current, bankOpen, bagsObserved = nil, false, false
local events = CreateFrame("Frame")
local materialInfo, itemRequests = {}, {}

local function plain(value)
    return not issecretvalue or not issecretvalue(value)
end

local function number(value)
    return plain(value) and type(value) == "number" and value >= 0 and value < math.huge
end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and plain(value) then return value end
end

local function now()
    return call(GetServerTime) or call(time) or 0
end

local function snapshot(value)
    if type(value) ~= "table" then value = {} end
    if type(value.items) ~= "table" then value.items = {} end
    if type(value.containers) ~= "table" then value.containers = {} end
    value.scanned = value.scanned == true
    -- Older snapshots recorded failed scans in state without clearing scanned.
    value.stale = value.stale == true or
        (value.scanned and value.state ~= nil and value.state ~= "scanned")
    if not number(value.updatedAt) then value.updatedAt = nil end
    return value
end

local function roster()
    if type(CraftGlanceDB) ~= "table" then CraftGlanceDB = {} end
    if type(CraftGlanceDB.characters) ~= "table" then CraftGlanceDB.characters = {} end
    CraftGlanceDB.inventoryVersion = 2
    return CraftGlanceDB.characters
end

local function identityNumber(value)
    if number(value) and value > 0 and value == math.floor(value) then return value end
end

local function realmName(value)
    if not plain(value) or type(value) ~= "string" then return nil end
    local normalized = value:lower():gsub("%s+", "")
    if normalized ~= "" then return normalized end
end

local function guidRealm(guid)
    if not plain(guid) or type(guid) ~= "string" then return nil end
    local realm = guid:match("^Player%-(%d+)%-%x+$")
    return identityNumber(tonumber(realm))
end

local function scopeKey(region, realm, guid)
    if not identityNumber(region) then return nil end
    local component = guidRealm(guid)
    if component then return "realm-guid-v1:" .. region .. ":" .. component end
    local normalized = realmName(realm)
    if normalized then return "realm-v2:" .. region .. ":" .. normalized end
end

local function migrateScope(character)
    local key, normalized = character.ruleset, realmName(character.realm)
    if type(key) ~= "string" then return end
    local component = guidRealm(character.guid)
    local region, identity = key:match("^realm%-guid%-v1:(%d+):(%d+)$")
    local kind = region and "guid"
    if not region then
        region, identity = key:match("^realm%-v2:(%d+):(.+)$")
        kind = region and "name"
    end
    if not region then
        region, identity = key:match("^(%d+):(.*)$")
        kind = region and "legacy"
    end
    if not region and component and key == "unverified:" .. character.guid then
        region, kind = character.region, "unverified"
    end
    region = identityNumber(tonumber(region))
    if not region or (character.region ~= nil and character.region ~= region) then return end
    local storedID = identityNumber(character.realmID)
    if character.realmID ~= nil and character.realmID ~= 0 and not storedID then return end
    local legacyID
    if kind == "guid" then
        if not component or identity ~= tostring(component) then return end
    elseif kind == "name" then
        if not normalized or identity ~= normalized then return end
    elseif kind == "legacy" then
        legacyID = identityNumber(tonumber(identity))
        if legacyID then
            if tostring(legacyID) ~= identity or (storedID and storedID ~= legacyID) then return end
        elseif (identity == "0" or identity == "") and component then
            -- Forever can report no realm name and a zero or missing realm ID. Only the
            -- individual Player GUID can disambiguate those old shared keys.
            if storedID then return end
        elseif not normalized or realmName(identity) ~= normalized then
            return
        end
    end
    local stable = scopeKey(region, character.realm, character.guid)
    if not stable then return end
    character.region = region
    character.realmID = storedID or legacyID
    character.ruleset = stable
end

local function ensureCharacter()
    local guid = call(UnitGUID, "player")
    local name, realm = call(UnitName, "player"), call(GetRealmName)
    if type(guid) ~= "string" or type(name) ~= "string" then return nil end
    if type(realm) ~= "string" then
        if not guidRealm(guid) then return nil end
        realm = ""
    end
    local characters = roster()
    for _, recorded in pairs(characters) do
        if type(recorded) == "table" then migrateScope(recorded) end
    end
    local character = characters[guid]
    if type(character) ~= "table" then character = {} end
    local sameGUIDRealm = character.guid == guid and guidRealm(guid) ~= nil
    local sameRealm = sameGUIDRealm or realmName(character.realm) == realmName(realm)
    local region = identityNumber(call(GetCurrentRegion))
    local realmID = identityNumber(call(GetRealmID))
    -- A missing API result must not erase identity learned for this same GUID.
    if not region and sameRealm then region = identityNumber(character.region) end
    if not realmID and sameRealm and character.region == region then realmID = identityNumber(character.realmID) end
    if not realmName(realm) and sameRealm and character.region == region and realmName(character.realm) then
        realm = character.realm
    end
    character.guid, character.name, character.realm = guid, name, realm
    character.faction = call(UnitFactionGroup, "player") or "Unknown"
    character.realmID, character.region = realmID, region
    -- Prefer the stable realm component of a real Player GUID even if APIs later
    -- supply names or IDs. Unknown regions remain isolated to this character.
    character.ruleset = scopeKey(region, realm, guid) or ("unverified:" .. guid)
    character.bags, character.bank = snapshot(character.bags), snapshot(character.bank)
    character.lastSeen = now()
    characters[guid], current = character, character
    return character
end

local function changed()
    if type(addon.InventoryChanged) == "function" then addon.InventoryChanged() end
end

local function bagIDs()
    local ids = {0}
    local maximum = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    local reagentBag = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
    if number(reagentBag) then maximum = math.max(maximum, reagentBag) end
    if not number(maximum) or maximum > 12 then maximum = 4 end
    for bagID = 1, maximum do ids[#ids + 1] = bagID end
    return ids
end

local function readContainers(ids, names, bank)
    if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemInfo then
        return nil, "unavailable"
    end
    local result = {scanned = true, stale = false, updatedAt = now(), state = "scanned", items = {}, containers = {}}
    for _, bagID in ipairs(ids) do
        local slots = call(C_Container.GetContainerNumSlots, bagID)
        if not number(slots) or slots ~= math.floor(slots) or (bank and slots == 0) then return nil, "unavailable" end
        local container = {
            id = bagID, name = names and names[bagID] or call(C_Container.GetBagName, bagID),
            size = slots, stacks = {}, updatedAt = result.updatedAt, scanned = true,
        }
        for slot = 1, slots do
            local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slot)
            if not ok or not plain(info) then return nil, "unavailable" end
            if info then
                local itemID, count = info.itemID, info.stackCount
                if not number(itemID) or itemID == 0 then return nil, "unavailable" end
                if not number(count) then return nil, "unavailable", itemID end
                container.stacks[#container.stacks + 1] = {
                    slot = slot, itemID = itemID, count = count,
                    link = plain(info.hyperlink) and info.hyperlink or nil,
                }
                result.items[itemID] = (result.items[itemID] or 0) + count
            elseif C_Container.GetContainerItemID then
                local idOK, itemID = pcall(C_Container.GetContainerItemID, bagID, slot)
                if not idOK or not plain(itemID) then return nil, "unavailable" end
                if itemID ~= nil and itemID ~= 0 then return nil, "unavailable", itemID end
            end
        end
        result.containers[bagID] = container
    end
    return result
end

function addon.ScanBags()
    local character = ensureCharacter()
    if not character then return false end
    local observed, reason = readContainers(bagIDs())
    bagsObserved = observed ~= nil
    if observed then
        character.bags = observed
    else
        character.bags.state, character.bags.stale = reason, true
    end
    changed()
    return observed ~= nil
end

local function characterBankIDs()
    local bankType = Enum and Enum.BankType and Enum.BankType.Character
    if not C_Bank or bankType == nil then return nil, "unsupported" end
    if C_Bank.CanViewBank and not call(C_Bank.CanViewBank, bankType) then return nil, "unavailable" end
    local details = call(C_Bank.FetchPurchasedBankTabData, bankType)
    local tabs = call(C_Bank.FetchPurchasedBankTabIDs, bankType)
    if not C_Bank.FetchPurchasedBankTabIDs and type(details) == "table" then
        tabs = {}
        for _, tab in ipairs(details) do
            if type(tab) ~= "table" or not number(tab.ID) then return nil, "unavailable" end
            tabs[#tabs + 1] = tab.ID
        end
    end
    if type(tabs) ~= "table" then return nil, "unavailable" end
    local ids, names, seen = {}, {}, {}
    for _, bagID in ipairs(tabs) do
        if not number(bagID) or bagID <= 0 or bagID ~= math.floor(bagID) then return nil, "unavailable" end
        if not seen[bagID] then ids[#ids + 1], seen[bagID] = bagID, true end
    end
    if C_Bank.FetchNumPurchasedBankTabs then
        local count = call(C_Bank.FetchNumPurchasedBankTabs, bankType)
        if not number(count) or count ~= #ids then return nil, "unavailable" end
    end
    if type(details) == "table" then
        for _, tab in ipairs(details) do
            if type(tab) == "table" and number(tab.ID) and plain(tab.name) then names[tab.ID] = tab.name end
        end
    end
    return ids, names
end

local waitingBankItemID
function addon.ScanBank()
    if not bankOpen then return false end
    local character = ensureCharacter()
    if not character then return false end
    local ids, names = characterBankIDs()
    local observed, reason
    waitingBankItemID = nil
    if ids and (#ids > 0 or next(character.bank.containers) == nil) then
        observed, reason, waitingBankItemID = readContainers(ids, names, true)
    else
        reason = type(names) == "string" and names or "unavailable"
    end
    if observed then
        character.bank = observed
    else
        character.bank.state = reason or "unavailable"
        character.bank.stale = true
    end
    changed()
    return observed ~= nil
end

local queuedBankScan
local function queueBankScan()
    if queuedBankScan then return end
    if not C_Timer or not C_Timer.After then addon.ScanBank(); return end
    local function scanIfQueued()
        if queuedBankScan ~= scanIfQueued then return end
        queuedBankScan = nil
        addon.ScanBank()
    end
    queuedBankScan = scanIfQueued
    C_Timer.After(0.1, scanIfQueued)
end

function addon.GetBagCount(itemID)
    if not number(itemID) or itemID == 0 then return nil end
    local fn = C_Item and C_Item.GetItemCount or GetItemCount
    local count = call(fn, itemID, false, false, false, false)
    if number(count) then return count end
    if current and bagsObserved then return current.bags.items[itemID] or 0 end
    return nil
end

local function compatible(character)
    if not current then return false end
    migrateScope(character)
    if character.faction ~= current.faction or character.ruleset ~= current.ruleset or
        character.region ~= current.region then return false end
    local component, currentComponent = guidRealm(character.guid), guidRealm(current.guid)
    if component or currentComponent then return component ~= nil and component == currentComponent end
    local realmID, currentID = identityNumber(character.realmID), identityNumber(current.realmID)
    return realmName(character.realm) == realmName(current.realm) and
        not (realmID and currentID and realmID ~= currentID)
end

local function source(character, location, itemID)
    local stored = snapshot(character[location])
    local isCurrent = current and character.guid == current.guid
    local count = stored.scanned and (stored.items[itemID] or 0) or nil
    if not number(count) then count = nil end
    if isCurrent and location == "bags" then count = addon.GetBagCount(itemID) end
    local live = isCurrent and (location == "bags" and count ~= nil or location == "bank" and bankOpen and stored.state == "scanned")
    local stale = stored.stale and not (isCurrent and location == "bags" and live)
    if stale then live = false end
    return {
        guid = character.guid, name = character.name, realm = character.realm,
        faction = character.faction, ruleset = character.ruleset, location = location,
        count = count, updatedAt = stored.updatedAt, isCurrent = not not isCurrent,
        scanned = count ~= nil and (stored.scanned or live), stale = not not stale,
        state = stored.state or "unscanned", live = not not live,
    }
end

function addon.GetSources(itemID)
    if not current then ensureCharacter() end
    local rows = {}
    if not number(itemID) or itemID == 0 then return rows end
    for _, character in pairs(roster()) do
        if type(character) == "table" and compatible(character) then
            for _, location in ipairs({"bags", "bank"}) do
                rows[#rows + 1] = source(character, location, itemID)
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.isCurrent ~= b.isCurrent then return a.isCurrent end
        if a.name ~= b.name then return (a.name or "") < (b.name or "") end
        if a.realm ~= b.realm then return (a.realm or "") < (b.realm or "") end
        return a.location == "bags" and b.location ~= "bags"
    end)
    return rows
end

local function craftingMaterial(itemID)
    local cached = materialInfo[itemID]
    if cached then return cached.name, cached.reagent end
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(getInfo) ~= "function" then return nil, false end
    local ok, info = pcall(function() return {getInfo(itemID)} end)
    if not ok or not plain(info[1]) or not plain(info[17]) then return nil, false end
    if info[1] and type(info[17]) == "boolean" then
        materialInfo[itemID] = {name = info[1], reagent = info[17]}
        return info[1], info[17]
    end
    -- Unknown metadata is not a material tag. Retry after the client loads it.
    if not itemRequests[itemID] and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        itemRequests[itemID] = true
        call(C_Item.RequestLoadItemDataByID, itemID)
    end
    return nil, false
end

function addon.GetMaterialList(query)
    if not current then ensureCharacter() end
    local ids, materials = {}, {}
    for _, character in pairs(roster()) do
        if type(character) == "table" and compatible(character) then
            for _, location in ipairs({"bags", "bank"}) do
                for itemID in pairs(snapshot(character[location]).items) do
                    if number(itemID) and itemID > 0 then ids[itemID] = true end
                end
            end
        end
    end
    query = type(query) == "string" and query:lower() or ""
    for itemID in pairs(ids) do
        local name, reagent = craftingMaterial(itemID)
        if reagent and (query == "" or tostring(itemID) == query or name:lower():find(query, 1, true)) then
            local sources, total = addon.GetSources(itemID), 0
            for _, row in ipairs(sources) do if number(row.count) then total = total + row.count end end
            if total > 0 then
                materials[#materials + 1] = {itemID = itemID, name = name, bags = addon.GetBagCount(itemID), sources = sources, total = total}
            end
        end
    end
    table.sort(materials, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.itemID < b.itemID
    end)
    return materials
end

function addon.GetScanSummary()
    if not current then ensureCharacter() end
    local summary = {currentName = current and current.name, characters = {}, characterCount = 0, unscannedBanks = 0}
    for _, character in pairs(roster()) do
        if type(character) == "table" and compatible(character) then
            local row = {
                guid = character.guid, name = character.name, realm = character.realm,
                ruleset = character.ruleset, faction = character.faction,
                isCurrent = current and character.guid == current.guid,
                bags = snapshot(character.bags), bank = snapshot(character.bank),
            }
            summary.characters[#summary.characters + 1] = row
            summary.characterCount = summary.characterCount + 1
            if not row.bank.scanned or row.bank.stale then summary.unscannedBanks = summary.unscannedBanks + 1 end
            if row.isCurrent then summary.bags, summary.bank = row.bags, row.bank end
        end
    end
    table.sort(summary.characters, function(a, b) return (a.name or "") < (b.name or "") end)
    summary.bankOpen = bankOpen
    return summary
end

for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, name, success)
    if event == "ADDON_LOADED" then
        if name == "CraftGlance" then roster() end
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        if number(name) then
            materialInfo[name] = nil
            if success then
                itemRequests[name] = nil
                if name == waitingBankItemID then queueBankScan() end
            end
            changed()
        end
    elseif event == "PLAYER_LOGIN" then
        ensureCharacter()
        addon.ScanBags()
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        addon.ScanBags()
        addon.ScanBank()
        queueBankScan()
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
        queuedBankScan, waitingBankItemID = nil, nil
        addon.ScanBags()
    else
        -- A bag or bank change can move stock between both snapshots. The old
        -- bank count is safe to display, but cannot be trusted until the rescan.
        if bankOpen and current then
            current.bank.state, current.bank.stale = "pending", true
        end
        addon.ScanBags()
        if bankOpen then queueBankScan() end
    end
end)
