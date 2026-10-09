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
    -- Ce qu'une piece apporte suit son etat : voir Objets.ApportSelonEtat.
    apport = function(entity, objet, montant)
        return LCM.Objets.ApportSelonEtat(entity, objet, montant)
    end,
    etatDefaut = function() return LCM.Equilibrage.forge.etatObjet.base end,
    categories = {
        { id = "arme",       label = "Arme",       onglet = "Armes",       bloc = "Armes" },
        { id = "equipement", label = "Armure",     onglet = "Armures",     bloc = "Armures et vêtements", toutesLesCases = true },
        { id = "accessoire", label = "Accessoire", onglet = "Accessoires", bloc = "Accessoires", toutesLesCases = true },
    },
    -- La valeur d'armure d'une piece (Equilibrage.armure). Une arme ou un
    -- accessoire n'en a pas.
    champs = {
        { cle = "armure", libelle = "armure", min = 0, categories = { equipement = true },
          defaut = function() return LCM.Equilibrage.armure.parDefaut end },
        -- Combien de mains une arme demande. Une epee en prend une, et il
        -- reste la place d'un bouclier ; une arme a deux mains prend les deux
        -- (5 octobre 2026).
        { cle = "taille", libelle = "emplacements", min = 1, max = 2,
          categories = { arme = true }, defaut = 1 },
    },
    -- Ce que l'element occupe : sa taille s'il en declare une.
    taille = function(objet) return tonumber(objet and objet.taille) or 1 end,
})
LCM.Objets = Objets

-- Les noms que le reste de l'addon connaissait deja.
Objets.Icone = LCM.Icone
Objets.Emplacements = Objets.Capacite
Objets.EstEquipe = Objets.Porte
Objets.Equipes = Objets.Portes

