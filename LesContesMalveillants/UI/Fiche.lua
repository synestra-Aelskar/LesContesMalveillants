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

-- Les lignes se touchent, et les blocs aussi : Necronicon n'aere pas, et c'est
-- ce qui lui permet de tenir la meme fiche dans moins de place. Le filet de
-- chaque ligne suffit a les separer.
-- Ce qu'on laisse entre la derniere valeur et le bord de la ligne.
local MARGE_VALEUR = 8
local ECART_LIGNES = 0
local ECART_BLOCS = 4

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
function Fiche.Surface(l)
    if UI.SurfaceLigne then
        UI.SurfaceLigne(l)
    else
        l.surface = UI.Aplat(l, UI.C.fondClair)
        l.surface:SetAllPoints(l)
    end
end

local Surface = Fiche.Surface

-- `sorte` : « Button » pour une ligne sur laquelle on clique. Le jeu ne donne
-- de script OnClick qu'aux boutons — une ligne-cadre a laquelle on en attache
-- un leve « doesn't have a "OnClick" script » et la fenetre ne s'ouvre plus.
function Fiche.Ligne(parent, c, sorte)
    local l = CreateFrame(sorte or "Frame", nil, parent)
    l:SetHeight(c.ligne)
    Surface(l)
    return l
end
local Ligne = Fiche.Ligne

-- Le nom, a sa place : apres l'icone s'il y en a une, sinon a la sienne.
--
-- Il recoit une LARGEUR, bornee par la colonne qui suit : sans elle un libelle
-- un peu long continue tout droit et s'ecrit sur la jauge (« Points d'action »
-- par-dessus sa barre). Coupe plutot que deborde — et si ca coupe souvent,
-- c'est le libelle qu'il faut raccourcir, comme le template le fait avec PA.
function Fiche.Nom(l, c, texte, avecIcone)
    l.nom = UI.Texte(l, texte, UI.C.texte)
    UI.Police(l.nom, c.police)
    local depart = avecIcone and c.nom or c.nomSansIcone
    l.nom:SetPoint("LEFT", l, "LEFT", depart, 0)
    l.nom:SetWidth(math.max(40, math.min(c.nomLargeur, c.barreDebut - depart - 6)))
    l.nom:SetJustifyH("LEFT")
    l.nom:SetWordWrap(false)
    l.label = l.nom
    return l.nom
end
local Nom = Fiche.Nom

-- Icone encadree et son separateur (UI.LayoutAelContainerRow).
-- `taille` force la taille de l'icone (les lignes de conteneur la doublent).
-- Elle est de toute facon bornee par la hauteur REELLE de la ligne : une icone
-- qui depasse de sa ligne mord sur la voisine.
function Fiche.Icone(l, c, texture, taille)
    local hauteur = l:GetHeight()
    if not hauteur or hauteur <= 0 then hauteur = c.ligne end
    local cote = math.min(taille or c.iconeTaille, hauteur - 4)
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(cote, cote)
    l.icone:SetPoint("LEFT", l, "LEFT", c.icone, 0)
    l.icone:SetTexture(texture)
    -- Rognee plus franchement : les icones du jeu portent un liseré gris sur
    -- leur bord, qui jurait avec l'habillage.
    l.icone:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    l.iconeCote = cote
    -- Ou finit l'icone, cadre compris : ce qui suit s'y accroche.
    l.apresIcone = c.icone + cote + 2
    if UI.AelCadre then
        -- Le tour dore mord d'un pixel SUR l'icone au lieu de l'entourer : pose
        -- autour, il laissait voir le liseré gris du jeu entre lui et l'image.
        local support = CreateFrame("Frame", nil, l)
        support:SetPoint("TOPLEFT", l.icone, "TOPLEFT", -1, 1)
        support:SetPoint("BOTTOMRIGHT", l.icone, "BOTTOMRIGHT", 1, -1)
        l.cadreIcone = UI.AelCadre(support, "icone")
        l.separateur = UI.AelRef(l, 202, 397, 15, 37, "ARTWORK")
        l.separateur:SetSize(12 * c.echelle, math.min(37 * c.echelle, hauteur - 4))
        -- Calee sur l'icone qu'on vient de poser, pas sur la colonne du
        -- gabarit : une icone doublee aurait pousse le separateur en plein
        -- milieu d'elle-meme.
        l.separateur:SetPoint("LEFT", l, "LEFT", taille and (l.apresIcone + 4) or c.separateur, 0)
        l.apresIcone = (taille and (l.apresIcone + 4) or c.separateur) + 12 * c.echelle + 6
    end
end
local Icone = Fiche.Icone

-- Une jauge du modele : barre avec embouts dores, chiffres contournes dessus,
-- trois boutons carres a droite. `rappels` : moins(), plus(), remise().
local function Jauge(l, c, couleur, rappels)
    local debut = c.barreDebut
    -- Une jauge SANS boutons (les points de vie, qui se perdent et se rendent
    -- zone par zone) laissait derriere elle la place des trois boutons, vide.
    -- Elle va donc jusqu'au bord gauche du « R » des jauges d'en dessous : les
    -- colonnes restent alignees, et la barre occupe ce qui ne servait a rien.
    local fin = rappels and c.barreFin or c.boutons[3]
    l.barre = UI.Barre(l, couleur, fin - debut, c.barreHauteur)
    l.barre:SetPoint("LEFT", l, "LEFT", debut, 0)
    UI.Police(l.barre.label, c.police, "OUTLINE")
    if UI.AelCadreJauge then l.cadreJauge = UI.AelCadreJauge(l.barre) end

    -- La barre commence apres le nom : une police plus grande ne la cache pas.
    function l:CaleBarre()
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
function Fiche.Bulle(l, titre, texte)
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
local Bulle = Fiche.Bulle

