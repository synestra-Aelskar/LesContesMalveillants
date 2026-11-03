-- Crossings dans la base commune (31 octobre 2026).
--
-- Les continents, pays, regions, lieux, passages et themes de banniere de Crossings
-- (Core/Crossings.lua) ne vivaient que dans la sauvegarde du MJ qui les avait
-- crees (LCM_Crossings) : une sauvegarde perdue les emportait, et l'autre MJ
-- ne les connaissait que s'il les avait vus passer en seance. Ils partent
-- donc dans la base commune, comme les points poses (MJ/Poses.lua) : meme
-- file d'envoi (MJ/Brouillons.lua), famille « crossings », RESERVEE au MJ —
-- jamais livree dans l'addon joueur, ou l'on lirait les noms que Crossings
-- masque.
--
-- Une entree par chose : un continent, un pays, une region (avec ses lieux),
-- un passage, un theme. Un passage a part, et ses points plies en une chaine : un perimetre
-- peut compter 1500 sommets, et une region entiere ne tiendrait pas dans une
-- cellule du Sheet.
--
-- Les regles des poses, a l'identique :
--   * seul l'AUTEUR ecrit ses lignes ; deux MJ ne se contredisent pas ;
--   * la base est en RETARD sur la seance : au chargement, on n'y prend que ce
--     qui MANQUE ici, sans rien ecraser ;
--   * rien n'est efface sur la seule absence d'une ligne ; une suppression
--     part explicitement (masque), et seulement pour ce que j'avais note.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local FAMILLE = "crossings"
local GENRES = { continent = true, pays = true, region = true, passage = true, theme = true }

LCM.CrossingsBase = LCM.Registre({
    nom = "élément Crossings", prefixe = "CrossingsBase",
    construire = function(definition, element, Erreur)
        local genre = tostring(definition.genre or "")
        if not GENRES[genre] then Erreur(element.id .. " : genre inconnu (" .. genre .. ")") end
        if type(definition.donnees) ~= "table" then Erreur(element.id .. " : sans donnees") end
        element.genre = genre
        element.auteur = tostring(definition.auteur or "")
        element.version = math.max(0, math.floor(tonumber(definition.version) or 0))
        element.donnees = LCM.Copie(definition.donnees)
    end,
})
local Base = LCM.CrossingsBase

local function ZG() return LCM.Crossings end
local function Moi() return UnitName and UnitName("player") or "" end

-- ===== Points plies =========================================================
-- « x,y[,nom][~soudure];… ». C'est le format du reseau de Crossings, et on le
-- lui EMPRUNTE plutot que d'en tenir une seconde ecriture : la copie qui
-- vivait ici ignorait la soudure des sommets, donc une frontiere posee en
-- seance ne serait jamais entree dans la base commune.

local function Plier(points)
    local zg = ZG()
    if not (zg and zg.PackPoints) then return "" end
    return zg.PackPoints(points)
end

local function Deplier(texte)
    local zg = ZG()
    if not (zg and zg.UnpackPoints) then return {} end
    return zg.UnpackPoints(texte)
end
Base.Plier, Base.Deplier = Plier, Deplier

-- ===== Ce que j'ai cree, en entrees =========================================

local function Entrees()
    local zg = ZG()
    if not zg then return {} end
    local db, moi, out = zg:GetDB(), Moi(), {}
    local function Ajouter(genre, id, label, donnees)
        out[id] = { id = id, genre = genre, label = tostring(label or id), auteur = moi, donnees = donnees }
    end
    for id, continent in pairs(db.continents or {}) do
        if continent.creator == moi then
            Ajouter("continent", id, continent.name, LCM.Copie(continent))
        end
    end
    for id, pays in pairs(db.countries or {}) do
        if pays.creator == moi then Ajouter("pays", id, pays.name, LCM.Copie(pays)) end
    end
    for id, zone in pairs(db.zones or {}) do
        if zone.creator == moi then
            local copie = LCM.Copie(zone)
            local passages = copie.subZones or {}
            copie.subZones = nil
            Ajouter("region", id, zone.name, copie)
            for sid, sub in pairs(passages) do
                local donnees = LCM.Copie(sub)
                donnees.points = Plier(sub.points)
                donnees.zoneId = id
                Ajouter("passage", sid, (zone.name or "") .. " / " .. tostring(sub.name or sid), donnees)
            end
        end
    end
    for id, theme in pairs(db.themes or {}) do
        if theme.creator == moi then Ajouter("theme", id, theme.name, LCM.Copie(theme)) end
    end
    return out
end

