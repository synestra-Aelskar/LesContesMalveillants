-- L'echange entre deux joueurs : glisser un objet sur quelqu'un ouvre une
-- fenetre des deux cotes, chacun pose, chacun accepte, tout change de main.
--
-- Le banc ne joue qu'un cote : l'autre est simule en lui donnant ses messages
-- (Reseau.Recevoir) et en lisant ce qu'on lui envoie (__envois).

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local moi = LCM.Entities.Self()
local I = LCM.Inventaire
local E = LCM.Echange
local AUTRE = "Akriaxx"

-- Un sac et deux objets dedans.
I.Poser(moi, "sacs", 1, "gros_sac", true)
attendu("la dague est rangee",
    I.Ranger(moi, "sacs", 1, 1, "objets/dague_d_assassin_du_culte", 1), true)

-- Ce qu'on vient d'envoyer, par sujet.
local function envoye(sujet, depuis)
    for i = (depuis or 0) + 1, #__envois do
        local m = tostring(__envois[i].message or "")
        if m:find(sujet, 1, true) then return __envois[i] end
    end
end
-- Jouer un message venu de l'autre.
local numero = 0
local function recevoir(sujet, donnees)
    numero = numero + 1
    LCM.Reseau.Recevoir(AUTRE, string.format("%d:1:1:%s|%s", numero, sujet,
        LCM.Reseau.Encoder(donnees or {})))
end

dire("== proposer : on demande, et on attend une reponse")
local avant = #__envois
attendu("la proposition part", E.Proposer(AUTRE), true)
attendu("une demande est envoyee", envoye("ECH_DEMANDE", avant) ~= nil, true)
attendu("elle est adressee a la personne", envoye("ECH_DEMANDE", avant).cible, AUTRE)
-- Tant qu'il n'a pas repondu, la seance n'est pas ouverte : il n'a peut-etre
-- pas l'addon.
attendu("la seance attend", E.courant.ouverte, false)
attendu("la fenetre reste fermee",
    LCM.UI.Echange.frame ~= nil and LCM.UI.Echange.frame:IsShown() or false, false)

dire("== il repond : la fenetre s'ouvre des deux cotes")
recevoir("ECH_OUI", {})
attendu("la seance est ouverte", E.courant.ouverte, true)
attendu("la fenetre est la", LCM.UI.Echange.frame:IsShown(), true)
attendu("elle nomme la personne", LCM.UI.Echange.frame.sousTitre:GetText(), AUTRE)

dire("== poser un objet : il quitte le sac tout de suite")
-- On le prend dans le sac comme a la souris, puis on le lache dans sa colonne.
LCM.UI.Menu.Trouver("inventaires").onClick()
local f = LCM.UI.Inventaires.frame
f.cartes[1]:Click("LeftButton")
__souris.LeftButton = true
f.lignes[1]:GetScript("OnDragStart")(f.lignes[1])
attendu("un glissement est en cours", LCM.UI.Glisser.EnCours(), true)
local avantContenu = #__envois
LCM.UI.Echange.frame.mienne.cadre.__survol = true
__avancer(0.02, 0.02)
__souris.LeftButton = false
__avancer(0.02, 0.02)
LCM.UI.Echange.frame.mienne.cadre.__survol = nil

