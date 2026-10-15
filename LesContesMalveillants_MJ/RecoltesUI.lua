-- La fenetre « Ressources » du MJ : creer des points de recolte, puis les poser
-- sur la carte (13 octobre 2026).
--
-- Deux onglets, dans l'ordre ou on s'en sert :
--   * CREATION — « Miner du fer » : plusieurs ressources (choisies, ou glissees
--     depuis le compendium), chance et quantite de chacune, regeneration,
--     limite du point, metier, DD et rayon ;
--   * PLACEMENT — on choisit « Miner du fer », on marche, et chaque clic sur
--     « Creer un point de recolte » en pose un ICI. Tous les points poses de
--     cette ressource sont listes en dessous, et se retirent un par un.
--
-- Elle remplace l'ancien editeur a offres pour les ressources : un point de
-- recolte ne se « vend » pas en liste, il se trouve sur le terrain. Le vendeur,
-- lui, garde son constructeur (MJ/PointsUI.lua).

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Points = LCM.Points
local Recoltes = LCM.Recoltes

local Ecran = {}
UI.Recoltes = Ecran

local LARGEUR, HAUTEUR = 760, 560
local COLONNE = 210
local LIGNE = 26

local function Eq() return (LCM.Equilibrage and LCM.Equilibrage.recolte) or {} end

-- « Nytherah-Apertus » -> « Nytherah ».
local function Court(nom) return (tostring(nom or ""):match("^([^%-]+)")) or "" end

