-- Equilibrage : tous les nombres du jeu, au meme endroit.
--
-- Aucune formule ne code un nombre en dur. Regler le jeu se fait ici, sans
-- toucher a la logique — c'est l'equivalent de l'onglet « Equilibrage » de
-- Necronicon, mais lisible d'un coup d'oeil et versionne.
--
-- Valeurs relevees dans la feuille Necronicon (onglets Level, Cout Secondaires,
-- Limites repartitions points, Deplacement).

local _, LCM = ...

local E = {}
LCM.Equilibrage = E

-- ===== Formules de fiche ===================================================
-- Releve du TEMPLATE Necronicon (« Template Fiche LVL 5 - Contes Malveillants
-- V2 », fenetre Equilibrage et formules de la fenetre Creation). C'est lui qui
-- fait foi : l'utilisateur l'a designe comme la source des regles.

-- PV max = base + parNiveau x niveau + parVitalite x (points secondaires)
--        + constitution totale x (2 + constitution investie x 0,25)
E.pv = {
    base = 2,
    parNiveau = 1.5,
    parVitalite = 3,          -- points secondaires investis en vitalite
    constitution = { base = 2, parConstitution = 0.25 },
    -- Chaque zone du corps vaut ce pourcentage des PV max (« Modif pv par
    -- zone »). Les zones se chevauchent : ensemble, elles depassent le total.
    parZone = 0.30,
}

-- Fatigue max = base + 2 x constitution + esprit + 2 x niveau
--             + Endurance (expertise) / diviseurEndurance + 3 x (pts secondaires)
E.fatigue = {
    base = 15,
    parNiveau = 2,
    parEsprit = 1,
    parConstitution = 2,
    diviseurEndurance = 1,    -- l'expertise Endurance, totale
    parSecondaire = 3,        -- points secondaires investis en fatigue
}

-- Initiative = points secondaires + niveau / 2 + esprit / 2 + perception / 2.
-- Le template DIVISE (« Initiative / lvl = 2 ») : deux niveaux font un point.
-- Il declare aussi une « Base initiative = 1 » que sa formule n'utilise pas ;
-- on suit la formule.
E.initiative = {
    diviseurNiveau = 2,
    diviseurEsprit = 2,
    diviseurPerception = 2,
}

-- Le deroule d'un combat (bandeau d'initiative, Core/Combat.lua). Ces reglages
-- ne sont pas dans le template de fiche : ils viennent du Panel MJ du profil
-- Necronicon des Contes (window_master) — initiativeTrackTurns et
-- initiativeTrackRounds vrais, initiativeRoundMax = 3, annonces du tour, du
-- round et du combattant actif dans le canal Raid.
-- Un tour = roundsParTour passages complets de la liste ; le compteur de tour
-- n'avance qu'au dernier.
E.combat = {
    roundsParTour = 3,
    annonces = "RAID",
}

