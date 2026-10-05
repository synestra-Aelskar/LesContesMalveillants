__declencher("PLAYER_LOGIN")
__personnage()
local e = LCM.Entities.Self()
local f = LCM.UI.Fiche.Fenetre()
f:Montrer(e)
-- 4 octobre 2026 : l'artwork est un VOLET LATERAL, pose a l'exterieur du bord
-- gauche. La fenetre ne double plus de largeur et ne saute plus sous la souris
-- quand on l'ouvre ou qu'on le ferme.
assert(f:GetWidth() == 340, "la fenetre garde sa largeur")
assert(f.artwork:IsShown(), "artwork visible")
local _, ancreVolet = f.artwork:GetPoint(1)
assert(ancreVolet == f, "le volet est accroche a la fenetre")
-- Il porte l'habillage complet, comme une fenetre : pose a l'exterieur du bord
-- gauche, un simple filet le faisait flotter a cote du cadre dore.
assert(f.artwork.cadre ~= nil, "le volet a son cadre")
-- Et l'image se range dedans, pas sous la bordure.
local _, _, _, artX = f.artwork.art:GetPoint(1)
assert(artX >= 2, "l'image laisse la place au cadre")
assert(not f.artwork.inconscient:IsShown(), "artwork normal quand le personnage vit")
local _, _, _, ongletsX = f.barre:GetPoint(1)
assert(ongletsX == 24 and f.barre:GetWidth() == f:GetWidth() - 72, "onglets rentres dans le cadre")
local enc = LCM.UI.AelEncoches(f)
if enc then
    local pc, _, rc, canalX, canalY = f.canal:GetPoint(1)
    local pf, _, rf, fermerX, fermerY = f.fermer:GetPoint(1)
    assert(pc == "CENTER" and rc == "TOPLEFT" and canalX == enc.gauche[1] and canalY == enc.gauche[2], "pastille centree dans l'encoche gauche")
    assert(pf == "CENTER" and rf == "TOPRIGHT" and fermerX == enc.droite[1] and fermerY == enc.droite[2], "croix centree dans l'encoche droite")
    assert(f.fermer:GetWidth() == math.max(10, math.floor(enc.cote + 0.5)) and f.canal:GetWidth() == f.fermer:GetWidth(), "a la taille de l'encoche")
end
assert(f.artwork.niveau:GetText() == "Niveau " .. LCM.Entities.Get_Value(e, "niveau"))
f:Afficher("traits")
assert(f:GetWidth() == 340 and not f.artwork:IsShown(), "traits : pas de volet, meme largeur")
assert(f.barre:GetWidth() == 268, "onglets compacts dans le cadre")
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
-- Le volet revient, la fenetre reste a sa largeur : c'est tout l'interet.
assert(f:GetWidth() == 340 and f.artwork:IsShown(), "retour du volet, largeur inchangee")
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
assert(tostring(f.artwork.inconscient.voile:GetTexture()):find("voile%-inconscient") ~= nil, "voile en une texture")
assert(f.artwork.inconscient.__allPoints == f.artwork.art, "voile cale sur le portrait, sans liseré")
assert(f.artwork.jauge:GetParent():GetFrameLevel() > f.artwork.inconscient:GetFrameLevel(), "le niveau passe devant le voile")
for _, zone in ipairs(LCM.Body.State(e)) do
    if zone.current > 0 then LCM.Body.Damage(e, zone.id, 1) break end
end
assert(select(1, LCM.Body.Totals(e)) < 0 and f.artwork.inconscient:IsShown(), "reste visible sous zero")
LCM.Body.HealAll(e)
assert(not f.artwork.inconscient:IsShown(), "voile retire apres soin")
-- Replier l'artwork (4 octobre 2026). Il prend la moitie de la fenetre et ne
-- sert pas a tout : quand on vient lire ses chiffres, l'artwork, le niveau et
-- l'experience sont du decor. Le choix est retenu d'une ouverture a l'autre.
f:Afficher("statistiques")
local largeOuvert = f:GetWidth()
assert(f.artwork:IsShown(), "artwork visible sur Statistiques")
assert(f.replierArtwork:IsShown(), "la poignee est offerte")
f.replierArtwork:Click()
assert(not f.artwork:IsShown(), "replie au clic")
assert(f:GetWidth() == largeOuvert, "la fenetre ne bouge pas")
assert(LCM.db.settings.ficheArtworkReplie == true, "le choix est retenu")
f:Afficher("traits")
assert(not f.replierArtwork:IsShown(), "pas de poignee hors Statistiques")
f:Afficher("statistiques")
f.replierArtwork:Click()
assert(f.artwork:IsShown(), "redeplie au clic")
assert(f:GetWidth() == largeOuvert, "et elle n'a toujours pas bouge")

print("TOUT PASSE : artwork, onglets, experience et paliers")
