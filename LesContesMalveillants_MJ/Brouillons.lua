-- Brouillons du maitre du jeu.
--
-- En seance, le MJ cree des traits, des races, des objets. Ces creations vivent
-- d'abord ICI, dans la sauvegarde du compagnon MJ — elles sont utilisables tout
-- de suite, mais ne sont encore le contenu de personne.
--
-- Entre deux seances, l'outil « Exporter les brouillons » les transforme en
-- fichiers Lua propres (Data/Genere/), qui partent dans le depot. Tout le monde
-- met a jour, et le contenu devient officiel et identique pour tous.
--
-- Pourquoi ce detour plutot qu'ecrire directement dans la sauvegarde de chacun :
-- le contenu reste du CODE, versionne, relu, et la sauvegarde ne contient que
-- ce que les joueurs ont saisi. C'est la regle de l'addon, et elle ne souffre
-- pas d'exception.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local Brouillons = {}
MJ.Brouillons = Brouillons
LCM.Brouillons = Brouillons

-- Les familles exportables. En ajouter une ici ET dans l'outil d'export.
Brouillons.FAMILLES = { "traits", "races", "objets" }

local function Store(famille)
    _G.LCM_MJ_DB = type(_G.LCM_MJ_DB) == "table" and _G.LCM_MJ_DB or {}
    local db = _G.LCM_MJ_DB
    db.brouillons = type(db.brouillons) == "table" and db.brouillons or {}
    if famille then
        db.brouillons[famille] = type(db.brouillons[famille]) == "table" and db.brouillons[famille] or {}
        return db.brouillons[famille]
    end
    return db.brouillons
end

local function FamilleValide(famille)
    for _, nom in ipairs(Brouillons.FAMILLES) do
        if nom == famille then return true end
    end
    return false
end

-- Ajoute ou remplace un brouillon. `entree` doit porter un `id`.
function Brouillons.Set(famille, entree)
    famille = tostring(famille or "")
    if not FamilleValide(famille) then
        LCM.Erreur("famille inconnue : " .. famille)
        return false
    end
    if type(entree) ~= "table" or tostring(entree.id or "") == "" then
        LCM.Erreur("brouillon sans identifiant")
        return false
    end
    Store(famille)[tostring(entree.id)] = entree
    return true
end

function Brouillons.Get(famille, id)
    return Store(tostring(famille or ""))[tostring(id or "")]
end

function Brouillons.Remove(famille, id)
    local store = Store(tostring(famille or ""))
    local cle = tostring(id or "")
    if store[cle] == nil then return false end
    store[cle] = nil
    return true
end

