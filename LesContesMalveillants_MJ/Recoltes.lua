-- Les points de recolte poses par le MJ (13 octobre 2026).
--
-- Deux choses distinctes, et il ne faut pas les confondre :
--   * la DEFINITION (« Miner du fer » : quelles ressources, combien, quel jet) est
--     du contenu. C'est un point de nature « ressource » (MJ/Points.lua), cree
--     dans l'atelier et exporte comme le reste ;
--   * les POINTS POSES sont l'etat du monde : ici, ici et ici, et chacun
--     garde ses usages et ses delais, puis s'epuise selon sa limite. Ils vivent
--     dans la sauvegarde du MJ,
--     comme les Lieux, parce qu'ils changent a chaque recolte — un fichier
--     publie ne peut pas suivre un filon qu'on vide en seance.
--
-- Les joueurs n'ont rien de tout cela : ils demandent (Core/Recolte.lua), le MJ
-- repond en silence, et c'est le MJ qui ARBITRE chaque prise.
--
-- Limite connue, la meme que les Lieux : deux MJ qui posent chacun de leur
-- cote ne fusionnent pas leurs points. Chacun arbitre les siens.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local Recoltes = {}
LCM.Recoltes = Recoltes

local R = LCM.Recolte
local S = R.SUJETS

local function Moi() return LCM.PlayerId() end

local function Magasin()
    LCM.EnsureDatabase()
    if type(LCM.db.recoltes) ~= "table" then LCM.db.recoltes = {} end
    return LCM.db.recoltes
end

-- Court : il voyage pour chaque point, dans une chaine « id,x,y,… ».
local compteur = 0
local function Identifiant()
    compteur = (compteur + 1) % 0x1000
    return string.format("r%x%03x%02x", (time and time()) or 0, compteur, math.random(0, 255))
end

local function Canal()
    -- Tout le monde (Reseau.TOUS), et pas seulement le groupe : voir
    -- Core/Presence.lua et le 20 octobre 2026.
    return LCM.Reseau.Diffusable()
end

-- ===== Les definitions =====================================================

-- Une definition est posable si elle dit quoi donner.
function Recoltes.Definition(defId)
    local point = LCM.Points.Get(defId)
    if not point or point.nature ~= "ressource" or not point.recolte then return nil end
    return point
end

