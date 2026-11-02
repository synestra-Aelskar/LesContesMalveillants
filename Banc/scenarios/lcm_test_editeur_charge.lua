__declencher('PLAYER_LOGIN')
__personnage()
LCM._masterCompanion=true;LCM.db.settings.modeJoueur=nil
local Z=LCM.Crossings
local zones={}
for j=1,24 do
 local zone=Z:CreateZone('Region '..j);zones[#zones+1]=zone
 local place=Z:CreatePlace(zone.id,'Lieu '..j)
 local sub=Z:GetPlaceAreas(place.id)[1].sub
 sub.points={};sub.shape='polygon';sub.regionReady=true;sub.mapID=1;sub.enabled=true
 for i=1,900 do
  local a=i*2*math.pi/900
  sub.points[i]={x=(j%6)*220+math.cos(a)*100,y=math.floor(j/6)*220+math.sin(a)*100}
 end
end
local map=LCMCrossings.CreateZoneMap(UIParent,900,600,{Regions=function() return zones end})
map:Fit()
local start=os.clock()
map:Draw()
assert(not map.attrapables and map.renderCounts.handles==0,'poignees invisibles toujours dessinees')
print('Dessin initial 21600 sommets (banc): '..(os.clock()-start))
local draw=map.Draw;local draws=0
map.Draw=function(self,...) draws=draws+1;return draw(self,...) end
for i=1,30 do
 map:GetScript('OnMouseWheel')(map,i<=15 and 1 or -1)
 map:GetScript('OnUpdate')(map,.016)
end
assert(draws==0,'reconstruction pendant rafale continue')
map:GetScript('OnUpdate')(map,.3)
assert(draws==1,'la rafale doit produire un seul dessin final')
assert(not map.pendingZoom and map.scene:GetScale()==1,'scene non stabilisee')
-- Un sommet immobile apres un deplacement ne doit pas relancer le travail.
local sub=Z:GetPlaceAreas(Z:GetPlaceList(zones[1].id)[1].id)[1].sub
map.prise={subId=sub.id,index=1,bouge=true,mx=0,my=0,lastX=0,lastY=0}
local cursor=GetCursorPosition
GetCursorPosition=function() return 0,0 end
local before=draws
for i=1,100 do map:GetScript('OnUpdate')(map,.016) end
assert(draws==before,'sommet immobile redessine')
map.prise=nil;GetCursorPosition=cursor
print('TOUT PASSE : 24 regions, 21600 sommets, 30 crans, 1 reconstruction')