-- Les nombres des ACTIONS (attaque, bouclier, soin, buff, controles), releves
-- dans l'onglet « Equilibrage ACTIONS » de la fenetre Equilibrage du template.
-- Les resolutions du compendium les citent par leur libelle
-- ({stat:Base buff Pen}) ou par leur champ ([[...custom_11::field_221...]]) :
-- la table de correspondance est dans Core/Actions.lua. Libelles du template
-- gardes en commentaire, pour qu'on retrouve d'ou vient chaque nombre.
E.actions = {
    -- ATTAQUES
    multiForce = 1.2,            -- Base multi Force (field_221)
    multiMystique = 0.8,         -- Base multi Mystique (field_223)
    multiPerception = 1,         -- Base multi Perception (field_224)
    -- DEFENSE
    baseConstitution = 1,        -- Base constitution (field_226)
    reductionMod = 3,            -- Equilibrage reduction Mod (field_244)
    baseDefense = 80,            -- Base défense (field_269)
    defenseParPoint = 5,         -- Défense par point (field_270)
    -- BOUCLIER
    bouclierForce = 0.2,         -- Base bouclier Force (field_227)
    bouclierMystique = 1,        -- Base bouclier Mystique (field_228)
    bouclierConstitution = 0.5,  -- Base bouclier Constitution (field_229)
    multiBouclier = 1.5,         -- Multiplicateur Bouclier
    multiStatBouclier = 1.5,     -- Multiplicateur Stat BOUCLIER
    multiPenBouclier = 1.5,      -- Multiplicateur Pen BOUCLIER
    multiFatigueBouclier = 4,    -- Multiplicateur Fatigue BOUCLIER
    coutPABouclier = 1,          -- Cout PA BOUCLIER
    -- SOIN
    soinMystique = 0.5,          -- Base soin Mystique (field_231)
    soinConstitution = 0.25,     -- Base soin Constitution (field_230)
    multiSoin = 1.25,            -- Multiplicateur SOIN
    multiStatSoin = 1.25,        -- Multiplicateur Stat SOIN
    multiPenSoin = 1.25,         -- Multiplicateur Pen SOIN
    multiFatigueSoin = 3,        -- Multiplicateur Fatigue SOIN
    coutPASoin = 1,              -- Cout PA SOIN
    -- BUFF
    buffForce = 0.2,             -- Base buff Force
    buffConstitution = 0.4,      -- Base buff Constitution
    buffPerception = 0.4,        -- Base buff Perception
    buffMystique = 0.8,          -- Base buff Mystique
    buffPen = 0.8,               -- Base buff Pen
    multiBuff = 1,               -- Multiplicateur BUFF
    multiStatBuff = 1,           -- Multiplicateur stat BUFF
    multiPenBuff = 2,            -- Multiplicateur pen BUFF
    attractionParStat = 0.5,     -- Attraction par stat
    attractionParPen = 0.25,     -- Attraction par Pen
    repulsionParStat = 0.5,      -- Répulsion par stat
    repulsionParPen = 0.25,      -- Répulsion par Pen
    -- CONTROL
    immobilisationParStat = 0.25, -- Immobilisation par stat
    immobilisationParPen = 0.1,   -- Immobilisation par Pen
    entraveParStat = 0.25,        -- Entrave par stat
    entraveParPen = 0.1,          -- Entrave par Pen
    permutationParStat = 0.5,     -- Permutation par stat
    permutationParPen = 0.25,     -- Permutation par Pen
    -- DEVIATION
    deviationParStat = 0.25,      -- Déviation par stat
    deviationParPen = 0.1,        -- Déviation par Pen
    deviationMalusDistance = 3,   -- Déviation malus distance
    deviationMalusAutrui = 3,     -- Déviation malus autrui
    interventionBonusDeplacement = 25, -- Intervention bonus déplacement
    deviationBonusActionPropre = 25,   -- Déviation bonus action propre
}

-- Le cout d'une reaction a une action qui nous vise (Core/Reactions.lua).
-- Releve du « Bloc D » de Necronicon (Reactions.lua, table COST), que le
-- template ne chiffre pas : une deviation coute le PA de l'action recue
-- (`pa` n'est que le repli quand elle n'en dit rien) et 5 PF ; une
-- intervention, 1 PA et 3 PF.
E.reactions = {
    deviation = { pa = 2, pf = 5, paDeLAction = true },
    intervention = { pa = 1, pf = 3 },
}

-- Un jet « inadapte » : on oppose Adresse a un jet d'Esprit, ou l'inverse. Le
-- template (fenetre Actions de combat, « Adresse Inadapté » / « Esprit
-- Inadapté ») lance le meme de, mais ne compte la primaire qu'a ce taux :
-- « Malus inadapté » de l'onglet « Mod Statistiques » (field_192).
E.malusInadapte = 0.8

