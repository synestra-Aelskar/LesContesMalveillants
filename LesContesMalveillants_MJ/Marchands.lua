-- Les marchands poses par le MJ (13 octobre 2026).
--
-- La meme procedure que les points de recolte (MJ/Recoltes.lua) :
--   * le VENDEUR (ses offres, ses prix, son stock) est du contenu : un point
--     de nature « vendeur » (MJ/Points.lua), construit dans le constructeur
--     de vendeur ;
--   * ses EMPLACEMENTS sur la carte sont l'etat du monde, dans la sauvegarde
--     du MJ, comme les Lieux et les points de recolte.
--
-- Le stock de chaque offre est celui de Stock (MJ/Stock.lua) : il repousse et
-- se fusionne entre MJ. Le MJ l'ARBITRE : un achat demande reserve l'unite
-- (EN ATTENTE), le joueur confirme quand il a paye et range, ou la rend. Un
-- achat fait en son absence lui est signale apres coup et entame le stock a
-- ce moment-la.
--
-- Un point de vendeur, lui, ne se consomme pas : pas de statut par point.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local Marchands = {}
LCM.MarchandsMJ = Marchands

local M = LCM.Marchands
local S = M.SUJETS
local R = LCM.Recolte

local function Moi() return LCM.PlayerId() end
local function Cle(v, o) return tostring(v) .. "/" .. tostring(o) end

local function Magasin()
    LCM.EnsureDatabase()
    if type(LCM.db.marchands) ~= "table" then LCM.db.marchands = {} end
    return LCM.db.marchands
end

local compteur = 0
local function Identifiant()
    compteur = (compteur + 1) % 0x1000
    return string.format("m%x%03x%02x", (time and time()) or 0, compteur, math.random(0, 255))
end

local function Canal()
    return LCM.Combat and LCM.Combat.CanalGroupe and LCM.Combat.CanalGroupe()
end

-- ===== Les vendeurs ========================================================

function Marchands.Definition(defId)
    local point = LCM.Points.Get(defId)
    if not point or point.nature ~= "vendeur" then return nil end
    return point
end

function Marchands.Definitions() return LCM.Points.Nature("vendeur") end

-- Les achats accordes et pas encore confirmes : « v/o » -> { [joueur] = n }.
-- En memoire : un achat accorde a un joueur qui se deconnecte avant de
-- confirmer reste reserve jusqu'au prochain /reload du MJ, pas au-dela.
local reserves = {}

function Marchands.EnAttente(defId, offreId)
    local n = 0
    for _, k in pairs(reserves[Cle(defId, offreId)] or {}) do n = n + k end
    return n
end

-- La forme que le joueur recoit : les offres a plat, avec le nom de leur
-- onglet et ce qu'il en reste.
local function Publique(point)
    local definition = { id = point.id, label = point.label, offres = {}, rachats = {}, auteur = Moi() }
    for _, onglet in ipairs(point.onglets or {}) do
        for _, offre in ipairs(onglet.offres or {}) do
            local limite = LCM.Stock.Limite(offre.cle)
            definition.offres[#definition.offres + 1] = {
                id = offre.id, entree = offre.entree, label = offre.label,
                quantite = offre.quantite, formules = offre.formules,
                onglet = onglet.label, limite = limite,
                restant = limite > 0 and LCM.Stock.Restant(offre.cle) or 0,
            }
        end
    end
    for _, onglet in ipairs(point.rachats or {}) do
        for _, offre in ipairs(onglet.offres or {}) do
            definition.rachats[#definition.rachats + 1] = {
                id = offre.id, entree = offre.entree, label = offre.label,
                formules = offre.formules, onglet = onglet.label,
            }
        end
    end
    return definition
end

-- ===== Les emplacements ====================================================

function Marchands.Points(defId)
    local out = {}
    for id, p in pairs(Magasin()) do
        if not defId or p.def == defId then
            out[#out + 1] = { id = id, def = p.def, x = p.x, y = p.y,
                source = p.source, carte = p.carte, quand = p.quand }
        end
    end
    table.sort(out, function(a, b)
        if (a.quand or 0) ~= (b.quand or 0) then return (a.quand or 0) > (b.quand or 0) end
        return a.id > b.id
    end)
    return out
end

function Marchands.Compte(defId)
    local n = 0
    for _, p in pairs(Magasin()) do if p.def == defId then n = n + 1 end end
    return n
end

-- Le MJ connait ses vendeurs aussi en joueur : il peut ouvrir leur etal.
local function Rafraichir(defId)
    local point = Marchands.Definition(defId)
    if point then M.Connaitre(Publique(point), Marchands.Points(defId), Moi())
    else M.OublierDefinition(defId) end
    if Marchands.onChange then pcall(Marchands.onChange, defId) end
