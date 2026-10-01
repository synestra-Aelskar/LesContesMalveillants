-- Points de vente et points de recolte.
--
-- Les deux sont la meme chose, et c'etait deja le cas dans Necronicon : une
-- liste d'offres, chacune avec sa quantite et son stock limite qui repousse.
-- Seule la nature change ce qu'on en dit — on ACHETE a un vendeur, on RECOLTE
-- sur un filon — et le prix, qui n'existe que chez le vendeur.
--
-- Le stock lui-meme est ailleurs (Core/Stock.lua) : c'est lui qui sait repousser
-- et se mettre d'accord avec les autres joueurs. Ici, on ne fait que donner la
-- regle de chaque offre et dire ce qu'elle rapporte.
--
-- Un point est du CONTENU : il vient des fichiers livres, pas de la sauvegarde.

local _, LCM = ...

LCM.Points = LCM.Registre({
    nom = "point", prefixe = "Points",
    construire = function(definition, element, Erreur)
        local nature = tostring(definition.nature or "ressource")
        if nature ~= "vendeur" and nature ~= "ressource" then
            Erreur(element.id .. " : nature inconnue (" .. nature .. ")")
        end
        element.nature = nature
        element.offres = {}
        for rang, offre in ipairs(definition.offres or {}) do
            if type(offre) ~= "table" then Erreur(element.id .. " : offre " .. rang .. " illisible") end
            local id = tostring(offre.id or offre.entree or rang)
            local construite = {
                id = id,
                entree = tostring(offre.entree or ""),
                label = tostring(offre.label or ""),
                icone = LCM.Icone(offre.icone),
                quantite = math.max(1, math.floor(tonumber(offre.quantite) or 1)),
                prix = tonumber(offre.prix),
                devise = offre.devise and tostring(offre.devise) or nil,
                -- La cle du stock porte le point ET l'offre : deux vendeurs qui
                -- proposent la meme herbe n'ont pas le meme filon.
                cle = element.id .. "/" .. id,
                stock = {
                    limite = math.max(0, math.floor(tonumber(offre.stock and offre.stock.limite) or 0)),
                    unites = math.max(0, math.floor(tonumber(offre.stock and offre.stock.unites) or 0)),
                    minutes = math.max(0, tonumber(offre.stock and offre.stock.minutes) or 0),
                },
            }
            if construite.entree == "" and construite.label == "" then
                Erreur(element.id .. " : offre " .. rang .. " sans entree ni libelle")
            end
            if nature == "vendeur" and construite.prix == nil then
                Erreur(element.id .. " : « " .. id .. " » est a vendre sans prix")
            end
            element.offres[#element.offres + 1] = construite
        end
    end,
})

local Points = LCM.Points

function Points.Nature(nature)
    local out = {}
    for _, point in ipairs(Points.list) do
        if point.nature == nature then out[#out + 1] = point end
    end
    return out
end

-- `entree` est une REFERENCE de compendium, « famille/identifiant » : la meme
-- que celle que range l'inventaire (objets/..., ressources/..., sacs/...).
-- Ce qu'une offre donne a voir : son libelle propre, sinon celui de l'entree.
function Points.Libelle(offre)
    if offre.label ~= "" then return offre.label end
    local entree = LCM.Compendium.Resoudre(offre.entree)
    return (entree and entree.label) or offre.entree
end

function Points.Icone(offre)
    if offre.icone then return offre.icone end
    local entree = LCM.Compendium.Resoudre(offre.entree)
    return (entree and entree.icone) or "Interface\\ICONS\\INV_Misc_QuestionMark"
end

function Points.Offre(pointId, offreId)
    local point = Points.Get(pointId)
    if not point then return nil end
    for _, offre in ipairs(point.offres) do
        if offre.id == tostring(offreId) then return offre, point end
    end
    return nil
end

-- ===== Prendre une offre ===================================================
-- Recolter et acheter font la meme chose : prendre au stock, puis ranger. Le
-- PAIEMENT n'est pas automatique — le prix est affiche, la table le regle.
-- C'est volontaire tant qu'on n'a pas tranche comment vit une bourse.

function Points.Prendre(entity, pointId, offreId)
    local offre, point = Points.Offre(pointId, offreId)
    if not offre then return false, "offre inconnue." end
    if type(entity) ~= "table" then return false, "aucun personnage." end

    local limite = LCM.Stock.Limite(offre.cle)
    if limite > 0 then
        local ok, restant = LCM.Stock.Consommer(offre.cle, 1)
        if not ok then return false, "il n'y en a plus." end
        offre.restant = restant
    end

    local range, raison = true, nil
    if offre.entree ~= "" then
        range, raison = LCM.Inventaire.Deposer(entity, offre.entree, offre.quantite)
    end
    if not range then
        -- On rend ce qu'on vient de prendre : un filon entame pour rien est une
        -- ressource perdue pour tout le monde.
        if limite > 0 then LCM.Stock.Rendre(offre.cle, 1) end
        return false, raison or "impossible de ranger."
    end
    return true, offre
end

-- Declarer les regles de stock a la connexion : elles vivent dans le contenu,
-- pas dans la sauvegarde, donc elles se reposent a chaque session.
LCM.WhenReady(function()
    for _, point in ipairs(Points.list) do
        for _, offre in ipairs(point.offres) do
            if offre.stock.limite > 0 then
                LCM.Stock.Declarer(offre.cle, offre.stock)
            end
        end
    end
end)
