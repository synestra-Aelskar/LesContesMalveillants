-- lcm-db: {"family": "points", "id": "lcm_64a651_6ad0c3a2_098cbb12_0006_191c5c", "registry": "Points", "side": "mj"}
return {
    coffre = {
        expertises = {
            {
                dd = 10,
                fatigue = 2,
                id = "crochetage",
                reverrouillable = true,
                usureOutils = true,
            },
            {
                dd = 15,
                fatigue = 4,
                id = "puissance",
                reverrouillable = true,
                usureOutils = true,
            },
            {
                dd = 10,
                fatigue = 3,
                id = "sabotage",
                reverrouillable = false,
                usureOutils = true,
            },
        },
        objets = {
            {
                entree = "objets/trousse_de_veterinaire_de_terrain",
                quantite = 1,
            },
            {
                entree = "objets/lcm_aa9c40_6ad01d02_0701cde1_0001_4276a5",
                quantite = 1,
            },
            {
                entree = "objets/couteau_a_depecer",
                quantite = 1,
            },
            {
                entree = "objets/luth",
                quantite = 1,
            },
        },
        outils = {
            {
                consomme = false,
                consommeQuantite = 1,
                entree = "objets/lcm_64a651_6ad0c1d8_0985bdbc_0003_781391",
                expertise = "crochetage",
                quantite = 1,
            },
        },
        places = 10,
        rayon = 4,
        reset = false,
        verrous = 1,
    },
    description = "",
    id = "lcm_64a651_6ad0c3a2_098cbb12_0006_191c5c",
    label = "Coffre miteux de gauche.",
    nature = "coffre",
    offres = {  },
    onglets = {
        {
            id = "onglet_1",
            label = "Articles",
            offres = {  },
        },
    },
    rachats = {  },
}
