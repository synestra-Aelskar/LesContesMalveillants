-- Relecture MJ des narrations de contrôle mental.
-- Ce fichier vit volontairement dans le compagnon : un joueur ne peut ni
-- ouvrir le panneau, ni fabriquer localement une validation légitime.

local _, MJ = ...
local LCM = _G.LCM
if not LCM or not LCM.Influences then return end

local UI = LCM.UI
local file = {}
local fenetre

local function Construire()
    if fenetre then return fenetre end
    local f = UI.Fenetre("validation_mentale", "Contrôle mental", 510, 360, { x = 80, y = 20 })
    local c = f.contenu

    f.introduction = UI.Texte(c,
        "Relisez et corrigez l'instruction avant qu'elle ne soit présentée à la cible.", UI.C.discret)
    f.introduction:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -8)
    f.introduction:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -8)
    f.introduction:SetJustifyH("CENTER")

    f.lanceurTitre = UI.Texte(c, "Lanceur", UI.C.libelle, "GameFontNormalSmall")
    f.lanceurTitre:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -42)
    f.lanceur = UI.Texte(c, "", UI.C.texte)
    f.lanceur:SetPoint("TOPLEFT", c, "TOPLEFT", 118, -40)

    f.ciblesTitre = UI.Texte(c, "Cible(s)", UI.C.libelle, "GameFontNormalSmall")
    f.ciblesTitre:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -68)
    f.cibles = UI.Texte(c, "", UI.C.texte)
    f.cibles:SetPoint("TOPLEFT", c, "TOPLEFT", 118, -66)
    f.cibles:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -66)

    f.narrationTitre = UI.Texte(c, "Instruction transmise à la cible", UI.C.titreBloc)
    f.narrationTitre:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -102)
    f.narration = UI.Zone(c, 458, 118)
    f.narration:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -124)
    f.narration:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -124)

    local function Terminer(accepte)
        local courant = f.courant
        if not courant then return end
        f.courant = nil
        f:Hide()
        LCM.Influences.DeciderControleMental(courant.demande, courant.expediteur,
            accepte, f.narration:GetText())
        if #file > 0 then
            local suivant = table.remove(file, 1)
            f:Afficher(suivant.demande, suivant.expediteur)
        end
    end

    f.refuser = UI.Bouton(c, "Refuser", 130, 26, function() Terminer(false) end)
    f.refuser:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 12, 8)
    f.valider = UI.Bouton(c, "Valider et transmettre", 190, 26, function() Terminer(true) end)
    f.valider:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -12, 8)

    function f:Afficher(demande, expediteur)
        if self.courant then
            file[#file + 1] = { demande = demande, expediteur = expediteur }
            LCM.Info("Une validation de contrôle mental a été ajoutée à la file MJ.")
            return
        end
        self.courant = { demande = demande, expediteur = expediteur }
        self.lanceur:SetText(tostring(demande.rp or expediteur or "?"))
        self.cibles:SetText(tostring(demande.c or "?"))
        self.narration:SetText(tostring(demande.txt or ""))
        self:Show()
        UI.Devant(self)
    end

    -- Fermer la fenêtre équivaut à un refus explicite : le joueur récupère
    -- immédiatement son action au lieu d'attendre l'expiration de 2 minutes.
    f.fermer:SetScript("OnClick", function() Terminer(false) end)
    fenetre = f
    return f
end

LCM.Influences.onValidationControleMental = function(demande, expediteur)
    if not LCM.IsMaster() then return end
    Construire():Afficher(demande, expediteur)
end

MJ.ValidationMentale = { Fenetre = Construire }

