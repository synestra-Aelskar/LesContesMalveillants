-- lcm-db: {"family": "points", "id": "lcm_64a651_6ace4c99_12e6ed6b_0002_67745d", "registry": "Points", "side": "mj"}
return {
    description = "",
    id = "lcm_64a651_6ace4c99_12e6ed6b_0002_67745d",
    label = "Récolter des gravats",
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
        dd = 10,
        echecConsomme = false,
        limite = 1,
        metiers = {  },
        rayon = 3,
        ressources = {
            {
                aleatoire = true,
                chance = 100,
                entree = "ressources/lcm_64a651_6ace4cd9_12e7e6e8_0004_f78759",
                max = 6,
                min = 1,
                minutes = 0,
                regeneration = false,
            },
        },
    },
}
