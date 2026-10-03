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
    -- Le titre d'un bloc de fiche : #CCB366, releve sur Necronicon. Il est plus
    -- sourd que `titre`, qui sert aux valeurs et aux en-tetes de fenetre.
    titreBloc   = { 0.80, 0.70, 0.40 },
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
    -- Repris de la palette Necronicon (UI.colors) : libelles de champ,
    -- filets de separation, bordure fine des panneaux.
    libelle     = { 0.70, 0.65, 0.50 },
    filet       = { 0.25, 0.25, 0.25, 1 },
    filetDoux   = { 0.18, 0.18, 0.18, 1 },
    bordureFine = { 0.88, 0.82, 0.65 },
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

-- Capitales avec leurs accents : string.upper ne connait que l'ASCII, il
-- laisserait « é » en minuscule au milieu d'un titre.
local CAPITALES = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["ë"] = "Ë", ["à"] = "À", ["â"] = "Â",
    ["î"] = "Î", ["ï"] = "Ï", ["ô"] = "Ô", ["ù"] = "Ù", ["û"] = "Û", ["ç"] = "Ç", ["œ"] = "Œ" }
function UI.Majuscules(texte)
    texte = tostring(texte or ""):gsub("[\195\197][\128-\191]", function(c) return CAPITALES[c] or c end)
    return (texte:upper())
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
--
-- `options.enTeteSimple` : l'en-tete des fenetres de travail du modele
-- (compendium, hub) — titre centre en 18, sans ornements ni filet d'or, et
-- un contenu qui commence a 38 du haut (PANEL_TOP_OFFSET de Necronicon).
function UI.Fenetre(cle, titre, largeur, hauteur, defaut, options)
    options = options or {}
    local f = CreateFrame("Frame", "LCM_" .. tostring(cle), UIParent)
    f.cle = cle
    f:SetSize(largeur or 420, hauteur or 520)
    -- La place de naissance est gardee : « remettre les fenetres a leur place »
    -- doit pouvoir y revenir, meme apres des mois de deplacements.
    f.defautPosition = { x = (defaut and defaut.x) or 0, y = (defaut and defaut.y) or 0 }
    f:SetPoint("CENTER", UIParent, "CENTER", f.defautPosition.x, f.defautPosition.y)
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
        local avant = type(LCM.db.fenetres[self.cle]) == "table" and LCM.db.fenetres[self.cle] or {}
        LCM.db.fenetres[self.cle] = { point = point, relPoint = relPoint, x = x, y = y,
                                      largeur = avant.largeur, hauteur = avant.hauteur }
    end)

    f.fond = UI.Aplat(f, UI.C.fond)
    f.fond:SetAllPoints(f)

    -- En-tete du modele Necronicon (AelWidgets, LayoutFiche) : titre en
    -- capitales entre deux ornements, deux pendentifs, un filet d'or a 63
    -- unites, la croix du modele. Tout suit la largeur (845 unites).
    local m = UI.AelMesures(largeur or 420)
    local q = m.echelle
    f.titre = UI.Texte(f, "", UI.C.titre)
    f.titre:SetPoint("CENTER", f, "TOP", 0, -32 * q)
    f.titre:SetJustifyH("CENTER")
    UI.Police(f.titre, m.titre)
    -- Le motif du haut du cadre se rogne pour laisser passer le titre.
    f.titreCentre = true

    if options.enTeteSimple then
        f.titre:ClearAllPoints()
        f.titre:SetPoint("TOPLEFT", f, "TOPLEFT", 150 * q, -20 * q)
        f.titre:SetPoint("TOPRIGHT", f, "TOPRIGHT", -150 * q, -20 * q)
        UI.Police(f.titre, 18)
        f.enTeteSimple = true
    end

    if UI.AelRef and not options.enTeteSimple then
        f.ornementG = UI.AelRef(f, 329, 119, 63, 19, "ARTWORK")
        f.ornementD = UI.AelRef(f, 635, 119, 64, 19, "ARTWORK")
        f.ornementG:SetSize(63 * q, 19 * q)
        f.ornementD:SetSize(64 * q, 19 * q)
        f.pendentifs = { UI.AelRef(f, 262, 100, 20, 46, "ARTWORK"), UI.AelRef(f, 742, 100, 20, 46, "ARTWORK") }
        f.pendentifs[1]:SetSize(20 * q, 46 * q)
        f.pendentifs[1]:SetPoint("TOPLEFT", f, "TOPLEFT", 172 * q, -5 * q)
        f.pendentifs[2]:SetSize(20 * q, 46 * q)
        f.pendentifs[2]:SetPoint("TOPRIGHT", f, "TOPRIGHT", -173 * q, -5 * q)
        f.regle = UI.AelRef(f, 420, 158, 180, 3, "ARTWORK")
        f.regle:SetPoint("TOPLEFT", f, "TOPLEFT", 10 * q, -m.regle)
        f.regle:SetPoint("TOPRIGHT", f, "TOPRIGHT", -13 * q, -m.regle)
        f.regle:SetHeight(math.max(1, 3 * q))
    end

    -- Le titre s'ecrit en capitales, et les ornements l'encadrent au plus
    -- pres, quelle que soit sa longueur.
    function f:Titre(texte)
        self.titre:SetText(UI.Majuscules(texte))
        if self.ornementG then
            local demi = (self.titre:GetStringWidth() or 0) / 2 + 14 * q
            self.ornementG:ClearAllPoints()
            self.ornementG:SetPoint("RIGHT", self.titre, "CENTER", -demi, 0)
            self.ornementD:ClearAllPoints()
            self.ornementD:SetPoint("LEFT", self.titre, "CENTER", demi, 0)
            -- Un titre long dans une fenetre etroite (« Pénétration &
            -- Résistances » sur 340) pousserait ses ornements sous la croix et
            -- la pastille : ils s'effacent, le titre reste. Ce sont eux le
            -- decor, pas les boutons.
            local place = self.fermer and (self:GetWidth() / 2 - (self.retraitCoin or 0) - self.fermer:GetWidth() - 4)
            local tient = not place or demi + self.ornementD:GetWidth() <= place
            self.ornementG:SetShown(tient)
            self.ornementD:SetShown(tient)
        end
    end
    f:Titre(titre)

    -- Sous-titre (le nom du personnage affiche) : il vit DANS l'en-tete,
    -- entre le titre et le filet d'or. Le titre remonte pour lui faire place ;
    -- sans sous-titre, il reste centre dans l'en-tete.
    f.sousTitre = UI.Texte(f, "", UI.C.discret)
    f.sousTitre:SetJustifyH("CENTER")
    UI.Police(f.sousTitre, math.max(11, m.police * 0.62))
    f.sousTitre:SetPoint("CENTER", f, "TOP", 0, -m.regle + 9 * q + 2)
    function f:SousTitre(texte)
        if self.enTeteSimple then return end
        texte = tostring(texte or "")
        self.sousTitre:SetText(texte)
        self.titre:ClearAllPoints()
        if texte ~= "" then
            self.titre:SetPoint("CENTER", self, "TOP", 0, -22 * q)
        else
            self.titre:SetPoint("CENTER", self, "TOP", 0, -32 * q)
        end
        self:Titre(self.titre:GetText())
    end

    f.fermer = CreateFrame("Button", nil, f)
    -- Plafonnee a 32 : a 54 unites de l'atlas, une fenetre large porte une
    -- croix de 46 px qui mange l'en-tete et vient mordre sur le titre. Une
    -- croix n'a pas besoin de grandir avec la fenetre, on sait ce qu'elle fait.
    local cote = math.max(14, math.min(18, 54 * q))
    f.fermer:SetSize(cote, cote)
    -- La croix, et ce que la fenetre pose en miroir a gauche (la pastille de
    -- canal), doivent commencer APRES l'ornement du coin : pose au ras du bord,
    -- un bouton mord sur la tour d'angle de l'habillage.
    function f:PlacerCoinsHaut()
        local retrait = math.max(6 * q, (UI.AelRetraitCoin and UI.AelRetraitCoin(self) or 0) + 4)
        self.fermer:ClearAllPoints()
        self.fermer:SetPoint("TOPRIGHT", self, "TOPRIGHT", -retrait, -6 * q)
        if self.coinGauche then
            self.coinGauche:ClearAllPoints()
            self.coinGauche:SetPoint("TOPLEFT", self, "TOPLEFT", retrait, -6 * q)
        end
        self.retraitCoin = retrait
        -- Les coins ont bouge : les ornements du titre tiennent-ils encore ?
        self:Titre(self.titre:GetText())
    end
    f:PlacerCoinsHaut()
    -- Au-dessus de l'habillage : l'ornement du coin passait par-dessus la croix
    -- et la fenetre n'avait plus l'air d'avoir de fermeture.
    f.fermer:SetFrameLevel(f:GetFrameLevel() + 6)
    if UI.AelRef then
        f.fermer.icone = UI.AelRef(f.fermer, 898, 102, 54, 54, "OVERLAY")
        f.fermer.icone:SetAllPoints(f.fermer)
    end
    f.fermer.survol = UI.Aplat(f.fermer, UI.C.survol, "HIGHLIGHT")
    f.fermer.survol:SetAllPoints(f.fermer)
    f.fermer:SetScript("OnClick", function() f:Hide() end)

    -- Le contenu commence sous le filet, la ou le modele pose ses onglets.
    f.contenu = CreateFrame("Frame", nil, f)
    -- Les marges sont retenues : une fenetre qui veut prendre la hauteur de son
    -- contenu doit savoir ce que son habillage lui prend, et le DEDUIRE des
    -- ancrages demande une geometrie d'ecran qu'on n'a pas toujours (au banc,
    -- jamais).
    f.insetHaut = options.enTeteSimple and 38 or m.bandeau
    f.insetBas = 12
    f.insetCote = 12
    f.contenu:SetPoint("TOPLEFT", f, "TOPLEFT", f.insetCote, -f.insetHaut)
    f.contenu:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -f.insetCote, f.insetBas)
    f.mesures = m

    -- Position retenue.
    LCM.EnsureDatabase()
    local memoire = LCM.db.fenetres and LCM.db.fenetres[cle]
    if type(memoire) == "table" then
        f:ClearAllPoints()
        f:SetPoint(memoire.point or "CENTER", UIParent, memoire.relPoint or "CENTER",
            tonumber(memoire.x) or 0, tonumber(memoire.y) or 0)
        -- Une fenetre redimensionnable retrouve sa taille (UI.Redimensionner).
        if options.redimensionnable and tonumber(memoire.largeur) and tonumber(memoire.hauteur) then
            f:SetSize(tonumber(memoire.largeur), tonumber(memoire.hauteur))
        end
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

