-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par l'outil « Exporter les brouillons » le 2026-10-08 18:42.
--  Source : ce que le MJ a cree en jeu. Toute retouche manuelle sera perdue au
--  prochain export.
--
--  Pour changer une entree : la corriger en jeu, puis reexporter.
-- ============================================================================

local LCM = _G.LCM
if not LCM then return end

-- ----- jeux (1) ----------------------------------------------------
LCM.Publier(LCM.Forge, {
    categorie = "traits",
    champs = {
        acrobaties = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        adresse = {
            verrou = true,
        },
        age = {
            min = -10,
        },
        communication = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        constitution = {
            verrou = true,
        },
        cosmique = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        course = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        crochetage = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        defense_constitution = {
            cout = 4,
            max = 4,
            min = -4,
        },
        deguisement = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        depl_nage = {
            base = 0,
            cout = 2,
            max = 5,
            min = -5,
        },
        depl_terrestre = {
            base = 0,
            cout = 2,
            max = 5,
            min = -5,
        },
        depl_vol = {
            min = -10,
        },
        discretion = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        elementaire = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        endurance = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        equilibre = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        escalade = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        escamotage = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        esprit = {
            verrou = true,
        },
        evasion = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        existence_ame = {
            min = -10,
        },
        existence_esprit = {
            min = -10,
        },
        fatigue = {
            base = 0,
            cout = 1,
            max = 5,
            min = -5,
        },
        force = {
            verrou = true,
        },
        initiative = {
            base = 0,
            cout = 4,
            max = 5,
            min = -5,
        },
        investigation = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        meca_attaque_simple = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_attraction = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_bouclier = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_brise_armure = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_buff = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_confusion = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_controle_mental = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_creation = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_debuff = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_deviation = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_dissipation = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_entrave = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_illusion = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_immobilisation = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_intervention = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_levitation = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_perce_armure = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_permutation = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_repulsion = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        meca_soin = {
            base = 0,
            cout = 2,
            max = 4,
            min = -4,
        },
        mystique = {
            verrou = true,
        },
        nage = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        niveau = {
            min = -10,
        },
        odorat_gout = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        ouie = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        pa = {
            base = 0,
            cout = 8,
            max = 1,
            min = -1,
        },
        pen_contondant = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_desordre = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_eau = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_esprit = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_feu = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_lumiere = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_mort = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_ombre = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_ordre = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_perforant = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_pourriture = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_terre = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_tranchant = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_vent = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        pen_vie = {
            base = 0,
            cout = 1,
            max = 4,
            min = 0,
        },
        perception = {
            verrou = true,
        },
        pistage = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        poids = {
            min = -10,
        },
        prise = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        projection = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        puissance = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        resi_contondant = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_desordre = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_eau = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_esprit = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_feu = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_lumiere = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_mort = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_ombre = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_ordre = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_perforant = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_pourriture = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_terre = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_tranchant = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_vent = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resi_vie = {
            base = 0,
            cout = 1,
            max = 4,
            min = -2,
        },
        resistance = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        sabotage = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        sec_deplacement = {
            min = -10,
        },
        sec_expertises = {
            min = -10,
        },
        sec_fatigue = {
            min = -10,
        },
        sec_initiative = {
            min = -10,
        },
        sec_mecanique = {
            min = -10,
        },
        sec_pa = {
            min = -10,
        },
        sec_penetration = {
            min = -10,
        },
        sec_resistance = {
            min = -10,
        },
        sec_vitalite = {
            min = -10,
        },
        toucher = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        vol_a_la_tire = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
        vue = {
            base = 0,
            cout = 2,
            max = 4,
            min = 0,
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "traits",
    label = "Traits",
    raretes = { {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = 6,
        }, {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            points = 12,
        }, {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            points = 18,
        }, {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            points = 26,
        } },
    remplacePublie = true,
})

-- ----- pnj (1) -----------------------------------------------------
LCM.Publier(LCM.PNJ, {
    icone = "Interface\\ICONS\\ability_mage_frostjaw",
    id = "lcm_64a651_6ac7bd59_36ccb275_0002_1e1934",
    label = "Asssassin du culte",
    metiersNiveaux = {
        eclaireur = 4,
    },
    traits = { "lcm_64a651_6ac7710f_35a2aedc_0003_6b06bc", "lcm_64a651_6ac76e82_3598aaf8_0001_f2b89d", "lcm_64a651_6ac7715c_35a3dd0b_0004_ba2485", "lcm_64a651_6ac77195_35a4bae4_0005_9cc402" },
    valeurs = {
        acrobaties = 4,
        adresse = 7,
        age = 30,
        constitution = 5,
        crochetage = 3,
        deguisement = 4,
        discretion = 6,
        equilibre = 4,
        escalade = 4,
        esprit = 7,
        evasion = 4,
        force = 4,
        meca_brise_armure = 6,
        meca_buff = 7,
        meca_debuff = 7,
        meca_entrave = 6,
        meca_immobilisation = 6,
        meca_perce_armure = 16,
        mystique = 7,
        niveau = 12,
        pen_contondant = 11,
        pen_ombre = 14,
        pen_perforant = 14,
        pen_tranchant = 14,
        perception = 9,
        pistage = 6,
        poids = 70,
        prise = 2,
        race = "aelskardien",
        resi_contondant = 13,
        resi_ombre = 13,
        resi_perforant = 13,
        resi_tranchant = 13,
        sabotage = 2,
        sec_deplacement = 4,
        sec_expertises = 5,
        sec_fatigue = 5,
        sec_initiative = 3,
        sec_mecanique = 10,
        sec_pa = 1,
        sec_penetration = 8,
        sec_vitalite = 8,
        sexe = "Autre",
        vol_a_la_tire = 3,
    },
})

-- ----- points (1) --------------------------------------------------
LCM.Publier(LCM.Points, {
    arcId = "vendeur_1_6ac4d4a7_2b6fce7a_0003_2eb5f7",
    description = "",
    deviseDefaut = "credits",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "lcm_64a651_6ac4d4a7_2b6fce7a_0003_2eb5f7",
    label = "Martin",
    nature = "vendeur",
    onglets = { {
            id = "onglet_1",
            label = "Articles",
            offres = { {
                    cle = "lcm_64a651_6ac4d4a7_2b6fce7a_0003_2eb5f7/lcm_64a651_6ac4d4c7_2b704ab2_0004_524268",
                    devise = "credits",
                    entree = "objets/arc_court",
                    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
                    id = "lcm_64a651_6ac4d4c7_2b704ab2_0004_524268",
                    label = "",
                    prix = 250,
                    quantite = 1,
                    stock = {
                        limite = 3,
                        minutes = 60,
                        unites = 1,
                    },
                } },
        } },
    rachats = { {
            id = "rachat_1",
            label = "Rachats",
            offres = {},
        } },
})
