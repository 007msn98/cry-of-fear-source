if SERVER then AddCSLuaFile() end
if game.GetMap() ~= "cof_coop_start" then return end

if SERVER then
    util.AddNetworkString("cof_coop_start_entry_audio")
    resource.AddFile("sound/cof_coop_start/coopstart.mp3")
    resource.AddFile("sound/cof_coop_start/new_chapter.wav")
    local managers = include("cof_coop_start/storm.lua")
    local running, generation = false, 0
    local greeted = setmetatable({}, {__mode = "k"})
    local function fire(name)
        if managers[name] then
            for _, event in ipairs(managers[name]) do
                local target, delay, token = event[1], event[2], generation
                timer.Simple(delay, function()
                    if generation == token then fire(target) end
                end)
            end
        elseif string.match(name, "^skyblixt_%d$") then
            local skin = tonumber(string.match(name, "(%d)$"))
            for _, ent in ipairs(ents.FindByName("skyblixt")) do
                if skin < ent:SkinCount() then
                    ent:SetSkin(skin)
                    ent:Fire("Enable")
                end
            end
        else
            for _, ent in ipairs(ents.FindByName(name)) do
                if ent:GetClass() == "ambient_generic" then ent:Fire("PlaySound") end
                if ent:GetClass() == "light_dynamic" then ent:Fire("Toggle") end
            end
        end
    end
    hook.Add("COF.CoopStart.Entered", "COF.CoopStart.Ambience", function(player)
        if not greeted[player] then
            greeted[player] = true
            net.Start("cof_coop_start_entry_audio")
            net.Send(player)
        end
        if not running then
            running = true
            fire("multistartus")
        end
    end)
    hook.Add("PostCleanupMap", "COF.CoopStart.StormReset", function()
        generation = generation + 1
        running = false
        greeted = setmetatable({}, {__mode = "k"})
    end)
    return
end

local music, generation = nil, 0
local chapterUntil = 0
local function stop()
    generation = generation + 1
    if IsValid(music) then music:Stop() end
    music, chapterUntil = nil, 0
end
net.Receive("cof_coop_start_entry_audio", function()
    stop()
    local token = generation
    timer.Simple(13, function()
        if token ~= generation then return end
        chapterUntil = CurTime() + 6
        surface.PlaySound("cof_coop_start/new_chapter.wav")
    end)
    sound.PlayFile("sound/cof_coop_start/coopstart.mp3", "noplay", function(stream, code, message)
        if token ~= generation then
            if IsValid(stream) then stream:Stop() end
            return
        end
        if not IsValid(stream) then
            print("[COF coop] Música inicial indisponível:", code, message)
            return
        end
        music = stream
        music:SetVolume(0.6)
        music:Play()
    end)
end)
hook.Add("HUDPaint", "COF.CoopStart.Chapter", function()
    if CurTime() >= chapterUntil then return end
    draw.SimpleTextOutlined("Chapter 9 - Where is Simon?", "DermaLarge", ScrW() / 2,
        ScrH() * 0.72, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end)
hook.Add("ShutDown", "COF.CoopStart.StopMusic", stop)
hook.Add("PostCleanupMap", "COF.CoopStart.StopMusic", stop)
