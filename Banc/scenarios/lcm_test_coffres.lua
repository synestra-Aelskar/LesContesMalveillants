-- Coffres : contenu persistant, capacite, prises concurrentes et verrous.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local MOI = LCM.PlayerId()
__groupe({ MOI, "Syn-Apertus", "Claydenn-Apertus" })
__position(100, 200, 0)

local REF, REF2, REF3 = "objets/cle_temoin", "objets/outil_temoin", "objets/aide_temoin"
LCM.Objets.Add({ id = "cle_temoin", label = "Clé témoin", categorie = "accessoire",
    icone = "inv_misc_key_01", etat = { courant = 1, max = 1 }, pileMax = 1 })
LCM.Objets.Add({ id = "outil_temoin", label = "Outil témoin", categorie = "accessoire",
    icone = "inv_misc_gear_01", etat = { courant = 10, max = 10 }, pileMax = 1,
    bonus = { vue = 4 } })
LCM.Objets.Add({ id = "aide_temoin", label = "Aide témoin", categorie = "accessoire",
    icone = "inv_misc_tool_01", etat = { courant = 10, max = 10 }, pileMax = 1,
    bonus = { vue = 2 } })
local definition = { id = "coffre_temoin", label = "Coffre témoin", nature = "coffre",
    coffre = { places = 1, rayon = 7, verrous = 1, reset = false,
        objets = { { entree = REF, quantite = 1 } },
        expertises = { { id = "vue", dd = 15, fatigue = 3, usureOutils = true,
            reverrouillable = true },
            { id = LCM.Coffres.METHODE_CLEF, dd = 0, fatigue = 0, reverrouillable = true } },
        outils = { { entree = REF2, quantite = 1, consomme = true,
            consommeQuantite = 1, expertise = "vue" },
            { entree = REF3, quantite = 1, consomme = false,
                consommeQuantite = 1, expertise = LCM.Coffres.METHODE_CLEF } } } }
local sauvegarde, erreur = LCM.Brouillons.Enregistrer("points", definition, true)
attendu("définition enregistrée", sauvegarde, true)
if not sauvegarde then dire("raison de l'erreur :", tostring(erreur)) end

