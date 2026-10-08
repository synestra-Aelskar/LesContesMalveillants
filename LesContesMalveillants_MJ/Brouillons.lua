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
--
-- L'outil les connait toutes (6 octobre 2026) et les range en DEUX fichiers :
-- ce qui part chez les joueurs (Data/Genere/Atelier.lua) et ce qui reste chez
-- les MJ (LesContesMalveillants_MJ/Genere/Atelier_MJ.lua) — les PNJ, les jeux
-- d'equilibrage, et les resolutions de categorie « mj ».
Brouillons.FAMILLES = { "traits", "races", "objets", "etats", "apprentissages", "sacs",
    "informations", "listes", "devises", "ressources", "connaissances", "resolutions", "calculateurs", "pnj",
    "jeux", "points" }

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

-- Compare la forme construite du brouillon avec l'entree publiee. Les valeurs
-- brutes peuvent differer sans que le contenu differe ("3" contre 3, chemin
-- d'icone normalise, champs vides retires) : il faut donc comparer APRES le
-- passage par le registre. `brouillon` est un marqueur de provenance, pas du
-- contenu.
local function MemeValeur(gauche, droite)
    if type(gauche) ~= type(droite) then return false end
    if type(gauche) ~= "table" then return gauche == droite end
    for cle, valeur in pairs(gauche) do
        if cle ~= "brouillon" and not MemeValeur(valeur, droite[cle]) then return false end
    end
    for cle, valeur in pairs(droite) do
        if cle ~= "brouillon" and not MemeValeur(valeur, gauche[cle]) then return false end
    end
    return true
end

local function PublieIdentique(registre, entree)
    local existant = registre and registre.Get(entree.id)
    if not existant or existant.brouillon == true then return false end
    local ok, construit = pcall(registre.Construire, entree)
    return ok and MemeValeur(construit, existant)
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

-- Normalise un texte en identifiant lisible. Les anciennes entrees et les
-- sous-identifiants (par exemple une rarete) s'en servent encore. Les NOUVELLES
-- entrees, elles, recoivent plus bas un identifiant unique sans rapport avec
-- leur nom.
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
    if tostring(famille or "") == "points" then return LCM.Points end
    local nom = LCM.Compendium and LCM.Compendium.FAMILLES[tostring(famille or "")]
    return nom and LCM[nom] or nil
end
Brouillons.Registre = Registre

-- Un identifiant d'entree ne doit plus dependre de son libelle : deux objets
-- peuvent avoir exactement le meme nom. On combine l'identite du MJ, l'heure
-- serveur, le temps de la session, un compteur et de l'alea. Le resultat reste
-- compose uniquement de caracteres surs pour les sauvegardes et les liens.
local compteurIdentifiants = 0

local function Empreinte(texte)
    local valeur = 5381
    texte = tostring(texte or "")
    for index = 1, #texte do
        valeur = (valeur * 33 + texte:byte(index)) % 0x1000000
    end
    return valeur
end

local function IdentifiantOccupe(id)
    for _, famille in ipairs(Brouillons.FAMILLES) do
        if Brouillons.Get(famille, id) then return true end
        local registre = Registre(famille)
        if registre and registre.Get and registre.Get(id) then return true end
    end
    return false
end

function Brouillons.NouvelIdentifiant()
    local id
    repeat
        compteurIdentifiants = compteurIdentifiants + 1
        local secondes = tonumber((GetServerTime and GetServerTime())
            or (time and time()) or 0) or 0
        local session = math.floor((tonumber(GetTime and GetTime() or 0) or 0) * 1000)
        local alea = math.random(0, 0xFFFFFF)
        id = string.format("lcm_%06x_%08x_%08x_%04x_%06x",
            Empreinte(LCM.PlayerId()), secondes % 0x100000000,
            session % 0x100000000, compteurIdentifiants % 0x10000, alea)
    until not IdentifiantOccupe(id)
    return id
end

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
    -- Les points de vente/recolte assemblent du contenu deja forge : ils
    -- n'ont ni cout ni jeu d'equilibrage propre a verifier.
    if famille ~= "points" then
        local dansLeBareme, horsBareme = LCM.Forge.Verifier(famille, neuf)
        if not dansLeBareme then return false, horsBareme end
    end

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
local mjConnus, attentes, recus = {}, {}, {}
local ordreRecus, sequence = {}, 0
local horlogeSync

local function IdentifiantSync()
    sequence = sequence + 1
    return tostring(LCM.PlayerId()) .. ":" .. tostring(time and time() or 0) .. ":" .. tostring(sequence)
end

local function Canal()
    local id = LCM.Presence and LCM.Presence.Rejoindre and LCM.Presence.Rejoindre()
    return id and "CHANNEL", id
end

local function Accuser(expediteur, identifiant)
    if identifiant and identifiant ~= "" then
        LCM.Reseau.Envoyer("sync-ok", { s = identifiant }, "WHISPER", expediteur)
    end
end

-- Le meme envoi peut revenir apres une relance. Il doit etre acquitte de
-- nouveau, mais applique une seule fois.
local function CleReception(expediteur, identifiant)
    if not identifiant or identifiant == "" then return false end
    return tostring(expediteur) .. "\031" .. tostring(identifiant)
end

local function MarquerRecu(cle)
    if not cle then return end
    recus[cle] = true
    ordreRecus[#ordreRecus + 1] = cle
    if #ordreRecus > 200 then recus[table.remove(ordreRecus, 1)] = nil end
end

local function EnvoyerAttente(a)
    local canal, cible
    if a.cible then
        canal, cible = "WHISPER", a.cible
    else
        canal, cible = Canal()
        if not canal then return false end
    end
    local avant = LCM.Reseau.FileEnvoi and LCM.Reseau.FileEnvoi() or 0
    local ok, morceaux = LCM.Reseau.Envoyer("brouillon", a.donnees, canal, cible, { etale = true })
    if not ok then return false end
    a.essais = a.essais + 1
    -- L'accuse ne peut revenir qu'une fois tous les fragments sortis.
    a.reste = math.max(5, (avant + (tonumber(morceaux) or 1))
        * (LCM.Reseau.CADENCE or 0.25) + 3)
    return true
end

local function NoterMJ(nom)
    nom = tostring(nom or "")
    if nom == "" or nom == tostring(LCM.PlayerId()) then return end
    mjConnus[nom] = true
    -- Un brouillon diffuse avant la decouverte du binome bascule aussitot en
    -- chuchotement fiable, sans attendre la prochaine modification.
    for cle, a in pairs(attentes) do
        if not a.cible then
            attentes[cle] = nil
            a.cible, a.essais, a.reste = nom, 0, 0
            attentes[a.identifiant .. "\031" .. nom] = a
        end
    end
end

local function AnnoncerMJ()
    local canal, cible = Canal()
    if canal then return LCM.Reseau.Envoyer("mj-sync?", {}, canal, cible) end
    return false
end

local function BattreLaMesure()
    if horlogeSync or not CreateFrame then return end
    horlogeSync = CreateFrame("Frame")
    horlogeSync.cumul = 0
    horlogeSync:SetScript("OnUpdate", function(self, dt)
        self.cumul = self.cumul + (dt or 0)
        if self.cumul < 0.5 then return end
        local ecoule = self.cumul
        self.cumul = 0
        for cle, a in pairs(attentes) do
            a.reste = math.max(0, (a.reste or 0) - ecoule)
            if a.reste <= 0 then
                if a.essais >= 3 or (not a.cible and a.essais >= 1) then
                    attentes[cle] = nil
                    if a.cible then
                        LCM.Alerte("Synchronisation non confirmée par " .. tostring(a.cible)
                            .. " : « " .. tostring(a.donnees.e and (a.donnees.e.label or a.donnees.e.id)) .. " ».")
                    end
                elseif not EnvoyerAttente(a) then
                    -- Rejoindre un canal est asynchrone : on garde le paquet
                    -- au lieu de le perdre et on retente apres sa creation.
                    a.reste = 1
                end
            end
        end
    end)
end

function Brouillons.SynchronisationsEnAttente()
    local n = 0
    for _ in pairs(attentes) do n = n + 1 end
    return n
end

function Brouillons.Diffuser(famille, entree, remplace)
    if enReception or not LCM.IsMaster() then return false end
    if not (LCM.Reseau and LCM.Reseau.Envoyer) then return false end
    BattreLaMesure()
    AnnoncerMJ()
    local identifiant = IdentifiantSync()
    local donnees = { f = tostring(famille), r = remplace and 1 or nil,
        e = entree, s = identifiant }
    local trouve = false
    for nom in pairs(mjConnus) do
        trouve = true
        local a = { identifiant = identifiant, cible = nom, donnees = donnees,
            essais = 0, reste = 0 }
        attentes[identifiant .. "\031" .. nom] = a
        if not EnvoyerAttente(a) then a.reste = 1 end
    end
    if not trouve then
        local a = { identifiant = identifiant, donnees = donnees, essais = 0, reste = 0 }
        attentes[identifiant] = a
        if not EnvoyerAttente(a) then a.reste = 1 end
    end
    return true
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

    BattreLaMesure()

    LCM.Reseau.Ecouter("mj-sync?", function(expediteur)
        if not LCM.IsMaster() or expediteur == LCM.PlayerId() then return end
        NoterMJ(expediteur)
        LCM.Reseau.Envoyer("mj-sync", {}, "WHISPER", expediteur)
    end)
    LCM.Reseau.Ecouter("mj-sync", function(expediteur)
        if not LCM.IsMaster() or expediteur == LCM.PlayerId() then return end
        NoterMJ(expediteur)
    end)
    LCM.Reseau.Ecouter("sync-ok", function(expediteur, donnees)
        if not LCM.IsMaster() then return end
        NoterMJ(expediteur)
        local identifiant = tostring(donnees.s or "")
        attentes[identifiant .. "\031" .. tostring(expediteur)] = nil
        -- Compatibilite avec le premier envoi sur le canal, avant que le MJ
        -- distant ait eu le temps de se presenter.
        attentes[identifiant] = nil
    end)

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
        local identifiant = donnees.s and tostring(donnees.s) or nil
        local cleReception = CleReception(expediteur, identifiant)
        if cleReception and recus[cleReception] then
            Accuser(expediteur, identifiant)
            return
        end
        enReception = true
        local ok, raison = Brouillons.Enregistrer(famille, entree, false, donnees.r ~= nil)
        enReception = false
        if ok then
            MarquerRecu(cleReception)
            Accuser(expediteur, identifiant)
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

    AnnoncerMJ()
end)

-- Le canal prive apparait quelques instants apres la connexion. Une annonce
-- ici permet aussi aux brouillons restes en attente de trouver leur cible.
LCM.On("CHAT_MSG_CHANNEL_NOTICE", function(notice, _, _, _, _, _, _, _, nomCanal)
    if (notice == "YOU_JOINED" or notice == "YOU_CHANGED")
        and LCM.Presence and tostring(nomCanal or "") == tostring(LCM.Presence.CANAL) then
        AnnoncerMJ()
    end
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
    local retiresCarPublies = 0
    for _, famille in ipairs(Brouillons.FAMILLES) do
        local registre = Registre(famille)
        for _, entree in ipairs(Brouillons.List(famille)) do
            if not registre.Get(entree.id) then
                local ok, cree = pcall(registre.Add, entree)
                if ok and type(cree) == "table" then
                    cree.brouillon = true
                    if famille == "points" and registre.ActualiserRegles then
                        registre.ActualiserRegles(cree)
                    end
                elseif not ok then
                    LCM.Erreur(string.format("brouillon refuse (%s) : %s", famille, Raison(cree)))
                end
            elseif PublieIdentique(registre, entree) then
                -- L'outil d'export ne touche volontairement jamais au WTF.
                -- Quand la mise a jour revient, c'est donc l'addon qui retire
                -- la copie devenue strictement redondante. Une version locale
                -- differente reste intacte et continue d'etre signalee.
                if Brouillons.Remove(famille, entree.id) then
                    retiresCarPublies = retiresCarPublies + 1
                end
            end
        end
    end
    if retiresCarPublies > 0 then
        LCM.Info(string.format("%d brouillon(s) retire(s) : ils sont maintenant publies.",
            retiresCarPublies))
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
