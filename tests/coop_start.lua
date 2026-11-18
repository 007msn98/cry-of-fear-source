-- Offline multiplayer state tests; no engine rendering/audio or Weapon Pack execution.
SERVER = true
function AddCSLuaFile() end
function IsValid(v) return type(v) == "table" and not v.removed end
local vector = {}
vector.__index = vector
function Vector(x,y,z) return setmetatable({x=x,y=y,z=z}, vector) end
function vector.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
function vector:DistToSqr(b) return (self.x-b.x)^2+(self.y-b.y)^2+(self.z-b.z)^2 end
vector_origin = Vector(0,0,0)
MASK_PLAYERSOLID, HUD_PRINTTALK = 1, 2
local now, timers, hooks, receivers, sent = 0, {}, {}, {}, {}
function CurTime() return now end
function RealTime() return now end
game = {GetMap=function() return "cof_coop_start" end}
hook = {Add=function(_,name,fn) hooks[name]=fn end,Run=function(name,p)
 if name=="COF.CoopStart.RestoreRespawn" then p.restored=true end
end}
timer = {Simple=function(delay,fn) timers[#timers+1]={at=now+delay,fn=fn} end}
local function advance(time)
    now=time
    while true do
        local chosen
        for i,t in ipairs(timers) do if t.at<=now then chosen=i break end end
        if not chosen then break end
        local t=table.remove(timers,chosen);t.fn()
    end
end
local packet, incomingToken, incomingOk
net = {Start=function(name) packet={name=name} end,
 WriteBool=function(v) packet.start=v end,WriteUInt=function(v) packet.token=v end,
 Send=function(p) packet.player=p;sent[#sent+1]=packet;p.packet=packet end,
 ReadUInt=function() return incomingToken end,ReadBool=function() return incomingOk end,
 Receive=function(name,fn) receivers[name]=fn end}
local unavailable, blocked = false, false
weapons = {GetStored=function(class)
 if unavailable then return nil end
 return {ViewModel="models/test.mdl",WorldModel="models/test.mdl"}
end}
scripted_ents = {GetStored=function() return not unavailable and {} or nil end}
file = {Exists=function() return true end}
resource = {AddFile=function() end}
util = {AddNetworkString=function() end,TraceHull=function(t)
 return {Hit=blocked,StartSolid=blocked,AllSolid=false}
end}
ents = {FindByName=function(name)
 local index=tonumber(name:match("(%d)$"))
 if not index then return {} end
 local campaign=name:find("cof_coop_arrival_")
 return {{GetPos=function() return Vector(campaign and index*100 or -12000,index,0) end,
 GetAngles=function() return {} end}}
end,Create=function() error("campaign pickups must not be created per player") end}
local function player(id)
 return {id=id,pos=Vector(-12000,0,0),nw={},loadouts=0,
  EntIndex=function(self) return self.id end,IsPlayer=function() return true end,
  Alive=function(self) return not self.dead end,GetPos=function(self) return self.pos end,
  SetPos=function(self,pos) self.pos=pos end,GetHull=function() return Vector(-16,-16,0),Vector(16,16,72) end,
  SetEyeAngles=function() end,SetLocalVelocity=function() end,
  SetNWBool=function(self,k,v) self.nw[k]=v end,PrintMessage=function(self,_,v) self.diagnostic=v end,
  StripWeapons=function(self) self.loadouts=self.loadouts+1 end,RemoveAllAmmo=function() end,
  Give=function(self,class)
   self.given=self.given or {};self.given[#self.given+1]=class
   local w={SetClip1=function(_,v) self.clip=v end};return w
  end,SetAmmo=function(self,v,kind) self.ammo=v;self.ammoType=kind end,
  SelectWeapon=function(self,class) self.selected=class end,
  Freeze=function() error("movement must remain free") end,
  SetModel=function() error("playermodel must remain intact") end,
  SetupHands=function() error("hands must remain intact") end}
end
local relayWatch={GetName=function() return "cof_coop_watch_signal" end}
local relaySkip={GetName=function() return "cof_coop_skip_signal" end}
local function button(name)
 return {GetClass=function() return "func_button" end,GetName=function() return name end,
 WorldSpaceCenter=function() return Vector(-12000,0,0) end}
end
local watch,skip=button("cof_intro_watch"),button("cof_intro_skip")
local function loadRuntime() dofile("addon/lua/autorun/cof_coop_start.lua") end
loadRuntime()
hooks["COF.CoopStart.Preflight"]()
local a,b=player(1),player(2)
hooks["COF.CoopStart.Spawn"](a);hooks["COF.CoopStart.Spawn"](b);advance(0)
local function use(p,watching)
 hooks["COF.CoopStart.Buttons"](watching and relayWatch or relaySkip,"Trigger",p,watching and watch or skip)
end
local function ack(p,token,ok)
 incomingToken,incomingOk=token,ok;receivers.cof_coop_start_ready(0,p)
end
local function finished(p,token)
 incomingToken=token;receivers.cof_coop_start_finished(0,p)
end
use(a,true);local token=a.packet.token
use(a,true);assert(a.packet.token==token)
ack(a,token+1,true) -- forged/stale token must do nothing
advance(5);ack(a,token,true)
use(b,false)
assert(b.nw.cof_coop_playing and b.clip==8 and b.ammo==8 and b.ammoType=="Pistol")
assert(b.selected=="weapon_cof_nightstick" and b.loadouts==1 and not a.nw.cof_coop_playing)
advance(55.7);assert(not a.nw.cof_coop_playing) -- deadline is relative to ACK at t=5
advance(61);assert(not a.nw.cof_coop_playing, "timer released before client detected the end")
finished(a,token+1)
advance(62);finished(a,token)
advance(71.99);assert(not a.nw.cof_coop_playing)
advance(72);assert(a.nw.cof_coop_playing and a.loadouts==1)
advance(200);assert(a.loadouts==1 and b.loadouts==1)
-- Respawn skips intro and restores the death snapshot instead of giving starter weapons.
hooks["COF.CoopStart.Death"](a);hooks["COF.CoopStart.Spawn"](a);advance(200)
assert(a.nw.cof_coop_playing and a.restored and a.loadouts==1)
local late=player(3);hooks["COF.CoopStart.Spawn"](late);advance(200)
assert(not late.nw.cof_coop_playing and late.loadouts==0)
use(late,true);local oldToken=late.packet.token
use(late,false);assert(late.nw.cof_coop_playing and not late.packet.start)
ack(late,oldToken,true);advance(300);assert(late.loadouts==1)
-- No safe hull means no loadout/entry; retry via the same physical button.
local c=player(4);hooks["COF.CoopStart.Spawn"](c);advance(300)
blocked=true;use(c,false);assert(not c.nw.cof_coop_playing and c.loadouts==0 and c.diagnostic)
blocked=false;use(c,false);assert(c.nw.cof_coop_playing and c.loadouts==1)
-- An early finish cannot shorten the minimum voice duration plus ten seconds.
local early=player(6);hooks["COF.CoopStart.Spawn"](early);advance(300)
use(early,true);token=early.packet.token;ack(early,token,true);finished(early,token)
advance(355);assert(not early.nw.cof_coop_playing)
advance(356);assert(early.nw.cof_coop_playing)
-- Missing dependency is latched at map load: activating it later requires a reload.
unavailable=true;loadRuntime();hooks["COF.CoopStart.Preflight"]()
local d=player(5);hooks["COF.CoopStart.Spawn"](d);advance(356)
use(d,false);assert(not d.nw.cof_coop_playing and d.loadouts==0 and d.diagnostic:find("Depend"))
unavailable=false;use(d,false);assert(d.loadouts==0)
loadRuntime();hooks["COF.CoopStart.Preflight"]();hooks["COF.CoopStart.Spawn"](d);advance(356)
use(d,true);token=d.packet.token;ack(d,token,false)
assert(not d.packet.start and not d.nw.cof_coop_playing)
use(d,true);token=d.packet.token;ack(d,token,true)
advance(432);assert(d.diagnostic:find("fim da voz") and not d.packet.start)
use(d,true);token=d.packet.token;ack(d,token,true);finished(d,token)
hooks["COF.CoopStart.Disconnect"](d);advance(500);assert(d.loadouts==0)

-- Client: wall is fixed; skip/reset invalidates an asynchronous load callback.
SERVER=false
function Material() return {} end
function Angle(p,y,r) return {p=p,y=y,r=r} end
local projection,drawn= nil,0
cam={Start3D2D=function(pos) projection=pos end,End3D2D=function() end}
surface={CreateFont=function() end,SetDrawColor=function() end,SetMaterial=function() end,
 DrawTexturedRect=function() drawn=drawn+1 end}
local pending,clientStart,clientToken
net.ReadBool=function() return clientStart end
net.ReadUInt=function() return clientToken end
net.SendToServer=function() sent[#sent+1]=packet end
sound={PlayFile=function(_,_,cb) pending=cb end}
loadRuntime()
local receive=receivers.cof_coop_start_intro
clientStart,clientToken=true,100;receive()
local stale=pending
clientStart=false;receive()
local orphan={Stop=function(self) self.stopped=true end}
stale(orphan);assert(orphan.stopped)
clientStart,clientToken=true,102;receive()
GMOD_CHANNEL_STOPPED=0
local audio={SetVolume=function() end,Play=function(self) self.played=true end,Stop=function(self) self.stopped=true end,
 GetState=function(self) return self.state end}
pending(audio);assert(audio.played)
hooks["COF.CoopStart.Wall"](false,false)
assert(drawn==1 and projection.x==-11746 and projection.y==80 and projection.z==176)
local checkVoice=hooks["COF.CoopStart.VoiceEnd"]
local previous=#sent
audio.state=GMOD_CHANNEL_STOPPED;checkVoice();assert(#sent==previous)
advance(546);audio.state=1;checkVoice();assert(#sent==previous)
audio.state=GMOD_CHANNEL_STOPPED;checkVoice();checkVoice()
assert(#sent==previous+1 and sent[#sent].name=="cof_coop_start_finished" and sent[#sent].token==102)
clientStart=false;receive();assert(audio.stopped)
hooks["COF.CoopStart.Wall"](false,false);assert(drawn==1)
