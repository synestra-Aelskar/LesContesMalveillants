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

local DOSSIER = "Interface\\AddOns\\LesContesMalveillants\\ressources\\aelrazkah\\"

-- Les habillages disponibles. Chacun donne les dimensions de son atlas et de
-- son interieur, en pixels de l'image SOURCE (l'atlas livre en est une
-- reduction), puis ses pieces fixes et ses bandes etirees.
--
--   leger  « panel » : le cadre sobre, celui de tous les jours.
--   lourd  « light » : le cadre a crane, plus charge.
-- `incritas` n'est pas ici : c'est l'absence d'habillage.
local VARIANTES = {
    leger = {
        fichier = "frame-panel.tga",
        tw = 1024, th = 1024,
        L = 98, T = 95, R = 1438, B = 884,
        largeur = 1340,
        facteur = 0.75, min = 0.26, max = 0.40,
        coupeHaut = 102,  -- le motif du haut est rogne quand un titre est centre
        fixes = {
            {   0,   0, 230, 330,    0,   0, "TOPLEFT" },
            { 232,   0, 236, 330, 1300,   0, "TOPRIGHT" },
            { 470,   0, 230, 284,    0, 740, "BOTTOMLEFT" },
            { 702,   0, 236, 284, 1300, 740, "BOTTOMRIGHT" },
            {   0, 340, 340, 200,  600,   0, "TOP" },
            { 342, 340, 260, 174,  640, 850, "BOTTOM" },
        },
        bandes = {
            { 610, 340, 12, 160, true,  "TOPLEFT",     230,  40, "TOP",          600, 200 },
            { 632, 340, 12, 160, true,  "TOP",         940,  40, "TOPRIGHT",    1300, 200 },
            { 654, 340, 12, 110, true,  "BOTTOMLEFT",  230, 850, "BOTTOM",       640, 960 },
            { 654, 340, 12, 110, true,  "BOTTOM",      900, 850, "BOTTOMRIGHT", 1300, 960 },
            { 668, 340, 70,  12, false, "TOPLEFT",      40, 330, "BOTTOMLEFT",   110, 740 },
            { 668, 356, 70,  12, false, "TOPRIGHT",   1426, 330, "BOTTOMRIGHT", 1496, 740 },
        },
    },
    lourd = {
        fichier = "frame-light.tga",
        tw = 1024, th = 512,
        L = 106, T = 150, R = 1227, B = 1032,
        largeur = 1121,
        facteur = 0.7, min = 0.22, max = 0.40,
        coupeHaut = 158,
        fixes = {
            {   0,   0, 175, 225,    0,    0, "TOPLEFT" },
            { 180,   0, 168, 225, 1165,    0, "TOPRIGHT" },
            { 352,   0, 185, 190,    0,  990, "BOTTOMLEFT" },
            { 541,   0, 183, 190, 1150,  990, "BOTTOMRIGHT" },
            { 728,   0, 235, 200,  550,    0, "TOP" },
            {   0, 256, 385, 200,  475,  980, "BOTTOM" },
        },
        bandes = {
            { 400, 256, 12, 80, true,  "TOPLEFT",     175,   80, "TOP",          550,  160 },
            { 400, 256, 12, 80, true,  "TOP",         785,   80, "TOPRIGHT",    1165,  160 },
            { 420, 256, 12, 65, true,  "BOTTOMLEFT",  185, 1025, "BOTTOM",       475, 1090 },
            { 420, 256, 12, 65, true,  "BOTTOM",      860, 1025, "BOTTOMRIGHT", 1150, 1090 },
            { 440, 256, 62, 12, false, "TOPLEFT",      50,  225, "BOTTOMLEFT",   112,  990 },
            { 440, 280, 61, 12, false, "TOPRIGHT",   1222,  225, "BOTTOMRIGHT", 1283,  990 },
        },
    },
}

