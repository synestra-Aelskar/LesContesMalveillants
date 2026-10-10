-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Construit depuis la base commune `necronicon/database/entries`.
--  Une archive d'addon est un livrable ; elle n'est jamais la source de verite.
-- ============================================================================

local _, LCM = ...

-- ----- accessoires_camping (1) -------------------------------------
LCM.Publier(LCM.AccessoiresCamping, {
    bonus = {
        recup_armure = 40,
    },
    description = "Les petits outils de Kaléa pour qu'elle répare ses équipements.",
    id = "accessoire_reparation_kalea",
    label = "Accessoire de réparation de Kaléa",
    origine = "Kaléa",
})

-- ----- listes (7) --------------------------------------------------
LCM.Publier(LCM.Listes, {
    icone = "Interface\\ICONS\\inv_jewelry_ring_03",
    id = "anneau",
    label = "Anneau",
    liste = "type_accessoires",
    maxEquipe = 2,
})

LCM.Publier(LCM.Listes, {
    icone = "Interface\\ICONS\\inv_misc_gem_pearl_03",
    id = "bijou",
    label = "Bijou",
    liste = "type_accessoires",
})

LCM.Publier(LCM.Listes, {
    icone = "Interface\\ICONS\\inv_bracer_07",
    id = "bracelet",
    label = "Bracelet",
    liste = "type_accessoires",
    maxEquipe = 2,
})

LCM.Publier(LCM.Listes, {
    icone = "Interface\\ICONS\\inv_misc_cape_11",
    id = "cape",
    label = "Cape",
    liste = "type_accessoires",
    maxEquipe = 1,
})

LCM.Publier(LCM.Listes, {
    icone = "Interface\\ICONS\\inv_belt_15",
    id = "ceinture",
    label = "Ceinture",
    liste = "type_accessoires",
    maxEquipe = 1,
})

LCM.Publier(LCM.Listes, {
    icone = "Interface\\ICONS\\inv_jewelry_necklace_07",
    id = "pendentif",
    label = "Pendentif",
    liste = "type_accessoires",
    maxEquipe = 1,
})

LCM.Publier(LCM.Listes, {
    icone = "Interface\\ICONS\\inv_misc_idol_03",
    id = "talisman",
    label = "Talisman",
    liste = "type_accessoires",
})

-- ----- objets (27) --------------------------------------------------
LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        depl_nage = -1,
        depl_terrestre = -1,
        pen_contondant = 2,
        pen_perforant = 10,
    },
    categorie = "arme",
    couleurTitre = "FF8CB8",
    description = "C'est un arc de bonne facture, souple et résistant. Il apparaît que la barde n'a jamais eu besoin de plus.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/commun",
    icone = "Interface\\ICONS\\eps_wc3h_woodenbow",
    id = "arc_court",
    label = "Arc court",
    remplacePublie = true,
    tags = "Commun",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    bonus = {
        depl_nage = -1,
        depl_terrestre = -1,
        meca_buff = 1,
        meca_debuff = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Une bannière dont le drapé change au gré des volontés de celui qui la porte, une fois planté dans le sol, elle peut diffuser divers effet bénéfique pour les alliés de son utilisateur ou néfaste pour ses ennemis.\n\nUne bannière qui peut prendre plusieurs forme, soit augmentant les capacités des alliés ou en causant des troubles pour les ennemis. \nSi la bannière est détruite, Caedicia souffre d'un malus temporaire particulièrement lourd.",
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_banner_tolbarad_alliance",
    id = "banniere_de_toute_les_gloires",
    label = "Bannière de toute les gloires",
    tags = "Commun",
})

LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        meca_buff = 1,
        meca_soin = 1,
        pen_contondant = 4,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Ce bâton, réalisé à partir du bois de la forêt d'Elestria, a pour principale fonction d'aider un randonneur à se déplacer sous ces frondaisons. Il est orné de l'emblème de la Garde et permet à son porteur de se défendre en cas de problème.\n\nArme à deux mains, au corps à corps.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_staff_17",
    id = "baton_forestier",
    label = "Bâton forestier",
    remplacePublie = true,
    tags = "Inhabituel",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    ["bonus.depl_nage"] = "-1",
    ["bonus.resi_contondant"] = "1",
    ["bonus.resi_perforant"] = "1",
    ["bonus.resi_tranchant"] = "2",
    categorie = "equipement",
    couleurTitre = "FF8CB8",
    description = "Armure du pauvre.",
    forge = "equilibrage_arme_copie/commun",
    icone = "Interface\\ICONS\\inv_chest_chain_12",
    id = "bridandine_de_pauvre",
    label = "Bridandine de pauvre",
    tags = "Commun",
})

