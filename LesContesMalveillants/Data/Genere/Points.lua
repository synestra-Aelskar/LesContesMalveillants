-- ============================================================================
--  FICHIER GENERE — NE PAS MODIFIER A LA MAIN
-- ============================================================================
--  Les vendeurs et les points de recolte de la campagne. Ils viendront de
--  l'atelier MJ, comme le reste du contenu ; en attendant, ce fichier est vide.
--
--  Forme d'un point :
--      LCM.Points.Add({
--          id = "herboriste_du_port", label = "Herboriste du port",
--          nature = "vendeur",              -- ou "ressource"
--          description = "...",
--          offres = {
--              { entree = "herbe_de_lune", quantite = 1, prix = 5, devise = "ecus",
--                stock = { limite = 10, unites = 2, minutes = 30 } },
--          },
--      })
-- ============================================================================

local _, LCM = ...
local _ = LCM.Points
