-- Le DD et les metiers sur la RESSOURCE (le MJ, 3 novembre 2026). Ils
-- vivaient sur le point de recolte, ligne de metier par ligne ; ils sont
-- maintenant au compendium, dans la forge des ressources. Un seul jet par
-- tentative, et chaque ressource du point se compare a SON DD : on garde
-- celles qu'on bat (« un jet par ressource », choix du MJ).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local R, D, M = LCM.Recolte, LCM.Difficultes, LCM.Metiers
local moi = LCM.Entities.Self()

dire("== le registre garde le DD et les métiers")
-- Des ressources temoins : le contenu de la campagne bouge a chaque seance.
local fer = LCM.Ressources.Add({ id = "fer_dd_temoin", label = "Fer témoin", dd = 8, metiers = { "mineur" } })
LCM.Ressources.Add({ id = "gemme_dd_temoin", label = "Gemme témoin", dd = 20 })
LCM.Ressources.Add({ id = "herbe_dd_temoin", label = "Herbe témoin" })
attendu("le DD est gardé", fer.dd, 8)
attendu("les métiers aussi", fer.metiers and fer.metiers[1], "mineur")
attendu("un DD négatif est refusé", (pcall(LCM.Ressources.Construire, { id = "x", label = "X", dd = -3 })), false)
attendu("un DD à virgule est refusé", (pcall(LCM.Ressources.Construire, { id = "x", label = "X", dd = 2.5 })), false)
local FER, GEMME, HERBE = "ressources/fer_dd_temoin", "ressources/gemme_dd_temoin", "ressources/herbe_dd_temoin"

dire("== une ressource se compare à SON DD et à ses métiers")
attendu("mineur 10 contre le Fer DD 8 : oui", R.Accessible(FER, { total = 10, metier = "mineur" }), true)
attendu("mineur 7 contre le Fer DD 8 : non", R.Accessible(FER, { total = 7, metier = "mineur" }), false)
attendu("bûcheron 15 contre le Fer : pas son métier", R.Accessible(FER, { total = 15, metier = "bucheron" }), false)
attendu("sans métier contre le Fer : non", R.Accessible(FER, { total = 15 }), false)
attendu("la Gemme, ouverte à tous, DD 20 : bûcheron 20 oui", R.Accessible(GEMME, { total = 20, metier = "bucheron" }), true)
attendu("l'Herbe sans DD : l'ancien DD de la ligne vaut encore", R.Accessible(HERBE, { total = 5, dd = 6 }), false)
attendu("sans jet, tout passe", R.Accessible(GEMME, nil), true)

