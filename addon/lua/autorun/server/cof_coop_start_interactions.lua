local map = game.GetMap()
-- Bounds from the original trigger_coop_changelevel submodel in each BSP.
local routes = {
    cof_coop_start = {"c_cof_village2", {2602, 708, -80}, {2782, 1132, 59}},
    c_cof_village2 = {"c_cof_village1", {-20, 1267, -56}, {109, 1431, 88}},
    c_cof_village1 = {"c_cof_fsewer1", {-255, -901, -450}, {-51, -694, -306}},
    c_cof_fsewer1 = {"c_cof_lake", {1090, -1635, 64}, {1239, -1456, 208}},
    c_cof_lake = {"c_cof_forestday", {265, -3979, 35}, {959, -3782, 179}},
    c_cof_forestday = {"c_cof_asylum1day", {1529, -3063, 48}, {1675, -2907, 192}},
    c_cof_asylum1day = {"cof_campaign_01_p2", {-452, 1128, -130}, {-293, 1283, 14}},
    cof_campaign_01_p2 = {"c_cof_asylum1", {189, 381, -140}, {263, 563, 68}},
    c_cof_asylum1 = {"c_cof_forest7", {-44, -754, -48}, {85, -626, 96}},
    c_cof_forest7 = {"c_cof_forest6", {-2322, -1606, -905}, {-2091, -1427, -761}},
    c_cof_forest6 = {"c_cof_forest5", {1016, 48, -803}, {1144, 176, -659}},
    c_cof_forest5 = {"c_cof_forest4", {-1481, 745, 8}, {-1353, 873, 152}},
    c_cof_forest4 = {"c_cof_forest3", {-1503, 195, 25}, {-1241, 426, 169}},
    c_cof_forest3 = {"c_cof_forest2", {-2584, 1850, 8}, {-2212, 2120, 152}},
    c_cof_forest2 = {"c_cof_forest1", {-2003, 934, -91}, {-1842, 1227, 53}},
    c_cof_forest1 = {"c_cof_bridge", {68, -1663, 16}, {354, -1362, 160}},
    c_cof_bridge = {"cof_campaign_01_p3", {-1042, -21, 9}, {-885, 181, 187}},
    cof_campaign_01_p3 = {"c_cof_trainride", {1763, 1813, 217}, {1904, 1995, 361}},
    c_cof_trainride = {"c_cof_subway2st3"},
    c_cof_subway2st3 = {"c_cof_subway2st2", {-564, -89, -802}, {-372, 110, -658}},
    c_cof_subway2st2 = {"c_cof_subway2st1", {-1500, 1418, -586}, {-1319, 1686, -442}},
    c_cof_subway2st1 = {"c_cof_buscity", {231, -2668, -220}, {405, -2436, -76}},
    c_cof_buscity = {"c_cof_city", {-458, 984, 172}, {-330, 1183, 384}},
    c_cof_city = {"cof_campaign_01_p4", {2752, -1359, 360}, {2880, -1110, 504}},
    cof_campaign_01_p4 = {"c_cof_park", {1104, 732, -1488}, {1308, 925, -1344}},
    c_cof_park = {"c_cof_park2", {6, -2218, 29}, {271, -1988, 173}},
    c_cof_park2 = {"c_cof_stad", {2529, -2318, -112}, {2781, -2190, 32}},
    c_cof_stad = {"c_cof_subway1st1", {-692, -227, -344}, {-451, -86, -200}},
    c_cof_subway1st1 = {"c_cof_coopend", {635, 2595, -342}, {776, 2778, -198}},
}
local route = routes[map]
if not route and map ~= "c_cof_coopend" then return end
route = route or {}

local objects = setmetatable({}, {__mode = "k"})
local cooldown = setmetatable({}, {__mode = "k"})
local changingLevel = false
local nextMap = route[1]
local exitMins = route[2] and Vector(unpack(route[2]))
local exitMaxs = route[3] and Vector(unpack(route[3]))
local function changeMap()
    if changingLevel then return end
    changingLevel = true
    hook.Run("COF.Coop.BeforeChangeLevel", nextMap)
    RunConsoleCommand("changelevel", nextMap)
