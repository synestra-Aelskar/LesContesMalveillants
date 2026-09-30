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
        local valeur = LCM.Entities.Get_Value(e, field.id)
        -- Un nombre saisi recoit les bonus portes (traits, objets), montres a
        -- part : « 2 +3 », pour qu'on sache ce qui vient de soi.
        local bonus = field.kind == "stat" and LCM.Effets.Bonus(e, field.id) or 0
        if bonus ~= 0 then
            self.valeur:SetText(Nombre(tonumber(valeur) or 0) .. " " .. ((bonus > 0) and "+" or "") .. Nombre(bonus))
        else
            self.valeur:SetText(Nombre(valeur))
        end
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
        -- Ce que le personnage vaut de lui-meme (investi + apport de ses
        -- primaires), puis ce qu'il porte : « 6 +3 ».
        local valeur = (tonumber(LCM.Entities.Get_Value(e, field.id)) or 0) + LCM.Formules.Apport(e, field.id)
        local bonus = LCM.Effets.Bonus(e, field.id)
        if bonus ~= 0 then
            self.valeur:SetText(string.format("%d %+d", valeur, bonus))
        else
            self.valeur:SetText(Nombre(valeur))
        end
        local trait = LCM.Effets.Avantage(e, field.id)
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

-- ----- Les traits portes ----------------------------------------------------
-- Une carte par trait : nom, cout, description, effets. La liste defile dans
-- une hauteur fixe, pour que les lignes suivantes de l'onglet ne bougent pas
-- selon le nombre de traits.
--
-- Donner ou retirer un trait est un geste de MJ : le joueur choisit les siens a
-- la creation, avec un budget ; ensuite, c'est la partie qui les accorde.

local HAUTEUR_TRAITS = 380
local LARGEUR_CARTE = 500

local function Montant(n)
    return (n >= 0 and "+" or "") .. Nombre(n)
end

-- « Escalade +3  ·  Avantage : Escalade ». Trie, pour qu'un meme trait se lise
-- toujours pareil.
local function Effets(trait)
    local bonus, avantages = {}, {}
    for champ, montant in pairs(trait.bonus) do
        local field = LCM.Schema.Field(champ)
        bonus[#bonus + 1] = (field and field.label or champ) .. " " .. Montant(montant)
    end
    for champ in pairs(trait.avantage) do
        local field = LCM.Schema.Field(champ)
        avantages[#avantages + 1] = field and field.label or champ
    end
    table.sort(bonus)
    table.sort(avantages)
    if #avantages > 0 then bonus[#bonus + 1] = "Avantage : " .. table.concat(avantages, ", ") end
    return table.concat(bonus, "  ·  ")
end

-- Une carte pour tout ce qui porte des effets (trait, objet) : la fenetre
-- d'equipement s'en sert aussi. `onRetirer(id)` est appele par la croix.
function Fiche.Carte(parent, onRetirer)
    local c = CreateFrame("Frame", nil, parent)
    c.fond = UI.Aplat(c, UI.C.fondClair)
    c.fond:SetAllPoints(c)

    c.nom = UI.Texte(c, "", UI.C.titre, "GameFontNormalSmall")
    c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -6)
    c.cout = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
    c.cout:SetPoint("TOPRIGHT", c, "TOPRIGHT", -32, -6)
    c.cout:SetJustifyH("RIGHT")
    -- L'identifiant est porte par la carte, lu au clic : les cartes sont
    -- reutilisees d'un affichage a l'autre.
    c.retirer = UI.Bouton(c, "x", 18, 18, function() onRetirer(c.elementId) end)
    c.retirer:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -4)

    c.description = UI.Texte(c, "", UI.C.texte, "GameFontNormalSmall")
    c.description:SetWidth(LARGEUR_CARTE - 16)
    c.description:SetWordWrap(true)
    c.effets = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
    c.effets:SetWidth(LARGEUR_CARTE - 16)
    c.effets:SetWordWrap(true)

    -- Remplit la carte et renvoie sa hauteur. `element` est nil quand
    -- l'identifiant ne designe plus rien ; `coin` est le texte en haut a
    -- droite (le cout d'un trait).
    function c:Habiller(id, element, mj, coin)
        self.elementId = id
        local description, effets
        if element then
            self.nom:SetText(element.label .. (element.brouillon and "  |cff99907f· brouillon|r" or ""))
            self.nom:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
            self.cout:SetText(coin or "")
            description = element.description
            effets = Effets(element)
            if effets == "" then effets = "Aucun effet chiffré." end
        else
            -- Un element disparu reste montre : il est encore sur l'entite, et
            -- redevient actif s'il revient. Le taire ferait croire a une
            -- fiche saine.
            self.nom:SetText("? " .. tostring(id))
            self.nom:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])
            self.cout:SetText("")
            description = "N'existe pas dans cette version de l'addon (brouillon supprimé, "
                .. "ou contenu pas encore publié). Ne donne rien tant qu'il n'existe pas."
            effets = ""
        end
        self.retirer:SetShown(mj)

        local y = 24
        self.description:ClearAllPoints()
        self.description:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -y)
        self.description:SetText(description or "")
        if (description or "") ~= "" then
            self.description:Show()
            y = y + self.description:GetStringHeight() + 4
        else
            self.description:Hide()
        end
        self.effets:ClearAllPoints()
        self.effets:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -y)
        self.effets:SetText(effets)
        if effets ~= "" then
            self.effets:Show()
            y = y + self.effets:GetStringHeight() + 4
        else
            self.effets:Hide()
        end
        return y + 4
    end
    return c
