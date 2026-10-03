-- Creation de personnage : le moteur.
--
-- Ici, aucune fenetre — seulement les budgets, les plafonds et les refus.
-- L'ecran (UI/Creation.lua) ne fait que poser des questions a ce fichier, ce
-- qui rend les regles verifiables au banc sans dessiner quoi que ce soit.
--
-- Un brouillon est une table plate :
--     { nom, race, niveau, valeurs = { [champ] = n }, traits = { id, ... } }
-- Les identifiants de `valeurs` sont ceux du schema : au bout du compte, creer
-- le personnage se resume a recopier cette table.

local _, LCM = ...

-- Core/ se charge avant Data/ : l'equilibrage n'existe pas encore ici. On le
-- resout au premier appel plutot que de capturer une table vide.
local E
local function Eq()
    E = E or LCM.Equilibrage
    return E
end

local Creation = {}
LCM.Creation = Creation

-- Les cinq etapes, dans l'ordre. L'ecran s'y conforme ; il ne les invente pas.
-- Les onglets de la fenetre Creation du template, dans son ordre.
Creation.ETAPES = {
    { id = "bienvenue",    label = "Bienvenue" },
    { id = "generale",     label = "Générale" },
    { id = "statistiques", label = "Statistiques" },
    { id = "expertises",   label = "Expertises" },
    -- Les mecaniques ont leur propre etape depuis le 3 octobre 2026 : elles
    -- ont leur budget, leurs vingt lignes, et elles passaient inapercues en
    -- bas de la page des expertises.
    { id = "mecaniques",   label = "Mécaniques" },
    { id = "penetrations", label = "Pénétrations" },
    { id = "resistances",  label = "Résistances" },
    { id = "traits",       label = "Traits" },
}

function Creation.Nouveau(niveau)
    return {
        nom = "",
        race = "",
        niveau = tonumber(niveau) or Eq().creation.niveauDepart,
        valeurs = {},
        traits = {},
    }
end

function Creation.Valeur(brouillon, champ)
    return tonumber(brouillon.valeurs[champ]) or 0
end

local function Somme(brouillon, liste)
    local total = 0
    for _, entree in ipairs(liste) do
        total = total + Creation.Valeur(brouillon, entree.id or entree)
    end
    return total
end

-- ===== Les listes de lignes d'une categorie ================================

