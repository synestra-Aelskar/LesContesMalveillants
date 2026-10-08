-- Consultation unifiee d'un personnage depuis le panneau MJ.
--
-- Les fenetres restent celles de l'addon principal : on leur accole seulement
-- une tranche d'onglets, et l'on passe la meme entite distante de l'une a
-- l'autre. La copie recue est strictement en lecture seule.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local Consultation = {}
MJ.Consultation = Consultation
UI.ConsultationMJ = Consultation

Consultation.ONGLETS = {
    { id = "fiche", label = "Fiche" },
    { id = "sante", label = "Santé" },
    { id = "expertise", label = "Expertises" },
    { id = "penetrations_resistances", label = "Pénétration & Résistances" },
    { id = "apprentissage", label = "Apprentissage" },
    { id = "equipement", label = "Équipement" },
    { id = "bourse", label = "Bourse" },
}

local RADIAL = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\"
local TAILLE_ONGLET, ECART_ONGLETS = 42, 5
local ESPACEMENT_FEUILLE = 12
Consultation.ESPACEMENT_FEUILLE = ESPACEMENT_FEUILLE

local function IconePour(id)
    local entree = UI.Menu and UI.Menu.Trouver and UI.Menu.Trouver(id)
    return entree and entree.icone or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Fenetre(id)
    if id == "fiche" then return UI.Fiche.Fenetre() end
    if id == "bourse" then return UI.Bourse.Fenetre() end
    return UI.Vues.Fenetre(id)
end

local function ConstruireBarre()
    local barre = CreateFrame("Frame", nil, UIParent)
    Consultation.barre = barre
    barre.boutons = {}
    barre:SetWidth(TAILLE_ONGLET)
    local function CommencerDeplacement()
        local fenetre = Consultation.fenetre
        if fenetre then fenetre:StartMoving() end
    end
    local function FinirDeplacement()
        local fenetre = Consultation.fenetre
        if not fenetre then return end
        local finir = fenetre:GetScript("OnDragStop")
        if finir then finir(fenetre) else fenetre:StopMovingOrSizing() end
    end
    barre:EnableMouse(true)
    barre:RegisterForDrag("LeftButton")
    -- La tranche appartient visuellement a la feuille. On peut donc aussi
    -- saisir ses espaces pour deplacer l'ensemble, pas seulement le titre de
    -- la feuille.
    barre:SetScript("OnDragStart", CommencerDeplacement)
    barre:SetScript("OnDragStop", FinirDeplacement)

    local y = 0
    for rang, definition in ipairs(Consultation.ONGLETS) do
        local id = definition.id
        local bouton = UI.Bouton(barre, "", TAILLE_ONGLET, TAILLE_ONGLET, function()
            Consultation.Ouvrir(Consultation.entity, id)
        end)
        bouton.consultationId = id
        bouton.consultationLabel = definition.label
        bouton:SetPoint("TOPLEFT", barre, "TOPLEFT", 0, -y)
        bouton.label:Hide()

        -- Meme cadre et memes icones que le menu radial, en miniature.
        bouton.radialFond = bouton:CreateTexture(nil, "BACKGROUND")
        bouton.radialFond:SetTexture(RADIAL .. "button.tga")
        bouton.radialFond:SetPoint("CENTER", bouton, "CENTER")
        bouton.radialFond:SetSize(TAILLE_ONGLET * 64 / 48, TAILLE_ONGLET * 64 / 48)
        bouton.icone = bouton:CreateTexture(nil, "ARTWORK")
        bouton.icone:SetTexture(IconePour(id))
        bouton.icone:SetPoint("TOPLEFT", bouton, "TOPLEFT", 4, -4)
        bouton.icone:SetPoint("BOTTOMRIGHT", bouton, "BOTTOMRIGHT", -4, 4)
        if bouton.CreateMaskTexture and bouton.icone.AddMaskTexture then
            bouton.masque = bouton:CreateMaskTexture()
            bouton.masque:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            bouton.masque:SetAllPoints(bouton.icone)
            bouton.icone:AddMaskTexture(bouton.masque)
        end
        bouton.actifFond = UI.Aplat(bouton,
            { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.24 }, "OVERLAY")
        bouton.actifFond:SetPoint("TOPLEFT", bouton, "TOPLEFT", 2, -2)
        bouton.actifFond:SetPoint("BOTTOMRIGHT", bouton, "BOTTOMRIGHT", -2, 2)
        bouton.actifFond:Hide()
        bouton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.consultationLabel)
            GameTooltip:Show()
        end)
        bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        -- Les icones couvrent presque toute la tranche. Elles doivent donc
        -- elles aussi servir de poignee : un clic change d'onglet, un glisser
        -- deplace la feuille et toute sa barre.
        bouton:RegisterForDrag("LeftButton")
        bouton:SetScript("OnDragStart", CommencerDeplacement)
        bouton:SetScript("OnDragStop", FinirDeplacement)
        barre.boutons[rang] = bouton
        y = y + TAILLE_ONGLET + ECART_ONGLETS
    end
    barre:SetHeight(y - ECART_ONGLETS)
    barre:Hide()
    return barre