end

function Lignes.traits(parent, field)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(HAUTEUR_TRAITS)
    l.cartes = {}

    l.label = UI.Texte(l, field.label, UI.C.texte, "GameFontNormalSmall")
    l.label:SetPoint("TOPLEFT", l, "TOPLEFT", 0, -4)
    l.resume = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
    l.resume:SetPoint("TOPLEFT", l, "TOPLEFT", COLONNE_LABEL, -4)

    l.ajouter = UI.Bouton(l, "+  Ajouter", 90, 18, function() l:ProposerAjout() end)
    l.ajouter:SetPoint("TOPRIGHT", l, "TOPRIGHT", -4, -2)
    l.choix = UI.Choix("fiche_traits", "Ajouter un trait")
    l:SetScript("OnHide", function() l.choix:Hide() end)

    l.zone = UI.Defilement(l)
    l.zone:SetPoint("TOPLEFT", l, "TOPLEFT", 0, -26)
    l.zone:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", 0, 0)

    l.vide = UI.Texte(l.zone.contenu, "Aucun trait porté.", UI.C.discret, "GameFontNormalSmall")
    l.vide:SetPoint("TOPLEFT", l.zone.contenu, "TOPLEFT", 8, -6)

    -- Ne propose que ce qui n'est pas deja porte.
    function l:ProposerAjout()
        if not (self.entity and LCM.IsMaster()) then return end
        local options = {}
        for _, trait in ipairs(LCM.Traits.list) do
            if not LCM.Traits.Has(self.entity, trait.id) then
                options[#options + 1] = {
                    id = trait.id,
                    label = string.format("%s  (%d pt%s)%s", trait.label, trait.cout,
                        trait.cout > 1 and "s" or "", trait.brouillon and "  · brouillon" or ""),
                }
            end
        end
        if #options == 0 then
            LCM.Alerte("tous les traits connus sont deja portes.")
            return
        end
        table.sort(options, function(a, b) return a.label:lower() < b.label:lower() end)
        self.choix:Proposer(self.ajouter, options, function(id)
            if LCM.Traits.Grant(self.entity, id) then self:Actualiser(self.entity) end
        end)
    end

    -- Retirer se rattrape (on redonne le trait) : pas de confirmation.
    function l:Retirer(id)
        if not (self.entity and LCM.IsMaster()) then return end
        if LCM.Traits.Revoke(self.entity, id) then self:Actualiser(self.entity) end
    end

    function l:Actualiser(e)
        self.entity = e
        local mj = LCM.IsMaster()
        self.ajouter:SetShown(mj)

        local ids = LCM.Traits.Ids(e)
        local y = 0
        for index, id in ipairs(ids) do
            local c = self.cartes[index]
            if not c then
                c = Fiche.Carte(self.zone.contenu, function(traitId) self:Retirer(traitId) end)
                self.cartes[index] = c
            end
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            local trait = LCM.Traits.Get(id)
            local hauteur = c:Habiller(id, trait, mj,
                trait and string.format("%d pt%s", trait.cout, trait.cout > 1 and "s" or ""))
            c:SetHeight(hauteur)
            c:Show()
            y = y + hauteur + 6
        end
        for index = #ids + 1, #self.cartes do self.cartes[index]:Hide() end
        self.vide:SetShown(#ids == 0)

        local cout = LCM.Traits.CoutTotal(e)
        self.resume:SetText(#ids == 0 and "" or string.format("%d trait%s  ·  %d pt%s",
            #ids, #ids > 1 and "s" or "", cout, cout > 1 and "s" or ""))
        self.zone:Regler(y)
    end
    return l
end

-- ===== La fenetre ==========================================================

-- Une page : des sections du schema, dessinees ligne a ligne. La fiche en fait
-- un onglet ; les fenetres du menu (UI/Vues.lua) en font une fenetre a part
-- avec les MEMES lignes — une seule facon de montrer un champ dans l'addon.
function Fiche.Page(parent, sections)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page.lignes = {}

    local y = 0
    for _, section in ipairs(sections) do
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
        f.pages[tab.id] = Fiche.Page(f.zone, tab.sections)
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
