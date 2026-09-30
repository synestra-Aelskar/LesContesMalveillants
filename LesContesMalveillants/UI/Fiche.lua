-- La fenetre de fiche.
--
-- Elle se construit ENTIEREMENT a partir du schema : un champ ajoute dans
-- Data/ apparait ici sans une ligne de plus. Le rendu ne connait que les types
-- de champ.
--
-- La mise en page est celle du theme Ael'Raz'kah de Necronicon (AelLayout.lua,
-- AelWidgets.lua), reprise avec ses mesures : une section est un bloc encadre
-- avec un titre en capitales ; une ligne fait 62 unites sur 786 et place ses
-- colonnes aux memes abscisses que le modele (nom 96, plage 310, valeur 418,
-- modificateur 535, action 652 ; jauge de 270 a 540, boutons a 561 / 607 / 653).
-- Tout suit la largeur : une fenetre elargie grossit, elle ne s'etale pas.
--
-- Une seule fenetre, qui affiche l'entite qu'on lui donne : la sienne, ou celle
-- d'un PNJ. Joueurs et PNJ partagent la meme feuille, donc le meme ecran.

local _, LCM = ...
local UI = LCM.UI

local Fiche = {}
UI.Fiche = Fiche

local ECART_LIGNES = 6

local function Nombre(valeur)
    local n = tonumber(valeur)
    if not n then return tostring(valeur or "") end
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return string.format("%.2f", n)
end

local function Montant(n)
    return (n >= 0 and "+" or "") .. Nombre(n)
end

-- ===== Une ligne : surface, colonnes ======================================

-- Le fond de pierre et le cadre discret d'une ligne de fiche (UI.SkinAelRow).
local function Surface(l)
    if UI.AelRef then
        l.surface = UI.AelRef(l, 735, 800, 55, 30, "BACKGROUND")
        l.surface:SetAllPoints(l)
        l.surface:SetAlpha(0.65)
        l.cadre = UI.AelCadre(l, "controle")
        l.cadre:SetAlpha(0.25)
    else
        l.surface = UI.Aplat(l, UI.C.fondClair)
        l.surface:SetAllPoints(l)
    end
end

local function Ligne(parent, c)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(c.ligne)
    Surface(l)
    return l
end

-- Le nom, a sa place : apres l'icone s'il y en a une, sinon a la sienne.
local function Nom(l, c, texte, avecIcone)
    l.nom = UI.Texte(l, texte, UI.C.texte)
    UI.Police(l.nom, c.police)
    l.nom:SetPoint("LEFT", l, "LEFT", avecIcone and c.nom or c.nomSansIcone, 0)
    l.nom:SetWordWrap(false)
    l.label = l.nom
    return l.nom
end

-- Icone encadree et son separateur (UI.LayoutAelContainerRow).
local function Icone(l, c, texture)
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(math.min(c.iconeTaille, c.ligne - 4), math.min(c.iconeTaille, c.ligne - 4))
    l.icone:SetPoint("LEFT", l, "LEFT", c.icone, 0)
    l.icone:SetTexture(texture)
    l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if UI.AelCadre then
        local support = CreateFrame("Frame", nil, l)
        support:SetPoint("TOPLEFT", l.icone, "TOPLEFT", -2, 2)
        support:SetPoint("BOTTOMRIGHT", l.icone, "BOTTOMRIGHT", 2, -2)
        l.cadreIcone = UI.AelCadre(support, "icone")
        l.separateur = UI.AelRef(l, 202, 397, 15, 37, "ARTWORK")
        l.separateur:SetSize(12 * c.echelle, math.min(37 * c.echelle, c.ligne - 4))
        l.separateur:SetPoint("LEFT", l, "LEFT", c.separateur, 0)
    end
end