-- Ramene toutes les fenetres la ou elles naissent, et oublie les places
-- retenues. Le filet de secours quand une fenetre est partie hors de l'ecran.
function UI.ReplacerFenetres()
    LCM.EnsureDatabase()
    LCM.db.fenetres = {}
    local nombre = 0
    for _, f in ipairs(UI.fenetres) do
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", f.defautPosition.x, f.defautPosition.y)
        nombre = nombre + 1
    end
    return nombre
end

function UI.Bouton(parent, texte, largeur, hauteur, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(largeur or 90, hauteur or 22)
    b:EnableMouse(true)
    b.fond = UI.Aplat(b, UI.C.fondClair)
    b.fond:SetAllPoints(b)
    b.traits = UI.Bordure(b, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.30 })
    -- L'habillage du modele remplace le fond et la bordure d'origine, qui
    -- restent pour le cas ou le skin manquerait.
    if UI.AelBoutonNet then
        UI.AelBoutonNet(b)
        b.fond:Hide()
        for _, t in ipairs(b.traits) do t:Hide() end
    end
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
        if UI.HabillerOnglet then UI.HabillerOnglet(b) end

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

-- Bande d'onglets du modele (Necronicon, Fiche.lua + ApplyAelTab) :
-- chaque onglet prend la largeur de son libelle + 50 (70 au moins) ; une
-- rangee qui deborde passe a la ligne ; chaque rangee est ensuite justifiee sur
-- toute la largeur, 6 d'ecart. Hauteur : 55 unites de la fenetre. L'actif est
-- dore, les autres ivoire.
--
-- `bandeau:Disposer(largeur, hauteurRangee)` pose les onglets et renvoie la
-- hauteur occupee : c'est au proprietaire de placer son contenu dessous.
function UI.BandeauOnglets(parent, onglets, onChange)
    local bandeau = CreateFrame("Frame", nil, parent)
    bandeau.boutons = {}
    bandeau.mesure = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bandeau.mesure:SetAlpha(0)

    for _, onglet in ipairs(onglets) do
        local b = CreateFrame("Button", nil, bandeau)
        b.ongletId = onglet.id
        b.label = UI.Texte(b, onglet.label, UI.C.texte)
        b.label:SetPoint("CENTER", b, "CENTER", 0, 1)
        b.label:SetJustifyH("CENTER")
        b.survol = UI.Aplat(b, UI.C.survol, "HIGHLIGHT")
        b.survol:SetAllPoints(b)
        if UI.HabillerOnglet then UI.HabillerOnglet(b) end
        b:SetScript("OnClick", function(bouton)
            bandeau:Selectionner(bouton.ongletId)
            if onChange then onChange(bouton.ongletId) end
        end)
        bandeau.boutons[#bandeau.boutons + 1] = b
    end

    function bandeau:Selectionner(id)
        self.actif = id
        for _, b in ipairs(self.boutons) do
            if b.Selectionner then b:Selectionner(b.ongletId == id) end
        end
    end

    -- `options.uneRangee` : tout tient sur une seule ligne, quitte a reduire le
    -- texte. Chaque onglet recoit la meme part de la largeur, et la police
    -- descend jusqu'a ce que le plus long libelle y tienne (jamais sous 9 : en
    -- dessous ca ne se lit plus, mieux vaut alors une fenetre plus large).
    function bandeau:Disposer(largeur, hauteurRangee, options)
        options = options or {}
        local police = 24 * ((hauteurRangee - 2) / 55)

        if options.uneRangee and #self.boutons > 0 then
            local n = #self.boutons
            local part = math.max(40, (largeur - (n - 1) * 6) / n)
            UI.Police(self.mesure, police)
            local pire = 0
            for _, b in ipairs(self.boutons) do
                self.mesure:SetText(b.label:GetText() or "")
                pire = math.max(pire, self.mesure:GetStringWidth() or 0)
            end
            -- La largeur d'un texte suit sa police : on en deduit le rapport.
            if pire > 0 and pire + 14 > part then
                police = math.max(9, math.floor(police * (part - 14) / pire))
            end
            local x = 0
            for index, b in ipairs(self.boutons) do
                UI.Police(b.label, police)
                b:SetSize(part, hauteurRangee - 2)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
                x = x + part + (index < n and 6 or 0)
            end
            self:SetHeight(hauteurRangee)
            self.rangees = 1
            self:Selectionner(self.actif or self.boutons[1].ongletId)
            return hauteurRangee
        end

        UI.Police(self.mesure, police)
        local rangees, courante, x = {}, nil, 0
        for _, b in ipairs(self.boutons) do
            UI.Police(b.label, police)
            self.mesure:SetText(b.label:GetText() or "")
            local l = math.max(70, math.ceil((self.mesure:GetStringWidth() or 0) + 50))
            if courante and x > 0 and x + l > largeur then courante = nil end
            if not courante then
                courante = { boutons = {}, naturelle = 0 }
                rangees[#rangees + 1] = courante
                x = 0
            end
            courante.boutons[#courante.boutons + 1] = { bouton = b, largeur = l }
            courante.naturelle = courante.naturelle + l
            x = x + l + 6
        end
        for r, rangee in ipairs(rangees) do
            local n = #rangee.boutons
            local ecarts = (n - 1) * 6
            local extra = n > 1 and math.max(0, (largeur - rangee.naturelle - ecarts) / n) or 0
            local justifiee = rangee.naturelle + ecarts + extra * n
            local px = n == 1 and math.max(0, (largeur - justifiee) / 2) or 0
            for index, info in ipairs(rangee.boutons) do
                local b = info.bouton
                b:SetSize(info.largeur + extra, hauteurRangee - 2)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self, "TOPLEFT", px, -(r - 1) * hauteurRangee)
                px = px + info.largeur + extra + (index < n and 6 or 0)
            end
        end
        local hauteur = math.max(1, #rangees) * hauteurRangee
        self:SetHeight(hauteur)
        self.rangees = math.max(1, #rangees)
        self:Selectionner(self.actif or (self.boutons[1] and self.boutons[1].ongletId))
        return hauteur
    end
    return bandeau
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
    e.fond = UI.Aplat(e, { 0.035, 0.030, 0.023, 0.9 })
    e.fond:SetAllPoints(e)
    if UI.HabillerSaisie then UI.HabillerSaisie(e)
    else UI.Bordure(e, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.30 }) end
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- Tabulation : au champ suivant, Maj au precedent. Sans `suivant`, elle
    -- rend simplement la main — jamais le curseur coince dans la case.
    e:SetScript("OnTabPressed", function(self)
        local cible = (IsShiftKeyDown and IsShiftKeyDown()) and self.precedent or self.suivant
        self:ClearFocus()
        if cible and cible:IsShown() then
            cible:SetFocus()
            if cible.HighlightText then cible:HighlightText() end
        end
    end)
    if onChange then
        e:SetScript("OnTextChanged", function(self, parLUtilisateur)
            if parLUtilisateur ~= false then onChange(self:GetText() or "") end
        end)
    end
    return e
end

-- Infobulle apres un temps d'arret. Elle ne doit pas sauter au visage des qu'on
-- traverse un bouton : on la laisse venir, et elle part des qu'on s'en va.
-- `texte` peut etre une fonction, pour une valeur qui bouge.
function UI.Bulle(cadre, titre, texte, delai)
    delai = delai or 1
    cadre:HookScript("OnEnter", function(self)
        self.__attente = 0
        self:SetScript("OnUpdate", function(soi, ecoule)
            soi.__attente = (soi.__attente or 0) + ecoule
            if soi.__attente < delai then return end
            soi:SetScript("OnUpdate", nil)
            if not GameTooltip then return end
            GameTooltip:SetOwner(soi, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:SetText(type(titre) == "function" and titre(soi) or titre,
                UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
            local detail = type(texte) == "function" and texte(soi) or texte
            if detail and detail ~= "" then GameTooltip:AddLine(detail, 0.78, 0.75, 0.68, true) end
            GameTooltip:Show()
            soi.__bulle = true
        end)
    end)
    cadre:HookScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        self.__attente = nil
        if self.__bulle and GameTooltip then GameTooltip:Hide() end
        self.__bulle = nil
    end)
    return cadre
end

-- Chaine des champs d'un formulaire : la tabulation passe de l'un a l'autre,
-- Maj + tabulation revient. On donne la liste dans l'ordre de lecture.
function UI.Enchainer(champs)
    for index, champ in ipairs(champs) do
        champ.suivant = champs[index + 1] or champs[1]
        champ.precedent = champs[index - 1] or champs[#champs]
    end
    return champs
end

-- Ligne de repartition : « libelle .... [R][-] valeur / plafond [+][M] ».
--
-- `rappels.change(valeur)` doit renvoyer `false` si la valeur est refusee, et
-- rien ne bouge alors. `rappels.max()` donne la plus grande valeur qu'on puisse
-- encore se payer ; sans lui, le bouton M n'apparait pas.
function UI.Compteur(parent, libelle, largeurLibelle, rappels)
    if type(rappels) == "function" then rappels = { change = rappels } end
    rappels = rappels or {}

    -- `rappels.serre` : le chiffre a l'etroit. 46 et pas moins : la valeur la
    -- plus large n'est pas « 0 / 3 » mais « 10 / 10 », et a 38 elle passait a
    -- la ligne — ce qui doublait la hauteur de la ligne et desalignait la
    -- colonne entiere.
    local largeurChiffre = rappels.serre and 46 or 52

    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(20)
    l.valeur, l.plafond = 0, 0
    -- Meme boite que les lignes de fiche (UI.SkinAelAllocLine).
    if UI.SurfaceLigne then UI.SurfaceLigne(l) end

    l.label = UI.Texte(l, libelle, UI.C.texte, "GameFontNormalSmall")
    UI.Police(l.label, 12)
    l.label:SetPoint("LEFT", l, "LEFT", 6, 0)
    l.label:SetWidth(largeurLibelle or 120)
    -- Un libelle trop long se coupe ; il ne passe pas a la ligne, sinon la
    -- ligne double de hauteur et la colonne se desaligne. `SetMaxLines(1)`
    -- rend la coupe franche : sans lui, le texte deborde sous les boutons au
    -- lieu de s'arreter a sa largeur.
    l.label:SetWordWrap(false)
    if l.label.SetMaxLines then l.label:SetMaxLines(1) end

    -- Ce que la ligne occupe apres le libelle : R, -, le chiffre, +, M.
    -- Utile pour decider ce qui tient encore a droite dans une colonne etroite.
    l.largeurBoutons = 84 + largeurChiffre

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
    l.chiffre:SetWidth(largeurChiffre)
    l.chiffre:SetJustifyH("CENTER")
    -- Jamais de retour a la ligne dans un chiffre : s'il ne tient pas, c'est la
    -- colonne qu'il faut elargir, pas la ligne qu'il faut faire grandir.
    l.chiffre:SetWordWrap(false)

    -- On clique le chiffre pour le taper. Monter de 0 a 10 au bouton « + »,
    -- c'est dix clics ; le « M » envoie au plafond, mais entre les deux il n'y
    -- avait rien. La saisie passe par le meme chemin que les boutons, donc par
    -- les memes refus : on ne peut pas se donner ce qu'on n'a pas.
    l.saisieValeur = CreateFrame("Button", nil, l)
    l.saisieValeur:SetPoint("TOPLEFT", l.chiffre, "TOPLEFT", 0, 2)
    l.saisieValeur:SetPoint("BOTTOMRIGHT", l.chiffre, "BOTTOMRIGHT", 0, -2)
    l.saisieValeur.survol = UI.Aplat(l.saisieValeur, UI.C.survol, "HIGHLIGHT")
    l.saisieValeur.survol:SetAllPoints(l.saisieValeur)
    l.saisieValeur:SetScript("OnClick", function()
        local plafond = rappels.max and rappels.max() or nil
        UI.Demande():Demander(tostring(libelle or ""), l.valeur, function(texte)
            local n = tonumber(texte)
            if not n or n ~= math.floor(n) or n < 0 then
                return false, "un nombre entier, 0 au minimum."
            end
            -- Le garde-fou est ici ET dans le rappel : ici on explique le
            -- plafond avant d'essayer, la-bas on refuse ce qui ne passe pas.
            if plafond and n > plafond then
                return false, string.format("%d au maximum.", plafond)
            end
            Poser(n)
            return true
        end)
    end)
    UI.Bulle(l.saisieValeur, tostring(libelle or ""), "Clic : saisir la valeur.")

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
    -- Titre du modele : capitales dorees suivies de leur ornement.
    h.label = UI.Texte(h, UI.Majuscules(libelle), UI.C.titre, "GameFontNormalSmall")
    UI.Police(h.label, 13)
    h.label:SetPoint("LEFT", h, "LEFT", 0, 0)
    if UI.AelRef then
        h.ornement = UI.AelRef(h, 347, 344, 45, 17, "ARTWORK")
        h.ornement:SetSize(30, 11)
        h.ornement:SetPoint("LEFT", h.label, "RIGHT", 8, 0)
    end

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

-- Zone defilante. Ce qui depasse est ROGNE au bord de la zone (sans ca, une
-- page longue deborde sous la fenetre), et une barre fine, dans la marge a
-- droite, montre ou l'on est : elle n'apparait que si le contenu depasse.
-- Molette, clic sur la gouttiere (page par page) ou poignee tiree a la souris.
-- `zone.contenu` est le cadre ou l'on pose, `zone:Regler(h)` annonce la
-- hauteur reelle du contenu.
function UI.Defilement(parent)
    local zone = CreateFrame("Frame", nil, parent)
    zone.decalage, zone.hauteurContenu, zone.debord = 0, 0, 0
    zone:SetClipsChildren(true)

    zone.contenu = CreateFrame("Frame", nil, zone)
    zone.contenu:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, 0)
    zone.contenu:SetPoint("TOPRIGHT", zone, "TOPRIGHT", 0, 0)

    -- La barre vit HORS de la zone (dans la marge du parent) : elle ne prend
    -- pas de largeur au contenu, et le rognage de la zone ne la coupe pas.
    local barre = CreateFrame("Button", nil, parent)
    barre:SetWidth(6)
    barre:SetPoint("TOPLEFT", zone, "TOPRIGHT", 3, 0)
    barre:SetPoint("BOTTOMLEFT", zone, "BOTTOMRIGHT", 3, 0)
    barre.gouttiere = UI.Aplat(barre, { 0.12, 0.10, 0.07, 0.8 })
    barre.gouttiere:SetAllPoints(barre)
    barre.poignee = CreateFrame("Frame", nil, barre)
    barre.poignee:SetWidth(6)
    barre.poignee.fond = UI.Aplat(barre.poignee, { 0.66, 0.51, 0.27, 0.9 }, "ARTWORK")
    barre.poignee.fond:SetAllPoints(barre.poignee)
    barre.poignee:EnableMouse(true)
    barre:Hide()
    zone.barre = barre

    local function Appliquer()
        local visible = zone:GetHeight()
        local debord = math.max(0, zone.hauteurContenu - visible)
        zone.decalage = math.max(0, math.min(zone.decalage, debord))
        zone.contenu:ClearAllPoints()
        zone.contenu:SetPoint("TOPLEFT", zone, "TOPLEFT", 0, zone.decalage)
        zone.contenu:SetPoint("TOPRIGHT", zone, "TOPRIGHT", 0, zone.decalage)
        zone.debord = debord
        -- Qui veut suivre le defilement — un sommaire qui marque le chapitre
        -- ou l'on est — l'apprend ici, donc a la molette aussi, pas seulement
        -- quand on clique dans la table des matieres.
        if zone.onDefilement then zone.onDefilement(zone.decalage) end

        barre:SetShown(debord > 0)
        if debord > 0 then
            local hauteurBarre = barre:GetHeight()
            -- La poignee est a l'echelle de ce qu'on voit, jamais minuscule.
            local taille = math.max(24, hauteurBarre * visible / zone.hauteurContenu)
            barre.poignee:SetHeight(taille)
            barre.poignee:ClearAllPoints()
            barre.poignee:SetPoint("TOP", barre, "TOP", 0, -(hauteurBarre - taille) * zone.decalage / debord)
            zone.course = hauteurBarre - taille
        end
    end
    zone.Appliquer = Appliquer

    function zone:Aller(decalage)
        self.decalage = decalage
        Appliquer()
    end

    zone:EnableMouseWheel(true)
    zone:SetScript("OnMouseWheel", function(_, delta) zone:Aller(zone.decalage - delta * 40) end)
    -- Une fenetre dont la taille n'est connue qu'apres la mise en page : on
    -- recalcule quand elle arrive.
    zone:SetScript("OnSizeChanged", Appliquer)

    -- Clic dans la gouttiere : une page vers le haut ou le bas.
    barre:SetScript("OnClick", function(self)
        local _, y = GetCursorPosition()
        y = y / (self:GetEffectiveScale() or 1)
        local haut = barre.poignee:GetTop() or 0
        local page = zone:GetHeight() * 0.9
        zone:Aller(zone.decalage + ((y > haut) and -page or page))
    end)

    -- Poignee tiree : le decalage suit la souris, proportionnellement.
    barre.poignee:SetScript("OnMouseDown", function(self)
        local _, y = GetCursorPosition()
        self.depart = { y = y / (self:GetEffectiveScale() or 1), decalage = zone.decalage }
        self:SetScript("OnUpdate", function(poignee)
            if not poignee.depart or (zone.course or 0) <= 0 then return end
            local _, cy = GetCursorPosition()
            cy = cy / (poignee:GetEffectiveScale() or 1)
            local ratio = (poignee.depart.y - cy) / zone.course
            zone:Aller(poignee.depart.decalage + ratio * zone.debord)
        end)
    end)
    barre.poignee:SetScript("OnMouseUp", function(self)
        self.depart = nil
        self:SetScript("OnUpdate", nil)
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
    -- Cadre des blocs du modele ; une simple bordure si le skin manque.
    if UI.AelCadre then d.cadre = UI.AelCadre(d, "section") else UI.Bordure(d) end

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

-- Texte sur plusieurs lignes (une description). Une zone de saisie multiligne
-- grandit avec son texte : on l'enferme dans un cadre qui rogne, pour qu'une
-- longue description ne deborde pas sur le reste du formulaire. Entree passe a
-- la ligne ; Echap rend la main.
function UI.Zone(parent, largeur, hauteur, onChange)
    local z = CreateFrame("Frame", nil, parent)
    z:SetSize(largeur or 260, hauteur or 70)
    z:SetClipsChildren(true)
    z:EnableMouse(true)
    z.fond = UI.Aplat(z, { 0.035, 0.030, 0.023, 0.9 })
    z.fond:SetAllPoints(z)
    if UI.HabillerSaisie then UI.HabillerSaisie(z)
    else UI.Bordure(z, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.30 }) end

    local e = CreateFrame("EditBox", nil, z)
    e:SetMultiLine(true)
    e:SetAutoFocus(false)
    e:SetMaxLetters(500)
    e:SetFontObject("GameFontNormalSmall")
    e:SetPoint("TOPLEFT", z, "TOPLEFT", 6, -4)
    e:SetWidth((largeur or 260) - 12)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if onChange then
        e:SetScript("OnTextChanged", function(self, parLUtilisateur)
            if parLUtilisateur ~= false then onChange(self:GetText() or "") end
        end)
    end
    z.saisie = e
    -- Cliquer n'importe ou dans le cadre donne la main au texte, meme sous la
    -- derniere ligne ecrite.
    z:SetScript("OnMouseDown", function() e:SetFocus() end)

    function z:SetText(texte) self.saisie:SetText(texte or "") end
    function z:GetText() return self.saisie:GetText() or "" end
    return z
end

-- Liste de choix, ouverte a cote d'un bouton : « quel champ ? », « quelle
-- morphologie ? ». Les options sont { id, label, groupe } ; un changement de
-- groupe pose un intertitre. `cle` nomme le cadre, ce qui le fait fermer par
-- Echap comme les fenetres.
--
-- Les lignes sont gardees d'une ouverture a l'autre et seulement completees :
-- on ne recree pas des cadres a chaque clic.
function UI.Choix(cle, titre)
    local d = CreateFrame("Frame", "LCM_Choix_" .. tostring(cle), UIParent)
    d:SetSize(260, 320)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetClampedToScreen(true)
    d:EnableMouse(true)
    d.fond = UI.Aplat(d, UI.C.fond)
    d.fond:SetAllPoints(d)
    -- Cadre des blocs du modele ; une simple bordure si le skin manque.
    if UI.AelCadre then d.cadre = UI.AelCadre(d, "section") else UI.Bordure(d) end

    d.titre = UI.Texte(d, titre or "", UI.C.titre, "GameFontNormalSmall")
    d.titre:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -9)

    d.fermer = UI.Bouton(d, "x", 18, 18, function() d:Hide() end)
    d.fermer:SetPoint("TOPRIGHT", d, "TOPRIGHT", -6, -6)

    d.zone = UI.Defilement(d)
    d.zone:SetPoint("TOPLEFT", d, "TOPLEFT", 8, -30)
    d.zone:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -8, 8)

    d.lignes, d.intertitres = {}, {}

    local HAUTEUR = 20

    function d:Proposer(ancre, options, onChoix)
        self.onChoix = onChoix
        local y, nLignes, nIntertitres, groupe = 0, 0, 0, nil
        for _, option in ipairs(options or {}) do
            if option.groupe and option.groupe ~= groupe then
                groupe = option.groupe
                nIntertitres = nIntertitres + 1
                local t = self.intertitres[nIntertitres]
                if not t then
                    t = UI.Texte(self.zone.contenu, "", UI.C.accent, "GameFontNormalSmall")
                    self.intertitres[nIntertitres] = t
                end
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 2, -y - 4)
                t:SetText(groupe)
                t:Show()
                y = y + HAUTEUR
            end
            nLignes = nLignes + 1
            local b = self.lignes[nLignes]
            if not b then
                -- La valeur choisie est portee par la ligne : une fermeture qui
                -- capturerait l'index de boucle renverrait toujours la derniere.
                b = UI.Bouton(self.zone.contenu, "", 10, HAUTEUR - 2, function(ligne)
                    d:Hide()
                    if d.onChoix then d.onChoix(ligne.choix) end
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 8, 0)
                b.label:SetJustifyH("LEFT")
                self.lignes[nLignes] = b
            end
            b.choix = option.id
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            b:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            b.label:SetText(option.label or option.id)
            b:Show()
            y = y + HAUTEUR
        end
        for index = nLignes + 1, #self.lignes do self.lignes[index]:Hide() end
        for index = nIntertitres + 1, #self.intertitres do self.intertitres[index]:Hide() end

        self:ClearAllPoints()
        if ancre then
            self:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", 0, -2)
        else
            self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        self.zone.decalage = 0
        self:Show()
        self:Raise()
        self.zone:Regler(y)
    end

    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = d:GetName() end
    d:Hide()
    return d
