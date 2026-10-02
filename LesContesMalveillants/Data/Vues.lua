-- Les fenetres tirees de la fiche, telles que le template Necronicon les
-- organise (« Template Fiche LVL 5 - Contes Malveillants V2 ») : memes
-- fenetres, memes onglets, memes blocs, dans le meme ordre.
--
-- Chaque vue habille l'entree du menu qui porte son identifiant. Elle ne
-- declare pas de champ : elle designe ce qui existe dans la feuille (voir
-- Core/Vues.lua).

local _, LCM = ...
local Vues = LCM.Vues

-- Regles : huit onglets, seul FONDAMENTAUX est rempli dans le template. Chaque
-- separateur y ouvre un bloc, suivi de sa description en <taille=14>. Texte
-- d'origine, coquilles comprises ; le dernier separateur n'a pas de texte.
local TAILLE_REGLES = 14
Vues.Add({
    id = "regles", titre = "Règles",
    largeur = 520, hauteur = 600,
    sansPersonnage = true,
    onglets = {
        { id = "fondamentaux", label = "Fondamentaux", blocs = {
            { label = "Principes des Contes Malveillants.", taille = TAILLE_REGLES, texte =
                "Les contes malveillants sont un univers de jeu de rôle dans lequel chaque joueur incarne un "
                .. "personnage disposant de ses propres caractéristiques, compétences et capacités.\n\n"
                .. "Les personnages évoluent au fil des aventures, développent leurs aptitudes et affrontent des "
                .. "situations dont l'issue dépend de leurs décisions, de leurs capacités et du hasard.\n\n"
                .. "Le système repose sur une combinaison de caractéristiques, de jets de dés et de différentes "
                .. "ressources permettant de déterminer les possibilités de chaque personnage." },
            { label = "Maitres du jeu", taille = TAILLE_REGLES, texte =
                "Le ou les maîtres du jeu, ou MJ, sont responsables de la narration, de l'environnement et des "
                .. "personnages non joueurs.\n\n"
                .. "Ils décrivent  les situations auxquelles les personnages sont confrontés, interprètent les "
                .. "conséquences de leurs actions et déterminent les difficultés des épreuves.\n\n"
                .. "Lorsque les règles ne permettent pas de résoudre directement une situation, le ou les MJ "
                .. "disposent de l'autorité nécessaire pour prendre une décision cohérente avec le contexte." },
            { label = "Les joueurs :", taille = TAILLE_REGLES, texte =
                "Un personnage peut entreprendre toute action cohérente avec ses capacités et son environnement.\n\n"
                .. "Les actions courantes ne nécessitent pas systématiquement de jet. En revanche, lorsqu'une action "
                .. "présente une difficulté, un risque ou une opposition, le MJ peut demander au joueur d'effectuer "
                .. "un test.\n\n"
                .. "Le choix des caractéristiques et des compétences employées dépend de la nature de l'action.\n\n"
                .. "Il est exigé des joueurs d'être en mesure de jouer dans la limite des capacités de son "
                .. "personnage." },
            { label = "Le principe des tests", taille = TAILLE_REGLES, texte =
                "Les tests permettent de déterminer l'issue des actions dont la réussite est incertaine.\n\n"
                .. "Lorsqu'un test est nécessaire, le personnage utilise les caractéristiques et les compétences "
                .. "correspondant à l'action entreprise. Le résultat est comparé à une difficulté ou, lorsqu'il "
                .. "affronte un adversaire, à un résultat opposé.\n\n"
                .. "La réussite ou l'échec du test détermine les conséquences de l'action, et il est généralement à "
                .. "charge du joueur de dérouler une narration en cohérence avec le résultat obtenu. \n\n"
                .. "Un maitre du jeu demeure néanmoins en mesure d'offrir ou d'imposer des conditions de narration." },
            { label = "[NF] - No Fatigue", texte = "" },
        } },
        { id = "personnages",  label = "Personnages",         vide = true },
        { id = "ressources",   label = "Ressources",          vide = true },
        { id = "tests",        label = "Tests et Expertises", vide = true },
        { id = "combat",       label = "Combat",              vide = true },
        { id = "magie",        label = "Magie et effets",     vide = true },
        { id = "equipement",   label = "Équipement",          vide = true },
        { id = "progression",  label = "Progression",         vide = true },
    },
})

-- Fiche : STATISTIQUES (Generale, Statistiques, Caracteristiques,
-- Deplacement), FACULTES (Physiques), TRAITS.
Vues.Add({
    id = "fiche", titre = "Fiche",
    largeur = 520, hauteur = 600,
    onglets = {
        { id = "statistiques", label = "Statistiques", blocs = {
            -- La jauge des PV seule : les zones sont dans Sante. La surcharge
            -- des PV n'apparait qu'au MJ.
            { label = "Générale", champs = { { id = "corps", zones = false }, "armure", "fatigue", "pa", "pv_max_override" } },
            { label = "Statistiques", champs = { "force", "mystique", "perception", "adresse", "esprit", "constitution" } },
            { label = "Caractéristiques", champs = { "initiative" } },
            { label = "Déplacement", champs = { "depl_terrestre", "depl_nage" } },
        } },
        { id = "facultes", label = "Facultés", blocs = {
            { section = { "statistiques", "facultes" }, label = "Physiques" },
        } },
        { id = "traits", label = "Traits", blocs = {
            { champs = { "traits_portes" } },
        } },
    },
})

