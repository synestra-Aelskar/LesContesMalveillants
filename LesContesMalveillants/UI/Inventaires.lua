-- La fenetre Inventaires, et la fenetre d'un sac ouvert.
--
-- Reprise de Necronicon (Inventory.lua : CreateInventoryFrame,
-- RefreshInventoryUI, OpenBagWindow, GetEntryContextMenu) avec ses mesures :
--
--   * la fenetre : 420 x 360 (360 x 240 au moins), un bandeau d'onglets sous
--     le titre (Sacs, Saccoches, Devises : les onglets du template), la
--     bascule Grille / Liste ; en grille, des cartes de 112 de haut, une
--     colonne tous les 180, 8 d'ecart — icone de 36 en haut, nom et
--     description centres ; en liste, des lignes de 60 ;
--   * un clic sur un sac l'OUVRE : sa fenetre (380 x 300, cadre « panel »),
--     ses cases de 46, 8 d'ecart — les places du sac, puis ses places de
--     devise (« DEV ») ; bascule Grille / Liste ;
--   * on DEPOSE en glissant une ligne du compendium sur un emplacement ou une
--     case ; un clic sur un emplacement vide propose la liste du compendium ;
--     le clic droit ouvre le menu (Voir, Ouvrir, Quantite, Deplacer >,
--     Supprimer).
--
-- Ranger, deplacer et supprimer sont des gestes de MJ, comme l'equipement : le
-- joueur voit, ouvre et consulte. Ce qui n'est pas repris : l'edition des
-- onglets et des emplacements (structure, Data/Inventaire.lua), « Donner... »
-- (pas de reseau), « Scinder la pile », les colonnes personnalisees des sacs.

local _, LCM = ...
local UI = LCM.UI
local Inv = LCM.Inventaire

local Ecran = {}
UI.Inventaires = Ecran

local LARGEUR, HAUTEUR, MIN_L, MIN_H = 420, 360, 360, 240
local CARTE_H_GRILLE, CARTE_H_LISTE, ECART, COLONNE = 112, 60, 8, 180
local CASE, ECART_CASE = 46, 8
local VIDE = 135956   -- l'icone d'emplacement vide de Necronicon (DEFAULT_EMPTY_ICON)