end

-- ===== Widgets des fenetres de travail (compendium) ========================

-- Bordure fine d'un panneau (UI.EnsureThinBorder de Necronicon) : un pixel,
-- couleur de bordure du modele, opacite au choix.
function UI.BordureFine(frame, alpha)
    local c = UI.C.bordureFine
    return UI.Bordure(frame, { c[1], c[2], c[3], alpha or 0.2 })
end

-- Filet de separation (UI.ApplySeparator) : horizontal par defaut.
function UI.Filet(parent, doux, vertical)
    local t = UI.Aplat(parent, doux and UI.C.filetDoux or UI.C.filet, "ARTWORK")
    if vertical then t:SetWidth(1) else t:SetHeight(1) end
    return t
end

-- Poignee de redimensionnement en bas a droite (18 x 18, a 4 du bord). La
-- taille finale est retenue avec la position de la fenetre ; `onFin` est
-- appele quand on lache, pour que la fenetre se remette en page une fois.
-- `maxL` / `maxH` : des bornes hautes, facultatives. Verrouiller la LARGEUR
-- (maxL = minL) laisse une poignee qui ne change que la hauteur : c'est ce
-- qu'il faut pour une fiche, dont les colonnes sont calculees a la
-- construction et ne sauraient pas suivre un elargissement.
function UI.Redimensionner(f, minL, minH, onFin, maxL, maxH)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(minL, minH, maxL, maxH) end
    local poignee = CreateFrame("Button", nil, f)
    poignee:SetSize(18, 18)
    poignee:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 4)
    poignee:SetFrameLevel(f:GetFrameLevel() + 8)
    poignee.icone = poignee:CreateTexture(nil, "OVERLAY")
    poignee.icone:SetAllPoints(poignee)
    poignee.icone:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    poignee:SetScript("OnMouseDown", function()
        f.enRedimension = true
        f:StartSizing("BOTTOMRIGHT")
    end)
    poignee:SetScript("OnMouseUp", function()
        if not f.enRedimension then return end
        f.enRedimension = nil
        f:StopMovingOrSizing()
        -- Jamais plus petit que le minimum, meme si le client l'a laisse passer.
        -- Jamais plus petit que le minimum ni plus grand que le maximum, meme
        -- si le client a laisse passer.
        local l = math.max(minL, math.min(maxL or math.huge, f:GetWidth()))
        local h = math.max(minH, math.min(maxH or math.huge, f:GetHeight()))
        if l ~= f:GetWidth() or h ~= f:GetHeight() then f:SetSize(l, h) end
        if f.cle then
            LCM.EnsureDatabase()
            LCM.db.fenetres = type(LCM.db.fenetres) == "table" and LCM.db.fenetres or {}
            local m = type(LCM.db.fenetres[f.cle]) == "table" and LCM.db.fenetres[f.cle] or {}
            m.largeur, m.hauteur = f:GetWidth(), f:GetHeight()
            LCM.db.fenetres[f.cle] = m
        end
        if onFin then onFin() end
    end)
    f.poignee = poignee
    return poignee
