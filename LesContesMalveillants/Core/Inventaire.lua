-- Inventaire : ce qu'une entite range, et ou.
--
-- La fenetre Inventaires du template (inventoryWindows › window_custom_10) a
-- des ONGLETS (Sacs, Saccoches, Devises), chacun avec un nombre fixe
-- d'EMPLACEMENTS. Un emplacement de sac recoit un sac du compendium ; un sac
-- a des CASES (ses places, puis ses places de devise), et chaque case recoit
-- une entree du compendium avec sa quantite. Un emplacement de devise recoit
-- une devise et son solde.
--
-- Les onglets et leurs capacites sont de la structure (Data/Inventaire.lua,
-- Equilibrage.inventaire). Cote entite, seulement ce qui est range :
--
--     entity.inventaire = {
--         sacs      = { [1] = { sac = "gros_sac", cases = { [3] = { ref = "objets/dague", quantite = 1 } } } },
--         devises   = { [1] = { devise = "credits", solde = 120 } },
--     }
--
-- Un emplacement vide n'ecrit rien ; une table redevenue vide s'efface. Les
-- references sont celles du compendium (« famille/identifiant ») : une entree
-- disparue garde sa case, marquee, et revient si l'entree revient.

local _, LCM = ...

local Inventaire = { categories = {}, parId = {} }
LCM.Inventaire = Inventaire

local function Erreur(message) error("LCM/Inventaire : " .. tostring(message), 0) end

-- Core se charge avant Data : l'equilibrage se lit a l'appel.
local function Capacites() return LCM.Equilibrage and LCM.Equilibrage.inventaire or {} end

