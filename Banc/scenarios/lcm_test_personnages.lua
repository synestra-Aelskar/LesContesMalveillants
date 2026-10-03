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
-- Le nom seul sur la ligne ; le niveau et la marque en jeu passent dessous.
attendu("le nom seul", lignes[1], f.profils[1].name)
attendu("le niveau en detail", f.liste.boutons[1].detail:GetText():find("^Niveau %d+") ~= nil, true)

dire("== les cartes")
local centre, gauche, droite = f.cartes[0], f.cartes[-1], f.cartes[1]
attendu("la carte centrale porte le personnage joue", centre.entity.id, P.ActifId())
attendu("son nom", centre.nom:GetText(), centre.entity.name)
attendu("son niveau en pastille", centre.niveau.label:GetText(),
    "Niv. " .. tostring(LCM.Entities.Get_Value(centre.entity, "niveau")))
attendu("la marque en jeu", centre.marque:GetText(), "EN JEU")
attendu("elle est en grand", centre:GetWidth(), 208)
-- A deux personnages, on ne montre pas le meme des deux cotes.
attendu("pas de voisine a gauche", gauche:IsShown(), false)
attendu("une voisine a droite", droite:IsShown(), true)
attendu("plus petite", droite:GetWidth(), 128)
attendu("et en retrait", droite:GetAlpha(), 0.72)

dire("== cliquer une voisine la ramene au centre")
local vise = droite.entity.id
droite:Click()
__avancer(1)
attendu("elle est au centre", f.cartes[0].entity.id, vise)

-- Le carrousel suit la liste sans boucler : aux extremites, il s'arrete.
dire("== a trois personnages, le carrousel s'arrete aux bouts")
P.Creer("Reika", { race = "Humain", niveau = 1 })
f:Rafraichir()
attendu("trois profils", #f.profils, 3)
f.index = 1
f:Afficher()
attendu("pas de voisine a gauche du premier", f.cartes[-1]:IsShown(), false)
attendu("voisine de droite = la seconde", f.cartes[1].entity.id, f.profils[2].id)
attendu("position affichee", f.position:GetText(), "Personnage 1 / 3")
f:Decaler(-1)
__avancer(1)
attendu("on ne recule pas avant le premier", f.index, 1)
f:Decaler(1)
__avancer(1)
attendu("on avance", f.index, 2)
f:Decaler(-1)
__avancer(1)
attendu("et on revient", f.index, 1)

dire("== cliquer la liste change de carte")
f.liste.boutons[2]:Click()
__avancer(1)
attendu("index suivi", f.index, 2)
attendu("carte suivie", f.cartes[0].entity.id, f.profils[2].id)
attendu("ligne selectionnee", f.liste.boutons[2].__selectionne, true)

dire("== jouer le personnage affiche")
local courant = f:Courant()
f.jouer:Click()
attendu("nouveau personnage joue", P.ActifId(), courant.id)
attendu("la fiche suit", LCM.Entities.Self().id, courant.id)
attendu("la carte le marque", f.cartes[0].marque:GetText(), "EN JEU")

dire("== cliquer la carte centrale le joue aussi")
f.liste.boutons[1]:Click()
__avancer(1)
f.cartes[0]:Click()
attendu("joue", P.ActifId(), f.profils[1].id)

dire("== supprimer un personnage, avec confirmation")
f.liste.boutons[1]:Click()
__avancer(1)
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
-- Le nombre de portraits livres change a chaque conversion : on verifie le
-- COMPORTEMENT, pas le contenu.
attendu("une silhouette de repli est livree", LCM.Portraits.silhouette ~= nil, true)
attendu("sans artwork : la silhouette", LCM.Portraits.Appliquer(f.cartes[0].art, f:Courant()), "silhouette")
local avant = LCM.Portraits.Count()
LCM.Portraits.Add({ id = "portrait_d_essai", label = "Essai" })
attendu("un portrait de plus", LCM.Portraits.Count(), avant + 1)
attendu("chemin de texture", LCM.Portraits.Get("portrait_d_essai").texture:find("portraits") ~= nil, true)
local perso = f.profils[1]
LCM.Entities.Set_Value(perso, "portrait", "portrait_d_essai")
attendu("le personnage le porte", LCM.Portraits.Appliquer(f.cartes[0].art, perso), "portrait")
attendu("cadrage 2:3", LCM.Portraits.Of(perso).coords[4], 0.75)
-- Un reexport remplace l'entree, il ne la double pas.
LCM.Portraits.Add({ id = "portrait_d_essai", label = "Essai" })
attendu("pas de doublon apres reexport", LCM.Portraits.Count(), avant + 1)
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

dire("== changer l'artwork depuis la carte")
-- Le scenario finit sans personnage : on en remet un pour avoir une carte.
LCM.Personnages.Creer("Alba", { race = "humain", niveau = 5 })
local f2 = LCM.UI.Personnages.Fenetre()
f2:Montrer()
local carte = f2.cartes[0]
attendu("la carte centrale a son bouton", carte.editerArtwork:IsShown(), true)
attendu("les voisines non", f2.cartes[1].editerArtwork:IsShown(), false)
local qui = carte.entity
attendu("elle porte bien un personnage", qui ~= nil, true)
carte.editerArtwork:Click()
if #LCM.Portraits.list > 0 then
    attendu("le choix s'ouvre", carte.portraitMenu:IsShown(), true)
    local premier
    for _, b in ipairs(carte.portraitMenu.lignes) do
        if b:IsShown() and b.choix ~= "" and not premier then premier = b end
    end
    premier:Click()
    attendu("l'artwork est retenu sur le personnage",
        LCM.Entities.Get_Value(qui, "portrait"), premier.choix)
else
    attendu("sans artwork livre, on le dit",
        __sansCouleur(__sorties[#__sorties]):find("aucun artwork") ~= nil, true)
end

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
