-- La fenetre de fiche.
--
-- Elle se construit ENTIEREMENT a partir du schema : un champ ajoute dans
-- Data/ apparait ici sans une ligne de plus. C'est tout l'interet d'avoir fige
-- la structure — le rendu n'a plus a connaitre le jeu, seulement les cinq
-- types de champ.
--
-- Une seule fenetre, qui affiche l'entite qu'on lui donne : la sienne, ou celle
-- d'un PNJ. Joueurs et PNJ partagent la meme feuille, donc le meme ecran.

local _, LCM = ...
local UI = LCM.UI

local Fiche = {}
UI.Fiche = Fiche

local LIGNE = 22
local COLONNE_LABEL = 150

local function Nombre(valeur)
    local n = tonumber(valeur)
    if not n then return tostring(valeur or "") end
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return string.format("%.2f", n)
end

-- ===== Lignes, une par type de champ =======================================

local Lignes = {}

function Lignes.stat(parent, field, entity)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(LIGNE)
    l.label = UI.Texte(l, field.label, UI.C.texte, "GameFontNormalSmall")
    l.label:SetPoint("LEFT", l, "LEFT", 0, 0)
    l.valeur = UI.Texte(l, "", UI.C.titre, "GameFontNormalSmall")
    l.valeur:SetPoint("LEFT", l, "LEFT", COLONNE_LABEL, 0)
    function l:Actualiser(e)
        self.valeur:SetText(Nombre(LCM.Entities.Get_Value(e, field.id)))
    end
    return l
end

Lignes.calc = Lignes.stat
Lignes.text = Lignes.stat

function Lignes.gauge(parent, field, entity)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(LIGNE)
    l.label = UI.Texte(l, field.label, UI.C.texte, "GameFontNormalSmall")
    l.label:SetPoint("LEFT", l, "LEFT", 0, 0)
    local couleur = UI.C.fatigue
    if field.id == "armure" then couleur = UI.C.armure end
    l.barre = UI.Barre(l, couleur, 160, 14)
    l.barre:SetPoint("LEFT", l, "LEFT", COLONNE_LABEL, 0)
    function l:Actualiser(e)
        local jauge = LCM.Entities.Gauge(e, field.id)
        if jauge then self.barre:Regler(jauge.current, jauge.max) end
    end
    return l
end

function Lignes.roll(parent, field, entity)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(LIGNE)
    l.label = UI.Texte(l, field.label, UI.C.texte, "GameFontNormalSmall")
    l.label:SetPoint("LEFT", l, "LEFT", 0, 0)
    l.valeur = UI.Texte(l, "", UI.C.titre, "GameFontNormalSmall")
    l.valeur:SetPoint("LEFT", l, "LEFT", COLONNE_LABEL, 0)

    -- La case d'avantage n'apparait que si un trait l'accorde : inutile de
    -- proposer un choix qui n'en est pas un.
    l.avantage = CreateFrame("CheckButton", nil, l)
    l.avantage:SetSize(16, 16)
    l.avantage:SetPoint("LEFT", l, "LEFT", COLONNE_LABEL + 40, 0)
    l.avantage.fond = UI.Aplat(l.avantage, UI.C.fondClair)
    l.avantage.fond:SetAllPoints(l.avantage)
    UI.Bordure(l.avantage, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.5 })
    l.avantage.marque = UI.Texte(l.avantage, "", UI.C.accent, "GameFontNormalSmall")
    l.avantage.marque:SetAllPoints(l.avantage)
    l.avantage.marque:SetJustifyH("CENTER")
    l.avantage:SetScript("OnClick", function(bouton)
        bouton:SetChecked(not bouton:GetChecked())
        bouton.marque:SetText(bouton:GetChecked() and "v" or "")
    end)

    l.lancer = UI.Bouton(l, "Jet", 44, 18, function()
        local entite = l.entity
        if not entite then return end
        local resultat = LCM.Roll.Field(entite, field.id, { avantage = l.avantage:GetChecked() })
        if resultat then LCM.Info(LCM.Roll.Describe(resultat)) end
    end)
    l.lancer:SetPoint("LEFT", l, "LEFT", COLONNE_LABEL + 62, 0)

    function l:Actualiser(e)
        self.entity = e
        local valeur = tonumber(LCM.Entities.Get_Value(e, field.id)) or 0
        local bonus = LCM.Traits.Bonus(e, field.id)
        if bonus ~= 0 then
            self.valeur:SetText(string.format("%d %+d", valeur, bonus))
        else
            self.valeur:SetText(Nombre(valeur))
        end
        local trait = LCM.Traits.Advantage(e, field.id)
        self.avantage:SetShown(trait ~= nil)
        if not trait then
            self.avantage:SetChecked(false)
            self.avantage.marque:SetText("")
        end
    end
    return l
