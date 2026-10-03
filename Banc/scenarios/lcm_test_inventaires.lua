-- Inventaires : les onglets du template (Sacs, Saccoches, Devises), les sacs
-- poses, leurs cases, les devises, la fenetre et la fenetre d'un sac.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("sacs", { id = "sac_d_essai", label = "Sac d'essai", places = 12, icone = "inv_misc_bag_30" })
-- Un sac « ancien format » (entity.sacs.sac) : il doit etre repris, pas perdu.
local avant = LCM.Entities.Create(LCM.PlayerId(), "Reika", "player")
avant.sacs = { sac = { "gros_sac", "sac_de_gros", "gros_sac" } }
__declencher("PLAYER_LOGIN")
local S, I = LCM.Sacs, LCM.Inventaire
local moi = LCM.Entities.Self()

dire("== le catalogue des sacs")
attendu("places", S.Get("sac_d_essai").places, 12)
attendu("places de devise par defaut", S.Get("sac_d_essai").placesDevise, 0)
attendu("icone", S.Get("sac_d_essai").icone, "Interface\\Icons\\inv_misc_bag_30")
local ok = pcall(S.Construire, { id = "x", places = 0 })
attendu("un sac sans place est refuse", ok, false)
ok = pcall(S.Construire, { id = "x", places = "beaucoup" })
attendu("un nombre illisible aussi", ok, false)

