-- Consulter la fiche d'un autre joueur.
--
-- Le MJ demande, le joueur repond. L'inverse n'existe pas : un joueur n'a aucun
-- moyen de demander la fiche d'un autre — ce n'est pas une option, c'est qu'il
-- n'y a pas de code pour le faire, et que celui qui repond verifie qui demande.
--
-- Ce que ce fichier NE fait pas, et qu'il faut savoir : il n'empeche pas
-- quelqu'un qui aurait le dossier du compagnon MJ de poser la question. Un
-- addon vit sur la machine du joueur. La protection reelle est ailleurs : le
-- dossier `LesContesMalveillants_MJ` n'est pas livre aux joueurs. Le controle
-- ci-dessous arrete les curieux, pas un tricheur decide, et il ne faut pas lui
-- faire dire plus que ca.
--
-- Une fiche recue reste en MEMOIRE VIVE. On consulte, on ne collectionne pas :
-- rien n'entre en sauvegarde.

local _, LCM = ...

local Fiches = {}
LCM.Fiches = Fiches

local recues = {}

-- Combien de temps une fiche recue reste consultable. Au-dela, on la redemande
-- plutot que de montrer un etat d'il y a une heure pour l'etat actuel.
Fiches.FRAICHEUR = 300

local function Maintenant()
    return (GetTime and GetTime()) or 0
end

-- Qui a le droit de demander. Le groupe sert de garde-fou : on ne repond pas a
-- quelqu'un qui n'est meme pas avec nous.
local function DansLeGroupe(nom)
    if not (UnitName and GetNumGroupMembers) then return true end
    local nombre = GetNumGroupMembers() or 0
    if nombre == 0 then return false end
    local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
    for index = 1, nombre do
        local unite = prefixe .. index
        local n, royaume = UnitName(unite)
        if n then
            local complet = (royaume and royaume ~= "" and (n .. "-" .. royaume)) or n
            if complet == nom or n == tostring(nom):match("^[^-]+") then return true end
        end
    end
    return false
end
Fiches.DansLeGroupe = DansLeGroupe

-- ===== Cote joueur : repondre ==============================================

-- Ce qu'on envoie : les VALEURS de la fiche, rien d'autre. Pas les sorts
-- personnels, pas les brouillons — le MJ consulte une fiche, il ne fouille pas.
-- Les valeurs vont dans une SOUS-TABLE `v`, et pas sous un prefixe « v. » :
-- l'encodage du reseau se sert deja du point pour dire l'imbrication, et
-- « v.force » lui revenait comme une table nommee v. Un separateur qui veut
-- dire deux choses finit toujours par en dire une de trop.
function Fiches.Paquet(entity)
    local paquet = { nom = tostring(entity.name or entity.id), id = tostring(entity.id), v = {} }
    for champ, valeur in pairs(entity.values or {}) do
        -- Les jauges sont des tables : elles se disent « courant/max ».
        if type(valeur) == "table" then
            paquet.v[champ] = string.format("%s/%s",
                tostring(valeur.current or ""), tostring(valeur.max or ""))
        else
            paquet.v[champ] = tostring(valeur)
        end
    end
    return paquet
end

-- L'inverse : refaire une entite consultable a partir de ce qu'on a recu. Elle
-- n'est PAS enregistree ; elle sert a nourrir la fenetre de fiche.
function Fiches.Entite(paquet)
    local entity = { id = tostring(paquet.id or "?"), name = tostring(paquet.nom or "?"),
                     kind = "player", values = {}, distante = true }
    for champ, valeur in pairs(type(paquet.v) == "table" and paquet.v or {}) do
        -- Un champ absent du schema est ignore : ce qui arrive du reseau n'a
        -- pas a decider de ce qui existe dans la feuille.
        local field = LCM.Schema.Field(champ)
        if field then
            local courant, maximum = tostring(valeur):match("^(.-)/(.*)$")
            if courant and field.kind == "gauge" then
                entity.values[champ] = { current = tonumber(courant), max = tonumber(maximum) }
            else
                entity.values[champ] = tonumber(valeur) or valeur
            end
        end
    end
    return entity
end

-- ===== Cote MJ : demander ==================================================

function Fiches.Demander(joueur)
    joueur = tostring(joueur or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if joueur == "" then return false, "quel joueur ?" end
    if not LCM.IsMaster() then return false, "reserve au maitre du jeu." end
    if joueur == LCM.PlayerId() then return false, "c'est toi." end
    return LCM.Reseau.Envoyer("fiche?", {}, "WHISPER", joueur)
end

-- La derniere fiche recue de ce joueur, si elle est encore fraiche.
function Fiches.Recue(joueur)
    local entree = recues[tostring(joueur)]
    if not entree then return nil end
    if Maintenant() - entree.quand > Fiches.FRAICHEUR then return nil, entree.entity end
    return entree.entity, entree.entity
end

function Fiches.Oublier(joueur)
    recues[tostring(joueur)] = nil
end

function Fiches.Connues()
    local out = {}
    for joueur in pairs(recues) do out[#out + 1] = joueur end
    table.sort(out)
    return out
end

LCM.WhenReady(function()
    -- On me demande ma fiche.
    LCM.Reseau.Ecouter("fiche?", function(expediteur)
        if not DansLeGroupe(expediteur) then
            LCM.Debug(string.format("fiche refusee a %s : hors du groupe.", tostring(expediteur)))
            return
        end
        local moi = LCM.Entities.Self()
        if not moi then return end
        LCM.Reseau.Envoyer("fiche", Fiches.Paquet(moi), "WHISPER", expediteur)
        LCM.Info(string.format("%s a consulte ta fiche.", tostring(expediteur)))
    end)

    -- Une fiche arrive.
    LCM.Reseau.Ecouter("fiche", function(expediteur, donnees)
        local entity = Fiches.Entite(donnees)
        recues[tostring(expediteur)] = { entity = entity, quand = Maintenant() }
        if Fiches.onRecue then Fiches.onRecue(expediteur, entity) end
    end)
end)
