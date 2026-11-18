-- Offline state and delivery tests; does not simulate rendering or the audio engine.
SERVER = true
function AddCSLuaFile() end
function IsValid(v) return type(v)=="table" and not v.removed end
game={GetMap=function() return "cof_coop_intro_test" end}
util={AddNetworkString=function() end}
resource={AddFile=function() end}
local hooks, receivers = {},{}
hook={Add=function(_,name,fn) hooks[name]=fn end}
local sent, bit, target
net={Start=function() end,WriteBool=function(v) bit=v end,Send=function(p) sent=(sent or 0)+1 target=p end,
 Receive=function(n,fn) receivers[n]=fn end}
local function player()
 return {IsPlayer=function() return true end,Alive=function() return true end,
  GetNWBool=function(self) return self.active end,SetNWBool=function(self,_,v) self.active=v end,
  Freeze=function() error("intro must not change movement") end,PrintMessage=function() end}
end
local a,b=player(),player()
local relay={GetName=function() return "cof_intro_signal" end}
local watch={GetName=function() return "cof_intro_watch" end}
local skip={GetName=function() return "cof_intro_skip" end}
dofile("addon/lua/autorun/cof_coop_intro_test.lua")
local use=hooks["COF.IntroTest.Button"]
use(relay,"Trigger",a,skip);assert(not a.active and not sent)
use(relay,"Trigger",a,watch);assert(a.active and target==a and bit)
local count=sent
use(relay,"Trigger",a,watch);assert(sent==count and not b.active)
use(relay,"Trigger",b,watch);assert(b.active and target==b)
hooks["COF.IntroTest.Reset"](a);assert(not a.active and not bit and b.active)
receivers.cof_intro_test_error(0,b);assert(not b.active)

SERVER=false
local now=0
function RealTime() return now end
function Material() return {} end
function Vector(x,y,z) return {x=x,y=y,z=z} end
function Angle(p,y,r) return {p=p,y=y,r=r} end
function ScrW() return 1920 end
function ScrH() return 1080 end
local black,art=0,0
local projection
cam={Start3D2D=function(pos,angles,scale) projection={pos=pos,angles=angles,scale=scale} end,
 End3D2D=function() end}
surface={CreateFont=function() end,SetDrawColor=function() end,SetMaterial=function() end,
 DrawRect=function() black=black+1 end,DrawTexturedRect=function() art=art+1 end}
net.ReadBool=function() return bit end
net.SendToServer=function() sent=sent+1 end
GMOD_CHANNEL_STOPPED=0
local pending
sound={PlayFile=function(path,flags,cb)
 assert(path=="sound/cof_coop_intro/coop_introduction.wav" and flags=="noplay") pending=cb
end}
dofile("addon/lua/autorun/cof_coop_intro_test.lua")
local start=receivers.cof_intro_test
local paint=hooks["COF.IntroTest.Wall"]
local think=hooks["COF.IntroTest.Playback"]
local function stream()
 return {SetVolume=function() end,Play=function(self) self.played=true end,
 Stop=function(self) self.stopped=true end,GetState=function(self) return self.stopped and 0 or 1 end}
end
assert(not hooks["COF.IntroTest.Overlay"] and not hooks["COF.IntroTest.HideHUD"])
assert(not hooks["COF.IntroTest.HideWeapon"] and not hooks["COF.IntroTest.HideHands"])
bit=true;start();paint();assert(black==0 and art==1)
assert(projection.pos.x==254 and projection.pos.y==80 and projection.pos.z==176)
now=20 -- Waiting for loading must not consume any playback or hold time.
local voice=stream();pending(voice);assert(voice.played)
paint();assert(art==2)
-- Looking away/changing the view cannot move the projection's world coordinates.
local anchor=projection.pos
now=65.661814;voice.stopped=true;think();paint();assert(art==3)
now=75.65;think();paint();assert(art==4)
now=75.67;think();paint();assert(art==5 and black==0)
now=1000;think();paint();assert(art==6 and black==0)
assert(projection.pos.x==anchor.x and projection.pos.y==anchor.y and projection.pos.z==anchor.z)
paint(true,false);paint(false,true);assert(art==6)
-- Reset cancels an in-flight asynchronous file load.
bit=true;start();local stale=pending
bit=false;start();local orphan=stream();stale(orphan);assert(orphan.stopped and not orphan.played)
-- Failure returns to the room rather than showing an intro without voice.
bit=true;start();local before=sent;pending(nil,2,"missing");assert(sent==before+1)
local old=black;paint();assert(black==old)
