__declencher('PLAYER_LOGIN')
local person=__personnage();LCM.Personnages.Actif=function() return person end
LCM._masterCompanion=true;LCM.db.settings.modeJoueur=nil
local Z=LCM.Crossings
local zone=Z:CreateZone('Region secrete')
local place=Z:CreatePlace(zone.id,'Lieu secret')
local sub=Z:GetPlaceAreas(place.id)[1].sub
sub.points={{x=-50,y=-50},{x=50,y=-50},{x=50,y=50},{x=-50,y=50}}
sub.shape='polygon';sub.regionReady=true;sub.enabled=true;sub.mapID=999
Z.GetPlayerPose=function() return 0,0,0,999,0 end
Z:PreparerBrouillard(999)
local saved=LCM_CrossingsChar.parPerso[person.id]
saved.learnedZones[zone.id]=true;saved.learnedSubZones[place.id]=true
Z:MarkLearnedZoneName('visite-mj')
assert(not saved.playerKnowledge,'MJ enregistre connaissance joueur')
LCM.db.settings.modeJoueur=true
assert(not Z:HasLearnedZoneName(zone.id) and not Z:KnowsPlaceName(place),'historique MJ fuit en joueur')
local title,subTitle=Z:ResolveBannerText(place,zone)
assert(title~=zone.name and subTitle~=place.name,'auteur connait les noms')
Z:MarquerVu(999,0,0,60)
Z:ShowRegionMap()
local w=LCMCrossingsRegionMap
w:ShowRegion(zone)
w.cx,w.cy,w.scale=0,0,1;w:Draw()
assert(#w.hoverAreas>0,'zones de survol absentes')
title,subTitle=w:HoverAt(464,272)
assert(title and title~=zone.name and subTitle~=place.name,'hover inconnu non masque')
Z:MarkLearnedZoneName(zone.id)
title,subTitle=w:HoverAt(464,272)
assert(title==zone.name and subTitle~=place.name,'noms non independants')
Z:MarkLearnedSubZoneName(place.id)
title,subTitle=w:HoverAt(464,272)
assert(title==zone.name and subTitle==place.name,'apprentissage joueur absent')
LCM.db.settings.modeJoueur=nil
Z:MarkLearnedSubZoneName('autre-lieu-mj')
LCM.db.settings.modeJoueur=true
assert(not Z:HasLearnedSubZoneName('autre-lieu-mj') and Z:KnowsPlaceName(place),'bascule perd les connaissances ou ajoute celles du MJ')
assert(saved.learnedZones[zone.id] and saved.learnedSubZones[place.id],'archives supprimees')
-- Le parent des noms et icones est la couche juste sous le voile.
for _,frame in ipairs(w.scene.__children) do
 if frame:GetFrameLevel()==w.canvas:GetFrameLevel()+4 then
  for _,r in ipairs(frame.__regions) do
   if r.__kind=='FontString' then assert(not r:IsShown() or r:GetText()=='' ,'etiquette affichee sur carte M') end
  end
 end
end
GetCursorPosition=function() return 464,-272 end
w.canvas.__survol=true
w:UpdateMapTooltip()
assert(w.hoverTooltip and w.hoverTooltip:IsShown() and w.hoverTooltip.titre:GetText()==zone.name,'infobulle absente')
w.canvas:GetScript('OnLeave')()
assert(not w.hoverTooltip,'infobulle persiste hors carte')
Z:ForgetLearnedSubZoneName(place.id)
assert(not Z:KnowsPlaceName(place),'retrait ignore nouveaux noms')
print('TOUT PASSE : hover, masquage independant, absence etiquettes, auteur, switch, apprentissage, archives, retrait')