-- Une empreinte stable (les cles triees) : `pairs` change d'ordre d'un
-- chargement a l'autre, et une entree identique ne doit pas repartir.
local function Empreinte(v)
    local t = type(v)
    if t ~= "table" then return t:sub(1, 1) .. tostring(v) end
    local cles = {}
    for k in pairs(v) do cles[#cles + 1] = k end
    table.sort(cles, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, k in ipairs(cles) do out[#out + 1] = tostring(k) .. "=" .. Empreinte(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

local function Notes()
    _G.LCM_MJ_DB = type(_G.LCM_MJ_DB) == "table" and _G.LCM_MJ_DB or {}
    local db = _G.LCM_MJ_DB
    db.crossingsNotes = type(db.crossingsNotes) == "table" and db.crossingsNotes or {}
    return db.crossingsNotes
end

-- Ce qui a change depuis la derniere fois part dans la file d'envoi ; ce que
-- j'avais note et qui n'existe plus est supprime de la base. Rend le nombre
-- d'entrees ecrites et supprimees.
function Base.Noter()
    if not (LCM.Brouillons and LCM.IsMaster and LCM.IsMaster()) then return 0, 0 end
    local notes, entrees = Notes(), Entrees()
    local ecrites, supprimees = 0, 0
    for id, e in pairs(entrees) do
        local empreinte = Empreinte(e.donnees) .. "|" .. e.genre .. "|" .. e.label
        if notes[id] ~= empreinte then
            e.version = (time and time()) or 0
            LCM.Brouillons.Set(FAMILLE, e)
            LCM.Brouillons.Masques(FAMILLE)[id] = nil
            LCM.Publier(Base, e)
            notes[id] = empreinte
            ecrites = ecrites + 1
        end
    end
    for id in pairs(notes) do
        if not entrees[id] then
            LCM.Brouillons.Remove(FAMILLE, id)
            LCM.Brouillons.Masques(FAMILLE)[id] = true
            Base.Retirer(id)
            notes[id] = nil
            supprimees = supprimees + 1
        end
    end
    return ecrites, supprimees
end

-- ===== Ce que la base rend au chargement =====================================

-- N'ajoute que ce qui MANQUE ici, pour moi comme pour l'autre MJ : la seance
-- est en avance sur la base. Rend le nombre d'elements rendus.
function Base.Rendre()
    local zg = ZG()
    if not zg then return 0 end
    local db, rendus = zg:GetDB(), 0
    db.countries, db.zones, db.themes = db.countries or {}, db.zones or {}, db.themes or {}
    db.continents = db.continents or {}
    -- Les regions d'abord : un passage se range dans la sienne. Et le
    -- continent avant le pays, pour la meme raison.
    for _, genre in ipairs({ "continent", "pays", "region", "theme", "passage" }) do
        for _, e in ipairs(Base.list) do
            if e.genre == genre then
                local d = LCM.Copie(e.donnees)
                if genre == "continent" and not db.continents[e.id] then
                    db.continents[e.id] = d
                    rendus = rendus + 1
                elseif genre == "pays" and not db.countries[e.id] then
                    db.countries[e.id] = d
                    rendus = rendus + 1
                elseif genre == "region" and not db.zones[e.id] then
                    d.subZones, d.places = {}, d.places or {}
                    db.zones[e.id] = d
                    rendus = rendus + 1
                elseif genre == "theme" and not db.themes[e.id] then
                    db.themes[e.id] = d
                    rendus = rendus + 1
                elseif genre == "passage" then
                    local zone = db.zones[d.zoneId or ""]
                    if zone and not zone.subZones[e.id] then
                        d.points = Deplier(d.points)
                        d.zoneId = zone.id
                        zone.subZones[e.id] = d
                        rendus = rendus + 1
                    end
                end
            end
        end
    end
    return rendus
end

-- ===== Branchements ==========================================================

-- Chaque changement de Crossings passe par ScheduleBroadcast (l'auteur
-- diffuse son etat) : c'est donc la qu'on note aussi pour la base, une fois
-- les changements retombes — un trace de perimetre en appelle un par sommet.
local enAttente = false
local function Programmer()
    if enAttente then return end
    enAttente = true
    local zg = ZG()
    if zg and zg.Apres then
        zg.Apres(2, function() enAttente = false; Base.Noter() end)
    else
        enAttente = false
        Base.Noter()
    end
end
Base.Programmer = Programmer

LCM.WhenReady(function()
    local zg = ZG()
    if not zg then return end
    local rendus = Base.Rendre()
    if rendus > 0 then
        LCM.Info(string.format("Crossings : %d élément(s) rendu(s) par la base commune.", rendus))
    end
    local diffuser = zg.ScheduleBroadcast
    zg.ScheduleBroadcast = function(self, ...)
        local r = diffuser(self, ...)
        Programmer()
        return r
    end
    -- Ce que j'ai cree avant ce module (ou depuis le dernier envoi) part tout
    -- de suite : la premiere fois, tout.
    Base.Noter()
end)
