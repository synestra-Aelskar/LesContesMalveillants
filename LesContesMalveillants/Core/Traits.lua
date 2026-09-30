-- Traits.
--
-- Un trait apporte deux choses, et deux seulement :
--   * des bonus a des statistiques — jamais aux six primaires (force,
--     mystique, perception, adresse, esprit, constitution) ;
--   * un « avantage » sur une ou plusieurs expertises : le jet est lance deux
--     fois et l'on garde le meilleur.
--
-- Exemple : « Escalade de la jungle » donne +3 en escalade, et permet de
-- relancer un jet d'escalade quand la situation s'y prete. Le joueur coche la
-- case a cote de son jet : c'est lui qui juge si le trait s'applique.
--
-- Les traits d'une entite sont une LISTE D'IDENTIFIANTS. Le contenu du trait
-- vit dans le code, jamais dans la sauvegarde.

local _, LCM = ...

local Traits = { list = {}, byId = {} }
LCM.Traits = Traits

-- Les six primaires sont hors de portee des traits : c'est une regle de jeu,
-- donc elle est verifiee par le code et pas seulement ecrite quelque part.
Traits.PRIMAIRES = {
    force = true, mystique = true, perception = true,
    adresse = true, esprit = true, constitution = true,
}

Traits.COUT_MAX = 4

local function Erreur(message)
    error("LCM/Traits : " .. tostring(message), 0)
end

