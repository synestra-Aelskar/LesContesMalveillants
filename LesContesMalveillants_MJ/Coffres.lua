-- Etat autoritaire des coffres poses : leur contenu et leurs verrous sont
-- sauvegardes chez le MJ qui les a places.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local Coffres = {}
LCM.CoffresMJ = Coffres
local C, S, R = LCM.Coffres, LCM.Coffres.SUJETS, LCM.Recolte
local function Canal() return LCM.Combat and LCM.Combat.CanalGroupe() end
local function Magasin()
    LCM.EnsureDatabase()
    LCM.db.coffresMJ = type(LCM.db.coffresMJ) == "table" and LCM.db.coffresMJ or {}
    return LCM.db.coffresMJ
end
local compteur = 0
local function Identifiant()
    compteur = compteur + 1
    return string.format("c%x%03x%02x", (time and time()) or 0, compteur % 4096, math.random(0,255))
end

local function Definition(id)
    local d = LCM.Points.Get(id)
    return d and d.nature == "coffre" and d.coffre and d or nil
end

local function Cases(objets)
    local n = 0
    for _, o in ipairs(objets or {}) do
        local e = LCM.Compendium.Resoudre(o.entree)
        local pile = math.max(1, tonumber(e and e.pileMax) or 1)
        n = n + math.ceil((tonumber(o.quantite) or 0) / pile)
    end
    return n
end

local function Etat(p)
    return { i = p.id, o = LCM.Copie(p.objets or {}), v = p.verrousRestants or 0,
        f = p.verrouille == true, s = p.ouvert == true,
        vo = LCM.Copie(p.verrousOuverts or {}) }
end

local function Envoyer(expediteur, p, ok, extra)
    local data = Etat(p)
    data.ok = ok == true
    for k, v in pairs(extra or {}) do data[k] = v end
    if expediteur == LCM.PlayerId() then
        C.etat = data
        if C.onChange then pcall(C.onChange) end
        if C.onReponse then pcall(C.onReponse, expediteur, data) end
    else
        LCM.Reseau.Envoyer(S.etat, data, "WHISPER", expediteur)
    end
end