function Recoltes.Definitions()
    local out = {}
    for _, point in ipairs(LCM.Points.Nature("ressource")) do
        if point.recolte then out[#out + 1] = point end
    end
    return out
end

-- La forme que le joueur recoit (Core/Recolte.lua).
local function Publique(point)
    local r = point.recolte
    return {
        id = point.id, label = point.label, entree = r.entree,
        min = r.min, max = r.max, metier = r.metier, dd = r.dd, rayon = r.rayon,
        ressources = r.ressources, metiers = r.metiers,
        limite = r.limite, auteur = Moi(),
        echecConsomme = r.echecConsomme,
    }
end

-- ===== Les points poses ====================================================

-- Un point a un STATUT :
--   CREE        (`statut` absent) il est la ;
--   EN ATTENTE  le MJ a accorde la prise, le joueur n'a pas encore confirme
--               qu'il a range sa part. Il n'est plus envoye a personne ; s'il
--               ne peut pas ranger, le point repasse a CREE ;
--   RECOLTE     le joueur a confirme, ou il a signale apres coup un point
--               recolte en l'absence du MJ (Core/Recolte.lua).
-- Un point recolte reste au carnet, avec qui et quand : il n'est plus jamais
-- envoye, et c'est lui qu'une future repousse remettra a CREE.

-- ===== Ce qu'un point pose donne ===========================================
-- Le MODELE est un catalogue : tout ce que ce genre de point PEUT donner
-- (« Récolter la pierre » : huit pierres). Un point pose part TOUT ETEINT
-- (20 octobre 2026) : le MJ l'ouvre (clic droit sur « Récolter ») et allume,
-- ligne par ligne, ce que CE point donne, avec sa chance, sa quantite et sa
-- repousse a lui.
--
--     p.lignes = { ["ressources/granit"] = { actif = true, chance = 100, min = 1, … } }
--
-- Par REFERENCE et non par rang : reordonner le modele ne melange pas les
-- reglages. Une ligne que le modele n'a plus n'est plus rien ; une ligne
-- ajoutee au modele arrive eteinte sur les points deja poses.
--
-- Un point pose avant ce jour n'a pas de `lignes` : il donne tout son
-- modele, comme avant. On ne l'eteint pas dans le dos du MJ.

local CHAMPS_LIGNE = { "min", "max", "aleatoire", "chance", "regeneration", "minutes" }

function Recoltes.Effectives(p, recolte)
    local modele = R.Ressources(recolte or {})
    if type(p) ~= "table" or type(p.lignes) ~= "table" then return modele end
    local out = {}
    for _, lot in ipairs(modele) do
        local regle = p.lignes[lot.entree]
        if type(regle) == "table" and regle.actif == true then
            local ligne = LCM.Copie(lot)
            for _, champ in ipairs(CHAMPS_LIGNE) do
                if regle[champ] ~= nil then ligne[champ] = regle[champ] end
            end
            out[#out + 1] = ligne
        end
    end
    return out
end

-- Le point tel que la recolte le lit : une copie, avec son contenu effectif.
local function Vue(p, point)
    local vue = {}
    for k, v in pairs(p) do vue[k] = v end
    if type(p.lignes) == "table" then
        vue.ressources = Recoltes.Effectives(p, point and point.recolte)
        vue.vide = #vue.ressources == 0 or nil
    end
    return vue
end

-- Tout le carnet d'une definition, recoltes compris.
function Recoltes.Carnet(defId)
    local out = {}
    for id, p in pairs(Magasin()) do
        if not defId or p.def == defId then
            local point = Recoltes.Definition(p.def)
            local vue = Vue(p, point)
            local actif = point and R.Disponible(vue, point.recolte) or false
            local retour
            if point and not actif and not p.statut then
                for _, date in pairs(p.prochain or {}) do
                    date = tonumber(date)
                    if date and date > ((time and time()) or 0) and (not retour or date < retour) then
                        retour = date
                    end
                end
            end
            out[#out + 1] = { id = id, def = p.def, x = p.x, y = p.y, z = p.z,
                source = p.source, carte = p.carte, quand = p.quand,
                statut = p.statut or "cree", par = p.par, le = p.le,
                usages = p.usages, consomme = p.consomme, prochain = p.prochain,
                ressources = vue.ressources, vide = vue.vide, lignes = p.lignes,
                actif = actif, retour = retour }
        end
    end
    -- Du plus recent au plus ancien : celui qu'on vient de poser en tete.
    table.sort(out, function(a, b)
        if (a.quand or 0) ~= (b.quand or 0) then return (a.quand or 0) > (b.quand or 0) end
        return a.id > b.id
    end)
    return out
end

-- Les points encore la : les seuls qu'on envoie. Un point tout eteint ne
-- part a personne — il ne donne rien —, sauf au MJ lui-meme (`avecVides`),
-- qui doit pouvoir le trouver en jeu pour le regler.
function Recoltes.Points(defId, avecVides)
    local out = {}
    for _, p in ipairs(Recoltes.Carnet(defId)) do
        if p.statut == "cree" and (avecVides or not p.vide) then out[#out + 1] = p end
    end
    return out
end

function Recoltes.Compte(defId)
    local n = 0
    for _, p in pairs(Magasin()) do if p.def == defId and not p.statut then n = n + 1 end end
    return n
end

local function CompteStatut(defId, statut)
    local n = 0
    for _, p in pairs(Magasin()) do if p.def == defId and p.statut == statut then n = n + 1 end end
    return n
end
function Recoltes.CompteRecoltes(defId) return CompteStatut(defId, "recolte") end
function Recoltes.CompteAttente(defId) return CompteStatut(defId, "attente") end

-- Passer un point a un statut. Rend vrai s'il a change. Un point RECOLTE ne
-- revient a rien d'autre par ici : seule une repousse (ou le MJ) le rendra.
local function Marquer(id, statut, par)
    local p = Magasin()[id]
    if not p or p.statut == "recolte" or p.statut == statut then return false end
    p.statut, p.par, p.le = statut, par, (time and time()) or 0
    return true
end

-- Ce que le MJ connait, il le connait aussi en joueur : il peut recolter ses
-- propres points pour les essayer.
local function Rafraichir(defId)
    local point = Recoltes.Definition(defId)
    if point then R.Connaitre(Publique(point), Recoltes.Points(defId, true), Moi())
    else R.OublierDefinition(defId) end
    if Recoltes.onChange then pcall(Recoltes.onChange, defId) end
end

function Recoltes.Diffuser(defId, canal, cible)
    local point = Recoltes.Definition(defId)
    if not point then return false end
    canal = canal or Canal()
    if not canal then return false, "personne à qui l'envoyer : le point est posé, mais ni canal ni groupe ne repond." end
    return LCM.Reseau.Envoyer(S.definition, R.Paquet(Publique(point), Recoltes.Points(defId)),
        canal, cible, { etale = true })
end

-- Poser un point ICI, a l'endroit ou se tient le MJ.
function Recoltes.Placer(defId)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local point = Recoltes.Definition(defId)
    if not point then return nil, "choisis d'abord un point de récolte configuré." end
    if not point.recolte.ressources[1] or point.recolte.ressources[1].entree == "" then
        return nil, "« " .. point.label .. " » ne donne aucune ressource : choisis-la dans la création."
    end
    local x, y, source, z = R.Position3D()
    if not x then
        -- Au .gps, la reponse arrive dans le chat un instant apres : on la
        -- demande, et le clic suivant la trouvera.
        local D = LCM.DeplacementForce
        if D and D.DemanderGPS then D.DemanderGPS(true) end
        return nil, "position indisponible : .gps demandé, reclique dans un instant."
    end
    local id = Identifiant()
    -- La carte SERVEUR, quand la position vient de lui : c'est elle que
    -- « S'y téléporter » donne a .worldport (comme les coffres).
    local D = LCM.DeplacementForce
    local mapid = source == "gps" and D and D.CarteGPS and tonumber(D.CarteGPS()) or nil
    -- Tout eteint : le MJ allume ce que CE point donne (voir Effectives).
    Magasin()[id] = { def = point.id, x = x, y = y, z = z, source = source, carte = R.Carte(),
        mapid = mapid, quand = (time and time()) or 0, lignes = {} }
    Rafraichir(point.id)
    Recoltes.Diffuser(point.id)
    return id
end

-- Ce que CE point donne : un reglage par ligne du modele (voir Effectives).
-- Le contenu change, donc le point repart plein : ce qui avait ete pris ou
-- etait en repousse l'etait dans l'ancien contenu, et ses rangs ne veulent
-- plus rien dire. Tout eteindre est permis : le point ne donne plus rien, et
-- disparait chez les joueurs.
function Recoltes.Regler(id, lignes)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p then return false, "ce point n'existe plus." end
    if p.statut == "attente" then return false, "une récolte est en cours sur ce point : réessaie dans un instant." end
    if type(lignes) ~= "table" then return false, "réglage illisible." end
    for entree, regle in pairs(lignes) do
        if type(entree) ~= "string" or entree == "" or type(regle) ~= "table" then
            return false, "une ligne n'a pas de ressource choisie."
        end
    end
    p.lignes = LCM.Copie(lignes)
    p.ressources = nil
    p.consomme, p.prochain = nil, nil
    if p.statut == "recolte" then p.statut, p.par, p.le = nil, nil, nil end
    Rafraichir(p.def)
    Recoltes.Diffuser(p.def)
    return true
end

-- Tout allumer, tel que le modele le regle : le « Tout activer » du panneau,
-- sans le panneau.
function Recoltes.Allumer(id)
    local p = Magasin()[tostring(id or "")]
    local point = p and Recoltes.Definition(p.def)
    if not point then return false, "ce point n'existe plus." end
    local lignes = {}
    for _, lot in ipairs(R.Ressources(point.recolte)) do lignes[lot.entree] = { actif = true } end
    return Recoltes.Regler(id, lignes)
end

-- Aller au point, comme on va a un coffre pose (Coffres.Teleporter) : par
-- .worldport, avec l'altitude, et la carte serveur quand on l'a retenue.
-- Sans elle (un point pose avant), le serveur garde la carte ou l'on est.
function Recoltes.Teleporter(id)
    if not LCM.IsMaster() then return false, "réservé au maître du jeu." end
    local p = Magasin()[tostring(id or "")]
    if not p then return false, "point de récolte introuvable." end
    local x, y, z, mapid = tonumber(p.x), tonumber(p.y), tonumber(p.z), tonumber(p.mapid)
    if not x or not y or not z or p.source == "carte" then
        return false, "coordonnées 3D indisponibles : replace ce point pour pouvoir t'y téléporter."
    end
    local function Coord(n) return (string.format("%.6f", n):gsub(",", ".")) end
    local commande = ".worldport " .. Coord(x) .. " " .. Coord(y) .. " " .. Coord(z)
    if mapid then commande = commande .. " " .. tostring(math.floor(mapid)) end
    local D = LCM.DeplacementForce
    if not (D and D.Commande and D.Commande(commande)) then
        return false, "commande de téléportation non envoyée."
    end
    return true
end

-- Ce point est-il a moi (pose par ce MJ) ?
function Recoltes.Pose(id)
    return Magasin()[tostring(id or "")]
end

function Recoltes.Retirer(id)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p then return false end
    Magasin()[id] = nil
    Rafraichir(p.def)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { i = id }, canal) end
    return true
end

-- Une definition supprimee emporte ses points : ils ne donneraient plus rien.
function Recoltes.RetirerTout(defId)
    local n = 0
    for id, p in pairs(Magasin()) do
        if p.def == defId then Magasin()[id] = nil n = n + 1 end
    end
    Rafraichir(defId)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { d = defId }, canal) end
    return n
end

-- ===== L'arbitrage =========================================================
-- Une prise met le point EN ATTENTE avant de repondre : deux demandes sur le
-- meme filon arrivent l'une apres l'autre, et la seconde le trouve pris. Le
-- joueur confirme (RECOLTE) ou rend (CREE).

-- Rend la quantite et l'entree, ou nil et la raison.
function Recoltes.Accorder(id, par)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p or p.statut then return nil, "ce point a déjà été récolté." end
    local point = Recoltes.Definition(p.def)
    if not point then return nil, "ce point ne donne plus rien." end
    local lots, etat = R.Tirer(Vue(p, point), point.recolte)
    if not lots then return nil, "ce point ne donne plus rien pour le moment." end
    p.prise = etat
    Marquer(id, "attente", par)
    Rafraichir(p.def)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { i = id }, canal) end
    return lots
