-- Le lanceur radial : le point d'entree de tout l'addon.
--
-- Il est affiche en permanence. Clic gauche sur le sceau : la couronne des
-- categories se deploie. Clic sur une categorie : ses entrees s'ouvrent en
-- eventail. Clic droit sur le sceau : la selection du personnage.
--
-- La structure est FIGEE ici. Un module n'ajoute pas d'entree : il en habille
-- une qui existe deja, par Radial.Lier(id, fonction). Un identifiant inconnu
-- est refuse — c'est ce qui evite les menus qui poussent tout seuls et les
-- ordres negocies au vol qu'on a subis dans Necronicon.
--
-- Un chouilla plus petit que celui de Necronicon : sceau de 58 au lieu de 64,
-- categories a 94 au lieu de 106, actions a 172 au lieu de 202.

local _, LCM = ...
local UI = LCM.UI

local Radial = {}
UI.Radial = Radial

local ART = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\"
local SCEAU = ART .. "sceau.tga"
local SIGIL = ART .. "sigil.tga"
local ICONE = "Interface\\ICONS\\"

Radial.SCEAU = 58
Radial.CATEGORIE = 40
Radial.ACTION = 34
Radial.RAYON_CATEGORIE = 94
Radial.RAYON_ACTION = 172
Radial.FOND = 436
Radial.MAX_ENTREES = 5 -- au-dela, l'eventail n'a plus de dessin (fan-1..5)

-- ===== La structure, figee =================================================
-- Ajouter une entree ici est un acte de developpement, pas un reglage : les
-- identifiants sont ceux que citeront les liaisons, les raccourcis et la doc.

Radial.STRUCTURE = {
    {
        id = "personnage", label = "Personnage", icone = ICONE .. "Achievement_Character_Human_Male",
        entrees = {
            { id = "fiche",         label = "Fiche",         icone = ICONE .. "INV_Misc_Note_01" },
            { id = "equipement",    label = "Equipement",    icone = ICONE .. "INV_Chest_Plate04" },
            { id = "sante",         label = "Sante",         icone = ICONE .. "Spell_Holy_Heal" },
            { id = "expertise",     label = "Expertise",     icone = ICONE .. "INV_Misc_Book_09" },
            { id = "apprentissage", label = "Apprentissage", icone = ICONE .. "INV_Scroll_03" },
        },
    },
    {
        id = "inventaire", label = "Inventaire", icone = ICONE .. "INV_Misc_Bag_08",
        entrees = {
            { id = "metier",        label = "Metier",        icone = ICONE .. "Trade_BlackSmithing" },
            { id = "emplacement_1", label = "Emplacement 1", icone = ICONE .. "INV_Misc_Bag_09" },
            { id = "emplacement_2", label = "Emplacement 2", icone = ICONE .. "INV_Misc_Bag_10" },
            { id = "emplacement_3", label = "Emplacement 3", icone = ICONE .. "INV_Misc_Bag_11" },
            { id = "emplacement_4", label = "Emplacement 4", icone = ICONE .. "INV_Misc_Bag_12" },
        },
    },
    {
        id = "grimoire", label = "Grimoire", icone = ICONE .. "INV_Misc_Book_11",
        entrees = {
            { id = "competences", label = "Competences", icone = ICONE .. "INV_Misc_Book_07" },
            { id = "grimoires",   label = "Grimoires",   icone = ICONE .. "INV_Misc_Book_03" },
        },
    },
    -- Sans entree : le clic ouvre directement la fenetre de deplacement.
    {
        id = "deplacement", label = "Deplacement", icone = ICONE .. "Ability_Rogue_Sprint",
        direct = true,
    },
    {
        id = "outil", label = "Outil", icone = ICONE .. "Trade_Engineering", mjSeulement = true,
        entrees = {
            { id = "panneau_mj",           label = "Panneau MJ",           icone = ICONE .. "INV_Misc_Gear_01" },
            { id = "compendium",           label = "Compendium",           icone = ICONE .. "INV_Misc_Book_06" },
            { id = "action_emplacement",   label = "Action d'emplacement", icone = ICONE .. "Trade_Engraving" },
            { id = "incarner",             label = "Incarner",             icone = ICONE .. "Spell_Shadow_Possession" },
        },
    },
}

-- Verification au chargement : un eventail ne sait dessiner que 1 a 8 branches.
for _, categorie in ipairs(Radial.STRUCTURE) do
    local nombre = #(categorie.entrees or {})
    if nombre > Radial.MAX_ENTREES then
        error(string.format("radial : la categorie %s a %d entrees (maximum %d)",
            categorie.id, nombre, Radial.MAX_ENTREES))
    end