-- La puissance d'une mecanique de competence, en pourcentage : base + par
-- point investi + par point d'equipement. Releve de la grille « Mecaniques de
-- competence » (onglet « Equilibrage puissance action », field_258) : les
-- vingt et une lignes y portent les memes valeurs, 70 / 5 / 5. Une mecanique
-- qui en voudrait d'autres prend une entree a son id dans `parMecanique`.
E.puissanceMecanique = {
    base = 70,
    parPoint = 5,
    equipParPoint = 5,
    parMecanique = {},
}

-- Points d'action max = base + points secondaires investis.
E.pa = { base = 4 }

-- Deplacement = base + points investis dans l'expertise (Course / Nage)
--             + parSecondaire x points secondaires « Deplacement ».
E.deplacement = {
    terrestre = 8,
    nage = 5,
    vol = 0,
    parSecondaire = 1,
    -- Regle de Necronicon (Deplacement.lua) : UN deplacement gratuit par round,
    -- puis un supplementaire qui coute 1 PA et 1 PF. Au-dela, plus rien.
    parRound = 2,
    supplementPA = 1,
    supplementPF = 1,

    -- L'arrivee, reprise de Necronicon : on ralentit le personnage le temps
    -- qu'il s'arrete, et on lui pose une aura qui MARQUE sa position. Sans ca,
    -- « c'est fait » arrive quand on court encore, et on finit trois metres
    -- plus loin que la ou on avait le droit d'aller.
    --
    -- Ce sont des commandes serveur (`.mod speed`, `.aura`) envoyees par le
    -- chat, comme MoveMaster : le client ne laisse pas un addon les taper
    -- autrement. `aura = 0` les desactive entierement.
    aura = 333403,
    vitesseArret = 0.1,
    vitesseNormale = 0.8,
    secondesArret = 2,
    -- « auto » : guilde, sinon raid, sinon groupe. Rien en dehors : le client
    -- refuse le /dire d'un addon.
    canalCommandes = "auto",
}

-- Facultes (template, fenetre Equilibrage › Quotidien et Deplacement) :
-- poids soulevable = base + parForce x Force ; sauts = Force / a + Adresse / b.
E.quotidien = { poidsBase = 5, poidsParForce = 5 }
E.sauts = {
    horizontal = { diviseurForce = 2, diviseurAdresse = 3 },
    vertical   = { diviseurForce = 2, diviseurAdresse = 4 },
}

-- ===== Experience =========================================================
-- A VALIDER. Le template n'a AUCUNE table d'experience de personnage : il n'a
-- que celle des metiers, juste en dessous. Ces paliers sont donc le seul
-- chiffre de ce fichier qui ne vienne de nulle part — a trancher en jeu.
--
-- Les paliers sont CUMULATIFS : `xp` est le total qu'il faut avoir amasse pour
-- etre de ce niveau. La forme suit celle des metiers (chaque palier coute a
-- peu pres le double du precedent), parce qu'on sait deja qu'elle tient a
-- l'usage dans cette campagne.
E.experience = {
    niveauDepart = 5,
    paliers = {
        { niveau = 6,  xp = 100 },
        { niveau = 7,  xp = 250 },
        { niveau = 8,  xp = 500 },
        { niveau = 9,  xp = 1000 },
        { niveau = 10, xp = 2000 },
    },
}

-- ===== Metiers ============================================================
-- Table « XP METIER » du template : l'XP pour PASSER au palier suivant
-- (incrementale). La couleur suit le nom du palier.
E.metiers = {
    paliers = {
        { nom = "Rose",   xp = 5,    couleur = { 1.00, 0.55, 0.75 } },
        { nom = "Vert",   xp = 20,   couleur = { 0.40, 0.85, 0.40 } },
        { nom = "Bleu",   xp = 50,   couleur = { 0.40, 0.65, 1.00 } },
        { nom = "Orange", xp = 100,  couleur = { 1.00, 0.60, 0.20 } },
        { nom = "Rouge",  xp = 200,  couleur = { 0.95, 0.30, 0.30 } },
        { nom = "Violet", xp = 500,  couleur = { 0.70, 0.45, 0.95 } },
        { nom = "Noir",   xp = 2500, couleur = { 0.55, 0.55, 0.55 } },
    },
}

