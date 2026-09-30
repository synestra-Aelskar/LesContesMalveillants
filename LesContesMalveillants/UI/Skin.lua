-- Le cadre Ael'Raz'kah, variante legere.
--
-- Porte depuis `AelArtwork.lua` de Necronicon, ou le meme dessin existait en
-- deux variantes ; on ne garde ici que « panel », celle du mode leger, et on
-- laisse tomber tout ce qui allait avec (themes commutables, cadres securises,
-- variantes par fenetre). Le skin n'est pas une option dans cet addon : c'est
-- son allure.
--
-- Principe du decoupage : les quatre coins et les deux motifs centraux gardent
-- leur taille, les bandes entre eux s'etirent. Les coordonnees sont celles de
-- l'image source (frame-panel-source.png, 1536 x 1024, interieur x 98..1438,
-- y 95..884) ; l'atlas livre est une reduction en 1024 x 1024, et `k` fait le
-- pont entre les deux.
--
-- Consequence utile : le cadre de la fenetre EST l'interieur du dessin. Les
-- ornements debordent vers l'exterieur, donc les marges de contenu posees dans
-- le Kit restent valables.

local _, LCM = ...
local UI = LCM.UI

local ATLAS = "Interface\\AddOns\\LesContesMalveillants\\ressources\\aelrazkah\\frame-panel.tga"

-- Dimensions de l'atlas et de l'interieur, en pixels de l'image source.
local V = {
    tw = 1024, th = 1024,
    L = 98, T = 95, R = 1438, B = 884,
    largeur = 1340,
    facteur = 0.75, min = 0.26, max = 0.40,
    coupeHaut = 102,  -- le motif du haut est rogne quand un titre est centre
}

-- { atlas x, y, w, h, source x, y, point de la fenetre }
local FIXES = {
    {   0,   0, 230, 330,    0,   0, "TOPLEFT" },
    { 232,   0, 236, 330, 1300,   0, "TOPRIGHT" },
    { 470,   0, 230, 284,    0, 740, "BOTTOMLEFT" },
    { 702,   0, 236, 284, 1300, 740, "BOTTOMRIGHT" },
    {   0, 340, 340, 200,  600,   0, "TOP" },
    { 342, 340, 260, 174,  640, 850, "BOTTOM" },
}

-- { atlas x, y, w, h, etiree en x ?, point1, source x, y, point2, source x, y }
local BANDES = {
    { 610, 340, 12, 160, true,  "TOPLEFT",     230,  40, "TOP",          600, 200 },
    { 632, 340, 12, 160, true,  "TOP",         940,  40, "TOPRIGHT",    1300, 200 },
    { 654, 340, 12, 110, true,  "BOTTOMLEFT",  230, 850, "BOTTOM",       640, 960 },
    { 654, 340, 12, 110, true,  "BOTTOM",      900, 850, "BOTTOMRIGHT", 1300, 960 },
    { 668, 340, 70,  12, false, "TOPLEFT",      40, 330, "BOTTOMLEFT",   110, 740 },
    { 668, 356, 70,  12, false, "TOPRIGHT",   1426, 330, "BOTTOMRIGHT", 1496, 740 },
}

local CENTRE_X = (V.L + V.R) / 2

local function Texture(decor, r, etireeEnX, sousNiveau)
    local t = decor:CreateTexture(nil, "ARTWORK", nil, sousNiveau)
    t:SetTexture(ATLAS)
    local x0, x1, y0, y1 = r[1], r[1] + r[3], r[2], r[2] + r[4]
    -- Une bande etiree n'echantillonne que son milieu, sinon ses voisines
    -- bavent dessus au moment de l'etirement.
    if etireeEnX == true then
        x0, x1 = x0 + 3, x1 - 3
    elseif etireeEnX == false then
        y0, y1 = y0 + 3, y1 - 3
    end
    t:SetTexCoord(x0 / V.tw, x1 / V.tw, y0 / V.th, y1 / V.th)
    return t
end

-- Place une texture d'apres une coordonnee de l'image source : LEFT / RIGHT et
-- TOP / BOTTOM se rapportent aux bords interieurs du dessin.
local function Poser(t, point, relatif, sx, sy, cadre, k)
    local rx = relatif:find("LEFT") and V.L or (relatif:find("RIGHT") and V.R or CENTRE_X)
    local ry = relatif:find("TOP") and V.T or V.B
    t:SetPoint(point, cadre, relatif, (sx - rx) * k, -(sy - ry) * k)
end

-- Habille une fenetre. `cadre.titreCentre` rogne le motif du haut : ses
-- pendentifs passeraient par-dessus le titre.
function UI.Cadre(cadre)
    if cadre.decor then return cadre.decor end

    local decor = CreateFrame("Frame", nil, cadre)
    decor:SetAllPoints(cadre)
    decor:EnableMouse(false)
    -- Au niveau de la fenetre elle-meme, donc SOUS tous ses autres enfants :
    -- sinon les ornements des coins recouvrent le bouton de fermeture.
    decor:SetFrameLevel(cadre:GetFrameLevel())
    decor.fixes, decor.bandes = {}, {}
    cadre.decor = decor

    for index, r in ipairs(BANDES) do decor.bandes[index] = Texture(decor, r, r[5], 0) end
    for index, r in ipairs(FIXES) do decor.fixes[index] = Texture(decor, r, nil, 1) end

    function decor:Disposer()
        -- L'echelle suit la largeur de la fenetre, entre deux bornes : en
        -- dessous les ornements deviennent des taches, au-dessus ils mangent
        -- l'ecran.
        local k = math.min(V.max, math.max(V.min, cadre:GetWidth() / V.largeur * V.facteur))
        self.echelle = k

        for index, r in ipairs(FIXES) do
            local t = self.fixes[index]
            t:ClearAllPoints()
            Poser(t, "TOPLEFT", r[7], r[5], r[6], cadre, k)
            local h = r[4]
            if r[7] == "TOP" and cadre.titreCentre then h = math.min(h, V.coupeHaut) end
            t:SetTexCoord(r[1] / V.tw, (r[1] + r[3]) / V.tw, r[2] / V.th, (r[2] + h) / V.th)
            t:SetSize(r[3] * k, h * k)
        end

        for index, r in ipairs(BANDES) do
            local t = self.bandes[index]
            t:ClearAllPoints()
            Poser(t, "TOPLEFT", r[6], r[7], r[8], cadre, k)
            Poser(t, "BOTTOMRIGHT", r[9], r[10], r[11], cadre, k)
        end
    end

    decor:Disposer()
    return decor
end