LCM.Publier(LCM.Objets, {
    bonus = {
        investigation = 2,
        pistage = 3,
    },
    categorie = "accessoire",
    couleurTitre = "4DE04D",
    description = "Un étrange compas qui semble mettre en évidence les traces de pas laissée au sol.",
    forge = "equilibrage_armure_copie/inhabituel",
    icone = "Interface\\ICONS\\eps_arc_xtracompass",
    id = "compas_du_traqueur",
    label = "Compas du Traqueur",
    tags = "Inhabituel",
})

LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        pen_contondant = 1,
        pen_perforant = 2,
        pen_tranchant = 1,
    },
    categorie = "arme",
    couleurTitre = "FF8CB8",
    description = "Un simple couteau permettant de récupérer la peau d'un animal mort.\nPermet d'obtenir la peau d'un animal mort sous forme d'item vendable ou de composant.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme/commun",
    icone = "Interface\\ICONS\\trade_archaeology_silverdagger",
    id = "couteau_a_depecer",
    label = "Couteau à dépecer",
    remplacePublie = true,
    tags = "Commun",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    armure = 2,
    avantage = {},
    bonus = {
        depl_nage = -1,
        depl_terrestre = -1,
        puissance = 1,
        resi_contondant = 6,
        resi_perforant = 5,
        resi_tranchant = 5,
    },
    categorie = "equipement",
    couleurTitre = "4D8CFF",
    description = "Une armure composée d'un, alliage léger sans doute fait de mithril permet à son porteur de rester mobile. Néanmoins l'armure  porte des enchantements qui décuple la force du porteur, lui permettant de supporter un tel fardeau.\n\nArmure Lourde mais considérée comme une armure de catégorie plus légère au niveau du poids.",
    forge = "equilibrage_arme_copie/rare",
    icone = "Interface\\ICONS\\inv_chest_leather_11",
    id = "ensemble_harnois_blanc",
    label = "Harnois blanc",
    tags = "Rare",
})

LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        meca_brise_armure = 1,
        pen_contondant = 4,
        pen_perforant = 2,
        pen_tranchant = 6,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Une hallebarde forgée en thorium et pourvue de nombreux enchantement, l'arme est particulièrement lourde du fait de l'alliage qui la compose. Un utilisateur habile peut ouvrir des armures et tenir tête à une foule d'ennemis. On raconte même qu'elle permet à son utilisateur de briser le sol.\n\nEn puissant dans la magie de l'arme, l'utilisateur peut fracasser le sol sous les pieds de ses adversaires pour les faire tomber à la renverse.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_polearm_2h_maw_c_01",
    id = "hallebarde_du_briseur_de_ligne",
    label = "Hallebarde du briseur de ligne",
    tags = "Inhabituel",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        acrobaties = -2,
        depl_nage = -1,
        depl_terrestre = -1,
        equilibre = -2,
        escalade = -2,
        initiative = -1,
        meca_intervention = 1,
        pen_contondant = 2,
        resi_contondant = 3,
        resi_perforant = 3,
        resi_tranchant = 3,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "le pavois est intégralement composé de métal le rendant particulièrement lourd. Porte des enchantements qui décuple la force du porteur, lui permettant de supporter un tel fardeau.\nLe pavois donne un instinct de protectecteur.",
    etat = {
        courant = 30,
        max = 30,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_shield_1h_kultirasquest_b_01",
    id = "harnois_blanc",
    label = "Pavois du gardien",
    remplacePublie = true,
    tags = "Inhabituel",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        pen_contondant = 4,
        pen_perforant = 8,
        pen_tranchant = 12,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Un sabre qui coupe.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_sword_10",
    id = "katana",
    label = "Katana",
    remplacePublie = true,
    tags = "Inhabituel",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        acrobaties = -1,
        depl_nage = -1,
        equilibre = -1,
        escalade = -1,
        pen_contondant = 2,
        pen_perforant = 4,
        pen_tranchant = 6,
    },
    categorie = "arme",
    couleurTitre = "FF8CB8",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme/commun",
    icone = "Interface\\ICONS\\inv_sword_110",
    id = "lame_rouillee",
    label = "Lame rouillée",
    remplacePublie = true,
    tags = "Commun",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        pen_contondant = 4,
        pen_ombre = 12,
        pen_perforant = 12,
        pen_tranchant = 12,
    },
    categorie = "arme",
    couleurTitre = "4D8CFF",
    description = "Une lame sombre, courte, imbibée d'ombre. Toucher cette arme sans être liée à son maitre s'accompagne d'une douleur oblitérante.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/rare",
    icone = "Interface\\ICONS\\w3reforgeddaggerofescape",
    id = "lcm_64a651_6ac7bbe9_36c708be_0001_efdd32",
    label = "Dague du culte de l'assassin",
    remplacePublie = true,
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
    avantage = {  },
    bonus = {
        pen_contondant = 4,
        pen_ombre = 12,
        pen_perforant = 12,
        pen_tranchant = 12,
    },
    categorie = "arme",
    couleurTitre = "4D8CFF",
    description = "Une lame sombre, courte, imbibée d'ombre. Toucher cette arme sans être liée à son maitre s'accompagne d'une douleur oblitérante.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/rare",
    icone = "Interface\\ICONS\\w3reforgeddaggerofescape",
    id = "lcm_64a651_6ac7c627_36ef1069_0002_7464d5",
    label = "Seconde Dague du culte de l'assassin",
    remplacePublie = true,
    tags = "Rare",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    bonus = {
        acrobaties = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Une robe simple et élégante, tissée dans une soie noble. Elle semble imprégnée de l'âme d'un millier de représentation d'accrobaties.",
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_chest_cloth_pvpmagegladiator_o_01",
    id = "lcm_64a651_6ac7c7c7_36f56009_0001_a1f814",
    label = "Robe de l'automate.",
    tags = "Commun",
})

LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        meca_brise_armure = 1,
        pen_contondant = 10,
        pen_perforant = 6,
        pen_tranchant = 16,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Une lame inabituellement grande, qui semble capable de vendre un cheval en deux.",
    etat = {
        courant = 14,
        max = 14,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\inv_sword_1h_draenorraid_d_03blue",
    id = "lcm_64a651_6ac8a2eb_3a4d5de1_0001_5e0efb",
    label = "Déchireuse de l'automate.",
    tags = "Inhabituel",
    taille = 2,
})

LCM.Publier(LCM.Objets, {
    bonus = {
        cosmique = 1,
        elementaire = 1,
        meca_dissipation = 1,
        meca_soin = 2,
        vue = 4,
    },
    categorie = "accessoire",
    couleurTitre = "4D8CFF",
    description = "Une lentille enchantée permettant d'observer l'intérieur du corps d'une créature.\nPermet de repérer blessures internes, organes fragiles ou points faibles avant ou pendant un combat.",
    forge = "equilibrage_armure_copie/rare",
    icone = "Interface\\ICONS\\inv_helm_glasses_b_01_gold2_teal",
    id = "lunette_d_anatomie",
    label = "Lunette d'anatomie",
    tags = "Rare",
})

LCM.Publier(LCM.Objets, {
    avantage = {  },
    bonus = {
        acrobaties = -1,
        equilibre = -1,
        escalade = -1,
        meca_buff = 1,
        meca_confusion = 1,
        meca_controle_mental = 1,
        meca_debuff = 1,
        pen_contondant = 4,
    },
    categorie = "arme",
    couleurTitre = "4DE04D",
    description = "Un cadeau de l'école des Bardes. Une table d'harmonie en épicéa avec une caisse en érable flammé. Manche en érable, touche et chevilles en buis, le tout avec une rosace sculptée et des filets en bois sombre méticuleusement damasquinés.",
    etat = {
        courant = 10,
        max = 10,
    },
    forge = "equilibrage_arme/inhabituel",
    icone = "Interface\\ICONS\\trade_archaeology_carved harp of exotic wood",
    id = "luth",
    label = "Luth",
    tags = "Inhabituel",
    taille = 1,
})

