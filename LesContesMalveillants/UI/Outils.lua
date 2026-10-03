-- Les outils partages du MJ, vus par le joueur (Core/Outils.lua).
--
-- Une petite fenetre, sans le grand habillage : elle reste ouverte pendant la
-- scene a cote du jeu, et ses ornements d'angle mangeraient la moitie d'une
-- fenetre de cette taille. Les compteurs et les barres s'y lisent d'un coup
-- d'oeil ; une note s'ouvre au clic. Elle se montre a chaque nouveaute, et se
-- referme quand le MJ a tout retire.
--
-- Une annonce, elle, s'affiche en grand au milieu de l'ecran et s'efface.

local _, LCM = ...
local UI = LCM.UI

local Ecran = {}
UI.Outils = Ecran

local LARGEUR, LIGNE = 240, 22
local DUREE_ANNONCE = 6

local function Construire()
    local f = CreateFrame("Frame", "LCM_OutilsPartages", UIParent)
    f:SetSize(LARGEUR, 60)
    f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.fond = UI.Aplat(f, UI.C.fond)
    f.fond:SetAllPoints(f)
    if UI.AelCadre then UI.AelCadre(f, "section") else UI.Bordure(f) end
    Ecran.frame = f

    f.titre = UI.Texte(f, "", UI.C.titre, "GameFontNormalSmall")
    f.titre:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    f.fermer = UI.Bouton(f, "x", 16, 16, function() f:Hide() end)
    f.fermer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -5)
    f.lignes = {}

    function f:Ligne(rang)
        local l = self.lignes[rang]
        if l then return l end
        l = CreateFrame("Button", nil, self)
        l:SetHeight(LIGNE - 2)
        l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
        l.nom:SetPoint("LEFT", l, "LEFT", 0, 0)
        l.nom:SetJustifyH("LEFT")
        l.valeur = UI.Texte(l, "", UI.C.accent, "GameFontNormalSmall")
        l.valeur:SetPoint("RIGHT", l, "RIGHT", 0, 0)
        l.valeur:SetJustifyH("RIGHT")
        l.barre = UI.Barre(l, UI.C.accent, 110, 12)
        l.barre:SetPoint("RIGHT", l, "RIGHT", 0, 0)
        -- La note portee par la ligne au moment du clic : les lignes sont
        -- reutilisees d'un affichage a l'autre.
        l:SetScript("OnClick", function(self)
            if self.note then Ecran.Lire(self.note) end
        end)
        self.lignes[rang] = l
        return l
    end

    function f:Afficher()
        local recus = LCM.Outils.Recus()
        local mjs = {}
        local y = 26
        for rang, o in ipairs(recus) do
            mjs[o.mj] = true
            local l = self:Ligne(rang)
            l.note = o.sorte == "note" and o or nil
            l.nom:SetText(o.libelle)
            l.valeur:SetShown(o.sorte ~= "barre")
            l.barre:SetShown(o.sorte == "barre")
            if o.sorte == "barre" then
                l.barre:Regler(o.valeur, o.maximum)
            elseif o.sorte == "note" then
                l.valeur:SetText("Lire")
            else
                l.valeur:SetText(tostring(o.valeur or 0))
            end
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -y)
            l:SetPoint("TOPRIGHT", self, "TOPRIGHT", -10, -y)
            l:Show()
            y = y + LIGNE
        end
        for rang = #recus + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.nombre = #recus
        -- Le titre dit de qui ca vient : n'importe qui dans le groupe peut
        -- envoyer, et c'est en le montrant qu'on voit la triche.
        local noms = {}
        for mj in pairs(mjs) do noms[#noms + 1] = tostring(mj):match("^[^-]+") or tostring(mj) end
        table.sort(noms)
        self.titre:SetText("Outils de " .. (#noms > 0 and table.concat(noms, ", ") or "?"))
        self:SetHeight(y + 8)
    end
    f:Hide()
    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

-- Une note s'ouvre dans sa propre petite fenetre, le texte en entier.
function Ecran.Lire(note)
    if not Ecran.note then
        local n = UI.Fenetre("outil_note", "Note", 360, 300, { x = -200, y = 60 })
        n.texte = UI.Texte(n.contenu, "", UI.C.texte)
        UI.Police(n.texte, 12)
        n.texte:SetPoint("TOPLEFT", n.contenu, "TOPLEFT", 4, -4)
        n.texte:SetPoint("TOPRIGHT", n.contenu, "TOPRIGHT", -4, -4)
        n.texte:SetJustifyH("LEFT")
        n.texte:SetWordWrap(true)
        Ecran.note = n
    end
    local n = Ecran.note
    if n.titre then n.titre:SetText(UI.Majuscules and UI.Majuscules(note.libelle) or note.libelle) end
    n.texte:SetText(tostring(note.texte or ""))
    n.lue = note
    n:Show()
    return n
end

-- L'annonce : grande, au centre, et elle s'efface seule.
function Ecran.Annonce(expediteur, texte)
    if not Ecran.annonce then
        local a = CreateFrame("Frame", "LCM_Annonce", UIParent)
        a:SetSize(700, 80)
        a:SetPoint("TOP", UIParent, "TOP", 0, -180)
        a:SetFrameStrata("HIGH")
        a:EnableMouse(false)
        a.texte = UI.Texte(a, "", UI.C.titre)
        UI.Police(a.texte, 22)
        a.texte:SetAllPoints(a)
        a.texte:SetJustifyH("CENTER")
        a.texte:SetWordWrap(true)
        a.qui = UI.Texte(a, "", UI.C.discret)
        UI.Police(a.qui, 12)
        a.qui:SetPoint("TOP", a, "BOTTOM", 0, -2)
        a:SetScript("OnUpdate", function(self, ecoule)
            self.reste = (self.reste or 0) - (tonumber(ecoule) or 0)
            -- La derniere seconde, l'annonce s'estompe au lieu de disparaitre.
            self:SetAlpha(math.max(0, math.min(1, self.reste)))
            if self.reste <= 0 then self:Hide() end
        end)
        Ecran.annonce = a
    end
    local a = Ecran.annonce
    a.texte:SetText(texte)
    a.qui:SetText("— " .. (tostring(expediteur):match("^[^-]+") or tostring(expediteur)))
    a.reste = DUREE_ANNONCE
    a:SetAlpha(1)
    a:Show()
    return a
end

LCM.Outils.onChange = function()
    -- Le panneau du MJ (compagnon) s'accroche ici pour suivre SES outils.
    if LCM.Outils.onChangeMJ then LCM.Outils.onChangeMJ() end
    -- Chez le MJ, ses outils se lisent dans son panneau : la fenetre du joueur
    -- ne s'ouvre que pour ce qu'on RECOIT.
    local f = Ecran.Fenetre()
    local recus = LCM.Outils.Recus()
    if #recus == 0 then
        f:Hide()
        return
    end
    f:Afficher()
    f:Show()
    -- Une note lue qui change (ou disparait) se relit tout de suite.
    if Ecran.note and Ecran.note:IsShown() and Ecran.note.lue then
        local lue = LCM.Outils.recus[Ecran.note.lue.cle]
        if lue then Ecran.Lire(lue) else Ecran.note:Hide() end
    end
end

LCM.Outils.onAnnonce = function(expediteur, texte) Ecran.Annonce(expediteur, texte) end

LCM.AddCommand("outils", "montre les outils partages par le MJ", function()
    local f = Ecran.Fenetre()
    f:Afficher()
    f:Show()
end)
