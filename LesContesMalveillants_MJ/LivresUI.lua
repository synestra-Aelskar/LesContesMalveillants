-- Editeur MJ des notes et livres du compendium.
local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Ecran = {}
MJ.LivresUI = Ecran
LCM.LivresUI = Ecran

local PRESETS = {
    { label = "Parchemin", fond = "E5D3A3", encre = "302317", accent = "8D632D" },
    { label = "Ivoire", fond = "F5EEDC", encre = "292820", accent = "846B3D" },
    { label = "Nuit", fond = "202735", encre = "E9DDBF", accent = "C5A265" },
}

local function NouvellePage() return { titre = "", texte = "" } end

local function Construire()
    local f = UI.Fenetre("editeur_livres", "Éditer un livre", 820, 680,
        { x = 20, y = -10 }, { enTeteSimple = true, sobre = true })
    local c = f.contenu
    local function Legende(texte, x, y)
        local fs = UI.Texte(c, texte, UI.C.discret, "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
        return fs
    end
    Legende("Nom", 20, 12)
    f.nom = UI.Champ(c, 360, 23, function(texte) if f.travail then f.travail.label = texte end end)
    f.nom:SetMaxLetters(120)
    f.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 80, -8)
    Legende("Icône", 458, 12)
    f.icone = UI.Bouton(c, "Choisir", 115, 23, function(self)
        Ecran.selecteur = Ecran.selecteur or UI.SelecteurIcone("livre")
        Ecran.selecteur:Proposer(self, function(chemin)
            f.travail.icone = chemin
            f.icone.label:SetText("Icône choisie")
        end)
    end)
    f.icone:SetPoint("TOPLEFT", c, "TOPLEFT", 505, -8)

    Legende("Format", 20, 52)
    f.note = UI.Bouton(c, "Note recto verso", 150, 24, function()
        if f.travail.format == "note" then return end
        f.travail.format = "note"
        f.travail.pages[1] = f.travail.pages[1] or NouvellePage()
        f.travail.pages[2] = f.travail.pages[2] or NouvellePage()
        for index = #f.travail.pages, 3, -1 do table.remove(f.travail.pages, index) end
        f.selection = 1
        f:Afficher()
    end)
    f.note:SetPoint("TOPLEFT", c, "TOPLEFT", 80, -45)
    f.livre = UI.Bouton(c, "Livre", 110, 24, function()
        if f.travail.format == "livre" then return end
        f.travail.format = "livre"
        f.selection = "couverture"
        f:Afficher()
    end)
    f.livre:SetPoint("LEFT", f.note, "RIGHT", 8, 0)

    -- Une liste deroulante : un bouton qui tournait d'un modele au suivant
    -- obligeait a tous les parcourir (21 octobre 2026).
    f.modele = UI.Deroulant(c, 380, 24, function()
        local options = {}
        for _, modele in ipairs(LCM.Livres.Modeles) do
            options[#options + 1] = { id = modele.id, label = modele.label }
        end
        return options
    end, function(id)
        f.travail.modele = id
        f:AfficherStyle()
    end)
    f.modele:SetPoint("TOPRIGHT", c, "TOPRIGHT", -30, -45)

    Legende("Style", 20, 89)
    for index, preset in ipairs(PRESETS) do
        local b = UI.Bouton(c, preset.label, 110, 22, function()
            local style = f.travail.style
            style.fond, style.encre, style.accent = preset.fond, preset.encre, preset.accent
            f:AfficherStyle()
        end)
        b:SetPoint("TOPLEFT", c, "TOPLEFT", 80 + (index - 1) * 118, -82)
    end
    Legende("Fond", 20, 125)
    Legende("Encre", 205, 125)
    Legende("Accent", 390, 125)
    local function Couleur(cle, x)
        local champ = UI.Champ(c, 94, 22, function(texte)
            if f.travail then f.travail.style[cle] = texte end
        end)
        champ:SetMaxLetters(7)
        champ:SetPoint("TOPLEFT", c, "TOPLEFT", x, -117)
        return champ
    end
    f.fond = Couleur("fond", 80)
    f.encre = Couleur("encre", 265)
    f.accent = Couleur("accent", 450)
    f.alignement = UI.Bouton(c, "Alignement : gauche", 175, 22, function(self)
        local style = f.travail.style
        style.alignement = style.alignement == "CENTER" and "LEFT" or "CENTER"
        self.label:SetText(style.alignement == "CENTER" and "Alignement : centré" or "Alignement : gauche")
    end)
    f.alignement:SetPoint("TOPRIGHT", c, "TOPRIGHT", -18, -117)

    Legende("Résumé", 20, 150)
    f.description = UI.Champ(c, 680, 22, function(texte)
        if f.travail then f.travail.description = texte end
    end)
    f.description:SetMaxLetters(220)
    f.description:SetPoint("TOPLEFT", c, "TOPLEFT", 80, -143)

    Legende("Pages", 20, 170)
    f.pages = UI.Defilement(c)
    f.pages:SetPoint("TOPLEFT", c, "TOPLEFT", 20, -190)
    f.pages:SetSize(185, 345)
    f.lignes = {}
    f.ajouter = UI.Bouton(c, "+ Page", 82, 23, function()
        if f.travail.format ~= "livre" then return end
        if #f.travail.pages >= 32 then LCM.Alerte("32 pages maximum.") return end
        f.travail.pages[#f.travail.pages + 1] = NouvellePage()
        f.selection = #f.travail.pages
        f:Afficher()
    end)
    f.ajouter:SetPoint("TOPLEFT", c, "TOPLEFT", 20, -548)
    f.monter = UI.Bouton(c, "↑", 29, 23, function()
        local i = f.selection
        if type(i) ~= "number" or i <= 1 then return end
        local p = f.travail.pages
        p[i], p[i - 1] = p[i - 1], p[i]
        f.selection = i - 1
        f:Afficher()
    end)
    f.monter:SetPoint("LEFT", f.ajouter, "RIGHT", 4, 0)
    f.descendre = UI.Bouton(c, "↓", 29, 23, function()
        local i = f.selection
        local p = f.travail.pages
        if type(i) ~= "number" or i >= #p then return end
        p[i], p[i + 1] = p[i + 1], p[i]
        f.selection = i + 1
        f:Afficher()
    end)
    f.descendre:SetPoint("LEFT", f.monter, "RIGHT", 4, 0)
    f.retirer = UI.Bouton(c, "×", 29, 23, function()
        local i = f.selection
        if f.travail.format ~= "livre" or type(i) ~= "number" or #f.travail.pages <= 1 then return end
        table.remove(f.travail.pages, i)
        f.selection = math.min(i, #f.travail.pages)
        f:Afficher()
    end)
    f.retirer:SetPoint("LEFT", f.descendre, "RIGHT", 4, 0)

    Legende("Titre de la page", 230, 170)
    f.titrePage = UI.Champ(c, 540, 23, function(texte)
        local page = f:Page()
        if page then page.titre = texte end
    end)
    f.titrePage:SetMaxLetters(120)
    f.titrePage:SetPoint("TOPLEFT", c, "TOPLEFT", 230, -190)
    Legende("Contenu", 230, 232)
    f.texte = UI.Zone(c, 540, 290, function(texte)
        local page = f:Page()
        if page then page.texte = texte end
    end)
    f.texte.saisie:SetMaxLetters(4000)
    f.texte:SetPoint("TOPLEFT", c, "TOPLEFT", 230, -252)
    f.erreur = UI.Texte(c, "", { 1, 0.4, 0.35 }, "GameFontNormalSmall")
    f.erreur:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 20, 52)
    f.erreur:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -20, 52)
    f.apercu = UI.Bouton(c, "Aperçu", 105, 25, function()
        local ok, raison = UI.Livres.Apercu(f.travail)
        if not ok then f.erreur:SetText(tostring(raison)) end
    end)
    f.apercu:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 20, 14)
    f.enregistrer = UI.Bouton(c, "Enregistrer", 140, 25, function() f:Enregistrer() end)
    f.enregistrer:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -20, 14)

    function f:Page()
        if not self.travail then return nil end
        if self.selection == "couverture" then return self.travail.couverture end
        if self.selection == "dos" then return self.travail.dos end
        return self.travail.pages[self.selection or 1]
    end

    function f:AfficherStyle()
        local s = self.travail.style
        self.modele:Definir(self.travail.modele or LCM.Livres.MODELE_DEFAUT)
        self.modele:SetShown(self.travail.format == "livre")
        self.fond:SetText(s.fond)
        self.encre:SetText(s.encre)
        self.accent:SetText(s.accent)
        self.alignement.label:SetText(s.alignement == "CENTER" and "Alignement : centré" or "Alignement : gauche")
    end

    function f:Afficher()
        local livre = self.travail
        self.nom:SetText(livre.label or "")
        self.description:SetText(livre.description or "")
        self.icone.label:SetText(livre.icone and "Icône choisie" or "Choisir")
        self.note:Selectionner(livre.format == "note")
        self.livre:Selectionner(livre.format == "livre")
        self:AfficherStyle()
        local choix = {}
        if livre.format == "livre" then choix[#choix + 1] = { id = "couverture", label = "Couverture" } end
        for i = 1, #livre.pages do
            choix[#choix + 1] = { id = i, label = livre.format == "note"
                and (i == 1 and "Recto" or "Verso") or ("Page " .. i) }
        end
        if livre.format == "livre" then choix[#choix + 1] = { id = "dos", label = "Dos" } end
        for rang, entree in ipairs(choix) do
            local ligne = self.lignes[rang]
            if not ligne then
                ligne = UI.Bouton(self.pages.contenu, "", 172, 25, function(self)
                    f.selection = self.identifiant
                    f:Afficher()
                end)
                self.lignes[rang] = ligne
            end
            ligne.identifiant = entree.id
            ligne.label:SetText(entree.label)
            ligne:Selectionner(self.selection == entree.id)
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", self.pages.contenu, "TOPLEFT", 0, -(rang - 1) * 28)
            ligne:Show()
        end
        for rang = #choix + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.pages:Regler(#choix * 28)
        self.ajouter:SetShown(livre.format == "livre")
        self.monter:SetShown(livre.format == "livre")
        self.descendre:SetShown(livre.format == "livre")
        self.retirer:SetShown(livre.format == "livre")
        local page = self:Page()
        self.titrePage:SetText(page and page.titre or "")
        self.texte:SetText(page and page.texte or "")
    end

    function f:Enregistrer()
        local livre = self.travail
        if not tostring(livre.label or ""):match("%S") then self.erreur:SetText("Donne un nom au livre.") return false end
        local ok, raison = pcall(LCM.Livres.Construire, livre)
        if not ok then self.erreur:SetText(tostring(raison)) return false end
        local ajoute, erreur = LCM.Brouillons.Enregistrer("livres", livre, self.nouveau)
        if not ajoute then self.erreur:SetText(tostring(erreur)) return false end
        self.erreur:SetText("")
        if UI.Compendium and UI.Compendium.Actualiser then UI.Compendium.Actualiser() end
        self:Hide()
        return true
    end

    function f:Editer(element)
        self.nouveau = element == nil
        self.travail = element and LCM.Copie(element) or {
            id = LCM.Brouillons.NouvelIdentifiant(), label = "", format = "note", modele = "chronique",
            icone = "INV_Misc_Note_01", style = {
                fond = "E5D3A3", encre = "302317", accent = "8D632D", alignement = "LEFT" },
            pages = { NouvellePage(), NouvellePage() },
            couverture = NouvellePage(), dos = NouvellePage(),
        }
        self.travail.style = self.travail.style or {
            fond = "E5D3A3", encre = "302317", accent = "8D632D", alignement = "LEFT" }
        self.travail.modele = self.travail.modele or LCM.Livres.MODELE_DEFAUT
        self.travail.couverture = self.travail.couverture or NouvellePage()
        self.travail.dos = self.travail.dos or NouvellePage()
        self.selection = self.travail.format == "livre" and "couverture" or 1
        self.erreur:SetText("")
        self:Afficher()
        self:Show()
        UI.Devant(self)
    end
    f:Hide()
    return f
end

function Ecran.Editer(element)
    Ecran.frame = Ecran.frame or Construire()
    Ecran.frame:Editer(element)
    return true
end