end

-- Curseur horizontal (le defilement lateral d'un tableau trop large) :
-- gouttiere sombre et poignee doree, comme la barre de UI.Defilement.
-- `curseur:Regler(max, valeur)` ; `onChange(valeur)` au deplacement.
--
-- `options.auRelachement` : n'appelle `onChange` qu'au LACHER. Indispensable
-- quand ce qu'on regle change la taille de la fenetre — sinon la gouttiere
-- grandit sous la poignee pendant qu'on tire, la course change a chaque image
-- et le curseur part tout seul. (Le meme defaut existait dans Necronicon.)
-- `options.onApercu(valeur)` est appele, lui, a chaque deplacement : de quoi
-- afficher le pourcentage sans rien appliquer.
function UI.Curseur(parent, onChange, options)
    options = options or {}
    local c = CreateFrame("Button", nil, parent)
    c:SetHeight(12)
    c.valeur, c.max = 0, 0
    c.gouttiere = UI.Aplat(c, { 0.07, 0.07, 0.07, 1 })
    c.gouttiere:SetAllPoints(c)
    c.poignee = CreateFrame("Frame", nil, c)
    c.poignee:SetSize(24, 10)
    c.poignee.fond = UI.Aplat(c.poignee, { 0.50, 0.42, 0.22, 0.85 }, "ARTWORK")
    c.poignee.fond:SetAllPoints(c.poignee)
    c.poignee:EnableMouse(true)

    local function Poser()
        local course = math.max(0, c:GetWidth() - c.poignee:GetWidth())
        local x = c.max > 0 and course * c.valeur / c.max or 0
        c.poignee:ClearAllPoints()
        c.poignee:SetPoint("LEFT", c, "LEFT", x, 0)
    end

    -- La poignee se replace a chaque fois, meme quand la valeur ne bouge pas :
    -- sans ancrage elle ne s'affiche nulle part, et une valeur deja bonne ne
    -- doit pas laisser la barre vide. `onChange` ne part, lui, que si la
    -- valeur a change.
    function c:Aller(valeur)
        valeur = math.floor(math.max(0, math.min(tonumber(valeur) or 0, self.max)))
        local change = valeur ~= self.valeur
        self.valeur = valeur
        Poser()
        if not change then return end
        if options.onApercu then options.onApercu(valeur) end
        -- Tant qu'on tire, on ne fait qu'annoncer ; c'est le lacher qui agit.
        if options.auRelachement and self.enGlissement then return end
        if onChange then onChange(valeur) end
    end

    -- Poser la valeur sans rien declencher : pour rafraichir la barre depuis
    -- l'exterieur sans rejouer l'action qu'elle commande.
    function c:Poser(valeur)
        self.valeur = math.floor(math.max(0, math.min(tonumber(valeur) or 0, self.max)))
        Poser()
    end

    function c:Regler(maximum, valeur)
        self.max = math.max(0, math.floor(tonumber(maximum) or 0))
        self.valeur = math.max(0, math.min(math.floor(tonumber(valeur) or 0), self.max))
        self:SetShown(self.max > 0)
        Poser()
    end

    -- Clic dans la gouttiere : un ecran de cote.
    c:SetScript("OnClick", function(self)
        local x = GetCursorPosition()
        x = x / (self:GetEffectiveScale() or 1)
        local milieu = (self.poignee:GetLeft() or 0) + self.poignee:GetWidth() / 2
        local page = math.max(40, self:GetWidth() * 0.9)
        self:Aller(self.valeur + ((x < milieu) and -page or page))
    end)
    c.poignee:SetScript("OnMouseDown", function(self)
        local x = GetCursorPosition()
        c.enGlissement = true
        -- La course est relevee au DEPART et ne bouge plus : si ce qu'on regle
        -- redimensionne la fenetre, la gouttiere change de taille sous la
        -- poignee, et une course recalculee a chaque image fait fuir le
        -- curseur. C'est le bug qu'on avait dans Necronicon.
        self.depart = { x = x / (self:GetEffectiveScale() or 1), valeur = c.valeur,
                        course = c:GetWidth() - self:GetWidth() }
        self:SetScript("OnUpdate", function(poignee)
            local course = poignee.depart and poignee.depart.course or 0
            if not poignee.depart or course <= 0 then return end
            local cx = GetCursorPosition()
            cx = cx / (poignee:GetEffectiveScale() or 1)
            c:Aller(poignee.depart.valeur + (cx - poignee.depart.x) / course * c.max)
        end)
    end)
    c.poignee:SetScript("OnMouseUp", function(self)
        self.depart = nil
        self:SetScript("OnUpdate", nil)
        if not c.enGlissement then return end
        c.enGlissement = false
        -- Le lacher applique ce qu'on a choisi.
        if options.auRelachement and onChange then onChange(c.valeur) end
    end)
    c:SetScript("OnSizeChanged", Poser)
    c:Hide()
    return c
end

-- Case a cocher du modele (UI.CreateStyledCheckbox) : une boite sombre,
-- bordure doree, coche doree. `onChange(coche)` au clic.
function UI.Case(parent, libelle, onChange)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    b.fond = UI.Aplat(b, { 0.10, 0.10, 0.10, 1 })
    b.fond:SetAllPoints(b)
    UI.Bordure(b, { 0.82, 0.66, 0.20, 1 })
    b.coche = UI.Aplat(b, { 0.82, 0.66, 0.20, 1 }, "ARTWORK")
    b.coche:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
    b.coche:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
    b.survol = UI.Aplat(b, { 0.90, 0.78, 0.30, 0.22 }, "HIGHLIGHT")
    b.survol:SetAllPoints(b)
    b.label = UI.Texte(parent, libelle or "", UI.C.texte, "GameFontNormalSmall")
    b.label:SetPoint("LEFT", b, "RIGHT", 6, 0)
    b.coche:Hide()
    function b:Cocher(v)
        self.cochee = v and true or false
        self.coche:SetShown(self.cochee)
    end
    function b:EstCochee() return self.cochee == true end
    b:SetScript("OnClick", function(self)
        self:Cocher(not self.cochee)
        if onChange then onChange(self.cochee) end
    end)
    -- Le libelle suit la case : il vit sur le parent, pas dans le bouton.
    b:HookScript("OnShow", function() b.label:Show() end)
    b:HookScript("OnHide", function() b.label:Hide() end)
    return b
end

-- ===== Glisser-deposer =====================================================
-- Repris de Necronicon (Inventory.lua : ShowInventoryDragGhost) : on glisse
-- une entree (une ligne du compendium), un fantome de 180 x 42 — icone et nom
-- — suit le curseur, et au relache l'emplacement survole la recoit s'il
-- l'accepte. Un emplacement s'inscrit avec UI.Glisser.Cible ; c'est lui qui
-- dit ce qu'il accepte, et il le dit aussi quand il refuse.

local Glisser = { cibles = {} }
UI.Glisser = Glisser

local function Fantome()
    if Glisser.fantome then return Glisser.fantome end
    local g = CreateFrame("Frame", nil, UIParent)
    g:SetFrameStrata("TOOLTIP")
    g:SetSize(180, 42)
    g:EnableMouse(false)
    g.fond = UI.Aplat(g, { 0.06, 0.06, 0.06, 0.72 })
    g.fond:SetAllPoints(g)
    UI.Bordure(g, { UI.C.bordureFine[1], UI.C.bordureFine[2], UI.C.bordureFine[3], 0.35 })
    g.icone = g:CreateTexture(nil, "ARTWORK")
    g.icone:SetSize(30, 30)
    g.icone:SetPoint("LEFT", g, "LEFT", 6, 0)
    g.nom = UI.Texte(g, "", UI.C.texte, "GameFontNormalSmall")
    g.nom:SetPoint("LEFT", g.icone, "RIGHT", 8, 0)
    g.nom:SetPoint("RIGHT", g, "RIGHT", -8, 0)
    g.nom:SetWordWrap(false)
    g:SetAlpha(0.78)
    g:SetScript("OnUpdate", function(self)
        -- Bouton relache : on depose (ou on abandonne) une fois, puis on range.
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            Glisser.Lacher()
            return
        end
        local x, y = GetCursorPosition()
        local echelle = UIParent:GetEffectiveScale() or 1
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / echelle + 14, y / echelle - 10)
    end)
    g:Hide()
    Glisser.fantome = g
    return g
