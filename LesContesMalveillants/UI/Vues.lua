-- Les fenetres du menu tirees de la fiche (declarees dans Data/Vues.lua).
--
-- Une fenetre par vue, construite au premier clic et gardee ensuite. Elle
-- dessine ses sections avec les lignes de la fiche (UI.Fiche.Page) dans une
-- zone qui defile : l'onglet Expertises, a lui seul, est plus haut qu'un ecran
-- de portable.
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

    f.nom = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    f.nom:SetPoint("TOPLEFT", f.titre, "BOTTOMLEFT", 0, -4)

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -18)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.page = UI.Fiche.Page(f.zone.contenu, vue.sections)
    f.page:Show()
    f.zone:Regler(f.page.hauteur)

    function f:Montrer(entity)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self.nom:SetText(tostring(self.entity.name or self.entity.id))
        self.page:Actualiser(self.entity)
        self:Show()
    end

    function f:Actualiser()
        if self.entity then self.page:Actualiser(self.entity) end
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
-- faute d'ecriture : Radial.Lier la signale.
LCM.WhenReady(function()
    for _, vue in ipairs(LCM.Vues.list) do
        local id = vue.id
        UI.Radial.Lier(id, function() Ecran.Basculer(id) end)
    end
end)
