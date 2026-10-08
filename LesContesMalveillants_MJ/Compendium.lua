-- Editeur d'entree du compendium, pour le maitre du jeu.
--
-- Reprise de la fenetre « Configuration entree » de Necronicon
-- (CreateCompendiumFrame > entryConfigPopup, RefreshCompendiumEntryPrimary-
-- Tabs, LayoutCompendiumEntryConfigTab, RefreshCompendiumEntryFolderTabs,
-- RefreshCompendiumEntryDisplayEditors) : un onglet « General » (fond,
-- titre, nom, tags, ID, pile max, icone), puis un onglet par genre de champ
-- present dans la categorie (Textes courts, Statistiques — avec ses dossiers
-- —, Textes longs, Tables, Jauges, Listes, Liens compendium), « Etendre » et
-- « Minimiser », OK et Annuler.
--
-- Ce qui change : ce qu'on enregistre est un BROUILLON (MJ/Brouillons.lua),
-- verifie par le registre de la famille ; un refus s'affiche avec sa raison,
-- rien n'est corrige en douce. Le contenu publie (un fichier genere) s'ouvre
-- en lecture : c'est le fichier qui fait foi, on le corrige en le dupliquant.
-- Pas d'onglet « Actions » (jet, macro, Arcanum) : aucune entree du template
-- ne s'en sert et l'addon n'a pas encore de moteur d'actions. Pas
-- d'« Exporter (code) » : l'echange passe par l'export des brouillons.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local C = LCM.Compendium
local Brouillons = MJ.Brouillons

local Editeur = {}
MJ.CompendiumEditeur = Editeur
-- Expose comme LCM.Brouillons l'est : le compagnon vit dans son propre espace,
-- mais ce qu'il ouvre doit etre atteignable depuis l'addon de base (et depuis
-- le banc, qui ne connait que LCM).
LCM.CompendiumEditeur = Editeur

