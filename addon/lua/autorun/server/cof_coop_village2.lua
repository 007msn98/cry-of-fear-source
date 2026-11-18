local map = game.GetMap()
local function isCampaignMap(name)
    return name:match("^c_cof_") or name:match("^cof_campaign_01_p[234]$")
end
if map ~= "cof_coop_start" and not isCampaignMap(map) then return end

hook.Add("PlayerSwitchFlashlight", "COF.Coop.SuitFlashlight", function(ply)
    if ply:Alive() then return true end
end)

hook.Add("PlayerSwitchWeapon", "COF.Coop.KeepSuitFlashlight", function(ply, old, new)
    local function isCOF(weapon)
        return IsValid(weapon) and weapon:GetClass():match("^weapon_cof_")
    end
    if not isCOF(old) and not isCOF(new) then return end
    local wasOn = ply:FlashlightIsOn()
    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() or ply:GetActiveWeapon() ~= new then return end
        ply:AllowFlashlight(true)
        if wasOn and not ply:FlashlightIsOn() then ply:Flashlight(true) end
    end)
end)

local function transferPath(destination)
    return "cof_coop_transfer_" .. destination .. ".json"
end
local function playerKey(ply)
    return ply:IsBot() and ("bot:" .. ply:UserID()) or ply:SteamID64()
end

local function captureInventory(ply, equippedOnly)
    local state = {weapons = {}, ammo = {}}
    local active = ply:GetActiveWeapon()
    if IsValid(active) then state.active = active:GetClass() end
    for _, weapon in ipairs(ply:GetWeapons()) do
        if not equippedOnly or weapon == active then
            state.weapons[weapon:GetClass()] = {primary = weapon:Clip1(), secondary = weapon:Clip2()}
        end
    end
    for id, count in pairs(ply:GetAmmo()) do
        local name = game.GetAmmoName(id)
        if name then state.ammo[name] = count end
    end
    hook.Run("COF.Coop.CaptureInventory", ply, state, equippedOnly)
    return state
end

local function restoreInventory(ply, state)
    hook.Run("COF.Coop.BeforeRestoreInventory", ply, state)
    ply:StripWeapons()
    ply:RemoveAllAmmo()
    if not state then return end
    for class, clips in pairs(state.weapons) do
        local weapon = ply:Give(class, true)
        if IsValid(weapon) then
            weapon:SetClip1(clips.primary)
            weapon:SetClip2(clips.secondary)
        end
    end
    -- Some SWEPs grant ammo themselves on equip.
    ply:RemoveAllAmmo()
    for ammo, count in pairs(state.ammo) do ply:SetAmmo(count, ammo) end
    if state.active then ply:SelectWeapon(state.active) end
    hook.Run("COF.Coop.AfterRestoreInventory", ply, state)
end

local deaths = setmetatable({}, {__mode = "k"})
local function saveDeath(ply)
    if ply:GetNWBool("cof_coop_playing") and not deaths[ply] then
        deaths[ply] = captureInventory(ply, false)
    end
end

local function restoreDeath(ply)
    local state = deaths[ply]
    if not state then return end
    deaths[ply] = nil
    restoreInventory(ply, state)
    return true
end

hook.Add("PlayerLoadout", "COF.Coop.NoSandboxLoadout", function() return true end)
hook.Add("DoPlayerDeath", "COF.Coop.SaveInventory", saveDeath)
hook.Add("PlayerSilentDeath", "COF.Coop.SaveInventory", saveDeath)

hook.Add("COF.Coop.BeforeChangeLevel", "COF.Village2.SaveLoadout", function(nextMap)
    if not isCampaignMap(nextMap) then return end
    local snapshot = {version = 2, time = os.time(), players = {}}
    for _, ply in ipairs(player.GetAll()) do
        if ply:Alive() and ply:GetNWBool("cof_coop_playing") then
            local state = captureInventory(ply, true)
            state.health, state.armor = ply:Health(), ply:Armor()
            snapshot.players[playerKey(ply)] = state
        end
    end
    file.Write(transferPath(nextMap), util.TableToJSON(snapshot))
end)
if map == "cof_coop_start" then
    hook.Add("COF.CoopStart.RestoreRespawn", "COF.Coop.RestoreInventory", restoreDeath)
    return
end

local spawnPositions = setmetatable({}, {__mode = "k"})
hook.Add("PlayerCanPickupWeapon", "COF.Coop.NoPickupAtSpawn", function(ply, weapon)
    local start = spawnPositions[ply]
    if not start or not weapon:CreatedByMap() then return end
    local movement = ply:GetPos() - start
    if movement:Length2DSqr() >= 48 * 48 then
        spawnPositions[ply] = nil
        return
    end
    local offset = weapon:GetPos() - start
    if offset:Length2DSqr() < 48 * 48 and math.abs(offset.z) < 110 then return false end
end)
hook.Add("Move", "COF.Coop.ClearPickupGuard", function(ply, move)
    local start = spawnPositions[ply]
    if start and (move:GetOrigin() - start):Length2DSqr() >= 48 * 48 then
        spawnPositions[ply] = nil
    end
end)

