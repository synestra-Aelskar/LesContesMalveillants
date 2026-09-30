-- Les fenetres du menu qui montrent un morceau de la fiche.
--
-- Chaque vue habille l'entree du menu radial qui porte son identifiant. Elle
-- ne declare pas de champ : elle designe ce qui existe deja dans la feuille
-- (voir Core/Vues.lua). Une entree du menu sans vue ni fenetre reste eteinte.

local _, LCM = ...
local Vues = LCM.Vues

Vues.Add({
    id = "sante", titre = "Santé",
    largeur = 560, hauteur = 640,
    blocs = {
        { section = { "general", "vitalite" } },
    },
})

Vues.Add({
    id = "expertise", titre = "Expertise",
    largeur = 600, hauteur = 700,
    blocs = {
        { onglet = "expertises" },
    },
})

-- Categorie directe du menu (pas d'eventail) : le clic ouvre cette vue.
Vues.Add({
    id = "deplacement", titre = "Déplacement",
    largeur = 480, hauteur = 300,
    blocs = {
        { label = "Déplacement", champs = { "depl_terrestre", "depl_nage" } },
    },
})
