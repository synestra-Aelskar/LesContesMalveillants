-- Bandeau affiche lorsqu'un personnage RECOIT de l'experience du MJ.
-- Il ne depend d'aucune fenetre ouverte et disparait apres quatre secondes.

local _, LCM = ...
local UI = LCM.UI

local Ecran = {}
UI.Experience = Ecran

local DUREE = 4
local LARGEUR, HAUTEUR = 720, 132

local function Construire()
    local f = CreateFrame("Frame", "LCM_GainExperience", UIParent)
    f:SetSize(LARGEUR, HAUTEUR)
    f:SetPoint("TOP", UIParent, "TOP", 0, -145)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(false)

    -- Degrade brun-noir sans texture externe : des bandes non superposees
    -- s'intensifient vers le centre. Cela conserve la transparence en jeu,
    -- contrairement a certains SetGradient du client Epsilon.
    local bandes = 24
    local largeurBande = LARGEUR / bandes
    f.fond = {}
    for index = 1, bandes do
        local distance = math.abs((index - 0.5) - bandes / 2) / (bandes / 2)
        local force = math.max(0, 1 - distance)
        local fond = UI.Aplat(f, { 0.075, 0.052, 0.031, 0.10 + force * 0.72 }, "BACKGROUND")
        fond:SetPoint("TOPLEFT", f, "TOPLEFT", (index - 1) * largeurBande, 0)
        fond:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", (index - 1) * largeurBande, 0)
        fond:SetWidth(largeurBande + 1)
        f.fond[index] = fond

        local alphaFilet = 0.08 + force * 0.70
        local haut = UI.Aplat(f, { 0.78, 0.57, 0.24, alphaFilet }, "ARTWORK")
        haut:SetPoint("TOPLEFT", f, "TOPLEFT", (index - 1) * largeurBande, -5)
        haut:SetSize(largeurBande + 1, 1)
        local bas = UI.Aplat(f, { 0.46, 0.30, 0.12, alphaFilet * 0.75 }, "ARTWORK")
        bas:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", (index - 1) * largeurBande, 5)
        bas:SetSize(largeurBande + 1, 1)
    end

    f.titre = UI.Texte(f, "GAIN D'EXPÉRIENCE !", UI.C.titre)
    UI.Police(f.titre, 22, "OUTLINE")
    f.titre:SetPoint("TOP", f, "TOP", 0, -19)
    f.titre:SetWidth(LARGEUR - 80)
    f.titre:SetJustifyH("CENTER")

    f.gain = UI.Texte(f, "", UI.C.texte)
    UI.Police(f.gain, 17)
    f.gain:SetPoint("TOP", f.titre, "BOTTOM", 0, -12)
    f.gain:SetWidth(LARGEUR - 100)
    f.gain:SetJustifyH("CENTER")

    f.motif = UI.Texte(f, "", UI.C.discret)
    UI.Police(f.motif, 13)
    f.motif:SetPoint("TOP", f.gain, "BOTTOM", 0, -9)
    f.motif:SetWidth(LARGEUR - 110)
    f.motif:SetJustifyH("CENTER")
    f.motif:SetWordWrap(true)

    -- Un second bandeau, plus court, accompagne uniquement le franchissement
    -- d'un palier. Il reste separe du gain d'XP : les deux informations se
    -- lisent d'un coup sans agrandir artificiellement le premier cadre.
    f.niveau = CreateFrame("Frame", nil, f)
    f.niveau:SetSize(560, 72)
    f.niveau:SetPoint("TOP", f, "BOTTOM", 0, -6)
    f.niveau.fond = {}
    local bandesNiveau = 18
    local largeurNiveau = 560 / bandesNiveau
    for index = 1, bandesNiveau do
        local distance = math.abs((index - 0.5) - bandesNiveau / 2) / (bandesNiveau / 2)
        local force = math.max(0, 1 - distance)
        local fond = UI.Aplat(f.niveau,
            { 0.075, 0.052, 0.031, 0.10 + force * 0.72 }, "BACKGROUND")
        fond:SetPoint("TOPLEFT", f.niveau, "TOPLEFT", (index - 1) * largeurNiveau, 0)
        fond:SetPoint("BOTTOMLEFT", f.niveau, "BOTTOMLEFT", (index - 1) * largeurNiveau, 0)
        fond:SetWidth(largeurNiveau + 1)
        f.niveau.fond[index] = fond
    end
    f.niveau.haut = UI.Aplat(f.niveau, { 0.78, 0.57, 0.24, 0.72 }, "ARTWORK")
    f.niveau.haut:SetPoint("TOPLEFT", f.niveau, "TOPLEFT", 34, -3)
    f.niveau.haut:SetPoint("TOPRIGHT", f.niveau, "TOPRIGHT", -34, -3)
    f.niveau.haut:SetHeight(1)
    f.niveau.titre = UI.Texte(f.niveau, "", UI.C.titre)
    UI.Police(f.niveau.titre, 17, "OUTLINE")
    f.niveau.titre:SetPoint("TOP", f.niveau, "TOP", 0, -13)
    f.niveau.titre:SetWidth(520)
    f.niveau.titre:SetJustifyH("CENTER")
    f.niveau.felicitations = UI.Texte(f.niveau, "Félicitation !", UI.C.texte)
    UI.Police(f.niveau.felicitations, 13)
    f.niveau.felicitations:SetPoint("TOP", f.niveau.titre, "BOTTOM", 0, -8)
    f.niveau:Hide()

    f:SetScript("OnUpdate", function(self, ecoule)
        self.reste = (self.reste or 0) - (tonumber(ecoule) or 0)
        -- Trois secondes de lecture, puis une seconde de fondu.
        self:SetAlpha(math.max(0, math.min(1, self.reste)))
        if self.reste <= 0 then self:Hide() end
    end)
    f:Hide()
    Ecran.frame = f
    return f