local id, raison = LCM.CoffresMJ.Placer("coffre_temoin")
attendu("sans GPS le coffre attend la position serveur", id, nil)
attendu("un GPS est demandé", __chats[#__chats].texte, ".gps")
LCM.DeplacementForce.NoterGPS("100.000000 200.000000 0.000000 585 2.637213")
id, raison = LCM.CoffresMJ.Placer("coffre_temoin")
attendu("coffre posé", id ~= nil, true)
if not id then dire("raison du refus :", tostring(raison)) end
local C, MJ = LCM.Coffres, LCM.CoffresMJ
local p = MJ.Points("coffre_temoin")[1]
attendu("stock initial", p and p.objets[1] and p.objets[1].quantite, 1)
attendu("configuration connue côté client", C.definitions.coffre_temoin ~= nil, true)

dire("== ouvrir, déverrouiller, puis reverrouiller selon la méthode")
C.Ouvrir(id)
attendu("coffre encore verrouillé", p.verrouille, true)
local coffreUI = LCM.UI.Coffre.frame
attendu("les emplacements sont masqués tant que le coffre est verrouillé", coffreUI.grille:IsShown(), false)
attendu("la fenêtre verrouillée est compacte", coffreUI:GetHeight() < 300, true)
local personnage = LCM.Entities.Self()
attendu("outil équipé pour le test", LCM.Objets.Placer(personnage, "outil_temoin"), true)
attendu("un outil équipé compte comme possédé", LCM.UI.Coffre.InventaireTotal(personnage, REF2), 1)
attendu("le bonus d'un objet équipé est pris en compte", LCM.Effets.Bonus(personnage, "vue"), 4)
attendu("objet d'aide rangé dans les sacs", LCM.Inventaire.Deposer(personnage, REF3, 1), true)
attendu("un objet seulement rangé dans les sacs ne donne aucun bonus automatique",
    LCM.Effets.Bonus(personnage, "vue"), 4)
coffreUI.expertise = "vue"
coffreUI.aideCases[1].glisserDepose({ ref = REF3, element = LCM.Objets.Get("aide_temoin"),
    origine = { case = 1 } })
attendu("l'objet glissé reste dans l'inventaire", LCM.UI.Coffre.SacTotal(personnage, REF3), 1)
attendu("son bonus est compté pour l'expertise", coffreUI:BonusAides(coffreUI:MethodeCourante()), 2)
LCM.Entities.SetGauge(personnage, "fatigue", 10)
coffreUI:MettreAJourTentative()
local ancienField = LCM.Roll.Field
local modificateurRecu
LCM.Roll.Field = function(_, _, options)
    modificateurRecu = options and options.modificateur or 0
    return { jets = { 13 }, garde = 13, valeur = 0, apport = 3, bonus = 0,
        modificateur = modificateurRecu, label = "Vue", total = 16 + modificateurRecu }
end
coffreUI.forcer:Click()
LCM.Roll.Field = ancienField
local ok = p.ouvert == true
attendu("expertise autorisée", ok, true)
attendu("le bonus d'objet est appliqué au jet", modificateurRecu, 2)
attendu("le score dépasse bien le DD 15", p.ouvert, true)
attendu("la tentative dépense son coût en fatigue",
    LCM.Entities.Gauge(personnage, "fatigue").current, 7)
attendu("l'outil consommable équipé est retiré", LCM.Objets.EstEquipe(personnage, "outil_temoin"), false)
attendu("l'outil requis a perdu un point de durabilité", LCM.Objets.Usure(personnage, "outil_temoin"), 1)
attendu("l'objet d'aide a perdu un point de durabilité", LCM.Objets.Usure(personnage, "aide_temoin"), 1)
attendu("l'objet d'aide n'a pas quitté le sac", LCM.UI.Coffre.SacTotal(personnage, REF3), 1)
attendu("verrou ouvert", p.verrouille, false)
attendu("ouverture conservée", p.ouvert, true)
C.Envoyer("verrouiller")
attendu("verrou replacé", p.verrouille, true)
attendu("compteur restauré", p.verrousRestants, 1)
local demandeDistance = LCM.Reseau.Decoder(LCM.Reseau.Encoder({
    expertise = "vue", score = 16, total = 16,
}))
C.Envoyer("forcer", demandeDistance)
attendu("nouveau déverrouillage", p.ouvert, true)
C.Envoyer("verrouiller")
coffreUI.expertise = LCM.Coffres.METHODE_CLEF
coffreUI:MettreAJourTentative()
attendu("la méthode Clef masque les objets d'aide", coffreUI.aideCases[1]:IsShown(), false)
local jetClef = false
ancienField = LCM.Roll.Field
LCM.Roll.Field = function() jetClef = true; error("la méthode Clef ne doit pas lancer de jet") end
coffreUI.forcer:Click()
LCM.Roll.Field = ancienField
attendu("la bonne clef ouvre le verrou", p.ouvert, true)
attendu("la méthode Clef ne lance aucun jet", jetClef, false)
attendu("la méthode Clef ne dépense pas de fatigue",
    LCM.Entities.Gauge(personnage, "fatigue").current, 7)
attendu("le nom du coffre remplace le titre générique", coffreUI.titre:GetText(), "COFFRE TÉMOIN")
attendu("le contenu est présenté en grille", coffreUI.cases[1] and coffreUI.cases[1].pile.ref, REF)
attendu("la grille est visible une fois le coffre ouvert", coffreUI.grille:IsShown(), true)
attendu("la fenêtre ouverte s'adapte à son contenu", coffreUI:GetHeight() < 400, true)
attendu("le bouton Verrouiller est centré en bas", coffreUI.verrouiller:GetPoint(), "BOTTOM")
-- La carte se CHARGE au curseur, puis s'epingle (16 octobre 2026) : elle
-- n'apparait plus au premier survol, mais a la fin du chargement — et reste
-- alors, au-dessus de tout, jusqu'a sa croix.
local case1 = coffreUI.cases[1]
case1.__survol = true
case1:GetScript("OnEnter")(case1)
local carte = LCM.UI.Coffre.carteSurvol
attendu("au survol : pas encore de carte", carte:IsShown(), false)
__avancer(0.3, 0.1)
attendu("  un chargement au curseur", LCM.UI.chargementCurseur:IsShown(), true)
-- En anneau (16 octobre 2026) : une moitie de chargement, a peu pres la
-- moitie des segments allumes.
local anneau = LCM.UI.chargementCurseur
attendu("  en anneau de segments", #anneau.segments, 20)
attendu("  qui se remplit", anneau.fraction > 0.3 and anneau.fraction < 0.8, true)
case1.__survol = nil
case1:GetScript("OnLeave")(case1)
__avancer(0.6, 0.1)
attendu("parti avant la fin : rien ne s'ouvre", carte:IsShown(), false)
attendu("  le chargement disparait", LCM.UI.chargementCurseur:IsShown(), false)
case1.__survol = true
case1:GetScript("OnEnter")(case1)
__avancer(0.8, 0.1)
attendu("charge : la carte apparait", carte:IsShown(), true)
attendu("  le survol réutilise la carte du compendium", carte.donnees.nom, "Clé témoin")
attendu("  epinglee", carte.epinglee, true)
attendu("  elle prend la souris", carte:IsMouseEnabled(), true)
attendu("  sa croix est la", carte.fermer:IsShown(), true)
attendu("  le chargement s'efface", LCM.UI.chargementCurseur:IsShown(), false)
case1.__survol = nil
case1:GetScript("OnLeave")(case1)
__avancer(1, 0.1)
attendu("quitter la case ne la ferme pas", carte:IsShown(), true)
carte.basculeStats:Click()
attendu("on deplie ses statistiques", carte.statsRepliees, false)
-- La souris sur la carte : une case qu'elle recouvre ne charge rien (le
-- coffre temoin n'a qu'une case ; on la survole sous la carte).
carte.__survol = true
case1.__survol = true
case1:GetScript("OnEnter")(case1)
__avancer(0.3, 0.1)
attendu("a travers la carte, rien ne charge", LCM.UI.chargementCurseur:IsShown(), false)
case1.__survol = nil
case1:GetScript("OnLeave")(case1)
carte.__survol = nil
carte.fermer:Click()
attendu("la croix la ferme", carte:IsShown(), false)
attendu("  et rend la souris", carte:IsMouseEnabled(), false)
attendu("  la croix se cache", carte.fermer:IsShown(), false)
coffreUI.cases[1]:GetScript("OnClick")(coffreUI.cases[1], "RightButton")
attendu("le clic droit propose Prendre", LCM.UI.menuContexte.lignes[1].texte:GetText(), "Prendre")
attendu("le clic droit propose Voir", LCM.UI.menuContexte.lignes[2].texte:GetText(), "Voir")
LCM.UI.menuContexte:Hide()
p.verrousOuverts, C.etat.vo = { false }, { false }
C.onChange()
attendu("un verrou brisé est signalé", coffreUI.verrousBrises:GetText(), "1 verrou brisé.")
p.verrousOuverts, C.etat.vo = { true }, { true }
C.onChange()

dire("== stock non renouvelable et capacité en emplacements")
C.Envoyer("prendre", { e = REF, q = 1 })
attendu("le contenu est épuisé", #p.objets, 0)
C.Envoyer("prendre", { e = REF, q = 1 })
attendu("une prise après épuisement reste refusée", #p.objets, 0)
C.Envoyer("ranger", { e = REF, q = 1 })
attendu("retour au coffre accepté", p.objets[1] and p.objets[1].quantite, 1)
C.Envoyer("ranger", { e = REF2, q = 1 })
attendu("un deuxième type dépasse la capacité", #p.objets, 1)
attendu("le refus ne modifie pas le contenu", p.objets[1] and p.objets[1].entree, REF)

dire("== le paquet transporte les outils et les expertises")
local paquet = C.Paquet(C.definitions.coffre_temoin, { p })
paquet = LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet))
local def, points = C.Lire(paquet)
attendu("quantité d'outil", def.coffre.outils[1].quantite, 1)
attendu("consommation configurée", def.coffre.outils[1].consomme, true)
attendu("consommation paramétrée", def.coffre.outils[1].consommeQuantite, 1)
attendu("expertise de l'outil transmise", def.coffre.outils[1].expertise, "vue")
local outilsVue = LCM.UI.Coffre.OutilsPour({ outils = {
    { entree = "objets/vue", expertise = "vue" },
    { entree = "objets/puissance", expertise = "puissance" },
    { entree = "objets/ancien" },
} }, "vue")
attendu("seuls les outils de l'expertise choisie sont requis", #outilsVue, 2)
attendu("l'outil d'une autre expertise est ignoré", outilsVue[2].entree, "objets/ancien")
attendu("DD transmis", def.coffre.expertises[1].dd, 15)
attendu("coût en fatigue transmis", def.coffre.expertises[1].fatigue, 3)
attendu("usure des outils requise transmise", def.coffre.expertises[1].usureOutils, true)
attendu("réglage reverrouillable transmis", def.coffre.expertises[1].reverrouillable, true)
attendu("méthode Clef transmise", def.coffre.expertises[2].id, LCM.Coffres.METHODE_CLEF)
attendu("rayon transmis", def.coffre.rayon, 7)
attendu("emplacement conservé", points[1].id, id)
attendu("coffre visible dans son rayon", C.Proche({ [p.source] = { x = p.x + 6, y = p.y, z = p.z } }).id, id)
attendu("coffre invisible hors de son rayon", C.Proche({ [p.source] = { x = p.x + 8, y = p.y, z = p.z } }), nil)
C.definitions.coffre_temoin.coffre.reset = true
LCM.Points.Get("coffre_temoin").coffre.reset = true
C.Envoyer("fermer")
attendu("fermeture et reset auto replacent les verrous", p.verrouille, true)
attendu("le coffre est fermé", p.ouvert, false)

dire("== constructeur MJ et réglages multiples")
LCM.UI.Recoltes.Basculer()
local ressources = LCM.UI.Recoltes.frame
attendu("le constructeur n'est plus enfoui dans Ressources", ressources.boutonCoffres, nil)
attendu("entrée Coffres liée dans le radial", LCM.UI.Menu.EstLiee("coffres"), true)
SlashCmdList.LCM("coffres")
local editeur = LCM.UI.CoffresMJ.frame
attendu("/lcm coffres ouvre la fenêtre de gestion", editeur and editeur:IsShown(), true)
editeur:Nouveau()
editeur.nom:Saisir("Brouillon de coffre")
attendu("onglet Création visible", editeur.creation:IsShown(), true)
attendu("onglet Placement caché", editeur.placement:IsShown(), false)
local function ChoisirDans(popup, id)
    for _, ligne in ipairs(popup.lignes) do
        if ligne:IsShown() and ligne.choix == id then ligne:Click(); return true end
    end
    return false
end
-- 16 octobre 2026 : le tableau a la hauteur de ce qu'il contient (en-tete,
-- lignes, « + Ajouter »), et rien n'y est ajoute tout seul.
local tableau = editeur.creation.tableauObjets
attendu("coffre neuf : aucun objet pose d'office", #editeur.travail.coffre.objets, 0)
local hauteurVide = tableau:GetHeight()
attendu("  le tableau n'a que l'en-tete et l'ajout", hauteurVide, 25 + 28)
editeur.depotObjets:Click()
attendu("la liste d'objets propose le contenu", ChoisirDans(editeur.choixObjet, REF), true)
attendu("  il grandit d'une ligne", tableau:GetHeight(), hauteurVide + 28)
editeur.depotOutils:Click()
attendu("la liste d'objets propose l'outil", ChoisirDans(editeur.choixOutil, REF2), true)
editeur.ajouterExpertise:Click()
attendu("la liste propose une expertise", ChoisirDans(editeur.choixExpertise, "vue"), true)
editeur.ajouterExpertise:Click()
attendu("la liste propose la méthode Clef",
    ChoisirDans(editeur.choixExpertise, LCM.Coffres.METHODE_CLEF), true)
attendu("ligne de contenu créée", editeur.lignesObjets[1] and editeur.lignesObjets[1]:IsShown(), true)
attendu("case de consommation affichée", editeur.lignesOutils[1].consommer:IsShown(), true)
attendu("champ de quantité consommée affiché", editeur.lignesOutils[1].nc:IsShown(), false)
editeur.lignesOutils[1].consommer:Click()
attendu("le champ apparaît quand la consommation est activée", editeur.lignesOutils[1].nc:IsShown(), true)
attendu("expertise ajoutée", editeur.lignesExpertises[1] and editeur.lignesExpertises[1]:IsShown(), true)
attendu("champ de coût en fatigue affiché",
    editeur.lignesExpertises[1].fatigue and editeur.lignesExpertises[1].fatigue:IsShown(), true)
attendu("case d'usure des outils affichée",
    editeur.lignesExpertises[1].usureOutils and editeur.lignesExpertises[1].usureOutils:IsShown(), true)
attendu("la méthode Clef masque son DD", editeur.lignesExpertises[2].dd:IsShown(), false)
attendu("outil associé à l'expertise", editeur.travail.coffre.outils[1].expertise, "vue")
attendu("sélecteur d'expertise de l'outil affiché",
    editeur.lignesOutils[1].expertise and editeur.lignesOutils[1].expertise:IsShown(), true)
editeur:Choisir("coffre_temoin")
attendu("rayon affiché dans le constructeur", editeur.rayon:GetText(), "7")
attendu("un modèle chargé n'est pas considéré comme modifié", editeur:Modifie(), false)
attendu("le message de modifications disparaît après sélection", editeur.placement.etatEdition:GetText(), "")
editeur.rayon:Saisir("8")
editeur:Onglet("placement")
attendu("onglet Placement visible", editeur.placement:IsShown(), true)
attendu("onglet Création caché", editeur.creation:IsShown(), false)
attendu("placement disponible avec des modifications non enregistrées", editeur.poser:IsEnabled(), true)
local nombreAvantPose = #LCM.CoffresMJ.Points("coffre_temoin")
editeur.poser:Click()
attendu("le clic enregistre et place le coffre", #LCM.CoffresMJ.Points("coffre_temoin"), nombreAvantPose + 1)
attendu("le réglage modifié a été enregistré", LCM.Points.Get("coffre_temoin").coffre.rayon, 8)
attendu("le placement ne laisse pas de modification en attente", editeur:Modifie(), false)
local poseSupplementaire = editeur.pointPose
LCM.CoffresMJ.Retirer(poseSupplementaire)
editeur.rayon:Saisir("0")
editeur:Onglet("placement")
local nombreAvantRefus = #LCM.CoffresMJ.Points("coffre_temoin")
editeur.poser:Click()
attendu("un modèle invalide n'est pas placé", #LCM.CoffresMJ.Points("coffre_temoin"), nombreAvantRefus)
editeur.rayon:Saisir("7")
editeur:Enregistrer()
attendu("placement listé pour sa définition", editeur.placements[1] and editeur.placements[1]:IsShown(), true)
editeur.placements[1]:Click()
attendu("un placement peut être sélectionné", editeur.pointPose, id)
attendu("le bouton de retrait apparaît", editeur.retirer:IsShown(), true)
local chatsAvant = #__chats
editeur.placements[1].teleporter:Click()
attendu("le placement propose la téléportation",
    __chats[#__chats] and __chats[#__chats].texte,
    ".worldport 100.000000 200.000000 0.000000 585")
attendu("une seule commande de téléportation", #__chats - chatsAvant, 1)
p.z = nil
local commandesAvant = #__chats
local ancienOk = LCM.CoffresMJ.Teleporter(id)
attendu("ancien coffre sans altitude : téléportation refusée", ancienOk, false)
attendu("aucune commande risquée n'est envoyée", #__chats, commandesAvant)
p.mapid, p.z = 585, -81.5
editeur.placements[1].teleporter:Click()
attendu("mapid et altitude transmis à worldport", __chats[#__chats].texte,
    ".worldport 100.000000 200.000000 -81.500000 585")
p.source = "gps"
editeur.placements[1].teleporter:Click()
attendu("coordonnées GPS transmises sans échange des axes", __chats[#__chats].texte,
    ".worldport 100.000000 200.000000 -81.500000 585")
p.source = "monde"
p.mapid, p.z = nil, 0
LCM.DeplacementForce.NoterGPS("100.000000 200.000000 -386.359375 585 2.637213")
editeur.placements[1].teleporter:Click()
attendu("ancien coffre réparé depuis son emplacement", p.z, -386.359375)
attendu("carte serveur corrigée", p.mapid, 585)
attendu("téléportation avec altitude réparée", __chats[#__chats].texte,
    ".worldport 100.000000 200.000000 -386.359375 585")
LCM.DeplacementForce.NoterGPS("Map: 585 (Magisters' Terrace)")
LCM.DeplacementForce.NoterGPS("X: 11275.129883, Y: 11090.638672, Z: -81.208794")
attendu("mapid GPS lu même si la réponse est sur deux lignes",
    LCM.DeplacementForce.CarteGPS(), 585)
editeur:Hide()

dire("== édition MJ sur le médaillon et réinitialisation des verrous")
LCM.UI.Coffre.Proche(p)
local interaction = LCM.UI.Coffre.bouton
attendu("clic droit disponible sur l’icône MJ", interaction.editer:IsShown(), true)
attendu("coffre encore verrouillé avant édition", p.verrouille, true)
interaction.editer:Click("RightButton")
attendu("clic droit ouvre le mode édition", coffreUI.edition, true)
attendu("encart d’édition visible", coffreUI.modeEdition:IsShown(), true)
attendu("contenu visible en édition malgré le verrou", coffreUI.grille:IsShown(), true)
attendu("l’édition ne déverrouille pas le coffre", p.verrouille, true)
attendu("reset disponible en édition", coffreUI.resetVerrous:IsShown(), true)
C.Envoyer("prendre", { e = REF, q = 1 })
attendu("le MJ édite le contenu d’un coffre verrouillé", #p.objets, 0)
C.Envoyer("ranger", { e = REF, q = 1 })
attendu("le MJ peut y replacer le contenu", p.objets[1].quantite, 1)
p.verrouille, p.ouvert, p.verrousRestants, p.verrousOuverts = false, true, 0, { false }
MJ.Traiter("Syn-Apertus", { i = id, a = "reset_verrous", edition = true })
attendu("un joueur ne peut pas réinitialiser les verrous", p.verrousRestants, 0)
coffreUI.resetVerrous:Click()
attendu("reset restaure le verrou", p.verrouille, true)
attendu("reset restaure le compteur", p.verrousRestants, 1)
attendu("reset efface les verrous brisés", #p.verrousOuverts, 0)
attendu("le mode édition reste ouvert après reset", coffreUI.grille:IsShown(), true)
coffreUI:Hide()
attendu("fermer l’éditeur coupe le mode édition", C.edition, false)
LCM.DeplacementForce.NoterGPS("100.000000 200.000000 -386.359375 585 2.637213")
interaction.editer:Click("LeftButton")
attendu("clic gauche garde l’ouverture ordinaire", coffreUI.edition, false)
attendu("le joueur ne voit pas le contenu verrouillé", coffreUI.grille:IsShown(), false)
coffreUI:Hide()

dire("== la hauteur est prise en compte pour voir et utiliser le coffre")
LCM.DeplacementForce.NoterGPS("100.000000 200.000000 -186.359375 585 2.637213")
attendu("200 m au-dessus : pas de coffre à portée", C.Proche(), nil)
attendu("200 m au-dessus : ouverture refusée", C.Ouvrir(id), false)
attendu("200 m au-dessus : aucune action possible", C.Envoyer("prendre", { e = REF, q = 1 }), false)
LCM.DeplacementForce.NoterGPS("100.000000 200.000000 -386.359375 585 2.637213")
attendu("à la bonne hauteur : coffre de nouveau à portée", (C.Proche() or {}).id, p.id)

dire("== retirer un placement le fait disparaître immédiatement")
attendu("retrait accepté", MJ.Retirer(id), true)
attendu("placement retiré du magasin MJ", MJ.Points("coffre_temoin")[1], nil)
attendu("placement retiré du client local", C.points[id], nil)
attendu("fenêtre du coffre refermée", coffreUI:IsShown(), false)

if ko > 0 then error(tostring(ko) .. " vérification(s) en échec") end
dire("TOUT PASSE")
