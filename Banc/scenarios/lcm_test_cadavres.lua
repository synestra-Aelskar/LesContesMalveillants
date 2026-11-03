-- Les CADAVRES (le MJ, 3 novembre 2026). Un PNJ a son butin (onglet Loot de
-- sa creation : Sacs, Ressource naturelle, Ventre) ; tombe a 0 PV en combat,
-- son nom passe au rouge et « Mort » pose son cadavre a la position du MJ.
-- On le fouille : Équipé et Sac d'un clic, Naturel et Ventre par un jet
-- d'extraction contre le DD de la ressource, avec ses tentatives. Un seul
-- joueur a la fois ; a la fin, l'etat part a tous.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Du contenu temoin : le contenu de la campagne bouge a chaque seance.
LCM.Brouillons.Set("ressources", { id = "peau_cad", label = "Peau témoin", dd = 12, tentatives = 2 })
LCM.Brouillons.Set("ressources", { id = "croc_cad", label = "Croc témoin", dd = 5 })
LCM.Brouillons.Set("ressources", { id = "piece_cad", label = "Pièce témoin" })
__groupe({ "Joueur-Apertus", "Autre-Apertus" })
__declencher("PLAYER_LOGIN")
__personnage()
local C, M = LCM.Cadavres, LCM.CadavresMJ
local moi = LCM.Entities.Self()
LCM.Creation.MarquerAJour(moi)
LCM.Objets.Add({ id = "epee_cad", label = "Épée témoin", categorie = "arme", type = "epee_cad_type",
    etat = { courant = 10, max = 10 } })
local PEAU, CROC, PIECE = "ressources/peau_cad", "ressources/croc_cad", "ressources/piece_cad"

dire("== le butin du PNJ")
local loup = LCM.PNJ.Add({ id = "loup_cad", label = "Loup témoin", valeurs = {},
    equipement = { arme = { "epee_cad" } },
    loot = { sacs = { { entree = PIECE, quantite = 3 } },
             naturel = { { entree = PEAU, quantite = 1 } },
             ventre = { { entree = CROC, quantite = 1 } } } })
attendu("le PNJ garde son butin", loup.loot and loup.loot.sacs[1].quantite, 3)
attendu("une quantité nulle est refusée", (pcall(LCM.PNJ.Construire, { id = "x", label = "X",
    loot = { sacs = { { entree = PIECE, quantite = 0 } } } })), false)

dire("== l'onglet Loot de la création")
local brouillon = LCM.Creation.NouveauPNJ()
LCM.Creation.LootPourEcrire(brouillon).naturel = { { entree = PEAU, quantite = "2" } }
local f = LCM.UI.Creation.OuvrirPNJ(function() return true end, brouillon)
local fen = f or LCM.UI.Creation.frame
local avecLoot = false
for _, e in ipairs(fen:EtapesDisponibles()) do if e.id == "loot" then avecLoot = true end end
attendu("un PNJ a l'onglet Loot", avecLoot, true)
fen:Afficher("loot")
local bloc = fen.pages.loot and fen.pages.loot.sections.naturel
attendu("  la section Naturel montre sa ligne", bloc and bloc.lignes[1] and bloc.lignes[1]:IsShown(), true)
fen:Hide()
attendu("la définition porte le butin, en entiers", LCM.Creation.LootPropre(brouillon.loot).naturel[1].quantite, 2)
local joueur = LCM.Creation.Nouveau()
LCM.UI.Creation.Ouvrir(joueur)
local sansLoot = true
for _, e in ipairs(LCM.UI.Creation.frame:EtapesDisponibles()) do if e.id == "loot" then sansLoot = false end end
attendu("un joueur n'a pas l'onglet Loot", sansLoot, true)
LCM.UI.Creation.frame:Hide()

dire("== la mort : le cadavre à la position du MJ")
local instance = LCM.Incarnation.Instancier("loup_cad")
__position(100, 200, 0)
local id = M.Mort(instance.id)
attendu("le cadavre apparaît", id ~= nil, true)
local c = M.Get(id)
attendu("  à la position du MJ", c and (c.x .. "," .. c.y), "100,200")
local parSection = {}
for _, lot in ipairs(c.lots) do parSection[lot.section] = (parSection[lot.section] or 0) + 1 end
attendu("  Équipé, Sac, Naturel et Ventre", (parSection.equipe or 0) .. (parSection.sacs or 0)
    .. (parSection.naturel or 0) .. (parSection.ventre or 0), "1111")
attendu("  l'épée vient de son équipement", C.Lots(C.connus[id], "equipe")[1].entree, "objets/epee_cad")
attendu("une seconde mort ne double pas le cadavre", (M.Mort(instance.id)), nil)
local fenetre = LCM.UI.Cadavre.Ouvrir(id)
attendu("la fenêtre montre les quatre sections", (function()
    local n = 0
    for _, t in ipairs(fenetre.entetes) do if t:IsShown() then n = n + 1 end end
    return n
end)(), 4)
fenetre:Hide()

