-- Les panneaux d'affichage poses par le MJ (31 octobre 2026).
--
-- La meme procedure que les vendeurs (MJ/Marchands.lua), sans stock :
--   * le PANNEAU (son support, ses affiches) est du contenu : un point de
--     nature « affichage » (MJ/Points.lua), construit dans l'atelier ;
--   * ses EMPLACEMENTS sont l'etat du monde, dans la sauvegarde du MJ, et
--     partent dans la base commune par la famille des poses (MJ/Poses.lua).
local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local Affichages = {}
LCM.AffichagesMJ = Affichages

local A = LCM.Affichages
local S = A.SUJETS
local R = LCM.Recolte

local function Moi() return LCM.PlayerId() end

local function Magasin()
    LCM.EnsureDatabase()
    if type(LCM.db.panneauxPoses) ~= "table" then LCM.db.panneauxPoses = {} end
    return LCM.db.panneauxPoses
end

local compteur = 0
local function Identifiant()
    compteur = (compteur + 1) % 0x1000
    return string.format("a%x%03x%02x", (time and time()) or 0, compteur, math.random(0, 255))
end

-- Tout le monde (Reseau.Diffusable), comme les vendeurs.
local function Canal() return LCM.Reseau.Diffusable() end

-- ===== Les panneaux ========================================================

function Affichages.Definition(defId)
    local point = LCM.Points.Get(defId)
    if not point or point.nature ~= "affichage" then return nil end
    return point
end

function Affichages.Definitions() return LCM.Points.Nature("affichage") end

function Affichages.Points(defId)
    local out = {}
    for id, p in pairs(Magasin()) do
        if not defId or p.def == defId then
            out[#out + 1] = { id = id, def = p.def, x = p.x, y = p.y, z = p.z,
                source = p.source, carte = p.carte, mapid = p.mapid, quand = p.quand, posePar = p.posePar }
        end
    end
    table.sort(out, function(a, b)
        if (a.quand or 0) ~= (b.quand or 0) then return (a.quand or 0) > (b.quand or 0) end
        return a.id > b.id
    end)
    return out
end

function Affichages.Compte(defId) return #Affichages.Points(defId) end

-- Ce que le joueur recoit d'un panneau : son nom, son support, ses affiches.
local function Publique(point)
    return { id = point.id, label = point.label, support = point.affichage.support,
        affiches = point.affichage.affiches }
end

-- Chaque changement passe ici : il part donc aussi vers la base commune.
local function Noter(defId)
    if not LCM.Poses then return end
    for id, p in pairs(Magasin()) do
        if p.def == defId then LCM.Poses.Noter("affichage", id, p) end
    end
end

-- Le MJ connait ses panneaux aussi en joueur : il peut les lire.
local function Rafraichir(defId)
    Noter(defId)
    local point = Affichages.Definition(defId)
    if point then A.Connaitre(Publique(point), Affichages.Points(defId), Moi())
    else A.OublierDefinition(defId) end
    if Affichages.onChange then LCM.Proteger("panneau", Affichages.onChange, defId) end
end
Affichages.Rafraichir = Rafraichir

function Affichages.Diffuser(defId, canal, cible)
    local point = Affichages.Definition(defId)
    if not point then return false end
    canal = canal or Canal()
    if not canal then return false, "personne à qui l'envoyer : le panneau est posé, mais ni canal ni groupe ne répond." end
    return LCM.Reseau.Envoyer(S.definition, A.Paquet(Publique(point), Affichages.Points(defId)),
        canal, cible, { etale = true })
end

-- Tout ce que j'ai pose, a un joueur (ou a tous). Rend le nombre de panneaux.
function Affichages.Renvoyer(joueur)
    local vus, n = {}, 0
    for _, p in pairs(Magasin()) do
        if not vus[p.def] and Affichages.Definition(p.def) then
            vus[p.def] = true
            local ok
            if joueur then ok = Affichages.Diffuser(p.def, "WHISPER", joueur)
            else ok = Affichages.Diffuser(p.def) end
            if ok then n = n + 1 end
        end
    end
    return n
end

function Affichages.Placer(defId)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local point = Affichages.Definition(defId)
    if not point then return nil, "choisis d'abord un panneau." end
    local x, y, source, z = R.Position3D()
    if not x then
        local D = LCM.DeplacementForce
        if D and D.DemanderGPS then D.DemanderGPS(true) end
        return nil, "position indisponible : .gps demandé, reclique dans un instant."
    end
    local D = LCM.DeplacementForce
    local mapid = source == "gps" and D and D.CarteGPS and tonumber(D.CarteGPS()) or nil
    local id = Identifiant()
    Magasin()[id] = { def = point.id, x = x, y = y, z = z, source = source, carte = R.Carte(),
        mapid = mapid, quand = (time and time()) or 0, posePar = Moi() }
    Rafraichir(point.id)
    Affichages.Diffuser(point.id)
    return id
end

function Affichages.Teleporter(id)
    if not LCM.IsMaster() then return false, "réservé au maître du jeu." end
    local p = Magasin()[tostring(id or "")]
    if not p then return false, "emplacement de panneau introuvable." end
    return LCM.Poses.Teleporter(p)
end

function Affichages.Retirer(id)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p then return false end
    Magasin()[id] = nil
    if LCM.Poses then LCM.Poses.Supprimer(id) end
    Rafraichir(p.def)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { i = id }, canal) end
    return true
end

function Affichages.RetirerTout(defId)
    local n = 0
    for id, p in pairs(Magasin()) do
        if p.def == defId then
            Magasin()[id] = nil
            n = n + 1
            if LCM.Poses then LCM.Poses.Supprimer(id) end
        end
    end
    Rafraichir(defId)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { d = defId }, canal) end
    return n
end

function Affichages.Reconstruire()
    local vus = {}
    for _, p in pairs(Magasin()) do
        if not vus[p.def] then vus[p.def] = true Rafraichir(p.def) end
    end
end

-- Un panneau modifie (ou supprime) : ce que J'AI pose se met a jour chez
-- tous, sans le reposer.
if LCM.Brouillons and LCM.Brouillons.SurPoint then
    LCM.Brouillons.SurPoint(function(defId)
        if Affichages.Compte(defId) == 0 then return end
        Rafraichir(defId)
        if Affichages.Definition(defId) then
            Affichages.Diffuser(defId)
        else
            local canal = Canal()
            if canal then LCM.Reseau.Envoyer(S.retrait, { d = defId }, canal) end
        end
    end)
end

local precedent = LCM.Brouillons and LCM.Brouillons.onSynchro
if LCM.Brouillons then
    LCM.Brouillons.onSynchro = function(famille, entree)
        if precedent then precedent(famille, entree) end
        if famille == "points" then Affichages.Reconstruire() end
    end
end

-- MES panneaux que la base commune connait et qui manquent ici reviennent.
LCM.WhenReady(function()
    local rendus = 0
    for _, pose in ipairs(LCM.Poses and LCM.Poses.De("affichage") or {}) do
        if pose.auteur == Moi() and not Magasin()[pose.id] then
            local e = LCM.Copie(pose.donnees)
            e.id, e.auteur, e.epoque, e.version = nil, nil, nil, nil
            Magasin()[pose.id] = e
            rendus = rendus + 1
        end
    end
    if rendus > 0 then
        LCM.Info(string.format("%d panneau(x) rendu(s) par la base commune.", rendus))
    end
end)

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(S.demande, function(expediteur)
        if expediteur == Moi() then return end
        if not LCM.Reseau.Connu(expediteur) then return end
        Affichages.Renvoyer(expediteur)
    end)
    Affichages.Reconstruire()
end)
