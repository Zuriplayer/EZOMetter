-- Lectura compartida de sets equipados.
EZOMetter_EquipmentSets = EZOMetter_EquipmentSets or {}

local EquipmentSets = EZOMetter_EquipmentSets

local function CleanName(name)
    name = tostring(name or "")
    return string.gsub(name, "%^.*", "")
end

local function NormalizeName(name)
    name = CleanName(name)
    if name == "" then return "" end
    if type(zo_strlower) == "function" then
        name = zo_strlower(name)
    else
        name = string.lower(name)
    end
    name = string.gsub(name, "%-", " ")
    name = string.gsub(name, "%s+", " ")
    return name
end

local function AddSlot(slots, seen, slotName)
    local slot = _G[slotName]
    if slot ~= nil and seen[slot] ~= true then
        seen[slot] = true
        table.insert(slots, slot)
    end
end

local function GetWornSlots()
    local slots = {}
    local seen = {}
    local known = {
        "EQUIP_SLOT_HEAD",
        "EQUIP_SLOT_CHEST",
        "EQUIP_SLOT_SHOULDERS",
        "EQUIP_SLOT_WAIST",
        "EQUIP_SLOT_HAND",
        "EQUIP_SLOT_LEGS",
        "EQUIP_SLOT_FEET",
        "EQUIP_SLOT_NECK",
        "EQUIP_SLOT_RING1",
        "EQUIP_SLOT_RING2",
        "EQUIP_SLOT_MAIN_HAND",
        "EQUIP_SLOT_OFF_HAND",
        "EQUIP_SLOT_BACKUP_MAIN",
        "EQUIP_SLOT_BACKUP_OFF",
    }

    for _, slotName in ipairs(known) do
        AddSlot(slots, seen, slotName)
    end

    if #slots == 0 and BAG_WORN and type(GetBagSize) == "function" then
        for slot = 0, (GetBagSize(BAG_WORN) or 0) do
            table.insert(slots, slot)
        end
    end

    return slots
end

local function ReadSetInfo(itemLink)
    if not itemLink or itemLink == "" or type(GetItemLinkSetInfo) ~= "function" then
        return nil
    end

    local ok, hasSet, setName, numBonuses, numEquipped, maxEquipped, setId = pcall(GetItemLinkSetInfo, itemLink, true)
    if not ok then
        ok, hasSet, setName, numBonuses, numEquipped, maxEquipped, setId = pcall(GetItemLinkSetInfo, itemLink)
    end
    if not ok or not hasSet then return nil end

    return {
        setName = CleanName(setName),
        normalizedName = NormalizeName(setName),
        numBonuses = tonumber(numBonuses) or 0,
        numEquipped = tonumber(numEquipped) or 0,
        maxEquipped = tonumber(maxEquipped) or 0,
        setId = tonumber(setId) or 0,
    }
end

function EquipmentSets.NameMatches(setName, aliases)
    local normalized = NormalizeName(setName)
    if normalized == "" then return false end

    for _, alias in ipairs(aliases or {}) do
        local normalizedAlias = NormalizeName(alias)
        if normalized == normalizedAlias or string.find(normalized, normalizedAlias, 1, true) or string.find(normalizedAlias, normalized, 1, true) then
            return true
        end
    end

    return false
end

function EquipmentSets.GetWornSetSnapshot(matchFunc)
    local snapshot = {
        hasSet = false,
        setName = "",
        setId = 0,
        numEquipped = 0,
        maxEquipped = 0,
        slots = {},
        debugRows = {},
    }

    if BAG_WORN == nil or type(GetItemLink) ~= "function" then
        return snapshot
    end

    for _, slot in ipairs(GetWornSlots()) do
        local itemLink = GetItemLink(BAG_WORN, slot)
        local info = ReadSetInfo(itemLink)
        if info then
            table.insert(snapshot.debugRows, {
                slot = slot,
                setName = info.setName,
                setId = info.setId,
                numEquipped = info.numEquipped,
                maxEquipped = info.maxEquipped,
            })

            if matchFunc and matchFunc(info.setName, info.setId) then
                snapshot.hasSet = true
                snapshot.setName = snapshot.setName ~= "" and snapshot.setName or info.setName
                snapshot.setId = snapshot.setId ~= 0 and snapshot.setId or info.setId
                snapshot.numEquipped = math.max(snapshot.numEquipped, info.numEquipped)
                snapshot.maxEquipped = math.max(snapshot.maxEquipped, info.maxEquipped)
                table.insert(snapshot.slots, slot)
            end
        end
    end

    if snapshot.hasSet and snapshot.numEquipped <= 0 then
        snapshot.numEquipped = #snapshot.slots
        snapshot.maxEquipped = math.max(snapshot.maxEquipped, #snapshot.slots)
    end

    return snapshot
end
