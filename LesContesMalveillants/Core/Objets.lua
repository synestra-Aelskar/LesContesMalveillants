-- Objets : armes, armures et vetements, accessoires.
--
-- Un catalogue (Core/Catalogues.lua) : un objet est une DEFINITION, comme un
-- trait — icone, description, categorie, bonus, avantage. Il est cree en jeu
-- par le MJ (atelier), puis exporte vers Data/Genere/Objets.lua. Un objet
-- peut donner une primaire (le template en a : une armure a Force +1).
--
-- Cote entite, on ne stocke que ce qui est equipe : des identifiants, ranges
-- par categorie, autant que la categorie a d'emplacements.
--
--     entity.equipement = { arme = { "lame_de_givre" }, accessoire = { ... } }
--
-- Pas encore d'inventaire : on equipe un objet parce qu'il existe, pas parce
-- qu'on le possede. C'est pour ca que l'equipement est un geste de MJ.

local _, LCM = ...

-- `onglet` et `bloc` : les libelles de la fenetre Equipements du template.
-- `toutesLesCases` : la fenetre montre toutes les places, meme vides (les
-- cinq pieces d'armure, les cinq accessoires se lisent d'un coup d'oeil).
local Objets = LCM.Catalogue({
    nom = "objet", prefixe = "Objets", cleEntite = "equipement", primaires = true,
    categories = {
        { id = "arme",       label = "Arme",       onglet = "Armes",       bloc = "Armes principales" },
        { id = "equipement", label = "Armure",     onglet = "Armures",     bloc = "Armures et vêtements", toutesLesCases = true },
        { id = "accessoire", label = "Accessoire", onglet = "Accessoires", bloc = "Accessoires", toutesLesCases = true },
    },
})
LCM.Objets = Objets

-- Les noms que le reste de l'addon connaissait deja.
Objets.Icone = LCM.Icone
Objets.Emplacements = Objets.Capacite
Objets.Equiper = Objets.Placer
Objets.Desequiper = Objets.Enlever
Objets.EstEquipe = Objets.Porte
Objets.Equipes = Objets.Portes
