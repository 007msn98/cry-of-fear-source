local hooks={}
game={GetMap=function() return "cof_coop_start" end}
hook={Add=function(_,name,fn) hooks[name]=fn end}
hook.Run=function(event,map) assert(event=="COF.Coop.BeforeChangeLevel" and map=="c_cof_village2") end
resource={AddFile=function() end}
function IsValid(x) return type(x)=="table" and not x.removed end
local vector={}
function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
function vector.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
function vector.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
IN_USE,MASK_SOLID,HUD_PRINTCENTER=1,1,1
local now=0
function CurTime() return now end
local playing=true
local function mockPlayer()
 return {Alive=function() return true end,GetNWBool=function() return playing end,
 GetShootPos=function() return Vector(0,0,0) end,GetAimVector=function() return Vector(1,0,0) end,
 PrintMessage=function(self,_,s) self.message=s end,EmitSound=function(self,s) self.sound=s end}
end
local a,b=mockPlayer(),mockPlayer()
local installed,loads=false,0
_G.player={GetAll=function() return {a,b} end}
file={Exists=function(path,realm)
 assert(path=="maps/c_cof_village2.bsp" and realm=="GAME")
 return installed
end}
function RunConsoleCommand(command,map)
 assert(command=="changelevel" and map=="c_cof_village2")
 loads=loads+1
end
function a:WorldSpaceAABB() return Vector(2600,930,-80),Vector(2632,962,-8) end
function b:WorldSpaceAABB() return Vector(self.x or 2400,930,-80),Vector((self.x or 2400)+32,962,-8) end
local function object()
 return {GetClass=function() return "func_brush" end,EmitSound=function(self,s) self.sound=s end}
end
local door,check,otherCar,exit=object(),object(),object(),object()
local traced=door
util={TraceLine=function() return {Entity=traced} end}
dofile("addon/lua/autorun/server/cof_coop_start_interactions.lua")
local key=hooks["COF.CoopStart.InteractionKeys"]
key(door,"cof_lockedby","unreachable_original_master")
key(door,"cof_lockedmsg","Simon is not home.")
key(check,"cof_check","1");key(check,"cof_message","Our cars have stopped working.")
key(check,"cof_usesound","doors/car_door_locked.wav");key(check,"cof_checkdelay","2")
key(otherCar,"cof_check","1");key(otherCar,"cof_message","The interior is destroyed.")
key(exit,"cof_nextmap","c_cof_village2")
local use=hooks["COF.CoopStart.Inspect"]
playing=false;use(a,IN_USE);assert(not a.message)
playing=true;use(a,IN_USE);assert(a.message=="Simon is not home.")
traced=check;use(a,IN_USE)
assert(a.message=="Our cars have stopped working." and a.sound=="cof_coop_start/car_door_locked.wav")
use(b,IN_USE);assert(not b.message,"car cooldown must be shared")
traced=otherCar;use(b,IN_USE);assert(b.message=="The interior is destroyed.","cooldown belongs to the car")
now=2;traced=nil
use(b,IN_USE);assert(b.message=="The interior is destroyed.","inspection passed through wall")
traced=check;use(b,IN_USE);assert(b.message=="Our cars have stopped working.")
traced=exit
use(a,IN_USE);assert(a.message:find("c_cof_village2"))
installed=true;now=3
use(a,IN_USE);assert(loads==0 and a.message:find("Reúna"))
b.x=2750;use(a,IN_USE);use(b,IN_USE);assert(loads==1)

-- A valid internal door must teleport only after its destination hull is clear.
local inner=object()
key(inner,"cof_target","staffquarters_b2");key(inner,"cof_lockedby","")
traced=inner
local destination={GetPos=function() return Vector(781,665,145) end,
 GetAngles=function() return {y=180} end}
local exits={destination}
ents={FindByName=function(name) assert(name=="staffquarters_b2");return exits end}
function Angle(p,y,r) return {p=p,y=y,r=r} end
MASK_PLAYERSOLID=2
function a:GetHull() return Vector(-16,-16,0),Vector(16,16,72) end
function a:SetPos(v) self.position=v end
function a:SetEyeAngles(v) self.angles=v end
function a:SetLocalVelocity(v) self.velocity=v end
local obstruction=true
util.TraceHull=function(t)
 assert(t.start.z==146 and t.mins.x==-16 and t.filter==a and t.mask==MASK_PLAYERSOLID)
 return {StartSolid=obstruction}
end
now=5;use(a,IN_USE);assert(not a.position and a.message:find("obstruída"))
obstruction=false;now=6;use(a,IN_USE)
assert(a.position.x==781 and a.position.z==146 and a.angles.y==180 and a.velocity.x==0)
a.position=nil;use(a,IN_USE);assert(not a.position,"door cooldown")
now=7;exits={};use(a,IN_USE);assert(not a.position and a.message:find("indisponível"))
now=8;exits={destination,destination};use(a,IN_USE);assert(not a.position)
now=9;exits={destination};key(inner,"cof_lockedby","gatekey2");use(a,IN_USE)
assert(not a.position,"a real original lock must remain locked")