end

function Lignes.body(parent, field, entity)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(210)
    l.silhouette = UI.Silhouette.Creer(l, 240, 190)
    l.silhouette:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
    l.total = UI.Texte(l, "", UI.C.titre, "GameFontNormalSmall")
    l.total:SetPoint("TOPLEFT", l.silhouette, "TOPRIGHT", 12, -2)
    l.aide = UI.Texte(l, "molette : blesser / soigner", UI.C.discret, "GameFontNormalSmall")
    l.aide:SetPoint("TOPLEFT", l.silhouette, "TOPRIGHT", 12, -20)
    local function Rafraichir(e)
        local courant, maximum = LCM.Body.Totals(e)
        l.total:SetText(string.format("%d / %d PV", courant, maximum))
    end
    l.silhouette.onChange = Rafraichir
    function l:Actualiser(e)
        self.silhouette:Actualiser(e)
        Rafraichir(e)
    end
    return l
end

-- ===== La fenetre ==========================================================

local function ConstruireOnglet(parent, tab)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page.lignes = {}

    local y = 0
    for _, section in ipairs(tab.sections) do
        if section.label ~= "" then
            local titre = UI.Texte(page, section.label, UI.C.accent, "GameFontNormalSmall")
            titre:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
            y = y + LIGNE
        end
        for _, field in ipairs(section.fields) do
            local fabrique = Lignes[field.kind]
            if fabrique then
                local ligne = fabrique(page, field)
                ligne:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -y)
                ligne:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -y)
                page.lignes[#page.lignes + 1] = ligne
                y = y + ligne:GetHeight() + 2
            end
        end
        y = y + 6
    end
    page.hauteur = y

    function page:Actualiser(entity)
        for _, ligne in ipairs(self.lignes) do
            if ligne.Actualiser then ligne:Actualiser(entity) end
        end
    end
    page:Hide()
    return page
end

function Fiche.Fenetre()
    if Fiche.frame then return Fiche.frame end

    local f = UI.Fenetre("fiche", "Fiche", 560, 640, { x = -180, y = 0 })
    Fiche.frame = f

    f.nom = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    f.nom:SetPoint("TOPLEFT", f.titre, "BOTTOMLEFT", 0, -4)

    local onglets = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        onglets[#onglets + 1] = { id = tab.id, label = tab.label }
    end

    f.pages = {}
    f.zone = CreateFrame("Frame", nil, f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -46)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.barre = UI.Onglets(f.contenu, onglets, function(id) f:Afficher(id) end)
    -- Sept onglets ne tiennent pas a la largeur par defaut des boutons.
    for _, b in ipairs(f.barre.boutons) do b:SetWidth(72) end
    f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -18)
    f.barre:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -18)

    for _, tab in ipairs(LCM.Schema.Tabs()) do
        f.pages[tab.id] = ConstruireOnglet(f.zone, tab)
    end

    function f:Afficher(ongletId)
        self.onglet = ongletId
        for id, page in pairs(self.pages) do
            page:SetShown(id == ongletId)
        end
        if self.entity and self.pages[ongletId] then
            self.pages[ongletId]:Actualiser(self.entity)
        end
    end

    function f:Montrer(entity)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self.nom:SetText(tostring(self.entity.name or self.entity.id))
        self:Afficher(self.onglet or onglets[1] and onglets[1].id)
        self:Show()
    end

    function f:Actualiser()
        if self.entity and self.onglet and self.pages[self.onglet] then
            self.pages[self.onglet]:Actualiser(self.entity)
        end
    end

    return f
end

LCM.AddCommand("fiche", "ouvre la fiche", function(argument)
    local f = Fiche.Fenetre()
    if f:IsShown() then
        f:Hide()
        return
    end
    local entite = LCM.Entities.Self()
    local cible = tostring(argument or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cible ~= "" then
        entite = LCM.Entities.Get(cible) or entite
    end
    f:Montrer(entite)
end)