local function Libelle(parent, texte, x, y)
    local t = UI.Texte(parent, texte, UI.C.discret, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return t
end

local function Entier(texte)
    local n = tonumber(texte)
    return n and n == math.floor(n) and n or nil
end

-- Un point donne des ressources ou des objets forgés (armes, armures,
-- accessoires). Les sacs, tentes et autres entrées restent exclus.
local FAMILLES = { objets = "Objets", ressources = "Ressources" }

local function EstEntreeRecoltable(ref)
    local famille = tostring(ref or ""):match("^([%w_]+)/")
    return FAMILLES[famille] ~= nil
end

local function OptionsEntrees()
    local options = {}
    for famille, groupe in pairs(FAMILLES) do
        local registreNom = LCM.Compendium and LCM.Compendium.FAMILLES
            and LCM.Compendium.FAMILLES[famille]
        local registre = registreNom and LCM[registreNom]
        for _, entree in ipairs((registre and registre.list) or {}) do
            options[#options + 1] = { id = famille .. "/" .. entree.id,
                label = entree.label or entree.id, groupe = groupe }
        end
    end
    table.sort(options, function(a, b)
        if a.groupe ~= b.groupe then return a.groupe < b.groupe end
        return tostring(a.label) < tostring(b.label)
    end)
    return options
end

local function OptionsMetiers(choix, exception)
    local deja = {}
    for index, ligne in ipairs(choix or {}) do
        if index ~= exception then deja[ligne.id] = true end
    end
    local options = {}
    if not deja[LCM.Recolte.METIER_AUCUN] then
        options[#options + 1] = { id = LCM.Recolte.METIER_AUCUN, label = "Aucun métier" }
    end
    for _, metier in ipairs(LCM.Metiers.list) do
        if not deja[metier.id] then
            options[#options + 1] = { id = metier.id, label = metier.label }
        end
    end
    return options
end

local function Travail(point)
    if point then
        local copie = LCM.Copie(point)
        copie.brouillon, copie.remplacePublie = nil, nil
        copie.recolte = copie.recolte or {}
        if not copie.recolte.ressources then
            copie.recolte.ressources = { { entree = copie.recolte.entree or "",
                min = copie.recolte.min or 1, max = copie.recolte.max or 1,
                aleatoire = copie.recolte.aleatoire or false, chance = 100 } }
        end
        if copie.recolte.limite == nil then copie.recolte.limite = 1 end
        if not copie.recolte.metiers then
            copie.recolte.metiers = copie.recolte.metier
                and { { id = copie.recolte.metier, bonus = true } } or {}
        end
        return copie
    end
    return {
        id = LCM.Brouillons.NouvelIdentifiant(), nature = "ressource",
        label = "", description = "", offres = {},
        recolte = { ressources = {},
                    metiers = {}, limite = 1, dd = 0, rayon = Eq().rayon },
    }
end

-- « Mineur, DD 8 — 2 à 4 Minerai de fer, à 3 m »
local function Resume(point)
    local r = point and point.recolte
    if not r then return "Pas encore configuré : passe par l'onglet Création." end
    local noms = {}
    for _, lot in ipairs(r.ressources or { r }) do
        local ressource = LCM.Compendium.Resoudre(lot.entree)
        noms[#noms + 1] = string.format("%s (%d%%)",
            (ressource and ressource.label) or lot.entree, tonumber(lot.chance) or 100)
    end
    local nomsMetiers = {}
    for _, choix in ipairs(r.metiers or {}) do
        local metier = LCM.Metiers.Get(choix.id)
        nomsMetiers[#nomsMetiers + 1] = choix.id == LCM.Recolte.METIER_AUCUN
            and "Aucun métier" or (metier and metier.label or choix.id)
    end
    local jet = #nomsMetiers > 0 and string.format("%s, DD %d", table.concat(nomsMetiers, "/"), r.dd)
        or (r.dd > 0 and string.format("DD %d", r.dd) or "sans jet")
    return string.format("%s — %s — rayon %s yards", table.concat(noms, ", "), jet,
        tostring(r.rayon or Eq().rayon or 3))
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("recoltes", "Ressources", LARGEUR, HAUTEUR, { x = 100, y = -40 })
    f.onglet = "creation"

    -- ----- les points de recolte, a gauche --------------------------------
    f.liste = UI.Defilement(f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 34)
    f.liste:SetWidth(COLONNE)
    f.lignes = {}
    f.nouveau = UI.Bouton(f.contenu, "+ Nouveau", 100, 24, function() f:Nouveau() end)
    f.nouveau:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.supprimer = UI.Bouton(f.contenu, "Supprimer", 100, 24, function() f:Supprimer() end)
    f.supprimer:SetPoint("LEFT", f.nouveau, "RIGHT", 6, 0)
    f.confirmation = UI.Confirmer(f, "", "Confirmer")

    f.droite = CreateFrame("Frame", nil, f.contenu)
    f.droite:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 16, 0)
    f.droite:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.boutonCreation = UI.Bouton(f.droite, "Création", 120, 24, function() f:Onglet("creation") end)
    f.boutonCreation:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, 0)
    f.boutonPlacement = UI.Bouton(f.droite, "Placement", 120, 24, function() f:Onglet("placement") end)
    f.boutonPlacement:SetPoint("LEFT", f.boutonCreation, "RIGHT", 6, 0)
    -- ----- CREATION -------------------------------------------------------
    local c = CreateFrame("Frame", nil, f.droite)
    c:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -34)
    c:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.creation = c
    f.choixEntree = UI.Choix("recolte_entree", "Contenu récolté")
    f.choixMetier = UI.Choix("recolte_metier", "Métier du jet")

    Libelle(c, "Nom", 0, -6)
    c.nom = UI.Champ(c, 300, 22, function(texte) if f.travail then f.travail.label = texte end end)
    c.nom:SetMaxLetters(80)
    c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 110, 0)

    Libelle(c, "Ressources", 0, -40)
    c.tableau = CreateFrame("Frame", nil, c)
    c.tableau:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -62)
    c.tableau:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -62)
    c.tableau:SetHeight(54)
    UI.BordureFine(c.tableau, 0.18)
    c.entete = CreateFrame("Frame", nil, c.tableau)
    c.entete:SetPoint("TOPLEFT", c.tableau, "TOPLEFT", 1, -1)
    c.entete:SetPoint("TOPRIGHT", c.tableau, "TOPRIGHT", -1, -1)
    c.entete:SetHeight(23)
    local fondEntete = UI.Aplat(c.entete, { 0.07, 0.07, 0.07, 0.30 })
    fondEntete:SetAllPoints(c.entete)
    local function TitreColonne(texte, x, largeur)
        local titre = Libelle(c.entete, texte, x, -6)
        titre:SetWidth(largeur)
        titre:SetJustifyH("CENTER")
    end
    TitreColonne("I", 0, 31)
    TitreColonne("NOM", 31, 124)
    TitreColonne("QUANTITÉ", 155, 161)
    TitreColonne("CHANCE %", 316, 60)
    TitreColonne("REPOUSSE (min)", 376, 98)
    for _, x in ipairs({ 31, 155, 316, 376, 474 }) do
        local trait = UI.Filet(c.entete, false, true)
        trait:SetPoint("TOPLEFT", c.entete, "TOPLEFT", x, 0)
        trait:SetPoint("BOTTOMLEFT", c.entete, "BOTTOMLEFT", x, 0)
    end

    c.zoneRessources = UI.Defilement(c.tableau)
    c.zoneRessources:SetPoint("TOPLEFT", c.tableau, "TOPLEFT", 1, -24)
    c.zoneRessources:SetPoint("TOPRIGHT", c.tableau, "TOPRIGHT", -1, -24)
    c.zoneRessources:SetHeight(30)
    c.lignesRessources = {}

    c.communs = CreateFrame("Frame", nil, c)
    c.communs:SetPoint("TOPLEFT", c.tableau, "BOTTOMLEFT", 0, -14)
    c.communs:SetPoint("TOPRIGHT", c.tableau, "BOTTOMRIGHT", 0, -14)
    c.communs:SetHeight(201)
    local g = c.communs
    Libelle(g, "Récoltes / point", 0, -7)
    c.infini = UI.Case(g, "Infini", function(coche)
        if f.travail then
            f.travail.recolte.limite = coche and 0 or 1
            f:Remplir()
        end
    end)
    c.infini:SetPoint("TOPLEFT", g, "TOPLEFT", 110, -5)
    c.libelleLimite = Libelle(g, "Limite", 220, -7)
    c.limite = UI.Champ(g, 50, 22, function(texte)
        if f.travail then f.travail.recolte.limite = texte end
    end)
    c.limite:SetPoint("TOPLEFT", g, "TOPLEFT", 270, -1)

    Libelle(g, "Jet raté", 0, -35)
    c.echecConsomme = UI.Case(g, "Consomme une récolte", function(coche)
        if f.travail then f.travail.recolte.echecConsomme = coche end
    end)
    c.echecConsomme:SetPoint("TOPLEFT", g, "TOPLEFT", 110, -33)

    Libelle(g, "Métiers autorisés", 0, -69)
    c.tableauMetiers = CreateFrame("Frame", nil, g)
    c.tableauMetiers:SetPoint("TOPLEFT", g, "TOPLEFT", 0, -86)
    c.tableauMetiers:SetPoint("TOPRIGHT", g, "TOPRIGHT", -8, -86)
    c.tableauMetiers:SetHeight(51)
    UI.BordureFine(c.tableauMetiers, 0.18)
    c.enteteMetiers = CreateFrame("Frame", nil, c.tableauMetiers)
    c.enteteMetiers:SetPoint("TOPLEFT", c.tableauMetiers, "TOPLEFT", 1, -1)
    c.enteteMetiers:SetPoint("TOPRIGHT", c.tableauMetiers, "TOPRIGHT", -1, -1)
    c.enteteMetiers:SetHeight(23)
    local fondMetiers = UI.Aplat(c.enteteMetiers, { 0.07, 0.07, 0.07, 0.30 })
    fondMetiers:SetAllPoints(c.enteteMetiers)
    local enteteNom = Libelle(c.enteteMetiers, "MÉTIER", 0, -6)
    enteteNom:SetWidth(260)
    enteteNom:SetJustifyH("CENTER")
    local enteteBonus = Libelle(c.enteteMetiers, "BONUS DE JET", 260, -6)
    enteteBonus:SetWidth(214)
    enteteBonus:SetJustifyH("CENTER")
    local divisionMetiers = UI.Filet(c.enteteMetiers, false, true)
    divisionMetiers:SetPoint("TOPLEFT", c.enteteMetiers, "TOPLEFT", 260, 0)
    divisionMetiers:SetPoint("BOTTOMLEFT", c.enteteMetiers, "BOTTOMLEFT", 260, 0)
    c.zoneMetiers = UI.Defilement(c.tableauMetiers)
    c.zoneMetiers:SetPoint("TOPLEFT", c.tableauMetiers, "TOPLEFT", 1, -24)
    c.zoneMetiers:SetPoint("TOPRIGHT", c.tableauMetiers, "TOPRIGHT", -1, -24)
    c.zoneMetiers:SetHeight(28)
    c.lignesMetiers = {}

    c.apresMetiers = CreateFrame("Frame", nil, g)
    c.apresMetiers:SetPoint("TOPLEFT", c.tableauMetiers, "BOTTOMLEFT", 0, -12)
    c.apresMetiers:SetPoint("TOPRIGHT", c.tableauMetiers, "BOTTOMRIGHT", 0, -12)
    c.apresMetiers:SetHeight(80)
    local a = c.apresMetiers
    Libelle(a, "DD", 0, -7)
    c.dd = UI.Champ(a, 50, 22, function(texte)
        if f.travail then f.travail.recolte.dd = texte end
    end)
    c.dd:SetPoint("TOPLEFT", a, "TOPLEFT", 110, -1)
    c.aideJet = UI.Texte(a, "", UI.C.discret, "GameFontNormalSmall")
    c.aideJet:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -28)
    c.aideJet:SetPoint("RIGHT", a, "RIGHT", 0, 0)
    c.aideJet:SetJustifyH("LEFT")

    Libelle(a, "Rayon (yards)", 0, -56)
    c.rayon = UI.Champ(a, 50, 22, function(texte)
        if f.travail then f.travail.recolte.rayon = texte end
    end)
    c.rayon:SetPoint("TOPLEFT", a, "TOPLEFT", 110, -50)
    c.aideRayon = UI.Texte(a, "Distance à laquelle le bouton « Récolter » apparaît.",
        UI.C.discret, "GameFontNormalSmall")
    c.aideRayon:SetPoint("LEFT", c.rayon, "RIGHT", 10, 0)

    c.erreur = UI.Texte(c, "", UI.C.plein, "GameFontNormalSmall")
    c.erreur:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 6)
    c.erreur:SetPoint("RIGHT", c, "RIGHT", -150, 0)
    c.erreur:SetJustifyH("LEFT")
    c.enregistrer = UI.Bouton(c, "Enregistrer", 140, 26, function() f:Enregistrer() end)
    c.enregistrer:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
    -- ----- PLACEMENT ------------------------------------------------------
    local p = CreateFrame("Frame", nil, f.droite)
    p:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -34)
    p:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.placement = p

    p.titre = UI.Texte(p, "", UI.C.titre)
    UI.Police(p.titre, 14)
    p.titre:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -2)
    p.resume = UI.Texte(p, "", UI.C.discret, "GameFontNormalSmall")
    p.resume:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -22)
    p.resume:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    p.resume:SetJustifyH("LEFT")
    p.position = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
    p.position:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -44)
    p.position:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    p.position:SetJustifyH("LEFT")

    p.poser = UI.Bouton(p, "Créer un point de récolte", 260, 34, function() f:Poser() end)
    p.poser:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -66)
    p.compte = UI.Texte(p, "", UI.C.accent, "GameFontNormalSmall")
    p.compte:SetPoint("LEFT", p.poser, "RIGHT", 12, 0)
    p.toutRetirer = UI.Bouton(p, "Tout retirer", 110, 22, function() f:ToutRetirer() end)
    p.toutRetirer:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -72)

    p.zone = UI.Defilement(p)
    p.zone:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -110)
    p.zone:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -10, 0)
    p.lignes = {}
    p.vide = UI.Texte(p, "Aucun point posé. Marche jusqu'à l'endroit voulu et clique sur « Créer un point de récolte ».",
        UI.C.discret, "GameFontNormalSmall")
    p.vide:SetPoint("TOP", p.zone, "TOP", 0, -20)
    p.vide:SetWidth(380)
    p.vide:SetJustifyH("CENTER")
    p.vide:SetWordWrap(true)

    -- La position s'affiche en direct : on pose en marchant, il faut voir ou
    -- l'on est au moment ou l'on clique.
    p.attente = 0
    p:SetScript("OnUpdate", function(self, dt)
        self.attente = self.attente + (dt or 0)
        if self.attente < 0.5 then return end
        self.attente = 0
        f:Position()
    end)

    -- ----- comportement ---------------------------------------------------

    function f:Point()
        return self.pointId and Points.Get(self.pointId) or nil
    end

    function f:Ressource()
        local r = self.travail and self.travail.recolte
        return r and r.ressources and r.ressources[self.ressourceIndex or 1]
    end

    function f:Onglet(onglet)
        self.onglet = onglet
        self.boutonCreation:Selectionner(onglet == "creation")
        self.boutonPlacement:Selectionner(onglet == "placement")
        self.creation:SetShown(onglet == "creation")
        self.placement:SetShown(onglet == "placement")
        self:Afficher()
    end

    function f:Choisir(id)
        self.pointId = id
        local point = self:Point()
        self.creationNeuve = point == nil
        self.travail = Travail(point)
        self.ressourceIndex = 1
        self.ressourceOuverte = nil
        self.remplacePublie = point and LCM.Brouillons.EstPublie("points", point.id) or false
        self.creation.erreur:SetText("")
        self:Remplir()
        self:Afficher()
    end

    function f:Nouveau()
        self:Choisir(nil)
        self:Onglet("creation")
    end

    function f:AfficherRessources()
        local ressources = self.travail and self.travail.recolte.ressources or {}
        local PAS, DETAIL = 28, 33
        local function Nombre(champ, valeur)
            valeur = tostring(valeur)
            if champ:GetText() ~= valeur then champ:SetText(valeur) end
        end
        local function Accepter(objet)
            if objet and EstEntreeRecoltable(objet.ref) then return true end
            return false, "seules les ressources et les armes, armures ou accessoires du compendium peuvent être récoltés."
        end
        local function Ajouter(ref)
            local items = self.travail.recolte.ressources
            items[#items + 1] = { entree = ref, min = 1, max = 1,
                aleatoire = false, chance = 100, regeneration = false, minutes = 0 }
            self.ressourceIndex = #items
            self.ressourceOuverte = nil
            self:Remplir()
        end
        local y, ouvertureHaut, ouvertureBas = 0, nil, nil
        for index, lot in ipairs(ressources) do
            local ligne = c.lignesRessources[index]
            if not ligne then
                ligne = CreateFrame("Button", nil, c.zoneRessources.contenu)
                ligne:RegisterForClicks("LeftButtonUp")
                ligne.fond = UI.Aplat(ligne, { 0.07, 0.07, 0.07, 0.10 })
                ligne.fond:SetAllPoints(ligne)
                UI.BordureFine(ligne, 0.14)
                ligne.survol = UI.Aplat(ligne, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
                ligne.survol:SetAllPoints(ligne)
                ligne.selection = UI.Aplat(ligne, { 0.72, 0.72, 0.72, 0.13 }, "BORDER")
                ligne.selection:SetAllPoints(ligne)
                ligne:SetScript("OnClick", function(self)
                    f.ressourceIndex = self.index
                    if f.ressourceOuverte == self.index then
                        f.ressourceOuverte = nil
                    else
                        f.ressourceOuverte = self.index
                    end
                    f:AfficherRessources()
                end)

                for _, x in ipairs({ 31, 155, 316, 376, 474 }) do
                    local trait = UI.Filet(ligne, false, true)
                    trait:SetPoint("TOPLEFT", ligne, "TOPLEFT", x, -3)
                    trait:SetPoint("BOTTOMLEFT", ligne, "TOPLEFT", x, -PAS + 3)
                end
                ligne.icone = ligne:CreateTexture(nil, "ARTWORK")
                ligne.icone:SetSize(18, 18)
                ligne.icone:SetPoint("TOPLEFT", ligne, "TOPLEFT", 7, -5)
                ligne.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                ligne.nom = UI.Texte(ligne, "", UI.C.texte, "GameFontNormalSmall")
                ligne.nom:SetPoint("TOPLEFT", ligne, "TOPLEFT", 35, -7)
                ligne.nom:SetWidth(116)
                ligne.nom:SetWordWrap(false)
                ligne.quantiteResume = UI.Texte(ligne, "", UI.C.texte, "GameFontNormalSmall")
                ligne.quantiteResume:SetPoint("TOPLEFT", ligne, "TOPLEFT", 155, -7)
                ligne.quantiteResume:SetWidth(161)
                ligne.quantiteResume:SetJustifyH("CENTER")
                ligne.chanceResume = UI.Texte(ligne, "", UI.C.texte, "GameFontNormalSmall")
                ligne.chanceResume:SetPoint("TOPLEFT", ligne, "TOPLEFT", 316, -7)
                ligne.chanceResume:SetWidth(60)
                ligne.chanceResume:SetJustifyH("CENTER")
                ligne.repousseResume = UI.Texte(ligne, "", UI.C.texte, "GameFontNormalSmall")
                ligne.repousseResume:SetPoint("TOPLEFT", ligne, "TOPLEFT", 376, -7)
                ligne.repousseResume:SetWidth(98)
                ligne.repousseResume:SetJustifyH("CENTER")
                ligne.retirer = CreateFrame("Button", nil, ligne)
                ligne.retirer:SetSize(24, 22)
                ligne.retirer:SetPoint("TOPLEFT", ligne, "TOPLEFT", 477, -3)
                ligne.retirer.label = UI.Texte(ligne.retirer, "×", UI.C.discret, "GameFontNormalSmall")
                ligne.retirer.label:SetAllPoints(ligne.retirer)
                ligne.retirer.label:SetJustifyH("CENTER")
                local survolRetirer = UI.Aplat(ligne.retirer, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
                survolRetirer:SetAllPoints(ligne.retirer)
                ligne.retirer:SetScript("OnClick", function()
                    local items = f.travail.recolte.ressources
                    table.remove(items, ligne.index)
                    f.ressourceIndex = math.max(1, math.min(ligne.index, #items))
                    f.ressourceOuverte = nil
                    f:Remplir()
                end)

                ligne.detail = CreateFrame("Frame", nil, ligne)
                ligne.detail:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, -PAS)
                ligne.detail:SetPoint("TOPRIGHT", ligne, "TOPRIGHT", 0, -PAS)
                ligne.detail:SetHeight(DETAIL)
                local d = ligne.detail
                local fondDetail = UI.Aplat(d, { 0.13, 0.13, 0.13, 0.32 })
                fondDetail:SetAllPoints(d)
                UI.BordureFine(d, 0.14)
                for _, x in ipairs({ 31, 155, 316, 376, 474 }) do
                    local trait = UI.Filet(d, false, true)
                    trait:SetPoint("TOPLEFT", d, "TOPLEFT", x, -2)
                    trait:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", x, 2)
                end
                ligne.choix = CreateFrame("Button", nil, d)
                ligne.choix:SetSize(116, 24)
                ligne.choix:SetPoint("TOPLEFT", d, "TOPLEFT", 35, -5)
                ligne.choix.label = UI.Texte(ligne.choix, "Changer…", UI.C.discret, "GameFontNormalSmall")
                ligne.choix.label:SetAllPoints(ligne.choix)
                ligne.choix.label:SetJustifyH("LEFT")
                local survolChoix = UI.Aplat(ligne.choix, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
                survolChoix:SetAllPoints(ligne.choix)
                ligne.choix:SetScript("OnClick", function()
                    f.ressourceIndex = ligne.index
                    f.choixEntree:Proposer(ligne.choix, OptionsEntrees(), function(ref)
                        local courant = f.travail.recolte.ressources[ligne.index]
                        if courant then courant.entree = ref f:Remplir() end
                    end)
                end)
                UI.Glisser.Cible(ligne.choix, Accepter, function(objet)
                    local courant = f.travail.recolte.ressources[ligne.index]
                    if courant then courant.entree = objet.ref f:Remplir() end
                end)

                ligne.aleatoire = UI.Case(d, "Aléat.", function(coche)
                    local courant = f.travail.recolte.ressources[ligne.index]
                    if courant then courant.aleatoire = coche f:AfficherRessources() end
                end)
                ligne.aleatoire:SetPoint("TOPLEFT", d, "TOPLEFT", 160, -8)
                ligne.min = UI.Champ(d, 38, 22, function(texte)
                    local courant = f.travail.recolte.ressources[ligne.index]
                    if courant then courant.min = texte ligne.quantiteResume:SetText(texte) end
                end)
                ligne.min:SetPoint("TOPLEFT", d, "TOPLEFT", 226, -5)
                ligne.separateur = Libelle(d, "–", 264, -10)
                ligne.max = UI.Champ(d, 38, 22, function(texte)
                    local courant = f.travail.recolte.ressources[ligne.index]
                    if courant then courant.max = texte
                        ligne.quantiteResume:SetText(tostring(courant.min) .. "–" .. texte) end
                end)
                ligne.max:SetPoint("TOPLEFT", d, "TOPLEFT", 274, -5)
                ligne.chance = UI.Champ(d, 46, 22, function(texte)
                    local courant = f.travail.recolte.ressources[ligne.index]
                    if courant then courant.chance = texte ligne.chanceResume:SetText(texte .. "%") end
                end)
                ligne.chance:SetPoint("TOPLEFT", d, "TOPLEFT", 323, -5)
                ligne.regeneration = UI.Case(d, "", function(coche)
                    local courant = f.travail.recolte.ressources[ligne.index]
                    if courant then courant.regeneration = coche f:AfficherRessources() end
                end)
                ligne.regeneration:SetPoint("TOPLEFT", d, "TOPLEFT", 387, -8)
                ligne.minutes = UI.Champ(d, 54, 22, function(texte)
                    local courant = f.travail.recolte.ressources[ligne.index]
                    if courant then courant.minutes = texte ligne.repousseResume:SetText(texte .. " min") end
                end)
                ligne.minutes:SetPoint("TOPLEFT", d, "TOPLEFT", 409, -5)
                for _, champ in ipairs({ ligne.min, ligne.max, ligne.chance, ligne.minutes }) do
                    if champ.cadreSaisie then champ.cadreSaisie:SetAlpha(0.28) end
                end
                c.lignesRessources[index] = ligne
            end

            ligne.index = index
            local entree = LCM.Compendium.Resoudre(lot.entree)
            ligne.nom:SetText((entree and entree.label) or lot.entree or "")
            ligne.icone:SetTexture((entree and entree.icone)
                or "Interface\\ICONS\\INV_Misc_QuestionMark")
            ligne.quantiteResume:SetText(lot.aleatoire
                and (tostring(lot.min or 1) .. "–" .. tostring(lot.max or 1))
                or tostring(lot.min or 1))
            ligne.chanceResume:SetText(tostring(lot.chance == nil and 100 or lot.chance) .. "%")
            ligne.repousseResume:SetText(lot.regeneration
                and (tostring(lot.minutes or 0) .. " min") or "Non")
            ligne.aleatoire:Cocher(lot.aleatoire)
            Nombre(ligne.min, lot.min or 1)
            Nombre(ligne.max, lot.max or lot.min or 1)
            ligne.max:SetShown(lot.aleatoire == true)
            ligne.separateur:SetShown(lot.aleatoire == true)
            Nombre(ligne.chance, lot.chance == nil and 100 or lot.chance)
            ligne.regeneration:Cocher(lot.regeneration)
            Nombre(ligne.minutes, lot.minutes or 0)
            ligne.minutes:SetShown(lot.regeneration == true)
            local ouverte = index == self.ressourceOuverte
            ligne.detail:SetShown(ouverte)
            ligne.selection:SetShown(ouverte)
            ligne:SetHeight(PAS + (ouverte and DETAIL or 0))
            if index == self.ressourceIndex then
                c.entree, c.aleatoire, c.min, c.max = ligne.choix, ligne.aleatoire, ligne.min, ligne.max
                c.chance, c.regeneration, c.minutes = ligne.chance, ligne.regeneration, ligne.minutes
            end
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", c.zoneRessources.contenu, "TOPLEFT", 0, -y)
            ligne:SetPoint("TOPRIGHT", c.zoneRessources.contenu, "TOPRIGHT", 0, -y)
            ligne:Show()
            if ouverte then ouvertureHaut, ouvertureBas = y, y + PAS + DETAIL end
            y = y + PAS + (ouverte and DETAIL or 0)
        end
        for index = #ressources + 1, #c.lignesRessources do c.lignesRessources[index]:Hide() end

        if not c.ajouter then
            c.ajouter = CreateFrame("Button", nil, c.zoneRessources.contenu)
            c.ajouter:SetHeight(PAS)
            c.ajouter.fond = UI.Aplat(c.ajouter, { 0.07, 0.07, 0.07, 0.10 })
            c.ajouter.fond:SetAllPoints(c.ajouter)
            UI.BordureFine(c.ajouter, 0.14)
            c.ajouter.label = UI.Texte(c.ajouter, "Ajoutez un élément +", UI.C.discret, "GameFontNormalSmall")
            c.ajouter.label:SetAllPoints(c.ajouter)
            c.ajouter.label:SetJustifyH("CENTER")
            local survolAjout = UI.Aplat(c.ajouter, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
            survolAjout:SetAllPoints(c.ajouter)
            c.ajouter:SetScript("OnClick", function()
                f.choixEntree:Proposer(c.ajouter, OptionsEntrees(), Ajouter)
            end)
            UI.Glisser.Cible(c.ajouter, Accepter, function(objet) Ajouter(objet.ref) end)
        end
        c.ajouter:ClearAllPoints()
        c.ajouter:SetPoint("TOPLEFT", c.zoneRessources.contenu, "TOPLEFT", 0, -y)
        c.ajouter:SetPoint("TOPRIGHT", c.zoneRessources.contenu, "TOPRIGHT", 0, -y)
        if #ressources == 0 then c.entree = c.ajouter end
        local hauteur = y + PAS
        local visible = math.min(hauteur, 201)
        c.zoneRessources:SetHeight(visible)
        c.zoneRessources:Regler(hauteur)
        c.tableau:SetHeight(24 + visible)
        if ouvertureBas and ouvertureBas > c.zoneRessources.decalage + visible then
            c.zoneRessources:Aller(ouvertureBas - visible)
        elseif ouvertureHaut and ouvertureHaut < c.zoneRessources.decalage then
            c.zoneRessources:Aller(ouvertureHaut)
        end
        c.communs:Show()
        self:AfficherMetiers()
    end

    function f:AfficherMetiers()
        local choix = self.travail and self.travail.recolte.metiers or {}
        local pas = 28
        for index, regle in ipairs(choix) do
            local ligne = c.lignesMetiers[index]
            if not ligne then
                ligne = CreateFrame("Frame", nil, c.zoneMetiers.contenu)
                ligne:SetHeight(pas)
                local fond = UI.Aplat(ligne, { 0.07, 0.07, 0.07, 0.10 })
                fond:SetAllPoints(ligne)
                UI.BordureFine(ligne, 0.14)
                local division = UI.Filet(ligne, false, true)
                division:SetPoint("TOPLEFT", ligne, "TOPLEFT", 260, -3)
                division:SetPoint("BOTTOMLEFT", ligne, "BOTTOMLEFT", 260, 3)
                ligne.nom = CreateFrame("Button", nil, ligne)
                ligne.nom:SetPoint("TOPLEFT", ligne, "TOPLEFT", 8, -2)
                ligne.nom:SetSize(246, 24)
                ligne.nom.label = UI.Texte(ligne.nom, "", UI.C.texte, "GameFontNormalSmall")
                ligne.nom.label:SetAllPoints(ligne.nom)
                ligne.nom.label:SetJustifyH("LEFT")
                local survol = UI.Aplat(ligne.nom, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
                survol:SetAllPoints(ligne.nom)
                ligne.nom:SetScript("OnClick", function()
                    f.choixMetier:Proposer(ligne.nom,
                        OptionsMetiers(f.travail.recolte.metiers, ligne.index), function(id)
                            local courant = f.travail.recolte.metiers[ligne.index]
                            if courant then
                                courant.id = id
                                if id == LCM.Recolte.METIER_AUCUN then courant.bonus = false end
                                f:AfficherMetiers()
                            end
                        end)
                end)
                ligne.bonus = UI.Case(ligne, "Oui", function(coche)
                    local courant = f.travail.recolte.metiers[ligne.index]
                    if courant and courant.id ~= LCM.Recolte.METIER_AUCUN then
                        courant.bonus = coche
                        f:AfficherMetiers()
                    end
                end)
                ligne.bonus:SetPoint("TOPLEFT", ligne, "TOPLEFT", 320, -5)
                ligne.sansBonus = UI.Texte(ligne, "—", UI.C.discret, "GameFontNormalSmall")
                ligne.sansBonus:SetPoint("TOPLEFT", ligne, "TOPLEFT", 320, -7)
                ligne.retirer = CreateFrame("Button", nil, ligne)
                ligne.retirer:SetSize(24, 22)
                ligne.retirer:SetPoint("TOPLEFT", ligne, "TOPLEFT", 477, -3)
                ligne.retirer.label = UI.Texte(ligne.retirer, "×", UI.C.discret, "GameFontNormalSmall")
                ligne.retirer.label:SetAllPoints(ligne.retirer)
                ligne.retirer.label:SetJustifyH("CENTER")
                ligne.retirer:SetScript("OnClick", function()
                    table.remove(f.travail.recolte.metiers, ligne.index)
                    f:AfficherMetiers()
                end)
                c.lignesMetiers[index] = ligne
            end
            ligne.index = index
            local metier = LCM.Metiers.Get(regle.id)
            local sansMetier = regle.id == LCM.Recolte.METIER_AUCUN
            ligne.nom.label:SetText(sansMetier and "Aucun métier"
                or (metier and metier.label or tostring(regle.id or "")))
            ligne.bonus:Cocher(not sansMetier and regle.bonus ~= false)
            ligne.bonus.label:SetText(sansMetier and "—"
                or (regle.bonus ~= false and "Oui" or "Non"))
            ligne.bonus:SetShown(not sansMetier)
            ligne.sansBonus:SetShown(sansMetier)
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", c.zoneMetiers.contenu, "TOPLEFT", 0, -(index - 1) * pas)
            ligne:SetPoint("TOPRIGHT", c.zoneMetiers.contenu, "TOPRIGHT", 0, -(index - 1) * pas)
            ligne:Show()
        end
        for index = #choix + 1, #c.lignesMetiers do c.lignesMetiers[index]:Hide() end
        if not c.ajouterMetier then
            c.ajouterMetier = CreateFrame("Button", nil, c.zoneMetiers.contenu)
            c.ajouterMetier:SetHeight(pas)
            local fond = UI.Aplat(c.ajouterMetier, { 0.07, 0.07, 0.07, 0.10 })
            fond:SetAllPoints(c.ajouterMetier)
            UI.BordureFine(c.ajouterMetier, 0.14)
            c.ajouterMetier.label = UI.Texte(c.ajouterMetier,
                "Ajoutez un métier +", UI.C.discret, "GameFontNormalSmall")
            c.ajouterMetier.label:SetAllPoints(c.ajouterMetier)
            c.ajouterMetier.label:SetJustifyH("CENTER")
            local survol = UI.Aplat(c.ajouterMetier, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
            survol:SetAllPoints(c.ajouterMetier)
            c.ajouterMetier:SetScript("OnClick", function()
                f.choixMetier:Proposer(c.ajouterMetier,
                    OptionsMetiers(f.travail.recolte.metiers), function(id)
                        local items = f.travail.recolte.metiers
                        items[#items + 1] = { id = id,
                            bonus = id ~= LCM.Recolte.METIER_AUCUN }
                        f:AfficherMetiers()
                    end)
            end)
        end
        c.ajouterMetier:ClearAllPoints()
        c.ajouterMetier:SetPoint("TOPLEFT", c.zoneMetiers.contenu, "TOPLEFT", 0, -#choix * pas)
        c.ajouterMetier:SetPoint("TOPRIGHT", c.zoneMetiers.contenu, "TOPRIGHT", 0, -#choix * pas)
        c.metier = c.ajouterMetier
        local hauteur = (#choix + 1) * pas
        local visible = math.min(hauteur, 140)
        c.zoneMetiers:SetHeight(visible)
        c.zoneMetiers:Regler(hauteur)
        c.tableauMetiers:SetHeight(24 + visible)
        c.communs:SetHeight(201 + visible)
        self:SetHeight(458 + c.zoneRessources:GetHeight() + visible)
    end
    function f:Remplir()
        local t = self.travail
        if not t then return end
        local r = t.recolte
        r.entree = r.ressources[1] and r.ressources[1].entree or ""
        c.nom:SetText(t.label or "")
        self:AfficherRessources()
        c.infini:Cocher(tonumber(r.limite) == 0)
        c.limite:SetText(tostring(tonumber(r.limite) == 0 and 1 or (r.limite or 1)))
        c.limite:SetShown(tonumber(r.limite) ~= 0)
        c.libelleLimite:SetShown(tonumber(r.limite) ~= 0)
        c.echecConsomme:Cocher(r.echecConsomme == true)
        c.dd:SetText(tostring(r.dd or 0))
        local des = Eq().des or {}
        c.aideJet:SetText(string.format("Jet : D%d ; bonus selon le métier coché.", des.max or 15))
        c.rayon:SetText(tostring(r.rayon or Eq().rayon or 3))
    end
    -- Un refus dit pourquoi, et ne corrige rien en douce.
    function f:Valider()
        local t = self.travail
        local r = t.recolte
        if not tostring(t.label or ""):match("%S") then return nil, "donne un nom au point de récolte." end
        local ressources = {}
        if #(r.ressources or {}) == 0 then return nil, "choisis la ressource que le point donne." end
        for index, lot in ipairs(r.ressources or {}) do
            if (lot.entree or "") == "" or not LCM.Compendium.Resoudre(lot.entree) then
                return nil, "choisis la ressource que le point donne.", index
            end
            if not EstEntreeRecoltable(lot.entree) then
                return nil, "un point de récolte donne seulement des ressources ou des objets (armes, armures, accessoires).", index
            end
            local mini = Entier(lot.min)
            if not mini or mini < 1 then return nil, "la quantité doit être un nombre entier, au moins 1.", index end
            local maxi = mini
            if lot.aleatoire then
                maxi = Entier(lot.max)
                if not maxi or maxi < mini then
                    return nil, "le maximum doit être un entier, au moins égal au minimum.", index
                end
            end
            local chance = Entier(lot.chance)
            if not chance or chance < 0 or chance > 100 then
                return nil, "la chance doit être un entier de 0 à 100 %.", index
            end
            local minutes = tonumber(lot.minutes)
            if lot.regeneration and (not minutes or minutes < 0 or minutes > 10080) then
                return nil, "le délai de régénération doit être entre 0 et 10080 minutes.", index
            end
            ressources[#ressources + 1] = { entree = lot.entree, min = mini, max = maxi,
                aleatoire = lot.aleatoire and true or false, chance = chance,
                regeneration = lot.regeneration and true or false, minutes = minutes or 0 }
        end
        local limite = Entier(r.limite)
        if not limite or limite < 0 then return nil, "la limite doit être un entier positif (0 : infini)." end
        local metiers, deja = {}, {}
        for _, choix in ipairs(r.metiers or {}) do
            local id = tostring(choix.id or "")
            if id ~= LCM.Recolte.METIER_AUCUN and not LCM.Metiers.Get(id) then
                return nil, "choisis un métier valide."
            end
            if deja[id] then return nil, "un métier ne peut apparaître qu'une fois." end
            deja[id] = true
            metiers[#metiers + 1] = { id = id,
                bonus = id ~= LCM.Recolte.METIER_AUCUN and choix.bonus ~= false }
        end
        local dd = Entier(r.dd)
        if not dd or dd < 0 then return nil, "le DD doit être un entier positif (0 : réussite assurée)." end
        local rayon = tonumber(r.rayon)
        local rayonMax = Eq().rayonMax or 30
        if not rayon or rayon <= 0 or rayon > rayonMax then
            return nil, string.format("le rayon doit être entre 0 et %d yards.", rayonMax)
        end
        return { ressources = ressources, limite = limite, metiers = metiers,
                 echecConsomme = r.echecConsomme == true,
                 metier = metiers[1] and metiers[1].id or nil, dd = dd, rayon = rayon }
    end

    function f:Enregistrer()
        local recolte, raison, index = self:Valider()
        if not recolte then
            if index then
                self.ressourceIndex = index
                self.ressourceOuverte = index
                self:AfficherRessources()
            end
            c.erreur:SetText(raison)
            LCM.Alerte(raison)
            return
        end
        c.erreur:SetText("")
        self.travail.recolte = recolte
        local ok, erreur = LCM.Brouillons.Enregistrer("points", self.travail,
            self.creationNeuve, self.remplacePublie)
        if not ok then LCM.Alerte(tostring(erreur)) return end
        local id = self.travail.id
        -- Les points deja poses changent de regle tout de suite, chez tous.
        if Recoltes.Compte(id) > 0 then Recoltes.Diffuser(id) end
        if Recoltes.onChange then Recoltes.onChange(id) end
        LCM.Ok(string.format("Point de récolte « %s » enregistré.", self.travail.label))
        self:Choisir(id)
    end

    function f:Supprimer()
        local point = self:Point()
        if not point then return end
        local n = #Recoltes.Carnet(point.id)
        local texte = n > 0 and string.format("Supprimer « %s » et ses %d point(s) posé(s) ?", point.label, n)
            or string.format("Supprimer « %s » ?", point.label)
        self.confirmation:Demander(texte, function()
            local ok, raison
            if point.brouillon == true then ok = LCM.Brouillons.Supprimer("points", point.id)
            else ok, raison = LCM.Brouillons.Masquer("points", point.id) end
            if not ok then LCM.Alerte(tostring(raison or "suppression impossible")) return end
            Recoltes.RetirerTout(point.id)
            local premier = Points.Nature("ressource")[1]
            self:Choisir(premier and premier.id)
        end)
    end

    function f:Poser()
        local point = self:Point()
        if not point then LCM.Alerte("choisis d'abord un point de récolte.") return end
        local id, raison = Recoltes.Placer(point.id)
        if not id then LCM.Alerte(tostring(raison)) return end
        self:Afficher()
    end

    function f:ToutRetirer()
        local point = self:Point()
        if not point then return end
        local n = #Recoltes.Carnet(point.id)
        if n == 0 then return end
        self.confirmation:Demander(string.format("Retirer les %d point(s) posé(s) de « %s » ?", n, point.label),
            function()
                Recoltes.RetirerTout(point.id)
                self:Afficher()
            end)
    end

    function f:Position()
        local x, y, source = LCM.Recolte.Position()
        if x then
            local carte = LCM.Recolte.Carte()
            p.position:SetText(string.format("Tu es en %.1f, %.1f  (%s%s)", x, y, tostring(source),
                carte and (", carte " .. carte) or ""))
        else
            p.position:SetText("Position inconnue ici : le clic demandera « .gps ».")
        end
        return x, y, source
    end

    function f:AfficherPoints()
        local point = self:Point()
        -- Tout le carnet : les points recoltes y restent, grises, avec qui
        -- les a pris. Seuls les CREES partent aux joueurs.
        local liste = point and Recoltes.Carnet(point.id) or {}
        local x, y, source = self:Position()
        local carte = LCM.Recolte.Carte()
        local h = 0
        for rang, pose in ipairs(liste) do
            local l = p.lignes[rang]
            if not l then
                l = CreateFrame("Frame", nil, p.zone.contenu)
                l:SetHeight(LIGNE - 2)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.texte = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                l.texte:SetPoint("LEFT", l, "LEFT", 8, 0)
                l.texte:SetPoint("RIGHT", l, "RIGHT", -40, 0)
                l.texte:SetJustifyH("LEFT")
                l.retirer = UI.Bouton(l, "x", 24, 20, function(b)
                    Recoltes.Retirer(b:GetParent().poseId)
                    self:Afficher()
                end)
                l.retirer:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                p.lignes[rang] = l
            end
            l.poseId = pose.id
            -- La distance quand elle se mesure : meme source, meme carte.
            local distance = ""
            if x and pose.source == source and pose.carte == carte then
                distance = string.format("  —  à %.0f yards", math.sqrt((x - pose.x) ^ 2 + (y - pose.y) ^ 2))
            elseif pose.carte ~= carte then
                distance = "  —  autre carte"
            end
            local par = pose.par and (" par " .. Court(pose.par)) or ""
            local statut = pose.statut == "recolte" and string.format("|cff9d9d9dRécolté%s|r", par)
                or pose.statut == "attente" and string.format("|cffe0c060En attente%s|r", par)
                or not pose.actif and (pose.retour and "|cffe0c060En régénération|r"
                    or "|cff9d9d9dÉpuisé|r")
                or "|cff7fd07fCréé|r"
            l.texte:SetText(string.format("#%d   %s   %.1f, %.1f   (%s%s)%s", #liste - rang + 1, statut,
                pose.x, pose.y, tostring(pose.source), pose.carte and (", carte " .. pose.carte) or "",
                pose.statut == "cree" and distance or ""))
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", p.zone.contenu, "TOPLEFT", 0, -h)
            l:SetPoint("TOPRIGHT", p.zone.contenu, "TOPRIGHT", 0, -h)
            l:Show()
            h = h + LIGNE
        end
        for rang = #liste + 1, #p.lignes do p.lignes[rang]:Hide() end
        p.zone:Regler(h)
        p.vide:SetShown(point ~= nil and #liste == 0)
        local recoltes = point and Recoltes.CompteRecoltes(point.id) or 0
        local attente = point and Recoltes.CompteAttente(point.id) or 0
        local disponibles, regeneration = 0, 0
        for _, pose in ipairs(liste) do
            if pose.statut == "cree" then
                if pose.actif then disponibles = disponibles + 1
                else regeneration = regeneration + 1 end
            end
        end
        local morceaux = { string.format("%d disponible(s)", disponibles) }
        if regeneration > 0 then morceaux[#morceaux + 1] = string.format("%d en attente de ressource", regeneration) end
        if attente > 0 then morceaux[#morceaux + 1] = string.format("%d en attente", attente) end
        if recoltes > 0 then morceaux[#morceaux + 1] = string.format("%d récolté(s)", recoltes) end
        p.compte:SetText(point and table.concat(morceaux, ", ") or "")
        p.toutRetirer:SetEnabled(#liste > 0)
    end

    function f:Afficher()
        local definitions = Points.Nature("ressource")
        local y = 0
        for rang, point in ipairs(definitions) do
            local b = self.lignes[rang]
            if not b then
                b = UI.Bouton(self.liste.contenu, "", COLONNE - 10, LIGNE - 2, function(bouton)
                    self:Choisir(bouton.pointId)
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
                b.label:SetJustifyH("LEFT")
                self.lignes[rang] = b
            end
            b.pointId = point.id
            local n = Recoltes.Compte(point.id)
            b.label:SetText(n > 0 and string.format("%s  |cff9d9d9d(%d)|r", point.label, n) or point.label)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.liste.contenu, "TOPLEFT", 0, -y)
            b:Selectionner(point.id == self.pointId)
            b:Show()
            y = y + LIGNE
        end
        for rang = #definitions + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.liste:Regler(y)
        self.supprimer:SetEnabled(self:Point() ~= nil)

        local point = self:Point()
        p.titre:SetText(point and point.label or "Choisis un point de récolte à gauche")
        p.resume:SetText(point and Resume(point) or "")
        p.poser:SetEnabled(point ~= nil and point.recolte ~= nil)
        self:AfficherPoints()
    end

    function f:Montrer()
        local premier = Points.Nature("ressource")[1]
        if not self.travail then self:Choisir(premier and premier.id) end
        self:Onglet(self.onglet or "creation")
        self:Show()
    end

    UI.SuivrePersonnage(f, function(self) self:Afficher() end)
    f:Hide()
    return f
end

function Ecran.Fenetre()
    if not LCM.IsMaster() then
        LCM.Alerte("cet outil est réservé au maître du jeu.")
        return nil
    end
    Ecran.frame = Ecran.frame or Construire()
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if not f then return nil end
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.WhenReady(function()
    -- L'entree « Ressources » du menu ouvre cette fenetre. Posee apres
    -- MJ/PointsUI.lua, cette liaison remplace l'ancien editeur a offres.
    UI.Menu.Lier("ressources", function() Ecran.Basculer() end)
    Recoltes.onChange = function()
        local f = Ecran.frame
        if f and f:IsShown() then f:Afficher() end
    end
    local precedent = LCM.Brouillons.onSynchro
    LCM.Brouillons.onSynchro = function(famille, entree)
        if precedent then precedent(famille, entree) end
        if famille ~= "points" then return end
        local f = Ecran.frame
        if f and f:IsShown() then f:Afficher() end
    end
end)
