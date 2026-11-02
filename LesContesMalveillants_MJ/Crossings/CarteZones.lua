-- ============================================================
--  Crossings — Carte des zones d'une région (panneau MJ)
--
--  Ce que la carte du joueur (UI/Crossings/Carte.lua) montre en lecture,
--  celle-ci le donne à modifier : les zones d'une région, une couleur
--  chacune, leur nom au centre, et leurs sommets attrapables.
--
--  Elle sert surtout à la frontière. Avant, coller deux zones demandait de
--  déclarer un tronçon sur la première PUIS de partir de ce tronçon pour
--  dessiner la seconde — donc de les dessiner dans le bon ordre, et une
--  troisième zone qui touchait les deux premières était hors de portée. Ici
--  on désigne des sommets déjà posés, de part et d'autre, et on dit qu'ils
--  se confondent : la soudure (ZG:WeldSeam) les réunit pour de bon.
--
--  Le repère est celui de la carte du joueur : x vers l'ouest, y vers le
--  nord, nord en haut (voir ZG:PlacementOffset et win:ToScreen).
-- ============================================================

local ZG = LCMCrossings
local UI = ZG.EditorUI

local MIN_SCALE, MAX_SCALE = .02, 40
local ACCROCHE  = 11    -- pixels : à quelle distance du curseur un sommet se laisse prendre
local POIGNEE   = 9     -- côté du carré d'un sommet, en pixels
local MAX_POIGNEES = 600 -- au-delà, les sommets se dessinent sans être attrapables

local function Moi() return UnitName("player") or "" end

