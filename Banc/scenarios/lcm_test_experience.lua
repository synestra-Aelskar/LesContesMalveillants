-- L'experience : le MJ la donne, le palier fait monter le niveau.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local X = LCM.Experience
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "niveau", 5)

dire("== au depart")
attendu("aucune experience", X.Total(moi), 0)
attendu("niveau de depart", X.NiveauPour(0), 5)
local p = X.Progression(moi)
attendu("le prochain palier", p.prochainNiveau, 6)
attendu("ce qu'il reste a gagner", p.reste, 100)

dire("== on ne donne pas n'importe quoi")
attendu("zero est refuse", X.Donner(moi, 0), nil)
attendu("un montant negatif aussi", X.Donner(moi, -50), nil)
attendu("rien n'a bouge", X.Total(moi), 0)

dire("== un gain qui ne fait pas monter")
local r = X.Donner(moi, 40, "la taverne")
attendu("compte", X.Total(moi), 40)
attendu("pas de palier", r.monte, false)
attendu("niveau inchange", LCM.Entities.Get_Value(moi, "niveau"), 5)
attendu("il reste 60 pour le 6", X.Progression(moi).reste, 60)

dire("== le palier franchi fait monter")
r = X.Donner(moi, 60, "le dragon")
attendu("cent au total", X.Total(moi), 100)
attendu("monte", r.monte, true)
attendu("niveau 6 sur la fiche", LCM.Entities.Get_Value(moi, "niveau"), 6)

dire("== plusieurs paliers d'un coup")
r = X.Donner(moi, 900)
attendu("mille au total", X.Total(moi), 1000)
attendu("du 6 au 9 d'un seul gain", r.avant .. " -> " .. r.apres, "6 -> 9")
attendu("la fiche suit", LCM.Entities.Get_Value(moi, "niveau"), 9)

dire("== au dernier palier connu, plus rien a viser")
X.Donner(moi, 5000)
local fin = X.Progression(moi)
attendu("niveau maximum", fin.niveau, 10)
attendu("aucun palier suivant", fin.prochainNiveau, nil)
attendu("et aucun reste a afficher", fin.reste, nil)

dire("== un niveau pose a la main au-dessus de l'XP ne redescend pas")
local pnj = LCM.Entities.Create("pnj_vieux", "Ancien", "npc")
LCM.Entities.Set_Value(pnj, "niveau", 20)
X.Donner(pnj, 100)
attendu("le MJ garde son PNJ de niveau 20", LCM.Entities.Get_Value(pnj, "niveau"), 20)
attendu("mais son experience est comptee", X.Total(pnj), 100)

dire("== le budget de creation suit le niveau")
-- C'est tout l'interet de monter : on a des points a repartir.
local C = LCM.Creation
local bas = C.Nouveau(5)
local haut = C.Nouveau(6)
attendu("plus de points de statistiques au 6",
    C.Budget(haut, "primaires").total > C.Budget(bas, "primaires").total, true)

dire("== seul le MJ envoie")
attendu("le compagnon est la", LCM.IsMaster(), true)
attendu("l'envoi part", (LCM.Experience.Envoyer("Nytherah-Apertus", 50, "scene")), true)
attendu("sans destinataire : refus", (LCM.Experience.Envoyer("", 50)), false)
attendu("montant nul : refus", (LCM.Experience.Envoyer("Nytherah-Apertus", 0)), false)

dire("== le Panel MJ donne l'experience")
__groupe({ "Nytherah-Apertus" })
local panneau = LCM.UI.PanneauMJ.Basculer()
panneau:Afficher()
local ligne = panneau.lignes[1]
attendu("une ligne par joueur", ligne ~= nil, true)
attendu("avec sa case d'XP", ligne.xp ~= nil, true)
-- Sans montant, on ne devine pas : on le dit.
ligne.donner:Click()
attendu("case vide : on reclame le montant",
    __sansCouleur(__sorties[#__sorties]):find("combien") ~= nil, true)
ligne.xp:Saisir("75")
panneau.raison:Saisir("fin de scene")
ligne.donner:Click()
attendu("l'envoi est annonce", __sansCouleur(__sorties[#__sorties]):find("75 XP") ~= nil, true)
attendu("et la case se vide pour le suivant", ligne.xp:GetText(), "")

dire("== ce qui arrive chez le joueur")
-- Le message parti du MJ, rejoue tel quel a l'arrivee.
local avantXp = X.Total(LCM.Entities.Self())
LCM.Reseau.Recevoir("Nytherah-Apertus", "1:1:1:xp|m=30;r=le pont")
attendu("l'experience est comptee", X.Total(LCM.Entities.Self()), avantXp + 30)
attendu("et on dit qui l'a donnee",
    __sansCouleur(__sorties[#__sorties - 0]):find("Nytherah") ~= nil
    or __sansCouleur(__sorties[#__sorties - 1]):find("Nytherah") ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
