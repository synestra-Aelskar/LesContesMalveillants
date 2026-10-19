-- Geometrie, encre et restauration d'un feuillet tourne.
__declencher("PLAYER_LOGIN")
local A = LCM.UI.LivresAnimation
local p0, pm, p1 = A.Projeter(1,0,0,1,"feuille"), A.Projeter(1,0,0.5,1,"feuille"), A.Projeter(1,0,1,1,"feuille")
assert(math.abs(p0.x-797)<0.01 and math.abs(p1.x-103)<0.01, "bords papier au repos")
assert(pm.z>200, "la feuille se souleve en profondeur")
assert(pm.y<p0.y-30, "la perspective souleve le bord")
local haut, bas = A.Projeter(1,0,.4,1,"feuille"), A.Projeter(1,1,.4,1,"feuille")
assert(math.abs(haut.x-bas.x)>10, "bord courbe, pas une compression rectangulaire")
local gauche=A.Projeter(1,0,.4,-1,"feuille")
assert(math.abs(gauche.x+haut.x-900)<.01, "retour symetrique")
local def={id="mesh_test",label="Test",format="livre",pages={
 {titre="Premier",texte="À l’aube, le veilleur écrivait encore."}, {titre="Deuxième",texte="Feuillet recto"},
 {titre="Troisième",texte="Feuillet verso"}, {titre="Quatrième",texte="En dessous"}}}
assert(LCM.UI.Livres.Apercu(def))
local f=LCM.UI.Livres.frame
f:Tourner(1);__avancer(1.1)
f:Tourner(1)
assert(#f.animation.recto>10 and #f.animation.verso>10,"encre presente sur les deux faces")
__avancer(.3)
assert(#f.tourne.glyphes>10,"encre projetee dans le maillage")
assert(f.index==2,"pas de changement de page premature")
assert(f.gauche.texte:GetText():find("veilleur"),"page immobile conservee")
f:Hide()
assert(f.droite.texte:GetText()=="Feuillet recto","interruption restaure le dessous")
assert(f.index==2 and not f.tourne:IsShown(),"interruption sans saut de page")
f:Ouvrir(LCM.Livres.Construire(def));f:Tourner(1);__avancer(1.1)
f:Tourner(1);__avancer(1.1);f:Tourner(-1);__avancer(1.1)
assert(f.index==2 and f.droite.texte:GetText()=="Feuillet recto","retour arriere conserve le contenu")
f.gauche.texte:SetText("|cffff0000Écriture colorée|r")
A.Encrer(f.gauche)
assert(f.gauche.texte:IsShown() and not f.gauche.encre,"balises natives preservees")
assert(def.pages[2].texte=="Feuillet recto","aucune modification des donnees")
print("MAILLAGE ET ENCRE : TOUT PASSE")