-- Une couleur par zone, stable : c'est son identifiant qui la choisit, donc
-- elle ne change pas d'un dessin à l'autre ni d'une séance à l'autre.
-- La couleur d'une entrée dessinée : celle de la RÉGION quand on montre
-- plusieurs régions (carte d'un pays), celle du LIEU sinon — une variante de
-- celle de sa région, ou la sienne s'il en impose une (voir ZG:PlaceColor).
local function Teinte(e, parRegion)
    if parRegion then return ZG:ZoneColor(e.zone) end
    local place = e.sub and e.sub.enterPlace and ZG:FindPlace(e.sub.enterPlace)
    return ZG:PlaceColor(place, e.zone)
end
local function Clair(c) return { math.min(1, c[1] + .35), math.min(1, c[2] + .35), math.min(1, c[3] + .35) } end

-- Les portes, toujours en rouge, ici comme dans la liste de gauche ; les
-- bâtiments, en violet.
local PORTE = { 0.85, 0.45, 0.38 }
local BATIMENT = { 0.70, 0.52, 0.88 }

-- `hooks` :
--   Region()        → la région affichée (table zone), ou nil
--   Regions()       → plusieurs régions à la fois (carte d'un pays) ; prend
--                     le pas sur Region() quand elle existe
--   OuvrirZone(sub, zone) → clic sur le nom d'une zone
--   Change()        → appelé quand la géométrie a bougé (rafraîchir la fiche)
function ZG.CreateZoneMap(parent, width, height, hooks)
    local geo = nil   -- ZG.Geo, pris au premier dessin : l'addon joueur l'écrit à son chargement

    local map = CreateFrame("Frame", nil, parent)
    map:SetSize(width, height)
    map.scale, map.cx, map.cy = 2, 0, 0
    map.sel = {}        -- sélection ordonnée : { {subId=, index=} }
    map.pile = {}       -- retours en arrière, le plus récent en dernier
    -- Exposés pour le banc : un clic de souris ne se rejoue pas hors du jeu,
    -- mais ce qu'il appelle, oui.
    map.hooks = hooks

    local fond = map:CreateTexture(nil, "BACKGROUND")
    fond:SetAllPoints(); fond:SetColorTexture(.055, .060, .058, 1)
    if map.SetClipsChildren then map:SetClipsChildren(true) end

    local quadrillage = CreateFrame("Frame", nil, map); quadrillage:SetAllPoints()
    for i = 1, math.floor(width / 60) do
        local t = quadrillage:CreateTexture(nil, "BORDER"); t:SetColorTexture(1, 1, 1, .025); t:SetWidth(1)
        t:SetPoint("TOPLEFT", i * 60, 0); t:SetPoint("BOTTOMLEFT", i * 60, 0)
    end
    for i = 1, math.floor(height / 60) do
        local t = quadrillage:CreateTexture(nil, "BORDER"); t:SetColorTexture(1, 1, 1, .025); t:SetHeight(1)
        t:SetPoint("TOPLEFT", 0, -i * 60); t:SetPoint("TOPRIGHT", 0, -i * 60)
    end

    local remplissages = CreateFrame("Frame", nil, map); remplissages:SetAllPoints()
    remplissages:SetFrameLevel(map:GetFrameLevel() + 2)
    local traits = CreateFrame("Frame", nil, map); traits:SetAllPoints()
    traits:SetFrameLevel(map:GetFrameLevel() + 3)
    local sommets = CreateFrame("Frame", nil, map); sommets:SetAllPoints()
    sommets:SetFrameLevel(map:GetFrameLevel() + 4)
    local etiquettes = CreateFrame("Frame", nil, map); etiquettes:SetAllPoints()
    etiquettes:SetFrameLevel(map:GetFrameLevel() + 5)

    -- Remplir un triangle demande de déformer une texture : sans ça, on s'en
    -- tient aux contours (voir la carte du joueur, même garde).
    local sonde = remplissages:CreateTexture(nil, "ARTWORK"); sonde:Hide()
    local PEUT_REMPLIR = sonde.SetVertexOffset ~= nil

    local vide = etiquettes:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    vide:SetPoint("CENTER"); vide:SetWidth(width - 80); UI.ApplyMutedText(vide)
    map.vide = vide

    -- ── Réserves réutilisées d'un dessin à l'autre ────────────────────────

    local triPool, traitPool, texPool, carrePool = {}, {}, {}, {}
    local nTri, nTrait, nTex, nCarre = 0, 0, 0, 0

    local function Tri(a, b, c, color, alpha)
        if (a[1]<0 and b[1]<0 and c[1]<0) or (a[1]>width and b[1]>width and c[1]>width)
            or (a[2]<0 and b[2]<0 and c[2]<0) or (a[2]>height and b[2]>height and c[2]>height) then return end
        nTri = nTri + 1
        local t = triPool[nTri]
        if not t then t = remplissages:CreateTexture(nil, "ARTWORK"); triPool[nTri] = t end
        local minx, maxx = math.min(a[1], b[1], c[1]), math.max(a[1], b[1], c[1])
        local miny, maxy = math.min(a[2], b[2], c[2]), math.max(a[2], b[2], c[2])
        local w, h = math.max(1, maxx - minx), math.max(1, maxy - miny)
        t:ClearAllPoints(); t:SetPoint("TOPLEFT", map, "TOPLEFT", minx, -miny); t:SetSize(w, h)
        t:SetColorTexture(color[1], color[2], color[3], alpha or .28)
        t:SetVertexOffset(1, a[1] - minx, -(a[2] - miny))
        t:SetVertexOffset(2, b[1] - minx, -(b[2] - (miny + h)))
        t:SetVertexOffset(3, c[1] - (minx + w), -(c[2] - miny))
        t:SetVertexOffset(4, c[1] - (minx + w), -(c[2] - (miny + h)))
        t:Show()
    end

    local function Trait(x1, y1, x2, y2, color, epaisseur, alpha)
        local dx, dy = x2 - x1, y2 - y1
        local longueur = math.sqrt(dx * dx + dy * dy)
        if longueur < .5 then return end
        if (x1 < 0 and x2 < 0) or (x1 > width and x2 > width) then return end
        if (y1 < 0 and y2 < 0) or (y1 > height and y2 > height) then return end
        nTrait = nTrait + 1
        local t = traitPool[nTrait]
        if not t then t = traits:CreateTexture(nil, "ARTWORK"); traitPool[nTrait] = t end
        t:ClearAllPoints(); t:SetPoint("CENTER", map, "TOPLEFT", (x1 + x2) / 2, -(y1 + y2) / 2)
        t:SetSize(longueur, epaisseur or 2); t:SetRotation(math.atan2(-dy, dx))
        t:SetColorTexture(color[1], color[2], color[3], alpha or .95); t:Show()
    end

    -- `largeur` : le nom se replie dedans au lieu de déborder de sa zone, et
    -- la police descend d'un cran quand la place manque. Une plaque sombre
    -- passe dessous : sans elle, un nom posé sur un tracé devient illisible.
    local function Texte(x, y, texte, color, grand, largeur)
        nTex = nTex + 1
        local f = texPool[nTex]
        if not f then
            f = etiquettes:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            f:SetShadowColor(0, 0, 0, 1); f:SetShadowOffset(1, -1)
            f.plaque = traits:CreateTexture(nil, "OVERLAY")
            f.plaque:SetColorTexture(.03, .03, .03, .62)
            texPool[nTex] = f
        end
        local police = "GameFontNormalSmall"
        if grand then
            police = (largeur and largeur < 110) and "GameFontNormal" or "GameFontNormalLarge"
        end
        f:SetFontObject(police)
        f:ClearAllPoints(); f:SetPoint("CENTER", map, "TOPLEFT", x, -y)
        if largeur then
            f:SetWidth(largeur); f:SetWordWrap(true); f:SetJustifyH("CENTER")
        else
            f:SetWidth(0); f:SetWordWrap(false)
        end
        f:SetText(texte); f:SetTextColor(color[1], color[2], color[3], 1); f:Show()
        f.plaque:ClearAllPoints()
        f.plaque:SetPoint("CENTER", f, "CENTER", 0, 0)
        f.plaque:SetSize(math.min(largeur or 1e4, f:GetStringWidth()) + 10, f:GetStringHeight() + 4)
        f.plaque:Show()
        return f
    end

    -- Un sommet : carré plein, bordé si choisi, avec un point au centre quand
    -- il est soudé à un autre.
    local function Carre(x, y, color, choisi, soude)
        nCarre = nCarre + 1
        local c = carrePool[nCarre]
        if not c then
            c = {}
            c.bord = sommets:CreateTexture(nil, "ARTWORK")
            c.coeur = sommets:CreateTexture(nil, "OVERLAY")
            c.point = sommets:CreateTexture(nil, "OVERLAY")
            carrePool[nCarre] = c
        end
        local cote = POIGNEE + (choisi and 4 or 0)
        c.bord:ClearAllPoints(); c.bord:SetPoint("CENTER", map, "TOPLEFT", x, -y)
        c.bord:SetSize(cote + 4, cote + 4)
        c.bord:SetColorTexture(choisi and 1 or 0, choisi and .85 or 0, choisi and .25 or 0, choisi and 1 or .75)
        c.bord:Show()
        c.coeur:ClearAllPoints(); c.coeur:SetPoint("CENTER", map, "TOPLEFT", x, -y)
        c.coeur:SetSize(cote, cote)
        c.coeur:SetColorTexture(color[1], color[2], color[3], 1); c.coeur:Show()
        c.point:ClearAllPoints(); c.point:SetPoint("CENTER", map, "TOPLEFT", x, -y)
        c.point:SetSize(3, 3); c.point:SetColorTexture(.05, .05, .05, 1)
        c.point:SetShown(soude and true or false)
    end

    -- Un bâtiment ne s'étale pas sur la carte de sa région : il s'y marque
    -- d'un rond, son nom au-dessus. Sa carte à lui s'ouvre d'un clic — un
    -- intérieur dessiné à plat sur l'extérieur ne se lisait pas, et ses
    -- cloisons noyaient le reste.
    local rondPool, nRond = {}, 0
    local function Rond(x, y, color)
        nRond = nRond + 1
        local t = rondPool[nRond]
        if not t then
            t = sommets:CreateTexture(nil, "OVERLAY")
            t:SetTexture("Interface\\COMMON\\Indicator-Gray")
            t:SetSize(18, 18)
            rondPool[nRond] = t
        end
        t:SetVertexColor(color[1], color[2], color[3], 1)
        t:ClearAllPoints(); t:SetPoint("CENTER", map, "TOPLEFT", x, -y)
        t:Show()
    end

    -- ── Le terrain sous le tracé ─────────────────────────────────────────
    -- Deux sources, essayées dans cet ordre :
    --
    --   1. les TUILES DE MINIMAP du client. Le jeu range la minimap de chaque
    --      carte en BLP, une par bloc ADT de 533,33 yards, sous
    --      world\minimaps\<carte>\mapXX_YY.blp. C'est ce que Noggit exporte,
    --      et ça se lit comme n'importe quelle texture. Donc la minimap EST
    --      disponible en fond de carte — pas en empruntant le cadre du coin,
    --      qui n'est qu'un disque de 230 yards et que le jeu refuse de
    --      rogner, mais en lisant les mêmes fichiers que lui. C'est la seule
    --      source qui marche sur une carte personnalisée.
    --
    --   2. l'IMAGE DE ZONE publiée par le jeu (celle de la carte du monde),
    --      pour les cartes Blizzard qui en ont une.
    --
    -- Les deux sont de simples textures : le cadre les rogne, elles couvrent
    -- la carte entière, et personne n'a rien à rendre.
    local ADT = 533.33333      -- côté d'un bloc, en yards
    local MAX_TUILES = 240     -- au-delà, on est trop dézoomé pour que ça serve
    local tuilesFrame = CreateFrame("Frame", nil, map)
    tuilesFrame:SetAllPoints(); tuilesFrame:SetFrameLevel(map:GetFrameLevel() + 1)
    tuilesFrame:Hide()
    local tuiles = {}
    map.tuiles = tuiles   -- exposées pour le banc : il lit les chemins posés
    local function Tuile(i)
        local t = tuiles[i]
        if not t then t = tuilesFrame:CreateTexture(nil, "BACKGROUND"); tuiles[i] = t end
        t:SetTexCoord(0, 1, 0, 1)
        return t
    end

    -- Le dossier des tuiles pour cette carte du jeu. Réglé à la main une fois
    -- (ZG:SetMinimapDir), sinon deviné depuis le nom de la carte : sur Epsilon
    -- le dossier porte le nom de la carte, en minuscules.
    local function Dossier(mapID)
        local uiMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        -- La clé, c'est la carte du jeu où vivent les sommets. Quand elle est
        -- inconnue (le client se tait sur certaines cartes d'instance), on se
        -- rabat sur celle du joueur : c'est là qu'il se tient de toute façon.
        local regle = ZG:GetMinimapDir(mapID or uiMap)
        if regle and regle ~= "" then return regle end
        local info = uiMap and C_Map.GetMapInfo and C_Map.GetMapInfo(uiMap)
        local nom = (info and info.name or ""):gsub("[%s'’%-]", ""):lower()
        return nom ~= "" and nom or nil
    end

    -- Les tuiles de minimap visibles. Index des blocs ADT : la colonne compte
    -- vers l'OUEST et la ligne vers le NORD, toutes deux depuis le centre du
    -- monde (32) — la numérotation des fichiers .adt, que les minimaps
    -- reprennent telle quelle.
    function map:PoserTuiles(mapID)
        local dossier = Dossier(mapID)
        if not dossier then return false, "je ne sais pas comment s'appelle cette carte" end
        self.fondDossier = dossier
        local ouestMax = self.cx + (width / 2) / self.scale
        local ouestMin = self.cx - (width / 2) / self.scale
        local nordMax  = self.cy + (height / 2) / self.scale
        local nordMin  = self.cy - (height / 2) / self.scale
        local colMin = math.max(0, math.floor(32 - ouestMax / ADT))
        local colMax = math.min(63, math.floor(32 - ouestMin / ADT))
        local ligMin = math.max(0, math.floor(32 - nordMax / ADT))
        local ligMax = math.min(63, math.floor(32 - nordMin / ADT))
        if colMax < colMin or ligMax < ligMin then
            return false, "la vue est hors de la carte du jeu"
        end
        if (colMax - colMin + 1) * (ligMax - ligMin + 1) > MAX_TUILES then
            return false, "trop dézoomé pour le terrain"
        end
        local cote = ADT * self.scale
        local i = 0
        for lig = ligMin, ligMax do
            for col = colMin, colMax do
                i = i + 1
                local t = Tuile(i)
                t:SetTexture(string.format("world\\minimaps\\%s\\map%02d_%02d.blp", dossier, col, lig))
                local x, y = self:ToScreen((32 - col) * ADT, (32 - lig) * ADT)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", map, "TOPLEFT", x, -y)
                -- Un yard de rab : sans ça un liseré du fond passe entre deux
                -- tuiles dès que l'échelle tombe mal.
                t:SetSize(cote + 1, cote + 1)
                t:SetAlpha(self.fondAlpha or 1)
                t:Show()
            end
        end
        return i > 0
    end

    -- Les deux coins de l'image en coordonnées du MONDE, celles des sommets.
    -- La carte du jeu va du coin (0,0) au coin (1,1) ; le monde compte x vers
    -- l'ouest et y vers le nord (voir GetPlayerPose), et C_Map rend un
    -- Vector2D dont x est le nord et y l'ouest — le même repère, dans l'autre
    -- ordre. Prendre les deux coins plutôt que la taille déclarée évite de
    -- supposer où est l'origine.
    local function CoinsMonde(uiMap)
        if not (C_Map and C_Map.GetWorldPosFromMapPos) then return nil end
        local ok1, _, a = pcall(C_Map.GetWorldPosFromMapPos, uiMap, { x = 0, y = 0 })
        local ok2, _, b = pcall(C_Map.GetWorldPosFromMapPos, uiMap, { x = 1, y = 1 })
        if not (ok1 and ok2 and a and b) then return nil end
        if not (a.x and a.y and b.x and b.y) then return nil end
        if a.x == b.x or a.y == b.y then return nil end
        return a.y, a.x, b.y, b.x
    end

    -- L'image de zone publiée par le jeu. Rend false et le POURQUOI : sans la
    -- raison, une carte muette et une carte sans image se ressemblent, et on
    -- ne sait pas quoi corriger.
    function map:PoserImageZone()
        local uiMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if not uiMap then
            return false, "le jeu ne déclare aucune carte ici"
        end
        -- `a and f(a)` ne rendrait qu'UNE valeur : il faut un vrai `if`.
        local o1, n1, o2, n2 = CoinsMonde(uiMap)
        if not o1 then
            return false, "le jeu ne dit pas où cette carte commence et finit"
        end
        local couches = C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(uiMap)
        local couche = couches and couches[1]
        local images = couche and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(uiMap, 1)
        if not (couche and images and #images > 0
            and (couche.layerWidth or 0) > 0 and (couche.tileWidth or 0) > 0) then
            return false, "cette carte n'a pas d'image"
        end

        local x1, y1 = self:ToScreen(o1, n1)   -- coin de la carte en (0,0)
        local x2, y2 = self:ToScreen(o2, n2)   -- coin en (1,1)
        local larg, haut = x2 - x1, y2 - y1
        local colonnes = math.ceil(couche.layerWidth / couche.tileWidth)
        local lignes = math.ceil(couche.layerHeight / couche.tileHeight)
        local i = 0
        for ligne = 0, lignes - 1 do
            for col = 0, colonnes - 1 do
                i = i + 1
                local image = images[i]
                if image then
                    -- Les tuiles du bord sont remplies de vide : on n'en prend
                    -- que la part utile, sans quoi la carte serait étirée.
                    local tw = math.min(couche.tileWidth, couche.layerWidth - col * couche.tileWidth)
                    local th = math.min(couche.tileHeight, couche.layerHeight - ligne * couche.tileHeight)
                    local t = Tuile(i)
                    t:SetTexture(image)
                    t:SetTexCoord(0, tw / couche.tileWidth, 0, th / couche.tileHeight)
                    t:ClearAllPoints()
                    t:SetPoint("TOPLEFT", map, "TOPLEFT",
                        x1 + larg * (col * couche.tileWidth) / couche.layerWidth,
                        -(y1 + haut * (ligne * couche.tileHeight) / couche.layerHeight))
                    t:SetSize(math.max(1, larg * tw / couche.layerWidth),
                              math.max(1, haut * th / couche.layerHeight))
                    t:SetAlpha(self.fondAlpha or 1)
                    t:Show()
                end
            end
        end
        return true
    end

    -- Le terrain sous le tracé : les tuiles de minimap du client d'abord —
    -- seules à exister sur une carte personnalisée — puis l'image de zone
    -- publiée par le jeu. Retient le résultat pour que la fiche puisse dire
    -- ce qui a manqué.
    function map:PoserFondCarte(mapID)
        for _, t in ipairs(tuiles) do t:Hide() end
        self.fondPose, self.fondPourquoi, self.fondDossier = false, nil, nil
        if not self.fondCarte then tuilesFrame:Hide(); return false end
        local pose, pourquoi = self:PoserTuiles(mapID)
        if not pose then
            local poseZone, pourquoiZone = self:PoserImageZone()
            pose = poseZone
            pourquoi = poseZone and nil or (pourquoiZone or pourquoi)
        end
        tuilesFrame:SetShown(pose and true or false)
        self.fondPose, self.fondPourquoi = pose and true or false, pourquoi
        return self.fondPose, pourquoi
    end

    -- ── Repère ───────────────────────────────────────────────────────────

    function map:ToScreen(x, y)
        return width / 2 + (self.cx - x) * self.scale, height / 2 - (y - self.cy) * self.scale
    end
    function map:ToWorld(ox, oy)
        return self.cx - (ox - width / 2) / self.scale, self.cy - (oy - height / 2) / self.scale
    end
    -- Curseur → coordonnées du cadre, ou nil si le cadre n'est pas encore posé.
    local function Curseur()
        local mx, my = GetCursorPosition()
        local es = map:GetEffectiveScale()
        local left, top = map:GetLeft(), map:GetTop()
        if not left or not top then return nil end
        return mx / es - left, top - my / es
    end

    -- Les régions montrées : une seule (fiche Région) ou toutes celles d'un
    -- pays (fiche Pays).
    local function Montrees()
        if hooks.Regions then return hooks.Regions() or {} end
        local zone = hooks.Region and hooks.Region() or nil
        return zone and { zone } or {}
    end

    -- La carte du jeu affichée : celle où ces régions ont le plus de zones.
    local function CarteDuJeu(zones)
        local comptes, meilleure = {}, nil
        for _, zone in ipairs(zones) do
            for _, sub in pairs(zone.subZones or {}) do
                if sub.mapID then comptes[sub.mapID] = (comptes[sub.mapID] or 0) + 1 end
            end
        end
        for id, n in pairs(comptes) do
            if not meilleure or n > comptes[meilleure] then meilleure = id end
        end
        return meilleure
    end

    -- Ce qui se dessine : les zones de la région, puis les zones VOISINES de
    -- la même carte. Les voisines comptent : c'est contre elles qu'on soude,
    -- et une frontière ne s'arrête pas au bord d'une région.
    --
    -- Les PORTES de la région s'y ajoutent, en rouge : elles ne se soudent
    -- pas, mais on a besoin de voir où elles coupent les zones.
    function map:Dessinables()
        -- Carte d'un BÂTIMENT : son empreinte en guise de contour, ses pièces
        -- dedans. Un bâtiment est à ses pièces ce qu'une région est à ses
        -- lieux, et c'est le même outil qui les montre.
        if hooks.Batiment then return self:DessinablesBatiment() end
        local zones = Montrees()
        if #zones == 0 then return {}, nil end
        local carte = CarteDuJeu(zones)
        -- Plusieurs régions à l'écran (carte d'un pays) : la couleur distingue
        -- les RÉGIONS, pas les zones — c'est la carte des régions qu'on veut
        -- lire. Dans une seule région, c'est l'inverse.
        self.parRegion = #zones > 1
        local liste, miennes = {}, {}
        for _, zone in ipairs(zones) do
            miennes[zone.id] = true
            -- Un pays peut contenir la région d'un autre auteur : elle se
            -- montre, mais rien n'y bouge — le noyau refuserait, et des
            -- poignées mortes feraient croire le contraire.
            local tenue = zone.creator == Moi()
            for _, sub in pairs(zone.subZones or {}) do
                if sub.mapID == carte then
                    -- Le contour de la région contient tous les autres : le
                    -- remplir les cacherait, et son nom au centre tomberait
                    -- au milieu d'eux.
                    local lieu = sub.enterPlace and zone.places and zone.places[sub.enterPlace]
                    local pourRegion = lieu ~= nil and lieu.pourRegion == true
                    -- Un intérieur ne s'étale pas ici : les pièces d'un
                    -- bâtiment n'ont rien à faire sur la carte de la région,
                    -- et le bâtiment lui-même s'y marque d'un point. Sa carte
                    -- à lui s'ouvre d'un clic sur ce point.
                    if ZG:EstInterieur(sub) then
                        -- rien
                    elseif lieu and lieu.batiment and sub.shape == "polygon"
                        and sub.points and #sub.points >= 1 then
                        liste[#liste + 1] = { sub = sub, zone = zone, mienne = true,
                                              tenue = tenue, marqueur = true, place = lieu }
                    elseif sub.shape == "polygon" and sub.points and #sub.points >= 2 then
                        liste[#liste + 1] = { sub = sub, zone = zone, mienne = true,
                                              tenue = tenue, region = pourRegion }
                    elseif sub.shape ~= "polygon" and sub.x then
                        liste[#liste + 1] = { sub = sub, zone = zone, mienne = true, porte = true, tenue = tenue }
                    end
                end
            end
        end
        -- Les voisines : ce n'est pas contre elles qu'on travaille, mais une
        -- frontière ne s'arrête pas au bord d'une région, et sans elles on
        -- souderait à l'aveugle.
        for _, autre in ipairs(ZG:GetZoneList()) do
            if not miennes[autre.id] and autre.creator == Moi() then
                for _, sub in pairs(autre.subZones or {}) do
                    if sub.shape == "polygon" and sub.mapID == carte and sub.points and #sub.points >= 2
                        and not ZG:EstInterieur(sub) then
                        liste[#liste + 1] = { sub = sub, zone = autre, mienne = false }
                    end
                end
            end
        end
        -- Les contours de région d'abord : ils passent dessous, et leurs noms
        -- ne recouvrent pas ceux des lieux qu'ils contiennent.
        table.sort(liste, function(a, b)
            if (a.region or false) ~= (b.region or false) then return a.region == true end
            return a.sub.id < b.sub.id
        end)
        return liste, carte
    end

    -- La carte d'un bâtiment : son empreinte au sol en guise de contour
    -- (comme celui d'une région), et les zones de ses pièces dedans. Rien
    -- d'autre — on y travaille les cloisons, pas le voisinage.
    function map:DessinablesBatiment()
        local batiment = hooks.Batiment and hooks.Batiment() or nil
        if not batiment then return {}, nil end
        local zone = ZG:GetZone(batiment.zoneId)
        if not zone then return {}, nil end
        local tenue = zone.creator == Moi()
        self.parRegion = false

        -- Les pièces : les descendants du bâtiment, aussi profond qu'on veut
        -- (une alcôve dans une salle), portes comprises.
        local dedans = { [batiment.id] = true }
        local reste, bouge = {}, true
        for _, place in ipairs(ZG:GetPlaceList(zone.id)) do reste[#reste + 1] = place end
        while bouge do
            bouge = false
            for _, place in ipairs(reste) do
                if not dedans[place.id] and place.parent and dedans[place.parent] then
                    dedans[place.id] = true
                    bouge = true
                end
            end
        end

        local liste, carte = {}, nil
        for _, sub in pairs(zone.subZones or {}) do
            local lieu = sub.enterPlace and zone.places[sub.enterPlace]
            if lieu and dedans[lieu.id] then
                carte = carte or sub.mapID
                if lieu.id == batiment.id then
                    if sub.points and #sub.points >= 2 then
                        liste[#liste + 1] = { sub = sub, zone = zone, mienne = true,
                                              tenue = tenue, region = true }
                    end
                elseif sub.shape == "polygon" and sub.points and #sub.points >= 2 then
                    liste[#liste + 1] = { sub = sub, zone = zone, mienne = true, tenue = tenue }
                elseif sub.shape ~= "polygon" and sub.x then
                    liste[#liste + 1] = { sub = sub, zone = zone, mienne = true, porte = true, tenue = tenue }
                end
            end
        end
        table.sort(liste, function(a, b)
            if (a.region or false) ~= (b.region or false) then return a.region == true end
            return a.sub.id < b.sub.id
        end)
        return liste, carte
    end

    function map:Fit()
        local minx, maxx, miny, maxy
        for _, e in ipairs(self:Dessinables()) do
            if e.mienne then
                for _, p in ipairs(e.sub.points) do
                    minx = math.min(minx or p.x, p.x); maxx = math.max(maxx or p.x, p.x)
                    miny = math.min(miny or p.y, p.y); maxy = math.max(maxy or p.y, p.y)
                end
            end
        end
        if not minx then return end
        self.cx, self.cy = (minx + maxx) / 2, (miny + maxy) / 2
        local w, h = math.max(20, maxx - minx), math.max(20, maxy - miny)
        self.scale = math.max(MIN_SCALE, math.min(MAX_SCALE,
            math.min((width - 90) / w, (height - 90) / h)))
    end

    -- ── Sélection ────────────────────────────────────────────────────────

    local function Choisi(subId, index)
        for i, s in ipairs(map.sel) do
            if s.subId == subId and s.index == index then return i end
        end
        return nil
    end
    function map:Basculer(subId, index)
        local at = Choisi(subId, index)
        if at then table.remove(self.sel, at) else self.sel[#self.sel + 1] = { subId = subId, index = index } end
        self:Draw()
        if hooks.Change then hooks.Change() end
    end
    function map:Deselectionner()
        if #self.sel == 0 then return end
        self.sel = {}
        self:Draw()
        if hooks.Change then hooks.Change() end
    end
    -- La sélection ne survit pas au changement de géométrie : les indices
    -- auraient glissé, et une soudure se poserait sur le mauvais sommet.
    function map:Oublier() self.sel = {} end

    -- ── Retour en arrière ────────────────────────────────────────────────
    -- Glisser, souder, séparer laissent tous la même trace : des sommets et
    -- ce qu'ils valaient avant. Une seule pile pour les trois, et « Annuler »
    -- rend le dernier geste — sans quoi un sommet lâché au mauvais endroit se
    -- remet à la main, au pixel près, ce qui est impossible.
    local PROFONDEUR = 50

    -- cibles : { {subId=, index=} }. Rend l'instantané, à passer à Empiler.
    function map:Instantane(cibles) return ZG:SnapshotPoints(cibles) end

    local function Pousser(entree)
        map.pile[#map.pile + 1] = entree
        while #map.pile > PROFONDEUR do table.remove(map.pile, 1) end
    end

    function map:Empiler(avant, libelle)
        if not avant or #avant == 0 then return end
        Pousser({ avant = avant, libelle = libelle })
    end

    -- Un sommet AJOUTÉ ne se défait pas en restituant des coordonnées : il
    -- faut le retirer. D'où cette seconde sorte d'entrée dans la pile.
    function map:EmpilerRetrait(subId, index, libelle)
        Pousser({ retrait = { subId = subId, index = index }, libelle = libelle })
    end

    function map:Annulable()
        local dernier = self.pile[#self.pile]
        return dernier and dernier.libelle or nil
    end

    function map:Annuler()
        local dernier = table.remove(self.pile)
        if not dernier then return nil end
        if dernier.retrait then
            ZG:RemoveRegionPointAt(dernier.retrait.subId, dernier.retrait.index)
        else
            ZG:RestorePoints(dernier.avant)
        end
        self:Oublier()
        self:Draw()
        if hooks.Change then hooks.Change() end
        return dernier.libelle
    end

    -- Les deux côtés de la sélection, dans l'ordre où on les a désignés :
    -- a = la zone désignée en premier (elle fait foi), b = l'autre.
    function map:Cotes()
        local ordre, par = {}, {}
        for _, s in ipairs(self.sel) do
            if not par[s.subId] then par[s.subId] = {}; ordre[#ordre + 1] = s.subId end
            local liste = par[s.subId]
            liste[#liste + 1] = s.index
        end
        if #ordre ~= 2 then return nil, nil, #ordre end
        return { id = ordre[1], index = par[ordre[1]] }, { id = ordre[2], index = par[ordre[2]] }, 2
    end

    -- ── Dessin ───────────────────────────────────────────────────────────

    local poignees = {}   -- sommets attrapables du dernier dessin : { {subId=,index=,x=,y=} }
    local nomsCliquables = {}  -- { {subId=, zoneId=, x=, y=, w=, h=} }
    local segments = {}   -- arêtes de MES zones : { {subId=, index=, x1=,y1=,x2=,y2=} }

    local simplifications=setmetatable({}, {__mode="k"})
    function map:Draw()
        self.pendingZoom=nil
        geo = geo or ZG.Geo
        for i = 1, nTri do triPool[i]:Hide() end
        for i = 1, nTrait do traitPool[i]:Hide() end
        for i = 1, nTex do texPool[i]:Hide(); texPool[i].plaque:Hide() end
        for i = 1, nCarre do
            carrePool[i].bord:Hide(); carrePool[i].coeur:Hide(); carrePool[i].point:Hide()
        end
        for i = 1, nRond do rondPool[i]:Hide() end
        nTri, nTrait, nTex, nCarre, nRond = 0, 0, 0, 0, 0
        poignees, nomsCliquables, segments = {}, {}, {}
        -- Exposées pour le banc : il lit ce que le dessin a retenu.
        self.poignees, self.segments = poignees, segments

        local liste, carte = self:Dessinables()
        -- Le terrain suit la vue : il se repose à chaque dessin, comme le reste.
        self:PoserFondCarte(carte)
        local zone = Montrees()[1]
        if #liste == 0 then
            -- La carte s'ouvre la première : son message vide doit dire quoi
            -- faire ensuite, et ce n'est pas la même chose selon qu'il y a
            -- déjà des lieux ou non.
            local texte = "Choisissez une région."
            if hooks.Batiment then
                texte = "Ce bâtiment n'a pas encore d'empreinte.\nTracez son sol, puis créez ses pièces avec le bouton L de sa ligne."
            elseif zone then
                texte = (#ZG:GetPlaceList(zone.id) == 0)
                    and "Cette région n'a pas encore de lieu.\nCréez-en un dans l'onglet Lieux : sa zone naîtra avec lui."
                    or "Aucune zone dessinée ici.\nOuvrez un lieu, onglet Zone, et posez les sommets de son contour."
            end
            vide:SetText(texte)
            vide:Show()
            self.Moi()
            return
        end
        vide:Hide()

        -- Les sommets d'abord comptés : au-delà de MAX_POIGNEES, on les montre
        -- sans les rendre attrapables plutôt que de rendre la carte poussive.
        --
        -- Seuls comptent ceux qui sont À L'ÉCRAN. On comptait tous les sommets
        -- de toutes les zones montrées : sur la carte d'un pays on dépassait
        -- d'emblée, plus rien ne s'attrapait, et le message disait d'agrandir
        -- la zone affichée — ce qui ne changeait rien, puisque le compte ne
        -- regardait pas la vue. Zoomer sert maintenant à quelque chose.
        local ouestMax = self.cx + (width / 2 + 20) / self.scale
        local ouestMin = self.cx - (width / 2 + 20) / self.scale
        local nordMax  = self.cy + (height / 2 + 20) / self.scale
        local nordMin  = self.cy - (height / 2 + 20) / self.scale
        local total = 0
        for _, e in ipairs(liste) do
            if e.mienne and e.tenue and e.sub.points then
                for _, p in ipairs(e.sub.points) do
                    if p.x >= ouestMin and p.x <= ouestMax and p.y >= nordMin and p.y <= nordMax then
                        total = total + 1
                    end
                end
            end
        end
        local attrapables = total <= MAX_POIGNEES
        -- Exposés pour le banc : c'est le COMPTE qui décidait, et c'est lui
        -- qui était faux.
        self.sommetsEnVue, self.attrapables = total, attrapables

        local soudures = ZG:WeldGroups()
        for _, e in ipairs(liste) do
            -- Un bâtiment : un rond violet, son nom au-dessus. Son tracé et
            -- ses pièces se travaillent sur SA carte, qu'un clic ouvre.
            if e.marqueur then
                local cx, cy, n = 0, 0, 0
                for _, p in ipairs(e.sub.points or {}) do
                    local x, y = self:ToScreen(p.x, p.y)
                    cx, cy, n = cx + x, cy + y, n + 1
                end
                if n > 0 then
                    cx, cy = cx / n, cy / n
                elseif e.sub.x then
                    -- Empreinte pas encore tracée : le point de pose fait foi.
                    cx, cy = self:ToScreen(e.sub.x, e.sub.y)
                    n = 1
                end
                if n > 0 then
                    if cx > -60 and cx < width + 60 and cy > -40 and cy < height + 40 then
                        Rond(cx, cy, BATIMENT)
                        local nom = Texte(cx, cy - 17, e.sub.name or "", Clair(BATIMENT), false, 150)
                        local large = math.min(150, nom:GetStringWidth()) + 10
                        nomsCliquables[#nomsCliquables + 1] = {
                            subId = e.sub.id, zoneId = e.zone.id, x = cx, y = cy - 17,
                            w = large, h = nom:GetStringHeight() + 6,
                        }
                        -- Le rond se clique aussi : c'est lui qu'on vise.
                        nomsCliquables[#nomsCliquables + 1] = {
                            subId = e.sub.id, zoneId = e.zone.id, x = cx, y = cy, w = 20, h = 20,
                        }
                    end
                end

            -- Une porte : un segment rouge, son nom au-dessus. Elle n'a ni
            -- remplissage ni sommets à saisir — on la déplace depuis sa fiche.
            elseif e.porte then
                local a, b = geo.LineEnds(e.sub)
                local x1, y1 = self:ToScreen(a.x, a.y)
                local x2, y2 = self:ToScreen(b.x, b.y)
                Trait(x1, y1, x2, y2, PORTE, 4, e.sub.enabled == false and .35 or .95)
                local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
                if mx > -60 and mx < width + 60 and my > -30 and my < height + 30 then
                    local nom = Texte(mx, my - 14, e.sub.name or "", Clair(PORTE), false, 150)
                    nomsCliquables[#nomsCliquables + 1] = {
                        subId = e.sub.id, zoneId = e.zone.id, x = mx, y = my - 14,
                        w = math.min(150, nom:GetStringWidth()) + 10, h = nom:GetStringHeight() + 6,
                    }
                end
            else

            local sub = e.sub
            local points = sub.points
            -- Zone entièrement hors champ : rien à dessiner, et surtout rien à
            -- découper ni à transformer. Sur la carte d'un pays, c'est le gros
            -- du travail évité — la plupart des régions sont ailleurs.
            local bgMin, bgMax, bdMin, bdMax = points[1].x, points[1].x, points[1].y, points[1].y
            for i = 2, #points do
                local p = points[i]
                if p.x < bgMin then bgMin = p.x elseif p.x > bgMax then bgMax = p.x end
                if p.y < bdMin then bdMin = p.y elseif p.y > bdMax then bdMax = p.y end
            end
            if bgMax < ouestMin or bgMin > ouestMax or bdMax < nordMin or bdMin > nordMax then
                -- rien
            else

            local color = Teinte(e, self.parRegion)
            local ecran, cx, cy = {}, 0, 0
            -- Dézoomé, deux sommets voisins tombent sur le même pixel : on
            -- n'en garde qu'un. Un contour de 1500 sommets devenait 1500
            -- textures de trait à CHAQUE dessin, et ouvrir un pays — qui les
            -- montre tous — bloquait le jeu une seconde. Le dessin ne change
            -- pas : ce qu'on retire était invisible.
            --
            -- Seulement quand les sommets ne sont pas attrapables : tant qu'on
            -- peut les saisir, chacun doit être là où il est, et les arêtes
            -- doivent garder leur vrai rang (clic droit pour en insérer un).
            if not attrapables and #points > 64 then
                local cached=simplifications[points]
                local valid=cached and cached.scale==self.scale and #cached.coords==#points*2
                if valid then
                    for i,p in ipairs(points) do
                        if cached.coords[i*2-1]~=p.x or cached.coords[i*2]~=p.y then valid=false;break end
                    end
                end
                if not valid then
                    cached={scale=self.scale,coords={},points={points[1]}}
                    local last=points[1]
                    for i,p in ipairs(points) do
                        cached.coords[i*2-1],cached.coords[i*2]=p.x,p.y
                        if i>1 and i<#points and (math.abs(p.x-last.x)+math.abs(p.y-last.y))*self.scale>=2.5 then
                            cached.points[#cached.points+1]=p;last=p
                        end
                    end
                    cached.points[#cached.points+1]=points[#points]
                    simplifications[points]=cached
                end
                -- Identité stable : la triangulation peut enfin garder son cache.
                points=cached.points
            end
            for i, p in ipairs(points) do
                local x, y = self:ToScreen(p.x, p.y)
                ecran[i] = { x, y }; cx, cy = cx + x, cy + y
            end
            cx, cy = cx / #ecran, cy / #ecran
            local ferme = geo and geo.IsClosed(sub)

            -- Le nom se pose au centre du plus GRAND triangle du découpage,
            -- pas au milieu des sommets : une zone en L ou en T a son milieu
            -- de sommets dehors, et le nom se retrouvait sur un tracé, voire
            -- hors de sa propre zone. Le plus grand triangle, lui, est
            -- toujours dedans, et sa largeur dit de combien on dispose.
            local largeur
            if ferme and geo and geo.Triangulate then
                local triangles = geo.Triangulate(points)
                -- Le contour de la région se remplit AUSSI, mais à peine : il
                -- entoure tous les autres, et au même aplat qu'eux il les
                -- noierait. Sans aucun aplat, la région n'avait pas de fond
                -- du tout et son étendue ne se lisait pas.
                if PEUT_REMPLIR then
                    local alpha = e.region and .09 or (e.mienne and .28 or .10)
                    for _, t in ipairs(triangles) do
                        Tri(ecran[t[1]], ecran[t[2]], ecran[t[3]], color, alpha)
                    end
                end
                local meilleure = 0
                for _, t in ipairs(triangles) do
                    local a, b, c = ecran[t[1]], ecran[t[2]], ecran[t[3]]
                    local aire = math.abs((b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1])) / 2
                    if aire > meilleure then
                        meilleure = aire
                        cx, cy = (a[1] + b[1] + c[1]) / 3, (a[2] + b[2] + c[2]) / 3
                        largeur = math.max(math.min(a[1], b[1], c[1]), 0)
                        largeur = math.min(math.max(a[1], b[1], c[1]), width) - largeur
                    end
                end
                if largeur then largeur = math.max(52, math.min(220, largeur - 8)) end
            end
            -- Le nom de la région se pose en HAUT de son contour : au centre,
            -- il tomberait sur ses propres lieux.
            if e.region then
                local haut, gauche, droite = ecran[1][2], ecran[1][1], ecran[1][1]
                for i = 2, #ecran do
                    haut = math.min(haut, ecran[i][2])
                    gauche = math.min(gauche, ecran[i][1])
                    droite = math.max(droite, ecran[i][1])
                end
                cx, cy = (gauche + droite) / 2, haut + 13
                largeur = math.max(80, math.min(260, droite - gauche - 8))
            end
            local alphaTrait = e.mienne and .95 or .40
            -- Sans remplissage, le contour de la région ne se lit que par son
            -- trait : on le donne plus épais.
            local epaisseur = e.region and 3 or 2
            -- Les arêtes sont retenues : un clic droit sur l'une d'elles y
            -- insère un sommet (voir SegmentSous).
            -- Pas d'arête retenue quand le tracé est simplifié : son rang ne
            -- serait plus le vrai, et le clic droit insérerait au mauvais
            -- endroit. On ne simplifie que lorsque les sommets ne sont déjà
            -- plus attrapables, donc rien ne se perd.
            local function Arete(i, x1, y1, x2, y2)
                if e.mienne and e.tenue and attrapables then
                    segments[#segments + 1] = { subId = sub.id, index = i, x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
                end
            end
            for i = 2, #ecran do
                Trait(ecran[i - 1][1], ecran[i - 1][2], ecran[i][1], ecran[i][2], color, epaisseur, alphaTrait)
                Arete(i - 1, ecran[i - 1][1], ecran[i - 1][2], ecran[i][1], ecran[i][2])
            end
            if ferme then
                Trait(ecran[#ecran][1], ecran[#ecran][2], ecran[1][1], ecran[1][2], color, epaisseur, alphaTrait)
                Arete(#ecran, ecran[#ecran][1], ecran[#ecran][2], ecran[1][1], ecran[1][2])
            elseif e.mienne then
                -- Zone ouverte : la fermeture se devine, en pointillé clair,
                -- pour qu'on voie ce que « Fermer la zone » va relier.
                Trait(ecran[#ecran][1], ecran[#ecran][2], ecran[1][1], ecran[1][2], color, 1, .30)
            end

            -- Les sommets, seulement pour mes zones : on ne modifie pas celles
            -- d'un autre auteur, et des poignées mortes tromperaient.
            if e.mienne and e.tenue then
                for i, p in ipairs(sub.points) do
                    -- Recalculé depuis le sommet, pas lu dans `ecran` : le
                    -- tracé a pu être simplifié, et ses rangs ne sont alors
                    -- plus ceux des vrais sommets.
                    local x, y = self:ToScreen(p.x, p.y)
                    if x > -20 and x < width + 20 and y > -20 and y < height + 20 then
                        local groupe = p.weld and soudures[p.weld]
                        Carre(x, y, color, Choisi(sub.id, i) ~= nil, groupe and #groupe >= 2)
                        if attrapables then
                            poignees[#poignees + 1] = { subId = sub.id, index = i, x = x, y = y }
                        end
                    end
                end
            end

            -- Le nom au centre : celui de la zone, et dessous le lieu qu'elle
            -- ouvre. Cliquer dessus ouvre ce lieu sur son onglet Zone.
            if cx > -60 and cx < width + 60 and cy > -30 and cy < height + 30 then
                -- Une seule ligne quand le nom de la zone et celui de son lieu
                -- se ressemblent — ils naissent identiques, et les afficher
                -- deux fois n'apprenait rien.
                local sous
                if self.parRegion or not e.mienne then
                    -- Sur la carte d'un pays, c'est la région qui situe.
                    sous = e.zone.name
                elseif e.region then
                    -- Le contour de la région EST la région : rien à situer.
                    sous = nil
                else
                    local lieu = sub.enterPlace and ZG:FindPlace(sub.enterPlace)
                    sous = lieu and lieu.name or "(aucun lieu)"
                end
                if sous == (sub.name or "") then sous = nil end
                local nom = Texte(cx, cy, sub.name or "", Clair(color), e.mienne, largeur)
                if e.mienne then
                    nomsCliquables[#nomsCliquables + 1] = {
                        subId = sub.id, zoneId = e.zone.id, x = cx, y = cy,
                        w = math.min(largeur or 1e4, nom:GetStringWidth()) + 10,
                        h = nom:GetStringHeight() + 6,
                    }
                end
                if sous and sous ~= "" then
                    Texte(cx, cy + nom:GetStringHeight() / 2 + 9, sous, { .62, .60, .55 }, false, largeur)
                end
            end
            end   -- fin du cas « la zone est en vue »
            end   -- fin du cas « zone dessinée »
        end

        if not attrapables then
            Texte(width / 2, height - 14,
                string.format("%d sommets en vue : trop pour les attraper tous. Zoomez.", total),
                { .90, .78, .30 }, false)
        end
        self.Moi()
    end

    -- ── Où je me tiens ───────────────────────────────────────────────────
    -- La carte du JOUEUR cache volontairement sa position : elle ne doit rien
    -- révéler. Ici c'est l'inverse — on pose les sommets en marchant, et sans
    -- repère on ne sait pas de quel côté du contour on se trouve.
    local moi = sommets:CreateTexture(nil, "OVERLAY")
    moi:SetSize(11, 11); moi:SetColorTexture(.35, .85, 1, 1); moi:SetRotation(math.pi / 4)
    local moiHalo = traits:CreateTexture(nil, "OVERLAY")
    moiHalo:SetSize(19, 19); moiHalo:SetColorTexture(.08, .20, .26, .85); moiHalo:SetRotation(math.pi / 4)
    local moiCap = sommets:CreateTexture(nil, "OVERLAY")
    moiCap:SetColorTexture(.35, .85, 1, .9)
    local function Moi()
        local px, py, facing, carteJoueur = ZG:GetPlayerPose()
        local _, carte = map:Dessinables()
        if not px or (carte and carteJoueur ~= carte) then
            moi:Hide(); moiHalo:Hide(); moiCap:Hide()
            return
        end
        local x, y = map:ToScreen(px, py)
        for _, t in ipairs({ moi, moiHalo }) do
            t:ClearAllPoints(); t:SetPoint("CENTER", map, "TOPLEFT", x, -y); t:Show()
        end
        -- Le regard : +y est le nord (voir ZG:PlacementReadout), et le nord
        -- est en haut — donc à l'écran la pointe part en haut à gauche quand
        -- le cap tourne vers l'ouest.
        facing = facing or 0
        local L = 18
        local tx, ty = x - math.sin(facing) * L, y - math.cos(facing) * L
        local dx, dy = tx - x, ty - y
        moiCap:ClearAllPoints()
        moiCap:SetPoint("CENTER", map, "TOPLEFT", (x + tx) / 2, -(y + ty) / 2)
        moiCap:SetSize(math.sqrt(dx * dx + dy * dy), 2)
        moiCap:SetRotation(math.atan2(-dy, dx))
        moiCap:Show()
    end
    map.Moi = Moi

    -- ── Souris ───────────────────────────────────────────────────────────

    -- Un Frame reçoit le nom du bouton dans OnMouseDown : pas de
    -- RegisterForClicks, qui n'existe que sur un Button.
    map:EnableMouse(true); map:EnableMouseWheel(true)

    map:SetScript("OnMouseWheel", function(_, delta)
        if not map.scale or delta==0 then return end
        local p=map.pendingZoom or {scale=map.scale,cx=map.cx,cy=map.cy,age=0}
        local s=math.max(MIN_SCALE,math.min(MAX_SCALE,p.scale*1.25^delta))
        if s==p.scale then return end
        local ox,oy=Curseur()
        if ox then
            local wx=p.cx-(ox-width/2)/p.scale;local wy=p.cy-(oy-height/2)/p.scale
            p.cx=wx+(ox-width/2)/s;p.cy=wy+(oy-height/2)/s
        end
        p.scale,p.quiet=s,0;map.pendingZoom=p
    end)

    local function PoigneeSous(ox, oy)
        local best, bestD
        for _, h in ipairs(poignees) do
            local d = (h.x - ox) ^ 2 + (h.y - oy) ^ 2
            if d <= ACCROCHE * ACCROCHE and (not bestD or d < bestD) then best, bestD = h, d end
        end
        return best
    end
    local function NomSous(ox, oy)
        for _, n in ipairs(nomsCliquables) do
            if math.abs(n.x - ox) <= n.w / 2 and math.abs(n.y - oy) <= n.h / 2 then return n end
        end
    end

    -- L'arête la plus proche du curseur, et le point du segment qui lui fait
    -- face : le sommet inséré se pose SUR la ligne, pas à côté.
    local function SegmentSous(ox, oy)
        local best, bestD, bx, by
        for _, s in ipairs(segments) do
            local dx, dy = s.x2 - s.x1, s.y2 - s.y1
            local long = dx * dx + dy * dy
            local t = long > 0 and math.max(0, math.min(1, ((ox - s.x1) * dx + (oy - s.y1) * dy) / long)) or 0
            local px, py = s.x1 + t * dx, s.y1 + t * dy
            local d = (px - ox) ^ 2 + (py - oy) ^ 2
            if d <= ACCROCHE * ACCROCHE and (not bestD or d < bestD) then
                best, bestD, bx, by = s, d, px, py
            end
        end
        return best, bx, by
    end

    map:SetScript("OnMouseDown", function(_, bouton)
        -- Clic droit sur une arête : un sommet s'y insère, à sa place dans
        -- l'ordre du contour. Entre le 8 et le 9, le nouveau devient le 9 et
        -- l'ancien 9 passe 10.
        if bouton == "RightButton" then
            local ox, oy = Curseur()
            if not ox then return end
            local segment, px, py = SegmentSous(ox, oy)
            if not segment then return end
            local wx, wy = map:ToWorld(px, py)
            if ZG:InsertRegionPoint(segment.subId, segment.index, wx, wy) then
                map:EmpilerRetrait(segment.subId, segment.index + 1, "le sommet ajouté")
                -- Les rangs ont glissé : une sélection retenue viserait à côté.
                map:Oublier()
                map:Draw()
                if hooks.Change then hooks.Change() end
            end
            return
        end
        if bouton ~= "LeftButton" then return end
        local ox, oy = Curseur()
        if not ox then return end
        local mx, my = GetCursorPosition()
        local poignee = PoigneeSous(ox, oy)
        if poignee then
            -- L'instantané se prend AVANT le premier pixel : à la fin du
            -- glissement l'ancienne position n'existe plus nulle part.
            map.prise = {
                subId = poignee.subId, index = poignee.index, mx = mx, my = my, bouge = false,
                avant = map:Instantane({ { subId = poignee.subId, index = poignee.index } }),
            }
            return
        end
        local nom = NomSous(ox, oy)
        if nom then map.nomPris = { nom = nom, mx = mx, my = my }; return end
        map.pan = { mx = mx, my = my, cx = map.cx, cy = map.cy }
    end)

    map:SetScript("OnMouseUp", function(_, bouton)
        if bouton ~= "LeftButton" then
            map.prise, map.pan, map.nomPris = nil, nil, nil
            return
        end
        local prise, pan, nomPris = map.prise, map.pan, map.nomPris
        map.prise, map.pan, map.nomPris = nil, nil, nil
        local mx, my = GetCursorPosition()

        if prise then
            if prise.bouge then
                -- Le glissement a déplacé le sommet sans rien diffuser : ce
                -- dernier appel, lui, part sur le réseau et dans la base.
                local sub = ZG:FindSubZone(prise.subId)
                local p = sub and sub.points and sub.points[prise.index]
                if p then ZG:MoveRegionPoint(prise.subId, prise.index, p.x, p.y) end
                map:Empiler(prise.avant, "le déplacement d'un sommet")
                map:Draw()
                if hooks.Change then hooks.Change() end
            else
                map:Basculer(prise.subId, prise.index)
            end
            return
        end
        if nomPris then
            if math.abs(mx - nomPris.mx) + math.abs(my - nomPris.my) <= 4 then
                local sub, zone = ZG:FindSubZone(nomPris.nom.subId)
                if sub and hooks.OuvrirZone then hooks.OuvrirZone(sub, zone) end
            end
            return
        end
        -- Un clic dans le vide, sans glisser, oublie la sélection.
        if pan and math.abs(mx - pan.mx) + math.abs(my - pan.my) <= 4 then map:Deselectionner() end
    end)

    -- Le personnage bouge sans que la carte soit redessinée : son repère se
    -- rafraîchit tout seul, dix fois par seconde, sans refaire le dessin.
    local depuis = 0
    map:SetScript("OnUpdate", function(self, ecoule)
        local pending=self.pendingZoom
        if pending then
            pending.age=pending.age+ecoule;pending.quiet=pending.quiet+ecoule
            if pending.quiet>=.09 or pending.age>=.18 then
                self.cx,self.cy,self.scale=pending.cx,pending.cy,pending.scale
                self.pendingZoom=nil;self:Draw()
            end
        end
        depuis = depuis + (ecoule or 0)
        if depuis >= .1 then depuis = 0; self.Moi() end
        if self.prise then
            local ox, oy = Curseur()
            if not ox then return end
            local mx, my = GetCursorPosition()
            if not self.prise.bouge and math.abs(mx - self.prise.mx) + math.abs(my - self.prise.my) <= 3 then return end
            self.prise.bouge = true
            local wx, wy = self:ToWorld(ox, oy)
            ZG:MoveRegionPoint(self.prise.subId, self.prise.index, wx, wy, true)
            self:Draw()
        elseif self.pan then
            local mx, my = GetCursorPosition()
            local es = self:GetEffectiveScale()
            local cx=self.pan.cx+(mx-self.pan.mx)/es/self.scale
            local cy=self.pan.cy-(my-self.pan.my)/es/self.scale
            if cx~=self.cx or cy~=self.cy then self.cx,self.cy=cx,cy;self:Draw() end
        end
    end)

    return map
end
