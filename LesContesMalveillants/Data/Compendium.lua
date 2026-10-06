-- Le compendium « Systeme d'Aelskar » : ses categories, figees.
--
-- Releve du compendium du template (plugin Necronicon_System_Les_contes_
-- Malveillants_MJ, compendium « aelskar », 25 categories). Chaque categorie
-- garde son nom, son type, ses champs, leur emplacement sur la carte et leurs
-- dossiers, dans l'ordre du template. Ce qui change, et pourquoi :
--
--   * pas de « + Categorie », « + Champ », dossiers de champs ni transferts :
--     la structure est ici, pas dans la sauvegarde (CLAUDE.md, regle 1) ;
--   * « PNJ » et « Fiches PNJ » ne font qu'une categorie : un PNJ de l'addon
--     est une entree qui porte sa fiche (Core/Contenus.lua) ;
--   * le bloc de statistiques des categories generiques n'est pas recopie
--     champ par champ : ce sont les cibles de bonus de la fiche (le schema),
--     rangees dans les dossiers du template (BLOC ci-dessous) ;
--   * les quelques ajouts propres a l'addon (cout d'un trait, morphologie
--     d'une race, avantage...) sont signales la ou ils sont declares.
--
-- Une categorie dit d'ou viennent ses entrees (`registre`, et `filtre` quand
-- plusieurs categories partagent un registre) et sous quelle famille le MJ en
-- cree des brouillons (`famille`, voir MJ/Brouillons.lua).

local _, LCM = ...
local C = LCM.Compendium

-- ===== Le bloc de statistiques =============================================
-- Les dossiers des categories generiques du template (Traits), dans son
-- ordre. Les champs sont ceux de la fiche ; le libelle affiche est celui du
-- schema. Accents retablis dans les noms de dossiers du template
-- (« Resistances », « Athletismes »).

C.BLOC = {
    { dossier = "Statistiques", champs = { "force", "mystique", "perception", "adresse", "esprit", "constitution" } },
    { dossier = "Pénétrations", champs = {
        "pen_tranchant", "pen_perforant", "pen_contondant", "pen_feu", "pen_eau", "pen_vent", "pen_terre",
        "pen_esprit", "pen_pourriture", "pen_lumiere", "pen_ombre", "pen_desordre", "pen_ordre", "pen_vie", "pen_mort" } },
    { dossier = "Résistances", champs = {
        "resi_tranchant", "resi_perforant", "resi_contondant", "resi_feu", "resi_eau", "resi_vent", "resi_terre",
        "resi_esprit", "resi_pourriture", "resi_lumiere", "resi_ombre", "resi_vie", "resi_mort", "resi_ordre", "resi_desordre" } },
    { dossier = "Bonus", champs = { "pa", "fatigue", "depl_terrestre", "depl_nage", "initiative" } },
    { dossier = "Observations", champs = {
        "vue", "odorat_gout", "ouie", "toucher", "investigation", "elementaire", "cosmique", "pistage",
        "communication" } },
    { dossier = "Athlétismes", champs = {
        "puissance", "projection", "prise", "equilibre", "acrobaties", "escalade", "resistance", "endurance", "course", "nage" } },
    { dossier = "Filouteries", champs = {
        "discretion", "deguisement", "vol_a_la_tire", "crochetage", "escamotage", "evasion", "sabotage" } },
    { dossier = "Attaques & Défense", champs = {
        "force_attaque", "mystique_attaque", "perception_attaque", "defense_constitution" } },
    { dossier = "Bouclier et Soin", champs = {
        "force_bouclier", "mystique_bouclier", "constitution_bouclier", "mystique_soin", "constitution_soin" } },
    { dossier = "Buff", champs = {
        "force_buff", "mystique_buff", "perception_buff", "constitution_buff", "duree_buff", "puissance_buff" } },
    { dossier = "Perce-Armure", champs = { "force_perce_armure", "mystique_perce_armure", "perception_perce_armure" } },
    { dossier = "Brise-Armure", champs = { "force_brise_armure", "mystique_brise_armure", "perception_brise_armure" } },
    { dossier = "Provocation", champs = {
        "force_provocation", "constitution_provocation", "esprit_provocation", "mystique_provocation" } },
    { dossier = "Intimidation", champs = {
        "force_intimidation", "constitution_intimidation", "esprit_intimidation", "mystique_intimidation" } },
    { dossier = "Saignement", champs = { "force_saignement", "mystique_saignement", "perception_saignement" } },
    { dossier = "Empoisonnement", champs = {
        "mystique_empoisonnement", "perception_empoisonnement", "constitution_empoisonnement" } },
    { dossier = "Debuff", champs = {
        "force_debuff", "mystique_debuff", "perception_debuff", "constitution_debuff", "duree_debuff", "puissance_debuff" } },
    { dossier = "Mécanique de compétence", champs = {
        "meca_attaque_simple", "meca_perce_armure", "meca_brise_armure", "meca_provocation", "meca_intimidation",
        "meca_bouclier", "meca_soin", "meca_buff",
        "meca_debuff", "meca_attraction", "meca_repulsion", "meca_immobilisation",
        "meca_entrave", "meca_deviation", "meca_levitation", "meca_intervention", "meca_permutation",
        "meca_dissipation", "meca_creation", "meca_confusion", "meca_controle_mental", "meca_illusion" } },
}