LCM.Publier(LCM.Objets, {
    bonus = {
        pistage = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Dans leurs missions d'escorte de voyageurs,  les garde-forestiers d'Elestria donnent à ces derniers une pièce enchantée avec un sort de localisation : toute fée d'Elestria à portée peut situer la direction et une distance approximative de la pièce. Ce pouvoir est amplifié dans leur forêt native, permettant de repérer un voyageur égaré sur plusieurs kilomètres. En revanche, en dehors de la forêt, la pièce n'est détectable que sur quelques centaines de mètres et de manière peu précise.\n\nDans notre",
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_misc_azsharacoin",
    id = "piece_du_voyageur_egaree",
    label = "Pièce du voyageur égarée",
    tags = "Commun",
})

LCM.Publier(LCM.Objets, {
    ["bonus.depl_terrestre"] = "-1",
    ["bonus.resi_contondant"] = "4",
    ["bonus.resi_perforant"] = "4",
    ["bonus.resi_tranchant"] = "4",
    categorie = "equipement",
    couleurTitre = "4DE04D",
    description = "Un rempart qui protège bien.",
    forge = "equilibrage_arme_copie/inhabituel",
    icone = "Interface\\ICONS\\inv_chest_chain_17",
    id = "rempart_de_guerre",
    label = "Rempart de guerre",
    tags = "Inhabituel",
})

LCM.Publier(LCM.Objets, {
    bonus = {
        meca_soin = 1,
    },
    categorie = "accessoire",
    couleurTitre = "FF8CB8",
    description = "Une sacoche contenant bandages, aiguilles, fils, pinces, antiseptiques et petits instruments chirurgicaux.\n\nPermet à Archibald de soigner et stabiliser les créatures et allier blessées, même sans disposer d'une véritable infirmerie.",
    forge = "equilibrage_armure_copie/commun",
    icone = "Interface\\ICONS\\inv_misc_coinbag04",
    id = "trousse_de_veterinaire_de_terrain",
    label = "Trousse de vétérinaire de terrain",
    tags = "Commun",
})

-- ----- races (7) ---------------------------------------------------
LCM.Publier(LCM.Races, {
    avantage = {},
    bonus = {
        adresse = 3,
        constitution = 3,
        esprit = 3,
        force = 3,
        mystique = 3,
        pen_contondant = 3,
        pen_desordre = 3,
        pen_eau = 3,
        pen_esprit = 3,
        pen_feu = 3,
        pen_lumiere = 3,
        pen_mort = 3,
        pen_ombre = 3,
        pen_ordre = 3,
        pen_perforant = 3,
        pen_pourriture = 3,
        pen_terre = 3,
        pen_tranchant = 3,
        pen_vent = 3,
        pen_vie = 3,
        perception = 3,
        resi_contondant = 3,
        resi_desordre = 3,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 3,
        resi_mort = 3,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 3,
    },
    couleurFond = "080D11",
    couleurTitre = "FF8CB8",
    description = "Aeeelskardien.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\ability_mage_frostjaw",
    id = "aelskardien",
    label = "Aelskardien",
    mjSeulement = true,
    morphology = "humanoide",
    tags = "Commun",
})

LCM.Publier(LCM.Races, {
    bonus = {
        adresse = "4",
        constitution = "2",
        esprit = "3",
        force = "2",
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
    description = "Un elfe. Imbuvable. Mais pas comme son vin.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\achievement_character_bloodelf_male",
    id = "elfe",
    label = "Elfe",
    morphology = "humanoide",
    tags = "Commun",
})

LCM.Publier(LCM.Races, {
    bonus = {
        adresse = "3",
        constitution = "3",
        esprit = "3",
        force = "2",
        mystique = "4",
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
    description = "Fée Flappy. Fée pas le malin, tu n'as plus tes ailes.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\eps_lol_tft_faerieemblem",
    id = "fee",
    label = "Fée",
    morphology = "humanoide",
    tags = "Commun",
})

LCM.Publier(LCM.Races, {
    bonus = {
        adresse = 3,
        constitution = 3,
        esprit = 3,
        force = 3,
        mystique = 3,
        pen_contondant = 3,
        pen_desordre = 3,
        pen_eau = 3,
        pen_esprit = 3,
        pen_feu = 3,
        pen_lumiere = 3,
        pen_mort = 3,
        pen_ombre = 3,
        pen_ordre = 3,
        pen_perforant = 3,
        pen_pourriture = 3,
        pen_terre = 3,
        pen_tranchant = 3,
        pen_vent = 3,
        pen_vie = 3,
        perception = 3,
        resi_contondant = 3,
        resi_desordre = 3,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 3,
        resi_mort = 3,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 3,
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

LCM.Publier(LCM.Races, {
    avantage = {},
    bonus = {
        adresse = 3,
        constitution = 3,
        esprit = 3,
        force = 3,
        mystique = 3,
        pen_contondant = 3,
        pen_desordre = 3,
        pen_eau = 3,
        pen_esprit = 3,
        pen_feu = 3,
        pen_lumiere = 3,
        pen_mort = 3,
        pen_ombre = 3,
        pen_ordre = 3,
        pen_perforant = 3,
        pen_pourriture = 3,
        pen_terre = 3,
        pen_tranchant = 3,
        pen_vent = 3,
        pen_vie = 3,
        perception = 3,
        resi_contondant = 3,
        resi_desordre = 3,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 3,
        resi_mort = 3,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 3,
    },
    couleurTitre = "FF8CB8",
    forge = "race/commun",
    icone = "Interface\\ICONS\\eps_lol_leona_sunlight",
    id = "insgardienne",
    label = "Insgardienne",
    mjSeulement = true,
    morphology = "humanoide",
    remplacePublie = true,
    tags = "Commun",
})

LCM.Publier(LCM.Races, {
    avantage = {},
    bonus = {
        adresse = 3,
        constitution = 3,
        esprit = 3,
        force = 3,
        mystique = 3,
        pen_contondant = 3,
        pen_desordre = 3,
        pen_eau = 3,
        pen_esprit = 3,
        pen_feu = 3,
        pen_lumiere = 3,
        pen_mort = 3,
        pen_ombre = 3,
        pen_ordre = 3,
        pen_perforant = 3,
        pen_pourriture = 3,
        pen_terre = 3,
        pen_tranchant = 3,
        pen_vent = 3,
        pen_vie = 3,
        perception = 3,
        resi_contondant = 3,
        resi_desordre = 3,
        resi_eau = 3,
        resi_esprit = 3,
        resi_feu = 3,
        resi_lumiere = 3,
        resi_mort = 3,
        resi_ombre = 3,
        resi_ordre = 3,
        resi_perforant = 3,
        resi_pourriture = 3,
        resi_terre = 3,
        resi_tranchant = 3,
        resi_vent = 3,
        resi_vie = 3,
    },
    couleurTitre = "FF8CB8",
    forge = "race/commun",
    icone = "Interface\\ICONS\\eps_lol_nilah_jubilantveil",
    id = "projet_htdt_02",
    label = "Projet HTDT-02",
    mjSeulement = true,
    morphology = "humanoide",
    remplacePublie = true,
    tags = "Commun",
})

LCM.Publier(LCM.Races, {
    bonus = {
        adresse = "3",
        constitution = "4",
        esprit = "4",
        force = "2",
        mystique = "3",
        nage = "-1",
        pen_contondant = "3",
        pen_desordre = "2",
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
    description = "Une race qui vient du pays de l'été et du soleil qui ne se couche jamais.",
    forge = "race/commun",
    icone = "Interface\\ICONS\\achievement_zone_tanaris_01",
    id = "valien",
    label = "Valien",
    morphology = "humanoide",
    tags = "Commun",
})

-- ----- tentes (1) --------------------------------------------------
LCM.Publier(LCM.Tentes, {
    accessoiresMax = 20,
    bonus = {
        recup_fatigue = 100,
        recup_pv = 100,
        securite = 100,
    },
    id = "auberge_de_tephris",
    label = "Auberge de Tephris",
    lits = 1,
    origine = "Aelskar",
})

-- ----- traits (30) --------------------------------------------------
LCM.Publier(LCM.Traits, {
    bonus = {
        pen_perforant = 1,
        pen_tranchant = 2,
        resi_contondant = 1,
        resi_perforant = 1,
        resi_tranchant = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Elle maintient ses armes et son armure en bonne condition en toute circonstance. Il n'est pas rare qu'elle fasse du zèle pour aiguiser un peu plus sa lame ou ajouter quelques renforts d'appoint à son armure.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_eyeoftheowl",
    id = "attentive",
    label = "Attentive",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        acrobaties = "1",
        escalade = "1",
        resistance = "1",
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
        meca_buff = 1,
        meca_confusion = 1,
        meca_debuff = 1,
    },
    couleurTitre = "FF8CB8",
    description = "L'art a une souveraineté en ce bas monde. Il égaie les esprits, galvanise les coeurs... Autant de notes frémissantes pincées de ses cordes qui embaument l'air comme des promesses. Ses années passées à l'Ecole des Bardes lui ont enseigné les arcanes de l'envoûtement. Elle sait vous faire rire, - jusqu'à la mort. Vous faire pleurer sur une femme que vous n'avez pas connue. Vous exalter tant et si bien qu'aucun ennemi ne vous résistera. - jusqu'à ce qu'il vous résiste. - Les artistes sont ce qu'ils",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\hd_hd_hd_bard_   overture",
    id = "barde",
    label = "Barde",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        crochetage = 1,
        discretion = 1,
        vol_a_la_tire = 1,
    },
    couleurTitre = "FF8CB8",
    description = "L'arc et le jeu de scène suffisent assez rarement aux fins de mois. Alors, autrefois, elle se glissait avec quelques copains dans de riches baraques pour en voler les biens. Elle sait se faire discrète, se fondre dans les ombres, - dans une certaine mesure. Crocheter des verrous assez complexes, se faire morte quand le prédateur pointe le bout de son nez. Il est assez connu que Maia volait \"au-delà\" de ses besoins primaires. Elle aime l'argent comme l'orphelin aime la chaleur du feu. Parce qu'el",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_stealth",
    id = "cambrioleuse",
    label = "Cambrioleuse",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        deguisement = 2,
        discretion = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Que ce soit lorsqu'elle travaillait à la Foire de Sombrelune ou à l'Ecole des Bardes de Hurlevent, Maia a développé son sens de la comédie, du paraître et de la vraisemblance. Elle est le môme aux cheveux courts qu'on a engagé dans ce baleinier. Cette triste veuve grimée de noir qui attend son époux depuis dix ans maintenant. L'écuyer. L'amant. Ou l'amante. La pieuse femme et l'impie. Elle sait jouer le drame et la comédie, - bien qu'elle préfère la comédie.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_arc_halloween_shatteredmask",
    id = "comedienne",
    label = "Comédienne",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        communication = 1,
        pen_vie = 1,
        pistage = 1,
        resi_vie = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Archibald sait interpréter les comportements, traces et réactions des créatures. Grâce à ses connaissances de zoologiste, il peut déduire instinctivement leurs intentions, habitudes ou état d'esprit, là où d'autres devraient enquêter.\n\nSa permettrais d'avoir quelques informations pour :\n- Anticiper les attaques\n- Identifier les points faibles\n- Eviter certains combat\n- Comprendre l'écosystème",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_hunter_beasttraining",
    id = "comprehension_des_creatures",
    label = "Compréhension des créatures.",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        communication = 1,
        investigation = 1,
        pistage = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Des champignons aux oiseaux en passant par les rongeurs et autres créatures, les gardes forestiers se doivent de connaitre le microcosme de leur forêt natale afin de mieux guider quiconque s'y aventure.\n\nAvantage de savoir concernant les animaux vivant dans un milieu forestier. Cela permet aussi de mieux connaitre les habitudes de ces derniers et donc de mieux les chasser.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\achievement_zone_elwynnforest",
    id = "connaissance_du_regne_forestier",
    label = "Connaissance du règne forestier",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        pa = "1",
        resi_desordre = "-2",
        resi_ordre = "-2",
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
        acrobaties = 1,
        discretion = 1,
        pistage = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Les gardes-forestiers de la forêt d'Elestria sont formés à se déplacer de manière silencieuse au sein de leur environnement. Cela leur permet de guider les voyageurs et les commerçants sans attirer l'attention d'animaux considérés comme dangereux. Utile aussi lorsqu'ils doivent aider les chasseurs de leur communauté.\n\nAvantage de discrétion dans une forêt, sur un terrain \"végétalisé\" ou \"encombré de branches, feuilles, cailloux\".",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_hunter_posthaste",
    id = "deplacement_furtif_en_millieu_forestier",
    label = "Déplacement furtif en millieu forestier",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        meca_perce_armure = 2,
        perception_attaque = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Il n'y a rien qui puisse justifier que Maia Petersen ait une telle adresse à l'arc. C'est ainsi, comme il en est du génie qui remplit les fronts des poètes et de la puissance des grands sorciers. Petite, elle tirait avec l'arc de sa mère pour éloigner les goules; la chose lui est toujours apparue comme instinctive. Evidente. Elle manie l'arc avec une aisance industrielle et n'a jamais semblé s'en interroger.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_hunter_focusedaim",
    id = "elfe_manquee",
    label = "Elfe manquée",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        discretion = 2,
        evasion = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Malgré le port d'une armure lourde, on peut s'étonner de la vivacité de Caedicia, il n'est pas rare qu'elle évite plus de coup qu'elle n'en encaisse.\nDe plus, dans l'obscurité sa nature elfique lui permet de passer inaperçu...Tant qu'elle ne bouge pas.\n\nPlus prompt à esquivé les coups. Aisance à se cacher lorsqu'elle est immobile.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_ambush",
    id = "elusive",
    label = "Élusive",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        deguisement = "1",
        discretion = "1",
        evasion = "1",
    },
    couleurTitre = "FF8CB8",
    description = "C'est là qu'il a acquis son instinct pour repérer les ennuis, sa méfiance envers les inconnus et sa capacité à passer inaperçu. Il sait marchander, se faufiler et dormir n'importe où, et cette enfance explique pourquoi il n'a jamais cherché la gloire : il sait ce que vaut un repas chaud.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\achievement_dungeon_lostcity of tolvir",
    id = "enfant_des_rues",
    label = "Enfant des rues",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        resi_esprit = 3,
        resi_ombre = 3,
    },
    couleurTitre = "FF8CB8",
    description = "Une vie de conflit ont rendu Caedicia plutôt détachée, à tel point que les sorts d'influence mentales ont du mal à trouvé un ancrage solide dans son esprit.\n\nPlus grande chance de résister aux effets de peurs et d'influence mentale.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\dos2_mind",
    id = "forteresse_mentale",
    label = "Forteresse mentale",
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
    bonus = {
        communication = 2,
        pistage = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Archibald sais calmer, dresser et manipuler les animaux. Une créature non magique peut être apprivoisée ou temporairement coopérative si ses instincts et son état le permettent.\n\nMaître de la Ménagerie apporte surtout une utilité hors combat et situationnelle :\n- Aide au domptage de la faune forestière\n- Faciliter l'exploration\n- Interagir avec la faune",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_rumble_petrify",
    id = "maitre_de_la_menagerie",
    label = "Maitre de la ménagerie",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        initiative = "1",
        meca_attaque_simple = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Il se bat comme il dessine : sans fioritures, en allant à l'essentiel. Il vise à mettre fin au combat le plus vite possible pour reprendre la route. Ses années dans la rue lui ont appris à se battre sale et à profiter du terrain, plus que les gestes appris dans une salle d'armes.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\dos2_sword",
    id = "maniement_de_l_epee",
    label = "Maniement de l'épée",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        meca_attaque_simple = 1,
        meca_brise_armure = 1,
        meca_intervention = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Férue des ouvrages traitants des arts martiaux et de la guerre, Caedicia n'a besoin qu'une lecture pour retenir l'essentiel de tels ouvrages. Pratique dans certaines situations particulière.\n\nApprentissage bien plus rapide des techniques de combats. Connaissance quasi-encyclopédique de l'art de la guerre.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\ability_mage_studentofthemind",
    id = "memoire_selective",
    label = "Mémoire sélective",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        discretion = "1",
        meca_perce_armure = "1",
        odorat_gout = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Ses quelques années passées au contact des Blud’kra lui ont largement suffi. Il n’était désormais plus seulement question de leur survivre, mais d’apprendre à s’en défaire. Proprement. Efficacement. Avant qu’ils n’aient eux-mêmes l’occasion de frapper.\n\nÀ force de les observer, elle apprit à se mouvoir dans leur ombre, à masquer sa propre présence sous leur odeur et à reconnaître les traces qu’ils laissaient derrière eux. Avec le temps, elle devint même capable de sentir leur passage sur un terr",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_fiddlesticks_crowstormsurpriseparty",
    id = "moon_chasseuse_de_monstruosites",
    label = "Moon - Chasseuse de monstruosités",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        investigation = "1",
        pistage = "1",
        vue = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Danseuse n'est hélas pas le métier que l'on souhaiterait exercer. Il n'est guère propice aux soirées animées où éclatent de doux rires, ni aux représentations sous les regards émerveillés d'un public.\n\nDans le Val'Razkah, les danseurs sont ceux qui ont appris à arpenter les plaines de sable et les parois rocheuses sans finir dans la gueule d'une créature ou au fond d'un piège. Observer son environnement, reconnaître les traces laissées derrière soi et déceler ce que le désert cherche à dissimule",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_profileicon_thedancer",
    id = "moon_danseuse_du_val_razkah",
    label = "Moon - Danseuse du Val'Razkah",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        meca_perce_armure = "1",
        meca_soin = "1",
        mystique_soin = "2",
    },
    couleurTitre = "FF8CB8",
    description = "Prise sous le voile d'une mystérieuse femme, elle apprit à exploiter ses dons avec bien davantage de précision. On lui enseigna autant à préserver sa propre existence qu'à mettre rapidement un terme à celle de ses adversaires.\n\nElle sait reconnaître ce qui maintient un corps en vie, refermer certaines blessures lorsque personne d'autre ne peut le faire, mais également identifier les faiblesses d'une protection ou d'une anatomie afin de frapper là où cela fera réellement la différence.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\inv_crystallized_life",
    id = "moon_engeance_de_n",
    label = "Moon - Engeance de N'",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        cosmique = 1,
        investigation = 1,
        vue = 1,
    },
    couleurTitre = "FF8CB8",
    description = "Dès leur plus jeune âge, les fées apprennent à écouter et à ressentir le monde qui les entoure. Elles sont donc plus enclines à détecter des fluctuations de magie.\n\nUne perception légèrement accrue de la magie. Capacité à dire si un objet, une personne ou un lieu est magique ou non. Si la nature de la magie est familière au personnage, il peut mieux la cerner. Sinon, c'est juste magique.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_rk_yasuo_eyeofthewind",
    id = "perception_feerique",
    label = "Perception féérique",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        investigation = "1",
        ouie = "1",
        vue = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Son regard va au-delà de ce que tout le monde voit. Il repère le détail qui cloche dans un paysage : un sol trop lisse pour être naturel, un silence inhabituel, une trace qui mène à une embuscade. Cet œil aiguisé lui permet de tracer des cartes fiables, et de rester en vie pour les vendre.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\inv_misc_pignosemask_a_01",
    id = "perspicace",
    label = "Perspicace",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        depl_nage = "-1",
        initiative = "1",
        investigation = "1",
        pen_tranchant = "1",
    },
    couleurTitre = "FF8CB8",
    description = "Il ne cherche ni la gloire ni les grandes causes, seulement ce qui fonctionne. Il évite un danger quand il le peut, et sait jouer du fer quand il n'a pas d'autre choix. Pour lui, un combat n'est qu'un moyen de poursuivre sa route, jamais une fin.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_akshan_goingrogue",
    id = "pragmatique",
    label = "Pragmatique",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        crochetage = "1",
        deguisement = "1",
        evasion = "1",
    },
    couleurTitre = "FF8CB8",
    cout = "1",
    description = "Être prise en otage une fois aurait déjà pu être considéré comme un manque de chance. Lorsque cela devient une habitude, il faut bien finir par s'adapter.\n\nÀ force de captivités, elle apprit à devenir quelqu'un d'autre lorsque la situation l'exigeait, à tromper ses geôliers par la parole comme par les apparences et, surtout, à préparer méthodiquement sa sortie. Serrures, entraves et chaînes cessèrent peu à peu d'être des obstacles insurmontables.\n\nAprès suffisamment de tentatives, elle finit par",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_rk_illaoi_testofspirit",
    id = "quelle_vie_de_merde",
    label = "Moon - Quelle vie de merde... !",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        discretion = 1,
        escalade = 2,
    },
    couleurTitre = "FF8CB8",
    description = "La magie des fées imprègne le sang de ces dernières, conférant à leur corps une légèreté significative leur permettant de voler avec plus d'efficacité.\n\nLors de la marche, permet de laisser moins de traces au sol.\nEscalade facilitée.\nEn revanche, plus de difficulté à résister à de violentes bourrasques ou à repoussement.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\9xp_sigil_ardenweald01",
    id = "sang_feerique",
    label = "Sang féérique",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        meca_dissipation = 1,
        meca_soin = 2,
    },
    couleurTitre = "FF8CB8",
    description = "Archibald peut soigner les blessures et affections des animaux avec le matériel disponible. Il peut stabiliser une créature mourante et lui permettre de récupérer progressivement. Faire la même chose sur un allier ? Après tout nous sommes aussi des animaux.\n\n- Utilisation de la médecine vétérinaire pour soigner les alliers.\n- Stabiliser une créature.\n- Traiter les affections.",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\hots_ltmorales_healingbeam",
    id = "veterinaire_de_terrain",
    label = "Vétérinaire de terrain",
    tags = "Commun",
})

LCM.Publier(LCM.Traits, {
    bonus = {
        acrobaties = "1",
        meca_buff = "3",
        meca_soin = "-2",
    },
    couleurTitre = "FF8CB8",
    cout = "1",
    description = "Il ne suffit guère de savoir se façonner soi-même lorsque le monde qui nous entoure persiste à suivre sa propre mélodie. Reika dispose d'une attention particulière; qui, a l'image d'un instrument que l'on accorde, lui offre la mesure des subtilités qui composent l'équilibre d'un individu et d'y apporter quelques ajustements.\n\nUn mouvement, une respiration, une circulation magique ou le moindre déséquilibre deviennent autant d'occasions d'intervenir pour elle. Tantôt pour accompagner ses alliés,",
    forge = "traits/commun",
    icone = "Interface\\ICONS\\eps_lol_item_puppeteer",
    id = "violoniste_de_la_marionnette",
    label = "Violoniste de la marionnette.",
    tags = "Commun",
})