function Brouillons.List(famille)
    local out = {}
    for _, entree in pairs(Store(tostring(famille or ""))) do
        out[#out + 1] = entree
    end
    table.sort(out, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return out
end

function Brouillons.Count()
    local total = 0
    for _, famille in ipairs(Brouillons.FAMILLES) do
        for _ in pairs(Store(famille)) do total = total + 1 end
    end
    return total
end

-- Un brouillon deja publie (present dans les fichiers generes) n'a plus lieu
-- d'etre : on le signale pour que le MJ puisse faire le menage apres un export.
-- Attention : un brouillon se declare lui-meme au chargement ; on ne compare
-- donc pas sa simple presence, mais l'ORIGINE de ce qui porte son identifiant.
local function DejaEnDur(registre, id)
    local existant = registre.Get(id)
    return existant ~= nil and existant.brouillon ~= true
end

function Brouillons.Published()
    local out = {}
    for _, entree in ipairs(Brouillons.List("traits")) do
        if DejaEnDur(LCM.Traits, entree.id) then out[#out + 1] = "traits/" .. tostring(entree.id) end
    end
    for _, entree in ipairs(Brouillons.List("races")) do
        if DejaEnDur(LCM.Races, entree.id) then out[#out + 1] = "races/" .. tostring(entree.id) end
    end
    for _, entree in ipairs(Brouillons.List("objets")) do
        if DejaEnDur(LCM.Objets, entree.id) then out[#out + 1] = "objets/" .. tostring(entree.id) end
    end
    return out
end

-- ===== Saisie en seance ====================================================
-- Ce que l'atelier appelle. La saisie passe par les MEMES regles que le
-- chargement d'un fichier genere (`Construire` du registre) : un brouillon
-- refuse ici l'aurait ete a l'export, autant le dire tout de suite.

-- Les identifiants sont sans accents (convention de l'addon) : on les derive du
-- nom saisi. Lua ne connait que des octets, d'ou la table des sequences UTF-8.
local ACCENTS = {
    ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["À"] = "a", ["Â"] = "a", ["Ä"] = "a",
    ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
    ["î"] = "i", ["ï"] = "i", ["Î"] = "i", ["Ï"] = "i",
    ["ô"] = "o", ["ö"] = "o", ["Ô"] = "o", ["Ö"] = "o",
    ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u",
    ["ç"] = "c", ["Ç"] = "c", ["ÿ"] = "y",
    ["œ"] = "oe", ["Œ"] = "oe", ["æ"] = "ae", ["Æ"] = "ae",
}

-- « Escalade de la jungle » -> « escalade_de_la_jungle ». Un caractere
-- inconnu disparait plutot que de produire un identifiant illisible.
function Brouillons.Identifiant(nom)
    local texte = tostring(nom or ""):gsub("[\192-\255][\128-\191]*", function(c)
        return ACCENTS[c] or ""
    end)
    texte = texte:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    return texte
end

-- Resolu a l'appel : les registres vivent dans l'addon principal.
local function Registre(famille)
    if famille == "traits" then return LCM.Traits end
    if famille == "races" then return LCM.Races end
    if famille == "objets" then return LCM.Objets end
    return nil
end
Brouillons.Registre = Registre

-- « LCM/Traits : cout invalide » -> « cout invalide » : le prefixe sert a qui
-- lit une trace, pas au MJ devant son formulaire.
local function Raison(message)
    return (tostring(message or ""):gsub("^LCM/%a+ : ", ""))
end

-- Vrai si l'identifiant appartient a du contenu publie (un fichier genere).
function Brouillons.EstPublie(famille, id)
    local registre = Registre(famille)
    local existant = registre and registre.Get(id)
    return existant ~= nil and existant.brouillon ~= true
end

-- Enregistre un brouillon et le rend jouable aussitot. `creation` : le MJ
-- pense creer une entree neuve, donc un identifiant deja pris est une
-- collision, pas une modification. Renvoie true, ou false et la raison.
function Brouillons.Enregistrer(famille, entree, creation)
    famille = tostring(famille or "")
    if not FamilleValide(famille) then return false, "famille inconnue : " .. famille end
    local registre = Registre(famille)
    if not (registre and registre.Construire) then
        return false, "le format des " .. famille .. " n'est pas encore defini"
    end

    local ok, neuf = pcall(registre.Construire, entree)
    if not ok then return false, Raison(neuf) end

    if Brouillons.EstPublie(famille, neuf.id) then
        return false, string.format("« %s » est deja du contenu publie : le fichier fait foi", neuf.id)
    end
    if creation and Brouillons.Get(famille, neuf.id) then
        return false, string.format("un brouillon porte deja l'identifiant « %s »", neuf.id)
    end

    Brouillons.Set(famille, entree)

    -- Modifie SUR PLACE : les entites designent le trait par son identifiant,
    -- mais les ecrans ouverts tiennent la table elle-meme.
    local existant = registre.Get(neuf.id)
    if existant then
        for cle in pairs(existant) do existant[cle] = nil end
        for cle, valeur in pairs(neuf) do existant[cle] = valeur end
        existant.brouillon = true
    else
        registre.Add(entree).brouillon = true
    end
    return true
end

-- Supprime un brouillon, et le retire du jeu s'il n'etait qu'un brouillon.
-- Les entites qui le portaient gardent son identifiant : on n'efface pas les
-- donnees d'un joueur parce que le contenu a disparu.
function Brouillons.Supprimer(famille, id)
    famille = tostring(famille or "")
    if not Brouillons.Remove(famille, id) then return false end
    local registre = Registre(famille)
    local existant = registre and registre.Get(id)
    if existant and existant.brouillon == true then registre.Retirer(id) end
    return true
end

-- ===== Prise en compte immediate ===========================================
-- Les brouillons sont declares comme le reste, pour etre jouables des la
-- seance. S'ils existent deja en dur, on n'ecrase pas : le fichier fait foi.

LCM.WhenReady(function()
    -- On marque ce qui vient d'un brouillon : c'est ce qui permet ensuite de
    -- reperer un brouillon devenu redondant avec un fichier genere.
    for _, famille in ipairs({ "races", "traits", "objets" }) do
        local registre = Registre(famille)
        for _, entree in ipairs(Brouillons.List(famille)) do
            if not registre.Get(entree.id) then
                local ok, cree = pcall(registre.Add, entree)
                if ok and type(cree) == "table" then cree.brouillon = true
                elseif not ok then
                    LCM.Erreur(string.format("brouillon refuse (%s) : %s", famille, Raison(cree)))
                end
            end
        end
    end
    local nombre = Brouillons.Count()
    if nombre > 0 then
        LCM.Info(string.format("%d brouillon(s) en attente d'export.", nombre))
    end
end)

LCM.AddCommand("brouillons", "liste ce qui attend d'etre exporte", function()
    local total = Brouillons.Count()
    if total == 0 then
        LCM.Info("aucun brouillon.")
        return
    end
    for _, famille in ipairs(Brouillons.FAMILLES) do
        local liste = Brouillons.List(famille)
        if #liste > 0 then
            LCM.Info(string.format("%s (%d) :", famille, #liste))
            for _, entree in ipairs(liste) do
                LCM.Info("   " .. tostring(entree.label or entree.id))
            end
        end
    end
    local publies = Brouillons.Published()
    if #publies > 0 then
        LCM.Alerte(string.format("%d brouillon(s) deja publie(s), a supprimer : %s",
            #publies, table.concat(publies, ", ")))
    end
end, true)
