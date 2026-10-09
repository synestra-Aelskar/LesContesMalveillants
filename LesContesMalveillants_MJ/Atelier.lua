-- Atelier du maitre du jeu.
--
-- Le formulaire qui fabrique les brouillons : un trait, une race, un objet,
-- en seance, sans toucher au code. Ce qu'il produit est exactement ce qu'un fichier genere
-- declarerait (`Traits.Add({...})`), range dans la sauvegarde du compagnon en
-- attendant l'export.
--
-- L'atelier ne connait AUCUNE regle de contenu : il demande au registre
-- (`Construire`) si la saisie passe, et affiche son refus tel quel. Une regle
-- ajoutee dans Core/Traits.lua vaut donc ici sans une ligne de plus.
--
-- Le contenu publie s'affiche en lecture seule : il vient d'un fichier genere,
-- et c'est ce fichier qui fait foi.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local Brouillons = MJ.Brouillons

local Atelier = {}
MJ.Atelier = Atelier
UI.Atelier = Atelier

local LARGEUR, HAUTEUR = 700, 500
local LARGEUR_LISTE = 210
local LARGEUR_FORMULAIRE = LARGEUR - 24 - LARGEUR_LISTE - 12
local COLONNE = 100      -- largeur des libelles du formulaire
local LIGNE = 24

-- Les familles du compendium du template qu'on cree en seance.
local FAMILLES = {
    { id = "traits",         label = "Traits" },
    { id = "races",          label = "Races" },
    { id = "objets",         label = "Objets" },
    { id = "etats",          label = "États" },
    { id = "apprentissages", label = "Apprentissages" },
    { id = "sacs",           label = "Sacs" },
}

-- ===== Ce qu'on propose dans les listes de choix ===========================

-- Un bonus vise un nombre : stat, jet, jauge (Fatigue, PA), ou un champ calcule
-- qui l'accepte (Deplacement). Les primaires ne sont proposees qu'a un objet :
-- le registre des traits les refuserait.
local function OptionsBonus(famille)
    local out = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        for _, section in ipairs(tab.sections) do
            for _, field in ipairs(section.fields) do
                local cible = field.kind == "stat" or field.kind == "roll"
                    or (field.kind == "gauge" and field.id ~= "armure" and not field.lire)
                    or (field.kind == "calc" and field.recoitBonus)
                local primaire = LCM.Effets.PRIMAIRES[field.id]
                if cible and (not primaire or famille ~= "traits") then
                    out[#out + 1] = {
                        id = field.id, label = field.label,
                        groupe = section.label ~= "" and (tab.label .. " · " .. section.label) or tab.label,
                    }
                end
            end
        end
    end
    return out
end

-- La categorie du compendium que vise cette famille, pour y chercher un jeu
-- d'equilibrage. `nil` quand la famille n'a pas de categorie propre.
local function CategorieForge(famille, edition)
    if famille == "traits" then return "traits" end
    if famille == "races" then return "races" end
    if famille == "objets" then
        return edition and ({ arme = "armes", equipement = "armures", accessoire = "accessoires" })[edition.categorie]
            or nil
    end
    local registre = Brouillons.Registre(famille)
    if not registre then return nil end
    if #registre.CATEGORIES == 1 then return registre.CATEGORIES[1].id end
    return edition and edition.categorie or nil
end

-- Le jeu d'equilibrage en cours, s'il y en a un et qu'il est choisi.
local function JeuChoisi(edition)
    if not edition or not edition.forge then return nil end
    local jeu, rarete = LCM.Forge.Lire(edition.forge)
    if not (jeu and rarete) then return nil end
    return jeu, rarete
end

