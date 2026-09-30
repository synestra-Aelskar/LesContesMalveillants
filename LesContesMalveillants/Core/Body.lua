-- Morphologies et parties du corps.
--
-- Une morphologie se declare par un EFFECTIF : combien de tetes, de bras, de
-- jambes, de queues, d'ailes. Le buste et les internes sont toujours la. Les
-- parties sont ensuite engendrees et placees automatiquement — c'est ce qui
-- permet douze pattes ou six bras sans dessiner une silhouette par espece.
--
-- Chaque categorie declare sa part du total, PAR partie : `jambe = 11` veut
-- dire « chaque jambe vaut 11 % ». La somme effectif x part doit faire 100.
--
-- Points de vie :
--   - le maximum GLOBAL vient d'une formule (Data/Equilibrage.lua) ;
--   - le maximum d'une PARTIE en est la part ;
--   - les PV courants d'une partie se saisissent ou se prennent en degats ;
--   - les PV courants globaux sont la SOMME des parties, jamais stockes.
--
-- On enregistre les degats subis, pas les points restants : si le maximum
-- change, les blessures en cours restent coherentes sans recalcul, et une
-- partie intacte ne laisse rien dans la sauvegarde.

local _, LCM = ...

local Morphologies = { list = {}, byId = {} }
local Races = { list = {}, byId = {} }
local Body = {}
LCM.Morphologies = Morphologies
LCM.Races = Races
LCM.Body = Body

local function Erreur(message)
    error("LCM/Body : " .. tostring(message), 0)
end

-- Categories connues. `unique` : toujours exactement une, non denombrable.
-- `row` : etage de la silhouette. `flank` : se place de part et d'autre.
local CATEGORIES = {
    { id = "tete",     label = "Tete",     row = 1, feminin = true },
    { id = "buste",    label = "Buste",    row = 2, unique = true },
    { id = "internes", label = "Internes", row = 2, unique = true, inner = true, vital = true },
    { id = "aile",     label = "Aile",     row = 2, flank = true, outer = true, feminin = true },
    { id = "bras",     label = "Bras",     row = 2, flank = true },
    { id = "queue",    label = "Queue",    row = 4, feminin = true },
    { id = "jambe",    label = "Jambe",    row = 3, feminin = true },
}
Body.CATEGORIES = CATEGORIES

local CATEGORY_BY_ID = {}
for _, category in ipairs(CATEGORIES) do CATEGORY_BY_ID[category.id] = category end

