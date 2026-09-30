-- Entites : joueurs et PNJ, meme modele.
--
-- Une entite ne stocke QUE ses valeurs :
--     { id, name, icon, kind, values = { [champ] = valeur } }
-- Pas d'onglets, pas de sections, pas de formules — tout cela vit dans le
-- schema. C'est ce qui fait qu'un PNJ coute quelques kilo-octets au lieu des
-- centaines que coutait une copie complete de template.
--
-- Le personnage du joueur est une entite comme une autre, avec pour identifiant
-- son « Nom-Royaume ».

local _, LCM = ...

local Entities = {}
LCM.Entities = Entities

local function Store()
    LCM.EnsureDatabase()
    LCM.db.entities = type(LCM.db.entities) == "table" and LCM.db.entities or {}
    return LCM.db.entities
end

local function Normalise(entity, id)
    entity.id = tostring(entity.id or id or "")
    entity.name = tostring(entity.name or entity.id)
    entity.kind = (entity.kind == "npc") and "npc" or "player"
    entity.values = type(entity.values) == "table" and entity.values or {}
    return entity
end

function Entities.Get(id)
    id = tostring(id or "")
    if id == "" then return nil end
    local entity = Store()[id]
    return entity and Normalise(entity, id) or nil
end

function Entities.Create(id, name, kind, icon)
    id = tostring(id or "")
    if id == "" then return nil, "identifiant vide" end
    local store = Store()
    if store[id] then return Normalise(store[id], id) end
    store[id] = Normalise({ id = id, name = name or id, kind = kind, icon = icon }, id)
    return store[id]
end

function Entities.Delete(id)
    local store = Store()
    id = tostring(id or "")
    if not store[id] then return false end
    store[id] = nil
    return true
end

function Entities.All()
    local out = {}
    for id, entity in pairs(Store()) do
        out[#out + 1] = Normalise(entity, id)
    end
    table.sort(out, function(a, b) return tostring(a.name):lower() < tostring(b.name):lower() end)
    return out
end

-- L'entite que l'on joue : le personnage choisi dans la selection ; a defaut,
-- celui qui porte le nom de l'avatar WoW connecte, cree au besoin.
function Entities.Self()
    local actif = LCM.Personnages and LCM.Personnages.Actif and LCM.Personnages.Actif()
    if actif then return actif end
    local id = LCM.PlayerId()
    if id == "" then return nil end
    return Entities.Get(id) or Entities.Create(id, UnitName and UnitName("player") or id, "player")
end

-- ===== Valeurs =============================================================
-- Lecture et ecriture passent TOUJOURS par ici : un champ inconnu du schema est
-- refuse, ce qui interdit les valeurs orphelines dans la sauvegarde.

function Entities.Get_Value(entity, fieldId)
    local field = LCM.Schema.Field(fieldId)
    if not field or type(entity) ~= "table" then return nil end
    local stored = entity.values[field.id]
    if field.kind == "calc" and type(field.formula) == "function" then
        local ok, value = pcall(field.formula, entity)
        return ok and value or nil
    end
    -- Un jet dont la valeur est calculee (Initiative) : la formule fait foi,
    -- sauf si l'entite porte une valeur explicite.
    if type(field.valueFormula) == "function" and stored == nil then
        local ok, value = pcall(field.valueFormula, entity)
        if ok then return value end
    end
    if stored == nil then return field.default end
    return stored
end

function Entities.Set_Value(entity, fieldId, value)
    local field = LCM.Schema.Field(fieldId)
    if not field then
        LCM.Debug("champ inconnu refuse : " .. tostring(fieldId))
        return false
    end
    if field.kind == "calc" then return false end
    -- Les traits portes passent par LCM.Traits.Grant / Revoke : une valeur
    -- ecrite ici serait une seconde source de verite, ignoree de tous.
    if field.kind == "traits" then return false end
    if type(entity) ~= "table" then return false end
    -- Une valeur egale au defaut n'est pas ecrite : la sauvegarde ne garde que
    -- ce qui s'ecarte de la feuille vierge.
    if value == nil or value == field.default then
        entity.values[field.id] = nil
    else
        entity.values[field.id] = value
    end
    return true
end

-- Jauges : { current, max }. Le maximum vient du schema sauf si l'entite l'a
-- surcharge (un PNJ costaud, un buff...).
function Entities.Gauge(entity, fieldId)
    local field = LCM.Schema.Field(fieldId)
    if not field or field.kind ~= "gauge" then return nil end
    local stored = entity and entity.values[field.id]
    local maximum = (type(stored) == "table" and tonumber(stored.max)) or nil
    if not maximum and type(field.maxFormula) == "function" then
        local ok, value = pcall(field.maxFormula, entity)
        if ok then maximum = math.floor(tonumber(value) or 0) end
    end
    maximum = maximum or tonumber(field.max) or 0
    -- Sans valeur retenue, une jauge part de son defaut s'il existe (l'armure
    -- ponctuelle part de zero), sinon pleine.
    local depart = tonumber(field.default) or maximum
    local current = (type(stored) == "table" and tonumber(stored.current)) or depart
    if current > maximum then current = maximum end
    if current < 0 then current = 0 end
    return { current = current, max = maximum }
end

function Entities.SetGauge(entity, fieldId, current, maximum)
    local field = LCM.Schema.Field(fieldId)
    if not field or field.kind ~= "gauge" or type(entity) ~= "table" then return false end
    local gauge = Entities.Gauge(entity, fieldId)
    local newMax = tonumber(maximum) or gauge.max
    local newCurrent = math.max(0, math.min(tonumber(current) or gauge.current, newMax))
    local depart = tonumber(field.default) or newMax
    if newCurrent == depart and newMax == (tonumber(field.max) or 0) then
        entity.values[field.id] = nil
    else
        entity.values[field.id] = { current = newCurrent, max = newMax }
    end
    return true
end
