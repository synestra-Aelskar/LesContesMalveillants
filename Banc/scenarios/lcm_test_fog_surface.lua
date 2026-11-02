__declencher('PLAYER_LOGIN')
local perso=__personnage()
LCM.Personnages.Actif=function() return perso end
LCM.IsMaster=function() return false end
local Z=LCM.Crossings
local function check(s,v) assert(v,s);print('OK '..s) end
Z:OublierBrouillard(999)
Z:MarquerVu(999,0,.5,20)
check('cercle rayon 20',Z:EstVu(999,20,.5) and not Z:EstVu(999,20.01,.5) and not Z:EstVu(999,19,19))
local state=Z:PreparerBrouillard(999)
local rev=state.revision
Z:MarquerVu(999,0,.5,20)
check('immobile sans modification',state.revision==rev)
local circles={}
math.randomseed(918)
for i=1,250 do
 local x,y,r=math.random(-200,200),math.random(-200,200),math.random(5,35)
 circles[#circles+1]={x=x,y=y,r=r};Z:MarquerVu(998,x,y,r)
end
local sample=Z:PreparerBrouillard(998)
for y=-240,240 do
 local row=sample.rows[y] or {}
 for i=1,#row,2 do assert(row[i]<row[i+1] and (i==1 or row[i]>row[i-1]),'union invalide') end
 for x=-240,240,4 do
  local expected=false
  for _,c in ipairs(circles) do if (x-c.x)^2+(y+.5-c.y)^2<c.r^2 then expected=true;break end end
  assert(Z:EstVu(998,x,y+.5)==expected,'union differente du disque de reference')
 end
end
check('union verifiee sur 58000 points, 250 disques',true)
local data=LCM_CrossingsChar.parPerso[perso.id]
local old={cercles={{x=-100,y=-50,r=20},{x=100,y=50,r=20}}}
old[(2048+4)*4096+2048+4]=true
data.brouillard[997]=old
local converted=Z:PreparerBrouillard(997)
check('migration programmee',not converted.ready)
Z:AvancerMigrationBrouillard(1)
check('migration bornee',not converted.ready)
while not converted.ready do Z:AvancerMigrationBrouillard(1000) end
check('anciennes decouvertes conservees',Z:EstVu(997,-100,-50) and Z:EstVu(997,225,225))
check('migration non rejouee',Z:PreparerBrouillard(997)==converted and converted.ready)
local backup=perso
perso={id='autre-test'}
check('personnages separes',not Z:EstVu(999,0,0))
perso=backup
check('cartes separees',not Z:EstVu(996,0,0))
Z:ShowRegionMap()
local w=LCMCrossingsRegionMap
w.cx,w.cy,w.scale,w.markerMap=0,0,2,999
w:DrawFog()
local function uncovered(wx,wy)
 local x,y=w:ToScreen(wx,wy)
 for _,t in ipairs(w.fog.__regions) do
  if t.__kind=='Texture' and t:IsShown() and t.fogLeft then
   local _,_,_,left,ny=t:GetPoint()
   if x>=left and x<left+t:GetWidth() and y>=-ny and y<-ny+t:GetHeight() then return false end
  end
 end
 return true
end
check('centre revele, exterieur cache',uncovered(0,0) and not uncovered(40,0))
local drawCount,fitCount=0,0
local draw=w.Draw;w.Draw=function(self,...) drawCount=drawCount+1;return draw(self,...) end
local fit=w.Fit;w.Fit=function(self,...) fitCount=fitCount+1;return fit(self,...) end
Z.GetPlayerPose=function() return 0,0,0,999,0 end
local update=w:GetScript('OnUpdate')
local start=os.clock()
for i=1,1000 do
 Z:MarquerVu(999,i*.2,.5,20)
 update(w,.1)
 assert(uncovered(0,0),'decouverte precedente recouverte')
end
local elapsed=os.clock()-start
check('1000 pas sans redessin du fond',drawCount==0 and fitCount==0)
check('nouvelle surface revelee',uncovered(190,0))
local view=w.fogView
Z.CurrentRegion=function() return {id='frontiere',countryId='autre'} end
w.follow=true
update(w,2)
check('frontiere sans reconstruction ni recadrage',w.fogView==view and drawCount==0 and fitCount==0)
w.hasBaseMap=true;w.openInstance=999
w:Hide();w:Show()
check('fermeture reouverture conserve vue et savoir',w.fogView==view and uncovered(0,0) and drawCount==0 and fitCount==0)
w.scale=1;w:DrawFog()
check('zoom sans rejeu',uncovered(0,0) and uncovered(190,0))
w.cx=100;w:DrawFog()
check('pan sans rejeu',uncovered(0,0) and uncovered(190,0))
Z:OublierBrouillard(999);w:DrawFog()
check('oubli explicite remet voile',not uncovered(0,0))
print(string.format('BENCH 1000 pas + rendu + controle pixels : %.3f s',elapsed))
print('TOUT PASSE')
