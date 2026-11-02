-- L'XP de recolte (2 novembre 2026) : c'est la RESSOURCE qui porte l'XP
-- (« de l'argent, ca donne 3 XP »), multipliee par la grille couleur du metier
-- x couleur de la difficulte. Le metier qui gagne est celui du jet.
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

dire("== la ressource porte son XP")
-- Une ressource temoin : le contenu de la campagne bouge a chaque seance.
local argent = LCM.Ressources.Add({ id = "argent_xp_temoin", label = "Argent témoin", xpRecolte = 3 })
attendu("le registre garde l'XP de récolte", argent.xpRecolte, 3)
LCM.Ressources.Add({ id = "caillou_xp_temoin", label = "Caillou témoin" })
local ok = pcall(LCM.Ressources.Construire, { id = "faux_xp", label = "Faux", xpRecolte = -2 })
attendu("une XP négative est refusée", ok, false)
local lotArgent = { { entree = "ressources/argent_xp_temoin", quantite = 4 } }
attendu("l'XP compte par ressource, pas par unité", R.XPBase(lotArgent), 3)
attendu("deux ressources s'additionnent", R.XPBase({ lotArgent[1],
    { entree = "ressources/caillou_xp_temoin", quantite = 1 } }), 3)

dire("== × le coefficient de la grille")
D.Definir(10, 1)   -- DD 10, Rose
D.Definir(20, 3)   -- DD 20, Bleu
M.Gagner(moi, "mineur", M.XPPourNiveau(1) - M.XP(moi, "mineur"))
attendu("un mineur Rose", M.Palier(moi, "mineur").rangCouleur, 1)
attendu("Rose sur un filon Rose : 3 × 1", (R.XPGagnee(moi, { metier = "mineur", dd = 10 }, lotArgent)), 3)
attendu("Rose sur un filon Bleu : 3 × 2", (R.XPGagnee(moi, { metier = "mineur", dd = 20 }, lotArgent)), 6)
attendu("un DD hors liste compte x1", (R.XPGagnee(moi, { metier = "mineur", dd = 13 }, lotArgent)), 3)
attendu("sans métier au jet, personne ne gagne", (R.XPGagnee(moi, nil, lotArgent)), 0)

dire("== versée à la réception, au métier du jet")
local avant = M.XP(moi, "mineur")
R.jets["point_xp"] = { metier = "mineur", dd = 20 }
local recu = R.Recevoir("point_xp", lotArgent, nil, nil)
attendu("la récolte est reçue", recu, true)
attendu("le mineur gagne 6 XP", M.XP(moi, "mineur") - avant, 6)
attendu("le jet est oublié", R.jets["point_xp"], nil)
avant = M.XP(moi, "mineur")
R.Recevoir("point_xp", lotArgent, nil, nil)
attendu("une réception sans jet ne rapporte rien", M.XP(moi, "mineur") - avant, 0)

dire("== la forge d'entrées : le champ XP sur une ressource")
-- Demande du MJ (2 novembre 2026) : poser l'XP de recolte des la forge.
local FU = LCM.UI.Forge
LCM.Forge.Add({ id = "jeu_ressources_xp", label = "Jeu ressources XP", categorie = "ressources",
    raretes = { { id = "commun", label = "Commun", points = 10, couleur = "FF8CB8" } }, champs = {} })
FU.Ouvrir("ressources")
local forge = FU.Fenetre()
FU.courant.jeuId, FU.courant.rareteId = "jeu_ressources_xp", "commun"
forge:Rafraichir()
attendu("le champ XP se montre sur une ressource", forge.xpRecolte:IsShown(), true)
FU.courant.nom = "Fer témoin"
forge.xpRecolte:Saisir("4")
local def, raison = FU.Definition()
attendu("la définition porte l'XP " .. tostring(raison), def and def.xpRecolte, 4)
forge.xpRecolte:Saisir("-1")
attendu("une XP négative est refusée", (FU.Definition()), nil)
forge.xpRecolte:Saisir("")
def = FU.Definition()
attendu("vide : aucune XP", def and def.xpRecolte, nil)
attendu("  vide, la case dit « aucune »", forge.xpRecolte.indice:IsShown(), true)
attendu("le champ est calé à droite", select(1, forge.xpRecolte:GetPoint(1)), "TOPRIGHT")
forge:Hide()

dire("== « Modifier » une ressource ouvre la forge")
-- Il ouvrait encore l'ancien panneau a champs (le MJ, 2 novembre 2026).
LCM.Ressources.Add({ id = "or_xp_temoin", label = "Or témoin", xpRecolte = 5 })
local categorie = LCM.Compendium.Get("ressources")
LCM.CompendiumEditeur.Ouvrir(categorie, LCM.Ressources.Get("or_xp_temoin"))
attendu("la forge s'ouvre", FU.Fenetre():IsShown(), true)
attendu("  sur la ressource", FU.courant.nom, "Or témoin")
attendu("  avec son XP", FU.courant.xpRecolte, 5)
attendu("  la case montre 5, sans « aucune »", FU.Fenetre().xpRecolte:GetText() .. "/" .. tostring(FU.Fenetre().xpRecolte.indice:IsShown()), "5/false")
FU.Fenetre():Hide()
LCM.Ressources.Retirer("or_xp_temoin")

D.Retirer(10)
D.Retirer(20)
M.Gagner(moi, "mineur", -M.XP(moi, "mineur"))
LCM.Ressources.Retirer("argent_xp_temoin")
LCM.Ressources.Retirer("caillou_xp_temoin")
print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
