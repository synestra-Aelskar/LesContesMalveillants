-- Editeur MJ des cartes (Core/Cartes.lua), ouvert depuis le compendium ou
-- par l'entree Cartes du radial (Systeme > Interactions).
--
-- Une carte DEVOILE des regions et des lieux (un arbre a cocher : cocher une
-- region apprend son nom au lecteur et la fait figurer sur la carte ; cocher
-- un lieu apprend son nom et dessine son contour), et indique des REPERES. Un repere est toujours un point deja POSE — une
-- ressource, un vendeur, un coffre, par moi ou par l'autre MJ — et se place
-- tout seul a ses coordonnees X, Y, Z : pas d'epingle a poser a la main (le
-- MJ, 31 octobre 2026).
--
-- Les points poses se choisissent dans une fenetre a part (« Points posés ») :
-- d'abord ceux qui sont DANS la region de la carte (meme carte serveur, et
-- dans un perimetre de la region), puis tous les autres, ranges par pays ›
-- region › lieu. Une carte au tresor peut ainsi indiquer des coffres dans
-- plusieurs regions, plusieurs pays : la carte lue dessine ceux de sa region
-- et nomme l'emplacement des autres.
local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Ecran = {}
MJ.CartesUI = Ecran
LCM.CartesUI = Ecran

local LIGNE = 24
local AUCUNE = "__aucune"

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function ZG() return LCM.Crossings end

-- Un point pose, dans le repere de Crossings. Les points de LCM retiennent
-- la position telle que DeplacementForce la donne (x, y de UnitPosition, ou
-- de la position serveur : le meme repere) ; Crossings range ces deux axes
-- dans l'autre ordre (ZG:GetPlayerPose). La source « carte » (fraction de
-- carte fois sa taille) ne compte pas dans la meme unite : refusee.
local function DepuisPoint(p)
    if not (p and tonumber(p.x) and tonumber(p.y)) then return nil, "point sans position" end
    if p.source == "carte" then
        return nil, "posé par la carte du jeu : sa position ne se reporte pas sur Crossings"
    end
    return tonumber(p.y), tonumber(p.x)
end

