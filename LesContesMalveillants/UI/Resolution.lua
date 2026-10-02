-- Les fenetres d'une action qui part et qui arrive.
--
--   le choix des cibles     (Necronicon : OpenActionTargetPicker, 400 de large)
--   « Vous etes la cible »  (ShowActionResolutionPrompt, 400)
--   un choix ou un message  (ShowActionResolutionChoice, 404 avec le PA, 340 sans)
--   la repartition          (OpenActionApplyWindow, 520 x 424)
--   repartir un soin        (OpenActionDistributeWindow, 360)
--
-- Mesures et textes repris de Necronicon ; la logique est dans
-- Core/Actions.lua, ces fenetres ne font que montrer et transmettre le clic.
--
-- Ecart voulu : la fenetre de repartition n'a pas la zone d'emote de reponse
-- de Necronicon. On repond en emote dans le chat, comme d'habitude.

local _, LCM = ...
local UI = LCM.UI
local A = LCM.Actions

local Ecran = {}
UI.Resolution = Ecran

local DORE = { 0.93, 0.80, 0.52 }

local function Placer(region, point, parent, relPoint, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, parent, relPoint, x, y)
end

local function Fenetre(nom, largeur, hauteur)
    local f = CreateFrame("Frame", nom, UIParent)
    f:SetSize(largeur, hauteur)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f.fond = UI.Aplat(f, { 0.04, 0.04, 0.04, 0.97 })
    f.fond:SetAllPoints(f)
    if UI.AelCadre then f.cadre = UI.AelCadre(f, "section") else UI.Bordure(f) end
    f:Hide()
    return f
end

-- Un carre « coût / dispo » (PA, PF) : etiquette dessus, valeur dedans.
local function Carre(parent, libelle, couleur)
    local onglet = CreateFrame("Frame", nil, parent)
    onglet:SetSize(64, 18)
    onglet.fond = UI.Aplat(onglet, { 0.055, 0.055, 0.06, 0.95 })
    onglet.fond:SetAllPoints(onglet)
    UI.BordureFine(onglet, 0.38)
    onglet.texte = UI.Texte(onglet, libelle, DORE, "GameFontNormalSmall")
    Placer(onglet.texte, "CENTER", onglet, "CENTER", 0, 0)
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(64, 50)
    Placer(c, "TOPLEFT", onglet, "BOTTOMLEFT", 0, -3)
    c.fond = UI.Aplat(c, { couleur[1], couleur[2], couleur[3], 0.6 })
    c.fond:SetAllPoints(c)
    UI.BordureFine(c, 0.38)
    c.valeur = UI.Texte(c, "", { 1, 0.85, 0.25 }, "GameFontNormalLarge")
    Placer(c.valeur, "CENTER", c, "CENTER", 0, 6)
    c.sous = UI.Texte(c, "coût / dispo", { 1, 0.82, 0.2 }, "GameFontNormalSmall")
    Placer(c.sous, "BOTTOM", c, "BOTTOM", 0, 4)
    c.onglet, c.couleur = onglet, couleur
    function c:Peindre(cout, dispo)
        local function r(v) return v ~= nil and tostring(math.floor(v + 0.5)) or "?" end
        self.valeur:SetText(r(cout) .. " / " .. r(dispo))
        local trop = dispo ~= nil and cout > dispo + 0.005
        local k = trop and { 0.75, 0.2, 0.2, 0.7 } or { self.couleur[1], self.couleur[2], self.couleur[3], 0.6 }
        self.fond:SetColorTexture(k[1], k[2], k[3], k[4])
        return trop
    end
    return c
end

-- ===== Le choix des cibles =================================================

-- Une boite de cibles (« Joueurs : », « PNJ : ») : une ligne cochable par cible.
local function Boite(parent, titre)
    local b = CreateFrame("Frame", nil, parent)
    b.fond = UI.Aplat(b, { 1, 1, 1, 0.03 })
    b.fond:SetAllPoints(b)
    UI.BordureFine(b, 0.3)
    b.titre = UI.Texte(b, titre, DORE, "GameFontNormalSmall")
    Placer(b.titre, "TOPLEFT", b, "TOPLEFT", 8, -6)
    b.zone = UI.Defilement(b)
    b.zone:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -24)
    b.zone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -14, 6)
    b.lignes = {}
    return b
end

-- Le libelle d'une cible. Un joueur dont on n'a pas vu l'addon est marque,
-- pas bloque (Core/Presence.lua) : le message pourrait ne jamais
-- arriver, mais on ne refuse pas une cible sur un indice.
local function Libelle(cible)
    if cible.soi then return cible.nom .. "  |cff88cc88(vous)|r" end
    if cible.pnj or LCM.Presence.Confirmee(cible.id) then return cible.nom end
    return cible.nom .. "  |cff888888(addon non confirmé)|r"
end

local function Etiqueter(b)
    for i = 1, b.nombre or 0 do b.lignes[i].label:SetText(Libelle(b.lignes[i].cible)) end
end

