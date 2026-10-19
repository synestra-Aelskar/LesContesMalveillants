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
-- Ce qu'un coffre accueille, en plus des objets et des livres (le MJ,
-- 19 octobre 2026) : les ressources, et les monnaies qui ont une FORME.
LCM.Ressources.Add({ id = "herbe_coffre", label = "Herbe témoin" })
LCM.Sacs.Add({ id = "sac_coffre", label = "Sac témoin", places = 6, pileMax = 1 })
LCM.Devises.Add({ id = "piece_coffre", label = "Pièce témoin", materiel = true })
LCM.Devises.Add({ id = "jeton_coffre", label = "Jeton témoin" })
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

-- Poser un coffre demande une position SERVEUR : depuis le 17 octobre 2026,
-- l'addon exige une reponse de .gps et ne se contente plus de la carte. Le
-- banc en joue une, comme le guetteur de chat le ferait.
local GPS = "Map: 585 (Magisters' Terrace) Zone: 0 ( <unknown> ), Area: 0 ( <unknown> ), "
    .. "Phase: 158070, X: 11275.129883, Y: 11090.638672, Z: -81.208794, O: 1.904451"
LCM.DeplacementForce.NoterGPS(GPS)

local id, raison = LCM.CoffresMJ.Placer("coffre_temoin")
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
C.onChange()
dire("== garnir un coffre depuis le compendium")
-- Sortir un objet du compendium CREE un exemplaire : geste de MJ, comme pour
-- les sacs. Il fallait en plus le « mode edition », qui ne s'ouvre que sur un
-- coffre qu'on a soi-meme pose et qui n'est pas au sol — garnir en seance le
-- coffre d'un autre etait donc impossible (19 octobre 2026).
local libre
for _, c in ipairs(coffreUI.cases) do if c:IsShown() and not c.pile then libre = libre or c end end
attendu("une case libre dans le coffre", libre ~= nil, true)
local duCompendium = { ref = REF2, categorie = "objets",
    element = LCM.Compendium.Resoudre(REF2) }
attendu("hors mode édition, le MJ peut garnir",
    (libre.glisserAccepte(duCompendium)), true)
-- Et un joueur, non : il fabriquerait un objet.
LCM.BasculerModeJoueur(true)
local refuse, pourquoi = libre.glisserAccepte(duCompendium)
attendu("un joueur ne peut pas", refuse, false)
attendu("  et on dit pourquoi", tostring(pourquoi):find("maître du jeu", 1, true) ~= nil, true)
LCM.BasculerModeJoueur(false)
-- Ce qui vient d'un sac reste accepte des deux cotes.
attendu("ce qu'on possède passe toujours",
    (libre.glisserAccepte({ ref = REF2, origine = { onglet = "sacs", index = 1, case = 1 } })), true)
-- Aucune categorie du compendium ne s'appelle « objets » : celle d'une epee
-- s'appelle « armes », celle d'un anneau « accessoires ». La fenetre
-- reconnaissait l'entree a ce nom, et seuls les livres entraient — glisser une
-- epee s'entendait repondre qu'elle n'etait pas dans l'inventaire
-- (19 octobre 2026). C'est la famille de la reference qui dit ce qu'elle est.
attendu("une entrée nommée par sa vraie catégorie passe",
    (libre.glisserAccepte({ ref = REF2, categorie = "accessoires",
        element = LCM.Compendium.Resoudre(REF2) })), true)

dire("== le coffre accueille ressources et devises (le MJ, 19 octobre 2026)")
local function accueil(ref, categorie)
    return libre.glisserAccepte({ ref = ref, categorie = categorie,
        element = LCM.Compendium.Resoudre(ref) })
end
attendu("une ressource", (accueil("ressources/herbe_coffre", "ressources")), true)
attendu("un sac", (accueil("sacs/sac_coffre", "sacs")), true)
attendu("une monnaie matérielle", (accueil("devises/piece_coffre", "devises")), true)
local refusee, raisonDevise = accueil("devises/jeton_coffre", "devises")
attendu("une monnaie qui n'est qu'un compte, non", refusee, false)
attendu("  et on dit où elle vit", tostring(raisonDevise):find("bourse", 1, true) ~= nil, true)
attendu("un PNJ non plus", (accueil("pnj/assassin_du_culte", "pnj")), false)
-- Et le proprietaire arbitre selon la MEME regle : la fenetre et lui ne
-- peuvent pas dire deux choses differentes.
attendu("le propriétaire accepte la ressource",
    (LCM.Coffres.Accepte("ressources/herbe_coffre")), true)
