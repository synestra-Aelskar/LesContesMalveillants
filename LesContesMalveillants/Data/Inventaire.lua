-- Les onglets de la fenetre Inventaires, figes (template : inventoryWindows ›
-- window_custom_10). Leur nombre d'emplacements est dans
-- Equilibrage.inventaire ; leur vue de depart, celle du template.

local _, LCM = ...
local Inventaire = LCM.Inventaire

Inventaire.Categorie({ id = "sacs",      label = "Sacs",      vue = "grille", contient = "sac" })
Inventaire.Categorie({ id = "saccoches", label = "Saccoches", vue = "grille", contient = "sac" })
Inventaire.Categorie({ id = "devises",   label = "Devises",   vue = "liste",  contient = "devise" })
