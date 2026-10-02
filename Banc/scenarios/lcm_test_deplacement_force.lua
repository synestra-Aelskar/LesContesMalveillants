-- Le deplacement force : la jauge qui compte les metres d'une poussee.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local DF = LCM.DeplacementForce

dire("== on ne pousse pas de zero metre")
__position(0, 0, 0)
attendu("distance nulle : refus", DF.Demarrer(0, "Repulsion"), false)
attendu("rien en cours", DF.EnCours(), nil)

dire("== une poussee de 6 m")
attendu("demarre", DF.Demarrer(6, "Répulsion"), true)
attendu("la fenetre s'ouvre toute seule", LCM.UI.DeplacementForce.frame:IsShown(), true)
local d, limite, enCours = DF.Etat()
attendu("rien de parcouru", d, 0)
attendu("six metres a faire", limite, 6)
attendu("en cours", enCours, true)

dire("== la distance se compte depuis le DEPART, pas le chemin")
-- Aller a 4 m, revenir a 1 m : on est a 1 m du depart, pas a 7.
__position(4, 0, 0)
DF.Mesurer()
attendu("a quatre metres", select(1, DF.Etat()), 4)
__position(1, 0, 0)
DF.Mesurer()
attendu("revenu pres du depart", select(1, DF.Etat()), 1)
attendu("et ca compte toujours", DF.EnCours() ~= nil, true)

dire("== le relief ne compte pas")
-- Monter de moins d'une unite ne doit rien ajouter.
__position(1, 0, 0.9)
DF.Mesurer()
attendu("une marche n'avance a rien", select(1, DF.Etat()), 1)

dire("== la jauge suit")
local f = LCM.UI.DeplacementForce.frame
attendu("le compteur", f.compteur:GetText(), "1.0 / 6.0 m")
attendu("la raison est dite", f.raison:GetText(), "Répulsion")

dire("== arrivee")
__position(6, 0, 0)
DF.Mesurer()
attendu("plus rien en cours", DF.EnCours(), nil)
attendu("et on le dit", __sansCouleur(__sorties[#__sorties]):find("c'est fait") ~= nil, true)
attendu("la fenetre se retire", f:IsShown(), false)

dire("== fermer la fenetre interrompt la course")
DF.Demarrer(10, "Attraction")
attendu("repartie", DF.EnCours() ~= nil, true)
f:Hide()
attendu("fermee : la course s'arrete", DF.EnCours(), nil)
attendu("et c'est annonce comme une interruption",
    __sansCouleur(__sorties[#__sorties]):find("interrompu") ~= nil, true)

dire("== une poussee en remplace une autre")
__position(0, 0, 0)
DF.Demarrer(5, "Première")
__position(3, 0, 0)
DF.Mesurer()
DF.Demarrer(8, "Seconde")
local d2, l2 = DF.Etat()
attendu("la seconde repart de zero", d2, 0)
attendu("avec sa propre distance", l2, 8)
attendu("et sa propre raison", DF.EnCours().raison, "Seconde")
DF.Arreter("interrompu")

dire("== la commande d'essai")
SlashCmdList.LCM("pousse 12")
attendu("elle lance une course", select(2, DF.Etat()), 12)
DF.Arreter("interrompu")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
