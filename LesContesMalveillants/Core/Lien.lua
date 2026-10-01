-- Les liens de chat.
--
-- Un sort se cite dans la conversation comme un objet du jeu : « [Coupe
-- tranchante] », cliquable. C'est la technique des liens personnalises — un
-- `|H` d'un type que WoW ne connait pas, que le jeu laisse passer et qu'on
-- intercepte sur SetItemRef. Total RP 3 fait de meme, donc elle est eprouvee
-- dans l'environnement de la campagne.
--
-- Le lien ne porte PAS le sort : seulement a qui il est et son identifiant.
-- Un texte de chat est court, et un sort peut etre long. Celui qui clique et
-- qui ne connait pas le sort le DEMANDE a son proprietaire (Core/Reseau.lua) ;
-- la reponse arrive, l'infobulle s'affiche, et il peut l'ajouter au sien.

local _, LCM = ...

local Lien = {}
LCM.Lien = Lien

Lien.TYPE = "lcmsort"
local COULEUR = "ff8aa4ff"

-- Ce qu'on a recu d'autrui et qu'on n'a pas (encore) pris : garde en memoire
-- vive seulement. Rien n'entre en sauvegarde sans que le joueur l'accepte.
local connus = {}

local function Cle(proprietaire, id)
    return tostring(proprietaire) .. "/" .. tostring(id)
end

function Lien.Sort(entity, sort)
    if type(sort) ~= "table" then return nil end
    local proprietaire = (type(entity) == "table" and entity.id) or LCM.PlayerId()
    return string.format("|c%s|H%s:%s:%s|h[%s]|h|r",
        COULEUR, Lien.TYPE, proprietaire, sort.id, tostring(sort.label))
end

-- Pose le lien dans la zone de saisie si elle est ouverte ; sinon l'affiche,
-- ou il reste cliquable et copiable.
function Lien.Inserer(lien)
    if not lien then return false end
    local boite = _G.ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if boite and ChatEdit_InsertLink and ChatEdit_InsertLink(lien) then return true end
    LCM.Info(lien)
    return false
end

-- Ce qu'on sait d'un sort cite : le sien, celui d'un PNJ qu'on a, ou celui
-- qu'on nous a envoye il y a un instant.
function Lien.Trouver(proprietaire, id)
    local moi = LCM.Entities.Self()
    if moi and moi.id == proprietaire then
        local sort = LCM.Sorts.Get(moi, id)
        if sort then return sort, true end
    end
    local entity = LCM.Entities.Get(proprietaire)
    if entity then
        local sort = LCM.Sorts.Get(entity, id)
        if sort then return sort, true end
    end
    return connus[Cle(proprietaire, id)], false
end

function Lien.Retenir(proprietaire, sort)
    if type(sort) ~= "table" or not sort.id then return end
    connus[Cle(proprietaire, sort.id)] = sort
end

-- ===== L'infobulle =========================================================

function Lien.Montrer(proprietaire, id)
    local sort = Lien.Trouver(proprietaire, id)
    if not GameTooltip then return sort end
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    if not sort then
        GameTooltip:SetText(tostring(id), 1, 0.82, 0.3)
        GameTooltip:AddLine("Sort inconnu — demande en cours a " .. tostring(proprietaire) .. ".", 0.7, 0.68, 0.62, true)
        GameTooltip:Show()
        Lien.Demander(proprietaire, id)
        return nil
    end
    GameTooltip:SetText(tostring(sort.label), 1, 0.82, 0.3)
    if sort.description then GameTooltip:AddLine(sort.description, 0.86, 0.84, 0.78, true) end
    if sort.champ1 then GameTooltip:AddLine(sort.champ1, 0.6, 0.58, 0.54, true) end
    if sort.champ2 then GameTooltip:AddLine(sort.champ2, 0.6, 0.58, 0.54, true) end
    if sort.jet then
        GameTooltip:AddLine(string.format("Jet : %s a %s", tostring(sort.jet.min), tostring(sort.jet.max)), 0.9, 0.75, 0.35)
    end
    GameTooltip:AddLine("De " .. tostring(proprietaire), 0.5, 0.48, 0.45)
    GameTooltip:Show()
    return sort
end

-- ===== Le reseau ===========================================================

function Lien.Demander(proprietaire, id)
    local nom = tostring(proprietaire)
    if nom == "" or nom == LCM.PlayerId() then return false end
    return LCM.Reseau.Envoyer("sort?", { id = tostring(id) }, "WHISPER", nom)
end

-- Envoyer un sort a quelqu'un : c'est le « partage ». Le destinataire ne le
-- recoit pas dans sa sauvegarde — il recoit de quoi le regarder, et decide.
function Lien.Partager(entity, id, cible)
    local sort = LCM.Sorts.Get(entity, id)
    if not sort then return false, "sort inconnu." end
    cible = tostring(cible or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cible == "" then return false, "a qui ?" end
    local donnees = {
        id = sort.id, label = sort.label, description = sort.description,
        icone = sort.icone, champ1 = sort.champ1, champ2 = sort.champ2,
    }
    if sort.jet then donnees.jet = { min = sort.jet.min, max = sort.jet.max } end
    local ok, morceaux = LCM.Reseau.Envoyer("sort", donnees, "WHISPER", cible)
    if not ok then return false, "l'envoi a echoue." end
    return true, morceaux
end

LCM.WhenReady(function()
    -- On me demande un de mes sorts.
    LCM.Reseau.Ecouter("sort?", function(expediteur, donnees)
        local moi = LCM.Entities.Self()
        local sort = moi and LCM.Sorts.Get(moi, donnees.id)
        if not sort then return end
        Lien.Partager(moi, sort.id, expediteur)
    end)

    -- On me donne un sort. Il reste en memoire vive tant que je ne l'ai pas
    -- pris : rien n'entre dans ma sauvegarde sans que je le veuille.
    LCM.Reseau.Ecouter("sort", function(expediteur, donnees)
        local sort, raison = LCM.Sorts.Valider(donnees)
        if not sort then
            LCM.Debug(string.format("sort refuse de %s : %s", tostring(expediteur), tostring(raison)))
            return
        end
        sort.id = tostring(donnees.id or sort.label)
        Lien.Retenir(expediteur, sort)
        LCM.Info(string.format("%s te montre %s", tostring(expediteur), Lien.Sort({ id = expediteur }, sort)))
        if Lien.onRecu then Lien.onRecu(expediteur, sort) end
    end)
end)

-- Prendre un sort qu'on m'a montre.
function Lien.Adopter(proprietaire, id)
    local sort = Lien.Trouver(proprietaire, id)
    if not sort then return nil, "ce sort n'est pas la." end
    local moi = LCM.Entities.Self()
    if not moi then return nil, "aucun personnage." end
    return LCM.Sorts.Ajouter(moi, sort)
end

-- ===== Le clic =============================================================
-- SetItemRef recoit tous les clics sur un lien ; on ne retient que les notres
-- et on laisse passer le reste.

local function Intercepter(lien)
    local proprietaire, id = tostring(lien or ""):match("^" .. Lien.TYPE .. ":(.-):(.+)$")
    if not proprietaire then return false end
    Lien.Montrer(proprietaire, id)
    return true
end
Lien.Intercepter = Intercepter

if _G.SetItemRef and hooksecurefunc then
    hooksecurefunc("SetItemRef", function(lien) Intercepter(lien) end)
end
