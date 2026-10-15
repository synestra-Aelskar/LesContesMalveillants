-- Coffres poses sur la carte : contenu partage, ouverture et verrouillage.
-- Le MJ proprietaire arbitre chaque mouvement pour que deux joueurs ne
-- puissent ni prendre le meme objet, ni depasser la capacite du coffre.

local _, LCM = ...
local Coffres = { definitions = {}, points = {}, courant = nil, etat = nil }
LCM.Coffres = Coffres
Coffres.METHODE_CLEF = "clef"

Coffres.SUJETS = { definition = "cof", retrait = "cof-", demande = "cof?",
    action = "cof!", etat = "cof+" }
local S = Coffres.SUJETS
local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Moi() return LCM.PlayerId() end
local function Signaler() if Coffres.onChange then pcall(Coffres.onChange) end end
local function RayonDefaut()
    local equilibrage = LCM.Equilibrage or {}
    return tonumber(equilibrage.coffres and equilibrage.coffres.rayon)
        or tonumber(equilibrage.marchands and equilibrage.marchands.rayon) or 4
end
local Positionner

function Coffres.Paquet(definition, points)
    local c = definition.coffre or {}
    local objets = {}
    for _, o in ipairs(c.objets or {}) do
        objets[#objets + 1] = { e = o.entree, q = o.quantite,
            d = LCM.Echange and LCM.Echange.DefinitionObjet(o.entree) or nil }
    end
    local outils = {}
    for _, o in ipairs(c.outils or {}) do
        outils[#outils + 1] = { e = o.entree, q = o.quantite, c = o.consomme,
            n = o.consommeQuantite, x = o.expertise,
            d = LCM.Echange and LCM.Echange.DefinitionObjet(o.entree) or nil }
    end
    return { i = definition.id, n = definition.label, p = LCM.Recolte.Plier(points),
        c = { s = c.places, v = c.verrous, r = c.reset, y = c.rayon, o = objets,
            x = c.expertises, u = outils } }
end

function Coffres.Lire(paquet)
    local id = Texte(paquet and paquet.i)
    if id == "" then return nil end
    local function importer(ref, definition)
        if type(definition) == "table" and LCM.Echange and LCM.Echange.ImporterObjetPartage then
            LCM.Echange.ImporterObjetPartage({ ref = ref, definition = definition })
        end
    end
    local raw = type(paquet.c) == "table" and paquet.c or {}
    local coffre = { places = math.max(1, math.floor(tonumber(raw.s) or 1)),
        rayon = math.max(0.1, tonumber(raw.y) or RayonDefaut()),
        verrous = math.max(0, math.floor(tonumber(raw.v) or 0)), reset = raw.r == true or raw.r == "true",
        objets = {}, expertises = {}, outils = {} }
    for _, o in ipairs(type(raw.o) == "table" and raw.o or {}) do
        local ref = Texte(o.e)
        importer(ref, o.d)
        if ref ~= "" then coffre.objets[#coffre.objets + 1] = { entree = ref,
            quantite = math.max(0, math.floor(tonumber(o.q) or 0)) } end
    end
    for _, x in ipairs(type(raw.x) == "table" and raw.x or {}) do
        coffre.expertises[#coffre.expertises + 1] = { id = Texte(x.id),
            dd = math.max(0, math.floor(tonumber(x.dd) or 0)),
            fatigue = math.max(0, math.floor(tonumber(x.fatigue) or 0)),
            usureOutils = x.usureOutils == true or x.usureOutils == "true",
            reverrouillable = x.reverrouillable == true or x.reverrouillable == "true" }
    end
    for _, o in ipairs(type(raw.u) == "table" and raw.u or {}) do
        local ref = Texte(o.e)
        importer(ref, o.d)
        if ref ~= "" then coffre.outils[#coffre.outils + 1] = { entree = ref,
            quantite = math.max(1, math.floor(tonumber(o.q) or 1)),
            consomme = o.c == true or o.c == "true",
            consommeQuantite = math.max(1, math.floor(tonumber(o.n) or 1)),
            expertise = Texte(o.x) ~= "" and Texte(o.x) or nil } end
    end
    return { id = id, label = Texte(paquet.n) ~= "" and Texte(paquet.n) or "Coffre",
        coffre = coffre }, LCM.Recolte.Deplier(paquet.p)
end

function Coffres.Sauver()
    if not LCM.EnsureDatabase then return end
    LCM.EnsureDatabase()
    local defs, points = {}, {}
    for id, d in pairs(Coffres.definitions) do if d.auteur ~= Moi() then defs[id] = d end end
    for id, p in pairs(Coffres.points) do if defs[p.def] then points[id] = p end end
    LCM.db.coffres = next(defs) and { definitions = defs, points = points } or nil
end

function Coffres.Connaitre(definition, points, auteur)
    if type(definition) ~= "table" or not definition.id then return false end
    definition.auteur = auteur or definition.auteur
    Coffres.definitions[definition.id] = definition
    for id, p in pairs(Coffres.points) do if p.def == definition.id then Coffres.points[id] = nil end end
    for _, p in ipairs(points or {}) do p.def = definition.id; Coffres.points[p.id] = p end
    Coffres.Sauver()
    if Positionner and next(Coffres.points) then Positionner() end
    Signaler()
    return true
end

