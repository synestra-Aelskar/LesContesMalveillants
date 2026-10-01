-- Les sorts propres a un personnage.
--
-- C'est la PREMIERE chose qu'on ecrit en sauvegarde qui ne soit pas une valeur
-- de fiche : un sort appris est du contenu, et il appartient a celui qui l'a.
-- Decision de l'utilisateur (1er octobre 2026), prise en connaissance de cause.
--
-- Consequences, et elles comptent :
--   * ce contenu-la n'est PAS versionne, il vit chez le joueur. Il faut donc
--     qu'il puisse voyager : d'ou le lien de chat (Core/Lien.lua) et le partage
--     (Core/Reseau.lua) ;
--   * il faut le valider a l'entree, parce qu'il arrivera aussi du reseau,
--     ou rien ne garantit ce qu'on recoit.
--
-- Ils remplissent le grimoire personnel (Data/Grimoires.lua).

local _, LCM = ...

local Sorts = {}
LCM.Sorts = Sorts

local VIDE = {}

-- Bornes volontairement serrees : un sort doit tenir dans un partage sans
-- devenir un roman, et un texte sans limite finit toujours par en etre un.
Sorts.NOM_MAX = 60
Sorts.TEXTE_MAX = 400
Sorts.CHAMP_MAX = 60

local function Texte(v, maximum)
    v = tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if maximum and #v > maximum then v = v:sub(1, maximum) end
    return v
end

-- Lecture : ne cree rien.
local function Liste(entity)
    if type(entity) ~= "table" or type(entity.sorts) ~= "table" then return VIDE end
    return entity.sorts
end

local function ListePourEcrire(entity)
    if type(entity) ~= "table" then return nil end
    entity.sorts = type(entity.sorts) == "table" and entity.sorts or {}
    return entity.sorts
end

function Sorts.Liste(entity) return Liste(entity) end

function Sorts.Compte(entity) return #Liste(entity) end

function Sorts.Get(entity, id)
    id = tostring(id or "")
    for _, sort in ipairs(Liste(entity)) do
        if sort.id == id then return sort end
    end
    return nil
end

-- Un identifiant stable, derive du nom : c'est lui qui voyage dans un lien de
-- chat, donc il doit rester lisible et ne pas changer sous les pieds.
local function IdentifiantLibre(entity, nom)
    local base = Texte(nom):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if base == "" then base = "sort" end
    if not Sorts.Get(entity, base) then return base end
    local index = 2
    while Sorts.Get(entity, base .. "_" .. index) do index = index + 1 end
    return base .. "_" .. index
end
Sorts.IdentifiantLibre = IdentifiantLibre

-- Met une definition en forme, ou dit pourquoi elle est refusee. Appelee aussi
-- bien par l'editeur que par ce qui arrive du reseau : c'est le seul endroit
-- ou l'on decide qu'un sort est acceptable.
function Sorts.Valider(definition)
    if type(definition) ~= "table" then return nil, "sort illisible." end
    local nom = Texte(definition.label, Sorts.NOM_MAX)
    if nom == "" then return nil, "il faut un nom." end

    local sort = {
        label = nom,
        icone = Texte(definition.icone, 200),
        description = Texte(definition.description, Sorts.TEXTE_MAX),
        champ1 = Texte(definition.champ1, Sorts.CHAMP_MAX),
        champ2 = Texte(definition.champ2, Sorts.CHAMP_MAX),
    }
    if sort.icone == "" then sort.icone = nil end
    if sort.description == "" then sort.description = nil end
    if sort.champ1 == "" then sort.champ1 = nil end
    if sort.champ2 == "" then sort.champ2 = nil end

    local jet = definition.jet
    if jet ~= nil then
        if type(jet) ~= "table" then return nil, "jet illisible." end
        local minimum = math.floor(tonumber(jet.min) or 0)
        local maximum = math.floor(tonumber(jet.max) or 0)
        if maximum < minimum then minimum, maximum = maximum, minimum end
        -- Un jet de zero a zero n'est pas un jet : on l'efface plutot que de
        -- poser un bouton qui rendra toujours le meme chiffre.
        if not (minimum == 0 and maximum == 0) then
            sort.jet = { min = minimum, max = maximum }
        end
    end
    return sort
end

function Sorts.Ajouter(entity, definition)
    local sort, raison = Sorts.Valider(definition)
    if not sort then return nil, raison end
    local liste = ListePourEcrire(entity)
    if not liste then return nil, "aucun personnage." end
    -- Deux sorts peuvent porter le meme nom : le second prend un identifiant
    -- libre, comme les homonymes de personnages. En revanche, un identifiant
    -- IMPOSE doit etre libre — c'est le cas quand on adopte un sort partage, et
    -- la, ecraser le sien en silence serait une perte.
    local impose = Texte(definition.id)
    if impose ~= "" then
        if Sorts.Get(entity, impose) then return nil, "il a deja ce sort." end
        sort.id = impose
    else
        sort.id = IdentifiantLibre(entity, sort.label)
    end
    liste[#liste + 1] = sort
    return sort
end

function Sorts.Modifier(entity, id, definition)
    local ancien = Sorts.Get(entity, id)
    if not ancien then return nil, "sort inconnu." end
    local sort, raison = Sorts.Valider(definition)
    if not sort then return nil, raison end
    -- L'identifiant ne bouge pas : des liens de chat le citent peut-etre deja.
    sort.id = ancien.id
    for index, porte in ipairs(Liste(entity)) do
        if porte.id == ancien.id then entity.sorts[index] = sort end
    end
    return sort
end

function Sorts.Supprimer(entity, id)
    id = tostring(id or "")
    local liste = Liste(entity)
    for index = #liste, 1, -1 do
        if liste[index].id == id then
            table.remove(liste, index)
            -- Plus rien : on efface la table, la sauvegarde ne garde pas de
            -- liste vide.
            if #liste == 0 and type(entity) == "table" then entity.sorts = nil end
            return true
        end
    end
    return false
end