end

-- `par` : seul celui a qui la prise a ete accordee la rend ou la confirme.
-- Rien (le MJ local) : pas de controle.
function Recoltes.Restituer(id, par)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p or p.statut ~= "attente" or (par and p.par ~= par) then return false end
    p.statut, p.par, p.le, p.prise = nil, nil, nil, nil
    Rafraichir(p.def)
    Recoltes.Diffuser(p.def)
    return true
end

function Recoltes.Confirmer(id, par)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p or p.statut ~= "attente" or (par and p.par ~= par) then return false end
    local prise = p.prise
    if prise then
        p.usages, p.consomme, p.prochain = prise.usages, prise.consomme, prise.prochain
    end
    p.prise = nil
    local point = Recoltes.Definition(p.def)
    if point and not R.Epuise(Vue(p, point), point.recolte) then
        p.statut, p.par, p.le = nil, nil, nil
    else
        Marquer(id, "recolte", p.par)
    end
    Rafraichir(p.def)
    Recoltes.Diffuser(p.def)
    return true
end

-- Un jet rate peut epuiser le point sans attribuer le moindre lot.
function Recoltes.Echec(id, par, compte)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p or p.statut then return false end
    local point = Recoltes.Definition(p.def)
    if not point or not point.recolte.echecConsomme
        or not R.Disponible(Vue(p, point), point.recolte) then return false end
    local ancien = tonumber(p.usages) or 0
    p.usages = compte and math.max(ancien, math.floor(tonumber(compte) or ancien)) or ancien + 1
    if p.usages == ancien then return true end
    if R.Epuise(Vue(p, point), point.recolte) then Marquer(id, "recolte", par) end
    Rafraichir(p.def)
    Recoltes.Diffuser(p.def)
    return true
