-- La bourse.
--
-- Une ligne par devise declaree, meme a zero : savoir qu'une monnaie existe et
-- qu'on n'en a pas est une information. Le MJ ajuste les soldes ici ; le joueur
-- lit.

local _, LCM = ...
local UI = LCM.UI
local Bourse = LCM.Bourse

local Ecran = {}
UI.Bourse = Ecran

local LARGEUR, HAUTEUR = 420, 360
local LIGNE = 34

local function Construire()
    local f = UI.Fenetre("bourse", "Bourse", LARGEUR, HAUTEUR, { x = -120, y = -60 })
    Ecran.frame = f
    f.nom = f.sousTitre

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.lignes = {}

    f.vide = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("CENTER", f.zone, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")

    function f:Afficher()
        local entity = self.entity
        local devises = Bourse.Liste(entity)
        local mj = LCM.IsMaster()
        local y = 0

        for rang, devise in ipairs(devises) do
            local l = self.lignes[rang]
            if not l then
                l = CreateFrame("Frame", nil, self.zone.contenu)
                l:SetHeight(LIGNE - 2)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.icone = l:CreateTexture(nil, "ARTWORK")
                l.icone:SetSize(24, 24)
                l.icone:SetPoint("LEFT", l, "LEFT", 6, 0)
                l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                l.nom = UI.Texte(l, "", UI.C.texte)
                UI.Police(l.nom, 12)
                l.nom:SetPoint("LEFT", l.icone, "RIGHT", 8, 0)
                l.solde = UI.Texte(l, "", UI.C.titre)
                UI.Police(l.solde, 13)
                l.solde:SetJustifyH("RIGHT")

                -- Le MJ donne et retire ; le joueur ne touche a rien.
                l.plus = UI.Bouton(l, "+", 18, 18, function()
                    local ligne = self.lignes[rang]
                    local ok, raison = Bourse.Crediter(self.entity, ligne.deviseId, self.pas)
                    if not ok then LCM.Alerte(tostring(raison)) end
                    self:Afficher()
                end)
                l.plus:SetPoint("RIGHT", l, "RIGHT", -6, 0)
                l.moins = UI.Bouton(l, "-", 18, 18, function()
                    local ligne = self.lignes[rang]
                    local ok, raison = Bourse.Debiter(self.entity, ligne.deviseId, self.pas)
                    if not ok then LCM.Alerte(tostring(raison)) end
                    self:Afficher()
                end)
                l.moins:SetPoint("RIGHT", l.plus, "LEFT", -4, 0)
                self.lignes[rang] = l
            end
            l.deviseId = devise.id
            l.icone:SetTexture(devise.icone or "Interface\\ICONS\\INV_Misc_Coin_02")
            l.nom:SetText(devise.label)
            l.solde:SetText(tostring(devise.solde))
            -- Un solde a zero s'efface : l'oeil va a ce qu'on a.
            local couleur = devise.solde > 0 and UI.C.titre or UI.C.discret
            l.solde:SetTextColor(couleur[1], couleur[2], couleur[3])
            l.solde:ClearAllPoints()
            l.solde:SetPoint("RIGHT", l, "RIGHT", mj and -52 or -8, 0)
            l.plus:SetShown(mj)
            l.moins:SetShown(mj)

            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE
        end
        for rang = #devises + 1, #self.lignes do self.lignes[rang]:Hide() end

        self.zone:Regler(y)
        self.nombreAffiche = #devises
        self.vide:SetText(#devises > 0 and "" or "Aucune devise déclarée.")
    end

    -- De combien vont le + et le - du MJ. Maj : par dix, Ctrl : par cent.
    function f:Pas()
        if IsControlKeyDown and IsControlKeyDown() then return 100 end
        if IsShiftKeyDown and IsShiftKeyDown() then return 10 end
        return 1
    end

    function f:Montrer(entity)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self.pas = 1
        self:SousTitre(self.entity.name or self.entity.id)
        self:Afficher()
        self:Show()
    end

    -- Le pas se relit a chaque clic : on ne garde pas une touche enfoncee en
    -- memoire d'une ouverture a l'autre.
    f:HookScript("OnShow", function(self) self.pas = 1 end)
    f:SetScript("OnMouseDown", function(self)
        UI.Devant(self)
        self.pas = self:Pas()
    end)

    -- Le personnage change (equipement, sac, trait...) : la fenetre suit.
    UI.SuivrePersonnage(f, function(self) self:Afficher() end)
    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.AddCommand("bourse", "ouvre ta bourse", function() Ecran.Basculer() end)

LCM.WhenReady(function()
    UI.Menu.Lier("bourse", Ecran.Basculer)
end)