-- ===== Conteneurs ========================================================
-- Combien d'elements chaque conteneur de fiche accueille (template) : pas de
-- place precise, un emplacement accueille n'importe quel element de sa
-- categorie. Objets valides par l'utilisateur ; le reste releve des
-- conteneurs du template (Sante, Apprentissage).

E.conteneurs = {
    -- Deux mains : une arme et un bouclier, ou une seule arme qui prend les
    -- deux (son champ « emplacements »). 5 octobre 2026.
    arme = 2,             -- Equipements › Armes
    equipement = 5,       -- Equipements › Armures et vetements
    accessoire = 5,       -- Equipements › Accessoires
    etat = 30,            -- Sante › Etats divers
    maladie = 10,         -- Sante › Etats de maladies
    intangible = 10,      -- Sante › Etats intangibles
    apprentissage = 60,   -- Apprentissage
    traits = 10,          -- Creation › Traits (conteneur « Traits », 10 places)
}

-- ===== Armure portee ========================================================
-- ECART VOULU (decision du 2 octobre 2026) : dans le template, le tag #armure
-- des attaques ne visait aucune jauge. Ici, chaque piece d'armure equipee
-- (Equipements › Armures et vetements) apporte sa valeur d'armure, et la
-- jauge #armure compte les degats que les pieces portees ont encaisses sur
-- leur total. Sans rien sur le dos : 0 / 0. Un t-shirt : 0 / 2.
-- `parDefaut` : la valeur d'une armure dont l'atelier n'a pas fixe la sienne.

E.armure = {
    parDefaut = 2,
}