end

local function teamAtExit()
    local eligible = 0
    for _, member in ipairs(player.GetAll()) do
        if member:Alive() then
            if not member:GetNWBool("cof_coop_playing") then return false end
            local mins, maxs = member:WorldSpaceAABB()
            if exitMins and (maxs.x < exitMins.x or mins.x > exitMaxs.x or
                maxs.y < exitMins.y or mins.y > exitMaxs.y or
                maxs.z < exitMins.z or mins.z > exitMaxs.z) then return false end
            eligible = eligible + 1
        end
    end
    return eligible > 0
end
local originalSounds = {
    ["doors/car_door_locked.wav"] = "cof_coop_start/car_door_locked.wav",
    ["buttons/latchlocked1.wav"] = "cof_coop_start/latchlocked1.wav"
}
for _, sound in pairs(originalSounds) do resource.AddFile("sound/" .. sound) end
hook.Add("EntityKeyValue", "COF.CoopStart.InteractionKeys", function(ent, key, value)
    if ent:GetClass() ~= "func_brush" and not key:match("^cof_") then return end
    local field = string.match(key, "^cof_(.+)$")
    if not field then return end
    objects[ent] = objects[ent] or {}
    objects[ent][field] = value
end)
hook.Add("AcceptInput", "COF.Coop.EventRelays", function(ent, input, activator)
    if ent:GetClass() == "func_train" and string.lower(input) == "startforward" then
        ent:Fire("Start", "", 0, activator)
        return true
    end
    local config = objects[ent]
    if not config or config.event ~= "cof_teleport" or string.lower(input) ~= "trigger" then return end
    local destination = ents.FindByName(config.target)[1]
    if not IsValid(destination) then return end
    if config.subject and config.subject ~= "" then
        for _, subject in ipairs(ents.FindByName(config.subject)) do subject:SetPos(destination:GetPos()) end
    elseif IsValid(activator) and activator:IsPlayer() then
        activator:SetPos(destination:GetPos())
        activator:SetEyeAngles(destination:GetAngles())
    end
end)

if map == "c_cof_park" then
    local turned, opened = {}, false
    local names = {[1] = "owl", [2] = "eagle", [3] = "lion", [4] = "horse"}
    hook.Add("PlayerUse", "COF.Coop.ParkStatues", function(ply, ent)
        local config = objects[ent]
        if not config or not config.statue or opened then return end
        if CurTime() < (cooldown[ply] or 0) then return false end
        cooldown[ply] = CurTime() + 1
        local id = tonumber(config.statue)
        local name = names[id]
        if name then
            local statue = ents.FindByName("statue_" .. name .. "_visual")[1]
            if IsValid(statue) then
                local angles = statue:GetAngles()
                angles.y = angles.y + 90
                statue:SetAngles(angles)
            end
            turned[id] = true
        end
        if turned[1] and turned[2] and turned[3] and turned[4] then
            opened = true
            for _, relay in ipairs(ents.FindByName("multiasek")) do relay:Fire("Trigger", "", 0, ply) end
        else
            ply:PrintMessage(HUD_PRINTCENTER, "Inspecione as quatro estátuas do parque.")
        end
        return false
    end)
    hook.Add("PostCleanupMap", "COF.Coop.ParkReset", function() turned, opened = {}, false end)
end
if map == "c_cof_bridge" or map == "c_cof_trainride" then
    hook.Add("AcceptInput", "COF.Coop.ScriptedExit", function(ent, input)
        local config = objects[ent]
        if config and config.destination == nextMap and string.lower(input) == "trigger" and
            file.Exists("maps/" .. nextMap .. ".bsp", "GAME") then changeMap() end
    end)
end