-- Les points poses, tous genres confondus, les miens ET ceux de l'autre MJ
-- (ce que la base commune connait, MJ/Poses.lua). Chacun est SITUE : la
-- region et le lieu qui le contiennent (Cartes.Localiser : meme carte
-- serveur et dans un perimetre). { id, genre, label, posePar, x, y, z,
-- carte, ou = {...} | nil, refus }.
-- Les quatre ateliers qui posent des points : ressources, vendeurs, coffres,
-- panneaux d'affichage.
local GENRES_POSES = { "ressource", "vendeur", "coffre", "affichage" }
local function PointsPoses()
    local out, vus = {}, {}
    local function Ajouter(genre, p, posePar)
        local id = genre .. ":" .. tostring(p.id)
        if vus[id] then return end
        vus[id] = true
        local def = LCM.Points and LCM.Points.Get(p.def)
        local x, y = DepuisPoint(p)
        local e = { id = id, genre = genre, label = (def and def.label) or tostring(p.def or "?"),
            posePar = posePar, z = tonumber(p.z), carte = tonumber(p.mapid) }
        if x then
            e.x, e.y = x, y
            e.ou = LCM.Cartes.Localiser(x, y, e.carte)
        else
            e.refus = y
        end
        out[#out + 1] = e
    end
    local miens = {
        ressource = LCM.Recoltes and LCM.Recoltes.Points and LCM.Recoltes.Points(nil, true) or {},
        vendeur = LCM.MarchandsMJ and LCM.MarchandsMJ.Points and LCM.MarchandsMJ.Points() or {},
        coffre = LCM.CoffresMJ and LCM.CoffresMJ.Points and LCM.CoffresMJ.Points() or {},
        affichage = LCM.AffichagesMJ and LCM.AffichagesMJ.Points and LCM.AffichagesMJ.Points() or {},
    }
    for _, genre in ipairs(GENRES_POSES) do
        for _, p in ipairs(miens[genre]) do Ajouter(genre, p, p.posePar or LCM.PlayerId()) end
        for _, pose in ipairs(LCM.Poses and LCM.Poses.De(genre) or {}) do
            Ajouter(genre, LCM.Poses.Entree(pose), pose.donnees and pose.donnees.posePar or pose.auteur)
        end
    end
    table.sort(out, function(a, b)
        if a.genre ~= b.genre then return a.genre < b.genre end
        return a.label < b.label
    end)
    return out
end
Ecran.PointsPoses = PointsPoses

local function Par(e)
    local par = LCM.Poses and LCM.Poses.Court(e.posePar) or tostring(e.posePar or "")
    local moi = LCM.Poses and LCM.Poses.Court(LCM.PlayerId()) or ""
    return (par ~= "" and par ~= moi) and ("  |cffc8a45e(par " .. par .. ")|r") or ""
end

-- ===== La fenetre « Points posés » ==========================================
-- Les cases d'un editeur ouvert : cocher ajoute le repere a sa copie de
-- travail, decocher le retire.

local function ConstruireChoix()
    local d = UI.Fenetre("cartes_points", "Points posés", 560, 600, { x = 440, y = -10 },
        { enTeteSimple = true, sobre = true })
    local c = d.contenu
    d.aide = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    d.aide:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -8)
    d.aide:SetPoint("RIGHT", c, "RIGHT", -12, 0)
    d.aide:SetWordWrap(true)
    d.liste = UI.Defilement(c)
    d.liste:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -44)
    d.liste:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -20, 40)
    d.lignes = {}
    d.note = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    d.note:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 12, 12)
    d.note:SetPoint("RIGHT", c, "RIGHT", -12, 0)

    function d:Ligne(i)
        local l = self.lignes[i]
        if l then return l end
        l = CreateFrame("Frame", nil, self.liste.contenu)
        l:SetSize(500, LIGNE - 2)
        l.case = UI.Case(l, "", function(coche)
            if l.point and d.editeur then d.editeur:BasculerPoint(l.point, coche) end
        end)
        l.case:SetPoint("LEFT", l, "LEFT", 14, 0)
        l.texte = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
        l.texte:SetPoint("RIGHT", l, "RIGHT", -4, 0)
        l.texte:SetWordWrap(false)
        self.lignes[i] = l
        return l
    end

    function d:Afficher()
        local f = self.editeur
        if not f or not f.travail then return end
        local dans, noms = {}, {}
        for _, r in ipairs(f.travail.regions or {}) do
            dans[r.id] = true
            local zone = ZG() and ZG():GetZone(r.id)
            noms[#noms + 1] = (zone and zone.name) or r.nom or "?"
        end
        -- Les groupes : la region de la carte d'abord, puis pays › region,
        -- puis ce qu'aucune region ne contient.
        local ici, ailleurs, nonSitues, refuses = {}, {}, {}, 0
        local ordre = {}
        for _, e in ipairs(PointsPoses()) do
            if not e.x then
                refuses = refuses + 1
            elseif e.ou and dans[e.ou.region] then
                ici[#ici + 1] = e
            elseif e.ou then
                local cle = (e.ou.paysNom or "Sans pays") .. " › " .. (e.ou.regionNom or "?")
                if not ailleurs[cle] then ailleurs[cle] = {} ordre[#ordre + 1] = cle end
                table.insert(ailleurs[cle], e)
            else
                nonSitues[#nonSitues + 1] = e
            end
        end
        table.sort(ordre)
        local rangees = {}
        if #noms > 0 then
            rangees[#rangees + 1] = { titre = string.format("Dans %s « %s » (%d)",
                #noms > 1 and "les régions" or "la région", table.concat(noms, " », « "), #ici) }
            for _, e in ipairs(ici) do rangees[#rangees + 1] = { point = e } end
            if #ici == 0 then rangees[#rangees + 1] = { vide = "Aucun point posé dans ces régions." } end
        end
        for _, cle in ipairs(ordre) do
            rangees[#rangees + 1] = { titre = cle .. string.format(" (%d)", #ailleurs[cle]) }
            for _, e in ipairs(ailleurs[cle]) do rangees[#rangees + 1] = { point = e } end
        end
        if #nonSitues > 0 then
            rangees[#rangees + 1] = { titre = string.format("Dans aucune région Crossings (%d)", #nonSitues) }
            for _, e in ipairs(nonSitues) do rangees[#rangees + 1] = { point = e } end
        end
        if #rangees == 0 then rangees[1] = { vide = "Aucun point posé pour l'instant : pose une ressource, un vendeur, un coffre ou un panneau." } end

        for i, rangee in ipairs(rangees) do
            local l = self:Ligne(i)
            l.point = rangee.point
            l.texte:ClearAllPoints()
            l.texte:SetPoint("RIGHT", l, "RIGHT", -4, 0)
            if rangee.point then
                local e = rangee.point
                local g = LCM.Cartes.Genre(e.genre)
                l.case:Show()
                l.case:Cocher(f:RepereDuPoint(e.id) ~= nil)
                l.case.label:SetText("")
                l.texte:SetPoint("LEFT", l, "LEFT", 40, 0)
                l.texte:SetText(string.format("%s  ·  %s%s%s", g and g.label or e.genre, e.label,
                    e.ou and e.ou.lieuNom and ("  —  " .. e.ou.lieuNom) or "", Par(e)))
                l.texte:SetTextColor(UI.C.texte[1], UI.C.texte[2], UI.C.texte[3])
            else
                l.case:Hide()
                l.texte:SetPoint("LEFT", l, "LEFT", rangee.titre and 2 or 14, 0)
                l.texte:SetText(rangee.titre or rangee.vide)
                local couleur = rangee.titre and UI.C.accent or UI.C.discret
                l.texte:SetTextColor(couleur[1], couleur[2], couleur[3])
            end
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.liste.contenu, "TOPLEFT", 0, -2 - (i - 1) * LIGNE)
            l:Show()
        end
        for i = #rangees + 1, #self.lignes do self.lignes[i]:Hide() end
        self.liste:Regler(4 + #rangees * LIGNE)
        self.aide:SetText("Coche les points que la carte indique. Ceux des régions dévoilées viennent "
            .. "d'abord ; les autres sont rangés par pays et région — une carte au trésor peut en indiquer partout.")
        self.note:SetText(refuses > 0 and string.format(
            "%d point(s) posé(s) par la carte du jeu ne se situent pas sur Crossings.", refuses) or "")
    end

    d:Hide()
    return d
end

function Ecran.Choix()
    Ecran.choix = Ecran.choix or ConstruireChoix()
    return Ecran.choix
end

-- ===== L'editeur ============================================================

local function Construire()
    local f = UI.Fenetre("editeur_cartes", "Éditer une carte", 820, 680,
        { x = 20, y = -10 }, { enTeteSimple = true, sobre = true })
    local c = f.contenu
    local function Legende(texte, x, y)
        local fs = UI.Texte(c, texte, UI.C.discret, "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
        return fs
    end

    -- ── En-tete : nom, icone, resume ──
    Legende("Nom", 20, 12)
    f.nom = UI.Champ(c, 360, 23, function(texte) if f.travail then f.travail.label = texte end end)
    f.nom:SetMaxLetters(120)
    f.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 90, -8)
    Legende("Icône", 468, 12)
    f.icone = UI.Bouton(c, "Choisir", 115, 23, function(self)
        Ecran.selecteur = Ecran.selecteur or UI.SelecteurIcone("carte")
        Ecran.selecteur:Proposer(self, function(chemin)
            f.travail.icone = chemin
            f.icone.label:SetText("Icône choisie")
        end)
    end)
    f.icone:SetPoint("TOPLEFT", c, "TOPLEFT", 515, -8)
    Legende("Résumé", 20, 48)
    f.description = UI.Champ(c, 680, 22, function(texte) if f.travail then f.travail.description = texte end end)
    f.description:SetMaxLetters(220)
    f.description:SetPoint("TOPLEFT", c, "TOPLEFT", 90, -42)

    -- ── Reprendre une autre carte ──
    Legende("Reprend", 20, 82)
    f.reprend = UI.Deroulant(c, 320, 24, function()
        local options = { { id = AUCUNE, label = "Aucune : cette carte a son propre contenu" } }
        for _, carte in ipairs(LCM.Cartes.list) do
            if not f.travail or carte.id ~= f.travail.id then
                options[#options + 1] = { id = carte.id, label = carte.label or carte.id }
            end
        end
        return options
    end, function(id)
        f.travail.reprend = id ~= AUCUNE and id or nil
        f:Afficher()
    end)
    f.reprend:SetPoint("TOPLEFT", c, "TOPLEFT", 90, -76)
    f.reprendAide = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    f.reprendAide:SetPoint("LEFT", f.reprend, "RIGHT", 12, 0)
    f.reprendAide:SetWidth(360)

    -- Le contenu propre, cache quand la carte en reprend une autre.
    f.propre = CreateFrame("Frame", nil, c)
    f.propre:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -110)
    f.propre:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 60)
    local p = f.propre
    local function LegendeP(texte, x, y)
        local fs = UI.Texte(p, texte, UI.C.discret, "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", p, "TOPLEFT", x, -y)
        return fs
    end

    -- ── Ce que la carte devoile : un arbre region › lieux ──
    -- « Région » seul ne disait pas ce qu'il faisait (le MJ, 31 octobre 2026) :
    -- il devoilait la region ET filtrait ses lieux, et une seule a la fois.
    -- C'est maintenant un arbre, et chaque case dit ce qu'elle fait.
    LegendeP("Ce que la carte dévoile", 20, 8)
    f.aideArbre = UI.Texte(p, "Une région cochée : son nom est appris et elle figure sur la carte. "
        .. "Un lieu coché : son nom est appris et son contour est dessiné.", UI.C.discret, "GameFontNormalSmall")
    f.aideArbre:SetPoint("TOPLEFT", p, "TOPLEFT", 20, -26)
    f.aideArbre:SetWidth(310)
    f.aideArbre:SetWordWrap(true)
    f.arbre = UI.Defilement(p)
    f.arbre:SetPoint("TOPLEFT", p, "TOPLEFT", 20, -62)
    f.arbre:SetSize(310, 330)
    f.noeuds = {}
    f.aucuneRegion = UI.Texte(f.arbre.contenu, "Aucune région Crossings : crée-en une dans l'outil Lieux.",
        UI.C.discret, "GameFontNormalSmall")
    f.aucuneRegion:SetPoint("TOPLEFT", f.arbre.contenu, "TOPLEFT", 4, -6)
    f.aucuneRegion:SetWidth(290)
    f.aucuneRegion:SetWordWrap(true)

    -- ── Reperes : les points poses que la carte indique ──
    LegendeP("Repères (points posés)", 350, 42)
    f.reperes = UI.Defilement(p)
    f.reperes:SetPoint("TOPLEFT", p, "TOPLEFT", 350, -62)
    f.reperes:SetSize(430, 300)
    f.lignes = {}
    f.aucunRepere = UI.Texte(f.reperes.contenu, "Aucun repère : la carte ne montre que ses lieux.",
        UI.C.discret, "GameFontNormalSmall")
    f.aucunRepere:SetPoint("TOPLEFT", f.reperes.contenu, "TOPLEFT", 4, -6)
    f.choisirPoints = UI.Bouton(p, "Choisir des points posés…", 220, 26, function() f:OuvrirChoix() end)
    f.choisirPoints:SetPoint("TOPLEFT", p, "TOPLEFT", 350, -372)
    UI.Bulle(f.choisirPoints, "Points posés",
        "Ressources, vendeurs, coffres et panneaux posés, par toi ou par l'autre MJ. Le repère se place tout seul à leurs coordonnées.", 0.2)

    -- ── Pied ──
    f.erreur = UI.Texte(c, "", { 1, 0.4, 0.35 }, "GameFontNormalSmall")
    f.erreur:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 20, 46)
    f.erreur:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -20, 46)
    f.apercu = UI.Bouton(c, "Aperçu", 105, 25, function()
        local ok, raison = UI.Cartes.Apercu(f.travail)
        f.erreur:SetText(ok and "" or tostring(raison))
    end)
    f.apercu:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 20, 14)
    f.enregistrer = UI.Bouton(c, "Enregistrer", 140, 25, function() f:Enregistrer() end)
    f.enregistrer:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -20, 14)

    -- ── Gestes ──
    function f:RegionDevoilee(id)
        for _, r in ipairs(self.travail.regions or {}) do if r.id == id then return true end end
        return false
    end
    function f:LieuDevoile(id)
        for _, lieu in ipairs(self.travail.lieux or {}) do if lieu.id == id then return true end end
        return false
    end
    -- Decocher une region retire aussi ses lieux : ils ne se devoilent pas
    -- sans elle.
    function f:BasculerRegion(zone, coche)
        local regions = self.travail.regions
        for i = #regions, 1, -1 do if regions[i].id == zone.id then table.remove(regions, i) end end
        if coche then
            regions[#regions + 1] = { id = zone.id, nom = zone.name or "" }
        else
            local lieux = self.travail.lieux
            for i = #lieux, 1, -1 do
                local _, z = ZG():FindPlace(lieux[i].id)
                if z and z.id == zone.id then table.remove(lieux, i) end
            end
        end
        self:Afficher()
    end
    -- Cocher un lieu coche sa region : on ne devoile pas la Crique aux Os sans
    -- dire qu'elle est sur la Cote d'Osol.
    function f:Basculer(place, zone, coche)
        local lieux = self.travail.lieux
        for i = #lieux, 1, -1 do if lieux[i].id == place.id then table.remove(lieux, i) end end
        if coche then
            if #lieux >= LCM.Cartes.MAX_LIEUX then
                self.erreur:SetText(LCM.Cartes.MAX_LIEUX .. " lieux au plus sur une carte.")
                self:Afficher()
                return
            end
            lieux[#lieux + 1] = { id = place.id, nom = place.name or "" }
            if not self:RegionDevoilee(zone.id) then
                self.travail.regions[#self.travail.regions + 1] = { id = zone.id, nom = zone.name or "" }
            end
        end
        self:Afficher()
    end

    function f:RepereDuPoint(id)
        for i, r in ipairs(self.travail.reperes) do if r.point == id then return i end end
        return nil
    end
    -- Le repere d'un point pose se place a SES coordonnees (X, Y, Z), avec son
    -- emplacement recopie en clair.
    function f:BasculerPoint(e, coche)
        local rang = self:RepereDuPoint(e.id)
        if coche and not rang then
            if not e.x then self.erreur:SetText(tostring(e.refus)) self:Afficher() return end
            local reperes = self.travail.reperes
            if #reperes >= LCM.Cartes.MAX_REPERES then
                self.erreur:SetText(LCM.Cartes.MAX_REPERES .. " repères au plus sur une carte.")
                self:Afficher()
                return
            end
            local ou = e.ou or {}
            reperes[#reperes + 1] = { genre = e.genre, label = e.label, x = e.x, y = e.y, z = e.z,
                carte = e.carte, point = e.id, region = ou.region, regionNom = ou.regionNom,
                lieu = ou.lieu, lieuNom = ou.lieuNom, paysNom = ou.paysNom }
        elseif not coche and rang then
            table.remove(self.travail.reperes, rang)
        end
        self.erreur:SetText("")
        self:Afficher()
    end

    function f:OuvrirChoix()
        local d = Ecran.Choix()
        d.editeur = self
        d:Show()
        d:Afficher()
        UI.Devant(d)
    end

    function f:Afficher()
        local carte = self.travail
        self.nom:SetText(carte.label or "")
        self.description:SetText(carte.description or "")
        self.icone.label:SetText(carte.icone and "Icône choisie" or "Choisir")
        local reprise = carte.reprend and LCM.Cartes.Get(carte.reprend)
        self.reprend:Definir(carte.reprend or AUCUNE, reprise and reprise.label or nil)
        self.reprendAide:SetText(carte.reprend
            and "Cette carte montre exactement ce que montre l'autre : rien à saisir ici." or "")
        self.propre:SetShown(carte.reprend == nil)
        if Ecran.choix and Ecran.choix:IsShown() and Ecran.choix.editeur == self then Ecran.choix:Afficher() end
        if carte.reprend then return end

        -- L'arbre : chaque region, puis ses lieux, en retrait.
        local zg = ZG()
        local rangees = {}
        for _, zone in ipairs(zg and zg:GetZoneList() or {}) do
            rangees[#rangees + 1] = { zone = zone }
            for _, place in ipairs(zg:GetPlaceList(zone.id)) do
                rangees[#rangees + 1] = { zone = zone, place = place }
            end
        end
        for i, rangee in ipairs(rangees) do
            local noeud = self.noeuds[i]
            if not noeud then
                noeud = UI.Case(self.arbre.contenu, "", function(coche)
                    local n = f.noeuds[i]
                    if n.place then f:Basculer(n.place, n.zone, coche) else f:BasculerRegion(n.zone, coche) end
                end)
                self.noeuds[i] = noeud
            end
            noeud.zone, noeud.place = rangee.zone, rangee.place
            noeud:ClearAllPoints()
            noeud:SetPoint("TOPLEFT", self.arbre.contenu, "TOPLEFT", rangee.place and 26 or 4, -4 - (i - 1) * LIGNE)
            if rangee.place then
                noeud.label:SetText(rangee.place.name ~= "" and rangee.place.name or rangee.place.id)
                noeud.label:SetTextColor(UI.C.texte[1], UI.C.texte[2], UI.C.texte[3])
                noeud:Cocher(self:LieuDevoile(rangee.place.id))
            else
                local pays = rangee.zone.countryId and zg:GetCountry(rangee.zone.countryId)
                noeud.label:SetText((rangee.zone.name ~= "" and rangee.zone.name or rangee.zone.id)
                    .. (pays and ("  |cff9d9d9d(" .. (pays.name or "") .. ")|r") or ""))
                noeud.label:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
                noeud:Cocher(self:RegionDevoilee(rangee.zone.id))
            end
            noeud:Show()
        end
        for i = #rangees + 1, #self.noeuds do self.noeuds[i]:Hide() end
        self.aucuneRegion:SetShown(#rangees == 0)
        self.arbre:Regler(8 + #rangees * LIGNE)

        -- Les reperes choisis, avec leur emplacement.
        local reperes = carte.reperes
        for i, r in ipairs(reperes) do
            local ligne = self.lignes[i]
            if not ligne then
                ligne = CreateFrame("Frame", nil, self.reperes.contenu)
                ligne:SetSize(410, LIGNE * 2 - 4)
                ligne.texte = UI.Texte(ligne, "", UI.C.texte, "GameFontNormalSmall")
                ligne.texte:SetPoint("TOPLEFT", ligne, "TOPLEFT", 4, -2)
                ligne.texte:SetPoint("RIGHT", ligne, "RIGHT", -34, 0)
                ligne.texte:SetWordWrap(false)
                ligne.ou = UI.Texte(ligne, "", UI.C.discret, "GameFontNormalSmall")
                ligne.ou:SetPoint("TOPLEFT", ligne.texte, "BOTTOMLEFT", 0, -3)
                ligne.ou:SetPoint("RIGHT", ligne, "RIGHT", -34, 0)
                ligne.ou:SetWordWrap(false)
                ligne.retirer = UI.Bouton(ligne, "×", 26, 20, function(b)
                    table.remove(f.travail.reperes, b.rang)
                    f:Afficher()
                end)
                ligne.retirer:SetPoint("RIGHT", ligne, "RIGHT", 0, 0)
                self.lignes[i] = ligne
            end
            local g = LCM.Cartes.Genre(r.genre)
            ligne.retirer.rang = i
            ligne.texte:SetText(string.format("%s  ·  %s%s", g and g.label or r.genre,
                r.label ~= "" and r.label or "(sans légende)", r.point and "" or "  |cff9d9d9d(épingle)|r"))
            ligne.ou:SetText(LCM.Cartes.Emplacement(r) .. string.format("   |cff9d9d9d%.0f, %.0f%s|r",
                r.x, r.y, r.z and string.format(", %.0f", r.z) or ""))
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", self.reperes.contenu, "TOPLEFT", 0, -2 - (i - 1) * LIGNE * 2)
            ligne:Show()
        end
        for i = #reperes + 1, #self.lignes do self.lignes[i]:Hide() end
        self.aucunRepere:SetShown(#reperes == 0)
        self.reperes:Regler(4 + #reperes * LIGNE * 2)
    end

    function f:Enregistrer()
        local carte = self.travail
        if not Texte(carte.label):match("%S") then self.erreur:SetText("Donne un nom à la carte.") return false end
        local ok, raison = pcall(LCM.Cartes.Construire, carte)
        if not ok then self.erreur:SetText((tostring(raison):gsub("^LCM/Cartes : ", ""))) return false end
        if carte.reprend then
            local _, boucle = LCM.Cartes.Contenu({ id = carte.id, reprend = carte.reprend })
            if boucle then self.erreur:SetText(boucle) return false end
        end
        local ajoute, erreur = LCM.Brouillons.Enregistrer("cartes", carte, self.nouveau)
        if not ajoute then self.erreur:SetText(tostring(erreur)) return false end
        self.erreur:SetText("")
        if UI.Compendium and UI.Compendium.Actualiser then UI.Compendium.Actualiser() end
        if Ecran.choix then Ecran.choix:Hide() end
        self:Hide()
        return true
    end

    function f:Editer(element)
        self.nouveau = element == nil
        self.travail = element and LCM.Copie(element) or {
            id = LCM.Brouillons.NouvelIdentifiant(), label = "", icone = "INV_Misc_Map_01",
            regions = {}, lieux = {}, reperes = {},
        }
        -- Une ancienne carte n'avait qu'une `region` : elle devient la liste.
        if not self.travail.regions then
            self.travail.regions = self.travail.region
                and { { id = self.travail.region, nom = self.travail.regionNom or "" } } or {}
        end
        self.travail.region, self.travail.regionNom = nil, nil
        self.travail.lieux = self.travail.lieux or {}
        self.travail.reperes = self.travail.reperes or {}
        self.erreur:SetText("")
        self:Afficher()
        self:Show()
        UI.Devant(self)
    end
    f:HookScript("OnHide", function() if Ecran.choix then Ecran.choix:Hide() end end)
    f:Hide()
    return f
end

function Ecran.Editer(element)
    Ecran.frame = Ecran.frame or Construire()
    Ecran.frame:Editer(element)
    return true
end

-- L'entree Cartes du radial (Systeme > Interactions) a ete retiree le
-- 3 novembre 2026 (le MJ). Une carte se CREE au compendium (Système ›
-- Compendium › Cartes) et se pose comme toute trouvaille, dans l'atelier
-- Ressources, qui accepte les cartes. Le mode « cartes » de cet atelier
-- reste (UI.Recoltes.Basculer("cartes")) : plus rien du radial n'y mene.
