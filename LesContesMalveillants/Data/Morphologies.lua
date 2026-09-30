-- Morphologies : combien de chaque partie, et ce que vaut chacune.
--
-- `effectifs` : le nombre de parties par categorie. Buste et internes sont
-- toujours presents, on ne les compte pas.
-- `parts` : la part du total de PV que vaut UNE partie de cette categorie.
--           somme(effectif x part) doit faire exactement 100.
--
-- Ajouter une morphologie = ajouter un bloc ici. Six bras, douze pattes : il
-- suffit d'ecrire le nombre, la silhouette s'arrange toute seule.
--
-- LES PARTS SONT A VALIDER : elles tiennent mathematiquement, elles ne viennent
-- pas encore de tes regles.

local _, LCM = ...
local Morphologies = LCM.Morphologies

LCM.DEFAULT_MORPHOLOGY = "humanoide"

Morphologies.Add({
    id = "humanoide", label = "Humanoide",
    effectifs = { tete = 1, bras = 2, jambe = 2 },
    parts = { tete = 10, buste = 22, internes = 18, bras = 10, jambe = 15 },
})

Morphologies.Add({
    id = "quadrupede", label = "Quadrupede",
    effectifs = { tete = 1, jambe = 4, queue = 1 },
    parts = { tete = 10, buste = 26, internes = 18, jambe = 11, queue = 2 },
})

Morphologies.Add({
    id = "aile", label = "Humanoide aile",
    effectifs = { tete = 1, bras = 2, jambe = 2, aile = 2 },
    parts = { tete = 9, buste = 20, internes = 16, bras = 9, jambe = 12.5, aile = 6 },
})

-- Preuve par l'absurde que le systeme encaisse : une chose a douze pattes,
-- trois tetes et deux queues. Rien de special a ecrire.
Morphologies.Add({
    id = "aberration", label = "Aberration",
    effectifs = { tete = 3, jambe = 12, queue = 2 },
    parts = { tete = 6, buste = 20, internes = 14, jambe = 3, queue = 6 },
})
