-- Etat autoritaire des coffres poses : leur contenu et leurs verrous sont
-- sauvegardes chez le MJ qui les a places.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local Coffres = {}
LCM.CoffresMJ = Coffres
local C, S, R = LCM.Coffres, LCM.Coffres.SUJETS, LCM.Recolte
-- Tout le monde, et pas seulement le groupe : le canal d'addon que
-- Core/Presence.lua rejoint (silencieux, hors des fenetres de discussion), le
-- groupe en repli. Un joueur hors du raid ne recevait rien, et celui qui y
-- entrait devait recharger (le MJ, 20 octobre 2026).
local function Canal() return LCM.Reseau.Diffusable() end
local function Magasin()
    LCM.EnsureDatabase()
    LCM.db.coffresMJ = type(LCM.db.coffresMJ) == "table" and LCM.db.coffresMJ or {}
    return LCM.db.coffresMJ
end
local function Moi() return LCM.PlayerId() end
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
        n = n + LCM.Coffres.Places(o.entree, o.quantite)
    end
    return n
end

local function PositionServeur()
    local D = LCM.DeplacementForce
    if not (D and D.Position and D.CarteGPS) then return nil end
    local x, y, z, source = D.Position("gps")
    local mapid = D.CarteGPS()
    if source ~= "gps" or not (tonumber(x) and tonumber(y) and tonumber(z) and tonumber(mapid)) then return nil end
    return x, y, z, mapid
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
        if C.onChange then LCM.Proteger("coffre", C.onChange) end
        if C.onReponse then LCM.Proteger("coffre (réponse)", C.onReponse, expediteur, data) end
    else
        LCM.Reseau.Envoyer(S.etat, data, "WHISPER", expediteur)
    end
end

-- ===== La garde =============================================================
-- Le contenu d'un coffre vit chez le MJ qui l'arbitre. Absent, plus personne
-- ne l'ouvrait, et ce qu'il contenait n'existait que dans SA sauvegarde. Les
-- MJ se tiennent donc une COPIE de garde des coffres des autres, a jour a
-- chaque geste ; et quand l'arbitre se tait, un autre reprend la garde avec
-- le contenu tel qu'il etait (le MJ, 21 octobre 2026). Meme idee que le
-- gardien d'un sac au sol (Core/SacsAuSol.lua).
--
-- Chaque coffre pose porte son arbitre (`auteur`), une `epoque` qui monte a
-- chaque reprise de garde, et une `version` qui monte a chaque geste. L'epoque
-- passe d'abord : un MJ qui revient avec sa vieille copie, et y touche avant
-- d'avoir appris la reprise, ne peut pas l'emporter sur elle.
--
-- Un coffre retire laisse une TOMBE (epoque, version) : sans elle, une copie
-- de garde reprise plus tard ferait revenir un coffre qu'on avait enleve.
local G = { copie = "cofg", retrait = "cofg-", pouls = "cofg~" }
Coffres.GARDE = G
-- Un battement toutes les POULS secondes ; muet depuis ABSENCE, un MJ est
-- parti. On n'en juge qu'apres avoir ecoute ABSENCE soi-meme : a la connexion,
-- personne n'a encore eu le temps de battre.
Coffres.POULS = 30
Coffres.ABSENCE = 90
local OUBLI_TOMBES = 30 * 24 * 3600
local SESSION = string.format("%x%04x", (time and time()) or 0, math.random(0, 0xFFFF))
local pairsMJ, debutEcoute = {}, nil

local function Maintenant() return (GetTime and GetTime()) or 0 end
local function Gardes()
    LCM.EnsureDatabase()
    LCM.db.coffresGarde = type(LCM.db.coffresGarde) == "table" and LCM.db.coffresGarde or {}
    return LCM.db.coffresGarde
end
local function Tombes()
    LCM.EnsureDatabase()
    LCM.db.coffresRetires = type(LCM.db.coffresRetires) == "table" and LCM.db.coffresRetires or {}
    return LCM.db.coffresRetires
end