end

-- Le reglage par liste (le matin du 20 octobre 2026) devient des lignes
-- allumees. Une fois, au chargement — jamais dans un accesseur.
LCM.WhenReady(function()
    for _, p in pairs(Magasin()) do
        if type(p.ressources) == "table" and p.lignes == nil then
            p.lignes = {}
            for _, r in ipairs(p.ressources) do
                if r.entree then
                    local regle = { actif = true }
                    for _, champ in ipairs(CHAMPS_LIGNE) do regle[champ] = r[champ] end
                    p.lignes[r.entree] = regle
                end
            end
            p.ressources = nil
        end
    end
end)

R.Arbitre = Recoltes.Accorder
R.Restituer = Recoltes.Restituer
R.Confirmer = Recoltes.Confirmer
R.Echec = Recoltes.Echec

-- Tout renvoyer a un joueur qui demande : une definition par message, avec
-- ses points. Celles qui n'ont aucun point ne servent a rien chez lui.
function Recoltes.Renvoyer(joueur)
    local n = 0
    for _, point in ipairs(Recoltes.Definitions()) do
        if Recoltes.Compte(point.id) > 0 then
            if Recoltes.Diffuser(point.id, joueur and "WHISPER" or nil, joueur) then n = n + 1 end
        end
    end
    return n
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter(S.demande, function(expediteur)
        if expediteur == Moi() then return end
        if not LCM.Reseau.Connu(expediteur) then return end
        Recoltes.Renvoyer(expediteur)
    end)

    LCM.Reseau.Ecouter(S.prendre, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        local id = tostring(donnees.i or "")
        local lots, raison = Recoltes.Accorder(id, expediteur)
        if lots then
            local point = Magasin()[id] and Recoltes.Definition(Magasin()[id].def)
            local r = point and point.recolte
            local ancien = r and r.limite == 1 and #r.ressources == 1
                and r.ressources[1].chance == 100 and not r.ressources[1].regeneration
            if ancien and lots[1] then
                LCM.Reseau.Envoyer(S.reponse,
                    { i = id, q = lots[1].quantite, e = lots[1].entree }, "WHISPER", expediteur)
            else
                LCM.Reseau.Envoyer(S.reponse, { i = id, q = 0, l = lots }, "WHISPER", expediteur)
            end
        else
            LCM.Reseau.Envoyer(S.reponse, { i = id, n = raison }, "WHISPER", expediteur)
        end
    end)

    LCM.Reseau.Ecouter(S.echec, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        Recoltes.Echec(donnees.i, expediteur)
    end)

    LCM.Reseau.Ecouter(S.rendre, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        Recoltes.Restituer(donnees.i, expediteur)
    end)

    LCM.Reseau.Ecouter(S.confirmer, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        Recoltes.Confirmer(donnees.i, expediteur)
    end)

    -- Un joueur nous dit ce qu'il a recolte en notre absence : ces points
    -- passent a RECOLTE, le groupe les retire, et on accuse reception de TOUT
    -- ce qu'il a cite — meme d'un point deja pris ou retire, sinon il le
    -- redirait a chaque rencontre.
    LCM.Reseau.Ecouter(S.signaler, function(expediteur, donnees)
        if not LCM.Reseau.Connu(expediteur) then return end
        local cites, touches = {}, {}
        local echecs = {}
        local canal = Canal()
        for id in tostring(donnees.l or ""):gmatch("[^,]+") do
            cites[#cites + 1] = id
            local p = Magasin()[id]
            if p and p.statut ~= "recolte" then
                local point = Recoltes.Definition(p.def)
                local compte = type(donnees.c) == "table" and donnees.c[id]
                if point and type(compte) == "table" then
                    p.usages = math.max(tonumber(p.usages) or 0,
                        math.max(1, tonumber(compte.n) or 1))
                    p.consomme = p.consomme or {}
                    for i, v in pairs(compte.c or {}) do
                        if v == true or v == "true" then p.consomme[tonumber(i) or i] = true end
                    end
                    p.prochain = p.prochain or {}
                    for i, v in pairs(compte.p or {}) do
                        local index, date = tonumber(i), tonumber(v)
                        if index and date then p.prochain[index] = math.max(p.prochain[index] or 0, date) end
                    end
                    if R.Epuise(p, point.recolte) then Marquer(id, "recolte", expediteur)
                    else p.statut, p.par, p.le = nil, nil, nil end
                else
                    Marquer(id, "recolte", expediteur)
                end
                touches[p.def] = true
                if p.statut == "recolte" and canal then
                    LCM.Reseau.Envoyer(S.retrait, { i = id }, canal)
                end
            end
        end
        for id, n in pairs(type(donnees.f) == "table" and donnees.f or {}) do
            local compte = tonumber(n)
            if compte and compte >= 0 then
                echecs[id] = compte
                local p = Magasin()[id]
                if p and p.statut ~= "recolte" then
                    local point = Recoltes.Definition(p.def)
                    if point and point.recolte.echecConsomme then
                        p.usages = math.max(tonumber(p.usages) or 0, math.floor(compte))
                        if R.Epuise(p, point.recolte) then Marquer(id, "recolte", expediteur) end
                        touches[p.def] = true
                        if p.statut == "recolte" and canal then
                            LCM.Reseau.Envoyer(S.retrait, { i = id }, canal)
                        end
                    end
                end
            end
        end
        for defId in pairs(touches) do Rafraichir(defId) Recoltes.Diffuser(defId) end
        if #cites > 0 or next(echecs) then
            LCM.Reseau.Envoyer(S.accuse,
                { l = table.concat(cites, ","), f = echecs }, "WHISPER", expediteur)
        end
    end)

    -- Le MJ connait ses propres points des le chargement. Leurs DEFINITIONS
    -- sont souvent des entrees du MJ, rechargees par le WhenReady de
    -- MJ/Brouillons.lua : ce fichier doit donc venir APRES lui dans le .toc.
    -- Avant, il passait le premier, ne trouvait aucune definition, et les
    -- points poses restaient au carnet sans exister sur le terrain apres un
    -- /reload ou un crash (13 octobre 2026, lcm_test_recolte_reprise).
    Recoltes.Reconstruire()
    -- Et ceux qui jouent deja les recoivent sans rien demander.
    Recoltes.Accueillir()
end)