function Coffres.Oublier(id)
    id = tostring(id or "")
    Coffres.points[id] = nil
    if tostring(Coffres.courant or "") == id then Coffres.courant, Coffres.etat = nil, nil end
    if Coffres.proche and tostring(Coffres.proche.id or "") == id then
        Coffres.proche = nil
        if LCM.UI.Coffre and LCM.UI.Coffre.Proche then LCM.UI.Coffre.Proche(nil) end
    end
    if LCM.UI.Coffre and LCM.UI.Coffre.Retirer then LCM.UI.Coffre.Retirer(id) end
    Coffres.Sauver()
    if Positionner then Positionner() end
    Signaler()
end

function Coffres.Proche(positions)
    positions = positions or {}
    local carte = LCM.Recolte.Carte()
    local meilleur, distanceMin
    for _, p in pairs(Coffres.points) do
        local definition = Coffres.definitions[p.def]
        if definition and p.carte == carte then
            local source = p.source or "?"
            local pos = positions[source]
            if pos == nil then
                local x, y = LCM.Recolte.Position(p.source)
                pos = x and { x = x, y = y } or false; positions[source] = pos
            end
            if pos then
                local d = math.sqrt((pos.x - p.x)^2 + (pos.y - p.y)^2)
                local rayon = tonumber(definition.coffre and definition.coffre.rayon) or RayonDefaut()
                if d <= rayon and (not distanceMin or d < distanceMin) then meilleur, distanceMin = p, d end
            end
        end
    end
    return meilleur
end

function Coffres.Envoyer(action, donnees)
    local p = Coffres.points[Coffres.courant or ""]
    local d = p and Coffres.definitions[p.def]
    if not d or not d.auteur then return false, "propriétaire du coffre indisponible." end
    donnees = donnees or {}; donnees.i = p.id; donnees.a = action
    if d.auteur == Moi() and LCM.IsMaster() and LCM.CoffresMJ then
        local ok, raison = LCM.CoffresMJ.Traiter(Moi(), donnees)
        if ok == nil then return true end
        return ok, raison
    end
    return LCM.Reseau.Envoyer(S.action, donnees, "WHISPER", d.auteur)
end

function Coffres.Ouvrir(id)
    local p = Coffres.points[tostring(id or "")]
    local d = p and Coffres.definitions[p.def]
    if not d then return false, "coffre inconnu." end
    if Coffres.courant and Coffres.courant ~= p.id then Coffres.Envoyer("fermer") end
    Coffres.courant, Coffres.etat = p.id, nil
    if LCM.UI.Coffre and LCM.UI.Coffre.Ouvrir then LCM.UI.Coffre.Ouvrir(p.id) end
    return Coffres.Envoyer("ouvrir")
end

function Coffres.Demander()
    if LCM.IsMaster() then return end
    LCM.Reseau.Envoyer(S.demande, {}, LCM.Combat.CanalGroupe())
end

Positionner = function()
    if not Coffres.horloge then
        local h = CreateFrame("Frame"); h:Hide(); h.reste = 0
        h:SetScript("OnUpdate", function(self, elapsed)
            self.reste = self.reste + (tonumber(elapsed) or 0)
            if self.reste < 0.25 then return end
            self.reste = 0
            local proche = Coffres.Proche()
            if proche ~= Coffres.proche then
                Coffres.proche = proche
                if LCM.UI.Coffre and LCM.UI.Coffre.Proche then LCM.UI.Coffre.Proche(proche) end
            end
        end)
        Coffres.horloge = h
    end
    if next(Coffres.points) then Coffres.horloge:Show() else Coffres.horloge:Hide() end
end

LCM.WhenReady(function()
    local saved = LCM.db and LCM.db.coffres
    for id, d in pairs(type(saved) == "table" and saved.definitions or {}) do Coffres.definitions[id] = d end
    for id, p in pairs(type(saved) == "table" and saved.points or {}) do
        if Coffres.definitions[p.def] then Coffres.points[id] = p end
    end
    Positionner()
    LCM.Reseau.Ecouter(S.definition, function(expediteur, data)
        if expediteur == Moi() or not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local def, points = Coffres.Lire(data)
        if def then Coffres.Connaitre(def, points, expediteur) end
    end)
    LCM.Reseau.Ecouter(S.retrait, function(expediteur, data)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        if data.i then Coffres.Oublier(data.i) end
    end)
    LCM.Reseau.Ecouter(S.etat, function(expediteur, data)
        if tostring(data.i or "") ~= tostring(Coffres.courant or "") then return end
        local point = Coffres.points[Coffres.courant]
        local definition = point and Coffres.definitions[point.def]
        if definition and definition.auteur and definition.auteur ~= expediteur then return end
        Coffres.etat = data
        Signaler()
        if Coffres.onReponse then pcall(Coffres.onReponse, expediteur, data) end
    end)
    LCM.Reseau.Ecouter(S.demande, function(expediteur)
        if not LCM.IsMaster() or not LCM.Reseau.DansLeGroupe(expediteur) then return end
        LCM.CoffresMJ.Renvoyer(expediteur)
    end)
    if not LCM.IsMaster() then Coffres.Demander() end
end)

LCM.On("GROUP_JOINED", function() if not LCM.IsMaster() then Coffres.Demander() end end)
LCM.On("GROUP_ROSTER_UPDATE", Positionner)