-- `a` est-il plus recent que `b` ? A rang egal entre deux arbitres (deux MJ
-- qui reprennent le meme coffre a la fois), le plus petit nom l'emporte :
-- n'importe quelle regle, pourvu que les deux cotes tranchent pareil.
local function PlusRecent(a, b)
    if not b then return true end
    local ea, eb = tonumber(a.epoque) or 0, tonumber(b.epoque) or 0
    if ea ~= eb then return ea > eb end
    local va, vb = tonumber(a.version) or 0, tonumber(b.version) or 0
    if va ~= vb then return va > vb end
    return tostring(a.auteur or "") < tostring(b.auteur or "")
end
Coffres.PlusRecent = PlusRecent

local function Present(nom)
    local vu = pairsMJ[tostring(nom or "")]
    return vu ~= nil and Maintenant() - vu.quand < Coffres.ABSENCE
end

local function EnvoyerCopie(p, nom)
    return LCM.Reseau.Envoyer(G.copie, { c = LCM.Lien.Serialiser(p) }, "WHISPER", nom, { etale = true })
end
local function EnvoyerTombe(id, tombe, nom)
    return LCM.Reseau.Envoyer(G.retrait, { i = id, e = tombe.epoque, v = tombe.version,
        a = tombe.auteur }, "WHISPER", nom)
end

-- Un geste sur un coffre que j'arbitre : il change de version, et les autres
-- MJ presents en recoivent la copie.
local function Partager(p)
    p.auteur, p.epoque = Moi(), tonumber(p.epoque) or 0
    p.version = (tonumber(p.version) or 0) + 1
    for nom in pairs(pairsMJ) do
        if Present(nom) then EnvoyerCopie(p, nom) end
    end
end

-- Tout ce que je sais, a un MJ qui arrive (ou revient) : mes coffres, mes
-- copies de garde — l'arbitre est peut-etre parti, et c'est alors moi qui
-- sais — et les tombes.
local function Echanger(nom)
    for _, p in pairs(Magasin()) do EnvoyerCopie(p, nom) end
    for _, p in pairs(Gardes()) do EnvoyerCopie(p, nom) end
    for id, tombe in pairs(Tombes()) do EnvoyerTombe(id, tombe, nom) end
end

local function Battre(cible)
    if cible then return LCM.Reseau.Envoyer(G.pouls, { s = SESSION }, "WHISPER", cible) end
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(G.pouls, { s = SESSION }, canal) end
end

function Coffres.RecevoirPouls(expediteur, data)
    if not LCM.IsMaster() or expediteur == Moi() then return end
    local vu = pairsMJ[expediteur]
    -- Nouveau, revenu (autre session : il a recharge), ou de retour d'une
    -- absence : il ne sait peut-etre rien de ce qui a change entre-temps.
    local nouveau = not vu or vu.session ~= data.s or Maintenant() - vu.quand >= Coffres.ABSENCE
    pairsMJ[expediteur] = { quand = Maintenant(), session = data.s }
    if nouveau then
        -- Un battement en retour, pour qu'il me decouvre sans attendre le sien.
        Battre(expediteur)
        Echanger(expediteur)
    end
end

-- Une copie recue d'un autre MJ.
function Coffres.RecevoirCopie(expediteur, e)
    if not LCM.IsMaster() or type(e) ~= "table" or tostring(e.id or "") == "" then return end
    local id = tostring(e.id)
    local tombe = Tombes()[id]
    if tombe and not PlusRecent(e, tombe) then
        EnvoyerTombe(id, tombe, expediteur)
        return
    end
    local mien, garde = Magasin()[id], Gardes()[id]
    local connu = mien or garde
    if not PlusRecent(e, connu) then
        -- Il a une copie plus ancienne que la mienne : on le corrige. Si c'est
        -- moi l'arbitre, il vient peut-etre de l'annoncer aux joueurs en
        -- revenant : on la leur redit.
        if connu and PlusRecent(connu, e) then
            EnvoyerCopie(connu, expediteur)
            if mien then Coffres.Renvoyer() end
        end
        return
    end
    if e.auteur == Moi() then
        Gardes()[id], Magasin()[id] = nil, e
        Coffres.Renvoyer()
        return
    end
    Gardes()[id] = e
    if mien then
        -- La garde est passee a un autre pendant mon absence. Mon contenu
        -- n'est pas efface : sa version plus recente le remplace, et elle
        -- reste ici en copie de garde.
        Magasin()[id] = nil
        local point = C.points[id]
        if point then point.auteur = e.auteur; C.Sauver() end
        local d = Definition(e.def)
        LCM.Info(string.format("« %s » : %s en a repris la garde pendant ton absence.",
            tostring(d and d.label or id), tostring(e.auteur)))
    end