-- Ordre des dossiers d'une categorie generique : celui du template, ou le
-- dossier « General » (icone, type, etat, description, metiers) vient juste
-- apres « Statistiques ». C'est aussi l'ordre des colonnes du tableau.
local DOSSIERS_GENERIQUES = { "Statistiques", "Général" }
for index = 2, #C.BLOC do DOSSIERS_GENERIQUES[#DOSSIERS_GENERIQUES + 1] = C.BLOC[index].dossier end

-- ===== Fabriques de champs =================================================

local function Icone()
    -- Toujours cachee sur la carte (le template la montre a cote du titre),
    -- toujours premiere colonne du tableau.
    return { cle = "icone", label = "Icone", type = "icone", emplacement = "meta", libelle = false }
end

local function Description(avecLibelle, typeChamp)
    return { cle = "description", label = "Description", type = typeChamp or "texte_long",
             emplacement = "body", libelle = avecLibelle == true }
end

-- Une categorie generique du template : Type (liste), Etat (jauge),
-- Description, Metier, et le bloc de statistiques.
local function Generique(def)
    local champs = {
        Icone(),
        { cle = "type", label = "Type", type = "liste", source = "listes:" .. def.liste, emplacement = "header" },
        { cle = "etat", label = "Etat", type = "jauge", emplacement = "meta", defaut = { courant = 100, max = 100 } },
        Description(true),
        { cle = "metiers", label = "Metier", type = "liste", source = "metiers", multiple = true, emplacement = "body" },
    }
    for _, champ in ipairs(def.extras or {}) do champs[#champs + 1] = champ end
    -- Ajout de l'addon (3 octobre 2026) : le jeu d'equilibrage et la rarete
    -- de l'entree (Core/Forge.lua). Des qu'un jeu vise la categorie, le MJ
    -- doit en choisir un pour enregistrer, et le bareme s'applique.
    champs[#champs + 1] = { cle = "forge", label = "Forge", type = "liste", source = "forge:" .. def.id,
                            emplacement = "meta" }
    def.champs = champs
    def.statistiques = "bonus"
    -- Ecart au template (4 octobre 2026, demande du MJ) : le tableau ne
    -- montre que la description apres l'icone, l'ID et le nom, pas une
    -- colonne par statistique. Les statistiques se lisent dans « Voir ».
    def.colonnesTableau = def.colonnesTableau or { "description" }
    def.dossiers = DOSSIERS_GENERIQUES
    def.sousCategorie = "type"
    def.type = "generic"
    -- L'avantage (relance, garde le meilleur) est une regle de l'addon, pas
    -- un champ du template : il a son onglet dans l'editeur et sa ligne en pied
    -- de carte, sans quoi il disparaitrait a la premiere modification.
    if def.avantage ~= false then
        champs[#champs + 1] = { cle = "avantage", label = "Avantage", type = "avantage", emplacement = "footer" }
    end
    return C.Categorie(def)
end

-- ===== Les categories, dans l'ordre du template ===========================

C.Categorie({
    id = "information", label = "Information", type = "generic",
    icone = "Interface\\ICONS\\eps_arc_door_waycrest_double",
    registre = "Informations", famille = "informations",
    dossiers = { "Général" },
    champs = { Icone(), Description(true, "texte") },
})

-- Les quatre listes de valeurs. « Table de niveaux » n'a de sens que pour les
-- metiers (la table XP METIER) ; le template la propose partout, vide.
local function Liste(id, label, listeId)
    C.Categorie({
        id = id, label = label, type = "list",
        registre = "Listes", famille = "listes",
        filtre = function(element) return element.liste == listeId end,
        defaut = { liste = listeId },
        champs = {
            Icone(), Description(false),
            { cle = "niveaux", label = "Table de niveaux", type = "table_niveaux", emplacement = "meta", carte = false },
        },
    })
end
Liste("type_armures", "Type Armures", "type_armures")
Liste("liste_armes", "Liste Armes", "armes")
Liste("liste_origine", "Liste origine", "origines")
Liste("liste_ressources", "Liste ressources", "ressources")

-- Les metiers sont figes dans Data/Metiers.lua (du code, pas du contenu de
-- seance) : la categorie les montre, le MJ ne les cree pas en jeu. Leur
-- table de niveaux est celle de l'equilibrage, la seule.
C.Categorie({
    id = "liste_metiers", label = "Liste métiers", type = "list",
    registre = "Metiers",
    lectureSeule = "les métiers sont figés dans le code (Data/Metiers.lua).",
    lire = { niveaux = function() return "xp_metier" end },
    champs = {
        Icone(), Description(false),
        { cle = "niveaux", label = "Table de niveaux", type = "table_niveaux", emplacement = "meta", carte = false },
    },
})

C.Categorie({
    id = "connaissances", label = "Connaissances", type = "knowledge",
    registre = "Connaissances", famille = "connaissances",
    sousCategorie = "metiers",
    dossiers = { "Général" },
    champs = {
        Icone(),
        { cle = "metiers", label = "Metier", type = "liste", source = "metiers", multiple = true, emplacement = "meta" },
        { cle = "niveau", label = "Niveau", type = "texte", emplacement = "meta" },
        Description(false),
        { cle = "composants", label = "Composants", type = "composants", emplacement = "body" },
        { cle = "prerequis", label = "Prerequis", type = "prerequis", emplacement = "body" },
        { cle = "fabrication", label = "Fabrication", type = "case", emplacement = "hidden", onglet = "fabrication" },
        { cle = "resultat", label = "Entree fabriquee", type = "entree", emplacement = "hidden", onglet = "fabrication" },
        { cle = "quantite", label = "Quantite fabriquee", type = "nombre", emplacement = "hidden", onglet = "fabrication", min = 1 },
        { cle = "apprenable", label = "Peut etre appris", type = "case", emplacement = "hidden", onglet = "fabrication" },
        { cle = "xp", label = "XP par fabrication", type = "nombre", emplacement = "meta", carte = false, min = 0 },
        { cle = "niveauRequis", label = "Niveau metier requis", type = "palier", emplacement = "meta", carte = false },
        { cle = "xpPlafond", label = "Plafond XP (niveau)", type = "palier", emplacement = "meta", carte = false },
    },
})

-- La table XP METIER est un chiffre d'equilibrage : elle vit dans
-- Data/Equilibrage.lua et nulle part ailleurs. Le compendium la montre.
C.Categorie({
    id = "table_xp", label = "Table xp", type = "list_multiple",
    entrees = function()
        return { { id = "xp_metier", label = "XP METIER", lignes = LCM.Equilibrage.metiers.paliers } }
    end,
    lectureSeule = "c'est un chiffre d'équilibrage : il vit dans Data/Equilibrage.lua.",
    colonnes = { { cle = "nom", label = "Niveau" }, { cle = "xp", label = "XP requis" } },
    champs = {
        Icone(),
        { cle = "lignes", label = "Lignes de la table", type = "table_xp", emplacement = "body", carte = false },
    },
})

local function Resolution(id, label, categorie)
    C.Categorie({
        id = id, label = label, type = "action_resolution",
        registre = "Resolutions", famille = "resolutions",
        filtre = function(element) return element.categorie == categorie end,
        defaut = { categorie = categorie },
        champs = {
            Icone(),
            { cle = "natures", label = "Natures gerees", type = "texte", emplacement = "meta" },
            { cle = "feuilles", label = "Options", type = "feuilles", emplacement = "hidden" },
        },
    })
end
-- « Systeme-Resolution-Action » est retiree le 4 octobre 2026 : toutes ses
-- entrees sont passees dans le code (Data/ActionsBoutons.lua, Data/
-- Receptions.lua), elle restait vide.

C.Categorie({
    id = "calculateurs", label = "Calculateur", type = "calculateur",
    registre = "Calculateurs", famille = "calculateurs",
    champs = {
        Icone(),
        { cle = "formule", label = "Formule du calcul", type = "texte_long", emplacement = "body", carte = false },
        { cle = "injections", label = "Injections attendues", type = "injections", emplacement = "body", carte = false },
        { cle = "lignes", label = "Lignes de calcul", type = "calcul", emplacement = "hidden" },
    },
})

C.Categorie({
    id = "sacs", label = "Sacs", type = "container",
    registre = "Sacs", famille = "sacs",
    dossiers = { "Général" },
    -- Tout dans un seul onglet : un sac a trois champs, les repartir sur deux
    -- onglets demandait un clic pour voir la moitie de si peu.
    ongletUnique = true,
    champs = {
        Icone(),
        -- « Slotcount » dans le template : libelle traduit.
        -- Sac ou sacoche : il faut choisir, et ce choix commande tout le
        -- rangement (ou l'on peut l'equiper, et ce qu'il peut contenir).
        { cle = "nature", label = "Nature", type = "choix", emplacement = "meta", obligatoire = true,
          options = { { id = "sac", label = "Sac" }, { id = "sacoche", label = "Sacoche" } } },
        { cle = "places", label = "Emplacements", type = "nombre", emplacement = "meta", min = 1 },
        { cle = "placesDevise", label = "Emplacements devise", type = "nombre", emplacement = "meta", min = 0 },
    },
})

C.Categorie({
    id = "devises", label = "Devises", type = "currency",
    registre = "Devises", famille = "devises",
    champs = { Icone(), Description(false) },
})

-- Ajout de l'addon (3 octobre 2026) : les jeux d'equilibrage de la forge,
-- ranges juste avant les categories qu'ils equilibrent
-- (Core/Forge.lua). Ils se creent ici comme toute entree ; leur structure
-- (raretes, reglages par statistique) ne tient pas dans l'editeur a champs,
-- d'ou `editeur` : « Nouvelle entree » et la roue ouvrent l'equilibrage du
-- compagnon MJ (MJ/Forge.lua).
C.Categorie({
    id = "jeux_equilibrage", label = "Jeux d'équilibrage", type = "generic",
    registre = "Forge", famille = "jeux", editeur = "ForgeUI",
    dossiers = { "Général" },
    lire = {
        cible = function(jeu)
            local categorie = C.Get(jeu.categorie)
            return categorie and categorie.label or jeu.categorie
        end,
        raretes = function(jeu)
            local out = {}
            for _, r in ipairs(jeu.raretes or {}) do
                out[#out + 1] = string.format("|cff%s%s|r %d", r.couleur, r.label, r.points)
            end
            return table.concat(out, "  ·  ")
        end,
        reglages = function(jeu)
            local n = 0
            for _ in pairs(jeu.champs or {}) do n = n + 1 end
            return n
        end,
    },
    champs = {
        { cle = "cible", label = "Catégorie", type = "texte", emplacement = "meta" },
        { cle = "reglages", label = "Statistiques réglées", type = "nombre", emplacement = "meta" },
        { cle = "raretes", label = "Raretés", type = "texte", emplacement = "body" },
    },
})

Generique({ id = "ressources", label = "Ressources", liste = "ressources",
    registre = "Ressources", famille = "ressources", avantage = false })

-- Armes, armures, accessoires : un seul registre (les objets), une
-- categorie fixe chacun. Le template donne a Armures et Accessoires la
-- « Liste Armes » pour Type : corrige en « Type Armures » pour les armures ;
-- les accessoires gardent la liste du template, faute d'une liste a eux.
local function Objet(id, label, categorie, liste, extras)
    Generique({ id = id, label = label, liste = liste,
        registre = "Objets", famille = "objets",
        filtre = function(element) return element.categorie == categorie end,
        defaut = { categorie = categorie }, extras = extras })
end
Objet("armes", "Armes", "arme", "armes", {
    -- Ajout de l'addon (5 octobre 2026) : combien de mains l'arme demande.
    -- Une a une main laisse la place d'un bouclier ; une a deux mains prend
    -- les deux emplacements.
    { cle = "taille", label = "Emplacements", type = "nombre", emplacement = "meta",
      min = 1, max = 2, defaut = 1 },
})
Objet("armures", "Armures", "equipement", "type_armures", {
    -- Ajout de l'addon (2 octobre 2026) : ce qu'une piece porte vers la jauge
    -- #armure. Laisse vide, elle vaut Equilibrage.armure.parDefaut.
    { cle = "armure", label = "Armure", type = "nombre", emplacement = "meta", min = 0,
      defaut = LCM.Equilibrage.armure.parDefaut },
})
Objet("accessoires", "Accessoires", "accessoire", "armes")

-- Races, traits, etats, maladies, apprentissages : le template leur donne la
-- « Liste Armes » pour Type, sans doute par copie ; garde tel quel, a trancher.
Generique({ id = "races", label = "Races", liste = "armes",
    registre = "Races", famille = "races",
    defaut = { morphology = "humanoide" },
    extras = {
        -- Ajout de l'addon : une race engendre le corps (Core/Body.lua).
        { cle = "morphology", label = "Morphologie", type = "liste", source = "morphologies", emplacement = "meta" },
        -- Ajout de l'addon (3 octobre 2026) : une race que seul le MJ donne.
        -- Un joueur ne la voit pas dans sa creation et ne peut pas la choisir.
        { cle = "mjSeulement", label = "Réservée au MJ", type = "case", emplacement = "meta" },
    } })

Generique({ id = "traits", label = "Traits", liste = "armes",
    registre = "Traits", famille = "traits",
    extras = {
        -- Ajout de l'addon : le template mettait ce chiffre dans les tags.
        { cle = "cout", label = "Coût", type = "nombre", emplacement = "meta", min = 1, max = 4, defaut = 1 },
    } })

Generique({ id = "etats", label = "Etats", liste = "armes",
    registre = "Etats", famille = "etats",
    filtre = function(element) return element.categorie ~= "maladie" end,
    defaut = { categorie = "etat" },
    extras = {
        -- Ajout de l'addon : la fenetre Sante du template range aussi des
        -- « Etats intangibles », que le compendium n'avait pas.
        { cle = "categorie", label = "Conteneur", type = "liste", source = "etats", emplacement = "meta" },
    } })

Generique({ id = "maladies", label = "Maladies", liste = "armes",
    registre = "Etats", famille = "etats",
    filtre = function(element) return element.categorie == "maladie" end,
    defaut = { categorie = "maladie" } })

Generique({ id = "apprentissages", label = "Apprentissage", liste = "armes",
    registre = "Apprentissages", famille = "apprentissages" })

Resolution("actions_mj", "Actions-MJ", "mj")

-- Le profil du template : dans Necronicon, un instantane de fenetres a
-- importer. Ici le profil EST le code : l'entree decrit ce que l'addon
-- reproduit (le menu des fenetres), sans rien a importer.
C.Categorie({
    id = "template", label = "TEMPLATE", type = "profile",
    entrees = function()
        local fenetres = {}
        local function Parcourir(noeuds)
            for _, n in ipairs(noeuds or {}) do
                if n.enfants then Parcourir(n.enfants) else fenetres[#fenetres + 1] = n.label end
            end
        end
        Parcourir(LCM.UI and LCM.UI.Menu and LCM.UI.Menu.STRUCTURE)
        return { {
            id = "template_fiche_lvl_5", label = "Template Fiche LVL 5 - Contes Malveillants V2",
            icone = "Interface\\Icons\\INV_Misc_Book_11",
            source = "Template Fiche LVL 5 - Contes Malveillants V2",
            fenetres = fenetres,
        } }
    end,
    lectureSeule = "le profil est le code de l'addon : il ne se modifie pas en jeu.",
    dossiers = { "Général" },
    champs = {
        Icone(),
        { cle = "source", label = "Profil source", type = "texte", emplacement = "meta" },
        { cle = "fenetres", label = "Fenetres", type = "nombre_liste", emplacement = "meta" },
        { cle = "fenetres", label = "Fenêtres reproduites", type = "liste_texte", emplacement = "body", colonne = false },
    },
})

-- PNJ et Fiches PNJ du template, fondus : un PNJ porte sa fiche. La carte
-- montre ce que la fiche repartit (rangé par sections du schema) et ce
-- qu'elle porte.
C.Categorie({
    id = "pnj", label = "PNJ", type = "pnj",
    registre = "PNJ", famille = "pnj",
    statistiques = "valeurs",
    dossiers = { "Général" },
    champs = {
        Icone(),
        { cle = "race", label = "Race", type = "liste", source = "races", emplacement = "meta", valeur = true },
        { cle = "niveau", label = "Niveau", type = "nombre", emplacement = "meta", valeur = true },
        Description(false),
        { cle = "traits", label = "Traits", type = "liste", source = "traits", multiple = true, emplacement = "body" },
        { cle = "equipement", label = "Équipement", type = "contenu", source = "objets", emplacement = "body" },
    },
})
