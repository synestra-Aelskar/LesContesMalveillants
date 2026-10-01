-- La bourse : ce que le personnage possede en monnaie.
--
-- Pourquoi elle ne passe PAS par l'inventaire, alors qu'il a un onglet
-- « Devises » : cet onglet n'a qu'UN emplacement dans le template
-- (`Equilibrage.inventaire.devises = 1`). Il y loge une monnaie, pas une
-- bourse. Or on veut voir les trois d'un coup, et davantage.
--
-- La bourse tient donc ses propres soldes, un par devise, et c'est elle qui
-- fait foi. L'onglet Devises de l'inventaire garde son role du template ; si un
-- jour il doit disparaitre ou s'ouvrir, ce sera une decision prise exprès, pas
-- un effet de bord.
--
-- Les devises elles-memes sont du contenu : elles viennent du compendium
-- (famille « devises »), donc le MJ en cree une dans l'atelier et elle part
-- avec la mise a jour. Rien a declarer ici.

local _, LCM = ...

local Bourse = {}
LCM.Bourse = Bourse

local VIDE = {}

-- Les monnaies que tout personnage voit, meme a zero. Les autres n'apparaissent
-- que s'il en possede : une bourse pleine de lignes a zero ne dit rien.
Bourse.DEFAUTS = { "ecus", "credits", "essence_stelaire" }

-- Lecture : ne cree rien.
local function Soldes(entity)
    if type(entity) ~= "table" or type(entity.bourse) ~= "table" then return VIDE end
    return entity.bourse
end

local function SoldesPourEcrire(entity)
    if type(entity) ~= "table" then return nil end
    entity.bourse = type(entity.bourse) == "table" and entity.bourse or {}
    return entity.bourse
end

function Bourse.Solde(entity, deviseId)
    return math.floor(tonumber(Soldes(entity)[tostring(deviseId or "")]) or 0)
end

-- Ce que montre la bourse : les monnaies de base, toujours, puis celles qu'on
-- detient en plus.
function Bourse.Liste(entity)
    local out, vus = {}, {}
    local function poser(devise)
        if not devise or vus[devise.id] then return end
        vus[devise.id] = true
        out[#out + 1] = {
            id = devise.id, label = devise.label, icone = devise.icone,
            description = devise.description, solde = Bourse.Solde(entity, devise.id),
        }
    end
    for _, id in ipairs(Bourse.DEFAUTS) do poser(LCM.Devises.Get(id)) end
    -- Dans l'ordre du compendium, pour que deux joueurs voient la meme chose.
    for _, devise in ipairs(LCM.Devises.list) do
        if Bourse.Solde(entity, devise.id) ~= 0 then poser(devise) end
    end
    return out
end

-- Toutes les devises du compendium : ce que le MJ peut donner.
function Bourse.Catalogue()
    return LCM.Devises.list
end

function Bourse.Crediter(entity, deviseId, combien)
    local devise = LCM.Devises.Get(deviseId)
    if not devise then return false, "devise inconnue." end
    combien = math.floor(tonumber(combien) or 0)
    if combien <= 0 then return false, "un montant positif." end
    local soldes = SoldesPourEcrire(entity)
    if not soldes then return false, "aucun personnage." end
    soldes[devise.id] = Bourse.Solde(entity, devise.id) + combien
    return true, soldes[devise.id]
end

function Bourse.Debiter(entity, deviseId, combien)
    local devise = LCM.Devises.Get(deviseId)
    if not devise then return false, "devise inconnue." end
    combien = math.floor(tonumber(combien) or 0)
    if combien <= 0 then return false, "un montant positif." end
    local solde = Bourse.Solde(entity, devise.id)
    if solde < combien then
        return false, string.format("il n'a que %d %s.", solde, devise.label)
    end
    local soldes = SoldesPourEcrire(entity)
    soldes[devise.id] = solde - combien
    -- Un solde a zero ne se garde pas : la sauvegarde n'a pas a retenir ce
    -- qu'on n'a pas.
    if soldes[devise.id] == 0 then soldes[devise.id] = nil end
    if not next(soldes) then entity.bourse = nil end
    return true
end

-- A-t-on de quoi payer ? Pose la question sans rien debiter.
function Bourse.Peut(entity, deviseId, combien)
    return Bourse.Solde(entity, deviseId) >= math.floor(tonumber(combien) or 0)
end

function Bourse.Total(entity)
    local total = 0
    for _, ligne in ipairs(Bourse.Liste(entity)) do total = total + ligne.solde end
    return total
end
