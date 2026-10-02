-- La fenetre du constructeur de buff et de debuff.
--
-- Plan de Necronicon (RunBuffComposer : « fenetre UNIQUE : apercu en haut,
-- constructeur a gauche, familles repliables, choix a droite, carres de cout ») ;
-- 860 de large comme la sienne, moins haute : nos familles sont plus courtes
-- que son modele d'etats. La logique est dans Core/Actions.lua (Constructeur) :
-- la fenetre montre, et transmet les clics.
--
-- Ecarts voulus : pas de choix d'un modele d'etat du compendium (notre fiche
-- n'en a qu'un genre, les champs) ni de bouton « Illimite » (aucune regle du
-- template ne l'active).

local _, LCM = ...
local UI = LCM.UI
local A = LCM.Actions

local Ecran = {}
UI.Constructeur = Ecran

local LARGEUR, HAUTEUR = 860, 640
local DORE = { 0.93, 0.80, 0.52 }
local LIGNE = 22

local function Placer(region, point, parent, relPoint, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, parent, relPoint, x, y)
end

local function Arrondi(v) return tostring(math.floor((tonumber(v) or 0) + 0.5)) end

local function Construire()
    local f = CreateFrame("Frame", "LCM_Constructeur", UIParent)
    Ecran.frame = f
    f:SetSize(LARGEUR, HAUTEUR)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f.fond = UI.Aplat(f, UI.C.fond)
    f.fond:SetAllPoints(f)
    if UI.AelCadre then f.cadre = UI.AelCadre(f, "section") else UI.Bordure(f) end
    f.titre = UI.Texte(f, "", DORE, "GameFontNormalLarge")
    Placer(f.titre, "TOP", f, "TOP", 0, -12)

    -- ----- apercu -----------------------------------------------------------
    f.apercu = CreateFrame("Frame", nil, f)
    f.apercu:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -38)
    f.apercu:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -38)
    f.apercu:SetHeight(66)
    f.apercu.fond = UI.Aplat(f.apercu, { 1, 1, 1, 0.05 })
    f.apercu.fond:SetAllPoints(f.apercu)
    UI.BordureFine(f.apercu, 0.3)
    f.icone = f.apercu:CreateTexture(nil, "ARTWORK")
    f.icone:SetSize(44, 44)
    Placer(f.icone, "LEFT", f.apercu, "LEFT", 9, 0)
    f.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.nomApercu = UI.Texte(f.apercu, "", UI.C.titre)
    f.nomApercu:SetPoint("TOPLEFT", f.icone, "TOPRIGHT", 10, -2)
    f.nomApercu:SetPoint("RIGHT", f.apercu, "RIGHT", -230, 0)
    f.descApercu = UI.Texte(f.apercu, "", UI.C.texte, "GameFontNormalSmall")
    f.descApercu:SetPoint("TOPLEFT", f.icone, "TOPRIGHT", 10, -20)
    f.descApercu:SetPoint("RIGHT", f.apercu, "RIGHT", -230, 0)
    f.descApercu:SetWordWrap(false)
    f.effetsApercu = UI.Texte(f.apercu, "", UI.C.discret, "GameFontNormalSmall")
    f.effetsApercu:SetPoint("TOPLEFT", f.icone, "TOPRIGHT", 10, -38)
    f.effetsApercu:SetPoint("RIGHT", f.apercu, "RIGHT", -230, 0)
    f.effetsApercu:SetWordWrap(false)
    f.meta = UI.Texte(f.apercu, "", UI.C.discret, "GameFontNormalSmall")
    Placer(f.meta, "TOPRIGHT", f.apercu, "TOPRIGHT", -10, -8)
    f.meta:SetJustifyH("RIGHT")

    -- ----- gauche : le constructeur ----------------------------------------
    f.separateur = UI.Aplat(f, { 1, 1, 1, 0.08 }, "ARTWORK")
    f.separateur:SetWidth(1)
    f.separateur:SetPoint("TOP", f, "TOP", -6, -116)
    f.separateur:SetPoint("BOTTOM", f, "BOTTOM", -6, 56)

    f.titreGauche = UI.Texte(f, "CONSTRUCTEUR", DORE)
    Placer(f.titreGauche, "TOPLEFT", f, "TOPLEFT", 16, -116)
    f.nomLibelle = UI.Texte(f, "Nom", UI.C.discret, "GameFontNormalSmall")
    Placer(f.nomLibelle, "TOPLEFT", f, "TOPLEFT", 16, -142)
    f.nom = UI.Champ(f, 220, 22, function() Ecran.Rendre() end)
    Placer(f.nom, "LEFT", f.nomLibelle, "RIGHT", 10, 0)
    f.descLibelle = UI.Texte(f, "Description", UI.C.discret, "GameFontNormalSmall")
    Placer(f.descLibelle, "TOPLEFT", f, "TOPLEFT", 16, -170)
    f.desc = UI.Champ(f, 320, 22, function() Ecran.Rendre() end)
    Placer(f.desc, "LEFT", f.descLibelle, "RIGHT", 10, 0)

    f.reserve = UI.Texte(f, "", UI.C.titre, "GameFontNormalLarge")
    Placer(f.reserve, "TOPLEFT", f, "TOPLEFT", 16, -200)
    f.duree = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    Placer(f.duree, "TOPLEFT", f, "TOPLEFT", 16, -228)
    f.dureeMoins = UI.Bouton(f, "−", 22, 20, function() f.constructeur:AcheterDuree(-1) Ecran.Rendre() end)
    Placer(f.dureeMoins, "TOPLEFT", f, "TOPLEFT", 300, -224)
    f.dureePlus = UI.Bouton(f, "+", 22, 20, function() f.constructeur:AcheterDuree(1) Ecran.Rendre() end)
    Placer(f.dureePlus, "LEFT", f.dureeMoins, "RIGHT", 4, 0)

    f.champs = UI.Defilement(f)
    f.champs:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -254)
    f.champs:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -22, 60)
    f.entetes, f.lignes = {}, {}
    f.replies = {}

    -- ----- droite : les choix -----------------------------------------------
    f.titreDroite = UI.Texte(f, "CHOIX", DORE)
    Placer(f.titreDroite, "TOPLEFT", f, "TOP", 8, -116)
    f.choix = UI.Defilement(f)
    f.choix:SetPoint("TOPLEFT", f, "TOP", 8, -138)
    f.choix:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 110)
    f.questions, f.options = {}, {}
    f.couts = UI.Texte(f, "", UI.C.texte)
    Placer(f.couts, "BOTTOMLEFT", f, "BOTTOM", 8, 84)
    f.absents = UI.Texte(f, "", UI.C.discret, "GameFontNormalSmall")
    f.absents:SetPoint("BOTTOMLEFT", f, "BOTTOM", 8, 62)
    f.absents:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    f.absents:SetWordWrap(true)

    -- ----- pied -------------------------------------------------------------
    f.blocage = UI.Texte(f, "", UI.C.plein, "GameFontNormalSmall")
    Placer(f.blocage, "BOTTOMLEFT", f, "BOTTOMLEFT", 16, 22)
    f.declarer = UI.Bouton(f, "Déclarer", 150, 26, function() Ecran.Declarer() end)
    Placer(f.declarer, "BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    f.annuler = UI.Bouton(f, "Annuler", 110, 26, function() f:Hide() end)
    Placer(f.annuler, "RIGHT", f.declarer, "LEFT", -8, 0)
    f:SetScript("OnHide", function()
        local annuler = f.rappelAnnuler
        f.rappelValider, f.rappelAnnuler = nil, nil
        if annuler then annuler() end
    end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "LCM_Constructeur" end
    f:Hide()
    return f
end

function Ecran.Fenetre() return Ecran.frame or Construire() end

-- ===== Rendu ===============================================================

local function Gauche(f)
    local c = f.constructeur
    local y = 0
    local nEntete, nLigne = 0, 0
    for _, famille in ipairs(c.familles) do
        nEntete = nEntete + 1
        local e = f.entetes[nEntete]
        if not e then
            e = UI.Bouton(f.champs.contenu, "", 100, 20, function(self)
                -- `false` : ouverte. Un clic ouvre une famille fermee, et ferme
                -- une famille ouverte.
                f.replies[self.libelle] = (f.replies[self.libelle] == false)
                Ecran.Rendre()
            end)
            e.label:SetJustifyH("LEFT")
            f.entetes[nEntete] = e
        end
        e.libelle = famille.libelle
        local mis = 0
        for _, ch in ipairs(famille.champs) do mis = mis + (c.points[ch.id] or 0) end
        e.label:SetText(string.format("%s %s  |cff9a9a9a(%s pt)|r%s", f.replies[famille.libelle] == false and "-" or "+",
            famille.libelle, tostring(famille.cout), mis > 0 and ("  |cffffd200" .. mis .. "|r") or ""))
        e:ClearAllPoints()
        e:SetPoint("TOPLEFT", f.champs.contenu, "TOPLEFT", 0, -y)
        e:SetPoint("TOPRIGHT", f.champs.contenu, "TOPRIGHT", 0, -y)
        e:Show()
        y = y + 24
        -- Replie par defaut, sauf ce qu'on a deja touche : quatre-vingts champs
        -- deplies d'un coup ne se lisent pas.
        local ouverte = f.replies[famille.libelle] == false or (f.replies[famille.libelle] == nil and mis > 0)
        if ouverte then
            f.replies[famille.libelle] = false
            for _, ch in ipairs(famille.champs) do
                nLigne = nLigne + 1
                local l = f.lignes[nLigne]
                if not l then
                    l = CreateFrame("Frame", nil, f.champs.contenu)
                    l:SetHeight(LIGNE)
                    l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                    Placer(l.nom, "LEFT", l, "LEFT", 14, 0)
                    l.plus = UI.Bouton(l, "+", 20, 18, function(self)
                        local pas = (IsShiftKeyDown and IsShiftKeyDown()) and 5 or 1
                        f.constructeur:Ajouter(self:GetParent().champ, pas)
                        Ecran.Rendre()
                    end)
                    Placer(l.plus, "RIGHT", l, "RIGHT", -2, 0)
                    l.valeur = UI.Texte(l, "0", UI.C.titre, "GameFontNormalSmall")
                    l.valeur:SetWidth(28)
                    l.valeur:SetJustifyH("CENTER")
                    Placer(l.valeur, "RIGHT", l.plus, "LEFT", -2, 0)
                    l.moins = UI.Bouton(l, "−", 20, 18, function(self)
                        local pas = (IsShiftKeyDown and IsShiftKeyDown()) and 5 or 1
                        f.constructeur:Ajouter(self:GetParent().champ, -pas)
                        Ecran.Rendre()
                    end)
                    Placer(l.moins, "RIGHT", l.valeur, "LEFT", -2, 0)
                    l.cout = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
                    Placer(l.cout, "RIGHT", l.moins, "LEFT", -8, 0)
                    f.lignes[nLigne] = l
                end
                l.champ = ch.id
                l.nom:SetText(ch.nom)
                l.valeur:SetText(tostring(c.points[ch.id] or 0))
                local cout = c:Cout(ch.id)
                l.cout:SetText(cout ~= famille.cout and string.format("|cff9be08f%s pt|r", Arrondi(cout * 10) / 10)
                    or (cout .. " pt"))
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", f.champs.contenu, "TOPLEFT", 0, -y)
                l:SetPoint("TOPRIGHT", f.champs.contenu, "TOPRIGHT", 0, -y)
                l:Show()
                y = y + LIGNE
            end
        end
    end
    for i = nEntete + 1, #f.entetes do f.entetes[i]:Hide() end
    for i = nLigne + 1, #f.lignes do f.lignes[i]:Hide() end
    f.champs:Regler(y)
end

local function Droite(f)
    local c = f.constructeur.composeur
    local largeur = f.choix:GetWidth()
    if not largeur or largeur < 40 then largeur = 390 end
    local y, nQ, nO = 0, 0, 0
    for _, q in ipairs(c:Visibles()) do
        nQ = nQ + 1
        local t = f.questions[nQ]
        if not t then
            t = UI.Texte(f.choix.contenu, "", { 0.62, 0.75, 0.87 }, "GameFontNormalSmall")
            f.questions[nQ] = t
        end
        t:SetText(q.label)
        Placer(t, "TOPLEFT", f.choix.contenu, "TOPLEFT", 0, -y)
        t:Show()
        y = y + 18
        local options = c:Options(q)
        local colonnes = 3
        local l = math.floor((largeur - (colonnes - 1) * 6) / colonnes)
        for i, o in ipairs(options) do
            nO = nO + 1
            local b = f.options[nO]
            if not b then
                b = UI.Bouton(f.choix.contenu, "", 100, 22, function(self)
                    local cc = f.constructeur.composeur
                    if self.q.mode == "multi" then cc:Cocher(self.q, self.o.id, not cc:EstChoisie(self.q, self.o.id))
                    else cc:Repondre(self.q, self.o.id) end
                    Ecran.Rendre()
                end)
                b.label:SetWordWrap(true)
                f.options[nO] = b
            end
            b.q, b.o = q, o
            b:SetSize(l, 22)
            local col, rang = (i - 1) % colonnes, math.floor((i - 1) / colonnes)
            Placer(b, "TOPLEFT", f.choix.contenu, "TOPLEFT", col * (l + 6), -y - rang * 26)
            local couts = {}
            if o.pa ~= 0 then couts[#couts + 1] = o.pa .. " PA" end
            if o.pf ~= 0 then couts[#couts + 1] = o.pf .. " PF" end
            b.label:SetText(o.label .. (#couts > 0 and (" |cff909090(" .. table.concat(couts, " ") .. ")|r") or ""))
            b:Selectionner(c:EstChoisie(q, o.id))
            b:Show()
        end
        y = y + math.ceil(#options / colonnes) * 26 + 8
    end
    for i = nQ + 1, #f.questions do f.questions[i]:Hide() end
    for i = nO + 1, #f.options do f.options[i]:Hide() end
    f.choix:Regler(y)
end

function Ecran.Rendre()
    local f = Ecran.frame
    local c = f.constructeur
    if not c then return end
    local mot = c.debuff and "Débuff" or "Buff"
    local reserve, depense = c:Reserve(), c:Depense()
    local duree = c:Duree()
    local nom = f.nom:GetText() or ""
    f.nomApercu:SetText(nom ~= "" and nom or ("|cff9a9a9a" .. mot .. " sans nom|r"))
    f.descApercu:SetText(f.desc:GetText() or "")
    local effets = {}
    for champ, n in pairs(c.points) do
        local field = LCM.Schema.Field(champ)
        effets[#effets + 1] = string.format("%s %+d", field and field.label or champ, c.debuff and -n or n)
    end
    table.sort(effets)
    f.effetsApercu:SetText(#effets > 0 and table.concat(effets, ", ") or "|cff9a9a9a(aucun effet)|r")
    f.meta:SetText(string.format("Réserve : %s / %d\nDurée : %s", Arrondi(depense), reserve,
        duree and (duree .. " round" .. (duree > 1 and "s" or "")) or "jusqu'à dissipation"))
    f.reserve:SetText(string.format("Points : |cff%s%s|r / %d", depense > reserve + 0.001 and "ff5959" or "ffd200",
        Arrondi(depense), reserve))
    f.duree:SetText(string.format("Durée : %s  |cff9a9a9a(+1 round = %d pt)|r",
        duree and (duree .. " round" .. (duree > 1 and "s" or "")) or "jusqu'à dissipation", c:ParRound()))
    Gauche(f)
    Droite(f)
    local pa, pf = c.composeur:Deriver()
    local dpa, dpf = A.Disponible(c.ctx.entity)
    if c.etape.hideCost then
        f.couts:SetText("")
    else
        f.couts:SetText(string.format("PA : %s / %s     PF : %s / %s", Arrondi(pa), Arrondi(dpa), Arrondi(pf), Arrondi(dpf)))
    end
    f.absents:SetText(#c.absents > 0 and ("Sans champ sur notre fiche : " .. table.concat(c.absents, ", ")) or "")
    local blocage = c:Blocage()
    f.blocage:SetText(blocage or "")
    f.declarer:SetEnabled(blocage == nil)
    f.declarer:SetAlpha(blocage and 0.4 or 1)
end

function Ecran.Ouvrir(constructeur, valider, annuler)
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() end
    f.constructeur, f.rappelValider, f.rappelAnnuler = constructeur, valider, annuler
    f.replies = {}
    f.titre:SetText(constructeur.debuff and "Construire un débuff" or "Construire un buff")
    f.icone:SetTexture(LCM.Icone(constructeur.ctx.icone))
    f.nom:SetText("")
    f.desc:SetText("")
    f:Show()
    f:Raise()
    Ecran.Rendre()
    return f
end

function Ecran.Declarer()
    local f = Ecran.frame
    if f.constructeur:Blocage() then return end
    local valider = f.rappelValider
    f.rappelValider, f.rappelAnnuler = nil, nil
    local nom, desc = f.nom:GetText() or "", f.desc:GetText() or ""
    f:Hide()
    if valider then valider(nom, desc, nil) end
end

A.onConstruire = function(constructeur, valider, annuler) Ecran.Ouvrir(constructeur, valider, annuler) end
