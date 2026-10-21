-- Ce que le maitre du jeu ecrit en seance : traits, races, objets, coffres...
--
-- Une entree ENREGISTREE existe. Elle est jouable tout de suite, part chez
-- l'autre MJ dans l'instant, et entre dans la base commune au prochain /reload
-- (le service de synchro lit la sauvegarde, publie, et regenere les fichiers
-- de l'addon). Il n'y a pas d'etat intermediaire : une entree n'est pas « en
-- attente d'export », « publiee » ou « a reporter ». Elle est, ou elle n'est
-- pas (15 octobre 2026).
--
-- Ce qui n'est pas enregistre — un formulaire ouvert — n'existe pas, et ne
-- laisse rien derriere lui.
--
-- La sauvegarde n'est qu'une FILE D'ENVOI vers la base : `LCM_MJ_DB.brouillons`
-- (le nom reste, le service le lit) tient ce qui a ete enregistre depuis le
-- dernier passage du service, et `LCM_MJ_DB.masques` ce qui a ete supprime.
-- Le service vide la premiere une fois la base a jour ; la seconde se vide ici,
-- au chargement, quand le fichier genere ne porte plus l'entree. La structure
-- vit donc dans la base, jamais durablement dans la sauvegarde — c'est la
-- regle de l'addon.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local Brouillons = {}
MJ.Brouillons = Brouillons
LCM.Brouillons = Brouillons

-- Les familles que la base connait. En ajouter une ici ET dans l'outil de
-- synchro, qui les range en DEUX fichiers : ce qui part chez les joueurs
-- (Data/Genere/Atelier.lua) et ce qui reste chez les MJ
-- (LesContesMalveillants_MJ/Genere/Atelier_MJ.lua).
Brouillons.FAMILLES = { "traits", "races", "objets", "livres", "etats", "apprentissages", "sacs",
    "informations", "listes", "devises", "ressources", "connaissances", "resolutions", "calculateurs", "pnj",
    "jeux", "points", "tentes", "accessoires_camping",
    -- Ce qui est pose dans le monde (MJ/Poses.lua) : un etat, pas un modele,
    -- mais il voyage par la meme file pour arriver dans la base.
    "poses" }

-- Version du modele de la sauvegarde. 2 : plus de brouillons dormants ni de
-- masques « a reporter » (15 octobre 2026), voir la migration plus bas.
local VERSION = 2

local function Base()
    _G.LCM_MJ_DB = type(_G.LCM_MJ_DB) == "table" and _G.LCM_MJ_DB or {}
    return _G.LCM_MJ_DB
end

local function Store(famille)
    local db = Base()
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

-- Pose une entree dans la file d'envoi, sans verification. Les scenarios du
-- banc s'en servent pour preparer du contenu temoin avant la connexion.
function Brouillons.Set(famille, entree)
    famille = tostring(famille or "")
    if not FamilleValide(famille) then
        LCM.Erreur("famille inconnue : " .. famille)
        return false
    end
    if type(entree) ~= "table" or tostring(entree.id or "") == "" then
        LCM.Erreur("entrée sans identifiant")
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

-- Compare la forme construite d'une entree de la file avec celle du fichier
-- genere. Les valeurs brutes peuvent differer sans que le contenu differe
-- ("3" contre 3, chemin d'icone normalise, champs vides retires) : il faut donc
-- comparer APRES le passage par le registre.
local function MemeValeur(gauche, droite)
    if type(gauche) ~= type(droite) then return false end
    if type(gauche) ~= "table" then return gauche == droite end
    for cle, valeur in pairs(gauche) do
        if not MemeValeur(valeur, droite[cle]) then return false end
    end
    for cle, valeur in pairs(droite) do
        if not MemeValeur(valeur, gauche[cle]) then return false end
    end
    return true
end

-- ===== Saisie en seance ====================================================
-- Ce que l'atelier appelle. La saisie passe par les MEMES regles que le
-- chargement d'un fichier genere (`Construire` du registre) : une entree
-- refusee ici l'aurait ete au chargement, autant le dire tout de suite.

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
    if tostring(famille or "") == "poses" then return LCM.Poses end
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
-- Ce que les joueurs recoivent (Core/BasePublique.lua). Un addon joueur trop
-- ancien pour l'avoir ne doit pas empecher d'enregistrer.
-- Vrai pendant qu'on applique ce que l'autre MJ envoie : ce qui arrive ne
-- repart pas (voir la synchro entre maitres du jeu, plus bas).
local enReception = false

local RIEN = { Publier = function() return false end, Retirer = function() return false end }
local function Publique()
    return LCM.BasePublique and LCM.BasePublique.Publier and LCM.BasePublique or RIEN
end

local function Raison(message)
    return (tostring(message or ""):gsub("^LCM/%a+ : ", ""))
end

-- ===== Suppressions =========================================================
-- Supprimer une entree, c'est la retirer du jeu tout de suite et le noter ici,
-- pour que le service l'efface de la base au prochain /reload. Les personnages
-- qui la portaient gardent son identifiant : on n'efface pas les donnees d'un
-- joueur parce que le contenu a disparu.

local function Masques(famille)
    local db = Base()
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

-- Remplace le contenu d'une entree en place : les ecrans ouverts tiennent la
-- table elle-meme, les entites ne connaissent que son identifiant.
local function Remplacer(registre, existant, neuf)
    for cle in pairs(existant) do existant[cle] = nil end
    for cle, valeur in pairs(neuf) do existant[cle] = valeur end
    if type(registre.ActualiserRegles) == "function" then
        registre.ActualiserRegles(existant)
    end
    return existant
end

-- Un POINT (vendeur, ressource, coffre) qui change doit changer partout ou il
-- est pose, sans qu'on le retire et le repose (le MJ, 16 octobre 2026) :
-- changer la monnaie d'un marchand deja pose ne passait pas aux joueurs. Le
-- renvoi n'existait que dans certaines fenetres ; il passe ici, seul endroit
-- ou une entree s'ecrit ou s'efface — en seance comme a la reception de
-- l'autre MJ. Chaque module (MJ/Marchands.lua, Recoltes.lua, Coffres.lua)
-- s'y inscrit et renvoie ce qu'IL a pose.
local suiveursPoints = {}
function Brouillons.SurPoint(fonction)
    suiveursPoints[#suiveursPoints + 1] = fonction
end
local function PointChange(famille, id)
    if famille ~= "points" then return end
    for _, fonction in ipairs(suiveursPoints) do
        local ok, erreur = pcall(fonction, tostring(id))
        if not ok then LCM.Erreur("mise à jour des points posés : " .. tostring(erreur)) end
    end
end

-- Enregistre une entree et la rend jouable aussitot. `creation` : le MJ pense
-- creer une entree neuve, donc un identifiant deja pris est une collision, pas
-- une modification. Sinon, enregistrer une entree qui existe la MODIFIE, d'ou
-- qu'elle vienne. Renvoie true, ou false et la raison.
function Brouillons.Enregistrer(famille, entree, creation)
    famille = tostring(famille or "")
    if not FamilleValide(famille) then return false, "famille inconnue : " .. famille end
    local registre = Registre(famille)
    if not (registre and registre.Construire) then
        return false, "le format des " .. famille .. " n'est pas encore defini"
    end

    local ok, neuf = pcall(registre.Construire, entree)
    if not ok then return false, Raison(neuf) end

    if creation and (Brouillons.Get(famille, neuf.id) or registre.Get(neuf.id)) then
        return false, string.format("l'identifiant « %s » est déjà pris", neuf.id)
    end
    -- Le bareme de la forge BLOQUE (decision du 3 octobre 2026). Ici, et pas
    -- dans chaque fenetre : l'atelier, l'editeur et la modification groupee
    -- passent tous par cette porte.
    -- Les points de vente/recolte assemblent du contenu deja forge : ils
    -- n'ont ni cout ni jeu d'equilibrage propre a verifier.
    if famille ~= "points" then
        local dansLeBareme, horsBareme = LCM.Forge.Verifier(famille, neuf, enReception)
        if not dansLeBareme then return false, horsBareme end
    end

    -- Restes de l'ancien modele, qui ne veulent plus rien dire.
    if famille == "objets" then entree.ic = LCM.Copie(neuf.ic) end
    entree.brouillon, entree.remplacePublie = nil, nil
    Brouillons.Set(famille, entree)
    -- Ecrire une entree qu'on avait supprimee la fait revenir.
    Masques(famille)[tostring(neuf.id)] = nil
    -- Et chez l'autre maitre du jeu, tout de suite.
    Brouillons.Diffuser(famille, entree)

    local existant = registre.Get(neuf.id)
    if existant then
        Remplacer(registre, existant, neuf)
    else
        registre.Add(entree)
    end
    -- Et chez les joueurs connectes, tout de suite ; les autres la recoivent
    -- a leur connexion (Core/BasePublique.lua). Recue de l'autre MJ, elle
    -- est deja partie de chez lui.
    Publique().Publier(famille, entree, enReception)
    PointChange(famille, neuf.id)
    return true
end

-- Supprime une entree, d'ou qu'elle vienne. Renvoie true, ou false et la
-- raison.
function Brouillons.Supprimer(famille, id)
    famille, id = tostring(famille or ""), tostring(id or "")
    if not FamilleValide(famille) then return false, "famille inconnue : " .. famille end
    local registre = Registre(famille)
    local existant = registre and registre.Get(id)
    local enFile = Brouillons.Remove(famille, id)
    if not existant and not enFile then return false, "entrée inconnue : " .. id end
    -- Noter la suppression meme pour une entree enregistree dans la seance :
    -- le service a pu la publier entre-temps (un /reload suffit), et une
    -- suppression d'une entree absente de la base ne coute rien.
    Masques(famille)[id] = true
    if existant and registre.Retirer then registre.Retirer(id) end
    Brouillons.DiffuserSuppression(famille, id)
    Publique().Retirer(famille, id, enReception)
    PointChange(famille, id)
    return true
end

-- L'ancien nom de la suppression d'une entree « publiee ». Il n'y a plus
-- qu'une suppression.
Brouillons.Masquer = Brouillons.Supprimer

-- Annule une suppression pas encore passee dans la base. L'entree revient au
-- prochain chargement, de son fichier : en memoire, elle n'est plus la.
function Brouillons.Demasquer(famille, id)
    famille, id = tostring(famille or ""), tostring(id or "")
    if not Brouillons.EstMasquee(famille, id) then return false end
    Masques(famille)[id] = nil
    return true
end

-- ===== La synchro entre maitres du jeu =====================================
-- On est deux a ecrire du contenu en seance. La base ne se met a jour qu'au
-- /reload : sans rien, l'autre ne voit pas l'etat qu'on vient de creer, et une
-- action qui s'y refere tombe dans le vide.
--
-- Ce qu'on ecrit part donc TOUT DE SUITE chez l'autre, et s'applique chez lui
-- sans rien demander (choix du 5 octobre 2026). Le detour par « veux-tu
-- l'accepter ? » serait une boite de dialogue de plus au milieu d'une partie,
-- pour une reponse qui serait toujours oui.
--
-- Le canal de presence plutot que le groupe : on n'est pas toujours groupes, et
-- ce canal-la, tout le monde l'a rejoint.
--
-- Les sujets reseau gardent leurs anciens noms (« brouillon », « brouillon- »,
-- « masque ») : un MJ qui n'a pas encore mis a jour doit continuer a recevoir.
--
-- Deux garde-fous :
--   * ce qui ARRIVE ne repart pas (sinon deux ateliers se renvoient la meme
--     entree indefiniment) ;
--   * seul un maitre du jeu emet, et seul un maitre du jeu applique. Un joueur
--     n'a pas d'atelier, et n'a rien a recevoir.

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
    -- Une entree diffusee avant la decouverte du binome bascule aussitot en
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

function Brouillons.Diffuser(famille, entree)
    if enReception or not LCM.IsMaster() then return false end
    if not (LCM.Reseau and LCM.Reseau.Envoyer) then return false end
    BattreLaMesure()
    AnnoncerMJ()
    local identifiant = IdentifiantSync()
    -- `r = 1` : un MJ pas encore a jour refuserait sans lui de modifier une
    -- entree qu'il croit « publiee ».
    local donnees = { f = tostring(famille), r = 1, e = entree, s = identifiant }
    -- Le transport historique aplatit les nombres/booleens en texte et perd
    -- les tables vides. Garder les types des futurs parametres IC, comme la
    -- base publique le fait deja pour les definitions completes.
    if famille == "objets" and entree.ic then donnees.ic = LCM.Lien.Serialiser(entree.ic) end
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
    -- Les deux sujets : « brouillon- » retirait une entree de seance, « masque »
    -- une entree publiee. Un MJ pas encore a jour ne comprend que l'un ou
    -- l'autre selon l'entree ; chez un MJ a jour, le second ne trouve plus rien.
    LCM.Reseau.Envoyer("brouillon-", { f = tostring(famille), id = tostring(id) }, canal, cible)
    return LCM.Reseau.Envoyer("masque", { f = tostring(famille), id = tostring(id), p = 1 },
        canal, cible)
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

    local function Retirer(expediteur, donnees)
        if not LCM.IsMaster() then return end
        if expediteur == LCM.PlayerId() then return end
        local famille, id = tostring(donnees.f or ""), tostring(donnees.id or "")
        if not FamilleValide(famille) then return end
        enReception = true
        local retire = Brouillons.Supprimer(famille, id)
        enReception = false
        if retire then
            LCM.Info(string.format("%s a supprimé « %s » (%s).", tostring(expediteur), id, famille))
            if Brouillons.onSynchro then Brouillons.onSynchro(famille, nil) end
        end
    end

    -- Un MJ pas encore a jour envoie aussi « masque » sans `p` pour annuler une
    -- suppression : il n'y a rien a defaire ici, l'entree reviendra de la base.
    LCM.Reseau.Ecouter("masque", function(expediteur, donnees)
        if donnees.p ~= nil then Retirer(expediteur, donnees) end
    end)
    LCM.Reseau.Ecouter("brouillon-", Retirer)

    LCM.Reseau.Ecouter("brouillon", function(expediteur, donnees)
        -- Un joueur ne doit rien faire de ca : il n'a pas d'atelier.
        if not LCM.IsMaster() then return end
        if expediteur == LCM.PlayerId() then return end
        local famille = tostring(donnees.f or "")
        local entree = donnees.e
        if type(entree) ~= "table" or not FamilleValide(famille) then return end
        if famille == "objets" and donnees.ic then
            local ic = LCM.Lien.Deserialiser(donnees.ic)
            if type(ic) ~= "table" then LCM.Alerte("Données IC reçues illisibles."); return end
            entree.ic = ic
        end
        local identifiant = donnees.s and tostring(donnees.s) or nil
        local cleReception = CleReception(expediteur, identifiant)
        if cleReception and recus[cleReception] then
            Accuser(expediteur, identifiant)
            return
        end
        enReception = true
        local ok, raison = Brouillons.Enregistrer(famille, entree, false)
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

    AnnoncerMJ()
end)

-- Le canal prive apparait quelques instants apres la connexion. Une annonce
-- ici permet aussi aux entrees restees en attente de trouver leur cible.
LCM.On("CHAT_MSG_CHANNEL_NOTICE", function(notice, _, _, _, _, _, _, _, nomCanal)
    if (notice == "YOU_JOINED" or notice == "YOU_CHANGED")
        and LCM.Presence and tostring(nomCanal or "") == tostring(LCM.Presence.CANAL) then
        AnnoncerMJ()
    end
end)

-- ===== Au chargement ========================================================
-- Les fichiers generes sont charges ; on y pose ce que la file d'envoi tient
-- encore — ce qui a ete ecrit depuis le dernier passage du service, ou ce que
-- le service n'a pas pu envoyer. Ce n'est pas un etat a part : c'est le
-- contenu, simplement plus recent que le fichier.

-- Migration vers le modele 2 (15 octobre 2026). Les anciens masques cachaient
-- du contenu en seance sans jamais l'effacer de la base, et le service ne les
-- avait pas publies. Le MJ a choisi de GARDER ces entrees : on oublie les
-- masques, et elles reviennent. (Les 19 du compte AKRX sont mises de cote dans
-- Sauvegardes/entrees_masquees_2026-10-15/ du depot.)
local function Migrer()
    local db = Base()
    if (tonumber(db.version) or 1) >= VERSION then return end
    db.masques = nil
    for _, parFamille in pairs(Store()) do
        for _, entree in pairs(parFamille) do
            if type(entree) == "table" then
                entree.brouillon, entree.remplacePublie = nil, nil
            end
        end
    end
    db.version = VERSION
end

LCM.WhenReady(function()
    Migrer()

    -- Les suppressions d'abord. Si le fichier porte encore l'entree, la base
    -- n'a pas encore suivi : on la retire du jeu. S'il ne la porte plus, la
    -- suppression est faite, et la note n'a plus de raison d'etre.
    for famille, parFamille in pairs(Masques()) do
        local registre = Registre(famille)
        for id in pairs(parFamille) do
            if registre and registre.Get(id) then
                if registre.Retirer then registre.Retirer(id) end
                Publique().Retirer(famille, id, true)
            else
                parFamille[id] = nil
            end
        end
        if next(parFamille) == nil then Masques()[famille] = nil end
    end

    for _, famille in ipairs(Brouillons.FAMILLES) do
        local registre = Registre(famille)
        for _, entree in ipairs(Brouillons.List(famille)) do
            local existant = registre.Get(entree.id)
            local ok, neuf = pcall(registre.Construire, entree)
            if not ok then
                -- Refusee : on le dit, et elle reste dans la file pour que le
                -- MJ la corrige depuis l'atelier.
                LCM.Erreur(string.format("entrée refusée (%s / %s) : %s",
                    famille, tostring(entree.id), Raison(neuf)))
            elseif existant and MemeValeur(neuf, existant) then
                -- Le fichier la porte deja telle quelle : la base a suivi.
                Brouillons.Remove(famille, entree.id)
            elseif existant then
                Remplacer(registre, existant, neuf)
                Publique().Publier(famille, entree, true)
            else
                -- Protege lui aussi : une entree qui echoue ne doit pas
                -- emporter celles qui la suivent dans la file.
                local ajoute, cree = pcall(registre.Add, entree)
                if not ajoute then
                    LCM.Erreur(string.format("entrée refusée (%s / %s) : %s",
                        famille, tostring(entree.id), Raison(cree)))
                else
                    if famille == "points" and registre.ActualiserRegles then
                        registre.ActualiserRegles(cree)
                    end
                    Publique().Publier(famille, entree, true)
                end
            end
        end
    end
end)
