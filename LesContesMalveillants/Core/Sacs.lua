-- Sacs : les conteneurs de l'inventaire (fenetre Inventaires du template,
-- categorie « Sacs »). Un sac a un nombre de places, et des places pour les
-- devises (compendium : « Gros sac », 12 places ; « Sac de gros », 25).
--
-- Un catalogue (Core/Catalogues.lua) sans effets : un sac ne donne rien, il
-- contient. On peut en porter plusieurs identiques. Ce qu'on range dedans (les
-- placements) viendra ensuite : ce fichier ne pose que les sacs.

local _, LCM = ...

LCM.Sacs = LCM.Catalogue({
    nom = "sac", prefixe = "Sacs", cleEntite = "sacs", doublons = true,
    categories = {
        { id = "sac", label = "Sac", onglet = "Sacs", bloc = "Sacs", capacite = "sacs" },
    },
    champs = {
        { cle = "places", libelle = "nombre de places", min = 1, defaut = 12 },
        { cle = "placesDevise", libelle = "places de devise", min = 0, defaut = 0 },
    },
})
