-- Offline harness. Engine and VJ interfaces are simulated.
local MAP = "gm_construct"

local v={};v.__index=v
function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},v) end
function v.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
function v.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
function v:DistToSqr(b) return (self.x-b.x)^2+(self.y-b.y)^2+(self.z-b.z)^2 end
local now=0
function CurTime() return now end
function IsValid(e) return e and not e.removed end
local hooks={}
hook={Add=function(name,id,fn) hooks[name]=fn end}
game={GetMap=function() return MAP end,GetWorld=function() return 'world' end}
CONTENTS_WATER=32;DMG_GENERIC=0;VJ_STATE_FREEZE=1;VJ_STATE_NONE=0
local contents=32
util={PointContents=function() return contents end}
local players={}
player={GetAll=function() return players end}
function DamageInfo()
 local d={}
 function d:SetDamage(n) self.amount=n end
 function d:SetDamageType(n) assert(n==DMG_GENERIC) end
 function d:SetAttacker(n) assert(n=='world') end
 function d:SetInflictor(n) assert(n=='world') end
 return d
end
local sounds={}
function CreateSound(p,path)
 local s={owner=p,path=path}
 function s:PlayEx(vol,pitch) self.playing=true end
 function s:Stop() self.playing=false end
 sounds[#sounds+1]=s
 return s
end
local function playerMock(x)
 local p={hp=100,pos=Vector(x or 1000,0,24),water=0,notarget=false}
 function p:GetPos() return self.pos end
 function p:Alive() return self.hp>0 end
 function p:GetNoTarget() return self.notarget end
 function p:WaterLevel() return self.water end
 function p:TakeDamageInfo(d) self.hp=self.hp-d.amount end
 return p
end
local function tick(t) now=t;hooks.Think() end
local function npcMock(class)
 local n={class=class or 'npc_vj_cof_watro',HasMeleeAttack=true,AnimTbl_IdleStand='idle',hp=100}
 function n:GetClass() return self.class end
 function n:GetForward() return Vector(1,0,0) end
 function n:SetPos(p) self.pos=p end
 function n:SetState(s) self.state=s end
 function n:ResetSequence(s) self.seq=s end
 function n:SetCycle(c) self.cycle=c end
 function n:SetNotSolid(s) self.notSolid=s end
 function n:LookupSequence(s) return s end
 function n:GetSequence() return self.seq end
 function n:Health() return self.hp end
 function n:Visible(p) return not p.blocked end
 function n:PlayAnim(s,lock,dur) assert(lock and dur==false);self.seq=s;return s,1 end
 function n:EmitSound(s) self.sound=s end
 return n
end
local marker={GetPos=function() return Vector(0,0,23) end}

dofile("addon/lua/autorun/server/cof_coop_lake.lua")
assert(next(hooks) == nil, "Lake hooks must not run on other maps")
MAP = "c_cof_lake"
dofile("addon/lua/autorun/server/cof_coop_lake.lua")

local p=playerMock();local q=playerMock();players={p,q}
local n=npcMock()
hooks['COF.Coop.BeforeNPCSpawn'](n,marker)
n.pos=Vector(0,0,54) -- pack Init +30Z
hooks['COF.Coop.AfterNPCSpawn'](n,marker)
assert(n.pos.z==24 and n.seq=='under' and n.notSolid and not n.HasMeleeAttack)
tick(0);assert(n.state==VJ_STATE_FREEZE)
p.pos=Vector(356.1,0,24);tick(.2);assert(n.seq=='under')
p.pos=Vector(355,0,24);p.blocked=true;tick(.4);assert(n.seq=='under')
p.blocked=false;p.hp=0;tick(.6);assert(n.seq=='under')
p.hp=100;p.notarget=true;tick(.8);assert(n.seq=='under')
p.notarget=false;tick(1);assert(n.seq=='vjseq_appear' and not n.HasMeleeAttack)
assert(not n.notSolid and n.state==VJ_STATE_NONE and n.sound=='sewmo/out_water.wav')
tick(1.8);assert(not n.HasMeleeAttack)
tick(2.01);assert(n.HasMeleeAttack and n.AnimTbl_IdleStand=='idle')
-- Honor VJ's post-Initialize configuration, including melee disabled.
local off=npcMock();hooks['COF.Coop.BeforeNPCSpawn'](off,marker)
off.HasMeleeAttack=false;hooks['COF.Coop.AfterNPCSpawn'](off,marker)
tick(2.2);tick(3.3);assert(off.HasMeleeAttack==false)
local other=npcMock('npc_other');hooks['COF.Coop.BeforeNPCSpawn'](other,marker)
hooks['COF.Coop.AfterNPCSpawn'](other,marker);assert(other.state==nil and other.HasMeleeAttack)
-- Native contents required; water-level alone does not activate on dry deck.
p.water=1;contents=0;tick(4);tick(8);assert(p.hp==100 and #sounds==0)
contents=32;tick(10);tick(12.89);assert(p.hp==100 and #sounds==0)
q.water=1;tick(13.01);assert(p.hp==90 and q.hp==100 and #sounds==2)
tick(13.5);assert(p.hp==90)
tick(14.02);assert(p.hp==80)
p.water=0;tick(14.2);assert(not sounds[1].playing and not sounds[2].playing)
tick(16.02);assert(q.hp==90)
p.water=1;tick(17);tick(19.89);assert(p.hp==80)
tick(20.01);assert(p.hp==70)
hooks.PlayerDeath(p);assert(not sounds[#sounds].playing)
hooks.PlayerDisconnected(q);for _,s in ipairs(sounds) do assert(not s.playing) end
-- Fresh delay after respawn and cleanup, even if still in the water.
hooks.PlayerSpawn(p);tick(21);tick(23.89);assert(p.hp==70)
tick(24.01);assert(p.hp==60)
hooks.PreCleanupMap();for _,s in ipairs(sounds) do assert(not s.playing) end
tick(25);tick(27.89);assert(p.hp==60)
tick(28.01);assert(p.hp==50)
-- Damage killing a player stops both patches in that same update.
p.hp=5;tick(29.02);assert(p.hp==-5)
for _,s in ipairs(sounds) do if s.owner==p then assert(not s.playing) end end
-- Removed NPC and cleanup cannot leave a future emergence action.
local gone=npcMock();hooks['COF.Coop.BeforeNPCSpawn'](gone,marker)
hooks['COF.Coop.AfterNPCSpawn'](gone,marker);gone.removed=true;tick(30)
hooks.PreCleanupMap();tick(31)