-- Un objet BRISE : son etat est tombe a zero et il a survecu (il lui restait
-- une vie, ou il en a d'illimitees). Il reste porte, n'apporte plus rien, et
-- redevient normal des qu'on le repare au-dessus de zero.
--
-- On le DEDUIT de l'etat au lieu de le ranger quelque part : un drapeau de plus
-- serait un drapeau a tenir a jour, et il finirait par mentir apres une
-- reparation faite ailleurs.
function Objets.EstBrise(entity, objet)
    if type(objet) ~= "table" then objet = Objets.Get(objet) end
    if not objet then return false end
    local maximum = Objets.EtatMax(objet)
    if not maximum or maximum <= 0 then return false end
    return (maximum - Objets.Usure(entity, objet.id)) <= 0
end

-- ===== Ce qu'un objet apporte encore =======================================
-- Un objet abime donne moins. Il a perdu 20 % de son etat : il apporte 20 % de
-- moins (9 octobre 2026). Une armure en loques ne protege pas comme une neuve,
-- et cela rend la reparation utile avant la rupture, pas seulement apres.
--
-- ARRONDI AU SUPERIEUR, et sur la VALEUR ABSOLUE : « +5 » a 70 % d'etat donne
-- 3,5, donc 4. Un malus suit la meme pente — « -4 » devient « -3 » — sinon un
-- objet qui penalise deviendrait meilleur en s'abimant.
--
-- Brise (zero d'etat) : il n'apporte plus rien. Il reste porte, et la case
-- qu'il occupe ne donne rien tant qu'on ne l'a pas repare.
function Objets.ApportSelonEtat(entity, objet, montant)
    montant = tonumber(montant) or 0
    if montant == 0 then return 0 end
    local maximum = Objets.EtatMax(objet)
    if not maximum or maximum <= 0 then return montant end
    local reste = math.max(0, maximum - Objets.Usure(entity, objet.id))
    if reste >= maximum then return montant end
    if reste <= 0 then return 0 end
    local brut = math.abs(montant) * reste / maximum
    local garde = math.ceil(brut - 1e-9)
    return montant < 0 and -garde or garde
end

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

-- ===== Etat des objets portes ==============================================
-- Toute arme, armure ou accessoire porte possede son propre etat. La valeur
-- maximale vient de la jauge `etat` definie par la Forge ; une ancienne entree
-- qui n'en a pas encore recu part du defaut d'equilibrage. L'usure suit
-- l'objet quand on le range puis le reequipe.
--
--     entity.usureArmure = { tshirt_de_lin = 1 }
--
-- Le nom historique `usureArmure` est conserve dans la sauvegarde et dans le
-- paquet de fiche pour rester compatible avec les personnages existants. Il
-- contient maintenant l'usure de TOUS les objets portes.

local CATEGORIE_ARMURE = "equipement"

function Objets.Armure(objet)
    return type(objet) == "table" and math.max(0, math.floor(tonumber(objet.armure) or 0)) or 0
end

function Objets.EtatMax(objet)
    if type(objet) ~= "table" then objet = Objets.Get(objet) end
    local maximum = objet and type(objet.etat) == "table" and tonumber(objet.etat.max) or nil
    maximum = maximum or (LCM.Equilibrage.forge.etatObjet and LCM.Equilibrage.forge.etatObjet.base) or 10
    return math.max(0, math.floor(tonumber(maximum) or 0))
end

-- ===== Les vies d'un objet =================================================
-- Voir Data/Equilibrage.lua : la rarete (couleur du titre) dit combien de fois
-- un objet peut tomber a zero d'etat avant d'etre detruit.

-- Le reglage de sa rarete, ou le defaut si sa couleur n'en declare aucune.
local function Rarete(objet)
    local table_ = (LCM.Equilibrage and LCM.Equilibrage.viesParRarete) or {}
    local couleur = type(objet) == "table" and tostring(objet.couleurTitre or ""):upper() or ""
    return table_[couleur]
end

-- Combien de vies un objet a au depart. nil = illimitees.
function Objets.ViesMax(objet)
    if type(objet) ~= "table" then objet = Objets.Get(objet) end
    if not objet then return 0 end
    local r = Rarete(objet)
    if r then
        if r.illimitees then return nil end
        return math.max(0, math.floor(tonumber(r.vies) or 0))
    end
    return math.max(0, math.floor(tonumber(
        LCM.Equilibrage and LCM.Equilibrage.viesParDefaut or 0) or 0))
end

function Objets.ViesIllimitees(objet)
    return Objets.ViesMax(objet) == nil
end

-- Combien il en a DEJA perdu. Range comme l'usure : sur le personnage, pas sur
-- l'objet — deux exemplaires du meme modele ne se brisent pas ensemble.
function Objets.ViesPerdues(entity, id)
    local vies = type(entity) == "table" and entity.viesObjet
    return type(vies) == "table" and math.max(0, math.floor(tonumber(vies[tostring(id)]) or 0)) or 0
end

-- Ce qu'il lui reste, et son maximum. `nil, nil` pour les illimitees.
function Objets.Vies(entity, objet)
    if type(objet) ~= "table" then objet = Objets.Get(objet) end
    if not objet then return 0, 0 end
    local maximum = Objets.ViesMax(objet)
    if maximum == nil then return nil, nil end
    return math.max(0, maximum - Objets.ViesPerdues(entity, objet.id)), maximum
end

local function PerdreUneVie(entity, id)
    entity.viesObjet = type(entity.viesObjet) == "table" and entity.viesObjet or {}
    entity.viesObjet[tostring(id)] = Objets.ViesPerdues(entity, id) + 1
end

local function OublierLesVies(entity, id)
    if type(entity.viesObjet) ~= "table" then return end
    entity.viesObjet[tostring(id)] = nil
    if next(entity.viesObjet) == nil then entity.viesObjet = nil end
end

function Objets.Usure(entity, id)
    local usure = type(entity) == "table" and entity.usureArmure
    return type(usure) == "table" and math.max(0, math.floor(tonumber(usure[tostring(id)]) or 0)) or 0
end

-- Tous les objets portes, dans l'ordre des categories et des emplacements.
-- `reste` est l'etat actuel ; a zero, l'objet est detruit et retire.
function Objets.EquipementsEtat(entity)
    local out = {}
    for _, categorie in ipairs(Objets.CATEGORIES) do
        for _, id in ipairs(Objets.Ids(entity, categorie.id)) do
            local objet = Objets.Get(id)
            if objet then
                local valeur = Objets.EtatMax(objet)
                local usure = math.min(valeur, Objets.Usure(entity, id))
                out[#out + 1] = { id = objet.id, label = objet.label, categorie = objet.categorie,
                                  objet = objet, valeur = valeur, usure = usure,
                                  reste = valeur - usure }
            end
        end
    end
    return out
end


-- Les armures seulement, pour la jauge « Armure » de la fiche. Sa capacite
-- est maintenant leur etat forge, et non plus la petite statistique `armure`.
function Objets.PiecesArmure(entity)
    local out = {}
    for _, piece in ipairs(Objets.EquipementsEtat(entity)) do
        -- Une piece BRISEE ne protege plus. Depuis que l'etat a zero ne detruit
        -- plus l'objet (il perd une vie et reste porte), une loque restait dans
        -- la jauge et continuait d'encaisser — alors qu'elle n'apporte deja
        -- plus aucune statistique (10 octobre 2026).
        if piece.categorie == CATEGORIE_ARMURE and piece.reste > 0 then
            out[#out + 1] = piece
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

-- Un objet encaisse `n` points (negatif : on le repare), borne entre neuf et
-- detruit.
--
-- A zero d'etat il se BRISE : il perd une vie et reste porte, reparable. C'est
-- seulement quand il tombe a zero sans vie qu'il est detruit et retire, sans
-- revenir dans le sac (9 octobre 2026 : avant, le premier zero le detruisait,
-- ce qui etait trop dur).
--
-- `apres > avant` garde le compte juste : on ne perd une vie qu'en TOMBANT a
-- zero, pas a chaque coup encaisse une fois qu'on y est.
--
-- Renvoie la variation d'usure, le verdict de destruction, et si une vie vient
-- d'etre perdue.
function Objets.Encaisser(entity, id, n)
    local objet = Objets.Get(id)
    if type(entity) ~= "table" or not objet or not Objets.Porte(entity, objet.id) then return 0, false end
    local maximum = Objets.EtatMax(objet)
    local avant = Objets.Usure(entity, objet.id)
    local apres = math.max(0, math.min(maximum, avant + math.floor(tonumber(n) or 0)))
    local aZero = maximum > 0 and apres >= maximum and apres > avant
    local detruit, briseMaintenant = false, false
    if aZero then
        local restantes = Objets.Vies(entity, objet)
        if restantes == nil then
            -- Illimitees : il se brise, on ne compte rien, il n'est jamais
            -- detruit.
            briseMaintenant = true
        elseif restantes > 0 then
            PerdreUneVie(entity, objet.id)
            briseMaintenant = true
        else
            detruit = true
        end
    end
    if apres == 0 then
        if type(entity.usureArmure) == "table" then
            entity.usureArmure[objet.id] = nil
            if next(entity.usureArmure) == nil then entity.usureArmure = nil end
        end
    else
        entity.usureArmure = type(entity.usureArmure) == "table" and entity.usureArmure or {}
        entity.usureArmure[objet.id] = apres
    end
    if detruit then
        Objets.Enlever(entity, objet.id)
        if type(entity.usureArmure) == "table" then
            entity.usureArmure[objet.id] = nil
            if next(entity.usureArmure) == nil then entity.usureArmure = nil end
        end
        -- Detruit, il n'a plus d'histoire : un exemplaire neuf du meme modele
        -- repart avec toutes ses vies.
        OublierLesVies(entity, objet.id)
    end
    return apres - avant, detruit, briseMaintenant
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