end

local function EffetNiveau(monte)
    if not monte or type(SendChatMessage) ~= "function" then return false end
    -- Commande Epsilon : le sort remplace entierement la musique de niveau.
    return pcall(SendChatMessage, ".cast 194901", "SAY") and true or false
end

function Ecran.Afficher(montant, motif, resultat)
    local f = Ecran.frame or Construire()
    montant = math.max(0, math.floor(tonumber(montant) or 0))
    motif = tostring(motif or ""):gsub("^%s+", ""):gsub("%s+$", "")
    f.gain:SetText(string.format("Vous gagnez %d expérience", montant))
    f.motif:SetText("Motif : " .. (motif ~= "" and motif or "Non précisé"))
    f.reste = DUREE
    f:SetAlpha(1)
    f:Show()
    local monte = type(resultat) == "table" and resultat.monte or resultat == true
    if monte then
        local avant = type(resultat) == "table" and tonumber(resultat.avant) or nil
        local apres = type(resultat) == "table" and tonumber(resultat.apres) or nil
        if avant and apres then
            f.niveau.titre:SetText(string.format("GAIN DE NIVEAU : %d > %d", avant, apres))
        else
            f.niveau.titre:SetText("GAIN DE NIVEAU !")
        end
        f.niveau:Show()
    else
        f.niveau:Hide()
    end
    EffetNiveau(monte)
    return f
end

LCM.WhenReady(function()
    local avant = LCM.Experience.onReception
    LCM.Experience.onReception = function(_, montant, motif, expediteur, resultat)
        if avant then avant(_, montant, motif, expediteur, resultat) end
        Ecran.Afficher(montant, motif, resultat)
    end
end)

-- Bandeau de regain : meme langage visuel que l'experience, sans icone.
local RegainEcran = {}
UI.Regain = RegainEcran

local function ConstruireRegain()
    local f = CreateFrame("Frame", "LCM_Regain", UIParent)
    f:SetSize(LARGEUR, 112)
    f:SetPoint("TOP", UIParent, "TOP", 0, -145)
    f:SetFrameStrata("HIGH")
    f:EnableMouse(false)
    f.fond = {}
    local bandes = 24
    local largeurBande = LARGEUR / bandes
    for index = 1, bandes do
        local distance = math.abs((index - 0.5) - bandes / 2) / (bandes / 2)
        local force = math.max(0, 1 - distance)
        local fond = UI.Aplat(f, { 0.075, 0.052, 0.031, 0.10 + force * 0.72 }, "BACKGROUND")
        fond:SetPoint("TOPLEFT", f, "TOPLEFT", (index - 1) * largeurBande, 0)
        fond:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", (index - 1) * largeurBande, 0)
        fond:SetWidth(largeurBande + 1)
        f.fond[index] = fond
    end
    f.haut = UI.Aplat(f, { 0.78, 0.57, 0.24, 0.72 }, "ARTWORK")
    f.haut:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -5)
    f.haut:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -5)
    f.haut:SetHeight(1)
    f.bas = UI.Aplat(f, { 0.46, 0.30, 0.12, 0.55 }, "ARTWORK")
    f.bas:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 5)
    f.bas:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 5)
    f.bas:SetHeight(1)

    f.titre = UI.Texte(f, "REGAIN", UI.C.titre)
    UI.Police(f.titre, 22, "OUTLINE")
    f.titre:SetPoint("TOP", f, "TOP", 0, -19)
    f.titre:SetWidth(LARGEUR - 80)
    f.titre:SetJustifyH("CENTER")
    f.texte = UI.Texte(f, "", UI.C.texte)
    UI.Police(f.texte, 15)
    f.texte:SetPoint("TOP", f.titre, "BOTTOM", 0, -13)
    f.texte:SetWidth(LARGEUR - 90)
    f.texte:SetJustifyH("CENTER")
    f.texte:SetWordWrap(true)
    f:SetScript("OnUpdate", function(self, ecoule)
        self.reste = (self.reste or 0) - (tonumber(ecoule) or 0)
        self:SetAlpha(math.max(0, math.min(1, self.reste)))
        if self.reste <= 0 then self:Hide() end
    end)
    f:Hide()
    RegainEcran.frame = f
    return f
end

function RegainEcran.Afficher(resultat)
    local f = RegainEcran.frame or ConstruireRegain()
    f.texte:SetText(LCM.Regain.Texte(resultat))
    f.reste = DUREE
    f:SetAlpha(1)
    f:Show()
    return f
end

LCM.WhenReady(function()
    local avant = LCM.Regain.onReception
    LCM.Regain.onReception = function(entity, resultat, expediteur)
        if avant then avant(entity, resultat, expediteur) end
        RegainEcran.Afficher(resultat)
    end
end)
