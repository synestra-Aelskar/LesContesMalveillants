-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par l'outil « Exporter les brouillons » le 2026-10-08 18:42.
--  Source : ce que le MJ a cree en jeu. Toute retouche manuelle sera perdue au
--  prochain export.
--
--  Pour changer une entree : la corriger en jeu, puis reexporter.
-- ============================================================================

local _, LCM = ...

-- ----- objets (9) --------------------------------------------------
LCM.Publier(LCM.Objets, {
    bonus = {
        pen_contondant = 4,
        pen_ombre = 12,
        pen_perforant = 10,
        pen_tranchant = 10,
    },
    categorie = "arme",
    couleurTitre = "4D8CFF",
    description = "Une lame sombre, courte, imbibée d'ombre. Toucher cette arme sans être liée à son maitre s'accompagne d'une douleur oblitérante.",
    forge = "equilibrage_arme/rare",
    icone = "Interface\\ICONS\\w3reforgeddaggerofescape",
    id = "lcm_64a651_6ac7bbe9_36c708be_0001_efdd32",
    label = "Dague du culte de l'assassin",
    tags = "Rare",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    armure = 2,
    avantage = {},
    bonus = {
        discretion = 1,
        resi_contondant = 4,
        resi_feu = 3,
        resi_lumiere = -2,
        resi_perforant = 4,
        resi_tranchant = 4,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Une tenue sombre et délicate, qui semble clairement imbibée d'un manteau d'ombre.",
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_leather_raidrogue_p_01chest",
    id = "lcm_64a651_6ac7be10_36cf7992_0004_fb40af",
    label = "Tenue d'assassin du culte.",
    tags = "Rare",
})

LCM.Publier(LCM.Objets, {
    armure = 2,
    avantage = {},
    bonus = {
        discretion = 2,
        resi_contondant = 3,
        resi_feu = 2,
        resi_lumiere = -2,
        resi_perforant = 3,
        resi_tranchant = 3,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "..Nimbée d'ombre.",
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_leather_warfrontshorde_d_01_pants",
    id = "lcm_64a651_6ac7be6a_36d0dc15_0005_7dbd88",
    label = "Soutane des ombres",
    tags = "Rare",
})

LCM.Publier(LCM.Objets, {
    armure = 2,
    avantage = {},
    bonus = {
        discretion = 2,
        resi_contondant = 3,
        resi_feu = 2,
        resi_lumiere = -2,
        resi_perforant = 3,
        resi_tranchant = 3,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Nimbée d'ombre..",
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_boots_leather_cataclysm_b_02",
    id = "lcm_64a651_6ac7beb5_36d1fee9_0006_6b2588",
    label = "Bottes des ombres",
    tags = "Rare",
})

LCM.Publier(LCM.Objets, {
    armure = 2,
    avantage = {},
    bonus = {
        discretion = 2,
        resi_contondant = 3,
        resi_feu = 2,
        resi_lumiere = -2,
        resi_perforant = 3,
        resi_tranchant = 3,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Nimbée d'ombre.",
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_glove_leather_zuldazarraid_d_01",
    id = "lcm_64a651_6ac7beea_36d2cf27_0007_8cf26e",
    label = "Gants du cultiste des ombres",
    tags = "Rare",
})

LCM.Publier(LCM.Objets, {
    bonus = {
        discretion = 2,
        resi_contondant = 3,
        resi_feu = 2,
        resi_perforant = 2,
        resi_tranchant = 3,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Nimbée d'ombre.",
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_bracer_leather_zuldazarraid_d_01",
    id = "lcm_64a651_6ac7bf11_36d36743_0008_d09027",
    label = "Voile du corbeau",
    tags = "Rare",
})

LCM.Publier(LCM.Objets, {
    bonus = {
        crochetage = 2,
        discretion = 2,
        evasion = 2,
        sabotage = 2,
        vol_a_la_tire = 1,
    },
    categorie = "accessoire",
    couleurTitre = "4D8CFF",
    description = "Parfait pour stocker des lames.",
    forge = "equilibrage_armure_copie/rare",
    icone = "Interface\\ICONS\\inv_cloth_mawraid_d_01_belt",
    id = "lcm_64a651_6ac7bf81_36d51ea2_0010_f1c74a",
    label = "Baudrier de l'assassin.",
    tags = "Rare",
})

LCM.Publier(LCM.Objets, {
    bonus = {
        discretion = 2,
        meca_perce_armure = 2,
        pen_ombre = 5,
    },
    categorie = "accessoire",
    couleurTitre = "4D8CFF",
    description = "Une paire de bracelet qui semble augmenter la puissance des ombres ainsi que les facultés d'assassins de son porteur.",
    forge = "equilibrage_armure_copie/rare",
    icone = "Interface\\ICONS\\dos2_shadow12",
    id = "lcm_64a651_6ac7bfb7_36d5f1de_0011_981ba7",
    label = "Bracelets du cisaire de Nocturna",
    tags = "Rare",
})

LCM.Publier(LCM.Objets, {
    avantage = {},
    bonus = {
        pen_contondant = 4,
        pen_ombre = 12,
        pen_perforant = 10,
        pen_tranchant = 10,
    },
    categorie = "arme",
    couleurTitre = "4D8CFF",
    description = "Une lame sombre, courte, imbibée d'ombre. Toucher cette arme sans être liée à son maitre s'accompagne d'une douleur oblitérante.",
    forge = "equilibrage_arme/rare",
    icone = "Interface\\ICONS\\w3reforgeddaggerofescape",
    id = "lcm_64a651_6ac7c627_36ef1069_0002_7464d5",
    label = "Seconde Dague du culte de l'assassin",
    tags = "Rare",
    taille = 1,
})

-- ----- races (1) ---------------------------------------------------
LCM.Publier(LCM.Races, {
    bonus = {
        adresse = "3",
        constitution = "3",
        esprit = "3",
        force = "3",
        mystique = "3",
        pen_contondant = "3",
        pen_desordre = "3",
        pen_eau = "3",
        pen_esprit = "3",
        pen_feu = "3",
        pen_lumiere = "3",
        pen_mort = "3",
        pen_ombre = "3",
        pen_ordre = "3",
        pen_perforant = "3",
        pen_pourriture = "3",
        pen_terre = "3",
        pen_tranchant = "3",
        pen_vent = "3",
        pen_vie = "3",
        perception = "3",
        resi_contondant = "3",
        resi_desordre = "3",
        resi_eau = "3",
        resi_esprit = "3",
        resi_feu = "3",
        resi_lumiere = "3",
        resi_mort = "3",
        resi_ombre = "3",
        resi_ordre = "3",
        resi_perforant = "3",
        resi_pourriture = "3",
        resi_terre = "3",
        resi_tranchant = "3",
        resi_vent = "3",
        resi_vie = "3",
    },
    couleurTitre = "FF8CB8",
    description = "Un humain. tout ce qu'il y a de plus humain.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\achievement_character_human_male",
    id = "humain",
    label = "Humain",
    morphology = "humanoide",
    tags = "Commun",
})

-- ----- traits (7) --------------------------------------------------
LCM.Publier(LCM.Traits, {
    bonus = {
        acrobaties = 1,
        escalade = 1,
        resistance = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Au quotidien, Reika se meut avec la grâce d'un automate d'apparat. Ses gestes sont doux, lents et harmonieux, chaque mouvement soigneusement mesuré, comme il sied à une jeune dame de bonne famille.\n\nMais lorsque les circonstances l'exigent, cette délicatesse cède la place à une mécanique autrement plus troublante. Son corps s'articule avec une précision presque inhumaine, enchaînant les mouvements avec la célérité et l'exactitude d'une horloge parfaitement réglée.\n\nAprès tout, sous les apparence",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_viktor_gloriousevolution",
    id = "automate_danseuse",
    label = "Automate danseuse",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        pa = 1,
        resi_desordre = -2,
        resi_ordre = -2,
    },
    couleurTitre = "FF8CB8",
    description = "En quête de perfection, il ne suffisait guère à sa créatrice de produire une âme artificielle indiscernable d'une âme naturelle. Dans sa poursuite du progrès, elle dota sa création de la faculté de se façonner elle-même, lui offrant ainsi la plus grande des aventures : celle de passer une vie à expérimenter toutes les vies.\n\nAinsi, Reika, fruit de recherches que nul ne saurait pleinement comprendre, dispose de ce que sa créatrice a sobrement nommé « l'âme mouvante ».\n\nContrepied peu dissimulé à",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_camille_adaptivedefense",
    id = "cycle_construire_et_deconstruire",
    label = "Cycle : Construire et déconstruire.",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        discretion = 2,
        pen_ombre = 3,
        resi_lumiere = -2,
    },
    couleurTitre = "FF8CB8",
    description = "Ce personnage manie les ombres avec une aisance terrifiante.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_rogue_shadowdance",
    id = "lcm_64a651_6ac76e82_3598aaf8_0001_f2b89d",
    label = "Danseur des ombres",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        discretion = 1,
        meca_perce_armure = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Autrefois quelqu'un.. Il n'aspire désormais qu'à s'élever dans la hiérarchie du culte de Nocturna.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\hots_sylvanas_shadowdagger",
    id = "lcm_64a651_6ac7710f_35a2aedc_0003_6b06bc",
    label = "Cisaire ambitieux.",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        deguisement = 1,
        discretion = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Nul ne sait qui des nôtres est si ce n'est lui-même.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\spell_arcane_prismaticcloak",
    id = "lcm_64a651_6ac7715c_35a3dd0b_0004_ba2485",
    label = "Terreur des ombres.",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        pen_ombre = 2,
        resi_lumiere = 4,
    },
    couleurTitre = "FF8CB8",
    description = "Vos lumières nous font chaux, car dans l'abnégation du culte, nous servons, nous endurons.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\d3_shadowpower",
    id = "lcm_64a651_6ac77195_35a4bae4_0005_9cc402",
    label = "Résilience nocturne",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    avantage = {},
    bonus = {
        acrobaties = 1,
        meca_buff = 3,
        meca_soin = -2,
    },
    couleurTitre = "FF8CB8",
    cout = 1,
    description = "Il ne suffit guère de savoir se façonner soi-même lorsque le monde qui nous entoure persiste à suivre sa propre mélodie. Reika dispose d'une attention particulière; qui, a l'image d'un instrument que l'on accorde, lui offre la mesure des subtilités qui composent l'équilibre d'un individu et d'y apporter quelques ajustements.\n\nUn mouvement, une respiration, une circulation magique ou le moindre déséquilibre deviennent autant d'occasions d'intervenir pour elle. Tantôt pour accompagner ses alliés,",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_item_puppeteer",
    id = "violoniste_de_la_marionnette",
    label = "Violoniste de la marionnette.",
    tags = "Commun",
})
