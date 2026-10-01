-- Le menu des fenetres.
--
-- Repris de Necronicon (Menu.lua, Core.lua:InitButton) : un bouton de 36 px,
-- deplacable ; son clic gauche deroule SOUS lui une colonne d'icones (36 px,
-- 4 d'ecart, 0,18 s) ; un dossier ouvre un volet A GAUCHE de son icone
-- (icones de 30, marge 5, ecart 4). Le lanceur radial, lui, sert aux actions
-- (UI/Radial.lua), comme dans Necronicon.
--
-- La STRUCTURE est celle du menu du template (« Template Fiche LVL 5 - Contes
-- Malveillants V2 », menuTree), figee ici. Un module n'ajoute pas d'entree : il
-- en habille une qui existe, par Menu.Lier(id, fonction). Une entree sans
-- fenetre reste visible, eteinte, et le dit au clic.

local _, LCM = ...
local UI = LCM.UI

local Menu = {}
UI.Menu = Menu

local ICONE = "Interface\\ICONS\\"
local TAILLE, ECART = 36, 4
local VOLET_ICONE, VOLET_ECART, VOLET_MARGE = 30, 4, 5
local DUREE = 0.18

-- ===== La structure, figee =================================================
-- Icones : celles du template (menuWindowIcons, dossiers du menuTree) ; a
-- defaut, celles que Necronicon donne au type de fenetre.

Menu.STRUCTURE = {
    -- « Création » a quitte le menu le 1er octobre 2026 : on cree un personnage
    -- depuis la selection (clic droit sur le sceau, « + Créer un personnage »),
    -- la ou l'on choisit deja qui l'on joue. L'avoir aux deux endroits ne
    -- servait qu'a se demander lequel fait foi.
    { id = "creation_personnage", label = "Création Personnage", icone = ICONE .. "eps_buildershaven_gobinfo",
      enfants = {
          { id = "regles",   label = "Règles",   icone = ICONE .. "eps_arc_book_bluedragon2" },
      } },
    { id = "fiches_personnages", label = "Fiches personnages", icone = ICONE .. "eps_lol_tft_infiltratoremblem",
      enfants = {
          { id = "fiche",         label = "Fiche",                     icone = ICONE .. "eps_lol_tft_enlightenedemblem" },
          { id = "sante",         label = "Santé",                     icone = ICONE .. "eps_lol_tft_heartemblem" },
          { id = "expertise",     label = "Expertises",                icone = ICONE .. "eps_lol_tft_syndicateemblem" },
          { id = "penetrations_resistances", label = "Pénétration & Résistances", icone = ICONE .. "eps_lol_tft_skirmisheremblem" },
          { id = "statistiques",  label = "Statistiques",              icone = ICONE .. "eps_buildershaven_gears" },
          { id = "apprentissage", label = "Apprentissage",             icone = ICONE .. "eps_lol_tft_storyweaveremblem" },
      } },
    { id = "grimoires", label = "Grimoires", icone = ICONE .. "eps_lol_tft_sorcereremblem" },
    { id = "objets", label = "Objets", icone = ICONE .. "inv_misc_coinbag03",
      enfants = {
          { id = "equipement",  label = "Équipements", icone = ICONE .. "eps_lol_tft_sentinelemblem" },
          { id = "inventaires", label = "Inventaires", icone = ICONE .. "inv_misc_bag_29" },
          -- Ajout a la structure du template : chaque joueur voit sa bourse.
          { id = "bourse",      label = "Bourse",      icone = ICONE .. "INV_Misc_Coin_17" },
          { id = "metiers",     label = "Métiers",     icone = ICONE .. "eps_lol_tft_witchcraftemblem" },
      } },
    { id = "outils", label = "Outils", icone = ICONE .. "eps_lol_yorick_mourningmist2",
      enfants = {
          { id = "parametres", label = "Paramètres", icone = ICONE .. "eps_lol_tft_scrapemblem" },
          { id = "compendium", label = "Compendium", icone = ICONE .. "eps_arc_book_venthyr2", mjSeulement = true },
          { id = "panneau_mj", label = "Panel MJ",   icone = ICONE .. "ability_rogue_controlisking", mjSeulement = true },
          { id = "vendeur",    label = "Vendeur",    icone = ICONE .. "INV_Misc_Coin_02" },
          { id = "ressources", label = "Ressources", icone = ICONE .. "INV_Misc_Herb_07" },
          { id = "incarner",   label = "Incarner",   icone = ICONE .. "Spell_Shadow_Possession", mjSeulement = true },
      } },
    -- Reserve au MJ depuis le 1er octobre 2026 : le compendium porte les PNJ,
    -- les resolutions et les actions MJ, et un joueur n'a rien a y lire. Sa
    -- race, il la choisit a la creation, pas ici.
    { id = "systeme_aelskar", label = "Système d'Aelskar", icone = ICONE .. "achievement_zone_stormpeaks_03",
      mjSeulement = true },
    { id = "deplacement", label = "Déplacement", icone = ICONE .. "eps_lol_janna_tailwind" },
}

