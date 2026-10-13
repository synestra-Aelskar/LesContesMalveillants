-- Les points de recolte poses par le MJ (13 octobre 2026).
--
-- Deux choses distinctes, et il ne faut pas les confondre :
--   * la DEFINITION (« Miner du fer » : quelle ressource, combien, quel jet) est
--     du contenu. C'est un point de nature « ressource » (MJ/Points.lua), cree
--     dans l'atelier et exporte comme le reste ;
--   * les POINTS POSES sont l'etat du monde : ici, ici et ici, et chacun
--     disparait quand on le recolte. Ils vivent dans la sauvegarde du MJ,
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
    return LCM.Combat and LCM.Combat.CanalGroupe and LCM.Combat.CanalGroupe()
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
        auteur = Moi(),
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

-- Tout le carnet d'une definition, recoltes compris.
function Recoltes.Carnet(defId)
    local out = {}
    for id, p in pairs(Magasin()) do
        if not defId or p.def == defId then
            out[#out + 1] = { id = id, def = p.def, x = p.x, y = p.y,
                source = p.source, carte = p.carte, quand = p.quand,
                statut = p.statut or "cree", par = p.par, le = p.le }
        end
    end
    -- Du plus recent au plus ancien : celui qu'on vient de poser en tete.
    table.sort(out, function(a, b)
        if (a.quand or 0) ~= (b.quand or 0) then return (a.quand or 0) > (b.quand or 0) end
        return a.id > b.id
    end)
    return out
end

