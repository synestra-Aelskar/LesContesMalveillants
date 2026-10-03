-- Objets : armes, armures et vetements, accessoires.
--
-- Un catalogue (Core/Catalogues.lua) : un objet est une DEFINITION, comme un
-- trait — icone, description, categorie, bonus, avantage. Il est cree en jeu
-- par le MJ (atelier), puis exporte vers Data/Genere/Objets.lua. Un objet
-- peut donner une primaire (le template en a : une armure a Force +1).
--
-- Cote entite, on ne stocke que ce qui est equipe : des identifiants, ranges
-- par categorie, autant que la categorie a d'emplacements.
--
--     entity.equipement = { arme = { "lame_de_givre" }, accessoire = { ... } }
--
-- On n'equipe que ce qu'on POSSEDE (3 octobre 2026) : l'objet doit etre dans
-- un sac du personnage, et il le quitte en passant sur lui ; le retirer le
-- remet dans le premier sac qui a de la place. Le compendium n'est pas un
-- magasin. Tout le monde peut donc equiper ses propres affaires ; remplir un
-- sac, en revanche, reste un geste du MJ (UI/Inventaires.lua).

local _, LCM = ...

-- `onglet` et `bloc` : les libelles de la fenetre Equipements du template.
-- `toutesLesCases` : la fenetre montre toutes les places, meme vides (les
-- cinq pieces d'armure, les cinq accessoires se lisent d'un coup d'oeil).
local Objets = LCM.Catalogue({
    nom = "objet", prefixe = "Objets", cleEntite = "equipement", primaires = true,
    categories = {
        { id = "arme",       label = "Arme",       onglet = "Armes",       bloc = "Armes principales" },
        { id = "equipement", label = "Armure",     onglet = "Armures",     bloc = "Armures et vêtements", toutesLesCases = true },
        { id = "accessoire", label = "Accessoire", onglet = "Accessoires", bloc = "Accessoires", toutesLesCases = true },
    },
    -- La valeur d'armure d'une piece (Equilibrage.armure). Une arme ou un
    -- accessoire n'en a pas.
    champs = {
        { cle = "armure", libelle = "armure", min = 0, categories = { equipement = true },
          defaut = function() return LCM.Equilibrage.armure.parDefaut end },
    },
})
LCM.Objets = Objets

-- Les noms que le reste de l'addon connaissait deja.
Objets.Icone = LCM.Icone
Objets.Emplacements = Objets.Capacite
Objets.EstEquipe = Objets.Porte
Objets.Equipes = Objets.Portes

-- ===== Equiper depuis les sacs =============================================
-- `Placer` et `Enlever` (le catalogue) restent les gestes bruts, sans sac :
-- ils servent aux regles et aux PNJ que le MJ habille. Les fenetres passent
-- par `Equiper` et `Desequiper`.

local function Ref(id) return "objets/" .. tostring(id) end

function Objets.Possede(entity, id)
    return LCM.Inventaire.Chercher(entity, Ref(id)) ~= nil
end

function Objets.Equiper(entity, id)
    if type(entity) ~= "table" then return false, "aucun personnage." end
    local objet = Objets.Get(id)
    if not objet then return false, "objet inconnu." end
    if not Objets.Possede(entity, objet.id) then
        return false, string.format("%s n'est dans aucun sac : on n'équipe que ce qu'on porte sur soi.", objet.label)
    end
    -- La place sur soi d'abord : si elle manque, l'objet reste dans son sac.
    local ok, raison = Objets.Placer(entity, objet.id)
    if not ok then return false, raison end
    LCM.Inventaire.Prendre(entity, Ref(objet.id))
    return true
end

-- Remet l'objet dans un sac. Sans place libre, il reste porte : on ne le
-- fait pas disparaitre faute de sac.
function Objets.Desequiper(entity, id)
    if not Objets.Porte(entity, id) then return false, "cet objet n'est pas équipé." end
    local objet = Objets.Get(id)
    if not objet then
        return false, string.format("« %s » n'existe pas dans cette version : il reste équipé.", tostring(id))
    end
    local ok, raison = LCM.Inventaire.Deposer(entity, Ref(objet.id), 1)
    if not ok then
        return false, string.format("%s reste équipé : %s", objet.label, raison == "aucune place libre."
            and "aucune place libre dans les sacs." or tostring(raison))
    end
    Objets.Enlever(entity, objet.id)
    return true
end

-- Ce que la fenetre propose : les objets de cette categorie qui sont dans les
-- sacs, une fois chacun, sauf ceux deja portes.
function Objets.CandidatsPossedes(entity, categorieId)
    local out, vus = {}, {}
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local emplacement = LCM.Inventaire.Emplacement(entity, categorie.id, index)
            for _, c in pairs(emplacement and type(emplacement.cases) == "table" and emplacement.cases or {}) do
                local id = type(c) == "table" and tostring(c.ref or ""):match("^objets/(.+)$")
                local objet = id and Objets.Get(id)
                if objet and objet.categorie == categorieId and not vus[objet.id] and not Objets.Porte(entity, objet.id) then
                    vus[objet.id] = true
                    out[#out + 1] = objet
                end
            end
        end
    end
    return out
end

-- ===== L'armure portee =====================================================
-- Chaque piece d'armure equipee apporte sa valeur ; la jauge #armure compte
-- ce que les pieces portees ont ENCAISSE sur leur total (0 / 2 : un t-shirt
-- neuf). L'usure est retenue PIECE PAR PIECE, sur l'entite : un t-shirt
-- abime qu'on enleve puis remet reste abime. On ne stocke que l'usure, par
-- identifiant d'objet (un objet ne se porte pas deux fois), et seulement
-- quand elle n'est pas nulle.
--
--     entity.usureArmure = { tshirt_de_lin = 1 }

local CATEGORIE_ARMURE = "equipement"

function Objets.Armure(objet)
    return type(objet) == "table" and math.max(0, math.floor(tonumber(objet.armure) or 0)) or 0
end

function Objets.Usure(entity, id)
    local usure = type(entity) == "table" and entity.usureArmure
    return type(usure) == "table" and math.max(0, math.floor(tonumber(usure[tostring(id)]) or 0)) or 0
end

-- Les pieces d'armure portees, dans l'ordre des emplacements :
-- { { id, label, valeur, usure, reste } }. Une piece dont la definition a
-- disparu ne protege plus : elle n'y figure pas.
function Objets.PiecesArmure(entity)
    local out = {}
    for _, id in ipairs(Objets.Ids(entity, CATEGORIE_ARMURE)) do
        local objet = Objets.Get(id)
        if objet then
            local valeur = Objets.Armure(objet)
            local usure = math.min(valeur, Objets.Usure(entity, id))
            out[#out + 1] = { id = objet.id, label = objet.label, valeur = valeur, usure = usure,
                              reste = valeur - usure }
        end
    end
    return out
end

-- La jauge #armure : { current = encaisse, max = total des pieces portees }.
function Objets.Protection(entity)
    local encaisse, total = 0, 0
    for _, piece in ipairs(Objets.PiecesArmure(entity)) do
        encaisse, total = encaisse + piece.usure, total + piece.valeur
    end
    return { current = encaisse, max = total }
end

-- Une piece encaisse `n` points (negatif : on la repare), bornee entre neuve
-- et epuisee. Renvoie ce qui a reellement ete pris. Efface ce qui revient a
-- zero.
function Objets.Encaisser(entity, id, n)
    local objet = Objets.Get(id)
    if type(entity) ~= "table" or not objet or objet.categorie ~= CATEGORIE_ARMURE then return 0 end
    local avant = Objets.Usure(entity, objet.id)
    local apres = math.max(0, math.min(Objets.Armure(objet), avant + math.floor(tonumber(n) or 0)))
    if apres == 0 then
        if type(entity.usureArmure) == "table" then
            entity.usureArmure[objet.id] = nil
            if next(entity.usureArmure) == nil then entity.usureArmure = nil end
        end
    else
        entity.usureArmure = type(entity.usureArmure) == "table" and entity.usureArmure or {}
        entity.usureArmure[objet.id] = apres
    end
    return apres - avant
end

-- Porte la jauge a `encaisse` en repartissant l'ecart sur les pieces portees :
-- les coups s'empilent dans l'ordre des emplacements, les reparations
-- commencent par la derniere piece touchee. C'est ce que font les + / - et le
-- R de la fiche ; une attaque, elle, choisit ses pieces (Actions.Zones).
function Objets.PorterProtection(entity, encaisse)
    local pieces = Objets.PiecesArmure(entity)
    local ecart = math.floor(tonumber(encaisse) or 0) - Objets.Protection(entity).current
    if ecart > 0 then
        for i = 1, #pieces do
            if ecart == 0 then break end
            ecart = ecart - Objets.Encaisser(entity, pieces[i].id, math.min(ecart, pieces[i].reste))
        end
    elseif ecart < 0 then
        for i = #pieces, 1, -1 do
            if ecart == 0 then break end
            ecart = ecart - Objets.Encaisser(entity, pieces[i].id, math.max(ecart, -pieces[i].usure))
        end
    end
    return true
end