-- Ce que l'utilisateur peut choisir. « Incritas » est le nom du skin de debug :
-- aucune ornementation, juste des bordures — on voit la structure.
UI.THEMES = {
    { id = "incritas",   label = "Incritas" },
    { id = "necronicon", label = "Necronicon", indisponible = true },
    { id = "lourd",      label = "Ael'Raz'kah lourd" },
    { id = "leger",      label = "Ael'Raz'kah léger" },
}

function UI.ThemeActuel()
    LCM.EnsureDatabase()
    local choisi = LCM.db.settings and LCM.db.settings.theme
    if choisi == "incritas" or VARIANTES[choisi] then return choisi end
    return "leger"
end

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

local function Texture(decor, V, r, etireeEnX, sousNiveau)
    local t = decor:CreateTexture(nil, "ARTWORK", nil, sousNiveau)
    t:SetTexture(DOSSIER .. V.fichier)
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
local function Poser(t, V, point, relatif, sx, sy, cadre, k)
    local centreX = (V.L + V.R) / 2
    local rx = relatif:find("LEFT") and V.L or (relatif:find("RIGHT") and V.R or centreX)
    local ry = relatif:find("TOP") and V.T or V.B
    t:SetPoint(point, cadre, relatif, (sx - rx) * k, -(sy - ry) * k)
end

-- Les pieces d'un habillage, fabriquees a la demande : on ne paie un atlas que
-- si on l'affiche.
local function Jeu(decor, nom)
    if decor.jeux[nom] then return decor.jeux[nom] end
    local V = VARIANTES[nom]
    if not V then return nil end
    local jeu = { V = V, fixes = {}, bandes = {} }
    for index, r in ipairs(V.bandes) do jeu.bandes[index] = Texture(decor, V, r, r[5], 0) end
    for index, r in ipairs(V.fixes) do jeu.fixes[index] = Texture(decor, V, r, nil, 1) end
    decor.jeux[nom] = jeu
    return jeu
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
    decor.jeux = {}
    cadre.decor = decor

    function decor:Disposer()
        local nom = UI.ThemeActuel()
        -- On range ce qui ne sert plus avant de poser ce qui sert : deux
        -- habillages superposes, ca se voit.
        for autre, jeu in pairs(self.jeux) do
            if autre ~= nom then
                for _, t in ipairs(jeu.fixes) do t:Hide() end
                for _, t in ipairs(jeu.bandes) do t:Hide() end
            end
        end
        self.theme = nom
        local jeu = Jeu(self, nom)
        if not jeu then self.echelle = nil return end
        local V = jeu.V

        -- L'echelle suit la largeur de la fenetre, entre deux bornes : en
        -- dessous les ornements deviennent des taches, au-dessus ils mangent
        -- l'ecran.
        local k = math.min(V.max, math.max(V.min, cadre:GetWidth() / V.largeur * V.facteur))
        self.echelle = k

        for index, r in ipairs(V.fixes) do
            local t = jeu.fixes[index]
            t:ClearAllPoints()
            Poser(t, V, "TOPLEFT", r[7], r[5], r[6], cadre, k)
            local h = r[4]
            if r[7] == "TOP" and cadre.titreCentre then h = math.min(h, V.coupeHaut) end
            t:SetTexCoord(r[1] / V.tw, (r[1] + r[3]) / V.tw, r[2] / V.th, (r[2] + h) / V.th)
            t:SetSize(r[3] * k, h * k)
            t:Show()
        end

        for index, r in ipairs(V.bandes) do
            local t = jeu.bandes[index]
            t:ClearAllPoints()
            Poser(t, V, "TOPLEFT", r[6], r[7], r[8], cadre, k)
            Poser(t, V, "BOTTOMRIGHT", r[9], r[10], r[11], cadre, k)
            t:Show()
        end
    end

    decor:Disposer()
    -- Une fenetre redimensionnable (compendium) : l'echelle des ornements suit
    -- sa nouvelle largeur, comme dans le modele (aelLayout sur OnSizeChanged).
    decor:SetScript("OnSizeChanged", function(self) self:Disposer() end)
    return decor
