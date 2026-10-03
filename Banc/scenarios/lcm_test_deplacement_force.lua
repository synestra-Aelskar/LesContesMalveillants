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

dire("== l'anneau suit")
-- Depuis le 3 octobre 2026 la fenetre est celle de Necronicon : un anneau qui
-- se remplit, le chiffre au centre et la limite dessous.
local f = LCM.UI.DeplacementForce.frame
attendu("la distance au centre", f.anneau.valeur:GetText(), "1.0")
attendu("la limite dessous", f.anneau.sur:GetText(), "/ 6 m")
attendu("la ligne du round existe", f.round ~= nil, true)
attendu("le bouton de marqueur existe", f.marquer ~= nil, true)

dire("== arrivee")
__position(6, 0, 0)
DF.Mesurer()
attendu("plus rien en cours", DF.EnCours(), nil)
-- Pas forcement la DERNIERE ligne : l'arrivee envoie aussi les commandes
-- serveur, qui se plaignent quand on n'est ni en guilde ni en groupe.
local function dansLesSorties(motif, combien)
    for i = #__sorties, math.max(1, #__sorties - (combien or 4)), -1 do
        if __sansCouleur(__sorties[i]):find(motif) then return true end
    end
    return false
end
attendu("et on le dit", dansLesSorties("c'est fait"), true)
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

dire("== hors combat : aucune limite")
local moi = __personnage()
__position(0, 0, 0)
attendu("pas en combat", DF.EnCombat(), false)
for _ = 1, 4 do
    attendu("on repart toujours", select(1, DF.DemarrerMode("terrestre")), true)
    DF.Arreter("interrompu")
end
attendu("et toujours gratuitement", DF.Prochain(), "gratuit")
local f0 = LCM.UI.DeplacementForce.frame
f0:Montrer()
attendu("la ligne du round se tait", f0.round:IsShown(), false)
attendu("il n'y a plus de bouton « Nv round »", f0.nouveauRound, nil)
f0:Hide()

dire("== en combat : un gratuit, un paye, puis plus rien")
-- La regle ne vaut qu'en combat : c'est la que compter a un sens.
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true
__groupe({})
local garde = LCM.Incarnation.Instancier(LCM.PNJ.list[1].id, "Garde")
LCM.Combat.Inviter({ pnj = { garde.id } })
attendu("le combat est lance", DF.EnCombat(), true)
__position(0, 0, 0)
DF.NouveauRound()
attendu("le premier est gratuit", DF.Prochain(), "gratuit")
LCM.Entities.SetGauge(LCM.Entities.Self(), "pa", 5)
LCM.Entities.SetGauge(LCM.Entities.Self(), "fatigue", 5)
-- Les jauges sont plafonnees par la fiche (les PA s'arretent plus bas que 5) :
-- on compare donc des ECARTS, pas des valeurs qu'on ne choisit pas.
local function reserve()
    -- Celui qui est joue maintenant : en combat, le MJ incarne le PNJ dont
    -- c'est le tour, et c'est lui qui paie.
    local acteur = LCM.Entities.Self()
    return LCM.Entities.Gauge(acteur, "pa").current,
           LCM.Entities.Gauge(acteur, "fatigue").current
end
local pa0, pf0 = reserve()
attendu("il part", select(1, DF.DemarrerMode("terrestre")), true)
local pa1, pf1 = reserve()
attendu("sans rien coûter", (pa0 - pa1) .. "/" .. (pf0 - pf1), "0/0")
DF.Arreter("interrompu")
attendu("le second se paie", DF.Prochain(), "payant")
attendu("il part aussi", select(1, DF.DemarrerMode("terrestre")), true)
local pa2, pf2 = reserve()
attendu("1 PA de moins", pa1 - pa2, 1)
attendu("1 PF de moins", pf1 - pf2, 1)
DF.Arreter("interrompu")
attendu("et c'est tout", DF.Prochain(), "fini")
local ok3, raison3 = DF.DemarrerMode("terrestre")
attendu("le troisieme est refuse", ok3, false)
attendu("en disant pourquoi", tostring(raison3):find("plus de déplacement") ~= nil, true)
-- Et c'est le combat qui le rend, pas un bouton : quand l'initiative revient
-- sur nous, les deplacements repartent a zero (demande du 3 octobre 2026).
attendu("plus rien avant notre tour", DF.Prochain(), "fini")
-- On avance jusqu'a retrouver la main (quelques tours au plus).
for _ = 1, 8 do
    if LCM.Combat.Courant() and LCM.Combat.Courant().id == LCM.PlayerId() then break end
    LCM.Combat.Avancer(1)
end
attendu("l'initiative nous est revenue", LCM.Combat.Courant().id, LCM.PlayerId())
attendu("et le deplacement est rendu", DF.Mouvements(), 0)
attendu("donc de nouveau gratuit", DF.Prochain(), "gratuit")

DF.NouveauRound()
attendu("le round suivant rend le gratuit", DF.Prochain(), "gratuit")

dire("== on ne part pas a credit")
LCM.Entities.SetGauge(LCM.Entities.Self(), "pa", 0)
DF.DemarrerMode("terrestre")
DF.Arreter("interrompu")
local _, pfAvant = reserve()
local ok4, raison4 = DF.DemarrerMode("terrestre")
attendu("sans PA, le supplementaire est refuse", ok4, false)
attendu("et on dit qu'il faut des PA", tostring(raison4):find("PA") ~= nil, true)
-- Le refus doit etre complet : rien ne se preleve sur un depart qui n'a pas eu
-- lieu. C'est pour ca que les deux jauges sont verifiees AVANT de debiter.
attendu("la fatigue n'a pas ete prelevee pour rien", select(2, reserve()), pfAvant)
DF.NouveauRound()

dire("== la position : UnitPosition refuse, la carte repond")
-- Sur nos cartes de campagne, le client rend nil : c'est la ou Necronicon
-- s'arretait sur « Position du personnage indisponible ».
__positionMonde(false)
__carte(1, 1000, 1000)
__position(0, 0, 0)
attendu("la course demarre quand meme", DF.Demarrer(6, "Répulsion"), true)
attendu("par la carte", DF.EnCours().source, "carte")
__position(4, 0, 0)
DF.Mesurer()
attendu("et elle mesure", math.floor(select(1, DF.Etat()) + 0.5), 4)
DF.Arreter("interrompu")

dire("== une carte muette : la on ne peut vraiment rien mesurer")
__carte(nil)
local ok5, raison5 = DF.Demarrer(6, "Répulsion")
attendu("refus", ok5, false)
attendu("et on nomme les deux sources", tostring(raison5):find("carte") ~= nil, true)
__positionMonde(true)
__carte(1, 1000, 1000)

dire("== le marqueur d'emplacement")
__groupe({ "Nytherah" })
attendu("pose au depart ? non", DF.Marqueur(), false)
DF.BasculerMarqueur()
attendu("pose", DF.Marqueur(), true)
attendu("la commande part", dansLesSorties("aura", 6) or #__chats > 0, true)
local f2 = LCM.UI.DeplacementForce.frame
f2:Actualiser()
attendu("le bouton le dit", f2.marquer.label:GetText(), "Retirer l'emplacement")
DF.BasculerMarqueur()
attendu("retire", DF.Marqueur(), false)
f2:Actualiser()
attendu("le bouton le redit", f2.marquer.label:GetText(), "Marquer l'emplacement")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
