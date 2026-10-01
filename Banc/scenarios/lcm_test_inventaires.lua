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
attendu("Sacs 2, Saccoches 4, Devises 1", table.concat(ids, ","), "Sacs:2,Saccoches:4,Devises:1")

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
refus = I.Poser(moi, "devises", 1, "gros_sac")
attendu("une devise seulement en Devises", refus, false)
attendu("une devise", I.Poser(moi, "devises", 1, "credits"), true)
attendu("son solde part de zero", I.Emplacement(moi, "devises", 1).solde, 0)
refus, raison = I.Solde(moi, "devises", 1, "-3")
attendu("solde negatif refuse", refus, false)
attendu("solde pose", I.Solde(moi, "devises", 1, "120"), true)
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

dire("== la fenetre")
local M = LCM.UI.Menu
attendu("entree du menu allumee", M.EstLiee("inventaires"), true)
M.Trouver("inventaires").onClick()
local f = LCM.UI.Inventaires.frame
attendu("ouverte", f:IsShown(), true)
attendu("titre", f.titre:GetText(), "INVENTAIRES")
attendu("trois onglets", #f.onglets, 3)
attendu("onglet Sacs", f.onglets[1].label:GetText(), "Sacs")
attendu("occupation", f.occupation:GetText(), "1 / 2")
attendu("le sac (nom et remplissage)", f.cartes[1].nom:GetText(), "Gros sac (0/12)")
attendu("l'emplacement libre", f.cartes[2].nom:GetText(), "Emplacement")
attendu("pas de boutons en vue (template)", f.cartes[1].action, nil)
attendu("en grille : la deuxieme a droite",
    select(4, f.cartes[2]:GetPoint(1)) > select(4, f.cartes[1]:GetPoint(1)), true)
f.vue:Click()
attendu("en liste : l'une sous l'autre", select(5, f.cartes[2]:GetPoint(1)) < select(5, f.cartes[1]:GetPoint(1)), true)
f.vue:Click()

-- Clic sur l'emplacement libre : le MJ choisit un sac.
f.cartes[2]:Click("LeftButton")
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "sacs/sac_d_essai" then b:Click() end end
attendu("sac pose depuis la liste", I.Emplacement(moi, "sacs", 2).sac, "sac_d_essai")

-- Glisser un sac du compendium sur une saccoche.
f.onglets[2]:Click()
attendu("quatre emplacements de saccoche", f.cartes[4]:IsShown(), true)
local Comp = LCM.UI.Compendium.Ouvrir("sacs")
local ligne
for _, r in ipairs(Comp.rangees) do if r.element and r.element.id == "sac_de_gros" then ligne = r end end
__souris.LeftButton = true
ligne:GetScript("OnDragStart")(ligne)
f.cartes[1].__survol = true
__souris.LeftButton = false
__avancer(0.05)
f.cartes[1].__survol = nil
attendu("sac glisse dans la saccoche", I.Emplacement(moi, "saccoches", 1) and I.Emplacement(moi, "saccoches", 1).sac, "sac_de_gros")
Comp:Hide()

dire("== un sac ouvert")
f.onglets[1]:Click()
f.cartes[1]:Click("LeftButton")
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

dire("== Devises")
f.onglets[3]:Click()
attendu("en liste (template)", f.vue.label:GetText(), "Grille")
attendu("la devise", f.cartes[1].nom:GetText(), "Crédits")
attendu("son solde", f.cartes[1].description:GetText(), "Solde : 120")

dire("== le joueur voit, n'y touche pas")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f.onglets[1]:Click()
f.cartes[1]:Click("RightButton")
libelles = {}
for _, l in ipairs(menu.lignes) do if l:IsShown() then libelles[#libelles + 1] = l.texte:GetText() end end
attendu("menu joueur", table.concat(libelles, ","), "Ouvrir,Voir")
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

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