-- Ce qu'une statistique autorise, en une ligne lisible : « 0 à 4 · 2 pt »,
-- « verrouillé à 1 ». C'est ce qui manquait le plus — on saisissait a
-- l'aveugle, et le refus tombait a l'enregistrement (5 octobre 2026).
local function Bornes(limites)
    local N = LCM.Compendium.Nombre
    if limites.verrou then
        return string.format("verrouillé à %s", N(limites.base))
    end
    local morceaux = {}
    if limites.min and limites.max then
        morceaux[#morceaux + 1] = string.format("%s à %s", N(limites.min), N(limites.max))
    elseif limites.min then
        morceaux[#morceaux + 1] = string.format("%s au moins", N(limites.min))
    elseif limites.max then
        morceaux[#morceaux + 1] = string.format("%s au plus", N(limites.max))
    end
    if limites.base and limites.base ~= 0 then
        morceaux[#morceaux + 1] = string.format("base %s", N(limites.base))
    end
    morceaux[#morceaux + 1] = string.format("%s pt", N(limites.cout))
    return table.concat(morceaux, " · ")
end

-- Les bonus que le JEU autorise, avec leurs bornes. Une statistique
-- verrouillee n'est pas proposee : on ne peut rien en faire, et l'offrir
-- revient a promettre une saisie qui sera refusee.
local function OptionsBonusForge(edition)
    local jeu, rarete = JeuChoisi(edition)
    if not jeu then return nil end
    local out = {}
    for _, champ in ipairs(LCM.Forge.Champs(jeu.categorie)) do
        local limites = LCM.Forge.Limites(jeu, champ.cle, rarete.id)
        if not limites.verrou then
            -- Range par DOSSIER, comme le panneau de la forge : cent quarante
            -- statistiques a plat sont introuvables. Les bornes vont dans le
            -- libelle — les mettre en intertitre groupait « 0 à 4 · 2 pt »
            -- ensemble et eparpillait les champs au hasard (5 octobre 2026).
            out[#out + 1] = {
                id = champ.cle,
                label = string.format("%s   |cff8a8a8a%s|r", champ.label, Bornes(limites)),
                groupe = champ.dossier or "Général",
            }
        end
    end
    return out
end

-- La liste a proposer.
--
-- Trois cas, et le troisieme compte : si un jeu VISE la categorie mais qu'on
-- n'en a pas encore choisi un, on ne propose RIEN. Retomber sur la feuille
-- entiere laisserait choisir une statistique puis se faire refuser a
-- l'enregistrement, sans comprendre pourquoi.
local function OptionsBonusPour(edition)
    local duJeu = OptionsBonusForge(edition)
    if duJeu then return duJeu end
    local categorie = CategorieForge(edition.famille, edition)
    local jeux = categorie and LCM.Forge.PourCategorie(categorie) or {}
    if #jeux > 0 then return {} end
    return OptionsBonus(edition.famille)
end

-- L'avantage ne se choisit que parmi ce que l'entree AMELIORE, et seulement
-- sur un jet. Prendre l'avantage sur un jet qu'on ne touche pas — ou pire, sur
-- un qu'on penalise — n'a aucun sens : le desavantage y est deja, de facto
-- (regle du 5 octobre 2026, cf. Core/Traits.lua).
local function OptionsAvantageParmiBonus(e)
    local out = {}
    for _, ligne in ipairs(e.bonus or {}) do
        local montant = tonumber(ligne.montant) or 0
        local field = ligne.champ and LCM.Schema.Field(ligne.champ)
        if montant > 0 and field and field.kind == "roll" then
            out[#out + 1] = { id = field.id, label = field.label,
                              groupe = string.format("Bonus +%d", montant) }
        end
    end
    return out
end

-- L'ancienne liste : tous les jets de la feuille. Gardee pour les familles qui
-- n'ont pas de bonus chiffres.
local function OptionsAvantage()
    local out = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        for _, section in ipairs(tab.sections) do
            for _, field in ipairs(section.fields) do
                if field.kind == "roll" then
                    out[#out + 1] = {
                        id = field.id, label = field.label,
                        groupe = section.label ~= "" and (tab.label .. " · " .. section.label) or tab.label,
                    }
                end
            end
        end
    end
    return out
end

local function OptionsMorphologies()
    local out = {}
    for _, morphologie in ipairs(LCM.Morphologies.list) do
        out[#out + 1] = { id = morphologie.id, label = morphologie.label }
    end
    return out
end

-- Un champ disparu du schema reste affiche, marque : on ne fait pas semblant
-- que la saisie est saine.
local function LibelleChamp(id)
    local field = LCM.Schema.Field(id)
    if field then return field.label end
    return "|cffe86b6b? " .. tostring(id) .. "|r"
end

-- ===== L'edition en cours ==================================================
-- Une COPIE de travail : rien n'est ecrit tant que le MJ n'a pas enregistre, et
-- la copie ne partage aucune table avec le brouillon sauvegarde.

local function Vierge(famille)
    return {
        famille = famille, creation = true, id = Brouillons.NouvelIdentifiant(),
        label = "", description = "", cout = 1,
        bonus = {}, avantage = {},
        morphology = LCM.DEFAULT_MORPHOLOGY,
        -- Pas de categorie par defaut : c'est un choix, pas un reglage.
        categorie = nil,
        icone = "",
        places = "12", placesDevise = "0",
    }
end

-- `avantage` est une liste dans un brouillon, un ensemble dans un trait
-- enregistre ; on accepte les deux.
local function ListeAvantage(valeur)
    local out = {}
    if type(valeur) ~= "table" then return out end
    if valeur[1] ~= nil then
        for _, id in ipairs(valeur) do out[#out + 1] = tostring(id) end
    else
        for id in pairs(valeur) do out[#out + 1] = tostring(id) end
        table.sort(out)
    end
    return out
end

local function Charger(famille, source, publie)
    local e = Vierge(famille)
    e.creation = false
    e.publie = publie
    e.id = tostring(source.id)
    e.label = tostring(source.label or source.id)
    e.description = tostring(source.description or "")
    e.cout = tonumber(source.cout) or 1
    e.morphology = source.morphology
    e.mjSeulement = source.mjSeulement == true
    e.categorie = source.categorie
    e.icone = tostring(source.icone or "")
    e.places = tostring(source.places or 12)
    e.placesDevise = tostring(source.placesDevise or 0)
    for champ, montant in pairs(type(source.bonus) == "table" and source.bonus or {}) do
        e.bonus[#e.bonus + 1] = { champ = tostring(champ), montant = tostring(montant) }
    end
    table.sort(e.bonus, function(a, b) return a.champ < b.champ end)
    e.avantage = ListeAvantage(source.avantage)
    return e
end

-- La copie de travail -> la definition qu'on enregistre, ou nil et la raison.
-- Ne verifie que ce que le registre ne peut pas voir (un doublon de ligne
-- disparait en devenant une cle de table) ; le reste est son affaire.
local function Definition(e)
    local nom = tostring(e.label or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if nom == "" then return nil, "donne-lui un nom" end
    local id = e.id

    local bonus = {}
    for _, ligne in ipairs(e.bonus) do
        if bonus[ligne.champ] ~= nil then
            return nil, string.format("deux bonus sur « %s »", LibelleChamp(ligne.champ))
        end
        -- Un montant illisible passe tel quel : le registre le refusera, avec
        -- sa raison, plutot que de le voir remplace par zero en douce.
        bonus[ligne.champ] = tonumber(ligne.montant) or ligne.montant
    end
    local avantage = {}
    for _, champ in ipairs(e.avantage) do avantage[#avantage + 1] = champ end

    local definition = { id = id, label = nom, bonus = bonus, avantage = avantage }
    -- Le jeu d'equilibrage choisi : c'est lui que Forge.Verifier attend.
    if e.forge and e.forge ~= "" then definition.forge = e.forge end
    if e.famille == "traits" then
        definition.cout = e.cout
    else
        -- Tout le reste porte une icone, comme dans le compendium du template.
        local icone = tostring(e.icone or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if icone ~= "" then definition.icone = icone end
        if e.famille == "races" then
            definition.morphology = e.morphology
            -- Recopiee, sinon modifier la race ici effacerait en silence ce
            -- que l'editeur du compendium avait coche.
            definition.mjSeulement = e.mjSeulement or nil
        elseif e.famille == "sacs" then
            -- Un sac ne donne rien : pas d'effets, ses places. Un nombre
            -- illisible passe tel quel, le registre le refusera avec sa raison.
            definition.bonus, definition.avantage = nil, nil
            definition.places = tonumber(e.places) or e.places
            definition.placesDevise = tonumber(e.placesDevise) or e.placesDevise
        else
            -- Un catalogue a une seule categorie la rend implicite.
            local registre = Brouillons.Registre(e.famille)
            if #registre.CATEGORIES > 1 then
                if not e.categorie then return nil, "choisis sa catégorie" end
                definition.categorie = e.categorie
            end
        end
    end
    local description = tostring(e.description or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if description ~= "" then definition.description = description end
    return definition
end

-- ===== Morceaux de formulaire ==============================================

local function Libelle(parent, texte)
    return UI.Texte(parent, texte, UI.C.discret, "GameFontNormalSmall")
end

-- Nom et identifiant : communs aux traits et aux races.
local function EnTete(f, p, c)
    p.lblNom = Libelle(c, "Nom")
    p.lblNom:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -5)
    p.nom = UI.Champ(c, 260, 22, function(texte)
        f.edition.label = texte
        f:MajIdentifiant()
    end)
    p.nom:SetMaxLetters(60)
    p.nom:SetPoint("TOPLEFT", c, "TOPLEFT", COLONNE, 0)

    p.lblId = Libelle(c, "Identifiant")
    p.lblId:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -32)
    p.ident = UI.Texte(c, "", UI.C.texte, "GameFontNormalSmall")
    p.ident:SetPoint("TOPLEFT", c, "TOPLEFT", COLONNE + 6, -32)
end

-- Ligne de bonus : [champ] [montant] [x]. Chaque ligne connait son rang
-- (`ligne.index`, pose au rangement) : ses boutons le lisent au clic.
local function LigneBonus(f, p, c)
    local ligne = CreateFrame("Frame", nil, c)
    ligne:SetHeight(22)
    ligne.champ = UI.Bouton(ligne, "", 220, 20, function()
        f.choix.titre:SetText("Bonus sur…")
        f.choix:Proposer(ligne.champ, OptionsBonusPour(f.edition), function(id)
            f.edition.bonus[ligne.index].champ = id
            p:Remplir()
        end)
    end)
    ligne.champ:SetPoint("LEFT", ligne, "LEFT", 0, 0)
    ligne.champ.label:ClearAllPoints()
    ligne.champ.label:SetPoint("LEFT", ligne.champ, "LEFT", 8, 0)
    ligne.champ.label:SetJustifyH("LEFT")

    ligne.montant = UI.Champ(ligne, 56, 20, function(texte)
        f.edition.bonus[ligne.index].montant = texte
    end)
    ligne.montant:SetMaxLetters(5)
    ligne.montant:SetPoint("LEFT", ligne.champ, "RIGHT", 6, 0)

    ligne.retirer = UI.Bouton(ligne, "x", 20, 20, function()
        table.remove(f.edition.bonus, ligne.index)
        p:Remplir()
    end)
    ligne.retirer:SetPoint("LEFT", ligne.montant, "RIGHT", 6, 0)

    -- Ce que le jeu autorise sur CETTE statistique, et ce qu'elle coute.
    ligne.bornes = UI.Texte(ligne, "", UI.C.discret, "GameFontNormalSmall")
    ligne.bornes:SetPoint("LEFT", ligne.retirer, "RIGHT", 8, 0)
    ligne.bornes:SetJustifyH("LEFT")
    return ligne
end

local function LigneAvantage(f, p, c)
    local ligne = CreateFrame("Frame", nil, c)
    ligne:SetHeight(22)
    ligne.champ = UI.Texte(ligne, "", UI.C.texte, "GameFontNormalSmall")
    ligne.champ:SetPoint("LEFT", ligne, "LEFT", 8, 0)
    ligne.champ:SetWidth(212)
    ligne.retirer = UI.Bouton(ligne, "x", 20, 20, function()
        table.remove(f.edition.avantage, ligne.index)
        p:Remplir()
    end)
    ligne.retirer:SetPoint("LEFT", ligne, "LEFT", 226, 0)
    return ligne
end

-- Pose les lignes d'une liste a partir de `y` et renvoie le `y` suivant.
local function Ranger(c, lignes, nombre, fabrique, y, habiller)
    for index = 1, nombre do
        local ligne = lignes[index]
        if not ligne then
            ligne = fabrique()
            lignes[index] = ligne
        end
        ligne.index = index
        ligne:ClearAllPoints()
        ligne:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        ligne:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, y)
        habiller(ligne, index)
        ligne:Show()
        y = y - LIGNE
    end
    for index = nombre + 1, #lignes do lignes[index]:Hide() end
    return y
end

-- ===== Panneaux ============================================================

-- Trait et objet partagent tout (description, bonus, avantage) sauf une ligne :
-- le cout d'un trait, la categorie d'un objet.
local function OptionsCategories(famille)
    local registre = Brouillons.Registre(famille)
    local out = {}
    for _, categorie in ipairs(registre.CATEGORIES) do
        local places = registre.Capacite(categorie.id)
        out[#out + 1] = { id = categorie.id, label = string.format("%s  (%d emplacement%s)",
            categorie.label, places, places > 1 and "s" or "") }
    end
    return out
end

-- Un formulaire pour toutes les familles : elles partagent icone,
-- description, bonus et avantage (le modele unique du compendium du
-- template). Seule la ligne sous le nom change : le cout d'un trait, la
-- morphologie d'une race, la categorie d'un objet ou d'un etat.
local function PanneauEffets(f, genre)
    local p = UI.Defilement(f.droite)
    local c = p.contenu
    EnTete(f, p, c)
    local registre = genre ~= "traits" and genre ~= "races" and Brouillons.Registre(genre) or nil

    -- Le jeu d'equilibrage. Le bareme de la forge BLOQUE (Core/Forge.lua) :
    -- des qu'un jeu vise la categorie, une entree qui n'en choisit pas est
    -- REFUSEE. Sans ce champ, l'atelier ne pouvait plus rien enregistrer dans
    -- cette categorie — il ignorait la forge entierement (5 octobre 2026).
    p.lblForge = Libelle(c, "Équilibrage")
    p.forge = UI.Bouton(c, "", 260, 22, function()
        local categorie = CategorieForge(genre, f.edition)
        local options = categorie and LCM.Forge.Options(categorie) or {}
        if #options == 0 then
            LCM.Alerte("aucun jeu d'équilibrage ne vise cette catégorie.")
            return
        end
        f.choix.titre:SetText("Jeu d'équilibrage")
        f.choix:Proposer(p.forge, options, function(valeur)
            f.edition.forge = valeur
            p:Remplir()
        end)
    end)
    p.bilanForge = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    p.bilanForge:SetJustifyH("LEFT")
    p.bilanForge:SetWordWrap(true)

    -- Ce que le jeu autorise, et ce qu'on a depense : sans ca on saisit a
    -- l'aveugle et on se fait refuser a l'enregistrement.
    function p:MajForge()
        local categorie = CategorieForge(genre, f.edition)
        local jeux = categorie and LCM.Forge.PourCategorie(categorie) or {}
        local concerne = #jeux > 0
        self.lblForge:SetShown(concerne)
        self.forge:SetShown(concerne)
        self.bilanForge:SetShown(concerne)
        if not concerne then return end

        local valeur = f.edition.forge
        local jeu, rarete = LCM.Forge.Lire(valeur)
        self.forge.label:SetText(jeu and rarete
            and string.format("%s · %s", jeu.label, rarete.label)
            or "— choisir un jeu et sa rareté —")
        if not (jeu and rarete) then
            self.bilanForge:SetText("Obligatoire : cette catégorie passe par un jeu d'équilibrage.")
            return
        end
        local bonus = {}
        for _, ligne in ipairs(f.edition.bonus or {}) do
            bonus[ligne.champ] = tonumber(ligne.montant) or 0
        end
        local multiplicateurPool = categorie == "armes"
            and (tonumber(f.edition.taille) == 2 and 2 or 1) or 1
        local etatObjet = type(f.edition.etat) == "table" and f.edition.etat.max or nil
        local bilan = LCM.Forge.Bilan(jeu, rarete.id, bonus, multiplicateurPool, etatObjet)
        local hors
        for _, ligne in ipairs(bilan.lignes) do
            if ligne.hors then hors = ligne.hors break end
        end
        if hors then
            self.bilanForge:SetText(hors)
            self.bilanForge:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])
        else
            local pool = bilan.pool or rarete.points
            local depasse = bilan.total > pool
            local texte = string.format("%s / %d points du pool %s",
                LCM.Compendium.Nombre(bilan.total), pool, rarete.label)
            -- Les negatives ne rendent que la moitie, et jamais plus que le
            -- pool : on le dit, sinon baisser une statistique de plus ne change
            -- rien sans qu'on comprenne.
            if (bilan.creditPerdu or 0) > 0 then
                texte = string.format("%s (%s pt(s) rendus perdus : plafond du pool)",
                    texte, LCM.Compendium.Nombre(bilan.creditPerdu))
            end
            self.bilanForge:SetText(texte)
            local couleur = depasse and UI.C.plein or UI.C.discret
            self.bilanForge:SetTextColor(couleur[1], couleur[2], couleur[3])
        end
    end

    local plafond = LCM.Traits.COUT_MAX
    if genre == "traits" then
        p.cout = UI.Compteur(c, "Coût", COLONNE, {
            change = function(valeur)
                if valeur < 1 or valeur > plafond then return false end
                f.edition.cout = valeur
                p.cout:Regler(valeur, plafond)
            end,
            max = function() return plafond end,
        })
        p.cout:SetWidth(300)
        p.cout:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -56)
    elseif genre == "races" then
        p.lblMorpho = Libelle(c, "Morphologie")
        p.lblMorpho:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -61)
        p.morphologie = UI.Bouton(c, "", 200, 22, function()
            f.choix.titre:SetText("Morphologie")
            f.choix:Proposer(p.morphologie, OptionsMorphologies(), function(id)
                f.edition.morphology = id
                p:Remplir()
            end)
        end)
        p.morphologie:SetPoint("TOPLEFT", c, "TOPLEFT", COLONNE, -56)
        -- Ce que la morphologie engendre : ce sont les zones du corps.
        p.parties = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
        p.parties:SetPoint("LEFT", p.morphologie, "RIGHT", 10, 0)
        p.parties:SetWidth(LARGEUR_FORMULAIRE - COLONNE - 230)
        p.parties:SetWordWrap(true)
    elseif genre == "sacs" then
        -- Les places d'un sac, et ses places de devise (compendium du template).
        p.sansEffets = true
        p.lblPlaces = Libelle(c, "Places")
        p.lblPlaces:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -61)
        p.places = UI.Champ(c, 60, 22, function(texte) f.edition.places = texte end)
        p.places:SetPoint("TOPLEFT", c, "TOPLEFT", COLONNE, -56)
        p.places:SetMaxLetters(3)
        p.lblDevise = Libelle(c, "Places de devise")
        p.lblDevise:SetPoint("LEFT", p.places, "RIGHT", 20, 0)
        p.placesDevise = UI.Champ(c, 60, 22, function(texte) f.edition.placesDevise = texte end)
        p.placesDevise:SetPoint("LEFT", p.lblDevise, "RIGHT", 10, 0)
        p.placesDevise:SetMaxLetters(3)
    elseif registre and #registre.CATEGORIES > 1 then
        p.lblCategorie = Libelle(c, "Catégorie")
        p.lblCategorie:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -61)
        p.categorie = UI.Bouton(c, "", 200, 22, function()
            f.choix.titre:SetText("Catégorie")
            f.choix:Proposer(p.categorie, OptionsCategories(genre), function(id)
                f.edition.categorie = id
                p:Remplir()
            end)
        end)
        p.categorie:SetPoint("TOPLEFT", c, "TOPLEFT", COLONNE, -56)
    end

    -- Un objet a une icone (comme dans le compendium du template) : une ligne
    -- de plus, le reste du formulaire descend d'autant.
    local decale = 0
    if genre ~= "traits" then
        decale = 30
        p.lblIcone = Libelle(c, "Icône")
        p.lblIcone:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -91)
        p.icone = UI.Champ(c, 200, 22, function(texte)
            f.edition.icone = texte
            p.apercu:SetTexture(LCM.Objets.Icone(texte))
        end)
        p.icone:SetMaxLetters(120)
        p.icone:SetPoint("TOPLEFT", c, "TOPLEFT", COLONNE, -86)
        -- L'apercu est un bouton : on clique pour choisir dans ce qui sert
        -- deja dans la campagne, plutot que de taper un nom d'icone de tete.
        p.apercuBouton = CreateFrame("Button", nil, c)
        p.apercuBouton:SetSize(24, 24)
        p.apercuBouton:SetPoint("LEFT", p.icone, "RIGHT", 8, 0)
        if UI.BordureFine then UI.BordureFine(p.apercuBouton, 0.5) end
        p.apercu = p.apercuBouton:CreateTexture(nil, "ARTWORK")
        p.apercu:SetPoint("TOPLEFT", p.apercuBouton, "TOPLEFT", 1, -1)
        p.apercu:SetPoint("BOTTOMRIGHT", p.apercuBouton, "BOTTOMRIGHT", -1, 1)
        p.apercu:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        p.apercuBouton.survol = UI.Aplat(p.apercuBouton, UI.C.survol, "HIGHLIGHT")
        p.apercuBouton.survol:SetAllPoints(p.apercuBouton)
        p.selecteur = UI.SelecteurIcone("atelier")
        p.apercuBouton:SetScript("OnClick", function(self)
            p.selecteur:Proposer(self, function(chemin)
                f.edition.icone = chemin
                p.icone:SetText(chemin)
                p.apercu:SetTexture(LCM.Objets.Icone(chemin))
            end)
        end)
        p.aideIcone = Libelle(c, "clique l'icône pour choisir")
        p.aideIcone:SetPoint("LEFT", p.apercuBouton, "RIGHT", 8, 0)
    end
    -- Une race : la case « reservee au MJ », sur sa propre ligne.
    if genre == "races" then
        decale = decale + 30
        p.lblAcces = Libelle(c, "Création")
        p.lblAcces:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -121)
        p.mjSeulement = UI.Case(c, "réservée au MJ — un joueur ne la voit pas", function(v)
            f.edition.mjSeulement = v
        end)
        p.mjSeulement:SetPoint("TOPLEFT", c, "TOPLEFT", COLONNE, -118)
    end
    p.decale = decale

    p.lblDesc = Libelle(c, "Description")
    p.lblDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -86 - decale)
    p.description = UI.Zone(c, LARGEUR_FORMULAIRE - 20, 118, function(texte)
        f.edition.description = texte
    end)
    p.description:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -102 - decale)

    p.enteteBonus = UI.EnTeteGroupe(c, "BONUS")
    p.enteteAvantage = UI.EnTeteGroupe(c, "AVANTAGE (relance, garde le meilleur)")
    p.lignesBonus, p.lignesAvantage = {}, {}

    p.ajoutBonus = UI.Bouton(c, "+  Bonus", 150, 20, function()
        f.choix.titre:SetText("Bonus sur…")
        -- Quand un jeu d'equilibrage vise la categorie, on ouvre LA FORGE :
        -- son panneau range les statistiques par dossier repliable, montre les
        -- bornes et compte le pool. Une liste a plat de cent quarante entrees
        -- etait intenable (5 octobre 2026).
        local categorieForge = CategorieForge(f.edition.famille, f.edition)
        if categorieForge and #LCM.Forge.PourCategorie(categorieForge) > 0 then
            local valeurs = {}
            for _, ligne in ipairs(f.edition.bonus or {}) do
                valeurs[ligne.champ] = tonumber(ligne.montant) or ligne.montant
            end
            -- `UI.Forge` et non `ForgeUI` : ce dernier est un local de
            -- Forge.lua, donc nil ici. Resolu a l'appel, l'ordre du .toc n'a
            -- pas d'importance.
            local forgeUI = UI.Forge
            if not (forgeUI and forgeUI.OuvrirPourBonus) then
                LCM.Alerte("la forge n'est pas chargée.")
                return
            end
            local ouverte, raison = forgeUI.OuvrirPourBonus(categorieForge, valeurs, f.edition.forge,
                function(bonus, valeurForge, etat)
                    f.edition.bonus = {}
                    for cle, montant in pairs(bonus or {}) do
                        -- Zero n'est pas un bonus : l'ecrire encombrerait la
                        -- liste de cent quarante lignes a zero.
                        if (tonumber(montant) or 0) ~= 0 then
                            table.insert(f.edition.bonus, { champ = cle, montant = tostring(montant) })
                        end
                    end
                    table.sort(f.edition.bonus, function(a, b) return a.champ < b.champ end)
                    f.edition.forge = valeurForge
                    if etat ~= nil then f.edition.etat = etat end
                    p:Remplir()
                end, f.edition.taille, f.edition.etat)
            if not ouverte then LCM.Alerte(tostring(raison)) end
            return
        end
        local options = OptionsBonusPour(f.edition)
        if #options == 0 then
            LCM.Alerte("choisis d'abord le jeu d'équilibrage et sa rareté.")
            return
        end
        f.choix:Proposer(p.ajoutBonus, options, function(id)
            table.insert(f.edition.bonus, { champ = id, montant = "1" })
            p:Remplir()
        end)
    end)
    p.ajoutAvantage = UI.Bouton(c, "+  Avantage", 110, 20, function()
        f.choix.titre:SetText("Avantage sur…")
        -- Pour un TRAIT : parmi les bonus POSITIFS deja saisis, et pas la
        -- feuille entiere — un trait donne l'avantage sur ce qu'il ameliore
        -- (regle du 5 octobre 2026).
        --
        -- Les autres familles gardent la liste complete : un OBJET qui fait
        -- relancer un jet sans rien y ajouter est legitime (l'Amulette du
        -- guetteur donne l'avantage en Pistage sans bonus chiffre dessus), et
        -- la regle ne parlait que des traits.
        local options
        if f.edition.famille == "traits" then
            options = OptionsAvantageParmiBonus(f.edition)
            if #options == 0 then
                LCM.Alerte("ajoute d'abord un bonus POSITIF sur un jet : "
                    .. "c'est parmi eux que se choisit l'avantage d'un trait.")
                return
            end
            -- Un avantage par niveau, pas un de plus (Core/Traits.lua).
            local plafondAvantages = tonumber(f.edition.cout) or 1
            if #f.edition.avantage >= plafondAvantages then
                LCM.Alerte(string.format(
                    "un trait de niveau %d ne donne que %d avantage(s).",
                    plafondAvantages, plafondAvantages))
                return
            end
        else
            options = OptionsAvantage()
        end
        f.choix:Proposer(p.ajoutAvantage, options, function(id)
            for _, deja in ipairs(f.edition.avantage) do
                if deja == id then return end
            end
            table.insert(f.edition.avantage, id)
            p:Remplir()
        end)
    end)

    -- Remet toute la copie de travail dans les widgets, et range les listes.
    function p:Remplir()
        local e = f.edition
        self.nom:SetText(e.label or "")
        if self.cout then self.cout:Regler(e.cout or 1, plafond) end
        if self.categorie then
            local categorie = registre.Categorie(e.categorie)
            self.categorie.label:SetText(categorie and categorie.label or "|cff99907fChoisir…|r")
        end
        if self.mjSeulement then self.mjSeulement:Cocher(e.mjSeulement) end
        if self.morphologie then
            local morphologie = LCM.Morphologies.Get(e.morphology)
            if morphologie then
                self.morphologie.label:SetText(morphologie.label)
                local noms = {}
                for _, partie in ipairs(morphologie.parts) do noms[#noms + 1] = partie.label end
                self.parties:SetText(table.concat(noms, ", "))
            else
                self.morphologie.label:SetText("|cffe86b6b? " .. tostring(e.morphology) .. "|r")
                self.parties:SetText("")
            end
        end
        self.description:SetText(e.description or "")

        if self.places then
            self.places:SetText(tostring(e.places or ""))
            self.placesDevise:SetText(tostring(e.placesDevise or ""))
        end
        if self.icone then
            self.icone:SetText(e.icone or "")
            self.apercu:SetTexture(LCM.Objets.Icone(e.icone))
        end
        -- Le jeu d'equilibrage, juste au-dessus des bonus : c'est lui qui dit
        -- ce qu'on a le droit d'y mettre.
        self:MajForge()

        local y = -186 - self.decale
        if self.forge:IsShown() then
            self.lblForge:ClearAllPoints()
            self.lblForge:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
            self.forge:ClearAllPoints()
            self.forge:SetPoint("TOPLEFT", c, "TOPLEFT", COLONNE, y + 4)
            self.bilanForge:ClearAllPoints()
            self.bilanForge:SetPoint("TOPLEFT", c, "TOPLEFT", COLONNE, y - 22)
            self.bilanForge:SetPoint("TOPRIGHT", c, "TOPRIGHT", -20, y - 22)
            y = y - 48
        end
        -- Une famille sans effets (les sacs) s'arrete a la description.
        for _, w in ipairs({ self.enteteBonus, self.ajoutBonus, self.enteteAvantage, self.ajoutAvantage }) do
            w:SetShown(not self.sansEffets)
        end
        if self.sansEffets then
            self:Regler(-y)
            return
        end
        self.enteteBonus:ClearAllPoints()
        self.enteteBonus:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        self.enteteBonus:SetPoint("TOPRIGHT", c, "TOPRIGHT", -20, y)
        y = y - 26
        local jeuCourant, rareteCourante = JeuChoisi(e)
        y = Ranger(c, self.lignesBonus, #e.bonus, function() return LigneBonus(f, self, c) end, y,
            function(ligne, index)
                local b = e.bonus[index]
                ligne.champ.label:SetText(LibelleChamp(b.champ))
                ligne.montant:SetText(tostring(b.montant or ""))
                -- Les bornes du jeu, et le rouge quand on en sort : le refus
                -- doit se voir en saisissant, pas a l'enregistrement.
                if jeuCourant then
                    local limites = LCM.Forge.Limites(jeuCourant, b.champ, rareteCourante.id)
                    local valeur = tonumber(b.montant) or 0
                    local hors = (limites.verrou and valeur ~= limites.base)
                        or (limites.min and valeur < limites.min)
                        or (limites.max and valeur > limites.max)
                    ligne.bornes:SetText(Bornes(limites))
                    local couleur = hors and UI.C.plein or UI.C.discret
                    ligne.bornes:SetTextColor(couleur[1], couleur[2], couleur[3])
                else
                    ligne.bornes:SetText("")
                end
            end)
        self.ajoutBonus:ClearAllPoints()
        self.ajoutBonus:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        y = y - 36

        self.enteteAvantage:ClearAllPoints()
        self.enteteAvantage:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        self.enteteAvantage:SetPoint("TOPRIGHT", c, "TOPRIGHT", -20, y)
        y = y - 26
        y = Ranger(c, self.lignesAvantage, #e.avantage, function() return LigneAvantage(f, self, c) end, y,
            function(ligne, index)
                ligne.champ:SetText(LibelleChamp(e.avantage[index]))
            end)
        self.ajoutAvantage:ClearAllPoints()
        self.ajoutAvantage:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        y = y - 30

        self:Regler(-y)
    end
    return p
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("atelier", "Atelier du maître du jeu", LARGEUR, HAUTEUR, { x = 60, y = 20 })
    Atelier.frame = f
    f.famille = "traits"
    f.edition = Vierge("traits")
    f.choix = UI.Choix("atelier", "")
    f.confirmation = UI.Confirmer(f, "", "Supprimer")

    f.onglets = UI.Onglets(f.contenu, FAMILLES, function(id) f:ChoisirFamille(id) end, { largeur = 110 })
    f.onglets:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.onglets:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, 0)

    -- ----- la liste -------------------------------------------------------
    f.liste = CreateFrame("Frame", nil, f.contenu)
    f.liste:SetPoint("TOPLEFT", f.onglets, "BOTTOMLEFT", 0, -10)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.liste:SetWidth(LARGEUR_LISTE)
    f.liste.fond = UI.Aplat(f.liste, UI.C.fondClair)
    f.liste.fond:SetAllPoints(f.liste)
    UI.Bordure(f.liste)
    f.liste.lignes = {}

    f.nouveau = UI.Bouton(f.liste, "+  Nouveau", LARGEUR_LISTE - 16, 22, function() f:Nouveau() end)
    f.nouveau:SetPoint("BOTTOMLEFT", f.liste, "BOTTOMLEFT", 8, 8)

    f.liste.zone = UI.Defilement(f.liste)
    f.liste.zone:SetPoint("TOPLEFT", f.liste, "TOPLEFT", 8, -8)
    f.liste.zone:SetPoint("BOTTOMRIGHT", f.liste, "BOTTOMRIGHT", -8, 38)

    -- ----- le formulaire --------------------------------------------------
    f.droite = CreateFrame("Frame", nil, f.contenu)
    f.droite:SetPoint("TOPLEFT", f.liste, "TOPRIGHT", 12, 0)
    f.droite:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    -- Reprendre un contenu publie : il s'ouvrait en lecture seule, sans aucun
    -- moyen de corriger une faute en pleine seance. On en fait un brouillon
    -- qui prend le pas sur le fichier, a reporter entre deux seances.
    f.reprendre = UI.Bouton(f.droite, "Modifier (brouillon)", 180, 24, function() f:Reprendre() end)
    f.enregistrer = UI.Bouton(f.droite, "Enregistrer le brouillon", 180, 24, function() f:Enregistrer() end)
    f.enregistrer:SetPoint("BOTTOMLEFT", f.droite, "BOTTOMLEFT", 0, 0)
    f.supprimer = UI.Bouton(f.droite, "Supprimer", 110, 24, function() f:Supprimer() end)
    f.supprimer:SetPoint("LEFT", f.enregistrer, "RIGHT", 8, 0)
    f.supprimer.label:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])

    f.message = UI.Texte(f.droite, "", UI.C.discret, "GameFontNormalSmall")
    f.message:SetPoint("BOTTOMLEFT", f.droite, "BOTTOMLEFT", 0, 32)
    f.message:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 32)
    f.message:SetWordWrap(true)

    f.panneaux = {}
    for _, famille in ipairs(FAMILLES) do f.panneaux[famille.id] = PanneauEffets(f, famille.id) end
    -- Pose par f:PlacerPanneaux(), qui suit la hauteur reelle du message.

    -- Une liste de choix ou une confirmation n'a plus de sens fenetre fermee.
    f:HookScript("OnHide", function()
        f.choix:Hide()
        f.confirmation:Hide()
    end)

    -- ----- comportement ---------------------------------------------------

    -- Les panneaux descendent jusqu'au message, qui n'est pas toujours la.
    -- Ils reservaient 64 px en bas SYSTEMATIQUEMENT : sans message, c'etait du
    -- vide, et le formulaire se mettait a defiler pour rien (5 octobre 2026).
    function f:PlacerPanneaux()
        local texte = self.message:GetText() or ""
        -- 28 : la rangee de boutons et son air. Au-dela, la hauteur reelle du
        -- message, qui peut faire deux ou trois lignes.
        local bas = 28
        if texte ~= "" then
            bas = 36 + math.max(14, self.message:GetStringHeight() or 14)
        end
        for _, p in pairs(self.panneaux) do
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", self.droite, "TOPLEFT", 0, 0)
            p:SetPoint("BOTTOMRIGHT", self.droite, "BOTTOMRIGHT", 0, bas)
        end
    end

    function f:Message(texte, couleur)
        couleur = couleur or UI.C.discret
        self.message:SetText(texte or "")
        self.message:SetTextColor(couleur[1], couleur[2], couleur[3])
        self:PlacerPanneaux()
    end

    function f:MajIdentifiant()
        local p = self.panneaux[self.famille]
        if not (p and p.ident) then return end
        local e = self.edition
        if e.creation then
            p.ident:SetText(tostring(e.id) .. "   |cff99907fidentifiant unique, figé|r")
        else
            p.ident:SetText(tostring(e.id))
        end
    end

    -- Ce qu'on montre dans la liste : les brouillons (jouables ou refuses au
    -- chargement), puis le contenu publie. Un brouillon qui reprend
    -- l'identifiant d'un contenu publie donne DEUX lignes : chacune ouvre sa
    -- source, sinon le publie devient invisible derriere son doublon.
    function f:Entrees()
        local registre = Brouillons.Registre(self.famille)
        local brouillons, publies = {}, {}
        for _, entree in ipairs(Brouillons.List(self.famille)) do
            local id = tostring(entree.id)
            local statut = "refuse"
            if Brouillons.EstPublie(self.famille, id) then
                statut = "doublon"
            elseif registre and registre.Get(id) then
                statut = "brouillon"
            end
            brouillons[#brouillons + 1] = { id = id, label = tostring(entree.label or id), statut = statut }
        end
        for _, element in ipairs(registre and registre.list or {}) do
            if element.brouillon ~= true then
                publies[#publies + 1] = { id = element.id, label = element.label, statut = "publie" }
            end
        end
        local parNom = function(a, b) return a.label:lower() < b.label:lower() end
        table.sort(brouillons, parNom)
        table.sort(publies, parNom)
        for _, element in ipairs(publies) do brouillons[#brouillons + 1] = element end
        return brouillons
    end

    local STATUTS = {
        brouillon = { suffixe = "",                    couleur = UI.C.accent },
        publie    = { suffixe = "  · publié",          couleur = UI.C.discret },
        refuse    = { suffixe = "  · refusé",          couleur = UI.C.plein },
        -- Il ne double plus : il REMPLACE. La couleur reste vive, parce que
        -- c'est un etat a reporter dans le fichier, pas un etat normal.
        doublon   = { suffixe = "  · remplace le publié", couleur = UI.C.plein },
    }

    function f:RemplirListe()
        local zone = self.liste.zone
        local entrees = self:Entrees()
        for index, entree in ipairs(entrees) do
            local b = self.liste.lignes[index]
            if not b then
                b = UI.Bouton(zone.contenu, "", 10, 20, function(bouton)
                    f:Ouvrir(bouton.entreeId, bouton.publie)
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetJustifyH("LEFT")
                self.liste.lignes[index] = b
            end
            b.entreeId = entree.id
            b.publie = entree.statut == "publie"
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", zone.contenu, "TOPLEFT", 0, -(index - 1) * 22)
            b:SetPoint("TOPRIGHT", zone.contenu, "TOPRIGHT", 0, -(index - 1) * 22)
            local statut = STATUTS[entree.statut]
            local choisi = (not self.edition.creation) and self.edition.id == entree.id
                and (self.edition.publie == true) == b.publie
            b.label:SetText((choisi and "> " or "") .. entree.label .. statut.suffixe)
            local couleur = choisi and UI.C.titre or statut.couleur
            b.label:SetTextColor(couleur[1], couleur[2], couleur[3])
            b:Show()
        end
        for index = #entrees + 1, #self.liste.lignes do self.liste.lignes[index]:Hide() end
        zone:Regler(#entrees * 22)
    end

    function f:Afficher()
        self:PlacerPanneaux()
        local e = self.edition
        for famille, p in pairs(self.panneaux) do p:SetShown(famille == self.famille) end
        local p = self.panneaux[self.famille]
        p:Remplir()
        self:MajIdentifiant()

        local aRegistre = Brouillons.Registre(self.famille) ~= nil
        local editable = aRegistre and not e.publie
        -- Un brouillon qui double un contenu publie se garde : il le REMPLACE,
        -- c'est ce qu'on vient demander en le modifiant.
        local remplace = editable and not e.creation and Brouillons.EstPublie(self.famille, e.id)
        self.enregistrer:SetShown(editable)
        self.reprendre:SetShown(aRegistre and e.publie == true)
        self.supprimer:SetShown(editable and not e.creation)
        if e.publie then
            self:Message("Contenu publié : il vient d'un fichier généré. « Modifier (brouillon) » "
                .. "en fait une version jouable tout de suite, à reporter dans le fichier ensuite.")
        elseif remplace or e.remplace then
            self:Message("Ce brouillon REMPLACE un contenu publié : c'est lui qui s'applique en jeu. "
                .. "Reporte-le dans le fichier entre deux séances, sinon il restera à part.",
                UI.C.accent)
        elseif e.creation then
            self:Message("")
        end
        self:RemplirListe()
    end

    function f:Nouveau()
        self.choix:Hide()
        self.edition = Vierge(self.famille)
        self:Afficher()
    end

    -- `publie` : ouvrir le contenu publie plutot que le brouillon du meme nom.
    function f:Ouvrir(id, publie)
        self.choix:Hide()
        local brouillon = not publie and Brouillons.Get(self.famille, id)
        if brouillon then
            self.edition = Charger(self.famille, brouillon, false)
        else
            local registre = Brouillons.Registre(self.famille)
            local element = registre and registre.Get(id)
            if not element then return end
            self.edition = Charger(self.famille, element, true)
        end
        self:Message("")
        self:Afficher()
    end

    function f:ChoisirFamille(id)
        self.famille = id
        self:Nouveau()
    end

    function f:Reprendre()
        local e = self.edition
        if not e.publie then return end
        e.publie = false
        e.creation = false
        e.remplace = true
        self:Afficher()
        self:Message("Repris en brouillon : enregistre, il prendra le pas sur le fichier publié. "
            .. "Pense à le reporter dans le fichier entre deux séances.", UI.C.accent)
    end

    function f:Enregistrer()
        local e = self.edition
        local definition, raison = Definition(e)
        if not definition then
            self:Message("Refusé : " .. raison, UI.C.plein)
            return
        end
        local ok, refus = Brouillons.Enregistrer(self.famille, definition, e.creation, e.remplace)
        if not ok then
            self:Message("Refusé : " .. tostring(refus), UI.C.plein)
            return
        end
        e.creation = false
        e.id = definition.id
        self:Message("Brouillon enregistré : jouable dès maintenant, à exporter entre deux séances.",
            UI.C.accent)
        LCM.Ok(string.format("brouillon enregistre : %s (%s)", definition.label, self.famille))
        self:Afficher()
    end

    -- Irreversible : on confirme, avec le nom dans la question.
    function f:Supprimer()
        local e = self.edition
        if e.creation or e.publie then return end
        local famille, id, nom = self.famille, e.id, e.label
        self.confirmation:Demander(
            string.format("Supprimer le brouillon « %s » ?\nLes personnages qui le portent gardent "
                .. "son identifiant, mais il ne s'applique plus.", tostring(nom)),
            function()
                Brouillons.Supprimer(famille, id)
                LCM.Ok(string.format("brouillon supprime : %s", tostring(nom)))
                f:Nouveau()
                f:Message(string.format("« %s » supprimé.", tostring(nom)))
            end)
    end

    function f:Montrer()
        self:Afficher()
        self:Show()
    end

    return f
end

function Atelier.Fenetre()
    if not Atelier.frame then Construire() end
    return Atelier.frame
end

function Atelier.Basculer()
    if not LCM.IsMaster() then
        LCM.Alerte("l'atelier est reserve au maitre du jeu.")
        return
    end
    local f = Atelier.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
end

-- Le menu (« Compendium », « Systeme d'Aelskar ») ouvre le compendium
-- (UI/Compendium.lua), dont l'editeur MJ (Compendium.lua du compagnon) cree et
-- modifie les memes brouillons.
--
-- L'atelier, lui, a sa propre entree dans « Outils » depuis le 3 octobre 2026 :
-- il etait enfoui dans le Panel MJ, a trois clics, alors que c'est l'outil
-- qu'on ouvre le plus en seance.
LCM.WhenReady(function()
    if LCM.UI and LCM.UI.Menu then LCM.UI.Menu.Lier("atelier", Atelier.Basculer) end
end)

LCM.AddCommand("atelier", "(MJ) creer traits, races et objets en seance", function() Atelier.Basculer() end, true)
