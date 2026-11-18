SERVER=true
function AddCSLuaFile() end
game={GetMap=function() return "cof_coop_start" end}
util={AddNetworkString=function() end}
resource={AddFile=function() end}
local hooks,queue,sends,fires={},{},0,0
hook={Add=function(_,name,fn) hooks[name]=fn end}
timer={Simple=function(delay,fn) queue[#queue+1]={delay,fn} end}
net={Start=function() end,Send=function() sends=sends+1 end}
function include(path)
 assert(path=="cof_coop_start/storm.lua")
 return {multistartus={{"flash",0},{"multiblixtro1",35}},multiblixtro1={{"flash",0},{"skyblixt_3",0.2}}}
end
local flash={GetClass=function() return "light_dynamic" end,Fire=function(_,input) assert(input=="Toggle") fires=fires+1 end}
local sky={SkinCount=function() return 8 end,SetSkin=function(self,n) self.skin=n end,Fire=function() end}
ents={FindByName=function(name) return name=="flash" and {flash} or name=="skyblixt" and {sky} or {} end}
function IsValid(x) return x~=nil end
dofile("addon/lua/autorun/cof_coop_start_ambience.lua")
local a,b={},{}
local enter=hooks["COF.CoopStart.Ambience"]
enter(a);enter(a);enter(b)
assert(sends==2 and #queue==2,"storm or music duplicated by player entry")
queue[1][2]();assert(fires==1)
queue[2][2]();assert(#queue==4)
queue[3][2]();queue[4][2]();assert(fires==2 and sky.skin==3)
hooks["COF.CoopStart.StormReset"]()
local prior=fires
queue[1][2]();assert(fires==prior,"stale storm survived cleanup")
enter(a);assert(sends==3 and #queue==6)