-- Une jauge du modele : barre avec embouts dores, chiffres contournes dessus,
-- trois boutons carres a droite. `rappels` : moins(), plus(), remise().
local function Jauge(l, c, couleur, rappels)
    local debut = c.barreDebut
    l.barre = UI.Barre(l, couleur, c.barreFin - debut, c.barreHauteur)
    l.barre:SetPoint("LEFT", l, "LEFT", debut, 0)
    UI.Police(l.barre.label, c.police, "OUTLINE")
    if UI.AelCadreJauge then l.cadreJauge = UI.AelCadreJauge(l.barre) end

    -- La barre commence apres le nom : une police plus grande ne la cache pas.
    function l:CaleBarre()
        local fin = c.barreFin
        local x = math.min(fin - 80 * c.echelle,
            math.max(debut, (self.nomX or c.nomSansIcone) + (self.nom:GetStringWidth() or 0) + 14 * c.echelle))
        self.barre:ClearAllPoints()
        self.barre:SetPoint("LEFT", self, "LEFT", x, 0)
        self.barre:SetWidth(fin - x)
        if self.barre.courant then self.barre:Regler(self.barre.courant, self.barre.maximum) end
    end

    if rappels then
        l.boutons = {}
        for i, def in ipairs({ { "-", rappels.moins }, { "+", rappels.plus }, { "R", rappels.remise } }) do
            local b = UI.Bouton(l, def[1], c.boutonL, c.boutonH, function() def[2]() end)
            b:SetPoint("LEFT", l, "LEFT", c.boutons[i], 0)
            UI.Police(b.label, c.police)
            l.boutons[i] = b
        end
    end
end

-- Bulle d'aide au survol d'une ligne.
local function Bulle(l, titre, texte)
    if not texte or texte == "" then return end
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(titre)
        GameTooltip:AddLine(texte, 0.88, 0.84, 0.76, true)
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

-- ===== Lignes, une par type de champ =======================================

local Lignes = {}

-- Valeur simple : le nom a gauche, la valeur alignee a droite sur la derniere
-- colonne (comme dans Deplacement chez Necronicon), bonus portes a la suite.
function Lignes.stat(parent, field, c)
    local l = Ligne(parent, c)
    Nom(l, c, field.label)
    l.valeur = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.valeur, c.police)
    l.valeur:SetPoint("RIGHT", l, "LEFT", c.action + c.actionLargeur, 0)
    l.valeur:SetJustifyH("RIGHT")
    Bulle(l, field.label, field.note)
    function l:Actualiser(e)
        local valeur = LCM.Entities.Get_Value(e, field.id)
        -- Un nombre saisi recoit les bonus portes (traits, objets), montres a
        -- part : « 2 +3 », pour qu'on sache ce qui vient de soi.
        local bonus = field.kind == "stat" and LCM.Effets.Bonus(e, field.id) or 0
        if bonus ~= 0 then
            self.valeur:SetText(Nombre(tonumber(valeur) or 0) .. " " .. Montant(bonus))
        else
            self.valeur:SetText(Nombre(valeur))
        end
    end
    return l
end

Lignes.calc = Lignes.stat
Lignes.text = Lignes.stat

local COULEURS_JAUGE = {
    fatigue = UI.C.fatigue,
    armure = UI.C.armure,
    pa = { 0.83, 0.68, 0.33 },
}

function Lignes.gauge(parent, field, c)
    local l = Ligne(parent, c)
    Nom(l, c, field.label)
    local function Poser(delta, absolu)
        local e = l.entity
        if not e then return end
        local jauge = LCM.Entities.Gauge(e, field.id)
        if not jauge then return end
        local cible = absolu or (jauge.current + delta)
        LCM.Entities.SetGauge(e, field.id, cible)
        l:Actualiser(e)
    end
    Jauge(l, c, COULEURS_JAUGE[field.id] or UI.C.vie, {
        moins = function() Poser(-1) end,
        plus = function() Poser(1) end,
        -- Remise : au defaut du champ s'il en a un (l'armure ponctuelle
        -- repart de zero), sinon au maximum.
        remise = function()
            local jauge = l.entity and LCM.Entities.Gauge(l.entity, field.id)
            if jauge then Poser(0, field.default ~= nil and field.default or jauge.max) end
        end,
    })
    Bulle(l, field.label, field.note)
    function l:Actualiser(e)
        self.entity = e
        local jauge = LCM.Entities.Gauge(e, field.id)
        if jauge then self.barre:Regler(jauge.current, jauge.max) end
        self:CaleBarre()
    end
    return l
end

