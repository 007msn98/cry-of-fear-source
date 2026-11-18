-- Local adaptation for the original lake encounters; never changes the SNPC pack.
if game.GetMap() ~= "c_cof_lake" then return end

local watros = setmetatable({}, {__mode = "k"})
local wet = {}
local biteSounds = {
    {"ambient/creatures/leech_bites_loop1.wav", 0.30},
    {"ambient/creatures/leech_water_churn_loop2.wav", 0.15}
}

hook.Add("COF.Coop.BeforeNPCSpawn", "COF.Lake.WatroPrepare", function(npc, marker)
    if npc:GetClass() ~= "npc_vj_cof_watro" then return end
    local state = {position = marker:GetPos() + Vector(0, 0, 1),
        idle = npc.AnimTbl_IdleStand}
    watros[npc] = state
    npc.AnimTbl_IdleStand = {"vjseq_under"}
end)

hook.Add("COF.Coop.AfterNPCSpawn", "COF.Lake.WatroSubmerge", function(npc)
    local state = watros[npc]
    if not state then return end
    state.melee = npc.HasMeleeAttack
    npc.HasMeleeAttack = false
    -- The pack's Init adds 30 Z. Keep the map anchor and use its real under/appear sequences.
    npc:SetPos(state.position)
    npc:SetState(VJ_STATE_FREEZE)
    npc:ResetSequence("under")
    npc:SetCycle(0)
    npc:SetNotSolid(true)
    local originalThink = npc.OnThink
    npc.OnThink = function(self)
        if originalThink then originalThink(self) end
        if watros[self] == state and not state.emergedAt then
            local sequence = self:LookupSequence("under")
            if self:GetSequence() ~= sequence then self:ResetSequence(sequence) end
        end
    end
end)

local nextThink = 0
local function stopWater(ply)
    local state = wet[ply]
    if not state then return end
    for _, sound in ipairs(state.sounds or {}) do sound:Stop() end
    wet[ply] = nil
end

hook.Add("Think", "COF.Lake.WaterAndWatro", function()
    local now = CurTime()
    if now < nextThink then return end
    nextThink = now + 0.1
    local players = player.GetAll()
    for npc, state in pairs(watros) do
        if not IsValid(npc) or npc:Health() <= 0 then
            watros[npc] = nil
        elseif state.emergedAt then
            if now >= state.emergedAt then
                npc.HasMeleeAttack = state.melee
                watros[npc] = nil
            end
        else
            for _, ply in ipairs(players) do
                -- Original InactiveThink: sphere256, centered100 units forward.
                if ply:Alive() and not ply:GetNoTarget() and
                    ply:GetPos():DistToSqr(state.position + npc:GetForward() * 100) <= 256 * 256 and
                    npc:Visible(ply) then
                    npc.AnimTbl_IdleStand = state.idle
                    npc:SetNotSolid(false)
                    npc:SetState(VJ_STATE_NONE)
                    local _, duration = npc:PlayAnim("vjseq_appear", true, false)
                    npc:EmitSound("sewmo/out_water.wav")
                    state.emergedAt = now + duration
                    break
                end
            end
        end
    end

    for _, ply in ipairs(players) do
        -- Uses the native world water volume, not a rectangle around the boardwalk.
        local inWater = ply:Alive() and ply:WaterLevel() > 0 and
            bit.band(util.PointContents(ply:GetPos() + Vector(0, 0, 2)), CONTENTS_WATER) ~= 0
        if not inWater then
            stopWater(ply)
        else
            local state = wet[ply]
            if not state then state = {nextBite = now + 3}; wet[ply] = state end
            if now >= state.nextBite then
                if not state.sounds then
                    state.sounds = {}
                    for _, spec in ipairs(biteSounds) do
                        local sound = CreateSound(ply, spec[1])
                        if sound then sound:PlayEx(spec[2], 100); state.sounds[#state.sounds + 1] = sound end
                    end
                end
                state.nextBite = now + 1
                local damage = DamageInfo()
                damage:SetDamage(10)
                damage:SetDamageType(DMG_GENERIC)
                damage:SetAttacker(game.GetWorld())
                damage:SetInflictor(game.GetWorld())
                ply:TakeDamageInfo(damage)
                if not ply:Alive() then stopWater(ply) end
            end
        end
    end
end)

hook.Add("PlayerDeath", "COF.Lake.WaterDeath", stopWater)
hook.Add("PlayerDisconnected", "COF.Lake.WaterDisconnect", stopWater)
hook.Add("PlayerSpawn", "COF.Lake.WaterRespawn", stopWater)
hook.Add("PreCleanupMap", "COF.Lake.Reset", function()
    for ply in pairs(wet) do stopWater(ply) end
    watros = setmetatable({}, {__mode = "k"})
    nextThink = 0
end)
