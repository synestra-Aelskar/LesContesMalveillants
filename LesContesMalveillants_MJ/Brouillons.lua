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
-- Les huit suivantes viennent du compendium (Core/Contenus.lua), et « jeux »
-- de la forge (Core/Forge.lua) : l'outil d'export ne les connait pas encore,
-- leurs brouillons attendent qu'il le fasse.
Brouillons.FAMILLES = { "traits", "races", "objets", "etats", "apprentissages", "sacs",
    "informations", "listes", "devises", "ressources", "connaissances", "resolutions", "calculateurs", "pnj",
    "jeux" }

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
    for _, famille in ipairs(Brouillons.FAMILLES) do
        local registre = Brouillons.Registre(famille)
        for _, entree in ipairs(Brouillons.List(famille)) do
            if registre and DejaEnDur(registre, entree.id) then
                out[#out + 1] = famille .. "/" .. tostring(entree.id)
            end
        end
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

-- Resolu a l'appel : les registres vivent dans l'addon principal. La table
-- famille -> registre est celle du compendium, la seule.
local function Registre(famille)
    local nom = LCM.Compendium and LCM.Compendium.FAMILLES[tostring(famille or "")]
    return nom and LCM[nom] or nil
end
Brouillons.Registre = Registre

-- « LCM/Traits : cout invalide » -> « cout invalide » : le prefixe sert a qui
-- lit une trace, pas au MJ devant son formulaire.
local function Raison(message)
    return (tostring(message or ""):gsub("^LCM/%a+ : ", ""))
end

-- Vrai si l'identifiant appartient a du contenu publie (un fichier genere).
-- Ce qu'un brouillon a recouvert : l'entree publiee, telle qu'elle etait. Elle
-- vit en memoire vive — au prochain chargement, le fichier la redonne de toute
-- facon, et c'est lui qui fait foi.
local originaux = {}

function Brouillons.Original(famille, id)
    local parFamille = originaux[tostring(famille or "")]
    return parFamille and parFamille[tostring(id or "")] or nil
end

function Brouillons.EstPublie(famille, id)
    local registre = Registre(famille)
    local existant = registre and registre.Get(id)
    return existant ~= nil and existant.brouillon ~= true
end

-- Enregistre un brouillon et le rend jouable aussitot. `creation` : le MJ
-- pense creer une entree neuve, donc un identifiant deja pris est une
-- collision, pas une modification. Renvoie true, ou false et la raison.
--
-- `remplacer` : le MJ modifie SCIEMMENT du contenu publie. Le refus pur et
-- simple rendait l'atelier inutilisable en seance — on ouvrait une entree, on
-- corrigeait une faute, et aucun bouton ne permettait d'enregistrer. Le
-- brouillon prend alors le pas sur le fichier jusqu'a ce qu'on l'y reporte,
-- et il est marque pour qu'on sache qu'il reste a reporter.
function Brouillons.Enregistrer(famille, entree, creation, remplacer)
    famille = tostring(famille or "")
    if not FamilleValide(famille) then return false, "famille inconnue : " .. famille end
    local registre = Registre(famille)
    if not (registre and registre.Construire) then
        return false, "le format des " .. famille .. " n'est pas encore defini"
    end

    local ok, neuf = pcall(registre.Construire, entree)
    if not ok then return false, Raison(neuf) end

    if Brouillons.EstPublie(famille, neuf.id) and not remplacer then
        return false, string.format("« %s » est deja du contenu publie : le fichier fait foi", neuf.id)
    end
    if creation and Brouillons.Get(famille, neuf.id) then
        return false, string.format("un brouillon porte deja l'identifiant « %s »", neuf.id)
    end
    -- Le bareme de la forge BLOQUE (decision du 3 octobre 2026). Ici, et pas
    -- dans chaque fenetre : l'atelier, l'editeur et la modification groupee
    -- passent tous par cette porte.
    local dansLeBareme, horsBareme = LCM.Forge.Verifier(famille, neuf)
    if not dansLeBareme then return false, horsBareme end

    -- Retenu DANS le brouillon : l'export doit savoir qu'il ecrase un publie,
    -- et l'atelier doit pouvoir le dire a chaque ouverture.
    if remplacer then entree.remplacePublie = true end
    Brouillons.Set(famille, entree)
    -- Et chez l'autre maitre du jeu, tout de suite.
    Brouillons.Diffuser(famille, entree, remplacer)

    -- Modifie SUR PLACE : les entites designent le trait par son identifiant,
    -- mais les ecrans ouverts tiennent la table elle-meme.
    local existant = registre.Get(neuf.id)
    if existant then
        -- On ECRASE une entree publiee : il faut en garder une copie, sinon
        -- supprimer le brouillon ensuite emporterait le contenu publie avec
        -- lui. Ce n'est pas theorique : le banc l'a attrape immediatement.
        if remplacer and existant.brouillon ~= true and not Brouillons.Original(famille, neuf.id) then
            local copie = {}
            for cle, valeur in pairs(existant) do copie[cle] = valeur end
            originaux[famille] = originaux[famille] or {}
            originaux[famille][neuf.id] = copie
        end
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
    Brouillons.DiffuserSuppression(famille, id)
    local registre = Registre(famille)
    local existant = registre and registre.Get(id)
    local original = Brouillons.Original(famille, id)
    if existant and original then
        -- Le brouillon recouvrait du publie : on REND l'original, on ne retire
        -- pas l'entree. Sinon supprimer son brouillon effacait du contenu qu'on
        -- n'avait jamais cree.
        for cle in pairs(existant) do existant[cle] = nil end
        for cle, valeur in pairs(original) do existant[cle] = valeur end
        existant.brouillon = nil
        originaux[tostring(famille)][tostring(id)] = nil
    elseif existant and existant.brouillon == true then
        registre.Retirer(id)
    end
    return true
end

-- ===== Retirer une entree publiee =========================================
-- Le contenu publie vient d'un fichier genere, et ce fichier fait foi : on ne
-- peut pas l'effacer depuis le jeu. Mais s'en servir en seance alors qu'on veut
-- s'en debarrasser n'avait aucune issue — « 0 supprimée(s). Refus : Automate
-- danseuse » et rien d'autre a faire (5 octobre 2026).
--
-- On pose donc un MASQUE : l'entree disparait du jeu tout de suite et reste
-- masquee d'une session a l'autre. Elle n'est PAS effacee du fichier — c'est
-- l'export qui le rappellera, et le retrait definitif se fait a la source.

local function Masques(famille)
    _G.LCM_MJ_DB = type(_G.LCM_MJ_DB) == "table" and _G.LCM_MJ_DB or {}
    local db = _G.LCM_MJ_DB
    db.masques = type(db.masques) == "table" and db.masques or {}
    if famille then
        db.masques[famille] = type(db.masques[famille]) == "table" and db.masques[famille] or {}
        return db.masques[famille]
    end
    return db.masques
end
Brouillons.Masques = Masques

function Brouillons.EstMasquee(famille, id)
    return Masques(tostring(famille or ""))[tostring(id or "")] == true
end

-- Retire l'entree du registre, donc du jeu. Les personnages qui la portaient
-- gardent son identifiant : on n'efface pas les donnees d'un joueur parce que
-- le contenu a disparu.
function Brouillons.Masquer(famille, id)
    famille, id = tostring(famille or ""), tostring(id or "")
    if not FamilleValide(famille) then return false, "famille inconnue : " .. famille end
    local registre = Registre(famille)
    local existant = registre and registre.Get(id)
    if not existant then return false, "entrée inconnue : " .. id end
    if existant.brouillon == true then
        return false, "c'est un brouillon : il se supprime, il n'a pas besoin d'être masqué"
    end
    Masques(famille)[id] = true
    if registre.Retirer then registre.Retirer(id) end
    Brouillons.DiffuserMasque(famille, id, true)
    return true
end

-- Le rend au jeu. Au prochain chargement il revient de son fichier ; ici on ne
-- peut que lever le masque, l'entree elle-meme n'est plus en memoire.
function Brouillons.Demasquer(famille, id)
    famille, id = tostring(famille or ""), tostring(id or "")
    if not Brouillons.EstMasquee(famille, id) then return false end
    Masques(famille)[id] = nil
    Brouillons.DiffuserMasque(famille, id, false)
    return true
end

function Brouillons.CompteMasques()
    local total = 0
    for _, parFamille in pairs(Masques()) do
        for _ in pairs(parFamille) do total = total + 1 end
    end
    return total
end

-- ===== La synchro entre maitres du jeu =====================================
-- On est deux a ecrire du contenu en seance. Sans rien, chacun garde le sien
-- dans sa SavedVariables jusqu'au prochain export : l'autre ne voit pas l'etat
-- qu'on vient de creer, et une action qui s'y refere tombe dans le vide.
--
-- Ce qu'on ecrit part donc TOUT DE SUITE chez l'autre, et s'applique chez lui
-- sans rien demander (choix du 5 octobre 2026). Le detour par « veux-tu
-- l'accepter ? » serait une boite de dialogue de plus au milieu d'une partie,
-- pour une reponse qui serait toujours oui.
--
-- Le canal de presence plutot que le groupe : on n'est pas toujours groupes, et
-- ce canal-la, tout le monde l'a rejoint.
--
-- Deux garde-fous :
--   * ce qui ARRIVE ne repart pas (sinon deux ateliers se renvoient la meme
--     entree indefiniment) ;
--   * seul un maitre du jeu emet, et seul un maitre du jeu applique. Un joueur
--     n'a pas de brouillons, et n'a pas a en recevoir.

local enReception = false

local function Canal()
    local id = LCM.Presence and LCM.Presence.Rejoindre and LCM.Presence.Rejoindre()
    return id and "CHANNEL", id
end

function Brouillons.Diffuser(famille, entree, remplace)
    if enReception or not LCM.IsMaster() then return false end
    if not (LCM.Reseau and LCM.Reseau.Envoyer) then return false end
    local canal, cible = Canal()
    if not canal then return false end
    -- `etale` : une resolution entiere fait plusieurs milliers d'octets, donc
    -- des dizaines de morceaux. Envoyes d'un coup, le serveur en jette la
    -- moitie sans rien dire.
    return LCM.Reseau.Envoyer("brouillon", {
        f = tostring(famille), r = remplace and 1 or nil, e = entree,
    }, canal, cible, { etale = true })
end

function Brouillons.DiffuserSuppression(famille, id)
    if enReception or not LCM.IsMaster() then return false end
    if not (LCM.Reseau and LCM.Reseau.Envoyer) then return false end
    local canal, cible = Canal()
    if not canal then return false end
    return LCM.Reseau.Envoyer("brouillon-", { f = tostring(famille), id = tostring(id) },
        canal, cible)
end

function Brouillons.DiffuserMasque(famille, id, pose)
    if enReception or not LCM.IsMaster() then return false end
    if not (LCM.Reseau and LCM.Reseau.Envoyer) then return false end
    local canal, cible = Canal()
    if not canal then return false end
    return LCM.Reseau.Envoyer("masque", { f = tostring(famille), id = tostring(id),
        p = pose and 1 or nil }, canal, cible)
end

LCM.WhenReady(function()
    if not (LCM.Reseau and LCM.Reseau.Ecouter) then return end

    LCM.Reseau.Ecouter("masque", function(expediteur, donnees)
        if not LCM.IsMaster() then return end
        if expediteur == LCM.PlayerId() then return end
        local famille, id = tostring(donnees.f or ""), tostring(donnees.id or "")
        if not FamilleValide(famille) then return end
        enReception = true
        if donnees.p ~= nil then
            if Brouillons.Masquer(famille, id) then
                LCM.Info(string.format("%s a retiré « %s » (%s).", tostring(expediteur), id, famille))
            end
        else
            Brouillons.Demasquer(famille, id)
        end
        enReception = false
    end)

    LCM.Reseau.Ecouter("brouillon", function(expediteur, donnees)
        -- Un joueur ne doit rien faire de ca : il n'a pas d'atelier.
        if not LCM.IsMaster() then return end
        if expediteur == LCM.PlayerId() then return end
        local famille = tostring(donnees.f or "")
        local entree = donnees.e
        if type(entree) ~= "table" or not FamilleValide(famille) then return end
        enReception = true
        local ok, raison = Brouillons.Enregistrer(famille, entree, false, donnees.r ~= nil)
        enReception = false
        if ok then
            LCM.Ok(string.format("%s a écrit « %s » (%s) : c'est chez toi.",
                tostring(expediteur), tostring(entree.label or entree.id), famille))
            if Brouillons.onSynchro then Brouillons.onSynchro(famille, entree) end
        else
            -- On le DIT : une entree refusee en silence, c'est un contenu qui
            -- existe chez l'un et pas chez l'autre, et personne ne le sait.
            LCM.Alerte(string.format("« %s » de %s refusé : %s",
                tostring(entree.label or entree.id), tostring(expediteur), tostring(raison)))
        end
    end)

    LCM.Reseau.Ecouter("brouillon-", function(expediteur, donnees)
        if not LCM.IsMaster() then return end
        if expediteur == LCM.PlayerId() then return end
        local famille, id = tostring(donnees.f or ""), tostring(donnees.id or "")
        if not FamilleValide(famille) then return end
        enReception = true
        local retire = Brouillons.Supprimer(famille, id)
        enReception = false
        if retire then
            LCM.Info(string.format("%s a supprimé « %s » (%s).",
                tostring(expediteur), id, famille))
            if Brouillons.onSynchro then Brouillons.onSynchro(famille, nil) end
        end
    end)
end)

-- ===== Prise en compte immediate ===========================================
-- Les brouillons sont declares comme le reste, pour etre jouables des la
-- seance. S'ils existent deja en dur, on n'ecrase pas : le fichier fait foi.

LCM.WhenReady(function()
    -- Les masques d'abord : une entree publiee qu'on a retiree ne doit pas
    -- reapparaitre a chaque connexion. Le fichier la redonne, le masque la
    -- reprend.
    for famille, parFamille in pairs(Brouillons.Masques()) do
        local registre = Registre(famille)
        if registre and registre.Retirer then
            for id in pairs(parFamille) do
                if registre.Get(id) then registre.Retirer(id) end
            end
        end
    end

    -- On marque ce qui vient d'un brouillon : c'est ce qui permet ensuite de
    -- reperer un brouillon devenu redondant avec un fichier genere.
    for _, famille in ipairs(Brouillons.FAMILLES) do
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
    local masques = Brouillons.CompteMasques()
    if masques > 0 then
        LCM.Info(string.format("%d entrée(s) publiée(s) masquée(s) : retire-les du fichier "
            .. "à la prochaine passe (/lcm brouillons).", masques))
    end
end)

LCM.AddCommand("brouillons", "liste ce qui attend d'etre exporte", function()
    -- Les masques AUSSI : une entree publiee retiree en seance disparait du
    -- jeu, mais reste dans son fichier. Si personne ne le rappelle, elle y
    -- restera pour toujours et reviendra chez qui n'a pas le masque.
    local masques = {}
    for famille, parFamille in pairs(Brouillons.Masques()) do
        for id in pairs(parFamille) do
            masques[#masques + 1] = string.format("%s / %s", famille, id)
        end
    end
    table.sort(masques)
    if #masques > 0 then
        LCM.Info(string.format("%d entrée(s) publiée(s) masquée(s) — à RETIRER du fichier :", #masques))
        for _, ligne in ipairs(masques) do LCM.Info("   " .. ligne) end
    end

    local total = Brouillons.Count()
    if total == 0 then
        if #masques == 0 then LCM.Info("aucun brouillon.") end
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
