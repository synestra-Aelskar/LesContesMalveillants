-- Les coffres poses survivent a un /reload et retrouvent leurs boutons.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local REF = "objets/contenu_reprise_coffre"
LCM.Objets.Add({ id = "contenu_reprise_coffre", label = "Contenu témoin",
    categorie = "accessoire", icone = "inv_misc_key_01", pileMax = 1 })
LCM.Brouillons.Set("points", {
    id = "coffre_reprise", label = "Coffre de reprise", nature = "coffre",
    coffre = { places = 4, rayon = 4, verrous = 0, reset = false,
        objets = { { entree = REF, quantite = 1 } }, expertises = {}, outils = {} },
})
LCM.EnsureDatabase()
local carte = LCM.Recolte.Carte()
LCM.db.coffresMJ = {
    coffre_avant_1 = { id = "coffre_avant_1", def = "coffre_reprise",
        x = 10, y = 20, source = "monde", carte = carte, quand = 1,
        objets = { { entree = REF, quantite = 1 } }, verrousRestants = 0,
        verrouille = false, ouvert = true, verrousOuverts = {} },
    coffre_avant_2 = { id = "coffre_avant_2", def = "coffre_reprise",
        x = 30, y = 40, source = "monde", carte = carte, quand = 2,
        objets = { { entree = REF, quantite = 1 } }, verrousRestants = 0,
        verrouille = false, ouvert = true, verrousOuverts = {} },
}

attendu("avant la connexion, la définition n'est pas chargée",
    LCM.Points.Get("coffre_reprise"), nil)

__declencher("PLAYER_LOGIN")
__personnage()

dire("== les placements sont republies apres le rechargement")
attendu("la définition est rechargée", LCM.Points.Get("coffre_reprise") ~= nil, true)
attendu("les deux coffres restent dans le magasin MJ", #LCM.CoffresMJ.Points("coffre_reprise"), 2)
attendu("le premier coffre est restauré côté joueur", LCM.Coffres.points.coffre_avant_1 ~= nil, true)
attendu("le second coffre est restauré côté joueur", LCM.Coffres.points.coffre_avant_2 ~= nil, true)

dire("== chacun retrouve son bouton a proximite")
__position(11, 20, 0)
__avancer(0.3)
local bouton = LCM.UI.Coffre.bouton
attendu("le bouton du premier coffre apparaît", bouton and bouton:IsShown(), true)
attendu("il cible le premier placement", bouton and bouton.pointId, "coffre_avant_1")
__position(30, 41, 0)
__avancer(0.3)
attendu("le bouton reste affiché près du second", bouton and bouton:IsShown(), true)
attendu("il cible le second placement", bouton and bouton.pointId, "coffre_avant_2")

if ko > 0 then error(tostring(ko) .. " vérification(s) en échec") end
dire("TOUT PASSE")
