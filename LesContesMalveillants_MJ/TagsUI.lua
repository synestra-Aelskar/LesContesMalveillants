-- Constructeur des tags du compendium : une fiche courte, comme celle des
-- lanternes, avec les origines de Liste origine et un parent facultatif.
local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Ecran = {}
MJ.TagsUI = Ecran
LCM.TagsUI = Ecran

local LARGEUR, MARGE = 404, 14
local CHAMP = LARGEUR - 24 - 2 * MARGE
local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Menu leger, attache sous le champ parent. La liste ne prend que la place
-- necessaire ; la recherche et le defilement apparaissent quand elle grandit.
local function MenuParent(f)
    local d = CreateFrame("Frame", nil, f)
    d:SetWidth(CHAMP)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetClampedToScreen(true)
    d:EnableMouse(true)
    d.fond = UI.Aplat(d, { UI.C.fond[1], UI.C.fond[2], UI.C.fond[3], 1 })
    d.fond:SetAllPoints(d)
    UI.BordureFine(d, 0.7)
    d.lignes = {}
    d.recherche = UI.Champ(d, CHAMP - 12, 20, function() d:Rendre() end)
    d.recherche:SetMaxLetters(80)
    d.recherche:SetPoint("TOPLEFT", d, "TOPLEFT", 6, -6)
    d.zone = UI.Defilement(d)
    d.aucun = UI.Texte(d.zone.contenu, "Aucun tag trouvé", UI.C.discret, "GameFontNormalSmall")
    d.aucun:SetPoint("TOPLEFT", d.zone.contenu, "TOPLEFT", 8, -7)

    function d:Rendre()
        local filtre = Texte(self.recherche:GetText()):lower()
        local visibles = {}
        for _, option in ipairs(self.options or {}) do
            if filtre == "" or tostring(option.label):lower():find(filtre, 1, true) then
                visibles[#visibles + 1] = option
            end
        end
        local recherche = #self.options > 8
        self.recherche:SetShown(recherche)
        self.zone:ClearAllPoints()
        self.zone:SetPoint("TOPLEFT", self, "TOPLEFT", 4, recherche and -32 or -4)
        self.zone:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -14, 4)
        self:SetHeight((recherche and 32 or 4) + 8 + 24 * math.max(1, math.min(#visibles, 8)))
        for i, option in ipairs(visibles) do
            local ligne = self.lignes[i]
            if not ligne then
                ligne = UI.Bouton(self.zone.contenu, "", CHAMP - 18, 22, function(b)
                    d:Hide()
                    if d.surChoix then d.surChoix(b.choix) end
                end)
                ligne.label:ClearAllPoints()
                ligne.label:SetPoint("LEFT", ligne, "LEFT", 8, 0)
                ligne.label:SetPoint("RIGHT", ligne, "RIGHT", -8, 0)
                ligne.label:SetJustifyH("LEFT")
                ligne.label:SetWordWrap(false)
                self.lignes[i] = ligne
            end
            ligne.choix = option.id
            ligne.label:SetText(option.label)
            ligne:Selectionner(option.id == self.selection)
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 2, -2 - (i - 1) * 24)
            ligne:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", -2, -2 - (i - 1) * 24)
            ligne:Show()
        end
        for i = #visibles + 1, #self.lignes do self.lignes[i]:Hide() end
        self.aucun:SetShown(#visibles == 0)
        self.zone:Regler(4 + math.max(1, #visibles) * 24)
        self.zone:Aller(0)
    end

    function d:Proposer(options, selection, choisir)
        self.options, self.selection, self.surChoix = options, selection, choisir
        self.recherche:SetText("")
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", f.parent, "BOTTOMLEFT", 0, -3)
        self:Rendre()
        self:Show()
        self:Raise()
    end
    d:Hide()
    return d
end

local function Construire()
    local f = UI.Fenetre("constructeur_tags", "Nouveau tag", LARGEUR, 470, { x = -170, y = 30 })
    local c = f.contenu
    local function Libelle(texte)
        return UI.Texte(c, texte, UI.C.libelle, "GameFontNormalSmall")
    end
    local function Poser(w, y, x)
        w:SetPoint("TOPLEFT", c, "TOPLEFT", x or MARGE, -y)
    end

    f.icone = CreateFrame("Button", nil, c)
    f.icone:SetSize(40, 40)
    Poser(f.icone, 20)
    UI.BordureFine(f.icone, 0.55)
    f.apercuIcone = f.icone:CreateTexture(nil, "ARTWORK")
    f.apercuIcone:SetPoint("TOPLEFT", f.icone, "TOPLEFT", 2, -2)
    f.apercuIcone:SetPoint("BOTTOMRIGHT", f.icone, "BOTTOMRIGHT", -2, 2)
    f.apercuIcone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    UI.Bulle(f.icone, "Icône du tag", "Clique pour choisir une icône.")
    f.icone:SetScript("OnClick", function(b)
        Ecran.selecteur = Ecran.selecteur or UI.SelecteurIcone("tags")
        Ecran.selecteur:Proposer(b, function(chemin)
            f.travail.icone = chemin
            f:AfficherIcone()
        end)
    end)

    f.lblNom = Libelle("Nom")
    Poser(f.lblNom, 8, 64)
    f.nom = UI.Champ(c, CHAMP - 50, 22)
    f.nom:SetMaxLetters(120)
    Poser(f.nom, 26, 64)

    f.lblDescription = Libelle("Description")
    Poser(f.lblDescription, 74)
    f.description = UI.Zone(c, CHAMP, 90)
    f.description.saisie:SetMaxLetters(512)
    Poser(f.description, 92)

    f.lblOrigine = Libelle("Origines")
    Poser(f.lblOrigine, 196)
    f.origine = UI.Bouton(c, "Aucune", CHAMP, 24, function(b)
        if f.choixParent then f.choixParent:Hide() end
        local parent = f.travail.parent and LCM.Etiquettes.Get(f.travail.parent)
        local permises = {}
        if parent then
            for _, id in ipairs(LCM.Etiquettes.Origines(parent)) do permises[id] = true end
        end
        local options = {}
        for _, entree in ipairs(LCM.Listes.De("origines")) do
            if not parent or permises[entree.id] then
                options[#options + 1] = { id = entree.id, label = tostring(entree.label or entree.id) }
            end
        end
        local coches = {}
        for _, id in ipairs(LCM.Etiquettes.Origines(f.travail)) do coches[id] = true end
        f.choixOrigine = f.choixOrigine or UI.ChoixCoches("tags_origines", "Origines du tag")
        f.choixOrigine.compact = true
        f.choixOrigine.aideTexte = parent
            and "Garde les origines où ce sous-tag existe."
            or "Coche toutes les origines concernées ; aucun choix = tag général."
        f.choixOrigine:Proposer("Origines du tag", {
            { label = parent and "Origines du parent" or "Liste origine", options = options },
        }, coches, function(ids)
            if parent and not ids[1] then
                f.erreur:SetText("Un sous-tag doit garder au moins une origine de son parent.")
                return
            end
            f.travail.origines = ids[1] and ids or nil
            f.travail.origine = nil
            f.erreur:SetText("")
            f:AfficherClassement()
        end)
    end)
    Poser(f.origine, 214)
    f.origine.label:ClearAllPoints()
    f.origine.label:SetPoint("LEFT", f.origine, "LEFT", 12, 0)
    f.origine.label:SetPoint("RIGHT", f.origine, "RIGHT", -12, 0)
    f.origine.label:SetJustifyH("LEFT")
    f.origine.label:SetWordWrap(false)
    f.aideOrigine = UI.Texte(c, "Plusieurs choix possibles ; aucune = tag général.",
        UI.C.discret, "GameFontNormalSmall")
    Poser(f.aideOrigine, 241)

    f.lblParent = Libelle("Tag parent (facultatif)")
    Poser(f.lblParent, 270)
    f.parent = UI.Bouton(c, "Aucun", CHAMP, 24, function(b)
        if f.choixParent and f.choixParent:IsShown() then f.choixParent:Hide() return end
        local options = { { id = "", label = "Aucun" } }
        local ajoutes = {}
        for _, groupe in ipairs(LCM.Etiquettes.Groupes()) do
            for _, ligne in ipairs(groupe.tags) do
                local candidat = ligne.tag
                local courant, vus = candidat, {}
                while courant and not vus[courant.id] do
                    if courant.id == f.travail.id then break end
                    vus[courant.id] = true
                    courant = courant.parent and LCM.Etiquettes.Get(courant.parent)
                end
                if not courant and not ajoutes[candidat.id] then
                    ajoutes[candidat.id] = true
                    options[#options + 1] = {
                        id = candidat.id,
                        label = LCM.Etiquettes.Chemin(candidat.id),
                    }
                end
            end
        end
        f.choixParent = f.choixParent or MenuParent(f)
        f.choixParent:Proposer(options, f.travail.parent or "", function(id)
            local avant = LCM.Copie(LCM.Etiquettes.Origines(f.travail))
            f.travail.parent = id ~= "" and id or nil
            f.travail.origines = f.travail.parent
                and LCM.Copie(LCM.Etiquettes.Origines(LCM.Etiquettes.Get(id))) or (avant[1] and avant or nil)
            f.travail.origine = nil
            f:AfficherClassement()
        end)
    end)
    Poser(f.parent, 288)
    f.parent.label:ClearAllPoints()
    f.parent.label:SetPoint("LEFT", f.parent, "LEFT", 12, 0)
    f.parent.label:SetPoint("RIGHT", f.parent, "RIGHT", -28, 0)
    f.parent.label:SetJustifyH("LEFT")
    f.parent.label:SetWordWrap(false)
    f.parent.fleche = f.parent:CreateTexture(nil, "OVERLAY")
    f.parent.fleche:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    f.parent.fleche:SetSize(14, 14)
    f.parent.fleche:SetPoint("RIGHT", f.parent, "RIGHT", -8, -2)
    f.aideParent = UI.Texte(c, "Le tag hérite de l'origine de son parent.",
        UI.C.discret, "GameFontNormalSmall")
    Poser(f.aideParent, 315)

    f.erreur = UI.Texte(c, "", { 1, 0.4, 0.35 }, "GameFontNormalSmall")
    f.erreur:SetWidth(CHAMP)
    Poser(f.erreur, 335)
    f.filetBas = UI.Filet(c)
    f.filetBas:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 34)
    f.filetBas:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 34)
    local moitie = math.floor((CHAMP - 8) / 2)
    f.valider = UI.Bouton(c, "Valider", moitie, 22, function() f:Valider() end)
    f.annuler = UI.Bouton(c, "Annuler", moitie, 22, function() f:Hide() end)
    f.valider:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", MARGE, 4)
    f.annuler:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -MARGE, 4)
    f:SetHeight(f.insetHaut + 389 + f.insetBas)

    function f:AfficherIcone()
        local icone = self.travail.icone
        self.apercuIcone:SetTexture(LCM.Icone(icone))
    end

    function f:AfficherClassement()
        local parent = self.travail.parent and LCM.Etiquettes.Get(self.travail.parent)
        local noms = {}
        for _, id in ipairs(LCM.Etiquettes.Origines(self.travail)) do
            local entree = LCM.Listes.Get(id)
            noms[#noms + 1] = entree and entree.label or ("? " .. id)
        end
        self.origine.label:SetText(noms[1] and table.concat(noms, ", ") or "Aucune")
        self.origine:SetEnabled(not parent or #LCM.Etiquettes.Origines(parent) > 0)
        self.aideOrigine:SetText(parent
            and "Ce sous-tag peut garder une partie des origines du parent."
            or "Plusieurs choix possibles ; aucune = tag général.")
        self.parent.label:SetText(parent and LCM.Etiquettes.Chemin(parent.id) or "Aucun")
    end

    function f:Valider()
        local nom = Texte(self.nom:GetText())
        if nom == "" then self.erreur:SetText("Donne un nom au tag.") return false end
        local def = self.travail
        def.label = nom
        def.description = self.description.saisie:GetText() or ""
        def.liste = "tags"
        local ok, raison = LCM.Brouillons.Enregistrer("listes", def, self.nouveau)
        if not ok then self.erreur:SetText(tostring(raison)) return false end
        self.erreur:SetText("")
        if UI.Compendium and UI.Compendium.Actualiser then UI.Compendium.Actualiser() end
        self:Hide()
        return true
    end

    function f:Editer(element)
        if self.choixParent then self.choixParent:Hide() end
        self.nouveau = element == nil
        self.travail = element and LCM.Copie(element) or {
            id = LCM.Brouillons.NouvelIdentifiant(), liste = "tags",
        }
        self:Titre(self.nouveau and "Nouveau tag" or "Modifier le tag")
        self.nom:SetText(self.travail.label or "")
        self.description:SetText(self.travail.description or "")
        self.erreur:SetText("")
        self:AfficherIcone()
        self:AfficherClassement()
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