local function Action(parent, texte, largeur, hauteur)
    return UI.Bouton(parent, texte, largeur or math.max(18, #tostring(texte) * 7 + 10), hauteur or 18)
end

local function Peindre(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function Entite() return LCM.Entities.Self() end

local function Refuser(raison) if raison then LCM.Alerte(raison) end end

-- La categorie du compendium d'une reference, pour « Voir ».
local function Voir(ref, ancre)
    local element, categorie = LCM.Compendium.Resoudre(ref)
    if element and categorie then UI.Compendium.Voir(categorie, element, ancre) end
end

-- La liste du compendium qu'un emplacement ou une case peut recevoir.
local function Candidats(familles)
    local out = {}
    for _, categorie in ipairs(LCM.Compendium.categories) do
        if categorie.famille and familles[categorie.famille] then
            for _, element in ipairs(LCM.Compendium.Entrees(categorie)) do
                out[#out + 1] = { id = LCM.Compendium.Reference(categorie, element), label = element.label,
                                  groupe = categorie.label, element = element }
            end
        end
    end
    return out
end

-- Les vues choisies (grille / liste) durent le temps de la session : une
-- preference d'ecran, pas une donnee du personnage.
local vues = {}
local function Vue(cle, defaut) return vues[cle] or defaut end

-- ===== Une carte d'emplacement ============================================

local function Carte(f)
    local c = CreateFrame("Button", nil, f.zone.contenu)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    c.fond = UI.Aplat(c, { 0, 0, 0, 0.2 })
    c.fond:SetAllPoints(c)
    UI.BordureFine(c, 0.30)
    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.nom = UI.Texte(c, "", UI.C.titre, "GameFontNormal")
    c.nom:SetWordWrap(false)
    c.description = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    c.description:SetWordWrap(true)
    c.survol = UI.Aplat(c, UI.C.survol, "HIGHLIGHT")
    c.survol:SetAllPoints(c)
    -- On y depose un sac (ou une devise) glisse depuis le compendium.
    UI.Glisser.Cible(c, function(objet)
        if not LCM.IsMaster() then return false, "ranger est un geste du maître du jeu." end
        local categorie = Inv.Get(f.onglet)
        local voulu = categorie.contient == "sac" and "sacs" or "devises"
        if not tostring(objet.ref or ""):match("^" .. voulu .. "/") then
            return false, categorie.contient == "sac" and "cet emplacement n'accepte qu'un sac."
                or "cet emplacement n'accepte qu'une devise."
        end
        if Inv.Emplacement(Entite(), f.onglet, c.index) then return false, "cet emplacement est déjà occupé." end
        return true
    end, function(objet)
        local ok, raison = Inv.Poser(Entite(), f.onglet, c.index, objet.element.id)
        if not ok then Refuser(raison) end
        f:Rafraichir()
    end)
    c:SetScript("OnClick", function(self, bouton) f:CliquerEmplacement(self, bouton) end)
    c:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.nom:GetText() or "Emplacement", 1, 0.82, 0)
        if self.aide then GameTooltip:AddLine(self.aide, 0.8, 0.75, 0.62, true) end
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return c
end

-- ===== La fenetre principale ==============================================

local function Construire()
    local f = UI.Fenetre("inventaires", "Inventaires", LARGEUR, HAUTEUR, { x = 240, y = 20 },
        { enTeteSimple = true, redimensionnable = true })
    Ecran.frame = f
    f.onglet = Inv.categories[1].id
    f.choix = UI.Choix("inventaire", "")

    f.vue = Action(f, "Liste", 44, 18)
    f.vue:SetPoint("RIGHT", f.fermer, "LEFT", -8, 0)
    f.vue:SetFrameLevel(f:GetFrameLevel() + 6)
    f.vue:SetScript("OnClick", function()
        local categorie = Inv.Get(f.onglet)
        vues[f.onglet] = Vue(f.onglet, categorie.vue) == "grille" and "liste" or "grille"
        f:Rafraichir()
    end)

    f.filet = UI.Filet(f)
    f.filet:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    f.filet:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -36)

    -- Les onglets : un par categorie du template, crees une fois.
    f.bandeau = CreateFrame("Frame", nil, f)
    f.bandeau:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    f.bandeau:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -36)
    f.bandeau:SetHeight(24)
    f.onglets = {}
    for index, categorie in ipairs(Inv.categories) do
        local b = UI.Bouton(f.bandeau, categorie.label, 84, 22, function(bouton)
            f.onglet = bouton.categorieId
            f.zone:Aller(0)
            f:Rafraichir()
        end)
        if UI.HabillerOnglet then UI.HabillerOnglet(b) end
        UI.Police(b.label, 12)
        b.categorieId = categorie.id
        f.onglets[index] = b
    end

    f.zone = UI.Defilement(f)
    f.cartes = {}

    -- Le compte « occupes / total » de l'onglet, a droite du bandeau.
    f.occupation = UI.Texte(f, "", UI.C.titre, "GameFontNormalSmall")
    f.occupation:SetPoint("BOTTOMRIGHT", f.bandeau, "BOTTOMRIGHT", 0, 6)
    f.occupation:SetJustifyH("RIGHT")

    UI.Redimensionner(f, MIN_L, MIN_H, function() f:Rafraichir() end)
    f:HookScript("OnSizeChanged", function() if not f.enRedimension then f:Rafraichir() end end)
    f:HookScript("OnShow", function() f:Rafraichir() end)
    f:HookScript("OnHide", function() f.choix:Hide() end)

    -- Les onglets passent a la ligne si la fenetre est etroite (70 a 116 de
    -- large selon le nom, 6 d'ecart, 24 par rangee).
    function f:Onglets()
        local largeur = self.bandeau:GetWidth()
        if not largeur or largeur <= 0 then largeur = self:GetWidth() - 24 end
        local x, y = 0, 0
        for _, b in ipairs(self.onglets) do
            local w = math.max(70, math.min(116, #b.label:GetText() * 7 + 16))
            if x > 0 and x + w > largeur - 80 then x, y = 0, y + 24 end
            b:SetSize(w, 22)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.bandeau, "TOPLEFT", x, -y)
            if b.Selectionner then b:Selectionner(b.categorieId == self.onglet) end
            x = x + w + 6
        end
        local hauteur = y + 24
        self.bandeau:SetHeight(hauteur)
        return hauteur
    end

    function f:Rafraichir()
        if not self:IsShown() then return end
        local entity = Entite()
        local categorie = Inv.Get(self.onglet)
        local vue = Vue(self.onglet, categorie.vue)
        self.vue.label:SetText(vue == "grille" and "Liste" or "Grille")
        local hauteurBandeau = self:Onglets()
        self.zone:ClearAllPoints()
        self.zone:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -42 - hauteurBandeau)
        self.zone:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -28, 16)

        local capacite = Inv.Capacite(self.onglet)
        self.occupation:SetText(string.format("%d / %d", Inv.Occupes(entity, self.onglet), capacite))

        local largeur = self.zone:GetWidth()
        if not largeur or largeur <= 0 then largeur = self:GetWidth() - 40 end
        largeur = math.max(280, largeur)
        local colonnes, largeurCarte, hauteurCarte = 1, largeur - 2, CARTE_H_LISTE
        if vue == "grille" then
            colonnes = math.max(1, math.floor((largeur + ECART) / COLONNE))
            largeurCarte = math.floor((largeur - (colonnes - 1) * ECART) / colonnes)
            hauteurCarte = CARTE_H_GRILLE
        end
        for index = 1, capacite do
            local c = self.cartes[index]
            if not c then
                c = Carte(self)
                self.cartes[index] = c
            end
            c.index = index
            c:SetSize(largeurCarte, hauteurCarte)
            c:ClearAllPoints()
            if vue == "grille" then
                local col, rang = (index - 1) % colonnes, math.floor((index - 1) / colonnes)
                c:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", col * (largeurCarte + ECART), -rang * (hauteurCarte + ECART))
            else
                c:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -(index - 1) * (hauteurCarte + ECART))
            end
            self:HabillerCarte(c, entity, categorie, Inv.Emplacement(entity, self.onglet, index), vue)
            c:Show()
        end
        for index = capacite + 1, #self.cartes do self.cartes[index]:Hide() end
        local rangs = vue == "grille" and math.ceil(capacite / colonnes) or capacite
        self.zone:Regler(math.max(1, rangs * (hauteurCarte + ECART) - ECART))
        Ecran.RafraichirSacs()
    end

    function f:HabillerCarte(c, entity, categorie, e, vue)
        c.icone:ClearAllPoints()
        c.nom:ClearAllPoints()
        c.description:ClearAllPoints()
        if vue == "grille" then
            c.icone:SetSize(36, 36)
            c.icone:SetPoint("TOP", c, "TOP", 0, -10)
            c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -52)
            c.nom:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -52)
            c.nom:SetJustifyH("CENTER")
            c.description:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -2)
            c.description:SetPoint("TOPRIGHT", c.nom, "BOTTOMRIGHT", 0, -2)
            c.description:SetJustifyH("CENTER")
        else
            c.icone:SetSize(34, 34)
            c.icone:SetPoint("LEFT", c, "LEFT", 8, 0)
            c.nom:SetPoint("TOPLEFT", c.icone, "TOPRIGHT", 10, 1)
            c.nom:SetPoint("RIGHT", c, "RIGHT", -12, 0)
            c.nom:SetJustifyH("LEFT")
            c.description:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -2)
            c.description:SetPoint("RIGHT", c, "RIGHT", -12, 0)
            c.description:SetJustifyH("LEFT")
        end
        c.emplacement = e
        if not e then
            c.icone:SetTexture(VIDE)
            c.nom:SetText(categorie.contient == "devise" and "Emplacement devise" or "Emplacement")
            Peindre(c.nom, UI.C.discret)
            c.description:SetText("Emplacement disponible")
            c.aide = LCM.IsMaster()
                and (categorie.contient == "sac" and "Clic : choisir un sac, ou glisse-le depuis le compendium."
                    or "Clic : choisir une devise, ou glisse-la depuis le compendium.")
                or nil
            return
        end
        Peindre(c.nom, UI.C.titre)
        if e.sac then
            local sac = LCM.Sacs.Get(e.sac)
            local total = Inv.Cases(e)
            local pleines = 0
            for _ in pairs(e.cases or {}) do pleines = pleines + 1 end
            c.icone:SetTexture(sac and sac.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
            -- Le nom et le remplissage, comme le template : « Gros sac (2/12) ».
            c.nom:SetText(string.format("%s (%d/%d)", sac and sac.label or ("? " .. e.sac), pleines, total))
            if not sac then Peindre(c.nom, UI.C.plein) end
            c.description:SetText(sac and sac.description or "N'existe pas dans cette version de l'addon.")
            c.aide = "Clic : ouvrir. Clic droit : options."
        else
            local devise = LCM.Devises.Get(e.devise)
            c.icone:SetTexture(devise and devise.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
            c.nom:SetText(devise and devise.label or ("? " .. e.devise))
            if not devise then Peindre(c.nom, UI.C.plein) end
            c.description:SetText("Solde : " .. tostring(e.solde or 0))
            c.aide = "Clic droit : options."
        end
    end

    -- Clic : ouvrir un sac, ou (MJ) choisir ce qu'on pose dans un vide.
    -- Clic droit : le menu de l'emplacement.
    function f:CliquerEmplacement(c, bouton)
        local entity, onglet, index = Entite(), self.onglet, c.index
        local e = c.emplacement
        local categorie = Inv.Get(onglet)
        if bouton == "RightButton" then
            if not e then return end
            local options = {}
            if e.sac then
                options[#options + 1] = { label = "Ouvrir", action = function() Ecran.OuvrirSac(onglet, index) end }
                options[#options + 1] = { label = "Voir", action = function() Voir("sacs/" .. e.sac, self) end }
            else
                options[#options + 1] = { label = "Voir", action = function() Voir("devises/" .. e.devise, self) end }
            end
            if LCM.IsMaster() then
                if e.devise then
                    options[#options + 1] = { label = "Solde : " .. tostring(e.solde or 0), action = function()
                        UI.Demande():Demander("Solde de la devise", e.solde or 0, function(texte)
                            local ok, raison = Inv.Solde(entity, onglet, index, texte)
                            if ok then self:Rafraichir() end
                            return ok, raison
                        end)
                    end }
                end
                if e.sac then
                    -- Deplacer > : vers un emplacement de sac libre (Sacs ou Saccoches).
                    local cibles = {}
                    for _, autre in ipairs(Inv.categories) do
                        if autre.contient == "sac" then
                            for i = 1, Inv.Capacite(autre.id) do
                                if not Inv.Emplacement(entity, autre.id, i) then
                                    local cibleOnglet, cibleIndex = autre.id, i
                                    cibles[#cibles + 1] = { label = string.format("%s · emplacement %d", autre.label, i),
                                        action = function()
                                            local ok, raison = Inv.Deplacer(entity, onglet, index, cibleOnglet, cibleIndex)
                                            if not ok then Refuser(raison) return end
                                            Ecran.FermerSac(onglet, index)
                                            self:Rafraichir()
                                        end }
                                end
                            end
                        end
                    end
                    if #cibles > 0 then options[#options + 1] = { label = "Deplacer >", sous = cibles } end
                end
                options[#options + 1] = { label = "Supprimer", action = function()
                    local ok, raison = Inv.Retirer(entity, onglet, index)
                    if ok then Ecran.FermerSac(onglet, index) else Refuser(raison) end
                    self:Rafraichir()
                end }
            end
            UI.MenuContexte():Ouvrir(c, options)
            return
        end
        if e and e.sac then
            Ecran.OuvrirSac(onglet, index)
        elseif e then
            Voir("devises/" .. e.devise, self)
        elseif LCM.IsMaster() then
            local options = Candidats({ [categorie.contient == "sac" and "sacs" or "devises"] = true })
            self.choix.titre:SetText(categorie.contient == "sac" and "Sac" or "Devise")
            self.choix:Proposer(c, options, function(ref)
                local id = tostring(ref):match("/(.+)$")
                local ok, raison = Inv.Poser(entity, onglet, index, id)
                if not ok then Refuser(raison) end
                self:Rafraichir()
            end)
        end
    end
    return f
end

-- ===== La fenetre d'un sac ================================================

local sacs = {}

local function NouvelleCase(s, n)
    local b = CreateFrame("Button", nil, s.zone.contenu)
    b:SetSize(CASE, CASE)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.fond = UI.Aplat(b, { 0, 0, 0, 0.2 })
    b.fond:SetAllPoints(b)
    UI.BordureFine(b, 0.30)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
    b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 5)
    b.nombre = UI.Texte(b, "", { 1, 0.97, 0.86 }, "GameFontNormal")
    b.nombre:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.nombre:SetJustifyH("RIGHT")
    -- En liste : une ligne de 28, icone de 20 et nom.
    b.nom = UI.Texte(b, "", UI.C.texte, "GameFontNormalSmall")
    b.nom:SetWordWrap(false)
    b.survol = UI.Aplat(b, { 0.80, 0.70, 0.40, 0.12 }, "HIGHLIGHT")
    b.survol:SetAllPoints(b)
    UI.Glisser.Cible(b, function(objet)
        if not LCM.IsMaster() then return false, "ranger est un geste du maître du jeu." end
        local e = s:Emplacement()
        if Inv.Case(e, b.index) then return false, "cette case est déjà occupée." end
        return Inv.Accepte(e, b.index, objet.ref)
    end, function(objet)
        local ok, raison = Inv.Ranger(Entite(), s.onglet, s.index, b.index, objet.ref, 1)
        if not ok then Refuser(raison) end
        Ecran.Actualiser()
    end)
    b:SetScript("OnClick", function(self, bouton) s:CliquerCase(self, bouton) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local c = Inv.Case(s:Emplacement(), self.index)
        local element = c and LCM.Compendium.Resoudre(c.ref)
        if c then
            GameTooltip:SetText(element and element.label or ("? " .. tostring(c.ref)), 1, 0.82, 0)
            if element and element.description ~= "" then
                GameTooltip:AddLine(element.description, 0.8, 0.75, 0.62, true)
            end
            GameTooltip:AddLine("Clic gauche : voir. Clic droit : options.", 0.55, 0.55, 0.55)
        else
            GameTooltip:SetText(self.devise and "Emplacement devise" or "Emplacement", 1, 0.82, 0)
            if LCM.IsMaster() then GameTooltip:AddLine("Clic : ajouter une entree.", 0.55, 0.55, 0.55) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    s.cases[n] = b
    return b
end

local function ConstruireSac(onglet, index)
    local cle = onglet .. "_" .. index
    local s = UI.Fenetre("sac_" .. cle, "Sac", 380, 300, { x = 120 + index * 20, y = -40 - index * 20 },
        { enTeteSimple = true, redimensionnable = true })
    s.onglet, s.index = onglet, index
    s.cases = {}
    s.vue = Action(s, "Liste", 44, 18)
    s.vue:SetPoint("TOPLEFT", s, "TOPLEFT", 14, -12)
    s.vue:SetFrameLevel(s:GetFrameLevel() + 6)
    s.vue:SetScript("OnClick", function()
        vues[cle] = Vue(cle, "grille") == "grille" and "liste" or "grille"
        s:Rafraichir()
    end)
    s.filet = UI.Filet(s)
    s.filet:SetPoint("TOPLEFT", s, "TOPLEFT", 14, -42)
    s.filet:SetPoint("TOPRIGHT", s, "TOPRIGHT", -14, -42)
    s.zone = UI.Defilement(s)
    s.zone:SetPoint("TOPLEFT", s, "TOPLEFT", 14, -52)
    s.zone:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -30, 28)
    s.choix = UI.Choix("sac_" .. cle, "")
    UI.Redimensionner(s, 320, 260, function() s:Rafraichir() end)
    s:HookScript("OnSizeChanged", function() if not s.enRedimension then s:Rafraichir() end end)
    s:HookScript("OnShow", function() s:Rafraichir() end)
    s:HookScript("OnHide", function() s.choix:Hide() end)

    function s:Emplacement() return Inv.Emplacement(Entite(), self.onglet, self.index) end

    function s:Rafraichir()
        if not self:IsShown() then return end
        local e = self:Emplacement()
        if not (e and e.sac) then self:Hide() return end
        local sac = LCM.Sacs.Get(e.sac)
        self:Titre(sac and sac.label or ("? " .. e.sac))
        local vue = Vue(cle, "grille")
        self.vue.label:SetText(vue == "grille" and "Liste" or "Grille")
        local total = Inv.Cases(e)
        local largeur = self.zone:GetWidth()
        if not largeur or largeur <= CASE then largeur = self:GetWidth() - 44 end
        largeur = math.max(CASE, largeur - 8)
        local colonnes = math.max(1, math.floor((largeur + ECART_CASE) / (CASE + ECART_CASE)))
        for n = 1, total do
            local b = self.cases[n] or NouvelleCase(self, n)
            b.index = n
            b.devise = Inv.EstCaseDevise(e, n)
            local c = Inv.Case(e, n)
            local element = c and LCM.Compendium.Resoudre(c.ref)
            b:ClearAllPoints()
            b.icone:ClearAllPoints()
            b.nom:ClearAllPoints()
            if vue == "grille" then
                local col, rang = (n - 1) % colonnes, math.floor((n - 1) / colonnes)
                b:SetSize(CASE, CASE)
                b:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", col * (CASE + ECART_CASE), -rang * (CASE + ECART_CASE))
                b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
                b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 5)
                b.nom:Hide()
            else
                b:SetHeight(28)
                b:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -(n - 1) * 30)
                b:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -(n - 1) * 30)
                b.icone:SetSize(20, 20)
                b.icone:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.nom:SetPoint("LEFT", b.icone, "RIGHT", 8, 0)
                b.nom:SetPoint("RIGHT", b, "RIGHT", -40, 0)
                b.nom:SetText(c and (element and element.label or ("? " .. tostring(c.ref)))
                    or (b.devise and "Emplacement devise" or "Emplacement"))
                b.nom:Show()
            end
            if c then
                b.icone:SetTexture(element and element.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
                b.icone:Show()
                b.fond:SetColorTexture(0, 0, 0, 0.28)
                -- Une devise montre toujours son nombre ; le reste, a partir de deux.
                local q = tonumber(c.quantite) or 1
                b.nombre:SetText((b.devise or q > 1) and ("x" .. q) or "")
            else
                b.icone:SetShown(vue ~= "grille")
                if vue ~= "grille" then b.icone:SetTexture(VIDE) end
                b.fond:SetColorTexture(0, 0, 0, 0.2)
                b.nombre:SetText(b.devise and "DEV" or "")
            end
            b:Show()
        end
        for n = total + 1, #self.cases do self.cases[n]:Hide() end
        local rangs = vue == "grille" and math.ceil(total / colonnes) or total
        self.zone:Regler(vue == "grille" and rangs * (CASE + ECART_CASE) or total * 30)
    end

    function s:CliquerCase(b, bouton)
        local entity = Entite()
        local e = self:Emplacement()
        local c = Inv.Case(e, b.index)
        if bouton == "RightButton" then
            if not c then return end
            local options = { { label = "Voir", action = function() Voir(c.ref, self) end } }
            if LCM.IsMaster() then
                options[#options + 1] = { label = "Quantite : " .. tostring(c.quantite or 1), action = function()
                    UI.Demande():Demander("Quantite de la pile", c.quantite or 1, function(texte)
                        local ok, raison = Inv.Quantite(entity, self.onglet, self.index, b.index, texte)
                        if ok then Ecran.Actualiser() end
                        return ok, raison
                    end)
                end }
                -- Deplacer > : vers la premiere case libre d'un autre sac qui l'accepte.
                local cibles = {}
                for _, categorie in ipairs(Inv.categories) do
                    for i = 1, Inv.Capacite(categorie.id) do
                        local autre = Inv.Emplacement(entity, categorie.id, i)
                        if autre and autre.sac and autre ~= e then
                            local libre
                            for n = 1, Inv.Cases(autre) do
                                if not libre and not Inv.Case(autre, n) and Inv.Accepte(autre, n, c.ref) then libre = n end
                            end
                            if libre then
                                local sac = LCM.Sacs.Get(autre.sac)
                                local cibleOnglet, cibleIndex, cibleCase = categorie.id, i, libre
                                cibles[#cibles + 1] = { label = sac and sac.label or autre.sac, action = function()
                                    local ref, quantite = c.ref, c.quantite
                                    Inv.Vider(entity, self.onglet, self.index, b.index)
                                    Inv.Ranger(entity, cibleOnglet, cibleIndex, cibleCase, ref, quantite)
                                    Ecran.Actualiser()
                                end }
                            end
                        end
                    end
                end
                if #cibles > 0 then options[#options + 1] = { label = "Deplacer >", sous = cibles } end
                options[#options + 1] = { label = "Supprimer", action = function()
                    Inv.Vider(entity, self.onglet, self.index, b.index)
                    Ecran.Actualiser()
                end }
            end
            UI.MenuContexte():Ouvrir(b, options)
            return
        end
        if c then
            -- Un sac range dans un sac : comme dans le template, on le voit.
            Voir(c.ref, self)
        elseif LCM.IsMaster() then
            local familles = b.devise and { devises = true } or { objets = true, ressources = true, sacs = true }
            self.choix.titre:SetText(b.devise and "Devise" or "Entrée")
            self.choix:Proposer(b, Candidats(familles), function(ref)
                local ok, raison = Inv.Ranger(entity, self.onglet, self.index, b.index, ref, 1)
                if not ok then Refuser(raison) end
                Ecran.Actualiser()
            end)
        end
    end
    return s
end

function Ecran.OuvrirSac(onglet, index)
    local cle = onglet .. "_" .. index
    sacs[cle] = sacs[cle] or ConstruireSac(onglet, index)
    sacs[cle]:Show()
    sacs[cle]:Rafraichir()
    return sacs[cle]
end

function Ecran.FermerSac(onglet, index)
    local s = sacs[onglet .. "_" .. index]
    if s then s:Hide() end
end

function Ecran.RafraichirSacs()
    for _, s in pairs(sacs) do if s:IsShown() then s:Rafraichir() end end
end
Ecran.sacs = sacs

function Ecran.Actualiser()
    if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Rafraichir() else Ecran.RafraichirSacs() end
end

-- ===== Ouverture ==========================================================

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Show() end
end

LCM.WhenReady(function()
    UI.Menu.Lier("inventaires", Ecran.Basculer)
end)