end

local function Selectionner(id)
    for _, bouton in ipairs(Consultation.barre.boutons) do
        local actif = bouton.consultationId == id
        bouton.__selectionne = actif
        bouton.actifFond:SetShown(actif)
        local intensite = actif and 1 or 0.42
        bouton.icone:SetVertexColor(intensite, intensite, intensite)
        if bouton.icone.SetDesaturated then bouton.icone:SetDesaturated(not actif) end
    end
end

-- La barre reste enfant logique de la feuille affichee : la deplacer entraine
-- donc immediatement les icones. Lors d'un changement d'onglet, on conserve
-- la position absolue de la barre, puis on rattache la nouvelle feuille.
local function Positionner(barre, fenetre, centreX, centreY)
    if centreX and centreY then
        local ux, uy = UIParent:GetCenter()
        local bordDroit = centreX - barre:GetWidth() / 2 - ESPACEMENT_FEUILLE
        fenetre:ClearAllPoints()
        fenetre:SetPoint("RIGHT", UIParent, "CENTER", bordDroit - ux, centreY - uy)
    end
    barre:ClearAllPoints()
    barre:SetPoint("LEFT", fenetre, "RIGHT", ESPACEMENT_FEUILLE, 0)
    Consultation.positionAncree = true
end

local function SuivreFermeture(fenetre)
    if fenetre.__consultationMJ then return end
    fenetre.__consultationMJ = true
    fenetre:HookScript("OnHide", function(self)
        if Consultation.fenetre == self and not Consultation.enBascule then
            Consultation.barre:Hide()
            Consultation.fenetre = nil
            Consultation.positionAncree = nil
        end
    end)
end

function Consultation.Ouvrir(entity, id)
    if not entity then return nil end
    id = id or Consultation.onglet or "fiche"
    local fenetre = Fenetre(id)
    if not fenetre then return nil end
    local barre = Consultation.barre or ConstruireBarre()
    local centreX, centreY
    if Consultation.positionAncree and barre:IsShown() then
        centreX, centreY = barre:GetCenter()
    end

    Consultation.enBascule = true
    if Consultation.fenetre and Consultation.fenetre ~= fenetre then
        Consultation.fenetre:Hide()
    end
    Consultation.entity = entity
    Consultation.onglet = id
    Consultation.fenetre = fenetre
    SuivreFermeture(fenetre)
    fenetre:Montrer(entity)
    Consultation.enBascule = false

    Positionner(barre, fenetre, centreX, centreY)
    Selectionner(id)
    barre:Show()
    return fenetre
end

function Consultation.Fermer()
    if Consultation.fenetre then Consultation.fenetre:Hide() end
    if Consultation.barre then Consultation.barre:Hide() end
    Consultation.fenetre = nil
    Consultation.positionAncree = nil
end