-- ===== Liaisons ============================================================

local function Trouver(id, noeuds)
    id = tostring(id or "")
    for _, noeud in ipairs(noeuds or Menu.STRUCTURE) do
        if noeud.id == id then return noeud end
        if noeud.enfants then
            local trouve = Trouver(id, noeud.enfants)
            if trouve then return trouve end
        end
    end
end
Menu.Trouver = Trouver

-- LCM.UI.Menu.Lier("fiche", function() ... end). Un dossier ne se lie pas :
-- il s'ouvre.
function Menu.Lier(id, onClick)
    local cible = Trouver(id)
    if not cible or cible.enfants then
        LCM.Erreur(string.format("menu : entree inconnue « %s »", tostring(id)))
        return false
    end
    if type(onClick) ~= "function" then return false end
    cible.onClick = onClick
    return true
end

function Menu.EstLiee(id)
    local cible = Trouver(id)
    return cible ~= nil and type(cible.onClick) == "function"
end

-- Ce que le joueur voit ; le MJ voit en plus ses outils. Un dossier dont tout
-- le contenu est reserve au MJ disparait pour les autres.
function Menu.Visibles(noeuds)
    local out = {}
    for _, noeud in ipairs(noeuds or Menu.STRUCTURE) do
        if not noeud.mjSeulement or LCM.IsMaster() then
            if not noeud.enfants or #Menu.Visibles(noeud.enfants) > 0 then out[#out + 1] = noeud end
        end
    end
    return out
end

-- ===== Rendu ===============================================================

local function Adoucir(p) p = math.max(0, math.min(1, p)) local i = 1 - p return 1 - i * i * i end

local function Bulle(bouton)
    if not GameTooltip or not bouton.noeud then return end
    local n = bouton.noeud
    GameTooltip:SetOwner(bouton, "ANCHOR_LEFT")
    GameTooltip:SetText(n.label .. (n.enfants and "  >" or ""), 1, 0.9, 0.6)
    if not n.enfants and type(n.onClick) ~= "function" then
        GameTooltip:AddLine("Pas encore disponible.", 0.6, 0.56, 0.5)
    end
    GameTooltip:Show()
end

-- Une icone de menu (UI.StyleMenuIconButton) : fond sombre, filet d'accent en
-- bas, icone attenuee qui s'eclaire au survol. Eteinte si rien n'est branche.
local function Icone(parent, taille, marge)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(taille, taille)
    b:RegisterForClicks("LeftButtonUp")
    b.fond = UI.Aplat(b, { 0.035, 0.030, 0.023, 0.95 })
    b.fond:SetAllPoints(b)
    b.accent = UI.Aplat(b, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.8 }, "ARTWORK")
    b.accent:SetHeight(1)
    b.accent:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 1)
    b.accent:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 1)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", marge, -marge)
    b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -marge, marge)
    b.survol = UI.Aplat(b, { 1, 1, 1, 0.12 }, "HIGHLIGHT")
    b.survol:SetAllPoints(b)
    function b:Habiller(noeud)
        self.noeud = noeud
        self.icone:SetTexture(noeud.icone)
        local pret = noeud.enfants ~= nil or type(noeud.onClick) == "function"
        self.icone:SetDesaturated(not pret)
        self.icone:SetAlpha(pret and 0.85 or 0.4)
    end
    b:SetScript("OnEnter", function(self)
        self.icone:SetAlpha(1)
        Bulle(self)
    end)
    b:SetScript("OnLeave", function(self)
        if self.noeud then self:Habiller(self.noeud) end
        if GameTooltip then GameTooltip:Hide() end
    end)
    return b
end

