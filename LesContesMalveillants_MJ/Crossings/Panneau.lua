-- ============================================================
--  Zone Gate — Panel principal
--  /oche pour ouvrir
--  Colonne gauche : Pays › Régions › Lieux. Un pays ne sert qu'à
--  ranger ; une région porte ses lieux, ses zones et ses passages ;
--  un lieu porte son nom, sa zone, sa bannière, ses effets et sa
--  découverte.
--  Colonne droite : fiche du pays, de la région (lieux, carte, zones,
--  passages, bannière) ou du lieu sélectionné.
--
--  Une ZONE est une étendue dessinée (on est dedans ou dehors), un
--  PASSAGE une porte droite (on la traverse). Les deux vivent dans
--  zone.subZones, séparées par leur forme — voir ZG:GetAreaList.
-- ============================================================

local ZG = LCMCrossings
local UI = ZG.EditorUI

local function MyName() return UnitName("player") or "" end

local PANEL_W  = 1000
local PANEL_H  = 800
local PAD      = 16
-- L'en-tête ne porte que trois boutons : il respirait pour rien, au-dessus
-- comme au-dessous, et c'est autant de moins pour la carte.
local HEADER_H = 44
local LIST_W   = 264
local ROW_H    = 34
local FORM_W   = PANEL_W - LIST_W - PAD * 2 - 24
local PAGE_Y   = 140   -- haut des pages, sous l'en-tête et les onglets
-- Tout ce qui se crée depuis l'arbre — les couleurs, les trois lettres du
-- bout de ligne, et les gestes eux-mêmes — dans UNE table : Lua 5.1 n'accepte
-- que 200 variables locales dans le corps d'un fichier, et ce panneau est à
-- son plafond (il l'a dépassé le 1er novembre 2026, et plus rien ne se
-- chargeait).
--
-- Les portes, partout en rouge : dans l'arbre comme sur la carte. Les
-- bâtiments, en violet, pour la même raison.
local CREER = {
    porte = { 0.85, 0.45, 0.38 },
    batiment = { 0.70, 0.52, 0.88 },
}
CREER.lettres = {
    { lettre = "L", mot = "Nouveau lieu",     c = { 0.42, 0.80, 0.45 } },
    { lettre = "P", mot = "Nouvelle porte",   c = CREER.porte },
    { lettre = "B", mot = "Nouveau bâtiment", c = CREER.batiment },
}
local M        = 16    -- marge intérieure des fiches
local FIELD_H  = 32

local function Place(control, parent, x, y, w, h)
    control:SetParent(parent); control:ClearAllPoints()
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if w then control:SetWidth(w) end
    if h then control:SetHeight(h) end
end

local function Caption(parent, text, x, y, w)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    Place(fs, parent, x, y, w); fs:SetText(text); fs:SetJustifyH("LEFT")
    UI.ApplyMutedText(fs); return fs
end

local function Label(parent, text, x, y, w)
    local fs = Caption(parent, text, x, y, w)
    UI.ApplyLabel(fs); return fs
end

local function Button(parent, label, x, y, w, h)
    local b = UI.CreatePanelButton(parent, w, h or FIELD_H, label)
    Place(b, parent, x, y); return b
end

-- Suppression : bouton rouge, en bas à droite de la fiche.
local function DangerButton(parent, label, w)
    local b = UI.CreatePanelButton(parent, w, FIELD_H, label)
    b:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -M, 8)
    if b.bgN then b.bgN:SetColorTexture(.30, .05, .05, .95) end
    if b.bgP then b.bgP:SetColorTexture(.45, .08, .08, 1) end
    if b.highlight then b.highlight:SetColorTexture(1, .25, .25, .12) end
    if b.accent then b.accent:SetColorTexture(.90, .30, .30, 1) end
    local fs = b:GetFontString()
    if fs then fs:SetTextColor(1, .62, .58) end
    return b
end

local function EditBox(parent, x, y, w, h, maxLetters)
    local box = UI.CreateStyledEditBox(parent, w, h or FIELD_H, false)
    Place(box, parent, x, y); box:SetMaxLetters(maxLetters or 64)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

local function Checkbox(parent, text, x, y)
    local cb, label = UI.CreateStyledCheckbox(parent, text)
    Place(cb, parent, x, y)
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    return cb, label
end

-- Menu déroulant maison (voir UI.CreateSelect) : dd.items() renvoie
-- { {text=, value=, title=} } et dd.onSelect(value) reçoit le choix.
local function Dropdown(parent, x, y, width)
    local dd = UI.CreateSelect(parent, width, FIELD_H)
    Place(dd, parent, x, y)
    return dd
end

local function SetDropdownEnabled(dd, enabled) dd:SetEnabled(enabled) end

-- Filet de séparation entre deux sections d'une fiche.
local function Rule(parent, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", M, -y)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -M, -y)
    t:SetHeight(1)
    t:SetColorTexture(0.57, 0.46, 0.28, 0.25)
    return t
end

-- ── Panel racine ─────────────────────────────────────────────────────────────

-- Une UI.Fenetre de LCM autour du panneau (UI.Habiller, UI/Crossings/Kit.lua) :
-- cadre A'hell'Raz'kah, titre couronné, croix, place retenue, Échap.
local panel = CreateFrame("Frame", "LCMCrossingsPanel", UIParent)
panel:SetSize(PANEL_W, PANEL_H)
panel:SetFrameStrata("HIGH")
local fenetre = UI.Habiller(panel, "panneau", "Crossings")
fenetre:SousTitre("Pays, régions, lieux, zones et passages")
panel:Hide()

-- ── Taille de la fenêtre ────────────────────────────────────────────────
-- La fenêtre s'agrandit À L'ÉCHELLE, pas en remettant son contenu en page :
-- le panneau est posé en coordonnées absolues, et le reflux de cent widgets
-- serait un autre chantier. On gagne donc de la lisibilité, pas de la place
-- utile — pour la place, la carte a son propre zoom.
-- L'écran reste le plafond : une fenêtre plus grande que lui serait perdue.
-- Une seule table, comme partout ici : le corps du fichier frôle les 200
-- variables locales de Lua 5.1, au-delà desquelles plus rien ne se charge.
local taille = { MIN = 0.55, MAX = 2.0 }

function taille.Voulue()
    return tonumber(LCM_CrossingsChar and LCM_CrossingsChar.panelScale) or 1
end

local function Fit()
    panel:SetScale(math.min(taille.Voulue(),
        (UIParent:GetWidth() - 32) / PANEL_W, (UIParent:GetHeight() - 32) / PANEL_H))
end

function taille.Poser(echelle)
    LCM_CrossingsChar = LCM_CrossingsChar or {}
    LCM_CrossingsChar.panelScale = math.max(taille.MIN, math.min(taille.MAX, echelle))
    Fit()
end
panel.Redimensionner = taille.Poser

panel:HookScript("OnShow", Fit)
panel:RegisterEvent("DISPLAY_SIZE_CHANGED"); panel:SetScript("OnEvent", Fit)
Fit()

-- La poignée du coin, comme n'importe quelle fenêtre redimensionnable : on
-- tire vers la droite pour agrandir. Elle vit sur le CADRE, pas sur le
-- panneau, pour tomber dans le coin de la fenêtre habillée.
taille.grip = CreateFrame("Button", nil, fenetre)
taille.grip:SetSize(16, 16)
taille.grip:SetPoint("BOTTOMRIGHT", fenetre, "BOTTOMRIGHT", -10, 10)
taille.grip:SetFrameLevel(fenetre:GetFrameLevel() + 10)
for i = 1, 3 do
    local t = taille.grip:CreateTexture(nil, "OVERLAY")
    t:SetSize(14 - (i - 1) * 4, 2)
    t:SetRotation(math.pi / 4)
    t:SetPoint("CENTER", taille.grip, "CENTER", (i - 1) * 3, -(i - 1) * 3)
    t:SetColorTexture(0.57, 0.46, 0.28, 0.75)
end
taille.grip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Taille de la fenêtre")
    GameTooltip:AddLine("Tirez pour agrandir. Double-clic : taille d'origine.", 1, 1, 1, true)
    GameTooltip:Show()
end)
taille.grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
taille.grip:RegisterForClicks("AnyUp")
taille.grip:SetScript("OnDoubleClick", function() taille.Poser(1) end)
taille.grip:SetScript("OnMouseDown", function(self)
    local mx = GetCursorPosition()
    local depart = taille.Voulue()
    -- 700 pixels d'écran valent un facteur 1 : assez fin pour viser, assez
    -- large pour doubler la fenêtre d'un seul geste.
    self:SetScript("OnUpdate", function()
        local x = GetCursorPosition()
        taille.Poser(depart + (x - mx) / 700)
    end)
end)
taille.grip:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)

-- ── En-tête ──────────────────────────────────────────────────────────────────
-- Le titre est dans la couronne de la fenêtre ; il ne reste ici que les
-- boutons d'outils.

local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT",  4, -4)
header:SetPoint("TOPRIGHT", -4, -4)
header:SetHeight(HEADER_H - 4)

local themesBtn = UI.CreatePanelButton(header, 174, 22, "Atelier des bannières")
themesBtn:SetPoint("RIGHT", header, "RIGHT", -12, 0)
themesBtn:SetScript("OnClick", function()
    if LCMCrossingsThemePanel then LCMCrossingsThemePanel:Toggle() end
end)

-- Panneau Connaissances : apprendre des noms par lots.
local knowledgeBtn = UI.CreatePanelButton(header, 150, 22, "Connaissances")
knowledgeBtn:SetScript("OnClick", function() ZG:ToggleKnowledge() end)

-- Interrupteur général des auras imposées.
local auraToggleBtn = UI.CreatePanelButton(header, 174, 22, "")
auraToggleBtn:SetPoint("RIGHT", themesBtn, "LEFT", -10, 0)
auraToggleBtn:SetScript("OnClick", function() ZG:SetAurasEnabled(not ZG:AurasEnabled()) end)
auraToggleBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Auras des passages")
    GameTooltip:AddLine("Coupées, aucun passage ne vous impose d'aura et celles déjà posées sont retirées. Réglage propre à ce personnage.", 1, 1, 1, true)
    GameTooltip:Show()
end)
auraToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
function panel:RefreshAuraToggle()
    auraToggleBtn:SetText(ZG:AurasEnabled() and "Auras : actives" or "|cffe6c94dAuras : coupées|r")
end
knowledgeBtn:SetPoint("RIGHT", auraToggleBtn, "LEFT", -10, 0)
panel:HookScript("OnShow", function() panel:RefreshAuraToggle() end)
panel:RefreshAuraToggle()

-- Au-dessus des caches de la minimap du tracé (voir UI_Radar.lua).
local footer = CreateFrame("Frame", nil, panel)
footer:SetAllPoints(); footer:SetFrameLevel(panel:GetFrameLevel() + 3)
Caption(footer, "Modifications enregistrées automatiquement", PAD, PANEL_H - 26, 380)

function panel:Toggle()
    if self.traceWindow and self.traceWindow:IsShown() then self:ExitTrace(); return end
    -- En nomade, la page Carte est sortie du panneau : on la rentre d'abord.
    if self.ModeNomadePays and self.paysBoutons and self.paysBoutons.nomade:GetText()=="Rattacher" then self:ModeNomadePays(false);return end
    if self.carteFenetre and self.carteFenetre:IsShown() then self:ModeNomade(false); return end
    if self:IsShown() then
        self:Hide()
    else
        panel:RefreshAll()
        ZG:MaybeRequestSync()
        self:Show()
    end
end

-- ── État de sélection ──────────────────────────────────────────────────────
-- mode : "country" | "zone" | "place" | nil

panel.mode       = nil
panel.countryId  = nil
panel.zoneId     = nil
panel.placeId    = nil
panel.passageId  = nil
-- On ouvre sur ce qu'on vient voir : la carte d'une région, la zone d'un lieu.
panel.zoneTab    = "carte"
panel.placeTab   = "zone"

-- Accordéon : pays et régions repliés par défaut, « Sans pays » ouvert.
-- Mémorisé par personnage (LCM_CrossingsChar.treeOpen[clé] = true / false).
local function OpenSet()
    LCM_CrossingsChar = LCM_CrossingsChar or {}
    LCM_CrossingsChar.treeOpen = LCM_CrossingsChar.treeOpen or {}
    return LCM_CrossingsChar.treeOpen
end
local function IsOpen(key)
    local value = OpenSet()[key]
    if key == "loose" then return value ~= false end
    return value == true
end
local function SetOpen(key, open) if key then OpenSet()[key] = open and true or false end end

-- Ouvre les parents d'un élément sélectionné pour qu'il reste visible.
local function Reveal(zoneId)
    local zone = ZG:GetZone(zoneId)
    if not zone then return end
    if ZG:GetCountry(zone.countryId) then SetOpen(zone.countryId, true) else SetOpen("loose", true) end
end

local function Select(mode, id, zoneId)
    panel.mode = mode
    if mode == "country" then panel.countryId = id; SetOpen(id, true)
    elseif mode == "zone" then panel.zoneId = id; Reveal(id); SetOpen(id, true)
    elseif mode == "place" then panel.placeId = id; panel.zoneId = zoneId; Reveal(zoneId); SetOpen(zoneId, true) end
    panel:RefreshAll()
end

local function ZoneKnown(zone) return zone.creator == MyName() or ZG:HasLearnedZoneName(zone.id) end
local function PlaceKnown(place, zone) return zone.creator == MyName() or ZG:KnowsPlaceName(place) end
local function ZoneTitle(zone) return ZoneKnown(zone) and (zone.name or "") or ZG:MaskText(zone.name or "") end
local function PlaceTitle(place, zone) return PlaceKnown(place, zone) and (place.name or "") or ZG:MaskText(place.name) end

-- ── Création : toujours confirmée, avec le nom à saisir ──────────────────
-- Évite de créer des dizaines de régions par des clics accidentels.

local prompt = CreateFrame("Frame", "LCMCrossingsCreatePrompt", panel)
local AskCreate
do
prompt:SetSize(420, 178); prompt:SetPoint("CENTER"); prompt:SetFrameStrata("DIALOG")
prompt:EnableMouse(true); UI.Surface(prompt); prompt:Hide()
local promptTitle = Label(prompt, "", M, 16, 388)
local promptHint = Caption(prompt, "", M, 38, 388)
local promptName = EditBox(prompt, M, 64, 388)
local promptError = Caption(prompt, "", M, 102, 388)
local promptCancel = Button(prompt, "Annuler", M, 128, 186)
local promptCreate = Button(prompt, "Créer", 218, 128, 186)
promptCancel:SetScript("OnClick", function() prompt:Hide() end)
promptCreate:SetScript("OnClick", function()
    local name = (promptName:GetText() or ""):match("^%s*(.-)%s*$") or ""
    if name == "" then promptError:SetText("|cffe6c94dDonnez un nom.|r"); return end
    local fn = prompt.onCreate
    prompt:Hide()
    if fn then fn(name) end
end)
promptName:SetScript("OnEnterPressed", function() promptCreate:GetScript("OnClick")(promptCreate) end)
promptName:SetScript("OnEscapePressed", function() prompt:Hide() end)

-- `propose` : un nom déjà écrit dans le champ, qu'on garde ou qu'on remplace.
function AskCreate(title, hint, onCreate, propose)
    promptTitle:SetText(title)
    promptHint:SetText(hint or "")
    promptError:SetText("")
    promptName:SetText(propose or "")
    if propose and promptName.HighlightText then promptName:HighlightText() end
    prompt.onCreate = onCreate
    prompt:Show()
    if promptName.SetFocus then promptName:SetFocus() end
end
panel.createPrompt = prompt
end

-- ── Colonne gauche : Pays › Régions › Lieux ──────────────────────────────

Label(panel, "PAYS, RÉGIONS ET LIEUX", PAD, HEADER_H + 6, LIST_W)

local addCountryBtn = Button(panel, "+ Pays", PAD, HEADER_H + 28, (LIST_W - 10) / 2)
addCountryBtn:SetScript("OnClick", function()
    AskCreate("Créer un nouveau pays ?", "Un pays sert à ranger vos régions.", function(name)
        local country = ZG:CreateCountry(name)
        if country then
            if panel.searchBox then panel.searchBox:SetText("") end
            Select("country", country.id)
        end
    end)
end)

-- Nouvelle région : rangée dans le pays sélectionné (ou celui de la région).
local function CurrentCountryId()
    if panel.mode == "country" then return panel.countryId end
    local zone = ZG:GetZone(panel.zoneId)
    if zone and (panel.mode == "zone" or panel.mode == "place") then return zone.countryId end
end

local function CreateRegion(countryId)
    local country = ZG:GetCountry(countryId)
    if country and country.creator ~= MyName() then country = nil end
    AskCreate("Créer une nouvelle région ?", country and ("Dans le pays « " .. country.name .. " ».") or "Sans pays.", function(name)
        local zone = ZG:CreateZone(name, country and country.id or nil)
        if zone then
            -- Une région toute neuve n'a rien à montrer sur sa carte : on
            -- atterrit sur ses lieux, qui sont le geste suivant.
            panel.zoneTab = "places"
            if panel.searchBox then panel.searchBox:SetText("") end
            Select("zone", zone.id)
        end
    end)
end

-- parentPlaceId (facultatif) : le lieu — ou le bâtiment — qui le contient.
-- Dans un bâtiment, un lieu est une PIÈCE : il hérite de sa tranche
-- d'altitude, sans quoi il déborderait des murs en hauteur.
function CREER.Lieu(zoneId, parentPlaceId)
    local zone = ZG:GetZone(zoneId)
    if not zone then return end
    local parent = parentPlaceId and ZG:FindPlace(parentPlaceId)
    local dansBatiment = parent and ZG:EstBatiment(parent)
    AskCreate(dansBatiment and "Créer une nouvelle pièce ?" or "Créer un nouveau lieu ?",
        (parent and ("Dans « " .. (parent.name or "") .. " ». ") or ("Dans la région « " .. (zone.name or "") .. " ». "))
            .. (dansBatiment
                and "Elle reprend la hauteur du bâtiment ; il ne restera qu'à en poser les sommets."
                or "Sa zone est créée avec lui, sous son nom : il ne restera qu'à en poser les sommets."),
        function(name)
            local place
            if dansBatiment then
                place = ZG:CreateRoomPlace(parent.id, name)
            else
                place = ZG:CreatePlace(zoneId, name)
                if place and parentPlaceId then ZG:SetPlaceParent(place.id, parentPlaceId) end
            end
            -- On atterrit sur sa zone : c'est le geste suivant.
            if place then panel.placeTab = "zone"; Select("place", place.id, zoneId) end
        end)
end

-- Un bâtiment est un lieu dont l'étendue se referme en hauteur : on dessine
-- son sol, puis on dit de combien il monte et descend. Il contient ses
-- pièces comme une région contient ses lieux.
function CREER.Batiment(zoneId, parentPlaceId)
    local zone = ZG:GetZone(zoneId)
    if not zone then return end
    local parent = parentPlaceId and ZG:FindPlace(parentPlaceId)
    AskCreate("Créer un nouveau bâtiment ?",
        (parent and ("Dans « " .. (parent.name or "") .. " ». ") or "")
            .. "On dessine son sol, puis on dit de combien il descend et monte, en yards. Il ne s'étale pas sur la carte de la région : il s'y marque d'un point, et sa propre carte s'ouvre quand on y entre.",
        function(name)
            local place = ZG:CreateBuildingPlace(zoneId, parentPlaceId, name)
            if place then panel.placeTab = "carte"; Select("place", place.id, zoneId) end
        end)
end

-- Une porte est un lieu dont la géométrie est une porte droite. Elle se pose
-- là où se tient le joueur, orientée selon son regard : rien à dessiner.
function CREER.Porte(zoneId, parentPlaceId)
    local zone = ZG:GetZone(zoneId)
    if not zone then return end
    local parent = parentPlaceId and ZG:FindPlace(parentPlaceId)
    AskCreate("Poser une nouvelle porte ?",
        (parent and ("Rangée sous « " .. (parent.name or "") .. " ». ") or "")
            .. "Elle sera placée à votre position et orientée selon votre regard : on entre par le côté vert, on sort par le côté rouge.",
        function(name)
            local place = ZG:CreateDoorPlace(zoneId, parentPlaceId, name)
            if place then panel.placeTab = "zone"; Select("place", place.id, zoneId) end
        end)
end

local addZoneBtn = Button(panel, "+ Région", PAD + (LIST_W + 10) / 2, HEADER_H + 28, (LIST_W - 10) / 2)
addZoneBtn:SetScript("OnClick", function() CreateRegion(CurrentCountryId()) end)

local search = UI.CreateStyledEditBox(panel, LIST_W, FIELD_H, false)
Place(search, panel, PAD, HEADER_H + 72)
local searchHint = Caption(search, "Rechercher un pays, une région, un lieu", 10, 10, LIST_W - 20)
search:SetScript("OnTextChanged", function(self)
    panel.searchText = (self:GetText() or ""):lower()
    searchHint:SetShown(panel.searchText == "")
    panel:RefreshTree()
end)
panel.searchBox = search

local treeScroll = CreateFrame("ScrollFrame", nil, panel)
treeScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 118))
treeScroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, 36)
treeScroll:SetWidth(LIST_W)
treeScroll:EnableMouseWheel(true)

local treeContent = CreateFrame("Frame", nil, treeScroll)
treeContent:SetWidth(LIST_W)
treeContent:SetHeight(1)
treeScroll:SetScrollChild(treeContent)

treeScroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 24)))
end)