do
    hook.Add("AcceptInput", "COF.Coop.DSP", function(ent, input, activator, caller, value)
        if string.lower(input) ~= "cof_setdsp" or not ent:IsPlayer() or not IsValid(caller) or
            caller:GetClass() ~= "trigger_multiple" then return end
        local preset = tonumber(value)
        if preset and preset >= 0 and preset <= 28 then ent:SetDSP(preset) end
        return true
    end)
end
if map == "c_cof_bridge" then
    hook.Add("PlayerUse", "COF.Coop.BridgeTeam", function(ply, ent)
        if not objects[ent] or objects[ent].teambutton ~= "1" then return end
        if teamAtExit() then return end
        if CurTime() >= (cooldown[ply] or 0) then
            cooldown[ply] = CurTime() + 1
            ply:PrintMessage(HUD_PRINTCENTER, "Reúna os jogadores vivos junto à saída.")
        end
        return false
    end)
end

hook.Add("KeyPress", "COF.CoopStart.Inspect", function(player, key)
    if key ~= IN_USE or not player:Alive() or not player:GetNWBool("cof_coop_playing") then return end
    local origin, delta = player:GetShootPos(), player:GetAimVector() * 100
    local trace = util.TraceLine({start = origin, endpos = origin + delta, filter = player, mask = MASK_SOLID})
    local chosen = trace.Entity
    local config = IsValid(chosen) and objects[chosen]
    if not config then return end
    local message, sound
    if config.nextmap == nextMap then
        if changingLevel then return end
        if not file.Exists("maps/" .. nextMap .. ".bsp", "GAME") then
            message = "A próxima área (" .. nextMap .. ") ainda não está incluída neste pacote."
        elseif not teamAtExit() then
            message = "Reúna os jogadores vivos junto à saída."
        else
            changeMap()
            return
        end
        sound = "doors/default_locked.wav"
    elseif config.check == "1" then
        if CurTime() < (config.nextCheck or 0) then return end
        config.nextCheck = CurTime() + (tonumber(config.checkdelay) or 2)
        if config.usesound and config.usesound ~= "" then
            player:EmitSound(originalSounds[config.usesound] or config.usesound, 75)
        end
        if config.message and config.message ~= "" then player:PrintMessage(HUD_PRINTCENTER, config.message) end
        return
    elseif config.lockedby and config.lockedby ~= "" then
        message, sound = config.lockedmsg or "Trancada.", config.lockedsnd or "buttons/latchlocked1.wav"
    elseif config.target and config.target ~= "" then
        if CurTime() < (cooldown[player] or 0) then return end
        cooldown[player] = CurTime() + 0.75
        local exits = ents.FindByName(config.target)
        if #exits ~= 1 or not IsValid(exits[1]) then
            player:PrintMessage(HUD_PRINTCENTER, "Destino da porta indisponível.")
            return
        end
        local destination = exits[1]:GetPos() + Vector(0, 0, 1)
        local mins, maxs = player:GetHull()
        local hull = util.TraceHull({start = destination, endpos = destination, mins = mins,
            maxs = maxs, filter = player, mask = MASK_PLAYERSOLID})
        if hull.StartSolid or hull.AllSolid or hull.Hit then
            player:PrintMessage(HUD_PRINTCENTER, "Saída da porta obstruída.")
            return
        end
        chosen:EmitSound(config.opensound or "doors/doormove6.wav", 65)
        player:SetPos(destination)
        player:SetEyeAngles(Angle(0, exits[1]:GetAngles().y, 0))
        player:SetLocalVelocity(Vector(0, 0, 0))
        return
    else
        return
    end
    if CurTime() < (cooldown[player] or 0) then return end
    cooldown[player] = CurTime() + 0.75
    if sound and sound ~= "" then chosen:EmitSound(originalSounds[sound] or sound, 65) end
    if message and message ~= "" then player:PrintMessage(HUD_PRINTCENTER, message) end
end)

hook.Add("PostCleanupMap", "COF.CoopStart.InspectReset", function()
    changingLevel = false
    cooldown = setmetatable({}, {__mode = "k"})
    for _, config in pairs(objects) do config.nextCheck = nil end
end)
