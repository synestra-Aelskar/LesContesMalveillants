-- lcm-db: {"family": "points", "id": "lcm_64a651_6ad64b86_1f2763c4_0002_a79731", "registry": "Points", "side": "mj"}
return {
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
}
