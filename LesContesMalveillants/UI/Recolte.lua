-- Le bouton « Recolter » : il apparait quand on se tient sur un point de
-- recolte (Core/Recolte.lua) et disparait quand on s'en eloigne. Rien n'est
-- visible avant : le filon se trouve en marchant dessus.

local _, LCM = ...
local UI = LCM.UI

local Ecran = {}
UI.Recolte = Ecran

local function Construire()
    local b = CreateFrame("Button", "LCM_BoutonRecolte", UIParent)
    b:SetSize(260, 44)
    b:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
    b:SetFrameStrata("HIGH")
    b.fond = UI.Aplat(b, UI.C.fond, "BACKGROUND")
    b.fond:SetAllPoints(b)
    UI.Bordure(b)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetSize(34, 34)
    b.icone:SetPoint("LEFT", b, "LEFT", 5, 0)
    b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.titre = UI.Texte(b, "Récolter", UI.C.titre)
    UI.Police(b.titre, 13)
    b.titre:SetPoint("TOPLEFT", b.icone, "TOPRIGHT", 8, -2)
    b.nom = UI.Texte(b, "", UI.C.texte)
    UI.Police(b.nom, 11)
    b.nom:SetPoint("BOTTOMLEFT", b.icone, "BOTTOMRIGHT", 8, 2)
    b.nom:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    b.nom:SetJustifyH("LEFT")
    b.nom:SetWordWrap(false)
    b.survol = UI.Aplat(b, UI.C.survol, "HIGHLIGHT")
    b.survol:SetAllPoints(b)
    b:SetScript("OnClick", function(self)
        local ok, raison = LCM.Recolte.Tenter(self.pointId)
        if not ok and raison then LCM.Alerte(tostring(raison)) end
    end)
    b:Hide()
    Ecran.bouton = b
    return b
end

function Ecran.Actualiser(point)
    local b = Ecran.bouton or Construire()
    local definition = point and LCM.Recolte.definitions[point.def]
    if not definition then
        b.pointId = nil
        b:Hide()
        return
    end
    b.pointId = point.id
    local ressource = LCM.Compendium and LCM.Compendium.Resoudre
        and LCM.Compendium.Resoudre(definition.entree)
    b.icone:SetTexture((ressource and ressource.icone) or "Interface\\ICONS\\INV_Misc_QuestionMark")
    b.nom:SetText(definition.label)
    b:Show()
end

LCM.Recolte.onProche = function(point) Ecran.Actualiser(point) end