dire("== le MJ corrige : ce qui est désactivé ne part pas aux joueurs")
local pieces = C.Lots(C.connus[id], "sacs")[1]
M.Basculer(id, pieces.id)
attendu("le paquet des joueurs n'a plus les pièces", (function()
    for _, l in ipairs(C.Paquet(c, false).l) do if l.e == PIECE then return false end end
    return true
end)(), true)
attendu("le MJ les voit encore", #C.Lots(C.connus[id], "sacs", true), 1)
M.Basculer(id, pieces.id)
M.Quantite(id, pieces.id, 5)
attendu("la quantité se corrige", M.Get(id).lots[2].quantite, 5)

dire("== un seul à la fois")
local r = M.Traiter("Joueur-Apertus", { i = id, a = "ouvrir" })
attendu("le premier ouvre", r.ouvert, 1)
r = M.Traiter("Autre-Apertus", { i = id, a = "ouvrir" })
attendu("le second attend son tour", r.refus, "Joueur-Apertus fouille déjà ce cadavre : attends ton tour.")
r = M.Traiter("Autre-Apertus", { i = id, a = "prendre", l = pieces.id })
attendu("  et ne peut rien prendre", r.donne, nil)

dire("== prendre, extraire")
r = M.Traiter("Joueur-Apertus", { i = id, a = "prendre", l = pieces.id })
attendu("les pièces se prennent d'un clic", r.donne and r.donne.e .. " x" .. r.donne.q, PIECE .. " x5")
local peau = C.Lots(C.Lire(C.Paquet(M.Get(id), true)), "naturel")[1]
r = M.Traiter("Joueur-Apertus", { i = id, a = "prendre", l = peau.id, t = 8 })
attendu("8 contre la Peau DD 12 : raté", r.rate, 1)
attendu("  il reste une tentative", r.reste, 1)
r = M.Traiter("Joueur-Apertus", { i = id, a = "prendre", l = peau.id, t = 3 })
attendu("le second raté la détruit", r.detruit, "Peau témoin")
attendu("  elle a quitté le cadavre", #C.Lots(C.Lire(C.Paquet(M.Get(id), true)), "naturel", true), 0)
attendu("  pas le compendium", LCM.Ressources.Get("peau_cad") ~= nil, true)
local croc = C.Lots(C.Lire(C.Paquet(M.Get(id), true)), "ventre")[1]
r = M.Traiter("Joueur-Apertus", { i = id, a = "prendre", l = croc.id, t = 9 })
attendu("9 contre le Croc DD 5 : extrait", r.donne and r.donne.e, CROC)

dire("== finir : l'état part à tous, le verrou tombe")
local avant = #__envois
M.Traiter("Joueur-Apertus", { i = id, a = "fermer" })
attendu("l'état est rediffusé", #__envois > avant, true)
r = M.Traiter("Autre-Apertus", { i = id, a = "ouvrir" })
attendu("l'autre peut ouvrir à son tour", r.ouvert, 1)
M.Traiter("Autre-Apertus", { i = id, a = "fermer" })

dire("== le MJ fouille lui-même, par le même chemin")
attendu("il ouvre", (C.Ouvrir(id)), true)
attendu("  la fouille est à lui", C.fouille and C.fouille.id, id)
local epee = C.Lots(C.connus[id], "equipe")[1]
attendu("il prend l'épée", (C.Prendre(id, epee.id)), true)
attendu("  elle est dans son sac", LCM.OutilsRequis.SacTotal(moi, "objets/epee_cad"), 1)
attendu("plus rien à prendre : le cadavre s'efface", M.Get(id), nil)
attendu("  chez lui aussi", C.connus[id], nil)

dire("== poser un cadavre sans combat (Interactions › Cadavres)")
-- Le MJ, 3 novembre 2026 : « pré-poser des créatures déjà mortes » ; le PNJ
-- tient lieu de modèle.
attendu("l'entrée est au radial", LCM.UI.Menu.EstLiee("cadavres"), true)
LCM.UI.Menu.Trouver("cadavres").onClick()
local atelier = LCM.UI.CadavresMJ.frame
attendu("l'atelier s'ouvre", atelier and atelier:IsShown(), true)
attendu("  sans PNJ choisi, pas de pose", atelier.poser:IsEnabled(), false)
atelier.choixPNJ.choisir("loup_cad")
attendu("choisir un PNJ résume son butin", atelier.resume:GetText(), "Équipé : 1 · Sac : 1 · Naturel : 1 · Ventre : 1")
__position(300, 400, 0)
atelier.poser:Click()
local pose
for _, cad in ipairs(M.Liste()) do if cad.x == 300 then pose = cad end end
attendu("le cadavre est posé à ma position", pose ~= nil, true)
attendu("  avec l'équipement et le butin du PNJ", pose and #pose.lots, 4)
attendu("  la liste le montre", atelier.lignes[1] and atelier.lignes[1]:IsShown(), true)
atelier.poser:Click()
attendu("deux poses, deux cadavres distincts", #M.Liste(), 2)
for _, cad in ipairs(M.Liste()) do M.Supprimer(cad.id) end
atelier:Afficher()
attendu("retirés, la liste est vide", atelier.vide:IsShown(), true)
atelier:Hide()

dire("== le bouton Mort en combat")
local inst2 = LCM.Incarnation.Instancier("loup_cad")
LCM.Combat.etat = { s = 1, c = 1, t = 1, r = 1, rm = 3, mj = LCM.PlayerId(), entrees = {
    { id = inst2.id, nom = inst2.name, v = 10, pnj = true, ko = true } } }
local P = LCM.UI.PanneauMJ.Basculer()
P:Onglet("combat")
local rangee
for _, page in pairs(P.pages) do
    local liste = page.combat and page.combat.lignesListe
    if liste then for _, l in ipairs(liste) do if l:IsShown() and l.instance == inst2.id then rangee = l end end end
end
if rangee then
    attendu("à 0 PV, le bouton Mort apparaît", rangee.mort:IsShown(), true)
    rangee.mort:Click()
    attendu("  il pose le cadavre", inst2.cadavre ~= nil and M.Get(inst2.cadavre) ~= nil, true)
    attendu("  et disparaît ensuite", rangee.mort:IsShown(), false)
else
    attendu("la ligne du PNJ est dans la liste de combat", rangee ~= nil, true)
end
LCM.Combat.etat = nil

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
