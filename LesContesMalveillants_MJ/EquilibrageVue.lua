-- Comment l'onglet Equilibrage du Panel MJ RANGE les nombres du jeu
-- (2 novembre 2026). Rien ici ne change une valeur : c'est une vue. Les
-- nombres restent dans Data/Equilibrage.lua, les reglages passent toujours
-- par LCM.Reglages et le meme chemin.
--
-- Avant : quarante-cinq groupes aux noms de code, par ordre alphabetique, et
-- des lignes « attractionParPen » (« c'est a vomir », le MJ). Maintenant :
--   * des THEMES, et dedans des groupes nommes en francais ;
--   * des sous-sections DEDUITES des noms (« bouclierForce » et
--     « bouclierMystique » vont sous « Bouclier ») : on n'a pas a ranger
--     chaque nombre a la main, et un nombre ajoute demain se range seul ;
--   * un groupe de l'equilibrage qui n'est nomme nulle part ici tombe dans
--     « Autres » : rien ne disparait de l'ecran faute d'avoir ete range.
--
-- Un groupe est soit `id` (une table de Data/Equilibrage.lua), soit
-- `chemins` (des nombres poses a la racine, qu'aucune table ne porte).

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local Vue = {}
MJ.EquilibrageVue = Vue

Vue.themes = {
    -- Les difficultes servent PARTOUT (le MJ, 2 novembre 2026) : epreuves,
    -- jets d'expertise, ressources. Elles ont leur propre categorie, en tete.
    { titre = "Règles", groupes = {
        -- L'echelle des paliers (Core/Nommages.lua), au-dessus des
        -- difficultes qu'elle nomme. Du contenu, pas un nombre : `chemins` vide.
        { id = "nommages",    label = "Nommages", chemins = {} },
        { id = "difficultes", label = "Difficultés" },
    } },
    { titre = "Personnage", groupes = {
        { id = "pv",                label = "Points de vie" },
        { id = "fatigue",           label = "Fatigue" },
        { id = "pa",                label = "Points d'action" },
        { id = "deplacement",       label = "Déplacement" },
        { id = "sauts",             label = "Sauts" },
        { id = "quotidien",         label = "Poids porté" },
        { id = "primaire",          label = "Statistiques primaires" },
        { id = "secondaires",       label = "Statistiques secondaires" },
        { id = "expertise",         label = "Expertises" },
        { id = "apportsExpertises", label = "Ce qui nourrit les expertises" },
        { id = "effetsExpertises",  label = "Ce que donnent les expertises" },
        { id = "creation",          label = "Création" },
        { id = "conversion",        label = "Conversion" },
        { id = "experience",        label = "Expérience" },
    } },
    { titre = "Combat", groupes = {
        { id = "combat",             label = "Tours" },
        { id = "initiative",         label = "Initiative" },
        { id = "actions",            label = "Actions" },
        { id = "reactions",          label = "Réactions" },
        { id = "cibles",             label = "Plusieurs cibles" },
        { id = "puissanceMecanique", label = "Puissance des mécaniques" },
        { id = "defenses",           label = "Défenses" },
        { id = "penetration",        label = "Pénétration" },
        { id = "resistance",         label = "Résistance" },
        { id = "dot",                label = "Dégâts sur la durée" },
        { id = "armure",             label = "Armure" },
        { id = "ic",                 label = "IC" },
        { id = "malus", label = "Malus d'arme inadaptée", chemins = { "malusInadapte" } },
    } },
    { titre = "Objets & forge", groupes = {
        { id = "forge",      label = "Forge" },
        { id = "inventaire", label = "Inventaire" },
        { id = "conteneurs", label = "Emplacements" },
        { id = "vies",       label = "Vies des objets", chemins = { "viesParDefaut" } },
    } },
    { titre = "Métiers & ressources", groupes = {
        -- Paliers ET XP gagnee par couleur : un seul tableau (Panneau.lua,
        -- ConstruirePaliers). Les coefficients vivent dans `difficultes.matrice`.
        { id = "metiers",     label = "Paliers & XP des métiers" },
        { id = "recolte",     label = "Récolte" },
        { id = "marchands",   label = "Marchands" },
        { id = "coffres",     label = "Coffres" },
    } },
    { titre = "Monde", groupes = {
        { id = "campement",  label = "Campement" },
        { id = "lanterne",   label = "Lanterne" },
        { id = "affichages", label = "Panneaux d'affichage" },
    } },
}

-- Ce qui n'est pas un REGLAGE, meme si c'est un nombre : la teinte d'une
-- couleur de metier, son rang, le numero d'un niveau. Le montrer inviterait a
-- casser la table des metiers d'un clic. Reste reglable par /lcm equilibrage
-- pour qui sait ce qu'il fait.
Vue.masques = {
    -- Les paliers ont leur grille (Panneau.lua, ConstruirePaliers) : le cout
    -- s'y regle, le seuil cumule s'y calcule. Le tableau ne les montre plus.
    "^metiers%.paliers%.",
    "^VERSION_CREATION$",
}

-- Les mots des identifiants, ecrits pour etre lus. Un mot absent s'ecrit
-- tel quel, avec une majuscule : jamais d'identifiant perdu, au pire un mot
-- sans accent.
Vue.mots = {
    pa = "PA", pf = "PF", pv = "PV", ps = "PS", xp = "XP", ic = "IC",
    pen = "pén.", resi = "rési.", par = "par", de = "de", en = "en", a = "à", la = "la",
    cout = "coût", couts = "coûts", base = "base", plafond = "plafond", plancher = "plancher",
    niveau = "niveau", niveaux = "niveaux", palier = "palier", paliers = "paliers",
    defense = "défense", defenses = "défenses", deviation = "déviation", repulsion = "répulsion",
    reduction = "réduction", mod = "mod.", multi = "multi", stat = "stat", stats = "stats",
    secondaire = "secondaire", secondaires = "secondaires", primaires = "primaires",
    expertises = "expertises", mecaniques = "mécaniques", traits = "traits",
    deplacement = "déplacement", decimales = "décimales", securite = "sécurité",
    duree = "durée", degats = "dégâts", equip = "équip.", egale = "même couleur",
    dessous = "en dessous", dessus = "au-dessus", elementaire = "élémentaire",
    equilibre = "équilibre", evasion = "évasion", deguisement = "déguisement",
    discretion = "discrétion", priere = "prière", reparation = "réparation",
    vitalite = "vitalité", heures = "heures", heure = "heure", ouie = "ouïe",
    gout = "goût", odorat = "odorat", desordre = "désordre", lumiere = "lumière",
    resistance = "résistance", penetration = "pénétration", parade = "parade",
    portee = "portée", obligatoire = "obligatoire", part = "part", objet = "objet",
    etat = "état", etats = "états", remboursement = "remboursement",
    categorie = "catégorie", races = "races", rayon = "rayon", max = "max", min = "min",
    des = "dé", nage = "nage", vol = "vol", aura = "aura", terrestre = "terrestre",
    arret = "arrêt", vitesse = "vitesse", normale = "normale", supplement = "supplément",
    secondes = "secondes", round = "round", rounds = "rounds", tour = "tour", tours = "tours",
    stack = "stack", stacks = "stacks", rand = "rand", source = "source", pool = "pool",
    taux = "taux", embuscade = "embuscade", dangers = "dangers", campeur = "campeur",
    garde = "garde", repos = "repos", lits = "lits", defaut = "défaut", pas = "pas",
    rapide = "rapide", surpopulation = "surpopulation", population = "population",
    inf = "inf.", sup = "sup.", taille = "taille", variables = "variables", minutes = "minutes",
    sommeil = "sommeil", soin = "soin", histoire = "histoire", fabrication = "fabrication",
    actions = "actions", coef = "coef.", diviseur = "diviseur", horizontal = "horizontal",
    vertical = "vertical", adresse = "adresse", force = "force", esprit = "esprit",
    mystique = "mystique", perception = "perception", constitution = "constitution",
    poids = "poids", zone = "zone", depart = "départ", gain = "gain",
    declencheur = "déclencheur", frequence = "fréquence", critique = "critique",
    conversion = "conversion", minimum = "minimum", combat = "combat",
    reussie = "réussie", inflige = "infligé", recu = "reçu", recus = "reçus",
    debut = "début", fin = "fin", instantanee = "instantanée", attenuation = "atténuation",
    immunite = "immunité", temporaire = "temporaire", renforce = "renforcé",
    reparateur = "réparateur", protecteur = "protecteur", protection = "protection",
    quotidienne = "quotidienne", majeure = "majeure", mineure = "mineure",
    affaiblissant = "affaiblissant", augmentation = "augmentation", seuil = "seuil",
    esquive = "esquive", manuel = "manuel", hors = "hors", sans = "sans", limite = "limite",
    cumul = "XP cumulée", valeur = "valeur", fatigue = "fatigue", armure = "armure",
}

-- Un libelle donne a la main, pour un chemin complet, quand la deduction
-- dit mal les choses. Et une aide, en infobulle.
Vue.libelles = {
    ["malusInadapte"] = "Multiplicateur d'une arme inadaptée",
    ["viesParDefaut"] = "Vies d'un objet sans rareté",
    ["combat.roundsParTour"] = "Rounds par tour",
    ["armure.parDefaut"] = "Armure par défaut",
}
-- ===== Les aides ===========================================================
-- Ce qu'un nombre fait EXACTEMENT, en infobulle (le MJ, 2 novembre 2026 :
-- « le nombre d'accessoires qu'un personnage peut porter sur lui »). Chaque
-- texte est relu des commentaires de Data/Equilibrage.lua et du code qui lit
-- le nombre ; quand le fichier dit « a confirmer », l'aide le dit aussi. Rien
-- n'est invente : un nombre sans aide n'en affiche pas.
--
-- `Vue.aides` : un chemin complet. `Vue.aidesMotifs` : une FAMILLE de chemins
-- (les 78 apports d'expertises, les paliers...), le texte se fabriquant avec
-- ce que le motif capture.

local E = function() return LCM.Equilibrage end

-- Un identifiant, lisible : « vol_a_la_tire » -> « vol à la tire ».
local function Lisible(id)
    local out = {}
    for mot in tostring(id or ""):gsub("(%l)(%u)", "%1 %2"):gsub("[_:]", " "):gmatch("%S+") do
        out[#out + 1] = Vue.mots[mot:lower()] or mot:lower()
    end
    return table.concat(out, " ")
end
-- Le nom de l'element N d'une liste de l'equilibrage (« secondaires », 4).
local function Element(liste, indice)
    local t = E()
    for bout in tostring(liste):gmatch("[^%.]+") do t = type(t) == "table" and t[bout] or nil end
    local e = type(t) == "table" and t[tonumber(indice)] or nil
    if type(e) ~= "table" then return "n° " .. tostring(indice) end
    return tostring(e.label or (e.nom and (e.nom .. " " .. tostring(e.niveau or ""))) or e.id or indice)
end
-- « de » devant un mot : « d'évasion », « de force ».
local VOYELLES = { a = true, e = true, i = true, o = true, u = true, h = true }
local function De(mot)
    mot = tostring(mot or "")
    local premier = mot:sub(1, 1):lower()
    if VOYELLES[premier] or mot:find("^\195") then return "d'" .. mot end
    return "de " .. mot
end
-- Les mecaniques des actions, avec leur article.
local ARTICLES = { attraction = "l'attraction", repulsion = "la répulsion",
    immobilisation = "l'immobilisation", entrave = "l'entrave", permutation = "la permutation",
    deviation = "la déviation", defense = "la défense" }

-- Une source d'apport : une primaire, une autre expertise, ou une pen / resi.
local function Source(cle)
    local type_ = cle:match("^pen_(.+)$")
    if type_ then return "pénétration " .. Lisible(type_) end
    type_ = cle:match("^resi_(.+)$")
    if type_ then return "résistance " .. Lisible(type_) end
    return Lisible(cle)
end

Vue.aides = {
    ["difficultes"] = "Une difficulté est un nombre rangé dans une couleur de métier.",

    -- Personnage
    ["pv.base"] = "PV de départ de tout personnage. PV max = base + par niveau × niveau + par vitalité × points secondaires en Vitalité + Constitution × (2 + Constitution investie × 0,25).",
    ["pv.parNiveau"] = "PV gagnés à chaque niveau.",
    ["pv.parVitalite"] = "PV gagnés par point secondaire investi en Vitalité.",
    ["pv.constitution.base"] = "PV apportés par chaque point de Constitution totale.",
    ["pv.constitution.parConstitution"] = "Ce que chaque point de Constitution INVESTIE ajoute au rendement de la Constitution en PV : avec 0,25, chaque point de Constitution vaut 2 + 0,25 × la Constitution investie.",
    ["pv.parZone"] = "Part des PV max que vaut chaque zone du corps (0,30 = 30 %). Les zones se chevauchent : ensemble, elles dépassent le total.",
    ["fatigue.base"] = "Fatigue (PF) de départ. Fatigue max = base + 2 × Constitution + Esprit + 2 × niveau + Endurance / diviseur + 3 × points secondaires en Fatigue.",
    ["fatigue.parNiveau"] = "PF gagnés à chaque niveau.",
    ["fatigue.parEsprit"] = "PF gagnés par point d'Esprit.",
    ["fatigue.parConstitution"] = "PF gagnés par point de Constitution.",
    ["fatigue.diviseurEndurance"] = "La valeur TOTALE de l'expertise Endurance est divisée par ce nombre, puis ajoutée aux PF max. À 1 : un PF par point d'Endurance.",
    ["fatigue.parSecondaire"] = "PF gagnés par point secondaire investi en Fatigue.",
    ["pa.base"] = "Points d'action de départ, au niveau 1.",
    ["pa.niveauxParPA"] = "Un PA de plus tous les N niveaux : à 5, 4 PA du niveau 1 au 4, 5 au niveau 5, 6 au niveau 10.",
    ["deplacement.terrestre"] = "Yards parcourus à pied en un déplacement, avant l'expertise Course et les points secondaires.",
    ["deplacement.nage"] = "Yards parcourus à la nage en un déplacement, avant l'expertise Nage.",
    ["deplacement.vol"] = "Yards parcourus en vol en un déplacement. 0 : on ne vole pas sans un trait ou un objet qui le donne.",
    ["deplacement.parSecondaire"] = "Yards gagnés par point secondaire investi en Déplacement.",
    ["deplacement.parRound"] = "Déplacements possibles par round. Le premier est gratuit, les suivants coûtent le supplément en PA et en PF.",
    ["deplacement.supplementPA"] = "PA que coûte un déplacement au-delà du premier du round.",
    ["deplacement.supplementPF"] = "PF que coûte un déplacement au-delà du premier du round.",
    ["deplacement.aura"] = "Identifiant de l'aura posée à l'arrivée pour marquer la position (commande serveur .aura). 0 désactive tout l'arrêt.",
    ["deplacement.vitesseArret"] = "Vitesse imposée le temps de s'arrêter à l'arrivée (commande .mod speed).",
    ["deplacement.vitesseNormale"] = "Vitesse rendue une fois l'arrêt terminé.",
    ["deplacement.secondesArret"] = "Durée du ralentissement à l'arrivée, en secondes : sans lui, on finit trois mètres plus loin que permis.",
    ["quotidien.poidsBase"] = "Poids qu'un personnage soulève sans Force.",
    ["quotidien.poidsParForce"] = "Poids soulevable en plus par point de Force.",
    ["sauts.horizontal.diviseurForce"] = "Saut en longueur = Force / ce nombre + Adresse / l'autre diviseur.",
    ["sauts.horizontal.diviseurAdresse"] = "Saut en longueur = Force / l'autre diviseur + Adresse / ce nombre.",
    ["sauts.vertical.diviseurForce"] = "Saut en hauteur = Force / ce nombre + Adresse / l'autre diviseur.",
    ["sauts.vertical.diviseurAdresse"] = "Saut en hauteur = Force / l'autre diviseur + Adresse / ce nombre.",
    ["primaire.cout"] = "Coût d'un point de statistique primaire à la création. Adresse et Esprit ont leur propre coût (2), réglé dans le fichier.",
    ["primaire.plafond.base"] = "Plafond d'une primaire = base + par niveau × niveau (9 au niveau 5). Adresse et Esprit plafonnent plus bas (2 + niveau).",
    ["primaire.plafond.parNiveau"] = "Ce que le plafond d'une primaire gagne à chaque niveau.",
    ["expertise.plafond.base"] = "Plafond d'une expertise = base + par niveau × niveau. Les mécaniques se plafonnent pareil.",
    ["expertise.plafond.parNiveau"] = "Ce que le plafond d'une expertise gagne à chaque niveau.",
    ["creation.niveauDepart"] = "Niveau auquel un personnage est créé.",
    ["creation.primaires.base"] = "Points de primaires à répartir à la création = base + par niveau × niveau.",
    ["creation.primaires.parNiveau"] = "Points de primaires gagnés par niveau.",
    ["creation.secondaires.base"] = "Points secondaires à répartir à la création = base + par niveau × niveau.",
    ["creation.secondaires.parNiveau"] = "Points secondaires gagnés par niveau.",
    ["creation.expertises.base"] = "Points d'expertise à répartir à la création = base + par niveau × niveau.",
    ["creation.expertises.parNiveau"] = "Points d'expertise gagnés par niveau.",
    ["creation.mecaniques.base"] = "Points de mécaniques au niveau de départ.",
    ["creation.mecaniques.niveauDepart"] = "Niveau à partir duquel les points de mécaniques supplémentaires se comptent.",
    ["creation.mecaniques.parNiveau"] = "Points de mécaniques gagnés à chaque niveau au-delà du départ.",
    ["creation.mecaniques.niveauxParPalier"] = "Tous les N niveaux, un palier : ce niveau donne « gain palier » points au lieu de « par niveau ».",
    ["creation.mecaniques.gainPalier"] = "Points de mécaniques donnés par un niveau palier (multiple de N), à la place du gain normal.",
    ["creation.traits.base"] = "Points de traits au niveau de départ. Un trait coûte de 1 à 4 points selon sa force.",
    ["conversion.expertises"] = "Points d'expertise reçus pour 1 point secondaire investi en Expertises.",
    ["conversion.mecaniques"] = "Points de mécanique reçus pour 1 point secondaire investi en Mécanique de compétence.",
    ["experience.niveauDepart"] = "Niveau d'un personnage qui n'a encore aucune XP. (Paliers d'XP à valider : le template n'en donnait pas.)",

    -- Combat
    ["combat.roundsParTour"] = "Un tour de combat = ce nombre de passages complets de la liste d'initiative. Le compteur de tour n'avance qu'au dernier.",
    ["initiative.diviseurNiveau"] = "Initiative = points secondaires + niveau / ce nombre + Esprit / … + Perception / …. À 2 : deux niveaux font un point.",
    ["initiative.diviseurEsprit"] = "L'Esprit est divisé par ce nombre dans l'initiative. À 2 : deux points d'Esprit font un point d'initiative.",
    ["initiative.diviseurPerception"] = "La Perception est divisée par ce nombre dans l'initiative.",
    ["reactions.deviation.pa"] = "PA d'une déviation quand l'action reçue ne dit pas son coût. Sinon, une déviation coûte le PA de l'action qu'elle détourne.",
    ["reactions.deviation.pf"] = "PF que coûte une déviation.",
    ["reactions.intervention.pa"] = "PA que coûte une intervention (s'interposer pour un allié).",
    ["reactions.intervention.pf"] = "PF que coûte une intervention.",
    ["malusInadapte"] = "Quand on oppose l'Adresse à un jet d'Esprit, ou l'inverse, la statistique ne compte qu'à ce taux (0,8 = 80 %).",
    ["puissanceMecanique.base"] = "Puissance d'une mécanique de compétence, en %, sans point investi. Une mécanique peut avoir la sienne.",
    ["puissanceMecanique.parPoint"] = "% de puissance gagnés par point investi dans la mécanique.",
    ["puissanceMecanique.equipParPoint"] = "% de puissance gagnés par point de la mécanique apporté par l'équipement.",
    ["penetration.points.base"] = "Points de pénétration à répartir sur les quinze types = base + par niveau × niveau + par stat de dégâts × (Force + Mystique + Perception) + par secondaire × points secondaires.",
    ["penetration.points.parNiveau"] = "Points de pénétration gagnés par niveau.",
    ["penetration.points.parStatDeDegats"] = "Points de pénétration par point de Force, Mystique et Perception.",
    ["penetration.points.parSecondaire"] = "Points de pénétration par point secondaire investi en Pénétration.",
    ["penetration.plafond.base"] = "Plafond d'un type de pénétration = base + (Force + Mystique + Perception) / diviseur, arrondi à l'inférieur.",
    ["penetration.plafond.diviseurStats"] = "Diviseur des trois stats de dégâts dans le plafond d'un type de pénétration.",
    ["resistance.points.base"] = "Points de résistance à répartir sur les quinze types (relevé du template, lecture à confirmer).",
    ["resistance.points.parNiveau"] = "Points de résistance gagnés par niveau.",
    ["resistance.points.parConstitution"] = "Points de résistance par point de Constitution.",
    ["resistance.points.parEsprit"] = "Points de résistance par point d'Esprit.",
    ["resistance.points.parSecondaire"] = "Points de résistance par point secondaire investi en Résistance.",
    ["resistance.plafond.base"] = "Plafond d'un type de résistance = base + par constitution × Constitution.",
    ["resistance.plafond.parConstitution"] = "Ce que chaque point de Constitution ajoute au plafond d'un type de résistance.",
    ["cibles.multicible.enPlus.pa"] = "PA ajoutés par cible au-delà de la sixième, au même rythme que la fin de la table.",
    ["cibles.multicible.enPlus.pf"] = "PF ajoutés par cible au-delà de la sixième.",
    ["dot.coutRound"] = "Prix, en points du pool, d'un round de grignotage en plus.",
    ["dot.coutStack"] = "Prix, en points du pool, d'un stack en plus.",
    ["dot.roundsBase"] = "Rounds que dure un dot sans rien acheter.",
    ["dot.stacksBase"] = "Stacks d'un dot sans rien acheter.",
    ["dot.randParRound"] = "Le jet à battre pour dissiper un dot baisse d'autant chaque round : un dot ancien se décroche plus facilement.",
    ["dot.pool.parSource"] = "Points de pool d'un dot par point de la statistique source.",
    ["dot.pool.parPen"] = "Points de pool par point de la moyenne des pénétrations choisies.",
    ["dot.pool.parNiveau"] = "Points de pool par niveau du sort.",
    ["dot.resistance.plancher"] = "Contre une cible très résistante, le grignotage ne descend jamais sous cette part (rapport 2 × pén / (pén + rési)).",
    ["dot.resistance.plafond"] = "Contre une cible sans résistance, le grignotage ne dépasse jamais cette part.",
    ["armure.parDefaut"] = "Valeur d'armure d'une pièce dont l'atelier n'a pas fixé la sienne.",
    ["ic.conversion"] = "Points de forge obtenus par IC converti (0,25 : un IC donne un quart de point).",
    ["ic.coutMinimum"] = "Coût minimum d'un effet d'IC, quels que soient ses rabais.",

    -- Objets & forge
    ["forge.coutParDefaut"] = "Coût d'un point dans une statistique qu'un jeu d'équilibrage ne règle pas.",
    ["forge.pourcentParPoint"] = "Combien de % vaut un point sur une ligne « % » de la forge (5 : un point pour 5 %).",
    ["forge.remboursement"] = "Part du coût rendue au pool quand une statistique passe SOUS sa base (0,5 = la moitié).",
    ["forge.remboursementParCategorie.races"] = "Même chose pour les races : 1 = une faiblesse est remboursée en entier.",
    ["forge.etatObjet.base"] = "État de départ d'une arme, d'une armure ou d'un accessoire forgé.",
    ["forge.etatObjet.min"] = "État le plus bas qu'on peut forger.",
    ["forge.etatObjet.pas"] = "De combien l'état monte ou descend par cran dans la forge.",
    ["forge.etatObjet.coutParPas"] = "Points de forge que coûte un cran d'état.",
    ["forge.etatObjet.bonusPool"] = "Points ajoutés au pool des objets pour compenser l'état, devenu obligatoire.",
    ["inventaire.sacs"] = "Nombre d'emplacements de sac.",
    ["inventaire.saccoches"] = "Nombre d'emplacements de sacoche.",
    ["inventaire.ceintures"] = "Ceintures portées : une, toujours, même sans objet ceinture.",
    ["inventaire.placesCeinture"] = "Cases de la ceinture nue. Un objet « ceinture » ajoute les siennes par-dessus.",
    ["inventaire.cristaux_usage"] = "La poche des cristaux entamés : un emplacement, sans limite de cases.",
    ["conteneurs.arme"] = "Le nombre d'armes qu'un personnage tient en main : une arme et un bouclier, ou une arme qui prend les deux places.",
    ["conteneurs.equipement"] = "Le nombre de pièces d'armure et de vêtements qu'un personnage peut porter à la fois.",
    ["conteneurs.accessoire"] = "Le nombre d'accessoires qu'un personnage peut porter sur lui.",
    ["conteneurs.outil"] = "Le nombre d'outils accrochés à la ceinture de base.",
    ["conteneurs.etat"] = "Places pour les états divers (fenêtre Santé).",
    ["conteneurs.maladie"] = "Places pour les maladies (fenêtre Santé).",
    ["conteneurs.intangible"] = "Places pour les états intangibles (fenêtre Santé).",
    ["conteneurs.apprentissage"] = "Places dans la fenêtre Apprentissage.",
    ["conteneurs.traits"] = "Le nombre de traits qu'un personnage peut avoir.",
    ["viesParDefaut"] = "Vies d'un objet dont la couleur de rareté n'est déclarée nulle part.",

    -- Metiers & ressources
    ["recolte.des.min"] = "Plus petit résultat du dé de récolte. Le jet = ce dé + bonus du métier, contre la difficulté de la ressource ; égalité = réussite.",
    ["recolte.des.max"] = "Plus grand résultat du dé de récolte.",
    ["recolte.rayon"] = "Distance, en yards, à laquelle un point se récolte quand le MJ ne lui en donne pas.",
    ["recolte.rayonMax"] = "Plus grand rayon de récolte que le créateur de points accepte.",
    ["marchands.rayon"] = "Distance, en yards, à laquelle on commerce avec un vendeur posé.",
    ["marchands.rayonOffrir"] = "Distance, en yards, entre l'acheteur et le joueur à qui il offre un achat (« Acheter pour… »).",
    ["coffres.rayon"] = "Rayon d'interaction, en yards, d'un coffre qui ne dit pas le sien.",
    ["coffres.rayonMax"] = "Plus grand rayon qu'un modèle de coffre peut se donner.",

    -- Monde
    ["campement.securite.base"] = "Base du regain de sécurité au campement.",
    ["campement.fatigue.base"] = "Base du regain de fatigue au campement.",
    ["campement.fatigue.decimales"] = "Décimales gardées avant l'arrondi final de la fatigue rendue.",
    ["campement.vitalite.base"] = "PS = base × (heures de soin × par soin + heures de sommeil × par sommeil).",
    ["campement.vitalite.decimales"] = "Décimales gardées avant l'arrondi final des PS.",
    ["campement.vitalite.parSoin"] = "Poids d'une heure de soin dans les PS rendus.",
    ["campement.vitalite.parSommeil"] = "Poids d'une heure de sommeil dans les PS rendus.",
    ["campement.vitalite.psParPointNegatif"] = "PS que coûte le retrait d'un état ou d'une maladie, par point NÉGATIF qu'il porte. Un état qui ne retire rien ne coûte rien.",
    ["campement.armure.base"] = "Base de la remise en état des armures au camp (la formule reste à donner).",
    ["campement.embuscade.parHeureRepos"] = "Risque d'embuscade ajouté par heure de repos (jusqu'aux heures max).",
    ["campement.embuscade.heuresMax"] = "Heures de repos au-delà desquelles le risque n'augmente plus.",
    ["campement.embuscade.parCampeur"] = "Risque retiré par campeur.",
    ["campement.embuscade.parSecurite"] = "Risque retiré par point de sécurité du camp.",
    ["campement.embuscade.parHeureGarde"] = "Risque retiré par heure de garde, tout le camp compris.",
    ["campement.embuscade.decimales"] = "Décimales gardées du risque, arrondi à l'inférieur.",
    ["campement.embuscade.de"] = "Faces du dé tiré à la fin de la nuit : un résultat inférieur ou égal au risque (en %) déclenche l'embuscade.",
    ["campement.surpopulation"] = "% que la tente perd de ce qu'elle rend, par personne au-delà de ses lits (à confirmer).",
    ["campement.litsParDefaut"] = "Lits d'une tente qui ne dit pas les siens.",
    ["campement.minutesParHeure"] = "Minutes dans une heure de camp : les durées se saisissent en minutes, les formules comptent en heures.",
    ["campement.pasRapide"] = "Pas des boutons « +1h » / « -1h » de la répartition, en minutes.",
    ["lanterne.variateurDefaut"] = "Rythme d'écoulement choisi par défaut (1 = celui de la lanterne).",
    ["affichages.rayon"] = "Distance, en yards, à laquelle on lit un panneau d'affichage.",
    ["affichages.maxAffiches"] = "Affiches au plus sur un panneau.",
    ["affichages.titreMax"] = "Caractères au plus dans le titre d'une affiche.",
    ["affichages.texteMax"] = "Caractères au plus dans le texte d'une affiche.",
}

-- Les familles. Chaque motif capture ce qu'il faut pour nommer.
local STATS_ACTIONS = { Force = "Force", Mystique = "Mystique", Perception = "Perception",
    Constitution = "Constitution", Pen = "pénétration" }
Vue.aidesMotifs = {
    { "^actions%.multi(%u%a+)$", function(reste)
        if STATS_ACTIONS[reste] then
            return "Multiplicateur d'attaque sur la " .. STATS_ACTIONS[reste] .. " (« Base multi " .. reste .. " » du template), lu par les formules de résolution du compendium."
        end
        local actions = { Bouclier = "du bouclier", Soin = "du soin", Buff = "du buff" }
        for prefixe, sur in pairs({ Stat = " appliqué à la statistique", Pen = " appliqué à la pénétration",
                                     Fatigue = " appliqué à la fatigue" }) do
            local action = reste:match("^" .. prefixe .. "(%u%a+)$")
            if action and actions[action] then
                return "Multiplicateur " .. actions[action] .. sur .. " (« Multiplicateur " .. prefixe .. " " .. action:upper() .. " » du template), lu par sa formule de résolution."
            end
        end
        if actions[reste] then
            return "Multiplicateur général " .. actions[reste] .. " (« Multiplicateur " .. reste .. " » du template), lu par sa formule de résolution."
        end
    end },
    { "^actions%.(%l+)(%u%a+)$", function(action, stat)
        local noms = { bouclier = "un bouclier", soin = "un soin", buff = "un buff" }
        if noms[action] and STATS_ACTIONS[stat] then
            return "Ce que chaque point de " .. STATS_ACTIONS[stat] .. " apporte à " .. noms[action] .. " (« Base " .. action .. " " .. stat .. " » du template)."
        end
    end },
    { "^actions%.(%l+)Par(%u%l+)$", function(meca, par)
        local quoi = ({ Stat = "point de statistique", Pen = "point de pénétration", Point = "point" })[par]
        if quoi then
            return "Ce que chaque " .. quoi .. " apporte à " .. (ARTICLES[meca] or Lisible(meca)) .. " (« " .. Lisible(meca) .. " par " .. par:lower() .. " » du template)."
        end
    end },
    { "^actions%.coutPA(%u%a+)$", function(action)
        return "Coût en PA d'un " .. action:lower() .. "."
    end },
    { "^actions%.(%a+)$", function(nom)
        return "« " .. Lisible(nom) .. " », nombre de l'onglet Équilibrage ACTIONS du template, lu par les formules de résolution du compendium."
    end },
    { "^secondaires%.(%d+)%.cout$", function(i)
        return "Ce que coûte UN point de " .. Element("secondaires", i) .. ", en points secondaires."
    end },
    { "^secondaires%.(%d+)%.plafond%.parNiveau$", function(i)
        return "Points de " .. Element("secondaires", i) .. " qu'on peut avoir, par niveau."
    end },
    { "^secondaires%.(%d+)%.plafond%.base$", function(i)
        return "Points de " .. Element("secondaires", i) .. " permis avant ce que donnent les niveaux."
    end },
    { "^apportsExpertises%.([%w_]+)%.([%w_]+)$", function(expertise, source)
        return "Ce que chaque point " .. De(Source(source)) .. " ajoute à l'expertise « " .. Lisible(expertise) .. " »."
    end },
    { "^effetsExpertises%.(%w+)%.parade$", function(expertise)
        return "Bonus au jet de défense, par point " .. De(Lisible(expertise)) .. " (valeur totale), quand le jet subi porte sur la statistique que cette expertise pare."
    end },
    { "^effetsExpertises%.resistance%.partObligatoire$", function()
        return "Chaque point de Résistance allège de ce taux la part des dégâts qu'un perce-armure force en santé (0,02 = 2 %). Elle ne retire aucun dégât."
    end },
    { "^effetsExpertises%.puissance%.degats$", function()
        return "Supplément de dégâts par point de Puissance, en fraction (0,005 = 0,5 %), sur l'attaque simple et le brise-armure."
    end },
    { "^effetsExpertises%.projection%.portee$", function()
        return "Mètres de portée gagnés par point de Projection, sur la répulsion."
    end },
    { "^effetsExpertises%.projection%.rand$", function()
        return "Bonus au jet de répulsion par point de Projection."
    end },
    { "^effetsExpertises%.(%w+)%.deplacement$", function(expertise)
        return "Yards gagnés par point " .. De(Lisible(expertise)) .. " (valeur totale)."
    end },
    { "^creation%.traits%.niveaux%.(%d+)$", function(i)
        return "Niveau auquel le personnage gagne son " .. i .. (i == "1" and "er" or "e") .. " point de trait en plus."
    end },
    { "^experience%.paliers%.(%d+)%.niveau$", function()
        return "Le niveau que donne ce palier."
    end },
    { "^experience%.paliers%.(%d+)%.xp$", function()
        return "XP TOTALE qu'il faut avoir amassée pour être à ce niveau (paliers cumulatifs, à valider)."
    end },
    { "^metiers%.paliers%.(%d+)%.xp$", function(i)
        return "XP pour ACHEVER le niveau de métier " .. Element("metiers.paliers", i) .. " (coût de ce palier)."
    end },
    { "^metiers%.paliers%.(%d+)%.cumul$", function(i)
        return "XP totale à atteindre pour être " .. Element("metiers.paliers", i) .. " : c'est ce seuil que le jeu lit. Si tu changes un coût, ajuste les seuils qui suivent."
    end },
    { "^cibles%.multicible%.paliers%.(%d+)%.(%a+)$", function(i, quoi)
        return quoi:upper() .. " en plus pour une attaque sur " .. i .. " cible" .. (i == "1" and "" or "s") .. "."
    end },
    { "^defenses%.(%d+)%.parPoint$", function(i)
        local d = E().defenses and E().defenses[tonumber(i)]
        return d and d.note or nil
    end },
    { "^dot%.cibles%.(%d+)%.cout$", function(i)
        return "Prix d'un point de dot sur : " .. Element("dot.cibles", i) .. "."
    end },
    { "^dot%.cibles%.(%d+)%.taux$", function(i)
        return "Part du MAXIMUM de la jauge « " .. Element("dot.cibles", i) .. " » grignotée par point et par round (0,05 = 5 %)."
    end },
    { "^ic%.coutsDeclencheur%.(.+)$", function(cle)
        return "Ce que coûte (ou rend, si négatif) le déclencheur « " .. Lisible(cle) .. " » d'un effet d'IC."
    end },
    { "^ic%.coutsDuree%.(.+)$", function(cle)
        local unite, n = cle:match("^(%a+):(%d+)$")
        local lisible = unite and (n .. " " .. (tonumber(n) > 1 and unite or unite:gsub("s$", ""))) or Lisible(cle)
        return "Ce que coûte (ou rend, si négatif) un effet d'IC qui dure « " .. lisible .. " »."
    end },
    { "^ic%.coutsFrequence%.(.+)$", function(cle)
        local unite, n = cle:match("^(%a+)%d*:(%d+)$")
        local lisible = unite and (n .. " fois par " .. (({ combat = "combat", tour = "tour", heures = "24 h" })[unite] or unite))
            or Lisible(cle)
        return "Ce que coûte (ou rend, si négatif) un effet d'IC utilisable « " .. lisible .. " »."
    end },
    { "^ic%.critique%.([%w_]+)%.cout$", function(cle)
        return "Coût de l'effet critique « " .. Lisible(cle) .. " »."
    end },
    { "^ic%.critique%.([%w_]+)%.(%a+)$", function(cle, quoi)
        return "Force de l'effet critique « " .. Lisible(cle) .. " » : " .. Lisible(quoi) .. " (0,25 = 25 %)."
    end },
    { "^ic%.paliers%.(%a+)%.pool$", function(couleur)
        return "IC disponibles pour un objet de palier " .. Lisible(couleur) .. "."
    end },
    { "^campement%.embuscade%.dangers%.(%d+)%.valeur$", function(i)
        return "Ce que le niveau de danger « " .. Element("campement.embuscade.dangers", i) .. " » ajoute au risque d'embuscade (négatif : il l'augmente)."
    end },
    { "^campement%.embuscade%.dangers%.(%d+)%.force$", function(i)
        return "Risque FORCÉ pour « " .. Element("campement.embuscade.dangers", i) .. " », quoi qu'en disent les heures et la garde."
    end },
    { "^campement%.variables%.(%a+)%.(%a+)$", function(stat, quoi)
        local q = ({ populationSup = "quand le camp compte plus de monde que prévu",
            populationInf = "quand il en compte moins", taille = "selon la taille du camp" })[quoi]
        return q and ("Variation, en %, de la " .. Lisible(stat) .. " " .. q .. ".") or nil
    end },
    { "^campement%.actions%.(%d+)%.fatigue$", function(i)
        return "Fatigue rendue par heure de « " .. Element("campement.actions", i) .. " » (négatif : elle en coûte)."
    end },
    { "^campement%.coefActions%.(%a+)$", function(cat)
        return "Facteur appliqué aux actions de camp de la catégorie " .. Lisible(cat) .. "."
    end },
    { "^lanterne%.variateurs%.(%d+)$", function()
        return "Un rythme d'écoulement proposé au joueur pour sa lanterne (1 = celui de la lanterne)."
    end },
    { "^campement%.(%a+)%.decimales$", function(quoi)
        return "Décimales gardées avant l'arrondi final (" .. Lisible(quoi) .. ")."
    end },
}

-- L'aide d'un chemin : la sienne, sinon celle de sa famille, sinon rien.
function Vue.Aide(chemin)
    chemin = tostring(chemin or "")
    if Vue.aides[chemin] then return Vue.aides[chemin] end
    for _, m in ipairs(Vue.aidesMotifs) do
        local captures = { chemin:match(m[1]) }
        if captures[1] ~= nil then
            local ok, texte = pcall(m[2], unpack(captures))
            if ok and texte then return texte end
        end
    end
end
