-- Regler UN point de recolte pose (20 octobre 2026).
--
-- Le MODELE est un catalogue : tout ce que ce genre de point peut donner
-- (« Récolter la pierre » : plusieurs pierres). Un point pose part TOUT
-- ETEINT ; le MJ l'ouvre (clic droit sur « Récolter ») et allume, ligne par
-- ligne, ce que CE point donne, avec sa chance, sa quantite et sa repousse.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Des ressources temoins : le contenu de la campagne bouge.
LCM.Brouillons.Set("ressources", { id = "fer_temoin", label = "Fer témoin" })
LCM.Brouillons.Set("ressources", { id = "cuivre_temoin", label = "Cuivre témoin" })
LCM.Brouillons.Set("ressources", { id = "etain_temoin", label = "Étain témoin" })
__declencher("PLAYER_LOGIN")
__personnage()
local R, MJ = LCM.Recolte, LCM.Recoltes
local FER, CUIVRE, ETAIN = "ressources/fer_temoin", "ressources/cuivre_temoin", "ressources/etain_temoin"
local function Ligne(entree, chance)
    return { entree = entree, min = 2, max = 2, chance = chance or 100,
        aleatoire = false, regeneration = false, minutes = 0 }
end

dire("== le modele : un catalogue")
local f = LCM.UI.Recoltes.Fenetre()
f:Montrer()
f:Nouveau()
local c = f.creation
c.nom:Saisir("Récolter du minerai")
f.travail.recolte.ressources = { Ligne(FER), Ligne(CUIVRE), Ligne(ETAIN) }
f:Remplir()
c.enregistrer:Click()
attendu("modele enregistre", c.erreur:GetText(), "")
local modele = f:Point()
attendu("trois lignes au catalogue", #modele.recolte.ressources, 3)
attendu("dans le modele : la croix, pas d'allumage", c.lignesRessources[1].retirer:IsShown()
    and not c.lignesRessources[1].actif:IsShown(), true)

dire("== pose : tout est eteint")
__position(100, 200, 0)
local un = MJ.Placer(modele.id)
__position(140, 200, 0)
local deux = MJ.Placer(modele.id)
attendu("deux points", un ~= nil and deux ~= nil, true)
attendu("un point pose ne donne rien", #MJ.Effectives(MJ.Pose(un), modele.recolte), 0)
attendu("il ne part a aucun joueur", #MJ.Points(modele.id), 0)
attendu("le MJ le connait quand meme", R.points[un] ~= nil and R.points[un].vide, true)
-- Le MJ se tient dessus : le bouton apparait, et dit qu'il faut le regler.
__position(140, 200, 0)
R.Tick()
attendu("le MJ le trouve en marchant dessus", R.courant and R.courant.id, deux)
local bouton = LCM.UI.Recolte.bouton
attendu("  le bouton dit qu'il est a regler",
    bouton.nom:GetText():find("à régler", 1, true) ~= nil, true)

dire("== clic droit : le panneau de gestion du point")
__position(100, 200, 0)
R.Tick()
bouton:Click("RightButton")
attendu("le clic droit ouvre CE point", f.poseRegle, un)
attendu("le bandeau le dit", c.bandeau:IsShown(), true)
attendu("  colonne ACTIF", c.titreActif:IsShown(), true)
local l1, l2, l3 = c.lignesRessources[1], c.lignesRessources[2], c.lignesRessources[3]
attendu("toutes les lignes eteintes", tostring(l1.actif:EstCochee()) .. tostring(l2.actif:EstCochee())
    .. tostring(l3.actif:EstCochee()), "falsefalsefalse")
attendu("  et grisees", l1:GetAlpha() < 1, true)
attendu("pas de croix ni de « Changer… »", l1.retirer:IsShown() or l1.choix:IsShown(), false)
attendu("on n'ajoute pas de ligne ici", c.ajouter:IsShown(), false)
attendu("les conditions restent celles du modele", c.pages.boutons[2]:IsShown(), false)

dire("== allumer le fer, et le cuivre a 50 %")
l1.actif:Click()
f.travail.recolte.ressources[2].chance = 50
l2.actif:Click()
attendu("le fer s'allume", l1.actif:EstCochee() and l1:GetAlpha() == 1, true)
attendu("le bandeau compte", c.bandeau.texte:GetText():find("(2/3)", 1, true) ~= nil, true)
c.enregistrer:Click()
attendu("enregistre sans erreur", c.erreur:GetText(), "")
local lignes = MJ.Pose(un).lignes
attendu("fer allume", lignes[FER] and lignes[FER].actif, true)
attendu("cuivre allume, a 50 %", lignes[CUIVRE] and (tostring(lignes[CUIVRE].actif) .. " " .. lignes[CUIVRE].chance), "true 50")
attendu("etain eteint", lignes[ETAIN] and lignes[ETAIN].actif, false)
attendu("le modele n'a pas bouge", LCM.Points.Get(modele.id).recolte.ressources[2].chance, 100)
attendu("l'autre point est toujours eteint", #MJ.Effectives(MJ.Pose(deux), modele.recolte), 0)

dire("== la recolte lit ce qui est allume")
local des = LCM.Roll.Des
LCM.Roll.Des = function(mini) return mini end
local lots = R.Tirer(MJ.Carnet(modele.id)[1].id == un and MJ.Carnet(modele.id)[1] or MJ.Carnet(modele.id)[2],
    modele.recolte)
LCM.Roll.Des = des
attendu("fer et cuivre, pas d'etain", lots and (#lots .. " " .. lots[1].entree .. "," .. lots[2].entree),
    "2 " .. FER .. "," .. CUIVRE)

dire("== il part aux joueurs, seul")
attendu("un point a envoyer", #MJ.Points(modele.id), 1)
local paquet = R.Paquet(modele.recolte, MJ.Points(modele.id))
paquet.i, paquet.n = modele.id, modele.label
local lu, points = R.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)))
attendu("le joueur ne recoit que le point allume", #points == 1 and points[1].id, un)
attendu("  avec son contenu", points[1] and #R.RessourcesDuPoint(points[1], lu), 2)
attendu("  et sa chance a lui", points[1] and R.RessourcesDuPoint(points[1], lu)[2].chance, 50)

dire("== tout activer")
f:ReglerPose(un)
c.bandeau.rendre:Click()
attendu("tout s'allume", l3.actif:EstCochee(), true)
c.enregistrer:Click()
attendu("trois ressources", #MJ.Effectives(MJ.Pose(un), modele.recolte), 3)
attendu("le cuivre garde ses 50 %", MJ.Pose(un).lignes[CUIVRE].chance, 50)

dire("== un point epuise repart plein quand on le regle")
local pose = MJ.Pose(un)
pose.consomme = { [1] = true, [2] = true, [3] = true }
attendu("epuise", R.Disponible(MJ.Carnet(modele.id)[1].id == un and MJ.Carnet(modele.id)[1]
    or MJ.Carnet(modele.id)[2], modele.recolte), false)
f:ReglerPose(un)
c.enregistrer:Click()
attendu("regle : il repart plein", MJ.Pose(un).consomme, nil)

dire("== un point pose avant les lignes donne tout son modele")
local ancien = { def = modele.id, x = 0, y = 0 }
attendu("sans reglage : tout le catalogue", #MJ.Effectives(ancien, modele.recolte), 3)

dire("== « Contenu… » sur la liste des points poses")
f:Choisir(modele.id)
f:Onglet("placement")
local ligneDeux
for _, l in ipairs(f.placement.lignes) do if l:IsShown() and l.poseId == deux then ligneDeux = l end end
attendu("la liste dit qu'il est a regler",
    ligneDeux and __sansCouleur(ligneDeux.texte:GetText()):find("À régler", 1, true) ~= nil, true)
ligneDeux.contenu:Click()
attendu("« Contenu… » ouvre ce point", f.poseRegle, deux)

dire("== « S'y téléporter », comme un coffre pose")
local D = LCM.DeplacementForce
local commandeVraie, envoyee = D.Commande, nil
D.Commande = function(texte) envoyee = texte return true end
f:Onglet("placement")
ligneDeux = nil
for _, l in ipairs(f.placement.lignes) do if l:IsShown() and l.poseId == deux then ligneDeux = l end end
ligneDeux.teleporter:Click()
local pd = MJ.Pose(deux)
attendu("le bouton envoie .worldport vers le point",
    envoyee and envoyee:find(string.format(".worldport %.6f %.6f %.6f", pd.x, pd.y, pd.z), 1, true) == 1, true)
local sansZ = MJ.Pose(un).z
MJ.Pose(un).z = nil
envoyee = nil
local ok, raison = MJ.Teleporter(un)
attendu("sans altitude : refuse, et dit pourquoi", (not ok) and raison:find("replace ce point", 1, true) ~= nil, true)
attendu("  rien n'est envoye", envoyee, nil)
MJ.Pose(un).z = sansZ
D.Commande = commandeVraie
f:ReglerPose(deux)

dire("== retour au modele")
c.bandeau.retour:Click()
attendu("plus de bandeau", c.bandeau:IsShown(), false)
attendu("  la croix revient", c.lignesRessources[1].retirer:IsShown(), true)
attendu("  l'ajout aussi", c.ajouter:IsShown(), true)
attendu("  et le bouton du modele", c.enregistrer.label:GetText(), "Enregistrer le modèle")

dire("== un refus dit pourquoi")
local _, raison = MJ.Regler("inconnu", {})
attendu("un point inconnu", raison, "ce point n'existe plus.")
_, raison = MJ.Regler(un, "n'importe quoi")
attendu("un reglage illisible", raison, "réglage illisible.")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