function Coffres.Renvoyer(joueur)
    local n = 0
    for _, d in ipairs(LCM.Points.Nature("coffre")) do
        local points = {}
        for id, p in pairs(Magasin()) do
            if p.def == d.id then points[#points + 1] = p end
        end
        if #points > 0 then
            local publique = LCM.Copie(d)
            publique.auteur = LCM.PlayerId()
            C.Connaitre(publique, LCM.Copie(points), LCM.PlayerId())
            LCM.Reseau.Envoyer(S.definition, C.Paquet(publique, points),
                joueur and "WHISPER" or Canal(), joueur, { etale = true })
            n = n + 1
        end
    end
    return n
end

function Coffres.Placer(defId)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local d = Definition(defId)
    if not d then return nil, "choisis d'abord un coffre configuré." end
    local x, y, source = R.Position()
    if not x then
        if LCM.DeplacementForce and LCM.DeplacementForce.DemanderGPS then LCM.DeplacementForce.DemanderGPS(true) end
        return nil, "position indisponible : .gps demandé, reclique dans un instant."
    end
    local contents = {}
    for _, o in ipairs(d.coffre.objets or {}) do contents[#contents + 1] = LCM.Copie(o) end
    if Cases(contents) > d.coffre.places then return nil, "le contenu configuré dépasse le nombre d'emplacements." end
    local id = Identifiant()
    Magasin()[id] = { id = id, def = d.id, x = x, y = y, source = source,
        carte = R.Carte(), quand = time and time() or 0, objets = contents,
        verrousRestants = d.coffre.verrous, verrouille = d.coffre.verrous > 0,
        ouvert = d.coffre.verrous == 0, verrousOuverts = {} }
    Coffres.Renvoyer()
    return id
end

function Coffres.Retirer(id)
    local p = Magasin()[tostring(id or "")]
    if not p then return false end
    Magasin()[p.id] = nil
    -- Le client du MJ ignore ses propres messages réseau : sans retrait local,
    -- le coffre supprimé restait visible jusqu'au prochain rechargement.
    C.Oublier(p.id)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { i = p.id }, canal) end
    Coffres.Renvoyer()
    return true
end

function Coffres.Points(defId)
    local out = {}
    for id, p in pairs(Magasin()) do
        if not defId or p.def == defId then out[#out + 1] = p end
    end
    table.sort(out, function(a,b) return (a.quand or 0) > (b.quand or 0) end)
    return out
end

local function MettreAJour(p)
    local canal = Canal()
    if p.id == C.courant and LCM.PlayerId() == (C.definitions[p.def] or {}).auteur then
        C.etat = Etat(p)
        if C.onChange then pcall(C.onChange) end
    end
    if canal then
        local data = Etat(p)
        LCM.Reseau.Envoyer(S.etat, data, canal)
    end
end

function Coffres.Traiter(expediteur, req)
    local p = Magasin()[tostring(req.i or "")]
    local d = p and Definition(p.def)
    if not p or not d then return end
    local function Repondre(ok, extra)
        extra = extra or {}
        if extra.action == nil then extra.action = req.a end
        Envoyer(expediteur, p, ok, extra)
    end
    if req.a == "ouvrir" then
        if not p.verrouille then p.ouvert = true; MettreAJour(p) end
        Repondre(true)
        return
    end
    if req.a == "fermer" then
        p.ouvert = false
        if d.coffre.reset and d.coffre.verrous > 0 then
            p.verrouille, p.verrousRestants = true, d.coffre.verrous
            p.verrousOuverts = {}
        end
        MettreAJour(p); Repondre(true); return
    end
    if req.a == "verrouiller" then
        local permis = not d.coffre.reset and #(p.verrousOuverts or {}) > 0
        for _, relockable in ipairs(p.verrousOuverts or {}) do
            if not relockable then permis = false; break end
        end
        if not permis then Repondre(false, { msg = "aucun verrou ne peut être replacé." }); return end
        p.verrousRestants, p.verrouille, p.ouvert = d.coffre.verrous, true, false
        p.verrousOuverts = {}
        MettreAJour(p); Repondre(true); return
    end
    if req.a == "forcer" then
        local score = tonumber(req.score or req.total)
        if not p.verrouille or not score or score < 0 then Repondre(false); return end
        local choisi
        for _, m in ipairs(d.coffre.expertises or {}) do
            if m.id == tostring(req.expertise or "") then choisi = m break end
        end
        local dd = choisi and (tonumber(choisi.dd) or 0) or nil
        local avecClef = choisi and choisi.id == C.METHODE_CLEF
        if not choisi or (not avecClef and score < dd) then
            Repondre(false, { msg = choisi and "échec du jet." or "expertise non autorisée." }); return
        end
        p.verrousRestants = math.max(0, (tonumber(p.verrousRestants) or d.coffre.verrous) - 1)
        p.verrousOuverts = p.verrousOuverts or {}
        p.verrousOuverts[#p.verrousOuverts + 1] = choisi.reverrouillable == true
        if p.verrousRestants == 0 then p.verrouille, p.ouvert = false, true end
        MettreAJour(p); Repondre(true, { resultat = "réussite", expertise = choisi.id, total = score })
        return
    end
    if not p.ouvert or p.verrouille then Repondre(false, { msg = "le coffre est verrouillé." }); return end
    if req.a == "prendre" then
        local ref, n = tostring(req.e or ""), math.max(1, math.floor(tonumber(req.q) or 1))
        for index, o in ipairs(p.objets or {}) do
            if o.entree == ref and (tonumber(o.quantite) or 0) >= n then
                o.quantite = o.quantite - n
                if o.quantite == 0 then table.remove(p.objets, index) end
                local element = LCM.Compendium.Resoudre(ref)
                MettreAJour(p)
                Repondre(true, { e = ref, q = n,
                    objet = LCM.Echange and LCM.Echange.DefinitionObjet(ref) })
                return
            end
        end
        Repondre(false, { msg = "il n'y en a plus assez." }); return
    end
    if req.a == "ranger" then
        local ref, n = tostring(req.e or ""), math.max(1, math.floor(tonumber(req.q) or 1))
        if not ref:match("^objets/") or not LCM.Compendium.Resoudre(ref) then
            Repondre(false, { msg = "objet inconnu." }); return
        end
        local found
        for _, o in ipairs(p.objets) do if o.entree == ref then found = o break end end
        local entree = LCM.Compendium.Resoudre(ref)
        local pile = math.max(1, tonumber(entree and entree.pileMax) or 1)
        local places = Cases(p.objets)
        local ajoutePlaces = found and (math.ceil(((tonumber(found.quantite) or 0) + n) / pile)
            - math.ceil((tonumber(found.quantite) or 0) / pile)) or math.ceil(n / pile)
        if places + ajoutePlaces > d.coffre.places then
            Repondre(false, { msg = "le coffre n'a pas assez d'emplacements." }); return
        end
        if found then found.quantite = found.quantite + n
        else p.objets[#p.objets + 1] = { entree = ref, quantite = n } end
        MettreAJour(p); Repondre(true); return
    end
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(S.action, function(expediteur, data)
        if LCM.Reseau.DansLeGroupe(expediteur) then Coffres.Traiter(expediteur, data) end
    end)
    local precedent = LCM.Brouillons and LCM.Brouillons.onSynchro
    if LCM.Brouillons then LCM.Brouillons.onSynchro = function(famille, entree)
        if precedent then precedent(famille, entree) end
        if famille == "points" and entree and entree.nature == "coffre" then Coffres.Renvoyer() end
    end end

    -- Les placements vivent dans la sauvegarde MJ, tandis que le détecteur de
    -- proximité appartient au module joueur. Après un /reload, sa copie locale
    -- est volontairement vide : republier ici restaure les boutons « Ouvrir »
    -- sans obliger le MJ à déplacer ou réenregistrer chaque coffre.
    Coffres.Renvoyer()
end)

