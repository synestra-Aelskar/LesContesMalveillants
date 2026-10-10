-- L'atelier des bannieres : de quoi a l'air le nom d'un lieu.
--
-- Le catalogue et la tenue des themes sont dans Core/Bannieres.lua, le rendu
-- dans UI/Banniere.lua. Ici, c'est l'etabli du MJ.
--
-- Deux partis pris, par rapport a l'atelier d'Omega Hub dont tout ceci vient :
--
--   * LE FORMULAIRE EST ENGENDRE par `Bannieres.CHAMPS`, pas pose a la main.
--     Vingt-quatre reglages ecrits un par un, ce sont vingt-quatre occasions
--     d'oublier d'en brancher un le jour ou on en ajoute un vingt-cinquieme.
--     Ici, ajouter une ligne a la table suffit, des deux cotes ;
--   * PAS DE GALERIE DE VIGNETTES. Les quarante-deux compositions pesent un
--     mega-octet chacune : les afficher ensemble, c'est quarante-deux
--     mega-octets de textures pour en choisir une. La liste deroulante les
--     range par famille, et l'APERCU en dessous montre celle qu'on survole —
--     c'est la meme chose, en une image a la fois.
--
-- L'apercu n'est pas une imitation : c'est le meme afficheur que la vraie
-- banniere (`UI.Banniere.Creer`). Un apercu qui ment ne sert a rien.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local Ecran = {}
UI.BannieresMJ = Ecran
MJ.Bannieres = Ecran

local LARGEUR, HAUTEUR = 840, 620
local COLONNE = 210
local LIGNE = 22
-- La boite d'apercu, en bas du volet de droite.
local APERCU_H = 170

local function B() return LCM.Bannieres end

local function Dire(ok, raison)
    if not ok and raison then LCM.Alerte(tostring(raison)) end
    return ok
end

