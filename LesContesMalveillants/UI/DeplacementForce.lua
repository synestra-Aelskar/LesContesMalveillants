-- La jauge du deplacement force.
--
-- Mesures de Necronicon (`Deplacement.lua`) : fenetre de 260 de large, la jauge
-- en haut, le compteur dessous, la consigne sous le compteur, le bouton en bas.
--
-- Necronicon dessine un ANNEAU (un Cooldown retourne dont on fige le balayage)
-- et retombe sur une barre horizontale quand le Cooldown n'est pas disponible.
-- On prend sa barre : c'est son propre repli, pas une invention, et l'anneau
-- demande un gabarit qu'on n'a pas porte.
--
-- Fermer la fenetre interrompt la course, comme chez lui : une jauge qu'on
-- ferme et qui continuerait a compter dans le dos est pire que pas de jauge.

local _, LCM = ...
local UI = LCM.UI
local DF = LCM.DeplacementForce

local Ecran = {}
UI.DeplacementForce = Ecran

local LARGEUR, HAUTEUR = 260, 170

local function Construire()
    local f = UI.Fenetre("deplacement_force", "Déplacement forcé", LARGEUR, HAUTEUR, { x = 260, y = 60 })
    Ecran.frame = f

    f.raison = UI.Texte(f.contenu, "", UI.C.accent)
    UI.Police(f.raison, 12)
    f.raison:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.raison:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, 0)
    f.raison:SetJustifyH("CENTER")

    f.barre = UI.Barre(f.contenu, UI.C.accent, LARGEUR - 48, 16)
    f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -24)
    f.barre:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -24)
    UI.Police(f.barre.label, 12, "OUTLINE")

    f.compteur = UI.Texte(f.contenu, "", UI.C.titre)
    UI.Police(f.compteur, 16)
    f.compteur:SetPoint("TOP", f.barre, "BOTTOM", 0, -10)

    f.consigne = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.consigne, 11)
    f.consigne:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -82)
    f.consigne:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -82)
    f.consigne:SetJustifyH("CENTER")
    f.consigne:SetWordWrap(true)

    f.arreter = UI.Bouton(f.contenu, "Interrompre", 140, 22, function() f:Hide() end)
    f.arreter:SetPoint("BOTTOM", f.contenu, "BOTTOM", 0, 4)

    -- Fermer, c'est interrompre. On passe par Arreter pour que le module le
    -- sache, et le drapeau evite que Arreter -> Hide -> Arreter tourne en rond.
    f:SetScript("OnHide", function(self)
        if self.enFermeture then return end
        self.enFermeture = true
        if DF.EnCours() then DF.Arreter("interrompu") end
        self.enFermeture = nil
    end)

    function f:Actualiser()
        local distance, limite, enCours = DF.Etat()
        self.barre:Regler(math.min(distance, limite), limite > 0 and limite or 1)
        self.compteur:SetText(string.format("%.1f / %.1f m", distance, limite))
        local course = DF.EnCours()
        self.raison:SetText(course and course.raison or "")
        self.consigne:SetText(enCours
            and "Éloigne-toi de ton point de départ. La distance compte à vol d'oiseau : tourner en rond n'avance à rien."
            or "Terminé.")
        self.arreter:SetEnabled(enCours)
    end

    function f:Montrer()
        self:Actualiser()
        self:Show()
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

LCM.WhenReady(function()
    -- La fenetre s'ouvre toute seule quand une poussee commence : on ne demande
    -- pas a quelqu'un qu'on vient de repousser d'aller ouvrir un panneau.
    DF.onDemarrage = function()
        local f = Ecran.Fenetre()
        f:Montrer()
        if f.Raise then f:Raise() end
    end
    DF.onChange = function()
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Actualiser() end
    end
    DF.onFin = function(_, fini)
        if not Ecran.frame then return end
        Ecran.frame:Actualiser()
        -- Course finie : la fenetre se retire d'elle-meme. Interrompue, c'est
        -- qu'on vient de la fermer.
        if fini then Ecran.frame:Hide() end
    end
end)

-- De quoi la regarder sans se faire pousser, et verifier qu'elle va bien.
LCM.AddCommand("pousse", "essaie la jauge de deplacement force", function(argument)
    local metres = tonumber(tostring(argument or ""):match("%d+%.?%d*")) or 6
    local ok, raison = DF.Demarrer(metres, "Essai")
    if not ok then LCM.Alerte(tostring(raison)) end
end)
