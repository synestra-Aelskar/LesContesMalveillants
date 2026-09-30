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
                -- Template : 2 + 1,5 x niveau + 3 x vitalite
                --   + constitution totale x (2 + constitution investie x 0,25).
                -- La constitution compte deux fois : elle multiplie, et sa part
                -- investie fait grandir le multiplicateur.
                { id = "pv_max", kind = "calc", label = "Points de vie (max)",
                  formula = function(entity)
                      local e = LCM.Equilibrage.pv
                      local v = function(id) return tonumber(LCM.Entities.Get_Value(entity, id)) or 0 end
                      local investie = v("constitution")
                      local totale = LCM.Formules.Primaire(entity, "constitution")
                      return math.floor(e.base + e.parNiveau * v("niveau") + e.parVitalite * v("sec_vitalite")
                          + totale * (e.constitution.base + investie * e.constitution.parConstitution))
                  end },
                -- Surcharge : un PNJ dont on fixe les PV a la main.
                { id = "pv_max_override", kind = "stat", label = "PV max impose" },
                { id = "corps",    kind = "body", label = "Silhouette",
                  note = "Repartition des points de vie sur les parties du corps." },
                -- Fatigue (template) : 15 + 2 x niveau + esprit + 2 x constitution
                --   + Endurance totale / 1 + 3 x (pts secondaires) + bonus portes.
                { id = "fatigue",  kind = "gauge", label = "Fatigue",
                  maxFormula = function(entity)
                      local e = LCM.Equilibrage.fatigue
                      local v = function(id) return tonumber(LCM.Entities.Get_Value(entity, id)) or 0 end
                      return math.floor(e.base + e.parNiveau * v("niveau") + e.parEsprit * v("esprit")
                          + e.parConstitution * v("constitution")
                          + LCM.Formules.Expertise(entity, "endurance") / e.diviseurEndurance
                          + e.parSecondaire * v("sec_fatigue") + LCM.Effets.Bonus(entity, "fatigue"))
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

-- Un mode de deplacement : base + points investis dans son expertise (et non
-- sa valeur totale : le template lit la repartition) + points secondaires.
function LCM.Deplacement(entity, mode, expertise)
    local e = LCM.Equilibrage.deplacement
    local v = function(id) return tonumber(LCM.Entities.Get_Value(entity, id)) or 0 end
    return math.floor((e[mode] or 0) + v(expertise) + e.parSecondaire * v("sec_deplacement")
        + LCM.Effets.Bonus(entity, "depl_" .. mode))
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
                -- Initiative (template) : pts secondaires + niveau / 2
                --   + esprit / 2 + perception / 2. Les bonus portes s'ajoutent
                --   au jet (Core/Roll.lua), pas ici.
                { id = "initiative", kind = "roll", label = "Initiative", dice = { min = 0, max = 10 },
                  valueFormula = function(entity)
                      local e = LCM.Equilibrage.initiative
                      local v = function(id) return tonumber(LCM.Entities.Get_Value(entity, id)) or 0 end
                      return math.floor(v("sec_initiative") + v("niveau") / e.diviseurNiveau
                          + LCM.Formules.Primaire(entity, "esprit") / e.diviseurEsprit
                          + LCM.Formules.Primaire(entity, "perception") / e.diviseurPerception)
                  end },
                -- Points d'action : 4 + pts secondaires + bonus portes.
                { id = "pa",         kind = "gauge", label = "Points d'action",
                  maxFormula = function(entity)
                      local v = tonumber(LCM.Entities.Get_Value(entity, "sec_pa")) or 0
                      return math.floor(LCM.Equilibrage.pa.base + v + LCM.Effets.Bonus(entity, "pa"))
                  end },
                -- Deplacement (template) : base + points investis dans l'expertise
                --   + pts secondaires x 1 + bonus portes (compris dans la formule :
                --   un objet peut viser ces champs, d'ou `recoitBonus`).
                { id = "depl_terrestre", kind = "calc", label = "Terrestre", recoitBonus = true,
                  formula = function(entity) return LCM.Deplacement(entity, "terrestre", "course") end },
                { id = "depl_nage",      kind = "calc", label = "Nage",      recoitBonus = true,
                  formula = function(entity) return LCM.Deplacement(entity, "nage", "nage") end },
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
