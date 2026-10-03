__declencher("PLAYER_LOGIN")
__personnage()
local e = LCM.Entities.Self()
local f = LCM.UI.Fiche.Fenetre()
f:Montrer(e)
assert(f:GetWidth() == 680, "largeur doublee")
assert(f.artwork:IsShown(), "artwork visible")
assert(not f.artwork.inconscient:IsShown(), "artwork normal quand le personnage vit")
local _, _, _, ongletsX = f.barre:GetPoint(1)
assert(ongletsX == 16 and f.barre:GetWidth() == f:GetWidth() - 56, "onglets rentres dans le cadre")
local _, _, _, canalX, canalY = f.canal:GetPoint(1)
local _, _, _, fermerX, fermerY = f.fermer:GetPoint(1)
assert(canalX == -fermerX and canalY == fermerY, "boutons symetriques dans les encoches")
if LCM.UI.AelRetraitCoin(f) > 0 then
    assert(canalX < 30 and canalY > 0, "boutons poses dans les tours d'angle")
end
assert(f.artwork.niveau:GetText() == "Niveau " .. LCM.Entities.Get_Value(e, "niveau"))
f:Afficher("traits")
assert(f:GetWidth() == 340 and not f.artwork:IsShown(), "traits compacts")
assert(f.barre:GetWidth() == 284, "onglets compacts dans le cadre")
f:Afficher("statistiques")
local palier = LCM.Equilibrage.experience.paliers[1]
e.xp = 0
LCM.Experience.Donner(e, math.max(1, math.floor(palier.xp / 2)))
assert(f.artwork.xp:GetText() == e.xp .. " / " .. palier.xp, "gain XP visible sans rouvrir")
LCM.Experience.Donner(e, palier.xp - e.xp)
assert(f.artwork.xp:GetText():match("^0 / "), "nouveau palier remis a zero")
local paliers = LCM.Equilibrage.experience.paliers
e.xp = paliers[#paliers].xp
f:Actualiser()
assert(f.artwork.xp:GetText() == "Palier maximal", "dernier palier")
f.poignee:Click("LeftButton")
f:Afficher("facultes")
assert(f:GetWidth() == 340, "facultes compactes")
f:Afficher("statistiques")
assert(f:GetWidth() == 680, "retour artwork")
LCM.Entities.Set_Value(e, "race", "humain")
local pvRestants = select(2, LCM.Body.Totals(e))
for _, zone in ipairs(LCM.Body.State(e)) do
    if pvRestants > 0 then
        local degats = math.min(zone.max, pvRestants)
        LCM.Body.Damage(e, zone.id, degats)
        pvRestants = pvRestants - degats
    end
end
assert(select(1, LCM.Body.Totals(e)) == 0, "PV exactement a zero")
assert(f.artwork.inconscient:IsShown(), "voile inconscient immediat")
assert(f.artwork.inconscient.texte:GetText() == "INCONSCIENT", "titre de l'etat")
assert(f.artwork.inconscient.gouttes == nil, "plus de gouttes (retirees le 4 octobre, a redessiner)")
local bord = f.artwork.inconscient.bords[1]:GetGradient()
assert(bord and bord.min.a > 0.9 and bord.max.a == 0, "bord gauche : opaque au bord, efface vers le centre")
assert(bord.min.r < 0.2 and bord.max.r > 0.8, "du rouge sombre au rouge clair")
assert(f.artwork.inconscient.coeur.__color[4] < 0.5, "centre rouge clair translucide")
assert(f.artwork.jauge:GetParent():GetFrameLevel() > f.artwork.inconscient:GetFrameLevel(), "le niveau passe devant le voile")
for _, zone in ipairs(LCM.Body.State(e)) do
    if zone.current > 0 then LCM.Body.Damage(e, zone.id, 1) break end
end
assert(select(1, LCM.Body.Totals(e)) < 0 and f.artwork.inconscient:IsShown(), "reste visible sous zero")
LCM.Body.HealAll(e)
assert(not f.artwork.inconscient:IsShown(), "voile retire apres soin")
print("TOUT PASSE : artwork, onglets, experience et paliers")
