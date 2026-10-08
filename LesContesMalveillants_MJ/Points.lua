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

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

LCM.Points = LCM.Registre({
    nom = "point", prefixe = "Points",
    construire = function(definition, element, Erreur)
        local nature = tostring(definition.nature or "ressource")
        if nature ~= "vendeur" and nature ~= "ressource" then
            Erreur(element.id .. " : nature inconnue (" .. nature .. ")")
        end
        element.nature = nature
        element.arcId = definition.arcId and tostring(definition.arcId) or nil
        element.icone = definition.icone and tostring(definition.icone):match("%S")
            and LCM.Icone(definition.icone) or nil
        element.deviseDefaut = definition.deviseDefaut and tostring(definition.deviseDefaut) or nil
        element.offres = {}
        local ids = {}
        local function ConstruireOffre(offre, rang)
            if type(offre) ~= "table" then Erreur(element.id .. " : offre " .. rang .. " illisible") end
            local id = tostring(offre.id or offre.entree or rang)
            if ids[id] then Erreur(element.id .. " : offre en double (" .. id .. ")") end
            ids[id] = true
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
            if nature == "vendeur" and not construite.devise then
                construite.devise = element.deviseDefaut
            end
            return construite
        end

        -- Les anciennes definitions portaient une liste plate. Le constructeur
        -- complet range maintenant les ventes par onglet, sans casser ces
        -- points deja publies ni les consommateurs qui lisent `offres`.
        element.onglets = {}
        local onglets = type(definition.onglets) == "table" and definition.onglets or nil
        if not onglets or #onglets == 0 then
            onglets = { { id = "onglet_1", label = "Articles", offres = definition.offres or {} } }
        end
        local rangGlobal = 0
        for index, onglet in ipairs(onglets) do
            local construit = {
                id = tostring(onglet.id or ("onglet_" .. index)),
                label = tostring(onglet.label or onglet.name or ("Onglet " .. index)),
                offres = {},
            }
            for _, offre in ipairs(onglet.offres or onglet.entries or {}) do
                rangGlobal = rangGlobal + 1
                local o = ConstruireOffre(offre, rangGlobal)
                construit.offres[#construit.offres + 1] = o
                element.offres[#element.offres + 1] = o
            end
            element.onglets[#element.onglets + 1] = construit
        end
        element.rachats = {}
        for index, onglet in ipairs(definition.rachats or {}) do
            local construit = {
                id = tostring(onglet.id or ("rachat_" .. index)),
                label = tostring(onglet.label or onglet.name or ("Rachats " .. index)),
                offres = {},
            }
            for _, offre in ipairs(onglet.offres or onglet.entries or {}) do
                rangGlobal = rangGlobal + 1
                construit.offres[#construit.offres + 1] = ConstruireOffre(offre, rangGlobal)
            end
            element.rachats[#element.rachats + 1] = construit
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

function Points.OffreRachat(pointId, offreId)
    local point = Points.Get(pointId)
    if not point then return nil end
    for _, onglet in ipairs(point.rachats or {}) do
        for _, offre in ipairs(onglet.offres or {}) do
            if offre.id == tostring(offreId) then return offre, point end
        end
    end
    return nil
end

-- Une creation faite en jeu arrive apres l'initialisation du contenu. Ses
-- regles de stock doivent donc etre posees immediatement, et pas seulement au
-- prochain /reload.
function Points.ActualiserRegles(point)
    if not point then return end
    for _, offre in ipairs(point.offres or {}) do
        if offre.stock and offre.stock.limite > 0 then
            LCM.Stock.Declarer(offre.cle, offre.stock)
        end
        if offre.prix and offre.devise and not LCM.Devises.Get(offre.devise) then
            LCM.Erreur(string.format("%s : « %s » se paie en « %s », qui n'existe pas.",
                point.label, Points.Libelle(offre), offre.devise))
        end
    end
end

-- ===== Prendre une offre ===================================================
-- Recolter et acheter font la meme chose : prendre au stock, puis ranger. Chez
-- un vendeur, le prix est PRELEVE dans la bourse.
--
-- L'ordre compte : on verifie d'abord qu'il peut payer, ensuite seulement on
-- entame le stock. Un filon entame pour un achat qui echoue est une ressource
-- perdue pour tout le monde.

function Points.Prendre(entity, pointId, offreId)
    if not LCM.IsMaster() then return false, "reserve au maitre du jeu." end
    local offre, point = Points.Offre(pointId, offreId)
    if not offre then return false, "offre inconnue." end
    if type(entity) ~= "table" then return false, "aucun personnage." end

    if offre.prix and offre.devise then
        if not LCM.Bourse.Peut(entity, offre.devise, offre.prix) then
            local devise = LCM.Devises.Get(offre.devise)
            return false, string.format("il te faut %d %s.", offre.prix,
                (devise and devise.label) or offre.devise)
        end
    end

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

    -- Le paiement vient en dernier : a ce stade, plus rien ne peut echouer, et
    -- le joueur a bien ce pour quoi il paie.
    if offre.prix and offre.devise then
        LCM.Bourse.Debiter(entity, offre.devise, offre.prix)
    end
    return true, offre
end

-- Le versant « Achats » du constructeur : le vendeur reprend une entree du
-- sac et verse son prix. Le retrait precede le credit, de sorte qu'un objet
-- absent ne puisse jamais produire de monnaie.
function Points.Racheter(entity, pointId, offreId)
    if not LCM.IsMaster() then return false, "reserve au maitre du jeu." end
    local offre = Points.OffreRachat(pointId, offreId)
    if not offre then return false, "offre de rachat inconnue." end
    if type(entity) ~= "table" then return false, "aucun personnage." end
    if offre.entree == "" then return false, "cette offre ne designe aucun objet." end
    local retire, raison = LCM.Inventaire.Prendre(entity, offre.entree)
    if not retire then return false, raison or "objet absent des sacs." end
    if offre.prix and offre.prix > 0 and offre.devise then
        LCM.Bourse.Crediter(entity, offre.devise, offre.prix)
    end
    return true, offre
end

-- Declarer les regles de stock a la connexion : elles vivent dans le contenu,
-- pas dans la sauvegarde, donc elles se reposent a chaque session.
--
-- C'est aussi le moment de verifier les devises : le compendium n'est complet
-- qu'une fois tout charge, et une faute de frappe dans un prix doit se voir au
-- demarrage, pas a la premiere tentative d'achat en seance.
LCM.WhenReady(function()
    for _, point in ipairs(Points.list) do
        Points.ActualiserRegles(point)
    end
end)