local LARGEUR, HAUTEUR, MIN_L, MIN_H = 760, 640, 650, 500

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function Action(parent, texte, hauteur)
    return UI.Bouton(parent, texte, math.max(18, #tostring(texte) * 7 + 10), hauteur or 16)
end

local function Peindre(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

-- ===== Genres de champ et onglets ==========================================

-- Le genre d'un champ (FIELD_TYPE_OPTIONS du template), qui decide de son
-- onglet. L'ordre est celui des onglets.
local GENRES = {
    { id = "text",             label = "Textes courts" },
    { id = "statistic",        label = "Statistiques" },
    { id = "longtext",         label = "Textes longs" },
    { id = "table",            label = "Tables" },
    { id = "gauge",            label = "Jauges" },
    { id = "list_from",        label = "Listes" },
    { id = "compendium_entry", label = "Liens compendium" },
    -- Propre a l'addon : l'avantage d'un trait ou d'un objet.
    { id = "avantage",         label = "Avantage" },
}

local GENRE = {
    texte = "text", nombre = "text", case = "text", palier = "text",
    statistique = "statistic", texte_long = "longtext",
    composants = "table", prerequis = "table", injections = "table", table_xp = "table", feuilles = "table",
    calcul = "longtext", jauge = "gauge", liste = "list_from", contenu = "list_from",
    entree = "compendium_entry", avantage = "avantage", table_niveaux = "list_from",
}

-- Les libelles que le template donne a certains onglets selon la categorie.
local function LibelleGenre(categorie, genre)
    if categorie.type == "knowledge" and genre == "compendium_entry" then return "Fabrication" end
    if categorie.type == "action_resolution" and genre == "text" then return "Natures" end
    if categorie.type == "action_resolution" and genre == "table" then return "Options" end
    if categorie.type == "calculateur" and genre == "longtext" then return "Formule" end
    if categorie.type == "calculateur" and genre == "table" then return "Injections" end
    for _, g in ipairs(GENRES) do if g.id == genre then return g.label end end
    return genre
end

local function GenreDe(champ)
    if champ.onglet == "fabrication" then return "compendium_entry" end
    return GENRE[champ.type]
end

-- Les champs que l'editeur montre : ceux de la categorie (sans l'icone, qui a
-- son panneau), et pour un PNJ les champs repartis de la fiche.
local champsPNJ
local function ChampsPNJ()
    if champsPNJ then return champsPNJ end
    champsPNJ = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        for _, section in ipairs(tab.sections) do
            for _, field in ipairs(section.fields) do
                if (field.kind == "stat" or field.kind == "roll") and field.id ~= "niveau" then
                    champsPNJ[#champsPNJ + 1] = { cle = field.id, label = field.label, type = "statistique",
                        dossier = section.label ~= "" and section.label or tab.label }
                end
            end
        end
    end
    return champsPNJ
end

local function Champs(categorie)
    local out = {}
    for _, champ in ipairs(C.Champs(categorie)) do
        if champ.type ~= "icone" then out[#out + 1] = champ end
    end
    if categorie.statistiques == "valeurs" then
        for _, champ in ipairs(ChampsPNJ()) do out[#out + 1] = champ end
    end
    return out
end

-- Une categorie « liste » (et la table XP) s'edite sur une seule page, sans
-- onglets, comme dans le template.
local function PageUnique(categorie)
    return categorie.type == "list" or categorie.type == "list_multiple"
end

-- ===== La copie de travail =================================================
-- Rien n'est ecrit tant que le MJ ne valide pas, et la copie ne partage
-- aucune table avec ce qui est enregistre.

local function Travail(categorie, element)
    local e = LCM.Copie(element or {})
    e.brouillon = nil
    -- L'avantage est un ensemble dans un element, une liste dans une definition.
    if type(e.avantage) == "table" and e.avantage[1] == nil then
        local liste = {}
        for id in pairs(e.avantage) do liste[#liste + 1] = id end
        table.sort(liste)
        e.avantage = liste
    end
    if not element then
        for k, v in pairs(categorie.defaut or {}) do e[k] = LCM.Copie(v) end
        e.label = "Nouvelle entree"
        e.id = Brouillons.NouvelIdentifiant()
    end
    local famille = categorie.famille
    return {
        categorie = categorie,
        e = e,
        creation = element == nil,
        publie = element ~= nil and famille ~= nil and Brouillons.EstPublie(famille, element.id),
    }
end

local function Lire(t, champ)
    local e, categorie = t.e, t.categorie
    if champ.type == "statistique" then
        local source = categorie.statistiques == "valeurs" and e.valeurs or e.bonus
        return type(source) == "table" and source[champ.cle] or nil
    end
    if champ.valeur then return type(e.valeurs) == "table" and e.valeurs[champ.cle] or nil end
    return e[champ.cle]
end

-- Ecrit une valeur ; nil efface. Une table devenue vide est effacee aussi.
local function Ecrire(t, champ, valeur)
    local e, categorie = t.e, t.categorie
    local cible, cle = e, champ.cle
    if champ.type == "statistique" then
        local nom = categorie.statistiques == "valeurs" and "valeurs" or "bonus"
        e[nom] = type(e[nom]) == "table" and e[nom] or {}
        cible = e[nom]
    elseif champ.valeur then
        e.valeurs = type(e.valeurs) == "table" and e.valeurs or {}
        cible = e.valeurs
    end
    cible[cle] = valeur
end

-- La copie -> la definition qu'on enregistre, ou nil et la raison. Ne
-- verifie que ce que le registre ne voit pas ; le reste est son affaire.
local function Definition(t)
    local def = LCM.Copie(t.e)
    def.label = Texte(def.label)
    if def.label == "" then return nil, "donne-lui un nom" end
    def.id = def.id or Brouillons.NouvelIdentifiant()
    if Texte(def.id) == "" then return nil, "identifiant absent" end
    for k, v in pairs(t.categorie.defaut or {}) do
        if def[k] == nil then def[k] = LCM.Copie(v) end
    end
    -- La jauge d'etat a son defaut (100 / 100) : rien a retenir.
    if type(def.etat) == "table" and tonumber(def.etat.courant) == 100 and tonumber(def.etat.max) == 100 then
        def.etat = nil
    end
    if def.icone == LCM.Icone(nil) then def.icone = nil end
    for _, cle in ipairs({ "bonus", "valeurs" }) do
        if type(def[cle]) == "table" and next(def[cle]) == nil then def[cle] = nil end
    end
    return def
end

-- ===== Les editeurs de champ ===============================================
-- Un editeur par champ, cree a sa premiere apparition puis reutilise : il
-- connait son champ, se remplit depuis la copie de travail et y ecrit.

local function Options(champ)
    if champ.type == "avantage" then
        local out = {}
        for _, tab in ipairs(LCM.Schema.Tabs()) do
            for _, section in ipairs(tab.sections) do
                for _, field in ipairs(section.fields) do
                    if field.kind == "roll" then
                        out[#out + 1] = { id = field.id, label = field.label,
                            groupe = section.label ~= "" and (tab.label .. " · " .. section.label) or tab.label }
                    end
                end
            end
        end
        return out
    end
    if champ.type == "palier" then
        local out = {}
        for _, p in ipairs(LCM.Equilibrage.metiers.paliers) do
            local libelle = p.niveau and string.format("%s %d", p.nom, p.niveau) or p.nom
            out[#out + 1] = { id = libelle, label = libelle }
        end
        return out
    end
    if champ.type == "table_niveaux" then
        return { { id = "", label = "Aucune" }, { id = "xp_metier", label = "Table xp / XP METIER" } }
    end
    return C.Options(champ)
end

-- Toutes les entrees du compendium, pour les liens (composants, resultat).
local function OptionsEntrees()
    local out = {}
    for _, categorie in ipairs(C.categories) do
        if categorie.famille then
            for _, element in ipairs(C.Entrees(categorie)) do
                out[#out + 1] = { id = C.Reference(categorie, element), label = element.label, groupe = categorie.label }
            end
        end
    end
    return out
end

local function NomReference(ref)
    local element = C.Resoudre(ref)
    if element then return element.label end
    return Texte(ref) ~= "" and ("|cffe86b6b? " .. tostring(ref) .. "|r") or "|cff99907fAucune|r"
end

-- ===== La fenetre ==========================================================

local function Construire(parent)
    local f = CreateFrame("Frame", "LCM_CompendiumEditeur", parent)
    Editeur.frame = f
    f:SetSize(LARGEUR, HAUTEUR)
    f:SetPoint("CENTER", parent, "CENTER", 0, 0)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f.fond = UI.Aplat(f, UI.C.fond)
    f.fond:SetAllPoints(f)
    UI.BordureFine(f, 0.38)
    f.titre = UI.Texte(f, "Configuration entree", UI.C.titre, "GameFontNormalSmall")
    f.titre:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
    f.fermer = UI.Bouton(f, "x", 16, 16, function() f:Hide() end)
    f.fermer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    f.choix = UI.Choix("compendium_editeur", "")

    -- ----- onglets ------------------------------------------------------------
    f.zoneOnglets = CreateFrame("Frame", nil, f)
    f.zoneOnglets:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    f.zoneOnglets:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -36)
    f.onglets = {}
    f.zoneDossiers = CreateFrame("Frame", nil, f)
    f.dossiers = {}

    -- ----- General : identite -----------------------------------------------
    local id = CreateFrame("Frame", nil, f)
    f.identite = id
    id:SetHeight(96)
    id.fond = UI.Aplat(id, { 0, 0, 0, 0.2 })
    id.fond:SetAllPoints(id)
    UI.BordureFine(id, 0.22)
    local function Libelle(parent, texte) return UI.Texte(parent, texte, UI.C.libelle, "GameFontNormalSmall") end
    -- Pastille de couleur : le selecteur du jeu, et le code RRVVBB.
    local function Pastille(cle, defaut)
        local b = CreateFrame("Button", nil, id)
        b:SetSize(18, 18)
        b.couleur = UI.Aplat(b, { 1, 1, 1, 1 }, "ARTWORK")
        b.couleur:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
        b.couleur:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
        UI.BordureFine(b, 0.6)
        function b:Regler(hexa)
            self.hexa = hexa or defaut
            self.couleur:SetColorTexture(UI.Compendium.Couleur(self.hexa))
        end
        b:SetScript("OnClick", function(self)
            if f.lecture then return end
            local avant = self.hexa
            local r, g, bl = UI.Compendium.Couleur(avant)
            local function Poser(rr, gg, bb)
                local hexa = string.format("%02X%02X%02X", math.floor(rr * 255 + 0.5), math.floor(gg * 255 + 0.5),
                    math.floor(bb * 255 + 0.5))
                f.travail.e[cle] = hexa ~= defaut and hexa or nil
                self:Regler(hexa)
            end
            if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
                ColorPickerFrame:SetupColorPickerAndShow({
                    r = r, g = g, b = bl, hasOpacity = false,
                    swatchFunc = function() Poser(ColorPickerFrame:GetColorRGB()) end,
                    cancelFunc = function() Poser(r, g, bl) end,
                })
            end
        end)
        return b
    end
    id.lblFond = Libelle(id, "Fond")
    id.lblFond:SetPoint("TOPLEFT", id, "TOPLEFT", 8, -8)
    id.fondCouleur = Pastille("couleurFond", LCM.COULEUR_FOND)
    id.fondCouleur:SetPoint("LEFT", id.lblFond, "RIGHT", 12, 0)
    id.lblTitre = Libelle(id, "Titre")
    id.lblTitre:SetPoint("LEFT", id.fondCouleur, "RIGHT", 18, 0)
    id.titreCouleur = Pastille("couleurTitre", LCM.COULEUR_TITRE)
    id.titreCouleur:SetPoint("LEFT", id.lblTitre, "RIGHT", 12, 0)
    id.lblNom = Libelle(id, "Nom")
    id.lblNom:SetPoint("TOPLEFT", id, "TOPLEFT", 8, -42)
    id.nom = UI.Champ(id, 250, 20, function(texte)
        f.travail.e.label = texte
        f:MajIdentifiant()
    end)
    id.nom:SetMaxLetters(80)
    id.nom:SetPoint("LEFT", id.lblNom, "RIGHT", 12, 0)
    id.lblTags = Libelle(id, "Tags")
    id.lblTags:SetPoint("LEFT", id.nom, "RIGHT", 24, 0)
    id.tags = UI.Champ(id, 180, 20, function(texte) f.travail.e.tags = Texte(texte) ~= "" and texte or nil end)
    id.tags:SetPoint("LEFT", id.lblTags, "RIGHT", 12, 0)
    id.lblId = Libelle(id, "ID")
    id.lblId:SetPoint("TOPLEFT", id, "TOPLEFT", 8, -72)
    id.ident = UI.Texte(id, "", UI.C.discret, "GameFontNormalSmall")
    id.ident:SetPoint("LEFT", id.lblId, "RIGHT", 12, 0)
    id.lblPile = Libelle(id, "Pile max")
    id.lblPile:SetPoint("TOPLEFT", id, "TOPLEFT", 340, -72)
    id.pile = UI.Champ(id, 100, 20, function(texte)
        f.travail.e.pileMax = Texte(texte) ~= "" and (tonumber(texte) or texte) or nil
    end)
    id.pile:SetPoint("LEFT", id.lblPile, "RIGHT", 12, 0)
    id.sacMJ = UI.Case(id, "Sac maitre du jeu", function(v) f.travail.e.sacMJ = v or nil end)
    id.sacMJ:SetPoint("TOPLEFT", id, "TOPLEFT", 8, -100)
    id.debug = UI.Case(id, "Mode Débug  (récap détaillé de la résolution)", function(v) f.travail.e.debug = v or nil end)
    id.debug:SetPoint("TOPLEFT", id, "TOPLEFT", 8, -100)
    id.emission = UI.Case(id, "Action d'émission  (l'attaquant lance ses étapes, se termine par « Déclarer »)",
        function(v) f.travail.e.emission = v or nil end)
    id.emission:SetPoint("TOPLEFT", id, "TOPLEFT", 8, -124)

    -- ----- General : icone ------------------------------------------------------
    local ic = CreateFrame("Frame", nil, f)
    f.panneauIcone = ic
    ic:SetHeight(58)
    ic.fond = UI.Aplat(ic, { 0, 0, 0, 0.2 })
    ic.fond:SetAllPoints(ic)
    UI.BordureFine(ic, 0.2)
    ic.lbl = Libelle(ic, "Icone")
    ic.lbl:SetPoint("TOPLEFT", ic, "TOPLEFT", 12, -8)
    -- L'apercu est un BOUTON : on clique dessus et on choisit, comme dans
    -- Necronicon et comme dans l'atelier. Taper un chemin a la main reste
    -- possible — c'est plus rapide quand on connait deja le nom — mais ce ne
    -- peut pas etre le seul moyen.
    ic.apercuBouton = CreateFrame("Button", nil, ic)
    ic.apercuBouton:SetSize(26, 26)
    ic.apercuBouton:SetPoint("TOPLEFT", ic, "TOPLEFT", 16, -26)
    UI.BordureFine(ic.apercuBouton, 0.4)
    ic.apercu = ic.apercuBouton:CreateTexture(nil, "ARTWORK")
    ic.apercu:SetPoint("TOPLEFT", ic.apercuBouton, "TOPLEFT", 1, -1)
    ic.apercu:SetPoint("BOTTOMRIGHT", ic.apercuBouton, "BOTTOMRIGHT", -1, 1)
    ic.apercu:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ic.apercuBouton.survol = UI.Aplat(ic.apercuBouton, UI.C.survol, "HIGHLIGHT")
    ic.apercuBouton.survol:SetAllPoints(ic.apercuBouton)
    UI.Bulle(ic.apercuBouton, "Icône", "Clic : choisir dans la liste.")
    ic.selecteur = UI.SelecteurIcone("compendium_entree")
    ic.apercuBouton:SetScript("OnClick", function(self)
        -- En lecture seule (contenu publie), on ne propose rien : l'entree se
        -- duplique d'abord.
        if f.lecture then LCM.Alerte("contenu publié : duplique-le pour le modifier.") return end
        ic.selecteur:Proposer(self, function(chemin)
            f.travail.e.icone = Texte(chemin) ~= "" and chemin or nil
            ic.chemin:SetText(chemin or "")
            ic.apercu:SetTexture(LCM.Icone(chemin))
        end)
    end)
    ic.chemin = UI.Champ(ic, 300, 20, function(texte)
        f.travail.e.icone = Texte(texte) ~= "" and texte or nil
        ic.apercu:SetTexture(LCM.Icone(texte))
    end)
    ic.chemin:SetMaxLetters(160)
    ic.chemin:SetPoint("LEFT", ic.apercuBouton, "RIGHT", 12, 0)
    ic.aide = UI.Texte(ic, "nom court (INV_Sword_05) ou chemin complet", UI.C.discret, "GameFontNormalSmall")
    ic.aide:SetPoint("LEFT", ic.chemin, "RIGHT", 10, 0)

    -- ----- Champs : barre d'outils et panneau -----------------------------------
    f.filetOutils = UI.Filet(f)
    f.etendre = Action(f, "Etendre")
    f.etendre:SetScript("OnClick", function() f:ToutDeplier(true) end)
    f.minimiser = Action(f, "Minimiser")
    f.minimiser:SetPoint("LEFT", f.etendre, "RIGHT", 8, 0)
    f.minimiser:SetScript("OnClick", function() f:ToutDeplier(false) end)
    f.sections = CreateFrame("Frame", nil, f)
    f.sections.fond = UI.Aplat(f.sections, { 0, 0, 0, 0.12 })
    f.sections.fond:SetAllPoints(f.sections)
    UI.BordureFine(f.sections, 0.18)
    f.zone = UI.Defilement(f.sections)
    f.zone:SetPoint("TOPLEFT", f.sections, "TOPLEFT", 10, -10)
    f.zone:SetPoint("BOTTOMRIGHT", f.sections, "BOTTOMRIGHT", -22, 10)
    f.editeurs = {}

    -- ----- pied -------------------------------------------------------------------
    f.filetPied = UI.Filet(f, true)
    f.filetPied:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 42)
    f.filetPied:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 42)
    f.ok = Action(f, "OK")
    f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -44, 12)
    f.ok:SetScript("OnClick", function() f:Valider() end)
    f.annuler = Action(f, "Annuler")
    f.annuler:SetPoint("RIGHT", f.ok, "LEFT", -10, 0)
    f.annuler:SetScript("OnClick", function() f:Hide() end)
    f.message = UI.Texte(f, "", UI.C.discret, "GameFontNormalSmall")
    f.message:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 16)
    f.message:SetPoint("RIGHT", f.annuler, "LEFT", -12, 0)
    f.message:SetWordWrap(false)

    UI.Redimensionner(f, MIN_L, MIN_H, function() f:Afficher() end)
    f:HookScript("OnHide", function() f.choix:Hide() end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = f:GetName() end
    f:Hide()

    Editeur.Comportement(f)
    return f
end

-- ===== Comportement ========================================================

function Editeur.Comportement(f)
    function f:Message(texte, couleur)
        self.message:SetText(texte or "")
        Peindre(self.message, couleur or UI.C.discret)
    end

    function f:MajIdentifiant()
        local t = self.travail
        if t.creation then
            self.identite.ident:SetText(tostring(t.e.id) .. "   |cff99907fidentifiant unique, figé|r")
        else
            self.identite.ident:SetText(tostring(t.e.id))
        end
    end

    -- Les onglets presents : General, puis un par genre de champ.
    function f:Onglets()
        local out = { { id = "general", label = "Général" } }
        -- Une categorie peut tout tenir dans « Général » : deux onglets pour
        -- trois champs, c'est un clic pour rien. C'est le cas des sacs.
        if self.travail.categorie and self.travail.categorie.ongletUnique then return out end
        local presents = {}
        for _, champ in ipairs(Champs(self.travail.categorie)) do
            local genre = GenreDe(champ)
            if genre then presents[genre] = true end
        end
        for _, g in ipairs(GENRES) do
            if presents[g.id] then out[#out + 1] = { id = g.id, label = LibelleGenre(self.travail.categorie, g.id) } end
        end
        return out
    end

    -- Rangee d'onglets : largeur selon le libelle (82 a 158), retour a la
    -- ligne, 24 de haut, 10 d'ecart.
    function f:RangerOnglets()
        local onglets = self:Onglets()
        local valide = false
        for _, o in ipairs(onglets) do valide = valide or o.id == self.onglet end
        if not valide then self.onglet = "general" end
        local dispo = math.max(self:GetWidth() - 40, 300)
        local x, y = 0, 0
        for n, o in ipairs(onglets) do
            local b = self.onglets[n]
            if not b then
                b = UI.Bouton(self.zoneOnglets, "", 82, 24, function(bouton)
                    if f.onglet == bouton.ongletId then return end
                    f.onglet = bouton.ongletId
                    f.dossier = nil
                    f.zone:Aller(0)
                    f:Afficher()
                end)
                if UI.HabillerOnglet then UI.HabillerOnglet(b) end
                UI.Police(b.label, 12)
                self.onglets[n] = b
            end
            b.ongletId = o.id
            b.label:SetText(o.label)
            local largeur = math.max(82, math.min(158, #o.label * 7 + 28))
            if x > 0 and x + largeur > dispo then x, y = 0, y + 28 end
            b:SetSize(largeur, 24)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.zoneOnglets, "TOPLEFT", x, -y)
            if b.Selectionner then b:Selectionner(o.id == self.onglet) end
            b:Show()
            x = x + largeur + 10
        end
        for n = #onglets + 1, #self.onglets do self.onglets[n]:Hide() end
        local hauteur = y + 24
        self.zoneOnglets:SetHeight(hauteur)
        return hauteur
    end

    -- Les dossiers de l'onglet actif (Statistiques) : une rangee d'onglets de
    -- plus, s'il y en a au moins deux.
    function f:RangerDossiers(champs)
        local dossiers, vus = {}, {}
        for _, champ in ipairs(champs) do
            local d = champ.dossier or "Général"
            if not vus[d] then vus[d] = true dossiers[#dossiers + 1] = d end
        end
        local montrer = #dossiers > 1
        local actif = self.dossier
        if not vus[actif or ""] then actif = dossiers[1] self.dossier = actif end
        self.zoneDossiers:ClearAllPoints()
        self.zoneDossiers:SetPoint("TOPLEFT", self.zoneOnglets, "BOTTOMLEFT", 0, -4)
        self.zoneDossiers:SetPoint("TOPRIGHT", self, "TOPRIGHT", -28, 0)
        local dispo = math.max(160, self:GetWidth() - 56)
        local x, y, rangs = 0, 0, 1
        for n, nom in ipairs(dossiers) do
            local b = self.dossiers[n]
            if not b then
                b = UI.Bouton(self.zoneDossiers, "", 86, 22, function(bouton)
                    f.dossier = bouton.dossier
                    f.zone:Aller(0)
                    f:Afficher()
                end)
                if UI.HabillerOnglet then UI.HabillerOnglet(b) end
                UI.Police(b.label, 11)
                self.dossiers[n] = b
            end
            b.dossier = nom
            b.label:SetText(nom)
            local largeur = math.max(86, math.min(150, #nom * 7 + 28))
            if x > 0 and x + largeur > dispo then x, y, rangs = 0, y + 28, rangs + 1 end
            b:SetSize(largeur, 22)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.zoneDossiers, "TOPLEFT", x, -y)
            if b.Selectionner then b:Selectionner(nom == actif) end
            b:SetShown(montrer)
            x = x + largeur + 10
        end
        for n = #dossiers + 1, #self.dossiers do self.dossiers[n]:Hide() end
        self.zoneDossiers:SetShown(montrer)
        local hauteur = montrer and (rangs * 22 + (rangs - 1) * 6 + 8) or 0
        self.zoneDossiers:SetHeight(math.max(1, hauteur))
        return hauteur, montrer
    end

    function f:ToutDeplier(v)
        for _, champ in ipairs(Champs(self.travail.categorie)) do self.deplies[champ] = v end
        self:Afficher()
    end

    -- Met la fenetre en page selon l'onglet actif.
    function f:Afficher()
        local t = self.travail
        if not t then return end
        local categorie = t.categorie
        local id, ic = self.identite, self.panneauIcone
        self.lecture = t.publie or not C.Editable(categorie)
        self.titre:SetText("Configuration entree" .. (self.lecture and "  |cff99907f(lecture seule)|r" or ""))

        local unique = PageUnique(categorie)
        local hauteurOnglets, hauteurDossiers = 0, 0
        local champsVisibles = {}
        if unique then
            self.zoneOnglets:Hide()
            self.zoneDossiers:Hide()
            self.onglet = "liste"
            for _, champ in ipairs(Champs(categorie)) do champsVisibles[#champsVisibles + 1] = champ end
        else
            self.zoneOnglets:Show()
            hauteurOnglets = self:RangerOnglets()
            -- Onglet unique : l'identite ET tous les champs sur la meme page.
            -- Ce n'est pas « on cache les autres onglets », c'est « il n'y en a
            -- qu'un, et il porte tout ».
            if categorie.ongletUnique then
                for _, champ in ipairs(Champs(categorie)) do
                    champsVisibles[#champsVisibles + 1] = champ
                end
                self.zoneDossiers:Hide()
            elseif self.onglet ~= "general" then
                local duGenre = {}
                for _, champ in ipairs(Champs(categorie)) do
                    if GenreDe(champ) == self.onglet then duGenre[#duGenre + 1] = champ end
                end
                local montrer
                hauteurDossiers, montrer = self:RangerDossiers(duGenre)
                for _, champ in ipairs(duGenre) do
                    if not montrer or (champ.dossier or "Général") == self.dossier then
                        champsVisibles[#champsVisibles + 1] = champ
                    end
                end
            else
                self.zoneDossiers:Hide()
            end
        end

        -- General : identite et icone.
        local general = self.onglet == "general" or unique
        local haut = 36 + (unique and 0 or (hauteurOnglets + 10)) + hauteurDossiers
        id:SetShown(general)
        ic:SetShown(general)
        if general then
            id:ClearAllPoints()
            id:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -haut)
            id:SetPoint("TOPRIGHT", self, "TOPRIGHT", -12, -haut)
            local conteneur = categorie.type == "container"
            local resolution = categorie.type == "action_resolution"
            for _, w in ipairs({ id.lblFond, id.fondCouleur, id.lblTitre, id.titreCouleur, id.lblTags, id.tags,
                                 id.lblPile, id.pile }) do w:SetShown(not unique) end
            id.lblNom:ClearAllPoints()
            id.lblNom:SetPoint("TOPLEFT", id, "TOPLEFT", 8, unique and -10 or -42)
            id.lblId:ClearAllPoints()
            id.lblId:SetPoint("TOPLEFT", id, "TOPLEFT", 8, unique and -40 or -72)
            id.sacMJ:SetShown(conteneur and not unique)
            id.debug:SetShown(resolution)
            id.emission:SetShown(resolution)
            id:SetHeight(unique and 64 or (resolution and 148 or (conteneur and 124 or 96)))
            ic:ClearAllPoints()
            ic:SetPoint("TOPLEFT", id, "BOTTOMLEFT", 0, -10)
            ic:SetPoint("TOPRIGHT", id, "BOTTOMRIGHT", 0, -10)
            local e = t.e
            id.nom:SetText(e.label or "")
            id.tags:SetText(e.tags or "")
            id.pile:SetText(e.pileMax and tostring(e.pileMax) or "")
            id.fondCouleur:Regler(e.couleurFond)
            id.titreCouleur:Regler(e.couleurTitre)
            id.sacMJ:Cocher(e.sacMJ == true)
            id.debug:Cocher(e.debug == true)
            id.emission:Cocher(e.emission == true)
            ic.chemin:SetText(e.icone and e.icone ~= LCM.Icone(nil) and e.icone or "")
            ic.apercu:SetTexture(LCM.Icone(e.icone))
            self:MajIdentifiant()
        end

        -- Champs : la barre d'outils puis le panneau qui defile.
        local avecChamps = (unique and #champsVisibles > 0) or (not general)
        self.filetOutils:SetShown(avecChamps and not unique)
        self.etendre:SetShown(avecChamps and not unique)
        self.minimiser:SetShown(avecChamps and not unique)
        self.sections:SetShown(avecChamps)
        if avecChamps then
            self.sections:ClearAllPoints()
            if unique then
                self.sections:SetPoint("TOPLEFT", ic, "BOTTOMLEFT", 0, -10)
            else
                self.filetOutils:ClearAllPoints()
                self.filetOutils:SetPoint("TOPLEFT", self, "TOPLEFT", 12, -haut)
                self.filetOutils:SetPoint("TOPRIGHT", self, "TOPRIGHT", -12, -haut)
                self.etendre:ClearAllPoints()
                self.etendre:SetPoint("TOPLEFT", self.filetOutils, "BOTTOMLEFT", 0, -8)
                self.sections:SetPoint("TOPLEFT", self.etendre, "BOTTOMLEFT", 0, -10)
            end
            self.sections:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -16, 48)
            self:RangerChamps(champsVisibles, unique)
        else
            for _, ed in pairs(self.editeurs) do ed:Hide() end
        end

        self.ok:SetShown(not self.lecture)
        self.annuler.label:SetText(self.lecture and "Fermer" or "Annuler")
        if self.lecture and not self.messageFixe then
            if t.publie then
                self:Message("Contenu publié : le fichier généré fait foi, il ne se modifie pas ici. "
                    .. "« Dup » en fait un brouillon modifiable.")
            elseif categorie.lectureSeule then
                self:Message("Lecture seule : " .. categorie.lectureSeule)
            end
        end
    end

    -- Pose les editeurs des champs visibles, les uns sous les autres.
    function f:RangerChamps(champs, unique)
        local contenu = self.zone.contenu
        local largeur = math.max((self.zone:GetWidth() or 600) - 8, 300)
        local y = 4
        local vus = {}
        for _, champ in ipairs(champs) do
            local ed = self.editeurs[champ]
            if not ed then
                ed = Editeur.NouvelEditeur(self, champ)
                self.editeurs[champ] = ed
            end
            vus[ed] = true
            if self.deplies[champ] == nil then self.deplies[champ] = true end
            ed:ClearAllPoints()
            ed:SetPoint("TOPLEFT", contenu, "TOPLEFT", 0, -y)
            ed:SetWidth(largeur)
            local h = ed:Remplir(self.travail, self.deplies[champ] ~= false or unique, self.lecture, unique)
            ed:SetHeight(h)
            ed:Show()
            y = y + h + (champ.type == "statistique" and 4 or 10)
        end
        for _, ed in pairs(self.editeurs) do if not vus[ed] then ed:Hide() end end
        self.zone:Regler(y)
    end

    function f:Ouvrir(categorie, element)
        self.travail = Travail(categorie, element)
        self.onglet, self.dossier = "general", nil
        self.deplies = {}
        self.messageFixe = nil
        self:Message("")
        self.zone:Aller(0)
        self:Show()
        self:Raise()
        self:Afficher()
    end

    function f:Valider()
        local t = self.travail
        if self.lecture then return end
        local def, raison = Definition(t)
        if not def then
            self:Message("Refusé : " .. raison, UI.C.plein)
            return
        end
        local ok, refus = Brouillons.Enregistrer(t.categorie.famille, def, t.creation)
        if not ok then
            self:Message("Refusé : " .. tostring(refus), UI.C.plein)
            return
        end
        LCM.Ok(string.format("brouillon enregistre : %s (%s)", def.label, t.categorie.label))
        self:Hide()
        UI.Compendium.Actualiser()
    end
end

-- ===== Un editeur de champ ================================================

function Editeur.NouvelEditeur(f, champ)
    local ed = CreateFrame("Frame", nil, f.zone.contenu)
    ed.champ = champ
    local compact = champ.type == "texte" or champ.type == "nombre" or champ.type == "statistique"
        or champ.type == "palier"
    ed.compact = compact

    -- Le bouton resume : replie / deplie ce champ.
    ed.resume = UI.Bouton(ed, "", 120, 20, function()
        f.deplies[champ] = not (f.deplies[champ] ~= false)
        f:Afficher()
    end)
    ed.resume.label:ClearAllPoints()
    ed.resume.label:SetPoint("LEFT", ed.resume, "LEFT", 8, 0)
    ed.resume.label:SetPoint("RIGHT", ed.resume, "RIGHT", -26, 0)
    ed.resume.label:SetJustifyH("LEFT")
    ed.signe = UI.Texte(ed.resume, "", UI.C.discret, "GameFontNormalSmall")
    ed.signe:SetPoint("RIGHT", ed.resume, "RIGHT", -8, 0)
    ed.etiquette = UI.Texte(ed, "", UI.C.libelle, "GameFontNormalSmall")
    ed.lignes = {}

    local t = champ.type
    if compact then
        ed.saisie = UI.Champ(ed, 160, 22, function(texte)
            local valeur = Texte(texte)
            if t == "texte" or t == "palier" then
                Ecrire(f.travail, champ, valeur ~= "" and valeur or nil)
            elseif valeur == "" or tonumber(valeur) == 0 and t == "statistique" then
                Ecrire(f.travail, champ, nil)
            else
                -- Un nombre illisible passe tel quel : le registre le refusera,
                -- avec sa raison, plutot que de le voir remplace par zero.
                Ecrire(f.travail, champ, tonumber(valeur) or valeur)
            end
        end)
        ed.saisie:SetMaxLetters(t == "texte" and 200 or 12)
    elseif t == "texte_long" then
        ed.zone = UI.Zone(ed, 400, 90, function(texte) Ecrire(f.travail, champ, texte ~= "" and texte or nil) end)
        ed.zone.saisie:SetMaxLetters(4000)
    elseif t == "case" then
        ed.case = UI.Case(ed, champ.label, function(v) Ecrire(f.travail, champ, v or nil) end)
    elseif t == "jauge" then
        ed.lblCourant = UI.Texte(ed, "Actuelle", UI.C.libelle, "GameFontNormalSmall")
        ed.courant = UI.Champ(ed, 70, 20, function(texte)
            local j = LCM.Copie(Lire(f.travail, champ) or champ.defaut or { courant = 0, max = 0 })
            j.courant = tonumber(texte) or texte
            Ecrire(f.travail, champ, j)
        end)
        ed.lblMax = UI.Texte(ed, "Maximum", UI.C.libelle, "GameFontNormalSmall")
        ed.max = UI.Champ(ed, 70, 20, function(texte)
            local j = LCM.Copie(Lire(f.travail, champ) or champ.defaut or { courant = 0, max = 0 })
            j.max = tonumber(texte) or texte
            Ecrire(f.travail, champ, j)
        end)
    end

    -- Un bouton de choix (liste, lien, palier...) : la liste s'ouvre dessous.
    ed.choisir = Action(ed, "Choisir")
    ed.vider = Action(ed, "X")
    ed.ajouter = Action(ed, "+ Ligne")
    ed.valeur = UI.Texte(ed, "", UI.C.texte, "GameFontNormalSmall")
    ed.valeur:SetWordWrap(true)

    -- Remplit l'editeur depuis la copie de travail ; renvoie sa hauteur.
    function ed:Remplir(travail, deplie, lecture, unique)
        local brut = Lire(travail, champ)
        local largeur = self:GetWidth()
        local categorie = travail.categorie
        for _, w in ipairs({ self.choisir, self.vider, self.ajouter, self.valeur, self.etiquette }) do w:Hide() end
        if self.saisie then self.saisie:Hide() end
        if self.zone then self.zone:Hide() end
        if self.case then self.case:Hide() end
        if self.courant then for _, w in ipairs({ self.lblCourant, self.courant, self.lblMax, self.max }) do w:Hide() end end
        for _, l in ipairs(self.lignes) do l:Hide() end

        local apercu = C.Texte(categorie, champ, brut, "compact")
        if t == "statistique" or t == "nombre" then apercu = brut ~= nil and tostring(brut) or "" end
        self.resume:ClearAllPoints()
        self.resume:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        if unique then
            self.resume:Hide()
        else
            self.resume:Show()
            if compact and deplie then
                local w = t == "statistique" and math.min(180, math.max(132, math.floor(largeur * 0.22)))
                    or math.min(190, math.max(120, math.floor(largeur * 0.24)))
                self.resume:SetSize(w, 24)
                self.resume.label:SetText(champ.label)
            else
                self.resume:SetSize(largeur, 20)
                self.resume.label:SetText(champ.label .. "  |  " .. (apercu ~= "" and apercu or "-"))
            end
            self.signe:SetText(deplie and "-" or "+")
        end
        if not deplie then return 20 end

        if compact then
            self.saisie:ClearAllPoints()
            if unique then
                self.etiquette:SetText(champ.label)
                self.etiquette:ClearAllPoints()
                self.etiquette:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -4)
                self.etiquette:Show()
                self.saisie:SetPoint("TOPLEFT", self, "TOPLEFT", 140, 0)
            else
                self.saisie:SetPoint("LEFT", self.resume, "RIGHT", 10, 0)
            end
            self.saisie:SetWidth(t == "texte" and math.min(360, largeur - 220) or 90)
            self.saisie:SetText(brut ~= nil and tostring(brut) or "")
            self.saisie:SetEnabled(not lecture)
            self.saisie:Show()
            if t == "palier" then
                self.saisie:Hide()
                self.choisir:ClearAllPoints()
                self.choisir:SetPoint("LEFT", self.resume, "RIGHT", 10, 0)
                self.choisir.label:SetText(Texte(brut) ~= "" and tostring(brut) or "Choisir…")
                self.choisir:SetWidth(120)
                self.choisir:SetShown(not lecture)
                self.choisir:SetScript("OnClick", function(b)
                    f.choix.titre:SetText(champ.label)
                    f.choix:Proposer(b, Options(champ), function(id)
                        Ecrire(f.travail, champ, id)
                        f:Afficher()
                    end)
                end)
                self.vider:ClearAllPoints()
                self.vider:SetPoint("LEFT", self.choisir, "RIGHT", 8, 0)
                self.vider:SetShown(not lecture and Texte(brut) ~= "")
                self.vider:SetScript("OnClick", function() Ecrire(f.travail, champ, nil) f:Afficher() end)
            end
            return 24
        end

        local y = unique and 0 or 30
        self.etiquette:ClearAllPoints()
        self.etiquette:SetPoint("TOPLEFT", self, "TOPLEFT", unique and 0 or 8, -y)
        self.etiquette:Show()

        if t == "texte_long" then
            self.etiquette:SetText(unique and champ.label or "Valeur")
            self.zone:ClearAllPoints()
            self.zone:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y - 16)
            self.zone:SetSize(math.max(200, largeur - 10), 96)
            self.zone.saisie:SetWidth(math.max(200, largeur - 22))
            self.zone:SetText(brut or "")
            self.zone.saisie:SetEnabled(not lecture)
            self.zone:Show()
            return y + 16 + 96
        elseif t == "case" then
            self.etiquette:Hide()
            self.case:ClearAllPoints()
            self.case:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -y)
            self.case:Cocher(brut == true)
            self.case:SetEnabled(not lecture)
            self.case:Show()
            return y + 22
        elseif t == "jauge" then
            local j = brut or champ.defaut or { courant = 0, max = 0 }
            self.etiquette:SetText(string.format("Jauge  (%s / %s)", tostring(j.courant), tostring(j.max)))
            self.lblCourant:ClearAllPoints()
            self.lblCourant:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -y - 24)
            self.courant:ClearAllPoints()
            self.courant:SetPoint("LEFT", self.lblCourant, "RIGHT", 8, 0)
            self.courant:SetText(tostring(j.courant or ""))
            self.lblMax:ClearAllPoints()
            self.lblMax:SetPoint("LEFT", self.courant, "RIGHT", 20, 0)
            self.max:ClearAllPoints()
            self.max:SetPoint("LEFT", self.lblMax, "RIGHT", 8, 0)
            self.max:SetText(tostring(j.max or ""))
            for _, w in ipairs({ self.lblCourant, self.courant, self.lblMax, self.max }) do w:Show() end
            self.courant:SetEnabled(not lecture)
            self.max:SetEnabled(not lecture)
            return y + 48
        elseif t == "liste" or t == "avantage" or t == "table_niveaux" then
            local multiple = champ.multiple or t == "avantage"
            self.etiquette:SetText(multiple and "Valeurs (selection multiple)" or "Valeur")
            local resume = C.Texte(categorie, champ, brut, "full")
            if t == "table_niveaux" then resume = Texte(brut) ~= "" and "Table xp / XP METIER" or "Aucune" end
            self.valeur:ClearAllPoints()
            self.valeur:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -y - 20)
            self.valeur:SetWidth(math.max(160, largeur - 150))
            self.valeur:SetText(resume ~= "" and resume or "|cff99907fAucune|r")
            self.valeur:Show()
            self.choisir:ClearAllPoints()
            self.choisir:SetPoint("TOPRIGHT", self, "TOPRIGHT", -40, -y - 18)
            self.choisir.label:SetText(multiple and "Ajouter" or "Choisir")
            self.choisir:SetWidth(70)
            self.choisir:SetShown(not lecture)
            self.choisir:SetScript("OnClick", function(b)
                f.choix.titre:SetText(champ.label)
                f.choix:Proposer(b, Options(champ), function(id)
                    if multiple then
                        local liste = LCM.Copie(Lire(f.travail, champ) or {})
                        local deja = false
                        for _, x in ipairs(liste) do deja = deja or x == id end
                        if not deja then liste[#liste + 1] = id end
                        Ecrire(f.travail, champ, liste)
                    else
                        Ecrire(f.travail, champ, id ~= "" and id or nil)
                    end
                    f:Afficher()
                end)
            end)
            self.vider:ClearAllPoints()
            self.vider:SetPoint("LEFT", self.choisir, "RIGHT", 8, 0)
            self.vider:SetShown(not lecture and brut ~= nil and (type(brut) ~= "table" or #brut > 0))
            self.vider:SetScript("OnClick", function()
                if multiple then
                    local liste = LCM.Copie(Lire(f.travail, champ) or {})
                    table.remove(liste)
                    Ecrire(f.travail, champ, #liste > 0 and liste or nil)
                else
                    Ecrire(f.travail, champ, nil)
                end
                f:Afficher()
            end)
            return y + 20 + math.max(20, self.valeur:GetStringHeight() or 0) + 4
        elseif t == "entree" then
            self.etiquette:SetText("Entree compendium")
            self.valeur:ClearAllPoints()
            self.valeur:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -y - 20)
            self.valeur:SetWidth(math.max(160, largeur - 150))
            self.valeur:SetText(NomReference(brut))
            self.valeur:Show()
            self.choisir:ClearAllPoints()
            self.choisir:SetPoint("TOPRIGHT", self, "TOPRIGHT", -40, -y - 18)
            self.choisir.label:SetText("Choisir")
            self.choisir:SetWidth(70)
            self.choisir:SetShown(not lecture)
            self.choisir:SetScript("OnClick", function(b)
                f.choix.titre:SetText(champ.label)
                f.choix:Proposer(b, OptionsEntrees(), function(id) Ecrire(f.travail, champ, id) f:Afficher() end)
            end)
            self.vider:ClearAllPoints()
            self.vider:SetPoint("LEFT", self.choisir, "RIGHT", 8, 0)
            self.vider:SetShown(not lecture and Texte(brut) ~= "")
            self.vider:SetScript("OnClick", function() Ecrire(f.travail, champ, nil) f:Afficher() end)
            return y + 40
        elseif t == "composants" or t == "prerequis" or t == "injections" then
            return Editeur.Table(f, self, champ, brut or {}, y, lecture)
        elseif t == "feuilles" or t == "calcul" then
            return Editeur.Arbre(f, self, champ, brut or {}, y, lecture)
        elseif t == "contenu" then
            return Editeur.Contenu(f, self, champ, brut or {}, y, lecture)
        end
        -- Ce qui ne s'edite pas (table XP, fenetres du profil) se lit.
        self.etiquette:SetText("Valeur")
        self.valeur:ClearAllPoints()
        self.valeur:SetPoint("TOPLEFT", self, "TOPLEFT", 8, -y - 20)
        self.valeur:SetWidth(math.max(160, largeur - 20))
        self.valeur:SetText(C.Texte(categorie, champ, brut, "full"))
        self.valeur:Show()
        return y + 24 + (self.valeur:GetStringHeight() or 0)
    end
    return ed
end

-- ===== Tables (composants, prerequis, injections) =========================

-- Une ligne de table, prise dans le vivier de l'editeur.
local function LigneTable(f, ed, n)
    local l = ed.lignes[n]
    if l then return l end
    l = CreateFrame("Frame", nil, ed)
    l:SetHeight(22)
    l.genre = Action(l, "Texte")
    l.genre:SetWidth(64)
    l.entree = UI.Bouton(l, "", 220, 20)
    l.entree.label:ClearAllPoints()
    l.entree.label:SetPoint("LEFT", l.entree, "LEFT", 6, 0)
    l.entree.label:SetJustifyH("LEFT")
    l.texte = UI.Champ(l, 220, 20)
    l.texte:SetMaxLetters(200)
    l.valeur = UI.Champ(l, 60, 20)
    l.valeur:SetMaxLetters(400)
    l.retirer = Action(l, "x")
    ed.lignes[n] = l
    return l
end

function Editeur.Table(f, ed, champ, lignes, y, lecture)
    local largeur = ed:GetWidth()
    ed.etiquette:SetText(champ.type == "injections" and "Injections (nom : description)"
        or (champ.type == "composants" and "Composants (entree, quantite)" or "Prerequis"))
    local yl = y + 20
    local copie = LCM.Copie(lignes)
    local function Poser(liste) Ecrire(f.travail, champ, #liste > 0 and liste or nil) end
    for n, ligne in ipairs(copie) do
        local l = LigneTable(f, ed, n)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", ed, "TOPLEFT", 8, -yl)
        l:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -8, -yl)
        for _, w in ipairs({ l.genre, l.entree, l.texte, l.valeur, l.retirer }) do w:ClearAllPoints() w:Hide() end
        local x = 0
        if champ.type == "prerequis" then
            local estEntree = ligne.ref ~= nil
            l.genre.label:SetText(estEntree and "Entrée" or "Texte")
            l.genre:SetPoint("LEFT", l, "LEFT", 0, 0)
            l.genre:SetShown(true)
            l.genre:SetScript("OnClick", function()
                if lecture then return end
                local liste = LCM.Copie(Lire(f.travail, champ) or {})
                liste[n] = estEntree and { texte = "" } or { ref = "" }
                Poser(liste)
                f:Afficher()
            end)
            x = 72
        end
        if champ.type == "composants" or (champ.type == "prerequis" and ligne.ref ~= nil) then
            l.entree:SetPoint("LEFT", l, "LEFT", x, 0)
            l.entree:SetWidth(math.max(160, largeur - x - 150))
            l.entree.label:SetText(NomReference(ligne.ref))
            l.entree:SetScript("OnClick", function(b)
                if lecture then return end
                f.choix.titre:SetText("Entrée")
                f.choix:Proposer(b, OptionsEntrees(), function(id)
                    local liste = LCM.Copie(Lire(f.travail, champ) or {})
                    liste[n].ref = id
                    Poser(liste)
                    f:Afficher()
                end)
            end)
            l.entree:Show()
            x = x + l.entree:GetWidth() + 8
        else
            l.texte:SetPoint("LEFT", l, "LEFT", x, 0)
            l.texte:SetWidth(champ.type == "injections" and 120 or math.max(160, largeur - x - 60))
            l.texte:SetText(champ.type == "injections" and (ligne.nom or "") or (ligne.texte or ""))
            l.texte:SetScript("OnTextChanged", function(saisie, parLUtilisateur)
                if parLUtilisateur == false then return end
                local liste = LCM.Copie(Lire(f.travail, champ) or {})
                if champ.type == "injections" then liste[n].nom = saisie:GetText() else liste[n].texte = saisie:GetText() end
                Poser(liste)
            end)
            l.texte:SetEnabled(not lecture)
            l.texte:Show()
            x = x + l.texte:GetWidth() + 8
        end
        if champ.type == "composants" or champ.type == "injections" then
            l.valeur:SetPoint("LEFT", l, "LEFT", x, 0)
            l.valeur:SetWidth(champ.type == "injections" and math.max(120, largeur - x - 60) or 60)
            l.valeur:SetText(champ.type == "injections" and (ligne.description or "") or tostring(ligne.quantite or 1))
            l.valeur:SetScript("OnTextChanged", function(saisie, parLUtilisateur)
                if parLUtilisateur == false then return end
                local liste = LCM.Copie(Lire(f.travail, champ) or {})
                if champ.type == "injections" then liste[n].description = saisie:GetText()
                else liste[n].quantite = tonumber(saisie:GetText()) or saisie:GetText() end
                Poser(liste)
            end)
            l.valeur:SetEnabled(not lecture)
            l.valeur:Show()
        end
        l.retirer:SetPoint("RIGHT", l, "RIGHT", 0, 0)
        l.retirer:SetShown(not lecture)
        l.retirer:SetScript("OnClick", function()
            local liste = LCM.Copie(Lire(f.travail, champ) or {})
            table.remove(liste, n)
            Poser(liste)
            f:Afficher()
        end)
        l:Show()
        yl = yl + 24
    end
    ed.ajouter:ClearAllPoints()
    ed.ajouter:SetPoint("TOPLEFT", ed, "TOPLEFT", 8, -yl - 2)
    ed.ajouter:SetShown(not lecture)
    ed.ajouter:SetScript("OnClick", function()
        local liste = LCM.Copie(Lire(f.travail, champ) or {})
        if champ.type == "composants" then liste[#liste + 1] = { ref = "", quantite = 1 }
        elseif champ.type == "injections" then liste[#liste + 1] = { nom = "", description = "" }
        else liste[#liste + 1] = { texte = "" } end
        Poser(liste)
        f:Afficher()
    end)
    return yl + 24
end

-- ===== Contenu d'un PNJ (equipement) =======================================

function Editeur.Contenu(f, ed, champ, contenu, y, lecture)
    ed.etiquette:SetText("Objets portés, par emplacement")
    local yl = y + 20
    for n, categorie in ipairs(LCM.Objets.CATEGORIES) do
        local l = LigneTable(f, ed, n)
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", ed, "TOPLEFT", 8, -yl)
        l:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -8, -yl)
        for _, w in ipairs({ l.genre, l.entree, l.texte, l.valeur, l.retirer }) do w:ClearAllPoints() w:Hide() end
        local noms = {}
        for _, id in ipairs(contenu[categorie.id] or {}) do
            local o = LCM.Objets.Get(id)
            noms[#noms + 1] = o and o.label or ("? " .. id)
        end
        l.genre.label:SetText(categorie.label)
        l.genre:SetWidth(90)
        l.genre:SetPoint("LEFT", l, "LEFT", 0, 0)
        l.genre:Show()
        l.entree:SetPoint("LEFT", l, "LEFT", 98, 0)
        l.entree:SetWidth(math.max(160, ed:GetWidth() - 160))
        l.entree.label:SetText(#noms > 0 and table.concat(noms, ", ") or "|cff99907fVide — cliquer pour ajouter|r")
        l.entree:SetScript("OnClick", function(b)
            if lecture then return end
            local options = {}
            for _, o in ipairs(LCM.Objets.list) do
                if o.categorie == categorie.id then options[#options + 1] = { id = o.id, label = o.label } end
            end
            f.choix.titre:SetText(categorie.label)
            f.choix:Proposer(b, options, function(id)
                local c = LCM.Copie(Lire(f.travail, champ) or {})
                c[categorie.id] = c[categorie.id] or {}
                table.insert(c[categorie.id], id)
                Ecrire(f.travail, champ, c)
                f:Afficher()
            end)
        end)
        l.entree:Show()
        l.retirer:SetPoint("RIGHT", l, "RIGHT", 0, 0)
        l.retirer:SetShown(not lecture and #noms > 0)
        l.retirer:SetScript("OnClick", function()
            local c = LCM.Copie(Lire(f.travail, champ) or {})
            if c[categorie.id] then
                table.remove(c[categorie.id])
                if #c[categorie.id] == 0 then c[categorie.id] = nil end
            end
            Ecrire(f.travail, champ, next(c) and c or nil)
            f:Afficher()
        end)
        l:Show()
        yl = yl + 24
    end
    return yl + 4
end

-- ===== Cheminement (resolutions) et lignes de calcul =======================
-- Un arbre : feuilles, etapes, branches, options, operandes. Chaque noeud est
-- une table ; ses valeurs simples s'editent, ses listes de tables sont ses
-- enfants. C'est l'acces complet aux donnees que lira le moteur d'actions ;
-- la vue « Schema » en organigramme de Necronicon n'est pas reprise.

local TYPES_ETAPE = { "message", "grant", "grantsplit", "condition", "choice", "call", "pay", "paymulti",
    "roll", "apply", "compose", "declare", "compute", "distribute", "dispel", "allocate", "effect" }

local function LibelleNoeud(cle, noeud)
    local nom = noeud.label ~= nil and noeud.label ~= "" and noeud.label or noeud.nom or noeud.name or noeud.id or ""
    local genre = noeud.type or noeud.kind or noeud.op
    return (genre and ("[" .. tostring(genre) .. "] ") or "") .. (nom ~= "" and tostring(nom) or tostring(cle))
end

-- Aplatit l'arbre : { profondeur, libelle, noeud, parent, index }.
local function Aplatir(liste, profondeur, out, parent)
    for index, noeud in ipairs(liste) do
        if type(noeud) == "table" then
            out[#out + 1] = { profondeur = profondeur, libelle = LibelleNoeud(index, noeud), noeud = noeud,
                              parent = parent, index = index }
            for cle, valeur in pairs(noeud) do
                if type(valeur) == "table" and valeur[1] ~= nil and type(valeur[1]) == "table" then
                    out[#out + 1] = { profondeur = profondeur + 1, libelle = tostring(cle), groupe = valeur, noeud = noeud }
                    Aplatir(valeur, profondeur + 2, out, valeur)
                end
            end
        end
    end
    return out
end

function Editeur.Arbre(f, ed, champ, racine, y, lecture)
    local largeur = ed:GetWidth()
    -- L'arbre se modifie sur la copie de travail elle-meme : on la cree au
    -- premier geste.
    local donnees = Lire(f.travail, champ)
    if type(donnees) ~= "table" then
        donnees = {}
        Ecrire(f.travail, champ, donnees)
    end
    ed.etiquette:SetText(champ.type == "feuilles" and "Cheminement (feuilles, étapes, branches)" or "Lignes de calcul")
    ed.arbre = ed.arbre or {}
    local lignes = Aplatir(donnees, 0, {}, donnees)
    local yl = y + 20
    for n, info in ipairs(lignes) do
        local b = ed.arbre[n]
        if not b then
            b = UI.Bouton(ed, "", 10, 18, function(bouton) ed.choisi = bouton.info.noeud f:Afficher() end)
            b.label:ClearAllPoints()
            b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
            b.label:SetJustifyH("LEFT")
            ed.arbre[n] = b
        end
        b.info = info
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", ed, "TOPLEFT", 8 + info.profondeur * 14, -yl)
        b:SetWidth(math.max(120, largeur - 16 - info.profondeur * 14))
        b.label:SetText((info.groupe and "|cff99907f" or "") .. info.libelle .. (info.groupe and "|r" or ""))
        b:Selectionner(info.noeud == ed.choisi and not info.groupe)
        b:Show()
        yl = yl + 20
    end
    for n = #lignes + 1, #ed.arbre do ed.arbre[n]:Hide() end

    -- Gestes sur le noeud choisi : monter, descendre, retirer, ajouter.
    ed.outils = ed.outils or {
        ajouter = Action(ed, champ.type == "feuilles" and "+ Étape" or "+ Ligne"),
        feuille = Action(ed, "+ Feuille"),
        monter = Action(ed, "^"), descendre = Action(ed, "v"), retirer = Action(ed, "Retirer"),
    }
    local o = ed.outils
    local choisiInfo
    for _, info in ipairs(lignes) do if info.noeud == ed.choisi and not info.groupe then choisiInfo = info end end
    local x = 8
    for _, nom in ipairs({ "ajouter", "feuille", "monter", "descendre", "retirer" }) do
        local b = o[nom]
        local montrer = not lecture and (nom == "ajouter" or (nom == "feuille" and champ.type == "feuilles")
            or (choisiInfo ~= nil and nom ~= "ajouter" and nom ~= "feuille"))
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", ed, "TOPLEFT", x, -yl - 2)
        b:SetShown(montrer)
        if montrer then x = x + b:GetWidth() + 8 end
    end
    local function Liste() return choisiInfo and choisiInfo.parent end
    o.monter:SetScript("OnClick", function()
        local l, i = Liste(), choisiInfo.index
        if i > 1 then l[i], l[i - 1] = l[i - 1], l[i] end
        f:Afficher()
    end)
    o.descendre:SetScript("OnClick", function()
        local l, i = Liste(), choisiInfo.index
        if i < #l then l[i], l[i + 1] = l[i + 1], l[i] end
        f:Afficher()
    end)
    o.retirer:SetScript("OnClick", function()
        table.remove(Liste(), choisiInfo.index)
        ed.choisi = nil
        f:Afficher()
    end)
    o.feuille:SetScript("OnClick", function()
        donnees[#donnees + 1] = { id = "s_" .. (#donnees + 1), nom = "Feuille " .. (#donnees + 1), etapes = {} }
        f:Afficher()
    end)
    o.ajouter:SetScript("OnClick", function(b)
        if champ.type == "calcul" then
            donnees[#donnees + 1] = { id = "l_" .. (#donnees + 1), label = "", op = "valeur", operands = {}, sortie = false }
            f:Afficher()
            return
        end
        -- Une etape va dans la feuille choisie, ou la liste d'etapes du noeud
        -- choisi, a defaut dans la premiere feuille.
        local cible = ed.choisi and (ed.choisi.etapes or ed.choisi.steps)
        if not cible then
            if #donnees == 0 then donnees[1] = { id = "s_1", nom = "Feuille 1", etapes = {} } end
            cible = donnees[1].etapes
        end
        local options = {}
        for _, genre in ipairs(TYPES_ETAPE) do options[#options + 1] = { id = genre, label = genre } end
        f.choix.titre:SetText("Type d'étape")
        f.choix:Proposer(b, options, function(genre)
            cible[#cible + 1] = { type = genre, label = "", id = genre .. "_" .. (#cible + 1) }
            f:Afficher()
        end)
    end)
    yl = yl + 26

    -- Proprietes du noeud choisi : ses valeurs simples, une ligne chacune.
    ed.proprietes = ed.proprietes or {}
    local cles = {}
    if choisiInfo then
        for cle, valeur in pairs(choisiInfo.noeud) do
            if type(valeur) ~= "table" then cles[#cles + 1] = cle end
        end
        table.sort(cles, function(a, b) return tostring(a) < tostring(b) end)
    end
    for n, cle in ipairs(cles) do
        local p = ed.proprietes[n]
        if not p then
            p = CreateFrame("Frame", nil, ed)
            p:SetHeight(22)
            p.nom = UI.Texte(p, "", UI.C.libelle, "GameFontNormalSmall")
            p.nom:SetPoint("LEFT", p, "LEFT", 0, 0)
            p.nom:SetWidth(150)
            p.saisie = UI.Champ(p, 300, 20)
            p.saisie:SetMaxLetters(2000)
            p.saisie:SetPoint("LEFT", p, "LEFT", 156, 0)
            ed.proprietes[n] = p
        end
        local noeud = choisiInfo.noeud
        local avant = noeud[cle]
        p.nom:SetText(tostring(cle))
        p.saisie:SetWidth(math.max(160, largeur - 180))
        p.saisie:SetText(tostring(avant))
        p.saisie:SetEnabled(not lecture)
        p.saisie:SetScript("OnTextChanged", function(saisie, parLUtilisateur)
            if parLUtilisateur == false then return end
            local texte = saisie:GetText() or ""
            -- Le genre de la valeur est garde : un booleen reste un booleen.
            if type(avant) == "boolean" then noeud[cle] = texte == "true"
            elseif type(avant) == "number" then noeud[cle] = tonumber(texte) or texte
            else noeud[cle] = texte end
        end)
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", ed, "TOPLEFT", 8, -yl)
        p:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -8, -yl)
        p:Show()
        yl = yl + 24
    end
    for n = #cles + 1, #ed.proprietes do ed.proprietes[n]:Hide() end
    return yl + 4
end

-- ===== Gestes depuis la fenetre du compendium ===============================

local function Fenetre()
    local parent = UI.Compendium.Fenetre()
    return Editeur.frame or Construire(parent)
end

-- Le bouton engrenage d'un PNJ ouvre sa vraie fiche. On travaille sur une
-- entite locale (donc editable par les controles ordinaires de la fiche),
-- puis chaque modification de contenu est reconvertie en definition de PNJ
-- et rangee dans les brouillons du compendium.
local function DefinitionPNJDepuisEntite(entity, original)
    local niveaux = {}
    for _, metier in ipairs(LCM.Metiers.list or {}) do
        local rang = LCM.Metiers.Palier(entity, metier.id).rang
        if rang > 0 then niveaux[metier.id] = rang end
    end
    return {
        id = original.id,
        label = entity.name or original.label,
        icone = original.icone,
        valeurs = LCM.Copie(entity.values or {}),
        traits = LCM.Copie(entity.traits or {}),
        metiersNiveaux = niveaux,
        equipement = LCM.Copie(entity.equipement or {}),
        etats = LCM.Copie(entity.etats or {}),
        apprentissages = LCM.Copie(entity.apprentissages or {}),
    }
end

local function OuvrirFichePNJ(element)
    if not (UI.ConsultationMJ and UI.ConsultationMJ.Ouvrir) then
        return false, "consultation de fiche indisponible."
    end
    local original = LCM.Copie(element)
    local remplacePublie = Brouillons.EstPublie("pnj", element.id)
    local entity = {
        id = "edition-pnj:" .. tostring(element.id),
        modele = element.id,
        name = element.label,
        icon = element.icone,
        kind = "npc",
        values = LCM.Copie(element.valeurs or {}),
        traits = LCM.Copie(element.traits or {}),
        metiers = LCM.Copie(element.metiers or {}),
        equipement = LCM.Copie(element.equipement or {}),
        etats = LCM.Copie(element.etats or {}),
        apprentissages = LCM.Copie(element.apprentissages or {}),
        editionPNJ = true,
    }
    entity.__sauverPNJ = function(courant)
        local definition = DefinitionPNJDepuisEntite(courant, original)
        local ok, raison = Brouillons.Enregistrer("pnj", definition, false, remplacePublie)
        if ok and UI.Compendium and UI.Compendium.Actualiser then UI.Compendium.Actualiser() end
        return ok, raison
    end
    if Editeur.frame then Editeur.frame:Hide() end
    UI.ConsultationMJ.Ouvrir(entity, "fiche")
    return true
end

function Editeur.Ouvrir(categorie, element)
    -- Un nouveau PNJ est une fiche, pas une collection de champs bruts. Le
    -- compagnon confie donc sa creation au parcours complet de personnage puis
    -- enregistre le resultat dans les brouillons du compendium MJ.
    if not element and categorie and (categorie.id == "pnj" or categorie.famille == "pnj") then
        if Editeur.frame then Editeur.frame:Hide() end
        if not (UI.Creation and UI.Creation.OuvrirPNJ and LCM.Creation and LCM.Creation.DefinitionPNJ) then
            LCM.Alerte("créateur de PNJ indisponible.")
            return false
        end
        local fenetre, raison = UI.Creation.OuvrirPNJ(function(brouillon)
            local definition, erreur = LCM.Creation.DefinitionPNJ(brouillon, Brouillons.NouvelIdentifiant())
            if not definition then return false, erreur end
            local ok, refus = Brouillons.Enregistrer("pnj", definition, true)
            if not ok then return false, refus end
            UI.Compendium.Actualiser()
            return true, definition.label
        end)
        if not fenetre then LCM.Alerte(tostring(raison)) return false end
        return true
    end
    if element and categorie and (categorie.id == "pnj" or categorie.famille == "pnj") then
        local ok, raison = OuvrirFichePNJ(element)
        if not ok then LCM.Alerte("PNJ : " .. tostring(raison)) end
        return ok
    end
    -- Les entrees dosees par la Forge se reprennent dans la Forge elle-meme :
    -- l'ancien panneau a champs du compendium faisait doublon et separait le
    -- nom/la description des statistiques et de leur pool.
    if element and UI.Forge and UI.Forge.EstCategorie(categorie) then
        if Editeur.frame then Editeur.frame:Hide() end
        local ok, raison = UI.Forge.OuvrirEdition(categorie, element)
        if not ok then LCM.Alerte("Forge : " .. tostring(raison)) end
        return ok
    end
    -- Une categorie qui a son propre editeur (les jeux de la forge) l'ouvre :
    -- sa structure ne tient pas dans des champs.
    local propre = categorie and categorie.editeur and MJ[categorie.editeur]
    if propre then return propre.Editer(element) end
    Fenetre():Ouvrir(categorie, element)
end

-- Duplique en brouillon (« Nom (copie) ») : c'est aussi la voie pour
-- corriger un contenu publie.
function Editeur.Dupliquer(categorie, element)
    if not C.Editable(categorie) then return false, categorie.lectureSeule or "categorie en lecture seule" end
    local t = Travail(categorie, element)
    t.creation = true
    t.e.id = Brouillons.NouvelIdentifiant()
    t.e.label = Texte(element.label) .. " (copie)"
    local def, raison = Definition(t)
    if not def then return false, raison end
    local ok, refus = Brouillons.Enregistrer(categorie.famille, def, true)
    if not ok then return false, refus end
    return true, def.label
end

-- Supprime ce qui est brouillon ; le contenu publie est refuse, et dit.
function Editeur.Supprimer(categorie, elements)
    local faits, masques, refus = 0, {}, {}
    for _, element in ipairs(elements) do
        if element.brouillon == true then
            if Brouillons.Supprimer(categorie.famille, element.id) then faits = faits + 1 end
        else
            -- Publie : on ne peut pas toucher au fichier depuis le jeu, mais on
            -- peut le MASQUER — l'entree disparait tout de suite et reste
            -- masquee d'une session a l'autre. Refuser net ne laissait aucune
            -- issue (5 octobre 2026).
            local ok = Brouillons.Masquer(categorie.famille, element.id)
            if ok then masques[#masques + 1] = element.label
            else refus[#refus + 1] = element.label end
        end
    end
    UI.Compendium.Actualiser()
    local notes = {}
    if #masques > 0 then
        notes[#notes + 1] = string.format("%s masqué(s) : retiré(s) du jeu, à retirer du fichier "
            .. "à la prochaine passe", table.concat(masques, ", "))
    end
    if #refus > 0 then
        notes[#notes + 1] = table.concat(refus, ", ") .. " (refusé)"
    end
    return faits + #masques, #notes > 0 and table.concat(notes, " ; ") or nil
end

-- Modification groupee : un champ, une valeur, appliques a chaque brouillon
-- selectionne. Le contenu publie est ignore, et compte.
function Editeur.ModifGroupee(categorie, elements)
    -- Les champs d'une categorie a editeur propre sont des resumes calcules :
    -- les ecrire n'aurait aucun sens.
    if categorie.editeur then
        LCM.Alerte(categorie.label .. " : pas de modification groupee, chacun s'edite dans sa fenetre.")
        return
    end
    local f = Fenetre()
    local champs = {}
    for _, champ in ipairs(Champs(categorie)) do
        if champ.type == "texte" or champ.type == "nombre" or champ.type == "statistique" or champ.type == "texte_long" then
            champs[#champs + 1] = { id = champ, label = champ.label, groupe = champ.dossier }
        end
    end
    f.choix.titre:SetText("Modifier quel champ ?")
    f.choix:Proposer(nil, champs, function(champ)
        Editeur.Groupe(categorie, elements, champ)
    end)
end

function Editeur.Groupe(categorie, elements, champ)
    local g = Editeur.groupe
    if not g then
        g = CreateFrame("Frame", "LCM_CompendiumGroupe", UI.Compendium.Fenetre())
        g:SetSize(340, 150)
        g:SetPoint("CENTER", UI.Compendium.Fenetre(), "CENTER", 0, 0)
        g:SetFrameStrata("FULLSCREEN_DIALOG")
        g:EnableMouse(true)
        g.fond = UI.Aplat(g, UI.C.fond)
        g.fond:SetAllPoints(g)
        UI.BordureFine(g, 0.38)
        g.titre = UI.Texte(g, "", UI.C.titre, "GameFontNormalSmall")
        g.titre:SetPoint("TOPLEFT", g, "TOPLEFT", 12, -12)
        g.saisie = UI.Champ(g, 300, 22)
        g.saisie:SetMaxLetters(400)
        g.saisie:SetPoint("TOPLEFT", g, "TOPLEFT", 20, -50)
        g.message = UI.Texte(g, "", UI.C.discret, "GameFontNormalSmall")
        g.message:SetPoint("TOPLEFT", g, "TOPLEFT", 20, -80)
        g.message:SetPoint("TOPRIGHT", g, "TOPRIGHT", -20, -80)
        g.message:SetWordWrap(true)
        g.ok = Action(g, "Appliquer")
        g.ok:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -12, 12)
        g.annuler = Action(g, "Annuler")
        g.annuler:SetPoint("RIGHT", g.ok, "LEFT", -10, 0)
        g.annuler:SetScript("OnClick", function() g:Hide() end)
        Editeur.groupe = g
    end
    g.titre:SetText(string.format("%s — %d entrée(s)", champ.label, #elements))
    g.saisie:SetText("")
    g.message:SetText("")
    g.ok:SetScript("OnClick", function()
        local brut = Texte(g.saisie:GetText())
        local valeur = brut
        if champ.type == "nombre" or champ.type == "statistique" then
            valeur = (brut == "" or (champ.type == "statistique" and tonumber(brut) == 0)) and nil or (tonumber(brut) or brut)
        elseif brut == "" then
            valeur = nil
        end
        local faits, refus = 0, {}
        for _, element in ipairs(elements) do
            if element.brouillon ~= true then
                refus[#refus + 1] = element.label .. " (publié)"
            else
                local t = Travail(categorie, element)
                Ecrire(t, champ, valeur)
                local def, raison = Definition(t)
                local ok, pourquoi = def ~= nil, raison
                if def then ok, pourquoi = Brouillons.Enregistrer(categorie.famille, def, false) end
                if ok then faits = faits + 1 else refus[#refus + 1] = element.label .. " : " .. tostring(pourquoi) end
            end
        end
        UI.Compendium.Actualiser()
        if #refus > 0 then
            g.message:SetText(string.format("%d modifiée(s). Refus : %s", faits, table.concat(refus, " ; ")))
            g.message:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])
        else
            g:Hide()
        end
    end)
    g:Show()
    g:Raise()
end

LCM.WhenReady(function()
    if UI.Compendium then UI.Compendium.Editeur = Editeur end
end)
