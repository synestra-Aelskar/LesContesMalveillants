-- Synchronisation du contenu PUBLIC entre addons WoW. Le compagnon MJ lit le
-- Sheet par son programme local ; les joueurs ne recoivent que les definitions
-- du fichier public genere, par le meme canal que le ping de presence.
local _, LCM = ...

local Base = {}
LCM.BasePublique = Base

local R = LCM.Reseau
local Source = LCM.SourcePublique
local REGISTRES = {
    accessoires_camping = "AccessoiresCamping", apprentissages = "Apprentissages",
    calculateurs = "Calculateurs", connaissances = "Connaissances",
    devises = "Devises", etats = "Etats", informations = "Informations",
    listes = "Listes", objets = "Objets", races = "Races",
    ressources = "Ressources", sacs = "Sacs", tentes = "Tentes",
    traits = "Traits", resolutions = "Resolutions",
}
local session
local derniereDemande = -math.huge

local function Maintenant() return (GetTime and GetTime()) or 0 end
local function Cache()
    LCM.EnsureDatabase()
    LCM.db.basePublique = type(LCM.db.basePublique) == "table" and LCM.db.basePublique or {}
    return LCM.db.basePublique
end

local function Registre(cle, definition)
    local famille, id = tostring(cle or ""):match("^([%w_]+)/([%w_.%-]+)$")
    if not famille or type(definition) ~= "table" or tostring(definition.id) ~= id
        or definition.distributionMJ then return nil end
    if famille == "resolutions" and definition.categorie == "mj" then return nil end
    return LCM[REGISTRES[famille]]
end

local function Poser(cle, definition)
    local registre = Registre(cle, definition)
    if not registre then return false end
    local ok, erreur = pcall(LCM.Publier, registre, definition)
    if not ok then LCM.Debug("base publique : " .. tostring(erreur)) end
    return ok
end

local function Versions()
    local versions = {}
    for cle, entree in pairs(Source) do versions[cle] = entree.revision end
    for cle, entree in pairs(Cache()) do
        if type(entree) == "table" and type(entree.revision) == "string"
            and Registre(cle, entree.definition) then
            versions[cle] = entree.revision
        end
    end
    return versions
end

-- Le cache est charge apres les fichiers generes. Un joueur qui revient sans
-- MJ connecte retrouve ainsi la derniere copie publique qu'il a recue.
local function Charger()
    for cle, entree in pairs(Cache()) do
        if type(entree) == "table" and Registre(cle, entree.definition) then
            Poser(cle, entree.definition)
        end
    end
end

function Base.Demander(force)
    if LCM.IsMaster() then return false end
    if not force and Maintenant() - derniereDemande < 30 then return false end
    local canal = LCM.Presence and LCM.Presence.Canal()
    local envoye = canal and R.Envoyer("base?", {}, "CHANNEL", canal)
    local groupe = LCM.Combat and LCM.Combat.CanalGroupe()
    if groupe then envoye = R.Envoyer("base?", {}, groupe) or envoye end
    if envoye then derniereDemande = Maintenant() end
    return envoye and true or false
end

local function ServirListe(joueur)
    if not LCM.IsMaster() then return end
    local versions = {}
    for cle, entree in pairs(Source) do versions[cle] = entree.revision end
    if not next(versions) then return end
    R.Envoyer("base_liste", { corps = LCM.Lien.Serialiser(versions) },
        "WHISPER", joueur, { etale = true })
end

local function RecevoirListe(joueur, donnees)
    if LCM.IsMaster() then return end
    if session and Maintenant() - session.debut < 120 then return end
    local versions = LCM.Lien.Deserialiser(donnees.corps)
    if type(versions) ~= "table" or not next(versions) then return end
    local locales = Versions()
    local demandes = {}
    for cle, revision in pairs(versions) do
        if type(cle) == "string" and type(revision) == "string"
            and cle:match("^[%w_]+/[%w_.%-]+$") and locales[cle] ~= revision then
            demandes[#demandes + 1] = cle
        end
    end
    table.sort(demandes)
    session = { mj = joueur, debut = Maintenant(), versions = versions,
                attendues = {}, recues = {} }
    for _, cle in ipairs(demandes) do session.attendues[cle] = true end
    R.Envoyer("base_demande", { cles = table.concat(demandes, ",") },
        "WHISPER", joueur, { etale = true })
end

local function ServirEntrees(joueur, donnees)
    if not LCM.IsMaster() then return end
    local nombre = 0
    for cle in tostring(donnees.cles or ""):gmatch("[^,]+") do
        local entree = Source[cle]
        if entree and nombre < 500 then
            R.Envoyer("base_entree", { cle = cle, revision = entree.revision,
                corps = LCM.Lien.Serialiser(entree.definition) },
                "WHISPER", joueur, { etale = true })
            nombre = nombre + 1
        end
    end
    R.Envoyer("base_fin", {}, "WHISPER", joueur, { etale = true })
end

local function RecevoirEntree(joueur, donnees)
    if not (session and session.mj == joueur) then return end
    local cle = tostring(donnees.cle or "")
    if not session.attendues[cle] or session.versions[cle] ~= donnees.revision then return end
    local definition = LCM.Lien.Deserialiser(donnees.corps)
    if not Registre(cle, definition) or not Poser(cle, definition) then return end
    Cache()[cle] = { revision = donnees.revision, definition = definition }
    session.recues[cle] = true
end

local function Finir(joueur)
    if not (session and session.mj == joueur) then return end
    for cle in pairs(session.attendues) do
        if not session.recues[cle] then session = nil return end
    end
    local cache = Cache()
    for cle in pairs(cache) do
        if not session.versions[cle] then
            local famille, id = cle:match("^([%w_]+)/([%w_.%-]+)$")
            local registre = famille and LCM[REGISTRES[famille]]
            if registre then registre.Retirer(id) end
            cache[cle] = nil
        elseif Source[cle] and Source[cle].revision == session.versions[cle] then
            Poser(cle, Source[cle].definition)
            cache[cle] = nil
        end
    end
    for cle, entree in pairs(Source) do
        if not session.versions[cle] then
            local registre = LCM[REGISTRES[entree.famille]]
            if registre then registre.Retirer(entree.definition.id) end
        end
    end
    session = nil
end

LCM.WhenReady(function()
    Charger()
    R.Ecouter("base?", ServirListe)
    R.Ecouter("base_liste", RecevoirListe)
    R.Ecouter("base_demande", ServirEntrees)
    R.Ecouter("base_entree", RecevoirEntree)
    R.Ecouter("base_fin", Finir)
    if not LCM.IsMaster() then
        LCM.Presence.Suivre(function() Base.Demander() end)
        Base.Demander(true)
    end
end)