-- ===== Lignes, une par type de champ =======================================

local Lignes = {}

-- Valeur simple : le nom a gauche, la valeur alignee a droite sur la derniere
-- colonne (comme dans Deplacement chez Necronicon), bonus portes a la suite.
function Lignes.stat(parent, field, c)
    local l = Ligne(parent, c)
    local icone = LCM.IconeChamp(field)
    if icone then Icone(l, c, icone) end
    -- Le quatrieme argument n'est pas decoratif : sans lui le nom se pose a la
    -- colonne « sans icone » et vient s'ecrire par-dessus l'icone.
    Nom(l, c, field.label, icone ~= nil)
    l.valeur = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.valeur, c.police)
    -- Calee sur la COLONNE DE VALEUR, pas sur le bord droit de la ligne. Au
    -- bord, le nom finissait vers 110 et le chiffre vers 300 : deux cents
    -- pixels de rien entre les deux, et dans un volet etroit le chiffre
    -- sortait carrement du cadre visible. Toujours alignee a droite, donc les
    -- chiffres restent les uns sous les autres ; simplement plus pres du nom.
    l.valeur:SetPoint("RIGHT", l, "LEFT", c.valeur + c.valeurLargeur, 0)
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
    -- L'armure portee se remplit de ce qu'elle a encaisse : un bronze terni.
    armure_portee = { 0.62, 0.48, 0.34 },
    pa = { 0.83, 0.68, 0.33 },
}