end

-- `objet` : { icone, nom, ... } — le reste ne regarde que les cibles.
function Glisser.Commencer(objet)
    if type(objet) ~= "table" then return false end
    Glisser.objet = objet
    local g = Fantome()
    g.icone:SetTexture(objet.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
    g.nom:SetText(objet.nom or "Entrée")
    g:Show()
    return true
end

function Glisser.EnCours() return Glisser.objet ~= nil end

-- La cible survolee au relache, parmi celles qui sont affichees.
function Glisser.Lacher()
    local objet = Glisser.objet
    Glisser.objet = nil
    if Glisser.fantome then Glisser.fantome:Hide() end
    if not objet then return false end
    for _, cible in ipairs(Glisser.cibles) do
        if cible:IsVisible() and cible:IsMouseOver() then
            local ok, raison = cible.glisserAccepte(objet)
            if ok then
                cible.glisserDepose(objet)
                return true
            end
            if raison then LCM.Alerte(raison) end
            return false
        end
    end
    return false
end

-- `accepte(objet)` -> true, ou false et la raison ; `depose(objet)`.
function Glisser.Cible(frame, accepte, depose)
    frame.glisserAccepte, frame.glisserDepose = accepte, depose
    Glisser.cibles[#Glisser.cibles + 1] = frame
    -- Le survol pendant un glissement se voit : la case s'eclaire.
    frame.glisserSurvol = UI.Aplat(frame, { 0.95, 0.82, 0.38, 0.20 }, "OVERLAY")
    frame.glisserSurvol:SetAllPoints(frame)
    frame.glisserSurvol:Hide()
    frame:HookScript("OnEnter", function(self)
        if Glisser.objet and self.glisserAccepte(Glisser.objet) then self.glisserSurvol:Show() end
    end)
    frame:HookScript("OnLeave", function(self) self.glisserSurvol:Hide() end)
    return frame
end

-- ===== Menu contextuel (clic droit) ========================================
-- Repris de Necronicon (Inventory.lua : GetEntryContextMenu) : 150 de large,
-- lignes de 24 tous les 26, un sous-menu a droite pour « Deplacer > », et un
-- voile plein ecran qui ferme le menu au premier clic ailleurs.
-- `menu:Ouvrir(ancre, options)` ; une option : { label, action } ou
-- { label, sous = { { label, action }, ... } }.

function UI.MenuContexte()
    if UI.menuContexte then return UI.menuContexte end
    local m = CreateFrame("Frame", "LCM_MenuContexte", UIParent)
    m:SetFrameStrata("FULLSCREEN_DIALOG")
    m:SetSize(150, 92)
    m:EnableMouse(true)
    m.voile = CreateFrame("Frame", nil, UIParent)
    m.voile:SetFrameStrata("FULLSCREEN_DIALOG")
    m.voile:SetAllPoints(UIParent)
    m.voile:EnableMouse(true)
    m.voile:SetScript("OnMouseDown", function() m:Hide() end)
    m.voile:Hide()
    m.fond = UI.Aplat(m, { 0.05, 0.05, 0.05, 1 })
    m.fond:SetAllPoints(m)
    UI.BordureFine(m, 0.35)
    m.sous = CreateFrame("Frame", nil, m)
    m.sous:SetPoint("TOPLEFT", m, "TOPRIGHT", 4, 0)
    m.sous:SetSize(190, 1)
    m.sous:EnableMouse(true)
    m.sous.fond = UI.Aplat(m.sous, { 0.05, 0.05, 0.05, 1 })
    m.sous.fond:SetAllPoints(m.sous)
    UI.BordureFine(m.sous, 0.35)
    m.sous:Hide()
    m.lignes, m.sousLignes = {}, {}

    local function Ligne(parent, vivier, n)
        local l = vivier[n]
        if l then return l end
        l = CreateFrame("Button", nil, parent)
        l:SetHeight(24)
        l:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4 - (n - 1) * 26)
        l:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -4 - (n - 1) * 26)
        l.survol = UI.Aplat(l, { 0.80, 0.70, 0.40, 0.12 }, "HIGHLIGHT")
        l.survol:SetAllPoints(l)
        l.texte = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
        l.texte:SetPoint("LEFT", l, "LEFT", 8, 0)
        l.texte:SetPoint("RIGHT", l, "RIGHT", -8, 0)
        vivier[n] = l
        return l
    end

    local function Remplir(parent, vivier, options, sousMenu)
        for n, o in ipairs(options) do
            local l = Ligne(parent, vivier, n)
            l.option = o
            l.texte:SetText(o.label)
            l:SetScript("OnClick", function(self)
                if self.option.sous then
                    Remplir(m.sous, m.sousLignes, self.option.sous, true)
                    m.sous:Show()
                    return
                end
                m:Hide()
                if self.option.action then self.option.action() end
            end)
            l:Show()
        end
        for n = #options + 1, #vivier do vivier[n]:Hide() end
        parent:SetHeight(8 + #options * 26 - 2)
        if sousMenu and #options == 0 then parent:Hide() end
    end

    function m:Ouvrir(ancre, options)
        self.sous:Hide()
        Remplir(self, self.lignes, options)
        self:ClearAllPoints()
        if ancre then self:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", 0, -4)
        else self:SetPoint("CENTER", UIParent, "CENTER", 0, 0) end
        self.voile:Show()
        self:Show()
        self:Raise()
    end
    m:SetScript("OnHide", function(self) self.sous:Hide() self.voile:Hide() end)
    m:Hide()
    UI.menuContexte = m
    return m
end

-- ===== Petite saisie ======================================================
-- La fenetre « Quantite de la pile » de Necronicon (300 x 132) : un titre,
-- une saisie, Valider. `onValider(texte)` renvoie true, ou false et la
-- raison, qui s'affiche sans fermer.

function UI.Demande()
    if UI.demande then return UI.demande end
    local d = CreateFrame("Frame", "LCM_Demande", UIParent)
    d:SetSize(300, 132)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:EnableMouse(true)
    d.fond = UI.Aplat(d, { 0.05, 0.05, 0.05, 1 })
    d.fond:SetAllPoints(d)
    UI.BordureFine(d, 0.38)
    d.titre = UI.Texte(d, "", UI.C.titre, "GameFontNormalSmall")
    d.titre:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -12)
    d.fermer = UI.Bouton(d, "x", 16, 16, function() d:Hide() end)
    d.fermer:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -8)
    d.saisie = UI.Champ(d, 190, 24)
    d.saisie:SetMaxLetters(15)
    d.saisie:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -44)
    d.message = UI.Texte(d, "", UI.C.plein, "GameFontNormalSmall")
    d.message:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -74)
    d.message:SetPoint("TOPRIGHT", d, "TOPRIGHT", -12, -74)
    d.message:SetWordWrap(true)
    d.valider = UI.Bouton(d, "Valider", 82, 24, function()
        local ok, raison = d.onValider(d.saisie:GetText() or "")
        if ok then d:Hide() else d.message:SetText(raison or "") end
    end)
    d.valider:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 12)
    d.saisie:SetScript("OnEnterPressed", function() d.valider:Click() end)
    function d:Demander(titre, valeur, onValider)
        self.titre:SetText(titre)
        self.saisie:SetText(tostring(valeur or ""))
        self.message:SetText("")
        self.onValider = onValider
        self:Show()
        self:Raise()
        self.saisie:SetFocus()
    end
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = d:GetName() end
    d:Hide()
    UI.demande = d
    return d
