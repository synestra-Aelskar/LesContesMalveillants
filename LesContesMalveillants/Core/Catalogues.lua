-- Catalogues : ce qu'une entite porte dans des emplacements.
--
-- Dans le compendium du template, objets, etats, maladies, apprentissages ont
-- tous la MEME forme : une icone, une description, des bonus et des avantages
-- sur les statistiques de la fiche. Et une fiche les range dans des conteneurs
-- a nombre d'emplacements fixe (1 arme, 30 etats, 60 apprentissages...).
--
-- Un catalogue, c'est ce modele une fois pour toutes :
--   * un REGISTRE de definitions (Construire / Add / Get / Retirer), cree en
--     jeu par le MJ puis exporte, comme les traits ;
--   * des CATEGORIES, chacune avec sa capacite (lue dans l'equilibrage) ;
--   * cote entite, des LISTES D'IDENTIFIANTS par categorie, rien d'autre ;
--   * une SOURCE D'EFFETS (Core/Effets.lua) : ce qu'on porte compte partout.
--
--   local Etats = LCM.Catalogue({
--       nom = "etat", cleEntite = "etats", primaires = true,
--       categories = { { id = "etat", label = "État", capacite = "etat" }, ... },
--   })

local _, LCM = ...

-- LCM.Icone et les champs communs (onglet General du template) vivent dans
-- Core/Contenus.lua : un catalogue n'est qu'une famille du compendium parmi
-- d'autres.

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
local function Capacites()
    return LCM.Equilibrage and LCM.Equilibrage.conteneurs or {}
end

function LCM.Catalogue(def)
    local C = { list = {}, byId = {}, CATEGORIES = def.categories, nom = def.nom }
    local CATEGORIE = {}
    for _, categorie in ipairs(def.categories) do CATEGORIE[categorie.id] = categorie end
    local prefixe = "LCM/" .. (def.prefixe or def.nom) .. " : "

    local function Erreur(message) error(prefixe .. tostring(message), 0) end

    function C.Categorie(id) return CATEGORIE[tostring(id or "")] end

    function C.Capacite(categorieId)
        local categorie = CATEGORIE[tostring(categorieId or "")]
        if not categorie then return 0 end
        return tonumber(Capacites()[categorie.capacite or categorie.id]) or 0
    end

    -- Verifie et met en forme sans enregistrer. Une seule categorie : elle
    -- est implicite.
    function C.Construire(definition)
        if type(definition) ~= "table" then Erreur(def.nom .. " invalide") end
        local id = tostring(definition.id or "")
        if id == "" then Erreur(def.nom .. " sans identifiant") end
        local categorie = tostring(definition.categorie or "")
        if categorie == "" and #def.categories == 1 then categorie = def.categories[1].id end
        if not CATEGORIE[categorie] then
            Erreur(id .. " : categorie inconnue « " .. categorie .. " »")
        end
        local bonus, avantage = LCM.Effets.Lire(id, definition, Erreur, def.primaires == true)
        local element = {
            id = id,
            label = tostring(definition.label or id),
            categorie = categorie,
            bonus = bonus,
            avantage = avantage,
        }
        LCM.ChampsCommuns(definition, element, Erreur)
        -- Champs propres a une famille (les places d'un sac) : des entiers,
        -- bornes, avec un defaut, ou des cases a cocher (sac du MJ). Un nombre
        -- illisible est refuse, pas devine. `categories` limite un champ a
        -- certaines categories (l'armure d'une piece, pas d'une arme) ; un
        -- defaut peut etre une fonction, pour le lire dans l'equilibrage,
        -- qui n'existe pas encore quand Core se charge.
        for _, champ in ipairs(def.champs or {}) do
            local brut = definition[champ.cle]
            -- Une case laissee vide dans l'atelier : le defaut, pas un refus.
            if brut == "" then brut = nil end
            local defaut = champ.defaut
            if type(defaut) == "function" then defaut = defaut() end
            if champ.categories and not champ.categories[categorie] then
                -- Hors de ses categories, le champ n'existe pas.
            elseif champ.genre == "case" then
                element[champ.cle] = brut == true or brut == 1 or brut == "1" or nil
            elseif champ.genre == "choix" then
                -- Un choix parmi des valeurs nommees : la nature d'un sac, par
                -- exemple. Hors de la liste, c'est une faute de saisie, pas une
                -- valeur a garder.
                local valeur = brut == nil and defaut or tostring(brut)
                if not (champ.valeurs and champ.valeurs[valeur]) then
                    Erreur(string.format("%s : %s invalide (%s)", id, champ.libelle or champ.cle, tostring(brut)))
                end
                element[champ.cle] = valeur
            else
                local valeur = brut == nil and defaut or tonumber(brut)
                if valeur == nil or valeur ~= math.floor(valeur) or valeur < (champ.min or 0) then
                    Erreur(string.format("%s : %s invalide (%s)", id, champ.libelle or champ.cle, tostring(brut)))
                end
                element[champ.cle] = valeur
            end
        end
        return element
    end

    function C.Add(definition)
        local element = C.Construire(definition)
        if C.byId[element.id] then Erreur(def.nom .. " en double : " .. element.id) end
        C.byId[element.id] = element
        C.list[#C.list + 1] = element
        return element
    end

    function C.Get(id) return C.byId[tostring(id or "")] end

    -- Brouillons supprimes en seance uniquement (voir Traits.Retirer).
    function C.Retirer(id)
        id = tostring(id or "")
        if not C.byId[id] then return false end
        C.byId[id] = nil
        for index = #C.list, 1, -1 do
            if C.list[index].id == id then table.remove(C.list, index) end
        end
        return true
    end

    -- ===== Cote entite =====================================================

    -- Lecture seule : ne CREE rien (voir Traits.lua, meme piege).
    local VIDE = {}
    local function Rangee(entity, categorieId)
        local stock = type(entity) == "table" and entity[def.cleEntite]
        if type(stock) ~= "table" then return VIDE end
        local rangee = stock[categorieId]
        return type(rangee) == "table" and rangee or VIDE
    end

    -- Les identifiants portes dans une categorie, TOUS, meme ceux dont la
    -- definition n'existe plus (la fenetre doit pouvoir les montrer). Une copie.
    function C.Ids(entity, categorieId)
        local out = {}
        for _, id in ipairs(Rangee(entity, tostring(categorieId))) do out[#out + 1] = id end
        return out
    end

    function C.Porte(entity, id)
        for _, categorie in ipairs(def.categories) do
            for _, porte in ipairs(Rangee(entity, categorie.id)) do
                if porte == tostring(id) then return true end
            end
        end
        return false
    end

    -- Tout ce qui est porte et connu, toutes categories.
    function C.Portes(entity)
        local out = {}
        for _, categorie in ipairs(def.categories) do
            for _, id in ipairs(Rangee(entity, categorie.id)) do
                local element = C.Get(id)
                if element then out[#out + 1] = element end
            end
        end
        return out
    end

    -- Place un element. Renvoie true, ou false et la raison : un refus se dit.
    function C.Placer(entity, id)
        if type(entity) ~= "table" then return false, "aucune entite." end
        local element = C.Get(id)
        if not element then return false, def.nom .. " inconnu." end
        -- Deux fois le meme cumulerait ses bonus : refuse — sauf pour une
        -- famille sans effets ou chaque exemplaire compte (deux sacs).
        if not def.doublons and C.Porte(entity, element.id) then
            return false, string.format("%s est deja porte.", element.label)
        end
        local places = C.Capacite(element.categorie)
        local occupees = #Rangee(entity, element.categorie)
        if occupees >= places then
            return false, string.format("plus d'emplacement libre en %s (%d / %d).",
                CATEGORIE[element.categorie].label:lower(), occupees, places)
        end
        entity[def.cleEntite] = type(entity[def.cleEntite]) == "table" and entity[def.cleEntite] or {}
        local stock = entity[def.cleEntite]
        stock[element.categorie] = type(stock[element.categorie]) == "table" and stock[element.categorie] or {}
        table.insert(stock[element.categorie], element.id)
        return true
    end

    -- Enleve un element (un seul exemplaire), qu'il existe encore ou non.
    -- Efface les tables vides.
    function C.Enlever(entity, id)
        local stock = type(entity) == "table" and entity[def.cleEntite]
        if type(stock) ~= "table" then return false end
        local cible = tostring(id)
        for categorieId, rangee in pairs(stock) do
            if type(rangee) == "table" then
                for index = #rangee, 1, -1 do
                    if rangee[index] == cible then
                        table.remove(rangee, index)
                        if #rangee == 0 then stock[categorieId] = nil end
                        if next(stock) == nil then entity[def.cleEntite] = nil end
                        return true
                    end
                end
            end
        end
        return false
    end

    -- Les definitions d'une categorie qu'on ne porte pas deja : ce que la
    -- fenetre propose.
    function C.Candidats(entity, categorieId)
        local out = {}
        for _, element in ipairs(C.list) do
            if element.categorie == categorieId and (def.doublons or not C.Porte(entity, element.id)) then
                out[#out + 1] = element
            end
        end
        return out
    end

    LCM.Effets.Source(def.nom, C.Portes, function() return C.list end)
    return C
end