-- Sur son propre cadre, au-dessus des caches du tracé (voir UI_Radar.lua).
local sepHolder = CreateFrame("Frame", nil, panel)
sepHolder:SetAllPoints(); sepHolder:SetFrameLevel(panel:GetFrameLevel() + 3)
local listSep = sepHolder:CreateTexture(nil, "ARTWORK")
listSep:SetPoint("TOPLEFT",    panel, "TOPLEFT",    PAD + LIST_W + 12, -(HEADER_H + 4))
listSep:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD + LIST_W + 12, PAD)
listSep:SetWidth(1)
UI.ApplySeparator(listSep, true)

local treeRows = {}
panel.treeRows = treeRows   -- le banc lit les lignes rendues
local treeEmpty = treeContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
treeEmpty:SetPoint("TOPLEFT", 8, -8); treeEmpty:SetWidth(LIST_W - 16)
treeEmpty:SetJustifyH("LEFT"); UI.ApplyMutedText(treeEmpty)

-- ── Glisser-déposer : une région sur un pays, sur « Sans pays », ou sur une
-- autre région pour la ranger dans le même pays. row.dropCountry : id du pays
-- visé, "" pour aucun, nil si la ligne n'accepte rien.
local ghost = CreateFrame("Frame", nil, UIParent)
ghost:SetSize(LIST_W, 26); ghost:SetFrameStrata("TOOLTIP"); UI.Surface(ghost); ghost:Hide()
local ghostText = Caption(ghost, "", 8, 7, LIST_W - 16)

local function DropTarget()
    for _, row in ipairs(treeRows) do
        if row:IsShown() and row.dropCountry and row:IsMouseOver() then return row end
    end
end

ghost:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 14, y / scale - 14)
    local target = DropTarget()
    for _, row in ipairs(treeRows) do row.drop:SetShown(row == target) end
end)

local function StartDrag(row)
    if not row.dragZone then return end
    panel.dragZoneId = row.dragZone
    ghostText:SetText(row.label:GetText())
    ghost:Show()
    panel:RefreshTree()   -- fait apparaître « Sans pays » comme cible
end

local function StopDrag()
    local zoneId = panel.dragZoneId
    if not zoneId then return end
    local target = DropTarget()
    panel.dragZoneId = nil
    ghost:Hide()
    for _, row in ipairs(treeRows) do row.drop:Hide() end
    if target then ZG:SetZoneCountry(zoneId, target.dropCountry ~= "" and target.dropCountry or nil) end
    panel:RefreshAll()
end

-- Apparence de chaque catégorie : hauteur, fond, liseré gauche, texte.
-- Pays : bronze doré ; Sans pays : gris ; région : bleu acier ; lieu : vert.
local TREE_STYLE = {
    country = { h = 38, bg = { 0.110, 0.085, 0.040, 0.95 }, accent = { 0.86, 0.68, 0.30 }, text = { 0.95, 0.80, 0.46 } },
    loose   = { h = 34, bg = { 0.070, 0.070, 0.080, 0.95 }, accent = { 0.48, 0.48, 0.52 }, text = { 0.72, 0.72, 0.75 } },
    zone    = { h = 34, bg = { 0.035, 0.075, 0.105, 0.95 }, accent = { 0.40, 0.64, 0.84 }, text = { 0.82, 0.90, 0.97 } },
    place   = { h = 28, bg = { 0.020, 0.030, 0.040, 0.55 }, dot = { 0.52, 0.82, 0.62 }, text = { 0.84, 0.86, 0.80 } },
    -- Ligne de création : pas de carte, texte vert discret, jamais comptée.
    create  = { h = 28, bg = { 0, 0, 0, 0 }, text = { 0.46, 0.74, 0.50 } },
}
local TREE_GAP   = 10   -- espace entre deux pays (et avant « Sans pays »)
local TREE_NEST  = 12   -- retrait de la carte d'un niveau à l'autre

