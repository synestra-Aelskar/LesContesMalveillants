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

E.pv = {
    base = 2,
    parNiveau = 1.5,
    parConstitution = 0.25,
    parVitalite = 3,          -- points secondaires investis en vitalite
}

E.fatigue = {
    base = 4,
    parNiveau = 2,
    parEsprit = 1,
    parConstitution = 2,
    parEndurance = 1,         -- l'expertise Endurance
    parSecondaire = 3,        -- points secondaires investis en fatigue
}

E.initiative = {
    parNiveau = 2,
    parEsprit = 2,
    parPerception = 2,
}

E.deplacement = {
    terrestre = 8,
    nage = 5,
    vol = 0,
    parSecondaire = 1,
}

-- ===== Emplacements d'objets ===============================================
-- Combien d'objets de chaque categorie on peut porter a la fois. Pas de place
-- precise (tete, mains...) : un emplacement accueille n'importe quel objet de
-- sa categorie. Valide par l'utilisateur.

E.emplacements = {
    arme = 1,
    equipement = 5,
    accessoire = 5,
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
    plafond = { base = 3, parConstitution = 0.25 },
}

-- ===== Statistiques secondaires ============================================
-- `cout` : ce que coute UN point dans ce pool.
-- `plafond` : combien de points on peut y mettre, au niveau courant.
-- L'ordre est celui de l'ecran de creation.

E.secondaires = {
    { id = "sec_vitalite",    label = "Vitalité",                cout = 1, plafond = { parNiveau = 2 } },
    { id = "sec_fatigue",     label = "Fatigue",                 cout = 1, plafond = { parNiveau = 2 } },
    { id = "sec_initiative",  label = "Initiative",              cout = 1, plafond = { parNiveau = 4 } },
    -- Le point d'action est la ressource rare : huit points secondaires, et un
    -- plafond qui ne monte que d'un niveau sur trois.
    { id = "sec_pa",          label = "Points d'action",         cout = 8, plafond = { base = 1, parNiveau = 1 / 3 } },
    { id = "sec_deplacement", label = "Déplacement",             cout = 2, plafond = { parNiveau = 2 } },
    { id = "sec_penetration", label = "Pénétration",             cout = 1, plafond = { parNiveau = 2 } },
    { id = "sec_resistance",  label = "Résistance",              cout = 1, plafond = { parNiveau = 2 } },
    { id = "sec_expertises",  label = "Expertises",              cout = 1, plafond = { parNiveau = 2 } },
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
    { id = "bouclier",         label = "Bouclier" },
    { id = "soin",             label = "Soin" },
    { id = "buff",             label = "Buff" },
    { id = "debuff",           label = "Debuff" },
    { id = "attraction",       label = "Attraction" },
    { id = "communication",    label = "Communication" },
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

-- ===== Lecture d'un bareme =================================================
-- `{ base = 1, parNiveau = 2 }` lu au niveau 5 vaut 11, arrondi a l'inferieur.

function E.Bareme(bareme, niveau)
    if type(bareme) ~= "table" then return 0 end
    niveau = tonumber(niveau) or 0
    return math.floor((tonumber(bareme.base) or 0) + (tonumber(bareme.parNiveau) or 0) * niveau)
end
