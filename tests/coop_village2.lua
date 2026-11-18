local current = "cof_coop_start"
local hooks, saved, messages = {}, nil, {}
game = {GetMap=function() return current end, GetAmmoName=function(id) assert(id==1); return "Pistol" end}
hook = {Add=function(_,name,fn) hooks[name]=fn end, Run=function() end}
file = {
 Write=function(_,data) saved=data end,
 Read=function() return saved end,
 Delete=function() saved=nil end
}
util = {TableToJSON=function(data) return data end, JSONToTable=function(data,_,keepKeys)
 assert(keepKeys,"SteamID64 keys must stay strings")
 return data
end}
timer = {Simple=function(_,fn) fn() end}
function IsValid(value) return type(value)=="table" and not value.removed end
function ErrorNoHalt(message) error(message) end
local vector = {}
vector.__add = function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
vector.__sub = function(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
vector.__index = {Length2DSqr=function(v) return v.x*v.x+v.y*v.y end}
function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
local function weapon(class)
 return {clip1=3,clip2=-1,GetClass=function() return class end,
  Clip1=function(self) return self.clip1 end,Clip2=function(self) return self.clip2 end,
  SetClip1=function(self,n) self.clip1=n end,SetClip2=function(self,n) self.clip2=n end}
end
local p = {
 current={weapon("weapon_cof_p345"),weapon("weapon_cof_nightstick")},
 IsBot=function() return false end, SteamID64=function() return "123" end,
 Alive=function() return true end, GetNWBool=function() return true end,
 GetPos=function(self) return self.pos or Vector(0,0,66) end,
 SetNWBool=function(self,key,value) self[key]=value end, Health=function() return 63 end,
 Armor=function() return 17 end, GetWeapons=function(self) return self.current end,
 GetActiveWeapon=function(self) return self.current[1] end, GetAmmo=function() return {[1]=14} end,
 StripWeapons=function(self) self.current={} end, RemoveAllAmmo=function(self) self.reserve={} end,
 Give=function(self,class) local w=weapon(class); self.current[#self.current+1]=w; return w end,
 SetAmmo=function(self,n,ammo) self.reserve[ammo]=n end,
 SelectWeapon=function(self,class) self.selected=class end,
 SetHealth=function(self,n) self.hp=n end, SetArmor=function(self,n) self.armor=n end,
 PrintMessage=function(_,_,s) messages[#messages+1]=s end
}
player={GetAll=function() return {p} end}
local function loadRuntime() dofile("addon/lua/autorun/server/cof_coop_village2.lua") end
loadRuntime()
assert(hooks["COF.Coop.SuitFlashlight"](p) == true)
local lightOn, permitted, pending = true, false, nil
local old, new = weapon("weapon_cof_p345"), weapon("weapon_cof_nightstick")
function p:FlashlightIsOn() return lightOn end
function p:AllowFlashlight(value) permitted=value end
function p:Flashlight(value) lightOn=value end
local previousTimer = timer.Simple
timer.Simple=function(_,callback) pending=callback end
hooks["COF.Coop.KeepSuitFlashlight"](p,old,new)
lightOn=false
p.current[1]=new
pending()
assert(lightOn and permitted)
timer.Simple=previousTimer
p.current[1]=old
hooks["COF.Village2.SaveLoadout"]("c_cof_village2")
assert(saved.players["123"].weapons.weapon_cof_p345.primary==3)
assert(not saved.players["123"].weapons.weapon_cof_nightstick)

current="c_cof_village2"
loadRuntime()
assert(saved==nil,"transition snapshot must be consumed")
hooks["COF.Village2.Loadout"](p)
assert(p.cof_coop_playing and #p.current==1 and p.current[1].clip1==3)
assert(p.reserve.Pistol==14 and p.selected=="weapon_cof_p345" and p.hp==63 and p.armor==17)
p.current[2]=weapon("weapon_cof_syringe")
p.current[3]=weapon("weapon_cof_g43")
p.current[3].clip1=6
hooks["COF.Coop.SaveInventory"](p)
local restoredClasses={}
for _, w in ipairs(p.current) do restoredClasses[w:GetClass()]=w:Clip1() end
hooks["COF.Village2.Loadout"](p)
assert(#p.current==3 and p.reserve.Pistol==14 and p.selected=="weapon_cof_p345")
for _, w in ipairs(p.current) do assert(restoredClasses[w:GetClass()]==w:Clip1()) end
hooks["COF.Village2.Loadout"](p)
assert(#p.current==0 and next(p.reserve)==nil)
local worldWeapon={CreatedByMap=function() return true end,GetPos=function() return Vector(5,0,31) end}
local pickup=hooks["COF.Coop.NoPickupAtSpawn"]
assert(pickup(p,worldWeapon)==false)
hooks["COF.Coop.ClearPickupGuard"](p,{GetOrigin=function() return Vector(60,0,66) end})
assert(pickup(p,worldWeapon)==nil)

local created={}
ents={Create=function(class)
 local obj={class=class,SetPos=function(self,pos) self.pos=pos end,SetAngles=function() end,
  Spawn=function() end,Activate=function() end,Remove=function(self) self.removed=true end}
 created[#created+1]=obj
 return obj
end}
scripted_ents={GetStored=function() return {} end}
weapons={GetStored=function() return {} end}
local function mark(class,group,draws,x)
 local entity={GetClass=function() return "info_target" end,GetPos=function() return Vector(x,0,0) end,
  GetAngles=function() return {} end}
 local register=hooks["COF.Village2.EncounterKeys"]
 register(entity,"cof_npc",class)
 register(entity,"cof_group",group)
 register(entity,"cof_draws",draws)
 return entity
end
local points={mark("npc_vj_cof_sawcrazy","","0",1), mark("npc_vj_cof_slower1","group1","2",2),
 mark("npc_vj_cof_baby","group1","0",3), mark("npc_vj_cof_faster","group1","0",4)}
local attempts=0
math.random=function(count) assert(count==3); attempts=attempts+1; return 2 end
VJBASE_INSTALLED=false
hooks["COF.Village2.StartEncounter"]()
assert(#created==0 and attempts==0)
VJBASE_INSTALLED=true
hooks["COF.Village2.StartEncounter"]()
assert(attempts==2 and #created==2 and created[1].class=="npc_vj_cof_sawcrazy")
assert(created[2].pos.z==1 and #points==4)
hooks["COF.Village2.RestartEncounter"]()
assert(attempts==4 and #created==4 and created[1].removed and created[2].removed)
