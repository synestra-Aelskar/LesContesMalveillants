-- Compagnon du maitre du jeu.
--
-- Il porte le CONTENU reserve (PNJ, secrets, notes de rencontre) et, au
-- passage, debloque l'interface MJ de l'addon principal. Ce n'est pas un
-- verrou : un addon vit sur la machine du joueur, donc tout ce qu'on lui envoie
-- lui est lisible. La seule protection reelle est de ne pas livrer ce dossier.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

LCM._masterCompanion = true
MJ.LCM = LCM

_G.LCM_MJ_DB = type(_G.LCM_MJ_DB) == "table" and _G.LCM_MJ_DB or {}

LCM.WhenReady(function()
    LCM.Debug("compagnon MJ charge")
end)
