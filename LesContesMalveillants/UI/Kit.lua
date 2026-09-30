-- Boite a outils d'interface.
--
-- Volontairement petite : une fenetre, un onglet, un libelle, une valeur, un
-- bouton, une barre. Tout l'addon se dessine avec ca. Si un ecran demande un
-- widget de plus, il s'ajoute ICI — pas dans l'ecran, sinon chaque fenetre
-- finit par avoir son propre style.

local _, LCM = ...

local UI = {}
LCM.UI = UI

-- Palette. Un seul endroit pour changer l'allure de tout l'addon.
UI.C = {
    fond        = { 0.06, 0.05, 0.04, 0.94 },
    fondClair   = { 1, 1, 1, 0.04 },
    bordure     = { 0.78, 0.64, 0.36, 0.55 },
    titre       = { 0.95, 0.85, 0.63 },
    texte       = { 0.88, 0.84, 0.76 },
    discret     = { 0.60, 0.56, 0.50 },
    accent      = { 0.83, 0.68, 0.33 },
    vie         = { 0.74, 0.23, 0.23 },
    vieVide     = { 0.25, 0.10, 0.10 },
    fatigue     = { 0.30, 0.52, 0.78 },
    armure      = { 0.55, 0.58, 0.64 },
    survol      = { 1, 1, 1, 0.07 },
    -- Coloration d'un investissement : rien, quelque chose, au plafond.
    plein       = { 0.90, 0.36, 0.30 },
}

local function Couleur(frame, methode, couleur)
    frame[methode](frame, couleur[1], couleur[2], couleur[3], couleur[4])
end

