__declencher('PLAYER_LOGIN')
__personnage()
LCM._masterCompanion=true;LCM.db.settings.modeJoueur=nil
local Z=LCM.Crossings
local country=Z:CreateCountry('Pays dense')
local zone=Z:CreateZone('Region dense');zone.countryId=country.id
local place=Z:CreatePlace(zone.id,'Foret dense')
local sub=Z:GetPlaceAreas(place.id)[1].sub
sub.points={};sub.shape='polygon';sub.regionReady=true;sub.mapID=1;sub.enabled=true
for i=1,900 do local a=i*2*math.pi/900;sub.points[i]={x=math.cos(a)*100,y=math.sin(a)*100} end
local panel=LCMCrossingsPanel
panel.mode='country';panel.countryId=country.id;panel:Show();panel:RefreshAll()
local map=panel.paysMap
map:Fit()
local original=Z.Geo.Triangulate
local first,last
Z.Geo.Triangulate=function(points) if not first then first=points end;last=points;return original(points) end
map:Draw();local used=last
assert(used and #used<900,'contour non simplifie')
map:Draw();assert(last==used,'cache simplifie reconstruit')
local cx,cy,scale=map.cx,map.cy,map.scale
assert(panel.paysBoutons.nomade:IsVisible(),'bouton nomade masque')
local button=panel.paysBoutons.nomade
button:GetScript('OnClick')(button)
assert(not panel:IsShown() and map:IsVisible(),'carte pays non detachee')
assert(map.cx==cx and map.cy==cy and map.scale==scale,'nomade recadre')
button:GetScript('OnClick')(button)
assert(panel:IsShown() and map:IsVisible(),'rattachement perdu')
local draws=0;local draw=map.Draw
map.Draw=function(self,...) draws=draws+1;return draw(self,...) end
for i=1,8 do map:GetScript('OnMouseWheel')(map,1) end
assert(draws==0,'molette redessine par cran')
local before=map.scale
map:GetScript('OnUpdate')(map,.016)
assert(map.scale>before and draws==0,'zoom sans interpolation')
map:GetScript('OnUpdate')(map,.3)
assert(draws==1,'rafale pas regroupee')
print('TOUT PASSE : 900 points, cache reutilise, nomade pays, cadrage et rafale')

local beforeDraws=draws
map.pan={mx=0,my=0,cx=map.cx,cy=map.cy}
local oldCursor=GetCursorPosition
GetCursorPosition=function() return 30,40 end
map:GetScript('OnUpdate')(map,.016)
assert(draws==beforeDraws,'pan redessine la geometrie')
map:GetScript('OnMouseUp')(map,'LeftButton')
assert(draws==beforeDraws+1,'pan ne reconstruit pas au relachement')
GetCursorPosition=oldCursor
assert(#used<150,'trop de sommets inutiles pour un cercle')
print('TOUT PASSE : interpolation et pan sans reconstruction par image')
