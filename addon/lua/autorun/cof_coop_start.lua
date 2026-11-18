if SERVER then AddCSLuaFile() end
if game.GetMap() ~= "cof_coop_start" then return end

local voiceDuration = 1006843 / 22050
local playbackMessage = "cof_coop_start_intro"
local readyMessage = "cof_coop_start_ready"
local finishedMessage = "cof_coop_start_finished"

if SERVER then
    util.AddNetworkString(playbackMessage)
    util.AddNetworkString(readyMessage)
    util.AddNetworkString(finishedMessage)
    resource.AddFile("sound/cof_coop_intro/coop_introduction.wav")
    resource.AddFile("materials/cof_coop_intro/intro.vmt")
    resource.AddFile("materials/cof_coop_intro/intro.vtf")
    local states = setmetatable({}, {__mode = "k"})
    local serial = 0
    local missing

    local function preflight()
        local problems = {}
        for _, class in ipairs({"weapon_cof_nightstick", "weapon_cof_p345", "weapon_cof_syringe"}) do
            local stored = weapons.GetStored(class)
            if not stored then
                problems[#problems + 1] = class
            else
                for _, field in ipairs({"ViewModel", "WorldModel"}) do
                    local path = stored[field]
                    if not path or path == "" or not file.Exists(path, "GAME") then
                        problems[#problems + 1] = class .. ":" .. field
                    end
                end
            end
        end
        if not scripted_ents.GetStored("ent_cof_p345_ammo") then
            problems[#problems + 1] = "ent_cof_p345_ammo"
        end
        return table.concat(problems, ", ")
    end

    local function diagnose(player, message)
        player:PrintMessage(HUD_PRINTTALK, "[COF coop] " .. message)
    end

    local function send(player, state, start)
        net.Start(playbackMessage)
        net.WriteBool(start)
        net.WriteUInt(state.token, 32)
        net.Send(player)
    end

    local function cancel(player, state)
        serial = serial + 1
        state.token = serial
        state.phase, state.earliestEnd = "choice", nil
        player:SetNWBool("cof_coop_playing", false)
        send(player, state, false)
    end

    local function place(player, prefix)
        local low, high = player:GetHull()
        for step = 1, 4 do
            local index = (player:EntIndex() + step - 1) % 4 + 1
            local target = ents.FindByName(prefix .. index)[1]
            if IsValid(target) then
                local position = target:GetPos() + Vector(0, 0, 1)
                local hit = util.TraceHull({start = position, endpos = position,
                    mins = low, maxs = high, filter = player, mask = MASK_PLAYERSOLID})
                if not hit.Hit and not hit.StartSolid and not hit.AllSolid then
                    player:SetPos(position)
                    player:SetEyeAngles(target:GetAngles())
                    player:SetLocalVelocity(vector_origin)
                    return true
                end
            end
        end
        return false
    end

    local function enter(player, state)
        if not IsValid(player) or not player:Alive() or states[player] ~= state then return false end
        if missing == nil then missing = preflight() end
        if missing ~= "" then
            diagnose(player, "Dependências ausentes: " .. missing .. ". Ative o Weapon Pack e recarregue o mapa.")
            return false
        end
        if not place(player, "cof_coop_arrival_") then
            diagnose(player, "Entrada ocupada ou sem destino seguro. Tente Pular intro novamente.")
            return false
        end
        if state.entered then
            hook.Run("COF.CoopStart.RestoreRespawn", player)
        else
            player:StripWeapons()
            player:RemoveAllAmmo()
            local nightstick = player:Give("weapon_cof_nightstick", true)
            local pistol = player:Give("weapon_cof_p345", true)
            if not IsValid(nightstick) or not IsValid(pistol) then
                diagnose(player, "Não foi possível conceder o loadout; recarregue o mapa após conferir o Weapon Pack.")
                place(player, "cof_intro_spawn")
                return false
            end
            -- Conservative adapter for the map CFG's declared 8/8.
            pistol:SetClip1(8)
            player:SetAmmo(8, "Pistol")
            player:SelectWeapon("weapon_cof_nightstick")
        end
        state.entered = true
        cancel(player, state)
        state.phase = "playing"
        player:SetNWBool("cof_coop_playing", true)
        hook.Run("COF.CoopStart.Entered", player)
        return true
    end

    hook.Add("InitPostEntity", "COF.CoopStart.Preflight", function()
        missing = preflight()
        if missing ~= "" then print("[COF coop] Dependências ausentes no carregamento: " .. missing) end
        -- Pickups belong to the BSP. Never create another batch here or on player entry.
    end)

    hook.Add("PlayerSpawn", "COF.CoopStart.Spawn", function(player)
        local entered = states[player] and states[player].entered or false
        serial = serial + 1
        local state = {phase = "choice", token = serial, entered = entered}
        states[player] = state
        player:SetNWBool("cof_coop_playing", false)
        send(player, state, false)
        timer.Simple(0, function()
            if states[player] ~= state or not IsValid(player) or not player:Alive() then return end
            if entered then
                if not enter(player, state) then
                    state.entered = false
                    place(player, "cof_intro_spawn")
                end
            else
                if not place(player, "cof_intro_spawn") then
                    diagnose(player, "Sala de entrada ocupada. Aguarde espaço antes de avançar.")
                end
            end
        end)
    end)

    hook.Add("AcceptInput", "COF.CoopStart.Buttons", function(ent, input, activator, caller)
        local name = ent:GetName()
        if string.lower(input) ~= "trigger" or
            (name ~= "cof_coop_watch_signal" and name ~= "cof_coop_skip_signal") then return end
        if not IsValid(caller) or caller:GetClass() ~= "func_button" then return true end
        local watch = name == "cof_coop_watch_signal"
        if caller:GetName() ~= (watch and "cof_intro_watch" or "cof_intro_skip") then return true end
        if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return true end
        if activator:GetPos():DistToSqr(caller:WorldSpaceCenter()) > 200 * 200 then return true end
        local state = states[activator]
        if not state or state.entered then return true end
        if not watch then
            cancel(activator, state)
            enter(activator, state)
            return true
        end
        if state.phase ~= "choice" then return true end
        serial = serial + 1
        state.token, state.phase = serial, "loading"
        local token = state.token
        send(activator, state, true)
        timer.Simple(20, function()
            if states[activator] == state and state.token == token and state.phase == "loading" then
                cancel(activator, state)
                diagnose(activator, "A voz não iniciou. Tente novamente ou use Pular intro.")
            end
        end)
        return true
    end)

    net.Receive(readyMessage, function(_, player)
        local token, ok = net.ReadUInt(32), net.ReadBool()
        local state = states[player]
        if not IsValid(player) or not player:Alive() or not state or state.phase ~= "loading" or
            state.token ~= token then return end
        if not ok then
            cancel(player, state)
            diagnose(player, "Não foi possível carregar a voz. Tente novamente ou use Pular intro.")
            return
        end
        state.phase, state.earliestEnd = "voice", CurTime() + voiceDuration
        timer.Simple(voiceDuration + 30, function()
            if states[player] ~= state or state.token ~= token or state.phase ~= "voice" then return end
            cancel(player, state)
            diagnose(player, "O fim da voz não foi confirmado. Tente novamente ou use Pular intro.")
        end)
    end)

    net.Receive(finishedMessage, function(_, player)
        local token = net.ReadUInt(32)
        local state = states[player]
        if not IsValid(player) or not player:Alive() or not state or state.phase ~= "voice" or
            state.token ~= token then return end
        state.phase = "hold"
        local delay = math.max(0, state.earliestEnd - CurTime()) + 10
        timer.Simple(delay, function()
            if states[player] ~= state or state.token ~= token or state.phase ~= "hold" then return end
            if not enter(player, state) then cancel(player, state) end
        end)
    end)

    hook.Add("PlayerDeath", "COF.CoopStart.Death", function(player)
        if states[player] then cancel(player, states[player]) end
    end)
    hook.Add("PlayerDisconnected", "COF.CoopStart.Disconnect", function(player) states[player] = nil end)
    hook.Add("PostCleanupMap", "COF.CoopStart.Cleanup", function()
        for player, state in pairs(states) do
            if IsValid(player) then
                state.entered = false
                cancel(player, state)
                place(player, "cof_intro_spawn")
            end
        end
    end)
    return
end

local art = Material("cof_coop_intro/intro", "smooth")
local active, channel, generation = false, nil, 0
local voiceToken, earliestEnd
local function stop()
    generation = generation + 1
    if IsValid(channel) then channel:Stop() end
    channel, active = nil, false
    voiceToken, earliestEnd = nil, nil
end
net.Receive(playbackMessage, function()
    local start, token = net.ReadBool(), net.ReadUInt(32)
    stop()
    if not start then return end
    active = true
    local request = generation
    sound.PlayFile("sound/cof_coop_intro/coop_introduction.wav", "noplay", function(stream, code, message)
        if request ~= generation then
            if IsValid(stream) then stream:Stop() end
            return
        end
        local ok = IsValid(stream)
        if ok then
            channel = stream
            channel:SetVolume(1)
            channel:Play()
            voiceToken, earliestEnd = token, RealTime() + voiceDuration
        else
            stop()
            print("[COF coop] Falha no áudio:", code, message)
        end
        net.Start(readyMessage)
        net.WriteUInt(token, 32)
        net.WriteBool(ok)
        net.SendToServer()
    end)
end)
hook.Add("Think", "COF.CoopStart.VoiceEnd", function()
    if not voiceToken or RealTime() < earliestEnd or not IsValid(channel) or
        channel:GetState() ~= GMOD_CHANNEL_STOPPED then return end
    net.Start(finishedMessage)
    net.WriteUInt(voiceToken, 32)
    net.SendToServer()
    voiceToken = nil
end)
hook.Add("PostDrawTranslucentRenderables", "COF.CoopStart.Wall", function(depth, sky)
    if depth or sky or not active then return end
    cam.Start3D2D(Vector(-11746, 80, 176), Angle(0, 270, 90), 160 / 512)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(art)
    surface.DrawTexturedRect(0, 0, 512, 512)
    cam.End3D2D()
end)
surface.CreateFont("COF.CoopStart.Button", {font = "Tahoma", size = 36, weight = 700})
hook.Add("PostDrawTranslucentRenderables", "COF.CoopStart.Labels", function(depth, sky)
    if depth or sky then return end
    for _, ent in ipairs(ents.FindByClass("func_button")) do
        local name = ent:GetName()
        if name == "cof_intro_watch" or name == "cof_intro_skip" then
            cam.Start3D2D(ent:WorldSpaceCenter() + Vector(0, -6, 28), Angle(0, 0, 90), 0.12)
            draw.SimpleText(name == "cof_intro_watch" and "Ver intro" or "Pular intro",
                "COF.CoopStart.Button", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        end
    end
end)
hook.Add("ShutDown", "COF.CoopStart.Stop", stop)
hook.Add("PostCleanupMap", "COF.CoopStart.Stop", stop)