-- Aplat uni : sert de fond et de bordure. Quatre traits valent un cadre.
function UI.Aplat(parent, couleur, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    Couleur(t, "SetColorTexture", couleur)
    return t
end

function UI.Bordure(frame, couleur)
    couleur = couleur or UI.C.bordure
    local traits = {}
    for _, cote in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = UI.Aplat(frame, couleur, "BORDER")
        if cote == "TOP" or cote == "BOTTOM" then
            t:SetHeight(1)
            t:SetPoint(cote .. "LEFT", frame, cote .. "LEFT", 0, 0)
            t:SetPoint(cote .. "RIGHT", frame, cote .. "RIGHT", 0, 0)
        else
            t:SetWidth(1)
            t:SetPoint("TOP" .. cote, frame, "TOP" .. cote, 0, 0)
            t:SetPoint("BOTTOM" .. cote, frame, "BOTTOM" .. cote, 0, 0)
        end
        traits[#traits + 1] = t
    end
    return traits
end

function UI.Texte(parent, texte, couleur, gabarit)
    local fs = parent:CreateFontString(nil, "OVERLAY", gabarit or "GameFontNormal")
    fs:SetText(texte or "")
    Couleur(fs, "SetTextColor", couleur or UI.C.texte)
    fs:SetJustifyH("LEFT")
    return fs
end

-- Toutes les fenetres de l'addon, pour pouvoir passer l'une devant l'autre.
UI.fenetres = {}
UI.niveauDevant = 10

-- Met une fenetre au premier plan. Sans ca, deux fenetres ouvertes au meme
-- endroit se melangent : le cadre de l'une passe par-dessus le contenu de
-- l'autre, et on ne sait plus laquelle on manipule.
function UI.Devant(f)
    UI.niveauDevant = UI.niveauDevant + 10
    if UI.niveauDevant > 2000 then UI.niveauDevant = 10 end
    f:SetFrameLevel(UI.niveauDevant)
    f:Raise()
    f.rangDevant = UI.niveauDevant
end

-- Fenetre deplacable avec titre et bouton de fermeture. `cle` sert a retenir
-- sa position d'une session a l'autre ; `defaut` donne sa place a la premiere
-- ouverture, pour que deux fenetres ne naissent pas exactement l'une sur
-- l'autre.
function UI.Fenetre(cle, titre, largeur, hauteur, defaut)
    local f = CreateFrame("Frame", "LCM_" .. tostring(cle), UIParent)
    f.cle = cle
    f:SetSize(largeur or 420, hauteur or 520)
    f:SetPoint("CENTER", UIParent, "CENTER",
        defaut and defaut.x or 0, defaut and defaut.y or 0)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    -- Cliquer dans une fenetre la ramene devant, comme partout ailleurs.
    f:SetScript("OnMouseDown", function(self) UI.Devant(self) end)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        LCM.EnsureDatabase()
        LCM.db.fenetres = type(LCM.db.fenetres) == "table" and LCM.db.fenetres or {}
        local point, _, relPoint, x, y = self:GetPoint()
        LCM.db.fenetres[self.cle] = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    f.fond = UI.Aplat(f, UI.C.fond)
    f.fond:SetAllPoints(f)

    f.titre = UI.Texte(f, titre, UI.C.titre)
    f.titre:SetPoint("TOP", f, "TOP", 0, -12)
    f.titre:SetJustifyH("CENTER")
    -- Le motif du haut du cadre se rogne pour laisser passer le titre.
    f.titreCentre = true

    f.fermer = CreateFrame("Button", nil, f)
    f.fermer:SetSize(20, 20)
    f.fermer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
    -- Au-dessus de l'habillage : l'ornement du coin passait par-dessus la croix
    -- et la fenetre n'avait plus l'air d'avoir de fermeture.
    f.fermer:SetFrameLevel(f:GetFrameLevel() + 6)
    f.fermer.fond = UI.Aplat(f.fermer, UI.C.fondClair)
    f.fermer.fond:SetAllPoints(f.fermer)
    UI.Bordure(f.fermer, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.45 })
    f.fermer.label = UI.Texte(f.fermer, "x", UI.C.titre)
    f.fermer.label:SetAllPoints(f.fermer)
    f.fermer.label:SetJustifyH("CENTER")
    f.fermer:SetScript("OnClick", function() f:Hide() end)

    f.contenu = CreateFrame("Frame", nil, f)
    f.contenu:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
    f.contenu:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)

    -- Position retenue.
    LCM.EnsureDatabase()
    local memoire = LCM.db.fenetres and LCM.db.fenetres[cle]
    if type(memoire) == "table" then
        f:ClearAllPoints()
        f:SetPoint(memoire.point or "CENTER", UIParent, memoire.relPoint or "CENTER",
            tonumber(memoire.x) or 0, tonumber(memoire.y) or 0)
    end

    f:HookScript("OnShow", function(self) UI.Devant(self) end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = f:GetName() end
    UI.fenetres[#UI.fenetres + 1] = f

    -- Le cadre ouvrage, s'il est charge. Sans lui, une simple bordure : la
    -- fenetre doit rester lisible meme si l'habillage manque.
    if UI.Cadre then
        UI.Cadre(f)
    else
        UI.Bordure(f)
    end

    f:Hide()
    return f
end

function UI.Bouton(parent, texte, largeur, hauteur, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(largeur or 90, hauteur or 22)
    b:EnableMouse(true)
    b.fond = UI.Aplat(b, UI.C.fondClair)
    b.fond:SetAllPoints(b)
    UI.Bordure(b, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.30 })
    b.label = UI.Texte(b, texte, UI.C.texte, "GameFontNormalSmall")
    b.label:SetAllPoints(b)
    b.label:SetJustifyH("CENTER")
    b.survol = UI.Aplat(b, UI.C.survol, "HIGHLIGHT")
    b.survol:SetAllPoints(b)
    if onClick then b:SetScript("OnClick", onClick) end
    function b:Selectionner(actif)
        self.__selectionne = actif and true or false
        local couleur = actif and UI.C.accent or UI.C.texte
        self.label:SetTextColor(couleur[1], couleur[2], couleur[3])
    end
    return b
end

-- Grille d'onglets. `onChange(id)` est appele au clic.
--
-- Les onglets se replient sur plusieurs rangees plutot que de retrecir jusqu'a
-- l'illisible : `options.parRangee` dit combien par ligne, et la derniere
-- rangee, incomplete, est centree.
function UI.Onglets(parent, onglets, onChange, options)
    options = options or {}
    local parRangee = options.parRangee or #onglets
    local largeur = options.largeur or 96
    local hauteur = options.hauteur or 22
    local ecart = options.ecart or 4

    local barre = CreateFrame("Frame", nil, parent)
    barre.boutons = {}

    local rangees = math.max(1, math.ceil(#onglets / parRangee))
    barre:SetHeight(rangees * (hauteur + ecart) - ecart)

    for index, onglet in ipairs(onglets) do
        local b = UI.Bouton(barre, onglet.label, largeur, hauteur, function()
            barre:Selectionner(onglet.id)
            if onChange then onChange(onglet.id) end
        end)
        b.ongletId = onglet.id

        local rangee = math.ceil(index / parRangee)
        local place = (index - 1) % parRangee
        -- Combien d'onglets sur CETTE rangee : la derniere peut etre courte.
        local surLaRangee = math.min(parRangee, #onglets - (rangee - 1) * parRangee)
        local largeurRangee = surLaRangee * largeur + (surLaRangee - 1) * ecart
        b:SetPoint("TOPLEFT", barre, "TOP",
            -largeurRangee / 2 + place * (largeur + ecart),
            -(rangee - 1) * (hauteur + ecart))
        barre.boutons[#barre.boutons + 1] = b
    end

    function barre:Selectionner(id)
        self.actif = id
        for _, b in ipairs(self.boutons) do b:Selectionner(b.ongletId == id) end
    end
    if onglets[1] then barre:Selectionner(onglets[1].id) end
    return barre
end

-- Barre de progression (jauge, partie du corps...).
function UI.Barre(parent, couleur, largeur, hauteur)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(largeur or 120, hauteur or 14)
    b.vide = UI.Aplat(b, UI.C.vieVide)
    b.vide:SetAllPoints(b)
    b.plein = UI.Aplat(b, couleur or UI.C.vie, "ARTWORK")
    b.plein:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.plein:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    b.plein:SetWidth(largeur or 120)
    b.label = UI.Texte(b, "", UI.C.texte, "GameFontNormalSmall")
    b.label:SetAllPoints(b)
    b.label:SetJustifyH("CENTER")
    function b:Regler(courant, maximum)
        courant = math.max(0, tonumber(courant) or 0)
        maximum = math.max(0, tonumber(maximum) or 0)
        local largeurTotale = self:GetWidth()
        local part = maximum > 0 and (courant / maximum) or 0
        -- Une barre a zero garde un liseré : « vide » et « absent » ne doivent
        -- pas se ressembler.
        self.plein:SetWidth(math.max(part > 0 and 2 or 0, largeurTotale * part))
        self.plein:SetShown(part > 0)
        self.label:SetText(string.format("%d / %d", courant, maximum))
        self.courant, self.maximum = courant, maximum
    end
    b:Regler(0, 0)
    return b
end

-- Champ de saisie. `onChange(texte)` est appele a chaque frappe.
function UI.Champ(parent, largeur, hauteur, onChange)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(largeur or 180, hauteur or 22)
    e:SetAutoFocus(false)
    e:SetMaxLetters(40)
    e:SetFontObject("GameFontNormalSmall")
    e:SetTextInsets(6, 6, 0, 0)
    e.fond = UI.Aplat(e, UI.C.fondClair)
    e.fond:SetAllPoints(e)
    UI.Bordure(e, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.30 })
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    if onChange then
        e:SetScript("OnTextChanged", function(self, parLUtilisateur)
            if parLUtilisateur ~= false then onChange(self:GetText() or "") end
        end)
    end
    return e
end

-- Ligne de repartition : « libelle .... [R][-] valeur / plafond [+][M] ».
--
-- `rappels.change(valeur)` doit renvoyer `false` si la valeur est refusee, et
-- rien ne bouge alors. `rappels.max()` donne la plus grande valeur qu'on puisse
-- encore se payer ; sans lui, le bouton M n'apparait pas.
function UI.Compteur(parent, libelle, largeurLibelle, rappels)
    if type(rappels) == "function" then rappels = { change = rappels } end
    rappels = rappels or {}

    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(20)
    l.valeur, l.plafond = 0, 0

    l.label = UI.Texte(l, libelle, UI.C.texte, "GameFontNormalSmall")
    l.label:SetPoint("LEFT", l, "LEFT", 0, 0)
    l.label:SetWidth(largeurLibelle or 120)

    local function Poser(valeur)
        if valeur < 0 then return end
        if rappels.change and rappels.change(valeur) == false then return end
    end

    -- L'ordre suit celui de la feuille : remise a zero et retrait a gauche du
    -- chiffre, ajout et maximum a droite.
    l.remise = UI.Bouton(l, "R", 16, 16, function() Poser(0) end)
    l.remise:SetPoint("LEFT", l, "LEFT", (largeurLibelle or 120) + 2, 0)
    l.moins = UI.Bouton(l, "-", 16, 16, function() Poser(l.valeur - 1) end)
    l.moins:SetPoint("LEFT", l.remise, "RIGHT", 2, 0)

    l.chiffre = UI.Texte(l, "0", UI.C.titre, "GameFontNormalSmall")
    l.chiffre:SetPoint("LEFT", l.moins, "RIGHT", 4, 0)
    l.chiffre:SetWidth(52)
    l.chiffre:SetJustifyH("CENTER")

    l.plus = UI.Bouton(l, "+", 16, 16, function() Poser(l.valeur + 1) end)
    l.plus:SetPoint("LEFT", l.chiffre, "RIGHT", 4, 0)
    l.maximum = UI.Bouton(l, "M", 16, 16, function()
        if rappels.max then Poser(rappels.max()) end
    end)
    l.maximum:SetPoint("LEFT", l.plus, "RIGHT", 2, 0)
    l.maximum:SetShown(rappels.max ~= nil)

    -- Coloration : gris tant que rien n'est investi, dore des le premier point,
    -- rouge au plafond — on voit d'un coup d'oeil ou l'on a pousse a fond. Une
    -- valeur AU-DESSUS du plafond reste affichee, en rouge, plutot que d'etre
    -- corrigee en douce : c'est au joueur de trancher ce qu'il abandonne.
    function l:Regler(valeur, plafond)
        self.valeur, self.plafond = valeur or 0, plafond or 0
        self.chiffre:SetText(string.format("%d / %d", self.valeur, self.plafond))
        local couleur = UI.C.discret
        if self.plafond > 0 and self.valeur >= self.plafond then
            couleur = UI.C.plein
        elseif self.valeur > 0 then
            couleur = UI.C.accent
        end
        self.chiffre:SetTextColor(couleur[1], couleur[2], couleur[3])
        local teinte = self.valeur > 0 and UI.C.texte or UI.C.discret
        self.label:SetTextColor(teinte[1], teinte[2], teinte[3])
    end
    l:Regler(0, 0)
    return l
end

-- En-tete de groupe : « STATISTIQUES PRIMAIRES      reste / total   [R] ».
function UI.EnTeteGroupe(parent, libelle, onReset)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(18)
    h.label = UI.Texte(h, libelle, UI.C.accent, "GameFontNormalSmall")
    h.label:SetPoint("LEFT", h, "LEFT", 0, 0)

    h.remise = UI.Bouton(h, "R", 16, 16, function() if onReset then onReset() end end)
    h.remise:SetPoint("RIGHT", h, "RIGHT", 0, 0)
    h.remise:SetShown(onReset ~= nil)

    h.budget = UI.Texte(h, "", UI.C.titre, "GameFontNormalSmall")
    h.budget:SetPoint("RIGHT", h.remise, "LEFT", -6, 0)
    h.budget:SetJustifyH("RIGHT")

    local trait = UI.Aplat(h, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.25 })
    trait:SetHeight(1)
    trait:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, -1)
    trait:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, -1)

    function h:Regler(reste, total)
        self.budget:SetText(string.format("%d / %d", reste, total))
        local couleur = UI.C.titre
        if reste < 0 then couleur = UI.C.plein elseif reste == 0 then couleur = UI.C.discret end
        self.budget:SetTextColor(couleur[1], couleur[2], couleur[3])
    end
    return h
end

-- Zone defilante. Pas de barre : la molette suffit, et l'utilisateur les cache
-- de toute facon. `zone.contenu` est le cadre ou l'on pose, `zone:Regler(h)`
-- annonce la hauteur reelle du contenu.
function UI.Defilement(parent)
    local zone = CreateFrame("Frame", nil, parent)
    zone.decalage, zone.hauteurContenu = 0, 0

    zone.contenu = CreateFrame("Frame", nil, zone)
    zone.contenu:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, 0)
    zone.contenu:SetPoint("TOPRIGHT", zone, "TOPRIGHT", 0, 0)

    local function Appliquer()
        local visible = zone:GetHeight()
        local debord = math.max(0, zone.hauteurContenu - visible)
        zone.decalage = math.max(0, math.min(zone.decalage, debord))
        zone.contenu:ClearAllPoints()
        zone.contenu:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, zone.decalage)
        zone.contenu:SetPoint("TOPRIGHT", zone, "TOPRIGHT", 0, zone.decalage)
        zone.debord = debord
    end

    zone:EnableMouseWheel(true)
    zone:SetScript("OnMouseWheel", function(_, delta)
        zone.decalage = zone.decalage - delta * 24
        Appliquer()
    end)

    function zone:Regler(hauteur)
        self.hauteurContenu = hauteur or 0
        self.contenu:SetHeight(math.max(1, self.hauteurContenu))
        Appliquer()
    end
    return zone
