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
-- Ce que tient un emplacement de sac : un SAC, ou une TENTE (10 octobre 2026).
-- La tente a son registre (Core/Campement.lua) mais se porte comme un sac : sur
-- un emplacement de sacoche, avec des cases ou l'on range ses accessoires.
-- Rend { element, ref, places, placesDevise, tente } ou nil.
function Inventaire.Contenant(emplacement)
    if type(emplacement) ~= "table" then return nil end
    if emplacement.sac then
        local sac = LCM.Sacs.Get(emplacement.sac)
        return { element = sac, ref = "sacs/" .. emplacement.sac, id = emplacement.sac,
                 places = sac and sac.places or 0, placesDevise = sac and sac.placesDevise or 0 }
    end
    if emplacement.tente then
        local tente = LCM.Tentes and LCM.Tentes.Get(emplacement.tente)
        -- Ses accessoires inclus prennent deja leurs places.
        local places = tente and math.max(0, (tente.accessoiresMax or 0) - #(tente.accessoires or VIDE)) or 0
        return { element = tente, ref = "tentes/" .. emplacement.tente, id = emplacement.tente,
                 places = places, placesDevise = 0, tente = true }
    end
    return nil
end

function Inventaire.Cases(emplacement)
    local contenant = Inventaire.Contenant(emplacement)
    local places = contenant and contenant.places or 0
    local devise = contenant and contenant.placesDevise or 0
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
-- `forcer` : poser sans verifier la nature. Reserve a la MIGRATION — un sac
-- deja porte avant que la regle existe reste porte. La regle vaut pour ce qu'on
-- range aujourd'hui, pas pour reprendre ce qui etait la hier.
function Inventaire.Poser(entity, categorieId, index, id, forcer)
    local categorie, i = Verifier(entity, categorieId, index)
    if not categorie then return false, i end
    if Inventaire.Emplacement(entity, categorieId, i) then
        return false, "cet emplacement est déjà occupé."
    end
    -- Une TENTE (« tentes/<id> ») ne se porte que sur un emplacement de sacoche
    -- (le MJ, 10 octobre 2026).
    local tenteId = categorie.contient == "sac" and tostring(id or ""):match("^tentes/(.+)$")
    if tenteId then
        local tente = LCM.Tentes and LCM.Tentes.Get(tenteId)
        if not tente then return false, "tente inconnue." end
        if categorieId ~= "saccoches" then return false, "une tente se porte dans un emplacement de sacoche." end
        RangeePourEcrire(entity, categorieId)[i] = { tente = tente.id }
    elseif categorie.contient == "sac" then
        local sac = LCM.Sacs.Get(id)
        if not sac then return false, "cet emplacement n'accepte qu'un sac." end
        -- Un SAC se porte dans un emplacement de sac ; une SACOCHE va dans les
        -- deux. On ne met pas un sac de voyage dans une poche de ceinture.
        if not forcer and categorieId == "saccoches" and not LCM.Sacs.EstSacoche(sac) then
            return false, "un sac ne se porte que dans un emplacement de sac."
        end
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

-- Deplace ce que tient un emplacement vers un emplacement libre, contenu
-- compris : un sac garde ses cases. L'arrivee doit accepter la meme chose que
-- le depart (un sac ne part pas dans l'onglet des devises).
function Inventaire.Deplacer(entity, categorieId, index, versCategorieId, versIndex)
    local depart, i = Verifier(entity, categorieId, index)
    if not depart then return false, i end
    local arrivee, j = Verifier(entity, versCategorieId, versIndex)
    if not arrivee then return false, j end
    local e = Inventaire.Emplacement(entity, categorieId, i)
    if not e then return false, "cet emplacement est vide." end
    if depart.id == arrivee.id and i == j then return false, "c'est déjà là." end
    if Inventaire.Emplacement(entity, versCategorieId, j) then
        return false, "l'emplacement d'arrivée est déjà occupé."
    end
    if arrivee.contient ~= depart.contient then
        return false, string.format("l'onglet %s n'accepte pas ça.", arrivee.label)
    end
    if e.tente and arrivee.id ~= "saccoches" then
        return false, "une tente se porte dans un emplacement de sacoche."
    end
    RangeePourEcrire(entity, arrivee.id)[j] = e
    entity.inventaire[depart.id][i] = nil
    Nettoyer(entity, depart.id)
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
-- Une tente se porte comme un sac (10 octobre 2026), mais elle ne recoit QUE
-- des accessoires de camping. Un accessoire, lui, se transporte aussi dans un
-- sac ordinaire. La tente, elle, ne se range pas dans un sac : elle s'equipe.
local RANGEABLES = { objets = true, ressources = true, sacs = true, accessoires_camping = true }

function Inventaire.Accepte(emplacement, index, ref)
    local famille = tostring(ref or ""):match("^([%w_]+)/")
    if not LCM.Compendium.Resoudre(ref) then return false, "entrée inconnue du compendium." end
    if emplacement and emplacement.tente then
        if famille ~= "accessoires_camping" then
            return false, "une tente n'accueille que des accessoires de camping."
        end
        return true
    end
    if Inventaire.EstCaseDevise(emplacement, index) then
        if famille ~= "devises" then return false, "une case de devise n'accepte qu'une devise." end
    elseif not RANGEABLES[famille] then
        return false, "un sac accepte des objets, des ressources, des accessoires de camping ou des sacs."
    end
    -- Un contenant dans un contenant : seul un SAC en accepte, et il faut que
    -- le nouveau venu tienne — il occupe sa case plus toutes les siennes.
    if famille == "sacs" then
        local hote = LCM.Sacs.Get(emplacement and emplacement.sac)
        if not hote then return false, "aucun sac ici." end
        if LCM.Sacs.EstSacoche(hote) then
            return false, "une sacoche ne contient ni sac ni sacoche."
        end
        local range = LCM.Compendium.Resoudre(ref)
        local encombrement = LCM.Sacs.Encombrement(range and range.id)
        local libres = Inventaire.CasesLibres(emplacement)
        if encombrement > libres then
            return false, string.format("il faut %d places libres, il en reste %d.", encombrement, libres)
        end
    end
    return true
end

-- Combien de cases restent libres dans un sac, en comptant ce que les sacs
-- qu'il contient deja lui prennent.
function Inventaire.CasesLibres(emplacement)
    local total = Inventaire.Cases(emplacement)
    local pris = 0
    for index = 1, total do
        local c = Inventaire.Case(emplacement, index)
        if c then
            local famille = tostring(c.ref or ""):match("^([%w_]+)/")
            if famille == "sacs" then
                local dedans = LCM.Compendium.Resoudre(c.ref)
                pris = pris + LCM.Sacs.Encombrement(dedans and dedans.id)
            else
                pris = pris + 1
            end
        end
    end
    return math.max(0, total - pris)
end

-- Range une entree dans une case libre d'un sac.
function Inventaire.Ranger(entity, categorieId, index, case, ref, quantite)
    local e = Inventaire.Emplacement(entity, categorieId, index)
    if not e or not (e.sac or e.tente) then return false, "aucun sac dans cet emplacement." end
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
                        if not place and Inventaire.Poser(entity, categorieId, index, id, true) then place = true end
                    end
                end
                if not place then restants[#restants + 1] = id end
            end
            entity.sacs.sac = #restants > 0 and restants or nil
            if next(entity.sacs) == nil then entity.sacs = nil end
        end
    end
end)

-- Ou se trouve une entree dans les sacs : l'onglet, l'emplacement et la case
-- de la premiere pile qui la contient, ou nil. Sert a l'equipement, qui ne
-- prend que ce que le personnage porte dans ses sacs.
function Inventaire.Chercher(entity, ref)
    if type(entity) ~= "table" then return nil end
    for _, categorie in ipairs(Inventaire.categories) do
        for index = 1, Inventaire.Capacite(categorie.id) do
            local emplacement = Inventaire.Emplacement(entity, categorie.id, index)
            for case, c in pairs(emplacement and type(emplacement.cases) == "table" and emplacement.cases or VIDE) do
                if type(c) == "table" and c.ref == ref then return categorie.id, index, case end
            end
        end
    end
    return nil
end

-- Sort UN exemplaire d'une entree des sacs : la pile baisse, la derniere
-- unite libere la case. false et la raison si elle n'y est pas.
function Inventaire.Prendre(entity, ref)
    local categorieId, index, case = Inventaire.Chercher(entity, ref)
    if not categorieId then return false, "absent des sacs." end
    local c = Inventaire.Case(Inventaire.Emplacement(entity, categorieId, index), case)
    local quantite = tonumber(c.quantite) or 1
    if quantite > 1 then
        c.quantite = quantite - 1
        return true
    end
    return Inventaire.Vider(entity, categorieId, index, case)
end

-- Ranger une entree SANS dire ou : la premiere case libre venue, tous sacs
-- confondus. C'est ce dont ont besoin la recolte et l'achat, qui donnent un
-- objet sans savoir ce que le joueur a dans ses sacs.
--
-- Les cases de devise sont sautees : une devise ne se range pas comme un objet,
-- et une herbe n'a rien a faire dans un porte-monnaie.
function Inventaire.Deposer(entity, ref, quantite)
    if type(entity) ~= "table" then return false, "aucun personnage." end
    -- Une tente ne se range pas dans un sac : elle s'equipe, sur le premier
    -- emplacement de sacoche libre. Sans quoi on ne pourrait ni l'acheter ni
    -- la recevoir.
    if tostring(ref or ""):match("^tentes/") then
        for index = 1, Inventaire.Capacite("saccoches") do
            if not Inventaire.Emplacement(entity, "saccoches", index) then
                return Inventaire.Poser(entity, "saccoches", index, ref)
            end
        end
        return false, "aucun emplacement de sacoche libre pour la tente."
    end
    for _, categorie in ipairs(Inventaire.categories) do
        for index = 1, Inventaire.Capacite(categorie.id) do
            local emplacement = Inventaire.Emplacement(entity, categorie.id, index)
            if emplacement then
                local total, places = Inventaire.Cases(emplacement)
                -- Une case qui n'accepte pas l'entree (une dague dans une tente)
                -- n'est pas une place libre pour elle : on passe au sac suivant.
                for case = 1, math.min(total, places) do
                    if not Inventaire.Case(emplacement, case) and Inventaire.Accepte(emplacement, case, ref) then
                        return Inventaire.Ranger(entity, categorie.id, index, case, ref, quantite)
                    end
                end
            end
        end
    end
    return false, "aucune place libre."
end
