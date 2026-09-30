-- Metiers : les 31 metiers du template (compendium « Liste metiers ») et
-- l'experience qu'un personnage accumule dans chacun.
--
-- Un metier progresse par paliers (table « XP METIER » du template, dans
-- Equilibrage.metiers.paliers). La table est INCREMENTALE, comme dans
-- Necronicon (Profession.lua) : chaque palier demande son XP pour passer au
-- suivant ; le dernier ne se depasse pas. Le bonus de jet d'un metier est le
-- rang de son palier.
--
-- Cote entite, seulement l'XP gagnee : entity.metiers = { [id] = xp }. Un
-- metier a zero ne laisse rien dans la sauvegarde.

local _, LCM = ...

local Metiers = { list = {}, byId = {} }
LCM.Metiers = Metiers

local function Erreur(message) error("LCM/Metiers : " .. tostring(message), 0) end

function Metiers.Add(definition)
    local id = tostring(definition and definition.id or "")
    if id == "" then Erreur("metier sans identifiant") end
    if Metiers.byId[id] then Erreur("metier en double : " .. id) end
    local metier = {
        id = id,
        label = tostring(definition.label or id),
        description = tostring(definition.description or ""),
        icone = LCM.Icone(definition.icone),
    }
    Metiers.byId[id] = metier
    Metiers.list[#Metiers.list + 1] = metier
    return metier
end

function Metiers.Get(id) return Metiers.byId[tostring(id or "")] end

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
local function Paliers() return LCM.Equilibrage and LCM.Equilibrage.metiers and LCM.Equilibrage.metiers.paliers or {} end

function Metiers.XP(entity, id)
    local stock = type(entity) == "table" and entity.metiers
    return type(stock) == "table" and math.max(0, math.floor(tonumber(stock[tostring(id)]) or 0)) or 0
end

-- Le palier atteint : { rang, nom, xpDansPalier, xpPalier, xpRestante, max }.
function Metiers.Palier(entity, id)
    local paliers = Paliers()
    local reste = Metiers.XP(entity, id)
    local rang = 1
    while rang < #paliers do
        local cout = math.max(0, math.floor(tonumber(paliers[rang].xp) or 0))
        if cout > 0 and reste >= cout then
            reste = reste - cout
            rang = rang + 1
        else
            break
        end
    end
    local palier = paliers[rang] or { nom = "?", xp = 0 }
    local max = rang >= #paliers
    return {
        rang = rang, nom = palier.nom, couleur = palier.couleur,
        xpDansPalier = reste, xpPalier = palier.xp,
        xpRestante = max and 0 or math.max(0, palier.xp - reste), max = max,
    }
end

-- Bonus de jet d'un metier (Necronicon : GetProfessionRollBonus).
function Metiers.Bonus(entity, id)
    return Metiers.Palier(entity, id).rang
end

-- Ajoute (ou retire) de l'XP. Ne descend pas sous zero ; efface ce qui
-- revient a zero.
function Metiers.Gagner(entity, id, montant)
    if type(entity) ~= "table" or not Metiers.Get(id) then return false end
    local xp = math.max(0, Metiers.XP(entity, id) + math.floor(tonumber(montant) or 0))
    if xp == 0 then
        if type(entity.metiers) == "table" then
            entity.metiers[tostring(id)] = nil
            if next(entity.metiers) == nil then entity.metiers = nil end
        end
    else
        entity.metiers = type(entity.metiers) == "table" and entity.metiers or {}
        entity.metiers[tostring(id)] = xp
    end
    return true
end
