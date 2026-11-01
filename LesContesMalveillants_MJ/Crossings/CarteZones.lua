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
local function Teinte(id)
    local geo = ZG.Geo
    if geo and geo.Color then return geo.Color(id) end
    return { .6, .6, .6 }
end
local function Clair(c) return { math.min(1, c[1] + .35), math.min(1, c[2] + .35), math.min(1, c[3] + .35) } end

-- Les portes, toujours en rouge, ici comme dans la liste de gauche.
local PORTE = { 0.85, 0.45, 0.38 }

-- `hooks` :
--   Region()        → la région affichée (table zone), ou nil
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

    -- La carte du jeu affichée : celle où la région a ses zones.
    local function CarteDuJeu(zone)
        local comptes, meilleure = {}, nil
        for _, sub in pairs(zone and zone.subZones or {}) do
            if sub.mapID then comptes[sub.mapID] = (comptes[sub.mapID] or 0) + 1 end
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
        local zone = hooks.Region and hooks.Region() or nil
        if not zone then return {}, nil end
        local carte = CarteDuJeu(zone)
        local liste = {}
        for _, sub in pairs(zone.subZones or {}) do
            if sub.shape == "polygon" and sub.mapID == carte and sub.points and #sub.points >= 2 then
                liste[#liste + 1] = { sub = sub, zone = zone, mienne = true }
            end
        end
        for _, sub in pairs(zone.subZones or {}) do
            if sub.shape ~= "polygon" and sub.mapID == carte and sub.x then
                liste[#liste + 1] = { sub = sub, zone = zone, mienne = true, porte = true }
            end
        end
        for _, autre in ipairs(ZG:GetZoneList()) do
            if autre.id ~= zone.id and autre.creator == Moi() then
                for _, sub in pairs(autre.subZones or {}) do
                    if sub.shape == "polygon" and sub.mapID == carte and sub.points and #sub.points >= 2 then
                        liste[#liste + 1] = { sub = sub, zone = autre, mienne = false }
                    end
                end
            end
        end
        table.sort(liste, function(a, b) return a.sub.id < b.sub.id end)
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

    function map:Empiler(avant, libelle)
        if not avant or #avant == 0 then return end
        self.pile[#self.pile + 1] = { avant = avant, libelle = libelle }
        while #self.pile > PROFONDEUR do table.remove(self.pile, 1) end
    end

    function map:Annulable()
        local dernier = self.pile[#self.pile]
        return dernier and dernier.libelle or nil
    end

    function map:Annuler()
        local dernier = table.remove(self.pile)
        if not dernier then return nil end
        ZG:RestorePoints(dernier.avant)
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

    function map:Draw()
        geo = geo or ZG.Geo
        for i = 1, nTri do triPool[i]:Hide() end
        for i = 1, nTrait do traitPool[i]:Hide() end
        for i = 1, nTex do texPool[i]:Hide(); texPool[i].plaque:Hide() end
        for i = 1, nCarre do
            carrePool[i].bord:Hide(); carrePool[i].coeur:Hide(); carrePool[i].point:Hide()
        end
        nTri, nTrait, nTex, nCarre = 0, 0, 0, 0
        poignees, nomsCliquables = {}, {}

        local liste, carte = self:Dessinables()
        local zone = hooks.Region and hooks.Region() or nil
        if #liste == 0 then
            -- La carte s'ouvre la première : son message vide doit dire quoi
            -- faire ensuite, et ce n'est pas la même chose selon qu'il y a
            -- déjà des lieux ou non.
            local texte = "Choisissez une région."
            if zone then
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
        local total = 0
        for _, e in ipairs(liste) do if e.mienne then total = total + #e.sub.points end end
        local attrapables = total <= MAX_POIGNEES

        local soudures = ZG:WeldGroups()
        for _, e in ipairs(liste) do
            -- Une porte : un segment rouge, son nom au-dessus. Elle n'a ni
            -- remplissage ni sommets à saisir — on la déplace depuis sa fiche.
            if e.porte then
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

            local sub, color = e.sub, Teinte(e.sub.id)
            local ecran, cx, cy = {}, 0, 0
            for i, p in ipairs(sub.points) do
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
                local triangles = geo.Triangulate(sub.points)
                if PEUT_REMPLIR then
                    local alpha = e.mienne and .28 or .10
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
            local alphaTrait = e.mienne and .95 or .40
            for i = 2, #ecran do
                Trait(ecran[i - 1][1], ecran[i - 1][2], ecran[i][1], ecran[i][2], color, 2, alphaTrait)
            end
            if ferme then
                Trait(ecran[#ecran][1], ecran[#ecran][2], ecran[1][1], ecran[1][2], color, 2, alphaTrait)
            elseif e.mienne then
                -- Zone ouverte : la fermeture se devine, en pointillé clair,
                -- pour qu'on voie ce que « Fermer la zone » va relier.
                Trait(ecran[#ecran][1], ecran[#ecran][2], ecran[1][1], ecran[1][2], color, 1, .30)
            end

            -- Les sommets, seulement pour mes zones : on ne modifie pas celles
            -- d'un autre auteur, et des poignées mortes tromperaient.
            if e.mienne then
                for i, p in ipairs(sub.points) do
                    local x, y = ecran[i][1], ecran[i][2]
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
                if e.mienne then
                    local lieu = sub.enterPlace and ZG:FindPlace(sub.enterPlace)
                    sous = lieu and lieu.name or "(aucun lieu)"
                    if sous == (sub.name or "") then sous = nil end
                else
                    sous = e.zone.name
                end
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
            end   -- fin du cas « zone dessinée »
        end

        if not attrapables then
            Texte(width / 2, height - 14,
                string.format("%d sommets : trop pour les attraper tous. Agrandissez la zone affichée.", total),
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

    map:EnableMouse(true); map:EnableMouseWheel(true)

    map:SetScript("OnMouseWheel", function(_, delta)
        local facteur = delta > 0 and 1.25 or 1 / 1.25
        local s = math.max(MIN_SCALE, math.min(MAX_SCALE, map.scale * facteur))
        local ox, oy = Curseur()
        if ox then
            -- Le point sous le curseur reste sous le curseur.
            local wx, wy = map:ToWorld(ox, oy)
            map.scale = s
            map.cx = wx + (ox - width / 2) / s
            map.cy = wy + (oy - height / 2) / s
        else
            map.scale = s
        end
        map:Draw()
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

    map:SetScript("OnMouseDown", function(_, bouton)
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
            self.cx = self.pan.cx + (mx - self.pan.mx) / es / self.scale
            self.cy = self.pan.cy - (my - self.pan.my) / es / self.scale
            self:Draw()
        end
    end)

    return map
end
