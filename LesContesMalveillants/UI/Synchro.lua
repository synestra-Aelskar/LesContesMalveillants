-- Fenetre commune aux deux boutons de synchronisation forcee du MJ.
local _, LCM = ...
local UI = LCM.UI
local Ecran = {}
UI.Synchro = Ecran

local function Construire()
    local f = UI.Fenetre("transfert_synchro", "Transfert des données", 390, 190,
        { x = 160, y = -100 }, { sobre = true })
    local c = f.contenu
    f.etat = UI.Texte(c, "Préparation du transfert…", UI.C.texte, "GameFontNormal")
    f.etat:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -8)
    f.etat:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -8)
    f.compteur = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    f.compteur:SetPoint("TOPLEFT", f.etat, "BOTTOMLEFT", 0, -12)
    f.compteur:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -38)
    f.fondBarre = CreateFrame("Frame", nil, c)
    f.fondBarre:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -75)
    f.fondBarre:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -75)
    f.fondBarre:SetHeight(18)
    local fond = UI.Aplat(f.fondBarre, UI.C.fondClair)
    fond:SetAllPoints(f.fondBarre)
    UI.Bordure(f.fondBarre)
    f.remplissage = UI.Aplat(f.fondBarre, UI.C.accent, "ARTWORK")
    f.remplissage:SetPoint("TOPLEFT", f.fondBarre, "TOPLEFT", 1, -1)
    f.remplissage:SetPoint("BOTTOMLEFT", f.fondBarre, "BOTTOMLEFT", 1, 1)
    f.remplissage:SetWidth(1)
    f.pourcentage = UI.Texte(c, "0 %", UI.C.accent, "GameFontNormal")
    f.pourcentage:SetPoint("TOP", f.fondBarre, "BOTTOM", 0, -9)
    f:SetScript("OnUpdate", function(self, dt)
        self.cumul = (self.cumul or 0) + (dt or 0)
        if self.cumul < 0.25 then return end
        self.cumul = 0
        self:Rafraichir()
    end)
    function f:Rafraichir()
        local p = LCM.Synchro.Progression()
        if not p then return end
        local pct = p.total > 0 and math.floor(100 * p.envoyes / p.total) or 0
        if not p.fini then pct = math.min(99, pct) end
        self.pct = pct
        self.pourcentage:SetText(pct .. " %")
        self.remplissage:SetWidth(math.max(1, (self.fondBarre:GetWidth() - 2) * pct / 100))
        self.compteur:SetText(string.format("%d / %d paquet(s) envoyés", p.envoyes, p.total))
        if p.fini then
            self.etat:SetText("Envoi terminé")
        elseif (p.attentes or 0) > 0 and p.envoyes == p.total then
            self.etat:SetText(string.format("En attente de %d confirmation(s) MJ", p.attentes))
        elseif p.envoyes == p.total then
            self.etat:SetText("Recherche des données manquantes…")
        else
            self.etat:SetText("Transfert en cours…")
        end
    end
    return f
end

function Ecran.Ouvrir()
    local f = Ecran.frame or Construire()
    Ecran.frame = f
    f.cumul = 0
    f:Rafraichir()
    f:Show()
    UI.Devant(f)
    return f
end