-- Les listes de choix d'un champ, dans l'ordre d'affichage.
local function Options(cle)
    local b = B()
    local out = {}
    if cle == "composition" then
        for _, c in ipairs(b.COMPOSITIONS) do
            out[#out + 1] = { id = c.id, label = c.label, groupe = c.groupe }
        end
    elseif cle == "police" then
        for _, id in ipairs(b.ORDRE_POLICES) do
            out[#out + 1] = { id = id, label = b.POLICES[id].label }
        end
    elseif cle == "separateur" then
        for _, id in ipairs(b.ORDRE_SEPARATEURS) do
            out[#out + 1] = { id = id, label = b.SEPARATEURS[id] }
        end
    elseif cle == "cadre" then
        for _, id in ipairs(b.ORDRE_CADRES) do
            out[#out + 1] = { id = id, label = b.CADRES[id] }
        end
    elseif cle == "mouvement" then
        for _, id in ipairs(b.ORDRE_MOUVEMENTS) do
            out[#out + 1] = { id = id, label = b.MOUVEMENTS[id] }
        end
    elseif cle == "placement" then
        for _, id in ipairs(b.ORDRE_PLACEMENTS) do
            out[#out + 1] = { id = id, label = b.PLACEMENTS[id] }
        end
    end
    return out
end

local function LibelleChoix(cle, valeur)
    for _, o in ipairs(Options(cle)) do
        if o.id == valeur then return o.label end
    end
    return tostring(valeur or "—")
end

-- Une couleur, en six (ou huit) chiffres hexadecimaux.
local function VersHexa(c, avecAlpha)
    if type(c) ~= "table" then return "" end
    local t = string.format("%02X%02X%02X",
        math.floor((c[1] or 0) * 255 + 0.5),
        math.floor((c[2] or 0) * 255 + 0.5),
        math.floor((c[3] or 0) * 255 + 0.5))
    if avecAlpha then t = t .. string.format("%02X", math.floor((c[4] or 1) * 255 + 0.5)) end
    return t
end

local function DepuisHexa(texte, avecAlpha)
    texte = tostring(texte or ""):upper():gsub("[^0-9A-F]", "")
    if #texte ~= (avecAlpha and 8 or 6) and #texte ~= 6 then return nil end
    local c = {
        tonumber(texte:sub(1, 2), 16) / 255,
        tonumber(texte:sub(3, 4), 16) / 255,
        tonumber(texte:sub(5, 6), 16) / 255,
    }
    if avecAlpha then
        c[4] = (#texte == 8) and (tonumber(texte:sub(7, 8), 16) / 255) or 1
    end
    return c
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("bannieres_mj", "Atelier des bannières", LARGEUR, HAUTEUR, { x = 20, y = 0 })
    Ecran.frame = f
    f.lignes = {}
    f.rangees = {}

    -- ----- colonne de gauche : la bibliotheque -----------------------------
    f.titreListe = UI.Texte(f.contenu, "Thèmes", UI.C.titre)
    UI.Police(f.titreListe, 12)
    f.titreListe:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)

    f.nouveau = UI.Champ(f.contenu, COLONNE - 92, 20, nil)
    f.nouveau:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -20)
    f.creer = UI.Bouton(f.contenu, "+ Thème", 86, 20, function()
        local theme, raison = B().Creer(f.nouveau:GetText())
        if not theme then LCM.Alerte(tostring(raison)) return end
        f.nouveau:SetText("")
        Ecran.theme = theme.id
        f:Afficher()
    end)
    f.creer:SetPoint("LEFT", f.nouveau, "RIGHT", 6, 0)

    f.liste = UI.Defilement(f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -48)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 52)
    f.liste:SetWidth(COLONNE)

    f.vide = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("TOPLEFT", f.liste, "TOPLEFT", 4, -4)
    f.vide:SetWidth(COLONNE - 12)
    f.vide:SetWordWrap(true)
    f.vide:SetJustifyH("LEFT")

    f.dupliquer = UI.Bouton(f.contenu, "Dupliquer", COLONNE / 2 - 3, 20, function()
        local copie = B().Dupliquer(Ecran.theme)
        if copie then Ecran.theme = copie.id end
        f:Afficher()
    end)
    f.dupliquer:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 26)
    f.retirer = UI.Bouton(f.contenu, "Retirer", COLONNE / 2 - 3, 20, function()
        local theme = B().Get(Ecran.theme)
        if not theme then return end
        f.confirmation:Demander(string.format("Retirer le thème « %s » ?", tostring(theme.nom)),
            function()
                if Dire(B().Retirer(Ecran.theme)) then
                    Ecran.theme = nil
                    f:Afficher()
                end
            end)
    end)
    f.retirer:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMLEFT", COLONNE, 26)
    f.renvoyer = UI.Bouton(f.contenu, "Tout renvoyer au groupe", COLONNE, 20, function()
        LCM.Ok(string.format("%d thème(s) renvoyé(s).", B().Renvoyer()))
    end)
    f.renvoyer:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)

    f.filet = UI.Filet(f.contenu, true, true)
    f.filet:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 12, 0)
    f.filet:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", COLONNE + 12, 0)

    -- ----- volet de droite : le nom, le formulaire, l'apercu ---------------
    local X = COLONNE + 24
    local largeur = LARGEUR - 24 - X

    f.nomLabel = UI.Texte(f.contenu, "Nom", UI.C.libelle)
    UI.Police(f.nomLabel, 11)
    f.nomLabel:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", X, -2)
    f.nom = UI.Champ(f.contenu, largeur - 150, 20, nil)
    f.nom:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", X + 34, 0)
    f.renommer = UI.Bouton(f.contenu, "Renommer", 96, 20, function()
        Dire(B().Renommer(Ecran.theme, f.nom:GetText()))
        f:Afficher()
    end)
    f.renommer:SetPoint("LEFT", f.nom, "RIGHT", 6, 0)

    f.formulaire = UI.Defilement(f.contenu)
    f.formulaire:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", X, -28)
    f.formulaire:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, APERCU_H + 10)

    -- La boite d'apercu. Elle rogne ce qui depasse : une banniere large se
    -- met a l'echelle, mais on ne lui demande pas de rentrer au chausse-pied.
    f.boite = CreateFrame("Frame", nil, f.contenu)
    f.boite:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", X, 0)
    f.boite:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.boite:SetHeight(APERCU_H)
    f.boite:SetClipsChildren(true)
    f.boite.fond = UI.Aplat(f.boite, { 0.02, 0.02, 0.02, 0.85 })
    f.boite.fond:SetAllPoints(f.boite)
    UI.Bordure(f.boite, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.35 })

    f.apercu = UI.Banniere.Creer(f.boite, nil, false)
    f.apercu:ClearAllPoints()
    f.apercu:SetPoint("CENTER", f.boite, "CENTER", 0, -10)
    f.apercu:SetFrameStrata("DIALOG")

    f.titreApercu = UI.Champ(f.contenu, 170, 18, nil)
    f.titreApercu:SetPoint("BOTTOMLEFT", f.boite, "TOPLEFT", 2, 3)
    f.titreApercu:SetText("Les Marches Grises")
    f.sousApercu = UI.Champ(f.contenu, 150, 18, nil)
    f.sousApercu:SetPoint("LEFT", f.titreApercu, "RIGHT", 6, 0)
    f.sousApercu:SetText("Porte du Nord")
    f.rejouer = UI.Bouton(f.contenu, "Rejouer", 80, 18, function() f:Apercu(true) end)
    f.rejouer:SetPoint("LEFT", f.sousApercu, "RIGHT", 6, 0)
    f.enJeu = UI.Bouton(f.contenu, "Voir en jeu", 90, 18, function()
        local theme = B().Get(Ecran.theme)
        if not theme then return end
        UI.Banniere.Montrer(f.titreApercu:GetText(), f.sousApercu:GetText(), theme)
    end)
    f.enJeu:SetPoint("LEFT", f.rejouer, "RIGHT", 6, 0)

    f.confirmation = UI.Confirmer(f, "", "Retirer")

    -- ----- une rangee de formulaire, selon la nature du champ --------------
    local largeurForm = largeur - 20

    local function Rangee(rang, champ)
        local r = f.rangees[rang]
        if r and r.nature == champ.nature then return r end
        if r then r:Hide() end

        r = CreateFrame("Frame", nil, f.formulaire.contenu)
        r:SetHeight(24)
        r.nature = champ.nature
        r.label = UI.Texte(r, "", UI.C.libelle)
        UI.Police(r.label, 11)
        r.label:SetPoint("LEFT", r, "LEFT", 4, 0)
        r.label:SetWidth(170)
        r.label:SetJustifyH("LEFT")
        r.label:SetWordWrap(false)

        local function Poser(w) w:SetPoint("LEFT", r, "LEFT", 180, 0) return w end

        if champ.nature == "oui" then
            r.case = UI.Case(r, "", function(cochee)
                Dire(B().Definir(Ecran.theme, r.cle, cochee))
                f:Apercu()
            end)
            Poser(r.case)
        elseif champ.nature == "choix" then
            r.bouton = UI.Bouton(r, "", 200, 20, function(bouton)
                local options = Options(r.cle)
                if #options == 0 then return end
                f.choix = f.choix or UI.Choix("banniere_choix", "Choisir")
                f.choix:Proposer(bouton, options, function(id)
                    Dire(B().Definir(Ecran.theme, r.cle, id))
                    f:Afficher()
                end)
            end)
            Poser(r.bouton)
        elseif champ.nature == "couleur" or champ.nature == "couleurA" then
            r.pastille = CreateFrame("Frame", nil, r)
            r.pastille:SetSize(20, 16)
            Poser(r.pastille)
            r.pastille.aplat = UI.Aplat(r.pastille, { 1, 1, 1, 1 })
            r.pastille.aplat:SetAllPoints(r.pastille)
            UI.Bordure(r.pastille, { 0.5, 0.45, 0.3, 0.8 })
            r.saisie = UI.Champ(r, 86, 20, nil)
            r.saisie:SetPoint("LEFT", r.pastille, "RIGHT", 6, 0)
            r.ok = UI.Bouton(r, "OK", 34, 20, function()
                local c = DepuisHexa(r.saisie:GetText(), r.nature == "couleurA")
                if not c then
                    LCM.Alerte("une couleur s'écrit en six chiffres hexadécimaux, "
                        .. "ou huit avec l'opacité.")
                    return
                end
                Dire(B().Definir(Ecran.theme, r.cle, c))
                f:Afficher()
            end)
            r.ok:SetPoint("LEFT", r.saisie, "RIGHT", 6, 0)
            r.aide = UI.Texte(r, "", UI.C.discret)
            UI.Police(r.aide, 10)
            r.aide:SetPoint("LEFT", r.ok, "RIGHT", 8, 0)
        else
            r.saisie = UI.Champ(r, (champ.nature == "texte") and 220 or 70, 20, nil)
            Poser(r.saisie)
            r.ok = UI.Bouton(r, "OK", 34, 20, function()
                Dire(B().Definir(Ecran.theme, r.cle, r.saisie:GetText()))
                f:Afficher()
            end)
            r.ok:SetPoint("LEFT", r.saisie, "RIGHT", 6, 0)
            r.aide = UI.Texte(r, "", UI.C.discret)
            UI.Police(r.aide, 10)
            r.aide:SetPoint("LEFT", r.ok, "RIGHT", 8, 0)
        end

        f.rangees[rang] = r
        return r
    end

    -- ----- l'apercu ---------------------------------------------------------
    function f:Apercu(rejouer)
        local theme = B().Get(Ecran.theme)
        if not theme then
            self.apercu:Cacher()
            return
        end
        local titre = self.titreApercu:GetText()
        if titre == "" then titre = "Les Marches Grises" end
        local sous = self.sousApercu:GetText()
        -- On compose d'abord : c'est ce qui donne sa taille a la banniere, et
        -- c'est de la qu'on deduit de combien la reduire pour tenir dans la
        -- boite.
        self.apercu:Composer(titre, sous, theme)
        local l, h = self.apercu:GetWidth(), self.apercu:GetHeight()
        local k = 1
        if l and h and l > 0 and h > 0 then
            k = math.min(1, (self.boite:GetWidth() - 12) / l, (APERCU_H - 24) / h)
        end
        self.apercu:SetScale(math.max(0.25, k))
        self.apercu:ClearAllPoints()
        self.apercu:SetPoint("CENTER", self.boite, "CENTER", 0, 0)
        if rejouer then
            self.apercu:Montrer(titre, sous, theme)
            self.apercu:SetScale(math.max(0.25, k))
            self.apercu:ClearAllPoints()
            self.apercu:SetPoint("CENTER", self.boite, "CENTER", 0, 0)
        else
            -- Sans rejouer, on montre l'etat « pose » : pleine opacite, sans
            -- animation. C'est ce qu'on veut en reglant une couleur.
            self.apercu:SetScript("OnUpdate", nil)
            self.apercu:SetAlpha(1)
            self.apercu:Show()
        end
    end

    function f:Afficher()
        if not LCM.IsMaster() then
            self.vide:SetText("Réservé au maître du jeu.")
            return
        end
        local b = B()
        local themes = b.Liste()

        local y = 0
        for rang, theme in ipairs(themes) do
            local l = self.lignes[rang]
            if not l then
                l = CreateFrame("Button", nil, self.liste.contenu)
                l:SetHeight(LIGNE - 2)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.survol = UI.Aplat(l, UI.C.survol, "HIGHLIGHT")
                l.survol:SetAllPoints(l)
                l.nom = UI.Texte(l, "", UI.C.texte)
                UI.Police(l.nom, 11)
                l.nom:SetPoint("LEFT", l, "LEFT", 6, 0)
                l.nom:SetWordWrap(false)
                l.note = UI.Texte(l, "", UI.C.discret)
                UI.Police(l.note, 10)
                l.note:SetPoint("RIGHT", l, "RIGHT", -6, 0)
                l:SetScript("OnClick", function(self2)
                    Ecran.theme = self2.themeId
                    f:Afficher()
                end)
                self.lignes[rang] = l
            end
            l.themeId = theme.id
            l.nom:SetText(tostring(theme.nom))
            l.note:SetText(b.AMoi(theme) and "" or "reçu")
            local couleur = (Ecran.theme == theme.id) and UI.C.accent or UI.C.texte
            l.nom:SetTextColor(couleur[1], couleur[2], couleur[3])
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.liste.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.liste.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE
        end
        for rang = #themes + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.liste:Regler(math.max(1, y))
        self.vide:SetText(#themes > 0 and ""
            or "Aucun thème. Nomme-en un : il part du rendu d'origine, et tu le "
            .. "changes ensuite.")

        local theme = Ecran.theme and b.Get(Ecran.theme) or nil
        if not theme then Ecran.theme = nil end
        local mien = theme ~= nil and b.AMoi(theme)

        self.nomLabel:SetShown(theme ~= nil)
        self.nom:SetShown(theme ~= nil)
        self.renommer:SetShown(mien)
        self.dupliquer:SetShown(theme ~= nil)
        self.retirer:SetShown(mien)
        for _, w in ipairs({ self.titreApercu, self.sousApercu, self.rejouer, self.enJeu }) do
            w:SetShown(theme ~= nil)
        end

        if not theme then
            for _, r in pairs(self.rangees) do r:Hide() end
            self.formulaire:Regler(1)
            self.apercu:Cacher()
            return
        end

        if not self.nom:HasFocus() then self.nom:SetText(tostring(theme.nom)) end

        local yf = 0
        for rang, champ in ipairs(b.CHAMPS) do
            local r = Rangee(rang, champ)
            r.cle = champ.cle
            r.label:SetText(champ.label)
            local valeur = b.Valeur(theme, champ.cle)

            if champ.nature == "oui" then
                r.case:Cocher(valeur and true or false)
            elseif champ.nature == "choix" then
                r.bouton.label:SetText(LibelleChoix(champ.cle, valeur))
            elseif champ.nature == "couleur" or champ.nature == "couleurA" then
                local avecAlpha = champ.nature == "couleurA"
                r.pastille.aplat:SetColorTexture(valeur[1] or 0, valeur[2] or 0,
                    valeur[3] or 0, 1)
                if not r.saisie:HasFocus() then r.saisie:SetText(VersHexa(valeur, avecAlpha)) end
                r.aide:SetText(avecAlpha and "RRVVBBOO" or "RRVVBB")
            else
                if not r.saisie:HasFocus() then r.saisie:SetText(tostring(valeur or "")) end
                if champ.min and champ.max then
                    r.aide:SetText(string.format("de %s à %s", tostring(champ.min), tostring(champ.max)))
                else
                    r.aide:SetText("")
                end
            end

            -- Un theme recu se lit, il ne se modifie pas : on eteint ce qui
            -- ecrirait plutot que de laisser cliquer pour rien.
            for _, w in ipairs({ r.case, r.bouton, r.saisie, r.ok }) do
                if w then w:SetShown(mien) end
            end
            if r.case and r.case.label then r.case.label:SetShown(false) end

            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", self.formulaire.contenu, "TOPLEFT", 0, -yf)
            r:SetWidth(largeurForm)
            r:Show()
            yf = yf + 26
        end
        for rang = #b.CHAMPS + 1, #self.rangees do self.rangees[rang]:Hide() end
        self.formulaire:Regler(math.max(1, yf))

        self:Apercu()
    end

    function f:Montrer()
        self:Afficher()
        self:Show()
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer(themeId)
    local f = Ecran.Fenetre()
    if themeId then Ecran.theme = themeId end
    if f:IsShown() and not themeId then f:Hide() else f:Montrer() end
    return f
end

LCM.WhenReady(function()
    LCM.AddCommand("atelier-bannieres", "l'atelier des bannières", function()
        Ecran.Basculer()
    end, true)

    local avant = LCM.Bannieres.onChange
    LCM.Bannieres.onChange = function(...)
        if avant then avant(...) end
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
        -- L'atelier des lieux montre le nom du theme de chaque lieu.
        local lieux = UI.LieuxMJ and UI.LieuxMJ.frame
        if lieux and lieux:IsShown() then lieux:Afficher() end
    end
end)
