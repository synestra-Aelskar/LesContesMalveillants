-- Objets : armes, equipements, accessoires.
--
-- Un objet est une DEFINITION, comme un trait : { id, label, description,
-- categorie, bonus, avantage }. Ses effets suivent les regles communes
-- (Core/Effets.lua). Il est cree en jeu par le MJ (atelier), puis exporte vers
-- Data/Genere/Objets.lua.
--
-- Cote entite, on ne stocke que ce qui est equipe : des identifiants, ranges
-- par categorie. Pas de place precise sur le corps : une categorie a un nombre
-- d'emplacements (Equilibrage.emplacements), et c'est tout.
--
--     entity.equipement = { arme = { "lame_de_givre" }, accessoire = { ... } }
--
-- Pas encore d'inventaire : on equipe un objet parce qu'il existe, pas parce
-- qu'on le possede. C'est pour ca que l'equipement est un geste de MJ.

local _, LCM = ...

local Objets = { list = {}, byId = {} }
LCM.Objets = Objets

-- Les categories, dans l'ordre d'affichage. Leur nombre d'emplacements vit
-- dans l'equilibrage, pas ici.
Objets.CATEGORIES = {
    { id = "arme",       label = "Arme" },
    { id = "equipement", label = "Équipement" },
    { id = "accessoire", label = "Accessoire" },
}
local CATEGORIE = {}
for _, categorie in ipairs(Objets.CATEGORIES) do CATEGORIE[categorie.id] = categorie end

local function Erreur(message)
    error("LCM/Objets : " .. tostring(message), 0)
end

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
function Objets.Emplacements(categorieId)
    local e = LCM.Equilibrage and LCM.Equilibrage.emplacements
    return tonumber(e and e[tostring(categorieId)]) or 0
end

function Objets.Categorie(id)
    return CATEGORIE[tostring(id or "")]
end

-- Verifie et met en forme sans enregistrer (voir Traits.Construire).
function Objets.Construire(definition)
    if type(definition) ~= "table" then Erreur("objet invalide") end
    local id = tostring(definition.id or "")
    if id == "" then Erreur("objet sans identifiant") end
    local categorie = tostring(definition.categorie or "")
    if not CATEGORIE[categorie] then
        Erreur(id .. " : categorie inconnue « " .. categorie .. " »")
    end
    local bonus, avantage = LCM.Effets.Lire(id, definition, Erreur)
    return {
        id = id,
        label = tostring(definition.label or id),
        description = tostring(definition.description or ""),
        categorie = categorie,
        bonus = bonus,
        avantage = avantage,
    }
end

function Objets.Add(definition)
    local objet = Objets.Construire(definition)
    if Objets.byId[objet.id] then Erreur("objet en double : " .. objet.id) end
    Objets.byId[objet.id] = objet
    Objets.list[#Objets.list + 1] = objet
    return objet
end

function Objets.Get(id)
    return Objets.byId[tostring(id or "")]
end

-- Brouillons supprimes en seance uniquement (voir Traits.Retirer).
function Objets.Retirer(id)
    id = tostring(id or "")
    if not Objets.byId[id] then return false end
    Objets.byId[id] = nil
    for index = #Objets.list, 1, -1 do
        if Objets.list[index].id == id then table.remove(Objets.list, index) end
    end
    return true
end

-- ===== Cote entite =========================================================

-- Lecture seule : ne CREE rien (voir Traits.lua, meme piege).
local VIDE = {}
local function Rangee(entity, categorieId)
    if type(entity) ~= "table" or type(entity.equipement) ~= "table" then return VIDE end
    local rangee = entity.equipement[categorieId]
    return type(rangee) == "table" and rangee or VIDE
end

-- Les identifiants equipes dans une categorie, TOUS, meme ceux dont l'objet
-- n'existe plus (la fenetre doit pouvoir les montrer). Une copie.
function Objets.Ids(entity, categorieId)
    local out = {}
    for _, id in ipairs(Rangee(entity, tostring(categorieId))) do out[#out + 1] = id end
    return out
end

function Objets.EstEquipe(entity, objetId)
    for _, categorie in ipairs(Objets.CATEGORIES) do
        for _, id in ipairs(Rangee(entity, categorie.id)) do
            if id == tostring(objetId) then return true end
        end
    end
    return false
end

-- Tous les objets equipes et connus, toutes categories.
function Objets.Equipes(entity)
    local out = {}
    for _, categorie in ipairs(Objets.CATEGORIES) do
        for _, id in ipairs(Rangee(entity, categorie.id)) do
            local objet = Objets.Get(id)
            if objet then out[#out + 1] = objet end
        end
    end
    return out
end

-- Equipe un objet. Renvoie true, ou false et la raison : un refus se dit.
function Objets.Equiper(entity, objetId)
    if type(entity) ~= "table" then return false, "aucune entite." end
    local objet = Objets.Get(objetId)
    if not objet then return false, "objet inconnu." end
    -- Le meme objet deux fois cumulerait ses bonus : refuse, en attendant
    -- l'inventaire (et la question des exemplaires).
    if Objets.EstEquipe(entity, objet.id) then
        return false, string.format("%s est deja equipe.", objet.label)
    end
    local places = Objets.Emplacements(objet.categorie)
    local occupees = #Rangee(entity, objet.categorie)
    if occupees >= places then
        return false, string.format("plus d'emplacement libre en %s (%d / %d).",
            CATEGORIE[objet.categorie].label:lower(), occupees, places)
    end
    entity.equipement = type(entity.equipement) == "table" and entity.equipement or {}
    entity.equipement[objet.categorie] = type(entity.equipement[objet.categorie]) == "table"
        and entity.equipement[objet.categorie] or {}
    table.insert(entity.equipement[objet.categorie], objet.id)
    return true
end

-- Retire un objet, qu'il existe encore ou non : on cherche l'identifiant dans
-- toutes les categories. Efface les tables devenues vides.
function Objets.Desequiper(entity, objetId)
    if type(entity) ~= "table" or type(entity.equipement) ~= "table" then return false end
    local cible = tostring(objetId)
    for categorieId, rangee in pairs(entity.equipement) do
        if type(rangee) == "table" then
            for index = #rangee, 1, -1 do
                if rangee[index] == cible then
                    table.remove(rangee, index)
                    if #rangee == 0 then entity.equipement[categorieId] = nil end
                    if next(entity.equipement) == nil then entity.equipement = nil end
                    return true
                end
            end
        end
    end
    return false
end

-- Les objets equipes sont une source d'effets, apres les traits.
LCM.Effets.Source("objet", Objets.Equipes, function() return Objets.list end)
