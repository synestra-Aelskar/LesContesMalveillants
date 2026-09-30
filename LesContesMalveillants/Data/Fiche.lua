-- La feuille des Contes Malveillants.
--
-- C'est ici, et nulle part ailleurs, que vit la structure d'une fiche. Les
-- identifiants ne bougent jamais une fois publies : ce sont eux que referencent
-- les formules, les actions et les sauvegardes existantes.
--
-- Trois onglets : General, Statistiques, Traits.

local _, LCM = ...
local Schema = LCM.Schema

Schema.AddTab({
    id = "general",
    label = "General",
    sections = {
        {
            label = "Vitalite",
            fields = {
                -- Le maximum vient d'une formule ; sa repartition sur les
                -- parties du corps vient de la morphologie de la race.
                -- Les PV COURANTS ne sont pas un champ : ils sont la somme des
                -- parties (LCM.Body.Totals).
                { id = "pv_max", kind = "calc", label = "Points de vie (max)",
                  formula = function(entity)
                      local e = LCM.Equilibrage.pv
                      local niveau = tonumber(LCM.Entities.Get_Value(entity, "niveau")) or 0
                      local constitution = tonumber(LCM.Entities.Get_Value(entity, "constitution")) or 0
                      local vitalite = tonumber(LCM.Entities.Get_Value(entity, "sec_vitalite")) or 0
                      return math.floor(e.base + e.parNiveau * niveau
                          + e.parConstitution * constitution + e.parVitalite * vitalite)
                  end },
                -- Surcharge : un PNJ dont on fixe les PV a la main.
                { id = "pv_max_override", kind = "stat", label = "PV max impose" },
                { id = "corps",    kind = "body", label = "Silhouette",
                  note = "Repartition des points de vie sur les parties du corps." },
                -- Fatigue : 4 + 2xniveau + 1xesprit + 2xconstitution
                --            + 1x(total expertise Endurance) + 3x(pts secondaires)
                { id = "fatigue",  kind = "gauge", label = "Fatigue",
                  maxFormula = function(entity)
                      local e = LCM.Equilibrage.fatigue
                      local v = function(id) return tonumber(LCM.Entities.Get_Value(entity, id)) or 0 end
                      return math.floor(e.base + e.parNiveau * v("niveau") + e.parEsprit * v("esprit")
                          + e.parConstitution * v("constitution") + e.parEndurance * v("endurance")
                          + e.parSecondaire * v("sec_fatigue"))
                  end },
                { id = "armure",   kind = "gauge", label = "Armure ponctuelle", max = 1000, default = 0 },
            },
        },
        {
            label = "Identite",
            fields = {
                { id = "race",         kind = "text", label = "Race" },
                { id = "portrait",     kind = "text", label = "Portrait",
                  note = "Identifiant de l'artwork livre avec l'addon ; vide = celui du personnage." },
                { id = "morphologie",  kind = "text", label = "Morphologie imposee",
                  note = "Pour un PNJ sans race : prime sur celle de la race." },
                { id = "niveau", kind = "stat", label = "Niveau",
                  default = LCM.Equilibrage.creation.niveauDepart },
                { id = "age",   kind = "stat", label = "Age" },
                { id = "sexe",  kind = "text", label = "Sexe" },
                { id = "poids", kind = "stat", label = "Poids", note = "En kilogrammes." },
            },
        },
    },
})

-- Les points secondaires : un champ par pool, engendre depuis l'equilibrage.
-- Ajouter un pool se fait la-bas, pas ici.
local champsSecondaires = {}
for _, pool in ipairs(LCM.Equilibrage.secondaires) do
    champsSecondaires[#champsSecondaires + 1] = {
        id = pool.id, kind = "stat", label = pool.label, default = 0,
        note = string.format("Points secondaires investis (%d point%s l'unite).",
            pool.cout, pool.cout > 1 and "s" or ""),
    }
end

Schema.AddTab({
    id = "statistiques",
    label = "Statistiques",
    sections = {
        {
            label = "Statistiques",
            fields = {
                { id = "force",        kind = "stat", label = "Force",        default = 0 },
                { id = "mystique",     kind = "stat", label = "Mystique",     default = 0 },
                { id = "perception",   kind = "stat", label = "Perception",   default = 0 },
                { id = "adresse",      kind = "stat", label = "Adresse",      default = 0 },
                { id = "esprit",       kind = "stat", label = "Esprit",       default = 0 },
                { id = "constitution", kind = "stat", label = "Constitution", default = 0 },
            },
        },
        {
            label = "Points secondaires",
            fields = champsSecondaires,
        },
        {
            label = "Caracteristiques",
            fields = {
                -- Initiative : 2xniveau + 2xesprit + 2xperception
                { id = "initiative", kind = "roll", label = "Initiative", dice = { min = 0, max = 10 },
                  valueFormula = function(entity)
                      local e = LCM.Equilibrage.initiative
                      local v = function(id) return tonumber(LCM.Entities.Get_Value(entity, id)) or 0 end
                      return math.floor(e.parNiveau * v("niveau") + e.parEsprit * v("esprit")
                          + e.parPerception * v("perception"))
                  end },
                { id = "pa",         kind = "gauge", label = "Points d'action", max = 5 },
                { id = "depl_terrestre", kind = "stat", label = "Terrestre", default = 0 },
                { id = "depl_nage",      kind = "stat", label = "Nage",      default = 0 },
            },
        },
    },
})

Schema.AddTab({
    id = "traits",
    label = "Traits",
    sections = {
        {
            label = "Traits",
            fields = {
                -- La liste des traits portes : un champ a part entiere, pour
                -- que la fiche la dessine comme le reste, mais sa donnee vit
                -- dans `entity.traits` (voir Core/Traits.lua).
                { id = "traits_portes", kind = "traits", label = "Traits portés" },
                { id = "traits_notes", kind = "text", label = "Notes" },
            },
        },
    },
})