end

function Marchands.Diffuser(defId, canal, cible)
    local point = Marchands.Definition(defId)
    if not point then return false end
    canal = canal or Canal()
    if not canal then return false, "hors groupe : le marchand est posé, mais personne ne le voit." end
    return LCM.Reseau.Envoyer(S.definition, M.Paquet(Publique(point), Marchands.Points(defId)),
        canal, cible, { etale = true })
end

function Marchands.Placer(defId)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local point = Marchands.Definition(defId)
    if not point then return nil, "choisis d'abord un marchand." end
    local x, y, source = R.Position()
    if not x then
        local D = LCM.DeplacementForce
        if D and D.DemanderGPS then D.DemanderGPS(true) end
        return nil, "position indisponible : .gps demandé, reclique dans un instant."
    end
    local id = Identifiant()
    Magasin()[id] = { def = point.id, x = x, y = y, source = source, carte = R.Carte(),
        quand = (time and time()) or 0 }
    Rafraichir(point.id)
    Marchands.Diffuser(point.id)
    return id
end

function Marchands.Retirer(id)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p then return false end
    Magasin()[id] = nil
    Rafraichir(p.def)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { i = id }, canal) end
    return true
end

function Marchands.RetirerTout(defId)
    local n = 0
    for id, p in pairs(Magasin()) do
        if p.def == defId then Magasin()[id] = nil n = n + 1 end
    end
    Rafraichir(defId)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { d = defId }, canal) end
    return n
end

-- ===== Le stock ============================================================

local function AnnoncerStock(defId, offre)
    local canal = Canal()
    if canal then
        LCM.Reseau.Envoyer(S.stock, { v = defId, o = offre.id, r = LCM.Stock.Restant(offre.cle) }, canal)
    end
end

-- Reserver une unite pour `par`. Rend vrai et ce qu'il reste, ou nil et la raison.
function Marchands.Accorder(defId, offreId, par)
    local offre, point = LCM.Points.Offre(defId, offreId)
    if not offre or not point or point.nature ~= "vendeur" then return nil, "offre inconnue." end
    if LCM.Stock.Limite(offre.cle) > 0 then
        local ok = LCM.Stock.Consommer(offre.cle, 1)
        if not ok then return nil, "il n'y en a plus." end
    end
    local cle = Cle(defId, offreId)
    reserves[cle] = reserves[cle] or {}
    reserves[cle][par] = (reserves[cle][par] or 0) + 1
    Rafraichir(defId)
    AnnoncerStock(defId, offre)
    return true, LCM.Stock.Restant(offre.cle)
end

local function Liberer(defId, offreId, par)
    local cle = Cle(defId, offreId)
    local parJoueur = reserves[cle]
    if not parJoueur or (parJoueur[par] or 0) < 1 then return false end
    parJoueur[par] = parJoueur[par] - 1
    if parJoueur[par] == 0 then parJoueur[par] = nil end
    if not next(parJoueur) then reserves[cle] = nil end
    return true
end

function Marchands.Confirmer(defId, offreId, par)
    if not Liberer(defId, offreId, par) then return false end
    Rafraichir(defId)
    return true
end

function Marchands.Restituer(defId, offreId, par)
    if not Liberer(defId, offreId, par) then return false end
    local offre = LCM.Points.Offre(defId, offreId)
    if offre and LCM.Stock.Limite(offre.cle) > 0 then LCM.Stock.Rendre(offre.cle, 1) end
    Rafraichir(defId)
    if offre then AnnoncerStock(defId, offre) end
    return true
end

M.Arbitre = Marchands.Accorder
M.Confirmer = Marchands.Confirmer
M.Restituer = Marchands.Restituer

-- ===== Servir ==============================================================

function Marchands.Renvoyer(joueur)
    local n = 0
    for _, point in ipairs(Marchands.Definitions()) do
        if Marchands.Compte(point.id) > 0 then
            if Marchands.Diffuser(point.id, joueur and "WHISPER" or nil, joueur) then n = n + 1 end
        end
    end
    return n
end

local servis = {}
local ARRIVANTS_GROUPES = 3

-- Un membre DECONNECTE reste dans la liste du groupe : a son retour, il
-- n'etait pas « nouveau », et rien ne lui partait (constate en jeu, 13
-- octobre 2026). On retient donc qui est connecte : un nouveau venu est servi
-- tout de suite ; celui qui revient l'est quelques secondes plus tard, le
-- temps que son addon soit pret a ecouter. Il demande aussi de lui-meme a sa
-- connexion — ceci est le filet.
local DELAI_RETOUR = 5

