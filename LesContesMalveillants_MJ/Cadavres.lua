-- Les cadavres, cote MJ (le MJ, 3 novembre 2026) : les faire apparaitre a la
-- mort d'un PNJ, corriger leur contenu, et arbitrer la fouille.
--
-- Le MJ tient tout : le contenu (lots actifs ET desactives), le verrou de
-- fouille (un joueur a la fois) et le compte des tentatives. Les joueurs ne
-- recoivent que ce qui est encore prenable (Core/Cadavres.lua).
--
-- Un cadavre est un objet de SEANCE : il vit dans la sauvegarde du MJ (il
-- survit a un /reload), jamais dans la base commune. Il s'efface quand plus
-- rien n'y est a prendre, ou quand le MJ le retire.
local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local C = LCM.Cadavres
local S = C.SUJETS

local Cadavres = {}
MJ.Cadavres = Cadavres
LCM.CadavresMJ = Cadavres

local function Moi() return LCM.PlayerId() end
local function Eq() return LCM.Equilibrage and LCM.Equilibrage.cadavres or {} end
local function Maintenant() return (GetTime and GetTime()) or 0 end

-- Lecture sans rien creer ; l'ecriture cree, et la table vide s'efface.
local function Magasin(ecrire)
    LCM.EnsureDatabase()
    if ecrire and type(LCM.db.cadavres) ~= "table" then LCM.db.cadavres = {} end
    return type(LCM.db.cadavres) == "table" and LCM.db.cadavres or {}
end

function Cadavres.Get(id) return Magasin()[tostring(id or "")] end

function Cadavres.Liste()
    local out = {}
    for _, c in pairs(Magasin()) do out[#out + 1] = c end
    table.sort(out, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return out
end

local function Canal()
    local canal = LCM.Reseau.Diffusable()
    return canal
end

-- Diffuser l'etat a tous, et le connaitre soi-meme (le MJ voit tout).
local function Diffuser(c)
    local moi = C.Lire(C.Paquet(c, true))
    if moi then moi.auteur = Moi(); C.Connaitre(moi) end
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.annonce, C.Paquet(c, false), canal, nil, { etale = true }) end
end
Cadavres.Diffuser = Diffuser

local function Retirer(id)
    local magasin = Magasin()
    if not magasin[id] then return false end
    magasin[id] = nil
    if not next(magasin) then LCM.db.cadavres = nil end
    C.Oublier(id)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { i = id }, canal) end
    if Cadavres.onChange then LCM.Proteger("cadavre", Cadavres.onChange, id) end
    return true
end
Cadavres.Supprimer = function(id) return Retirer(tostring(id or "")) end

local function Libelle(entree)
    local element = LCM.Compendium.Resoudre(entree)
    return element and (element.label or element.id) or tostring(entree), element and element.icone or nil
end

