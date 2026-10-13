-- Les points de recolte, cote aventurier (13 octobre 2026).
--
-- Le MJ pose des points sur la carte (« Miner du fer », ici, ici et ici) ; un
-- aventurier qui marche dessus voit un bouton « Recolter », lance son jet de
-- metier et, s'il reussit, recoit la ressource. Le point disparait alors pour
-- tout le monde : il a ete consomme.
--
-- Rien de tout cela n'est livre dans l'addon joueur. Le joueur DEMANDE les
-- points a la connexion (« rec? » au groupe) ; ceux qui ont le panneau MJ lui
-- repondent en silence, a lui seul. Il ne les garde qu'en memoire : sans MJ
-- dans le groupe, il n'y a rien a recolter — c'est le MJ qui tient le registre
-- et qui dit si un point est encore la.
--
-- Le MJ ARBITRE chaque prise. Le jet se lance chez le joueur (c'est son
-- personnage), mais la quantite se tire chez le MJ, qui retire le point au
-- meme moment : deux joueurs sur le meme filon ne peuvent pas le vider deux
-- fois. Un jet rate ne coute rien, on peut retenter.
--
-- Les coordonnees suivent la regle des Lieux : un point retient la SOURCE de
-- position qui l'a pose (monde, carte, .gps) et sa carte, et ne se mesure
-- qu'avec elles. Des yards du monde contre des yards de carte, et l'on
-- recolterait a cent pas du filon.

local _, LCM = ...