function Lignes.roll(parent, field, c)
    local l = Ligne(parent, c)
    Nom(l, c, field.label)

    local dice = type(field.dice) == "table" and field.dice or {}
    l.plage = UI.Texte(l, string.format("%d-%d", tonumber(dice.min) or 0, tonumber(dice.max) or 0), UI.C.discret)
    UI.Police(l.plage, c.police)
    l.plage:SetPoint("LEFT", l, "LEFT", c.plage, 0)
    l.plage:SetWidth(c.plageLargeur)
    l.plage:SetJustifyH("CENTER")

    l.valeur = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.valeur, c.police)
    l.valeur:SetPoint("LEFT", l, "LEFT", c.valeur, 0)
    l.valeur:SetWidth(c.valeurLargeur)
    l.valeur:SetJustifyH("CENTER")

    l.bonus = UI.Texte(l, "", UI.C.accent)
    UI.Police(l.bonus, c.police)
    l.bonus:SetPoint("LEFT", l, "LEFT", c.modificateur, 0)
    l.bonus:SetWidth(c.modificateurLargeur - 22 * c.echelle)
    l.bonus:SetJustifyH("CENTER")

    -- La case d'avantage n'apparait que si un trait ou un objet l'accorde :
    -- inutile de proposer un choix qui n'en est pas un.
    l.avantage = CreateFrame("CheckButton", nil, l)
    local cote = math.max(14, 20 * c.echelle)
    l.avantage:SetSize(cote, cote)
    l.avantage:SetPoint("RIGHT", l, "LEFT", c.modificateur + c.modificateurLargeur, 0)
    l.avantage.fond = UI.Aplat(l.avantage, { 0.035, 0.030, 0.023, 1 })
    l.avantage.fond:SetAllPoints(l.avantage)
    UI.Bordure(l.avantage, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.7 })
    l.avantage.marque = UI.Texte(l.avantage, "", UI.C.accent, "GameFontNormalSmall")
    l.avantage.marque:SetAllPoints(l.avantage)
    l.avantage.marque:SetJustifyH("CENTER")
    l.avantage:SetScript("OnClick", function(bouton)
        bouton:SetChecked(not bouton:GetChecked())
        bouton.marque:SetText(bouton:GetChecked() and "v" or "")
    end)

    l.lancer = UI.Bouton(l, "Jet", c.actionLargeur, c.boutonH, function()
        local entite = l.entity
        if not entite then return end
        local resultat = LCM.Roll.Field(entite, field.id, { avantage = l.avantage:GetChecked() })
        if resultat then LCM.Info(LCM.Roll.Describe(resultat)) end
    end)
    l.lancer:SetPoint("LEFT", l, "LEFT", c.action, 0)
    UI.Police(l.lancer.label, c.police)
    Bulle(l, field.label, field.note)

    function l:Actualiser(e)
        self.entity = e
        -- Ce que le personnage vaut de lui-meme (investi + apport de ses
        -- primaires), puis ce qu'il porte, dans sa colonne.
        local valeur = (tonumber(LCM.Entities.Get_Value(e, field.id)) or 0) + LCM.Formules.Apport(e, field.id)
        local bonus = LCM.Effets.Bonus(e, field.id)
        self.valeur:SetText(Nombre(valeur))
        self.bonus:SetText(bonus ~= 0 and Montant(bonus) or "")
        local source = LCM.Effets.Avantage(e, field.id)
        self.avantage:SetShown(source ~= nil)
        if not source then
            self.avantage:SetChecked(false)
            self.avantage.marque:SetText("")
        end
    end
    return l
end

