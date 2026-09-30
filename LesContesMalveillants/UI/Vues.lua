-- Les fenetres tirees de la fiche (declarees dans Data/Vues.lua) : la Fiche
-- elle-meme, Sante, Expertises, Penetration & Resistances...
--
-- Une fenetre par vue, construite au premier clic et gardee ensuite. Une vue a
-- plusieurs onglets recoit la bande d'onglets du modele ; chaque onglet est une
-- page (UI.Fiche.Page) dans une zone qui defile et rogne.
--
-- Elle montre le personnage joue, relu a chaque ouverture : changer de
-- personnage puis rouvrir ne laisse pas l'ancien a l'ecran.

local _, LCM = ...
local UI = LCM.UI

local Ecran = { frames = {} }
UI.Vues = Ecran

-- Decalage de la premiere ouverture, pour que deux vues ne naissent pas l'une
-- sur l'autre (la position est ensuite retenue par fenetre).
local DECALAGE = 28

local function Construire(vue, rang)
    local f = UI.Fenetre("vue_" .. vue.id, vue.titre, vue.largeur, vue.hauteur,
        { x = 180 + rang * DECALAGE, y = -rang * DECALAGE })
    f.vue = vue
    f.nom = f.sousTitre
    local largeurContenu = vue.largeur - 24

    local haut = 0
    if #vue.onglets > 1 then
        local onglets = {}
        for _, onglet in ipairs(vue.onglets) do onglets[#onglets + 1] = { id = onglet.id, label = onglet.label } end
        f.barre = UI.BandeauOnglets(f.contenu, onglets, function(id) f:Afficher(id) end)
        f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
        f.barre:SetWidth(largeurContenu)
        haut = f.barre:Disposer(largeurContenu, f.mesures.onglet) + 10
    end

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -haut)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.pages = {}
    for _, onglet in ipairs(vue.onglets) do
        local page = UI.Fiche.Page(f.zone.contenu, onglet.sections, largeurContenu)
        page.onHauteur = function(h) if page:IsShown() then f.zone:Regler(h) end end
        f.pages[onglet.id] = page
    end
    -- Une vue simple : sa page unique, sous le nom qu'on lui a toujours donne.
    f.page = f.pages[vue.onglets[1].id]

    function f:Afficher(ongletId)
        self.onglet = ongletId
        if self.barre then self.barre:Selectionner(ongletId) end
        for id, page in pairs(self.pages) do page:SetShown(id == ongletId) end
        local page = self.pages[ongletId]
        if page then
            if self.entity then page:Actualiser(self.entity) end
            self.zone.decalage = 0
            self.zone:Regler(page.hauteur)
        end
    end

    function f:Montrer(entity)
        if vue.sansPersonnage then
            self:Afficher(self.onglet or vue.onglets[1].id)
            self:Show()
            return
        end
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self:SousTitre(self.entity.name or self.entity.id)
        self:Afficher(self.onglet or vue.onglets[1].id)
        self:Show()
    end

    function f:Actualiser()
        local page = self.onglet and self.pages[self.onglet]
        if self.entity and page then page:Actualiser(self.entity) end
    end
    return f
end

function Ecran.Fenetre(id)
    local vue = LCM.Vues.Get(id)
    if not vue then return nil end
    if not Ecran.frames[vue.id] then
        local rang = 0
        for index, v in ipairs(LCM.Vues.list) do
            if v.id == vue.id then rang = index - 1 end
        end
        Ecran.frames[vue.id] = Construire(vue, rang)
    end
    return Ecran.frames[vue.id]
end

function Ecran.Basculer(id)
    local f = Ecran.Fenetre(id)
    if not f then return nil end
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

-- Chaque vue allume l'entree du menu du meme nom. Une vue sans entree est une
-- faute d'ecriture : Menu.Lier la signale.
LCM.WhenReady(function()
    for _, vue in ipairs(LCM.Vues.list) do
        local id = vue.id
        UI.Menu.Lier(id, function() Ecran.Basculer(id) end)
    end
end)