end

-- ===== Liaisons ============================================================

local function Trouver(id)
    id = tostring(id or "")
    for _, categorie in ipairs(Radial.STRUCTURE) do
        if categorie.id == id then return categorie end
        for _, entree in ipairs(categorie.entrees or {}) do
            if entree.id == id then return entree, categorie end
        end
    end
end
Radial.Trouver = Trouver

-- LCM.UI.Radial.Lier("fiche", function() ... end)
function Radial.Lier(id, onClick)
    local cible = Trouver(id)
    if not cible then
        LCM.Erreur(string.format("radial : entree inconnue « %s »", tostring(id)))
        return false
    end
    if type(onClick) ~= "function" then return false end
    cible.onClick = onClick
    return true
end

function Radial.EstLiee(id)
    local cible = Trouver(id)
    return cible ~= nil and type(cible.onClick) == "function"
end

-- Ce que le joueur a le droit de voir. Le MJ voit en plus ses outils.
function Radial.Categories()
    local out = {}
    for _, categorie in ipairs(Radial.STRUCTURE) do
        if (not categorie.mjSeulement) or LCM.IsMaster() then out[#out + 1] = categorie end
    end
    return out
end

function Radial.Entrees(categorieId)
    local categorie = Trouver(categorieId)
    local out = {}
    if not categorie then return out end
    -- Une categorie reservee au MJ ne laisse rien filtrer de son contenu.
    if categorie.mjSeulement and not LCM.IsMaster() then return out end
    for _, entree in ipairs(categorie.entrees or {}) do
        if (not entree.mjSeulement) or LCM.IsMaster() then out[#out + 1] = entree end
    end
    return out
end

-- ===== Animation ===========================================================
-- Un seul cadre d'animation pour tout le lanceur : aucun minuteur ne peut
-- terminer une fermeture devenue obsolete apres une reouverture rapide.

local transitions = {}
local animateur = CreateFrame("Frame")

local function Arreter(cible)
    transitions[cible] = nil
    if not next(transitions) then animateur:SetScript("OnUpdate", nil) end
end

local function Battement(_, ecoule)
    -- Les callbacks peuvent masquer des cadres ou annuler d'autres mouvements :
    -- on fige la liste avant de les appeler.
    local en_cours = {}
    for cible, mouvement in pairs(transitions) do
        en_cours[#en_cours + 1] = { cible, mouvement }
    end
    for _, entree in ipairs(en_cours) do
        local cible, mouvement = entree[1], entree[2]
        if transitions[cible] == mouvement then
            mouvement.temps = mouvement.temps + ecoule
            if mouvement.temps >= 0 then
                local t = math.min(1, mouvement.temps / mouvement.duree)
                mouvement.pas(1 - (1 - t) ^ 3)
                if t == 1 and transitions[cible] == mouvement then
                    transitions[cible] = nil
                    if mouvement.fin then mouvement.fin() end
                end
            end
        end
    end
    if not next(transitions) then animateur:SetScript("OnUpdate", nil) end
end

local function Mouvement(cible, duree, delai, pas, fin)
    Arreter(cible)
    transitions[cible] = { temps = -(delai or 0), duree = duree, pas = pas, fin = fin }
    pas(0)
    animateur:SetScript("OnUpdate", Battement)
end

-- Le bouton sort du centre en tournant : c'est ce mouvement-la qui fait le
-- caractere du menu de Necronicon, on le garde tel quel.
local TOURNIS = 0.95

local function Deployer(bouton, centre, x, y, departX, departY, delai)
    local dx, dy = x - departX, y - departY
    local rayon, angle = math.sqrt(dx * dx + dy * dy), math.atan2(dy, dx)
    Mouvement(bouton, 0.34, delai, function(t)
        local a = angle - (1 - t) * TOURNIS
        bouton:SetAlpha(t)
        bouton:ClearAllPoints()
        bouton:SetPoint("CENTER", centre, "CENTER",
            departX + math.cos(a) * rayon * t, departY + math.sin(a) * rayon * t)
    end)
end

local function Replier(bouton, centre, x, y, arriveeX, arriveeY, delai, fin)
    local dx, dy = x - arriveeX, y - arriveeY
    local rayon, angle = math.sqrt(dx * dx + dy * dy), math.atan2(dy, dx)
    Mouvement(bouton, 0.3, delai, function(t)
        local u = 1 - t
        local a = angle - (1 - u) * TOURNIS
        bouton:SetAlpha(u)
        bouton:ClearAllPoints()
        bouton:SetPoint("CENTER", centre, "CENTER",
            arriveeX + math.cos(a) * rayon * u, arriveeY + math.sin(a) * rayon * u)
    end, fin)
end

-- ===== Habillage ===========================================================

local function Surface(parent, nom, taille, couche)
    local t = parent:CreateTexture(nil, couche or "BACKGROUND")
    t:SetTexture(ART .. nom .. ".tga")
    t:SetPoint("CENTER", parent, "CENTER")
    t:SetSize(taille, taille)
    return t
end

local function Rond(bouton, taille)
    -- Le masque arrondit l'icone carree ; sans lui, des vignettes carrees dans
    -- un menu circulaire, ca se voit tout de suite.
    if not bouton.CreateMaskTexture then return end
    local masque = bouton:CreateMaskTexture()
    masque:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    masque:SetAllPoints(bouton.icone)
    if bouton.icone.AddMaskTexture then bouton.icone:AddMaskTexture(masque) end
    bouton.masque = masque
end

local function Halo(bouton, taille)
    local halo = CreateFrame("Frame", nil, bouton)
    halo:SetAllPoints()
    halo:EnableMouse(false)
    Surface(halo, "glow", taille * 64 / 48, "OVERLAY")
    halo:SetAlpha(0)
    bouton.halo = halo
    bouton:HookScript("OnHide", function(self)
        Arreter(self.halo)
        self.halo:SetAlpha(0)
        self.survole = false
    end)
end

local function Eclairer(bouton, choisi, survole)
    bouton.choisi, bouton.survole = choisi, survole
    local vise = survole and 1 or (choisi and 0.78 or 0)
    local depuis = bouton.halo:GetAlpha()
    Mouvement(bouton.halo, 0.12, 0, function(t)
        bouton.halo:SetAlpha(depuis + (vise - depuis) * t)
    end)
    if bouton.legende then
        local couleur = (choisi or survole) and UI.C.titre or UI.C.discret
        bouton.legende:SetTextColor(couleur[1], couleur[2], couleur[3])
    end
end

local function Bulle(bouton, titre, detail)
    bouton:SetScript("OnEnter", function(self)
        Eclairer(self, self.choisi, true)
        if self.legende then self.legende:Show() end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(titre, UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
        if detail then GameTooltip:AddLine(detail, 0.7, 0.68, 0.62, true) end
        GameTooltip:Show()
    end)
    bouton:SetScript("OnLeave", function(self)
        Eclairer(self, self.choisi, false)
        if self.legende and self.legendeAuSurvol then self.legende:Hide() end
        if GameTooltip then GameTooltip:Hide() end
    end)
end

local function Vignette(parent, taille, legendeAuSurvol)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(taille, taille)
    Surface(b, "button", taille * 64 / 48)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetPoint("TOPLEFT", 3, -3)
    b.icone:SetPoint("BOTTOMRIGHT", -3, 3)
    Rond(b, taille)
    b.legende = UI.Texte(b, "", UI.C.discret, "GameFontNormalSmall")
    b.legende:SetPoint("TOP", b, "BOTTOM", 0, -4)
    b.legende:SetJustifyH("CENTER")
    b.legendeAuSurvol = legendeAuSurvol and true or false
    if legendeAuSurvol then b.legende:Hide() end
    Halo(b, taille)
    return b
end

-- ===== Le lanceur ==========================================================

local function Fond(f, t)
    f.fond:SetAlpha(t)
    local phase, echelle = -(1 - t) * TOURNIS, 0.65 + 0.35 * t
    if f.fond.surface.SetSize then
        f.fond.surface:SetSize(Radial.FOND * echelle, Radial.FOND * echelle)
    end
    if f.fond.surface.SetRotation then f.fond.surface:SetRotation(phase) end
    if f.sigil.SetRotation then f.sigil:SetRotation(-phase * 0.3) end
end

local function Eventail(f, angle, nombre, avancement)
    f.secteur.surface:SetTexture(ART .. "fan-" .. nombre .. ".tga")
    if f.secteur.surface.SetRotation then
        f.secteur.surface:SetRotation(angle - math.pi / 2)
    end
    local taille = Radial.FOND * (0.94 + 0.06 * (avancement or 1))
    f.secteur.surface:SetSize(taille, taille)
    f.secteur:Show()
end

local Dessiner

-- Replie les entrees vers leur categorie, puis appelle `apres`.
local function ReplierEntrees(f, apres)
    local une = false
    for i, b in ipairs(f.boutonsEntree) do
        if b:IsShown() then
            une = true
            Replier(b, f, b.rx, b.ry, f.choisiX or 0, f.choisiY or 0, (i - 1) * 0.012,
                function() b:Hide() end)
        end
    end
    if not une then if apres then apres() end return end
    f.replie = true
    Mouvement(f.secteur, 0.3, 0, function(t) f.secteur:SetAlpha(1 - t) end, function()
        f.replie = nil
        f.secteur:Hide()
        if apres then apres() end
    end)
end

local function Fermer(f, anime)
    Arreter(f.orbite) Arreter(f.fond) Arreter(f.secteur)
    for _, liste in ipairs({ f.boutonsCategorie, f.boutonsEntree }) do
        for _, b in ipairs(liste) do Arreter(b) end
    end
    local choisiX, choisiY = f.choisiX, f.choisiY
    f.ouvert, f.choisi, f.replie = false, nil, nil
    if not anime or not f.orbite:IsShown() then
        f.orbite:Hide()
        f.orbite:SetAlpha(1)
        Fond(f, 1)
        return
    end
    -- Les entrees rentrent dans leur categorie, les categories rentrent dans le
    -- sceau, le fond se replie en meme temps.
    local attente = 0
    for i, b in ipairs(f.boutonsEntree) do
        if b:IsShown() then
            Replier(b, f, b.rx, b.ry, choisiX or 0, choisiY or 0, (i - 1) * 0.012,
                function() b:Hide() end)
            attente = 0.12
        end
    end
    if f.secteur:IsShown() then
        Mouvement(f.secteur, 0.25, 0, function(t) f.secteur:SetAlpha(1 - t) end,
            function() f.secteur:Hide() end)
    end
    for i, b in ipairs(f.boutonsCategorie) do
        if b:IsShown() then
            Replier(b, f, b.rx, b.ry, 0, 0, attente + (i - 1) * 0.02)
        end
    end
    Mouvement(f.fond, 0.32, attente + 0.05, function(t) Fond(f, 1 - t) end)
    Mouvement(f.orbite, 0.42 + attente, 0, function() end, function()
        f.orbite:Hide()
        f.orbite:SetAlpha(1)
        Fond(f, 1)
    end)
end

local function Lancer(f, cible)
    if type(cible.onClick) == "function" then
        Fermer(f, true)
        local ok, err = pcall(cible.onClick)
        if not ok then LCM.Erreur(string.format("%s : %s", tostring(cible.label), tostring(err))) end
        return
    end
    LCM.Alerte(string.format("%s : pas encore disponible.", tostring(cible.label)))
end

Dessiner = function(f, animeCategories, animeEntrees)
    Arreter(f.orbite) Arreter(f.fond) Arreter(f.secteur)
    f.orbite:SetAlpha(1)
    for _, b in ipairs(f.boutonsCategorie) do Arreter(b) b:SetAlpha(1) b:Hide() end
    for _, b in ipairs(f.boutonsEntree) do Arreter(b) b:SetAlpha(1) b:Hide() end
    f.secteur:Hide()
    if not f.ouvert then f.orbite:Hide() return end
    f.orbite:Show()
    if animeCategories then
        Mouvement(f.fond, 0.4, 0, function(t) Fond(f, t) end)
    else
        Fond(f, 1)
    end

    local categories = Radial.Categories()
    local choisie, angleChoisi
    for i, categorie in ipairs(categories) do
        local b = f.boutonsCategorie[i]
        if not b then
            b = Vignette(f.orbite, Radial.CATEGORIE, false)
            f.boutonsCategorie[i] = b
        end
        -- Premiere categorie en haut, puis dans le sens horaire.
        local angle = math.pi / 2 - (i - 1) * 2 * math.pi / #categories
        b.rx, b.ry = math.cos(angle) * Radial.RAYON_CATEGORIE, math.sin(angle) * Radial.RAYON_CATEGORIE
        b.cible = categorie
        b:ClearAllPoints()
        b:SetPoint("CENTER", f, "CENTER", b.rx, b.ry)
        b.icone:SetTexture(categorie.icone)
        b.legende:SetText(categorie.label)
        b.choisi = (f.choisi == categorie.id)
        local teinte = b.choisi and 1 or 0.78
        b.icone:SetVertexColor(teinte, teinte, teinte)
        Bulle(b, categorie.label, categorie.direct and "Clic : ouvrir." or "Clic : deployer.")
        Eclairer(b, b.choisi, false)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function(bouton)
            local cat = bouton.cible
            if cat.direct or #Radial.Entrees(cat.id) == 0 then
                Lancer(f, cat)
                return
            end
            f.choisi = (f.choisi ~= cat.id) and cat.id or nil
            -- Un clic pendant le repli : le choix est memorise, le dessin qui
            -- suit la fin du repli l'utilisera.
            if f.replie then return end
            ReplierEntrees(f, function() if f.ouvert then Dessiner(f, false, true) end end)
        end)
        b:Show()
        if animeCategories then Deployer(b, f, b.rx, b.ry, 0, 0, (i - 1) * 0.025) end
        if f.choisi == categorie.id then choisie, angleChoisi = categorie, angle end
    end
    for i = #categories + 1, #f.boutonsCategorie do f.boutonsCategorie[i]:Hide() end
    f.nombreCategories = #categories

    if not choisie then
        f.choisiX, f.choisiY = nil, nil
        f.nombreEntrees = 0
        return
    end

    local entrees = Radial.Entrees(choisie.id)
    f.choisiX = math.cos(angleChoisi) * Radial.RAYON_CATEGORIE
    f.choisiY = math.sin(angleChoisi) * Radial.RAYON_CATEGORIE
    if animeEntrees then
        Mouvement(f.secteur, 0.4, 0, function(t)
            Eventail(f, angleChoisi - (1 - t) * TOURNIS, #entrees, t)
            f.secteur:SetAlpha(t)
        end)
    else
        Eventail(f, angleChoisi, #entrees)
        f.secteur:SetAlpha(1)
    end

    for i, entree in ipairs(entrees) do
        local b = f.boutonsEntree[i]
        if not b then
            b = Vignette(f.orbite, Radial.ACTION, true)
            f.boutonsEntree[i] = b
        end
        local angle = angleChoisi + (i - (#entrees + 1) / 2) * math.pi / 8.75
        b.rx, b.ry = math.cos(angle) * Radial.RAYON_ACTION, math.sin(angle) * Radial.RAYON_ACTION
        b.cible = entree
        b:ClearAllPoints()
        b:SetPoint("CENTER", f, "CENTER", b.rx, b.ry)
        b:SetSize(Radial.ACTION, Radial.ACTION)
        b.icone:SetTexture(entree.icone)
        b.legende:SetText(entree.label)
        -- Une entree sans fenetre derriere elle reste visible mais eteinte : le
        -- menu ne ment pas sur ce qui existe.
        local prete = type(entree.onClick) == "function"
        local teinte = prete and 0.95 or 0.42
        b.icone:SetVertexColor(teinte, teinte, teinte)
        Bulle(b, entree.label, prete and "Clic : ouvrir." or "Pas encore disponible.")
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function(bouton) Lancer(f, bouton.cible) end)
        b:Show()
        if animeEntrees then
            Deployer(b, f, b.rx, b.ry, f.choisiX, f.choisiY, (i - 1) * 0.018)
        end
    end
    for i = #entrees + 1, #f.boutonsEntree do f.boutonsEntree[i]:Hide() end
    f.nombreEntrees = #entrees
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_Radial", UIParent)
    f:SetSize(Radial.SCEAU, Radial.SCEAU)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f.boutonsCategorie, f.boutonsEntree = {}, {}

    f.sceau = Vignette(f, Radial.SCEAU, false)
    f.sceau:SetAllPoints(f)
    f.sceau.icone:SetTexture(SCEAU)
    f.sceau.icone:SetAlpha(0.9)
    f.sceau.legende:Hide()
    f.sigil = f.sceau:CreateTexture(nil, "ARTWORK", nil, -1)
    f.sigil:SetTexture(SIGIL)
    f.sigil:SetPoint("CENTER", f.sceau, "CENTER")
    f.sigil:SetSize(Radial.SCEAU * 1.55, Radial.SCEAU * 1.55)
    f.sigil:SetAlpha(0.62)

    f.orbite = CreateFrame("Frame", "LCM_RadialOrbite", f)
    f.orbite:SetAllPoints()
    f.orbite:Hide()
    f.sceau:SetFrameLevel(f.orbite:GetFrameLevel() + 3)

    f.fond = CreateFrame("Frame", nil, f.orbite)
    f.fond:SetAllPoints()
    f.fond:EnableMouse(false)
    f.fond.surface = Surface(f.fond, "background", Radial.FOND)

    f.secteur = CreateFrame("Frame", nil, f.orbite)
    f.secteur:SetAllPoints()
    f.secteur:EnableMouse(false)
    f.secteur.surface = Surface(f.secteur, "fan-1", Radial.FOND)
    f.secteur:Hide()
    Fond(f, 1)

    -- Echap referme la couronne.
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "LCM_RadialOrbite" end
    f.orbite:SetScript("OnHide", function()
        Arreter(f.orbite) Arreter(f.fond) Arreter(f.secteur)
        for _, liste in ipairs({ f.boutonsCategorie, f.boutonsEntree }) do
            for _, b in ipairs(liste) do Arreter(b) end
        end
        f.ouvert, f.choisi = false, nil
    end)

    -- Maj + glisser deplace le sceau ; sa place est retenue.
    f.sceau:RegisterForDrag("LeftButton")
    f.sceau:SetScript("OnDragStart", function()
        if not (IsShiftKeyDown and IsShiftKeyDown()) then return end
        Fermer(f)
        f:StartMoving()
    end)
    f.sceau:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        LCM.EnsureDatabase()
        LCM.db.settings.radial = type(LCM.db.settings.radial) == "table" and LCM.db.settings.radial or {}
        local x, y = f:GetCenter()
        local cx, cy = UIParent:GetCenter()
        if x and cx then
            LCM.db.settings.radial.x, LCM.db.settings.radial.y = x - cx, y - cy
        end
    end)

    f.sceau:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f.sceau:SetScript("OnClick", function(_, souris)
        if souris == "RightButton" then
            Fermer(f, true)
            if UI.Personnages then UI.Personnages.Ouvrir() end
            return
        end
        if f.ouvert then Fermer(f, true) return end
        f.ouvert = true
        f.choisi = nil
        Dessiner(f, true, false)
    end)
    Bulle(f.sceau, "Les Contes Malveillants",
        "Clic : le menu\nClic droit : choisir un personnage\nMaj + glisser : deplacer")

    Radial.frame = f
    return f
end

function Radial.Fenetre()
    if not Radial.frame then Construire() end
    return Radial.frame
end

-- Place le sceau : au centre-bas par defaut, ou la ou le joueur l'a laisse.
function Radial.Placer()
    local f = Radial.Fenetre()
    LCM.EnsureDatabase()
    local place = LCM.db.settings and LCM.db.settings.radial
    local x = type(place) == "table" and tonumber(place.x) or 0
    local y = type(place) == "table" and tonumber(place.y) or -160
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function Radial.Basculer()
    local f = Radial.Fenetre()
    if f.ouvert then Fermer(f, true) return end
    f.ouvert = true
    f.choisi = nil
    Dessiner(f, true, false)
end

function Radial.Fermer() Fermer(Radial.Fenetre(), true) end

-- Montre ou cache le sceau lui-meme (il est affiche en permanence par defaut).
function Radial.Afficher(visible)
    local f = Radial.Fenetre()
    if visible == nil then visible = not f:IsShown() end
    if not visible then Fermer(f) end
    f:SetShown(visible and true or false)
    LCM.EnsureDatabase()
    LCM.db.settings.radialCache = (not visible) and true or nil
end

LCM.AddCommand("menu", "ouvre le menu radial", function() Radial.Basculer() end)
LCM.AddCommand("sceau", "montre ou cache le sceau du menu", function() Radial.Afficher() end)

-- ===== Liaisons de base ====================================================
-- Chaque fenetre habille son entree. Celles qui n'existent pas encore restent
-- eteintes dans le menu, ce qui vaut mieux qu'une entree absente.

LCM.WhenReady(function()
    Radial.Lier("fiche", function()
        local f = LCM.UI.Fiche.Fenetre()
        if f:IsShown() then f:Hide() else f:Montrer(LCM.Entities.Self()) end
    end)
    Radial.Placer()
    local f = Radial.Fenetre()
    f:SetShown(not (LCM.db.settings and LCM.db.settings.radialCache))
end)

-- Nom lisible dans les raccourcis clavier de WoW.
_G.BINDING_HEADER_LESCONTESMALVEILLANTS = "Les Contes Malveillants"
_G.BINDING_NAME_LCM_MENU = "Ouvrir le menu"
_G.BINDING_NAME_LCM_FICHE = "Ouvrir la fiche"

function LCM_ToggleMenu() Radial.Basculer() end
function LCM_ToggleFiche()
    local f = LCM.UI.Fiche.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer(LCM.Entities.Self()) end
end