-- Sante : Physique (les zones du corps), Etats, Maladies, Intangible (Esprit,
-- Ame et les etats intangibles) — les quatre onglets du template.
Vues.Add({
    id = "sante", titre = "Santé",
    largeur = 500, hauteur = 560,
    onglets = {
        { id = "physique", label = "Physique", blocs = {
            { label = "Parties corporelles", champs = { { id = "corps", total = false } } },
        } },
        { id = "etats", label = "États", blocs = { { conteneur = { "etats", "etat" } } } },
        { id = "maladies", label = "Maladies", blocs = { { conteneur = { "etats", "maladie" } } } },
        { id = "intangible", label = "Intangible", blocs = {
            { section = { "general", "existence" } },
            { conteneur = { "etats", "intangible" } },
        } },
    },
})

-- Equipements : Armes, Armures, Accessoires (1 / 5 / 5 emplacements).
Vues.Add({
    id = "equipement", titre = "Équipements",
    largeur = 520, hauteur = 560,
    onglets = {
        { id = "arme",       label = "Armes",       blocs = { { conteneur = { "objets", "arme" } } } },
        { id = "equipement", label = "Armures",     blocs = { { conteneur = { "objets", "equipement" } } } },
        { id = "accessoire", label = "Accessoires", blocs = { { conteneur = { "objets", "accessoire" } } } },
    },
})

-- Apprentissage : un conteneur de 60 emplacements.
Vues.Add({
    id = "apprentissage", titre = "Apprentissage",
    largeur = 520, hauteur = 580,
    blocs = { { conteneur = { "apprentissages", "apprentissage" }, label = "Apprentissages" } },
})

-- Expertises : un onglet par domaine.
Vues.Add({
    id = "expertise", titre = "Expertises",
    largeur = 520, hauteur = 580,
    onglets = {
        { id = "observations", label = "Observations", blocs = { { section = { "expertises", "observations" } } } },
        { id = "athletisme",   label = "Athlétisme",   blocs = { { section = { "expertises", "athletisme" } } } },
        { id = "filouterie",   label = "Filouterie",   blocs = { { section = { "expertises", "filouterie" } } } },
    },
})

-- Penetration & Resistances : les resistances d'abord, comme le template.
Vues.Add({
    id = "penetrations_resistances", titre = "Pénétration & Résistances",
    largeur = 520, hauteur = 580,
    onglets = {
        { id = "resistances",  label = "Résistances",  blocs = { { onglet = "resistances" } } },
        { id = "penetrations", label = "Pénétrations", blocs = { { onglet = "penetrations" } } },
    },
})

-- Deplacement : fenetre a part dans le template (son propre ecran chez
-- Necronicon, Deplacement.lua) ; ici, ses deux valeurs en attendant.
Vues.Add({
    id = "deplacement", titre = "Déplacement",
    largeur = 440, hauteur = 280,
    blocs = {
        { label = "Déplacement", champs = { "depl_terrestre", "depl_nage" } },
    },
})

-- Statistiques : le recapitulatif du template, un dossier par famille, chaque
-- ligne montrant la valeur TOTALE (race, traits, objets, etats, repartition).
-- Dossiers replies ou ouverts comme dans le template ; « Bonus » ne montre
-- que ce qu'apportent traits et objets.
do
    local E = LCM.Equilibrage
    local function Types(prefixe)
        local out = {}
        for _, t in ipairs(E.types) do out[#out + 1] = prefixe .. t.id end
        return out
    end
    local mecaniques = {}
    for _, m in ipairs(E.mecaniques) do mecaniques[#mecaniques + 1] = "meca_" .. m.id end

    Vues.Add({
        id = "statistiques", titre = "Statistiques",
        largeur = 500, hauteur = 580,
        blocs = {
            { texte = "Ci-dessous, vous retrouverez le total de l'ensemble des statistiques de votre personnage." },
            { label = "Statistiques", recap = "total", replie = true,
              champs = { "force", "mystique", "perception", "adresse", "esprit", "constitution" } },
            { label = "Pénétrations", recap = "total", replie = false, champs = Types("pen_") },
            { label = "Résistances",  recap = "total", replie = false, champs = Types("resi_") },
            { label = "Bonus", recap = "bonus", replie = false,
              champs = { "pa", "fatigue", "depl_terrestre", "depl_nage", "initiative" } },
            { section = { "expertises", "observations" }, label = "Observations", recap = "total", replie = true },
            { section = { "expertises", "athletisme" },   label = "Athlétismes",  recap = "total", replie = true },
            { section = { "expertises", "filouterie" },   label = "Filouteries",  recap = "total", replie = true },
            { section = { "combat", "attaques_defense" }, recap = "total", replie = true },
            { section = { "combat", "bouclier_soin" },    recap = "total", replie = true },
            { section = { "combat", "buff" },             recap = "total", replie = true },
            { section = { "combat", "perce_armure" },     recap = "total", replie = true },
            { section = { "combat", "brise_armure" },     recap = "total", replie = false },
            { section = { "combat", "provocation" },      recap = "total", replie = false },
            { section = { "combat", "intimidation" },     recap = "total", replie = true },
            { section = { "combat", "saignement" },       recap = "total", replie = true },
            { section = { "combat", "empoisonnement" },   recap = "total", replie = true },
            { section = { "combat", "debuff" },           recap = "total", replie = true },
            { label = "Mécanique de compétence", recap = "total", replie = true, champs = mecaniques },
        },
    })
end
