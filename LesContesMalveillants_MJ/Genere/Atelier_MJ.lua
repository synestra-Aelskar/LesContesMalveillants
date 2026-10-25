-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Construit depuis la base commune `necronicon/database/entries`.
--  Une archive d'addon est un livrable ; elle n'est jamais la source de verite.
-- ============================================================================

local LCM = _G.LCM
if not LCM then return end

-- ----- jeux (12) ----------------------------------------------------
LCM.Publier(LCM.Forge, {
    categorie = "armes",
    champs = {
        acrobaties = {
            cout = 3,
        },
        adresse = {
            verrou = true,
        },
        communication = {
            cout = 3,
        },
        constitution = {
            verrou = true,
        },
        constitution_bouclier = {
            cout = 4,
        },
        constitution_buff = {
            cout = 4,
        },
        constitution_provocation = {
            cout = 7,
        },
        constitution_soin = {
            cout = 4,
        },
        cosmique = {
            cout = 3,
        },
        course = {
            cout = 3,
        },
        crochetage = {
            cout = 3,
        },
        def_agilite = {
            cout = "1",
        },
        def_courage = {
            cout = "1",
        },
        def_defense = {
            cout = "1",
        },
        def_esprit_libre = {
            cout = "1",
        },
        def_insensible = {
            cout = "1",
        },
        def_mental = {
            cout = "1",
        },
        def_stable = {
            cout = "1",
        },
        deguisement = {
            cout = 3,
        },
        depl_nage = {
            cout = 2,
        },
        depl_terrestre = {
            cout = 2,
        },
        discretion = {
            cout = 3,
        },
        duree_buff = {
            cout = 4,
        },
        elementaire = {
            cout = 3,
        },
        endurance = {
            cout = 3,
        },
        equilibre = {
            cout = 3,
        },
        escalade = {
            cout = 3,
        },
        escamotage = {
            cout = 3,
        },
        esprit = {
            verrou = true,
        },
        esprit_provocation = {
            cout = 7,
        },
        evasion = {
            cout = 3,
        },
        fatigue = {
            cout = 1,
        },
        force = {
            verrou = true,
        },
        force_bouclier = {
            cout = 4,
        },
        force_buff = {
            cout = 4,
        },
        force_perce_armure = {
            cout = 4,
        },
        force_provocation = {
            cout = 7,
        },
        initiative = {
            cout = 2,
        },
        investigation = {
            cout = 3,
        },
        meca_attaque_simple = {
            cout = 1,
        },
        meca_attraction = {
            cout = 1,
        },
        meca_bouclier = {
            cout = 1,
        },
        meca_brise_armure = {
            cout = 1,
        },
        meca_buff = {
            cout = 1,
        },
        meca_confusion = {
            cout = 1,
        },
        meca_controle_mental = {
            cout = 1,
        },
        meca_creation = {
            cout = 1,
        },
        meca_debuff = {
            cout = 1,
        },
        meca_deviation = {
            cout = 1,
        },
        meca_dissipation = {
            cout = 1,
        },
        meca_dot = {
            cout = 1,
        },
        meca_entrave = {
            cout = 1,
        },
        meca_illusion = {
            cout = 1,
        },
        meca_immobilisation = {
            cout = 1,
        },
        meca_intervention = {
            cout = 1,
        },
        meca_intimidation = {
            cout = 1,
        },
        meca_levitation = {
            cout = 1,
        },
        meca_perce_armure = {
            cout = 1,
        },
        meca_permutation = {
            cout = 1,
        },
        meca_peur = {
            cout = 1,
        },
        meca_provocation = {
            cout = 1,
        },
        meca_repulsion = {
            cout = 1,
        },
        meca_soin = {
            cout = 1,
        },
        mystique = {
            verrou = true,
        },
        mystique_bouclier = {
            cout = 4,
        },
        mystique_buff = {
            cout = 4,
        },
        mystique_perce_armure = {
            cout = 4,
        },
        mystique_provocation = {
            cout = 7,
        },
        mystique_soin = {
            cout = 4,
        },
        nage = {
            cout = 3,
        },
        odorat_gout = {
            cout = 3,
        },
        ouie = {
            cout = 3,
        },
        pa = {
            cout = 8,
        },
        perception = {
            verrou = true,
        },
        perception_buff = {
            cout = 4,
        },
        perception_perce_armure = {
            cout = 4,
        },
        pistage = {
            cout = 3,
        },
        prise = {
            cout = 3,
        },
        projection = {
            cout = 3,
        },
        puissance = {
            cout = 3,
        },
        puissance_buff = {
            cout = 4,
        },
        resi_contondant = {
            cout = 1,
        },
        resi_desordre = {
            cout = 1,
        },
        resi_eau = {
            cout = 1,
        },
        resi_esprit = {
            cout = 1,
        },
        resi_feu = {
            cout = 1,
        },
        resi_lumiere = {
            cout = 1,
        },
        resi_mort = {
            cout = 1,
        },
        resi_ombre = {
            cout = 1,
        },
        resi_ordre = {
            cout = 1,
        },
        resi_perforant = {
            cout = 1,
        },
        resi_pourriture = {
            cout = 1,
        },
        resi_terre = {
            cout = 1,
        },
        resi_tranchant = {
            cout = 1,
        },
        resi_vent = {
            cout = 1,
        },
        resi_vie = {
            cout = 1,
        },
        resistance = {
            cout = 3,
        },
        sabotage = {
            cout = 3,
        },
        toucher = {
            cout = 3,
        },
        vol_a_la_tire = {
            cout = 3,
        },
        vue = {
            cout = 3,
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "armes",
    label = "Armes",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            palierIC = "rose",
            points = 0,
        },
        {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            palierIC = "vert",
            points = 6,
        },
        {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            palierIC = "bleu",
            points = 12,
        },
        {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            palierIC = "orange",
            points = 18,
        },
        {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            palierIC = "rouge",
            points = 24,
        },
        {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            palierIC = "violet",
            points = 32,
        },
        {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            palierIC = "noir",
            points = 40,
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "armes",
    champs = {
        acrobaties = {
            base = 0,
            cout = "3",
            min = -2,
        },
        adresse = {
            verrou = true,
        },
        age = {
            verrou = true,
        },
        communication = {
            cout = "3",
            min = -2,
        },
        constitution = {
            verrou = true,
        },
        constitution_bouclier = {
            base = 0,
            cout = 2,
            min = -2,
        },
        constitution_buff = {
            base = 0,
            cout = 2,
            min = -2,
        },
        constitution_debuff = {
            cout = 2,
            max = 2,
            min = -2,
        },
        constitution_empoisonnement = {
            base = 0,
            cout = 2,
            min = -2,
        },
        constitution_intimidation = {
            base = 0,
            cout = 2,
            min = -2,
        },
        constitution_provocation = {
            base = 0,
            cout = 2,
            min = -2,
        },
        constitution_soin = {
            base = 0,
            cout = 2,
            min = -2,
        },
        cosmique = {
            cout = "3",
            min = -2,
        },
        course = {
            base = 0,
            cout = "3",
            min = -2,
        },
        crochetage = {
            base = 0,
            cout = "3",
            min = -2,
        },
        def_agilite = {
            cout = 2,
            max = 4,
            min = -2,
        },
        def_courage = {
            cout = 2,
            max = 4,
            min = -2,
        },
        def_defense = {
            cout = 2,
            max = 4,
            min = -2,
        },
        def_esprit_libre = {
            cout = 2,
            max = 4,
            min = -2,
        },
        def_insensible = {
            cout = 2,
            max = 4,
            min = -2,
        },
        def_mental = {
            cout = 2,
            max = 4,
            min = -2,
        },
        def_stable = {
            cout = 2,
            max = 4,
            min = -2,
        },
        defense_constitution = {
            base = 0,
            cout = 2,
            min = -2,
        },
        deguisement = {
            base = 0,
            cout = "3",
            min = -2,
        },
        depl_nage = {
            cout = 2,
        },
        depl_terrestre = {
            cout = 2,
        },
        depl_vol = {
            verrou = true,
        },
        discretion = {
            base = 0,
            cout = "3",
            min = -2,
        },
        duree_buff = {
            base = 0,
            cout = 2,
            min = -2,
        },
        duree_debuff = {
            cout = 2,
            max = 2,
            min = -2,
        },
        elementaire = {
            cout = "3",
            min = -2,
        },
        endurance = {
            base = 0,
            cout = "3",
            min = -2,
        },
        equilibre = {
            base = 0,
            cout = "3",
            min = -2,
        },
        escalade = {
            base = 0,
            cout = "3",
            min = -2,
        },
        escamotage = {
            base = 0,
            cout = "3",
            min = -2,
        },
        esprit = {
            verrou = true,
        },
        esprit_intimidation = {
            base = 0,
            cout = 2,
            min = -2,
        },
        esprit_provocation = {
            base = 0,
            cout = 2,
            min = -2,
        },
        evasion = {
            base = 0,
            cout = "3",
            min = -2,
        },
        existence_ame = {
            verrou = true,
        },
        existence_esprit = {
            verrou = true,
        },
        fatigue = {
            cout = 1,
        },
        force = {
            verrou = true,
        },
        force_attaque = {
            base = 0,
            cout = 2,
            min = -2,
        },
        force_bouclier = {
            base = 0,
            cout = 2,
            min = -2,
        },
        force_brise_armure = {
            base = 2,
            cout = 2,
            min = -2,
        },
        force_buff = {
            base = 0,
            cout = 2,
            min = -2,
        },
        force_debuff = {
            cout = 2,
            max = 2,
            min = -2,
        },
        force_intimidation = {
            base = 0,
            cout = 2,
            min = -2,
        },
        force_perce_armure = {
            base = 0,
            cout = 2,
            min = -2,
        },
        force_provocation = {
            base = 0,
            cout = 2,
            min = -2,
        },
        force_saignement = {
            base = 0,
            cout = 2,
            min = -2,
        },
        initiative = {
            cout = 2,
        },
        investigation = {
            cout = "3",
            min = -2,
        },
        meca_attaque_simple = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_attraction = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_bouclier = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_brise_armure = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_buff = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_confusion = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_controle_mental = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_creation = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_debuff = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_deviation = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_dissipation = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_dot = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_entrave = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_illusion = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_immobilisation = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_intervention = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_intimidation = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_levitation = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_perce_armure = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_permutation = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_peur = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_provocation = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_repulsion = {
            cout = 2,
            max = 4,
            min = -2,
        },
        meca_soin = {
            cout = 2,
            max = 4,
            min = -2,
        },
        mystique = {
            verrou = true,
        },
        mystique_attaque = {
            base = 0,
            cout = 2,
            min = -2,
        },
        mystique_bouclier = {
            base = 0,
            cout = 2,
            min = -2,
        },
        mystique_brise_armure = {
            base = 2,
            cout = 2,
            min = -2,
        },
        mystique_buff = {
            base = 0,
            cout = 2,
            min = -2,
        },
        mystique_debuff = {
            cout = 2,
            max = 2,
            min = -2,
        },
        mystique_empoisonnement = {
            base = 0,
            cout = 2,
            min = -2,
        },
        mystique_intimidation = {
            base = 0,
            cout = 2,
            min = -2,
        },
        mystique_perce_armure = {
            base = 0,
            cout = 2,
            min = -2,
        },
        mystique_provocation = {
            base = 0,
            cout = 2,
            min = -2,
        },
        mystique_saignement = {
            base = 0,
            cout = 2,
            min = -2,
        },
        mystique_soin = {
            base = 0,
            cout = 2,
            min = -2,
        },
        nage = {
            base = 0,
            cout = "3",
            min = -2,
        },
        niveau = {
            verrou = true,
        },
        odorat_gout = {
            cout = "3",
            min = -2,
        },
        ouie = {
            cout = "3",
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
            base = 0,
            cout = 2,
            min = -2,
        },
        perception_brise_armure = {
            base = 2,
            cout = 2,
            min = -2,
        },
        perception_buff = {
            base = 0,
            cout = 2,
            min = -2,
        },
        perception_debuff = {
            cout = 2,
            max = 2,
            min = -2,
        },
        perception_empoisonnement = {
            base = 0,
            cout = 2,
            min = -2,
        },
        perception_perce_armure = {
            base = 0,
            cout = 2,
            min = -2,
        },
        perception_saignement = {
            base = 0,
            cout = 2,
            min = -2,
        },
        pistage = {
            cout = "3",
            min = -2,
        },
        poids = {
            verrou = true,
        },
        prise = {
            base = 0,
            cout = "3",
            min = -2,
        },
        projection = {
            base = 0,
            cout = "3",
            min = -2,
        },
        puissance = {
            base = 0,
            cout = "3",
            min = -2,
        },
        puissance_buff = {
            base = 0,
            cout = 2,
            min = -2,
        },
        puissance_debuff = {
            cout = 2,
            max = 2,
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
            base = 0,
            cout = "3",
            min = -2,
        },
        sabotage = {
            base = 0,
            cout = "3",
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
            cout = "3",
            min = -2,
        },
        vol_a_la_tire = {
            base = 0,
            cout = "3",
            min = -2,
        },
        vue = {
            cout = "3",
            min = -2,
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "equilibrage_arme",
    label = "Equilibrage_arme",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            palierIC = "rose",
            points = 1,
        },
        {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            palierIC = "vert",
            points = 5,
        },
        {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            palierIC = "bleu",
            points = 9,
        },
        {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            palierIC = "orange",
            points = 14,
        },
        {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            palierIC = "rouge",
            points = 20,
        },
        {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            palierIC = "violet",
            points = 30,
        },
        {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            palierIC = "noir",
            points = 50,
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "armures",
    champs = {
        acrobaties = {
            cout = 3,
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
            cout = 2,
            min = -2,
        },
        constitution_buff = {
            cout = 2,
            min = -2,
        },
        constitution_debuff = {
            cout = 2,
            min = -2,
        },
        constitution_empoisonnement = {
            cout = 2,
            min = -2,
        },
        constitution_intimidation = {
            cout = 2,
            min = -2,
        },
        constitution_provocation = {
            cout = 2,
            min = -2,
        },
        constitution_soin = {
            cout = 2,
            min = -2,
        },
        cosmique = {
            cout = 2,
            min = -2,
        },
        course = {
            cout = 3,
            min = -2,
        },
        crochetage = {
            cout = 3,
            min = -2,
        },
        def_agilite = {
            cout = "1",
        },
        def_courage = {
            cout = "1",
        },
        def_defense = {
            cout = "1",
        },
        def_esprit_libre = {
            cout = "1",
        },
        def_insensible = {
            cout = "1",
        },
        def_mental = {
            cout = "1",
        },
        def_stable = {
            cout = "1",
        },
        defense_constitution = {
            cout = 2,
            min = -2,
        },
        deguisement = {
            cout = 3,
            min = -2,
        },
        depl_nage = {
            cout = 2,
            min = -1,
        },
        depl_terrestre = {
            cout = 2,
            min = -1,
        },
        depl_vol = {
            verrou = true,
        },
        discretion = {
            cout = 3,
            min = -2,
        },
        duree_buff = {
            cout = 2,
            min = -2,
        },
        duree_debuff = {
            cout = 2,
            min = -2,
        },
        elementaire = {
            cout = 2,
            min = -2,
        },
        endurance = {
            cout = 3,
            min = -2,
        },
        equilibre = {
            cout = 3,
            min = -2,
        },
        escalade = {
            cout = 3,
            min = -2,
        },
        escamotage = {
            cout = 3,
            min = -2,
        },
        esprit = {
            verrou = true,
        },
        esprit_intimidation = {
            cout = 2,
            min = -2,
        },
        esprit_provocation = {
            cout = 2,
            min = -2,
        },
        evasion = {
            cout = 3,
            min = -2,
        },
        existence_ame = {
            verrou = true,
        },
        existence_esprit = {
            verrou = true,
        },
        fatigue = {
            cout = 1,
            min = -1,
        },
        force = {
            verrou = true,
        },
        force_attaque = {
            cout = 2,
            min = -2,
        },
        force_bouclier = {
            cout = 2,
            min = -2,
        },
        force_brise_armure = {
            cout = 2,
            min = -2,
        },
        force_buff = {
            cout = 2,
            min = -2,
        },
        force_debuff = {
            cout = 2,
            min = -2,
        },
        force_intimidation = {
            cout = 2,
            min = -2,
        },
        force_perce_armure = {
            cout = 2,
            min = -2,
        },
        force_provocation = {
            cout = 2,
            min = -2,
        },
        force_saignement = {
            cout = 2,
            min = -2,
        },
        initiative = {
            cout = 2,
            min = -1,
        },
        investigation = {
            cout = 2,
            min = -2,
        },
        meca_attaque_simple = {
            cout = "1",
            min = -2,
        },
        meca_attraction = {
            cout = "1",
            min = -2,
        },
        meca_bouclier = {
            cout = "1",
            min = -2,
        },
        meca_brise_armure = {
            cout = "1",
            min = -2,
        },
        meca_buff = {
            cout = "1",
            min = -2,
        },
        meca_confusion = {
            cout = "1",
            min = -2,
        },
        meca_controle_mental = {
            cout = "1",
            min = -2,
        },
        meca_creation = {
            cout = "1",
            min = -2,
        },
        meca_debuff = {
            cout = "1",
            min = -2,
        },
        meca_deviation = {
            cout = "1",
            min = -2,
        },
        meca_dissipation = {
            cout = "1",
            min = -2,
        },
        meca_dot = {
            cout = "1",
        },
        meca_entrave = {
            cout = "1",
            min = -2,
        },
        meca_illusion = {
            cout = "1",
            min = -2,
        },
        meca_immobilisation = {
            cout = "1",
            min = -2,
        },
        meca_intervention = {
            cout = "1",
            min = -2,
        },
        meca_intimidation = {
            cout = "1",
        },
        meca_levitation = {
            cout = "1",
            min = -2,
        },
        meca_perce_armure = {
            cout = "1",
            min = -2,
        },
        meca_permutation = {
            cout = "1",
            min = -2,
        },
        meca_peur = {
            cout = "1",
        },
        meca_provocation = {
            cout = "1",
        },
        meca_repulsion = {
            cout = "1",
            min = -2,
        },
        meca_soin = {
            cout = "1",
            min = -2,
        },
        mystique = {
            verrou = true,
        },
        mystique_attaque = {
            cout = 2,
            min = -2,
        },
        mystique_bouclier = {
            cout = 2,
            min = -2,
        },
        mystique_brise_armure = {
            cout = 2,
            min = -2,
        },
        mystique_buff = {
            cout = 2,
            min = -2,
        },
        mystique_debuff = {
            cout = 2,
            min = -2,
        },
        mystique_empoisonnement = {
            cout = 2,
            min = -2,
        },
        mystique_intimidation = {
            cout = 2,
            min = -2,
        },
        mystique_perce_armure = {
            cout = 2,
            min = -2,
        },
        mystique_provocation = {
            cout = 2,
            min = -2,
        },
        mystique_saignement = {
            cout = 2,
            min = -2,
        },
        mystique_soin = {
            cout = 2,
            min = -2,
        },
        nage = {
            cout = 3,
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
            min = -1,
        },
        pen_contondant = {
            cout = 0.5,
            min = -2,
        },
        pen_desordre = {
            cout = 0.5,
            min = -2,
        },
        pen_eau = {
            cout = 0.5,
            min = -2,
        },
        pen_esprit = {
            cout = 0.5,
            min = -2,
        },
        pen_feu = {
            cout = 0.5,
            min = -2,
        },
        pen_lumiere = {
            cout = 0.5,
            min = -2,
        },
        pen_mort = {
            cout = 0.5,
            min = -2,
        },
        pen_ombre = {
            cout = 0.5,
            min = -2,
        },
        pen_ordre = {
            cout = 0.5,
            min = -2,
        },
        pen_perforant = {
            cout = 0.5,
            min = -2,
        },
        pen_pourriture = {
            cout = 0.5,
            min = -2,
        },
        pen_terre = {
            cout = 0.5,
            min = -2,
        },
        pen_tranchant = {
            cout = 0.5,
            min = -2,
        },
        pen_vent = {
            cout = 0.5,
            min = -2,
        },
        pen_vie = {
            cout = 0.5,
            min = -2,
        },
        perception = {
            verrou = true,
        },
        perception_attaque = {
            cout = 2,
            min = -2,
        },
        perception_brise_armure = {
            cout = 2,
            min = -2,
        },
        perception_buff = {
            cout = 2,
            min = -2,
        },
        perception_debuff = {
            cout = 2,
            min = -2,
        },
        perception_empoisonnement = {
            cout = 2,
            min = -2,
        },
        perception_perce_armure = {
            cout = 2,
            min = -2,
        },
        perception_saignement = {
            cout = 2,
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
            cout = 3,
            min = -2,
        },
        projection = {
            cout = 3,
            min = -2,
        },
        puissance = {
            cout = 3,
            min = -2,
        },
        puissance_buff = {
            cout = 2,
            min = -2,
        },
        puissance_debuff = {
            cout = 2,
            min = -2,
        },
        resi_contondant = {
            cout = 0.25,
            min = -4,
        },
        resi_desordre = {
            cout = 0.25,
            min = -4,
        },
        resi_eau = {
            cout = 0.25,
            min = -4,
        },
        resi_esprit = {
            cout = 0.25,
            min = -4,
        },
        resi_feu = {
            cout = 0.25,
            min = -4,
        },
        resi_lumiere = {
            cout = 0.25,
            min = -4,
        },
        resi_mort = {
            cout = 0.25,
            min = -4,
        },
        resi_ombre = {
            cout = 0.25,
            min = -4,
        },
        resi_ordre = {
            cout = 0.25,
            min = -4,
        },
        resi_perforant = {
            cout = 0.25,
            min = -4,
        },
        resi_pourriture = {
            cout = 0.25,
            min = -4,
        },
        resi_terre = {
            cout = 0.25,
            min = -4,
        },
        resi_tranchant = {
            cout = 0.25,
            min = -4,
        },
        resi_vent = {
            cout = 0.25,
            min = -4,
        },
        resi_vie = {
            cout = 0.25,
            min = -4,
        },
        resistance = {
            cout = 3,
            min = -2,
        },
        sabotage = {
            cout = 3,
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
            cout = 3,
            min = -2,
        },
        vue = {
            cout = 3,
            min = -2,
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "equilibrage_arme_copie",
    label = "Equilibrage_armure",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            palierIC = "rose",
            points = 1,
        },
        {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            palierIC = "vert",
            points = 5,
        },
        {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            palierIC = "bleu",
            points = 9,
        },
        {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            palierIC = "orange",
            points = 14,
        },
        {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            palierIC = "rouge",
            points = 20,
        },
        {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            palierIC = "violet",
            points = 30,
        },
        {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            palierIC = "noir",
            points = 50,
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "accessoires",
    champs = {
        acrobaties = {
            cout = 3,
        },
        communication = {
            cout = 3,
        },
        cosmique = {
            cout = 3,
        },
        course = {
            cout = 3,
        },
        crochetage = {
            cout = 3,
        },
        def_agilite = {
            cout = "1",
        },
        def_courage = {
            cout = "1",
        },
        def_defense = {
            cout = "1",
        },
        def_esprit_libre = {
            cout = "1",
        },
        def_insensible = {
            cout = "1",
        },
        def_mental = {
            cout = "1",
        },
        def_stable = {
            cout = "1",
        },
        deguisement = {
            cout = 3,
        },
        depl_nage = {
            cout = 2,
        },
        depl_terrestre = {
            cout = 2,
        },
        discretion = {
            cout = 3,
        },
        elementaire = {
            cout = 3,
        },
        endurance = {
            cout = 3,
        },
        equilibre = {
            cout = 3,
        },
        escalade = {
            cout = 3,
        },
        escamotage = {
            cout = 3,
        },
        evasion = {
            cout = 3,
        },
        fatigue = {
            cout = 1,
        },
        initiative = {
            cout = 2,
        },
        investigation = {
            cout = 3,
        },
        meca_attaque_simple = {
            cout = "1",
        },
        meca_attraction = {
            cout = "1",
        },
        meca_bouclier = {
            cout = "1",
        },
        meca_brise_armure = {
            cout = "1",
        },
        meca_buff = {
            cout = "1",
        },
        meca_confusion = {
            cout = "1",
        },
        meca_controle_mental = {
            cout = "1",
        },
        meca_creation = {
            cout = "1",
        },
        meca_debuff = {
            cout = "1",
        },
        meca_deviation = {
            cout = "1",
        },
        meca_dissipation = {
            cout = "1",
        },
        meca_dot = {
            cout = "1",
        },
        meca_entrave = {
            cout = "1",
        },
        meca_illusion = {
            cout = "1",
        },
        meca_immobilisation = {
            cout = "1",
        },
        meca_intervention = {
            cout = "1",
        },
        meca_intimidation = {
            cout = "1",
        },
        meca_levitation = {
            cout = "1",
        },
        meca_perce_armure = {
            cout = "1",
        },
        meca_permutation = {
            cout = "1",
        },
        meca_peur = {
            cout = "1",
        },
        meca_provocation = {
            cout = "1",
        },
        meca_repulsion = {
            cout = "1",
        },
        meca_soin = {
            cout = "1",
        },
        nage = {
            cout = 3,
        },
        odorat_gout = {
            cout = 3,
        },
        ouie = {
            cout = 3,
        },
        pa = {
            cout = 8,
        },
        pistage = {
            cout = 3,
        },
        prise = {
            cout = 3,
        },
        projection = {
            cout = 3,
        },
        puissance = {
            cout = 3,
        },
        resistance = {
            cout = 3,
        },
        sabotage = {
            cout = 3,
        },
        toucher = {
            cout = 3,
        },
        vol_a_la_tire = {
            cout = 3,
        },
        vue = {
            cout = 3,
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "equilibrage_armure_copie",
    label = "Equilibrage_accessoires",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            palierIC = "rose",
            points = 1,
        },
        {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            palierIC = "vert",
            points = 5,
        },
        {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            palierIC = "bleu",
            points = 9,
        },
        {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            palierIC = "orange",
            points = 14,
        },
        {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            palierIC = "rouge",
            points = 20,
        },
        {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            palierIC = "violet",
            points = 30,
        },
        {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            palierIC = "noir",
            points = 50,
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "consommables",
    champs = {  },
    description = "",
    id = "lcm_132159_6adb718b_2005bd2b_0004_7abb48",
    label = "Equilibrage_consommable",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            palierIC = "rose",
            points = "1",
        },
        {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            palierIC = "vert",
            points = "5",
        },
        {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            palierIC = "bleu",
            points = "9",
        },
        {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            palierIC = "orange",
            points = "14",
        },
        {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            palierIC = "rouge",
            points = "20",
        },
        {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            palierIC = "violet",
            points = "30",
        },
        {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            palierIC = "noir",
            points = "50",
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "tentes",
    champs = {
        recup_armure = {
            base = "0",
            cout = "1",
            max = "100",
            min = "-20",
        },
        recup_fatigue = {
            base = "0",
            cout = "1",
            max = "100",
            min = "-20",
        },
        recup_pv = {
            base = "0",
            cout = "1",
            max = "100",
            min = "-20",
        },
        securite = {
            base = "0",
            cout = "1",
            max = "100",
            min = "-20",
        },
    },
    id = "lcm_64a651_6acbc610_09097aca_0002_99aa48",
    label = "Jeu 6",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = "10",
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "etats",
    champs = {
        acrobaties = {
            cout = 2,
        },
        adresse = {
            cout = 4,
        },
        age = {
            cout = 10,
        },
        communication = {
            cout = 2,
        },
        constitution = {
            cout = 2,
        },
        cosmique = {
            cout = 2,
        },
        course = {
            cout = 2,
        },
        crochetage = {
            cout = 2,
        },
        def_agilite = {
            cout = 2,
        },
        def_courage = {
            cout = 2,
        },
        def_defense = {
            cout = 2,
        },
        def_esprit_libre = {
            cout = 2,
        },
        def_insensible = {
            cout = 2,
        },
        def_mental = {
            cout = 2,
        },
        def_stable = {
            cout = 2,
        },
        deguisement = {
            cout = 2,
        },
        depl_nage = {
            cout = 2,
        },
        depl_terrestre = {
            cout = 2,
        },
        depl_vol = {
            verrou = true,
        },
        discretion = {
            cout = 2,
        },
        elementaire = {
            cout = 2,
        },
        endurance = {
            cout = 2,
        },
        equilibre = {
            cout = 2,
        },
        escalade = {
            cout = 2,
        },
        escamotage = {
            cout = 2,
        },
        esprit = {
            cout = 4,
        },
        evasion = {
            cout = 2,
        },
        existence_ame = {
            cout = 10,
        },
        existence_esprit = {
            cout = 10,
        },
        fatigue = {
            cout = 1,
        },
        force = {
            cout = 2,
        },
        initiative = {
            cout = 2,
        },
        investigation = {
            cout = 2,
        },
        meca_attaque_simple = {
            cout = 2,
        },
        meca_attraction = {
            cout = 2,
        },
        meca_bouclier = {
            cout = 2,
        },
        meca_brise_armure = {
            cout = 2,
        },
        meca_buff = {
            cout = 2,
        },
        meca_confusion = {
            cout = 2,
        },
        meca_controle_mental = {
            cout = 2,
        },
        meca_creation = {
            cout = 2,
        },
        meca_debuff = {
            cout = 2,
        },
        meca_deviation = {
            cout = 2,
        },
        meca_dissipation = {
            cout = 2,
        },
        meca_dot = {
            cout = 2,
        },
        meca_entrave = {
            cout = 2,
        },
        meca_illusion = {
            cout = 2,
        },
        meca_immobilisation = {
            cout = 2,
        },
        meca_intervention = {
            cout = 2,
        },
        meca_intimidation = {
            cout = 2,
        },
        meca_levitation = {
            cout = 2,
        },
        meca_perce_armure = {
            cout = 2,
        },
        meca_permutation = {
            cout = 2,
        },
        meca_peur = {
            cout = 2,
        },
        meca_provocation = {
            cout = 2,
        },
        meca_repulsion = {
            cout = 2,
        },
        meca_soin = {
            cout = 2,
        },
        mystique = {
            cout = 2,
        },
        nage = {
            cout = 2,
        },
        niveau = {
            cout = 100,
            verrou = true,
        },
        odorat_gout = {
            cout = 2,
        },
        ouie = {
            cout = 2,
        },
        pa = {
            cout = 8,
        },
        pen_contondant = {
            cout = 1,
        },
        pen_desordre = {
            cout = 1,
        },
        pen_eau = {
            cout = 1,
        },
        pen_esprit = {
            cout = 1,
        },
        pen_feu = {
            cout = 1,
        },
        pen_lumiere = {
            cout = 1,
        },
        pen_mort = {
            cout = 1,
        },
        pen_ombre = {
            cout = 1,
        },
        pen_ordre = {
            cout = 1,
        },
        pen_perforant = {
            cout = 1,
        },
        pen_pourriture = {
            cout = 1,
        },
        pen_terre = {
            cout = 1,
        },
        pen_tranchant = {
            cout = 1,
        },
        pen_vent = {
            cout = 1,
        },
        pen_vie = {
            cout = 1,
        },
        perception = {
            cout = 2,
        },
        pistage = {
            cout = 2,
        },
        poids = {
            cout = 1,
        },
        prise = {
            cout = 2,
        },
        projection = {
            cout = 2,
        },
        puissance = {
            cout = 2,
        },
        resi_contondant = {
            cout = 1,
        },
        resi_desordre = {
            cout = 1,
        },
        resi_eau = {
            cout = 1,
        },
        resi_esprit = {
            cout = 1,
        },
        resi_feu = {
            cout = 1,
        },
        resi_lumiere = {
            cout = 1,
        },
        resi_mort = {
            cout = 1,
        },
        resi_ombre = {
            cout = 1,
        },
        resi_ordre = {
            cout = 1,
        },
        resi_perforant = {
            cout = 1,
        },
        resi_pourriture = {
            cout = 1,
        },
        resi_terre = {
            cout = 1,
        },
        resi_tranchant = {
            cout = 1,
        },
        resi_vent = {
            cout = 1,
        },
        resi_vie = {
            cout = 1,
        },
        resistance = {
            cout = 2,
        },
        sabotage = {
            cout = 2,
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
        },
        vol_a_la_tire = {
            cout = 2,
        },
        vue = {
            cout = 2,
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "lcm_64a651_6acd99d5_102ca8dd_0002_e477e8",
    label = "Equilibrage-Etats",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            palierIC = "rose",
            points = 10000,
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "outils",
    champs = {  },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "lcm_64a651_6ad4ab02_18cc6d43_0002_bbe6a7",
    label = "Equilibrage_Outils",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = 1,
        },
        {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            points = 5,
        },
        {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            points = 9,
        },
        {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            points = 14,
        },
        {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            points = 20,
        },
        {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            points = 30,
        },
        {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            points = 50,
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "outils",
    champs = {  },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "lcm_64a651_6ad64dd2_1f305b72_0007_10d35a",
    label = "Outils",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = 1,
        },
        {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            points = 5,
        },
        {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            points = 9,
        },
        {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            points = 14,
        },
        {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            points = 20,
        },
        {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            points = 30,
        },
        {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            points = 50,
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "ressources",
    champs = {  },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "lcm_64a651_6ad65ba9_1f666be6_0003_7e668c",
    label = "Ressources",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = 1,
        },
        {
            couleur = "4DE04D",
            id = "inhabituel",
            label = "Inhabituel",
            points = 5,
        },
        {
            couleur = "4D8CFF",
            id = "rare",
            label = "Rare",
            points = 9,
        },
        {
            couleur = "FF9926",
            id = "epique",
            label = "Épique",
            points = 14,
        },
        {
            couleur = "FF3838",
            id = "legendaire",
            label = "Légendaire",
            points = 20,
        },
        {
            couleur = "BF4DFF",
            id = "mythique",
            label = "Mythique",
            points = 30,
        },
        {
            couleur = "9999A6",
            id = "unique",
            label = "Unique",
            points = 50,
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "races",
    champs = {
        acrobaties = {
            cout = 1,
            max = 5,
            min = -15,
        },
        adresse = {
            base = 3,
            cout = 2,
            max = 5,
            min = 1,
        },
        age = {
            verrou = true,
        },
        communication = {
            cout = 1,
            max = 5,
            min = -15,
        },
        constitution = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        constitution_bouclier = {
            verrou = true,
        },
        constitution_buff = {
            verrou = true,
        },
        constitution_debuff = {
            verrou = true,
        },
        constitution_provocation = {
            verrou = true,
        },
        constitution_soin = {
            verrou = true,
        },
        cosmique = {
            cout = 1,
            max = 5,
            min = -15,
        },
        course = {
            cout = 1,
            max = 5,
            min = -15,
        },
        crochetage = {
            cout = 1,
            max = 5,
            min = -15,
        },
        defense_constitution = {
            verrou = true,
        },
        deguisement = {
            cout = 1,
            max = 5,
            min = -15,
        },
        depl_nage = {
            verrou = true,
        },
        depl_terrestre = {
            verrou = true,
        },
        depl_vol = {
            verrou = true,
        },
        discretion = {
            cout = 1,
            max = 5,
            min = -15,
        },
        duree_buff = {
            verrou = true,
        },
        duree_debuff = {
            verrou = true,
        },
        elementaire = {
            cout = 1,
            max = 5,
            min = -15,
        },
        endurance = {
            cout = 1,
            max = 5,
            min = -15,
        },
        equilibre = {
            cout = 1,
            max = 5,
            min = -15,
        },
        escalade = {
            cout = 1,
            max = 5,
            min = -15,
        },
        escamotage = {
            cout = 1,
            max = 5,
            min = -15,
        },
        esprit = {
            base = 3,
            cout = 2,
            max = 5,
            min = 1,
        },
        esprit_provocation = {
            verrou = true,
        },
        evasion = {
            cout = 1,
            max = 5,
            min = -15,
        },
        existence_ame = {
            verrou = true,
        },
        existence_esprit = {
            verrou = true,
        },
        fatigue = {
            verrou = true,
        },
        force = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        force_attaque = {
            verrou = true,
        },
        force_bouclier = {
            verrou = true,
        },
        force_brise_armure = {
            verrou = true,
        },
        force_buff = {
            verrou = true,
        },
        force_debuff = {
            verrou = true,
        },
        force_perce_armure = {
            verrou = true,
        },
        force_provocation = {
            verrou = true,
        },
        initiative = {
            verrou = true,
        },
        investigation = {
            cout = 1,
            max = 5,
            min = -15,
        },
        meca_attaque_simple = {
            verrou = true,
        },
        meca_attraction = {
            verrou = true,
        },
        meca_bouclier = {
            verrou = true,
        },
        meca_brise_armure = {
            verrou = true,
        },
        meca_buff = {
            verrou = true,
        },
        meca_confusion = {
            verrou = true,
        },
        meca_controle_mental = {
            verrou = true,
        },
        meca_creation = {
            verrou = true,
        },
        meca_debuff = {
            verrou = true,
        },
        meca_deviation = {
            verrou = true,
        },
        meca_dissipation = {
            verrou = true,
        },
        meca_entrave = {
            verrou = true,
        },
        meca_illusion = {
            verrou = true,
        },
        meca_immobilisation = {
            verrou = true,
        },
        meca_intervention = {
            verrou = true,
        },
        meca_levitation = {
            verrou = true,
        },
        meca_perce_armure = {
            verrou = true,
        },
        meca_permutation = {
            verrou = true,
        },
        meca_repulsion = {
            verrou = true,
        },
        meca_soin = {
            verrou = true,
        },
        mystique = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        mystique_attaque = {
            verrou = true,
        },
        mystique_bouclier = {
            verrou = true,
        },
        mystique_brise_armure = {
            verrou = true,
        },
        mystique_buff = {
            verrou = true,
        },
        mystique_debuff = {
            verrou = true,
        },
        mystique_perce_armure = {
            verrou = true,
        },
        mystique_provocation = {
            verrou = true,
        },
        mystique_soin = {
            verrou = true,
        },
        nage = {
            cout = 1,
            max = 5,
            min = -15,
        },
        niveau = {
            verrou = true,
        },
        odorat_gout = {
            cout = 1,
            max = 5,
            min = -15,
        },
        ouie = {
            cout = 1,
            max = 5,
            min = -15,
        },
        pa = {
            verrou = true,
        },
        pen_contondant = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_desordre = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_eau = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_esprit = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_feu = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_lumiere = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_mort = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_ombre = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_ordre = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_perforant = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_pourriture = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_terre = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_tranchant = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_vent = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        pen_vie = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        perception = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        perception_attaque = {
            verrou = true,
        },
        perception_brise_armure = {
            verrou = true,
        },
        perception_buff = {
            verrou = true,
        },
        perception_debuff = {
            verrou = true,
        },
        perception_perce_armure = {
            verrou = true,
        },
        pistage = {
            cout = 1,
            max = 5,
            min = -15,
        },
        poids = {
            verrou = true,
        },
        prise = {
            cout = 1,
            max = 5,
            min = -15,
        },
        projection = {
            cout = 1,
            max = 5,
            min = -15,
        },
        puissance = {
            cout = 1,
            max = 5,
            min = -15,
        },
        puissance_buff = {
            verrou = true,
        },
        puissance_debuff = {
            verrou = true,
        },
        resi_contondant = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_desordre = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_eau = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_esprit = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_feu = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_lumiere = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_mort = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_ombre = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_ordre = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_perforant = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_pourriture = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_terre = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_tranchant = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_vent = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resi_vie = {
            base = 3,
            cout = 1,
            max = 5,
            min = 1,
        },
        resistance = {
            cout = 1,
            max = 5,
            min = -15,
        },
        sabotage = {
            cout = 1,
            max = 5,
            min = -15,
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
            cout = 1,
            max = 5,
            min = -15,
        },
        vol_a_la_tire = {
            cout = 1,
            max = 5,
            min = -15,
        },
        vue = {
            cout = 1,
            max = 5,
            min = -15,
        },
    },
    description = "",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "race",
    label = "Race",
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            points = "40",
        },
    },
})

LCM.Publier(LCM.Forge, {
    categorie = "traits",
    champs = {
        acrobaties = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        adresse = {
            verrou = true,
        },
        age = {
            min = "-10",
            verrou = true,
        },
        communication = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        constitution = {
            verrou = true,
        },
        constitution_bouclier = {
            verrou = true,
        },
        constitution_buff = {
            verrou = true,
        },
        constitution_debuff = {
            verrou = true,
        },
        constitution_empoisonnement = {
            verrou = true,
        },
        constitution_intimidation = {
            verrou = true,
        },
        constitution_provocation = {
            verrou = true,
        },
        constitution_soin = {
            verrou = true,
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
        def_agilite = {
            base = "0",
            cout = "2",
            max = "8",
            min = "0",
        },
        def_courage = {
            base = "0",
            cout = "2",
            max = "8",
            min = "0",
        },
        def_defense = {
            base = "0",
            cout = "2",
            max = "8",
            min = "0",
        },
        def_esprit_libre = {
            base = "0",
            cout = "2",
            max = "8",
            min = "0",
        },
        def_insensible = {
            base = "0",
            cout = "2",
            max = "8",
            min = "0",
        },
        def_mental = {
            base = "0",
            cout = "2",
            max = "8",
            min = "0",
        },
        def_stable = {
            base = "0",
            cout = "2",
            max = "8",
            min = "0",
        },
        defense_constitution = {
            cout = "4",
            max = "4",
            min = "-4",
            verrou = true,
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
            verrou = true,
        },
        discretion = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        duree_buff = {
            verrou = true,
        },
        duree_debuff = {
            verrou = true,
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
            verrou = true,
        },
        esprit_intimidation = {
            verrou = true,
        },
        esprit_provocation = {
            verrou = true,
        },
        evasion = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        existence_ame = {
            min = "-10",
            verrou = true,
        },
        existence_esprit = {
            min = "-10",
            verrou = true,
        },
        fatigue = {
            base = "0",
            cout = "1",
            max = "5",
            min = "-5",
        },
        force = {
            verrou = true,
        },
        force_attaque = {
            verrou = true,
        },
        force_bouclier = {
            verrou = true,
        },
        force_brise_armure = {
            verrou = true,
        },
        force_buff = {
            verrou = true,
        },
        force_debuff = {
            verrou = true,
        },
        force_intimidation = {
            verrou = true,
        },
        force_perce_armure = {
            verrou = true,
        },
        force_provocation = {
            verrou = true,
        },
        force_saignement = {
            verrou = true,
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
            max = "8",
            min = "-4",
        },
        meca_attraction = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_bouclier = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_brise_armure = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_buff = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_confusion = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_controle_mental = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_creation = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_debuff = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_deviation = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_dissipation = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_dot = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_entrave = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_illusion = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_immobilisation = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_intervention = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_intimidation = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_levitation = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_perce_armure = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_permutation = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_peur = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_provocation = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_repulsion = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        meca_soin = {
            base = "0",
            cout = "2",
            max = "8",
            min = "-4",
        },
        mystique = {
            verrou = true,
        },
        mystique_attaque = {
            verrou = true,
        },
        mystique_bouclier = {
            verrou = true,
        },
        mystique_brise_armure = {
            verrou = true,
        },
        mystique_buff = {
            verrou = true,
        },
        mystique_debuff = {
            verrou = true,
        },
        mystique_empoisonnement = {
            verrou = true,
        },
        mystique_intimidation = {
            verrou = true,
        },
        mystique_perce_armure = {
            verrou = true,
        },
        mystique_provocation = {
            verrou = true,
        },
        mystique_saignement = {
            verrou = true,
        },
        mystique_soin = {
            verrou = true,
        },
        nage = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        niveau = {
            min = "-10",
            verrou = true,
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
            max = "20",
            min = "0",
        },
        pen_desordre = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_eau = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_esprit = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_feu = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_lumiere = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_mort = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_ombre = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_ordre = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_perforant = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_pourriture = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_terre = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_tranchant = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_vent = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        pen_vie = {
            base = "0",
            cout = "1",
            max = "20",
            min = "0",
        },
        perception = {
            verrou = true,
        },
        perception_attaque = {
            verrou = true,
        },
        perception_brise_armure = {
            verrou = true,
        },
        perception_buff = {
            verrou = true,
        },
        perception_debuff = {
            verrou = true,
        },
        perception_empoisonnement = {
            verrou = true,
        },
        perception_perce_armure = {
            verrou = true,
        },
        perception_saignement = {
            verrou = true,
        },
        pistage = {
            base = "0",
            cout = "2",
            max = "4",
            min = "0",
        },
        poids = {
            min = "-10",
            verrou = true,
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
        puissance_buff = {
            verrou = true,
        },
        puissance_debuff = {
            verrou = true,
        },
        resi_contondant = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_desordre = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_eau = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_esprit = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_feu = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_lumiere = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_mort = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_ombre = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_ordre = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_perforant = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_pourriture = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_terre = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_tranchant = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_vent = {
            base = "0",
            cout = "1",
            max = "20",
            min = "-2",
        },
        resi_vie = {
            base = "0",
            cout = "1",
            max = "20",
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
        },
        sec_expertises = {
            min = "-10",
            verrou = true,
        },
        sec_fatigue = {
            min = "-10",
        },
        sec_initiative = {
            min = "-10",
        },
        sec_mecanique = {
            min = "-10",
            verrou = true,
        },
        sec_pa = {
            min = "-10",
        },
        sec_penetration = {
            min = "-10",
            verrou = true,
        },
        sec_resistance = {
            min = "-10",
            verrou = true,
        },
        sec_vitalite = {
            min = "-10",
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
    raretes = {
        {
            couleur = "FF8CB8",
            id = "commun",
            label = "Commun",
            palierIC = "rose",
            points = "6",
        },
        {
            couleur = "4DE04D",
            coutTrait = "2",
            id = "inhabituel",
            label = "Inhabituel",
            palierIC = "vert",
            points = "12",
        },
        {
            couleur = "4D8CFF",
            coutTrait = "3",
            id = "rare",
            label = "Rare",
            palierIC = "bleu",
            points = "18",
        },
        {
            couleur = "FF9926",
            coutTrait = "4",
            id = "epique",
            label = "Épique",
            palierIC = "orange",
            points = "26",
        },
    },
})

-- ----- pnj (3) -----------------------------------------------------
LCM.Publier(LCM.PNJ, {
    apprentissages = {  },
    equipement = {
        accessoire = { "lcm_64a651_6ac7bf81_36d51ea2_0010_f1c74a", "lcm_64a651_6ac7bfb7_36d5f1de_0011_981ba7", "lcm_64a651_6acb7e3f_07f0f686_000e_eee119" },
        arme = { "lcm_64a651_6ac7bbe9_36c708be_0001_efdd32", "lcm_64a651_6ac7bbe9_36c708be_0001_efdd32" },
        equipement = { "lcm_64a651_6ac7bf11_36d36743_0008_d09027", "lcm_64a651_6ac7be10_36cf7992_0004_fb40af", "lcm_64a651_6ac7be6a_36d0dc15_0005_7dbd88", "lcm_64a651_6ac7beb5_36d1fee9_0006_6b2588", "lcm_64a651_6ac7beea_36d2cf27_0007_8cf26e" },
    },
    etats = {  },
    icone = "Interface\\ICONS\\ability_mage_frostjaw",
    id = "lcm_64a651_6ac7bd59_36ccb275_0002_1e1934",
    label = "Asssassin du culte",
    metiersNiveaux = {
        eclaireur = 4,
    },
    traits = { "lcm_64a651_6ac7710f_35a2aedc_0003_6b06bc", "lcm_64a651_6ac76e82_3598aaf8_0001_f2b89d", "lcm_64a651_6ac7715c_35a3dd0b_0004_ba2485", "lcm_64a651_6ac77195_35a4bae4_0005_9cc402", "lcm_64a651_6acb7c33_07e8ea2e_0001_290bb6" },
    valeurs = {
        acrobaties = 4,
        adresse = 8,
        age = "30",
        constitution = 6,
        crochetage = 3,
        def_agilite = 2,
        def_courage = 2,
        def_defense = 2,
        def_esprit_libre = 2,
        def_mental = 2,
        def_stable = 2,
        deguisement = 4,
        discretion = 8,
        equilibre = 4,
        escalade = 4,
        esprit = 7,
        evasion = 6,
        force = 5,
        meca_brise_armure = 2,
        meca_buff = 4,
        meca_debuff = 4,
        meca_entrave = 2,
        meca_immobilisation = 2,
        meca_perce_armure = 6,
        mystique = 7,
        niveau = 14,
        pen_contondant = 11,
        pen_ombre = 16,
        pen_perforant = 14,
        pen_tranchant = 14,
        perception = 11,
        pistage = 6,
        poids = "70",
        prise = 2,
        race = "aelskardien",
        resi_contondant = 14,
        resi_ombre = 16,
        resi_perforant = 14,
        resi_tranchant = 14,
        sabotage = 2,
        sec_deplacement = 5,
        sec_expertises = 5,
        sec_fatigue = 3,
        sec_initiative = 3,
        sec_mecanique = 10,
        sec_pa = 1,
        sec_penetration = 8,
        sec_vitalite = 6,
        sexe = "Autre",
        vol_a_la_tire = 3,
    },
})

LCM.Publier(LCM.PNJ, {
    apprentissages = {  },
    equipement = {
        accessoire = { "lcm_64a651_6aced581_02029a27_0024_0779ae" },
        arme = { "lcm_64a651_6aced4fa_02008acc_0023_de2ead" },
        equipement = { "lcm_64a651_6aced371_01fa872b_0008_2528da", "lcm_64a651_6aced3c9_01fbe20c_000b_ffef6c", "lcm_64a651_6aced474_01fe7f4a_000e_7cd315", "lcm_64a651_6aced4d3_01fff30d_001f_3216c5" },
    },
    etats = {  },
    icone = "Interface\\ICONS\\eps_lol_item_bamiscinder",
    id = "lcm_64a651_6aced381_01fac6f6_0009_468327",
    label = "Nhin Géolier",
    metiersNiveaux = {  },
    traits = { "lcm_64a651_6aced2e4_01f863c6_0003_d663b1", "lcm_64a651_6aced05c_01ee805c_0002_685bb7" },
    valeurs = {
        adresse = 7,
        age = 140,
        constitution = 11,
        def_defense = 8,
        endurance = 8,
        esprit = 7,
        force = 14,
        meca_attaque_simple = 10,
        meca_attraction = 5,
        meca_brise_armure = 6,
        meca_peur = 8,
        mystique = 6,
        niveau = 16,
        pen_contondant = 17,
        pen_perforant = 14,
        pen_pourriture = 17,
        pen_tranchant = 14,
        perception = 6,
        poids = 250,
        prise = 8,
        projection = 8,
        puissance = 8,
        race = "lcm_aa9c40_6acecf5e_01ea95fe_0001_4b65d0",
        resi_contondant = 30,
        resi_perforant = 30,
        resi_pourriture = 31,
        resi_tranchant = 30,
        resistance = 8,
        sec_initiative = 10,
        sec_mecanique = 10,
        sec_penetration = 9,
        sec_resistance = 15,
        sec_vitalite = 22,
        sexe = "Masculin",
    },
})

LCM.Publier(LCM.PNJ, {
    description = "",
    equipement = {
        arme = { "lcm_64a651_6adb7af6_0a5736cd_0004_627585" },
    },
    icone = "Interface\\ICONS\\achievement_reputation_ogre",
    id = "lcm_64a651_6adb7aff_0a5759ec_0005_286071",
    label = "Max la bagarre",
    metiersNiveaux = {
        depeceur = "30",
    },
    traits = { "lcm_64a651_6adb7916_0a4fe223_0002_603254", "lcm_64a651_6adb7ab8_0a5642fe_0003_de4228" },
    valeurs = {
        adresse = "9",
        age = "42",
        constitution = "15",
        course = "2",
        def_defense = "5",
        def_stable = "5",
        esprit = "2",
        force = "18",
        meca_attaque_simple = "8",
        meca_intimidation = "6",
        meca_repulsion = "6",
        mystique = "2",
        niveau = "14",
        odorat_gout = "10",
        pen_contondant = "25",
        pen_perforant = "6",
        perception = "2",
        poids = "1250",
        prise = "4",
        projection = "10",
        puissance = "10",
        race = "lcm_aa9c40_6adb6c92_0a1ef442_0001_98aa1a",
        resi_contondant = "29",
        resi_feu = "15",
        resi_perforant = "29",
        resi_tranchant = "29",
        sec_fatigue = "13",
        sec_mecanique = "8",
        sec_pa = "2",
        sec_penetration = "1",
        sec_resistance = "9",
        sec_vitalite = "13",
        sexe = "Masculin",
    },
})

-- ----- points (13) --------------------------------------------------
LCM.Publier(LCM.Points, {
    categorie = "Osolninh - Horrig-Burg",
    description = "",
    deviseDefaut = "ecus",
    icone = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\fenetres-bourse.tga",
    id = "lcm_132159_6ace46bf_03455ffe_0002_644c43",
    label = "Segarmat",
    nature = "vendeur",
    onglets = {
        {
            id = "onglet_1",
            label = "Articles",
            offres = {
                {
                    cle = "lcm_132159_6ace46bf_03455ffe_0002_644c43/lcm_132159_6ace46e5_0345f355_0003_6ee99a",
                    entree = "sacs/gros_sac",
                    id = "lcm_132159_6ace46e5_0345f355_0003_6ee99a",
                    label = "",
                    prix = {
                        {
                            {
                                quantite = "600",
                                ref = "devises/ecus",
                            },
                        },
                    },
                    quantite = "1",
                    stock = {
                        limite = "1",
                        minutes = "0",
                        unites = "0",
                    },
                },
                {
                    cle = "lcm_132159_6ace46bf_03455ffe_0002_644c43/lcm_132159_6ace46e5_0345f5ad_0004_a6c4af",
                    entree = "sacs/sac_de_gros",
                    id = "lcm_132159_6ace46e5_0345f5ad_0004_a6c4af",
                    label = "",
                    prix = {
                        {
                            {
                                quantite = "250",
                                ref = "devises/ecus",
                            },
                        },
                    },
                    quantite = "1",
                    stock = {
                        limite = "0",
                        minutes = "0",
                        unites = "0",
                    },
                },
                {
                    cle = "lcm_132159_6ace46bf_03455ffe_0002_644c43/lcm_132159_6ace46e6_0345f783_0005_5058fc",
                    entree = "sacs/sacoche_de_depart",
                    id = "lcm_132159_6ace46e6_0345f783_0005_5058fc",
                    label = "",
                    prix = {
                        {
                            {
                                quantite = "150",
                                ref = "devises/ecus",
                            },
                        },
                    },
                    quantite = "1",
                    stock = {
                        limite = "0",
                        minutes = "0",
                        unites = "0",
                    },
                },
            },
        },
    },
    rachats = {
        {
            id = "rachat_1",
            label = "Rachats",
        },
    },
})

LCM.Publier(LCM.Points, {
    description = "",
    id = "lcm_132159_6ad78dfb_10d4c284_0002_bf568f",
    label = "Récolter la pierre",
    nature = "ressource",
    offres = {  },
    recolte = {
        dd = 0,
        echecConsomme = false,
        limite = 1,
        metiers = {  },
        rayon = 3,
        ressources = {
            {
                aleatoire = false,
                chance = 100,
                entree = "ressources/lcm_64a651_6ad65d53_1f6ceb05_0008_ac7d09",
                max = 1,
                min = 1,
                minutes = 0,
                regeneration = false,
            },
            {
                aleatoire = false,
                chance = 100,
                entree = "ressources/lcm_64a651_6ad65c1f_1f683923_0006_eecba6",
                max = 1,
                min = 1,
                minutes = 0,
                regeneration = false,
            },
            {
                aleatoire = false,
                chance = 100,
                entree = "ressources/lcm_64a651_6ad65e22_1f70123b_000b_aa9a60",
                max = 1,
                min = 1,
                minutes = 0,
                regeneration = false,
            },
            {
                aleatoire = false,
                chance = 100,
                entree = "ressources/lcm_64a651_6ad65ebf_1f7276d7_000e_4cb110",
                max = 1,
                min = 1,
                minutes = 0,
                regeneration = false,
            },
        },
    },
})

LCM.Publier(LCM.Points, {
    categorie = "Osolninh - Horrig-Burg",
    description = "",
    deviseDefaut = "credits",
    icone = "Interface\\Icons\\INV_Misc_QuestionMark",
    id = "lcm_64a651_6ac4d4a7_2b6fce7a_0003_2eb5f7",
    label = "Martin",
    nature = "vendeur",
    onglets = {
        {
            id = "onglet_1",
            label = "Articles",
            offres = {
                {
                    cle = "lcm_64a651_6ac4d4a7_2b6fce7a_0003_2eb5f7/lcm_64a651_6ac4d4c7_2b704ab2_0004_524268",
                    entree = "objets/arc_court",
                    id = "lcm_64a651_6ac4d4c7_2b704ab2_0004_524268",
                    label = "",
                    prix = {
                        {
                            {
                                quantite = "250",
                                ref = "devises/credits",
                            },
                        },
                    },
                    quantite = "1",
                    stock = {
                        limite = "3",
                        minutes = "60",
                        unites = "1",
                    },
                },
            },
        },
    },
    rachats = {
        {
            id = "rachat_1",
            label = "Rachats",
        },
    },
})

LCM.Publier(LCM.Points, {
    categorie = "HUB",
    description = "",
    deviseDefaut = "credits",
    icone = "Interface\\Icons\\INV_Misc_Coin_02",
    id = "lcm_64a651_6acfe4c4_06262ef9_0002_c341b0",
    label = "Epheron",
    nature = "vendeur",
    onglets = {
        {
            id = "onglet_1",
            label = "Articles",
            offres = {
                {
                    cle = "lcm_64a651_6acfe4c4_06262ef9_0002_c341b0/lcm_64a651_6acff549_0666b210_0002_ed1a1c",
                    entree = "objets/lcm_aa9c40_6acfb25d_056140d0_0001_6ce82a",
                    id = "lcm_64a651_6acff549_0666b210_0002_ed1a1c",
                    label = "",
                    prix = {
                        {
                            {
                                quantite = "250",
                                ref = "devises/credits",
                            },
                        },
                    },
                    quantite = "1",
                    stock = {
                        limite = "15",
                        minutes = "0",
                        unites = "0",
                    },
                },
            },
        },
    },
    rachats = {
        {
            id = "rachat_1",
            label = "Rachats",
        },
    },
})

LCM.Publier(LCM.Points, {
    coffre = {
        expertises = {
            {
                dd = "17",
                fatigue = "2",
                id = "crochetage",
                reverrouillable = true,
                usureOutils = true,
            },
            {
                dd = "20",
                fatigue = "4",
                id = "puissance",
                reverrouillable = false,
                usureOutils = false,
            },
            {
                dd = "17",
                fatigue = "2",
                id = "sabotage",
                reverrouillable = true,
                usureOutils = false,
            },
        },
        outils = {
            {
                consomme = false,
                consommeQuantite = "1",
                expertise = "crochetage",
                quantite = "1",
                typeOutil = "lcm_64a651_6ad257b0_0fb70286_0002_90a6d4",
            },
        },
        places = "10",
        rayon = "1.5",
        reset = false,
        verrous = "2",
    },
    description = "",
    id = "lcm_64a651_6ad0355b_0760f978_0002_69c19a",
    label = "Coffre solidement verrouillé.",
    nature = "coffre",
    onglets = {
        {
            id = "onglet_1",
            label = "Articles",
        },
    },
})

LCM.Publier(LCM.Points, {
    coffre = {
        expertises = {
            {
                dd = "14",
                fatigue = "2",
                id = "crochetage",
                reverrouillable = true,
                usureOutils = true,
            },
            {
                dd = "14",
                fatigue = "2",
                id = "sabotage",
                reverrouillable = false,
                usureOutils = false,
            },
            {
                dd = "20",
                fatigue = "4",
                id = "puissance",
                reverrouillable = true,
                usureOutils = false,
            },
        },
        outils = {
            {
                consomme = false,
                consommeQuantite = "1",
                expertise = "crochetage",
                quantite = "1",
                typeOutil = "lcm_64a651_6ad257b0_0fb70286_0002_90a6d4",
            },
        },
        places = "10",
        rayon = "1.5",
        reset = false,
        verrous = "1",
    },
    description = "",
    id = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
    label = "Coffre verrouillé",
    nature = "coffre",
    onglets = {
        {
            id = "onglet_1",
            label = "Articles",
        },
    },
})

LCM.Publier(LCM.Points, {
    coffre = {
        expertises = {
            {
                dd = "17",
                fatigue = "2",
                id = "crochetage",
                reverrouillable = true,
                usureOutils = true,
            },
            {
                dd = "17",
                fatigue = "2",
                id = "sabotage",
                reverrouillable = false,
                usureOutils = false,
            },
            {
                dd = "20",
                fatigue = "4",
                id = "puissance",
                reverrouillable = true,
                usureOutils = false,
            },
        },
        outils = {
            {
                consomme = false,
                consommeQuantite = "1",
                expertise = "crochetage",
                quantite = "1",
                typeOutil = "lcm_64a651_6ad257b0_0fb70286_0002_90a6d4",
            },
        },
        places = "10",
        rayon = "1",
        reset = false,
        verrous = "1",
    },
    description = "",
    id = "lcm_64a651_6ad64b86_1f2763c4_0002_a79731",
    label = "Coffre solidement verrouillé",
    nature = "coffre",
    onglets = {
        {
            id = "onglet_1",
            label = "Articles",
        },
    },
})

LCM.Publier(LCM.Points, {
    coffre = {
        expertises = {
            {
                dd = 15,
                fatigue = 2,
                id = "escamotage",
                reverrouillable = true,
                usureOutils = false,
            },
            {
                dd = 15,
                fatigue = 2,
                id = "puissance",
                reverrouillable = false,
                usureOutils = false,
            },
        },
        objets = {  },
        outils = {  },
        places = 10,
        rayon = 1,
        reset = false,
        verrous = 1,
    },
    description = "",
    id = "lcm_64a651_6ad6953f_20475b27_0005_8e597a",
    label = "Cassier bloqué.",
    nature = "coffre",
})

LCM.Publier(LCM.Points, {
    coffre = {
        expertises = {
            {
                dd = "20",
                fatigue = "4",
                id = "puissance",
                reverrouillable = false,
                usureOutils = false,
            },
            {
                dd = "15",
                fatigue = "2",
                id = "crochetage",
                reverrouillable = true,
                usureOutils = true,
            },
        },
        outils = {
            {
                consomme = false,
                consommeQuantite = "1",
                expertise = "puissance",
                quantite = "1",
                typeOutil = "lcm_64a651_6ad257b0_0fb70286_0002_90a6d4",
            },
        },
        places = "10",
        rayon = "1",
        reset = false,
        verrous = "1",
    },
    description = "",
    id = "lcm_64a651_6ad6958c_20488800_0006_95616c",
    label = "Cassier fermé.",
    nature = "coffre",
    onglets = {
        {
            id = "onglet_1",
            label = "Articles",
        },
    },
})

LCM.Publier(LCM.Points, {
    coffre = {
        expertises = {  },
        objets = {  },
        outils = {  },
        places = 5,
        rayon = 2,
        reset = false,
        verrous = 0,
    },
    description = "",
    id = "lcm_64a651_6ad696d6_204d92ef_000a_e325e4",
    label = "Table",
    nature = "coffre",
})

LCM.Publier(LCM.Points, {
    coffre = {
        expertises = {
            {
                dd = 40,
                fatigue = 10,
                id = "puissance",
                reverrouillable = true,
                usureOutils = false,
            },
        },
        objets = {  },
        outils = {  },
        places = 10,
        rayon = 4,
        reset = false,
        verrous = 2,
    },
    description = "",
    id = "lcm_64a651_6ad69b2b_205e800a_0015_33aeef",
    label = "Coffre ancien",
    nature = "coffre",
})

LCM.Publier(LCM.Points, {
    coffre = {
        expertises = {  },
        objets = {
            {
                entree = "objets/lcm_64a651_6ad4ab11_18cca79b_0003_582122",
                quantite = 2,
            },
            {
                entree = "objets/katana",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad699e3_20597cb9_0012_35135e",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad65961_1f5d7298_0001_bb9861",
                quantite = 4,
            },
            {
                entree = "objets/lcm_64a651_6ad6a129_2075e8c3_001c_b21b43",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad693f0_20423093_0001_2f767b",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad6a1ac_2077e559_001e_3e8557",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad693b8_204164db_0008_1cbf44",
                quantite = 4,
            },
            {
                entree = "ressources/lcm_64a651_6ad698e5_20559c3e_0010_d9c4c2",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad6a21c_20799d29_001f_2e1783",
                quantite = 25,
            },
        },
        outils = {  },
        places = 25,
        reset = false,
        sac = "sac_de_gros",
        verrous = 0,
    },
    description = "Lâché au sol par Reïkä-Apertus.",
    id = "lcm_64a651_6ad6a2e8_207cb95d_0024_f2e669",
    label = "Sac de gros de Inconnue",
    nature = "coffre",
})

LCM.Publier(LCM.Points, {
    description = "",
    id = "lcm_64a651_6ad79771_2437e8ec_0004_45e4ae",
    label = "Récupérer les outils de crochetages.",
    nature = "ressource",
    offres = {  },
    onglets = {
        {
            id = "onglet_1",
            label = "Articles",
            offres = {  },
        },
    },
    rachats = {  },
    recolte = {
        dd = 0,
        echecConsomme = false,
        limite = 1,
        metiers = {  },
        rayon = 1,
        ressources = {
            {
                aleatoire = false,
                chance = 100,
                entree = "objets/lcm_64a651_6ad64b7b_1f2726d6_0001_9b532f",
                max = 1,
                min = 1,
                minutes = 0,
                regeneration = false,
            },
        },
    },
})

-- ----- poses (43) ---------------------------------------------------
LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad4b4e200161",
        mapid = 585,
        objets = {
            {
                entree = "objets/couteau_a_depecer",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad10a50_0aa0cd22_0003_a57e3e",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad65961_1f5d7298_0001_bb9861",
                quantite = 5,
            },
            {
                entree = "ressources/lcm_64a651_6ad6a21c_20799d29_001f_2e1783",
                quantite = 8,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792324834,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11101.619140625,
        y = 10443.2109375,
        z = -387.03329467773,
    },
    epoque = 29,
    id = "c6ad4b4e200161",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad64b86_1f2763c4_0002_a79731",
        epoque = 29,
        id = "c6ad64cab0049f",
        mapid = 585,
        objets = {
            {
                entree = "objets/rempart_de_guerre",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad64e8d_1f333644_0002_031f9a",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792429227,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11080.10546875,
        y = 10439.440429688,
        z = -478.32897949219,
    },
    epoque = 29,
    id = "c6ad64cab0049f",
    label = "Coffre solidement verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad64b86_1f2763c4_0002_a79731",
        epoque = 29,
        id = "c6ad6561a001d0",
        mapid = 585,
        objets = {
            {
                entree = "objets/lcm_64a651_6ad655bc_1f4f3bea_0001_191e68",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad4ab11_18cca79b_0003_582122",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad65717_1f548f99_0004_7f5032",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad693f0_20423093_0001_2f767b",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad693b8_204164db_0008_1cbf44",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792431642,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11109.21875,
        y = 10468.24609375,
        z = -454.03039550781,
    },
    epoque = 29,
    id = "c6ad6561a001d0",
    label = "Coffre solidement verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad0355b_0760f978_0002_69c19a",
        epoque = 29,
        id = "c6ad6593e0027f",
        mapid = 585,
        objets = {
            {
                entree = "objets/lcm_64a651_6ad65732_1f54fb40_0005_e376f8",
                quantite = 1,
            },
            {
                entree = "objets/trousse_de_veterinaire_de_terrain",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad0c1d8_0985bdbc_0003_781391",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad698e5_20559c3e_0010_d9c4c2",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad693b8_204164db_0008_1cbf44",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792432446,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 2,
        version = 1,
        x = 11104.03125,
        y = 10427.775390625,
        z = -387.03268432617,
    },
    epoque = 29,
    id = "c6ad6593e0027f",
    label = "Coffre solidement verrouillé.",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad0355b_0760f978_0002_69c19a",
        epoque = 29,
        id = "c6ad65a390010a",
        mapid = 585,
        objets = {  },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792432697,
        source = "gps",
        verrouille = false,
        verrousOuverts = { true, true },
        verrousRestants = 0,
        version = 1,
        x = 11124.173828125,
        y = 10467.701171875,
        z = -386.99127197266,
    },
    epoque = 29,
    id = "c6ad65a390010a",
    label = "Coffre solidement verrouillé.",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad65a3f00256",
        mapid = 585,
        objets = {  },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792432703,
        source = "gps",
        verrouille = false,
        verrousOuverts = { false },
        verrousRestants = 0,
        version = 1,
        x = 11124.896484375,
        y = 10469.502929688,
        z = -386.54049682617,
    },
    epoque = 29,
    id = "c6ad65a3f00256",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad65ac6004d7",
        mapid = 585,
        objets = {
            {
                entree = "objets/rempart_de_guerre",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad65732_1f54fb40_0005_e376f8",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad4ab11_18cca79b_0003_582122",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792432838,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11072.442382812,
        y = 10502.9609375,
        z = -426.45486450195,
    },
    epoque = 29,
    id = "c6ad65ac6004d7",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad65b17005fd",
        mapid = 585,
        objets = {
            {
                entree = "objets/epee_rouillee",
                quantite = 1,
            },
            {
                entree = "objets/harnois_blanc",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792432919,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11099.672851562,
        y = 10392.3203125,
        z = -487.01937866211,
    },
    epoque = 29,
    id = "c6ad65b17005fd",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad65b4000648",
        mapid = 585,
        objets = {
            {
                entree = "objets/lcm_64a651_6ad65732_1f54fb40_0005_e376f8",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad6a8b1_2093524d_0003_269275",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad6a21c_20799d29_001f_2e1783",
                quantite = 2,
            },
            {
                entree = "ressources/lcm_64a651_6ad65961_1f5d7298_0001_bb9861",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad691e4_203a41c9_0005_edf1c8",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad698e5_20559c3e_0010_d9c4c2",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792432960,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11035.676757812,
        y = 10400.376953125,
        z = -487.09683227539,
    },
    epoque = 29,
    id = "c6ad65b4000648",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad0355b_0760f978_0002_69c19a",
        epoque = 29,
        id = "c6ad68fdd001e6",
        mapid = 585,
        objets = {
            {
                entree = "ressources/lcm_64a651_6ad65961_1f5d7298_0001_bb9861",
                quantite = 5,
            },
            {
                entree = "objets/lcm_64a651_6ad65732_1f54fb40_0005_e376f8",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad693b8_204164db_0008_1cbf44",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad6a6b5_208b909d_0002_03630b",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792446429,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 2,
        version = 1,
        x = 11038.473632812,
        y = 10394.931640625,
        z = -478.36755371094,
    },
    epoque = 29,
    id = "c6ad68fdd001e6",
    label = "Coffre solidement verrouillé.",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad6913b0027d",
        mapid = 585,
        objets = {
            {
                entree = "ressources/lcm_aa9c40_6ad68e2f_202bb932_0001_d016e0",
                quantite = 5,
            },
            {
                entree = "ressources/lcm_64a651_6ad6917e_2038b154_0002_0495e5",
                quantite = 4,
            },
            {
                entree = "ressources/lcm_64a651_6ad693b8_204164db_0008_1cbf44",
                quantite = 2,
            },
            {
                entree = "ressources/lcm_64a651_6ad691e4_203a41c9_0005_edf1c8",
                quantite = 3,
            },
            {
                entree = "ressources/lcm_64a651_6ad693f0_20423093_0001_2f767b",
                quantite = 2,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792446779,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11068.036132812,
        y = 10398.983398438,
        z = -477.69436645508,
    },
    epoque = 29,
    id = "c6ad6913b0027d",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad6953f_20475b27_0005_8e597a",
        epoque = 29,
        id = "c6ad695740013a",
        mapid = 585,
        objets = {
            {
                entree = "ressources/lcm_64a651_6ad65c1f_1f683923_0006_eecba6",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792447860,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11092.603515625,
        y = 10440.892578125,
        z = -487.67208862305,
    },
    epoque = 29,
    id = "c6ad695740013a",
    label = "Cassier bloqué.",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad6958c_20488800_0006_95616c",
        epoque = 29,
        id = "c6ad695b20023e",
        mapid = 585,
        objets = {  },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792447922,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11090.657226562,
        y = 10440.881835938,
        z = -487.67208862305,
    },
    epoque = 29,
    id = "c6ad695b20023e",
    label = "Cassier fermé.",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad6958c_20488800_0006_95616c",
        epoque = 29,
        id = "c6ad695b6003d8",
        mapid = 585,
        objets = {
            {
                entree = "ressources/lcm_64a651_6ad69649_204b6b9c_0008_8ea27e",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792447926,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11088.409179688,
        y = 10440.693359375,
        z = -487.67208862305,
    },
    epoque = 29,
    id = "c6ad695b6003d8",
    label = "Cassier fermé.",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad6958c_20488800_0006_95616c",
        epoque = 29,
        id = "c6ad695b80049f",
        mapid = 585,
        objets = {
            {
                entree = "objets/epee_rouillee",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792447928,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11096.703125,
        y = 10441.41015625,
        z = -487.67208862305,
    },
    epoque = 29,
    id = "c6ad695b80049f",
    label = "Cassier fermé.",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad696d6_204d92ef_000a_e325e4",
        epoque = 29,
        id = "c6ad696da005c1",
        mapid = 585,
        objets = {
            {
                entree = "objets/lcm_64a651_6ad64b7b_1f2726d6_0001_9b532f",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad4ab11_18cca79b_0003_582122",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792448218,
        source = "gps",
        verrouille = false,
        verrousOuverts = {  },
        verrousRestants = 0,
        version = 1,
        x = 11099.508789062,
        y = 10441.655273438,
        z = -486.81112670898,
    },
    epoque = 29,
    id = "c6ad696da005c1",
    label = "Table",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 349,
        def = "lcm_64a651_6ad64b86_1f2763c4_0002_a79731",
        epoque = 29,
        id = "c6ad69985006ba",
        mapid = 585,
        objets = {
            {
                entree = "ressources/lcm_64a651_6ad69940_2056ffd5_0011_2aebe3",
                quantite = 3,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792448901,
        source = "gps",
        verrouille = false,
        verrousOuverts = { false },
        verrousRestants = 0,
        version = 1,
        x = 11197.934570312,
        y = 10494.612304688,
        z = -403.63278198242,
    },
    epoque = 29,
    id = "c6ad69985006ba",
    label = "Coffre solidement verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 349,
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad699f50070b",
        mapid = 585,
        objets = {
            {
                entree = "ressources/lcm_64a651_6ad69940_2056ffd5_0011_2aebe3",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792449013,
        source = "gps",
        verrouille = false,
        verrousOuverts = { false },
        verrousRestants = 0,
        version = 1,
        x = 11203.583007812,
        y = 10480.244140625,
        z = -402.81893920898,
    },
    epoque = 29,
    id = "c6ad699f50070b",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 349,
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad699fc008ca",
        mapid = 585,
        objets = {  },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792449020,
        source = "gps",
        verrouille = false,
        verrousOuverts = { false },
        verrousRestants = 0,
        version = 1,
        x = 11199.540039062,
        y = 10475.571289062,
        z = -403.00555419922,
    },
    epoque = 29,
    id = "c6ad699fc008ca",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 349,
        def = "lcm_64a651_6ad69b2b_205e800a_0015_33aeef",
        epoque = 29,
        id = "c6ad69b41009b5",
        mapid = 585,
        objets = {
            {
                entree = "objets/lcm_64a651_6ad69c6a_20635e8c_0018_cf22e7",
                quantite = 1,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792449345,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 2,
        version = 1,
        x = 11169.200195312,
        y = 10492.509765625,
        z = -402.66763305664,
    },
    epoque = 29,
    id = "c6ad69b41009b5",
    label = "Coffre ancien",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 204,
        def = "lcm_64a651_6ad6a2e8_207cb95d_0024_f2e669",
        epoque = 29,
        id = "c6ad6a2d900c20",
        objets = {
            {
                entree = "objets/lcm_64a651_6ad4ab11_18cca79b_0003_582122",
                quantite = 2,
            },
            {
                entree = "objets/katana",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad699e3_20597cb9_0012_35135e",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad65961_1f5d7298_0001_bb9861",
                quantite = 4,
            },
            {
                entree = "objets/lcm_64a651_6ad6a129_2075e8c3_001c_b21b43",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad693f0_20423093_0001_2f767b",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad6a1ac_2077e559_001e_3e8557",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad693b8_204164db_0008_1cbf44",
                quantite = 4,
            },
            {
                entree = "ressources/lcm_64a651_6ad698e5_20559c3e_0010_d9c4c2",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad6a21c_20799d29_001f_2e1783",
                quantite = 25,
            },
        },
        ouvert = true,
        posePar = "Reïkä-Apertus",
        quand = 1792451289,
        source = "gps",
        verrouille = false,
        verrousOuverts = {  },
        verrousRestants = 0,
        version = 1,
        x = -5550.7749023438,
        y = 5560.2060546875,
        z = 518.25244140625,
    },
    epoque = 29,
    id = "c6ad6a2d900c20",
    label = "Sac de gros de Inconnue",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad6a5a100166",
        mapid = 585,
        objets = {
            {
                entree = "ressources/lcm_64a651_6ad698e5_20559c3e_0010_d9c4c2",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad6a21c_20799d29_001f_2e1783",
                quantite = 5,
            },
            {
                entree = "devises/ecus",
                quantite = 200,
            },
        },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792452001,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 11103.15625,
        y = 10491.295898438,
        z = -386.73672485352,
    },
    epoque = 29,
    id = "c6ad6a5a100166",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 1606,
        def = "lcm_64a651_6ad696d6_204d92ef_000a_e325e4",
        epoque = 29,
        id = "c6ad6b01c002cb",
        mapid = 585,
        objets = {
            {
                entree = "objets/lcm_64a651_6ad6a939_209564a6_0006_8050a9",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad6a1ac_2077e559_001e_3e8557",
                quantite = 1,
            },
            {
                entree = "ressources/lcm_64a651_6ad6a21c_20799d29_001f_2e1783",
                quantite = 3,
            },
            {
                entree = "ressources/lcm_64a651_6ad65961_1f5d7298_0001_bb9861",
                quantite = 1,
            },
            {
                entree = "objets/lcm_64a651_6ad65732_1f54fb40_0005_e376f8",
                quantite = 1,
            },
        },
        ouvert = true,
        posePar = "Reïkä-Apertus",
        quand = 1792454684,
        source = "gps",
        verrouille = false,
        verrousOuverts = {  },
        verrousRestants = 0,
        version = 1,
        x = 11068.447265625,
        y = 10395.87890625,
        z = -477.51574707031,
    },
    epoque = 29,
    id = "c6ad6b01c002cb",
    label = "Table",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad78c430019c",
        mapid = 1925,
        objets = {  },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792511043,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 13130.935546875,
        y = 9333.9482421875,
        z = -85.439125061035,
    },
    epoque = 29,
    id = "c6ad78c430019c",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        def = "lcm_64a651_6ad105d7_0a8f5408_0002_ed545c",
        epoque = 29,
        id = "c6ad790a700156",
        mapid = 1925,
        objets = {  },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792512167,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 1,
        version = 1,
        x = 13130.897460938,
        y = 9354.6748046875,
        z = -85.43968963623,
    },
    epoque = 29,
    id = "c6ad790a700156",
    label = "Coffre verrouillé",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        auteur = "Reïkä-Apertus",
        carte = 947,
        def = "lcm_64a651_6ad0355b_0760f978_0002_69c19a",
        epoque = 15,
        id = "c6ad8d9d6001cd",
        mapid = 1270,
        objets = {  },
        ouvert = false,
        posePar = "Reïkä-Apertus",
        quand = 1792596438,
        source = "gps",
        verrouille = true,
        verrousOuverts = {  },
        verrousRestants = 2,
        version = 1,
        x = 7971.8481445312,
        y = 2164.8237304688,
        z = 231.07386779785,
    },
    epoque = 15,
    id = "c6ad8d9d6001cd",
    label = "Coffre solidement verrouillé.",
    nature = "coffre",
    version = 1,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        def = "lcm_64a651_6acfe4c4_06262ef9_0002_c341b0",
        id = "m6acfe50600167",
        quand = 1792009478,
        source = "monde",
        x = 13128.7998046875,
        y = 9327.6005859375,
    },
    epoque = 0,
    id = "m6acfe50600167",
    label = "Epheron",
    nature = "vendeur",
    stock = {
        ["lcm_64a651_6acfe4c4_06262ef9_0002_c341b0/lcm_64a651_6acff549_0666b210_0002_ed1a1c"] = 13,
    },
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Nytherah-Apertus",
    description = "",
    donnees = {
        carte = 947,
        def = "lcm_132159_6ace46bf_03455ffe_0002_644c43",
        id = "m6ad8ac49001f8",
        mapid = 1270,
        posePar = "Nytherah-Apertus",
        quand = 1792584777,
        source = "gps",
        x = 5097.7314453125,
        y = 1313.478393554688,
        z = 42.06788635253906,
    },
    epoque = 0,
    id = "m6ad8ac49001f8",
    label = "Segarmat",
    nature = "vendeur",
    stock = {
        ["lcm_132159_6ace46bf_03455ffe_0002_644c43/lcm_132159_6ace46e5_0345f355_0003_6ee99a"] = 0,
    },
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 349,
        def = "lcm_64a651_6ad0d5c6_09d397ff_0003_13331c",
        id = "r6ad4c16c00135",
        quand = 1792328044,
        source = "gps",
        x = 11186.2529296875,
        y = 10478.73828125,
        z = -378.3488464355469,
    },
    epoque = 0,
    id = "r6ad4c16c00135",
    label = "lcm_64a651_6ad0d5c6_09d397ff_0003_13331c",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad658cb_1f5b36c6_0007_51af86",
        id = "r6ad658d5001c0",
        quand = 1792432341,
        source = "gps",
        x = 11100.314453125,
        y = 10484.1044921875,
        z = -442.8186950683594,
    },
    epoque = 0,
    id = "r6ad658d5001c0",
    label = "lcm_64a651_6ad658cb_1f5b36c6_0007_51af86",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad658cb_1f5b36c6_0007_51af86",
        id = "r6ad658f80020c",
        quand = 1792432376,
        source = "gps",
        x = 11095.4453125,
        y = 10443.00390625,
        z = -452.4873657226563,
    },
    epoque = 0,
    id = "r6ad658f80020c",
    label = "lcm_64a651_6ad658cb_1f5b36c6_0007_51af86",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad658cb_1f5b36c6_0007_51af86",
        id = "r6ad659230033c",
        quand = 1792432419,
        source = "gps",
        x = 11044.546875,
        y = 10473.591796875,
        z = -386.0072937011719,
    },
    epoque = 0,
    id = "r6ad659230033c",
    label = "lcm_64a651_6ad658cb_1f5b36c6_0007_51af86",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad65dab_1f6e413b_0009_48aa6d",
        id = "r6ad65db9002be",
        quand = 1792433593,
        source = "gps",
        x = 11046.45703125,
        y = 10434.7138671875,
        z = -488.100830078125,
    },
    epoque = 0,
    id = "r6ad65db9002be",
    label = "lcm_64a651_6ad65dab_1f6e413b_0009_48aa6d",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad65dd4_1f6ee441_000a_03df8e",
        id = "r6ad65ddb003e1",
        quand = 1792433627,
        source = "gps",
        x = 11024.09765625,
        y = 10428.173828125,
        z = -485.5959167480469,
    },
    epoque = 0,
    id = "r6ad65ddb003e1",
    label = "lcm_64a651_6ad65dd4_1f6ee441_000a_03df8e",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad65e4c_1f70b5dd_000c_6485f2",
        id = "r6ad65e4a0044e",
        quand = 1792433738,
        source = "gps",
        x = 11102.7255859375,
        y = 10394.154296875,
        z = -486.8223876953125,
    },
    epoque = 0,
    id = "r6ad65e4a0044e",
    label = "lcm_64a651_6ad65e4c_1f70b5dd_000c_6485f2",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad65f4c_1f74a128_000f_e3884b",
        id = "r6ad65f4900586",
        quand = 1792433993,
        source = "gps",
        x = 11083.9482421875,
        y = 10388.1875,
        z = -477.3483581542969,
    },
    epoque = 0,
    id = "r6ad65f4900586",
    label = "lcm_64a651_6ad65f4c_1f74a128_000f_e3884b",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad65fa3_1f75f518_0011_f06db7",
        id = "r6ad65f9d00692",
        quand = 1792434077,
        source = "gps",
        x = 11078.4853515625,
        y = 10378.56640625,
        z = -487.6725158691406,
    },
    epoque = 0,
    id = "r6ad65f9d00692",
    label = "lcm_64a651_6ad65fa3_1f75f518_0011_f06db7",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad65e4c_1f70b5dd_000c_6485f2",
        id = "r6ad66003007be",
        quand = 1792434179,
        source = "gps",
        x = 11044.1494140625,
        y = 10473.1484375,
        z = -386.2335815429688,
    },
    epoque = 0,
    id = "r6ad66003007be",
    label = "lcm_64a651_6ad65e4c_1f70b5dd_000c_6485f2",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 1606,
        def = "lcm_64a651_6ad69808_20523dae_000c_d8935d",
        id = "r6ad6980e0015d",
        quand = 1792448526,
        source = "gps",
        x = 11102.4306640625,
        y = 10287.5625,
        z = 300.2156982421875,
    },
    epoque = 0,
    id = "r6ad6980e0015d",
    label = "lcm_64a651_6ad69808_20523dae_000c_d8935d",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 349,
        def = "lcm_64a651_6ad79771_2437e8ec_0004_45e4ae",
        id = "r6ad797730011d",
        lignes = {  },
        mapid = 585,
        quand = 1792513907,
        source = "gps",
        x = 11186.7158203125,
        y = 10479.3955078125,
        z = -378.5048522949219,
    },
    epoque = 0,
    id = "r6ad797730011d",
    label = "Récupérer les outils de crochetages.",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 349,
        def = "lcm_64a651_6ad79771_2437e8ec_0004_45e4ae",
        id = "r6ad797db002b4",
        lignes = {  },
        mapid = 585,
        quand = 1792514011,
        source = "gps",
        x = 11170.4990234375,
        y = 10459.6650390625,
        z = -403.6333923339844,
    },
    epoque = 0,
    id = "r6ad797db002b4",
    label = "Récupérer les outils de crochetages.",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 349,
        def = "lcm_64a651_6ad79771_2437e8ec_0004_45e4ae",
        id = "r6ad7980b0035d",
        lignes = {  },
        mapid = 585,
        quand = 1792514059,
        source = "gps",
        x = 11175.3486328125,
        y = 10485.8984375,
        z = -403.6337585449219,
    },
    epoque = 0,
    id = "r6ad7980b0035d",
    label = "Récupérer les outils de crochetages.",
    nature = "ressource",
    version = 0,
})

LCM.Publier(LCM.Poses, {
    auteur = "Reïkä-Apertus",
    description = "",
    donnees = {
        carte = 349,
        def = "lcm_64a651_6ad79771_2437e8ec_0004_45e4ae",
        id = "r6ad7983c004f6",
        lignes = {  },
        mapid = 585,
        quand = 1792514108,
        source = "gps",
        x = 11201.7392578125,
        y = 10474.630859375,
        z = -402.7030639648438,
    },
    epoque = 0,
    id = "r6ad7983c004f6",
    label = "Récupérer les outils de crochetages.",
    nature = "ressource",
    version = 0,
})