-- ===== Servir ceux qui sont la ============================================
-- Un joueur ne doit jamais attendre un /reload pour voir les points (13
-- octobre 2026). Sa demande a la connexion ne suffit pas : si le MJ arrive
-- APRES lui, elle est partie dans le vide ; s'il rejoint un groupe deja forme,
-- il ne redemande rien. C'est donc le MJ qui sert : tout le groupe quand il
-- arrive, puis chaque nouveau venu, a lui seul.

local servis = {}

-- Au-dela de quelques arrivants d'un coup (le MJ qui rejoint un raid), une
-- diffusion au groupe coute moins qu'un chuchotement par tete.
local ARRIVANTS_GROUPES = 3

-- Un membre DECONNECTE reste dans la liste du groupe : a son retour, il
-- n'etait pas « nouveau », et rien ne lui partait (constate en jeu, 13
-- octobre 2026). On retient donc qui est connecte : un nouveau venu est servi
-- tout de suite ; celui qui revient l'est quelques secondes plus tard, le
-- temps que son addon soit pret a ecouter. Il demande aussi de lui-meme a sa
-- connexion — ceci est le filet.
local DELAI_RETOUR = 5

function Recoltes.Accueillir()
    local etats = R.Connectes()
    local nouveaux, revenus = {}, {}
    for nom, enLigne in pairs(etats) do
        if enLigne and servis[nom] == nil then nouveaux[#nouveaux + 1] = nom
        elseif enLigne and servis[nom] == false then revenus[#revenus + 1] = nom end
    end
    servis = etats
    for _, nom in ipairs(revenus) do
        R.PlusTard(DELAI_RETOUR, function()
            if R.EnLigne(nom) then Recoltes.Renvoyer(nom) end
        end)
    end
    if #nouveaux == 0 then return 0 end
    if #nouveaux > ARRIVANTS_GROUPES then return Recoltes.Renvoyer() end
    local n = 0
    for _, nom in ipairs(nouveaux) do n = n + Recoltes.Renvoyer(nom) end
    return n
end

LCM.On("GROUP_ROSTER_UPDATE", function()
    if LCM.ready and LCM.IsMaster() then Recoltes.Accueillir() end
end)
-- Un membre se connecte ou se deconnecte sans que la liste change.
LCM.On("UNIT_CONNECTION", function()
    if LCM.ready and LCM.IsMaster() then Recoltes.Accueillir() end
end)

-- Rend actifs tous les points poses dont la definition est connue. Rappele
-- quand une definition arrive ou change par la synchronisation entre MJ.
function Recoltes.Reconstruire()
    local vus = {}
    for _, p in pairs(Magasin()) do
        if not vus[p.def] then
            vus[p.def] = true
            Rafraichir(p.def)
        end
    end
end

-- Un point de recolte modifie (ou supprime) : ce que J'AI pose se met a jour
-- chez tous, sans le reposer (MJ/Brouillons.lua, SurPoint).
if LCM.Brouillons and LCM.Brouillons.SurPoint then
    LCM.Brouillons.SurPoint(function(defId)
        if Recoltes.Compte(defId) == 0 then return end
        Rafraichir(defId)
        if Recoltes.Definition(defId) then
            Recoltes.Diffuser(defId)
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
        if famille == "points" then Recoltes.Reconstruire() end
    end
end