dire("== les onglets du template")
local ids = {}
for _, c in ipairs(I.categories) do ids[#ids + 1] = c.label .. ":" .. I.Capacite(c.id) end
attendu("Sacs 2, Saccoches 4", table.concat(ids, ","), "Sacs:2,Saccoches:4")

dire("== les sacs d'avant sont repris")
attendu("sac 1", I.Emplacement(moi, "sacs", 1).sac, "gros_sac")
attendu("sac 2", I.Emplacement(moi, "sacs", 2).sac, "sac_de_gros")
attendu("le troisieme en saccoche", I.Emplacement(moi, "saccoches", 1).sac, "gros_sac")
attendu("l'ancien format est vide", moi.sacs, nil)
moi.inventaire = nil

dire("== poser, ranger, retirer")
attendu("poser un sac", I.Poser(moi, "sacs", 1, "gros_sac"), true)
local refus, raison = I.Poser(moi, "sacs", 1, "sac_de_gros")
attendu("emplacement occupe : refus", refus, false)
refus, raison = I.Poser(moi, "sacs", 3, "gros_sac")
attendu("pas de troisieme emplacement de sac", refus, false)
dire("     " .. tostring(raison))
-- L'onglet « Devises » a ete retire (1er octobre 2026) : la monnaie vit dans la
-- Bourse, voir lcm_test_bourse.lua. Les cases de devise DANS un sac restent,
-- et sont verifiees plus bas.
refus, raison = I.Poser(moi, "devises", 1, "credits")
attendu("l'onglet Devises n'existe plus", refus, false)
local e = I.Emplacement(moi, "sacs", 1)
attendu("douze cases", I.Cases(e), 12)
attendu("ranger une dague", I.Ranger(moi, "sacs", 1, 3, "objets/dague_d_assassin_du_culte", 1), true)
refus, raison = I.Ranger(moi, "sacs", 1, 3, "ressources/eau", 1)
attendu("case occupee : refus", refus, false)
refus, raison = I.Ranger(moi, "sacs", 1, 4, "traits/assassin_expert", 1)
attendu("un trait ne se range pas", refus, false)
dire("     " .. tostring(raison))
refus, raison = I.Ranger(moi, "sacs", 1, 4, "devises/credits", 1)
attendu("une devise hors case de devise : refus", refus, false)
attendu("quantite", I.Quantite(moi, "sacs", 1, 3, "4"), true)
refus = I.Quantite(moi, "sacs", 1, 3, "0")
attendu("quantite nulle refusee", refus, false)
refus, raison = I.Retirer(moi, "sacs", 1)
attendu("un sac plein ne se retire pas", refus, false)
dire("     " .. tostring(raison))
attendu("vider la case", I.Vider(moi, "sacs", 1, 3), true)
attendu("plus rien dans le sac", I.Emplacement(moi, "sacs", 1).cases, nil)

dire("== deplacer un sac, avec ce qu'il contient")
I.Ranger(moi, "sacs", 1, 2, "ressources/eau", 3)
attendu("vers une saccoche", I.Deplacer(moi, "sacs", 1, "saccoches", 2), true)
attendu("le sac est arrive", I.Emplacement(moi, "saccoches", 2).sac, "gros_sac")
attendu("avec son contenu", I.Case(I.Emplacement(moi, "saccoches", 2), 2).quantite, 3)
attendu("le depart est libre", I.Emplacement(moi, "sacs", 1), nil)
attendu("et l'onglet vide n'est pas garde", moi.inventaire.sacs, nil)
refus, raison = I.Deplacer(moi, "sacs", 1, "saccoches", 3)
attendu("depuis un emplacement vide : refus", refus, false)
I.Poser(moi, "sacs", 1, "sac_de_gros")
refus, raison = I.Deplacer(moi, "sacs", 1, "saccoches", 2)
attendu("vers un emplacement occupe : refus", refus, false)
dire("     " .. tostring(raison))
attendu("rien n'a bouge", I.Emplacement(moi, "sacs", 1).sac, "sac_de_gros")
refus, raison = I.Deplacer(moi, "saccoches", 2, "saccoches", 9)
attendu("vers un emplacement qui n'existe pas : refus", refus, false)
attendu("sur place : refus", (I.Deplacer(moi, "saccoches", 2, "saccoches", 2)), false)
-- On remet la situation d'avant pour la suite : gros sac vide en Sacs 1.
I.Retirer(moi, "sacs", 1)
I.Deplacer(moi, "saccoches", 2, "sacs", 1)
I.Vider(moi, "sacs", 1, 2)
attendu("retour a la situation d'avant", I.Emplacement(moi, "sacs", 1).sac .. "/" .. tostring(moi.inventaire.saccoches),
    "gros_sac/nil")

dire("== la fenetre")
local M = LCM.UI.Menu
attendu("entree du menu allumee", M.EstLiee("inventaires"), true)
M.Trouver("inventaires").onClick()
local f = LCM.UI.Inventaires.frame
attendu("ouverte", f:IsShown(), true)
attendu("titre", f.titre:GetText(), "INVENTAIRES")
-- Plus d'onglets depuis le 3 octobre 2026 : les six emplacements sont dans une
-- colonne a gauche, deux sacs puis quatre sacoches.
attendu("plus de bande d'onglets", f.onglets, nil)
attendu("six emplacements", #f.cartes, 6)
attendu("le sac (nom et remplissage)", f.cartes[1].nom:GetText(), "Gros sac (0/12)")
attendu("un emplacement de sac libre se nomme Sac", f.cartes[2].nom:GetText(), "Sac")
attendu("et une sacoche libre, Sacoche", f.cartes[3].nom:GetText(), "Sacoche")
attendu("pas de boutons en vue (template)", f.cartes[1].action, nil)
attendu("ils sont l'un sous l'autre",
    select(5, f.cartes[2]:GetPoint(1)) < select(5, f.cartes[1]:GetPoint(1)), true)
attendu("et tous a la meme abscisse",
    select(4, f.cartes[2]:GetPoint(1)) == select(4, f.cartes[1]:GetPoint(1)), true)

dire("   clic gauche : le contenu s'affiche a droite")
f.cartes[1]:Click("LeftButton")
attendu("c'est lui qu'on regarde", f.choisi, 1)
attendu("son nom est en haut", f.titreContenu:GetText(), "Gros sac")
attendu("occupation du sac", f.occupation:GetText(), "0 / 12")
attendu("douze lignes de contenu", #f.lignes, 12)
attendu("toutes vides pour l'instant", f.lignes[1].nom:GetText(), "Vide")

-- Clic sur l'emplacement libre : le MJ choisit un sac.
f.cartes[2]:Click("LeftButton")
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "sacs/sac_d_essai" then b:Click() end end
attendu("sac pose depuis la liste", I.Emplacement(moi, "sacs", 2).sac, "sac_d_essai")

-- Glisser un sac du compendium sur une saccoche (les rangs 3 a 6).
attendu("quatre emplacements de saccoche", f.cartes[6]:IsShown(), true)
local Comp = LCM.UI.Compendium.Ouvrir("sacs")
local ligne
for _, r in ipairs(Comp.rangees) do if r.element and r.element.id == "sac_de_gros" then ligne = r end end
__souris.LeftButton = true
ligne:GetScript("OnDragStart")(ligne)
f.cartes[3].__survol = true
__souris.LeftButton = false
__avancer(0.05)
f.cartes[3].__survol = nil
-- Un SAC ne se porte pas dans un emplacement de sacoche : le glisser la est
-- refuse depuis le 3 octobre 2026.
attendu("un sac refuse l'emplacement de sacoche",
    I.Emplacement(moi, "saccoches", 1) == nil
    or I.Emplacement(moi, "saccoches", 1).sac ~= "sac_de_gros", true)
Comp:Hide()

dire("== un sac ouvert : clic DROIT")
f.cartes[1]:Click("RightButton")
local s = LCM.UI.Inventaires.sacs["sacs_1"]
attendu("fenetre du sac", s and s:IsShown(), true)
attendu("son titre", s.titre:GetText(), "GROS SAC")
attendu("douze cases", #s.cases, 12)
attendu("cases de 46", s.cases[1]:GetWidth(), 46)
-- Clic sur une case vide : le MJ choisit une entree.
s.cases[1]:Click("LeftButton")
for _, b in ipairs(s.choix.lignes) do if b:IsShown() and b.choix == "ressources/eau" then b:Click() end end
attendu("eau rangee", I.Case(I.Emplacement(moi, "sacs", 1), 1).ref, "ressources/eau")
attendu("le remplissage suit", f.cartes[1].nom:GetText(), "Gros sac (1/12)")
-- Clic droit : le menu ; Quantite.
s.cases[1]:Click("RightButton")
local menu = LCM_MenuContexte
attendu("menu ouvert", menu:IsShown(), true)
local libelles = {}
for _, l in ipairs(menu.lignes) do if l:IsShown() then libelles[#libelles + 1] = l.texte:GetText() end end
attendu("options", table.concat(libelles, ","), "Voir,Quantite : 1,Deplacer >,Supprimer")
menu.lignes[2]:Click()
local d = LCM_Demande
d.saisie:SetText("abc")
d.valider:Click()
attendu("quantite illisible : refus dit", (d.message:GetText() or ""):find("illisible") ~= nil, true)
attendu("la demande reste ouverte", d:IsShown(), true)
d.saisie:SetText("5")
d.valider:Click()
attendu("quantite posee", I.Case(I.Emplacement(moi, "sacs", 1), 1).quantite, 5)
attendu("affichee x5", s.cases[1].nombre:GetText(), "x5")
-- Deplacer vers l'autre sac.
s.cases[1]:Click("RightButton")
menu.lignes[3]:Click()
menu.sousLignes[1]:Click()
attendu("deplacee hors du gros sac", I.Case(I.Emplacement(moi, "sacs", 1), 1), nil)
attendu("dans le sac d'essai", I.Case(I.Emplacement(moi, "sacs", 2), 1).ref, "ressources/eau")

dire("== deux categories pour six emplacements")
-- Les categories restent le modele (combien d'emplacements, ce qu'ils
-- acceptent) ; c'est leur bande d'onglets qui a disparu.
attendu("Sacs et Saccoches", #LCM.Inventaire.categories, 2)
attendu("deux sacs et quatre sacoches", #f.cartes, 6)

dire("== le joueur voit, n'y touche pas")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Rafraichir()
-- Un emplacement OCCUPE s'ouvre au clic droit, joueur comme MJ : il n'y a plus
-- de menu a cet endroit.
LCM.UI.Inventaires.sacs["sacs_1"]:Hide()
f.cartes[1]:Click("RightButton")
attendu("le sac s'ouvre", LCM.UI.Inventaires.sacs["sacs_1"]:IsShown(), true)
LCM.UI.Inventaires.sacs["sacs_1"]:Hide()
-- Un emplacement VIDE garde son menu : il n'y a rien a ouvrir, et c'est la
-- qu'on choisit quoi y mettre.
f.cartes[4]:Click("RightButton")
attendu("rien a ouvrir, rien a proposer au joueur", menu:IsShown(), false)
menu:Hide()
local Comp2 = LCM.UI.Compendium.Ouvrir("ressources")
__souris.LeftButton = true
Comp2.rangees[1]:GetScript("OnDragStart")(Comp2.rangees[1])
s:Show()
s.cases[2].__survol = true
__souris.LeftButton = false
__avancer(0.05)
s.cases[2].__survol = nil
attendu("le depot du joueur est refuse", I.Case(I.Emplacement(moi, "sacs", 1), 2), nil)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire("== la fenetre d'un sac prend la taille de son sac")
-- Deux sacs de capacites differentes : la fenetre ne peut pas faire la meme
-- taille pour cinq cases et pour vingt-cinq.
LCM.Sacs.Add({ id = "sac_etroit", label = "Sac etroit", nature = "sac", places = 4 })
LCM.Sacs.Add({ id = "sac_vaste",  label = "Sac vaste",  nature = "sac", places = 30 })
moi.inventaire = nil
I.Poser(moi, "sacs", 1, "sac_etroit")
I.Poser(moi, "sacs", 2, "sac_vaste")
local petit = LCM.UI.Inventaires.OuvrirSac("sacs", 1)
local hautPetit = petit:GetHeight()
petit:Hide()
local grand = LCM.UI.Inventaires.OuvrirSac("sacs", 2)
attendu("le grand sac ouvre une plus grande fenetre", grand:GetHeight() > hautPetit, true)

dire("   passer de la grille a la liste change la hauteur")
local enGrille = grand:GetHeight()
grand.vue:Click()
attendu("en liste, c'est plus haut", grand:GetHeight() > enGrille, true)
grand.vue:Click()
attendu("et en grille, ca revient", grand:GetHeight(), enGrille)

dire("   une fenetre qu'on a tiree garde sa taille")
grand.placee = true
grand:SetHeight(250)
grand.vue:Click()
attendu("elle ne bouge plus", grand:GetHeight(), 250)
grand:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
