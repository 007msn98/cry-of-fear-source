if SERVER then AddCSLuaFile() end
if game.GetMap() ~= "cof_coop_intro_test" then return end

if SERVER then
    util.AddNetworkString("cof_intro_test")
    util.AddNetworkString("cof_intro_test_error")
    resource.AddFile("sound/cof_coop_intro/coop_introduction.wav")
    resource.AddFile("materials/cof_coop_intro/intro.vmt")
    resource.AddFile("materials/cof_coop_intro/intro.vtf")
    local function reset(player)
        player:SetNWBool("cof_intro_test_active", false)
        net.Start("cof_intro_test")
        net.WriteBool(false)
        net.Send(player)
    end
    hook.Add("AcceptInput", "COF.IntroTest.Button", function(ent, input, activator, caller)
        if ent:GetName() ~= "cof_intro_signal" or string.lower(input) ~= "trigger" then return end
        if not IsValid(caller) or caller:GetName() ~= "cof_intro_watch" then return end
        if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return true end
        if activator:GetNWBool("cof_intro_test_active") then return true end
        activator:SetNWBool("cof_intro_test_active", true)
        net.Start("cof_intro_test")
        net.WriteBool(true)
        net.Send(activator)
        return true
    end)
    hook.Add("PlayerSpawn", "COF.IntroTest.Reset", reset)
    hook.Add("PlayerDeath", "COF.IntroTest.Death", reset)
    net.Receive("cof_intro_test_error", function(_, player)
        if not player:GetNWBool("cof_intro_test_active") then return end
        reset(player)
        player:PrintMessage(HUD_PRINTTALK, "Não foi possível carregar a voz da introdução. Confira o console e tente novamente.")
    end)
    hook.Add("PostCleanupMap", "COF.IntroTest.Cleanup", function()
        for _, player in ipairs(player.GetAll()) do reset(player) end
    end)
    return
end

local art = Material("cof_coop_intro/intro", "smooth")
local stage, channel, holdUntil
local generation = 0
local function stop()
    generation = generation + 1
    if IsValid(channel) then channel:Stop() end
    channel, stage, holdUntil = nil, nil, nil
end
net.Receive("cof_intro_test", function()
    local start = net.ReadBool()
    stop()
    if not start then return end
    stage = "loading"
    local token = generation
    sound.PlayFile("sound/cof_coop_intro/coop_introduction.wav", "noplay", function(stream, code, message)
        if token ~= generation then
            if IsValid(stream) then stream:Stop() end
            return
        end
        if not IsValid(stream) then
            stop()
            print("[COF intro] Falha no áudio:", code, message)
            net.Start("cof_intro_test_error")
            net.SendToServer()
            return
        end
        channel, stage = stream, "voice"
        channel:SetVolume(1)
        channel:Play()
    end)
end)

hook.Add("Think", "COF.IntroTest.Playback", function()
    if stage == "voice" and IsValid(channel) and channel:GetState() == GMOD_CHANNEL_STOPPED then
        stage, holdUntil = "hold", RealTime() + 10
    elseif stage == "hold" and RealTime() >= holdUntil then
        -- This milestone deliberately has no destination or campaign start.
        stage = "finished"
        print("[COF intro] Voz e espera de 10 segundos concluídas; texto mantido na parede.")
    end
end)

hook.Add("PostDrawTranslucentRenderables", "COF.IntroTest.Wall", function(depth, sky)
    if depth or sky or not stage then return end
    -- East wall, facing into the room; fixed in world space, never attached to the view.
    cam.Start3D2D(Vector(254, 80, 176), Angle(0, 270, 90), 160 / 512)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(art)
    surface.DrawTexturedRect(0, 0, 512, 512)
    cam.End3D2D()
end)
hook.Add("ShutDown", "COF.IntroTest.Stop", stop)
hook.Add("PostCleanupMap", "COF.IntroTest.Stop", stop)

-- Labels follow the actual buttons, so there is no second list of coordinates.
surface.CreateFont("COF.IntroTest.Button", {font = "Tahoma", size = 36, weight = 700})
hook.Add("PostDrawTranslucentRenderables", "COF.IntroTest.Labels", function(_, sky)
    if sky then return end
    for _, ent in ipairs(ents.FindByClass("func_button")) do
        local name = ent:GetName()
        if name == "cof_intro_watch" or name == "cof_intro_skip" then
            local center = ent:WorldSpaceCenter()
            cam.Start3D2D(center + Vector(0, -6, 28), Angle(0, 0, 90), 0.12)
            draw.SimpleText(name == "cof_intro_watch" and "Ver intro" or "Pular intro",
                "COF.IntroTest.Button", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        end
    end
end)
