-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par l'outil « Exporter les brouillons » le 2026-10-06 06:07.
--  Source : ce que le MJ a cree en jeu. Toute retouche manuelle sera perdue au
--  prochain export.
--
--  Pour changer une entree : la corriger en jeu, puis reexporter.
-- ============================================================================

local LCM = _G.LCM
if not LCM then return end

-- ----- jeux (5) ----------------------------------------------------
LCM.Forge.Add({
    categorie = "armes",
    champs = {
        acrobaties = {
            cout = 2,
            min = -2,
        },
        adresse = {
            verrou = true,
        },
        age = {
            verrou = true,
        },
        communication = {
            cout = 2,
            min = -2,
        },
        constitution = {
            verrou = true,
        },
        constitution_bouclier = {
            min = -2,
        },
        constitution_buff = {
            min = -2,
        },
        constitution_debuff = {
            min = -2,
        },
        constitution_empoisonnement = {
            min = -2,
        },
        constitution_intimidation = {
            min = -2,
        },
        constitution_provocation = {
            min = -2,
        },
        constitution_soin = {
            min = -2,
        },
        cosmique = {
            cout = 2,
            min = -2,
        },
        course = {
            cout = 2,
            min = -2,
        },
        crochetage = {
            cout = 2,
            min = -2,
        },
        defense_constitution = {
            min = -2,
        },
        deguisement = {
            cout = 2,
            min = -2,
        },
        depl_nage = {
            cout = 1,
        },
        depl_terrestre = {
            cout = 1,
        },
        depl_vol = {
            verrou = true,
        },
        discretion = {
            cout = 2,
            min = -2,
        },
        duree_buff = {
            min = -2,
        },
        duree_debuff = {
            min = -2,
        },
        elementaire = {
            cout = 2,
            min = -2,
        },
        endurance = {
            cout = 2,
            min = -2,
        },
        equilibre = {
            cout = 2,
            min = -2,
        },
        escalade = {
            cout = 2,
            min = -2,
        },
        escamotage = {
            cout = 2,
            min = -2,
        },
        esprit = {
            verrou = true,
        },
        esprit_intimidation = {
            min = -2,
        },
        esprit_provocation = {
            min = -2,
        },
        evasion = {
            cout = 2,
            min = -2,
        },
        existence_ame = {
            verrou = true,
        },
        existence_esprit = {
            verrou = true,
        },
        fatigue = {
            cout = 2,
        },
        force = {
            verrou = true,
        },
        force_attaque = {
            min = -2,
        },
        force_bouclier = {
            min = -2,
        },
        force_brise_armure = {
            min = -2,
        },
        force_buff = {
            min = -2,
        },
        force_debuff = {
            min = -2,
        },
        force_intimidation = {
            min = -2,
        },
        force_perce_armure = {
            min = -2,
        },
        force_provocation = {
            min = -2,
        },
        force_saignement = {
            min = -2,
        },
        initiative = {
            cout = 1,
        },
        investigation = {
            cout = 2,
            min = -2,
        },
        meca_attaque_simple = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_attraction = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_bouclier = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_brise_armure = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_buff = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_confusion = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_controle_mental = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_creation = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_debuff = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_deviation = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_dissipation = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_entrave = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_illusion = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_immobilisation = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_intervention = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_levitation = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_perce_armure = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_permutation = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_repulsion = {
            cout = "2",
            max = 4,
            min = -2,
        },
        meca_soin = {
            cout = "2",
            max = 4,
            min = -2,
        },
        mystique = {
            verrou = true,
        },
        mystique_attaque = {
            min = -2,
        },
        mystique_bouclier = {
            min = -2,
        },
        mystique_brise_armure = {
            min = -2,
        },
        mystique_buff = {
            min = -2,
        },
        mystique_debuff = {
            min = -2,
        },
        mystique_empoisonnement = {
            min = -2,
        },
        mystique_intimidation = {
            min = -2,
        },
        mystique_perce_armure = {
            min = -2,
        },
        mystique_provocation = {
            min = -2,
        },
        mystique_saignement = {
            min = -2,
        },
        mystique_soin = {
            min = -2,
        },
        nage = {
            cout = 2,
            min = -2,
        },
        niveau = {
            verrou = true,
        },
        odorat_gout = {
            cout = 2,
            min = -2,
        },
        ouie = {
            cout = 2,
            min = -2,
        },
        pa = {
            cout = 8,
            max = 1,
        },
        pen_contondant = {
            cout = 0.25,
            min = -6,
        },
        pen_desordre = {
            cout = 0.25,
            min = -6,
        },
        pen_eau = {
            cout = 0.25,
            min = -6,
        },
        pen_esprit = {
            cout = 0.25,
            min = -6,
        },
        pen_feu = {
            cout = 0.25,
            min = -6,
        },
        pen_lumiere = {
            cout = 0.25,
            min = -6,
        },
        pen_mort = {
            cout = 0.25,
            min = -6,
        },
        pen_ombre = {
            cout = 0.25,
            min = -6,
        },
        pen_ordre = {
            cout = 0.25,
            min = -6,
        },
        pen_perforant = {
            cout = 0.25,
            min = -6,
        },
        pen_pourriture = {
            cout = 0.25,
            min = -6,
        },
        pen_terre = {
            cout = 0.25,
            min = -6,
        },
        pen_tranchant = {
            cout = 0.25,
            min = -6,
        },
        pen_vent = {
            cout = 0.25,
            min = -6,
        },
        pen_vie = {
            cout = 0.25,
            min = -6,
        },
        perception = {
            verrou = true,
        },
        perception_attaque = {
            min = -2,
        },
        perception_brise_armure = {
            min = -2,
        },
        perception_buff = {
            min = -2,
        },
        perception_debuff = {
            min = -2,
        },
        perception_empoisonnement = {
            min = -2,
        },
        perception_perce_armure = {
            min = -2,
        },
        perception_saignement = {
            min = -2,
        },
        pistage = {
            cout = 2,
            min = -2,
        },
        poids = {
            verrou = true,
        },
        prise = {
            cout = 2,
            min = -2,
        },
        projection = {
            cout = 2,
            min = -2,
        },
        puissance = {
            cout = 2,
            min = -2,
        },
        puissance_buff = {
            min = -2,
        },
        puissance_debuff = {
            min = -2,
        },
        resi_contondant = {
            cout = 0.5,
            min = -6,
        },
        resi_desordre = {
            cout = 0.5,
            min = -6,
        },
        resi_eau = {
            cout = 0.5,
            min = -6,
        },
        resi_esprit = {
            cout = 0.5,
            min = -6,
        },
        resi_feu = {
            cout = 0.5,
            min = -6,
        },
        resi_lumiere = {
            cout = 0.5,
            min = -6,
        },
        resi_mort = {
            cout = 0.5,
            min = -6,
        },
        resi_ombre = {
            cout = 0.5,
            min = -6,
        },
        resi_ordre = {
            cout = 0.5,
            min = -6,
        },
        resi_perforant = {
            cout = 0.5,
            min = -6,
        },
        resi_pourriture = {
            cout = 0.5,
            min = -6,
        },
        resi_terre = {
            cout = 0.5,
            min = -6,
        },
        resi_tranchant = {
            cout = 0.5,
            min = -6,
        },
        resi_vent = {
            cout = 0.5,
            min = -6,
        },
        resi_vie = {
            cout = 0.5,
            min = -6,
        },
        resistance = {
            cout = 2,
            min = -2,
        },
        sabotage = {
            cout = 2,
            min = -2,
        },
        sec_deplacement = {
            verrou = true,
        },
        sec_expertises = {
            verrou = true,
        },
        sec_fatigue = {
            verrou = true,
        },
        sec_initiative = {
            verrou = true,
        },
        sec_mecanique = {
            verrou = true,
        },
        sec_pa = {
            verrou = true,
        },
        sec_penetration = {
            verrou = true,
        },
        sec_resistance = {
            verrou = true,
        },
        sec_vitalite = {
            verrou = true,
        },
        toucher = {
            cout = 2,
            min = -2,
        },
        vol_a_la_tire = {
            cout = 2,
            min = -2,
        },
        vue = {
            cout = 2,
            min = -2,
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "equilibrage_arme",
    label = "Equilibrage_arme",
    raretes = { {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = 1,
        }, {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            points = 5,
        }, {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            points = 9,
        }, {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            points = 14,
        }, {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            points = 20,
        }, {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            points = 30,
        }, {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            points = 50,
        } },
})

LCM.Forge.Add({
    categorie = "armures",
    champs = {
        acrobaties = {
            cout = "2",
            min = "-2",
        },
        adresse = {
            verrou = "true",
        },
        communication = {
            cout = "2",
            min = "-2",
        },
        constitution = {
            verrou = "true",
        },
        constitution_bouclier = {
            cout = "3",
            min = "-2",
        },
        constitution_buff = {
            cout = "3",
            min = "-2",
        },
        constitution_debuff = {
            cout = "3",
            min = "-2",
        },
        constitution_empoisonnement = {
            cout = "3",
            min = "-2",
        },
        constitution_intimidation = {
            cout = "3",
            min = "-2",
        },
        constitution_provocation = {
            cout = "3",
            min = "-2",
        },
        constitution_soin = {
            cout = "3",
            min = "-2",
        },
        cosmique = {
            cout = "2",
            min = "-2",
        },
        course = {
            cout = "2",
            min = "-2",
        },
        crochetage = {
            cout = "2",
            min = "-2",
        },
        defense_constitution = {
            cout = "3",
            min = "-2",
        },
        deguisement = {
            cout = "2",
            min = "-2",
        },
        depl_nage = {
            cout = "1",
            min = "-1",
        },
        depl_terrestre = {
            cout = "1",
            min = "-1",
        },
        discretion = {
            cout = "2",
            min = "-2",
        },
        duree_buff = {
            cout = "3",
            min = "-2",
        },
        duree_debuff = {
            cout = "3",
            min = "-2",
        },
        elementaire = {
            cout = "2",
            min = "-2",
        },
        endurance = {
            cout = "2",
            min = "-2",
        },
        equilibre = {
            cout = "2",
            min = "-2",
        },
        escalade = {
            cout = "2",
            min = "-2",
        },
        escamotage = {
            cout = "2",
            min = "-2",
        },
        esprit = {
            verrou = "true",
        },
        esprit_intimidation = {
            cout = "3",
            min = "-2",
        },
        esprit_provocation = {
            cout = "3",
            min = "-2",
        },
        evasion = {
            cout = "2",
            min = "-2",
        },
        fatigue = {
            cout = "2",
            min = "-1",
        },
        force = {
            verrou = "true",
        },
        force_attaque = {
            cout = "3",
            min = "-2",
        },
        force_bouclier = {
            cout = "3",
            min = "-2",
        },
        force_brise_armure = {
            cout = "3",
            min = "-2",
        },
        force_buff = {
            cout = "3",
            min = "-2",
        },
        force_debuff = {
            cout = "3",
            min = "-2",
        },
        force_intimidation = {
            cout = "3",
            min = "-2",
        },
        force_perce_armure = {
            cout = "3",
            min = "-2",
        },
        force_provocation = {
            cout = "3",
            min = "-2",
        },
        force_saignement = {
            cout = "3",
            min = "-2",
        },
        initiative = {
            cout = "1",
            min = "-1",
        },
        investigation = {
            cout = "2",
            min = "-2",
        },
        meca_attaque_simple = {
            cout = "3",
            min = "-2",
        },
        meca_attraction = {
            cout = "3",
            min = "-2",
        },
        meca_bouclier = {
            cout = "3",
            min = "-2",
        },
        meca_brise_armure = {
            cout = "3",
            min = "-2",
        },
        meca_buff = {
            cout = "3",
            min = "-2",
        },
        meca_confusion = {
            cout = "3",
            min = "-2",
        },
        meca_controle_mental = {
            cout = "3",
            min = "-2",
        },
        meca_creation = {
            cout = "3",
            min = "-2",
        },
        meca_debuff = {
            cout = "3",
            min = "-2",
        },
        meca_deviation = {
            cout = "3",
            min = "-2",
        },
        meca_dissipation = {
            cout = "3",
            min = "-2",
        },
        meca_entrave = {
            cout = "3",
            min = "-2",
        },
        meca_illusion = {
            cout = "3",
            min = "-2",
        },
        meca_immobilisation = {
            cout = "3",
            min = "-2",
        },
        meca_intervention = {
            cout = "3",
            min = "-2",
        },
        meca_levitation = {
            cout = "3",
            min = "-2",
        },
        meca_perce_armure = {
            cout = "3",
            min = "-2",
        },
        meca_permutation = {
            cout = "3",
            min = "-2",
        },
        meca_repulsion = {
            cout = "3",
            min = "-2",
        },
        meca_soin = {
            cout = "3",
            min = "-2",
        },
        mystique = {
            verrou = "true",
        },
        mystique_attaque = {
            cout = "3",
            min = "-2",
        },
        mystique_bouclier = {
            cout = "3",
            min = "-2",
        },
        mystique_brise_armure = {
            cout = "3",
            min = "-2",
        },
        mystique_buff = {
            cout = "3",
            min = "-2",
        },
        mystique_debuff = {
            cout = "3",
            min = "-2",
        },
        mystique_empoisonnement = {
            cout = "3",
            min = "-2",
        },
        mystique_intimidation = {
            cout = "3",
            min = "-2",
        },
        mystique_perce_armure = {
            cout = "3",
            min = "-2",
        },
        mystique_provocation = {
            cout = "3",
            min = "-2",
        },
        mystique_saignement = {
            cout = "3",
            min = "-2",
        },
        mystique_soin = {
            cout = "3",
            min = "-2",
        },
        nage = {
            cout = "2",
            min = "-2",
        },
        odorat_gout = {
            cout = "2",
            min = "-2",
        },
        ouie = {
            cout = "2",
            min = "-2",
        },
        pa = {
            cout = "8",
            max = "1",
            min = "-1",
        },
        pen_contondant = {
            verrou = "true",
        },
        pen_desordre = {
            verrou = "true",
        },
        pen_eau = {
            verrou = "true",
        },
        pen_esprit = {
            verrou = "true",
        },
        pen_feu = {
            verrou = "true",
        },
        pen_lumiere = {
            verrou = "true",
        },
        pen_mort = {
            verrou = "true",
        },
        pen_ombre = {
            verrou = "true",
        },
        pen_ordre = {
            verrou = "true",
        },
        pen_perforant = {
            verrou = "true",
        },
        pen_pourriture = {
            verrou = "true",
        },
        pen_terre = {
            verrou = "true",
        },
        pen_tranchant = {
            verrou = "true",
        },
        pen_vent = {
            verrou = "true",
        },
        pen_vie = {
            verrou = "true",
        },
        perception = {
            verrou = "true",
        },
        perception_attaque = {
            cout = "3",
            min = "-2",
        },
        perception_brise_armure = {
            cout = "3",
            min = "-2",
        },
        perception_buff = {
            cout = "3",
            min = "-2",
        },
        perception_debuff = {
            cout = "3",
            min = "-2",
        },
        perception_empoisonnement = {
            cout = "3",
            min = "-2",
        },
        perception_perce_armure = {
            cout = "3",
            min = "-2",
        },
        perception_saignement = {
            cout = "3",
            min = "-2",
        },
        pistage = {
            cout = "2",
            min = "-2",
        },
        prise = {
            cout = "2",
            min = "-2",
        },
        projection = {
            cout = "2",
            min = "-2",
        },
        puissance = {
            cout = "2",
            min = "-2",
        },
        puissance_buff = {
            cout = "3",
            min = "-2",
        },
        puissance_debuff = {
            cout = "3",
            min = "-2",
        },
        resi_contondant = {
            cout = "0.5",
            min = "-2",
        },
        resi_desordre = {
            cout = "0.5",
            min = "-2",
        },
        resi_eau = {
            cout = "0.5",
            min = "-2",
        },
        resi_esprit = {
            cout = "0.5",
            min = "-2",
        },
        resi_feu = {
            cout = "0.5",
            min = "-2",
        },
        resi_lumiere = {
            cout = "0.5",
            min = "-2",
        },
        resi_mort = {
            cout = "0.5",
            min = "-2",
        },
        resi_ombre = {
            cout = "0.5",
            min = "-2",
        },
        resi_ordre = {
            cout = "0.5",
            min = "-2",
        },
        resi_perforant = {
            cout = "0.5",
            min = "-2",
        },
        resi_pourriture = {
            cout = "0.5",
            min = "-2",
        },
        resi_terre = {
            cout = "0.5",
            min = "-2",
        },
        resi_tranchant = {
            cout = "0.5",
            min = "-2",
        },
        resi_vent = {
            cout = "0.5",
            min = "-2",
        },
        resi_vie = {
            cout = "0.5",
            min = "-2",
        },
        resistance = {
            cout = "2",
            min = "-2",
        },
        sabotage = {
            cout = "2",
            min = "-2",
        },
        toucher = {
            cout = "2",
            min = "-2",
        },
        vol_a_la_tire = {
            cout = "2",
            min = "-2",
        },
        vue = {
            cout = "2",
            min = "-2",
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "equilibrage_arme_copie",
    label = "Equilibrage_armure",
    raretes = { {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = "1",
        }, {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            points = "5",
        }, {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            points = "9",
        }, {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            points = "14",
        }, {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            points = "20",
        }, {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            points = "30",
        }, {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            points = "50",
        } },
})

LCM.Forge.Add({
    categorie = "accessoires",
    champs = {},
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "equilibrage_armure_copie",
    label = "Equilibrage_accessoires",
    raretes = { {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = 1,
        }, {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            points = 5,
        }, {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            points = 9,
        }, {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            points = 14,
        }, {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            points = 20,
        }, {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            points = 30,
        }, {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            points = 50,
        } },
})

LCM.Forge.Add({
    categorie = "races",
    champs = {
        acrobaties = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        adresse = {
            base = "3",
            cout = "2",
            max = "5",
            min = "1",
        },
        age = {
            verrou = "true",
        },
        communication = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        constitution = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        constitution_bouclier = {
            verrou = "true",
        },
        constitution_buff = {
            verrou = "true",
        },
        constitution_debuff = {
            verrou = "true",
        },
        constitution_provocation = {
            verrou = "true",
        },
        constitution_soin = {
            verrou = "true",
        },
        cosmique = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        course = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        crochetage = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        defense_constitution = {
            verrou = "true",
        },
        deguisement = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        depl_nage = {
            verrou = "true",
        },
        depl_terrestre = {
            verrou = "true",
        },
        depl_vol = {
            verrou = "true",
        },
        discretion = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        duree_buff = {
            verrou = "true",
        },
        duree_debuff = {
            verrou = "true",
        },
        elementaire = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        endurance = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        equilibre = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        escalade = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        escamotage = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        esprit = {
            base = "3",
            cout = "2",
            max = "5",
            min = "1",
        },
        esprit_provocation = {
            verrou = "true",
        },
        evasion = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        existence_ame = {
            verrou = "true",
        },
        existence_esprit = {
            verrou = "true",
        },
        fatigue = {
            verrou = "true",
        },
        force = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        force_attaque = {
            verrou = "true",
        },
        force_bouclier = {
            verrou = "true",
        },
        force_brise_armure = {
            verrou = "true",
        },
        force_buff = {
            verrou = "true",
        },
        force_debuff = {
            verrou = "true",
        },
        force_perce_armure = {
            verrou = "true",
        },
        force_provocation = {
            verrou = "true",
        },
        initiative = {
            verrou = "true",
        },
        investigation = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        meca_attaque_simple = {
            verrou = "true",
        },
        meca_attraction = {
            verrou = "true",
        },
        meca_bouclier = {
            verrou = "true",
        },
        meca_brise_armure = {
            verrou = "true",
        },
        meca_buff = {
            verrou = "true",
        },
        meca_confusion = {
            verrou = "true",
        },
        meca_controle_mental = {
            verrou = "true",
        },
        meca_creation = {
            verrou = "true",
        },
        meca_debuff = {
            verrou = "true",
        },
        meca_deviation = {
            verrou = "true",
        },
        meca_dissipation = {
            verrou = "true",
        },
        meca_entrave = {
            verrou = "true",
        },
        meca_illusion = {
            verrou = "true",
        },
        meca_immobilisation = {
            verrou = "true",
        },
        meca_intervention = {
            verrou = "true",
        },
        meca_levitation = {
            verrou = "true",
        },
        meca_perce_armure = {
            verrou = "true",
        },
        meca_permutation = {
            verrou = "true",
        },
        meca_repulsion = {
            verrou = "true",
        },
        meca_soin = {
            verrou = "true",
        },
        mystique = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        mystique_attaque = {
            verrou = "true",
        },
        mystique_bouclier = {
            verrou = "true",
        },
        mystique_brise_armure = {
            verrou = "true",
        },
        mystique_buff = {
            verrou = "true",
        },
        mystique_debuff = {
            verrou = "true",
        },
        mystique_perce_armure = {
            verrou = "true",
        },
        mystique_provocation = {
            verrou = "true",
        },
        mystique_soin = {
            verrou = "true",
        },
        nage = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        niveau = {
            verrou = "true",
        },
        odorat_gout = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        ouie = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        pa = {
            verrou = "true",
        },
        pen_contondant = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_desordre = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_eau = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_esprit = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_feu = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_lumiere = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_mort = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_ombre = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_ordre = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_perforant = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_pourriture = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_terre = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_tranchant = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_vent = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        pen_vie = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        perception = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        perception_attaque = {
            verrou = "true",
        },
        perception_brise_armure = {
            verrou = "true",
        },
        perception_buff = {
            verrou = "true",
        },
        perception_debuff = {
            verrou = "true",
        },
        perception_perce_armure = {
            verrou = "true",
        },
        pistage = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        poids = {
            verrou = "true",
        },
        prise = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        projection = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        puissance = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        puissance_buff = {
            verrou = "true",
        },
        puissance_debuff = {
            verrou = "true",
        },
        resi_contondant = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_desordre = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_eau = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_esprit = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_feu = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_lumiere = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_mort = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_ombre = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_ordre = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_perforant = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_pourriture = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_terre = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_tranchant = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_vent = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resi_vie = {
            base = "3",
            cout = "1",
            max = "5",
            min = "1",
        },
        resistance = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        sabotage = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        sec_deplacement = {
            verrou = "true",
        },
        sec_expertises = {
            verrou = "true",
        },
        sec_fatigue = {
            verrou = "true",
        },
        sec_initiative = {
            verrou = "true",
        },
        sec_mecanique = {
            verrou = "true",
        },
        sec_pa = {
            verrou = "true",
        },
        sec_penetration = {
            verrou = "true",
        },
        sec_resistance = {
            verrou = "true",
        },
        sec_vitalite = {
            verrou = "true",
        },
        toucher = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        vol_a_la_tire = {
            cout = "1",
            max = "5",
            min = "-15",
        },
        vue = {
            cout = "1",
            max = "5",
            min = "-15",
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "race",
    label = "Race",
    raretes = { {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = "6",
        } },
})

LCM.Forge.Add({
    categorie = "traits",
    champs = {
        acrobaties = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        adresse = {
            verrou = "true",
        },
        age = {
            min = "-10",
            verrou = "true",
        },
        communication = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        constitution = {
            verrou = "true",
        },
        cosmique = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        course = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        crochetage = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        defense_constitution = {
            cout = "4",
            max = "4",
            min = "-4",
        },
        deguisement = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        depl_nage = {
            base = "0",
            cout = "2",
            max = "5",
            min = "-5",
        },
        depl_terrestre = {
            base = "0",
            cout = "2",
            max = "5",
            min = "-5",
        },
        depl_vol = {
            min = "-10",
            verrou = "true",
        },
        discretion = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        elementaire = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        endurance = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        equilibre = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        escalade = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        escamotage = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        esprit = {
            verrou = "true",
        },
        evasion = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        existence_ame = {
            min = "-10",
            verrou = "true",
        },
        existence_esprit = {
            min = "-10",
            verrou = "true",
        },
        fatigue = {
            base = "0",
            cout = "1",
            max = "5",
            min = "-5",
        },
        force = {
            verrou = "true",
        },
        initiative = {
            base = "0",
            cout = "4",
            max = "5",
            min = "-5",
        },
        investigation = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        meca_attaque_simple = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_attraction = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_bouclier = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_brise_armure = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_buff = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_confusion = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_controle_mental = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_creation = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_debuff = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_deviation = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_dissipation = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_entrave = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_illusion = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_immobilisation = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_intervention = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_levitation = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_perce_armure = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_permutation = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_repulsion = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        meca_soin = {
            base = "0",
            cout = "2",
            max = "4",
            min = "-4",
        },
        mystique = {
            verrou = "true",
        },
        nage = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        niveau = {
            min = "-10",
            verrou = "true",
        },
        odorat_gout = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        ouie = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        pa = {
            base = "0",
            cout = "8",
            max = "1",
            min = "-1",
        },
        pen_contondant = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_desordre = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_eau = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_esprit = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_feu = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_lumiere = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_mort = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_ombre = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_ordre = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_perforant = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_pourriture = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_terre = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_tranchant = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_vent = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        pen_vie = {
            base = "0",
            cout = "1",
            max = "4",
            min = "0",
        },
        perception = {
            verrou = "true",
        },
        pistage = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        poids = {
            min = "-10",
            verrou = "true",
        },
        prise = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        projection = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        puissance = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        resi_contondant = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_desordre = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_eau = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_esprit = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_feu = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_lumiere = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_mort = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_ombre = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_ordre = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_perforant = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_pourriture = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_terre = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_tranchant = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_vent = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resi_vie = {
            base = "0",
            cout = "1",
            max = "4",
            min = "-2",
        },
        resistance = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        sabotage = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        sec_deplacement = {
            min = "-10",
            verrou = "true",
        },
        sec_expertises = {
            min = "-10",
            verrou = "true",
        },
        sec_fatigue = {
            min = "-10",
            verrou = "true",
        },
        sec_initiative = {
            min = "-10",
            verrou = "true",
        },
        sec_mecanique = {
            min = "-10",
            verrou = "true",
        },
        sec_pa = {
            min = "-10",
            verrou = "true",
        },
        sec_penetration = {
            min = "-10",
            verrou = "true",
        },
        sec_resistance = {
            min = "-10",
            verrou = "true",
        },
        sec_vitalite = {
            min = "-10",
            verrou = "true",
        },
        toucher = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        vol_a_la_tire = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        vue = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
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
            points = "6",
        }, {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            points = "12",
        }, {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            points = "18",
        }, {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            points = "26",
        } },
})