dire("== le tirage ne donne que ce qu'on bat")
local definition = { limite = 0, ressources = {
    { entree = FER, min = 1, max = 1, chance = 100 },
    { entree = GEMME, min = 1, max = 1, chance = 100 },
} }
local point = {}
local lots = R.Tirer(point, definition, 0, { total = 12, metier = "mineur" })
attendu("mineur 12 : le Fer seul", #lots == 1 and lots[1].entree, FER)
lots = R.Tirer(point, definition, 0, { total = 22, metier = "mineur" })
attendu("mineur 22 : le Fer et la Gemme", #lots, 2)
lots = R.Tirer(point, definition, 0, { total = 22, metier = "bucheron" })
attendu("bûcheron 22 : la Gemme seule", #lots == 1 and lots[1].entree, GEMME)
local fini = { limite = 1, ressources = { { entree = GEMME, min = 1, max = 1, chance = 100 } } }
local _, etat = R.Tirer({}, fini, 0, { total = 3 })
attendu("une ressource ratée n'est pas consommée", etat.consomme[1], nil)

dire("== le jet : réussi si au moins une ressource est battue")
M.Gagner(moi, "mineur", M.XPPourNiveau(1) - M.XP(moi, "mineur"))
local def = { metiers = { { id = "mineur", bonus = true, fatigue = 0 } }, ressources = definition.ressources }
local vrai = LCM.Roll.Des
LCM.Roll.Des = function() return 9 end
local r = R.Jet(moi, def, {})
attendu("9 + bonus bat le Fer : réussi", r and r.reussi, true)
LCM.Roll.Des = function() return 0 end
local bonus = M.Bonus(moi, "mineur")
r = R.Jet(moi, def, {})
attendu("0 + bonus ne bat rien : raté", r and r.reussi, bonus >= 8)
LCM.Roll.Des = vrai
attendu("un point dont les ressources exigent : il faut un jet",
    R.RessourcesExigent({}, { ressources = { { entree = FER } } }), true)
attendu("sans exigence : pas de jet", R.RessourcesExigent({}, { ressources = { { entree = HERBE } } }), false)

dire("== l'XP : chaque ressource avec son DD")
D.Definir(8, 1)    -- DD 8 : Rose
D.Definir(20, 3)   -- DD 20 : Bleu
LCM.Ressources.Retirer("fer_dd_temoin")
LCM.Ressources.Retirer("gemme_dd_temoin")
LCM.Ressources.Add({ id = "fer_dd_temoin", label = "Fer témoin", dd = 8, xpRecolte = 2 })
LCM.Ressources.Add({ id = "gemme_dd_temoin", label = "Gemme témoin", dd = 20, xpRecolte = 2 })
local c8 = D.CoefficientPour(moi, "mineur", 8)
local c20 = D.CoefficientPour(moi, "mineur", 20)
local xp = R.XPGagnee(moi, { metier = "mineur" }, { { entree = FER, quantite = 1 }, { entree = GEMME, quantite = 1 } })
attendu("Fer et Gemme : 2 × coef(DD 8) + 2 × coef(DD 20)", xp, math.floor(2 * c8 + 2 * c20 + 0.5))

dire("== la forge des ressources : Type · DD, puis Métiers · XP")
local FU = LCM.UI.Forge
LCM.Forge.Add({ id = "jeu_ressources_dd", label = "Jeu ressources DD", categorie = "ressources",
    raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FF8CB8" } }, champs = {} })
FU.Ouvrir("ressources")
local forge = FU.Fenetre()
FU.courant.jeuId, FU.courant.rareteId = "jeu_ressources_dd", "commun"
forge:Rafraichir()
attendu("le DD se montre", forge.ddRecolte:IsShown(), true)
attendu("  il part sans jet", forge.ddRecolte.label:GetText(), "Sans jet (DD 0)")
attendu("le bouton Métiers se montre", forge.metiersRecolte:IsShown(), true)
attendu("  il dit « tous » sans coche", forge.metiersRecolte.label:GetText(), "Tous les métiers du point")
-- Deux rangees depuis le 3 novembre 2026 : « Tentatives » s'est ajoutee
-- sous Métiers · XP de récolte.
attendu("le corps de la forge descend de deux rangées", forge.corpsDecale, 60)
-- Une grille propre (le MJ, 3 novembre 2026) : deux colonnes, controles au
-- meme bord gauche, colonne de droite calee au bord de la forge.
local function bord(cadre, i)
    local point, rel, relPoint, x = cadre:GetPoint(i or 1)
    return tostring(point) .. ">" .. tostring(relPoint) .. ":" .. tostring(x)
end
attendu("Type et Métiers commencent au même bord", bord(forge.type), bord(forge.metiersRecolte))
attendu("DD et XP commencent au même bord", bord(forge.ddRecolte), bord(forge.xpRecolte))
attendu("DD et XP finissent au même bord", bord(forge.ddRecolte, 2), bord(forge.xpRecolte, 2))
attendu("les libellés de gauche s'alignent", bord(forge.typeLibelle), bord(forge.metiersLibelle))
attendu("ceux de droite aussi", bord(forge.ddLibelle), bord(forge.xpLibelle))
forge.ddRecolte.choisir(20)
attendu("choisir un DD le pose", FU.courant.ddRecolte, 20)
attendu("la liste nomme le palier", (function()
    for _, o in ipairs(LCM.Difficultes.Options(nil, true)) do
        if o.id == 20 then return (o.label:find(D.Get(20).nom, 1, true)) ~= nil end
    end
end)(), true)
attendu("  le bouton aussi", forge.ddRecolte.label:GetText():find(D.Get(20).nom, 1, true) ~= nil, true)
forge.metiersRecolte:Click()
local popup = FU.choixMetiers
attendu("la fenêtre des métiers s'ouvre", popup and popup:IsShown(), true)
local caseMineur
for _, cse in ipairs(popup.cases) do
    if cse:IsShown() and cse.id == "mineur" then caseMineur = cse break end
end
attendu("  le mineur y est", caseMineur ~= nil, true)
attendu("  rangé sous une catégorie", popup.entetes[1] and popup.entetes[1]:IsShown(), true)
if caseMineur then caseMineur:Click() end
popup.valider:Click()
attendu("valider garde les coches", FU.courant.metiersRecolte and FU.courant.metiersRecolte[1], "mineur")
attendu("le bouton nomme le métier", forge.metiersRecolte.label:GetText(), M.Get("mineur").label)
forge.metiersRecolte:GetScript("OnEnter")(forge.metiersRecolte)
local bulle = LCM.UI.Infobulle and LCM.UI.Infobulle()
FU.courant.nom = "Fer forgé"
local definitionForge = FU.Definition()
attendu("la définition porte le DD", definitionForge and definitionForge.dd, 20)
attendu("  et les métiers", definitionForge and definitionForge.metiers and definitionForge.metiers[1], "mineur")
forge:Hide()
FU.Ouvrir("armes")
FU.Fenetre():Rafraichir()
attendu("ailleurs, pas de DD de récolte", FU.Fenetre().ddRecolte:IsShown(), false)
FU.Fenetre():Hide()

D.Retirer(8)
D.Retirer(20)
M.Gagner(moi, "mineur", -M.XP(moi, "mineur"))
LCM.Ressources.Retirer("fer_dd_temoin")
LCM.Ressources.Retirer("gemme_dd_temoin")
LCM.Ressources.Retirer("herbe_dd_temoin")
print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