local function NouveauLot(c, section, entree, quantite, dd)
    c.suivant = (tonumber(c.suivant) or 0) + 1
    local label, icone = Libelle(entree)
    local lot = { id = c.suivant, section = section, entree = entree,
        quantite = math.max(1, math.floor(tonumber(quantite) or 1)), label = label, icone = icone,
        essais = 0, actif = true, dd = section == "ventre" and tonumber(dd) or nil }
    c.lots[#c.lots + 1] = lot
    return lot
end

local function Lot(c, lotId)
    lotId = tonumber(lotId) or lotId
    for index, lot in ipairs(c.lots or {}) do
        if lot.id == lotId then return lot, index end
    end
end

-- ===== La mort d'un PNJ ====================================================

-- Un cadavre a la position du MJ, d'apres un PNJ du compendium : ce qu'il
-- porte (`equipement`, celui de l'instance quand il meurt en combat, celui du
-- modele sinon), puis son butin (Sac, Naturel, Ventre). Tout part ACTIF, le
-- MJ corrige ensuite. Rend l'identifiant, ou nil et pourquoi.
local function Poser(modele, nom, icone, equipement, origine)
    local x, y, source, z = LCM.Recolte.Position3D()
    if not (x and y and z) then
        return nil, "ta position est inconnue (il faut l'altitude) : réessaie, ou fais un .gps."
    end
    local id = "cad:" .. tostring(origine or (modele and modele.id) or "?") .. ":" .. tostring((time and time()) or 0)
    -- Deux cadavres du meme PNJ posés dans la meme seconde ne se confondent pas.
    local base, n = id, 2
    while Magasin()[id] do id = base .. "#" .. n; n = n + 1 end
    local c = { id = id, nom = "Cadavre de " .. tostring(nom), icone = icone,
        x = x, y = y, z = z, source = source, carte = LCM.Recolte.Carte and LCM.Recolte.Carte() or nil,
        auteur = Moi(), lots = {}, modele = modele and modele.id or nil }
    for _, ids in pairs(equipement or {}) do
        for _, objetId in ipairs(type(ids) == "table" and ids or {}) do
            NouveauLot(c, "equipe", "objets/" .. tostring(objetId), 1)
        end
    end
    for _, section in ipairs(LCM.SECTIONS_LOOT) do
        for _, ligne in ipairs(modele and modele.loot and modele.loot[section] or {}) do
            NouveauLot(c, section, ligne.entree, ligne.quantite, ligne.dd)
        end
    end
    Magasin(true)[id] = c
    Diffuser(c)
    if Cadavres.onChange then LCM.Proteger("cadavre", Cadavres.onChange, id) end
    return id
end

-- La mort d'un PNJ EN SCENE (le bouton « Mort » du combat et de la Scène).
function Cadavres.Mort(instanceId)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local instance = LCM.Incarnation.Instance(instanceId)
    if not instance then return nil, "ce PNJ n'est plus en scène." end
    if instance.cadavre and Cadavres.Get(instance.cadavre) then
        return nil, "son cadavre est déjà là."
    end
    local id, raison = Poser(LCM.PNJ.Get(instance.modele), instance.name, instance.icon,
        instance.equipement, instance.id)
    if not id then return nil, raison end
    Cadavres.Get(id).pnj = instance.id
    instance.cadavre = id
    return id
end

-- Un cadavre POSE A L'AVANCE, sans combat (le MJ, 3 novembre 2026 : « des
-- creatures deja mortes ») : le PNJ du compendium tient lieu de modele.
function Cadavres.PoserPNJ(pnjId)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local modele = LCM.PNJ.Get(pnjId)
    if not modele then return nil, "choisis d'abord un PNJ du compendium." end
    return Poser(modele, modele.label, modele.icone, modele.equipement, modele.id)
end

-- ===== Les corrections du MJ ===============================================
-- Ce qui sera prenable ou non, a la volee (clic droit dans la fenetre).

function Cadavres.Basculer(id, lotId)
    local c = Cadavres.Get(id)
    local lot = c and Lot(c, lotId)
    if not lot then return false, "objet introuvable." end
    lot.actif = lot.actif == false
    Diffuser(c)
    return true
end

function Cadavres.Quantite(id, lotId, quantite)
    local c = Cadavres.Get(id)
    local lot = c and Lot(c, lotId)
    if not lot then return false, "objet introuvable." end
    local q = tonumber(quantite)
    if not q or q < 1 or q ~= math.floor(q) then return false, "une quantité est un nombre entier, au moins 1." end
    lot.quantite = q
    Diffuser(c)
    return true
end

function Cadavres.Ajouter(id, section, entree, quantite)
    local c = Cadavres.Get(id)
    if not c then return false, "ce cadavre n'est plus là." end
    if not C.Section(section) then return false, "section inconnue." end
    if not LCM.Compendium.Resoudre(entree) then return false, "objet inconnu du compendium." end
    NouveauLot(c, section, entree, quantite)
    Diffuser(c)
    return true
end

function Cadavres.RetirerLot(id, lotId)
    local c = Cadavres.Get(id)
    local _, index = c and Lot(c, lotId)
    if not index then return false, "objet introuvable." end
    table.remove(c.lots, index)
    Diffuser(c)
    return true
end

-- ===== L'arbitrage =========================================================

local function Verrou(c)
    if not c.fouille then return nil end
    if Maintenant() - (tonumber(c.fouille.quand) or 0) > (tonumber(Eq().verrou) or 90) then
        c.fouille = nil
        return nil
    end
    return c.fouille.par
end

-- Plus rien a prendre : le cadavre s'efface, chez tous.
local function Epuiser(c)
    for _, lot in ipairs(c.lots) do if lot.actif ~= false then return false end end
    Retirer(c.id)
    return true
end

