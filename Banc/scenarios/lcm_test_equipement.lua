-- L'equipement passe par les sacs (3 octobre 2026) : on n'equipe que ce qui
-- est dans un sac du personnage, l'objet quitte le sac en passant sur lui et y
-- retourne quand on le retire. Le joueur equipe ses propres affaires ; remplir
-- un sac reste un geste du MJ.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function contient(libelle, texte, motif)
    local ok = tostring(texte or ""):find(motif, 1, true) ~= nil
    attendu(libelle, ok, true)
    if not ok then dire("     obtenu : " .. tostring(texte)) end
end

__declencher("PLAYER_LOGIN")
__personnage()
local O, I = LCM.Objets, LCM.Inventaire
local moi = LCM.Entities.Self()
LCM.Personnages.Choisir(moi.id)

O.Add({ id = "dague_d_essai", label = "Dague d'essai", categorie = "arme" })
O.Add({ id = "epee_d_essai", label = "Épée d'essai", categorie = "arme" })
O.Add({ id = "bague_d_essai", label = "Bague d'essai", categorie = "accessoire" })

dire("== Sans sac, rien a equiper")
local ok, raison = O.Equiper(moi, "dague_d_essai")
attendu("refuse", ok, false)
contient("dit pourquoi", raison, "n'est dans aucun sac")
attendu("rien d'equipe", O.Porte(moi, "dague_d_essai"), false)

