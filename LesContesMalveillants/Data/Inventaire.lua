-- Les onglets de la fenetre Inventaires, figes (template : inventoryWindows ›
-- window_custom_10). Leur nombre d'emplacements est dans
-- Equilibrage.inventaire ; leur vue de depart, celle du template.

local _, LCM = ...
local Inventaire = LCM.Inventaire

Inventaire.Categorie({ id = "sacs",      label = "Sacs",      vue = "grille", contient = "sac" })
Inventaire.Categorie({ id = "saccoches", label = "Saccoches", vue = "grille", contient = "sac" })
-- L'onglet « Devises » du template a ete retire le 1er octobre 2026 : il n'avait
-- qu'un emplacement, donc il ne pouvait pas tenir la monnaie d'un personnage.
-- C'est la Bourse (Core/Bourse.lua) qui s'en charge. Les cases de devise DANS
-- un sac, elles, restent : c'est autre chose.
