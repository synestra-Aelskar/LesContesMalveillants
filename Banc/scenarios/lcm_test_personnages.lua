-- Profils de personnage, liste et carrousel de cartes.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local P = LCM.Personnages

dire("== aucun personnage au depart")
attendu("liste vide", P.Compte(), 0)
attendu("personne en jeu", P.ActifId(), "")

dire("== creer un personnage")
local nytherah = P.Creer("Nytherah", { race = "Humain", niveau = 3, constitution = 4 })
attendu("cree", nytherah ~= nil, true)
attendu("identifiant lisible", nytherah.id, "nytherah")
attendu("il devient le personnage joue", P.ActifId(), "nytherah")
attendu("la fiche suit", LCM.Entities.Self().id, "nytherah")
attendu("ses valeurs sont posees", LCM.Entities.Get_Value(nytherah, "niveau"), 3)

dire("== un homonyme ne recouvre pas le premier")
local autre = P.Creer("Nytherah", { race = "Humain" })
attendu("identifiant distinct", autre.id, "nytherah-2")
attendu("un nom vide est refuse", (P.Creer("")), nil)

dire("== le resume")
attendu("resume", P.Resume(nytherah), "Humain — niveau 3")

dire("== la fenetre de selection")
local f = LCM.UI.Personnages.Ouvrir()
attendu("fenetre ouverte", f:IsShown(), true)
attendu("deux profils", #f.profils, 2)
attendu("ouvre sur celui qu'on joue", f:Courant().id, P.ActifId())

dire("== la liste de gauche")
attendu("deux lignes", #f.liste.boutons, 2)
local lignes = {}
for _, b in ipairs(f.liste.boutons) do lignes[#lignes + 1] = b.label:GetText() end
dire("   " .. table.concat(lignes, "  |  "))
attendu("niveau puis nom", lignes[1]:find("^%d+  %-  ") ~= nil, true)

dire("== les cartes")
local centre, gauche, droite = f.cartes[0], f.cartes[-1], f.cartes[1]
attendu("la carte centrale porte le personnage joue", centre.entity.id, P.ActifId())
attendu("son nom", centre.nom:GetText(), centre.entity.name)
attendu("son niveau en pastille", centre.niveau.label:GetText(),
    tostring(LCM.Entities.Get_Value(centre.entity, "niveau")))
attendu("la marque en jeu", centre.marque:GetText(), "· en jeu ·")
attendu("elle est en grand", centre:GetWidth(), 208)
-- A deux personnages, on ne montre pas le meme des deux cotes.
attendu("pas de voisine a gauche", gauche:IsShown(), false)
attendu("une voisine a droite", droite:IsShown(), true)
attendu("plus petite", droite:GetWidth(), 158)
attendu("et en retrait", droite:GetAlpha(), 0.55)

dire("== cliquer une voisine la ramene au centre")
local vise = droite.entity.id
droite:Click()
attendu("elle est au centre", f.cartes[0].entity.id, vise)

dire("== a trois personnages, le carrousel boucle")
P.Creer("Reika", { race = "Humain", niveau = 1 })
f:Rafraichir()
attendu("trois profils", #f.profils, 3)
f.index = 1
f:Afficher()
attendu("voisine de gauche = la derniere", f.cartes[-1].entity.id, f.profils[3].id)
attendu("voisine de droite = la seconde", f.cartes[1].entity.id, f.profils[2].id)
f:Decaler(-1)
attendu("on recule en boucle", f.index, 3)
f:Decaler(1)
attendu("et on revient", f.index, 1)

dire("== cliquer la liste change de carte")
f.liste.boutons[2]:Click()
attendu("index suivi", f.index, 2)
attendu("carte suivie", f.cartes[0].entity.id, f.profils[2].id)
attendu("ligne selectionnee", f.liste.boutons[2].__selectionne, true)

dire("== jouer le personnage affiche")
local courant = f:Courant()
f.jouer:Click()
attendu("nouveau personnage joue", P.ActifId(), courant.id)
attendu("la fiche suit", LCM.Entities.Self().id, courant.id)
attendu("la carte le marque", f.cartes[0].marque:GetText(), "· en jeu ·")

dire("== cliquer la carte centrale le joue aussi")
f.liste.boutons[1]:Click()
f.cartes[0]:Click()
attendu("joue", P.ActifId(), f.profils[1].id)

dire("== supprimer un personnage, avec confirmation")
f.liste.boutons[1]:Click()
local condamne = f:Courant()
local avant = P.Compte()
f.supprimer:Click()
attendu("on demande confirmation", f.confirmation:IsShown(), true)
attendu("le nom est dans la question", f.confirmation.texte:GetText():find(condamne.name) ~= nil, true)
attendu("rien n'est supprime", P.Compte(), avant)
f.confirmation.non:Click()
attendu("annuler ne supprime rien", P.Compte(), avant)
attendu("la boite se referme", f.confirmation:IsShown(), false)
f.supprimer:Click()
f.confirmation.oui:Click()
attendu("confirme : le personnage est parti", P.Compte(), avant - 1)
attendu("et il n'est plus dans la liste", P.Liste()[1].id ~= condamne.id, true)
attendu("le carrousel s'est recale", #f.profils, avant - 1)

dire("== portraits")
attendu("aucun portrait livre", LCM.Portraits.Count(), 0)
attendu("pas de silhouette non plus", LCM.Portraits.silhouette, nil)
attendu("repli sur une icone", LCM.Portraits.Appliquer(f.cartes[0].art, f:Courant()), "icone")
-- Ce que l'outil ecrit dans Data/Genere/Portraits.lua.
LCM.Portraits.SetSilhouette("_silhouette.tga")
attendu("silhouette declaree", LCM.Portraits.Appliquer(f.cartes[0].art, f:Courant()), "silhouette")
LCM.Portraits.Add({ id = "reika_shira", label = "Reika Shira" })
attendu("un portrait livre", LCM.Portraits.Count(), 1)
attendu("chemin de texture", LCM.Portraits.Get("reika_shira").texture:find("portraits") ~= nil, true)
local perso = f.profils[1]
LCM.Entities.Set_Value(perso, "portrait", "reika_shira")
attendu("le personnage le porte", LCM.Portraits.Appliquer(f.cartes[0].art, perso), "portrait")
attendu("cadrage 2:3", LCM.Portraits.Of(perso).coords[4], 0.75)
-- Un reexport remplace l'entree, il ne la double pas.
LCM.Portraits.Add({ id = "reika_shira", label = "Reika Shira" })
attendu("pas de doublon apres reexport", LCM.Portraits.Count(), 1)
LCM.Entities.Set_Value(perso, "portrait", nil)

dire("== le bouton + ouvre la creation")
f.creer:Click()
attendu("fenetre de creation ouverte", LCM.UI.Creation.frame:IsShown(), true)
attendu("sur un brouillon neuf", LCM.UI.Creation.frame.brouillon.nom, "")
LCM.UI.Creation.frame:Hide()

dire("== supprimer celui qu'on joue")
P.Choisir(P.Liste()[1].id)
local supprime = P.ActifId()
attendu("supprime", P.Supprimer(supprime), true)
attendu("plus personne en jeu", P.ActifId(), "")
attendu("il en reste un", P.Compte(), 1)
f:Rafraichir()
attendu("le carrousel se recale", f.index <= #f.profils, true)

dire("== plus personne")
for _, profil in ipairs(P.Liste()) do P.Supprimer(profil.id) end
f:Rafraichir()
attendu("liste vide", #f.profils, 0)
attendu("aucune carte", f.cartes[0]:IsShown(), false)
attendu("pas de bouton Jouer", f.jouer:IsShown(), false)
attendu("on invite a creer", f.vide:GetText():find("Créer un personnage") ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
