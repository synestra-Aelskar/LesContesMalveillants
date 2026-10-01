-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Ecrit par Outils/importer_necronicon.py a partir du compendium Necronicon
--  « Systeme d'Aelskar »
--  (Necronicon_System_Les_contes_Malveillants_MJ/data.lua).
--  Toute retouche manuelle sera perdue au prochain import.
--
--  Pour changer une entree : la corriger en jeu (Compendium, mode MJ), puis
--  l'exporter comme un brouillon.
-- ============================================================================

local _, LCM = ...
LCM.PNJ.Add({
    id = "assassin_du_culte",
    label = "Assassin du culte",
    icone = "Interface\\ICONS\\ability_rogue_shadowdance",
    equipement = {
        arme = { "dague_d_assassin_du_culte" },
        equipement = { "capuche_d_assassin_du_culte", "tenue_d_assassin_du_culte" },
    },
    traits = { "maitre_de_la_discretion", "assassin_expert", "adepte_de_nocturna" },
    valeurs = {
        acrobaties = 5,
        adresse = 7,
        constitution = 5,
        crochetage = 3,
        deguisement = 5,
        discretion = 7,
        equilibre = 5,
        escalade = 5,
        esprit = 7,
        evasion = 5,
        force = 4,
        investigation = 2,
        meca_attaque_simple = 6,
        meca_bouclier = 3,
        meca_buff = 4,
        meca_deviation = 4,
        meca_entrave = 6,
        meca_immobilisation = 6,
        meca_perce_armure = 8,
        meca_soin = 3,
        mystique = 6,
        niveau = 12,
        pen_contondant = 5,
        pen_ombre = 14,
        pen_perforant = 10,
        pen_tranchant = 8,
        perception = 10,
        pistage = 4,
        prise = 2,
        race = "aelskardien",
        resi_contondant = 10,
        resi_esprit = 5,
        resi_feu = 5,
        resi_ombre = 14,
        resi_perforant = 10,
        resi_tranchant = 10,
        sec_deplacement = 3,
        sec_expertises = 7,
        sec_fatigue = 5,
        sec_initiative = 5,
        sec_mecanique = 2,
        sec_pa = 2,
        sec_penetration = 4,
        sec_resistance = 4,
        sec_vitalite = 4,
        vol_a_la_tire = 3,
    },
})