function Lignes.gauge(parent, field, c)
    local l = Ligne(parent, c)
    local icone = LCM.IconeChamp(field)
    if icone then Icone(l, c, icone) end
    Nom(l, c, field.label, icone ~= nil)
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
    local icone = LCM.IconeChamp(field)
    if icone then Icone(l, c, icone) end
    Nom(l, c, field.label, icone ~= nil)

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
        if resultat then LCM.Canal.Dire(LCM.Roll.Describe(resultat)) end
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
--
-- Options (Data/Vues.lua) : `zones = false` ne garde que la jauge des PV (la
-- Fiche du template), `total = false` que les zones (Sante › Physique).
function Lignes.body(parent, field, c, options)
    options = options or {}
    local avecZones, avecTotal = options.zones ~= false, options.total ~= false
    local l = CreateFrame("Frame", nil, parent)
    l.zones = {}

    l.total = Ligne(l, c)
    l.total:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
    l.total:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, 0)
    -- Le coeur du template : c'est sa ligne « Point de vie ».
    local iconeTotal = LCM.IconeChamp(field)
    if iconeTotal then Icone(l.total, c, iconeTotal) end
    -- « Point de vie » au singulier : c'est le libelle du template.
    Nom(l.total, c, "Point de vie", iconeTotal ~= nil)
    Jauge(l.total, c, UI.C.vie, nil)
    Bulle(l.total, "Point de vie",
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

    l.total:SetShown(avecTotal)

    function l:Actualiser(e)
        self.entity = e
        local courant, maximum = LCM.Body.Totals(e)
        self.total.barre:Regler(courant, maximum)
        self.total:CaleBarre()

        local etat = avecZones and LCM.Body.State(e) or {}
        local y = avecTotal and (c.ligne + ECART_LIGNES) or 0
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
function Fiche.Effets(element)
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
-- Les memes effets, mais RANGES : par section de la fiche, dans l'ordre de la
-- fiche, et chacun avec sa valeur a part. La version a plat (`Fiche.Effets`)
-- jetait tout sur une ligne par ordre alphabetique — « Ombre +2 · Perce-armure
-- +1 · Perforant +4 » melange une penetration, une mecanique et une autre
-- penetration, et on ne sait plus ce qu'on lit.
--
-- Rend une liste ordonnee de { titre, lignes = { { label, valeur } } }.
function Fiche.EffetsGroupes(element)
    -- L'ordre de la fiche, releve une fois : onglet, puis section, puis champ.
    if not Fiche.rangChamp then
        Fiche.rangChamp, Fiche.groupeChamp = {}, {}
        local n = 0
        for _, tab in ipairs(LCM.Schema.Tabs()) do
            for _, section in ipairs(tab.sections or {}) do
                -- Une section dont le nom se suffit n'a pas besoin de celui de
                -- son onglet ; « Élémentaires » si, sinon penetrations et
                -- resistances se ressemblent trait pour trait.
                local titre = section.label or ""
                local onglet = tab.label or tab.id
                if titre == "" then titre = onglet
                elseif onglet and onglet ~= titre then titre = onglet .. " — " .. titre end
                for _, field in ipairs(section.fields or {}) do
                    n = n + 1
                    Fiche.rangChamp[field.id] = n
                    Fiche.groupeChamp[field.id] = titre
                end
            end
        end
    end

    local plats = {}
    for champ, montant in pairs(element.bonus) do
        local field = LCM.Schema.Field(champ)
        plats[#plats + 1] = {
            id = champ,
            label = (field and field.label) or champ,
            valeur = Montant(montant),
            groupe = Fiche.groupeChamp[champ] or "Autres",
            rang = Fiche.rangChamp[champ] or 9999,
        }
    end
    table.sort(plats, function(a, b) return a.rang < b.rang end)

    local groupes, parNom = {}, {}
    for _, e in ipairs(plats) do
        local g = parNom[e.groupe]
        if not g then
            g = { titre = e.groupe, lignes = {} }
            parNom[e.groupe] = g
            groupes[#groupes + 1] = g
        end
        g.lignes[#g.lignes + 1] = { label = e.label, valeur = e.valeur }
    end

    -- Les avantages ne sont pas chiffres : ils font leur propre paquet, en bout.
    local avantages = {}
    for champ in pairs(element.avantage) do
        local field = LCM.Schema.Field(champ)
        avantages[#avantages + 1] = (field and field.label) or champ
    end
    table.sort(avantages)
    if #avantages > 0 then
        local g = { titre = "Avantage", lignes = {} }
        for _, nom in ipairs(avantages) do g.lignes[#g.lignes + 1] = { label = nom, valeur = "" } end
        groupes[#groupes + 1] = g
    end
    return groupes
end

local Effets = Fiche.Effets

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
        -- On ne retire pas SES PROPRES traits : ils se choisissent a la
        -- creation et font le personnage. La croix restait offerte au MJ sur
        -- toutes les fiches, la sienne comprise, et un clic de travers effacait
        -- un trait paye. Sur la fiche d'un AUTRE, le MJ garde la main.
        local sien = e ~= nil and e == LCM.Entities.Self()
        local peutRetirer = mj and not sien

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
            -- Exception : un trait qui n'existe plus (brouillon supprime) reste
            -- retirable, meme sur sa propre fiche. Sinon il y resterait colle,
            -- sans rien donner, sans moyen de s'en defaire.
            local hauteur = carte:Habiller(id, trait, peutRetirer or (mj and trait == nil),
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

-- ----- Recapitulatif -------------------------------------------------------
-- Une ligne compacte par statistique (fenetre Statistiques du template) : le
-- nom et la valeur TOTALE, toutes sources confondues — ou, pour le dossier
-- « Bonus », ce que portent traits et objets.

function Fiche.Total(e, field, mode)
    if mode == "bonus" then return LCM.Effets.Bonus(e, field.id) end
    if LCM.Effets.PRIMAIRES[field.id] then return LCM.Formules.Primaire(e, field.id) end
    if field.kind == "roll" then return LCM.Formules.Expertise(e, field.id) end
    local valeur = tonumber(LCM.Entities.Get_Value(e, field.id)) or 0
    if field.kind == "stat" then valeur = valeur + LCM.Effets.Bonus(e, field.id) end
    return valeur
end

function Lignes.recap(parent, field, c, mode)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(math.max(20, 34 * c.echelle))
    Surface(l)
    Nom(l, c, field.label)
    UI.Police(l.nom, c.police * 0.85)
    l.valeur = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.valeur, c.police * 0.85)
    -- Calee sur la COLONNE DE VALEUR, pas sur le bord droit de la ligne. Au
    -- bord, le nom finissait vers 110 et le chiffre vers 300 : deux cents
    -- pixels de rien entre les deux, et dans un volet etroit le chiffre
    -- sortait carrement du cadre visible. Toujours alignee a droite, donc les
    -- chiffres restent les uns sous les autres ; simplement plus pres du nom.
    l.valeur:SetPoint("RIGHT", l, "LEFT", c.valeur + c.valeurLargeur, 0)
    l.valeur:SetJustifyH("RIGHT")
    function l:Actualiser(e)
        local total = Fiche.Total(e, field, mode)
        self.valeur:SetText((mode == "bonus" and total > 0 and "+" or "") .. Nombre(total))
        -- Une valeur nulle s'efface : on lit d'un coup d'oeil ce qui compte.
        local couleur = total ~= 0 and UI.C.titre or UI.C.discret
        self.valeur:SetTextColor(couleur[1], couleur[2], couleur[3])
    end
    return l
end

-- ----- Conteneurs -----------------------------------------------------------
-- Les conteneurs du template (Equipements, Sante › Etats, Apprentissage) : une
-- ligne par emplacement, sur le modele des emplacements Necronicon
-- (UI.LayoutAelContainerRow) — icone encadree, separateur, nom, effets. Une
-- case vide dit « Emplacement ». Placer et retirer sont des gestes de MJ.

local VIDE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

-- La liste de choix partagee par tous les conteneurs (un seul menu ouvert a
-- la fois, de toute facon).
local function Choix()
    Fiche.choixConteneur = Fiche.choixConteneur or UI.Choix("conteneur", "")
    return Fiche.choixConteneur
end

-- La carte au survol : ce que le clic droit ouvre en grand, en lecture seule
-- et sans habillage. L'infobulle du jeu ne donnait que deux lignes de texte ;
-- ici on veut voir l'objet — son icone, son nom, ce qu'il est, ses chiffres.
--
-- Bordure SIMPLIFIEE a dessein : un survol apparait et disparait sans arret,
-- et l'habillage complet d'une carte de compendium y clignoterait.
local function CarteSurvol()
    if Fiche.carteSurvol then return Fiche.carteSurvol end
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetFrameStrata("TOOLTIP")
    p:SetSize(360, 120)
    p:EnableMouse(false)
    p:Hide()
    p.fond = UI.Aplat(p, { 0.04, 0.04, 0.05, 0.96 })
    p.fond:SetAllPoints(p)
    UI.BordureFine(p, 0.45)

    p.icone = p:CreateTexture(nil, "ARTWORK")
    p.icone:SetSize(40, 40)
    p.icone:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -10)
    p.icone:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    p.nom = UI.Texte(p, "", UI.C.titre)
    p.nom:SetPoint("TOPLEFT", p.icone, "TOPRIGHT", 10, -2)
    p.nom:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -10)
    p.nom:SetJustifyH("LEFT")
    p.nom:SetWordWrap(true)
    p.description = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
    p.description:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -56)
    p.description:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -56)
    p.description:SetJustifyH("LEFT")
    p.description:SetWordWrap(true)
    -- Les effets, ranges : un intertitre par section, puis ses lignes sur
    -- trois colonnes, libelle a gauche et valeur calee a droite de sa colonne.
    p.titres, p.cases = {}, {}
    p.COLONNES, p.LIGNE_H, p.TITRE_H = 3, 15, 17

    function p:Montrer(element, groupes, ancreSur)
        self.icone:SetTexture(element.icone)
        self.nom:SetText(element.label or "")
        local description = element.description or ""
        self.description:SetText(description)
        self.description:SetShown(description ~= "")
        local y = 56
        if description ~= "" then
            y = y + (self.description:GetStringHeight() or 14) + 8
        end
        local nT, nC = 0, 0
        local largeurCase = (self:GetWidth() - 20 - (self.COLONNES - 1) * 8) / self.COLONNES
        for _, groupe in ipairs(groupes or {}) do
            nT = nT + 1
            local t = self.titres[nT]
            if not t then
                t = UI.Texte(self, "", UI.C.titre, "GameFontNormalSmall")
                t:SetJustifyH("LEFT")
                self.titres[nT] = t
            end
            t:SetText(groupe.titre)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -y)
            t:Show()
            y = y + self.TITRE_H

            for index, ligne in ipairs(groupe.lignes) do
                nC = nC + 1
                local c = self.cases[nC]
                if not c then
                    c = CreateFrame("Frame", nil, self)
                    c.label = UI.Texte(c, "", UI.C.texte, "GameFontNormalSmall")
                    c.label:SetPoint("LEFT", c, "LEFT", 0, 0)
                    c.label:SetJustifyH("LEFT")
                    c.label:SetWordWrap(false)
                    c.valeur = UI.Texte(c, "", UI.C.accent, "GameFontNormalSmall")
                    c.valeur:SetPoint("RIGHT", c, "RIGHT", 0, 0)
                    c.valeur:SetJustifyH("RIGHT")
                    self.cases[nC] = c
                end
                local col = (index - 1) % self.COLONNES
                local rang = math.floor((index - 1) / self.COLONNES)
                c:SetSize(largeurCase, self.LIGNE_H)
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", self, "TOPLEFT",
                    14 + col * (largeurCase + 8), -(y + rang * self.LIGNE_H))
                c.label:SetWidth(largeurCase - 26)
                c.label:SetText(ligne.label)
                c.valeur:SetText(ligne.valeur)
                c:Show()
            end
            y = y + math.ceil(#groupe.lignes / self.COLONNES) * self.LIGNE_H + 4
        end
        for i = nT + 1, #self.titres do self.titres[i]:Hide() end
        for i = nC + 1, #self.cases do self.cases[i]:Hide() end
        self:SetHeight(math.max(62, y + 8))
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", ancreSur, "TOPRIGHT", 12, 0)
        self:Show()
    end

    Fiche.carteSurvol = p
    return p
end

-- Montre la fiche de l'element porte, comme le clic droit du compendium et de
-- l'inventaire.
local function VoirElement(conteneur, id, ancre)
    if not id or not UI.Compendium then return end
    local element, categorie = LCM.Compendium.Resoudre(
        tostring(conteneur.categorie) .. "/" .. tostring(id))
    -- Sinon on cherche l'entree dans les familles. Le repli evident — prendre
    -- la categorie du CATALOGUE — est faux : ce n'est pas une categorie de
    -- compendium, elle n'a pas de champs, et la carte plantait dessus.
    if not (element and categorie) then
        for _, cat in ipairs(LCM.Compendium.categories) do
            for _, e in ipairs(LCM.Compendium.Entrees(cat)) do
                if tostring(e.id) == tostring(id) then element, categorie = e, cat break end
            end
            if element then break end
        end
    end
    if element and categorie then UI.Compendium.Voir(categorie, element, ancre) end
end

local function Emplacement(conteneur, c)
    -- Un BOUTON, pas un cadre : seuls les boutons recoivent OnClick, et sans
    -- ca le clic droit ne part jamais (c'est la panne du 1er octobre).
    local l = Ligne(conteneur, c, "Button")
    -- Deux lignes de texte : le nom en entier, la description dessous.
    l:SetHeight(math.max(52, c.ligne * 2))

    -- L'icone double : une vignette de 16 ne montrait rien d'un objet. Bornee
    -- par la hauteur de la ligne, elle ne peut pas deborder.
    Icone(l, c, VIDE, c.iconeTaille * 2)
    local depart = l.apresIcone or c.nom
    local finTexte = c.action - 8 * c.echelle

    -- Le nom en ENTIER : il etait coupe des « Capuche de... ». Il a toute la
    -- largeur jusqu'au bouton, et sa propre ligne.
    l.nom = UI.Texte(l, "", UI.C.texte)
    UI.Police(l.nom, c.police)
    l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", depart, -8)
    l.nom:SetPoint("TOPRIGHT", l, "TOPLEFT", finTexte, -8)
    l.nom:SetJustifyH("LEFT")
    l.nom:SetWordWrap(false)
    l.label = l.nom

    -- La description dessous, et les effets au bout de la meme ligne : le nom
    -- garde ainsi sa ligne pour lui seul.
    l.description = UI.Texte(l, "", UI.C.discret)
    UI.Police(l.description, c.police * 0.78)
    l.description:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -3)
    l.description:SetJustifyH("LEFT")
    l.description:SetWordWrap(false)

    -- La description prend toute la ligne. Les chiffres (« Perce-armure +1 ·
    -- Perforant +4 ») etaient affiches ici : ils disent ce que l'objet FAIT,
    -- pas ce qu'il EST, et la carte au survol les donne deja. Sous le nom, on
    -- veut savoir de quoi il s'agit.
    l.description:SetPoint("TOPRIGHT", l, "TOPLEFT", finTexte, -(8 + c.police + 5))
    -- Garde pour le code qui l'alimente encore : jamais dessine.
    l.effets = UI.Texte(l, "", UI.C.accent)
    l.effets:Hide()

    l.action = UI.Bouton(l, "", c.actionLargeur, c.boutonH, function()
        if l.elementId then conteneur:Retirer(l.elementId) else conteneur:Proposer(l.action) end
    end)
    l.action:SetPoint("LEFT", l, "LEFT", c.action, 0)
    UI.Police(l.action.label, c.police * 0.8)

    -- Clic droit : la fiche de l'objet porte. Il manquait — on voyait l'objet
    -- sur soi sans pouvoir le lire.
    l:RegisterForClicks("RightButtonUp")
    l:SetScript("OnClick", function(self, bouton)
        if bouton == "RightButton" then VoirElement(conteneur, self.elementId, self) end
    end)

    -- Survol : la carte de l'objet quand il y en a un, l'infobulle sinon (une
    -- case vide n'a pas de carte a montrer).
    l:EnableMouse(true)
    l:SetScript("OnEnter", function(self)
        if self.survol then
            CarteSurvol():Montrer(self.survol.element, self.survol.groupes, self)
        elseif self.bulle and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.bulle.titre)
            GameTooltip:AddLine(self.bulle.texte, 0.88, 0.84, 0.76, true)
            GameTooltip:Show()
        end
    end)
    l:SetScript("OnLeave", function()
        if Fiche.carteSurvol then Fiche.carteSurvol:Hide() end
        if GameTooltip then GameTooltip:Hide() end
    end)

    function l:Habiller(catalogue, id, mj)
        self.elementId = id
        local element = id and catalogue.Get(id)
        if not id then
            self.icone:SetTexture(VIDE)
            self.nom:SetText("Emplacement")
            self.nom:SetTextColor(UI.C.discret[1], UI.C.discret[2], UI.C.discret[3])
            self.description:SetText("")
            self.effets:SetText("")
            self.survol = nil
            self.bulle = { titre = "Emplacement", texte = "Emplacement disponible." }
            self.action.label:SetText("+  Ajouter")
        elseif element then
            self.icone:SetTexture(element.icone)
            self.nom:SetText(element.label .. (element.brouillon and "  |cff99907f·|r" or ""))
            self.nom:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
            local effets = Effets(element)
            -- Une piece d'armure dit ce qui la protege encore : son usure la
            -- suit (Core/Objets.lua), elle doit se voir la ou on la porte.
            if element.armure then
                local usure = math.min(element.armure, LCM.Objets.Usure(conteneur.entity, element.id))
                local armure = usure > 0 and string.format("Armure %d / %d", element.armure - usure, element.armure)
                    or string.format("Armure %d", element.armure)
                effets = effets ~= "" and (armure .. "  ·  " .. effets) or armure
            end
            self.effets:SetText(effets)
            -- La description sous le nom : elle n'existait que dans l'infobulle,
            -- qu'il fallait aller chercher a la souris.
            self.description:SetText(element.description or "")
            -- La carte au survol remplace l'infobulle : elle montre l'objet.
            self.survol = { element = element, groupes = Fiche.EffetsGroupes(element) }
            self.bulle = nil
            self.action.label:SetText("Retirer")
        else
            -- Disparu : il occupe toujours sa case, et redevient actif s'il
            -- revient.
            self.icone:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            self.nom:SetText("? " .. tostring(id))
            self.nom:SetTextColor(UI.C.plein[1], UI.C.plein[2], UI.C.plein[3])
            self.description:SetText("")
            self.effets:SetText("")
            self.survol = nil
            self.bulle = { titre = tostring(id),
                           texte = "N'existe pas dans cette version de l'addon : ne donne rien." }
            self.action.label:SetText("Retirer")
        end
        self.action:SetShown(mj)
    end
    return l
end

-- Les etats temporaires (Core/EtatsTemporaires.lua) : une ligne par etat —
-- icone, nom, effets, duree. Le MJ peut retirer ; un etat qui se guerit par
-- un jet propose « Guérir ». Aucun : une ligne le dit.
function Lignes.temporaires(bloc, c, conteneur)
    local l = CreateFrame("Frame", nil, bloc)
    l.lignes = {}
    l.vide = UI.Texte(l, "Aucun état temporaire.", UI.C.discret)
    UI.Police(l.vide, c.police * 0.85)
    l.vide:SetPoint("TOPLEFT", l, "TOPLEFT", 8, -6)
    function l:Actualiser(e)
        self.entity = e
        local T = LCM.EtatsTemporaires
        local liste = T.Liste(e, self.conteneur)
        local y = 0
        for i, etat in ipairs(liste) do
            local r = self.lignes[i]
            if not r then
                r = Ligne(self, c)
                r:SetHeight(math.max(40, c.ligne))
                Icone(r, c, VIDE)
                Nom(r, c, "", true)
                r.effets = UI.Texte(r, "", UI.C.accent)
                UI.Police(r.effets, c.police * 0.72)
                r.effets:SetPoint("LEFT", r, "LEFT", c.plage, 0)
                r.effets:SetPoint("RIGHT", r, "LEFT", c.action - 8 * c.echelle, 0)
                r.effets:SetJustifyH("RIGHT")
                r.effets:SetWordWrap(false)
                r.action = UI.Bouton(r, "", c.actionLargeur, c.boutonH, function(self_)
                    local et = self_:GetParent().etat
                    local ent = l.entity
                    if not (et and ent) then return end
                    if et.guerison and et.guerison.mode == "rand" and not LCM.IsMaster() then
                        local _, ligne = T.Guerir(ent, et.nom)
                        if ligne then LCM.Actions.Annoncer(ligne) end
                    else
                        T.Retirer(ent, et.nom)
                    end
                end)
                r.action:SetPoint("LEFT", r, "LEFT", c.action, 0)
                UI.Police(r.action.label, c.police * 0.8)
                self.lignes[i] = r
            end
            r.etat = etat
            r.icone:SetTexture(LCM.Icone(etat.icone))
            r.nom:SetText(etat.nom)
            local couleur = etat.debuff and UI.C.plein or UI.C.titre
            r.nom:SetTextColor(couleur[1], couleur[2], couleur[3])
            local effets = {}
            for champ, n in pairs(etat.bonus or {}) do
                local field = LCM.Schema.Field(champ)
                effets[#effets + 1] = string.format("%s %+d", field and field.label or champ, n)
            end
            table.sort(effets)
            r.effets:SetText(table.concat(effets, ", ") .. "  |cff9a9a9a" .. T.Duree(etat) .. "|r")
            Bulle(r, etat.nom, ((etat.description or "") ~= "" and (etat.description .. "\n\n") or "")
                .. (etat.lanceur and ("De " .. etat.lanceur .. ". ") or "") .. "Durée : " .. T.Duree(etat))
            local guerir = etat.guerison and etat.guerison.mode == "rand" and not LCM.IsMaster()
            r.action.label:SetText(guerir and string.format("Guérir (%s)", etat.guerison.competence) or "Retirer")
            r.action:SetShown(LCM.IsMaster() or guerir)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
            r:Show()
            y = y + r:GetHeight() + 2
        end
        for i = #liste + 1, #self.lignes do self.lignes[i]:Hide() end
        self.vide:SetShown(#liste == 0)
        local h = math.max(#liste == 0 and 24 or 0, y)
        if h ~= self.hauteur then
            self.hauteur = h
            self:SetHeight(h)
            if self.onChange then self.onChange() end
        end
    end
    return l
end

-- Un conteneur : autant de lignes que d'emplacements. `bloc` recoit le compte
-- « occupes / total ».
function Lignes.conteneur(bloc, def, c)
    local l = CreateFrame("Frame", nil, bloc)
    l.catalogue, l.categorie = def.catalogue, def.categorie
    l.emplacements = {}
    local m = UI.AelMesures(c.largeurLigne)
    bloc.occupation = UI.Texte(bloc, "", UI.C.titre)
    UI.Police(bloc.occupation, m.titre * 0.6)
    -- Aligne sur le HAUT du titre, comme lui : ancre au centre, il flottait
    -- d'une demi-ligne trop haut.
    bloc.occupation:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -26 * m.echelle, -(bloc.hautTitre - 4) / 2 + 2)

    function l:Proposer(ancre)
        if not (self.entity and LCM.IsMaster()) then return end
        local categorie = self.catalogue.Categorie(self.categorie)
        local options = {}
        for _, element in ipairs(self.catalogue.Candidats(self.entity, self.categorie)) do
            options[#options + 1] = { id = element.id, label = element.label .. (element.brouillon and "  · brouillon" or "") }
        end
        if #options == 0 then
            LCM.Alerte(string.format("rien a ajouter en %s.", categorie.label:lower()))
            return
        end
        table.sort(options, function(a, b) return a.label:lower() < b.label:lower() end)
        local choix = Choix()
        choix.titre:SetText(categorie.label)
        choix:Proposer(ancre, options, function(id)
            local ok, raison = self.catalogue.Placer(self.entity, id)
            if not ok then LCM.Alerte(raison) end
            self:Actualiser(self.entity)
        end)
    end

    -- Retirer se rattrape (on replace) : pas de confirmation.
    function l:Retirer(id)
        if not (self.entity and LCM.IsMaster()) then return end
        if self.catalogue.Enlever(self.entity, id) then self:Actualiser(self.entity) end
    end

    function l:Actualiser(e)
        self.entity = e
        local mj = LCM.IsMaster()
        local portes = self.catalogue.Ids(e, self.categorie)
        local places = self.catalogue.Capacite(self.categorie)
        -- Au-dessus du total (capacite reduite apres coup), le compte passe au
        -- rouge : rien n'est retire en douce.
        bloc.occupation:SetText(string.format("%d / %d", #portes, places))
        local couleur = (#portes > places) and UI.C.plein or UI.C.titre
        bloc.occupation:SetTextColor(couleur[1], couleur[2], couleur[3])
        -- Les cases occupees, puis UNE case libre tant qu'il reste de la
        -- place : trente cases vides ne disent rien de plus qu'une seule.
        -- Sauf categorie qui demande toutes ses places (l'armure).
        local categorie = self.catalogue.Categorie(self.categorie)
        local n = math.max(#portes, math.min(places, #portes + 1))
        if categorie and categorie.toutesLesCases then n = math.max(#portes, places) end
        local y = 0
        for index = 1, n do
            local ligne = self.emplacements[index]
            if not ligne then
                ligne = Emplacement(self, c)
                self.emplacements[index] = ligne
            end
            ligne:Habiller(self.catalogue, portes[index], mj)
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            ligne:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
            ligne:Show()
            y = y + ligne:GetHeight() + ECART_LIGNES
        end
        for index = n + 1, #self.emplacements do self.emplacements[index]:Hide() end
        self:SetHeight(math.max(1, y - ECART_LIGNES))
        if self.onChange then self.onChange(e) end
    end
    l:SetScript("OnHide", function() if Fiche.choixConteneur then Fiche.choixConteneur:Hide() end end)
    return l
end

-- ===== Blocs de section ====================================================
-- Un bloc par section (UI.SkinFicheBlocks) : cadre du modele, titre en
-- capitales suivi de son ornement, filet sous le titre, gemme au sommet.

local MARGE_BLOC = 10
Fiche.MARGE_BLOC = MARGE_BLOC
Fiche.ECART_LIGNES = ECART_LIGNES

function Fiche.Bloc(parent, section, largeur)
    local b = CreateFrame("Frame", nil, parent)
    local m = UI.AelMesures(largeur)
    local q = largeur / 822
    -- Le bloc garde ce qui l'a produit : un sommaire a besoin de son titre et
    -- de savoir ou il se trouve dans la page.
    b.section = section
    b.aTitre = section.label ~= ""
    b.hautTitre = b.aTitre and math.max(24, 50 * m.echelle) or 0
    if b.aTitre then
        if UI.AelCadre then
            b.cadre = UI.AelCadre(b, "section")
            b.gemme = UI.AelRef(b, 501, 656, 27, 25, "OVERLAY")
            b.gemme:SetSize(9, 9)
            b.gemme:SetPoint("TOP", b, "TOP", 0, 5)
        end
        b.titre = UI.Texte(b, UI.Majuscules(section.label), UI.C.titreBloc)
        -- + 2 : a cette densite le titre de bloc se confondait avec ses lignes,
        -- alors que c'est lui qui dit de quoi parle le paquet (3 octobre 2026).
        UI.Police(b.titre, m.titre * 0.8 + 2)
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
        -- Un bloc repliable (le recapitulatif) : un clic sur son titre, un
        -- signe a droite pour dire dans quel etat il est.
        if section.repliable then
            b.replie = section.replie == true
            b.bascule = CreateFrame("Button", nil, b)
            b.bascule:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            b.bascule:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
            b.bascule:SetHeight(b.hautTitre)
            b.signe = UI.Texte(b.bascule, "", UI.C.titre)
            UI.Police(b.signe, m.titre * 0.8)
            b.signe:SetPoint("RIGHT", b.bascule, "RIGHT", -26 * m.echelle, 0)
            b.survolTitre = UI.Aplat(b.bascule, UI.C.survol, "HIGHLIGHT")
            b.survolTitre:SetAllPoints(b.bascule)
        end
    end
    -- Un paragraphe : la description d'une fenetre du template.
    if section.texte and section.texte ~= "" then
        b.paragraphe = UI.Texte(b, section.texte, UI.C.texte)
        UI.Police(b.paragraphe, section.taille or math.max(11, m.police * 0.75))
        b.paragraphe:SetWidth(largeur - 40)
        -- Le bloc sait se re-largir : son paragraphe se recoupe tout seul.
        function b:Largeur(l)
            self.paragraphe:SetWidth(math.max(80, l - 40))
        end
        b.paragraphe:SetWordWrap(true)
        b.paragraphe:SetPoint("TOPLEFT", b, "TOPLEFT", 20, -(b.hautTitre + 12))
    end
    b.lignes = {}
    return b
end
local Bloc = Fiche.Bloc

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
        if bloc.bascule then
            bloc.bascule:SetScript("OnClick", function()
                bloc.replie = not bloc.replie
                page:Disposer()
            end)
        end
        if section.temporaires then
            local ligne = Lignes.temporaires(bloc, c,
                type(section.temporaires) == "string" and section.temporaires or nil)
            ligne.conteneur = type(section.temporaires) == "string" and section.temporaires or nil
            ligne.onChange = function() if not page.enDisposition then page:Disposer() end end
            bloc.lignes[#bloc.lignes + 1] = ligne
            page.lignes[#page.lignes + 1] = ligne
        end
        if section.conteneur then
            local ligne = Lignes.conteneur(bloc, section.conteneur, c)
            ligne.onChange = function() if not page.enDisposition then page:Disposer() end end
            bloc.conteneur = ligne
            bloc.lignes[#bloc.lignes + 1] = ligne
            page.lignes[#page.lignes + 1] = ligne
        end
        for _, field in ipairs(section.fields) do
            local fabrique = Lignes[field.kind]
            if section.recap then
                local mode = section.recap
                fabrique = function(p, f, col) return Lignes.recap(p, f, col, mode) end
            end
            -- Un champ masque (le maximum brut des PV, deja dans la jauge) ou
            -- reserve au MJ (une surcharge) ne se dessine pas pour les autres.
            local visible = not field.masque and (not field.mjSeulement or LCM.IsMaster())
            if fabrique and visible then
                local ligne = fabrique(bloc, field, c, section.options and section.options[field.id])
                ligne.field = field
                -- Une ligne qui change de hauteur (corps, traits) le signale :
                -- la page se re-dispose.
                ligne.onChange = function() page:Disposer() end
                bloc.lignes[#bloc.lignes + 1] = ligne
                page.lignes[#page.lignes + 1] = ligne
            end
        end
        if #bloc.lignes > 0 or section.texte then
            page.blocs[#page.blocs + 1] = bloc
        else
            bloc:Hide()
        end
    end

    -- Pose blocs et lignes de haut en bas : certaines lignes (corps, traits)
    -- changent de hauteur avec l'entite.
    -- Changer la largeur d'une page : pour une fenetre qu'on tire. Les blocs
    -- s'etirent et les paragraphes se re-coupent tout seuls.
    --
    -- ATTENTION : les colonnes des LIGNES de fiche (`c`) gardent les mesures du
    -- depart. C'est sans effet sur une page de texte (les Regles), qui n'a pas
    -- de ligne ; une page de fiche ne doit pas etre redimensionnee tant que `c`
    -- ne se recalcule pas.
    function page:Largeur(nouvelle)
        nouvelle = math.max(120, tonumber(nouvelle) or largeur)
        if nouvelle == largeur then return end
        largeur = nouvelle
        for _, bloc in ipairs(self.blocs) do
            if bloc.Largeur then bloc:Largeur(largeur) end
        end
        self:Disposer()
    end

    function page:Disposer()
        local y = 0
        for _, bloc in ipairs(self.blocs) do
            local yb = bloc.hautTitre + (bloc.aTitre and 8 or 0)
            if bloc.paragraphe then
                yb = yb + (bloc.paragraphe:GetStringHeight() or 14) + 12
            end
            if bloc.signe then bloc.signe:SetText(bloc.replie and "+" or "-") end
            for _, ligne in ipairs(bloc.lignes) do
                -- Replie : on ne garde que le titre.
                ligne:SetShown(not bloc.replie)
                if not bloc.replie then
                    ligne:ClearAllPoints()
                    ligne:SetPoint("TOPLEFT", bloc, "TOPLEFT", MARGE_BLOC, -yb)
                    ligne:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -MARGE_BLOC, -yb)
                    yb = yb + ligne:GetHeight() + ECART_LIGNES
                end
            end
            local hauteur = bloc.replie and (bloc.hautTitre + 4) or (yb - ECART_LIGNES + MARGE_BLOC)
            bloc:ClearAllPoints()
            bloc:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            bloc:SetSize(largeur, hauteur)
            y = y + hauteur + ECART_BLOCS
        end
        self.hauteur = math.max(1, y - ECART_BLOCS)
        if self.onHauteur then self.onHauteur(self.hauteur) end
    end

    function page:Actualiser(entity)
        -- Les lignes se re-disposent elles-memes quand elles changent de
        -- hauteur ; pendant une actualisation complete, une seule fois a la fin.
        self.enDisposition = true
        for _, ligne in ipairs(self.lignes) do
            if ligne.Actualiser then ligne:Actualiser(entity) end
        end
        self.enDisposition = false
        self:Disposer()
    end

    page:Disposer()
    page:Hide()
    return page
end

-- ===== La fenetre ==========================================================
-- La Fiche est une vue comme les autres (Data/Vues.lua, id « fiche ») : ses
-- onglets sont ceux du template (Statistiques, Facultes, Traits).

function Fiche.Fenetre()
    local f = UI.Vues.Fenetre("fiche")
    Fiche.frame = f
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