end

-- ===== Reglages d'apparence ================================================
-- Theme, opacite et taille s'appliquent a TOUTES les fenetres d'un coup : une
-- fenetre ouverte doit changer avec les autres, pas a sa prochaine ouverture.

function UI.AppliquerTheme(nom)
    LCM.EnsureDatabase()
    if nom then LCM.db.settings.theme = (nom ~= "leger") and nom or nil end
    local actuel = UI.ThemeActuel()
    for _, f in ipairs(UI.fenetres) do
        if f.decor then f.decor:Disposer() end
        -- Sans habillage, la fenetre garde une bordure : elle doit rester
        -- lisible, pas disparaitre dans le decor du jeu.
        if f.bordureSimple then
            for _, trait in ipairs(f.bordureSimple) do trait:SetShown(actuel == "incritas") end
        end
    end
    return actuel
end

function UI.Opacite(pourcent)
    LCM.EnsureDatabase()
    if pourcent then LCM.db.settings.opacite = (pourcent ~= 100) and pourcent or nil end
    local v = tonumber(LCM.db.settings.opacite) or 100
    -- Jamais tout a fait transparente : une fenetre qu'on ne voit plus est une
    -- fenetre qu'on ne retrouve pas.
    local alpha = 0.1 + 0.9 * math.max(0, math.min(v, 100)) / 100
    for _, f in ipairs(UI.fenetres) do f:SetAlpha(alpha) end
    return v, alpha
end

-- La barre va de 0 a 100, et 50 vaut la taille normale : en dessous on
-- retrecit, au-dessus on agrandit, sans jamais disparaitre.
function UI.Echelle(pourcent)
    LCM.EnsureDatabase()
    if pourcent then LCM.db.settings.echelle = (pourcent ~= 50) and pourcent or nil end
    local v = tonumber(LCM.db.settings.echelle) or 50
    local facteur = 0.5 + math.max(0, math.min(v, 100)) / 100
    for _, f in ipairs(UI.fenetres) do f:SetScale(facteur) end
    return v, facteur
end

LCM.WhenReady(function()
    UI.AppliquerTheme()
    UI.Opacite()
    UI.Echelle()
end)

-- ===== Atlas des widgets ===================================================
-- `widgets-reference.tga` (1024 x 2048) : onglets, blocs, cadres d'icone,
-- embouts de jauge, ornements de titre. Repris de Necronicon avec ses
-- coordonnees (AelArtwork.lua / AelWidgets.lua) : ce sont elles qui donnent
-- a une fenetre l'allure de la reference, pas une imitation a l'oeil.

local WIDGETS = "Interface\\AddOns\\LesContesMalveillants\\ressources\\aelrazkah\\widgets-reference.tga"