-- Les points encore la : les seuls qu'on envoie.
function Recoltes.Points(defId)
    local out = {}
    for _, p in ipairs(Recoltes.Carnet(defId)) do
        if p.statut == "cree" then out[#out + 1] = p end
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
    if point then R.Connaitre(Publique(point), Recoltes.Points(defId), Moi())
    else R.OublierDefinition(defId) end
    if Recoltes.onChange then pcall(Recoltes.onChange, defId) end
end

function Recoltes.Diffuser(defId, canal, cible)
    local point = Recoltes.Definition(defId)
    if not point then return false end
    canal = canal or Canal()
    if not canal then return false, "hors groupe : le point est posé, mais personne ne le voit." end
    return LCM.Reseau.Envoyer(S.definition, R.Paquet(Publique(point), Recoltes.Points(defId)),
        canal, cible, { etale = true })
end

-- Poser un point ICI, a l'endroit ou se tient le MJ.
function Recoltes.Placer(defId)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local point = Recoltes.Definition(defId)
    if not point then return nil, "choisis d'abord un point de récolte configuré." end
    if point.recolte.entree == "" then
        return nil, "« " .. point.label .. " » ne donne aucune ressource : choisis-la dans la création."
    end
    local x, y, source = R.Position()
    if not x then
        -- Au .gps, la reponse arrive dans le chat un instant apres : on la
        -- demande, et le clic suivant la trouvera.
        local D = LCM.DeplacementForce
        if D and D.DemanderGPS then D.DemanderGPS(true) end
        return nil, "position indisponible : .gps demandé, reclique dans un instant."
    end
    local id = Identifiant()
    Magasin()[id] = { def = point.id, x = x, y = y, source = source, carte = R.Carte(),
        quand = (time and time()) or 0 }
    Rafraichir(point.id)
    Recoltes.Diffuser(point.id)
    return id
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
    local r = point.recolte
    local quantite = LCM.Roll.Des(r.min, r.max)
    Marquer(id, "attente", par)
    Rafraichir(p.def)
    local canal = Canal()
    if canal then LCM.Reseau.Envoyer(S.retrait, { i = id }, canal) end
    return quantite, r.entree
end

-- `par` : seul celui a qui la prise a ete accordee la rend ou la confirme.
-- Rien (le MJ local) : pas de controle.
function Recoltes.Restituer(id, par)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p or p.statut ~= "attente" or (par and p.par ~= par) then return false end
    p.statut, p.par, p.le = nil, nil, nil
    Rafraichir(p.def)
    Recoltes.Diffuser(p.def)
    return true
end

function Recoltes.Confirmer(id, par)
    id = tostring(id or "")
    local p = Magasin()[id]
    if not p or p.statut ~= "attente" or (par and p.par ~= par) then return false end
    Marquer(id, "recolte", p.par)
    Rafraichir(p.def)
    return true
end

R.Arbitre = Recoltes.Accorder
R.Restituer = Recoltes.Restituer
R.Confirmer = Recoltes.Confirmer

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
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        Recoltes.Renvoyer(expediteur)
    end)

    LCM.Reseau.Ecouter(S.prendre, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local id = tostring(donnees.i or "")
        local quantite, entree = Recoltes.Accorder(id, expediteur)
        if quantite then
            LCM.Reseau.Envoyer(S.reponse, { i = id, q = quantite, e = entree }, "WHISPER", expediteur)
        else
            LCM.Reseau.Envoyer(S.reponse, { i = id, n = entree }, "WHISPER", expediteur)
        end
    end)

    LCM.Reseau.Ecouter(S.rendre, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        Recoltes.Restituer(donnees.i, expediteur)
    end)

    LCM.Reseau.Ecouter(S.confirmer, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        Recoltes.Confirmer(donnees.i, expediteur)
    end)

    -- Un joueur nous dit ce qu'il a recolte en notre absence : ces points
    -- passent a RECOLTE, le groupe les retire, et on accuse reception de TOUT
    -- ce qu'il a cite — meme d'un point deja pris ou retire, sinon il le
    -- redirait a chaque rencontre.
    LCM.Reseau.Ecouter(S.signaler, function(expediteur, donnees)
        if not LCM.Reseau.DansLeGroupe(expediteur) then return end
        local cites, touches = {}, {}
        local canal = Canal()
        for id in tostring(donnees.l or ""):gmatch("[^,]+") do
            cites[#cites + 1] = id
            local p = Magasin()[id]
            if p and Marquer(id, "recolte", expediteur) then
                touches[p.def] = true
                if canal then LCM.Reseau.Envoyer(S.retrait, { i = id }, canal) end
            end
        end
        for defId in pairs(touches) do Rafraichir(defId) end
        if #cites > 0 then
            LCM.Reseau.Envoyer(S.accuse, { l = table.concat(cites, ",") }, "WHISPER", expediteur)
        end
    end)

    -- Le MJ connait ses propres points des le chargement. Leurs DEFINITIONS
    -- sont souvent des brouillons, recharges par le WhenReady de
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

function Recoltes.Accueillir()
    local presents, nouveaux = {}, {}
    for _, nom in ipairs(LCM.Combat.Membres()) do
        presents[nom] = true
        if not servis[nom] then nouveaux[#nouveaux + 1] = nom end
    end
    servis = presents
    if #nouveaux == 0 then return 0 end
    if #nouveaux > ARRIVANTS_GROUPES then return Recoltes.Renvoyer() end
    local n = 0
    for _, nom in ipairs(nouveaux) do n = n + Recoltes.Renvoyer(nom) end
    return n
end

LCM.On("GROUP_ROSTER_UPDATE", function()
    if LCM.ready and LCM.IsMaster() then Recoltes.Accueillir() end
end)

-- Rend actifs tous les points poses dont la definition est connue. Rappele
-- quand une definition arrive ou change par la synchronisation des brouillons.
function Recoltes.Reconstruire()
    local vus = {}
    for _, p in pairs(Magasin()) do
        if not vus[p.def] then
            vus[p.def] = true
            Rafraichir(p.def)
        end
    end
end

local precedent = LCM.Brouillons and LCM.Brouillons.onSynchro
if LCM.Brouillons then
    LCM.Brouillons.onSynchro = function(famille, entree)
        if precedent then precedent(famille, entree) end
        if famille == "points" then Recoltes.Reconstruire() end
    end
end