-- ===== Forge ================================================================
-- Le cout d'un point dans une statistique qu'un jeu d'equilibrage ne regle
-- pas (Core/Forge.lua). Repris de Necronicon (GetForgeStatCost : 1 quand rien
-- n'est fixe). Les pools des raretes et les autres couts sont decides par le
-- MJ en creant chaque jeu, pas ici (decision du 3 octobre 2026).

E.forge = {
    coutParDefaut = 1,
}

-- ===== Inventaires ==========================================================
-- Les emplacements de la fenetre Inventaires du template, par onglet : deux
-- sacs, quatre saccoches, un emplacement de devise (inventoryWindows ›
-- window_custom_10). Ce qu'un sac contient, lui, vient du sac (ses places).

E.inventaire = {
    sacs = 2,
    saccoches = 4,
    -- `devises` retire avec son onglet : voir Data/Inventaire.lua.
}

-- ===== Budgets de creation =================================================
-- Tout se lit au niveau courant : un PNJ cree directement au niveau 9 recoit
-- le budget de son niveau, sans table a maintenir par palier.

E.creation = {
    niveauDepart = 5,
    primaires   = { base = 17, parNiveau = 3 },
    secondaires = { base = 12, parNiveau = 4 },
    expertises  = { base = 8,  parNiveau = 2 },
    mecaniques  = { base = 2,  parNiveau = 3 },
    -- Traits : 2 au depart, puis un point tous les cinq niveaux. Un trait
    -- coute de 1 a 4 points selon sa force.
    traits      = { base = 2, niveauxParPoint = 5 },
}

-- Ce qu'un point secondaire rapporte quand on l'investit dans un pool.
E.conversion = {
    expertises = 2,           -- 1 point secondaire = 2 points d'expertise
    mecaniques = 1,
}

-- ===== Plafonds ============================================================
-- Ils ne limitent PAS le budget, seulement ce qu'on peut mettre dans une
-- ligne : c'est ce qui pousse aux archetypes plutot qu'aux profils plats.

-- Une statistique primaire : 4 + niveau (9 au niveau 5). Adresse et Esprit
-- coutent deux points et plafonnent plus bas (2 + niveau) : ce sont les deux
-- statistiques qui touchent a tout, elles se paient.
E.primaire = { plafond = { base = 4, parNiveau = 1 }, cout = 1 }

-- Une expertise : 5 + niveau.
E.expertise = { plafond = { base = 5, parNiveau = 1 } }

-- Penetration d'un type : 3 + (force + mystique + perception) / 1,75, arrondi
-- a l'inferieur. Plus on investit dans les trois statistiques de degats, plus
-- on peut se specialiser dans un type.
E.penetration = {
    -- Points a repartir sur les quinze types. LECTURE A CONFIRMER : relevee de
    -- la feuille Necronicon (Base Pene 5, Pene/lvl 0.5, Pene/Stat 0.5, stat
    -- secondaire Penetration 4), mais l'utilisateur n'a valide que le plafond.
    points = { base = 5, parNiveau = 0.5, parStatDeDegats = 0.5, parSecondaire = 4 },
    plafond = { base = 3, diviseurStats = 1.75 },
}

-- Resistance d'un type : 3 + constitution / 4, arrondi a l'inferieur.
E.resistance = {
    -- Meme reserve que pour la penetration : chiffres releves, lecture a
    -- confirmer (Base Resi 5, Resi/lvl 1.5, Resi/consti 3, Resi/esprit 2,
    -- stat secondaire Resistance 3).
    points = { base = 5, parNiveau = 1.5, parConstitution = 3, parEsprit = 2, parSecondaire = 3 },
    -- Plafond d'un type (grille de la Creation du template) : 3 + Constitution
    -- / 0,25, soit 3 + 4 x Constitution. Le texte d'aide du template annonce
    -- « Constitution x 2 + 3 » ; c'est la formule qui fait foi.
    plafond = { base = 3, parConstitution = 4 },
}

-- ===== Statistiques secondaires ============================================
-- `cout` : ce que coute UN point dans ce pool.
-- `plafond` : combien de points on peut y mettre, au niveau courant.
-- L'ordre est celui de l'ecran de creation.

E.secondaires = {
    { id = "sec_vitalite",    label = "Vitalité",                cout = 1, plafond = { parNiveau = 2 } },
    { id = "sec_fatigue",     label = "Fatigue",                 cout = 1, plafond = { parNiveau = 2 } },
    { id = "sec_initiative",  label = "Initiative",              cout = 1, plafond = { parNiveau = 3 } },
    -- Le point d'action est la ressource rare : huit points secondaires, et un
    -- plafond qui ne monte que d'un niveau sur trois.
    { id = "sec_pa",          label = "Points d'action",         cout = 8, plafond = { base = 1, parNiveau = 1 / 3 } },
    { id = "sec_deplacement", label = "Déplacement",             cout = 2, plafond = { parNiveau = 2 } },
    { id = "sec_penetration", label = "Pénétration",             cout = 1, plafond = { parNiveau = 2 } },
    { id = "sec_resistance",  label = "Résistance",              cout = 1, plafond = { parNiveau = 2 } },
    -- Le template fait payer DEUX points secondaires par point d'expertises.
    { id = "sec_expertises",  label = "Expertises",              cout = 2, plafond = { parNiveau = 2 } },
    { id = "sec_mecanique",   label = "Mécanique de compétence", cout = 1, plafond = { parNiveau = 2 } },
}

-- ===== Types de degats =====================================================
-- Les memes quinze types servent en penetration et en resistance ; les champs
-- de fiche en sont engendres (`pen_feu`, `resi_feu`...).

E.types = {
    { id = "tranchant",   label = "Tranchant",   groupe = "Physiques" },
    { id = "perforant",   label = "Perforant",   groupe = "Physiques" },
    { id = "contondant",  label = "Contondant",  groupe = "Physiques" },
    { id = "feu",         label = "Feu",         groupe = "Élémentaires" },
    { id = "eau",         label = "Eau",         groupe = "Élémentaires" },
    { id = "vent",        label = "Vent",        groupe = "Élémentaires" },
    { id = "terre",       label = "Terre",       groupe = "Élémentaires" },
    { id = "esprit",      label = "Esprit",      groupe = "Élémentaires" },
    { id = "pourriture",  label = "Pourriture",  groupe = "Élémentaires" },
    { id = "lumiere",     label = "Lumière",     groupe = "Cosmiques" },
    { id = "ombre",       label = "Ombre",       groupe = "Cosmiques" },
    { id = "ordre",       label = "Ordre",       groupe = "Cosmiques" },
    { id = "desordre",    label = "Désordre",    groupe = "Cosmiques" },
    { id = "vie",         label = "Vie",         groupe = "Cosmiques" },
    { id = "mort",        label = "Mort",        groupe = "Cosmiques" },
}

E.groupesTypes = { "Physiques", "Élémentaires", "Cosmiques" }

-- ===== Mecaniques de competence ============================================
-- Ce qu'une competence sait FAIRE. Relevees de la grille « Mecanique de
-- competence » de Necronicon, dans l'ordre de la feuille. Une mecanique se
-- plafonne comme une expertise (5 + niveau) : c'est le meme champ de limite
-- qui les alimentait la-bas.

E.mecaniques = {
    { id = "attaque_simple",   label = "Attaque simple" },
    { id = "perce_armure",     label = "Perce-armure" },
    { id = "brise_armure",     label = "Brise-armure" },
    { id = "provocation",      label = "Provocation" },
    { id = "intimidation",     label = "Intimidation" },
    { id = "bouclier",         label = "Bouclier" },
    { id = "soin",             label = "Soin" },
    { id = "buff",             label = "Buff" },
    { id = "debuff",           label = "Debuff" },
    { id = "attraction",       label = "Attraction" },
    { id = "repulsion",        label = "Répulsion" },
    { id = "immobilisation",   label = "Immobilisation" },
    { id = "entrave",          label = "Entrave" },
    { id = "deviation",        label = "Déviation" },
    { id = "levitation",       label = "Lévitation" },
    { id = "intervention",     label = "Intervention" },
    { id = "permutation",      label = "Permutation" },
    { id = "dissipation",      label = "Dissipation" },
    { id = "creation",         label = "Création" },
    { id = "confusion",        label = "Confusion" },
    { id = "controle_mental",  label = "Contrôle mental" },
    { id = "illusion",         label = "Illusion" },
}

-- Les six statistiques primaires, dans l'ordre de la feuille.
E.primaires = {
    { id = "force",        label = "Force" },
    { id = "mystique",     label = "Mystique" },
    { id = "perception",   label = "Perception" },
    { id = "adresse",      label = "Adresse", cout = 2, plafond = { base = 2, parNiveau = 1 } },
    { id = "esprit",       label = "Esprit",  cout = 2, plafond = { base = 2, parNiveau = 1 } },
    { id = "constitution", label = "Constitution" },
}

-- Les trois qui ouvrent les penetrations.
E.statsDeDegats = { "force", "mystique", "perception" }

-- ===== Apports aux expertises ==============================================
-- Une expertise vaut : points investis + somme(source x coefficient) + bonus.
-- Une source est une primaire (valeur totale, bonus compris), une autre
-- expertise (sa valeur totale) ou un champ de penetration / resistance.
-- Releve des formules de la fenetre Expertises du template.
--
-- Ecarts voulus avec le template, qui contenait des coquilles :
--   * Investigation, Elementaire, Cosmique : le template lisait un
--     « modificateur de jet » de l'Esprit (toujours 0), et Investigation le
--     DIVISAIT ; on applique le coefficient a l'Esprit, comme son libelle.
--   * Pistage : le template multipliait la Mystique sous le libelle
--     « Pistage-Perception » et oubliait les points investis ; on prend la
--     Perception, et les points investis comptent comme partout.

-- Elementaire et Cosmique recoivent 0,25 x 60 % des penetrations de leur
-- groupe : chaque type compte donc pour 0,15.
local PEN_GROUPE = 0.25 * 0.6

E.apportsExpertises = {
    -- Observations
    vue           = { perception = 0.33 },
    odorat_gout   = { perception = 0.33 },
    ouie          = { perception = 0.33 },
    toucher       = { perception = 0.33 },
    investigation = { perception = 0.33, esprit = 0.25 },
    elementaire   = { esprit = 0.25, mystique = 0.25, perception = 0.16,
                      pen_feu = PEN_GROUPE, pen_eau = PEN_GROUPE, pen_vent = PEN_GROUPE,
                      pen_terre = PEN_GROUPE, pen_esprit = PEN_GROUPE, pen_pourriture = PEN_GROUPE },
    cosmique      = { esprit = 0.25, mystique = 0.25, perception = 0.16,
                      pen_lumiere = PEN_GROUPE, pen_ombre = PEN_GROUPE, pen_ordre = PEN_GROUPE,
                      pen_desordre = PEN_GROUPE, pen_vie = PEN_GROUPE, pen_mort = PEN_GROUPE },
    pistage       = { perception = 0.5, resi_vie = 0.1 },
    -- A VALIDER : Communication a ete ajoutee aux Observations le 3 octobre
    -- 2026, et le releve du template n'en donne pas les apports. On part sur
    -- Esprit en tete (c'est une expertise de lecture et d'echange, pas de
    -- sens) avec un appoint de Perception, sur le patron d'Investigation.
    communication = { esprit = 0.33, perception = 0.25 },
    -- Athletisme
    puissance     = { force = 0.5, adresse = 0.25 },
    projection    = { force = 1, adresse = 0.25, perception = 0.25, constitution = 0.25 },
    prise         = { force = 1, adresse = 0.25, esprit = 0.15, perception = 0.15, constitution = 0.25 },
    equilibre     = { adresse = 0.25, perception = 0.4 },
    acrobaties    = { adresse = 0.25, force = 0.25, perception = 0.25 },
    escalade      = { force = 0.25, adresse = 0.25, perception = 0.25 },
    resistance    = { constitution = 0.35, esprit = 0.35 },
    endurance     = { constitution = 0.35 },
    course        = { force = 0.25, adresse = 0.25 },
    nage          = { force = 0.5, adresse = 0.25 },
    -- Filouterie
    discretion    = { adresse = 0.25, esprit = 0.25, perception = 0.25 },
    deguisement   = { adresse = 0.25, esprit = 0.35, perception = 0.35 },
    vol_a_la_tire = { adresse = 0.5, perception = 0.5 },
    crochetage    = { adresse = 0.35, perception = 0.25, toucher = 0.25, ouie = 0.25 },
    escamotage    = { adresse = 0.25, perception = 0.25, toucher = 0.35, ouie = 0.35, vue = 0.35 },
    evasion       = { adresse = 0.25, esprit = 0.25, perception = 0.35, force = 0.35 },
    sabotage      = { adresse = 0.35, perception = 0.35, esprit = 0.35 },
}

-- ===== Lecture d'un bareme =================================================
-- `{ base = 1, parNiveau = 2 }` lu au niveau 5 vaut 11, arrondi a l'inferieur.

function E.Bareme(bareme, niveau)
    if type(bareme) ~= "table" then return 0 end
    niveau = tonumber(niveau) or 0
    return math.floor((tonumber(bareme.base) or 0) + (tonumber(bareme.parNiveau) or 0) * niveau)
end
