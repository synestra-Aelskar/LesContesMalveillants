-- Sacs : les conteneurs de l'inventaire (fenetre Inventaires du template,
-- categorie « Sacs »). Un sac a un nombre de places, et des places pour les
-- devises (compendium : « Gros sac », 12 places ; « Sac de gros », 25).
--
-- Un catalogue (Core/Catalogues.lua) sans effets : un sac ne donne rien, il
-- contient. Ce fichier ne pose que les DEFINITIONS des sacs ; ou une entite
-- les range, et ce qu'elle met dedans, c'est l'inventaire (Core/Inventaire.lua).

local _, LCM = ...

LCM.Sacs = LCM.Catalogue({
    nom = "sac", prefixe = "Sacs", cleEntite = "sacs", doublons = true,
    categories = {
        { id = "sac", label = "Sac", onglet = "Sacs", bloc = "Sacs", capacite = "sacs" },
    },
    champs = {
        { cle = "places", libelle = "nombre de places", min = 1, defaut = 12 },
        { cle = "placesDevise", libelle = "places de devise", min = 0, defaut = 0 },
        -- « Sac maitre du jeu » du template (case de l'onglet General).
        { cle = "sacMJ", libelle = "sac du maitre du jeu", genre = "case" },
    },
})