-- Le corps (template : fenetre Sante, onglet Physique) : une jauge des points
-- de vie, puis une jauge par zone avec son icone. Moins blesse, plus soigne,
-- R soigne la zone entiere. Les PV courants = PV max - blessures.
function Lignes.body(parent, field, c)
    local l = CreateFrame("Frame", nil, parent)
    l.zones = {}

    l.total = Ligne(l, c)
    l.total:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
    l.total:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, 0)
    Nom(l.total, c, "Points de vie")
    Jauge(l.total, c, UI.C.vie, nil)
    Bulle(l.total, "Points de vie",
        "Points de vie maximum moins les blessures de toutes les zones. Chaque zone vaut 30 % du maximum.")

    local function Zone(index)
        local z = Ligne(l, c)
        Icone(z, c, "Interface\\Icons\\INV_Misc_QuestionMark")
        Nom(z, c, "", true)
        z.nomX = c.nom
        local function Agir(fonction, montant)
            if not (l.entity and z.partieId) then return end
            fonction(l.entity, z.partieId, montant)
            l:Actualiser(l.entity)
            if l.onChange then l.onChange(l.entity) end
        end
        Jauge(z, c, { 0.30, 0.76, 0.42 }, {
            moins = function() Agir(LCM.Body.Damage, 1) end,
            plus = function() Agir(LCM.Body.Heal, 1) end,
            remise = function() Agir(LCM.Body.Heal, 1000000) end,
        })
        l.zones[index] = z
        return z
    end

    function l:Actualiser(e)
        self.entity = e
        local courant, maximum = LCM.Body.Totals(e)
        self.total.barre:Regler(courant, maximum)
        self.total:CaleBarre()

        local etat = LCM.Body.State(e)
        local y = c.ligne + ECART_LIGNES
        for index, partie in ipairs(etat) do
            local z = self.zones[index] or Zone(index)
            z.partieId = partie.id
            z.nom:SetText(partie.label)
            z.icone:SetTexture(partie.part.icone)
            Bulle(z, partie.label, partie.part.description)
            z.barre:Regler(partie.current, partie.max)
            z:CaleBarre()
            z:ClearAllPoints()
            z:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            z:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
            z:Show()
            y = y + c.ligne + ECART_LIGNES
        end
        for index = #etat + 1, #self.zones do self.zones[index]:Hide() end
        self:SetHeight(y - ECART_LIGNES)
    end
    l:SetHeight(c.ligne)
    return l
end

-- ----- Les traits portes ----------------------------------------------------
-- Une carte par trait : nom, cout, description, effets. Donner ou retirer un
-- trait est un geste de MJ : le joueur choisit les siens a la creation, avec
-- un budget ; ensuite, c'est la partie qui les accorde.

-- « Escalade +3  ·  Avantage : Escalade ». Trie, pour qu'un meme trait se lise
-- toujours pareil.
local function Effets(element)
    local bonus, avantages = {}, {}
    for champ, montant in pairs(element.bonus) do
        local field = LCM.Schema.Field(champ)
        bonus[#bonus + 1] = (field and field.label or champ) .. " " .. Montant(montant)
    end
    for champ in pairs(element.avantage) do
        local field = LCM.Schema.Field(champ)
        avantages[#avantages + 1] = field and field.label or champ
    end
    table.sort(bonus)
    table.sort(avantages)
    if #avantages > 0 then bonus[#bonus + 1] = "Avantage : " .. table.concat(avantages, ", ") end
    return table.concat(bonus, "  ·  ")
end

-- Une carte pour tout ce qui porte des effets (trait, objet) : la fenetre
-- d'equipement s'en sert aussi. `onRetirer(id)` est appele par la croix.
-- `largeur` : celle du texte (la carte, elle, suit ses ancrages).
function Fiche.Carte(parent, onRetirer, largeur)
    largeur = largeur or 480
    local c = CreateFrame("Frame", nil, parent)
    Surface(c)

    c.nom = UI.Texte(c, "", UI.C.titre, "GameFontNormal")
    c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -8)
    c.cout = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
    c.cout:SetPoint("TOPRIGHT", c, "TOPRIGHT", -34, -8)
    c.cout:SetJustifyH("RIGHT")
    -- L'identifiant est porte par la carte, lu au clic : les cartes sont
    -- reutilisees d'un affichage a l'autre.
    c.retirer = UI.Bouton(c, "x", 20, 20, function() onRetirer(c.elementId) end)
    c.retirer:SetPoint("TOPRIGHT", c, "TOPRIGHT", -6, -6)

    c.description = UI.Texte(c, "", UI.C.texte, "GameFontNormalSmall")
    c.description:SetWidth(largeur - 20)
    c.description:SetWordWrap(true)
    c.effets = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
    c.effets:SetWidth(largeur - 20)
    c.effets:SetWordWrap(true)

    -- Remplit la carte et renvoie sa hauteur. `element` est nil quand
    -- l'identifiant ne designe plus rien ; `coin` est le texte en haut a
    -- droite (le cout d'un trait).
    function c:Habiller(id, element, mj, coin)
        self.elementId = id
        local description, effets
        if element then
            self.nom:SetText(element.label .. (element.brouillon and "  |cff99907f· brouillon|r" or ""))
            self.nom:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
            self.cout:SetText(coin or "")
            description = element.description
            effets = Effets(element)
            if effets == "" then effets = "Aucun effet chiffré." end
        else
            -- Un element disparu reste montre : il est encore sur l'entite, et
            -- redevient actif s'il revient. Le taire ferait croire a une
            -- fiche saine.
            self.nom:SetText("? " .. tostring(id))
            self.nom:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])
            self.cout:SetText("")
            description = "N'existe pas dans cette version de l'addon (brouillon supprimé, "
                .. "ou contenu pas encore publié). Ne donne rien tant qu'il n'existe pas."
            effets = ""
        end
        self.retirer:SetShown(mj)

        local y = 30
        self.description:ClearAllPoints()
        self.description:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -y)
        self.description:SetText(description or "")
        if (description or "") ~= "" then
            self.description:Show()
            y = y + self.description:GetStringHeight() + 4
        else
            self.description:Hide()
        end
        self.effets:ClearAllPoints()
        self.effets:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -y)
        self.effets:SetText(effets)
        if effets ~= "" then
            self.effets:Show()
            y = y + self.effets:GetStringHeight() + 4
        else
            self.effets:Hide()
        end
        return y + 8
    end
    return c
