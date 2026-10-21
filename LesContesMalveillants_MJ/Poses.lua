-- Ce qui est POSE dans le monde : coffres, filons, vendeurs (21 octobre 2026).
--
-- Le MODELE d'un point (un coffre de telle taille, un filon de cuivre, une
-- echoppe) est du contenu, et vit dans la base depuis longtemps (famille
-- « points »). Ce qu'on en a pose — ou, avec quoi dedans, combien de stock,
-- qui l'arbitre — ne vivait que dans la sauvegarde du MJ qui l'avait pose : une
-- sauvegarde perdue emportait ses coffres, et l'autre MJ ne les connaissait que
-- s'il les avait vus passer en seance.
--
-- Chaque point pose part donc dans la base commune, comme une entree de plus
-- (famille « poses », reservee au MJ : jamais livree dans l'addon joueur — un
-- coffre cache se lirait dans les fichiers). Il passe par la meme file d'envoi
-- que le contenu (MJ/Brouillons.lua) : le service de synchro le publie au
-- /reload, et le fichier genere le rend a tous les MJ au chargement suivant.
--
-- La base est en RETARD sur la seance : elle ne bouge qu'au /reload. Elle sert
-- de sauvegarde et de point de depart, jamais d'etat en direct. Chaque module
-- fusionne donc ce qu'il en recoit avec ce qu'il sait (MJ/Coffres.lua,
-- Recoltes.lua, Marchands.lua) : la version la plus recente l'emporte, une
-- suppression notee ne revient pas, et rien n'est efface sur la seule absence
-- d'une ligne.
--
-- Seul l'ARBITRE d'un point l'ecrit : deux MJ qui ecrivaient la meme ligne se
-- contrediraient dans la base.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local NATURES = { coffre = true, ressource = true, vendeur = true }

LCM.Poses = LCM.Registre({
    nom = "pose", prefixe = "Poses",
    construire = function(definition, element, Erreur)
        local nature = tostring(definition.nature or "")
        if not NATURES[nature] then Erreur(element.id .. " : nature inconnue (" .. nature .. ")") end
        local auteur = tostring(definition.auteur or "")
        if auteur == "" then Erreur(element.id .. " : sans arbitre") end
        if type(definition.donnees) ~= "table" then Erreur(element.id .. " : sans donnees") end
        element.nature, element.auteur = nature, auteur
        element.epoque = math.max(0, math.floor(tonumber(definition.epoque) or 0))
        element.version = math.max(0, math.floor(tonumber(definition.version) or 0))
        element.def = tostring(definition.donnees.def or definition.def or "")
        element.donnees = LCM.Copie(definition.donnees)
        if type(definition.stock) == "table" then element.stock = LCM.Copie(definition.stock) end
    end,
})

local Poses = LCM.Poses
local FAMILLE = "poses"

-- Un nom lisible dans la base : « Coffre « Cassier fermé. » — Reika ».
local function Libelle(nature, defId, auteur)
    local modele = LCM.Points and LCM.Points.Get(defId)
    local noms = { coffre = "Coffre", ressource = "Récolte", vendeur = "Vendeur" }
    return string.format("%s « %s » — %s", noms[nature] or nature,
        tostring(modele and modele.label or defId), tostring(auteur):match("^[^-]+") or tostring(auteur))
end

-- Ce point, tel qu'il est maintenant, part dans la file d'envoi. `entree` est
-- celle du magasin du module ; elle est copiee, jamais tenue.
function Poses.Noter(nature, id, entree, extra)
    id = tostring(id or "")
    if id == "" or type(entree) ~= "table" or not LCM.Brouillons then return false end
    local donnees = LCM.Copie(entree)
    donnees.id = id
    local definition = {
        id = id, nature = nature, label = Libelle(nature, donnees.def, entree.auteur or LCM.PlayerId()),
        auteur = entree.auteur or LCM.PlayerId(),
        epoque = tonumber(entree.epoque) or 0, version = tonumber(entree.version) or 0,
        donnees = donnees,
    }
    for cle, valeur in pairs(extra or {}) do definition[cle] = valeur end
    LCM.Brouillons.Set(FAMILLE, definition)
    LCM.Brouillons.Masques(FAMILLE)[id] = nil
    LCM.Publier(Poses, definition)
    return true
