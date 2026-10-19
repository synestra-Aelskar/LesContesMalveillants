-- S'eloigner ferme ce qu'on avait ouvert.
--
-- Les trois natures de point posees sur la carte — ressource, vendeur, coffre
-- (Core/Recolte.lua, Core/Marchands.lua, Core/Coffres.lua) — battent chacune
-- la mesure de la distance au quart de seconde. Le bouton de recolte
-- disparaissait, l'etal du vendeur se refermait, mais la FENETRE d'un coffre
-- restait ouverte : on regardait un contenu auquel le proprietaire refusait
-- desormais tout geste (le MJ, 20 octobre 2026).
--
-- Contenu TEMOIN : ressource, etal et coffre d'essai.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local HERBE = "ressources/herbe_temoin"
LCM.Brouillons.Set("ressources", { id = "herbe_temoin", label = "Herbe témoin" })
LCM.Brouillons.Set("sacs", { id = "sac_temoin", label = "Sac témoin", places = 12 })
LCM.Brouillons.Set("devises", { id = "piece_temoin", label = "Pièce témoin" })
LCM.Brouillons.Set("objets", { id = "babiole_temoin", label = "Babiole témoin",
    categorie = "accessoire", pileMax = 1 })
LCM.Brouillons.Set("points", {
    id = "filon_temoin", label = "Filon témoin", nature = "ressource",
    recolte = { entree = HERBE, dd = 0, rayon = 3,
        ressources = { { entree = HERBE, min = 1, max = 1 } } },
})
LCM.Brouillons.Set("points", {
    id = "etal_temoin", label = "Étal témoin", nature = "vendeur",
    deviseDefaut = "piece_temoin", rayon = 3,
    onglets = { { id = "o1", label = "Articles", offres = {
        { id = "herbe", entree = HERBE, quantite = 1, prix = 1, devise = "piece_temoin" },
    } } },
})
LCM.Brouillons.Set("points", {
    id = "coffre_temoin", label = "Coffre témoin", nature = "coffre",
    coffre = { places = 4, rayon = 3, verrous = 0, reset = false,
        objets = { { entree = "objets/babiole_temoin", quantite = 1 } },
        expertises = {}, outils = {} },
})

__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
LCM.Inventaire.Poser(moi, "sacs", 1, "sac_temoin", true)
local MOI = LCM.PlayerId()
__groupe({ MOI })
__declencher("GROUP_ROSTER_UPDATE")

local R, M, C = LCM.Recolte, LCM.Marchands, LCM.Coffres

-- Poser demande une position SERVEUR (le .gps, depuis le 17 octobre 2026). On
-- en joue une, comme le guetteur de chat le ferait.
local function GPS(x, y, z)
    LCM.DeplacementForce.NoterGPS(string.format(
        "Map: 585 (Magisters' Terrace) Zone: 0 ( <unknown> ), Area: 0 ( <unknown> ), "
        .. "Phase: 158070, X: %f, Y: %f, Z: %f, O: 1.904451", x, y, z))
end

dire("== trois points posés là où l'on se tient")
__position(100, 200, 0)
GPS(100, 200, 0)
attendu("un filon", LCM.Recoltes.Placer("filon_temoin") ~= nil, true)
attendu("un étal", LCM.MarchandsMJ.Placer("etal_temoin") ~= nil, true)
local coffreId = LCM.CoffresMJ.Placer("coffre_temoin")
attendu("un coffre", coffreId ~= nil, true)

dire("== devant eux : le bouton, l'étal, le coffre")
__avancer(0.3)
attendu("« Récolter » est là", LCM.UI.Recolte.bouton and LCM.UI.Recolte.bouton:IsShown(), true)
attendu("le coffre est à portée", C.Proche() ~= nil, true)
attendu("« Commercer » est là", LCM.UI.Marchand.bouton and LCM.UI.Marchand.bouton:IsShown(), true)
LCM.UI.Marchand.bouton:Click()
attendu("  l'étal est ouvert", LCM.UI.Marchand.frame:IsShown(), true)
local ok, raison = C.Ouvrir(coffreId)
attendu("le coffre s'ouvre", ok, true)
if not ok then dire("     raison du refus :", tostring(raison)) end
attendu("  sa fenêtre est là", LCM.UI.Coffre.frame:IsShown(), true)
attendu("  et c'est bien lui qu'on tient", C.courant, coffreId)
local pointMJ = LCM.CoffresMJ.Points("coffre_temoin")[1]
attendu("  le propriétaire le note ouvert", pointMJ and pointMJ.ouvert, true)

dire("== on s'éloigne : tout se referme")
__position(400, 600, 0)
GPS(400, 600, 0)
__avancer(0.3)
attendu("plus de bouton de récolte",
    not (LCM.UI.Recolte.bouton and LCM.UI.Recolte.bouton:IsShown()), true)
attendu("plus d'étal", LCM.UI.Marchand.frame:IsShown(), false)
-- Le gros du correctif : la fenetre du coffre restait ouverte.
attendu("plus de coffre", LCM.UI.Coffre.frame:IsShown(), false)
attendu("  et le bandeau « Ouvrir » a disparu",
    not (LCM.UI.Coffre.bouton and LCM.UI.Coffre.bouton:IsShown()), true)
-- Fermer previent le proprietaire, comme un clic sur la croix : son coffre
-- n'est plus marque « ouvert ». Il ne reste donc pas occupe par quelqu'un qui
-- est parti. (Ici le proprietaire, c'est nous : Coffres.Envoyer s'arbitre
-- soi-meme sans passer par le reseau.)
attendu("le propriétaire sait qu'on est parti", pointMJ.ouvert, false)

dire("== et un coffre qu'on a quitté ne s'ouvre plus")
local okLoin, raisonLoin = C.Ouvrir(coffreId)
attendu("refusé", okLoin, false)
attendu("  on dit la distance", tostring(raisonLoin):find("trop loin", 1, true) ~= nil, true)

dire("== on revient : tout revient")
__position(100, 200, 0)
GPS(100, 200, 0)
__avancer(0.3)
attendu("« Récolter » revient", LCM.UI.Recolte.bouton:IsShown(), true)
attendu("le coffre se rouvre", (C.Ouvrir(coffreId)), true)
attendu("  sa fenêtre est là", LCM.UI.Coffre.frame:IsShown(), true)

dire("== l'édition du MJ, elle, se mène à distance")
-- Un MJ edite le contenu d'un coffre qu'il a pose ailleurs : la regle des
-- actions l'autorise deja (Coffres.Agir), la fermeture automatique doit la
-- respecter.
LCM.UI.Coffre.frame:Hide()
attendu("ouvert en édition", (C.Ouvrir(coffreId, true)), true)
attendu("  la fenêtre est là", LCM.UI.Coffre.frame:IsShown(), true)
__position(400, 600, 0)
GPS(400, 600, 0)
__avancer(0.5)
attendu("elle reste ouverte de loin", LCM.UI.Coffre.frame:IsShown(), true)
LCM.UI.Coffre.frame:Hide()
attendu("et l'édition se referme à la main", C.edition, false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