-- Les parties d'un meme etage sont reparties sur une rangee. Le rendu place
-- chacune a (slot - 0.5) / slots : deux jambes ou douze, la silhouette tient.
local function Layout(parts)
    local rows = {}
    for _, part in ipairs(parts) do
        if not part.inner then
            rows[part.row] = rows[part.row] or {}
            table.insert(rows[part.row], part)
        end
    end
    for _, row in pairs(rows) do
        -- Les membres lateraux se repartissent de part et d'autre du tronc :
        -- rang impair a gauche, rang pair a droite, les plus « exterieurs »
        -- (ailes) au bord. Sans ce partage, le buste finissait sur le cote.
        local gauche, centre, droite = {}, {}, {}
        for _, part in ipairs(row) do
            if part.flank then
                table.insert((part.index % 2 == 1) and gauche or droite, part)
            else
                table.insert(centre, part)
            end
        end
        table.sort(gauche, function(a, b)
            if a.outer ~= b.outer then return a.outer == true end
            return a.index > b.index
        end)
        table.sort(droite, function(a, b)
            if a.outer ~= b.outer then return b.outer == true end
            return a.index < b.index
        end)
        table.sort(centre, function(a, b) return a.index < b.index end)

        local ordre = {}
        for _, part in ipairs(gauche) do ordre[#ordre + 1] = part end
        for _, part in ipairs(centre) do ordre[#ordre + 1] = part end
        for _, part in ipairs(droite) do ordre[#ordre + 1] = part end
        for slot, part in ipairs(ordre) do
            part.slot = slot
            part.slots = #ordre
        end
    end
    -- Les internes se superposent au buste.
    for _, part in ipairs(parts) do
        if part.inner then
            for _, other in ipairs(parts) do
                if other.category == "buste" then
                    part.row, part.slot, part.slots = other.row, other.slot, other.slots
                end
            end
        end
    end
end

function Morphologies.Add(definition)
    if type(definition) ~= "table" then Erreur("morphologie invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("morphologie sans identifiant") end
    if Morphologies.byId[id] then Erreur("morphologie en double : " .. id) end

    local effectifs = type(definition.effectifs) == "table" and definition.effectifs or {}
    local parts = type(definition.parts) == "table" and definition.parts or {}

    for categoryId in pairs(effectifs) do
        if not CATEGORY_BY_ID[categoryId] then
            Erreur(id .. " : categorie inconnue « " .. tostring(categoryId) .. " »")
        end
    end

    local morphology = { id = id, label = tostring(definition.label or id), parts = {}, byId = {}, rows = 0 }
    local total = 0

    for _, category in ipairs(CATEGORIES) do
        local count = category.unique and 1 or math.max(0, math.floor(tonumber(effectifs[category.id]) or 0))
        if count > 0 then
            local share = tonumber(parts[category.id])
            if not share or share <= 0 then
                Erreur(id .. " : part manquante ou nulle pour « " .. category.id .. " »")
            end
            for index = 1, count do
                local partId = (count > 1) and (category.id .. "_" .. index) or category.id
                local label = category.label
                if count == 2 then
                    label = category.label .. (index == 1 and " gauche" or (category.feminin and " droite" or " droit"))
                elseif count > 2 then
                    label = category.label .. " " .. index
                end
                local part = {
                    id = partId,
                    label = label,
                    category = category.id,
                    index = index,
                    share = share,
                    row = category.row,
                    inner = category.inner == true,
                    vital = category.vital == true,
                    flank = category.flank == true,
                    outer = category.outer == true,
                }
                morphology.byId[partId] = part
                morphology.parts[#morphology.parts + 1] = part
                if category.row > morphology.rows then morphology.rows = category.row end
                total = total + share
            end
        end
    end

    if #morphology.parts == 0 then Erreur(id .. " : aucune partie") end
    -- Une somme qui derive est une faute de saisie, pas un arrondi a rattraper.
    if math.abs(total - 100) > 0.01 then
        Erreur(string.format("%s : les parts totalisent %.2f%% au lieu de 100", id, total))
    end

    Layout(morphology.parts)
    Morphologies.byId[id] = morphology
    Morphologies.list[#Morphologies.list + 1] = morphology
    return morphology
end

function Morphologies.Get(id)
    return Morphologies.byId[tostring(id or "")]
end

function Races.Add(definition)
    if type(definition) ~= "table" then Erreur("race invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("race sans identifiant") end
    if Races.byId[id] then Erreur("race en double : " .. id) end
    local morphologyId = tostring(definition.morphology or "")
    if not Morphologies.byId[morphologyId] then
        Erreur("race " .. id .. " : morphologie inconnue « " .. morphologyId .. " »")
    end
    local race = { id = id, label = tostring(definition.label or id), morphology = morphologyId }
    Races.byId[id] = race
    Races.list[#Races.list + 1] = race
    return race
end

function Races.Get(id)
    return Races.byId[tostring(id or "")]
end

-- ===== Cote entite =========================================================

-- Priorite : morphologie imposee sur l'entite, puis celle de sa race, puis le
-- defaut. La voie directe sert aux PNJ qui n'appartiennent a aucune race.
function Body.MorphologyOf(entity)
    local values = entity and entity.values or nil
    local direct = values and Morphologies.Get(values.morphologie)
    if direct then return direct end
    local race = Races.Get(values and values.race)
    if race then return Morphologies.Get(race.morphology) end
    return Morphologies.Get(LCM.DEFAULT_MORPHOLOGY or "humanoide")
end

-- Repartit `total` sur les parties. Le reste des arrondis va a la plus grande :
-- la somme des parties vaut TOUJOURS le total, sinon les joueurs comptent faux.
function Body.Distribute(morphology, total)
    local out = {}
    if not morphology then return out end
    total = math.max(0, math.floor(tonumber(total) or 0))
    local attribue, plusGrande = 0, nil
    for _, part in ipairs(morphology.parts) do
        local points = math.floor(total * part.share / 100)
        out[part.id] = points
        attribue = attribue + points
        if not plusGrande or part.share > morphology.byId[plusGrande].share then plusGrande = part.id end
    end
    if plusGrande and attribue < total then
        out[plusGrande] = out[plusGrande] + (total - attribue)
    end
    return out
end

-- Lecture seule : ne CREE rien (voir Traits.lua, meme piege).
local AUCUNE_BLESSURE = {}
local function Wounds(entity)
    if type(entity) ~= "table" or type(entity.body) ~= "table" then return AUCUNE_BLESSURE end
    return entity.body
end

local function WoundsForWrite(entity)
    if type(entity) ~= "table" then return nil end
    entity.body = type(entity.body) == "table" and entity.body or {}
    return entity.body
end

-- Une fois la derniere blessure soignee, la table disparait.
local function ForgetIfClean(entity)
    if type(entity) ~= "table" or type(entity.body) ~= "table" then return end
    if next(entity.body) == nil then entity.body = nil end
end

-- Maximum global : la formule d'equilibrage, sauf si l'entite le surcharge
-- (un PNJ dont on fixe les PV a la main).
function Body.MaxTotal(entity)
    local surcharge = tonumber(entity and entity.values and entity.values.pv_max_override)
    if surcharge then return math.max(0, math.floor(surcharge)) end
    return math.max(0, math.floor(tonumber(LCM.Entities.Get_Value(entity, "pv_max")) or 0))
end

function Body.State(entity, total)
    local morphology = Body.MorphologyOf(entity)
    if not morphology then return {}, nil end
    total = tonumber(total) or Body.MaxTotal(entity)
    local repartition = Body.Distribute(morphology, total)
    local wounds = Wounds(entity)
    local state = {}
    for _, part in ipairs(morphology.parts) do
        local maximum = repartition[part.id] or 0
        local wound = math.max(0, math.min(tonumber(wounds[part.id]) or 0, maximum))
        state[#state + 1] = {
            id = part.id, label = part.label, part = part,
            max = maximum, wound = wound, current = maximum - wound,
        }
    end
    return state, morphology
end

function Body.Damage(entity, partId, amount)
    local morphology = Body.MorphologyOf(entity)
    if not morphology or not morphology.byId[tostring(partId or "")] then return false end
    local maximum = Body.Distribute(morphology, Body.MaxTotal(entity))[partId] or 0
    local actuelle = tonumber(Wounds(entity)[partId]) or 0
    local wound = math.max(0, math.min(actuelle + (tonumber(amount) or 0), maximum))
    if wound == 0 and actuelle == 0 then return true end
    local wounds = WoundsForWrite(entity)
    if not wounds then return false end
    wounds[partId] = wound > 0 and wound or nil
    ForgetIfClean(entity)
    return true
end

function Body.Heal(entity, partId, amount)
    return Body.Damage(entity, partId, -(tonumber(amount) or 0))
end

-- Fixe directement les PV courants d'une partie (saisie a la main).
function Body.SetCurrent(entity, partId, current)
    local morphology = Body.MorphologyOf(entity)
    if not morphology or not morphology.byId[tostring(partId or "")] then return false end
    local maximum = Body.Distribute(morphology, Body.MaxTotal(entity))[partId] or 0
    local valeur = math.max(0, math.min(tonumber(current) or 0, maximum))
    local wound = maximum - valeur
    if wound == 0 and (tonumber(Wounds(entity)[partId]) or 0) == 0 then return true end
    local wounds = WoundsForWrite(entity)
    if not wounds then return false end
    wounds[partId] = wound > 0 and wound or nil
    ForgetIfClean(entity)
    return true
end

function Body.HealAll(entity)
    if type(entity) ~= "table" then return false end
    entity.body = nil
    return true
end

-- PV courants = somme des parties. Jamais stocke.
function Body.Totals(entity, total)
    local current, maximum = 0, 0
    for _, part in ipairs(Body.State(entity, total)) do
        current = current + part.current
        maximum = maximum + part.max
    end
    return current, maximum
end
