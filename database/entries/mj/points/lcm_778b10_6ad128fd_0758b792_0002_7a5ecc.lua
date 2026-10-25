-- lcm-db: {"family": "points", "id": "lcm_778b10_6ad128fd_0758b792_0002_7a5ecc", "registry": "Points", "side": "mj"}
return {
    description = "",
    id = "lcm_778b10_6ad128fd_0758b792_0002_7a5ecc",
    label = "Récolter de l'eau",
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
        limite = 0,
        metier = "__aucun__",
        metiers = {
            {
                bonus = false,
                id = "__aucun__",
            },
        },
        rayon = 3,
        ressources = {
            {
                aleatoire = true,
                chance = 100,
                entree = "ressources/eau",
                max = 18,
                min = 1,
                minutes = 0,
                regeneration = true,
            },
        },
    },
}