-- Un onglet : { id, label, vue = "grille" | "liste", contient = "sac" | "devise" }.
function Inventaire.Categorie(def)
    if type(def) ~= "table" or tostring(def.id or "") == "" then Erreur("onglet invalide") end
    if def.contient ~= "sac" and def.contient ~= "devise" then
        Erreur(def.id .. " : contenu inconnu « " .. tostring(def.contient) .. " »")
    end
    Inventaire.parId[def.id] = def
    Inventaire.categories[#Inventaire.categories + 1] = def
    return def
end

function Inventaire.Get(id) return Inventaire.parId[tostring(id or "")] end

function Inventaire.Capacite(categorieId)
    return math.max(0, math.floor(tonumber(Capacites()[tostring(categorieId or "")]) or 0))
end

-- ===== Lecture (ne cree rien) ==============================================

local VIDE = {}

local function Rangee(entity, categorieId)
    local inv = type(entity) == "table" and entity.inventaire
    local r = type(inv) == "table" and inv[categorieId]
    return type(r) == "table" and r or VIDE
end

-- Ce que tient un emplacement (une table) ou nil.
function Inventaire.Emplacement(entity, categorieId, index)
    local e = Rangee(entity, categorieId)[tonumber(index)]
    return type(e) == "table" and e or nil
end

-- Combien d'emplacements sont occupes dans un onglet.
function Inventaire.Occupes(entity, categorieId)
    local n = 0
    for index = 1, Inventaire.Capacite(categorieId) do
        if Inventaire.Emplacement(entity, categorieId, index) then n = n + 1 end
    end
    return n
end

-- Le nombre de cases d'un sac : ses places, puis ses places de devise. Un sac
-- disparu du compendium n'a plus de cases connues : celles qui sont pleines
-- restent visibles.
function Inventaire.Cases(emplacement)
    local sac = emplacement and LCM.Sacs.Get(emplacement.sac)
    local places = sac and sac.places or 0
    local devise = sac and sac.placesDevise or 0
    local plusHaute = 0
    for index in pairs(emplacement and emplacement.cases or VIDE) do
        plusHaute = math.max(plusHaute, tonumber(index) or 0)
    end
    return math.max(places + devise, plusHaute), places, devise
end

-- Une case de devise : apres les places ordinaires.
function Inventaire.EstCaseDevise(emplacement, index)
    local _, places, devise = Inventaire.Cases(emplacement)
    return index > places and index <= places + devise
end

function Inventaire.Case(emplacement, index)
    local c = emplacement and type(emplacement.cases) == "table" and emplacement.cases[tonumber(index)]
    return type(c) == "table" and c or nil
end

-- ===== Ecriture ============================================================
-- Toutes renvoient true, ou false et la raison : un refus se dit.

local function RangeePourEcrire(entity, categorieId)
    entity.inventaire = type(entity.inventaire) == "table" and entity.inventaire or {}
    entity.inventaire[categorieId] = type(entity.inventaire[categorieId]) == "table" and entity.inventaire[categorieId] or {}
    return entity.inventaire[categorieId]
end

local function Nettoyer(entity, categorieId)
    local inv = entity.inventaire
    if type(inv) ~= "table" then return end
    if type(inv[categorieId]) == "table" and next(inv[categorieId]) == nil then inv[categorieId] = nil end
    if next(inv) == nil then entity.inventaire = nil end
end

local function Verifier(entity, categorieId, index)
    if type(entity) ~= "table" then return nil, "aucun personnage." end
    local categorie = Inventaire.Get(categorieId)
    if not categorie then return nil, "onglet inconnu." end
    index = tonumber(index)
    if not index or index < 1 or index > Inventaire.Capacite(categorieId) then
        return nil, string.format("l'onglet %s n'a pas d'emplacement %s.", categorie.label, tostring(index))
    end
    return categorie, index
end

-- Pose un sac (ou une devise, selon l'onglet) dans un emplacement libre.
function Inventaire.Poser(entity, categorieId, index, id)
    local categorie, i = Verifier(entity, categorieId, index)
    if not categorie then return false, i end
    if Inventaire.Emplacement(entity, categorieId, i) then
        return false, "cet emplacement est déjà occupé."
    end
    if categorie.contient == "sac" then
        local sac = LCM.Sacs.Get(id)
        if not sac then return false, "cet emplacement n'accepte qu'un sac." end
        RangeePourEcrire(entity, categorieId)[i] = { sac = sac.id }
    else
        local devise = LCM.Devises.Get(id)
        if not devise then return false, "cet emplacement n'accepte qu'une devise." end
        RangeePourEcrire(entity, categorieId)[i] = { devise = devise.id, solde = 0 }
    end
    return true
end

-- Retire ce que tient un emplacement. Un sac qui contient quelque chose est
-- refuse : on ne jette pas son contenu en douce.
function Inventaire.Retirer(entity, categorieId, index)
    local _, i = Verifier(entity, categorieId, index)
    if not _ then return false, i end
    local e = Inventaire.Emplacement(entity, categorieId, i)
    if not e then return false, "cet emplacement est déjà vide." end
    if type(e.cases) == "table" and next(e.cases) ~= nil then
        return false, "ce sac n'est pas vide : vide-le d'abord."
    end
    entity.inventaire[categorieId][i] = nil
    Nettoyer(entity, categorieId)
    return true
end

-- Le solde d'une devise (nombre entier, zero au moins).
function Inventaire.Solde(entity, categorieId, index, solde)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    if not e or not e.devise then return false, "aucune devise ici." end
    local n = tonumber(solde)
    if not n or n ~= math.floor(n) or n < 0 then
        return false, string.format("solde illisible (%s) : un nombre entier, zéro au moins.", tostring(solde))
    end
    e.solde = n
    return true
end

-- Ce qu'une case accepte : une entree du compendium. Une case de devise
-- n'accepte qu'une devise, une case ordinaire tout le reste qui se range
-- (objets, ressources, sacs).
local RANGEABLES = { objets = true, ressources = true, sacs = true }

function Inventaire.Accepte(emplacement, index, ref)
    local famille = tostring(ref or ""):match("^([%w_]+)/")
    if not LCM.Compendium.Resoudre(ref) then return false, "entrée inconnue du compendium." end
    if Inventaire.EstCaseDevise(emplacement, index) then
        if famille ~= "devises" then return false, "une case de devise n'accepte qu'une devise." end
    elseif not RANGEABLES[famille] then
        return false, "un sac accepte des objets, des ressources ou des sacs."
    end
    return true
end

-- Range une entree dans une case libre d'un sac.
function Inventaire.Ranger(entity, categorieId, index, case, ref, quantite)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    if not e or not e.sac then return false, "aucun sac dans cet emplacement." end
    local total = Inventaire.Cases(e)
    case = tonumber(case)
    if not case or case < 1 or case > total then return false, "ce sac n'a pas de case " .. tostring(case) .. "." end
    if Inventaire.Case(e, case) then return false, "cette case est déjà occupée." end
    local ok, raison = Inventaire.Accepte(e, case, ref)
    if not ok then return false, raison end
    quantite = tonumber(quantite or 1)
    if not quantite or quantite < 1 or quantite ~= math.floor(quantite) then
        return false, "quantité illisible : un nombre entier, 1 au moins."
    end
    e.cases = type(e.cases) == "table" and e.cases or {}
    e.cases[case] = { ref = ref, quantite = quantite }
    return true
end

-- Change la quantite d'une case. La pile maximale de l'entree, si elle en a
-- une, borne : au-dessus, c'est refuse, pas rabote.
function Inventaire.Quantite(entity, categorieId, index, case, quantite)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    local c = Inventaire.Case(e, case)
    if not c then return false, "case vide." end
    local n = tonumber(quantite)
    if not n or n < 1 or n ~= math.floor(n) then
        return false, string.format("quantité illisible (%s) : un nombre entier, 1 au moins.", tostring(quantite))
    end
    local element = LCM.Compendium.Resoudre(c.ref)
    if element and element.pileMax and n > element.pileMax then
        return false, string.format("%s s'empile par %d au plus.", element.label, element.pileMax)
    end
    c.quantite = n
    return true
end

function Inventaire.Vider(entity, categorieId, index, case)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    if not Inventaire.Case(e, case) then return false, "case déjà vide." end
    e.cases[tonumber(case)] = nil
    if next(e.cases) == nil then e.cases = nil end
    return true
end

-- ===== Reprise des sacs d'avant =============================================
-- L'inventaire precedent rangeait les sacs portes en liste (entity.sacs.sac).
-- Ils sont deplaces, pas effaces : dans les emplacements de sacs, puis de
-- saccoches ; ce qui ne tient nulle part reste ou il etait.
LCM.WhenReady(function()
    if not LCM.db or type(LCM.db.entities) ~= "table" then return end
    for _, entity in pairs(LCM.db.entities) do
        local ancien = type(entity.sacs) == "table" and entity.sacs.sac
        if type(ancien) == "table" then
            local restants = {}
            for _, id in ipairs(ancien) do
                local place = false
                for _, categorieId in ipairs({ "sacs", "saccoches" }) do
                    for index = 1, Inventaire.Capacite(categorieId) do
                        if not place and Inventaire.Poser(entity, categorieId, index, id) then place = true end
                    end
                end
                if not place then restants[#restants + 1] = id end
            end
            entity.sacs.sac = #restants > 0 and restants or nil
            if next(entity.sacs) == nil then entity.sacs = nil end
        end
    end
end)