dire("== Dans un sac : on equipe, l'objet quitte le sac")
attendu("un sac", I.Poser(moi, "sacs", 1, "gros_sac"), true)
attendu("une dague rangee", I.Ranger(moi, "sacs", 1, 1, "objets/dague_d_essai", 1), true)
attendu("deux epees en pile", I.Ranger(moi, "sacs", 1, 2, "objets/epee_d_essai", 2), true)
attendu("deux bagues en pile", I.Ranger(moi, "sacs", 1, 3, "objets/bague_d_essai", 2), true)
local candidats = {}
for _, o in ipairs(O.CandidatsPossedes(moi, "arme")) do candidats[#candidats + 1] = o.id end
table.sort(candidats)
attendu("candidats : les armes des sacs, une fois chacune", table.concat(candidats, ","), "dague_d_essai,epee_d_essai")
attendu("les accessoires a part", #O.CandidatsPossedes(moi, "accessoire"), 1)
ok, raison = O.Equiper(moi, "dague_d_essai")
attendu("dague equipee", ok, true)
attendu("portee", O.Porte(moi, "dague_d_essai"), true)
attendu("sa case liberee", I.Case(I.Emplacement(moi, "sacs", 1), 1), nil)
-- Une pile : un exemplaire en sort, le reste demeure.
ok = O.Equiper(moi, "bague_d_essai")
attendu("une bague de la pile", ok, true)
attendu("la pile baisse d'un", I.Case(I.Emplacement(moi, "sacs", 1), 3).quantite, 1)

dire("== Retirer : l'objet retourne dans un sac")
ok = O.Desequiper(moi, "dague_d_essai")
attendu("retiree", ok, true)
attendu("plus portee", O.Porte(moi, "dague_d_essai"), false)
attendu("de retour au sac", O.Possede(moi, "dague_d_essai"), true)

-- La ceinture (13 octobre 2026) a toujours ses cases de base : « plein »,
-- c'est elles aussi. On les remplit le temps de verifier le refus.
local function remplirCeinture(ref)
    local e = LCM.Inventaire.Emplacement(moi, "ceintures", 1)
    for case = 1, LCM.Inventaire.Cases(e) do
        if not LCM.Inventaire.Case(LCM.Inventaire.Emplacement(moi, "ceintures", 1), case) then
            LCM.Inventaire.Ranger(moi, "ceintures", 1, case, ref, 1)
        end
    end
end
local function viderCeinture()
    for case = 1, LCM.Inventaire.Cases(LCM.Inventaire.Emplacement(moi, "ceintures", 1)) do
        LCM.Inventaire.Vider(moi, "ceintures", 1, case)
    end
end
-- Sac plein : l'objet porte reste porte, rien ne disparait.
remplirCeinture("objets/epee_d_essai")
for case = 1, 12 do
    if not I.Case(I.Emplacement(moi, "sacs", 1), case) then
        I.Ranger(moi, "sacs", 1, case, "objets/epee_d_essai", 1)
    end
end
ok, raison = O.Desequiper(moi, "bague_d_essai")
attendu("sac plein : refuse", ok, false)
contient("dit pourquoi", raison, "aucune place libre")
attendu("la bague reste portee", O.Porte(moi, "bague_d_essai"), true)
viderCeinture()

dire("== La fenetre : seul ce qui est dans les sacs est propose")
-- La fenetre Inventaires ouverte a cote, sur le sac : elle doit suivre.
local inv = LCM.UI.Inventaires.Fenetre()
inv:Show()
inv.cartes[1]:Click("LeftButton")
attendu("l'inventaire montre la dague", inv.lignes[1].nom:GetText(), "Dague d'essai")
LCM.UI.Menu.Trouver("equipement").onClick()
local f = LCM.UI.Vues.frames.equipement
f.barre.boutons[1]:Click()
local conteneur = f.pages.arme.blocs[1].conteneur
conteneur:Actualiser(moi)
local vide
for _, ligne in ipairs(conteneur.emplacements) do
    if ligne:IsShown() and not ligne.elementId then vide = ligne end
end
attendu("une place libre a remplir", vide ~= nil, true)
vide.action:Click()
local choix = LCM.UI.Fiche.choixConteneur
local proposes = {}
for _, b in ipairs(choix.lignes) do if b:IsShown() then proposes[#proposes + 1] = b.choix end end
table.sort(proposes)
attendu("propose : les armes du sac", table.concat(proposes, ","), "dague_d_essai,epee_d_essai")
for _, b in ipairs(choix.lignes) do if b:IsShown() and b.choix == "dague_d_essai" then b:Click() end end
attendu("equipee depuis la fenetre", O.Porte(moi, "dague_d_essai"), true)
attendu("sortie du sac", O.Possede(moi, "dague_d_essai"), false)
attendu("l'inventaire ouvert suit aussitot", inv.lignes[1].nom:GetText(), "Vide")
inv:Hide()

dire("== Le MJ remplit un sac en glissant depuis le compendium")
-- Une place libre, et la lame glissee depuis une CELLULE de sa ligne (une
-- colonne de stat) : la ligne n'etait saisissable que par son nom.
I.Vider(moi, "sacs", 1, 11)
local Comp = LCM.UI.Compendium.Ouvrir("armes")
local rang
for _, r in ipairs(Comp.rangees) do if r.element and r.element.id == "epee_d_essai" then rang = r end end
local cellule
for _, c in ipairs(rang.cellules) do if c:IsShown() then cellule = c break end end
attendu("une cellule a saisir", cellule ~= nil, true)
local sac = LCM.UI.Inventaires.OuvrirSac("sacs", 1)
__souris.LeftButton = true
cellule:GetScript("OnDragStart")(cellule)
attendu("glissement commence", LCM.UI.Glisser.EnCours(), true)
-- Le survol eclaire la case (la case pose pourtant son propre OnEnter).
sac.cases[11].__survol = true
__avancer(0.02, 0.02)
attendu("la case survolee s'eclaire", sac.cases[11].glisserSurvol:IsShown(), true)
__souris.LeftButton = false
__avancer(0.02, 0.02)
sac.cases[11].__survol = nil
local depose = I.Case(I.Emplacement(moi, "sacs", 1), 11)
attendu("deposee dans la case", depose and depose.ref, "objets/epee_d_essai")
attendu("plus d'eclairage", sac.cases[11].glisserSurvol:IsShown(), false)
sac:Hide()
Comp:Hide()

dire("== Le joueur equipe lui-meme, mais ne remplit pas ses sacs")
LCM.db.settings.modeJoueur = true
attendu("plus MJ", LCM.IsMaster(), false)
conteneur:Actualiser(moi)
local porteeLigne
for _, ligne in ipairs(conteneur.emplacements) do
    if ligne:IsShown() and ligne.elementId == "dague_d_essai" then porteeLigne = ligne end
end
attendu("le joueur voit Retirer", porteeLigne.action:IsShown(), true)
-- Une place pour la dague.
I.Vider(moi, "sacs", 1, 12)
I.Vider(moi, "sacs", 1, 11)
porteeLigne.action:Click()
attendu("le joueur la retire", O.Porte(moi, "dague_d_essai"), false)
attendu("elle est au sac", O.Possede(moi, "dague_d_essai"), true)
LCM.db.settings.modeJoueur = nil

dire("== deux mains : ce qui tient, et ce qui est refuse")
-- DEUX emplacements d'arme depuis le 5 octobre 2026 : une arme et un
-- bouclier, ou une arme a deux mains qui prend les deux. Le scenario n'en
-- connaissait qu'un et attendait un refus des la deuxieme.
attendu("deux emplacements d'arme", LCM.Equilibrage.conteneurs.arme, 2)
for _, id in ipairs({ "dague_d_essai", "epee_d_essai" }) do
    if not O.Porte(moi, id) then O.Equiper(moi, id) end
end
attendu("la dague et l'epee tiennent ensemble",
    O.Porte(moi, "dague_d_essai") and O.Porte(moi, "epee_d_essai"), true)
local troisieme, pourquoiTroisieme = O.Equiper(moi, "epee_d_essai")
attendu("la troisieme est refusee", troisieme, false)
contient("  et on dit pourquoi", pourquoiTroisieme, "plus d'emplacement libre")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
