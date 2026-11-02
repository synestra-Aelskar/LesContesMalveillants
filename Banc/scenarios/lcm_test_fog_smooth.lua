__declencher('PLAYER_LOGIN')
__personnage()
local f=LCM.Crossings.Geo.SmoothFogRow
local a,b={-10,10},{-20,20}
local result=f(a,b,.25)
assert(result[1]==-12.5 and result[2]==12.5,'bords non interpoles')
assert(a[1]==-10 and b[1]==-20,'donnees sauvegardees modifiees')
local endCap=f(a,nil,.75)
assert(endCap[1]==-2.5 and endCap[2]==2.5,'extremite non lissee')
local separated=f({0,10},{50,60},.25)
assert(separated[1]==0 and separated[2]==10,'deux ilots relies')
local holes=f({0,10,30,40},{0,10},.25)
assert(#holes==4 and holes[2]<holes[3],'trou perdu')
LCM.IsMaster=function() return false end
local Z=LCM.Crossings
Z:ShowRegionMap()
local w=LCMCrossingsRegionMap
w.cx,w.cy,w.scale,w.markerMap=0,1,10,992
local state=Z:PreparerBrouillard(992)
state.rows[0]={-10,10,revision=1};state.rows[1]={-20,20,revision=1};state.revision=1
w:DrawFog()
local boundaries={}
for _,t in ipairs(w.fog.__regions) do
 if t.__kind=='Texture' and t:IsShown() and t.fogLeft==0 then
  local _,_,_,x,ny=t:GetPoint()
  local top=-ny
  if top>=268 and top<=275 then boundaries[#boundaries+1]=t:GetWidth() end
 end
end
assert(#boundaries==8,'bandes d un pixel absentes')
table.sort(boundaries)
for i=2,#boundaries do assert(math.abs(boundaries[i]-boundaries[i-1]-10)<.00001,'palier de zoom non interpole') end
print('TOUT PASSE : interpolation, extremites, ilots, trous, rendu zoome et sauvegarde intacte')