-- Un morceau de l'atlas, en pixels de l'atlas.
function UI.AelRef(parent, x, y, w, h, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(WIDGETS)
    t:SetTexCoord(x / 1024, (x + w) / 1024, y / 2048, (y + h) / 2048)
    return t
end

-- Bordure en huit morceaux decoupee dans l'atlas, SANS le centre : le texte
-- grave dans le modele ne doit jamais apparaitre. `b` : epaisseur du bord dans
-- l'atlas ; `taille` : son epaisseur a l'ecran ; `fin` : bords haut / bas plus
-- minces (onglets).
function UI.AelDecoupe(parent, x, y, w, h, b, taille, fin)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:EnableMouse(false)
    f:SetFrameLevel(parent:GetFrameLevel())
    f.morceaux = {}
    local function Morceau(px, py, pw, ph, a, c, dw, dh, ox, oy, cx, cy)
        local t = UI.AelRef(f, px, py, pw, ph, "BORDER")
        t:SetPoint(a, f, a, ox or 0, oy or 0)
        if c then t:SetPoint(c, f, c, cx or 0, cy or 0) end
        if dw then t:SetWidth(dw) end
        if dh then t:SetHeight(dh) end
        f.morceaux[#f.morceaux + 1] = t
    end
    local hb = fin or b
    Morceau(x + b, y, w - 2 * b, hb, "TOPLEFT", "TOPRIGHT", nil, fin and 2 or taille, taille, 0, -taille, 0)
    Morceau(x + b, y + h - hb, w - 2 * b, hb, "BOTTOMLEFT", "BOTTOMRIGHT", nil, fin and 2 or taille, taille, 0, -taille, 0)
    Morceau(x, y + b, b, h - 2 * b, "TOPLEFT", "BOTTOMLEFT", taille, nil, 0, -taille, 0, taille)
    Morceau(x + w - b, y + b, b, h - 2 * b, "TOPRIGHT", "BOTTOMRIGHT", taille, nil, 0, -taille, 0, taille)
    Morceau(x, y, b, b, "TOPLEFT", nil, taille, taille)
    Morceau(x + w - b, y, b, b, "TOPRIGHT", nil, taille, taille)
    Morceau(x, y + h - b, b, b, "BOTTOMLEFT", nil, taille, taille)
    Morceau(x + w - b, y + h - b, b, b, "BOTTOMRIGHT", nil, taille, taille)
    return f
end

-- Les cadres nommes du modele.
local CADRES = {
    section  = { 103, 328, 822, 318, 14, 7, 4 },
    onglet   = { 128, 165, 273, 55, 8, 4 },
    icone    = { 134, 390, 54, 54, 5, 2 },
    controle = { 694, 455, 37, 40, 4, 2 },
}
function UI.AelCadre(parent, genre)
    local r = CADRES[genre] or CADRES.controle
    return UI.AelDecoupe(parent, r[1], r[2], r[3], r[4], r[5], r[6], r[7])
end

-- Embouts dores d'une barre de jauge : le meme embout des deux cotes (le
-- gauche du modele contient un bout de remplissage), et deux filets.
function UI.AelCadreJauge(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    f:EnableMouse(false)
    f:SetFrameLevel(parent:GetFrameLevel() + 1)
    for _, cote in ipairs({ "LEFT", "RIGHT" }) do
        local t = UI.AelRef(f, 655, 459, 19, 34, "OVERLAY")
        if cote == "LEFT" then t:SetTexCoord(674 / 1024, 655 / 1024, 459 / 2048, 493 / 2048) end
        local dx = cote == "LEFT" and -4 or 4
        t:SetPoint("TOP" .. cote, f, "TOP" .. cote, dx, 2)
        t:SetPoint("BOTTOM" .. cote, f, "BOTTOM" .. cote, dx, -2)
        t:SetWidth(9)
    end
    for _, r in ipairs({ { 459, "TOP" }, { 490, "BOTTOM" } }) do
        local t = UI.AelRef(f, 413, r[1], 241, 3, "OVERLAY")
        t:SetPoint(r[2] .. "LEFT", f, r[2] .. "LEFT", 5, 0)
        t:SetPoint(r[2] .. "RIGHT", f, r[2] .. "RIGHT", -5, 0)
        t:SetHeight(2)
    end
    return f
end

-- Bouton net : fond sombre et filet d'or d'un pixel. Une tranche d'atlas
-- etiree a cette taille serait floue ; le modele Necronicon trace donc ce
-- cadre en aplats, et nous aussi.
local OR_TERNI = { 0.66, 0.51, 0.27, 1 }
function UI.AelBoutonNet(bouton)
    local f = CreateFrame("Frame", nil, bouton)
    f:SetAllPoints(bouton)
    f:EnableMouse(false)
    f:SetFrameLevel(bouton:GetFrameLevel())
    f.fond = f:CreateTexture(nil, "BACKGROUND")
    f.fond:SetAllPoints(f)
    f.fond:SetColorTexture(0.035, 0.030, 0.023, 1)
    UI.Bordure(f, OR_TERNI)
    local function Peindre(etat)
        local c = etat == "appui" and { 0.12, 0.085, 0.04 }
            or (etat == "survol" and { 0.09, 0.065, 0.03 } or { 0.035, 0.030, 0.023 })
        f.fond:SetColorTexture(c[1], c[2], c[3], 1)
    end
    bouton:HookScript("OnEnter", function() Peindre("survol") end)
    bouton:HookScript("OnLeave", function() Peindre() end)
    bouton:HookScript("OnMouseDown", function() Peindre("appui") end)
    bouton:HookScript("OnMouseUp", function() Peindre("survol") end)
    bouton.aelCadre = f
    return f
end

-- Police du theme : la Friz Quadrata du jeu, a une taille qui suit la
-- fenetre. En dessous de 10, plus rien ne se lit.
function UI.Police(fs, taille, contour)
    if fs and fs.SetFont then
        fs:SetFont("Fonts\\FRIZQT__.TTF", math.max(10, taille or 12), contour or "")
    end
end

-- Mesures du modele. Fenetre : sur 845 unites de large (en-tete, onglets,
-- titres). Lignes : sur 786 unites (colonnes d'une ligne de fiche).
-- Meme regle que pour les colonnes : le decor suit la largeur (c'est une
-- image, elle doit s'etirer), le texte et la hauteur des onglets non. Sans ces
-- plafonds, une fenetre de 720 porte un titre de 27 et des onglets de 47.
local POLICE_MAX = 12
local TITRE_MAX, ONGLET_MAX = 17, 24

function UI.AelMesures(largeur)
    local s = (tonumber(largeur) or 845) / 845
    return { echelle = s, ligne = 62 * s,
             onglet = math.min(ONGLET_MAX, 55 * s),
             titre = math.min(TITRE_MAX, 32 * s),
             police = math.min(POLICE_MAX, 24 * s),
             regle = 63 * s, bandeau = 70 * s }
end

-- Les colonnes d'une ligne suivent la largeur ; le rythme vertical et la taille
-- du texte, non. C'est la regle que Necronicon applique sans la dire : ses
-- fenetres qui ne portent pas l'atlas (les parametres) ecrivent en 12, quelle
-- que soit leur largeur, et ses lignes font 26 de haut.
--
-- Sans ces plafonds, une fiche de 600 de large donne des lignes de 46 et du
-- texte de 18 : trois fois l'air qu'il faut autour d'une ligne de chiffres, et
-- une fenetre qu'on trouve enorme meme a 76 % d'echelle.
-- Releve sur la fiche de Necronicon telle qu'elle tourne en seance : lignes de
-- 26, texte de 12, icones de 20, dans une fenetre de ~390. C'est la densite a
-- laquelle on joue ; au-dessus, la meme fiche demande deux fois plus d'ecran
-- pour dire la meme chose.
local LIGNE_MAX, ICONE_MAX, POLICE_MIN = 24, 16, 10

-- Les colonnes de DROITE sont calees sur le bord droit de la ligne, pas sur
-- leurs coordonnees du gabarit.
--
-- Le gabarit arrete sa derniere colonne a 762 unites sur 786 : les 24 qui
-- restent sont la marge de l'image, pas une marge de contenu. En les reportant
-- telles quelles, la ligne finissait avant son bord et laissait une bande vide
-- entre le dernier bouton et le cadre — d'autant plus large que les boutons
-- sont plafonnes et n'occupent plus toute leur case.
--
-- Les largeurs, elles, restent proportionnelles : seules les origines changent.
function UI.AelColonnes(largeur)
    local s = (tonumber(largeur) or 786) / 786
    local fin = tonumber(largeur) or 786
    local ecart = 4
    local iconeTaille = math.min(ICONE_MAX, 50 * s)

    local actionLargeur = 110 * s
    local modificateurLargeur = 85 * s
    local valeurLargeur = 90 * s
    local plageLargeur = 95 * s
    local action = fin - actionLargeur
    local modificateur = action - ecart - modificateurLargeur
    local valeur = modificateur - ecart - valeurLargeur
    local plage = valeur - ecart - plageLargeur

    -- Les trois boutons d'une jauge, colles a droite eux aussi, et la barre
    -- s'arrete juste avant le premier.
    local boutonL = math.min(22, 37 * s)
    local b3 = fin - boutonL
    local b2 = b3 - ecart - boutonL
    local b1 = b2 - ecart - boutonL

    return {
        echelle = s,
        ligne = math.min(LIGNE_MAX, 62 * s),
        -- Le texte a un PLAFOND et un PLANCHER : au-dessus il mange l'ecran,
        -- en dessous il ne se lit plus. Entre les deux il suit la fenetre.
        police = math.max(POLICE_MIN, math.min(POLICE_MAX, 24 * s)),
        icone = 8 * s, iconeTaille = iconeTaille, separateur = 72 * s,
        -- Le nom commence apres l'icone REELLE, pas a la place que le gabarit
        -- lui donnait : l'icone est plafonnee, et garder son ancienne colonne
        -- laissait un trou a gauche et serrait le libelle a droite.
        nom = 8 * s + iconeTaille + 10, nomSansIcone = 24 * s, nomLargeur = 205 * s,
        plage = plage, plageLargeur = plageLargeur,
        valeur = valeur, valeurLargeur = valeurLargeur,
        modificateur = modificateur, modificateurLargeur = modificateurLargeur,
        action = action, actionLargeur = actionLargeur,
        barreDebut = 270 * s, barreFin = b1 - 6, barreHauteur = math.min(16, 30 * s),
        boutons = { b1, b2, b3 },
        boutonL = boutonL, boutonH = math.min(20, 38 * s),
    }
end

-- ===== Habillages partages =================================================
-- Les memes gestes pour tous les ecrans : une fenetre qui dessinerait ses
-- propres onglets ou ses propres lignes finirait avec un style a elle.

-- Surface d'une ligne de fiche (UI.SkinAelRow) : pierre sombre, cadre discret.
function UI.SurfaceLigne(l)
    l.surface = UI.AelRef(l, 735, 800, 55, 30, "BACKGROUND")
    l.surface:SetAllPoints(l)
    l.surface:SetAlpha(0.65)
    l.cadre = UI.AelCadre(l, "controle")
    l.cadre:SetAlpha(0.25)
end

-- Un bouton devient un onglet du modele (UI.ApplyAelTab) : cadre d'onglet,
-- fond sombre (brun chaud pour l'actif), libelle dore ou ivoire.
function UI.HabillerOnglet(b)
    if b.aelCadre then b.aelCadre:Hide() end
    b.fondOnglet = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.fondOnglet:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.fondOnglet:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.cadreOnglet = UI.AelCadre(b, "onglet")
    UI.Police(b.label, math.max(11, 24 * (b:GetHeight() / 55)))
    function b:Selectionner(actif)
        self.__selectionne = actif and true or false
        self.fondOnglet:SetColorTexture(actif and 0.13 or 0.025, actif and 0.095 or 0.023, actif and 0.045 or 0.02, 0.95)
        if actif then self.label:SetTextColor(0.98, 0.87, 0.60) else self.label:SetTextColor(0.90, 0.86, 0.78) end
        for _, t in ipairs(self.cadreOnglet.morceaux) do
            t:SetVertexColor(actif and 1 or 0.74, actif and 0.94 or 0.68, actif and 0.78 or 0.56, 1)
        end
    end
    b:Selectionner(false)
end

-- Bordure d'un champ de saisie : celle du champ de recherche du modele.
function UI.HabillerSaisie(e)
    e.cadreSaisie = UI.AelDecoupe(e, 120, 257, 363, 46, 8, 4)
    e.cadreSaisie:SetAlpha(0.6)
end
