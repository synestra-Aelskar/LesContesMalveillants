-- Selection du personnage.
--
-- Une liste a gauche, un carrousel de cartes a droite : la carte du milieu est
-- grande et nette, ses voisines sont plus petites et en retrait. C'est la seule
-- fenetre de l'addon qui montre des artworks, donc la seule qui a le droit
-- d'etre large.
--
-- Ouverte par le clic droit sur le sceau du menu radial.

local _, LCM = ...
local UI = LCM.UI
local Personnages = LCM.Personnages
local Portraits = LCM.Portraits

local Ecran = {}
UI.Personnages = Ecran

local LARGEUR_LISTE = 196
local CARTE = { largeur = 208, hauteur = 318 }
local VOISINE = { largeur = 158, hauteur = 242 }
local ECART = 190      -- distance du centre a une carte voisine
local PIED = 32        -- hauteur du bandeau du nom

-- ===== Une carte ===========================================================

local function Carte(parent)
    local c = CreateFrame("Button", nil, parent)
    c:SetSize(CARTE.largeur, CARTE.hauteur)

    c.fond = UI.Aplat(c, UI.C.fond)
    c.fond:SetAllPoints(c)
    c.traits = UI.Bordure(c)

    -- L'artwork occupe toute la carte sauf le bandeau du nom.
    c.art = c:CreateTexture(nil, "ARTWORK")
    c.art:SetPoint("TOPLEFT", c, "TOPLEFT", 2, -2)
    c.art:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -2, PIED)

    c.bandeau = UI.Aplat(c, { 0.04, 0.03, 0.03, 0.96 }, "OVERLAY")
    c.bandeau:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 2, 2)
    c.bandeau:SetPoint("TOPRIGHT", c, "BOTTOMRIGHT", -2, PIED)

    c.nom = UI.Texte(c, "", UI.C.titre, "GameFontNormal")
    c.nom:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 6, 8)
    c.nom:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -6, 8)
    c.nom:SetJustifyH("CENTER")

    -- Le niveau, en haut a gauche, dans son propre cadre.
    c.niveau = CreateFrame("Frame", nil, c)
    c.niveau:SetSize(34, 24)
    c.niveau:SetPoint("TOPLEFT", c, "TOPLEFT", 6, -6)
    c.niveau.fond = UI.Aplat(c.niveau, { 0.04, 0.03, 0.03, 0.92 })
    c.niveau.fond:SetAllPoints(c.niveau)
    UI.Bordure(c.niveau)
    c.niveau.label = UI.Texte(c.niveau, "", UI.C.accent, "GameFontNormalSmall")
    c.niveau.label:SetAllPoints(c.niveau)
    c.niveau.label:SetJustifyH("CENTER")
    c.niveau.label:SetJustifyV("MIDDLE")

    c.marque = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
    c.marque:SetPoint("TOP", c, "TOP", 0, -10)
    c.marque:SetJustifyH("CENTER")

    c.survol = UI.Aplat(c, UI.C.survol, "HIGHLIGHT")
    c.survol:SetAllPoints(c)

    function c:Habiller(entity, centrale)
        self.entity = entity
        self:SetSize(centrale and CARTE.largeur or VOISINE.largeur,
                     centrale and CARTE.hauteur or VOISINE.hauteur)
        self:SetAlpha(centrale and 1 or 0.55)
        if not entity then self:Hide() return end

        local mode = Portraits.Appliquer(self.art, entity)
        -- Une icone ne doit pas s'etirer sur toute la carte ; un artwork ou une
        -- silhouette, si.
        self.art:ClearAllPoints()
        if mode ~= "icone" then
            self.art:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -2)
            self.art:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, PIED)
        else
            self.art:SetPoint("CENTER", self, "CENTER", 0, PIED / 2)
            self.art:SetSize(72, 72)
        end

        self.nom:SetText(tostring(entity.name))
        self.nom:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
        self.niveau.label:SetText(tostring(LCM.Entities.Get_Value(entity, "niveau") or ""))
        self.niveau:SetShown(centrale or false)
        self.marque:SetText(entity.id == Personnages.ActifId() and "· en jeu ·" or "")
        self:Show()
    end

    return c
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("personnages", "Selection du personnage", 860, 540)
    Ecran.frame = f
    f.index = 1

    -- ----- la liste -------------------------------------------------------
    f.liste = CreateFrame("Frame", nil, f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.liste:SetWidth(LARGEUR_LISTE)
    f.liste.fond = UI.Aplat(f.liste, UI.C.fondClair)
    f.liste.fond:SetAllPoints(f.liste)
    UI.Bordure(f.liste)
    f.liste.boutons = {}

    f.liste.titre = UI.Texte(f.liste, "Liste des personnages", UI.C.texte, "GameFontNormalSmall")
    f.liste.titre:SetPoint("TOPLEFT", f.liste, "TOPLEFT", 12, -12)

    f.creer = UI.Bouton(f.liste, "+  Créer un personnage", LARGEUR_LISTE - 24, 24, function()
        Ecran.Creer()
    end)
    f.creer:SetPoint("BOTTOMLEFT", f.liste, "BOTTOMLEFT", 12, 12)

    -- ----- la scene -------------------------------------------------------
    f.scene = CreateFrame("Frame", nil, f.contenu)
    f.scene:SetPoint("TOPLEFT", f.liste, "TOPRIGHT", 12, 0)
    f.scene:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.vide = UI.Texte(f.scene, "", UI.C.discret, "GameFontNormal")
    f.vide:SetPoint("CENTER", f.scene, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")

    -- Trois cartes, pas une de plus : au-dela, la quatrieme sort de la fenetre
    -- et on ne fait que payer des cadres invisibles.
    f.cartes = {}
    for place = -1, 1 do
        local c = Carte(f.scene)
        c.place = place
        c:SetPoint("CENTER", f.scene, "CENTER", place * ECART, 16)
        c:SetScript("OnClick", function(bouton)
            if bouton.place == 0 then
                if bouton.entity then f:Jouer(bouton.entity) end
            else
                f:Decaler(bouton.place)
            end
        end)
        f.cartes[place] = c
    end
    -- La carte du milieu passe devant ses voisines.
    f.cartes[0]:SetFrameLevel(f.scene:GetFrameLevel() + 4)

    f.jouer = UI.Bouton(f.scene, "Jouer ce personnage", 180, 24, function()
        local entity = f:Courant()
        if entity then f:Jouer(entity) end
    end)
    f.jouer:SetPoint("BOTTOM", f.scene, "BOTTOM", -60, 6)

    -- Effacer un personnage ne se rattrape pas : on demande confirmation, et le
    -- nom est dans la question — pour ne pas supprimer le mauvais.
    f.confirmation = UI.Confirmer(f, "", "Supprimer")
    f.supprimer = UI.Bouton(f.scene, "Supprimer", 100, 24, function()
        local entity = f:Courant()
        if not entity then return end
        f.confirmation:Demander(
            string.format("Supprimer %s ?\nSa fiche et tout ce qu'elle contient sont perdus.",
                tostring(entity.name)),
            function()
                local nom = tostring(entity.name)
                Personnages.Supprimer(entity.id)
                LCM.Ok(string.format("%s a ete supprime.", nom))
                f:Rafraichir()
            end)
    end)
    f.supprimer:SetPoint("LEFT", f.jouer, "RIGHT", 8, 0)

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta) f:Decaler(delta > 0 and -1 or 1) end)

    -- ----- comportement ---------------------------------------------------

    function f:Courant()
        return self.profils and self.profils[self.index] or nil
    end

    -- Le voisin a `pas` crans. Il boucle a partir de trois personnages : a deux,
    -- afficher le meme des deux cotes donnerait un carrousel menteur.
    function f:Voisin(pas)
        local nombre = #(self.profils or {})
        if nombre == 0 then return nil end
        if nombre == 1 then return pas == 0 and self.profils[1] or nil end
        if nombre == 2 and pas ~= 0 then
            local autre = (self.index == 1) and 2 or 1
            return pas == 1 and self.profils[autre] or nil
        end
        return self.profils[((self.index - 1 + pas) % nombre) + 1]
    end

    function f:Decaler(pas)
        local nombre = #(self.profils or {})
        if nombre < 2 then return end
        self.index = ((self.index - 1 + pas) % nombre) + 1
        self:Afficher()
    end

    function f:Jouer(entity)
        Personnages.Choisir(entity.id)
        LCM.Ok(string.format("tu joues %s.", tostring(entity.name)))
        self:Afficher()
    end

    function f:Afficher()
        local nombre = #(self.profils or {})
        for place = -1, 1 do
            self.cartes[place]:Habiller(self:Voisin(place), place == 0)
        end
        self.jouer:SetShown(nombre > 0)
        self.supprimer:SetShown(nombre > 0)
        self.vide:SetText(nombre > 0 and "" or
            "Aucun personnage.\nLe bouton « Créer un personnage » ouvre la création.")

        for index, profil in ipairs(self.profils or {}) do
            local b = self.liste.boutons[index]
            if not b then
                b = UI.Bouton(self.liste, "", LARGEUR_LISTE - 24, 20, function()
                    self.index = index
                    self:Afficher()
                end)
                b:SetPoint("TOPLEFT", self.liste, "TOPLEFT", 12, -34 - (index - 1) * 22)
                b.label:SetJustifyH("LEFT")
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                self.liste.boutons[index] = b
            end
            b.label:SetText(string.format("%s  -  %s",
                tostring(LCM.Entities.Get_Value(profil, "niveau") or "?"), tostring(profil.name)))
            b:Selectionner(index == self.index)
            b:Show()
        end
        for index = nombre + 1, #self.liste.boutons do self.liste.boutons[index]:Hide() end
    end

    function f:Rafraichir()
        self.profils = Personnages.Liste()
        self.index = math.max(1, math.min(self.index, math.max(1, #self.profils)))
        self:Afficher()
    end

    -- Ouvre sur le personnage joue plutot que sur le premier de la liste.
    function f:Montrer()
        self.profils = Personnages.Liste()
        local actif = Personnages.ActifId()
        self.index = 1
        for index, entity in ipairs(self.profils) do
            if entity.id == actif then self.index = index end
        end
        self:Afficher()
        self:Show()
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Ouvrir()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() return f end
    f:Montrer()
    return f
end

-- La creation prend toute la place : les deux fenetres cote a cote se
-- recouvrent et on ne sait plus laquelle on manipule. On efface donc la
-- selection, et elle revient quand la creation se ferme.
function Ecran.Creer()
    if not (UI.Creation and UI.Creation.Ouvrir) then
        LCM.Alerte("la creation de personnage n'est pas encore disponible.")
        return
    end
    local ouverte = Ecran.frame and Ecran.frame:IsShown()
    if ouverte then Ecran.frame:Hide() end
    local creation = UI.Creation.Ouvrir()
    creation.retourSelection = ouverte or nil
end

LCM.AddCommand("personnages", "choisir son personnage", function() Ecran.Ouvrir() end)