attendu("l'objet est dans mon offre", #E.courant.mien.objets, 1)
attendu("et c'est bien lui", E.courant.mien.objets[1].ref, "objets/dague_d_assassin_du_culte")
-- EN GAGE : il a quitte le sac. Promis deux fois, il n'existerait qu'une.
attendu("il a quitte le sac", I.Case(I.Emplacement(moi, "sacs", 1), 1), nil)
attendu("l'autre en est informe", envoye("ECH_CONTENU", avantContenu) ~= nil, true)

dire("== poser des pieces")
local devise = LCM.Bourse.Catalogue()[1]
attendu("une devise existe", devise ~= nil, true)
LCM.Bourse.Crediter(moi, devise.id, 50)
attendu("la bourse est garnie", LCM.Bourse.Solde(moi, devise.id), 50)
attendu("on pose dix pieces", E.Monnayer(devise.id, 10), true)
attendu("elles sortent de la bourse", LCM.Bourse.Solde(moi, devise.id), 40)
-- Corriger un montant ne debite PAS deux fois : seul l'ecart passe.
attendu("on corrige a quinze", E.Monnayer(devise.id, 15), true)
attendu("seul l'ecart est pris", LCM.Bourse.Solde(moi, devise.id), 35)
attendu("on ne peut pas poser plus que la bourse", E.Monnayer(devise.id, 999), false)

dire("== accepter : tout changement remet les accords a zero")
recevoir("ECH_CONTENU", { objets = { { ref = "ressources/eau", quantite = 2, nom = "Eau" } },
    devises = {} })
attendu("on voit ce qu'il pose", #E.courant.sien.objets, 1)
attendu("et il est affiche", LCM.UI.Echange.frame.sienne.lignes[1].nom:GetText(), "Eau  x2")
recevoir("ECH_ACCORD", { ok = true })
attendu("il a accepte", E.courant.sonAccord, true)
attendu("pas nous", E.courant.monAccord, false)
-- Il change d'avis sur le contenu : les deux accords tombent.
recevoir("ECH_CONTENU", { objets = { { ref = "ressources/eau", quantite = 3, nom = "Eau" } },
    devises = {} })
attendu("son accord est tombe", E.courant.sonAccord, false)

dire("== conclure")
recevoir("ECH_ACCORD", { ok = true })
local avantAccord = #__envois
attendu("on accepte a notre tour", E.Accepter(true), true)
attendu("notre accord part", envoye("ECH_ACCORD", avantAccord) ~= nil, true)
-- Les deux accords : l'echange se conclut tout seul.
attendu("l'echange est termine", E.courant, nil)
attendu("la fenetre s'est refermee", LCM.UI.Echange.frame:IsShown(), false)
local ou, index, case = I.Chercher(moi, "ressources/eau")
attendu("on a recu son eau", ou ~= nil, true)
attendu("avec sa quantite", I.Case(I.Emplacement(moi, ou, index), case).quantite, 3)
-- Ce qu'on avait pose est parti : il etait deja sorti du sac.
attendu("la dague n'est plus a nous", I.Chercher(moi, "objets/dague_d_assassin_du_culte"), nil)
attendu("et les pieces non plus", LCM.Bourse.Solde(moi, devise.id), 35)

dire("== annuler rend ce qu'on avait mis en gage")
-- L'eau recue s'est rangee dans la premiere case libre, c'est-a-dire celle-ci.
I.Vider(moi, "sacs", 1, 1)
attendu("la dague revient pour l'essai",
    I.Ranger(moi, "sacs", 1, 1, "objets/dague_d_assassin_du_culte", 1), true)
E.Proposer(AUTRE)
recevoir("ECH_OUI", {})
attendu("seance ouverte", E.courant.ouverte, true)
attendu("on pose la dague", E.Offrir({
    ref = "objets/dague_d_assassin_du_culte", quantite = 1, nom = "Dague",
    retirer = function() I.Vider(moi, "sacs", 1, 1) end,
    rendre = function() I.Ranger(moi, "sacs", 1, 1, "objets/dague_d_assassin_du_culte", 1) end,
}), true)
attendu("elle a quitte le sac", I.Case(I.Emplacement(moi, "sacs", 1), 1), nil)
attendu("on pose aussi des pieces", E.Monnayer(devise.id, 20), true)
attendu("la bourse descend", LCM.Bourse.Solde(moi, devise.id), 15)

E.Annuler("on se ravise")
attendu("plus d'echange", E.courant, nil)
attendu("la dague est revenue",
    I.Case(I.Emplacement(moi, "sacs", 1), 1).ref, "objets/dague_d_assassin_du_culte")
attendu("et les pieces aussi", LCM.Bourse.Solde(moi, devise.id), 35)

dire("== son depart annule l'echange, et rend le gage")
E.Proposer(AUTRE)
recevoir("ECH_OUI", {})
E.Offrir({ ref = "objets/dague_d_assassin_du_culte", quantite = 1, nom = "Dague",
    retirer = function() I.Vider(moi, "sacs", 1, 1) end,
    rendre = function() I.Ranger(moi, "sacs", 1, 1, "objets/dague_d_assassin_du_culte", 1) end })
attendu("en gage", I.Case(I.Emplacement(moi, "sacs", 1), 1), nil)
recevoir("ECH_FIN", { raison = "il ferme" })
attendu("l'echange est clos", E.courant, nil)
attendu("le gage est rendu",
    I.Case(I.Emplacement(moi, "sacs", 1), 1).ref, "objets/dague_d_assassin_du_culte")

dire("== on n'echange pas avec deux personnes a la fois")
E.Proposer(AUTRE)
recevoir("ECH_OUI", {})
local ok, raison = E.Proposer("Quelquun")
attendu("une seconde proposition est refusee", ok, false)
attendu("et on dit pourquoi", type(raison), "string")
E.Annuler("fin des essais")

dire("== le royaume ne casse plus la séance")
-- On propose a « Yutosuu » (le nom qu'on cible) et la reponse revient de
-- « Yutosuu-Apertus » : WoW qualifie l'expediteur de son royaume. Les
-- receptions comparaient les deux chaines telles quelles — chez le demandeur
-- le « oui » etait ignore et l'on lisait « n'a pas l'addon » apres cinq
-- secondes ; chez l'invite la fenetre s'ouvrait et restait vide
-- (12 octobre 2026, sur un echange entre un MJ et un joueur).
if E.courant then E.Annuler() end
if LCM.UI.Echange.frame then LCM.UI.Echange.frame:Hide() end
local COURT, LONG = "Yutosuu", "Yutosuu-Apertus"
attendu("on propose au nom court", E.Proposer(COURT), true)
attendu("  la seance attend encore", E.courant.ouverte, false)
-- La reponse arrive du nom QUALIFIE.
numero = numero + 1
LCM.Reseau.Recevoir(LONG, string.format("%d:1:1:ECH_OUI|%s", numero, LCM.Reseau.Encoder({})))
attendu("le oui est reconnu quand meme", E.courant and E.courant.ouverte, true)
attendu("  et la seance adopte l'ecriture de l'expediteur", E.courant.qui, LONG)
-- Et la suite du dialogue passe : un contenu recu du nom long est pris.
numero = numero + 1
LCM.Reseau.Recevoir(LONG, string.format("%d:1:1:ECH_CONTENU|%s", numero,
    LCM.Reseau.Encoder({ objets = { { ref = "ressources/eau", quantite = 1, nom = "Eau" } }, devises = {} })))
attendu("ce qu'il pose arrive", #E.courant.sien.objets, 1)
E.Annuler()

dire("== la place est verifiee avec les vraies regles de rangement")
-- Le joueur ne connait pas forcement un objet cree par le MJ. L'accord doit
-- etre refuse avant de conclure, avec la vraie raison au lieu de « sac plein ».
E.Proposer(AUTRE)
recevoir("ECH_OUI", {})
recevoir("ECH_CONTENU", { objets = { { ref = "objets/inconnu_du_joueur", quantite = 1,
    nom = "Objet du MJ" } }, devises = {} })
local place, raisonPlace = E.Place()
attendu("objet inconnu refuse avant accord", place, false)
attendu("raison precise", raisonPlace:find("entrée inconnue", 1, true) ~= nil, true)
attendu("aucun accord envoye", E.Accepter(true), false)
attendu("la seance reste ouverte", E.courant ~= nil, true)
E.Annuler()

dire("== une entree MJ inconnue arrive avec sa definition")
local objetPartage = {
    id = "armure_partagee_test", label = "Armure partagée", categorie = "equipement",
    icone = "inv_chest_cloth_17", description = "Objet transmis pendant l'échange.",
    etat = { courant = 10, max = 10 }, armure = 2, bonus = { force = 1 },
}
E.Proposer(AUTRE)
recevoir("ECH_OUI", {})
recevoir("ECH_CONTENU", { objets = { { ref = "objets/armure_partagee_test",
    quantite = 1, nom = objetPartage.label, definition = objetPartage } }, devises = {} })
attendu("la definition inconnue est importee", LCM.Objets.Get("armure_partagee_test") ~= nil, true)
attendu("l'objet peut etre range", E.Place(), true)
attendu("il reste dans le compendium local", LCM.db.objetsRecus.armure_partagee_test.label, "Armure partagée")
recevoir("ECH_ACCORD", { ok = true })
attendu("on accepte la reception", E.Accepter(true), true)
attendu("l'objet est bien recu", I.Chercher(moi, "objets/armure_partagee_test") ~= nil, true)
attendu("ses caracteristiques sont disponibles", LCM.Objets.Get("armure_partagee_test").armure, 2)
LCM.Objets.Retirer("armure_partagee_test")
E.ChargerObjetsRecus()
attendu("l'objet reste connu apres rechargement", LCM.Objets.Get("armure_partagee_test").label, "Armure partagée")

dire("== une definition partagee remplace la version locale perimee")
local ancienne = {
    id = "objet_revision_test", label = "Ancienne version", categorie = "arme",
    icone = "inv_sword_01", etat = { courant = 10, max = 10 },
}
LCM.Objets.Add(ancienne)
local nouvelle = {
    id = "objet_revision_test", label = "Bâton forestier révisé", categorie = "arme",
    icone = "inv_staff_01", etat = { courant = 20, max = 20 }, bonus = { force = 3 },
}
E.Proposer(AUTRE)
recevoir("ECH_OUI", {})
recevoir("ECH_CONTENU", { objets = { { ref = "objets/objet_revision_test",
    quantite = 1, nom = nouvelle.label, definition = nouvelle } }, devises = {} })
attendu("la version locale est remplacée", LCM.Objets.Get("objet_revision_test").label, nouvelle.label)
attendu("la nouvelle statistique est reçue", LCM.Objets.Get("objet_revision_test").etat.max, 20)
attendu("la révision est conservée", LCM.db.objetsRecus.objet_revision_test.label, nouvelle.label)
LCM.Objets.Retirer("objet_revision_test")
E.ChargerObjetsRecus()
attendu("la révision survit au rechargement", LCM.Objets.Get("objet_revision_test").label, nouvelle.label)
E.Annuler()

-- Une tente a des cases libres, mais n'accepte aucun objet ordinaire.
local inventaireAvant = moi.inventaire
moi.inventaire = { ceintures = { [1] = { ceinture = true, cases = {
    [1] = { ref = "ressources/eau", quantite = 1 },
    [2] = { ref = "ressources/eau", quantite = 1 },
    [3] = { ref = "ressources/eau", quantite = 1 },
} } }, saccoches = { [1] = { tente = "auberge_de_tephris" } } }
E.Proposer(AUTRE)
recevoir("ECH_OUI", {})
recevoir("ECH_CONTENU", { objets = { { ref = "objets/dague_d_assassin_du_culte",
    quantite = 1, nom = "Dague" } }, devises = {} })
place, raisonPlace = E.Place()
attendu("les cases de tente ne comptent pas pour une dague", place, false)
attendu("raison du rangement conservee", raisonPlace:find("aucune place libre", 1, true) ~= nil, true)
E.Annuler()
moi.inventaire = inventaireAvant

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