-- Verifie une definition et la met en forme, SANS l'enregistrer. C'est la seule
-- porte des regles d'un trait : l'atelier du MJ s'en sert pour refuser une
-- saisie avant qu'elle n'atteigne la sauvegarde, avec le meme message que le
-- chargement d'un fichier genere.
function Traits.Construire(definition)
    if type(definition) ~= "table" then Erreur("trait invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("trait sans identifiant") end

    -- Un trait coute de 1 a 4 points ; c'est la regle, donc le code la tient.
    local cout = tonumber(definition.cout) or 1
    if cout ~= math.floor(cout) or cout < 1 or cout > Traits.COUT_MAX then
        Erreur(id .. " : cout invalide (" .. tostring(definition.cout) .. "), attendu 1 a " .. Traits.COUT_MAX)
    end

    local trait = {
        id = id,
        label = tostring(definition.label or id),
        description = tostring(definition.description or ""),
        cout = cout,
        bonus = {},
        avantage = {},
    }

    for fieldId, value in pairs(definition.bonus or {}) do
        local cible = tostring(fieldId)
        if Traits.PRIMAIRES[cible] then
            Erreur(id .. " : un trait ne peut pas modifier une statistique primaire (" .. cible .. ")")
        end
        local montant = tonumber(value)
        if not montant or montant == 0 then
            Erreur(id .. " : bonus nul ou illisible sur " .. cible)
        end
        trait.bonus[cible] = montant
    end

    for _, fieldId in ipairs(definition.avantage or {}) do
        trait.avantage[tostring(fieldId)] = true
    end

    return trait
end

function Traits.Add(definition)
    local trait = Traits.Construire(definition)
    if Traits.byId[trait.id] then Erreur("trait en double : " .. trait.id) end
    Traits.byId[trait.id] = trait
    Traits.list[#Traits.list + 1] = trait
    return trait
end

function Traits.Get(id)
    return Traits.byId[tostring(id or "")]
end

-- Ne sert qu'aux brouillons que le MJ supprime en seance : le contenu publie se
-- recharge depuis son fichier, le retirer ici ne l'effacerait de rien. Les
-- entites qui portaient ce trait gardent son identifiant ; il redevient visible
-- si le trait revient.
function Traits.Retirer(id)
    id = tostring(id or "")
    if not Traits.byId[id] then return false end
    Traits.byId[id] = nil
    for index = #Traits.list, 1, -1 do
        if Traits.list[index].id == id then table.remove(Traits.list, index) end
    end
    return true
end

-- Les champs vises n'existent pas forcement au moment ou le trait est declare
-- (les fichiers se chargent dans l'ordre du .toc). On verifie donc une fois, a
-- la connexion, quand toute la feuille est connue.
LCM.WhenReady(function()
    for _, trait in ipairs(Traits.list) do
        for fieldId in pairs(trait.bonus) do
            if not LCM.Schema.Field(fieldId) then
                LCM.Erreur(string.format("trait « %s » : bonus vers un champ inconnu (%s)", trait.label, fieldId))
            end
        end
        for fieldId in pairs(trait.avantage) do
            local field = LCM.Schema.Field(fieldId)
            if not field then
                LCM.Erreur(string.format("trait « %s » : avantage sur un champ inconnu (%s)", trait.label, fieldId))
            elseif field.kind ~= "roll" then
                LCM.Erreur(string.format("trait « %s » : avantage sur « %s », qui ne se lance pas", trait.label, fieldId))
            end
        end
    end
end)

-- ===== Cote entite =========================================================

-- Lecture seule : ne CREE rien. Un accesseur qui fabrique la table au passage
-- finit par semer des tables vides dans la sauvegarde.
local VIDE = {}
local function OwnedIds(entity)
    if type(entity) ~= "table" or type(entity.traits) ~= "table" then return VIDE end
    return entity.traits
end

-- Version qui ecrit : appelee uniquement quand on ajoute vraiment un trait.
local function OwnedIdsForWrite(entity)
    if type(entity) ~= "table" then return nil end
    entity.traits = type(entity.traits) == "table" and entity.traits or {}
    return entity.traits
end

function Traits.Owned(entity)
    local out = {}
    for _, id in ipairs(OwnedIds(entity)) do
        local trait = Traits.Get(id)
        if trait then out[#out + 1] = trait end
    end
    return out
end

-- Les identifiants portes, TOUS, y compris ceux dont le trait n'existe plus
-- (brouillon supprime, contenu pas encore publie chez ce joueur). `Owned` les
-- tait ; la fiche doit pouvoir les montrer. Une copie : la modifier ne touche
-- pas l'entite.
function Traits.Ids(entity)
    local out = {}
    for _, id in ipairs(OwnedIds(entity)) do out[#out + 1] = id end
    return out
end

-- Somme des couts des traits portes et connus.
function Traits.CoutTotal(entity)
    local total = 0
    for _, trait in ipairs(Traits.Owned(entity)) do total = total + trait.cout end
    return total
end

function Traits.Has(entity, traitId)
    for _, id in ipairs(OwnedIds(entity)) do
        if id == tostring(traitId) then return true end
    end
    return false
end

function Traits.Grant(entity, traitId)
    local trait = Traits.Get(traitId)
    if not trait or type(entity) ~= "table" then return false end
    if Traits.Has(entity, trait.id) then return false end
    local owned = OwnedIdsForWrite(entity)
    if not owned then return false end
    owned[#owned + 1] = trait.id
    return true
end

function Traits.Revoke(entity, traitId)
    local owned = OwnedIds(entity)
    for index = #owned, 1, -1 do
        if owned[index] == tostring(traitId) then
            table.remove(owned, index)
            if #owned == 0 then entity.traits = nil end
            return true
        end
    end
    return false
end

-- Somme des bonus de tous les traits portes, pour un champ donne.
function Traits.Bonus(entity, fieldId)
    local total = 0
    for _, trait in ipairs(Traits.Owned(entity)) do
        total = total + (trait.bonus[tostring(fieldId)] or 0)
    end
    return total
end

-- Le trait qui accorde l'avantage sur ce jet, s'il y en a un.
function Traits.Advantage(entity, fieldId)
    for _, trait in ipairs(Traits.Owned(entity)) do
        if trait.avantage[tostring(fieldId)] then return trait end
    end
    return nil
end