function Marchands.Accueillir()
    local etats = R.Connectes()
    local nouveaux, revenus = {}, {}
    for nom, enLigne in pairs(etats) do
        if enLigne and servis[nom] == nil then nouveaux[#nouveaux + 1] = nom
        elseif enLigne and servis[nom] == false then revenus[#revenus + 1] = nom end
    end
    servis = etats
    for _, nom in ipairs(revenus) do
        R.PlusTard(DELAI_RETOUR, function()
            if R.EnLigne(nom) then Marchands.Renvoyer(nom) end
        end)
    end
    if #nouveaux == 0 then return 0 end
    if #nouveaux > ARRIVANTS_GROUPES then return Marchands.Renvoyer() end
    local n = 0
    for _, nom in ipairs(nouveaux) do n = n + Marchands.Renvoyer(nom) end
    return n
end

function Marchands.Reconstruire()
    local vus = {}
    for _, p in pairs(Magasin()) do
        if not vus[p.def] then
            vus[p.def] = true
            Rafraichir(p.def)
        end
    end
end

LCM.On("GROUP_ROSTER_UPDATE", function()
    if LCM.ready and LCM.IsMaster() then Marchands.Accueillir() end
end)
LCM.On("UNIT_CONNECTION", function()
    if LCM.ready and LCM.IsMaster() then Marchands.Accueillir() end
end)

-- Un vendeur modifie (ou supprime) : ce que J'AI pose se met a jour chez
-- tous, sans le reposer (MJ/Brouillons.lua, SurPoint).
if LCM.Brouillons and LCM.Brouillons.SurPoint then
    LCM.Brouillons.SurPoint(function(defId)
        if Marchands.Compte(defId) == 0 then return end
        Rafraichir(defId)
        if Marchands.Definition(defId) then
            Marchands.Diffuser(defId)
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
        if famille == "points" then Marchands.Reconstruire() end
    end
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(S.demande, function(expediteur)
        if expediteur == Moi() then return end
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        Marchands.Renvoyer(expediteur)
    end)

    LCM.Reseau.Ecouter(S.acheter, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local v, o = tostring(donnees.v or ""), tostring(donnees.o or "")
        local ok, reste = Marchands.Accorder(v, o, expediteur)
        if ok then
            LCM.Reseau.Envoyer(S.reponse, { v = v, o = o, ok = 1, r = reste }, "WHISPER", expediteur)
        else
            local offre = LCM.Points.Offre(v, o)
            LCM.Reseau.Envoyer(S.reponse, { v = v, o = o, n = reste,
                r = offre and LCM.Stock.Restant(offre.cle) or nil }, "WHISPER", expediteur)
        end
    end)

    LCM.Reseau.Ecouter(S.confirmer, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        Marchands.Confirmer(tostring(donnees.v or ""), tostring(donnees.o or ""), expediteur)
    end)

    LCM.Reseau.Ecouter(S.rendre, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        Marchands.Restituer(tostring(donnees.v or ""), tostring(donnees.o or ""), expediteur)
    end)

    -- Achats faits en notre absence : ils entament le stock maintenant, dans la
    -- limite de ce qu'il reste — le joueur a deja ses objets, on ne les lui
    -- reprend pas. On accuse reception de tout ce qu'il a cite.
    LCM.Reseau.Ecouter(S.signaler, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local cites, touches = {}, {}
        for morceau in tostring(donnees.l or ""):gmatch("[^,]+") do
            local v, o, n = morceau:match("^(.+)/(.+):(%d+)$")
            if v then
                cites[#cites + 1] = morceau
                local offre = LCM.Points.Offre(v, o)
                if offre and LCM.Stock.Limite(offre.cle) > 0 then
                    local prendre = math.min(tonumber(n), LCM.Stock.Restant(offre.cle))
                    if prendre > 0 then LCM.Stock.Consommer(offre.cle, prendre) end
                    touches[v] = touches[v] or {}
                    touches[v][#touches[v] + 1] = offre
                end
            end
        end
        for v, offres in pairs(touches) do
            Rafraichir(v)
            for _, offre in ipairs(offres) do AnnoncerStock(v, offre) end
        end
        if #cites > 0 then
            LCM.Reseau.Envoyer(S.accuse, { l = table.concat(cites, ",") }, "WHISPER", expediteur)
        end
    end)

    -- Apres MJ/Brouillons.lua dans le .toc : les vendeurs en brouillon sont
    -- deja recharges (meme piege que les recoltes, lcm_test_recolte_reprise).
    Marchands.Reconstruire()
    Marchands.Accueillir()
end)