local markers = setmetatable({}, {__mode = "k"})
local spawned = {}
local npcDeaths = setmetatable({}, {__mode = "k"})
local arrivals = {}
local path = transferPath(map)
local saved = file.Read(path, "DATA")
local snapshot = saved and util.JSONToTable(saved, false, true) or {}
if saved then file.Delete(path) end
if snapshot.version == 2 and type(snapshot.time) == "number" and math.abs(os.time() - snapshot.time) < 180 and
    type(snapshot.players) == "table" then arrivals = snapshot.players end
local depsMissing = ""

hook.Add("EntityKeyValue", "COF.Village2.EncounterKeys", function(ent, key, value)
    if ent:GetClass() ~= "info_target" or not key:match("^cof_") then return end
    markers[ent] = markers[ent] or {}
    markers[ent][key] = value
end)

local function spawnNPC(marker, class)
    local npc = ents.Create(class)
    if not IsValid(npc) then
        ErrorNoHalt("[COF coop] Não foi possível criar " .. class .. "\n")
        return
    end
    npc:SetPos(marker:GetPos() + Vector(0, 0, 1))
    npc:SetAngles(marker:GetAngles())
    local data = markers[marker]
    if data.cof_npcname and data.cof_npcname ~= "" then npc:SetName(data.cof_npcname) end
    if data.cof_npcdeath and data.cof_npcdeath ~= "" then npcDeaths[npc] = data.cof_npcdeath end
    hook.Run("COF.Coop.BeforeNPCSpawn", npc, marker)
    npc:Spawn()
    npc:Activate()
    hook.Run("COF.Coop.AfterNPCSpawn", npc, marker)
    spawned[#spawned + 1] = npc
end

hook.Add("OnNPCKilled", "COF.Coop.DeathOutputs", function(npc, attacker)
    local target = npcDeaths[npc]
    if not target then return end
    npcDeaths[npc] = nil
    for _, ent in ipairs(ents.FindByName(target)) do
        ent:Fire(ent:GetClass() == "ambient_generic" and "PlaySound" or "Trigger", "", 0, attacker)
    end
end)

local function startEncounter()
    local missing, required = {}, {}
    local fixed, groups = {}, {}
    for marker, data in pairs(markers) do
        if IsValid(marker) and data.cof_npc then
            required[data.cof_npc] = true
            local group = data.cof_group
            if group and group ~= "" then
                groups[group] = groups[group] or {points = {}, draws = 0}
                local config = groups[group]
                config.points[#config.points + 1] = marker
                config.draws = math.max(config.draws, tonumber(data.cof_draws) or 0)
            else
                fixed[#fixed + 1] = marker
            end
        end
    end
    if not VJBASE_INSTALLED then missing[#missing + 1] = "VJ Base" end
    for class in pairs(required) do
        if not scripted_ents.GetStored(class) then missing[#missing + 1] = class end
    end
    for _, class in ipairs({"weapon_cof_nightstick", "weapon_cof_p345", "weapon_cof_syringe",
                            "weapon_cof_g43", "weapon_cof_shotgun"}) do
        if not weapons.GetStored(class) then missing[#missing + 1] = class end
    end
    if not scripted_ents.GetStored("ent_cof_p345_ammo") then missing[#missing + 1] = "ent_cof_p345_ammo" end
    table.sort(missing)
    depsMissing = table.concat(missing, ", ")
    if depsMissing ~= "" then
        print("[COF coop] Dependências ausentes em " .. map .. ": " .. depsMissing)
        return
    end
    for _, marker in ipairs(fixed) do spawnNPC(marker, markers[marker].cof_npc) end
    for _, group in pairs(groups) do
        local used = {}
        -- GoldSrc draws from the original set. Drawing a used slot consumes that attempt.
        for _ = 1, math.min(group.draws, #group.points) do
            local slot = math.random(#group.points)
            if not used[slot] then
                used[slot] = true
                local marker = group.points[slot]
                spawnNPC(marker, markers[marker].cof_npc)
            end
        end
    end
end

hook.Add("InitPostEntity", "COF.Village2.StartEncounter", startEncounter)
hook.Add("PostCleanupMap", "COF.Village2.RestartEncounter", function()
    for _, npc in ipairs(spawned) do
        if IsValid(npc) then npc:Remove() end
    end
    spawned = {}
    startEncounter()
end)

hook.Add("PlayerSpawn", "COF.Village2.Loadout", function(ply)
    spawnPositions[ply] = ply:GetPos()
    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end
        ply:SetNWBool("cof_coop_playing", true)
        if depsMissing ~= "" then
            ply:PrintMessage(HUD_PRINTTALK, "[COF coop] Ative as dependências e recarregue: " .. depsMissing)
        end
        if restoreDeath(ply) then return end
        local key = playerKey(ply)
        local state = arrivals[key]
        arrivals[key] = nil
        restoreInventory(ply, state)
        if state then
            ply:SetHealth(state.health)
            ply:SetArmor(state.armor)
        end
    end)
end)