end

-- Supprime POUR DE BON : la suppression part dans la base. (`Retirer`, celui du
-- registre, ne fait que l'oublier en memoire : MJ/Brouillons.lua s'en sert.)
function Poses.Supprimer(id)
    id = tostring(id or "")
    if id == "" or not LCM.Brouillons then return false end
    LCM.Brouillons.Remove(FAMILLE, id)
    LCM.Brouillons.Masques(FAMILLE)[id] = true
    Poses.Retirer(id)
    return true
end

-- Ce point n'est plus a moi (un autre MJ en a repris la garde) : je n'ecris
-- plus sa ligne, sans pour autant la supprimer — elle est a lui maintenant.
function Poses.Lacher(id)
    id = tostring(id or "")
    if id ~= "" and LCM.Brouillons then LCM.Brouillons.Remove(FAMILLE, id) end
end

-- Les points poses d'une nature, tels que la base (et la file d'envoi) les
-- donnent.
function Poses.De(nature)
    local out = {}
    for _, p in ipairs(Poses.list) do
        if p.nature == nature then out[#out + 1] = p end
    end
    return out
end

-- L'entree telle qu'un magasin la range : les donnees, plus l'arbitre et le
-- rang (epoque, version).
function Poses.Entree(p)
    local e = LCM.Copie(p.donnees)
    e.id, e.auteur, e.epoque, e.version = p.id, p.auteur, p.epoque, p.version
    return e
end

-- ===== Qui a pose quoi =======================================================
-- Chaque point retient le PERSONNAGE qui l'a pose (`posePar`), et ne le perd
-- jamais : l'arbitre (`auteur`) change quand un autre MJ reprend la garde, pas
-- lui. C'est ce qui permet de dire « ca, Synestra l'a pose ; ca, Moon ; ca,
-- Ekho » (le MJ, 21 octobre 2026).
--
-- Les listes de placement sont PERSONNELLES : chacun y voit ce qu'il a pose.
-- Ce que les autres ont pose se consulte en le demandant (« tous », ou un
-- personnage), en lecture seule : on va voir ou c'est, on n'y touche pas. Les
-- modeles, eux, sont communs quoi qu'il arrive.

function Poses.Court(nom)
    return (tostring(nom or ""):match("^[^-]+")) or tostring(nom or "")
end

-- Qui a pose cette entree d'un magasin : elle le dit, sinon son arbitre, sinon
-- moi (un point pose avant ce jour, dans mon propre magasin).
function Poses.PosePar(entree)
    return (entree and (entree.posePar or entree.auteur)) or LCM.PlayerId()
end

-- `filtre` : « mien » (le defaut), « tous », ou le nom d'un personnage.
function Poses.Garder(filtre, posePar)
    filtre = filtre or "mien"
    if filtre == "tous" then return true end
    if filtre == "mien" then return Poses.Court(posePar) == Poses.Court(LCM.PlayerId()) end
    return Poses.Court(posePar) == Poses.Court(filtre)
end

-- Les points d'une nature et d'un modele que la base connait et qui ne sont
-- pas dans MON magasin (`miens` : id -> vrai). Chacun est marque `autre`.
function Poses.Autres(nature, defId, miens)
    local out = {}
    for _, pose in ipairs(Poses.De(nature)) do
        if pose.def == defId and not (miens and miens[pose.id]) then
            local e = Poses.Entree(pose)
            e.posePar, e.autre = pose.donnees.posePar or pose.auteur, true
            out[#out + 1] = e
        end
    end
    table.sort(out, function(a, b) return (tonumber(a.quand) or 0) > (tonumber(b.quand) or 0) end)
    return out
end

-- Ce qu'une liste de placement montre, selon son filtre : mes points (`miens`,
-- ceux de mon magasin, que je peux retirer), puis ceux des autres, en lecture
-- seule — les copies que je tiens deja (`copies`, la garde des coffres) avant
-- ce que dit la base, plus en retard.
function Poses.Composer(nature, defId, miens, filtre, copies)
    local out, vus = {}, {}
    for _, e in ipairs(miens or {}) do
        vus[e.id] = true
        if Poses.Garder(filtre, Poses.PosePar(e)) then out[#out + 1] = e end
    end
    if (filtre or "mien") == "mien" then return out end
    local autres = {}
    for _, e in ipairs(copies or {}) do
        if not vus[e.id] then
            vus[e.id] = true
            e.autre, e.posePar = true, Poses.PosePar(e)
            autres[#autres + 1] = e
        end
    end
    for _, e in ipairs(Poses.Autres(nature, defId, vus)) do autres[#autres + 1] = e end
    for _, e in ipairs(autres) do
        if Poses.Garder(filtre, e.posePar) then out[#out + 1] = e end
    end
    return out
end

-- Le debut d'une ligne : qui l'a pose, quand ce n'est pas moi.
function Poses.Prefixe(e)
    local nom = Poses.Court(Poses.PosePar(e))
    if nom == Poses.Court(LCM.PlayerId()) and not e.autre then return "" end
    return string.format("|cffc8a45epar %s|r   ", nom)
end

-- Les personnages qui ont pose quelque chose de cette nature, moi compris.
function Poses.Poseurs(nature, miens)
    local noms, vus = {}, {}
    local function Ajouter(nom)
        nom = Poses.Court(nom)
        if nom ~= "" and not vus[nom] then vus[nom] = true noms[#noms + 1] = nom end
    end
    Ajouter(LCM.PlayerId())
    for _, e in ipairs(miens or {}) do Ajouter(Poses.PosePar(e)) end
    for _, pose in ipairs(Poses.De(nature)) do Ajouter(pose.donnees.posePar or pose.auteur) end
    table.sort(noms)
    return noms
end

-- Le bouton qui choisit ce que la liste montre. Un clic passe au suivant :
-- les miens, tous, puis chaque personnage. `poseurs()` rend les noms connus.
function Poses.Selecteur(parent, f, poseurs, changer)
    f.filtrePoses = f.filtrePoses or "mien"
    local b = LCM.UI.Bouton(parent, "", 230, 22, function()
        local choix = { "mien", "tous" }
        for _, nom in ipairs(poseurs()) do
            if nom ~= Poses.Court(LCM.PlayerId()) then choix[#choix + 1] = nom end
        end
        local suivant = choix[1]
        for i, c in ipairs(choix) do
            if c == f.filtrePoses then suivant = choix[i % #choix + 1] end
        end
        f.filtrePoses = suivant
        changer()
    end)
    function b:Actualiser()
        local filtre = f.filtrePoses
        self.label:SetText("Placements : " .. (filtre == "mien" and "les miens"
            or filtre == "tous" and "tous" or ("posés par " .. filtre)) .. "  ›")
    end
    LCM.UI.Bulle(b, "Qui a posé quoi",
        "Ta liste ne montre que ce que tu as posé. Clique pour voir ceux des autres : "
        .. "ils restent en lecture seule.")
    b:Actualiser()
    return b
end

-- Aller a un point d'un autre, comme a l'un des siens : .worldport, avec
-- l'altitude et la carte serveur quand on les a.
function Poses.Teleporter(e)
    local x, y, z, mapid = tonumber(e and e.x), tonumber(e and e.y), tonumber(e and e.z), tonumber(e and e.mapid)
    if not x or not y or not z or e.source == "carte" then
        return false, "coordonnées 3D indisponibles pour ce point."
    end
    local function Coord(n) return (string.format("%.6f", n):gsub(",", ".")) end
    local commande = ".worldport " .. Coord(x) .. " " .. Coord(y) .. " " .. Coord(z)
    if mapid then commande = commande .. " " .. tostring(math.floor(mapid)) end
    local D = LCM.DeplacementForce
    if not (D and D.Commande and D.Commande(commande)) then
        return false, "commande de téléportation non envoyée."
    end
    return true
end