end

function Coffres.RecevoirTombe(expediteur, data)
    if not LCM.IsMaster() then return end
    local id = tostring(data.i or "")
    if id == "" then return end
    local tombe = { epoque = tonumber(data.e) or 0, version = tonumber(data.v) or 0,
        auteur = tostring(data.a or expediteur), quand = time and time() or 0 }
    local ancienne = Tombes()[id]
    if ancienne and not PlusRecent(tombe, ancienne) then return end
    local mien, garde = Magasin()[id], Gardes()[id]
    local connu = mien or garde
    -- Un geste plus recent que le retrait (une reprise de garde ignoree de
    -- celui qui l'a retire) : le coffre reste, on le redit.
    if connu and PlusRecent(connu, tombe) then
        EnvoyerCopie(connu, expediteur)
        return
    end
    Tombes()[id] = tombe
    Gardes()[id] = nil
    if mien then Magasin()[id] = nil; C.Oublier(id) end
end

-- Les arbitres muets : je reprends la garde de leurs coffres.
function Coffres.Veiller()
    if not LCM.IsMaster() or not debutEcoute
        or Maintenant() - debutEcoute < Coffres.ABSENCE then return 0 end
    local repris = 0
    for id, e in pairs(Gardes()) do
        if e.auteur ~= Moi() and not Present(e.auteur) then
            local ancien = e.auteur
            Gardes()[id] = nil
            e.epoque = (tonumber(e.epoque) or 0) + 1
            e.version = 0
            Magasin()[id] = e
            Partager(e)
            repris = repris + 1
            local d = Definition(e.def)
            LCM.Info(string.format("« %s » : %s est absent, tu en reprends la garde.",
                tostring(d and d.label or id), tostring(ancien)))
        end
    end
    if repris > 0 then Coffres.Renvoyer() end
    return repris
end

-- Les tombes d'un mois s'oublient : aucune copie de garde n'a survecu aussi
-- longtemps sans croiser son retrait.
local function OublierTombes()
    local maintenant = time and time() or 0
    for id, tombe in pairs(Tombes()) do
        if maintenant - (tonumber(tombe.quand) or 0) > OUBLI_TOMBES then Tombes()[id] = nil end
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

-- `position` : { x, y, z, source, carte, mapid } — la ou poser. Sans elle, la ou se
-- tient le MJ. Un sac lache au sol se pose la ou le joueur l'a lache.
function Coffres.Placer(defId, position)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local d = Definition(defId)
    if not d then return nil, "choisis d'abord un coffre configuré." end
    local x, y, z, source, carte, mapid
    if position then
        x, y, z, source, carte, mapid = position.x, position.y, position.z,
            position.source, position.carte, position.mapid
    else
        x, y, z, mapid = PositionServeur()
        source = "gps"
        carte = R.Carte()
    end
    if not x or z == nil or (not position and not mapid) or source == "carte" then
        if LCM.DeplacementForce and LCM.DeplacementForce.DemanderGPS then LCM.DeplacementForce.DemanderGPS(true) end
        return nil, "position serveur indisponible : .gps demandé, reclique après sa réponse."
    end
    local contents = {}
    for _, o in ipairs(d.coffre.objets or {}) do contents[#contents + 1] = LCM.Copie(o) end
    if Cases(contents) > d.coffre.places then return nil, "le contenu configuré dépasse le nombre d'emplacements." end
    local id = Identifiant()
    Magasin()[id] = { id = id, def = d.id, x = x, y = y, z = z, source = source,
        carte = carte, mapid = mapid, quand = time and time() or 0, objets = contents,
        verrousRestants = d.coffre.verrous, verrouille = d.coffre.verrous > 0,
        ouvert = d.coffre.verrous == 0, verrousOuverts = {} }
    Partager(Magasin()[id])
    Coffres.Renvoyer()
    return id
end

function Coffres.Teleporter(id)
    if not LCM.IsMaster() then return false, "réservé au maître du jeu." end
    local p = Magasin()[tostring(id or "")]
    if not p then return false, "coffre placé introuvable." end
    local x, y, z, mapid = tonumber(p.x), tonumber(p.y), tonumber(p.z), tonumber(p.mapid)
    if not x or not y or z == nil or p.source == "carte" then
        return false, "coordonnées 3D indisponibles : replace ce coffre pour pouvoir t'y téléporter."
    end
    -- Les anciens placements pouvaient retenir Z=0 et l'id de carte d'UI
    -- plutot que la carte serveur. Ne reparer que depuis le coffre lui-meme.
    if not mapid or (p.source == "monde" and z == 0) then
        local gx, gy, gz, gm = PositionServeur()
        if gx and p.carte == R.Carte() and math.abs(gx - x) <= 3 and math.abs(gy - y) <= 3 then
            p.x, p.y, p.z, p.mapid, p.source = gx, gy, gz, gm, "gps"
            x, y, z, mapid = gx, gy, gz, gm
            Partager(p)
            Coffres.Renvoyer()
        else
            if LCM.DeplacementForce and LCM.DeplacementForce.DemanderGPS then LCM.DeplacementForce.DemanderGPS(true) end
            return false, "ancien emplacement sans altitude ou carte serveur fiable : va près du coffre, attends la réponse .gps puis reclique, ou replace-le."
        end
    end
    local function Coord(n) return string.format("%.6f", n):gsub(",", ".") end
    -- .gps et .worldport utilisent le meme ordre X, Y sur le serveur.
    local commande = ".worldport " .. Coord(x) .. " " .. Coord(y)
    if z then
        commande = commande .. " " .. Coord(z)
        if mapid then commande = commande .. " " .. tostring(math.floor(mapid)) end
    end
    if not (LCM.DeplacementForce and LCM.DeplacementForce.Commande
        and LCM.DeplacementForce.Commande(commande)) then
        return false, "commande de téléportation non envoyée."
    end
    return true
end

function Coffres.Retirer(id)
    local p = Magasin()[tostring(id or "")]
    if not p then return false end
    Magasin()[p.id] = nil
    local tombe = { epoque = tonumber(p.epoque) or 0, version = (tonumber(p.version) or 0) + 1,
        auteur = Moi(), quand = time and time() or 0 }
    Tombes()[p.id] = tombe
    for nom in pairs(pairsMJ) do
        if Present(nom) then EnvoyerTombe(p.id, tombe, nom) end
    end
    -- Le client du MJ ignore ses propres messages réseau : sans retrait local,
    -- le coffre supprimé restait visible jusqu'au prochain rechargement.
    C.Oublier(p.id)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { i = p.id }, canal) end
    Coffres.Renvoyer()
    return true
end

-- Un sac lache au sol, que le MJ SECURISE (Core/SacsAuSol.lua) : il devient
-- une vraie entree « Coffre » (« Sac de gros de Blud'Sh'Idah »), posee la ou
-- le sac a ete lache, avec ce qu'il contient encore. `sol` : l'etat du sac au
-- sol tel que ses gardiens se le transmettent. Rend l'emplacement du coffre,
-- ou nil et la raison.
function Coffres.DepuisSol(sol)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local objets = {}
    for _, o in ipairs(sol.objets or {}) do
        objets[#objets + 1] = { entree = o.entree, quantite = o.quantite }
    end
    local definition = {
        id = LCM.Brouillons.NouvelIdentifiant(), nature = "coffre", label = sol.label,
        description = "Lâché au sol par " .. tostring(sol.auteur or "?") .. ".",
        coffre = {
            -- Assez de places pour ce qu'il contient : celles du sac, au moins.
            places = math.max(1, tonumber(sol.places) or 1, Cases(objets)),
            verrous = 0, reset = false, objets = objets, expertises = {}, outils = {},
            sac = sol.sac, tente = sol.tente, objet = sol.objet or nil,
        },
    }
    local ok, raison = LCM.Brouillons.Enregistrer("points", definition, true)
    if not ok then return nil, raison end
    return Coffres.Placer(definition.id, sol.position)
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
    Partager(p)
    local canal = Canal()
    -- `p` vient de mon magasin : c'est moi qui l'arbitre.
    if p.id == C.courant then
        C.etat = Etat(p)
        if C.onChange then LCM.Proteger("coffre", C.onChange) end
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
    -- L'edition venait forcement de MA machine : un autre MJ se faisait
    -- repondre « edition reservee au MJ » sur un coffre que j'avais pose (le
    -- MJ, 20 octobre 2026). Editer est un geste de MJ, pas un privilege de
    -- proprietaire.
    --
    -- On ne PROUVE pas qu'un expediteur est MJ : aucun message ne le peut, et
    -- les brouillons de contenu, qu'un autre MJ redefinit deja, reposent sur
    -- la meme confiance. Ce qui tient : la demande vient de quelqu'un de connu
    -- (Core/Coffres.lua le verifie avant d'appeler ici), et c'est MOI qui
    -- arbitre et qui sauvegarde.
    local editionMJ = req.edition == true
    -- Un ajout depuis le compendium CREE un exemplaire : geste de MJ, en mode
    -- edition ou sur sa propre machine (19 puis 20 octobre 2026).
    local compendiumMJ = editionMJ or (LCM.IsMaster() and expediteur == LCM.PlayerId())
    if req.a == "ajouter_compendium" and not compendiumMJ then
        Repondre(false, { msg = "sortir un objet du compendium est un geste du maître du jeu." })
        return
    end
    if req.a == "editer" then
        if not editionMJ then Repondre(false, { msg = "édition réservée au MJ." }); return end
        Repondre(true)
        return
    end
    if req.a == "reset_verrous" then
        if not editionMJ then Repondre(false, { msg = "réinitialisation réservée au MJ." }); return end
        local total = tonumber(d.coffre.verrous) or 0
        p.verrousRestants, p.verrouille = total, total > 0
        p.ouvert, p.verrousOuverts = total == 0, {}
        MettreAJour(p); Repondre(true)
        return
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
    if (not p.ouvert or p.verrouille) and not editionMJ then
        Repondre(false, { msg = "le coffre est verrouillé." }); return
    end
    if req.a == "prendre" then
        local ref, n = tostring(req.e or ""), math.max(1, math.floor(tonumber(req.q) or 1))
        for index, o in ipairs(p.objets or {}) do
            if o.entree == ref and (tonumber(o.quantite) or 0) >= n then
                o.quantite = o.quantite - n
                if o.quantite == 0 then table.remove(p.objets, index) end
                local element = LCM.Compendium.Resoudre(ref)
                MettreAJour(p)
                Repondre(true, { e = ref, q = n,
                    objet = (LCM.Livres and LCM.Livres.Definition(ref))
                        or (LCM.Echange and LCM.Echange.DefinitionObjet(ref)) })
                return
            end
        end
        Repondre(false, { msg = "il n'y en a plus assez." }); return
    end
    -- Ramasser le sac EN ENTIER : il n'est plus un coffre. Ce qu'il contient
    -- encore part avec lui ; le coffre quitte le monde et la base (le MJ,
    -- 16 octobre 2026). On repond AVANT de retirer : le retrait ferme la
    -- fenetre du demandeur.
    if req.a == "emporter" then
        if not (d.coffre.sac or d.coffre.tente or d.coffre.objet) then
            Repondre(false, { msg = "ce coffre ne se ramasse pas." }); return
        end
        local objets = {}
        for _, o in ipairs(p.objets or {}) do
            objets[#objets + 1] = { e = o.entree, q = o.quantite,
                d = (LCM.Livres and LCM.Livres.Definition(o.entree))
                    or (LCM.Echange and LCM.Echange.DefinitionObjet(o.entree)) or nil }
        end
        -- `w`, pas `o` : la reponse porte deja l'etat du coffre sous `o`.
        Repondre(true, { b = d.coffre.sac, t = d.coffre.tente, w = objets })
        Coffres.Retirer(p.id)
        if #Coffres.Points(d.id) == 0 then LCM.Brouillons.Supprimer("points", d.id) end
        return
    end
    if req.a == "ranger" or req.a == "ajouter_compendium" then
        local ref, n = tostring(req.e or ""), math.max(1, math.floor(tonumber(req.q) or 1))
        local accueilli, pourquoi = LCM.Coffres.Accepte(ref)
        if not accueilli then
            Repondre(false, { msg = pourquoi or "objet inconnu." }); return
        end
        local found
        for _, o in ipairs(p.objets) do if o.entree == ref then found = o break end end
        local places = Cases(p.objets)
        local dedans = found and (tonumber(found.quantite) or 0) or 0
        local ajoutePlaces = LCM.Coffres.Places(ref, dedans + n) - LCM.Coffres.Places(ref, dedans)
        if places + ajoutePlaces > d.coffre.places then
            Repondre(false, { msg = "le coffre n'a pas assez d'emplacements." }); return
        end
        if found then found.quantite = found.quantite + n
        else p.objets[#p.objets + 1] = { entree = ref, quantite = n } end
        MettreAJour(p); Repondre(true); return
    end
end

LCM.WhenReady(function()
    -- Les demandes « cof! » arrivent par l'aiguilleur de Core/Coffres.lua, qui
    -- les passe ici quand elles ne visent pas un sac au sol garde par un joueur.
    -- Un coffre modifie (ou supprime) : ce que J'AI pose se met a jour chez
    -- tous, sans le reposer (MJ/Brouillons.lua, SurPoint). Ce crochet passe
    -- par l'enregistrement lui-meme, en seance comme a la reception : l'ancien
    -- (onSynchro) ne voyait que ce qui venait de l'autre MJ.
    if LCM.Brouillons and LCM.Brouillons.SurPoint then
        LCM.Brouillons.SurPoint(function(defId)
            local poses = Coffres.Points(defId)
            if #poses == 0 then return end
            if Definition(defId) then Coffres.Renvoyer() return end
            local canal = Canal()
            for _, p in ipairs(poses) do
                C.Oublier(p.id)
                if canal then LCM.Reseau.Envoyer(S.retrait, { i = p.id }, canal) end
            end
        end)
    end

    -- Les placements vivent dans la sauvegarde MJ, tandis que le détecteur de
    -- proximité appartient au module joueur. Après un /reload, sa copie locale
    -- est volontairement vide : republier ici restaure les boutons « Ouvrir »
    -- sans obliger le MJ à déplacer ou réenregistrer chaque coffre.
    --
    -- Ce qui est dans mon magasin, je l'arbitre — y compris un coffre pose
    -- avant que la garde existe, ou sous un autre de mes personnages.
    for _, p in pairs(Magasin()) do
        p.auteur, p.epoque, p.version = Moi(), tonumber(p.epoque) or 0, tonumber(p.version) or 0
    end
    OublierTombes()
    Coffres.Renvoyer()

    LCM.Reseau.Ecouter(G.pouls, Coffres.RecevoirPouls)
    LCM.Reseau.Ecouter(G.copie, function(expediteur, data)
        if not LCM.Reseau.Connu(expediteur) then return end
        local e = LCM.Lien.Deserialiser(data.c)
        if type(e) ~= "table" then return end
        e.objets, e.verrousOuverts = e.objets or {}, e.verrousOuverts or {}
        Coffres.RecevoirCopie(expediteur, e)
    end)
    LCM.Reseau.Ecouter(G.retrait, function(expediteur, data)
        if LCM.Reseau.Connu(expediteur) then Coffres.RecevoirTombe(expediteur, data) end
    end)

    -- Le battement part des que le canal repond, puis a intervalle fixe ; la
    -- veille des arbitres muets suit le meme rythme.
    if LCM.Presence and LCM.Presence.QuandCanal then
        LCM.Presence.QuandCanal(function()
            debutEcoute = debutEcoute or Maintenant()
            Battre()
        end)
    end
    if CreateFrame then
        local h = CreateFrame("Frame")
        h.cumul = 0
        h:SetScript("OnUpdate", function(self, dt)
            self.cumul = self.cumul + (tonumber(dt) or 0)
            if self.cumul < Coffres.POULS then return end
            self.cumul = 0
            if not LCM.IsMaster() then return end
            debutEcoute = debutEcoute or Maintenant()
            Battre()
            Coffres.Veiller()
        end)
        Coffres.horlogeGarde = h
    end
end)