end

-- ===== Choisir une icone ===================================================
-- Il y a des milliers d'icones dans le jeu, et une liste de milliers d'icones
-- n'aide personne. Celles qu'on propose sont celles qui servent DEJA dans la
-- campagne — le contenu du compendium, les portraits, le menu — plus ce que le
-- jeu veut bien nous donner (GetMacroIcons). La saisie a la main reste : une
-- icone qu'on connait se tape plus vite qu'elle ne se cherche.

local catalogueIcones

function UI.CatalogueIcones()
    if catalogueIcones then return catalogueIcones end
    local vues, out = {}, {}
    local function poser(chemin)
        chemin = tostring(chemin or "")
        if chemin == "" or vues[chemin:lower()] then return end
        vues[chemin:lower()] = true
        out[#out + 1] = chemin
    end
    -- Celles de la campagne, livrees avec l'addon, et celles des champs de
    -- fiche relevees dans le template : la liste finale est triee par nom, la
    -- recherche fait le reste.
    for _, chemin in ipairs(LCM.IconesCampagne()) do poser(chemin) end
    for _, chemin in pairs(LCM.ICONES_CHAMPS) do poser(chemin) end
    for _, categorie in ipairs(LCM.Body.CATEGORIES) do poser(categorie.icone) end
    for _, nom in ipairs({ "Objets", "Traits", "Races", "Etats", "Apprentissages", "Sacs",
                           "Devises", "Ressources", "Connaissances", "PNJ", "Grimoires" }) do
        local registre = LCM[nom]
        for _, element in ipairs((registre and registre.list) or {}) do poser(element.icone) end
    end
    for _, portrait in ipairs((LCM.Portraits and LCM.Portraits.list) or {}) do poser(portrait.texture) end
    if GetNumMacroIcons and GetMacroIconInfo then
        for index = 1, math.min(GetNumMacroIcons(), 600) do poser(GetMacroIconInfo(index)) end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    catalogueIcones = out
    return out
end

-- Un nom lisible pour une icone : la fin de son chemin.
function UI.NomIcone(chemin)
    return (tostring(chemin or ""):match("([^\\/]+)$")) or tostring(chemin or "")
end

function UI.SelecteurIcone(cle)
    local d = CreateFrame("Frame", "LCM_Icones_" .. tostring(cle), UIParent)
    d:SetSize(340, 300)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetClampedToScreen(true)
    d:EnableMouse(true)
    d.fond = UI.Aplat(d, UI.C.fond)
    d.fond:SetAllPoints(d)
    if UI.AelCadre then d.cadre = UI.AelCadre(d, "section") else UI.Bordure(d) end

    d.titre = UI.Texte(d, "Icône", UI.C.titre, "GameFontNormalSmall")
    d.titre:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -9)
    d.fermer = UI.Bouton(d, "x", 18, 18, function() d:Hide() end)
    d.fermer:SetPoint("TOPRIGHT", d, "TOPRIGHT", -6, -6)

    d.recherche = UI.Champ(d, 300, 22, function(texte) d:Remplir(texte) end)
    d.recherche:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -28)

    d.zone = UI.Defilement(d)
    d.zone:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -56)
    d.zone:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -10, 10)
    d.cases = {}

    local TAILLE, PAR_RANGEE = 30, 9

    function d:Remplir(filtre)
        filtre = tostring(filtre or ""):lower()
        local nombre = 0
        for _, chemin in ipairs(UI.CatalogueIcones()) do
            if filtre == "" or chemin:lower():find(filtre, 1, true) then
                nombre = nombre + 1
                local b = self.cases[nombre]
                if not b then
                    b = CreateFrame("Button", nil, self.zone.contenu)
                    b:SetSize(TAILLE - 2, TAILLE - 2)
                    b.icone = b:CreateTexture(nil, "ARTWORK")
                    b.icone:SetAllPoints(b)
                    b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    b.survol = UI.Aplat(b, UI.C.survol, "HIGHLIGHT")
                    b.survol:SetAllPoints(b)
                    b:SetScript("OnClick", function(soi)
                        self:Hide()
                        if self.onChoix then self.onChoix(soi.chemin) end
                    end)
                    UI.Bulle(b, function(soi) return UI.NomIcone(soi.chemin) end, nil, 0.4)
                    self.cases[nombre] = b
                end
                b.chemin = chemin
                b.icone:SetTexture(chemin)
                local rangee = math.floor((nombre - 1) / PAR_RANGEE)
                local colonne = (nombre - 1) % PAR_RANGEE
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", colonne * TAILLE, -rangee * TAILLE)
                b:Show()
            end
            if nombre >= 400 then break end
        end
        for index = nombre + 1, #self.cases do self.cases[index]:Hide() end
        self.zone.decalage = 0
        self.zone:Regler(math.ceil(nombre / PAR_RANGEE) * TAILLE)
        self.nombreAffiche = nombre
    end

    function d:Proposer(ancre, onChoix)
        self.onChoix = onChoix
        self.recherche:SetText("")
        self:Remplir("")
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", 0, -4)
        UI.Devant(self)
        self:Show()
    end

    d:Hide()
    return d
end
