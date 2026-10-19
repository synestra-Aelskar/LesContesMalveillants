-- La bibliotheque d'outils du maitre du jeu.
--
-- Les outils d'une scene vivent en memoire (Core/Outils.lua) : une jauge de
-- rituel ne survit pas au /reload, et c'est bien. Mais la barre « Rituel du
-- Sceau », ses couleurs et son maximum, on la refait a chaque fois.
--
-- La bibliotheque garde donc des MODELES : on en pose un sur la table en un
-- clic, on le regle, on le montre. C'etait la « Library » des Outils de
-- Necronicon (Master.lua : SaveMasterToolBarToLibrary), qui manquait tout
-- entiere a la premiere reprise.
--
-- Elle vit chez le MJ seul, dans LCM_MJ_DB : un joueur n'a pas ce dossier,
-- donc il n'a pas ces modeles. Et elle ne passe par aucun reseau — ce qui part
-- aux joueurs, c'est l'outil pose, pas le modele.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local Biblio = {}
MJ.Bibliotheque = Biblio
LCM.OutilsBiblio = Biblio

local function Base()
    _G.LCM_MJ_DB = type(_G.LCM_MJ_DB) == "table" and _G.LCM_MJ_DB or {}
    local db = _G.LCM_MJ_DB
    db.outils = type(db.outils) == "table" and db.outils or {}
    return db.outils
end

local function Prevenir()
    if Biblio.onChange then Biblio.onChange() end
end

-- Les modeles d'une sorte, dans l'ordre ou le MJ les a gardes.
function Biblio.Liste(sorte)
    local out = {}
    for _, modele in ipairs(Base()) do
        if not sorte or modele.sorte == sorte then out[#out + 1] = modele end
    end
    return out
end

function Biblio.Get(id)
    for _, modele in ipairs(Base()) do
        if modele.id == id then return modele end
    end
end

-- Garder un outil : on en copie les CHAMPS, pas son etat de scene. Sa valeur
-- courante en fait partie — une barre gardee a 0 sur 10 se repose a 0 sur 10,
-- c'est ce qu'on attend d'un modele.
--
-- Un modele de meme sorte et de meme libelle est REMPLACE : garder deux fois
-- « Rituel » apres l'avoir corrige doit laisser un seul modele, le dernier.
function Biblio.Garder(outil)
    if not LCM.IsMaster() then return nil, "réservé au maître du jeu." end
    local propre, raison = LCM.Outils.Verifier(outil)
    if not propre then return nil, raison end
    local modeles = Base()
    local garde = { sorte = propre.sorte }
    for _, champ in ipairs(LCM.Outils.Champs(propre.sorte)) do
        garde[champ.cle] = propre[champ.cle]
    end
    for rang, ancien in ipairs(modeles) do
        if ancien.sorte == garde.sorte and ancien.libelle == garde.libelle then
            garde.id = ancien.id
            modeles[rang] = garde
            Prevenir()
            return garde
        end
    end
    garde.id = string.format("m%d", (tonumber(_G.LCM_MJ_DB.outilsCompteur) or 0) + 1)
    _G.LCM_MJ_DB.outilsCompteur = (tonumber(_G.LCM_MJ_DB.outilsCompteur) or 0) + 1
    modeles[#modeles + 1] = garde
    Prevenir()
    return garde
end

function Biblio.Oublier(id)
    local modeles = Base()
    for rang, modele in ipairs(modeles) do
        if modele.id == id then
            table.remove(modeles, rang)
            Prevenir()
            return true
        end
    end
    return false, "modèle inconnu."
end

-- Poser un modele sur la table : il devient un outil de scene, reglable et
-- affichable comme un autre. Rend l'outil pose.
function Biblio.Poser(id)
    local modele = Biblio.Get(id)
    if not modele then return nil, "modèle inconnu." end
    return LCM.Outils.Poser(modele)
end

-- Poser ET montrer, d'un geste : c'est ce qu'on veut en seance.
function Biblio.Montrer(id, portee, cibles)
    local outil, raison = Biblio.Poser(id)
    if not outil then return nil, raison end
    local ok, pourquoi = LCM.Outils.Afficher(outil.id, portee or "groupe", cibles)
    if not ok then return outil, pourquoi end
    return outil
end