-- `par` demande `req` ; rend la reponse a lui renvoyer.
function Cadavres.Traiter(par, req)
    local id = tostring(req and req.i or "")
    local c = Cadavres.Get(id)
    if not c then return { i = id, refus = "ce cadavre n'est plus là." } end
    local action = tostring(req.a or "")
    local tient = Verrou(c)

    if action == "ouvrir" then
        if tient and tient ~= par then
            return { i = id, refus = string.format("%s fouille déjà ce cadavre : attends ton tour.", tostring(tient)) }
        end
        c.fouille = { par = par, quand = Maintenant() }
        Diffuser(c)
        return { i = id, ouvert = 1, etat = C.Paquet(c, par == Moi()) }
    end

    if action == "fermer" then
        if tient == par then c.fouille = nil end
        -- L'etat part a TOUS : ce qui a ete pris ou detruit ne reapparait
        -- chez personne.
        if not Epuiser(c) then Diffuser(c) end
        return { i = id, ferme = 1 }
    end

    if action == "rendre" then
        -- Le joueur n'a pas pu ranger : l'objet revient, actif.
        local entree = tostring(req.e or "")
        if entree ~= "" then
            local lot = NouveauLot(c, tostring(req.s or "sacs"), entree, req.q)
            lot.label = req.n and tostring(req.n) or lot.label
        end
        Diffuser(c)
        return { i = id, etat = C.Paquet(c, par == Moi()) }
    end

    if action ~= "prendre" then return { i = id, refus = "action inconnue." } end
    if tient ~= par then
        return { i = id, refus = tient and string.format("%s fouille déjà ce cadavre : attends ton tour.", tostring(tient))
            or "ouvre d'abord le cadavre." }
    end
    c.fouille.quand = Maintenant()
    local lot, index = Lot(c, req.l)
    if not lot or lot.actif == false then
        return { i = id, refus = "cet objet n'est plus là.", etat = C.Paquet(c, par == Moi()) }
    end
    local section = C.Section(lot.section)
    if C.DD(lot) ~= nil then
        local element = LCM.Compendium.Resoudre(lot.entree)
        local dd = C.DD(lot, element)
        local metiers = element and type(element.metiers) == "table" and element.metiers[1] and element.metiers or nil
        local metierOk = not metiers
        for _, m in ipairs(metiers or {}) do if m == req.m then metierOk = true end end
        if not metierOk or (tonumber(req.t) or 0) < dd then
            lot.essais = (tonumber(lot.essais) or 0) + 1
            local maximum = tonumber(element and element.tentatives)
            if maximum and lot.essais >= maximum then
                local label = lot.label
                -- Les tentatives concernent un exemplaire du lot. Quand il
                -- est detruit, le suivant repart avec son propre compteur.
                lot.quantite = (tonumber(lot.quantite) or 1) - 1
                lot.essais = 0
                if lot.quantite <= 0 then table.remove(c.lots, index) end
                if not Epuiser(c) then Diffuser(c) end
                return { i = id, detruit = label, detruitQuantite = 1,
                    etat = Cadavres.Get(id) and C.Paquet(c, par == Moi()) or nil }
            end
            Diffuser(c)
            return { i = id, rate = 1, reste = maximum and (maximum - lot.essais) or nil,
                     etat = C.Paquet(c, par == Moi()) }
        end
    end
    table.remove(c.lots, index)
    local donne = { k = lot.id, e = lot.entree, q = lot.quantite, s = lot.section, n = lot.label, ic = lot.icone,
                    d = C.DefinitionDe(lot.entree) }
    -- La derniere prise efface le cadavre, chez tous : rien ne reste a fouiller.
    if Epuiser(c) then return { i = id, donne = donne, ferme = 1 } end
    Diffuser(c)
    return { i = id, donne = donne, etat = C.Paquet(c, par == Moi()) }
end
C.Arbitre = function(par, req) return Cadavres.Traiter(par, req) end

-- ===== Le reseau ===========================================================

function Cadavres.Renvoyer(cible)
    for _, c in ipairs(Cadavres.Liste()) do
        LCM.Reseau.Envoyer(S.annonce, C.Paquet(c, false), cible and "WHISPER" or (Canal() or "RAID"), cible,
            { etale = true })
    end
end

LCM.WhenReady(function()
    if not LCM.IsMaster() then return end
    -- Les cadavres de la sauvegarde : on les connait, et on les redit.
    for _, c in ipairs(Cadavres.Liste()) do
        c.fouille = nil
        local moi = C.Lire(C.Paquet(c, true))
        if moi then moi.auteur = Moi(); C.Connaitre(moi) end
    end
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end
    LCM.Reseau.Ecouter(S.demande, function(expediteur)
        if expediteur == Moi() or not LCM.Reseau.Connu(expediteur) then return end
        Cadavres.Renvoyer(expediteur)
    end)
    LCM.Reseau.Ecouter(S.action, function(expediteur, donnees)
        if expediteur == Moi() or not LCM.Reseau.Connu(expediteur) then return end
        local reponse = Cadavres.Traiter(expediteur, donnees)
        if reponse then LCM.Reseau.Envoyer(S.reponse, reponse, "WHISPER", expediteur, { etale = true }) end
    end)
end)