local function Lancer(noeud)
    Menu.FermerVolets()
    if type(noeud.onClick) == "function" then
        local ok, err = pcall(noeud.onClick)
        if not ok then LCM.Erreur(string.format("%s : %s", tostring(noeud.label), tostring(err))) end
        return
    end
    LCM.Alerte(string.format("%s : pas encore disponible.", tostring(noeud.label)))
end

-- Le volet d'un dossier, a gauche de son icone.
function Menu.Volet()
    if Menu.volet then return Menu.volet end
    local v = CreateFrame("Frame", "LCM_MenuVolet", UIParent)
    v:SetFrameStrata("HIGH")
    v.fond = UI.Aplat(v, { 0.03, 0.028, 0.024, 0.92 })
    v.fond:SetAllPoints(v)
    UI.Bordure(v, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.45 })
    v.boutons = {}
    v:Hide()
    Menu.volet = v
    return v
end

function Menu.FermerVolets()
    if Menu.volet then
        Menu.volet:Hide()
        Menu.volet.dossier = nil
    end
end

function Menu.OuvrirDossier(dossier, ancre)
    local v = Menu.Volet()
    -- Re-clic sur le meme dossier : on referme.
    if v:IsShown() and v.dossier == dossier.id then
        Menu.FermerVolets()
        return
    end
    local enfants = Menu.Visibles(dossier.enfants)
    local n = math.max(1, #enfants)
    v:SetSize(VOLET_ICONE + VOLET_MARGE * 2, n * VOLET_ICONE + (n - 1) * VOLET_ECART + VOLET_MARGE * 2)
    for i, enfant in ipairs(enfants) do
        local b = v.boutons[i]
        if not b then
            b = Icone(v, VOLET_ICONE, 3)
            -- Le noeud est porte par le bouton : les boutons sont reutilises.
            b:SetScript("OnClick", function(self) Lancer(self.noeud) end)
            v.boutons[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", v, "TOPLEFT", VOLET_MARGE, -(VOLET_MARGE + (i - 1) * (VOLET_ICONE + VOLET_ECART)))
        b:Habiller(enfant)
        b:Show()
    end
    for i = #enfants + 1, #v.boutons do v.boutons[i]:Hide() end
    v.dossier = dossier.id
    v:ClearAllPoints()
    v:SetPoint("RIGHT", ancre, "LEFT", -6, 0)
    v:Show()
    v:Raise()
end

-- ===== Le bouton et la colonne =============================================

local function Deployer(f, progres)
    f.progres = math.max(0, math.min(1, progres))
    local hauteur = math.max(1, math.floor(f.hauteurPleine * f.progres + 0.5))
    f:SetHeight(hauteur)
    local n = f.nombre or 0
    for index, b in ipairs(f.boutons) do
        if index <= n then
            local decalage = (index - 1) * (TAILLE + ECART)
            local depart = n > 1 and ((index - 1) / n) * 0.18 or 0
            local p = math.max(0, math.min(1, (f.progres - depart) / math.max(0.01, 1 - depart)))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(decalage * (f.progres >= 1 and 1 or f.progres)))
            b:SetAlpha(p)
            b:EnableMouse(f.progres >= 1 and f.ouvert == true)
            b:SetShown(f.progres > 0.01)
        else
            b:Hide()
        end
    end
end

function Menu.Colonne()
    if Menu.colonne then return Menu.colonne end
    local f = CreateFrame("Frame", "LCM_MenuColonne", UIParent)
    f:SetFrameStrata("HIGH")
    f.fond = UI.Aplat(f, { 0.03, 0.028, 0.024, 0.9 })
    f.fond:SetAllPoints(f)
    f.boutons = {}
    f:Hide()
    Menu.colonne = f
    return f
end

function Menu.Remplir()
    local f = Menu.Colonne()
    local noeuds = Menu.Visibles()
    f.nombre = #noeuds
    f.hauteurPleine = #noeuds * TAILLE + math.max(0, #noeuds - 1) * ECART
    f:SetWidth(TAILLE)
    for i, noeud in ipairs(noeuds) do
        local b = f.boutons[i]
        if not b then
            b = Icone(f, TAILLE, 4)
            b:SetScript("OnClick", function(self)
                if self.noeud.enfants then Menu.OuvrirDossier(self.noeud, self)
                else Lancer(self.noeud) end
            end)
            f.boutons[i] = b
        end
        b:Habiller(noeud)
    end
    for i = #noeuds + 1, #f.boutons do f.boutons[i]:Hide() end
end

-- Deroule ou replie la colonne. `anime` : avec la courbe du modele.
function Menu.Deplier(ouvert, anime)
    local f = Menu.Colonne()
    ouvert = ouvert == true
    f.ouvert = ouvert
    f:SetScript("OnUpdate", nil)
    Menu.FermerVolets()
    if ouvert then
        Menu.Remplir()
        f:ClearAllPoints()
        f:SetPoint("TOP", Menu.Bouton(), "BOTTOM", 0, -4)
        f:Show()
    end
    local depart, cible = f.progres or 0, ouvert and 1 or 0
    if not anime then
        Deployer(f, cible)
        if cible == 0 then f:Hide() end
        return
    end
    local ecoule = 0
    f:SetScript("OnUpdate", function(self, delta)
        ecoule = ecoule + (tonumber(delta) or 0)
        Deployer(self, depart + (cible - depart) * Adoucir(ecoule / DUREE))
        if ecoule >= DUREE then
            self:SetScript("OnUpdate", nil)
            if cible == 0 then self:Hide() end
        end
    end)
end

function Menu.Basculer()
    local f = Menu.Colonne()
    Menu.Deplier(not f.ouvert, true)
end

-- L'icone du bouton : celle du profil TRP3 du joueur, comme Necronicon ; sans
-- TRP3, celle du personnage joue ; sinon le point d'interrogation du modele.
function Menu.ActualiserIcone()
    local b = Menu.bouton
    if not b then return end
    local trp = LCM.Identite.IconeTRP()
    if trp then
        b.icone:SetTexture(trp)
        return
    end
    -- Lecture seule : Entities.Self() CREE le personnage s'il manque, et un
    -- bouton qui s'affiche n'a pas a fabriquer de fiche.
    local moi = LCM.Personnages and LCM.Personnages.Actif and LCM.Personnages.Actif()
    moi = moi or (LCM.Entities and LCM.Entities.Get(LCM.PlayerId()))
    b.icone:SetTexture((moi and moi.icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
end

function Menu.Bouton()
    if Menu.bouton then return Menu.bouton end
    local b = CreateFrame("Button", "LCM_MenuBouton", UIParent)
    b:SetSize(TAILLE, TAILLE)
    b:SetFrameStrata("HIGH")
    b:SetMovable(true)
    b:EnableMouse(true)
    b:SetClampedToScreen(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetAllPoints(b)
    b.survol = UI.Aplat(b, { 1, 1, 1, 0.15 }, "HIGHLIGHT")
    b.survol:SetAllPoints(b)
    UI.Bordure(b, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.7 })
    b:SetScript("OnDragStart", function(self) self:StartMoving() end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        LCM.EnsureDatabase()
        local point, _, relPoint, x, y = self:GetPoint()
        LCM.db.settings.menuBouton = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    -- Clic gauche : la colonne des fenetres. Clic droit : la selection du
    -- personnage (Necronicon y met son menu rapide, qui n'existe pas encore ici).
    b:SetScript("OnClick", function(_, souris)
        if souris == "RightButton" then
            Menu.Deplier(false, true)
            if UI.Personnages and UI.Personnages.Ouvrir then UI.Personnages.Ouvrir() end
            return
        end
        Menu.Basculer()
    end)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Les Contes Malveillants", 1, 0.9, 0.6)
        GameTooltip:AddLine("Clic : les fenêtres. Clic droit : les personnages.", 0.88, 0.84, 0.76)
        GameTooltip:AddLine("Glisser : déplacer.", 0.6, 0.56, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    LCM.EnsureDatabase()
    local pos = LCM.db.settings.menuBouton
    if type(pos) == "table" then
        b:SetPoint(pos.point or "TOPRIGHT", UIParent, pos.relPoint or "TOPRIGHT", tonumber(pos.x) or 0, tonumber(pos.y) or 0)
    else
        b:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -200)
    end
    Menu.bouton = b
    Menu.ActualiserIcone()
    return b
end

LCM.Identite.AuChangement(Menu.ActualiserIcone)

LCM.AddCommand("fenetres", "ouvre le menu des fenetres", function() Menu.Basculer() end)

-- Les vues (Regles comprise) se lient elles-memes (UI/Vues.lua).
LCM.WhenReady(function()
    Menu.Bouton():Show()
end)