local function Expertises()
    local out = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        if tab.id == "expertises" then
            for _, section in ipairs(tab.sections) do
                for _, field in ipairs(section.fields) do
                    out[#out + 1] = { id = field.id, label = field.label, groupe = section.label }
                end
            end
        end
    end
    return out
end

local cacheExpertises
function Creation.Expertises()
    cacheExpertises = cacheExpertises or Expertises()
    return cacheExpertises
end

local cacheMecaniques
function Creation.Mecaniques()
    if not cacheMecaniques then
        cacheMecaniques = {}
        for _, mecanique in ipairs(Eq().mecaniques) do
            cacheMecaniques[#cacheMecaniques + 1] = { id = "meca_" .. mecanique.id, label = mecanique.label }
        end
    end
    return cacheMecaniques
end

function Creation.Types(cote)
    local prefixe = (cote == "resistance") and "resi_" or "pen_"
    local out = {}
    for _, t in ipairs(Eq().types) do
        out[#out + 1] = { id = prefixe .. t.id, label = t.label, groupe = t.groupe }
    end
    return out
end

function Creation.Lignes(categorie)
    if categorie == "primaires" then return Eq().primaires end
    if categorie == "mecaniques" then return Creation.Mecaniques() end
    if categorie == "secondaires" then return Eq().secondaires end
    if categorie == "expertises" then return Creation.Expertises() end
    if categorie == "penetration" then return Creation.Types("penetration") end
    if categorie == "resistance" then return Creation.Types("resistance") end
    return {}
end

-- ===== Budgets =============================================================
-- Les points d'expertise, de mecanique, de penetration et de resistance ne
-- sont pas des budgets fixes : ils dependent de ce qu'on a deja investi
-- ailleurs. C'est voulu — c'est ce qui fait qu'un choix de statistique se paie
-- ou se rembourse plus loin.

function Creation.Total(brouillon, categorie)
    local niveau = brouillon.niveau
    if categorie == "primaires" then
        return Eq().Bareme(Eq().creation.primaires, niveau)
    elseif categorie == "secondaires" then
        return Eq().Bareme(Eq().creation.secondaires, niveau)
    elseif categorie == "expertises" then
        return Eq().Bareme(Eq().creation.expertises, niveau)
            + Eq().conversion.expertises * Creation.Valeur(brouillon, "sec_expertises")
    elseif categorie == "mecaniques" then
        return Eq().Bareme(Eq().creation.mecaniques, niveau)
            + Eq().conversion.mecaniques * Creation.Valeur(brouillon, "sec_mecanique")
    elseif categorie == "penetration" then
        local p = Eq().penetration.points
        local stats = 0
        for _, id in ipairs(Eq().statsDeDegats) do stats = stats + Creation.Valeur(brouillon, id) end
        return math.floor(p.base + p.parNiveau * niveau + p.parStatDeDegats * stats
            + p.parSecondaire * Creation.Valeur(brouillon, "sec_penetration"))
    elseif categorie == "resistance" then
        local p = Eq().resistance.points
        return math.floor(p.base + p.parNiveau * niveau
            + p.parConstitution * Creation.Valeur(brouillon, "constitution")
            + p.parEsprit * Creation.Valeur(brouillon, "esprit")
            + p.parSecondaire * Creation.Valeur(brouillon, "sec_resistance"))
    elseif categorie == "traits" then
        local t = Eq().creation.traits
        return t.base + math.floor(niveau / t.niveauxParPoint)
    end
    return 0
end

-- Ce que coute UN point sur cette ligne. Adresse et Esprit valent deux points,
-- un point d'action en vaut huit : le budget ne peut donc pas se contenter de
-- compter les valeurs.
function Creation.Cout(categorie, champ)
    if categorie == "primaires" then
        for _, stat in ipairs(Eq().primaires) do
            if stat.id == champ then return stat.cout or Eq().primaire.cout or 1 end
        end
    elseif categorie == "secondaires" then
        for _, pool in ipairs(Eq().secondaires) do
            if pool.id == champ then return pool.cout or 1 end
        end
    end
    return 1
end

function Creation.Depense(brouillon, categorie)
    if categorie == "primaires" or categorie == "secondaires" then
        local total = 0
        for _, ligne in ipairs(Creation.Lignes(categorie)) do
            total = total + Creation.Valeur(brouillon, ligne.id) * Creation.Cout(categorie, ligne.id)
        end
        return total
    elseif categorie == "traits" then
        local total = 0
        for _, id in ipairs(brouillon.traits) do
            local trait = LCM.Traits.Get(id)
            total = total + (trait and trait.cout or 1)
        end
        return total
    end
    return Somme(brouillon, Creation.Lignes(categorie))
end

function Creation.Budget(brouillon, categorie)
    local total = Creation.Total(brouillon, categorie)
    local depense = Creation.Depense(brouillon, categorie)
    return { total = total, depense = depense, reste = total - depense }
end

-- ===== Plafonds ============================================================

function Creation.Plafond(brouillon, categorie, champ)
    local niveau = brouillon.niveau
    if categorie == "primaires" then
        for _, stat in ipairs(Eq().primaires) do
            if stat.id == champ then
                return Eq().Bareme(stat.plafond or Eq().primaire.plafond, niveau)
            end
        end
        return Eq().Bareme(Eq().primaire.plafond, niveau)
    elseif categorie == "expertises" or categorie == "mecaniques" then
        -- Meme limite que pour une expertise : dans Necronicon, les deux
        -- grilles pointaient vers le meme champ « Max expertise ».
        return Eq().Bareme(Eq().expertise.plafond, niveau)
    elseif categorie == "secondaires" then
        for _, pool in ipairs(Eq().secondaires) do
            if pool.id == champ then return Eq().Bareme(pool.plafond, niveau) end
        end
        return 0
    elseif categorie == "penetration" then
        local stats = 0
        for _, id in ipairs(Eq().statsDeDegats) do stats = stats + Creation.Valeur(brouillon, id) end
        local p = Eq().penetration.plafond
        return math.floor(stats / p.diviseurStats) + p.base
    elseif categorie == "resistance" then
        local p = Eq().resistance.plafond
        return math.floor(Creation.Valeur(brouillon, "constitution") * p.parConstitution) + p.base
    end
    return 0
end

-- ===== Ecriture ============================================================
-- Un seul point d'entree pour modifier un brouillon : il refuse et dit
-- pourquoi, plutot que de corriger en silence.

function Creation.Definir(brouillon, categorie, champ, valeur)
    valeur = math.floor(tonumber(valeur) or 0)
    if valeur < 0 then return false, "une valeur ne descend pas sous zero." end

    local avant = Creation.Valeur(brouillon, champ)
    local plafond = Creation.Plafond(brouillon, categorie, champ)
    -- Un depassement peut apparaitre APRES coup, quand une statistique baisse
    -- et rabote un plafond. Redescendre doit rester possible, sinon la ligne
    -- est prise au piege : on refuse seulement ce qui monte au-dessus.
    if valeur > plafond and valeur >= avant then
        return false, string.format("plafond atteint : %d au maximum a ce niveau.", plafond)
    end

    brouillon.valeurs[champ] = (valeur ~= 0) and valeur or nil

    local budget = Creation.Budget(brouillon, categorie)
    if budget.reste < 0 then
        brouillon.valeurs[champ] = (avant ~= 0) and avant or nil
        local reste = Creation.Budget(brouillon, categorie).reste
        return false, string.format("il ne reste que %d point%s.", reste, reste > 1 and "s" or "")
    end

    -- Monter une statistique de degats ou la constitution peut abaisser un
    -- plafond de type deja rempli : on le dit, on ne corrige pas en douce.
    return true, Creation.Debordements(brouillon)
end

-- Les lignes qui depassent leur plafond apres coup (baisse d'une statistique,
-- changement de niveau). Retourne une liste vide quand tout va bien.
function Creation.Debordements(brouillon)
    local out = {}
    for _, categorie in ipairs({ "primaires", "secondaires", "expertises", "mecaniques", "penetration", "resistance" }) do
        for _, ligne in ipairs(Creation.Lignes(categorie)) do
            local plafond = Creation.Plafond(brouillon, categorie, ligne.id)
            local valeur = Creation.Valeur(brouillon, ligne.id)
            if valeur > plafond then
                out[#out + 1] = { categorie = categorie, id = ligne.id, label = ligne.label,
                    valeur = valeur, plafond = plafond }
            end
        end
    end
    return out
end

-- La plus grande valeur qu'on puisse encore se payer sur cette ligne : c'est ce
-- que pose le bouton « M ».
function Creation.Maximum(brouillon, categorie, champ)
    local plafond = Creation.Plafond(brouillon, categorie, champ)
    local cout = Creation.Cout(categorie, champ)
    local valeur = Creation.Valeur(brouillon, champ)
    local reste = Creation.Budget(brouillon, categorie).reste
    if cout <= 0 then return plafond end
    return math.min(plafond, valeur + math.floor(reste / cout))
end

-- Remet une ligne a zero, ou toute une categorie, ou tout le brouillon. Les
-- valeurs partent : ce sont les points qu'on recupere, pas une mise en forme.
function Creation.Remettre(brouillon, categorie, champ)
    brouillon.valeurs[champ] = nil
    return true
end

function Creation.RemettreCategorie(brouillon, categorie)
    if categorie == "traits" then
        brouillon.traits = {}
        return true
    end
    for _, ligne in ipairs(Creation.Lignes(categorie)) do
        brouillon.valeurs[ligne.id] = nil
    end
    return true
end

Creation.CATEGORIES = { "primaires", "secondaires", "expertises", "mecaniques",
    "penetration", "resistance", "traits" }

-- Reste-t-il quelque chose a ACHETER dans cette categorie ? Un budget qu'on ne
-- peut plus depenser ne doit pas interdire la creation : si toutes les lignes
-- sont a leur plafond, ou si plus aucun trait n'est abordable, le point qui
-- traine est impossible a placer, et bloquer dessus serait un cul-de-sac.
function Creation.PeutEncoreDepenser(brouillon, categorie)
    local reste = Creation.Budget(brouillon, categorie).reste
    if reste <= 0 then return false end
    if categorie == "traits" then
        for _, trait in ipairs(LCM.Traits.list) do
            if (tonumber(trait.cout) or 1) <= reste and not Creation.ATrait(brouillon, trait.id) then
                return true
            end
        end
        return false
    end
    for _, ligne in ipairs(Creation.Lignes(categorie)) do
        local id = ligne.id or ligne
        if Creation.Maximum(brouillon, categorie, id) > Creation.Valeur(brouillon, id) then return true end
    end
    return false
end

-- Ce qu'on en dit au joueur : « il reste 3 points de statistiques », pas
-- « il reste 3 points de primaires ».
Creation.LIBELLES = {
    primaires = "statistiques", secondaires = "statistiques secondaires",
    expertises = "expertises", mecaniques = "mécaniques de compétence",
    penetration = "pénétrations", resistance = "résistances", traits = "traits",
}

function Creation.RemettreTout(brouillon)
    for _, categorie in ipairs(Creation.CATEGORIES) do
        Creation.RemettreCategorie(brouillon, categorie)
    end
    return true
end

-- Ce trait est-il deja pris ? La liste est courte, la boucle suffit.
function Creation.ATrait(brouillon, id)
    for _, porte in ipairs(brouillon.traits or {}) do
        if porte == id then return true end
    end
    return false
end

function Creation.AjouterTrait(brouillon, id)
    local trait = LCM.Traits.Get(id)
    if not trait then return false, "trait inconnu." end
    if Creation.ATrait(brouillon, id) then return false, "trait deja choisi." end
    local budget = Creation.Budget(brouillon, "traits")
    if trait.cout > budget.reste then
        return false, string.format("%s coute %d point%s, il en reste %d.",
            trait.label, trait.cout, trait.cout > 1 and "s" or "", budget.reste)
    end
    brouillon.traits[#brouillon.traits + 1] = id
    return true
end

function Creation.RetirerTrait(brouillon, id)
    for index, porte in ipairs(brouillon.traits) do
        if porte == id then table.remove(brouillon.traits, index) return true end
    end
    return false
end

-- ===== Validation et application ===========================================

function Creation.Problemes(brouillon)
    local out = {}
    if tostring(brouillon.nom or ""):gsub("%s+", "") == "" then
        out[#out + 1] = "il faut un nom."
    end
    -- La race se CHOISIT dans le compendium, et nulle part ailleurs : une race
    -- tapee a la main n'apportait ni bonus ni morphologie, et laissait croire
    -- le contraire. Si elle manque, c'est au MJ de la creer.
    if tostring(brouillon.race or "") == "" then
        out[#out + 1] = "il faut choisir une race."
    elseif not LCM.Races.Get(brouillon.race) then
        out[#out + 1] = string.format("la race « %s » n'existe pas dans cette version.", tostring(brouillon.race))
    end
    -- Une saisie de niveau illisible reste affichee (en rouge) et bloque :
    -- `niveau`, lui, garde la derniere valeur valable pour les calculs.
    if brouillon.niveauSaisie ~= nil then
        out[#out + 1] = string.format("niveau illisible (%s) : un nombre entier, 1 au minimum.",
            tostring(brouillon.niveauSaisie))
    end
    for _, debordement in ipairs(Creation.Debordements(brouillon)) do
        out[#out + 1] = string.format("%s depasse son plafond (%d pour %d).",
            debordement.label, debordement.valeur, debordement.plafond)
    end
    -- Les points doivent etre TOUS places, pas seulement ne pas deborder.
    -- Un personnage qui arrive avec des points en poche, c'est un personnage
    -- qu'on finira de construire en seance, au moment ou tout le monde attend.
    -- Les traits comptent comme le reste : ce sont des points.
    for _, categorie in ipairs(Creation.CATEGORIES) do
        local budget = Creation.Budget(brouillon, categorie)
        if budget.reste < 0 then
            out[#out + 1] = string.format("budget %s depasse de %d.", categorie, -budget.reste)
        elseif budget.reste > 0 and Creation.PeutEncoreDepenser(brouillon, categorie) then
            out[#out + 1] = string.format("il reste %d point%s de %s a placer.",
                budget.reste, budget.reste > 1 and "s" or "", Creation.LIBELLES[categorie] or categorie)
        end
    end
    return out
end

-- Rien n'oblige a tout depenser : un personnage peut garder des points de cote.
function Creation.Appliquer(brouillon)
    local problemes = Creation.Problemes(brouillon)
    if #problemes > 0 then return nil, problemes[1] end

    -- Une race du compendium est rangee par son identifiant ; une race saisie,
    -- telle qu'elle a ete ecrite. Le champ `race` de la fiche porte les deux.
    local valeurs = {
        race = brouillon.race,
        niveau = brouillon.niveau,
    }
    -- « Autre » precise : c'est la precision qu'on garde, pas le mot « Autre ».
    if brouillon.valeurs.sexe == "Autre" and tostring(brouillon.sexeAutre or "") ~= "" then
        valeurs.sexe = brouillon.sexeAutre
    end
    for champ, valeur in pairs(brouillon.valeurs) do valeurs[champ] = valeur end

    local entity, erreur = LCM.Personnages.Creer(brouillon.nom, valeurs)
    if not entity then return nil, erreur end
    for _, id in ipairs(brouillon.traits) do LCM.Traits.Grant(entity, id) end
    return entity
end