-- `garder` : les cibles deja cochees le restent (une liste qui se met a jour
-- pendant qu'on choisit ne doit pas defaire le choix).
local function Remplir(b, cibles, onChange, garder)
    local cochees = {}
    if garder then
        for i = 1, b.nombre or 0 do
            if b.lignes[i]:EstCochee() then cochees[b.lignes[i].cible.id] = true end
        end
    end
    local y = 0
    for i, cible in ipairs(cibles) do
        local l = b.lignes[i]
        if not l then
            l = UI.Case(b.zone.contenu, "", function() if b.onChange then b.onChange(b.lignes[i]) end end)
            b.lignes[i] = l
        end
        l.cible = cible
        l.label:SetText(Libelle(cible))
        l:Cocher(cochees[cible.id] == true)
        Placer(l, "TOPLEFT", b.zone.contenu, "TOPLEFT", 2, -y)
        l:Show()
        y = y + 24
    end
    for i = #cibles + 1, #b.lignes do b.lignes[i]:Hide() end
    b.nombre = #cibles
    b.onChange = onChange
    b.zone:Regler(y)
end

local function Cochees(b)
    local out = {}
    for i = 1, b.nombre or 0 do
        local l = b.lignes[i]
        if l:EstCochee() then out[#out + 1] = l.cible end
    end
    return out
end

local function ConstruireCibles()
    local f = Fenetre("LCM_Cibles", 400, 342)
    f.titre = UI.Texte(f, "Déclarer une action", DORE, "GameFontNormalLarge")
    f.titre:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    f.titre:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -14)
    f.sous = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    f.sous:SetPoint("TOPLEFT", f.titre, "BOTTOMLEFT", 0, -3)
    f.cibles = UI.Texte(f, "CIBLES :", DORE, "GameFontNormalSmall")
    Placer(f.cibles, "TOPLEFT", f, "TOPLEFT", 18, -52)
    f.mode = UI.Texte(f, "", UI.C.discret, "GameFontNormalSmall")
    Placer(f.mode, "LEFT", f.cibles, "RIGHT", 12, 0)

    f.pa = Carre(f, "PA", { 0.45, 0.72, 0.55 })
    Placer(f.pa.onglet, "TOPLEFT", f, "TOPRIGHT", 6, -14)
    f.pf = Carre(f, "PF", { 0.55, 0.76, 0.92 })
    Placer(f.pf.onglet, "TOPLEFT", f, "TOPRIGHT", 6, -86)
    f.detail = UI.Texte(f, "", UI.C.discret, "GameFontNormalSmall")
    f.detail:SetPoint("TOPLEFT", f.pf, "BOTTOMLEFT", 0, -4)
    f.detail:SetWidth(64)
    f.detail:SetJustifyH("CENTER")
    f.detail:SetWordWrap(true)

    f.joueurs = Boite(f, "Joueurs :")
    f.pnj = Boite(f, "PNJ :")

    f.declarer = UI.Bouton(f, "Déclarer son action.", 180, 26, function() Ecran.Confirmer(true) end)
    Placer(f.declarer, "BOTTOMLEFT", f, "BOTTOM", 6, 12)
    f.annuler = UI.Bouton(f, "Annuler", 110, 26, function() Ecran.Confirmer(false) end)
    Placer(f.annuler, "BOTTOMRIGHT", f, "BOTTOM", -6, 12)
    f:SetScript("OnHide", function() Ecran.Confirmer(false) end)
    Ecran.cibles = f
    return f
end

local function CoutCibles(f)
    local ctx = f.ctx
    local n = #Cochees(f.joueurs) + #Cochees(f.pnj)
    local epa, epf = A.Supplement(ctx, n, f.mono)
    local pa = (tonumber(ctx.vars._coutPA) or 0) + epa
    local pf = (tonumber(ctx.vars._coutPF) or 0) + epf
    local dpa, dpf = A.Disponible(ctx.entity)
    local trop = f.pa:Peindre(pa, dpa)
    trop = f.pf:Peindre(pf, dpf) or trop
    local lignes = {}
    if trop then lignes[#lignes + 1] = "|cffff6060PA / PF insuffisants|r" end
    if epa > 0 or epf > 0 then lignes[#lignes + 1] = string.format("+%d PA / +%d PF pour les cibles", epa, epf) end
    f.detail:SetText(table.concat(lignes, "\n"))
    f.declarer:SetEnabled(not trop and n > 0)
    f.declarer:SetAlpha((not trop and n > 0) and 1 or 0.4)
    f.trop = trop
end

function Ecran.Cibler(ctx, mono, rappel)
    local f = Ecran.cibles or ConstruireCibles()
    if f:IsShown() then f:Hide() end
    f.ctx, f.mono, f.rappel = ctx, mono, rappel
    f.sous:SetText(ctx.declaration.nature)
    f.mode:SetText(mono and "monocible" or "multicible")
    local joueurs, pnj = A.Cibles()
    for _, p in ipairs(pnj) do p.pnj = true end
    -- Des membres pas encore vus : on repingue, la liste se met a jour a
    -- l'arrivee des reponses.
    local ids = {}
    for _, j in ipairs(joueurs) do if not j.soi then ids[#ids + 1] = j.id end end
    if #LCM.Presence.Inconnus(ids) > 0 then LCM.Presence.Demander(true) end
    -- La scene du MJ : redemandee a chaque ouverture, elle arrive en quelques
    -- instants et la liste des PNJ se met a jour.
    LCM.Scene.Demander()
    -- Monocible : cocher une ligne decoche les autres.
    local function Change(ligne)
        if mono and ligne and ligne:EstCochee() then
            for _, b in ipairs({ f.joueurs, f.pnj }) do
                for i = 1, b.nombre or 0 do
                    if b.lignes[i] ~= ligne then b.lignes[i]:Cocher(false) end
                end
            end
        end
        CoutCibles(f)
    end
    Remplir(f.joueurs, joueurs, Change)
    Remplir(f.pnj, pnj, Change)
    f.change = Change
    Ecran.Disposer(f, #pnj)
    CoutCibles(f)
    f:Show()
    f:Raise()
    return f
end

-- Avec ou sans PNJ, la fenetre n'a pas la meme hauteur (Necronicon : 472 / 342).
function Ecran.Disposer(f, nombrePNJ)
    f.joueurs:ClearAllPoints()
    f.joueurs:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -74)
    f.joueurs:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    if nombrePNJ > 0 then
        f:SetHeight(472)
        f.joueurs:SetHeight(196)
        f.pnj:ClearAllPoints()
        f.pnj:SetPoint("TOPLEFT", f.joueurs, "BOTTOMLEFT", 0, -10)
        f.pnj:SetPoint("RIGHT", f, "RIGHT", -16, 0)
        f.pnj:SetHeight(138)
        f.pnj:Show()
    else
        f:SetHeight(342)
        f.joueurs:SetHeight(228)
        f.pnj:Hide()
    end
end

function Ecran.Confirmer(oui)
    local f = Ecran.cibles
    local rappel = f and f.rappel
    if not rappel then return end
    if oui and (f.trop or (#Cochees(f.joueurs) + #Cochees(f.pnj)) == 0) then return end
    f.rappel = nil
    local joueurs, pnj, soi = {}, {}, false
    if oui then
        for _, c in ipairs(Cochees(f.joueurs)) do
            if c.soi then soi = true else joueurs[#joueurs + 1] = c.id end
        end
        pnj = Cochees(f.pnj)
    end
    f:Hide()
    if oui then rappel(joueurs, pnj, soi) else rappel(nil) end
end

-- La scene arrive (ou change) pendant qu'on choisit : la liste des PNJ suit.
LCM.Scene.onChange = function()
    local f = Ecran.cibles
    if not (f and f:IsShown()) then return end
    local _, pnj = A.Cibles()
    for _, p in ipairs(pnj) do p.pnj = true end
    Remplir(f.pnj, pnj, f.change, true)
    Ecran.Disposer(f, #pnj)
    CoutCibles(f)
end

LCM.Presence.onChange = function()
    local f = Ecran.cibles
    if f and f:IsShown() then Etiqueter(f.joueurs) end
end

-- ===== « Vous etes la cible de : » =========================================

local function ConstruireRecu()
    local f = Fenetre("LCM_ActionRecue", 400, 200)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f.titre = UI.Texte(f, "Vous êtes la cible de :", DORE, "GameFontNormalLarge")
    f.titre:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    f.titre:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -14)
    f.sous = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    f.sous:SetPoint("TOPLEFT", f.titre, "BOTTOMLEFT", 0, -4)
    f.sous:SetPoint("TOPRIGHT", f.titre, "BOTTOMRIGHT", 0, -4)
    f.resume = UI.Texte(f, "", UI.C.discret, "GameFontNormalSmall")
    f.resume:SetPoint("TOPLEFT", f.sous, "BOTTOMLEFT", 0, -10)
    f.resume:SetPoint("TOPRIGHT", f.sous, "BOTTOMRIGHT", 0, -10)
    f.resume:SetWordWrap(true)
    f.resoudre = UI.Bouton(f, "Résoudre", 368, 26, function()
        local recu = f.recu
        f.recu = nil
        f:Hide()
        if recu then A.Resoudre(recu) end
    end)
    f.ignorer = UI.Bouton(f, "Ignorer", 368, 22, function() Ecran.Ignorer() end)
    Ecran.recu = f
    return f
end

-- On ne montre qu'une action a la fois : les suivantes attendent leur tour
-- dans A.recus, et passent quand la premiere est resolue ou ignoree.
function Ecran.Montrer(recu)
    local f = Ecran.recu or ConstruireRecu()
    if f:IsShown() and f.recu and f.recu ~= recu then return f end
    f.recu = recu
    local p = recu.paquet
    local par = (p.rp and p.rp ~= "" and p.rp ~= p.a) and string.format("Déclaré par %s (%s)", p.rp, p.a)
        or string.format("Déclaré par %s", tostring(p.a))
    local cible = p.p and string.format("   |cffffa030[PNJ : %s]|r", tostring(p.pn or p.p)) or ""
    f.sous:SetText(string.format("|cffffd200%s|r   |cff808080%s|r%s", tostring(p.n), par, cible))
    local y = 14 + 22 + 18 + 10
    local zone = recu.paquet.valeurs and recu.paquet.valeurs.Zone
    if recu.resolution then
        f.resume:SetText(zone and ("Zone : " .. zone) or "")
        local h = zone and 16 or 0
        y = y + h + 14
        Placer(f.resoudre, "TOPLEFT", f, "TOPLEFT", 16, -y)
        f.resoudre:Show()
        y = y + 32
        -- Une zone : on peut dire qu'on n'y est pas (« Ignorer », renomme).
        f.ignorer.label:SetText(zone and "Je ne suis pas dans la zone AoE." or "Ignorer")
        f.ignorer:SetShown(zone ~= nil)
    else
        f.resume:SetText("|cffff8080Aucune résolution configurée pour cette nature.|r")
        y = y + 16 + 14
        f.resoudre:Hide()
        f.ignorer.label:SetText("Ignorer")
        f.ignorer:Show()
    end
    if f.ignorer:IsShown() then
        Placer(f.ignorer, "TOPLEFT", f, "TOPLEFT", 16, -y)
        y = y + 28
    end
    f:SetHeight(math.max(120, y + 14))
    f:Show()
    f:Raise()
    return f
end

function Ecran.Ignorer()
    local f = Ecran.recu
    local recu = f and f.recu
    if recu then
        for i, r in ipairs(A.recus) do if r == recu then table.remove(A.recus, i) break end end
    end
    f.recu = nil
    f:Hide()
    if A.recus[1] then Ecran.Montrer(A.recus[1]) end
end

-- ===== Un choix, ou un message =============================================

local function ConstruireChoix()
    local f = Fenetre("LCM_ActionChoix", 404, 120)
    f.titre = UI.Texte(f, "", DORE)
    f.contexte = UI.Texte(f, "", { 0.82, 0.82, 0.72 }, "GameFontNormalSmall")
    f.contexte:SetWordWrap(true)
    f.panneauPA = CreateFrame("Frame", nil, f)
    f.panneauPA:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.panneauPA:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
    f.panneauPA:SetWidth(60)
    f.panneauPA.fond = UI.Aplat(f.panneauPA, { 0.11, 0.10, 0.07, 0.96 })
    f.panneauPA.fond:SetAllPoints(f.panneauPA)
    f.panneauPA.trait = UI.Aplat(f.panneauPA, { 0.42, 0.36, 0.20, 0.85 }, "ARTWORK")
    f.panneauPA.trait:SetWidth(1)
    f.panneauPA.trait:SetPoint("TOPRIGHT", f.panneauPA, "TOPRIGHT", 0, 0)
    f.panneauPA.trait:SetPoint("BOTTOMRIGHT", f.panneauPA, "BOTTOMRIGHT", 0, 0)
    f.panneauPA.libelle = UI.Texte(f.panneauPA, "PA", { 0.72, 0.72, 0.72 }, "GameFontNormalSmall")
    Placer(f.panneauPA.libelle, "TOP", f.panneauPA, "TOP", 0, -12)
    f.panneauPA.valeur = UI.Texte(f.panneauPA, "", UI.C.titre, "GameFontNormalLarge")
    Placer(f.panneauPA.valeur, "CENTER", f.panneauPA, "CENTER", 0, -2)
    f.apercus, f.boutons = {}, {}
    Ecran.choix = f
    return f
end

-- boutons = { { texte, cout, aide, grise, choisir } }
-- options = { contexte, apercu = { { titre, valeur | texte, couleur } }, pa, grand }
function Ecran.Choix(titre, ctx, boutons, options)
    options = options or {}
    local f = Ecran.choix or ConstruireChoix()
    local avecPA = options.pa ~= nil
    local largeur, marge = avecPA and 404 or 340, avecPA and 74 or 14
    f:SetWidth(largeur)
    f.panneauPA:SetShown(avecPA)
    if avecPA then f.panneauPA.valeur:SetText(tostring(math.floor(options.pa + 0.5))) end

    f.titre:ClearAllPoints()
    f.titre:SetPoint("TOPLEFT", f, "TOPLEFT", marge, -14)
    f.titre:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -14)
    f.titre:SetText(titre)
    local contexte = tostring(options.contexte or "")
    f.contexte:ClearAllPoints()
    f.contexte:SetPoint("TOPLEFT", f, "TOPLEFT", marge, -34)
    f.contexte:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -34)
    f.contexte:SetText(contexte)
    UI.Police(f.contexte, options.grand and 14 or 11)
    f.contexte:SetShown(contexte ~= "")
    local hContexte = 0
    if contexte ~= "" then
        local lignes = 1
        for _ in contexte:gmatch("\n") do lignes = lignes + 1 end
        hContexte = math.max(lignes * (options.grand and 19 or 15) + 22, (f.contexte:GetStringHeight() or 0) + 10)
    end

    for _, a in ipairs(f.apercus) do a:Hide() end
    local apercu = options.apercu or {}
    local hApercu = 0
    if #apercu > 0 then
        local interieur = largeur - marge - 14
        local chacun = (interieur - 8 * (#apercu - 1)) / #apercu
        for i, info in ipairs(apercu) do
            local a = f.apercus[i]
            if not a then
                a = CreateFrame("Frame", nil, f)
                a.fond = UI.Aplat(a, { 1, 1, 1, 0.05 })
                a.fond:SetAllPoints(a)
                UI.BordureFine(a, 0.3)
                a.titre = UI.Texte(a, "", UI.C.discret, "GameFontNormalSmall")
                Placer(a.titre, "TOP", a, "TOP", 0, -5)
                a.valeur = UI.Texte(a, "", UI.C.titre, "GameFontNormalLarge")
                Placer(a.valeur, "BOTTOM", a, "BOTTOM", 0, 5)
                f.apercus[i] = a
            end
            a:SetSize(chacun, 44)
            Placer(a, "TOPLEFT", f, "TOPLEFT", marge + (i - 1) * (chacun + 8), -34 - hContexte)
            a.titre:SetText(info.titre)
            a.valeur:SetText(info.texte or (info.valeur ~= nil and tostring(info.valeur)) or "?")
            local k = info.couleur or { 1, 0.82, 0.35 }
            a.valeur:SetTextColor(k[1], k[2], k[3])
            a:Show()
        end
        hApercu = 52
    end

    for _, b in ipairs(f.boutons) do b:Hide() end
    local y = -40 - hContexte - hApercu
    for i, spec in ipairs(boutons) do
        local b = f.boutons[i]
        if not b then
            b = UI.Bouton(f, "", 100, 24, function(self)
                local s = self.spec
                if not s or s.grise then return end
                f:Hide()
                if s.choisir then s.choisir() end
            end)
            b:SetScript("OnEnter", function(self)
                if self.spec and self.spec.aide and self.spec.aide ~= "" then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.spec.aide, 0.88, 0.84, 0.76, 1, true)
                    GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.boutons[i] = b
        end
        b.spec = spec
        b:SetSize(largeur - marge - 14, 24)
        Placer(b, "TOPLEFT", f, "TOPLEFT", marge, y)
        local texte = spec.texte .. (spec.cout and ("  " .. spec.cout) or "")
        if spec.grise and spec.cout then texte = texte:gsub("(%d+%s*P[AF])", "|cffff3030%1|r") end
        b.label:SetText(texte)
        b:SetEnabled(not spec.grise)
        b:SetAlpha(spec.grise and 0.5 or 1)
        b:Show()
        y = y - 28
    end
    f:SetHeight(math.max(70, -y + 10))
    f:Show()
    f:Raise()
    return f
end

-- Un message : la premiere ligne en titre, le reste en corps, et « OK ».
function Ecran.Message(texte, ctx, suite)
    local titre, corps = texte:match("^(.-)\n(.+)$")
    return Ecran.Choix(titre or texte, ctx, { { texte = "OK", choisir = suite } },
        { contexte = corps, grand = true })
end

-- ===== La repartition ======================================================

local function ConstruireRepartition()
    local f = Fenetre("LCM_Repartition", 520, 424)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f.titre = UI.Texte(f, "", DORE)
    Placer(f.titre, "TOPLEFT", f, "TOPLEFT", 14, -14)

    f.aide = CreateFrame("Frame", nil, f)
    f.aide:SetPoint("TOPLEFT", f.titre, "BOTTOMLEFT", 0, -8)
    f.aide:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, 0)
    f.aide:SetHeight(46)
    f.aide.fond = UI.Aplat(f.aide, { 1, 0.86, 0.35, 0.05 })
    f.aide.fond:SetAllPoints(f.aide)
    UI.BordureFine(f.aide, 0.3)
    f.aide.texte = UI.Texte(f.aide, "", UI.C.texte, "GameFontNormalSmall")
    f.aide.texte:SetPoint("TOPLEFT", f.aide, "TOPLEFT", 10, -8)
    f.aide.texte:SetPoint("BOTTOMRIGHT", f.aide, "BOTTOMRIGHT", -10, 8)
    f.aide.texte:SetWordWrap(true)

    local function Compteur(titre)
        local c = CreateFrame("Frame", nil, f)
        c:SetHeight(40)
        c.fond = UI.Aplat(c, { 1, 1, 1, 0.04 })
        c.fond:SetAllPoints(c)
        UI.BordureFine(c, 0.3)
        c.titre = UI.Texte(c, titre, UI.C.discret, "GameFontNormalSmall")
        Placer(c.titre, "TOP", c, "TOP", 0, -4)
        c.valeur = UI.Texte(c, "0", UI.C.titre, "GameFontNormalLarge")
        Placer(c.valeur, "BOTTOM", c, "BOTTOM", 0, 4)
        return c
    end
    f.reste = Compteur("Reste à répartir")
    f.reste:SetWidth(160)
    Placer(f.reste, "TOPLEFT", f.aide, "BOTTOMLEFT", 0, -8)
    f.place = Compteur("Total réparti")
    f.place:SetWidth(160)
    Placer(f.place, "TOPLEFT", f.reste, "TOPRIGHT", 6, 0)
    f.perce = Compteur("Perce-armure (santé mini)")
    f.perce:SetPoint("TOPLEFT", f.place, "TOPRIGHT", 6, 0)
    f.perce:SetPoint("TOPRIGHT", f.aide, "BOTTOMRIGHT", 0, -8)

    f.zone = UI.Defilement(f)
    f.zone:SetPoint("TOPLEFT", f.reste, "BOTTOMLEFT", 0, -10)
    f.zone:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 48)
    f.lignes = {}

    f.appliquer = UI.Bouton(f, "Appliquer", 150, 24, function() Ecran.Appliquer(true) end)
    Placer(f.appliquer, "BOTTOM", f, "BOTTOM", 0, 12)
    f.ignorer = UI.Bouton(f, "Ignorer", 110, 24, function() Ecran.Appliquer(false) end)
    Placer(f.ignorer, "RIGHT", f.appliquer, "LEFT", -8, 0)
    Ecran.repartition = f
    return f
end

local function Etat(f)
    local place, sante, place_max = 0, 0, 0
    for i, case in ipairs(f.cases) do
        local n = f.valeurs[i] or 0
        place = place + n
        if case.sante then sante = sante + n end
        place_max = place_max + case.plafond
    end
    return place, sante, math.min(f.montant, place_max)
end

local function Rafraichir(f)
    local place, sante, possible = Etat(f)
    f.reste.valeur:SetText(tostring(f.montant - place))
    f.place.valeur:SetText(tostring(place))
    f.perce.valeur:SetText(string.format("%d / %d", math.min(sante, f.minimum), f.minimum))
    for i, case in ipairs(f.cases) do
        local l = f.lignes[i]
        local n = f.valeurs[i] or 0
        l.valeur:SetText(tostring(n))
        l.etat:SetText(string.format("%d / %d  ->  %d", case.courant, case.max, case.courant + (f.signe == "+" and n or -n)))
    end
    -- On a tout place (ou tout ce qui pouvait l'etre), et la sante a recu au
    -- moins le perce-armure (ou tout ce qu'elle pouvait encore recevoir).
    local santeMax = 0
    for _, case in ipairs(f.cases) do if case.sante then santeMax = santeMax + case.plafond end end
    local ok = place == possible and sante >= math.min(f.minimum, santeMax)
    f.appliquer:SetEnabled(ok)
    f.appliquer:SetAlpha(ok and 1 or 0.4)
    f.pret = ok
end

function Ecran.Repartir(ctx, fin)
    local f = Ecran.repartition or ConstruireRepartition()
    -- Necronicon ouvre une seule fenetre pour la somme des effets.
    local montant, tags, signe = 0, {}, "-"
    local vus = {}
    for _, e in ipairs(ctx.effets) do
        montant = montant + math.floor((tonumber(e.montant) or 0) + 0.5)
        signe = e.signe
        for _, t in ipairs(e.tags) do if not vus[t] then vus[t] = true tags[#tags + 1] = t end end
    end
    local cases, inconnus = A.Zones(ctx.entity, tags)
    f.ctx, f.fin, f.cases, f.montant, f.signe = ctx, fin, cases, montant, signe
    f.minimum = signe == "-" and A.PerceMinimum(ctx, montant) or 0
    f.valeurs = {}
    f.titre:SetText(string.format("%s : %d point%s à répartir", signe == "-" and "Dégâts" or "Gain", montant,
        montant > 1 and "s" or ""))
    local aide = "Répartissez sur vos zones."
    if f.minimum > 0 then aide = aide .. string.format(" Le perce-armure impose au moins %d en santé.", f.minimum) end
    if #inconnus > 0 then
        aide = aide .. "\n|cffff8080Sans jauge sur la fiche : " .. table.concat(inconnus, ", ") .. "|r"
    end
    f.aide.texte:SetText(aide)

    local y = 0
    for i, case in ipairs(cases) do
        local l = f.lignes[i]
        if not l then
            l = CreateFrame("Frame", nil, f.zone.contenu)
            l:SetHeight(26)
            if UI.SurfaceLigne then UI.SurfaceLigne(l) end
            l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
            Placer(l.nom, "LEFT", l, "LEFT", 8, 0)
            l.etat = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
            Placer(l.etat, "LEFT", l, "LEFT", 150, 0)
            l.plus = UI.Bouton(l, "+", 22, 20, function() Ecran.Ajuster(i, 1) end)
            Placer(l.plus, "RIGHT", l, "RIGHT", -4, 0)
            l.valeur = UI.Texte(l, "0", UI.C.titre, "GameFontNormal")
            l.valeur:SetWidth(34)
            l.valeur:SetJustifyH("CENTER")
            Placer(l.valeur, "RIGHT", l.plus, "LEFT", -2, 0)
            l.moins = UI.Bouton(l, "-", 22, 20, function() Ecran.Ajuster(i, -1) end)
            Placer(l.moins, "RIGHT", l.valeur, "LEFT", -2, 0)
            -- « Tout » : met ici tout ce qui reste, dans la limite de la zone.
            l.tout = UI.Bouton(l, "Tout", 44, 20, function() Ecran.Ajuster(i, math.huge) end)
            Placer(l.tout, "RIGHT", l.moins, "LEFT", -6, 0)
            f.lignes[i] = l
        end
        l.nom:SetText(case.sante and case.nom or (case.nom .. " |cff9fbfdf#bouclier|r"))
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", f.zone.contenu, "TOPLEFT", 0, -y)
        l:SetPoint("TOPRIGHT", f.zone.contenu, "TOPRIGHT", 0, -y)
        l:Show()
        y = y + 28
    end
    for i = #cases + 1, #f.lignes do f.lignes[i]:Hide() end
    f.zone:Regler(y)
    Rafraichir(f)
    f:Show()
    f:Raise()
    return f
end

function Ecran.Ajuster(i, pas)
    local f = Ecran.repartition
    local case = f.cases[i]
    local place = Etat(f)
    local n = f.valeurs[i] or 0
    local voulu = n + pas
    if pas == math.huge then voulu = n + (f.montant - place) end
    voulu = math.max(0, math.min(voulu, case.plafond, n + (f.montant - place)))
    f.valeurs[i] = voulu
    Rafraichir(f)
end

function Ecran.Appliquer(oui)
    local f = Ecran.repartition
    if oui and not f.pret then return end
    local fin = f.fin
    f.fin = nil
    f:Hide()
    if oui then
        A.Repartir(f.ctx, f.cases, f.valeurs, f.signe)
    else
        f.ctx.journal[#f.ctx.journal + 1] = "Réparti : ignoré"
    end
    if fin then fin() end
end

-- ===== Repartir un soin (chez celui qui le donne) ==========================
-- Necronicon : OpenActionDistributeWindow, 360 de large ; une ligne par zone,
-- « − valeur + M 0 », Maj pour aller de cinq en cinq.

local function ConstruireDistribution()
    local f = Fenetre("LCM_Distribution", 360, 240)
    f.titre = UI.Texte(f, "", DORE, "GameFontNormalLarge")
    f.titre:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    f.titre:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -14)
    f.note = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    f.note:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
    f.note:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -40)
    f.note:SetWordWrap(true)
    f.reste = UI.Texte(f, "", UI.C.texte)
    f.lignes = {}
    f.valider = UI.Bouton(f, "Valider", 150, 26, function() Ecran.Distribuer(true) end)
    Placer(f.valider, "BOTTOMLEFT", f, "BOTTOM", 6, 12)
    f.annuler = UI.Bouton(f, "Annuler", 110, 26, function() Ecran.Distribuer(false) end)
    Placer(f.annuler, "BOTTOMRIGHT", f, "BOTTOM", -6, 12)
    f:SetScript("OnHide", function() Ecran.Distribuer(false) end)
    Ecran.distribution = f
    return f
end

local function Depense(f)
    local t = 0
    for _, z in ipairs(f.zones) do t = t + (f.parts[z] or 0) end
    return t
end

local function RafraichirDistribution(f)
    local reste = f.montant - Depense(f)
    for i, z in ipairs(f.zones) do f.lignes[i].valeur:SetText(tostring(f.parts[z] or 0)) end
    f.reste:SetText(string.format("Total : %d  —  reste à répartir : |cff%s%d|r", f.montant,
        reste == 0 and "9be08f" or "ffd200", reste))
    f.valider:SetEnabled(reste == 0)
    f.valider:SetAlpha(reste == 0 and 1 or 0.4)
end

function Ecran.Repartition(titre, montant, zones, ctx, rappel, note)
    local f = Ecran.distribution or ConstruireDistribution()
    if f:IsShown() then f:Hide() end
    f.montant, f.zones, f.rappel, f.parts = montant, zones, rappel, {}
    f.titre:SetText(titre)
    f.note:SetText(note or "")
    local hNote = (note or "") ~= "" and math.max(14, math.ceil(f.note:GetStringHeight() or 14)) or 0
    f.reste:ClearAllPoints()
    f.reste:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40 - hNote - (hNote > 0 and 8 or 0))
    local haut = -64 - hNote - (hNote > 0 and 8 or 0)
    for i, z in ipairs(zones) do
        local l = f.lignes[i]
        if not l then
            l = CreateFrame("Frame", nil, f)
            l:SetHeight(24)
            l.nom = UI.Texte(l, "", UI.C.texte)
            l.nom:SetWidth(130)
            Placer(l.nom, "LEFT", l, "LEFT", 0, 0)
            local function Pas_(x, texte, action)
                local b = UI.Bouton(l, texte, 24, 20, function()
                    local zone = f.zones[i]
                    local pas = (IsShiftKeyDown and IsShiftKeyDown()) and 5 or 1
                    action(zone, pas)
                    RafraichirDistribution(f)
                end)
                Placer(b, "LEFT", l, "LEFT", x, 0)
                return b
            end
            l.moins = Pas_(140, "−", function(z_, pas) f.parts[z_] = math.max(0, (f.parts[z_] or 0) - pas) end)
            l.valeur = UI.Texte(l, "0", UI.C.titre)
            l.valeur:SetWidth(44)
            l.valeur:SetJustifyH("CENTER")
            Placer(l.valeur, "LEFT", l, "LEFT", 170, 0)
            l.plus = Pas_(218, "+", function(z_, pas)
                f.parts[z_] = (f.parts[z_] or 0) + math.min(pas, math.max(0, f.montant - Depense(f)))
            end)
            l.max = Pas_(246, "M", function(z_) f.parts[z_] = (f.parts[z_] or 0) + math.max(0, f.montant - Depense(f)) end)
            l.zero = Pas_(274, "0", function(z_) f.parts[z_] = 0 end)
            f.lignes[i] = l
        end
        l.nom:SetText(z)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", f, "TOPLEFT", 16, haut - (i - 1) * 26)
        l:SetPoint("RIGHT", f, "RIGHT", -16, 0)
        l:Show()
    end
    for i = #zones + 1, #f.lignes do f.lignes[i]:Hide() end
    f:SetHeight(-haut + #zones * 26 + 50)
    RafraichirDistribution(f)
    f:Show()
    f:Raise()
    return f
end

function Ecran.Distribuer(oui)
    local f = Ecran.distribution
    local rappel = f and f.rappel
    if not rappel then return end
    if oui and Depense(f) ~= f.montant then return end
    f.rappel = nil
    f:Hide()
    rappel(oui and f.parts or nil)
end

-- ===== Un effet recu : resister, subir, accepter ===========================
-- Necronicon : ShowBuffResistPrompt (440 de large, « Débuff — résistance ») et
-- ShowBuffAcceptPrompt pour un buff.

local function ConstruireEffet()
    local f = Fenetre("LCM_EffetRecu", 440, 240)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    f.titre = UI.Texte(f, "", DORE, "GameFontNormalLarge")
    f.titre:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    f.titre:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -14)
    f.sous = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    f.sous:SetPoint("TOPLEFT", f.titre, "BOTTOMLEFT", 0, -4)
    f.sous:SetPoint("TOPRIGHT", f.titre, "BOTTOMRIGHT", 0, -4)
    f.corps = UI.Texte(f, "", UI.C.discret, "GameFontNormalSmall")
    f.corps:SetPoint("TOPLEFT", f.sous, "BOTTOMLEFT", 0, -10)
    f.corps:SetPoint("TOPRIGHT", f.sous, "BOTTOMRIGHT", 0, -10)
    f.corps:SetJustifyV("TOP")
    f.corps:SetWordWrap(true)
    f.boutons = {}
    f.dernier = UI.Bouton(f, "Subir", 110, 24, function() Ecran.Effet(false) end)
    Placer(f.dernier, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    Ecran.effet = f
    return f
end

local function Trim(x) return (tostring(x or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function Plage(entity, competence, bonus)
    for _, id in ipairs({ "adresse", "esprit" }) do
        local field = LCM.Schema.Field(id)
        if field and A.Cle(field.label) == A.Cle(competence) then
            local fixe = (tonumber(LCM.Entities.Get_Value(entity, id)) or 0) + LCM.Formules.Apport(entity, id)
                + LCM.Effets.Bonus(entity, id)
            return string.format("  D%d + %d%s", field.dice.max or 0, fixe, bonus ~= 0 and string.format(" (+%d rés.)", bonus) or "")
        end
    end
    return ""
end

function Ecran.MontrerEffet(recu)
    local f = Ecran.effet or ConstruireEffet()
    if f:IsShown() and f.recu and f.recu ~= recu then return f end
    f.recu = recu
    local p = recu.paquet
    local de = (Trim and Trim(p.rp) or tostring(p.rp or "")) ~= "" and p.rp or p.a
    f.titre:SetText(recu.debuff and "Débuff — résistance" or "Buff reçu")
    f.sous:SetText(string.format("|cffff8888%s|r   |cff808080de %s|r%s", tostring(p.nom), tostring(de),
        p.p and string.format("   |cffffa030[PNJ : %s]|r", tostring(p.pn or p.p)) or ""))
    local lignes = {}
    local duree = tonumber(p.r) and (p.r .. " round" .. (tonumber(p.r) > 1 and "s" or "")) or "jusqu'à retrait"
    lignes[1] = (p.jr and string.format("Jet du lanceur : %d (%s)", p.jr, tostring(p.js)) or "Sans jet du lanceur")
        .. (p.nar and "" or ("   ·   Durée : " .. duree))
    if (p.desc or "") ~= "" then lignes[#lignes + 1] = "|cffcfc6ad" .. p.desc .. "|r" end
    if recu.bonusResistance ~= 0 then
        lignes[#lignes + 1] = string.format("|cff9be08fBonus de résistance : +%d|r", recu.bonusResistance)
    end
    if not p.nar then
        lignes[#lignes + 1] = " "
        lignes[#lignes + 1] = recu.debuff and "Malus :" or "Effets :"
        local cles = {}
        for k in pairs(type(p.d) == "table" and p.d or {}) do cles[#cles + 1] = k end
        table.sort(cles)
        if #cles == 0 then lignes[#lignes + 1] = "  (aucun)" end
        for _, k in ipairs(cles) do lignes[#lignes + 1] = string.format("  %s : %s", k, tostring(p.d[k])) end
    end
    f.corps:SetText(table.concat(lignes, "\n"))

    for _, b in ipairs(f.boutons) do b:Hide() end
    if recu.debuff then
        local x = 16
        for i, competence in ipairs(recu.competences) do
            local b = f.boutons[i]
            if not b then
                b = UI.Bouton(f, "", 190, 24, function(self) Ecran.Effet(true, self.competence) end)
                f.boutons[i] = b
            end
            b.competence = competence
            b.label:SetText("Résister : " .. competence .. Plage(recu.entity, competence, recu.bonusResistance))
            Placer(b, "BOTTOMLEFT", f, "BOTTOMLEFT", x, 14)
            b:Show()
            x = x + 198
        end
        f:SetWidth(math.max(440, 16 + #recu.competences * 198 + 130))
        f.dernier.label:SetText("Subir")
    else
        local b = f.boutons[1]
        if not b then
            b = UI.Bouton(f, "", 190, 24, function(self) Ecran.Effet(true, self.competence) end)
            f.boutons[1] = b
        end
        b.competence = nil
        b.label:SetText("Accepter")
        Placer(b, "BOTTOMLEFT", f, "BOTTOMLEFT", 16, 14)
        b:Show()
        f:SetWidth(440)
        f.dernier.label:SetText("Refuser")
    end
    f:SetHeight(math.max(160, 60 + (f.corps:GetStringHeight() or 60) + 60))
    f:Show()
    f:Raise()
    return f
end

-- `oui` : resister (debuff) ou accepter (buff) ; non : subir (debuff) ou
-- refuser (buff).
function Ecran.Effet(oui, competence)
    local f = Ecran.effet
    local recu = f and f.recu
    if not recu then return end
    f.recu = nil
    f:Hide()
    if recu.debuff then
        if oui then A.Resister(recu, competence) else A.Subir(recu) end
    else
        if oui then A.Subir(recu) else A.Refuser(recu) end
    end
end

-- ===== La dissipation ======================================================
-- Necronicon en faisait deux fenetres (les cibles et leurs etats, puis la
-- composition) ; ici une seule, en trois colonnes : cibles, etats, choix.

local function ConstruireDissipation()
    local f = Fenetre("LCM_Dissipation", 720, 440)
    f.titre = UI.Texte(f, "Dissipation", DORE, "GameFontNormalLarge")
    Placer(f.titre, "TOPLEFT", f, "TOPLEFT", 16, -14)
    local function Colonne(titre, x, largeur)
        local t = UI.Texte(f, titre, DORE, "GameFontNormalSmall")
        Placer(t, "TOPLEFT", f, "TOPLEFT", x, -44)
        local z = UI.Defilement(f)
        z:SetPoint("TOPLEFT", f, "TOPLEFT", x, -62)
        z:SetSize(largeur, 300)
        return t, z
    end
    f.tCibles, f.zCibles = Colonne("CIBLES", 16, 190)
    f.tEtats, f.zEtats = Colonne("ÉTATS", 222, 270)
    f.boutonsCibles, f.casesEtats = {}, {}
    f.tRand = UI.Texte(f, "RAND", DORE, "GameFontNormalSmall")
    Placer(f.tRand, "TOPLEFT", f, "TOPLEFT", 510, -44)
    f.tNiveau = UI.Texte(f, "NIVEAU DU SORT", DORE, "GameFontNormalSmall")
    Placer(f.tNiveau, "TOPLEFT", f, "TOPLEFT", 510, -104)
    f.competences, f.niveaux = {}, {}
    f.cout = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    Placer(f.cout, "TOPLEFT", f, "TOPLEFT", 510, -300)
    f.cout:SetWidth(194)
    f.cout:SetWordWrap(true)
    f.dissiper = UI.Bouton(f, "Dissiper", 150, 26, function() Ecran.Dissiper(true) end)
    Placer(f.dissiper, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    f.annuler = UI.Bouton(f, "Annuler", 110, 26, function() Ecran.Dissiper(false) end)
    Placer(f.annuler, "RIGHT", f.dissiper, "LEFT", -8, 0)
    f:SetScript("OnHide", function() Ecran.Dissiper(false) end)
    Ecran.dissipation = f
    return f
end

local function RendreDissipation()
    local f = Ecran.dissipation
    local ctx, cfg = f.ctx, f.cfg
    -- Cibles.
    for i, c in ipairs(f.cibles) do
        local b = f.boutonsCibles[i]
        if not b then
            b = UI.Bouton(f.zCibles.contenu, "", 186, 22, function(self)
                f.cible = self.cible
                A.EtatsDe(self.cible)
                RendreDissipation()
            end)
            f.boutonsCibles[i] = b
        end
        b.cible = c
        local n = 0
        for _, s in pairs(f.selection) do if s.cible.id == c.id then n = n + 1 end end
        b.label:SetText(c.nom .. (c.soi and " |cff88cc88(vous)|r" or "") .. (n > 0 and ("  |cffffd200" .. n .. "|r") or ""))
        b:Selectionner(f.cible and f.cible.id == c.id)
        Placer(b, "TOPLEFT", f.zCibles.contenu, "TOPLEFT", 0, -(i - 1) * 26)
        b:Show()
    end
    for i = #f.cibles + 1, #f.boutonsCibles do f.boutonsCibles[i]:Hide() end
    f.zCibles:Regler(#f.cibles * 26)
    -- Etats de la cible choisie.
    local etats = f.cible and (f.cible.soi or (f.cible.pnj and (f.cible.mj or LCM.PlayerId()) == LCM.PlayerId()))
        and A.EtatsDe(f.cible) or (f.cible and A.etatsConnus[f.cible.id]) or nil
    f.tEtats:SetText(f.cible and ("ÉTATS — " .. f.cible.nom) or "ÉTATS")
    local n = 0
    for _, e in ipairs(etats or {}) do
        n = n + 1
        local c = f.casesEtats[n]
        if not c then
            -- L'indice de CETTE ligne, pas le compteur `n` : il est partage par
            -- toutes les fermetures creees dans la boucle (CLAUDE.md, piege 1).
            local rang = n
            c = UI.Case(f.zEtats.contenu, "", function(coche)
                local cc = f.casesEtats[rang]
                local cle = cc.cible.id .. "|" .. cc.etat.id
                f.selection[cle] = coche and { cible = cc.cible, etat = cc.etat } or nil
                RendreDissipation()
            end)
            f.casesEtats[n] = c
        end
        c.cible, c.etat = f.cible, e
        local chance = f.choix.competence and A.ChanceDissipation(ctx.entity, f.choix.competence,
            A.Cle(f.choix.competence) ~= A.Cle(e.competence or f.choix.competence), f.choix.niveau or 0, cfg.mult, e.seuil)
        local couleur = not chance and "909090" or (chance >= 80 and "9be08f" or (chance >= 35 and "ffa030" or "ff5959"))
        c.label:SetText(string.format("%s |cff9a9a9a(%s)|r%s", tostring(e.nom),
            e.restant and (e.restant .. " r.") or "∞", chance and string.format("  |cff%s%d %%|r", couleur, chance) or ""))
        c:Cocher(f.selection[f.cible.id .. "|" .. e.id] ~= nil)
        Placer(c, "TOPLEFT", f.zEtats.contenu, "TOPLEFT", 2, -(n - 1) * 24)
        c:Show()
    end
    for i = n + 1, #f.casesEtats do f.casesEtats[i]:Hide() end
    f.zEtats:Regler(n * 24)
    if f.cible and not etats then
        f.tEtats:SetText("ÉTATS — " .. f.cible.nom .. "  |cff9a9a9a(demandés…)|r")
    end
    -- Competence et niveau.
    for i, comp in ipairs(cfg.competences) do
        local b = f.competences[i]
        if not b then
            b = UI.Bouton(f, "", 96, 26, function(self) f.choix.competence = self.valeur RendreDissipation() end)
            f.competences[i] = b
        end
        b.valeur = comp
        b.label:SetText(comp)
        b:Selectionner(f.choix.competence == comp)
        Placer(b, "TOPLEFT", f, "TOPLEFT", 510 + (i - 1) * 100, -62)
        b:Show()
    end
    for i, nv in ipairs(cfg.niveaux) do
        local b = f.niveaux[i]
        if not b then
            b = UI.Bouton(f, "", 62, 34, function(self) f.choix.niveau = self.valeur RendreDissipation() end)
            b.label:SetWordWrap(true)
            f.niveaux[i] = b
        end
        b.valeur = nv.niveau
        b.label:SetText(string.format("Niv. %d\n|cff909090%d PA · %d PF|r", nv.niveau, nv.pa, nv.pf))
        b:Selectionner(f.choix.niveau == nv.niveau)
        Placer(b, "TOPLEFT", f, "TOPLEFT", 510 + ((i - 1) % 3) * 66, -122 - math.floor((i - 1) / 3) * 38)
        b:Show()
    end
    -- Cout.
    local cibles, nEtats = {}, 0
    for _, s in pairs(f.selection) do cibles[s.cible.id] = true nEtats = nEtats + 1 end
    local nCibles = 0
    for _ in pairs(cibles) do nCibles = nCibles + 1 end
    local pa, pf = A.CoutDissipation(cfg, nCibles, nEtats, f.choix.niveau)
    local dpa, dpf = A.Disponible(ctx.entity)
    local trop = (dpa and pa > dpa) or (dpf and pf > dpf)
    f.cout:SetText(string.format("PA : %d / %d     PF : %d / %d\n|cff9a9a9a%d cible(s), %d état(s)|r%s", pa, dpa or 0,
        pf, dpf or 0, nCibles, nEtats, trop and "\n|cffff6060PA / PF insuffisants|r" or ""))
    local pret = nEtats > 0 and f.choix.competence and f.choix.niveau and not trop
    f.dissiper:SetEnabled(pret and true or false)
    f.dissiper:SetAlpha(pret and 1 or 0.4)
end

function Ecran.Dissipation(ctx, cfg, rappel)
    local f = Ecran.dissipation or ConstruireDissipation()
    if f:IsShown() then f:Hide() end
    f.ctx, f.cfg, f.rappel = ctx, cfg, rappel
    f.selection, f.choix, f.cible = {}, {}, nil
    local joueurs, pnj = A.Cibles()
    f.cibles = {}
    for _, j in ipairs(joueurs) do f.cibles[#f.cibles + 1] = j end
    for _, p in ipairs(pnj) do p.pnj = true f.cibles[#f.cibles + 1] = p end
    f.cible = f.cibles[1]
    RendreDissipation()
    f:Show()
    f:Raise()
    return f
end

function Ecran.Dissiper(oui)
    local f = Ecran.dissipation
    local rappel = f and f.rappel
    if not rappel then return end
    if oui and not f.dissiper:IsEnabled() then return end
    f.rappel = nil
    f:Hide()
    if not oui then return rappel(nil) end
    local selection = {}
    for _, s in pairs(f.selection) do selection[#selection + 1] = s end
    rappel(selection, { competence = f.choix.competence, niveau = f.choix.niveau })
end

-- ===== Branchements ========================================================

A.onCibler = function(ctx, mono, rappel) Ecran.Cibler(ctx, mono, rappel) end
A.onChoix = function(titre, ctx, boutons, options) Ecran.Choix(titre, ctx, boutons, options) end
A.onMessage = function(texte, ctx, suite) Ecran.Message(texte, ctx, suite) end
A.onAppliquer = function(ctx, fin) Ecran.Repartir(ctx, fin) end
A.onDistribuer = function(titre, montant, zones, ctx, rappel, note)
    Ecran.Repartition(titre, montant, zones, ctx, rappel, note)
end
A.onRecu = function(recu) Ecran.Montrer(recu) end
A.onEffetRecu = function(recu) Ecran.MontrerEffet(recu) end
A.onDissiper = function(ctx, cfg, rappel) Ecran.Dissipation(ctx, cfg, rappel) end
A.onEtats = function()
    if Ecran.dissipation and Ecran.dissipation:IsShown() then RendreDissipation() end
end

-- Une resolution finie (ou arretee) laisse la place a l'action recue suivante.
A.onResolu = function()
    if A.recus[1] then Ecran.Montrer(A.recus[1]) end
    if A.effetsRecus[1] then Ecran.MontrerEffet(A.effetsRecus[1]) end
end