end

-- Demande de confirmation. Elle ne sert qu'aux gestes qu'on ne peut pas defaire.
function UI.Confirmer(parent, texte, libelleOui)
    local d = CreateFrame("Frame", nil, parent)
    d:SetPoint("CENTER", parent, "CENTER", 0, 0)
    d:SetSize(340, 130)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:EnableMouse(true)
    d.fond = UI.Aplat(d, UI.C.fond)
    d.fond:SetAllPoints(d)
    UI.Bordure(d)

    d.texte = UI.Texte(d, texte or "", UI.C.texte, "GameFontNormalSmall")
    d.texte:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -20)
    d.texte:SetPoint("TOPRIGHT", d, "TOPRIGHT", -16, -20)
    d.texte:SetJustifyH("CENTER")
    d.texte:SetWordWrap(true)

    -- L'action change d'un appel a l'autre (« supprimer CE personnage ») : elle
    -- est portee par la demande, pas par le bouton.
    d.oui = UI.Bouton(d, libelleOui or "Confirmer", 130, 24, function()
        local action = d.action
        d.action = nil
        d:Hide()
        if action then action() end
    end)
    d.oui:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 24, 16)
    d.oui.label:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])

    d.non = UI.Bouton(d, "Annuler", 130, 24, function()
        d.action = nil
        d:Hide()
    end)
    d.non:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -24, 16)

    function d:Demander(question, action)
        self.texte:SetText(question or "")
        self.action = action
        self:Show()
    end

    d:Hide()
    return d
end
