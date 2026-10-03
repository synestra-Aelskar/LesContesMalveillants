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

local NOMS_MODE = { terrestre = "Terrestre", nage = "Nage", vol = "Vol" }

local Ecran = {}
UI.DeplacementForce = Ecran

local LARGEUR, HAUTEUR = 280, 300
local MODES = { { id = "terrestre", label = "Terrestre" },
                { id = "nage",      label = "Nage" },
                { id = "vol",       label = "Vol" } }

local function Construire()
    local f = UI.Fenetre("deplacement_force", "Déplacement", LARGEUR, HAUTEUR, { x = 260, y = 60 })
    -- Le contenu : 256 de large (LARGEUR moins les deux marges de 12).
    local DEDANS = LARGEUR - 24
    Ecran.frame = f

    f.raison = UI.Texte(f.contenu, "", UI.C.accent)
    UI.Police(f.raison, 12)
    f.raison:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -26)
    f.raison:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -26)
    f.raison:SetJustifyH("CENTER")

    f.barre = UI.Barre(f.contenu, UI.C.accent, DEDANS, 16)
    f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -46)
    f.barre:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -46)
    UI.Police(f.barre.label, 12, "OUTLINE")

    f.compteur = UI.Texte(f.contenu, "", UI.C.titre)
    UI.Police(f.compteur, 16)
    f.compteur:SetPoint("TOP", f.barre, "BOTTOM", 0, -8)

    f.consigne = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.consigne, 11)
    f.consigne:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -130)
    f.consigne:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -130)
    f.consigne:SetJustifyH("CENTER")
    f.consigne:SetWordWrap(true)

    -- Les trois modes, comme dans Necronicon : on choisit avant de partir, et
    -- la fiche donne la distance. Pendant une course, on ne change plus.
    f.modes = {}
    for index, mode in ipairs(MODES) do
        local b = UI.Bouton(f.contenu, mode.label, 80, 20, function()
            if DF.EnCours() then return end
            f.mode = mode.id
            f:Actualiser()
        end)
        b.modeId = mode.id
        b:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", (index - 1) * 86, 0)
        f.modes[index] = b
    end
    f.mode = "terrestre"

    f.partir = UI.Bouton(f.contenu, "Se déplacer", 180, 22, function()
        if DF.EnCours() then DF.Arreter("interrompu") return end
        local ok, raison = DF.DemarrerMode(f.mode)
        if not ok then LCM.Alerte(tostring(raison)) end
    end)
    f.partir:SetPoint("BOTTOM", f.contenu, "BOTTOM", 0, 30)

    -- Le compte du round, et la regle en toutes lettres : « 1 / 2 ce round »
    -- ne dit pas ce qu'on paie, et c'est ce qu'on veut savoir avant de partir.
    f.round = UI.Texte(f.contenu, "", UI.C.accent)
    UI.Police(f.round, 11)
    f.round:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -96)
    f.round:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -96)
    f.round:SetJustifyH("CENTER")
    f.round:SetWordWrap(true)

    f.nouveauRound = UI.Bouton(f.contenu, "Nouveau round", 110, 22, function()
        DF.NouveauRound()
        f:Actualiser()
    end)
    f.nouveauRound:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 4)

    f.arreter = UI.Bouton(f.contenu, "Interrompre", 120, 22, function() f:Hide() end)
    f.arreter:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 4)

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
        -- Hors course, la jauge montre ce que la fiche autorise dans le mode
        -- choisi : on voit son allocation avant de partir, pas seulement en
        -- marchant.
        if not enCours then limite = DF.Allocation(nil, self.mode) end
        for _, b in ipairs(self.modes) do
            b:Selectionner(b.modeId == self.mode)
            b:SetEnabled(not enCours)
        end
        -- Le bouton dit ce que le prochain depart coutera.
        local prochain = DF.Prochain()
        if enCours then
            self.partir.label:SetText("Arrêter")
        elseif prochain == "gratuit" then
            self.partir.label:SetText("Se déplacer (gratuit)")
        elseif prochain == "payant" then
            self.partir.label:SetText("Se déplacer (1 PA + 1 PF)")
        else
            self.partir.label:SetText("Plus de déplacement")
        end
        self.partir:SetEnabled(enCours or prochain ~= "fini")
        local regle = LCM.Equilibrage.deplacement
        self.round:SetText(string.format(
            "Déplacement %d / %d ce round\n1 gratuit par round, puis 1 supplémentaire à %d PA + %d PF.",
            DF.Mouvements(), DF.MaxParRound(), regle.supplementPA or 1, regle.supplementPF or 1))
        for _, b in ipairs(self.modes) do
            -- Un mode que la fiche ne permet pas (le vol, le plus souvent) reste
            -- visible mais eteint : le menu ne ment pas sur ce qui existe.
            b:SetEnabled(not enCours and DF.Allocation(nil, b.modeId) > 0)
        end
        self.barre:Regler(math.min(distance, limite), limite > 0 and limite or 1)
        self.compteur:SetText(string.format("%.1f / %.1f m", distance, limite))
        self.raison:SetText(DF.EnCours() and DF.EnCours().raison or NOMS_MODE[self.mode] or "")
        local course = DF.EnCours()
        if enCours and course and course.cumule then
            self.consigne:SetText("Chaque mètre parcouru compte, même en revenant sur tes pas.")
        elseif enCours then
            self.consigne:SetText("Éloigne-toi de ton point de départ : la distance compte à vol d'oiseau.")
        else
            self.consigne:SetText("Choisis un mode, puis « Se déplacer ».")
        end
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
LCM.WhenReady(function()
    -- L'entree « Deplacement » du menu ouvre la jauge : c'est elle qui montre
    -- l'allocation de la fiche ET la decompte pendant qu'on marche. Avant,
    -- elle ouvrait une vue qui ne faisait que lire les deux nombres.
    UI.Menu.Lier("deplacement", function()
        local f = Ecran.Fenetre()
        if f:IsShown() then f:Hide() else f:Montrer() end
    end)
end)

LCM.AddCommand("deplacer", "ouvre la jauge de deplacement", function()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
end)

LCM.AddCommand("pousse", "essaie la jauge de deplacement force", function(argument)
    local metres = tonumber(tostring(argument or ""):match("%d+%.?%d*")) or 6
    local ok, raison = DF.Demarrer(metres, "Essai")
    if not ok then LCM.Alerte(tostring(raison)) end
end)