end

function Lignes.traits(parent, field, c)
    local l = CreateFrame("Frame", nil, parent)
    l.cartes = {}
    l.largeur = c.largeurLigne

    l.entete = Ligne(l, c)
    l.entete:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
    l.entete:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, 0)
    l.label = Nom(l.entete, c, field.label)
    l.resume = UI.Texte(l.entete, "", UI.C.discret)
    UI.Police(l.resume, c.police * 0.85)
    l.resume:SetPoint("LEFT", l.entete, "LEFT", c.plage, 0)

    l.ajouter = UI.Bouton(l.entete, "+  Ajouter", c.actionLargeur, c.boutonH, function() l:ProposerAjout() end)
    l.ajouter:SetPoint("LEFT", l.entete, "LEFT", c.action, 0)
    UI.Police(l.ajouter.label, c.police * 0.85)
    l.choix = UI.Choix("fiche_traits", "Ajouter un trait")
    l:SetScript("OnHide", function() l.choix:Hide() end)

    l.vide = UI.Texte(l, "Aucun trait porté.", UI.C.discret, "GameFontNormalSmall")
    l.vide:SetPoint("TOPLEFT", l, "TOPLEFT", c.nomSansIcone, -(c.ligne + ECART_LIGNES + 4))

    -- Ne propose que ce qui n'est pas deja porte.
    function l:ProposerAjout()
        if not (self.entity and LCM.IsMaster()) then return end
        local options = {}
        for _, trait in ipairs(LCM.Traits.list) do
            if not LCM.Traits.Has(self.entity, trait.id) then
                options[#options + 1] = {
                    id = trait.id,
                    label = string.format("%s  (%d pt%s)%s", trait.label, trait.cout,
                        trait.cout > 1 and "s" or "", trait.brouillon and "  · brouillon" or ""),
                }
            end
        end
        if #options == 0 then
            LCM.Alerte("tous les traits connus sont deja portes.")
            return
        end
        table.sort(options, function(a, b) return a.label:lower() < b.label:lower() end)
        self.choix:Proposer(self.ajouter, options, function(id)
            if LCM.Traits.Grant(self.entity, id) then self:Changer() end
        end)
    end

    -- Retirer se rattrape (on redonne le trait) : pas de confirmation.
    function l:Retirer(id)
        if not (self.entity and LCM.IsMaster()) then return end
        if LCM.Traits.Revoke(self.entity, id) then self:Changer() end
    end

    -- La hauteur change avec le nombre de cartes : la page se re-dispose.
    function l:Changer()
        self:Actualiser(self.entity)
        if self.onChange then self.onChange(self.entity) end
    end

    function l:Actualiser(e)
        self.entity = e
        local mj = LCM.IsMaster()
        self.ajouter:SetShown(mj)

        local ids = LCM.Traits.Ids(e)
        local y = c.ligne + ECART_LIGNES
        for index, id in ipairs(ids) do
            local carte = self.cartes[index]
            if not carte then
                carte = Fiche.Carte(self, function(traitId) self:Retirer(traitId) end, self.largeur)
                self.cartes[index] = carte
            end
            carte:ClearAllPoints()
            carte:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            carte:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
            local trait = LCM.Traits.Get(id)
            local hauteur = carte:Habiller(id, trait, mj,
                trait and string.format("%d pt%s", trait.cout, trait.cout > 1 and "s" or ""))
            carte:SetHeight(hauteur)
            carte:Show()
            y = y + hauteur + ECART_LIGNES
        end
        for index = #ids + 1, #self.cartes do self.cartes[index]:Hide() end
        self.vide:SetShown(#ids == 0)
        if #ids == 0 then y = y + 24 end

        local cout = LCM.Traits.CoutTotal(e)
        self.resume:SetText(#ids == 0 and "" or string.format("%d trait%s  ·  %d pt%s",
            #ids, #ids > 1 and "s" or "", cout, cout > 1 and "s" or ""))
        self:SetHeight(y - ECART_LIGNES)
    end
    l:SetHeight(c.ligne)
    return l
end

-- ===== Blocs de section ====================================================
-- Un bloc par section (UI.SkinFicheBlocks) : cadre du modele, titre en
-- capitales suivi de son ornement, filet sous le titre, gemme au sommet.

local MARGE_BLOC = 10

local function Bloc(parent, section, largeur)
    local b = CreateFrame("Frame", nil, parent)
    local m = UI.AelMesures(largeur)
    local q = largeur / 822
    b.aTitre = section.label ~= ""
    b.hautTitre = b.aTitre and math.max(24, 50 * m.echelle) or 0
    if b.aTitre then
        if UI.AelCadre then
            b.cadre = UI.AelCadre(b, "section")
            b.gemme = UI.AelRef(b, 501, 656, 27, 25, "OVERLAY")
            b.gemme:SetSize(9, 9)
            b.gemme:SetPoint("TOP", b, "TOP", 0, 5)
        end
        b.titre = UI.Texte(b, UI.Majuscules(section.label), UI.C.titre)
        UI.Police(b.titre, m.titre * 0.8)
        b.titre:SetPoint("TOPLEFT", b, "TOPLEFT", math.max(14, 26 * m.echelle), -(b.hautTitre - 4) / 2 + 2)
        if UI.AelRef then
            b.ornement = UI.AelRef(b, 347, 344, 45, 17, "ARTWORK")
            b.ornement:SetSize(45 * m.echelle, 17 * m.echelle)
            b.ornement:SetPoint("LEFT", b.titre, "RIGHT", 12 * m.echelle, 0)
        end
        b.filet = UI.Aplat(b, { 0.48, 0.36, 0.19, 0.8 }, "ARTWORK")
        b.filet:SetHeight(1)
        b.filet:SetPoint("TOPLEFT", b, "TOPLEFT", 10 * q, -b.hautTitre)
        b.filet:SetPoint("TOPRIGHT", b, "TOPRIGHT", -10 * q, -b.hautTitre)
    end
    b.lignes = {}
    return b
end

-- ===== La page =============================================================

-- Une page : des sections du schema, en blocs. La fiche en fait un onglet ; les
-- fenetres du menu (UI/Vues.lua) en font une fenetre a part avec les MEMES
-- lignes — une seule facon de montrer un champ dans l'addon.
--
-- `largeur` : celle de la page. Les colonnes des lignes s'en deduisent.
function Fiche.Page(parent, sections, largeur)
    largeur = largeur or 520
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints(parent)
    page.lignes, page.blocs = {}, {}

    local largeurLigne = largeur - 2 * MARGE_BLOC
    local c = UI.AelColonnes(largeurLigne)
    c.largeurLigne = largeurLigne

    for _, section in ipairs(sections) do
        local bloc = Bloc(page, section, largeur)
        for _, field in ipairs(section.fields) do
            local fabrique = Lignes[field.kind]
            -- Un champ masque (le maximum brut des PV, deja dans la jauge) ou
            -- reserve au MJ (une surcharge) ne se dessine pas pour les autres.
            local visible = not field.masque and (not field.mjSeulement or LCM.IsMaster())
            if fabrique and visible then
                local ligne = fabrique(bloc, field, c)
                ligne.field = field
                -- Une ligne qui change de hauteur (corps, traits) le signale :
                -- la page se re-dispose.
                ligne.onChange = function() page:Disposer() end
                bloc.lignes[#bloc.lignes + 1] = ligne
                page.lignes[#page.lignes + 1] = ligne
            end
        end
        if #bloc.lignes > 0 then
            page.blocs[#page.blocs + 1] = bloc
        else
            bloc:Hide()
        end
    end

    -- Pose blocs et lignes de haut en bas : certaines lignes (corps, traits)
    -- changent de hauteur avec l'entite.
    function page:Disposer()
        local y = 0
        for _, bloc in ipairs(self.blocs) do
            local yb = bloc.hautTitre + (bloc.aTitre and 8 or 0)
            for _, ligne in ipairs(bloc.lignes) do
                ligne:ClearAllPoints()
                ligne:SetPoint("TOPLEFT", bloc, "TOPLEFT", MARGE_BLOC, -yb)
                ligne:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -MARGE_BLOC, -yb)
                yb = yb + ligne:GetHeight() + ECART_LIGNES
            end
            local hauteur = yb - ECART_LIGNES + MARGE_BLOC
            bloc:ClearAllPoints()
            bloc:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            bloc:SetSize(largeur, hauteur)
            y = y + hauteur + 14
        end
        self.hauteur = math.max(1, y - 14)
        if self.onHauteur then self.onHauteur(self.hauteur) end
    end

    function page:Actualiser(entity)
        for _, ligne in ipairs(self.lignes) do
            if ligne.Actualiser then ligne:Actualiser(entity) end
        end
        self:Disposer()
    end

    page:Disposer()
    page:Hide()
    return page
end

-- ===== La fenetre ==========================================================

local LARGEUR, HAUTEUR = 600, 720

function Fiche.Fenetre()
    if Fiche.frame then return Fiche.frame end

    local f = UI.Fenetre("fiche", "Fiche", LARGEUR, HAUTEUR, { x = -180, y = 0 })
    Fiche.frame = f
    local m = f.mesures

    f.nom = UI.Texte(f, "", UI.C.discret)
    UI.Police(f.nom, m.police * 0.8)
    f.nom:SetPoint("TOP", f.titre, "BOTTOM", 0, -2)
    f.nom:SetJustifyH("CENTER")

    local onglets = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        onglets[#onglets + 1] = { id = tab.id, label = tab.label }
    end

    local largeurContenu = LARGEUR - 24
    f.barre = UI.BandeauOnglets(f.contenu, onglets, function(id) f:Afficher(id) end)
    f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.barre:SetWidth(largeurContenu)
    local hauteurBandeau = f.barre:Disposer(largeurContenu, m.onglet)

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -(hauteurBandeau + 10))
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.pages = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        local page = Fiche.Page(f.zone.contenu, tab.sections, largeurContenu)
        page.onHauteur = function(h) if page:IsShown() then f.zone:Regler(h) end end
        f.pages[tab.id] = page
    end

    function f:Afficher(ongletId)
        self.onglet = ongletId
        self.barre:Selectionner(ongletId)
        for id, page in pairs(self.pages) do
            page:SetShown(id == ongletId)
        end
        local page = self.pages[ongletId]
        if page then
            if self.entity then page:Actualiser(self.entity) end
            self.zone.decalage = 0
            self.zone:Regler(page.hauteur)
        end
    end

    function f:Montrer(entity)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self.nom:SetText(tostring(self.entity.name or self.entity.id))
        self:Afficher(self.onglet or onglets[1] and onglets[1].id)
        self:Show()
    end

    function f:Actualiser()
        if self.entity and self.onglet and self.pages[self.onglet] then
            self.pages[self.onglet]:Actualiser(self.entity)
        end
    end

    return f
end

LCM.AddCommand("fiche", "ouvre la fiche", function(argument)
    local f = Fiche.Fenetre()
    if f:IsShown() then
        f:Hide()
        return
    end
    local entite = LCM.Entities.Self()
    local cible = tostring(argument or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cible ~= "" then
        entite = LCM.Entities.Get(cible) or entite
    end
    f:Montrer(entite)
end)
