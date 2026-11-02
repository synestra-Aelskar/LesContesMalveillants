__declencher('PLAYER_LOGIN')
__personnage()
local Z=LCM.Crossings
Z:ShowRegionMap()
local w=LCMCrossingsRegionMap
w.cx,w.cy,w.scale=100,200,1
w.Moi=function() end;w.DrawFog=function() end
local draws=0;local draw=w.Draw
w.Draw=function(self,...) draws=draws+1;return draw(self,...) end
local wheel=w.canvas:GetScript('OnMouseWheel');local update=w:GetScript('OnUpdate')
GetCursorPosition=function() return 300,-200 end
local es=w.canvas:GetEffectiveScale();local ox,oy=300/es,200/es
local wx=100-(ox-464);local wy=200-(oy-272)
local function anchor()
 local x,y=w:ToScreen(wx,wy)
 local _,_,_,tx,ty=w.scene:GetPoint()
 local ratio=w.scene:GetScale()
 assert(math.abs((x+tx)*ratio-ox)<.0001 and math.abs((y-ty)*ratio-oy)<.0001,'ancre perdue pendant animation')
end
for i=1,6 do wheel(w.canvas,1) end
assert(draws==0,'dessin par cran')
update(w,.05)
assert(w.zoomAnimation and draws==0 and w.scene:GetScale()>1,'animation absente')
anchor()
local last=w.scene:GetScale()
for i=1,5 do update(w,.016);assert(w.scene:GetScale()>last,'animation non progressive');last=w.scene:GetScale();anchor() end
assert(draws==0,'geometrie recalculee par image')
update(w,.05)
assert(not w.zoomAnimation and draws==1 and math.abs(w.scale-1.25^6)<1e-8,'fin de zoom incorrecte')
assert(w.scene:GetScale()==1,'transform non remis a zero')
for i=1,6 do wheel(w.canvas,-1) end
update(w,.05)
assert(draws==2 and w.zoomAnimation and w.zoomAnimation.drawn,'dezoom doit preparer la destination une fois')
anchor()
for i=1,7 do update(w,.016);anchor() end
assert(not w.zoomAnimation and draws==2 and math.abs(w.scale-1)<1e-8,'dezoom redessine')
wheel(w.canvas,1);update(w,.05)
wheel(w.canvas,1);update(w,.12)
update(w,.05);update(w,.2)
assert(not w.zoomAnimation and math.abs(w.scale-1.25^2)<1e-8,'retarget perd un cran')
wheel(w.canvas,1);update(w,.05)
w:Hide()
assert(not w.zoomAnimation and not w.pendingZoom and w.scene:GetScale()==1,'fermeture laisse une transformation')
print('TOUT PASSE : animation image par image, ancre stable, 1 dessin par rafale, dezoom, retarget, fermeture')