local Recolte = {
    -- Ce que les MJ nous ont envoye. definitions[id] et points[id], ou chaque
    -- point porte `def` (l'identifiant de sa definition).
    definitions = {}, points = {},
    -- Les prises demandees au MJ et pas encore repondues.
    enAttente = {},
}
LCM.Recolte = Recolte

local INTERVALLE = 0.25

Recolte.SUJETS = {
    definition = "rec",   -- MJ -> joueur(s) : une definition et tous ses points
    retrait    = "rec-",  -- MJ -> groupe   : un point (ou une definition) n'est plus
    demande    = "rec?",  -- joueur -> groupe : envoyez-moi ce que vous avez
    prendre    = "rec!",  -- joueur -> MJ   : j'ai reussi mon jet sur ce point
    reponse    = "rec+",  -- MJ -> joueur   : voici ta part (ou pourquoi non)
    rendre     = "rec~",  -- joueur -> MJ   : je n'ai pas pu ranger, reprends-le
}
local S = Recolte.SUJETS

local function Eq()
    return (LCM.Equilibrage and LCM.Equilibrage.recolte) or {}
end

local function Moi() return LCM.PlayerId() end

local function Texte(valeur)
    return (tostring(valeur or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Carte()
    local D = LCM.DeplacementForce
    return D and D.Carte and D.Carte() or nil
end

local function Position(source)
    local D = LCM.DeplacementForce
    if not (D and D.Position) then return nil end
    local x, y, _, trouvee = D.Position(source)
    if not x then return nil end
    return x, y, trouvee
end
Recolte.Position, Recolte.Carte = Position, Carte

function Recolte.Rayon(definition)
    return tonumber(definition and definition.rayon) or tonumber(Eq().rayon) or 3
end

-- ===== Les points en une chaine ============================================
-- Comme les Lieux : « id,x,y,source,carte|… ». Une table imbriquee coute une
-- ligne par champ a l'encodeur, et cent points depasseraient de loin ce qu'on
-- veut faire passer par message.

function Recolte.Plier(points)
    local out = {}
    for _, p in ipairs(points or {}) do
        out[#out + 1] = string.format("%s,%.2f,%.2f,%s,%s", p.id, p.x, p.y,
            tostring(p.source or ""), p.carte and tostring(p.carte) or "")
    end
    return table.concat(out, "|")
end

function Recolte.Deplier(texte)
    local out = {}
    for morceau in tostring(texte or ""):gmatch("[^|]+") do
        local id, x, y, source, carte = morceau:match("^([^,]+),(-?[%d%.]+),(-?[%d%.]+),([^,]*),([^,]*)$")
        if id and tonumber(x) and tonumber(y) then
            out[#out + 1] = { id = id, x = tonumber(x), y = tonumber(y),
                source = source ~= "" and source or nil, carte = tonumber(carte) }
        end
    end
    return out
end

-- Le paquet d'une definition, cles courtes : il part une fois par MJ et par
-- joueur, mais il porte tous ses points.
function Recolte.Paquet(definition, points)
    return {
        i = definition.id, n = definition.label, e = definition.entree,
        a = definition.min, b = definition.max,
        m = definition.metier, d = definition.dd, r = definition.rayon,
        p = Recolte.Plier(points),
    }
end

-- Le decodeur rend tout en texte : chaque nombre est remis dans son type ici.
function Recolte.Lire(paquet)
    local id = Texte(paquet and paquet.i)
    if id == "" then return nil end
    local mini = math.max(1, math.floor(tonumber(paquet.a) or 1))
    return {
        id = id,
        label = Texte(paquet.n) ~= "" and Texte(paquet.n) or "Point de récolte",
        entree = Texte(paquet.e),
        min = mini,
        max = math.max(mini, math.floor(tonumber(paquet.b) or mini)),
        metier = Texte(paquet.m) ~= "" and Texte(paquet.m) or nil,
        dd = math.max(0, math.floor(tonumber(paquet.d) or 0)),
        rayon = tonumber(paquet.r),
    }, Recolte.Deplier(paquet.p)
end

-- ===== Ce qu'on connait ====================================================

local function Prevenir()
    Recolte.Regler()
    if Recolte.onChange then pcall(Recolte.onChange) end
end

-- Une definition arrive avec TOUS ses points : ceux qu'on avait pour elle et
-- qu'elle ne porte plus ont ete recoltes ou retires.
function Recolte.Connaitre(definition, points, auteur)
    if type(definition) ~= "table" or not definition.id then return false end
    definition.auteur = auteur or definition.auteur
    Recolte.definitions[definition.id] = definition
    for id, p in pairs(Recolte.points) do
        if p.def == definition.id then Recolte.points[id] = nil end
    end
    for _, p in ipairs(points or {}) do
        p.def = definition.id
        Recolte.points[p.id] = p
    end
    Prevenir()
    return true
end

function Recolte.Oublier(pointId)
    if not Recolte.points[tostring(pointId or "")] then return false end
    Recolte.points[tostring(pointId)] = nil
    Prevenir()
    return true
end

function Recolte.OublierDefinition(defId)
    defId = tostring(defId or "")
    Recolte.definitions[defId] = nil
    for id, p in pairs(Recolte.points) do
        if p.def == defId then Recolte.points[id] = nil end
    end
    Prevenir()
end

function Recolte.Nombre()
    local n = 0
    for _ in pairs(Recolte.points) do n = n + 1 end
    return n
end

-- ===== Ou l'on se tient ====================================================

-- Le point le plus proche dans son rayon, ou nil. `positions` sert de cache
-- d'un battement : une position par source, pas une par point.
function Recolte.Proche(positions)
    positions = positions or {}
    local carte = Carte()
    local meilleur, meilleureDistance
    for _, p in pairs(Recolte.points) do
        local definition = Recolte.definitions[p.def]
        if definition and p.carte == carte then
            local source = p.source or "?"
            local pos = positions[source]
            if pos == nil then
                local x, y = Position(p.source)
                pos = x and { x = x, y = y } or false
                positions[source] = pos
            end
            if pos then
                local dx, dy = pos.x - p.x, pos.y - p.y
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance <= Recolte.Rayon(definition)
                    and (not meilleureDistance or distance < meilleureDistance) then
                    meilleur, meilleureDistance = p, distance
                end
            end
        end
    end
    return meilleur, meilleureDistance
end

function Recolte.Tick()
    local positions = {}
    local proche = Recolte.Proche(positions)
    -- Au .gps, la position ne vient pas toute seule : on la redemande, et la
    -- cadence est bornee dans DemanderGPS (comme pour les Lieux).
    if positions.gps == false then
        local D = LCM.DeplacementForce
        if D and D.DemanderGPS then D.DemanderGPS() end
    end
    local avant = Recolte.courant
    Recolte.courant = proche
    if avant ~= proche and Recolte.onProche then pcall(Recolte.onProche, proche) end
end

local horloge
local function Horloge()
    if horloge then return horloge end
    horloge = CreateFrame("Frame", nil, UIParent)
    horloge:Hide()
    horloge.reste = 0
    horloge:SetScript("OnUpdate", function(self, ecoule)
        self.reste = self.reste + (tonumber(ecoule) or 0)
        if self.reste < INTERVALLE then return end
        self.reste = 0
        Recolte.Tick()
    end)
    return horloge
end

-- On ne bat la mesure que s'il y a quelque chose a recolter.
function Recolte.Regler()
    local quelque = next(Recolte.points) ~= nil
    local h = Horloge()
    if quelque then h:Show() else h:Hide() end
    if not quelque and Recolte.courant then
        Recolte.courant = nil
        if Recolte.onProche then pcall(Recolte.onProche, nil) end
    end
    return quelque
end

-- ===== Le jet ==============================================================
-- D15 + bonus du metier contre le DD (Equilibrage.recolte, regle Necronicon).
-- Sans metier ni DD, il n'y a rien a reussir : on ramasse.

function Recolte.Jet(entity, definition)
    local des = Eq().des or {}
    local bonus = definition.metier and LCM.Metiers.Bonus(entity, definition.metier) or 0
    local jet = LCM.Roll.Des(des.min or 0, des.max or 15)
    local total = jet + bonus
    return { jet = jet, bonus = bonus, total = total, dd = definition.dd,
             reussi = total >= definition.dd, min = des.min or 0, max = des.max or 15 }
end

local function Annoncer(definition, r)
    local metier = definition.metier and LCM.Metiers.Get(definition.metier)
    local texte = string.format("Récolte : %s (DD %d) : %d  (D%d : %d%s) — %s",
        definition.label, r.dd, r.total, r.max, r.jet,
        metier and string.format(", %s : %+d", metier.label, r.bonus) or "",
        r.reussi and "réussi" or "raté")
    if LCM.Actions and LCM.Actions.Annoncer then LCM.Actions.Annoncer(texte)
    else LCM.Info(texte) end
end

-- Recevoir sa part : ranger, sinon rendre le point au MJ. Un filon vide pour
-- un sac plein serait une ressource perdue pour tout le monde.
function Recolte.Recevoir(pointId, quantite, entree, defId)
    Recolte.enAttente[pointId] = nil
    local definition = Recolte.definitions[defId or ""]
    Recolte.Oublier(pointId)
    local entity = LCM.Entities.Self()
    local ok, raison = LCM.Inventaire.Deposer(entity, entree, quantite)
    if not ok then
        return false, raison or "impossible de ranger."
    end
    local ressource = LCM.Compendium and LCM.Compendium.Resoudre and LCM.Compendium.Resoudre(entree)
    LCM.Ok(string.format("Tu récoltes %s x%d.",
        (ressource and ressource.label) or (definition and definition.label) or entree, quantite))
    if LCM.Entities.Changed then LCM.Entities.Changed(entity) end
    return true
end

-- Le geste du joueur. Rend vrai quand la prise est faite (ou demandee au MJ).
function Recolte.Tenter(pointId)
    pointId = tostring(pointId or (Recolte.courant and Recolte.courant.id) or "")
    local p = Recolte.points[pointId]
    if not p then return false, "il n'y a rien à récolter ici." end
    local definition = Recolte.definitions[p.def]
    if not definition then return false, "point inconnu." end
    if Recolte.enAttente[pointId] then return false, "récolte déjà en cours." end
    if Recolte.Proche() ~= p then return false, "tu es trop loin." end
    local entity = LCM.Entities.Self()
    if not entity then return false, "aucun personnage." end

    if definition.metier or definition.dd > 0 then
        local r = Recolte.Jet(entity, definition)
        Annoncer(definition, r)
        if not r.reussi then return false, "jet raté : tu peux retenter." end
    end

    -- Le MJ lui-meme : il est son propre arbitre, et un message a soi-meme ne
    -- revient pas (Reseau ignore ce qu'on s'envoie).
    if definition.auteur == Moi() then
        if not Recolte.Arbitre then return false, "aucun arbitre." end
        local quantite, entree = Recolte.Arbitre(pointId)
        if not quantite then return false, entree or "déjà récolté." end
        local ok, raison = Recolte.Recevoir(pointId, quantite, entree, definition.id)
        if not ok and Recolte.Restituer then Recolte.Restituer(pointId) end
        return ok, raison
    end
    Recolte.enAttente[pointId] = true
    LCM.Reseau.Envoyer(S.prendre, { i = pointId }, "WHISPER", definition.auteur)
    return true
end

-- Demander ce qu'il y a : a la connexion, et en entrant dans un groupe.
function Recolte.Demander()
    local canal = LCM.Combat and LCM.Combat.CanalGroupe and LCM.Combat.CanalGroupe()
    if not canal then return false end
    return LCM.Reseau.Envoyer(S.demande, {}, canal)
end

LCM.WhenReady(function()
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end

    LCM.Reseau.Ecouter(S.definition, function(expediteur, donnees)
        if expediteur == Moi() then return end
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local definition, points = Recolte.Lire(donnees)
        if definition then Recolte.Connaitre(definition, points, expediteur) end
    end)

    LCM.Reseau.Ecouter(S.retrait, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local id, defId = Texte(donnees.i), Texte(donnees.d)
        -- Seul celui qui a pose peut retirer.
        if id ~= "" then
            local p = Recolte.points[id]
            local definition = p and Recolte.definitions[p.def]
            if definition and definition.auteur == expediteur then Recolte.Oublier(id) end
        elseif defId ~= "" then
            local definition = Recolte.definitions[defId]
            if definition and definition.auteur == expediteur then Recolte.OublierDefinition(defId) end
        end
    end)

    LCM.Reseau.Ecouter(S.reponse, function(expediteur, donnees)
        local id = Texte(donnees.i)
        if not Recolte.enAttente[id] then return end
        local p = Recolte.points[id]
        local definition = p and Recolte.definitions[p.def]
        if definition and definition.auteur ~= expediteur then return end
        local quantite = tonumber(donnees.q)
        if not quantite then
            Recolte.enAttente[id] = nil
            Recolte.Oublier(id)
            LCM.Alerte(Texte(donnees.n) ~= "" and Texte(donnees.n) or "ce point a déjà été récolté.")
            return
        end
        local ok, raison = Recolte.Recevoir(id, quantite, Texte(donnees.e), definition and definition.id)
        if not ok then
            LCM.Reseau.Envoyer(S.rendre, { i = id }, "WHISPER", expediteur)
            LCM.Alerte(tostring(raison) .. " Le point reste en place.")
        end
    end)

    -- Le MJ n'a rien a demander : c'est lui qui detient les points.
    if not LCM.IsMaster() then Recolte.Demander() end
end)

LCM.On("GROUP_JOINED", function()
    if not LCM.IsMaster() then Recolte.Demander() end
end)
