-- Le stock partage des points de vente et de recolte.
--
-- Un filon ne se vide pas pour chacun de son cote : si deux joueurs ramassent
-- la meme herbe, il n'en reste pas deux. Mais il n'existe aucun serveur pour
-- arbitrer — chacun a sa copie, et les copies doivent converger toutes seules.
--
-- Trois nombres par entree, et c'est tout :
--   r  ce qu'il reste
--   t  l'instant de reference de la repousse
--   u  l'instant de la derniere prise
--
-- La repousse est **deterministe** : elle se deduit de (r, t) et du temps qui
-- passe, donc deux clients qui n'ont rien echange depuis une heure calculent la
-- meme valeur. Elle ne touche jamais u.
--
-- La fusion, quand deux copies se rencontrent (regle reprise de Necronicon) :
--   la prise la plus recente gagne ; a egalite, la repousse la plus recente ;
--   a egalite encore, le reste le PLUS BAS.
-- Le dernier point compte : en cas de doute, on croit celui qui a le moins.
-- Mieux vaut un filon qu'on croit vide et qui ne l'est pas, que deux joueurs
-- qui ramassent la meme chose.

local _, LCM = ...

local Stock = {}
LCM.Stock = Stock

local VIDE = {}
local declares = {}

local function Maintenant()
    return math.floor((GetTime and GetTime()) or 0)
end
Stock.Maintenant = Maintenant

local function Cache()
    LCM.EnsureDatabase()
    return LCM.db
end

local function Entrees()
    local db = Cache()
    return type(db.stock) == "table" and db.stock or VIDE
end

local function EntreesPourEcrire()
    local db = Cache()
    db.stock = type(db.stock) == "table" and db.stock or {}
    return db.stock
end

-- ===== Declaration =========================================================
-- La regle d'un stock (limite, repousse) est du CONTENU : elle vit dans le
-- point, pas dans la sauvegarde. Seuls les trois nombres sont sauvegardes.

function Stock.Declarer(cle, regle)
    cle = tostring(cle or "")
    if cle == "" then return nil end
    declares[cle] = {
        limite = math.max(0, math.floor(tonumber(regle and regle.limite) or 0)),
        unites = math.max(0, math.floor(tonumber(regle and regle.unites) or 0)),
        minutes = math.max(0, tonumber(regle and regle.minutes) or 0),
    }
    return declares[cle]
end

function Stock.Regle(cle)
    return declares[tostring(cle or "")]
end

function Stock.Oublier(cle)
    cle = tostring(cle or "")
    declares[cle] = nil
    local entrees = Entrees()
    if entrees[cle] then
        entrees[cle] = nil
        if not next(entrees) then Cache().stock = nil end
    end
end

-- ===== Lecture =============================================================

-- La repousse, appliquee a une copie des trois nombres. Elle ne s'ecrit que si
-- on le demande : lire un stock ne doit pas salir la sauvegarde.
local function Repousser(cle, etat)
    local regle = declares[cle]
    if not regle or regle.unites <= 0 or regle.minutes <= 0 then return etat end
    if etat.r >= regle.limite then return etat end
    local periode = regle.minutes * 60
    local ecoule = Maintenant() - etat.t
    if ecoule < periode then return etat end
    local periodes = math.floor(ecoule / periode)
    etat.r = math.min(regle.limite, etat.r + periodes * regle.unites)
    -- On avance t des periodes CONSOMMEES, pas jusqu'a maintenant : le reste du
    -- temps compte pour la repousse suivante.
    etat.t = etat.t + periodes * periode
    return etat
end

local function Copie(etat)
    return { r = etat.r, t = etat.t, u = etat.u }
end

function Stock.Etat(cle)
    cle = tostring(cle or "")
    local regle = declares[cle]
    local garde = Entrees()[cle]
    local etat = garde and Copie(garde)
        or { r = regle and regle.limite or 0, t = Maintenant(), u = 0 }
    return Repousser(cle, etat)
end

function Stock.Restant(cle)
    return Stock.Etat(cle).r
end

function Stock.Limite(cle)
    local regle = declares[tostring(cle or "")]
    return regle and regle.limite or 0
end

-- ===== Prendre =============================================================

function Stock.Consommer(cle, combien, silencieux)
    cle = tostring(cle or "")
    combien = math.max(1, math.floor(tonumber(combien) or 1))
    local etat = Stock.Etat(cle)
    if etat.r < combien then return false, etat.r end
    etat.r = etat.r - combien
    etat.u = Maintenant()
    EntreesPourEcrire()[cle] = etat
    if not silencieux then Stock.Partager(cle) end
    return true, etat.r
end

-- Le MJ remet du stock : c'est une prise negative, donc elle porte la meme
-- marque de temps, et elle gagne donc la fusion comme n'importe quelle prise.
function Stock.Rendre(cle, combien, silencieux)
    cle = tostring(cle or "")
    combien = math.max(1, math.floor(tonumber(combien) or 1))
    local etat = Stock.Etat(cle)
    local limite = Stock.Limite(cle)
    etat.r = math.min(limite > 0 and limite or etat.r + combien, etat.r + combien)
    etat.u = Maintenant()
    EntreesPourEcrire()[cle] = etat
    if not silencieux then Stock.Partager(cle) end
    return true, etat.r
end

-- ===== Fusion ==============================================================

function Stock.Fusionner(cle, distant)
    cle = tostring(cle or "")
    if type(distant) ~= "table" then return false end
    local venu = { r = math.floor(tonumber(distant.r) or 0),
                   t = math.floor(tonumber(distant.t) or 0),
                   u = math.floor(tonumber(distant.u) or 0) }
    local garde = Entrees()[cle]
    if not garde then
        EntreesPourEcrire()[cle] = venu
        return true
    end
    local mien = Copie(garde)

    local retenu
    if venu.u > mien.u then
        retenu = venu
    elseif venu.u < mien.u then
        retenu = mien
    elseif venu.t ~= mien.t then
        retenu = (venu.t > mien.t) and venu or mien
    else
        -- Meme histoire des deux cotes : on croit celui qui a le moins.
        retenu = { r = math.min(venu.r, mien.r), t = mien.t, u = mien.u }
    end

    local change = retenu.r ~= mien.r or retenu.t ~= mien.t or retenu.u ~= mien.u
    EntreesPourEcrire()[cle] = retenu
    return change
end

-- ===== Reseau ==============================================================

function Stock.Partager(cle, canal, cible)
    cle = tostring(cle or "")
    local etat = Entrees()[cle]
    if not etat then return false end
    return LCM.Reseau.Envoyer("stock", { cle = cle, r = etat.r, t = etat.t, u = etat.u },
        canal or "RAID", cible)
end

-- Demander l'etat d'un stock a ceux qui jouent : a l'ouverture d'un point, on
-- ne sait pas ce qui s'est passe pendant qu'on n'etait pas la.
function Stock.Demander(cle, canal)
    return LCM.Reseau.Envoyer("stock?", { cle = tostring(cle or "") }, canal or "RAID")
end

LCM.WhenReady(function()
    LCM.Reseau.Ecouter("stock", function(_, donnees)
        if Stock.Fusionner(donnees.cle, donnees) and Stock.onChange then
            Stock.onChange(tostring(donnees.cle))
        end
    end)
    LCM.Reseau.Ecouter("stock?", function(expediteur, donnees)
        local cle = tostring(donnees.cle or "")
        if Entrees()[cle] then Stock.Partager(cle, "WHISPER", expediteur) end
    end)
end)