local function TreeRow(index)
    local row = treeRows[index]
    if row then return row end

    row = CreateFrame("Button", nil, treeContent)
    row:SetSize(LIST_W, ROW_H)

    -- Carte : fond et liseré démarrent au retrait du niveau.
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.accent = row:CreateTexture(nil, "BORDER")
    row.accent:SetWidth(3)
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(5, 5)
    -- Filet entre deux éléments du même type.
    row.rule = row:CreateTexture(nil, "BORDER")
    row.rule:SetHeight(1)
    row.rule:SetColorTexture(0.57, 0.46, 0.28, 0.22)

    row.sel = row:CreateTexture(nil, "ARTWORK")
    row.sel:SetColorTexture(unpack(UI.colors.rowSelection))
    row.sel:Hide()

    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(row.bg)
    hover:SetColorTexture(1, 1, 1, 0.04)

    -- Cible survolée pendant un glisser-déposer.
    row.drop = row:CreateTexture(nil, "ARTWORK")
    row.drop:SetColorTexture(0.90, 0.78, 0.30, 0.25)
    row.drop:Hide()

    -- Clic gauche : action de la ligne ; clic droit : menu contextuel.
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.context then UI.OpenContextMenu(self, self.context) end
        elseif self.leftClick then
            self.leftClick()
        end
    end)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", StartDrag)
    row:SetScript("OnDragStop", StopDrag)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    -- Nombre d'enfants (régions d'un pays, lieux d'une région).
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.count:SetJustifyH("RIGHT")
    UI.ApplyMutedText(row.count)

    -- +/− : déplie ou replie un pays, une région ou « Sans pays ».
    -- Carré sombre au liseré bronze (palette de l'éditeur), distinct du "+" vert de création.
    row.toggle = CreateFrame("Button", nil, row)
    row.toggle:SetSize(16, 16)
    UI.Surface(row.toggle)
    local toggleHover = row.toggle:CreateTexture(nil, "HIGHLIGHT")
    toggleHover:SetAllPoints()
    toggleHover:SetColorTexture(0.90, 0.78, 0.30, 0.18)
    row.toggle.sign = row.toggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.toggle.sign:SetPoint("CENTER", 0, 1)
    UI.ApplyLabel(row.toggle.sign)

    -- "+" : une région dans ce pays, ou un lieu dans cette région.
    row.addBtn = UI.CreateAddButton(row, nil)
    row.addBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)

    -- Trois lettres au bout de la ligne : L un lieu, P une porte, B un
    -- bâtiment. Elles remplacent les lignes « + Nouveau lieu » et « + Porte »
    -- qui se répétaient sous chaque lieu et mangeaient la colonne entière.
    row.creer = {}
    for i, def in ipairs(CREER.lettres) do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(17, 17)
        UI.Surface(b)
        local chaud = b:CreateTexture(nil, "HIGHLIGHT")
        chaud:SetAllPoints()
        chaud:SetColorTexture(def.c[1], def.c[2], def.c[3], 0.22)
        b.sign = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.sign:SetPoint("CENTER", 0, 0)
        b.sign:SetText(def.lettre)
        b.sign:SetTextColor(def.c[1], def.c[2], def.c[3])
        b:SetPoint("RIGHT", row, "RIGHT", -8 - (#CREER.lettres - i) * 20, 0)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.mot or def.mot, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnClick", function(self) if self.faire then self.faire() end end)
        row.creer[i] = b
    end

    treeRows[index] = row
    return row
end

-- Met en forme une ligne selon sa catégorie. inset : retrait de la carte.
local function StyleRow(row, kind, inset, ruled)
    local style = TREE_STYLE[kind]
    row:SetHeight(style.h)
    row.bg:ClearAllPoints()
    row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", inset, 0)
    row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.bg:SetColorTexture(unpack(style.bg))
    for _, overlay in ipairs({ row.sel, row.drop }) do
        overlay:ClearAllPoints(); overlay:SetAllPoints(row.bg)
    end
    row.accent:ClearAllPoints()
    row.accent:SetPoint("TOPLEFT", row.bg, "TOPLEFT", 0, 0)
    row.accent:SetPoint("BOTTOMLEFT", row.bg, "BOTTOMLEFT", 0, 0)
    row.accent:SetShown(style.accent ~= nil)
    if style.accent then row.accent:SetColorTexture(style.accent[1], style.accent[2], style.accent[3], 1) end
    row.dot:SetShown(style.dot ~= nil)
    if style.dot then
        row.dot:ClearAllPoints()
        row.dot:SetPoint("LEFT", row.bg, "LEFT", 14, 0)
        row.dot:SetColorTexture(style.dot[1], style.dot[2], style.dot[3], 1)
    end
    row.rule:ClearAllPoints()
    row.rule:SetPoint("TOPLEFT", row.bg, "TOPLEFT", 10, 0)
    row.rule:SetPoint("TOPRIGHT", row.bg, "TOPRIGHT", -10, 0)
    row.rule:SetShown(ruled)
    row.label:SetTextColor(unpack(style.text))
end

-- Les trois lettres au bout d'une ligne. `place` nil : c'est la région qui
-- reçoit. Dans un bâtiment, un lieu s'appelle une pièce — c'est le même
-- geste, et le même bouton.
function CREER.Lettres(row, zoneId, place, estBatiment)
    local sous = place and place.id or nil
    local mots
    if estBatiment then
        mots = { "Nouvelle pièce", "Nouvelle porte dans ce bâtiment", "Nouveau bâtiment dedans" }
    elseif place then
        mots = { "Nouveau lieu dedans", "Nouvelle porte dedans", "Nouveau bâtiment dedans" }
    else
        mots = { "Nouveau lieu", "Nouvelle porte", "Nouveau bâtiment" }
    end
    local faire = {
        function() CREER.Lieu(zoneId, sous) end,
        function() CREER.Porte(zoneId, sous) end,
        function() CREER.Batiment(zoneId, sous) end,
    }
    for i, b in ipairs(row.creer) do
        b.mot, b.faire = mots[i], faire[i]
        b:Show()
    end
end

local function Matches(text, query)
    return query == "" or ((text or ""):lower():find(query, 1, true) ~= nil)
end

-- Entrées visibles : { kind, depth, country?, zone?, place? }.
local function BuildTree(query)
    local entries = {}
    local searching = query ~= ""
    local function addZone(zone, depth, parentMatched)
        -- Sans recherche, tout s'affiche, y compris les régions au nom encore inconnu.
        local zoneMatched = parentMatched or not searching or (ZoneKnown(zone) and Matches(zone.name, query))
        local places = {}
        for _, place in ipairs(ZG:GetPlaceList(zone.id)) do
            if zoneMatched or (PlaceKnown(place, zone) and Matches(place.name, query)) then places[#places + 1] = place end
        end
        if not zoneMatched and #places == 0 then return end
        local own = zone.creator == MyName()
        local open = searching or IsOpen(zone.id)
        -- Une région vide ne se déplie plus sur rien : ses lignes de création
        -- ont laissé la place aux trois lettres de sa propre ligne.
        entries[#entries + 1] = { kind = "zone", zone = zone, depth = depth, key = zone.id, open = open,
            parent = #places > 0, count = #ZG:GetLieuList(zone.id) }
        if not open then return end
        -- Lieux et portes se rangent SOUS celui qui les contient, décalés d'un
        -- cran, aussi profond qu'on veut : un village dans une forêt, sa
        -- crypte sous son mausolée. Chaque lieu porte son « + Porte ».
        local enfants, visibles = {}, {}
        for _, place in ipairs(places) do visibles[place.id] = true end
        for _, place in ipairs(places) do
            -- Un parent hors de la liste (filtré par la recherche, ou
            -- supprimé) ne doit pas faire disparaître son enfant : il remonte.
            local sous = place.parent
            if sous and not visibles[sous] then sous = nil end
            enfants[sous or ""] = enfants[sous or ""] or {}
            table.insert(enfants[sous or ""], place)
        end

        -- Profondeur bornée : une boucle de rangement est refusée à l'écriture
        -- (ZG:SetPlaceParent), mais un état reçu d'ailleurs pourrait en
        -- porter une, et l'arbre ne doit pas tourner en rond.
        local function poser(parentId, niveau)
            if niveau > depth + 8 then return end
            for _, place in ipairs(enfants[parentId or ""] or {}) do
                entries[#entries + 1] = { kind = "place", zone = zone, place = place, depth = niveau }
                -- Plus de lignes « + Nouveau lieu » / « + Porte » sous chaque
                -- lieu : les trois lettres au bout de la ligne font le même
                -- travail sans répéter deux rangées par niveau.
                if not place.porte then poser(place.id, niveau + 1) end
            end
        end
        poser(nil, depth + 1)
    end

    local countries = ZG:GetCountryList()
    local byCountry, loose = {}, {}
    for _, zone in ipairs(ZG:GetZoneList()) do
        if zone.countryId and ZG:GetCountry(zone.countryId) then
            byCountry[zone.countryId] = byCountry[zone.countryId] or {}
            table.insert(byCountry[zone.countryId], zone)
        else
            loose[#loose + 1] = zone
        end
    end

    for _, country in ipairs(countries) do
        local matched = Matches(country.name, query)
        local start = #entries + 1
        local zones = byCountry[country.id] or {}
        local own = country.creator == MyName()
        local open = searching or IsOpen(country.id)
        entries[start] = { kind = "country", country = country, depth = 0, key = country.id, open = open,
            parent = #zones > 0 or own, count = #zones }
        if open then
            for _, zone in ipairs(zones) do addZone(zone, 1, matched and searching) end
            if own and not searching then
                entries[#entries + 1] = { kind = "create", what = "zone", countryId = country.id, depth = 1 }
            end
        end
        if not matched and #entries == start then entries[start] = nil end
    end

    -- Pendant un glisser-déposer, « Sans pays » reste visible comme cible.
    if #loose > 0 or (panel.dragZoneId and #countries > 0) then
        local depth = 0
        local open = true
        if #countries > 0 then
            open = searching or IsOpen("loose")
            entries[#entries + 1] = { kind = "loose", depth = 0, key = "loose", open = open, parent = #loose > 0, count = #loose }
            depth = 1
        end
        local start = #entries
        if open then
            for _, zone in ipairs(loose) do addZone(zone, depth, false) end
            if depth == 1 and #loose > 0 and not searching then
                entries[#entries + 1] = { kind = "create", what = "zone", depth = 1 }
            end
        end
        if depth == 1 and #entries == start and not panel.dragZoneId and (searching or #loose == 0) then entries[start] = nil end
    end
    return entries
end

-- Lâcher sur une région (ou un de ses lieux) range dans le même pays.
local function ZoneDropCountry(zone)
    local country = ZG:GetCountry(zone.countryId)
    if not country then return "" end
    return country.creator == MyName() and country.id or nil
end

function panel:RefreshTree()
    local query = panel.searchText or ""
    local entries = BuildTree(query)
    local y = 0
    local zonesSeen = {}   -- [groupe] = true : une région a déjà été posée dans ce groupe

    for i, entry in ipairs(entries) do
        local row = TreeRow(i)
        local previous = entries[i - 1]

        -- Respiration entre deux blocs, filet entre deux éléments identiques.
        if (entry.kind == "country" or entry.kind == "loose") and i > 1 then y = y + TREE_GAP end
        local group = entry.zone and (entry.zone.countryId or "loose")
        local ruled = (entry.kind == "zone" and zonesSeen[group])
            or (entry.kind == "place" and previous and previous.kind == "place")
        if entry.kind == "zone" then zonesSeen[group] = true end

        local inset = entry.depth * TREE_NEST
        StyleRow(row, entry.kind, inset, ruled and true or false)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", treeContent, "TOPLEFT", 0, -y)
        row:Show()
        y = y + row:GetHeight()

        local textX = inset + 12
        row.toggle:ClearAllPoints()
        row.toggle:SetPoint("LEFT", row, "LEFT", textX, 0)
        -- Pendant une recherche, tout est déplié : pas de +/−.
        row.toggle:SetShown(entry.parent == true and query == "")
        row.toggle.sign:SetText(entry.open and "−" or "+")
        row.toggle:SetScript("OnClick", function() SetOpen(entry.key, not entry.open); panel:RefreshTree() end)
        if entry.kind == "place" then textX = textX + 14 elseif entry.kind ~= "create" then textX = textX + 24 end

        row.addBtn:Hide()
        row.leftClick, row.context = nil, nil
        row.dragZone, row.dropCountry = nil, nil
        for _, b in ipairs(row.creer) do b:Hide(); b.faire, b.mot = nil, nil end
        -- En toutes lettres : « 2 régions », « 1 lieu ».
        local n = entry.count or 0
        local noun = entry.kind == "zone" and (n > 1 and "lieux" or "lieu") or (n > 1 and "régions" or "région")
        row.count:SetText(n > 0 and (n .. " " .. noun) or "")

        if entry.kind == "country" then
            local country = entry.country
            local own = country.creator == MyName()
            row.label:SetText(string.upper(country.name or "") .. (own and "" or "  |cff888888(" .. country.creator .. ")|r"))
            row.sel:SetShown(panel.mode == "country" and panel.countryId == country.id)
            row.dropCountry = own and country.id or nil
            row.leftClick = function() Select("country", country.id) end
            if own then
                row.context = {
                    { text = country.name, title = true },
                    { text = "Ouvrir", func = row.leftClick },
                    { text = "Nouvelle région ici", func = function() CreateRegion(country.id) end },
                    { text = "Supprimer le pays…", func = function() panel:DeleteCountry(country.id) end },
                }
            end
        elseif entry.kind == "loose" then
            row.label:SetText("SANS PAYS")
            row.sel:Hide()
            row.dropCountry = ""
            row.leftClick = function() SetOpen("loose", not entry.open); panel:RefreshTree() end
        elseif entry.kind == "zone" then
            local zone = entry.zone
            local own = zone.creator == MyName()
            row.label:SetText(ZoneTitle(zone) .. (own and "" or "  |cff888888(" .. zone.creator .. ")|r"))
            if not ZoneKnown(zone) then row.label:SetTextColor(0.55, 0.55, 0.57) end
            row.sel:SetShown(panel.mode == "zone" and panel.zoneId == zone.id)
            row.leftClick = function() Select("zone", zone.id) end
            row.dragZone = own and zone.id or nil
            row.dropCountry = ZoneDropCountry(zone)
            if own and query == "" then
                CREER.Lettres(row, zone.id, nil, nil)
            end
            if own then
                row.context = {
                    { text = zone.name, title = true },
                    { text = "Ouvrir", func = row.leftClick },
                    { text = "Nouveau lieu ici", func = function() CREER.Lieu(zone.id) end },
                    { text = "Supprimer la région…", func = function() panel:DeleteRegion(zone.id) end },
                }
            end
        elseif entry.kind == "create" then
            row.sel:Hide()
            if entry.what == "zone" then
                row.label:SetText("+  Nouvelle région")
                row.leftClick = function() CreateRegion(entry.countryId) end
            elseif entry.what == "porte" then
                row.label:SetText("|cffd98b7a+  Porte|r")
                row.leftClick = function()
                    CREER.Porte(entry.zone.id, entry.parentPlace and entry.parentPlace.id or nil)
                end
            else
                row.label:SetText("+  Nouveau lieu")
                row.leftClick = function() CREER.Lieu(entry.zone.id) end
            end
        else
            local place, zone = entry.place, entry.zone
            local text = PlaceTitle(place, zone)
            if ZG:IsInPlace(place.id) then text = text .. "  |cff66e673(vous y êtes)|r" end
            row.label:SetText(text)
            -- Une porte se reconnaît à sa couleur, ici comme sur la carte :
            -- elle ne se règle pas du tout comme un lieu.
            if place.porte then row.label:SetTextColor(unpack(CREER.porte))
            elseif place.batiment then row.label:SetTextColor(unpack(CREER.batiment)) end
            if not PlaceKnown(place, zone) then row.label:SetTextColor(0.55, 0.55, 0.57) end
            row.sel:SetShown(panel.mode == "place" and panel.placeId == place.id)
            row.leftClick = function() Select("place", place.id, zone.id) end
            row.dropCountry = ZoneDropCountry(zone)
            -- Une porte ne contient rien : pas de lettres au bout de sa ligne.
            if zone.creator == MyName() and query == "" and not place.porte then
                CREER.Lettres(row, zone.id, place, ZG:EstBatiment(place))
            end
            if zone.creator == MyName() then
                row.context = {
                    { text = place.name, title = true },
                    { text = "Ouvrir", func = row.leftClick },
                    { text = place.porte and "Supprimer la porte…"
                        or (place.batiment and "Supprimer le bâtiment…" or "Supprimer le lieu…"),
                      func = function() panel:DeletePlace(place.id) end },
                }
            end
        end

        row.count:ClearAllPoints()
        local marge = -10
        if row.creer[1]:IsShown() then marge = -8 - #CREER.lettres * 20 - 4
        elseif row.addBtn:IsShown() then marge = -32 end
        row.count:SetPoint("RIGHT", row, "RIGHT", marge, 0)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", textX, 0)
        row.label:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
    end

    for i = #entries + 1, #treeRows do treeRows[i]:Hide() end
    treeContent:SetHeight(math.max(1, y))
    local empty = #ZG:GetZoneList() == 0 and #ZG:GetCountryList() == 0
    treeEmpty:SetText(empty and "Rien pour l'instant.\nCréez un pays ou une région ci-dessus." or "Aucun résultat.")
    treeEmpty:SetShown(#entries == 0)
    treeScroll:SetVerticalScroll(math.min(treeScroll:GetVerticalScroll(), math.max(0, y - treeScroll:GetHeight())))
end
panel.RefreshZoneTree = panel.RefreshTree

-- ── Découverte : résumé et accès au tableau « Qui connaît quoi » ─────────

local function BuildDiscovery(parent, y, titleText)
    local frame = CreateFrame("Frame", nil, parent)
    Place(frame, parent, M, y, FORM_W - 2 * M, 110)
    Label(frame, titleText, 0, 0, FORM_W - 2 * M)
    frame.summary = Caption(frame, "", 0, 20, FORM_W - 2 * M)
    frame.summary:SetHeight(30)
    frame.openBtn = Button(frame, "Gérer les connaissances…", 0, 56, 260)
    return frame
end

-- ── Onglets ──────────────────────────────────────────────────────────────

-- Un onglet peut se cacher : `tabs[clé].cache = true`, et les autres se
-- repartagent la largeur sans laisser de trou. C'est ce qui permet à un
-- bâtiment d'avoir sa Carte — celle de ses pièces — là où un lieu ordinaire
-- n'en a pas besoin, sans rétrécir les onglets de tout le monde.
local function Tabs(parent, entries, getter, setter)
    local tabs, pages, ordre = {}, {}, {}
    for i, entry in ipairs(entries) do
        local key = entry[1]
        local page = CreateFrame("Frame", nil, parent)
        Place(page, parent, 0, PAGE_Y, FORM_W, PANEL_H - HEADER_H - 42 - PAGE_Y)
        pages[key] = page
        local tab = Button(parent, entry[2], M, 100, 10)
        tab:SetScript("OnClick", function() setter(key); panel:RefreshForm() end)
        tabs[key] = tab
        ordre[i] = key
    end
    local function show()
        local current = getter()
        local visibles = {}
        for _, key in ipairs(ordre) do
            if not tabs[key].cache then visibles[#visibles + 1] = key end
        end
        local w = (FORM_W - 2 * M - (#visibles - 1) * 10) / math.max(1, #visibles)
        for i, key in ipairs(visibles) do
            Place(tabs[key], parent, M + (i - 1) * (w + 10), 100, w)
            tabs[key]:Show()
        end
        for _, key in ipairs(ordre) do
            if tabs[key].cache then tabs[key]:Hide() end
        end
        for key, page in pairs(pages) do
            page:SetShown(key == current)
            if tabs[key].accent then tabs[key].accent:SetShown(key == current) end
        end
    end
    return pages, tabs, show
end

-- ── Colonne droite ──────────────────────────────────────────────────────────

local form = CreateFrame("Frame", nil, panel)
form:SetPoint("TOPLEFT",     panel, "TOPLEFT",     PAD + LIST_W + 24, -(HEADER_H + 6))
form:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, 36)

local placeholder = Caption(form, "VOS LIEUX, LEURS ZONES ET LEURS PASSAGES\n\n" ..
    "1. Créez un pays pour ranger vos régions (facultatif), puis une région.\n\n" ..
    "2. Dans la région, créez ses lieux : leur nom, leur bannière et leurs effets.\n\n" ..
    "3. Dessinez la zone d'un lieu : son contour, sommet par sommet, en vous déplaçant en jeu. L'onglet Carte de la région les montre toutes et sert à les coller entre elles.\n\n" ..
    "4. Un passage, lui, est une porte : un point, une largeur, le lieu atteint en entrant et celui atteint en sortant.",
    16, 24, FORM_W - 32)

-- Confirmation des suppressions : un second clic explicite.
local confirm = CreateFrame("Frame", "LCMCrossingsDeleteConfirm", UIParent)
confirm:SetSize(360, 132); confirm:SetPoint("CENTER"); confirm:SetFrameStrata("DIALOG")
confirm:EnableMouse(true); UI.Surface(confirm); confirm:Hide()
local confirmText = Caption(confirm, "", 16, 16, 328)
local cancel = Button(confirm, "Annuler", 16, 86, 146, 28)
local accept = Button(confirm, "Confirmer la suppression", 170, 86, 174, 28)
cancel:SetScript("OnClick", function() confirm:Hide() end)
accept:SetScript("OnClick", function() local fn = confirm.action; confirm:Hide(); if fn then fn() end end)
local function Confirm(text, action)
    confirmText:SetText(text); confirm.action = action; confirm:Show()
end

-- ── Suppressions ──────────────────────────────────────────────────────────

function panel:DeleteCountry(id)
    Confirm("Supprimer ce pays ? Ses régions sont conservées, sans pays.", function()
        ZG:RemoveCountry(id)
        if panel.mode == "country" and panel.countryId == id then panel.mode = nil end
        panel:RefreshAll()
    end)
end

function panel:DeletePlace(id)
    -- Dire ce qui part avec lui : un tracé est du travail, et le chiffre est
    -- la seule chose qui distingue « supprimer un lieu vide » de « jeter deux
    -- heures de relevé ».
    local zones, sommets = ZG:PlaceEmporterait(id)
    local avec = zones > 0
        and string.format(" Ses %d zone(s) et leurs %d sommet(s) partent avec lui.", zones, sommets)
        or " Il n'a aucune zone à lui."
    Confirm("Supprimer ce lieu ?" .. avec .. " Les passages qui y menaient ne mèneront plus nulle part.", function()
        local _, zone = ZG:FindPlace(id)
        ZG:RemovePlace(id)
        if panel.mode == "place" and panel.placeId == id then
            panel.mode = zone and "zone" or nil; panel.zoneTab = "carte"
        end
        panel:RefreshAll()
    end)
end

-- Supprimer une région qui a des lieux : un tableau, une ligne par lieu,
-- pour choisir où le ranger (une autre de mes régions) ou ne pas le garder.
-- Rien ne change avant « Exécuter ».
local reassign = CreateFrame("Frame", "LCMCrossingsRegionDelete", panel)
do
local KEEP_NONE = "Ne pas garder"
local DELETE_ROWS = 7
reassign:SetSize(600, 150 + DELETE_ROWS * 40 + 60); reassign:SetPoint("CENTER")
reassign:SetFrameStrata("DIALOG"); reassign:EnableMouse(true); reassign:EnableMouseWheel(true)
UI.Surface(reassign); reassign:Hide()
local reassignTitle = Label(reassign, "", M, 16, 568)
local reassignHint = Caption(reassign, "", M, 38, 568)
reassignHint:SetHeight(30)
Label(reassign, "Tout affecter à", M, 80, 200)
local reassignAll = Dropdown(reassign, 200, 72, 384)
Rule(reassign, 116)
local reassignRows = {}
for i = 1, DELETE_ROWS do
    local y = 128 + (i - 1) * 40
    local name = Caption(reassign, "", M + 4, y + 9, 170)
    UI.ApplyBodyText(name)
    local choice = Dropdown(reassign, 200, y, 384)
    reassignRows[i] = { name = name, choice = choice }
end
local reassignMore = Caption(reassign, "", M, 128 + DELETE_ROWS * 40, 568)
local reassignCancel = Button(reassign, "Annuler", M, 128 + DELETE_ROWS * 40 + 24, 270)
local reassignRun = Button(reassign, "Exécuter", 600 - M - 270, 128 + DELETE_ROWS * 40 + 24, 270)
reassignCancel:SetScript("OnClick", function() reassign:Hide() end)
panel.reassign = reassign

-- Mes autres régions, cibles possibles.
local function TargetItems(zoneId)
    local items = { { text = KEEP_NONE, value = "" } }
    for _, zone in ipairs(ZG:GetZoneList()) do
        if zone.id ~= zoneId and zone.creator == MyName() then
            local country = ZG:GetCountry(zone.countryId)
            items[#items + 1] = { text = (country and (country.name .. " > ") or "") .. zone.name, value = zone.id }
        end
    end
    return items
end

local function TargetText(zoneId)
    local zone = ZG:GetZone(zoneId)
    if not zone then return KEEP_NONE end
    local country = ZG:GetCountry(zone.countryId)
    return (country and (country.name .. " > ") or "") .. zone.name
end

function reassign:Render()
    for i, row in ipairs(reassignRows) do
        local place = self.places[i + self.offset]
        row.name:SetShown(place ~= nil); row.choice:SetShown(place ~= nil)
        if place then
            row.name:SetText(place.name or "")
            row.choice:SetText(TargetText(self.targets[place.id]))
            row.choice.items = function() return TargetItems(self.zoneId) end
            row.choice.onSelect = function(value) self.targets[place.id] = value ~= "" and value or nil end
        end
    end
    local total = #self.places
    reassignMore:SetText(total > DELETE_ROWS and string.format("Molette pour faire défiler · %d lieux", total) or "")
end

reassign:SetScript("OnMouseWheel", function(self, delta)
    self.offset = math.max(0, math.min(math.max(0, #self.places - DELETE_ROWS), self.offset - delta))
    self:Render()
end)

reassignAll.onSelect = function(value)
    for _, place in ipairs(reassign.places) do reassign.targets[place.id] = value ~= "" and value or nil end
    reassign:Render()
end

reassignRun:SetScript("OnClick", function()
    local zoneId, targets = reassign.zoneId, reassign.targets
    reassign:Hide()
    for placeId, target in pairs(targets) do ZG:MovePlace(placeId, target) end
    ZG:RemoveZone(zoneId)
    if panel.zoneId == zoneId then panel.mode = nil end
    panel:RefreshAll()
end)

function panel:DeleteRegion(zoneId)
    local zone = ZG:GetZone(zoneId)
    if not zone or zone.creator ~= MyName() then return end
    local places = ZG:GetPlaceList(zoneId)
    local passages = #ZG:GetPassageList(zoneId)
    if #places == 0 then
        Confirm(string.format("Supprimer la région « %s », ses %d zone(s) et passage(s) ?", zone.name or "", passages), function()
            ZG:RemoveZone(zoneId)
            if panel.zoneId == zoneId then panel.mode = nil end
            panel:RefreshAll()
        end)
        return
    end
    reassign.zoneId, reassign.places, reassign.targets, reassign.offset = zoneId, places, {}, 0
    reassignTitle:SetText("Supprimer la région « " .. (zone.name or "") .. " »")
    reassignHint:SetText(string.format("Ses %d zone(s) et passage(s) seront supprimés. Choisissez où ranger chaque lieu, ou ne pas le garder, puis « Exécuter ».", passages))
    reassignAll.items = function() return TargetItems(zoneId) end
    reassignAll:SetText("Choisir pour tous les lieux…")
    reassign:Render()
    reassign:Show()
end
end

-- Liste des thèmes pour un menu de bannière.
local function ThemeItems(inherit)
    local items = { { text = inherit, value = "" } }
    for _, theme in ipairs(ZG:GetThemeList()) do items[#items + 1] = { text = theme.name, value = theme.id } end
    return items
end

local function EditTheme(themeId)
    if not LCMCrossingsThemePanel then return end
    if themeId then LCMCrossingsThemePanel:EditTheme(themeId) else LCMCrossingsThemePanel:Toggle() end
end

-- ── Les gestes d'une carte ──────────────────────────────────────────────────
-- Souder deux sommets, les séparer, revenir en arrière : les mêmes gestes sur
-- la carte d'une région — où ils collent deux zones — et sur celle d'un pays,
-- où ils collent deux RÉGIONS. Un seul jeu de boutons posé deux fois, plutôt
-- que deux copies qui finiraient par diverger.
--
-- Tout tient dans UNE table : Lua 5.1 n'accepte que 200 variables locales dans
-- le corps d'un fichier, et ce panneau en frôle le plafond.
local Gestes = {}

-- c : la table de la carte (c.map, c.hint, c.repos, c.etranger). Les boutons
-- s'y rangent. y : la ligne du premier rang, le second 40 plus bas.
function Gestes.Poser(c, page, y)
    c.fit = Button(page, "Vue d'ensemble", M, y, 160)
    c.fit:SetScript("OnClick", function() c.map:Fit(); c.map:Draw() end)
    c.weld = Button(page, "Les confondre comme une frontière", M + 168, y, 282)
    c.unweld = Button(page, "Séparer", M + 458, y, 120)
    c.clear = Button(page, "Désélectionner", M, y + 40, 160)
    c.clear:SetScript("OnClick", function() c.map:Deselectionner() end)
    -- Un sommet lâché au mauvais endroit ne se remet pas à la main : il
    -- faudrait retrouver ses coordonnées au yard près.
    c.undo = Button(page, "Annuler le dernier changement", M + 168, y + 40, 282)
    c.undo:SetScript("OnClick", function()
        local quoi = c.map:Annuler()
        panel:RefreshAll()
        if quoi then c.hint:SetText("|cff66e673Annulé : " .. quoi .. ".|r") end
    end)

    c.weld:SetScript("OnClick", function()
        local a, b = c.map:Cotes()
        if not a or not b then return end
        -- Avant de souder : où étaient les sommets, et à quoi ils tenaient.
        local avant = c.map:Instantane(c.map.sel)
        local couples = ZG:WeldSeam(a.id, a.index, b.id, b.index)
        if not couples then
            c.hint:SetText("|cffe6c94dImpossible : il faut autant de sommets de chaque côté, les deux contours sur la même carte du jeu, et tous deux de votre main.|r")
            return
        end
        local subA, subB = ZG:FindSubZone(a.id), ZG:FindSubZone(b.id)
        c.hint:SetText(string.format("|cff66e673%d sommet(s) de « %s » rejoignent « %s ». Déplacer l'un déplacera l'autre.|r",
            #couples, subB and subB.name or "?", subA and subA.name or "?"))
        c.map:Empiler(avant, "la frontière posée")
        c.map:Oublier()
        panel:RefreshAll()
    end)

    c.unweld:SetScript("OnClick", function()
        local avant = c.map:Instantane(c.map.sel)
        local defaits = 0
        for _, s in ipairs(c.map.sel) do
            if ZG:UnweldPoint(s.subId, s.index) then defaits = defaits + 1 end
        end
        if defaits > 0 then c.map:Empiler(avant, "la séparation des sommets") end
        c.hint:SetText(defaits > 0
            and string.format("%d sommet(s) ne se confondent plus.", defaits)
            or "Aucun des sommets choisis n'était soudé.")
        c.map:Oublier()
        panel:RefreshAll()
    end)
end

-- Ce que les boutons disent de la sélection : d'abord ce qu'il reste à faire
-- pour souder, puis ce qu'on peut faire de ce qui est choisi.
function Gestes.Dire(c, own)
    if not c.weld then return end
    local a, b, cotes = c.map:Cotes()
    local soudes = 0
    for _, s in ipairs(c.map.sel) do
        local sub = ZG:FindSubZone(s.subId)
        local point = sub and sub.points and sub.points[s.index]
        if point and point.weld then soudes = soudes + 1 end
    end
    local pret = own and a ~= nil and b ~= nil and #a.index == #b.index

    c.weld:SetEnabled(pret and true or false)
    c.unweld:SetEnabled(own and soudes > 0)
    c.clear:SetEnabled(#c.map.sel > 0)
    local annulable = own and c.map:Annulable() or nil
    c.undo:SetEnabled(annulable ~= nil)
    c.undo:SetText(annulable and ("Annuler : " .. annulable) or "Annuler le dernier changement")
    c.weld:SetText(pret
        and string.format("Les confondre comme une frontière (%d)", #a.index)
        or "Les confondre comme une frontière")

    if not own then
        c.hint:SetText(c.etranger or "")
    elseif #c.map.sel == 0 then
        c.hint:SetText(c.repos or "")
    elseif cotes == 1 then
        c.hint:SetText(string.format("%d sommet(s) d'un seul contour. Choisissez-en autant sur le contour voisin.", #c.map.sel))
    elseif cotes and cotes > 2 then
        c.hint:SetText("|cffe6c94dTrois contours ou plus : une frontière se pose entre deux à la fois.|r")
    elseif not pret then
        c.hint:SetText(string.format("|cffe6c94d%d sommet(s) d'un côté, %d de l'autre : il en faut autant des deux.|r", #a.index, #b.index))
    else
        local subA, subB = ZG:FindSubZone(a.id), ZG:FindSubZone(b.id)
        c.hint:SetText(string.format("Prêt : %d sommet(s) de « %s » rejoindront « %s » (la première désignée fait foi).",
            #b.index, subB and subB.name or "?", subA and subA.name or "?"))
    end
end

-- ── Fiche Pays ──────────────────────────────────────────────────────────────

local countryForm = CreateFrame("Frame", nil, form)
countryForm:SetAllPoints()
Label(countryForm, "PAYS", M, 4, FORM_W - 2 * M)
local countryName = EditBox(countryForm, M, 24, FORM_W - 2 * M)
countryName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "country" then return end
    ZG:RenameCountry(panel.countryId, self:GetText())
    panel:RefreshTree()
end)
local countryInfo = Caption(countryForm, "", M + 2, 74, FORM_W - 2 * M)
local countryAdd = Button(countryForm, "+ Nouvelle région dans ce pays", M, 140, 300)
countryAdd:SetScript("OnClick", function() CreateRegion(panel.countryId) end)
local countryDelete = DangerButton(countryForm, "Supprimer le pays", 220)
countryDelete:SetScript("OnClick", function() panel:DeleteCountry(panel.countryId) end)
-- Remonté sur la ligne de « + Nouvelle région » : le bas de la fiche revient
-- aux boutons de la carte, qui servent, eux, à chaque geste.
countryDelete:ClearAllPoints()
Place(countryDelete, countryForm, FORM_W - M - 220, 140)

-- La carte du pays : toutes les zones de toutes ses régions, une couleur par
-- RÉGION — la vraie carte des régions. Même outil que celle d'une région, et
-- donc mêmes gestes : glisser un sommet, clic droit pour en ajouter un,
-- souder deux sommets. C'est ici qu'on colle deux RÉGIONS l'une à l'autre.
local pays = { H = 400 }
pays.map = ZG.CreateZoneMap(countryForm, FORM_W - 2 * M, pays.H, {
    Regions = function()
        local liste = {}
        for _, zone in ipairs(ZG:GetZoneList()) do
            if zone.countryId == panel.countryId then liste[#liste + 1] = zone end
        end
        return liste
    end,
    OuvrirZone = function(sub, zone)
        if not sub or not zone then return end
        -- Depuis un pays, le nom d'une zone ouvre sa RÉGION : on descend d'un
        -- cran, on ne saute pas jusqu'au lieu.
        if pays.detache then panel:ModeNomadePays(false) end
        panel.passageId = sub.id
        panel.zoneTab = "carte"
        Select("zone", zone.id)
    end,
    Change = function() Gestes.Dire(pays, pays.own) end,
})
Place(pays.map, countryForm, M, 185)
panel.paysMap = pays.map
pays.hint = Caption(countryForm, "", M, 185 + pays.H + 6, FORM_W - 2 * M)
pays.hint:SetHeight(34); pays.hint:SetJustifyV("TOP")
pays.repos = "Glissez un sommet pour le déplacer, clic droit sur une arête pour en ajouter un, clic droit dans le vide pour tout désélectionner. Le nom d'une zone ouvre sa région.\nPour coller deux régions : cliquez autant de sommets de l'une que de sa voisine, puis « Les confondre »."
pays.etranger = "Pays d'un autre auteur : la carte se regarde, elle ne se modifie pas."
Gestes.Poser(pays, countryForm, 185 + pays.H + 44)
panel.paysBoutons = { fit = pays.fit, weld = pays.weld, unweld = pays.unweld,
                      clear = pays.clear, undo = pays.undo, hint = pays.hint }

pays.nomade=Button(countryForm,"Nomade",M+458,185+pays.H+84,120,26)
function panel:ModeNomadePays(actif)
    if actif==nil then actif=not pays.detache end
    if actif then
        if not ZG:GetCountry(self.countryId) then return end
        if not pays.fenetre then
            pays.fenetre=LCM.UI.Fenetre("crossings-pays-nomade","CARTE DU PAYS",FORM_W+32,780)
            pays.fenetre:HookScript("OnHide",function() if pays.detache then panel:ModeNomadePays(false) end end)
        end
        pays.detache=true
        Place(countryForm,pays.fenetre,16,64,FORM_W,700)
        pays.fenetre:SetScale(panel:GetScale());pays.fenetre:Show()
        countryForm:Show();panel:Hide();pays.nomade:SetText("Rattacher")
    else
        pays.detache=false
        countryForm:SetParent(form);countryForm:ClearAllPoints();countryForm:SetAllPoints(form)
        if pays.fenetre then pays.fenetre:Hide() end
        pays.nomade:SetText("Nomade");panel:Show();panel:RefreshAll()
    end
end
pays.nomade:SetScript("OnClick",function() panel:ModeNomadePays() end)
panel.paysBoutons.nomade=pays.nomade

local function RefreshCountryForm()
    local country = ZG:GetCountry(panel.countryId)
    local own = country.creator == MyName()
    panel.suppressEvents = true
    countryName:SetText(country.name or "")
    panel.suppressEvents = false
    countryName:SetEnabled(own)
    local n = 0
    for _, zone in ipairs(ZG:GetZoneList()) do if zone.countryId == country.id then n = n + 1 end end
    countryInfo:SetText(string.format("%d région(s). Un pays sert seulement à ranger vos régions : il n'apparaît pas dans la bannière.\nGlissez une région de la liste de gauche sur un pays pour l'y ranger.%s",
        n, own and "" or "\nAuteur : " .. country.creator))
    countryAdd:SetShown(own)
    countryDelete:SetShown(own)

    -- La vue se cadre une fois par pays : la refaire à chaque rafraîchissement
    -- annulerait le zoom en cours.
    if pays.map.cadree ~= country.id then
        pays.map.cadree = country.id
        pays.map:Fit()
    end
    pays.map:Draw()
    -- Sans région, il n'y a rien à montrer ni à souder : la carte et ses
    -- boutons s'effacent au lieu de rester vides.
    pays.map:SetShown(n > 0)
    pays.hint:SetShown(n > 0)
    for _, b in ipairs({ pays.fit, pays.weld, pays.unweld, pays.clear, pays.undo }) do
        b:SetShown(n > 0)
    end
    pays.own = own
    Gestes.Dire(pays, own)
end

-- ── Fiche Région ────────────────────────────────────────────────────────────

local zoneForm = CreateFrame("Frame", nil, form)
zoneForm:SetAllPoints()
Label(zoneForm, "RÉGION", M, 4, 200)
local zoneName = EditBox(zoneForm, M, 24, FORM_W - 2 * M - 268)
zoneName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "zone" then return end
    ZG:RenameZone(panel.zoneId, self:GetText())
    panel:RefreshTree()
end)
Label(zoneForm, "Pays", FORM_W - M - 252, 4, 252)
local zoneCountry = Dropdown(zoneForm, FORM_W - M - 252, 24, 252)
zoneCountry.items = function()
    local items = { { text = "(Sans pays)", value = "" } }
    for _, country in ipairs(ZG:GetCountryList()) do
        if country.creator == MyName() then items[#items + 1] = { text = country.name, value = country.id } end
    end
    return items
end
zoneCountry.onSelect = function(value)
    ZG:SetZoneCountry(panel.zoneId, value ~= "" and value or nil)
    panel:RefreshTree()
end
local zoneStatus = Caption(zoneForm, "", M + 2, 70, FORM_W - 2 * M)

-- Une ZONE est une étendue dessinée (on est dedans ou dehors), un PASSAGE une
-- porte droite (on la traverse). Elles partageaient un onglet « Passages » où
-- il fallait deviner, dans une liste, laquelle était laquelle.
--
-- La région n'a plus d'onglet Zones : une zone appartient à un lieu et se
-- règle dans sa fiche. Celle qui ne mène à aucun lieu se rattache depuis la
-- carte (voir carte.rattacher).
local zonePages, zoneTabs, ShowZoneTab = Tabs(zoneForm,
    { { "carte", "Carte" }, { "places", "Lieux" }, { "aura", "Aura" },
      { "doors", "Passages" }, { "settings", "Bannière" } },
    function() return panel.zoneTab end, function(key) panel.zoneTab = key end)
panel.zonePages = zonePages

-- Onglet Lieux : la base de données de la région.
local placesPage = zonePages.places
Caption(placesPage, "Chaque lieu porte son nom, sa bannière et ses effets. Les zones et les passages des onglets suivants y mènent.", M, 0, FORM_W - 2 * M)
local addPlaceBtn = Button(placesPage, "+ Nouveau lieu", M, 30, 220)
addPlaceBtn:SetScript("OnClick", function()
    CREER.Lieu(panel.zoneId)
end)
local placesEmpty = Caption(placesPage, "Aucun lieu. Créez-en un, par exemple « Le bois des Anciens ».", M, 92, FORM_W - 2 * M)
local placeButtons = {}
local MAX_PLACE_ROWS = 9
for i = 1, MAX_PLACE_ROWS do
    local b = Button(placesPage, "", M, 84 + (i - 1) * 42, FORM_W - 2 * M, 34)
    b:Hide(); placeButtons[i] = b
end
local placesMore = Caption(placesPage, "", M, 84 + MAX_PLACE_ROWS * 42, FORM_W - 2 * M)

-- L'éditeur de géométrie, UNE fois pour trois emplacements : l'onglet Zones
-- et l'onglet Passages de la région, et l'onglet Zone d'un lieu. Il déménage
-- (geoPage change de parent au rafraîchissement) plutôt que d'exister en
-- trois exemplaires qu'il faudrait corriger trois fois.
--
-- `panel.geoScope` dit ce que la liste propose :
--   "doors" → les passages droits de la région
--   "place" → les zones qui mènent au lieu ouvert
local geoPage = CreateFrame("Frame", nil, zoneForm)
geoPage:SetAllPoints(zonePages.doors)
geoPage:Hide()   -- RefreshGeoEditor le pose dans l'onglet voulu et le montre
panel.geoScope = "place"

-- Dans la fiche d'un lieu : TOUTE sa géométrie, quelle que soit sa forme.
-- Un lieu a une étendue dessinée, une porte a une porte droite — la même
-- page les montre, elle s'adapte à la forme de ce qu'elle tient.
local function GeoList()
    if panel.geoScope == "doors" then return ZG:GetDoorList(panel.zoneId) end
    -- Chacun sa forme : la fiche d'un lieu montre son étendue, celle d'une
    -- porte montre sa porte droite. Un vieux passage droit qui mène au lieu
    -- n'est PAS sa géométrie — il se règle dans l'onglet Passages.
    local place = ZG:FindPlace(panel.placeId)
    local veutPolygone = not (place and place.porte)
    local liste, vus = {}, {}
    for _, entry in ipairs(ZG:GetPlacePassages(panel.placeId)) do
        local sub = entry.sub
        if entry.which == "enter" and not vus[sub.id]
            and ((sub.shape == "polygon") == veutPolygone) then
            vus[sub.id] = true; liste[#liste + 1] = sub
        end
    end
    return liste
end
-- Le mot suit la FORME de ce qu'on édite, pas l'onglet : la fiche d'une porte
-- parle de porte, celle d'un lieu parle de zone.
local function GeoMot()
    local sub = ZG:FindSubZone(panel.passageId)
    if sub then return sub.shape == "polygon" and "zone" or "porte" end
    return panel.geoScope == "doors" and "passage" or "zone"
end

local geoLabel = Label(geoPage, "Zone", M, 0, 200)
local passagePicker = Dropdown(geoPage, M, 20, 340)
passagePicker.items = function()
    local items = {}
    for _, sub in ipairs(GeoList()) do
        items[#items + 1] = { text = (sub.name or "") .. (sub.enabled and "" or " (inactif)"), value = sub.id }
    end
    return items
end
passagePicker.onSelect = function(id) panel.passageId = id; panel:RefreshForm() end
local addPassageBtn = Button(geoPage, "+ Zone ici", FORM_W - M - 220, 20, 220)
addPassageBtn:SetScript("OnClick", function()
    local zoneId = panel.zoneId
    local porte = panel.geoScope == "doors"
    local lieuVoulu = panel.geoScope == "place" and panel.placeId or nil
    -- Depuis un lieu, la zone porte son nom d'office : c'est le cas courant,
    -- et le retaper n'apprend rien à personne.
    local lieu = lieuVoulu and ZG:FindPlace(lieuVoulu)
    AskCreate(porte and "Poser un nouveau passage ?" or "Dessiner une nouvelle zone ?",
        porte and "Il sera placé à votre position et orienté selon votre regard."
            or "Elle démarre vide : vous poserez ses sommets un par un, en vous déplaçant en jeu.",
        function(name)
            local places = ZG:GetPlaceList(zoneId)
            local sub = ZG:CreateSubZone(zoneId, name,
                lieuVoulu or (places[1] and places[1].id or nil),
                not porte and "polygon" or nil)
            if not sub then return end
            panel.passageId = sub.id
            if porte then panel:RefreshAll() else panel:EnterTrace(sub.id) end
        end,
        lieu and lieu.name or nil)
end)
local passagesEmpty = Caption(geoPage, "", M, 84, FORM_W - 2 * M)

Rule(geoPage, 68)
local editor = CreateFrame("Frame", nil, geoPage)
Place(editor, geoPage, 0, 82, FORM_W, 460)
local nameLabel = Label(editor, "Nom de la zone", M, 0, 280)
local passageName = EditBox(editor, M, 18, 280)
passageName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.passageId then return end
    ZG:RenameSubZone(panel.passageId, self:GetText())
    passagePicker:SetText(self:GetText())
end)
local passageActive = Checkbox(editor, "Actif", M + 296, 25)
passageActive:SetScript("OnClick", function(self)
    if panel.passageId then ZG:SetSubZoneEnabled(panel.passageId, self:GetChecked()) end
end)
-- Changer de forme déménage l'objet dans l'autre onglet : on l'y suit, sinon
-- il semblerait avoir disparu.
Label(editor, "Forme", FORM_W - M - 282, 0, 280)
local shapeLineBtn = Button(editor, "Passage droit", FORM_W - M - 282, 18, 136)
local shapeRegionBtn = Button(editor, "Zone dessinée", FORM_W - M - 136, 18, 136)
shapeLineBtn:SetScript("OnClick", function()
    if not panel.passageId then return end
    ZG:SetSubZoneShape(panel.passageId, "line")
    if panel.mode == "zone" then panel.zoneTab = "doors" end
    panel:RefreshForm()
end)
-- Une porte qui devient zone quitte l'onglet Passages pour la fiche du lieu
-- qu'elle dessert : c'est là que les zones se règlent désormais.
shapeRegionBtn:SetScript("OnClick", function()
    if not panel.passageId then return end
    ZG:SetSubZoneShape(panel.passageId, "polygon")
    local sub = ZG:FindSubZone(panel.passageId)
    if sub and sub.enterPlace and ZG:FindPlace(sub.enterPlace) then
        panel.placeTab = "zone"
        Select("place", sub.enterPlace, panel.zoneId)
    end
    if sub and not sub.regionReady then panel:EnterTrace(sub.id) else panel:RefreshForm() end
end)

-- Lieux proposés : ceux de la région d'abord, puis ceux de mes autres régions.
local function PlaceItems(noneText)
    local items = { { text = noneText, value = "" } }
    for _, place in ipairs(ZG:GetPlaceList(panel.zoneId)) do items[#items + 1] = { text = place.name, value = place.id } end
    for _, zone in ipairs(ZG:GetZoneList()) do
        if zone.id ~= panel.zoneId and zone.creator == MyName() then
            local places = ZG:GetPlaceList(zone.id)
            if #places > 0 then
                items[#items + 1] = { text = zone.name, title = true }
                for _, place in ipairs(places) do
                    items[#items + 1] = { text = zone.name .. " > " .. place.name, value = place.id }
                end
            end
        end
    end
    return items
end

local function PlaceText(placeId, noneText)
    local place, zone = ZG:FindPlace(placeId)
    if not place then return noneText end
    if zone.id == panel.zoneId then return PlaceTitle(place, zone) end
    return ZoneTitle(zone) .. " > " .. PlaceTitle(place, zone)
end

local enterCaption = Label(editor, "", M, 68, FORM_W / 2 - M - 8)
local leaveCaption = Label(editor, "", FORM_W / 2 + 8, 68, FORM_W / 2 - M - 8)
local enterPicker = Dropdown(editor, M, 86, FORM_W / 2 - M - 8)
enterPicker.items = function() return PlaceItems("(Aucun lieu)") end
enterPicker.onSelect = function(value)
    ZG:SetPassagePlace(panel.passageId, "enter", value ~= "" and value or nil); panel:RefreshAll()
end
local leavePicker = Dropdown(editor, FORM_W / 2 + 8, 86, FORM_W / 2 - M - 8)
leavePicker.items = function() return PlaceItems("(Aucun — rien ne s'affiche)") end
leavePicker.onSelect = function(value)
    ZG:SetPassagePlace(panel.passageId, "leave", value ~= "" and value or nil); panel:RefreshAll()
end
panel.pickers = { passage = passagePicker, enter = enterPicker, leave = leavePicker }

-- La tranche d'altitude d'un intérieur. Elle prend la place du lieu « en
-- sortant », qu'une étendue dessinée n'a pas. Rangée sur `panel` et non dans
-- une table à elle : ce fichier est au plafond des 200 locaux de Lua 5.1.
--
-- On ne dessine pas un volume sommet par sommet : on dessine son sol, puis on
-- dit de combien il descend et monte. Le repère, c'est le `z` relevé en
-- posant la zone — « Reprendre le sol ici » le recale sur l'étage où l'on se
-- tient.
panel.hauteur = {}
panel.hauteur.titre = Label(editor, "Intérieur : tranche d'altitude (yards)", FORM_W / 2 + 8, 68, FORM_W / 2 - M - 8)
panel.hauteur.basMot = Caption(editor, "sous", FORM_W / 2 + 8, 94, 36)
panel.hauteur.bas = EditBox(editor, FORM_W / 2 + 44, 86, 58, FIELD_H, 4)
panel.hauteur.hautMot = Caption(editor, "sur", FORM_W / 2 + 110, 94, 30)
panel.hauteur.haut = EditBox(editor, FORM_W / 2 + 142, 86, 58, FIELD_H, 4)
panel.hauteur.sol = Button(editor, "Reprendre le sol ici", FORM_W / 2 + 210, 86, FORM_W / 2 - M - 218)
panel.hauteur.Poser = function()
    if panel.suppressEvents or not panel.passageId then return end
    ZG:SetSubZoneHeights(panel.passageId, panel.hauteur.bas:GetText(), panel.hauteur.haut:GetText())
    panel:RefreshForm()
end
for _, champ in ipairs({ panel.hauteur.bas, panel.hauteur.haut }) do
    champ:SetScript("OnEnterPressed", panel.hauteur.Poser)
    champ:SetScript("OnEditFocusLost", panel.hauteur.Poser)
end
panel.hauteur.sol:SetScript("OnClick", function()
    if panel.passageId and ZG:RecaptureSubZoneHeight(panel.passageId) then panel:RefreshForm() end
end)

-- ── Couleur d'une zone ──────────────────────────────────────────────────
-- Une région porte sa couleur, chaque lieu en reçoit une variante, et un lieu
-- peut imposer la sienne. Le pavé montre la couleur courante ; le sélecteur
-- du jeu fait le reste. Rangé sur `panel` pour la même raison que la hauteur :
-- la fonction qui s'en sert est déclarée plus haut dans le fichier.
--
-- `Pave(parent, x, y, Lire, Ecrire)` : Lire rend {r,g,b}, Ecrire la pose.
panel.couleur = {}
function panel.couleur.Pave(parent, x, y, Lire, Ecrire)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(26, 26)
    UI.Surface(b)
    b.pastille = b:CreateTexture(nil, "ARTWORK")
    b.pastille:SetPoint("TOPLEFT", 3, -3); b.pastille:SetPoint("BOTTOMRIGHT", -3, 3)
    Place(b, parent, x, y)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Couleur sur la carte", 1, 1, 1)
        GameTooltip:AddLine("Clic droit : revenir à la couleur héritée.", .7, .7, .7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(_, bouton)
        if bouton == "RightButton" then Ecrire(nil); panel:RefreshAll(); return end
        local c = Lire() or { 1, 1, 1 }
        -- Le sélecteur du jeu a changé de forme selon les versions : on pose
        -- les deux écritures, celle d'aujourd'hui et l'ancienne.
        local function pris()
            local r, v, bl = ColorPickerFrame:GetColorRGB()
            Ecrire(r, v, bl); panel:RefreshAll()
        end
        local info = { r = c[1], g = c[2], b = c[3], hasOpacity = false,
                       swatchFunc = pris, opacityFunc = pris,
                       cancelFunc = function() end }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func, ColorPickerFrame.opacityFunc = pris, pris
            ColorPickerFrame.cancelFunc = info.cancelFunc
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
            ColorPickerFrame:Hide(); ColorPickerFrame:Show()
        end
    end)
    b.Lire = Lire
    return b
end

-- Celui du LIEU, dans son onglet Zone, là où « Forme » n'a rien à montrer.
panel.couleur.lieuMot = Label(editor, "Couleur", FORM_W - M - 282, 0, 120)
panel.couleur.lieu = panel.couleur.Pave(editor, FORM_W - M - 282, 18,
    function()
        local place, zone = ZG:FindPlace(panel.placeId)
        return place and ZG:PlaceColor(place, zone) or nil
    end,
    function(r, v, b) ZG:SetPlaceColor(panel.placeId, r, v, b) end)

local radarRow = CreateFrame("Frame", nil, editor)
Place(radarRow, editor, M, 140, FORM_W - 2 * M, 284)
-- L'éditeur déménage : le guide suit ce que geoPage montre, où qu'il soit.
local radar = ZG.CreatePassageGuide(radarRow, function()
    if not (geoPage:IsShown() and editor:IsShown()) then return nil end
    return ZG:FindSubZone(panel.passageId)
end)
radar:SetPoint("TOPLEFT", radarRow, "TOPLEFT", 0, 0)

local SIDE_X, SIDE_W = 328, 240
local widthLabel = Label(radarRow, "Largeur du passage", SIDE_X, 0, SIDE_W)
local widthEB = EditBox(radarRow, SIDE_X, 20, 90, FIELD_H, 4)

local SLIDER_MIN, SLIDER_MAX = 1, 500
local sliderTrack = CreateFrame("Frame", nil, radarRow)
Place(sliderTrack, radarRow, SIDE_X + 2, 72, FORM_W - 2 * M - SIDE_X - 8, 4)
local sliderBg = sliderTrack:CreateTexture(nil, "BACKGROUND")
sliderBg:SetAllPoints()
sliderBg:SetColorTexture(0.18, 0.18, 0.18, 1)
local sliderFill = sliderTrack:CreateTexture(nil, "ARTWORK")
sliderFill:SetPoint("LEFT")
sliderFill:SetHeight(4)
sliderFill:SetColorTexture(unpack(UI.colors.panelButtonAccent))
local sliderHandle = CreateFrame("Button", nil, sliderTrack)
sliderHandle:SetSize(14, 14)
sliderHandle:SetPoint("CENTER", sliderTrack, "LEFT", 0, 0)
local sliderHandleTex = sliderHandle:CreateTexture(nil, "OVERLAY")
sliderHandleTex:SetAllPoints()
sliderHandleTex:SetColorTexture(0.90, 0.78, 0.30, 1)

local function SetSliderValue(value, silent)
    value = math.max(SLIDER_MIN, math.min(SLIDER_MAX, math.floor(value + 0.5)))
    local ratio = (value - SLIDER_MIN) / (SLIDER_MAX - SLIDER_MIN)
    sliderHandle:SetPoint("CENTER", sliderTrack, "LEFT", ratio * sliderTrack:GetWidth(), 0)
    sliderFill:SetWidth(math.max(0.01, ratio * sliderTrack:GetWidth()))
    panel.suppressEvents = true
    widthEB:SetText(tostring(value))
    panel.suppressEvents = false
    if not silent and panel.passageId then ZG:SetSubZoneWidth(panel.passageId, value) end
end

sliderHandle:SetScript("OnMouseDown", function()
    sliderHandle:SetScript("OnUpdate", function()
        local x = GetCursorPosition() / sliderTrack:GetEffectiveScale()
        local left = sliderTrack:GetLeft()
        if not left then return end
        local ratio = math.max(0, math.min(1, (x - left) / sliderTrack:GetWidth()))
        SetSliderValue(SLIDER_MIN + ratio * (SLIDER_MAX - SLIDER_MIN))
    end)
end)
sliderHandle:SetScript("OnMouseUp", function() sliderHandle:SetScript("OnUpdate", nil) end)
widthEB:SetScript("OnEnterPressed", function(self)
    SetSliderValue(tonumber(self:GetText()) or SLIDER_MIN)
    self:ClearFocus()
end)

-- Périmètre : mêmes emplacements que la largeur (un seul des deux visible).
local regionLabel = Label(radarRow, "", SIDE_X, 0, SIDE_W)
local addPointBtn = Button(radarRow, "+ Point ici", SIDE_X, 22, SIDE_W)
addPointBtn:SetScript("OnClick", function()
    if panel.passageId and ZG:AddRegionPoint(panel.passageId) then panel:RefreshForm() end
end)
local undoPointBtn = Button(radarRow, "Annuler le point", SIDE_X, 62, (SIDE_W - 8) / 2)
undoPointBtn:SetScript("OnClick", function()
    if panel.passageId and ZG:RemoveLastRegionPoint(panel.passageId) then panel:RefreshForm() end
end)
local clearPointsBtn = Button(radarRow, "Effacer tout", SIDE_X + (SIDE_W + 8) / 2, 62, (SIDE_W - 8) / 2)
clearPointsBtn:SetScript("OnClick", function()
    if panel.passageId then ZG:ClearRegionPoints(panel.passageId); panel:RefreshForm() end
end)
local borderBtn = Button(radarRow, "Reprendre une frontière…", SIDE_X, 102, SIDE_W)
-- Fermer une zone, c'est relier son dernier sommet au premier. C'est ce que
-- « Valider le périmètre » faisait, sous un nom qui ne le disait pas.
local finishRegionBtn = Button(radarRow, "Fermer la zone", SIDE_X, 142, SIDE_W)
finishRegionBtn:SetScript("OnClick", function()
    local sub = ZG:FindSubZone(panel.passageId)
    if not sub then return end
    if sub.regionReady then
        ZG:ReopenRegion(sub.id)
        panel:EnterTrace(sub.id)
        return
    elseif not ZG:FinishRegion(sub.id) then
        LCM.Info("Crossings : il faut au moins 3 sommets pour fermer une zone.")
    end
    panel:RefreshForm()
end)

-- Nommer un sommet : il devient un point de frontière facile à retrouver.
local vertexLabel = Label(radarRow, "Nommer un sommet", SIDE_X, 186, SIDE_W)
local vertexPicker = Dropdown(radarRow, SIDE_X, 204, 96)
local vertexName = EditBox(radarRow, SIDE_X + 104, 204, SIDE_W - 104, FIELD_H, 40)
vertexPicker.items = function()
    local sub = ZG:FindSubZone(panel.passageId)
    local items = {}
    for i, point in ipairs(sub and sub.points or {}) do
        items[#items + 1] = { text = point.name and (i .. " · " .. point.name) or ("Point " .. i), value = i }
    end
    return items
end
vertexPicker.onSelect = function(index) panel.vertexIndex = index; panel:RefreshForm() end
vertexName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.passageId or not panel.vertexIndex then return end
    ZG:SetRegionPointName(panel.passageId, panel.vertexIndex, self:GetText())
end)

-- Reprendre une frontière : deux points d'un périmètre voisin, recopiés à
-- l'identique à la suite du contour en cours.
local border = CreateFrame("Frame", "LCMCrossingsBorderPick", UIParent)
do
-- Reprendre une frontière : un périmètre voisin, un point de départ, un point
-- d'arrivée, et le chemin suivi le long de son contour (deux sens possibles).
local BW = 560
border:SetSize(BW, 360); border:SetPoint("CENTER"); border:SetFrameStrata("DIALOG")
border:EnableMouse(true); UI.Surface(border); border:Hide()
border.title = Label(border, "Reprendre une frontière", M, 16, BW - 2 * M)
local hint = Caption(border, "Choisissez un périmètre voisin, puis le tronçon de son contour à reprendre. Ses points sont ajoutés à la suite de votre tracé, aux mêmes coordonnées : les deux zones se touchent sans trou ni chevauchement.", M, 38, BW - 2 * M)
hint:SetHeight(44)
Label(border, "Périmètre voisin", M, 92, BW - 2 * M)
local sourcePick = Dropdown(border, M, 110, BW - 2 * M)
local half = (BW - 2 * M - 16) / 2
Label(border, "Du point", M, 156, half)
local fromPick = Dropdown(border, M, 174, half)
Label(border, "Au point", M + half + 16, 156, half)
local toPick = Dropdown(border, M + half + 16, 174, half)
Label(border, "Chemin", M, 220, BW - 2 * M)
local pathPick = Dropdown(border, M, 238, BW - 2 * M - 140)
-- Partir de l'autre extrémité : même tronçon, parcouru à l'envers.
local flipBtn = Button(border, "Inverser", BW - M - 130, 238, 130)
local info = Caption(border, "", M, 280, BW - 2 * M)
local cancelBtn = Button(border, "Annuler", M, 308, half)
local addBtn = Button(border, "Ajouter", M + half + 16, 308, half)
cancelBtn:SetScript("OnClick", function() border:Hide() end)
panel.borderPick = border

local function PointText(sub, index)
    local point = sub.points[index]
    return point.name and (index .. " · " .. point.name) or ("Point " .. index)
end

-- Aperçu d'un chemin : « 47 > 1 > … > 6 (7 points) » (la police du jeu n'a pas de flèche).
local function PathText(path)
    local shown = {}
    for i, index in ipairs(path) do
        if i <= 3 or i == #path then shown[#shown + 1] = tostring(index)
        elseif i == 4 then shown[#shown + 1] = "…" end
    end
    return table.concat(shown, " > ") .. string.format("  (%d points)", #path)
end

local function Reset(level)
    if level <= 1 then border.from = nil; fromPick:SetText("Choisir…") end
    if level <= 2 then border.to = nil; toPick:SetText("Choisir…") end
    border.forward = nil; pathPick:SetText("Choisir…")
    info:SetText("")
end

-- Régions voisines : un de leurs périmètres passe à moins de NEAR yards du
-- contour en cours (ou du joueur, si le contour est vide).
local NEAR = 200
local function Sample(points, max)
    local step = math.max(1, math.floor(#points / max))
    local out = {}
    for i = 1, #points, step do out[#out + 1] = points[i] end
    return out
end
local function Distance(from, points)
    local best
    for _, a in ipairs(from) do
        for _, b in ipairs(Sample(points, 200)) do
            local d = (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2
            if not best or d < best then best = d end
        end
    end
    return best and math.sqrt(best) or math.huge
end

-- Par région : celle du passage d'abord, puis les voisines (les plus proches
-- d'abord), puis les autres. Dans chaque région, les frontières déclarées
-- avant les périmètres entiers.
sourcePick.items = function()
    local current, currentZone = ZG:FindSubZone(panel.passageId)
    local from = {}
    if current and current.points and #current.points > 0 then
        from = Sample(current.points, 60)
    else
        local px, py = ZG:GetPlayerPose()
        if px then from = { { x = px, y = py } } end
    end
    local groups, order = {}, {}
    local function Group(zone)
        if not groups[zone.id] then
            groups[zone.id] = { zone = zone, borders = {}, perimeters = {}, distance = math.huge }
            order[#order + 1] = groups[zone.id]
        end
        return groups[zone.id]
    end
    for _, entry in ipairs(ZG:GetBorderSources(panel.passageId)) do
        local g = Group(entry.zone)
        g.perimeters[#g.perimeters + 1] = entry
        g.distance = math.min(g.distance, Distance(from, entry.sub.points))
    end
    for _, entry in ipairs(ZG:GetDeclaredBorders(panel.passageId)) do
        local g = Group(entry.zone)
        g.borders[#g.borders + 1] = entry
    end
    local function Rank(g)
        if currentZone and g.zone.id == currentZone.id then return 0 end
        return g.distance <= NEAR and 1 or 2
    end
    table.sort(order, function(a, b)
        if Rank(a) ~= Rank(b) then return Rank(a) < Rank(b) end
        if Rank(a) == 1 and a.distance ~= b.distance then return a.distance < b.distance end
        return (a.zone.name or "") < (b.zone.name or "")
    end)
    local items = {}
    for _, g in ipairs(order) do
        local rank = Rank(g)
        local tag = (rank == 0 and "cette région")
            or (rank == 1 and string.format("région voisine · à %d yd", math.floor(g.distance + .5)))
            or "plus loin"
        items[#items + 1] = { text = string.format("%s  (%s)", g.zone.name or "", tag), title = true }
        table.sort(g.borders, function(a, b) return a.border.name < b.border.name end)
        for _, entry in ipairs(g.borders) do
            items[#items + 1] = { text = string.format("Frontière : %s  (%s)", entry.border.name, entry.sub.name or ""), value = entry }
        end
        table.sort(g.perimeters, function(a, b) return (a.sub.name or "") < (b.sub.name or "") end)
        for _, entry in ipairs(g.perimeters) do
            items[#items + 1] = { text = string.format("Périmètre entier : %s  (%d points)", entry.sub.name or "", #entry.sub.points), value = entry.sub }
        end
    end
    if #items == 0 then items[1] = { text = "Aucun autre de vos périmètres dans cette instance", title = true } end
    return items
end
-- Une frontière déclarée préremplit les deux points et le chemin.
sourcePick.onSelect = function(value)
    if value.border then
        local b = value.border
        border.source = value.sub
        Reset(1)
        border.from, border.to = b.from, b.to
        fromPick:SetText(PointText(value.sub, b.from)); toPick:SetText(PointText(value.sub, b.to))
        pathPick.onSelect(b.forward)
        pathPick:SetText(PathText(ZG:BorderPath(value.sub, b.from, b.to, b.forward)))
    else
        border.source = value; Reset(1)
    end
end

local function PointItems(exclude)
    local sub = border.source
    if not sub then return { { text = "Choisissez d'abord le périmètre", title = true } } end
    local items = {}
    for index in ipairs(sub.points) do
        if index ~= exclude then items[#items + 1] = { text = PointText(sub, index), value = index } end
    end
    return items
end
fromPick.items = function() return PointItems(border.to) end
fromPick.onSelect = function(index) border.from = index; border.forward = nil; pathPick:SetText("Choisir…"); info:SetText("") end
toPick.items = function() return PointItems(border.from) end
toPick.onSelect = function(index) border.to = index; border.forward = nil; pathPick:SetText("Choisir…"); info:SetText("") end

pathPick.items = function()
    local sub, from, to = border.source, border.from, border.to
    if not sub or not from or not to then return { { text = "Choisissez d'abord les deux points", title = true } } end
    local items = {}
    for _, forward in ipairs({ true, false }) do
        local path = ZG:BorderPath(sub, from, to, forward)
        if path then items[#items + 1] = { text = PathText(path), value = forward } end
    end
    return items
end
flipBtn:SetScript("OnClick", function()
    if not border.source or not border.from or not border.to then return end
    border.from, border.to = border.to, border.from
    fromPick:SetText(PointText(border.source, border.from)); toPick:SetText(PointText(border.source, border.to))
    if border.forward ~= nil then
        pathPick.onSelect(not border.forward)
        pathPick:SetText(PathText(ZG:BorderPath(border.source, border.from, border.to, border.forward)))
    end
end)
pathPick.onSelect = function(forward)
    border.forward = forward
    local path = ZG:BorderPath(border.source, border.from, border.to, forward)
    addBtn:SetText(path and string.format("Ajouter %d points", #path) or "Ajouter")
end

addBtn:SetScript("OnClick", function()
    if not border.source or not border.from or not border.to or border.forward == nil then
        info:SetText("|cffe6c94dChoisissez le périmètre, les deux points et le chemin.|r"); return
    end
    if ZG:AddBorderPath(panel.passageId, border.source.id, border.from, border.to, border.forward) then
        border:Hide()
        panel:RefreshForm()
        if panel.traceWindow and panel.traceWindow:IsShown() then panel.traceWindow.Refresh() end
    else
        info:SetText("|cffe6c94dImpossible d'ajouter ce tronçon (autre instance ou limite atteinte).|r")
    end
end)

borderBtn:SetScript("OnClick", function()
    -- Contour vide : la frontière reprise devient le début du tracé (son premier point = point 1).
    local current = ZG:FindSubZone(panel.passageId)
    border.title:SetText((current and current.points and #current.points == 0) and "Partir d'une frontière" or "Reprendre une frontière")
    border.source = nil
    sourcePick:SetText("Choisir…"); addBtn:SetText("Ajouter")
    Reset(1)
    local sources = ZG:GetBorderSources(panel.passageId)
    if #sources == 0 then
        info:SetText("Aucun autre de vos périmètres dans cette instance pour l'instant.")
    elseif #sources == 1 then
        sourcePick.onSelect(sources[1].sub)
        for _, item in ipairs(sourcePick.items()) do
            if item.value == sources[1].sub then sourcePick:SetText(item.text) end
        end
    end
    border:Show()
end)
end


-- Déclarer une frontière : un tronçon nommé de son propre contour, que les
-- périmètres voisins reprendront ensuite (même sans voisin pour l'instant).
local declare = CreateFrame("Frame", "LCMCrossingsBorderDeclare", UIParent)
do
-- Frontières de ce contour : en déclarer une nouvelle, ou modifier / supprimer
-- une frontière existante (choisie dans le premier menu).
local DW = 560
declare:SetSize(DW, 420); declare:SetPoint("CENTER"); declare:SetFrameStrata("DIALOG")
declare:EnableMouse(true); UI.Surface(declare); declare:Hide()
Label(declare, "Frontières de ce contour", M, 16, DW - 2 * M)
local hint = Caption(declare, "Nommez un tronçon de ce contour. Les périmètres voisins pourront le reprendre à l'identique avec « Reprendre une frontière… ».", M, 38, DW - 2 * M)
hint:SetHeight(30)
Label(declare, "Frontière", M, 76, DW - 2 * M)
local borderPick = Dropdown(declare, M, 94, DW - 2 * M - 140)
local deleteBtn = Button(declare, "Supprimer", DW - M - 130, 94, 130)
Label(declare, "Nom", M, 140, DW - 2 * M)
local nameBox = EditBox(declare, M, 158, DW - 2 * M, FIELD_H, 40)
local half = (DW - 2 * M - 16) / 2
Label(declare, "Du point", M, 202, half)
local fromPick = Dropdown(declare, M, 220, half)
Label(declare, "Au point", M + half + 16, 202, half)
local toPick = Dropdown(declare, M + half + 16, 220, half)
Label(declare, "Chemin", M, 266, DW - 2 * M)
local pathPick = Dropdown(declare, M, 284, DW - 2 * M)
local info = Caption(declare, "", M, 330, DW - 2 * M)
local cancelBtn = Button(declare, "Fermer", M, 364, half)
local okBtn = Button(declare, "Déclarer", M + half + 16, 364, half)
cancelBtn:SetScript("OnClick", function() declare:Hide() end)
panel.borderDeclare = declare

local NEW = "Nouvelle frontière"
local function Sub() return ZG:FindSubZone(panel.passageId) end
local function PointText(sub, index)
    local point = sub.points[index]
    return point.name and (index .. " · " .. point.name) or ("Point " .. index)
end
local function PathText(path)
    local shown = {}
    for i, index in ipairs(path) do
        if i <= 3 or i == #path then shown[#shown + 1] = tostring(index) elseif i == 4 then shown[#shown + 1] = "…" end
    end
    return table.concat(shown, " > ") .. string.format("  (%d points)", #path)
end
local function PointItems(exclude)
    local sub, items = Sub(), {}
    for index in ipairs(sub and sub.points or {}) do
        if index ~= exclude then items[#items + 1] = { text = PointText(sub, index), value = index } end
    end
    return items
end

-- Charge une frontière existante (index) dans le formulaire, ou le vide (nil).
local function Load(index)
    local sub = Sub()
    local b = index and sub and sub.borders and sub.borders[index]
    declare.editing = b and index or nil
    declare.from, declare.to, declare.forward = b and b.from, b and b.to, b and b.forward
    nameBox:SetText(b and b.name or "")
    borderPick:SetText(b and b.name or NEW)
    fromPick:SetText(b and PointText(sub, b.from) or "Choisir…")
    toPick:SetText(b and PointText(sub, b.to) or "Choisir…")
    local path = b and ZG:BorderPath(sub, b.from, b.to, b.forward)
    pathPick:SetText(path and PathText(path) or "Choisir…")
    okBtn:SetText(b and "Enregistrer" or "Déclarer")
    deleteBtn:SetShown(b ~= nil)
    info:SetText("")
end

borderPick.items = function()
    local items = { { text = NEW, value = 0 } }
    local sub = Sub()
    for index, b in ipairs(sub and sub.borders or {}) do
        items[#items + 1] = { text = string.format("%s  (%d > %d)", b.name, b.from, b.to), value = index }
    end
    return items
end
borderPick.onSelect = function(index) Load(index ~= 0 and index or nil) end

fromPick.items = function() return PointItems(declare.to) end
fromPick.onSelect = function(index) declare.from, declare.forward = index, nil; pathPick:SetText("Choisir…") end
toPick.items = function() return PointItems(declare.from) end
toPick.onSelect = function(index) declare.to, declare.forward = index, nil; pathPick:SetText("Choisir…") end
pathPick.items = function()
    local sub = Sub()
    if not sub or not declare.from or not declare.to then return { { text = "Choisissez d'abord les deux points", title = true } } end
    local items = {}
    for _, forward in ipairs({ true, false }) do
        local path = ZG:BorderPath(sub, declare.from, declare.to, forward)
        if path then items[#items + 1] = { text = PathText(path), value = forward } end
    end
    return items
end
pathPick.onSelect = function(forward) declare.forward = forward end

local function Done()
    if panel.traceWindow and panel.traceWindow:IsShown() then panel.traceWindow.Refresh() end
end

okBtn:SetScript("OnClick", function()
    local name = (nameBox:GetText() or ""):match("^%s*(.-)%s*$") or ""
    if name == "" or not declare.from or not declare.to or declare.forward == nil then
        info:SetText("|cffe6c94dDonnez un nom, les deux points et le chemin.|r"); return
    end
    local ok
    if declare.editing then
        ok = ZG:UpdateBorder(panel.passageId, declare.editing, name, declare.from, declare.to, declare.forward)
    else
        ok = ZG:DeclareBorder(panel.passageId, name, declare.from, declare.to, declare.forward)
    end
    if ok then
        declare:Hide(); Done()
    else
        info:SetText("|cffe6c94dCe tronçon n'existe pas sur ce contour.|r")
    end
end)

deleteBtn:SetScript("OnClick", function()
    if not declare.editing then return end
    ZG:RemoveBorder(panel.passageId, declare.editing)
    Load(nil); Done()
    info:SetText("Frontière supprimée.")
end)

function panel:OpenDeclareBorder()
    Load(nil)
    declare:Show()
end
end

-- ── Auras imposées par le passage ───────────────────────────────────────────
-- À gauche : les auras que le passage impose tant qu'on est dedans. À droite :
-- les auras d'Epsilon Aura Manager (onglets Personnel et Phase), un clic les
-- ajoute ; un ID de sort peut aussi être saisi à la main.
local auraWin = CreateFrame("Frame", "LCMCrossingsAuraManager", UIParent)
do
local AW, AH, HEAD = 720, 514, 56
local COL = (AW - 3 * M) / 2
local LIST_Y, LIST_H, ROW = 136, 270, 30
auraWin:SetSize(AW, AH); auraWin:SetFrameStrata("DIALOG")
-- Une UI.Fenetre de LCM autour (UI.Habiller) ; le nom du passage passe en
-- sous-titre de la couronne.
local auraFenetre = UI.Habiller(auraWin, "auras", "Auras imposées", HEAD)
auraWin:Hide()
local head = CreateFrame("Frame", nil, auraWin)
head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1); head:SetHeight(HEAD)
auraWin.title = { SetText = function(_, texte) auraFenetre:SousTitre(texte or "") end }

local hint = Caption(auraWin, "Tant qu'un joueur se trouve dans ce passage, ces auras lui sont posées, et reposées si elles disparaissent, y compris juste après sa connexion. Elles sont retirées dès qu'il en sort.", M, HEAD + 12, AW - 2 * M)
hint:SetHeight(30)

local function Sub() return ZG:FindSubZone(panel.passageId) end
local function AuraText(spellID)
    local name, _, icon = GetSpellInfo(spellID)
    return string.format("|T%s:16|t %s  |cff888888%d|r", icon or 136243, name or "Sort inconnu", spellID)
end
local function ShowSpellTooltip(owner, spellID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetSpellByID(spellID)
    GameTooltip:Show()
end
-- Texte des rangées aligné à gauche, comme une liste.
local function LeftText(button, right)
    local fs = button:GetFontString()
    if fs then
        fs:SetJustifyH("LEFT"); fs:SetWordWrap(false); fs:ClearAllPoints()
        fs:SetPoint("LEFT", 8, 0); fs:SetPoint("RIGHT", -(right or 8), 0)
    end
end

-- Liste défilante : rangées créées à la demande, molette pour défiler.
local function List(x, w)
    local scroll = CreateFrame("ScrollFrame", nil, auraWin)
    scroll:SetPoint("TOPLEFT", x, -LIST_Y); scroll:SetSize(w, LIST_H); scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll); content:SetSize(w, 1); scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(math.max(0, content:GetHeight() - LIST_H), self:GetVerticalScroll() - delta * ROW)))
    end)
    local empty = Caption(auraWin, "", x, LIST_Y + 8, w)
    return { scroll = scroll, content = content, rows = {}, empty = empty }
end
local function Fill(list, count, build)
    for i = 1, count do
        list.rows[i] = list.rows[i] or build()
        list.rows[i]:ClearAllPoints(); list.rows[i]:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -(i - 1) * ROW)
    end
    for i = count + 1, #list.rows do list.rows[i]:Hide() end
    list.content:SetHeight(math.max(1, count * ROW))
    list.scroll:SetVerticalScroll(math.min(list.scroll:GetVerticalScroll(), math.max(0, count * ROW - LIST_H)))
end

local status = Caption(auraWin, "", M, AH - 26, AW - 2 * M)

-- Colonne gauche : auras du passage.
Label(auraWin, "Imposées dans ce passage", M, HEAD + 52, COL)
local imposed = List(M, COL)
local function ImposedRow()
    -- Conteneur : la rangée et son bouton Retirer s'affichent ensemble.
    local row = CreateFrame("Frame", nil, imposed.content); row:SetSize(COL, ROW - 4)
    local aura = UI.CreatePanelButton(row, COL - 92, ROW - 4, "")
    aura:SetPoint("LEFT"); aura.accent:Hide(); LeftText(aura, 54)
    -- Origine dans Aura Manager, calée à droite sur la même ligne.
    local origin = aura:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    origin:SetPoint("RIGHT", -8, 0); origin:SetJustifyH("RIGHT")
    aura:SetScript("OnEnter", function(self) ShowSpellTooltip(self, row.spellID) end)
    aura:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local remove = UI.CreatePanelButton(row, 84, ROW - 4, "Retirer")
    remove:SetPoint("RIGHT")
    remove:SetScript("OnClick", function()
        ZG:RemovePassageAura(panel.passageId, row.spellID)
        status:SetText("Retirée : " .. AuraText(row.spellID))
        auraWin:Refresh(); panel:RefreshForm()
    end)
    row.aura, row.origin = aura, origin
    return row
end
Label(auraWin, "ID de sort", M, LIST_Y + LIST_H + 12, COL)
local idBox = EditBox(auraWin, M, LIST_Y + LIST_H + 30, COL - 128, FIELD_H, 10)
local addId = Button(auraWin, "Ajouter", M + COL - 120, LIST_Y + LIST_H + 30, 120)
local function AddAura(spellID, source)
    if not spellID or spellID <= 0 then return end
    if not GetSpellInfo(spellID) then status:SetText("|cffe6c94dSort introuvable : " .. spellID .. ".|r"); return end
    if ZG:AddPassageAura(panel.passageId, spellID, source) then
        status:SetText("Ajoutée : " .. AuraText(spellID))
    else
        status:SetText("|cffe6c94dCette aura est déjà imposée.|r")
    end
    auraWin:Refresh(); panel:RefreshForm()
end
addId:SetScript("OnClick", function() AddAura(tonumber(idBox:GetText())); idBox:SetText(""); idBox:ClearFocus() end)
idBox:SetScript("OnEnterPressed", function() addId:Click() end)

-- Colonne droite : listes d'Epsilon Aura Manager, onglets Personnel et Phase.
local RX = 2 * M + COL
local tabW = (COL - 8) / 2
local tabs = {
    personal = Button(auraWin, "Personnel", RX, HEAD + 46, tabW, 28),
    phase    = Button(auraWin, "Phase", RX + tabW + 8, HEAD + 46, tabW, 28),
}
auraWin.tab = "personal"
for key, b in pairs(tabs) do b:SetScript("OnClick", function() auraWin.tab = key; auraWin:Refresh() end) end
local manager = List(RX, COL)
local function ManagerRow()
    local row = UI.CreatePanelButton(manager.content, COL, ROW - 4, "")
    row.accent:Hide(); LeftText(row)
    row:SetScript("OnEnter", function(self) ShowSpellTooltip(self, self.spellID) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self) AddAura(self.spellID, auraWin.tab) end)
    return row
end
Caption(auraWin, "Listes d'Aura Manager · clic : imposer l'aura.", RX, LIST_Y + LIST_H + 12, COL)
local openManager = Button(auraWin, "Ouvrir Aura Manager", RX, LIST_Y + LIST_H + 30, COL)
openManager:SetScript("OnClick", function()
    if EpsilonAuraManager_ShowHide then EpsilonAuraManager_ShowHide() end
end)

-- Liste d'Aura Manager pour un onglet ; nil si l'addon est absent. Aura
-- Manager choisit sa liste selon isLocal : on le bascule le temps de la lire.
local function ManagerAuras(tab)
    if not (Epsilon_AuraManager and Epsilon_AuraManager_GetAurasTable) then return nil end
    local saved = Epsilon_AuraManager.isLocal
    Epsilon_AuraManager.isLocal = (tab == "personal")
    local ok, list = pcall(Epsilon_AuraManager_GetAurasTable)
    Epsilon_AuraManager.isLocal = saved
    local auras = {}
    for _, info in ipairs(ok and list or {}) do
        local id = tonumber(info.spellID)
        if id then auras[#auras + 1] = { id = id, name = info.name, icon = info.icon } end
    end
    table.sort(auras, function(a, b) return tostring(a.name or "") < tostring(b.name or "") end)
    return auras
end

function auraWin:Refresh()
    local sub = Sub()
    if not sub or sub.creator ~= MyName() then self:Hide(); return end
    self.title:SetText("Passage : " .. (sub.name or ""))

    local auras = sub.auras or {}
    Fill(imposed, #auras, ImposedRow)
    for i, aura in ipairs(auras) do
        local row = imposed.rows[i]
        row.spellID = aura.id
        row.origin:SetText((aura.source == "personal" and "|cffb08cffPerso|r") or (aura.source == "phase" and "|cff66b3ffPhase|r") or "")
        row.aura:SetText(AuraText(aura.id)); row:Show()
    end
    imposed.empty:SetText(#auras == 0 and "Aucune aura imposée." or "")

    for key, b in pairs(tabs) do b.accent:SetShown(self.tab == key) end
    local list = ManagerAuras(self.tab)
    openManager:SetEnabled(EpsilonAuraManager_ShowHide ~= nil)
    Fill(manager, list and #list or 0, ManagerRow)
    for i, aura in ipairs(list or {}) do
        local row = manager.rows[i]
        row.spellID = aura.id
        row:SetText(string.format("|T%s:16|t %s  |cff888888%d|r", aura.icon or 136243, aura.name or "?", aura.id)); row:Show()
    end
    if not list then
        manager.empty:SetText("Epsilon Aura Manager n'est pas chargé. Saisissez un ID de sort à gauche.")
    elseif #list == 0 then
        manager.empty:SetText(self.tab == "personal" and "Aucune aura dans votre liste personnelle." or "Aucune aura dans la liste de la phase.")
    else
        manager.empty:SetText("")
    end
    if status:GetText() == nil or status:GetText() == "" then
        if ZG:IsInsidePassage(sub.id) and #auras > 0 then
            status:SetText("|cff66e673Vous êtes dans ce passage : ces auras vous sont imposées.|r")
        end
    end
end
auraWin:SetScript("OnHide", function() status:SetText(""); idBox:SetText("") end)
UISpecialFrames = UISpecialFrames or {}; table.insert(UISpecialFrames, "LCMCrossingsAuraManager")

function panel:OpenPassageAuras()
    auraWin:Show(); auraWin:Refresh()
end
end

-- ── Fenêtre de tracé : pendant la construction d'un périmètre, seuls le
-- tracé et ses commandes restent à l'écran, jusqu'à « Valider le périmètre ».
do
-- Marges larges autour du tracé : la minimap qui pivote déborde du cadre
-- et ses caches doivent rester dans la fenêtre.
local W, H = 598, 352
local X, CW = 342, 240
local trace = CreateFrame("Frame", "LCMCrossingsTraceWindow", UIParent)
trace:SetSize(W, H); trace:SetFrameStrata("HIGH"); trace:SetClampedToScreen(true)
trace:SetMovable(true); trace:EnableMouse(true); trace:RegisterForDrag("LeftButton")
trace:SetScript("OnDragStart", trace.StartMoving)
trace:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    LCM_CrossingsChar = LCM_CrossingsChar or {}
    LCM_CrossingsChar.tracePos = { point, relPoint, x, y }
end)
UI.Surface(trace); trace:Hide()
-- Même teinte que les caches de la minimap : aucune démarcation visible.
if trace.surfaceBg then trace.surfaceBg:SetColorTexture(unpack(ZG.RadarCoverColor)) end
-- Contenu au-dessus de la minimap et de ses caches.
local content = CreateFrame("Frame", nil, trace)
content:SetAllPoints(); content:SetFrameLevel(trace:GetFrameLevel() + 3)
trace.content = content
local title = Label(content, "", M, 20, 380)
local back = Button(content, "Panneau complet", W - M - 150, 14, 150, 26)
local guide = ZG.CreatePassageGuide(content, function() return ZG:FindSubZone(panel.tracingId) end)
guide:SetPoint("TOPLEFT", content, "TOPLEFT", 26, -46)
local count = Label(content, "", X, 50, CW)
local add = Button(content, "+ Point ici", X, 74, CW)
local undo = Button(content, "Annuler le point", X, 114, (CW - 8) / 2)
local clear = Button(content, "Effacer tout", X + (CW + 8) / 2, 114, (CW - 8) / 2)
local borderPick = Button(content, "Reprendre une frontière…", X, 154, CW)
local declareBtn = Button(content, "Gérer les frontières…", X, 252, CW)
declareBtn:SetScript("OnClick", function() panel:OpenDeclareBorder() end)
local finish = Button(content, "Fermer la zone", X, 292, CW, 38)

local function Refresh()
    local sub = ZG:FindSubZone(panel.tracingId)
    if not sub then return end
    title:SetText("TRACÉ DE LA ZONE  ·  " .. string.upper(sub.name or ""))
    local n = sub.points and #sub.points or 0
    count:SetText(string.format(n < 3 and "|cffe6c94d%d sommet(s) — il en faut au moins 3.|r" or "|cffe6c94d%d sommets — prête à fermer.|r", n))
end
trace.Refresh = Refresh

add:SetScript("OnClick", function()
    if ZG:AddRegionPoint(panel.tracingId) then Refresh() end
end)
undo:SetScript("OnClick", function()
    if ZG:RemoveLastRegionPoint(panel.tracingId) then Refresh() end
end)
clear:SetScript("OnClick", function()
    local sub = ZG:FindSubZone(panel.tracingId)
    local n = sub and sub.points and #sub.points or 0
    if n == 0 then return end
    Confirm(string.format("Effacer les %d sommets de cette zone ?", n), function()
        ZG:ClearRegionPoints(panel.tracingId); Refresh()
    end)
end)
borderPick:SetScript("OnClick", function() borderBtn:GetScript("OnClick")(borderBtn) end)
finish:SetScript("OnClick", function()
    if ZG:FinishRegion(panel.tracingId) then
        panel:ExitTrace()
    else
        count:SetText("|cffe6c94dIl faut au moins 3 sommets pour fermer la zone.|r")
    end
end)
back:SetScript("OnClick", function() panel:ExitTrace() end)

function panel:EnterTrace(id)
    local sub = ZG:FindSubZone(id)
    if not sub or sub.shape ~= "polygon" then return end
    -- Le tracé rend la main au panneau : la page Carte doit y être rentrée,
    -- sinon on reviendrait sur un onglet Carte vide.
    if panel.carteFenetre and panel.carteFenetre:IsShown() then panel:ModeNomade(false) end
    panel.tracingId, panel.passageId = id, id
    panel:Hide()   -- libère la minimap du tracé du panneau avant de la prendre ici
    trace:ClearAllPoints()
    local pos = LCM_CrossingsChar and LCM_CrossingsChar.tracePos
    if pos then trace:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else trace:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180) end
    Refresh()
    trace:Show()
    -- On n'ouvre plus la fenêtre des frontières d'office : elle surgissait
    -- dès qu'on commençait un tracé, devant le tracé, alors que la frontière
    -- se pose maintenant sur la carte, après coup.
end

function panel:ExitTrace()
    trace:Hide()
    local sub, zone = ZG:FindSubZone(panel.tracingId)
    panel.tracingId = nil
    -- Un tracé revient chez le lieu qu'il dessert ; sans lieu, sur la carte
    -- de la région, d'où une zone orpheline se rattache. Le contour de la
    -- région n'a pas de fiche de lieu : il revient sur la carte, comme elle.
    local lieu = sub and sub.enterPlace and ZG:FindPlace(sub.enterPlace)
    if lieu and not lieu.pourRegion then
        panel.mode, panel.placeId, panel.passageId, panel.placeTab =
            "place", sub.enterPlace, sub.id, "zone"
        if zone then panel.zoneId = zone.id end
    elseif sub then
        panel.mode, panel.zoneId, panel.zoneTab, panel.passageId = "zone", zone.id, "carte", sub.id
    end
    panel:RefreshAll()
    panel:Show()
end
panel.traceWindow = trace
end

-- Dans le panneau complet, un périmètre en cours se reprend dans la fenêtre de tracé.
local traceBtn = Button(radarRow, "Reprendre le tracé", SIDE_X, 22, SIDE_W)
traceBtn:SetScript("OnClick", function() panel:EnterTrace(panel.passageId) end)
-- Déclarer une frontière ne touche pas à la géométrie : inutile de rouvrir le périmètre.
local declareBorderBtn = Button(radarRow, "Gérer les frontières…", SIDE_X, 102, SIDE_W)
declareBorderBtn:SetScript("OnClick", function() panel:OpenDeclareBorder() end)
local aurasBtn = Button(radarRow, "Auras imposées…", SIDE_X, 62, SIDE_W)
aurasBtn:SetScript("OnClick", function() panel:OpenPassageAuras() end)

local recaptureBtn = Button(radarRow, "Déplacer à ma position", SIDE_X, 168, SIDE_W)
recaptureBtn:SetScript("OnClick", function()
    if panel.passageId then ZG:RecaptureSubZone(panel.passageId) end
end)
local cloneBtn = Button(radarRow, "Dupliquer ici", SIDE_X, 210, SIDE_W)
cloneBtn:SetScript("OnClick", function()
    local clone = panel.passageId and ZG:CloneSubZone(panel.passageId)
    if clone then panel.passageId = clone.id; panel:RefreshAll() end
end)
local deletePassageBtn = Button(radarRow, "Supprimer la zone", SIDE_X, 252, SIDE_W)
deletePassageBtn:SetScript("OnClick", function()
    local id = panel.passageId
    local mot = GeoMot()
    Confirm(string.format("Supprimer cette %s ? Les lieux sont conservés.", mot), function()
        ZG:RemoveSubZone(id); panel.passageId = nil; panel:RefreshAll()
    end)
end)

-- Onglet Bannière et découverte de la région.
local settingsPage = zonePages.settings
Label(settingsPage, "Bannière par défaut des lieux", M, 0, FORM_W - 2 * M)
local zoneTheme = Dropdown(settingsPage, M, 20, FORM_W - 2 * M - 130)
zoneTheme.items = function() return ThemeItems("(Thème par défaut)") end
zoneTheme.onSelect = function(value) ZG:SetZoneTheme(panel.zoneId, value) end
local zoneEditTheme = Button(settingsPage, "Éditer", FORM_W - M - 116, 20, 116)
zoneEditTheme:SetScript("OnClick", function()
    local zone = ZG:GetZone(panel.zoneId)
    if zone then EditTheme(zone.themeId) end
end)
Rule(settingsPage, 72)
local zoneGrant = BuildDiscovery(settingsPage, 88, "Découverte des noms")
zoneGrant.openBtn:SetScript("OnClick", function()
    ZG:OpenKnowledge({ zone = panel.zoneId }, function() panel:RefreshForm() end)
end)
local zoneDelete = Button(settingsPage, "Supprimer la région", M, 350, 220)
zoneDelete:SetScript("OnClick", function() panel:DeleteRegion(panel.zoneId) end)

-- ── Onglet Carte : toutes les zones de la région, et la frontière ────────
--
-- Deux zones se collent en désignant leurs sommets ici, puis en disant qu'ils
-- se confondent. L'ancienne frontière (un tronçon nommé, repris en dessinant
-- la zone suivante) obligeait à dessiner dans le bon ordre et laissait sans
-- solution la zone qui touche deux voisines à la fois.

-- Tout l'onglet dans UNE table : Lua 5.1 n'accepte que 200 variables locales
-- dans le corps d'un fichier, et ce panneau en frôle le plafond (il l'a
-- dépassé le 1er novembre 2026, et plus rien ne se chargeait).
-- Une ligne au-dessus de la carte pour le contour de la RÉGION : CARTE_H est
-- le BAS de la carte, pour que tout ce qui se pose dessous ne bouge pas.
local carte = { page = zonePages.carte, H = 408, Y = 32 }
local cartePage, CARTE_H = carte.page, 32 + 408
carte.map = ZG.CreateZoneMap(cartePage, FORM_W - 2 * M, carte.H, {
    Region = function() return ZG:GetZone(panel.zoneId) end,
    OuvrirZone = function(sub, zone)
        if not sub then return end
        -- Le nom d'une zone ouvre le LIEU qu'elle dessert, sur son onglet
        -- Zone : c'est là qu'on la règle. Une zone qui ne mène nulle part n'a
        -- pas de fiche où aller — on la désigne ici, et le menu de
        -- rattachement apparaît sous la carte.
        --
        -- En nomade, on quitte d'abord la petite fenêtre : la fiche visée est
        -- dans le panneau, et la carte seule ne sait pas la montrer.
        if carte.fenetre and carte.fenetre:IsShown() then panel:ModeNomade(false) end
        local place = sub.enterPlace and ZG:FindPlace(sub.enterPlace)
        panel.passageId = sub.id
        if place and place.pourRegion then
            -- Le contour de la région n'a pas de fiche de lieu : il EST la
            -- région, dont on regarde déjà la carte.
            carte.orpheline = nil
            panel:RefreshAll()
        elseif place then
            carte.orpheline = nil
            -- Un bâtiment s'ouvre sur SA carte : c'est son intérieur qu'on
            -- vient voir en cliquant son point.
            panel.placeTab = place.batiment and "carte" or "zone"
            Select("place", place.id, zone and zone.id or panel.zoneId)
        else
            carte.orpheline = sub.id
            panel:RefreshAll()
        end
    end,
    Change = function() if panel.RefreshCarte then panel:RefreshCarte() end end,
})
Place(carte.map, cartePage, M, carte.Y)
panel.zoneMap = carte.map

-- Le contour de la région : l'étendue qui contient ses lieux. Hors de tout
-- lieu mais dedans, c'est elle qui donne la bannière — et c'est elle qu'on
-- soude aux régions voisines depuis la carte du pays.
carte.contour = Button(cartePage, "Dessiner le contour de la région", M, 0, 262)
carte.contour:SetScript("OnClick", function()
    local sub = ZG:CreateRegionArea(panel.zoneId)
    if sub then panel:EnterTrace(sub.id) end
end)
-- Mode nomade : la carte seule, dans une fenêtre à part. Le panneau entier
-- occupe tout l'écran et cache le jeu — or c'est en jeu qu'on relève un
-- contour, et il faut voir où l'on marche pendant qu'on le retouche.
carte.nomade = Button(cartePage, "Nomade", M + 270, 0, 96, 26)
carte.nomade:SetScript("OnClick", function() panel:ModeNomade() end)
-- La couleur de la RÉGION : ses lieux en reçoivent chacun une variante.
carte.couleur = panel.couleur.Pave(cartePage, M + 374, 0,
    function() return ZG:ZoneColor(ZG:GetZone(panel.zoneId)) end,
    function(r, v, b) ZG:SetZoneColor(panel.zoneId, r, v, b) end)
carte.contourMot = Caption(cartePage, "", M + 410, 2, FORM_W - 2 * M - 410)
carte.contourMot:SetHeight(28)
carte.contourMot:SetJustifyV("TOP")

carte.hint = Caption(cartePage, "", M, CARTE_H + 6, FORM_W - 2 * M)
carte.hint:SetHeight(34)
carte.hint:SetJustifyV("TOP")
carte.repos = "Glissez un sommet pour le déplacer, clic droit sur une arête pour en ajouter un, clic droit dans le vide pour tout désélectionner. Le nom d'une zone ouvre son lieu.\nPour une frontière : cliquez autant de sommets d'une zone que de sa voisine, puis « Les confondre »."
carte.etranger = "Région d'un autre auteur : la carte se regarde, elle ne se modifie pas."
Gestes.Poser(carte, cartePage, CARTE_H + 44)
-- Une zone qui ne mène à aucun lieu n'a plus de fiche où se régler depuis que
-- l'onglet Zones a disparu. On la rattache ici, et elle rejoint son lieu.
carte.rattacherLabel = Label(cartePage, "", M + 458, CARTE_H + 70, FORM_W - 2 * M - 458)
carte.rattacher = Dropdown(cartePage, M + 458, CARTE_H + 88, FORM_W - 2 * M - 458)
carte.rattacher.items = function()
    local items = {}
    for _, place in ipairs(ZG:GetPlaceList(panel.zoneId)) do
        items[#items + 1] = { text = place.name, value = place.id }
    end
    if #items == 0 then items[1] = { text = "Cette région n'a aucun lieu", title = true } end
    return items
end
carte.rattacher.onSelect = function(placeId)
    local id = carte.orpheline
    if not id or not placeId then return end
    ZG:SetPassagePlace(id, "enter", placeId)
    carte.orpheline = nil
    panel.passageId = id
    panel.placeTab = "zone"
    Select("place", placeId, panel.zoneId)
end
-- Une zone orpheline qu'on ne veut rattacher à rien : avant, on ne pouvait
-- que la laisser traîner. Elle se dessinait encore, portait encore ses auras,
-- et aucune fiche ne la montrait plus.
carte.jeter = Button(cartePage, "Supprimer cette zone", M + 458, CARTE_H + 124, FORM_W - 2 * M - 458)
carte.jeter:SetScript("OnClick", function()
    local id = carte.orpheline
    local sub = id and ZG:FindSubZone(id)
    if not sub then return end
    local n = #(sub.points or {})
    Confirm(string.format("Supprimer « %s » ? Ses %d sommet(s) sont perdus.", sub.name or "", n), function()
        ZG:RemoveSubZone(id)
        carte.orpheline = nil
        panel:RefreshAll()
    end)
end)

panel.carteBoutons = { fit = carte.fit, weld = carte.weld, unweld = carte.unweld,
                       clear = carte.clear, undo = carte.undo, hint = carte.hint,
                       rattacher = carte.rattacher, jeter = carte.jeter,
                       contour = carte.contour,
                       contourMot = carte.contourMot, nomade = carte.nomade }

-- ── Mode nomade ─────────────────────────────────────────────────────────
-- La page Carte entière déménage dans une petite fenêtre, et le panneau
-- s'efface. C'est le même procédé que l'éditeur de géométrie (geoPage change
-- de parent) : une seconde carte, entretenue en double, aurait fini par ne
-- plus montrer la même chose que la première.
carte.H_PAGE = 32 + 408 + 84 + 32   -- hauteur utile de la page Carte
carte.fenetre = CreateFrame("Frame", "LCMCrossingsNomade", UIParent)
carte.fenetre:SetSize(FORM_W + 2 * PAD, carte.H_PAGE + 2 * PAD + 30)
carte.fenetre:SetFrameStrata("HIGH"); carte.fenetre:SetClampedToScreen(true)
carte.fenetre:SetMovable(true); carte.fenetre:EnableMouse(true)
carte.fenetre:RegisterForDrag("LeftButton")
carte.fenetre:SetScript("OnDragStart", carte.fenetre.StartMoving)
carte.fenetre:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    LCM_CrossingsChar = LCM_CrossingsChar or {}
    LCM_CrossingsChar.nomadePos = { point, relPoint, x, y }
end)
UI.Surface(carte.fenetre); carte.fenetre:Hide()
carte.fenetreTitre = Label(carte.fenetre, "", PAD, 10, FORM_W - 460)
carte.fenetreFin = Button(carte.fenetre, "Panneau complet", FORM_W + PAD - 150, 6, 150, 24)
carte.fenetreFin:SetScript("OnClick", function() panel:ModeNomade(false) end)
panel.carteFenetre = carte.fenetre

-- ── Le terrain sous le tracé ────────────────────────────────────────────
-- L'image de la zone derrière le dessin, à la même échelle : on voit sur quoi
-- on pose ses sommets au lieu de les deviner sur un quadrillage vide.
--
-- La MINIMAP a été essayée et retirée. Deux raisons, et la seconde suffit :
-- elle ne montre qu'un disque de 230 yards au mieux, donc elle ne couvrira
-- jamais une région ; et comme le jeu refuse de la rogner, la faire tenir
-- derrière une page qui déménage entre le panneau et la fenêtre nomade
-- demandait de forcer caches et niveaux d'affichage — ce qui a rendu le
-- panneau transparent. L'image de zone n'a aucun de ces défauts : ce sont des
-- textures ordinaires, dans le cadre, sur la zone entière.
carte.MODES = { "aucun", "carte" }
carte.MOT_FOND = { aucun = "Fond : aucun", carte = "Fond : carte" }
carte.modeFond = "aucun"
carte.minimapBtn = Button(carte.fenetre, "Fond : aucun", FORM_W + PAD - 272, 6, 116, 24)
panel.carteBoutons.minimap = carte.minimapBtn

-- Le dossier des tuiles de minimap, réglable : le nom n'est pas exposé aux
-- addons, on le devine depuis le nom de la carte et on le corrige ici quand
-- la devinette tombe à côté.
carte.dossier = EditBox(carte.fenetre, FORM_W + PAD - 420, 6, 140, 24, 32)
carte.dossier:SetScript("OnEnterPressed", function(self)
    local _, mapID = carte.map:Dessinables()
    if mapID then ZG:SetMinimapDir(mapID, self:GetText()) end
    self:ClearFocus()
    if carte.modeFond == "carte" then carte.PoserMode("carte") end
end)
carte.dossierMot = Caption(carte.fenetre, "Tuiles", FORM_W + PAD - 480, 12, 56)

-- Revient au fond uni.
function carte.FondOff()
    if carte.modeFond == "aucun" then return end
    carte.modeFond = "aucun"
    carte.map.fondCarte = nil
    carte.minimapBtn:SetText(carte.MOT_FOND.aucun)
    carte.map:Draw()
end

function carte.PoserMode(mode)
    carte.FondOff()
    if mode == "aucun" then return end
    carte.modeFond = "carte"
    carte.map.fondCarte = true
    carte.map:Draw()
    if not carte.map.fondPose then
        local pourquoi = carte.map.fondPourquoi
        carte.FondOff()
        -- La raison en clair, et le dossier essayé : une carte muette, un
        -- mauvais nom de dossier et une carte sans image ne se corrigent pas
        -- pareil, et de dehors elles se ressemblent toutes les trois.
        carte.hint:SetText("|cffe6c94dPas de terrain ici : " .. (pourquoi or "le jeu ne donne pas de carte")
            .. (carte.map.fondDossier and (" (dossier essayé : " .. carte.map.fondDossier .. ")") or "") .. ".|r")
        return
    end
    carte.minimapBtn:SetText(carte.MOT_FOND.carte)
    if carte.map.fondDossier then
        panel.suppressEvents = true
        carte.dossier:SetText(carte.map.fondDossier)
        panel.suppressEvents = false
    end
end

carte.minimapBtn:SetScript("OnClick", function()
    carte.PoserMode(carte.modeFond == "aucun" and "carte" or "aucun")
end)
UISpecialFrames = UISpecialFrames or {}
table.insert(UISpecialFrames, "LCMCrossingsNomade")

-- actif : true pour partir, false pour revenir, nil pour basculer.
function panel:ModeNomade(actif)
    if actif == nil then actif = not carte.fenetre:IsShown() end
    if actif then
        if not ZG:GetZone(panel.zoneId) then return end
        panel.mode, panel.zoneTab = "zone", "carte"
        Place(cartePage, carte.fenetre, PAD, PAD + 30, FORM_W, carte.H_PAGE)
        carte.fenetre:SetScale(panel:GetScale())
        carte.fenetre:ClearAllPoints()
        local pos = LCM_CrossingsChar and LCM_CrossingsChar.nomadePos
        if pos then carte.fenetre:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        else carte.fenetre:SetPoint("CENTER") end
        carte.fenetre:Show()
        panel:Hide()
    else
        -- Le terrain d'abord rendu : la minimap doit retrouver son coin avant
        -- que la page ne quitte la fenêtre.
        carte.FondOff()
        -- La page retrouve sa place dans les onglets, à l'identique.
        Place(cartePage, zoneForm, 0, PAGE_Y, FORM_W, PANEL_H - HEADER_H - 42 - PAGE_Y)
        carte.fenetre:Hide()
        panel:Show()
    end
    carte.nomade:SetText(actif and "Fermer" or "Nomade")
    panel:RefreshAll()
end

-- Fermée par Échap : la page doit rentrer, sinon le panneau rouvrirait sur un
-- onglet Carte vide.
carte.fenetre:SetScript("OnHide", function()
    if cartePage:GetParent() == carte.fenetre then panel:ModeNomade(false) end
end)

-- Ce que la carte dit d'elle-même : les boutons et la phrase sont partagés
-- avec la carte du pays (voir Gestes), le rattachement d'une zone orpheline
-- est propre à la région.
function panel:RefreshCarte()
    local zone = ZG:GetZone(panel.zoneId)
    local own = zone and zone.creator == MyName()

    -- En nomade, la petite fenêtre dit de quelle région il s'agit : son nom
    -- n'est plus nulle part ailleurs à l'écran.
    carte.fenetreTitre:SetText("CARTE · " .. string.upper(zone and ZoneTitle(zone) or ""))

    carte.couleur:SetShown(own and true or false)
    if own then
        local c = carte.couleur.Lire() or { 1, 1, 1 }
        carte.couleur.pastille:SetColorTexture(c[1], c[2], c[3], 1)
    end

    -- Le contour de la région : à dessiner, ou à reprendre.
    local contour = ZG:GetRegionArea(panel.zoneId)
    carte.contour:SetShown(own and true or false)
    carte.contourMot:SetShown(own and true or false)
    if own then
        local trace = contour and contour.points and #contour.points > 0
        carte.contour:SetText(trace and "Reprendre le contour de la région" or "Dessiner le contour de la région")
        if not trace then
            carte.contourMot:SetText("L'étendue de la région entière : hors de tout lieu mais dedans, c'est elle qui s'affiche.")
        elseif contour.regionReady then
            carte.contourMot:SetText(string.format("%d sommet(s), fermé. Ses sommets se soudent aux régions voisines depuis la fiche du pays.", #contour.points))
        else
            carte.contourMot:SetText(string.format("|cffe6c94d%d sommet(s), pas encore fermé : il ne s'affichera pas tant qu'il ne l'est pas.|r", #contour.points))
        end
    end

    -- Le menu de rattachement ne sort que pour une zone orpheline désignée.
    local orpheline = carte.orpheline and ZG:FindSubZone(carte.orpheline)
    if orpheline and orpheline.enterPlace then orpheline = nil end
    carte.rattacherLabel:SetShown(own and orpheline ~= nil)
    carte.rattacher:SetShown(own and orpheline ~= nil)
    carte.jeter:SetShown(own and orpheline ~= nil)
    if own and orpheline then
        carte.rattacherLabel:SetText(string.format("« %s » ne mène à aucun lieu (%d sommets)",
            orpheline.name or "", #(orpheline.points or {})))
        carte.rattacher:SetText("Rattacher à un lieu…")
    end

    Gestes.Dire(carte, own)
end

-- L'éditeur de géométrie, dans l'onglet où il est appelé. `scope` vaut
-- "zones", "doors" ou "place" (voir GeoList).
local function RefreshGeoEditor(page, scope, own)
    panel.geoScope = scope
    geoPage:SetParent(page)
    geoPage:ClearAllPoints()
    geoPage:SetAllPoints(page)
    geoPage:Show()

    local porte = scope == "doors"
    local liste = GeoList()
    -- La sélection retenue doit appartenir à la liste affichée : sinon
    -- l'onglet Zones montrerait le passage choisi dans l'onglet voisin.
    local sub
    for _, candidat in ipairs(liste) do
        if candidat.id == panel.passageId then sub = candidat; break end
    end
    if not sub then
        sub = liste[1]
        panel.passageId = sub and sub.id or nil
    end

    -- Dans la fiche d'un lieu, c'est la nature du lieu qui décide : une porte
    -- pose une porte droite, un lieu dessine une étendue.
    local place = scope == "place" and ZG:FindPlace(panel.placeId) or nil
    local droite = porte or (place ~= nil and place.porte == true)

    geoLabel:SetText(droite and "Porte" or "Zone")
    addPassageBtn:SetText(droite and "+ Porte ici" or "+ Zone ici")
    addPassageBtn:SetShown(own)
    passagesEmpty:SetText(droite
        and "Aucune porte posée. Placez-vous en jeu à l'endroit voulu, puis « + Porte ici ».\n\nUne porte se traverse : on entre par le côté vert, on sort par le côté rouge."
        or "Aucune zone ne mène à ce lieu.\n\nPosez ses sommets avec « + Zone ici », en vous déplaçant en jeu.")
    passagePicker:SetShown(sub ~= nil)
    passagesEmpty:SetShown(sub == nil)
    editor:SetShown(sub ~= nil)
    if not sub then return end

    nameLabel:SetText(droite and "Nom de la porte" or "Nom de la zone")
    passagePicker:SetText(sub.name or "")
    panel.suppressEvents = true
    passageName:SetText(sub.name or "")
    panel.suppressEvents = false
    passageName:SetEnabled(own)
    passageActive:SetChecked(sub.enabled)
    passageActive:SetEnabled(own)

    local isPolygon = sub.shape == "polygon"
    -- Plus de bascule de forme dans la fiche d'un lieu : un lieu dessine une
    -- étendue, une porte se traverse, et on ne passe pas de l'un à l'autre.
    -- Le choix ne survit que dans l'onglet Passages de la région, qui porte
    -- les tracés d'avant cette séparation.
    shapeLineBtn.accent:SetShown(not isPolygon)
    shapeRegionBtn.accent:SetShown(isPolygon)
    shapeLineBtn:SetShown(own and scope == "doors")
    shapeRegionBtn:SetShown(own and scope == "doors")

    -- La couleur du lieu prend la place de « Forme », que la fiche d'un lieu
    -- ne montre pas : un lieu dessine une étendue, on n'en change pas.
    local colorable = own and isPolygon and scope == "place" and place ~= nil
        and not place.porte
    panel.couleur.lieuMot:SetShown(colorable and true or false)
    panel.couleur.lieu:SetShown(colorable and true or false)
    if colorable then
        local c = panel.couleur.lieu.Lire() or { 1, 1, 1 }
        panel.couleur.lieu.pastille:SetColorTexture(c[1], c[2], c[3], 1)
        panel.couleur.lieuMot:SetText(place.couleur and "Couleur (à lui)" or "Couleur (héritée)")
    end

    enterCaption:SetText(isPolygon and "À l'intérieur, on entre dans :" or "En entrant (côté vert), on arrive à :")
    leaveCaption:SetText(isPolygon and "En sortant, on arrive à :" or "En sortant (côté rouge), on arrive à :")
    enterPicker:SetText(PlaceText(sub.enterPlace, "(Aucun lieu)"))
    leavePicker:SetText(PlaceText(sub.leavePlace, "(Aucun — rien ne s'affiche)"))
    SetDropdownEnabled(enterPicker, own); SetDropdownEnabled(leavePicker, own)
    -- Périmètre : ce qu'on trouve en sortant dépend du périmètre voisin (frontière).
    leaveCaption:SetShown(not isPolygon); leavePicker:SetShown(not isPolygon)

    -- La tranche d'altitude prend la place du lieu « en sortant », et ne sort
    -- que pour un intérieur : une zone à ciel ouvert monte sans fin, exprès.
    local lieuZone = sub.enterPlace and ZG:FindPlace(sub.enterPlace)
    local interieur = isPolygon and lieuZone ~= nil
        and (lieuZone.batiment == true or ZG:BatimentDe(lieuZone) ~= nil)
    for _, w in pairs(panel.hauteur) do
        if type(w) == "table" and w.SetShown then w:SetShown(interieur and true or false) end
    end
    if interieur then
        panel.suppressEvents = true
        panel.hauteur.bas:SetText(sub.bas and tostring(math.floor(sub.bas)) or "")
        panel.hauteur.haut:SetText(sub.haut and tostring(math.floor(sub.haut)) or "")
        panel.suppressEvents = false
        panel.hauteur.bas:SetEnabled(own); panel.hauteur.haut:SetEnabled(own)
        panel.hauteur.sol:SetShown(own)
        panel.hauteur.titre:SetText(sub.z
            and string.format("Intérieur : tranche d'altitude (yards), sol à %d", math.floor(sub.z))
            or "|cffe6c94dIntérieur : altitude du sol inconnue|r")
    end

    widthLabel:SetShown(not isPolygon); widthEB:SetShown(not isPolygon)
    sliderTrack:SetShown(not isPolygon); sliderHandle:SetShown(not isPolygon)
    widthEB:SetEnabled(own); sliderHandle:EnableMouse(own)
    if not isPolygon then SetSliderValue(sub.width or 6, true) end

    regionLabel:SetShown(isPolygon)
    local editing = isPolygon and own and not sub.regionReady
    addPointBtn:Hide(); undoPointBtn:Hide(); clearPointsBtn:Hide(); borderBtn:Hide()
    traceBtn:SetShown(editing)
    declareBorderBtn:SetShown(isPolygon and own and sub.points ~= nil and #sub.points >= 3)
    finishRegionBtn:SetShown(isPolygon and own)
    -- Les auras d'une ZONE se règlent dans l'onglet Aura de son lieu ; il ne
    -- reste ici que celles d'un passage droit, qui n'a pas de fiche à lui.
    aurasBtn:SetShown(own and not isPolygon)
    Place(aurasBtn, radarRow, SIDE_X, 102)
    local auraCount = sub.auras and #sub.auras or 0
    aurasBtn:SetText(auraCount > 0 and string.format("Auras imposées… (%d)", auraCount) or "Auras imposées…")
    -- Nommer un sommet : possible même périmètre fermé (la géométrie ne change pas).
    local count = isPolygon and sub.points and #sub.points or 0
    local naming = isPolygon and own and count > 0
    vertexLabel:SetShown(naming); vertexPicker:SetShown(naming); vertexName:SetShown(naming)
    if naming then
        if not panel.vertexIndex or panel.vertexIndex > count or panel.vertexPassage ~= sub.id then
            panel.vertexIndex, panel.vertexPassage = count, sub.id
        end
        local point = sub.points[panel.vertexIndex]
        vertexPicker:SetText("Point " .. panel.vertexIndex)
        panel.suppressEvents = true
        vertexName:SetText(point.name or "")
        panel.suppressEvents = false
    end
    if isPolygon then
        local n = sub.points and #sub.points or 0
        if sub.regionReady then
            regionLabel:SetText(string.format("|cff66e673Zone fermée — %d sommets.|r", n))
            finishRegionBtn:SetText("Rouvrir la zone")
        else
            regionLabel:SetText(string.format(n < 3 and "|cffe6c94d%d sommet(s) — il en faut au moins 3.|r" or "|cffe6c94d%d sommets — prête à fermer.|r", n))
            finishRegionBtn:SetText("Fermer la zone")
        end
    end

    -- Déplacer / dupliquer n'ont de sens que pour un passage droit (UN point).
    recaptureBtn:SetShown(own and not isPolygon)
    cloneBtn:SetShown(own and not isPolygon)
    deletePassageBtn:SetShown(own)
end

local function RefreshZoneForm()
    local zone = ZG:GetZone(panel.zoneId)
    local own = zone.creator == MyName()
    panel.suppressEvents = true
    zoneName:SetText(ZoneTitle(zone))
    panel.suppressEvents = false
    zoneName:SetEnabled(own)
    local country = ZG:GetCountry(zone.countryId)
    zoneCountry:SetText(country and country.name or "(Sans pays)")
    SetDropdownEnabled(zoneCountry, own)
    -- L'onglet Lieux ne liste que les lieux : les portes se trouvent sous le
    -- lieu qu'elles desservent, dans la liste de gauche.
    local places = ZG:GetLieuList(zone.id)
    local areas, portes = ZG:GetAreaList(zone.id), ZG:GetPorteList(zone.id)
    zoneStatus:SetText(string.format("%s · %d lieu(x) · %d zone(s) · %d porte(s)",
        own and "|cff66e673Vous êtes l'auteur|r" or ("Auteur : " .. zone.creator),
        #places, #areas, #portes))

    -- Les auras de la RÉGION se posent sur son contour : qui y entre les
    -- reçoit, où qu'il soit dedans. Celles de ses lieux s'y ajoutent.
    if panel.zoneTab == "aura" then
        panel:RefreshAuras(own, zonePages.aura, ZG:GetRegionArea(zone.id), true)
    end

    -- Lieux
    addPlaceBtn:SetShown(own)
    placesEmpty:SetShown(#places == 0)
    for i, b in ipairs(placeButtons) do
        local place = places[i]
        b:SetShown(place ~= nil)
        if place then
            local count = #ZG:GetPlacePassages(place.id)
            b:SetText(PlaceTitle(place, zone) .. string.format("   |cff888888· %d accès|r", count))
            b:SetScript("OnClick", function() Select("place", place.id, zone.id) end)
        end
    end
    placesMore:SetText(#places > MAX_PLACE_ROWS and string.format("… et %d autre(s) : voir la liste à gauche.", #places - MAX_PLACE_ROWS) or "")

    -- La géométrie : l'onglet actif choisit la forme montrée. Hors de ces
    -- deux onglets, l'éditeur ne s'affiche pas — il est peut-être parti dans
    -- la fiche d'un lieu.
    if panel.zoneTab == "doors" then
        RefreshGeoEditor(zonePages.doors, "doors", own)
    end

    if panel.zoneTab == "carte" then
        -- La vue se cadre sur la région, une fois par région : refaire le
        -- cadrage à chaque rafraîchissement annulerait le zoom en cours.
        if carte.map.cadree ~= panel.zoneId then
            carte.map.cadree = panel.zoneId
            carte.map:Fit()
        end
        carte.map:Draw()
        panel:RefreshCarte()
    end

    -- Bannière et découverte
    local theme = zone.themeId and ZG:GetTheme(zone.themeId)
    zoneTheme:SetText(theme and theme.name or "(Thème par défaut)")
    SetDropdownEnabled(zoneTheme, own)
    zoneEditTheme:SetShown(own)
    zoneGrant:SetShown(own)
    if own then
        zoneGrant.summary:SetText(string.format("Nom de la région connu de %d joueur(s). Le panneau Connaissances apprend des régions et des lieux à plusieurs joueurs à la fois.", ZG:DiscoveryCount(zone)))
    end
    zoneDelete:SetShown(own)
    ShowZoneTab()
end

-- ── Fiche Lieu ──────────────────────────────────────────────────────────────

local placeForm = CreateFrame("Frame", nil, form)
placeForm:SetAllPoints()
local placeHeader = Label(placeForm, "", M, 4, FORM_W - 2 * M - 268)
local placeName = EditBox(placeForm, M, 24, FORM_W - 2 * M - 268)
placeName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "place" then return end
    ZG:RenamePlace(panel.placeId, self:GetText())
    panel:RefreshTree()
end)
-- Un lieu peut en contenir d'autres : une crypte sous son mausolée, un
-- hameau dans sa forêt. Du rangement seulement — la géométrie n'en sait rien.
Label(placeForm, "Dans", FORM_W - M - 252, 4, 252)
local placeParent = Dropdown(placeForm, FORM_W - M - 252, 24, 252)
placeParent.items = function()
    local items = { { text = "(Directement dans la région)", value = "" } }
    for _, autre in ipairs(ZG:GetLieuList(panel.zoneId)) do
        -- Ni soi-même, ni ses propres descendants : ZG:SetPlaceParent les
        -- refuserait, autant ne pas les proposer.
        if autre.id ~= panel.placeId then
            local boucle, courant, garde = false, autre, 0
            while courant and courant.parent and garde < 32 do
                if courant.parent == panel.placeId then boucle = true; break end
                courant = ZG:FindPlace(courant.parent)
                garde = garde + 1
            end
            if not boucle then items[#items + 1] = { text = autre.name, value = autre.id } end
        end
    end
    return items
end
placeParent.onSelect = function(value)
    ZG:SetPlaceParent(panel.placeId, value)
    panel:RefreshAll()
end
local placeStatus = Caption(placeForm, "", M + 2, 70, FORM_W - 2 * M)

-- L'onglet Zone : la zone de CE lieu se règle là où on règle le lieu. Il
-- fallait sinon revenir sur la région, ouvrir ses passages et retrouver le
-- bon dans une liste.
local placePages, placeTabs, ShowPlaceTab = Tabs(placeForm,
    { { "carte", "Carte" }, { "zone", "Zone" }, { "aura", "Aura" }, { "banner", "Bannière" },
      { "effects", "Effets" }, { "arcanum", "Arcanum" }, { "discovery", "Découverte" } },
    function() return panel.placeTab end, function(key) panel.placeTab = key end)
panel.placePages = placePages
panel.placeTabs = placeTabs

-- ── Onglet Carte d'un bâtiment ──────────────────────────────────────────
-- Un bâtiment se tient comme une région : son empreinte au sol en guise de
-- contour, ses pièces dedans, et les mêmes gestes pour poser leurs cloisons.
-- L'onglet se cache pour un lieu ordinaire (voir Tabs).
--
-- Les réglages de hauteur vivent dans cette table mais se posent sur
-- geoPage : ils appartiennent à l'onglet Zone, et une table de plus coûterait
-- un local dont ce fichier n'a plus.
local bati = { page = placePages.carte, H = 408, Y = 32 }
bati.map = ZG.CreateZoneMap(bati.page, FORM_W - 2 * M, bati.H, {
    Batiment = function() return ZG:FindPlace(panel.placeId) end,
    OuvrirZone = function(sub)
        local lieu = sub and sub.enterPlace and ZG:FindPlace(sub.enterPlace)
        -- Le nom de l'empreinte, c'est le bâtiment lui-même : on y est déjà.
        if lieu and lieu.id ~= panel.placeId then
            panel.passageId = sub.id
            panel.placeTab = "zone"
            Select("place", lieu.id, lieu.zoneId)
        end
    end,
    Change = function() Gestes.Dire(bati, bati.own) end,
})
Place(bati.map, bati.page, M, bati.Y)
panel.batiMap = bati.map
bati.contour = Button(bati.page, "Reprendre l'empreinte au sol", M, 0, 300)
bati.contour:SetScript("OnClick", function()
    local sub = ZG:GetBatimentArea(panel.placeId)
    if sub then panel:EnterTrace(sub.id) end
end)
bati.mot = Caption(bati.page, "", M + 310, 8, FORM_W - 2 * M - 310)
bati.hint = Caption(bati.page, "", M, 32 + 408 + 6, FORM_W - 2 * M)
bati.hint:SetHeight(34); bati.hint:SetJustifyV("TOP")
bati.repos = "Glissez un sommet pour le déplacer, clic droit sur une arête pour en ajouter un, clic droit dans le vide pour tout désélectionner. Le nom d'une pièce ouvre sa fiche.\nPour une cloison : cliquez autant de sommets d'une pièce que de sa voisine, puis « Les confondre »."
bati.etranger = "Bâtiment d'un autre auteur : la carte se regarde, elle ne se modifie pas."
Gestes.Poser(bati, bati.page, 32 + 408 + 44)
panel.batiBoutons = { fit = bati.fit, weld = bati.weld, unweld = bati.unweld,
                      clear = bati.clear, undo = bati.undo, hint = bati.hint,
                      contour = bati.contour }

function panel:RefreshBatiCarte(own)
    bati.own = own
    local empreinte = ZG:GetBatimentArea(panel.placeId)
    local pieces = #ZG:GetPieceList(panel.placeId)
    bati.contour:SetShown(own and empreinte ~= nil)
    if empreinte then
        local n = #(empreinte.points or {})
        bati.mot:SetText(string.format("Empreinte : %d sommet(s)%s · %s%s",
            n, empreinte.regionReady and ", fermée" or ", |cffe6c94dpas encore fermée|r",
            pieces > 0 and (pieces .. " pièce(s)") or "aucune pièce",
            (empreinte.bas or empreinte.haut)
                and string.format(" · %d yd sous, %d yd sur le sol", empreinte.bas or 0, empreinte.haut or 0)
                or " · |cffe6c94dhauteur infinie : ce n'est pas encore un intérieur|r"))
    else
        bati.mot:SetText("")
    end
    if bati.map.cadree ~= panel.placeId then
        bati.map.cadree = panel.placeId
        bati.map:Fit()
    end
    bati.map:Draw()
    Gestes.Dire(bati, own)
end

-- ── Onglet Aura du lieu ─────────────────────────────────────────────────
-- Les auras imposées vivaient sur la ZONE, derrière un bouton de l'éditeur de
-- géométrie : on ne les trouvait qu'en passant par la région. Elles se posent
-- en entrant dans un LIEU — c'est donc dans sa fiche qu'elles se règlent.
--
-- La liste et le retrait sont ici ; l'ajout garde sa fenêtre
-- (LCMCrossingsAuraManager), qui montre à côté les auras d'Epsilon Aura
-- Manager. Une seconde écriture de ce panneau ne vaudrait pas son entretien.
-- La page déménage entre l'onglet Aura d'un LIEU et celui d'une RÉGION, comme
-- l'éditeur de géométrie : une région impose ses auras à qui entre dans son
-- contour, un lieu aux siennes, et c'est le même réglage. Deux copies auraient
-- fini par diverger.
local aura = { page = CreateFrame("Frame", nil, placeForm), lignes = {}, MAX = 8 }
aura.page:SetAllPoints(placePages.aura)
aura.page:Hide()
aura.mot = Caption(aura.page, "", M, 0, FORM_W - 2 * M)
aura.mot:SetHeight(32)
aura.vide = Caption(aura.page, "", M, 44, FORM_W - 2 * M)
aura.vide:SetHeight(40)
for i = 1, aura.MAX do
    local y = 44 + (i - 1) * 32
    local ligne = Caption(aura.page, "", M + 4, y + 8, FORM_W - 2 * M - 130)
    UI.ApplyBodyText(ligne)
    local retirer = Button(aura.page, "Retirer", FORM_W - M - 110, y, 110, 26)
    ligne:Hide(); retirer:Hide()
    aura.lignes[i] = { texte = ligne, retirer = retirer }
end
aura.ajouter = Button(aura.page, "Ajouter une aura…", M, 44 + aura.MAX * 32 + 12, 260)
aura.ajouter:SetScript("OnClick", function()
    -- La fenêtre d'auras travaille sur panel.passageId : on la pointe sur la
    -- zone visée avant de l'ouvrir.
    if not aura.sub then return end
    panel.passageId = aura.sub.id
    panel:OpenPassageAuras()
end)
panel.auraPage = aura

-- `page` : l'onglet qui l'accueille. `sub` : la zone dont on règle les auras —
-- celle d'un lieu, ou le contour d'une région. `pourRegion` ne change que les
-- phrases : le réglage est le même.
function panel:RefreshAuras(own, page, sub, pourRegion)
    aura.page:SetParent(page)
    aura.page:ClearAllPoints()
    aura.page:SetAllPoints(page)
    aura.page:Show()
    aura.sub = sub
    aura.mot:SetText(pourRegion
        and "Tant qu'un joueur se trouve dans le contour de cette région, ces auras lui sont posées, et reposées si elles disparaissent. Celles de ses lieux s'y ajoutent."
        or "Tant qu'un joueur se trouve dans la zone de ce lieu, ces auras lui sont posées, et reposées si elles disparaissent. Elles sont retirées dès qu'il en sort.")
    local liste = sub and ZG:GetPassageAuras(sub.id) or {}
    aura.ajouter:SetShown(own and sub ~= nil)
    for i, ligne in ipairs(aura.lignes) do
        local entry = own and liste[i] or nil
        ligne.texte:SetShown(entry ~= nil)
        ligne.retirer:SetShown(entry ~= nil)
        if entry then
            local nom, _, icone = GetSpellInfo(entry.id)
            ligne.texte:SetText(string.format("|T%s:16|t %s  |cff888888%d|r",
                icone or 136243, nom or "Sort inconnu", entry.id))
            ligne.retirer:SetScript("OnClick", function()
                ZG:RemovePassageAura(sub.id, entry.id)
                panel:RefreshForm()
            end)
        end
    end
    local trop = #liste - aura.MAX
    if not own then
        aura.vide:SetText("D'un autre auteur : ses auras ne se modifient pas d'ici.")
    elseif not sub then
        aura.vide:SetText(pourRegion
            and "Cette région n'a pas de contour.\nDessinez-le dans l'onglet Carte : sans étendue, il n'y a nulle part où imposer une aura."
            or "Ce lieu n'a pas de zone.\nDessinez-la dans l'onglet Zone : les auras se posent en y entrant.")
    elseif #liste == 0 then
        aura.vide:SetText("Aucune aura imposée.")
    else
        aura.vide:SetText(trop > 0 and string.format("… et %d autre(s) : voir « Ajouter une aura… ».", trop) or "")
    end
    aura.vide:ClearAllPoints()
    aura.vide:SetPoint("TOPLEFT", aura.page, "TOPLEFT", M,
        -(44 + math.min(#liste, aura.MAX) * 32 + (#liste > 0 and 8 or 0)))
end

-- Gardé sous son ancien nom : le banc l'appelle.
function panel:RefreshPlaceAuras(own)
    local zones = ZG:GetPlaceAreas(panel.placeId)
    panel:RefreshAuras(own, placePages.aura, zones[1] and zones[1].sub, false)
end

-- Bannière
local bannerPage = placePages.banner
Label(bannerPage, "Bannière de ce lieu", M, 0, FORM_W - 2 * M)
local placeTheme = Dropdown(bannerPage, M, 20, FORM_W - 2 * M - 130)
placeTheme.items = function() return ThemeItems("(Bannière de la région)") end
placeTheme.onSelect = function(value) ZG:SetPlaceTheme(panel.placeId, value) end
local placeEditTheme = Button(bannerPage, "Éditer", FORM_W - M - 116, 20, 116)
placeEditTheme:SetScript("OnClick", function()
    local place = ZG:FindPlace(panel.placeId)
    if place then EditTheme(place.themeId) end
end)
Caption(bannerPage, "Quand un passage mène ici, la bannière affiche « Région / Lieu ».", M, 64, FORM_W - 2 * M)
Rule(bannerPage, 94)
Label(bannerPage, "Passages qui mènent ici", M, 110, FORM_W - 2 * M)
local linkLines = {}
for i = 1, 8 do linkLines[i] = Caption(bannerPage, "", M + 2, 110 + i * 24, FORM_W - 2 * M) end
local placeDelete = DangerButton(placeForm, "Supprimer le lieu", 220)
placeDelete:SetScript("OnClick", function() panel:DeletePlace(panel.placeId) end)

-- Effets
local effectsPage = placePages.effects
Label(effectsPage, "Action quand le joueur arrive ou part", M, 0, FORM_W - 2 * M)
local actionMsgLabel = Caption(effectsPage, "Message local", M, 36, FORM_W - 2 * M)
local actionMsg = EditBox(effectsPage, M, 54, FORM_W - 2 * M, FIELD_H, 120)
actionMsg:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "place" then return end
    ZG:SetPlaceActionMessage(panel.placeId, self:GetText())
end)
local actionCmdLabel = Caption(effectsPage, "Commande ou ID d'aura", M, 104, FORM_W - 2 * M)
local actionCmd = EditBox(effectsPage, M, 122, FORM_W - 2 * M, FIELD_H, 120)
actionCmd:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "place" then return end
    ZG:SetPlaceActionCommand(panel.placeId, self:GetText())
end)
local actionHint = Caption(effectsPage, "Un nombre applique l'aura à l'arrivée et la retire au départ. Une commande est envoyée dans le canal de groupe disponible.", M, 164, FORM_W - 2 * M)
actionHint:SetHeight(30)
Rule(effectsPage, 206)
local actionEnter, actionEnterLabel = Checkbox(effectsPage, "À l'arrivée dans le lieu", M, 222)
actionEnter:SetScript("OnClick", function(self) ZG:SetPlaceActionEnabled(panel.placeId, "enter", self:GetChecked()) end)
local actionLeave, actionLeaveLabel = Checkbox(effectsPage, "Au départ du lieu", FORM_W / 2, 222)
actionLeave:SetScript("OnClick", function(self) ZG:SetPlaceActionEnabled(panel.placeId, "leave", self:GetChecked()) end)
local effectsReadOnly = Caption(effectsPage, "Réglé par l'auteur de la région.", M, 36, FORM_W - 2 * M)

-- Sort Arcanum : lancé en arrivant dans le lieu, défait en le quittant.
local arcPage = placePages.arcanum
local arc = {}
arc.intro = Caption(arcPage, "Lance un sort Arcanum tant que le joueur est dans ce lieu, quel que soit le passage emprunté. En le quittant, le sort de sortie défait l'effet — ciel, brouillard, aura…", M, 0, FORM_W - 2 * M)
arc.intro:SetHeight(40)
arc.readOnly = Caption(arcPage, "Réglé par l'auteur de la région.", M, 60, FORM_W - 2 * M)
local function ArcSpellField(y, label, which)
    local field = {}
    field.caption = Caption(arcPage, label, M, y, FORM_W - 2 * M)
    field.box = EditBox(arcPage, M, y + 18, FORM_W - 2 * M - 130, FIELD_H, 80)
    field.test = Button(arcPage, "Tester", FORM_W - M - 116, y + 18, 116)
    field.status = Caption(arcPage, "", M, y + 56, FORM_W - 2 * M)
    field.box:SetScript("OnTextChanged", function(self)
        if panel.suppressEvents or panel.mode ~= "place" then return end
        ZG:SetPlaceArcSpell(panel.placeId, which, self:GetText())
        panel:RefreshArcStatus()
    end)
    field.test:SetScript("OnClick", function()
        local place = ZG:FindPlace(panel.placeId)
        if place then ZG:CastArcSpell(field.box:GetText(), place.arcVault) end
    end)
    return field
end
arc.enter = ArcSpellField(56, "Sort à l'arrivée (ArcSpell ID)", "enter")
arc.exit = ArcSpellField(140, "Sort au départ — retire l'effet (facultatif)", "exit")
arc.rule = Rule(arcPage, 222)
arc.phaseCB, arc.phaseLabel = Checkbox(arcPage, "Coffre de phase (recommandé : disponible pour tous les joueurs de la phase)", M, 238)
arc.phaseCB:SetScript("OnClick", function(self)
    ZG:SetPlaceArcVault(panel.placeId, self:GetChecked() and "phase" or "personal")
    panel:RefreshArcStatus()
end)
arc.toggleCB, arc.toggleLabel = Checkbox(arcPage, "Le joueur peut retirer puis remettre l'effet sur place", M, 272)
arc.toggleCB:SetScript("OnClick", function(self) ZG:SetPlaceArcToggle(panel.placeId, self:GetChecked()) end)
arc.hint = Caption(arcPage, "Un sort du coffre personnel n'existe que chez vous : les autres joueurs ne le recevront pas. Au départ, le sort d'arrivée encore en cours est interrompu avant le sort de départ. Sans sort de départ, l'effet suit sa propre durée.", M, 314, FORM_W - 2 * M)
arc.hint:SetHeight(58)

local function ArcStatusText(commID, vault)
    commID = (commID or ""):match("^%s*(.-)%s*$") or ""
    if commID == "" then return "" end
    if type(ARC) ~= "table" then return "|cffe6c94dArcanum n'est pas chargé.|r" end
    local spell = ZG:FindArcSpell(commID, vault)
    if spell then return "|cff66e673Trouvé : " .. (spell.fullName or commID) .. "|r" end
    return "|cffe6c94dIntrouvable dans le coffre " .. (vault == "personal" and "personnel" or "de phase") .. ".|r"
end

function panel:RefreshArcStatus()
    local place = ZG:FindPlace(self.placeId)
    if not place then return end
    arc.enter.status:SetText(ArcStatusText(place.arcEnterSpell, place.arcVault))
    arc.exit.status:SetText(ArcStatusText(place.arcExitSpell, place.arcVault))
end

-- Découverte
local discoveryPage = placePages.discovery
local placeGrant = BuildDiscovery(discoveryPage, 0, "Découverte du nom")
placeGrant.openBtn:SetScript("OnClick", function()
    if panel.placeId then ZG:OpenKnowledge({ place = panel.placeId }, function() panel:RefreshForm() end) end
end)
Caption(discoveryPage, "Le nom de la région et celui du lieu se révèlent séparément. Les autres joueurs voient des « ????? » tant qu'ils ne les ont pas appris.", M, 130, FORM_W - 2 * M)

local function RefreshPlaceForm()
    local place, zone = ZG:FindPlace(panel.placeId)
    local own = zone.creator == MyName()
    placeHeader:SetText((ZG:EstPorte(place) and "PORTE · "
        or (ZG:EstBatiment(place) and "BÂTIMENT · " or "LIEU · ")) .. ZoneTitle(zone))
    panel.suppressEvents = true
    placeName:SetText(PlaceTitle(place, zone))
    panel.suppressEvents = false
    placeName:SetEnabled(own)
    local links = ZG:GetPlacePassages(place.id)
    local dedans = #ZG:GetChildPlaces(zone.id, place.id)
    placeStatus:SetText(string.format("%s · atteint par %d accès%s%s",
        own and "|cff66e673Vous êtes l'auteur|r" or ("Auteur : " .. zone.creator), #links,
        dedans > 0 and string.format(" · contient %d lieu(x)", dedans) or "",
        ZG:IsInPlace(place.id) and " · |cff66e673vous y êtes|r" or ""))

    local parent = place.parent and ZG:FindPlace(place.parent)
    placeParent:SetText(parent and parent.name or "(Directement dans la région)")
    SetDropdownEnabled(placeParent, own)

    -- Seul un bâtiment a une carte : celle de ses pièces.
    local batiment = ZG:EstBatiment(place)
    placeTabs.carte.cache = not batiment
    if panel.placeTab == "carte" and not batiment then panel.placeTab = "zone" end

    -- L'onglet Zone emprunte l'éditeur de géométrie de la région, limité aux
    -- zones qui mènent ICI.
    if panel.placeTab == "zone" then RefreshGeoEditor(placePages.zone, "place", own) end
    if panel.placeTab == "aura" then panel:RefreshPlaceAuras(own) end
    if panel.placeTab == "carte" then panel:RefreshBatiCarte(own) end

    local theme = place.themeId and ZG:GetTheme(place.themeId)
    placeTheme:SetText(theme and theme.name or "(Bannière de la région)")
    SetDropdownEnabled(placeTheme, own)
    placeEditTheme:SetShown(own)
    for i, line in ipairs(linkLines) do
        local link = links[i]
        if link then
            line:SetText(string.format("%s  |cff888888(%s) — %s|r", link.sub.name or "", ZoneTitle(link.zone),
                link.which == "enter" and "en entrant" or "en sortant"))
        else
            line:SetText(i == 1 and "Aucun pour l'instant : dessinez une zone autour, ou posez un passage qui mène ici." or "")
        end
    end
    placeDelete:SetShown(own)

    for _, control in ipairs({ actionMsgLabel, actionCmdLabel, actionHint, actionMsg, actionCmd, actionEnter, actionEnterLabel, actionLeave, actionLeaveLabel }) do control:SetShown(own) end
    effectsReadOnly:SetShown(not own)
    if own then
        panel.suppressEvents = true
        actionMsg:SetText(place.actionMessage or "")
        actionCmd:SetText(place.actionCommand or "")
        panel.suppressEvents = false
        actionEnter:SetChecked(place.actionEnterEnabled)
        actionLeave:SetChecked(place.actionLeaveEnabled)
    end

    for _, field in ipairs({ arc.enter, arc.exit }) do
        for _, control in pairs(field) do control:SetShown(own) end
    end
    for _, control in ipairs({ arc.rule, arc.phaseCB, arc.phaseLabel, arc.toggleCB, arc.toggleLabel, arc.hint }) do control:SetShown(own) end
    arc.readOnly:SetShown(not own)
    if own then
        panel.suppressEvents = true
        arc.enter.box:SetText(place.arcEnterSpell or "")
        arc.exit.box:SetText(place.arcExitSpell or "")
        panel.suppressEvents = false
        arc.phaseCB:SetChecked(place.arcVault ~= "personal")
        arc.toggleCB:SetChecked(place.arcToggle ~= false)
        panel:RefreshArcStatus()
    end

    placeGrant:SetShown(own)
    if own then
        placeGrant.summary:SetText(string.format("Nom du lieu connu de %d joueur(s), nom de la région de %d joueur(s).", ZG:DiscoveryCount(place), ZG:DiscoveryCount(zone)))
    end
    ShowPlaceTab()
end

-- ── Bascule entre fiches ──────────────────────────────────────────────────

function panel:RefreshForm()
    countryForm:Hide(); zoneForm:Hide(); placeForm:Hide(); placeholder:Hide()
    if self.mode == "country" and ZG:GetCountry(self.countryId) then
        RefreshCountryForm(); countryForm:Show()
    elseif self.mode == "zone" and ZG:GetZone(self.zoneId) then
        RefreshZoneForm(); zoneForm:Show()
    elseif self.mode == "place" and ZG:FindPlace(self.placeId) then
        RefreshPlaceForm(); placeForm:Show()
    else
        placeholder:Show()
    end
end

function panel:RefreshAll()
    if self.mode == "country" and not ZG:GetCountry(self.countryId) then self.mode = nil end
    if self.mode == "zone" and not ZG:GetZone(self.zoneId) then self.mode = nil end
    if self.mode == "place" then
        local place, zone = ZG:FindPlace(self.placeId)
        if not place then self.mode = nil else self.zoneId = zone.id end
    end
    self:RefreshTree()
    self:RefreshForm()
end

panel:HookScript("OnHide", function()
    confirm:Hide(); prompt:Hide(); reassign:Hide(); border:Hide(); sliderHandle:SetScript("OnUpdate", nil)
    panel.dragZoneId = nil; ghost:Hide()
end)
UISpecialFrames = UISpecialFrames or {}
table.insert(UISpecialFrames, "LCMCrossingsPanel")
table.insert(UISpecialFrames, "LCMCrossingsDeleteConfirm")
table.insert(UISpecialFrames, "LCMCrossingsCreatePrompt")
table.insert(UISpecialFrames, "LCMCrossingsRegionDelete")
table.insert(UISpecialFrames, "LCMCrossingsBorderPick")
table.insert(UISpecialFrames, "LCMCrossingsBorderDeclare")
panel:RefreshForm()

-- La branche Lieux du dossier Outils du menu radial ouvre le panneau : c'est
-- l'entrée de l'ancien atelier des lieux, que Crossings remplace. Pas de
-- commande slash, comme pour les autres outils de LCM.
LCM.WhenReady(function()
    if LCM.UI and LCM.UI.Menu then LCM.UI.Menu.Lier("lieux", function() panel:Toggle() end) end
end)

-- « /lcm reset map » : rendre sa page blanche au brouillard. Réservée au MJ,
-- et elle vit dans le compagnon : le client d'un joueur ne la porte même pas.
-- Deux temps, comme les suppressions du panneau — effacer ce qu'on a découvert
-- en des mois de jeu ne doit pas tenir à une faute de frappe.
LCM.AddCommand("reset", "(MJ) « reset map » : oublie les cartes découvertes", function(argument)
    if tostring(argument or ""):lower():match("^map") == nil then
        LCM.Info("« /lcm reset map » oublie le brouillard et les noms appris.")
        return
    end
    if panel.resetMapArme ~= true then
        panel.resetMapArme = true
        LCM.Alerte("Cela efface TOUT ce que ce personnage a découvert : le brouillard et les noms. Retapez « /lcm reset map » pour confirmer.")
        -- L'armement retombe : la confirmation se donne tout de suite, pas une
        -- heure plus tard sur une commande qu'on a oubliée.
        if C_Timer and C_Timer.After then
            C_Timer.After(20, function() panel.resetMapArme = nil end)
        end
        return
    end
    panel.resetMapArme = nil
    local cases = ZG:OublierDecouvertes()
    LCM.Info(string.format("Cartes oubliées : %d case(s) de brouillard et tous les noms appris.", cases))
    if LCMCrossingsRegionMap and LCMCrossingsRegionMap.Draw and LCMCrossingsRegionMap:IsShown() then
        LCMCrossingsRegionMap:Draw()
    end
    panel:RefreshAll()
end, true)
