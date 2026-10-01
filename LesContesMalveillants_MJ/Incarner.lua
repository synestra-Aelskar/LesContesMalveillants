-- Incarner : la fenetre du maitre du jeu.
--
-- A gauche le catalogue des PNJ, a droite ceux qui sont en jeu. Prendre un PNJ
-- du catalogue en cree une INSTANCE : trois gardes du meme modele peuvent se
-- faire tailler en pieces chacun de son cote.
--
-- Un bandeau en haut dit toujours qui l'on est. C'est la panne qu'on veut
-- eviter : jouer une heure en croyant etre soi alors qu'on est encore le garde.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local Ecran = {}
UI.Incarner = Ecran
MJ.Incarner = Ecran

local LARGEUR, HAUTEUR = 640, 480
local COLONNE = 300
local LIGNE = 26

local function Construire()
    local f = UI.Fenetre("incarner", "Incarner", LARGEUR, HAUTEUR, { x = 80, y = -20 })
    Ecran.frame = f

    f.bandeau = UI.Texte(f.contenu, "", UI.C.accent)
    UI.Police(f.bandeau, 12)
    f.bandeau:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)

    f.relacher = UI.Bouton(f.contenu, "Reprendre ma place", 150, 22, function()
        if LCM.Incarnation.Relacher() then
            LCM.Ok("tu reprends ta place.")
        end
        f:Afficher()
    end)
    f.relacher:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, 2)

    -- ----- le catalogue ---------------------------------------------------
    f.titreCatalogue = UI.Texte(f.contenu, "Catalogue", UI.C.titre)
    UI.Police(f.titreCatalogue, 11)
    f.titreCatalogue:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -28)

    f.catalogue = UI.Defilement(f.contenu)
    f.catalogue:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -46)
    f.catalogue:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.catalogue:SetWidth(COLONNE)
    f.modeles = {}

    -- ----- les instances --------------------------------------------------
    f.titreJeu = UI.Texte(f.contenu, "En jeu", UI.C.titre)
    UI.Police(f.titreJeu, 11)
    f.titreJeu:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 16, -28)

    f.jeu = UI.Defilement(f.contenu)
    f.jeu:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 16, -46)
    f.jeu:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.instances = {}

    f.vide = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("CENTER", f.jeu, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")

    local function Rangee(parent, largeur)
        local l = CreateFrame("Frame", nil, parent)
        l:SetHeight(LIGNE - 2)
        if UI.SurfaceLigne then UI.SurfaceLigne(l) end
        l.icone = l:CreateTexture(nil, "ARTWORK")
        l.icone:SetSize(18, 18)
        l.icone:SetPoint("LEFT", l, "LEFT", 4, 0)
        l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        l.nom = UI.Texte(l, "", UI.C.texte)
        UI.Police(l.nom, 11)
        l.nom:SetPoint("LEFT", l.icone, "RIGHT", 6, 0)
        return l
    end

    function f:Afficher()
        local actuelle = LCM.Incarnation.Actuelle()
        self.bandeau:SetText(actuelle
            and string.format("Tu incarnes |cffffd36b%s|r.", tostring(actuelle.name))
            or "Tu es toi-même.")
        self.relacher:SetShown(actuelle ~= nil)

        -- Catalogue
        local y = 0
        for rang, modele in ipairs(LCM.PNJ.list) do
            local l = self.modeles[rang]
            if not l then
                l = Rangee(self.catalogue.contenu)
                l.prendre = UI.Bouton(l, "Incarner", 80, 18, function()
                    local pnjId = self.modeles[rang].pnjId
                    local instance, raison = LCM.Incarnation.Incarner(pnjId)
                    if not instance then LCM.Alerte(tostring(raison)) return end
                    LCM.Ok(string.format("tu incarnes %s.", tostring(instance.name)))
                    self:Afficher()
                end)
                l.prendre:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                self.modeles[rang] = l
            end
            l.pnjId = modele.id
            l.icone:SetTexture(modele.icone or "Interface\\ICONS\\INV_Misc_QuestionMark")
            l.nom:SetText(modele.label)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.catalogue.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.catalogue.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE
        end
        for rang = #LCM.PNJ.list + 1, #self.modeles do self.modeles[rang]:Hide() end
        self.catalogue:Regler(y)

        -- En jeu
        local liste = LCM.Incarnation.Liste()
        y = 0
        for rang, instance in ipairs(liste) do
            local l = self.instances[rang]
            if not l then
                l = Rangee(self.jeu.contenu)
                l.prendre = UI.Bouton(l, "Prendre", 70, 18, function()
                    local id = self.instances[rang].instanceId
                    local prise, raison = LCM.Incarnation.Prendre(id)
                    if not prise then LCM.Alerte(tostring(raison)) return end
                    LCM.Ok(string.format("tu incarnes %s.", tostring(prise.name)))
                    self:Afficher()
                end)
                l.prendre:SetPoint("RIGHT", l, "RIGHT", -26, 0)
                l.oublier = UI.Bouton(l, "x", 18, 18, function()
                    LCM.Incarnation.Oublier(self.instances[rang].instanceId)
                    self:Afficher()
                end)
                l.oublier:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                self.instances[rang] = l
            end
            l.instanceId = instance.id
            l.icone:SetTexture(instance.icon or "Interface\\ICONS\\INV_Misc_QuestionMark")
            local courant, maximum = LCM.Body.Totals(instance)
            l.nom:SetText(string.format("%s   |cff8a8a8a%d/%d PV|r",
                tostring(instance.name), courant, maximum))
            local joue = actuelle and actuelle.id == instance.id
            l.prendre.label:SetText(joue and "en cours" or "Prendre")
            l.prendre:Selectionner(joue and true or false)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.jeu.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.jeu.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE
        end
        for rang = #liste + 1, #self.instances do self.instances[rang]:Hide() end
        self.jeu:Regler(y)
        self.nombreEnJeu = #liste
        self.vide:SetText(#liste > 0 and "" or "Aucun PNJ en jeu.")
    end

    function f:Montrer()
        self:Afficher()
        self:Show()
    end

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

LCM.WhenReady(function()
    UI.Menu.Lier("incarner", Ecran.Basculer)
    -- Changer d'incarnation rafraichit ce qui est ouvert : la fiche ne doit pas
    -- rester sur le personnage d'avant.
    LCM.Incarnation.onChange = function()
        local fiche = UI.Fiche.frame
        if fiche and fiche:IsShown() then fiche:Montrer(LCM.Entities.Self()) end
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
    end
end)
