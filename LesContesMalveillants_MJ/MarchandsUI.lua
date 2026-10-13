-- La fenetre « Vendeur » du MJ : creer des marchands, puis les poser sur la
-- carte (13 octobre 2026). Meme forme que la fenetre « Ressources »
-- (MJ/RecoltesUI.lua) :
--   * CREATION — les marchands, et leur constructeur (MJ/PointsUI.lua), qui
--     reste celui qu'on connait : onglets, articles, rachats, devises ;
--   * PLACEMENT — on choisit un marchand, on marche, et chaque clic sur
--     « Poser le marchand ici » en pose un. Tous ses emplacements sont listes.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Points = LCM.Points
local Marchands = LCM.MarchandsMJ

local Ecran = {}
UI.MarchandsMJ = Ecran

local LARGEUR, HAUTEUR = 760, 500
local COLONNE = 210
local LIGNE = 26

local function Constructeur()
    return UI.Points and UI.Points.Editeur and UI.Points.Editeur("vendeur")
end

local function Prix(offre)
    if not (offre.prix and offre.devise) then return "" end
    local devise = LCM.Devises.Get(offre.devise)
    return string.format("%s %s", tostring(offre.prix), (devise and devise.label) or offre.devise)
end

local function Construire()
    local f = UI.Fenetre("marchands_mj", "Vendeur", LARGEUR, HAUTEUR, { x = -80, y = -40 })
    f.onglet = "creation"

    f.liste = UI.Defilement(f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 34)
    f.liste:SetWidth(COLONNE)
    f.lignes = {}
    f.nouveau = UI.Bouton(f.contenu, "+ Nouveau", 100, 24, function()
        local ed = Constructeur()
        if ed then ed:Ouvrir(nil) end
    end)
    f.nouveau:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.modifier = UI.Bouton(f.contenu, "Modifier", 100, 24, function()
        local ed, point = Constructeur(), f:Point()
        if ed and point then ed:Ouvrir(point) end
    end)
    f.modifier:SetPoint("LEFT", f.nouveau, "RIGHT", 6, 0)
    f.confirmation = UI.Confirmer(f, "", "Confirmer")

    f.droite = CreateFrame("Frame", nil, f.contenu)
    f.droite:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 16, 0)
    f.droite:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.boutonCreation = UI.Bouton(f.droite, "Création", 120, 24, function() f:Onglet("creation") end)
    f.boutonCreation:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, 0)
    f.boutonPlacement = UI.Bouton(f.droite, "Placement", 120, 24, function() f:Onglet("placement") end)
    f.boutonPlacement:SetPoint("LEFT", f.boutonCreation, "RIGHT", 6, 0)

    -- ----- CREATION : ce que le marchand vend ------------------------------
    local c = CreateFrame("Frame", nil, f.droite)
    c:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -34)
    c:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.creation = c
    c.titre = UI.Texte(c, "", UI.C.titre)
    UI.Police(c.titre, 14)
    c.titre:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -2)
    c.aide = UI.Texte(c, "Les articles, leurs prix et leur stock se règlent dans le constructeur (« Modifier »).",
        UI.C.discret, "GameFontNormalSmall")
    c.aide:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -22)
    c.aide:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    c.aide:SetJustifyH("LEFT")
    c.zone = UI.Defilement(c)
    c.zone:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -46)
    c.zone:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -10, 0)
    c.lignes = {}

    -- ----- PLACEMENT ------------------------------------------------------
    local p = CreateFrame("Frame", nil, f.droite)
    p:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -34)
    p:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.placement = p
    p.titre = UI.Texte(p, "", UI.C.titre)
    UI.Police(p.titre, 14)
    p.titre:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -2)
    p.position = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
    p.position:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -26)
    p.position:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    p.position:SetJustifyH("LEFT")
    p.poser = UI.Bouton(p, "Poser le marchand ici", 260, 34, function() f:Poser() end)
    p.poser:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -50)
    p.compte = UI.Texte(p, "", UI.C.accent, "GameFontNormalSmall")
    p.compte:SetPoint("LEFT", p.poser, "RIGHT", 12, 0)
    p.toutRetirer = UI.Bouton(p, "Tout retirer", 110, 22, function() f:ToutRetirer() end)
    p.toutRetirer:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -56)
    p.zone = UI.Defilement(p)
    p.zone:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -94)
    p.zone:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -10, 0)
    p.lignes = {}
    p.vide = UI.Texte(p, "Aucun emplacement. Marche jusqu'à l'étal et clique sur « Poser le marchand ici ».",
        UI.C.discret, "GameFontNormalSmall")
    p.vide:SetPoint("TOP", p.zone, "TOP", 0, -20)
    p.vide:SetWidth(380)
    p.vide:SetWordWrap(true)
    p.attente = 0
    p:SetScript("OnUpdate", function(self, dt)
        self.attente = self.attente + (dt or 0)
        if self.attente < 0.5 then return end
        self.attente = 0
        f:Position()
    end)

    function f:Point() return self.pointId and Points.Get(self.pointId) or nil end

    function f:Onglet(onglet)
        self.onglet = onglet
        self.boutonCreation:Selectionner(onglet == "creation")
        self.boutonPlacement:Selectionner(onglet == "placement")
        self.creation:SetShown(onglet == "creation")
        self.placement:SetShown(onglet == "placement")
        self:Afficher()
    end

    function f:Choisir(id)
        self.pointId = id
        self:Afficher()
    end

    function f:Poser()
        local point = self:Point()
        if not point then LCM.Alerte("choisis d'abord un marchand.") return end
        local id, raison = Marchands.Placer(point.id)
        if not id then LCM.Alerte(tostring(raison)) return end
        self:Afficher()
    end

    function f:ToutRetirer()
        local point = self:Point()
        if not point then return end
        local n = Marchands.Compte(point.id)
        if n == 0 then return end
        self.confirmation:Demander(string.format("Retirer les %d emplacement(s) de « %s » ?", n, point.label),
            function() Marchands.RetirerTout(point.id) self:Afficher() end)
    end

    function f:Position()
        local x, y, source = LCM.Recolte.Position()
        if x then
            local carte = LCM.Recolte.Carte()
            p.position:SetText(string.format("Tu es en %.1f, %.1f  (%s%s)", x, y, tostring(source),
                carte and (", carte " .. carte) or ""))
        else
            p.position:SetText("Position inconnue ici : le clic demandera « .gps ».")
        end
        return x, y, source
    end

    -- Les articles du marchand, avec ce qu'il en reste et ce qui est reserve.
    function f:AfficherArticles()
        local point = self:Point()
        c.titre:SetText(point and point.label or "Choisis un marchand à gauche")
        local h = 0
        local n = 0
        for _, onglet in ipairs((point and point.onglets) or {}) do
            for _, offre in ipairs(onglet.offres or {}) do
                n = n + 1
                local l = c.lignes[n]
                if not l then
                    l = UI.Texte(c.zone.contenu, "", UI.C.texte, "GameFontNormalSmall")
                    l:SetJustifyH("LEFT")
                    c.lignes[n] = l
                end
                local stock = ""
                local limite = LCM.Stock.Limite(offre.cle)
                if limite > 0 then
                    local reserve = Marchands.EnAttente(point.id, offre.id)
                    stock = string.format("   stock %d / %d%s", LCM.Stock.Restant(offre.cle), limite,
                        reserve > 0 and string.format(" (|cffe0c060%d en attente|r)", reserve) or "")
                end
                l:SetText(string.format("%s%s   |cffffd36b%s|r%s", Points.Libelle(offre),
                    offre.quantite > 1 and ("  x" .. offre.quantite) or "", Prix(offre), stock))
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", c.zone.contenu, "TOPLEFT", 4, -h)
                l:SetPoint("RIGHT", c.zone.contenu, "RIGHT", 0, 0)
                l:Show()
                h = h + 20
            end
        end
        for index = n + 1, #c.lignes do c.lignes[index]:Hide() end
        c.zone:Regler(h)
    end

    function f:AfficherPoints()
        local point = self:Point()
        local liste = point and Marchands.Points(point.id) or {}
        local x, y, source = self:Position()
        local carte = LCM.Recolte.Carte()
        local h = 0
        for rang, pose in ipairs(liste) do
            local l = p.lignes[rang]
            if not l then
                l = CreateFrame("Frame", nil, p.zone.contenu)
                l:SetHeight(LIGNE - 2)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.texte = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                l.texte:SetPoint("LEFT", l, "LEFT", 8, 0)
                l.texte:SetPoint("RIGHT", l, "RIGHT", -40, 0)
                l.texte:SetJustifyH("LEFT")
                l.retirer = UI.Bouton(l, "x", 24, 20, function(b)
                    Marchands.Retirer(b:GetParent().poseId)
                    self:Afficher()
                end)
                l.retirer:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                p.lignes[rang] = l
            end
            l.poseId = pose.id
            local distance = ""
            if x and pose.source == source and pose.carte == carte then
                distance = string.format("  —  à %.0f yards", math.sqrt((x - pose.x) ^ 2 + (y - pose.y) ^ 2))
            elseif pose.carte ~= carte then
                distance = "  —  autre carte"
            end
            l.texte:SetText(string.format("#%d   %.1f, %.1f   (%s%s)%s", #liste - rang + 1,
                pose.x, pose.y, tostring(pose.source), pose.carte and (", carte " .. pose.carte) or "", distance))
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", p.zone.contenu, "TOPLEFT", 0, -h)
            l:SetPoint("TOPRIGHT", p.zone.contenu, "TOPRIGHT", 0, -h)
            l:Show()
            h = h + LIGNE
        end
        for rang = #liste + 1, #p.lignes do p.lignes[rang]:Hide() end
        p.zone:Regler(h)
        p.titre:SetText(point and point.label or "Choisis un marchand à gauche")
        p.vide:SetShown(point ~= nil and #liste == 0)
        p.compte:SetText(point and string.format("%d emplacement(s)", #liste) or "")
        p.poser:SetEnabled(point ~= nil)
        p.toutRetirer:SetEnabled(#liste > 0)
    end

    function f:Afficher()
        local definitions = Marchands.Definitions()
        if self.pointId and not Points.Get(self.pointId) then self.pointId = nil end
        if not self.pointId and definitions[1] then self.pointId = definitions[1].id end
        local y = 0
        for rang, point in ipairs(definitions) do
            local b = self.lignes[rang]
            if not b then
                b = UI.Bouton(self.liste.contenu, "", COLONNE - 10, LIGNE - 2, function(bouton)
                    self:Choisir(bouton.pointId)
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
                b.label:SetJustifyH("LEFT")
                self.lignes[rang] = b
            end
            b.pointId = point.id
            local n = Marchands.Compte(point.id)
            b.label:SetText(n > 0 and string.format("%s  |cff9d9d9d(%d)|r", point.label, n) or point.label)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.liste.contenu, "TOPLEFT", 0, -y)
            b:Selectionner(point.id == self.pointId)
            b:Show()
            y = y + LIGNE
        end
        for rang = #definitions + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.liste:Regler(y)
        self.modifier:SetEnabled(self:Point() ~= nil)
        self:AfficherArticles()
        self:AfficherPoints()
    end

    function f:Montrer()
        self:Onglet(self.onglet or "creation")
        self:Show()
    end

    f:Hide()
    return f
end

function Ecran.Fenetre()
    if not LCM.IsMaster() then
        LCM.Alerte("cet outil est réservé au maître du jeu.")
        return nil
    end
    Ecran.frame = Ecran.frame or Construire()
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if not f then return nil end
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.WhenReady(function()
    -- L'entree « Vendeur » du menu ouvre cette fenetre. Posee apres
    -- MJ/PointsUI.lua, cette liaison remplace l'ancienne vue du vendeur, qui
    -- reste ce qu'ouvre le sort Arcanum.
    UI.Menu.Lier("vendeur", function() Ecran.Basculer() end)
    Marchands.onChange = function()
        local f = Ecran.frame
        if f and f:IsShown() then f:Afficher() end
    end
    -- Le constructeur referme : ce qu'on y a change part tout de suite aux
    -- joueurs (prix, articles, stock) si le marchand est pose quelque part.
    local ed = Constructeur()
    if ed then
        ed:HookScript("OnHide", function(self)
            Marchands.Reconstruire()
            local id = self.travail and self.travail.id
            if id and Marchands.Compte(id) > 0 then Marchands.Diffuser(id) end
            local f = Ecran.frame
            if f and f:IsShown() then f:Afficher() end
        end)
    end
end)
