-- Le lanceur radial : structure figee, deploiement, animation.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function rayon(bouton)
    local _, _, _, x, y = bouton:GetPoint(1)
    return math.floor(math.sqrt(x * x + y * y) + 0.5)
end
local function dernierMessage()
    return __sansCouleur(__sorties[#__sorties] or "")
end

__declencher("PLAYER_LOGIN")

local R = LCM.UI.Radial
local f = R.frame

dire("== le sceau est affiche en permanence")
attendu("le sceau existe", f ~= nil, true)
attendu("il est visible", f:IsShown(), true)
attendu("la couronne est repliee", f.orbite:IsShown(), false)

dire("== la structure est figee")
attendu("cinq categories declarees", #R.STRUCTURE, 5)
local attendus = {
    personnage = 5, inventaire = 5, grimoire = 2, deplacement = 0, outil = 4,
}
for _, categorie in ipairs(R.STRUCTURE) do
    local voulu = attendus[categorie.id]
    attendu("  " .. categorie.id, #(categorie.entrees or {}), voulu)
end
attendu("Deplacement ouvre directement", R.Trouver("deplacement").direct, true)
attendu("Outil est reserve au MJ", R.Trouver("outil").mjSeulement, true)

dire("== une entree inconnue est refusee")
attendu("liaison refusee", R.Lier("inventaire_secret", function() end), false)
attendu("le refus est dit", dernierMessage():find("inconnue") ~= nil, true)

dire("== le MJ voit une categorie de plus")
attendu("avec le compagnon MJ", #R.Categories(), 5)
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
attendu("sans le compagnon", #R.Categories(), 4)
attendu("Outil masque", #R.Entrees("outil"), 0)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== clic gauche : la couronne se deploie")
f.sceau:Click("LeftButton")
attendu("couronne ouverte", f.orbite:IsShown(), true)
attendu("categories dessinees", f.nombreCategories, 5)
-- Au depart de l'animation, tout est encore au centre.
attendu("depart au centre", rayon(f.boutonsCategorie[1]), 0)
__avancer(1)
local memeRayon, libelles = true, {}
for i = 1, f.nombreCategories do
    local b = f.boutonsCategorie[i]
    if rayon(b) ~= R.RAYON_CATEGORIE then memeRayon = false end
    libelles[#libelles + 1] = b.legende:GetText()
end
attendu("toutes sur le cercle (" .. R.RAYON_CATEGORIE .. ")", memeRayon, true)
dire("   couronne : " .. table.concat(libelles, " | "))

dire("== clic sur une categorie : l'eventail s'ouvre")
f.boutonsCategorie[1]:Click("LeftButton")
__avancer(1)
attendu("categorie retenue", f.choisi, "personnage")
attendu("cinq entrees", f.nombreEntrees, 5)
local memeRayonAction, entrees = true, {}
for i = 1, f.nombreEntrees do
    local b = f.boutonsEntree[i]
    if rayon(b) ~= R.RAYON_ACTION then memeRayonAction = false end
    entrees[#entrees + 1] = b.legende:GetText()
end
attendu("toutes sur l'arc (" .. R.RAYON_ACTION .. ")", memeRayonAction, true)
dire("   eventail : " .. table.concat(entrees, " | "))
attendu("dessin d'eventail a 5 branches",
    tostring(f.secteur.surface.__texture):find("fan%-5%.tga") ~= nil, true)

dire("== une entree sans fenetre le dit, sans rien casser")
local avant = #__sorties
f.boutonsEntree[2]:Click("LeftButton") -- Equipement
attendu("prevenu", dernierMessage():find("pas encore disponible") ~= nil, true)
attendu("la couronne reste ouverte", f.orbite:IsShown(), true)
attendu("aucune fenetre ouverte", #__sorties, avant + 1)

dire("== l'entree Fiche ouvre la fiche et referme le menu")
f.boutonsEntree[1]:Click("LeftButton")
attendu("fiche ouverte", LCM.UI.Fiche.frame:IsShown(), true)
attendu("fermeture engagee", f.ouvert, false)
__avancer(1)
attendu("couronne repliee", f.orbite:IsShown(), false)
LCM.UI.Fiche.frame:Hide()

dire("== Deplacement s'ouvre sans passer par un eventail")
f.sceau:Click("LeftButton")
__avancer(1)
local deplacement
for i = 1, f.nombreCategories do
    if f.boutonsCategorie[i].cible.id == "deplacement" then deplacement = f.boutonsCategorie[i] end
end
attendu("la categorie est la", deplacement ~= nil, true)
deplacement:Click("LeftButton")
attendu("rien a deployer, on previent", dernierMessage():find("pas encore disponible") ~= nil, true)
attendu("aucun eventail", f.nombreEntrees, 0)

dire("== clic droit : la selection du personnage")
f.sceau:Click("RightButton")
attendu("fenetre ouverte", LCM.UI.Personnages.frame:IsShown(), true)
__avancer(1)
attendu("le menu s'est referme", f.orbite:IsShown(), false)
LCM.UI.Personnages.frame:Hide()

dire("== le sceau se cache et revient")
SlashCmdList.LCM("sceau")
attendu("cache", f:IsShown(), false)
SlashCmdList.LCM("sceau")
attendu("revenu", f:IsShown(), true)

dire("== la documentation")
SlashCmdList.LCM("doc")
local d = LCM.UI.Document.frame
attendu("la fenetre existe", d ~= nil, true)
attendu("elle est ouverte", d:IsShown(), true)
attendu("deux documents", #d.documents, 2)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