attendu("  et refuse le jeton", (LCM.Coffres.Accepte("devises/jeton_coffre")), false)
C.Envoyer("prendre", { e = REF, q = 1 })
attendu("une prise après épuisement reste refusée", #p.objets, 0)
C.Envoyer("ranger", { e = REF, q = 1 })
attendu("retour au coffre accepté", p.objets[1] and p.objets[1].quantite, 1)
C.Envoyer("ranger", { e = REF2, q = 1 })
attendu("un deuxième type dépasse la capacité", #p.objets, 1)
attendu("le refus ne modifie pas le contenu", p.objets[1] and p.objets[1].entree, REF)

dire("== un emplacement tient toute une pile (le MJ, 19 octobre 2026)")
-- Une entree sans pile maximale n'occupe qu'UN emplacement, quelle qu'en soit
-- la quantite. Le compte en prenait un par unite : cinquante pieces
-- remplissaient cinquante emplacements, alors que la fenetre n'en montrait
-- qu'une pile. Les deux regles vivaient dans quatre fonctions ; elles n'en
-- font plus qu'une (LCM.Coffres.Places).
p.objets = {}
C.Envoyer("ranger", { e = "devises/piece_coffre", q = 50 })
attendu("cinquante pièces entrent", p.objets[1] and p.objets[1].quantite, 50)
attendu("  dans un seul emplacement", #p.objets, 1)
C.Envoyer("ranger", { e = "ressources/herbe_coffre", q = 40 })
attendu("et le coffre est plein", #p.objets, 1)
C.Envoyer("ranger", { e = "devises/piece_coffre", q = 25 })
attendu("la même pile s'épaissit sans place de plus",
    p.objets[1] and p.objets[1].quantite, 75)
-- Ce qui a une pile maximale garde son compte : la clef s'empile par une.
p.objets = {}
C.Envoyer("ranger", { e = REF, q = 1 })
attendu("une clé entre", p.objets[1] and p.objets[1].quantite, 1)
C.Envoyer("ranger", { e = REF, q = 1 })
attendu("  la seconde dépasse la capacité", p.objets[1] and p.objets[1].quantite, 1)

dire("== une definition de coffre garde ce qu'un coffre accueille")
-- Le geste passait, le CHARGEMENT ecartait : la construction d'une definition
-- gardait sa propre regle (« objets et livres »), et un coffre garni d'une
-- ressource ou d'un sac disparaissait au /reload suivant, avec tout son
-- contenu (20 octobre 2026). Les deux lisent maintenant la meme liste.
local garni = { id = "coffre_garni_temoin", label = "Coffre garni", nature = "coffre",
    coffre = { places = 6, rayon = 4, verrous = 0, reset = false, expertises = {}, outils = {},
        objets = { { entree = REF, quantite = 1 },
                   { entree = "ressources/herbe_coffre", quantite = 7 },
                   { entree = "sacs/sac_coffre", quantite = 1 },
                   { entree = "devises/piece_coffre", quantite = 40 } } } }
local okGarni, raisonGarni = LCM.Brouillons.Enregistrer("points", garni, true)
attendu("la définition est acceptée", okGarni, true)
if not okGarni then dire("     raison du refus :", tostring(raisonGarni)) end
local relu = LCM.Points.Get("coffre_garni_temoin")
attendu("  et elle se recharge entière", relu and #relu.coffre.objets, 4)
attendu("  la ressource y est", (function()
    for _, o in ipairs(relu and relu.coffre.objets or {}) do
        if o.entree == "ressources/herbe_coffre" then return o.quantite end
    end
end)(), 7)
attendu("  le sac aussi", (function()
    for _, o in ipairs(relu and relu.coffre.objets or {}) do
        if o.entree == "sacs/sac_coffre" then return true end
    end
    return false
end)(), true)
-- Et ce qui n'est pas rangeable reste refuse : un PNJ dans un coffre n'a
-- aucun sens, et le refus doit continuer a se voir.
local okPnj = LCM.Brouillons.Enregistrer("points", { id = "coffre_pnj_temoin",
    label = "Coffre absurde", nature = "coffre",
    coffre = { places = 1, rayon = 4, verrous = 0, reset = false, expertises = {}, outils = {},
        objets = { { entree = "pnj/assassin_du_culte", quantite = 1 } } } }, true)
attendu("un PNJ dans un coffre : refusé", okPnj, false)

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
-- La distance se mesure sur TROIS axes depuis le 17 octobre 2026 (« y compris
-- en hauteur ») : une position sans z ne peut plus etre comparee.
attendu("coffre visible dans son rayon",
    C.Proche({ [p.source] = { x = p.x + 6, y = p.y, z = p.z } }).id, id)
attendu("coffre invisible hors de son rayon",
    C.Proche({ [p.source] = { x = p.x + 8, y = p.y, z = p.z } }), nil)
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
editeur:Onglet("placement")
attendu("onglet Placement visible", editeur.placement:IsShown(), true)
attendu("onglet Création caché", editeur.creation:IsShown(), false)
attendu("placement listé pour sa définition", editeur.placements[1] and editeur.placements[1]:IsShown(), true)
editeur.placements[1]:Click()
attendu("un placement peut être sélectionné", editeur.pointPose, id)
attendu("le bouton de retrait apparaît", editeur.retirer:IsShown(), true)
editeur:Hide()

dire("== retirer un placement le fait disparaître immédiatement")
attendu("retrait accepté", MJ.Retirer(id), true)
attendu("placement retiré du magasin MJ", MJ.Points("coffre_temoin")[1], nil)
attendu("placement retiré du client local", C.points[id], nil)
attendu("fenêtre du coffre refermée", coffreUI:IsShown(), false)

if ko > 0 then error(tostring(ko) .. " vérification(s) en échec") end
dire("TOUT PASSE")
