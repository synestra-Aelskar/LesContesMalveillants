-- Les fenetres du menu qui montrent un morceau de la fiche.
--
-- Chaque vue habille l'entree du menu radial qui porte son identifiant. Elle
-- ne declare pas de champ : elle designe ce qui existe deja dans la feuille
-- (voir Core/Vues.lua). Une entree du menu sans vue ni fenetre reste eteinte.

local _, LCM = ...
local Vues = LCM.Vues

Vues.Add({
    id = "sante", titre = "Santé",
    largeur = 460, hauteur = 400,
    blocs = {
        { section = { "general", "Vitalite" } },
    },
})

Vues.Add({
    id = "expertise", titre = "Expertise",
    largeur = 460, hauteur = 600,
    blocs = {
        { onglet = "expertises" },
    },
})
