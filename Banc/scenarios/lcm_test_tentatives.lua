-- Les TENTATIVES d'une ressource (le MJ, 3 novembre 2026). Vide : on retente
-- sans fin. Avec N : au N-ieme rate, la ressource se DESACTIVE sur le point
-- de recolte (sa ligne s'eteint, le MJ peut la rallumer) — elle ne se detruit
-- pas, et le compendium n'y perd rien.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Des ressources temoins : le contenu de la campagne bouge.
LCM.Brouillons.Set("ressources", { id = "gemme_tent", label = "Gemme témoin", dd = 20, tentatives = 2 })
LCM.Brouillons.Set("ressources", { id = "fer_tent", label = "Fer témoin", dd = 5 })
__declencher("PLAYER_LOGIN")
__personnage()
local R, MJ = LCM.Recolte, LCM.Recoltes
local GEMME, FER = "ressources/gemme_tent", "ressources/fer_tent"

dire("== le registre")
attendu("la Gemme a 2 tentatives", LCM.Ressources.Get("gemme_tent").tentatives, 2)
attendu("le Fer, sans limite", LCM.Ressources.Get("fer_tent").tentatives, nil)
attendu("0 tentative est refusé", (pcall(LCM.Ressources.Construire, { id = "x", label = "X", tentatives = 0 })), false)

dire("== les ratées d'un jet")
local def = { ressources = { { entree = GEMME, chance = 100 }, { entree = FER, chance = 100 } } }
local ratees = R.Ratees({}, def, { total = 10 })
attendu("10 rate la Gemme (DD 20), pas le Fer", table.concat(ratees, ","), GEMME)
attendu("25 ne rate rien", #R.Ratees({}, def, { total = 25 }), 0)
attendu("le Fer raté ne compte pas (sans limite)", #R.Ratees({}, { ressources = { { entree = FER } } }, { total = 1 }), 0)

dire("== sur un point posé : la ligne s'éteint au dernier raté")
local f = LCM.UI.Recoltes.Fenetre()
f:Montrer()
f:Nouveau()
f.creation.nom:Saisir("Filon témoin")
f.travail.recolte.ressources = {
    { entree = GEMME, min = 1, max = 1, chance = 100, aleatoire = false, regeneration = false, minutes = 0 },
    { entree = FER, min = 1, max = 1, chance = 100, aleatoire = false, regeneration = false, minutes = 0 } }
f.travail.recolte.limite = 0
f:Remplir()
f.creation.enregistrer:Click()
local modele = f:Point()
f:Hide()
__position(100, 200, 0)
local id = MJ.Placer(modele.id)
MJ.Allumer(id)
attendu("deux lignes allumées", #MJ.Effectives(MJ.Pose(id), modele.recolte), 2)
MJ.Rater(id, { GEMME })
attendu("un raté : la Gemme reste", #MJ.Effectives(MJ.Pose(id), modele.recolte), 2)
attendu("  le compte est sur le point posé", MJ.Pose(id).ratees and MJ.Pose(id).ratees[GEMME], 1)
MJ.Rater(id, { GEMME })
local restantes = MJ.Effectives(MJ.Pose(id), modele.recolte)
attendu("deux ratés : la ligne s'éteint", #restantes == 1 and restantes[1].entree, FER)
attendu("  elle est désactivée, pas détruite", MJ.Pose(id).lignes[GEMME] and MJ.Pose(id).lignes[GEMME].actif, false)
attendu("  le modèle la garde", #MJ.Definition(modele.id).recolte.ressources, 2)
attendu("  le compendium aussi", LCM.Ressources.Get("gemme_tent") ~= nil, true)
attendu("  le compte repart de zéro", MJ.Pose(id).ratees, nil)

dire("== le jet du joueur compte ses ratées")
MJ.Allumer(id)
local vrai = LCM.Roll.Des
LCM.Roll.Des = function() return 8 end
R.dernierEssai = {}
R.Tenter(id)
LCM.Roll.Des = vrai
attendu("un jet à 8 : la Gemme a perdu un essai", MJ.Pose(id).ratees and MJ.Pose(id).ratees[GEMME], 1)

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
