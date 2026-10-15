-- Fenetre aventurier : consulter, prendre et ranger les objets d'un coffre.

local _, LCM = ...
local UI, C = LCM.UI, LCM.Coffres
local Ecran = {}
UI.Coffre = Ecran

local CASE, ECART, COLONNES_MAX = 58, 8, 6
local LARGEUR_MIN, LARGEUR_VERROUILLEE = 340, 390
local VIDE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function Libelle(parent, texte, x, y)
    local t = UI.Texte(parent, texte, UI.C.discret, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return t
end

local function SacTotal(entity, ref)
    local total = 0
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for i = 1, LCM.Inventaire.Capacite(categorie.id) do
            local e = LCM.Inventaire.Emplacement(entity, categorie.id, i)
            for _, item in pairs(e and e.cases or {}) do
                if item.ref == ref then total = total + (tonumber(item.quantite) or 1) end
            end
        end
    end
    return total
end
Ecran.SacTotal = SacTotal

local function InventaireTotal(entity, ref)
    local total = SacTotal(entity, ref)
    local objetId = tostring(ref or ""):match("^objets/(.+)$")
    if objetId and LCM.Objets and LCM.Objets.Equipes then
        for _, objet in ipairs(LCM.Objets.Equipes(entity) or {}) do
            if tostring(objet and objet.id or "") == objetId then total = total + 1 end
        end
    end
    return total
end
Ecran.InventaireTotal = InventaireTotal

local function ConsommerOutil(entity, ref)
    if LCM.Inventaire.Prendre(entity, ref) then return true end
    local objetId = tostring(ref or ""):match("^objets/(.+)$")
    if objetId and LCM.Objets and LCM.Objets.EstEquipe
            and LCM.Objets.EstEquipe(entity, objetId) then
        return LCM.Objets.Enlever(entity, objetId)
    end
    return false
end
Ecran.ConsommerOutil = ConsommerOutil

local function UserOutil(entity, ref)
    local objetId = tostring(ref or ""):match("^objets/(.+)$")
    if not objetId or not LCM.Objets then return false end
    if LCM.Objets.EstEquipe(entity, objetId) then
        LCM.Objets.Encaisser(entity, objetId, 1)
        return true
    end
    if SacTotal(entity, ref) > 0 and LCM.Objets.UserInventaire then
        LCM.Objets.UserInventaire(entity, objetId, 1)
        return true
    end
    return false
end
Ecran.UserOutil = UserOutil

local function BonusObjet(entity, ref, expertise)
    local element = LCM.Compendium.Resoudre(ref)
    if not (element and element.bonus) then return 0 end
    local montant = tonumber(element.bonus[expertise]) or 0
    if montant ~= 0 and LCM.Objets and LCM.Objets.ApportSelonEtat then
        montant = LCM.Objets.ApportSelonEtat(entity, element, montant)
    end
    return tonumber(montant) or 0
end
Ecran.BonusObjet = BonusObjet

local function ChanceExpertise(expertise, bonus, dd, entity)
    local champ = LCM.Schema.Field(expertise)
    local des = champ and champ.dice or {}
    local minimum, maximum = tonumber(des.min) or 0, tonumber(des.max) or 0
    if maximum < minimum then minimum, maximum = maximum, minimum end
    local reussites, total = 0, maximum - minimum + 1
    for jet = minimum, maximum do if jet + bonus >= dd then reussites = reussites + 1 end end
    local chance = total > 0 and reussites / total or 0
    -- Roll.Field impose automatiquement le désavantage : il garde le plus
    -- mauvais de deux jets, donc les deux doivent réussir.
    if entity and LCM.Effets.Desavantage(entity, expertise) then chance = chance * chance end
    return math.floor(100 * chance + 0.5)
end
Ecran.ChanceExpertise = ChanceExpertise

local function NomMethode(id)
    if id == C.METHODE_CLEF then return "Clef" end
    local champ = LCM.Schema.Field(id)
    return (champ and champ.label) or tostring(id or "Expertise inconnue")
end

local function OutilsPour(coffre, expertise)
    local outils = {}
    for _, outil in ipairs((coffre and coffre.outils) or {}) do
        -- Les anciennes définitions sans association restent globales afin
        -- de ne pas rendre soudainement leurs verrous plus permissifs.
        if not outil.expertise or outil.expertise == "" or outil.expertise == expertise then
            outils[#outils + 1] = outil
        end
    end
    return outils
end
Ecran.OutilsPour = OutilsPour

local function Occuper(objets)
    local total = 0
    for _, objet in ipairs(objets or {}) do
        local definition = LCM.Compendium.Resoudre(objet.entree)
        local pile = math.max(1, tonumber(definition and definition.pileMax) or 1)
        total = total + math.ceil((tonumber(objet.quantite) or 0) / pile)
    end
    return total
end

local function Piles(objets)
    local out = {}
    for _, objet in ipairs(objets or {}) do
        local definition = LCM.Compendium.Resoudre(objet.entree)
        local reste = math.max(0, math.floor(tonumber(objet.quantite) or 0))
        local pile = math.max(1, tonumber(definition and definition.pileMax) or reste)
        while reste > 0 do
            local quantite = math.min(reste, pile)
            out[#out + 1] = { ref = objet.entree, quantite = quantite, element = definition }
            reste = reste - quantite
        end
    end
    return out
end

local function Voir(ref, ancre)
    local element, categorie = LCM.Compendium.Resoudre(ref)
    if element and categorie and UI.Compendium and UI.Compendium.Voir then
        UI.Compendium.Voir(categorie, element, ancre)
    end
end

local function CarteSurvol()
    if Ecran.carteSurvol then return Ecran.carteSurvol end
    if not (UI.Compendium and UI.Compendium.NouvelleCarte) then return nil end
    local p = UI.Compendium.NouvelleCarte()
    p:SetFrameStrata("TOOLTIP")
    p:SetMovable(false)
    p:EnableMouse(false)
    p:SetScript("OnMouseDown", nil)
    p:SetScript("OnDragStart", nil)
    p:SetScript("OnDragStop", nil)
    if p.fermer then p.fermer:Hide() end
    if p.poignee then p.poignee:Hide() end
    p:Hide()
    Ecran.carteSurvol = p
    return p
end

local function AfficherProche(point)
    if not Ecran.bouton then
        local b = CreateFrame("Button", "LCM_BoutonCoffre", UIParent)
        b:SetSize(250, 42); b:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
        b:SetFrameStrata("HIGH")
        b.fond = UI.Aplat(b, UI.C.fond, "BACKGROUND"); b.fond:SetAllPoints(b); UI.Bordure(b)
        b.label = UI.Texte(b, "Ouvrir le coffre", UI.C.titre)
        b.label:SetPoint("CENTER", b, "CENTER")
        b:SetScript("OnClick", function(self) C.Ouvrir(self.pointId) end)
        Ecran.bouton = b
    end
    local b = Ecran.bouton
    if not point then b.pointId = nil; b:Hide(); return end
    b.pointId = point.id
    local d = C.definitions[point.def]
    b.label:SetText("Ouvrir : " .. tostring(d and d.label or "Coffre"))
    b:Show()
end

local function Construire()
    local f = UI.Fenetre("coffre_joueur", "Coffre", 420, 280, { x = 0, y = -30 })
    f.verrouiller = UI.Bouton(f.contenu, "Verrouiller", 120, 24, function() C.Envoyer("verrouiller") end)
    f.verrouiller:SetPoint("BOTTOM", f.contenu, "BOTTOM", 0, 0)
    f.verrousBrises = UI.Texte(f.contenu, "", UI.C.plein, "GameFontNormalSmall")
    f.verrousBrises:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.statut = UI.Texte(f.contenu, "", UI.C.discret, "GameFontNormalSmall")
    f.statut:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.choixExpertise = UI.Bouton(f.contenu, "Choisir une expertise", 320, 24, function()
        local d = C.definitions[(C.points[C.courant] or {}).def]
        local options = {}
        for _, m in ipairs((d and d.coffre and d.coffre.expertises) or {}) do
            local label = m.id == C.METHODE_CLEF
                and "Clef — objet requis, aucun jet"
                or (NomMethode(m.id) .. " — DD " .. tostring(m.dd)
                    .. " · " .. tostring(tonumber(m.fatigue) or 0) .. " PF")
            options[#options + 1] = { id = m.id, label = label }
        end
        UI.Choix("coffre_expertise_ouverture", "Expertise pour ouvrir")
            :Proposer(f.choixExpertise, options, function(id)
                f.expertise = id
                for _, o in ipairs(options) do if o.id == id then f.choixExpertise.label:SetText(o.label) end end
                f:MettreAJourTentative()
            end)
    end)
    f.choixExpertise:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -42)

    f.aidesTitre = UI.Texte(f.contenu,
        "Objets pour s’aider — glisse jusqu’à 6 objets depuis ton inventaire.",
        UI.C.discret, "GameFontNormalSmall")
    f.aidesTitre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -76)
    f.aides, f.aideCases = {}, {}
    for index = 1, 6 do
        local b = CreateFrame("Button", nil, f.contenu)
        b:SetSize(46, 46)
        b:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", (index - 1) * 54, -96)
        b:RegisterForClicks("RightButtonUp")
        b.fond = UI.Aplat(b, { 0, 0, 0, 0.24 }); b.fond:SetAllPoints(b)
        UI.BordureFine(b, 0.30)
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", 4, -4)
        b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 4)
        b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.bonus = UI.Texte(b, "", { 0.45, 1, 0.45 }, "GameFontNormalSmall")
        b.bonus:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 2)
        b.bonus:SetJustifyH("RIGHT")
        b:SetScript("OnClick", function(self, bouton)
            if bouton == "RightButton" and f.aides[self.index] then
                f.aides[self.index] = nil
                f:MettreAJourTentative()
            end
        end)
        b:SetScript("OnEnter", function(self)
            local aide = f.aides[self.index]
            local element, categorie = aide and LCM.Compendium.Resoudre(aide.ref)
            local carte = element and categorie and CarteSurvol()
            if carte then carte.placee = nil; carte:Montrer(categorie, element, self); carte:SetFrameStrata("TOOLTIP") end
        end)
        b:SetScript("OnLeave", function() if Ecran.carteSurvol then Ecran.carteSurvol:Hide() end end)
        UI.Glisser.Cible(b, function(objet)
            if not (f.etatRecu and f.etatRecu.f) then return false, "le coffre n’est pas verrouillé." end
            if not (objet.origine and objet.origine.case) then
                return false, "glisse un objet depuis une case de ton inventaire."
            end
            if not tostring(objet.ref or ""):match("^objets/") then
                return false, "seuls les objets peuvent aider cette tentative."
            end
            local deja = 0
            for i, aide in pairs(f.aides) do
                if i ~= b.index and aide.ref == objet.ref then deja = deja + 1 end
            end
            if deja >= SacTotal(LCM.Entities.Self(), objet.ref) then
                return false, "tu n’en possèdes pas assez pour remplir une autre case."
            end
            return true
        end, function(objet)
            f.aides[b.index] = { ref = objet.ref, element = objet.element }
            f:MettreAJourTentative()
        end)
        b.index = index
        f.aideCases[index] = b
    end
    f.bonusTentative = UI.Texte(f.contenu, "", UI.C.texte, "GameFontNormal")
    f.bonusTentative:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -153)
    f.ddTentative = UI.Texte(f.contenu, "", UI.C.texte, "GameFontNormalSmall")
    f.ddTentative:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -178)

    function f:MethodeCourante()
        local d = C.definitions[(C.points[C.courant] or {}).def]
        for _, methode in ipairs((d and d.coffre and d.coffre.expertises) or {}) do
            if methode.id == self.expertise then return methode end
        end
    end

    function f:BonusAides(methode)
        if not methode then return 0 end
        local total, entity = 0, LCM.Entities.Self()
        for _, aide in pairs(self.aides) do total = total + BonusObjet(entity, aide.ref, methode.id) end
        return total
    end

    function f:MettreAJourTentative()
        local methode, entity = self:MethodeCourante(), LCM.Entities.Self()
        local avecClef = methode and methode.id == C.METHODE_CLEF
        if self.etatRecu and self.etatRecu.f then
            local p = C.points[C.courant or ""]
            local d = p and C.definitions[p.def]
            local verbe = avecClef and "Ouvrir avec la clef" or "Forcer le verrou"
            local restants = tonumber(self.etatRecu.v) or 0
            self.forcer.label:SetText(string.format("%s (%d verrou%s restant%s / %d)",
                verbe, restants, restants > 1 and "s" or "", restants > 1 and "s" or "",
                tonumber(d and d.coffre and d.coffre.verrous) or 0))
        end
        self.aidesTitre:SetShown(self.etatRecu and self.etatRecu.f and not avecClef)
        local retenus = {}
        for index = 1, 6 do
            local aide = self.aides[index]
            if aide then
                retenus[aide.ref] = (retenus[aide.ref] or 0) + 1
                if retenus[aide.ref] > SacTotal(entity, aide.ref) then
                    self.aides[index], aide = nil, nil
                end
            end
            local case = self.aideCases[index]
            case:SetShown(self.etatRecu and self.etatRecu.f and not avecClef)
            local element = aide and (aide.element or LCM.Compendium.Resoudre(aide.ref))
            local bonus = aide and methode and BonusObjet(entity, aide.ref, methode.id) or 0
            case.icone:SetTexture(element and LCM.Icone(element.icone) or VIDE)
            case.icone:SetAlpha(element and 1 or 0.16)
            case.bonus:SetText(element and string.format("%+d", bonus) or "")
        end
        if not methode then
            self.bonusTentative:SetText("|cff70dc70Bonus total : —|r")
            self.ddTentative:SetText("DD d’expertise à vaincre : —")
            return
        end
        if avecClef then
            self.bonusTentative:SetText("|cff70dc70Ouverture automatique avec l’objet requis.|r")
            self.ddTentative:SetText("Aucun jet d’expertise ni DD à vaincre.")
            return
        end
        local expertise = LCM.Formules.Expertise(entity, methode.id)
        local objets = self:BonusAides(methode)
        local total, dd = expertise + objets, tonumber(methode.dd) or 0
        local chance = ChanceExpertise(methode.id, total, dd, entity)
        local couleur = chance < 30 and "ff5959" or (chance < 60 and "ff9f40"
            or (chance < 80 and "ffd34e" or "70dc70"))
        self.bonusTentative:SetText(string.format(
            "|cff70dc70Bonus total : %d|r  (|cffffd34eExpertise : %d|r + |cffffd34eObjets : %d|r)",
            total, expertise, objets))
        self.ddTentative:SetText(string.format(
            "DD d’expertise à vaincre : %d  (|cff%s%d %% de chance de réussir|r)", dd, couleur, chance))
    end

    f.forcer = UI.Bouton(f.contenu, "Forcer un verrou", 135, 24, function()
        local d = C.definitions[(C.points[C.courant] or {}).def]
        local m
        for _, method in ipairs((d and d.coffre and d.coffre.expertises) or {}) do
            if method.id == f.expertise then m = method break end
        end
        if not m then LCM.Alerte("choisis une expertise autorisée."); return end
        local entity = LCM.Entities.Self()
        local outils = OutilsPour(d.coffre, m.id)
        local avecClef = m.id == C.METHODE_CLEF
        if avecClef and #outils == 0 then
            LCM.Alerte("aucune clef n’est configurée pour ce verrou."); return
        end
        for _, tool in ipairs(outils) do
            if InventaireTotal(entity, tool.entree) < tool.quantite then
                LCM.Alerte("outil requis absent : " .. tostring((LCM.Compendium.Resoudre(tool.entree) or {}).label or tool.entree)); return
            end
        end
        if avecClef then
            if m.usureOutils then
                for _, outil in ipairs(outils) do
                    for _ = 1, tonumber(outil.quantite) or 1 do UserOutil(entity, outil.entree) end
                end
            end
            LCM.Actions.Annoncer("Clef : ouverture du verrou sans jet d’expertise.")
            f.outilsEnAttente = LCM.Copie(outils)
            C.Envoyer("forcer", { expertise = m.id, score = 0, total = 0, clef = true })
            return
        end
        local coutFatigue = math.max(0, math.floor(tonumber(m.fatigue) or 0))
        local fatigue = LCM.Entities.Gauge(entity, "fatigue")
        if coutFatigue > 0 and (not fatigue or (tonumber(fatigue.current) or 0) < coutFatigue) then
            LCM.Alerte("fatigue insuffisante : cette tentative coûte " .. coutFatigue .. " PF.")
            return
        end
        f:MettreAJourTentative()
        local compteAides = {}
        for _, aide in pairs(f.aides) do
            compteAides[aide.ref] = (compteAides[aide.ref] or 0) + 1
            if compteAides[aide.ref] > SacTotal(entity, aide.ref) then
                LCM.Alerte("un objet d’aide n’est plus dans ton inventaire."); return
            end
        end
        local bonusAides = f:BonusAides(m)
        local resultat, raison = LCM.Roll.Field(entity, m.id, { modificateur = bonusAides })
        if not resultat then LCM.Alerte(tostring(raison or "jet impossible.")); return end
        if coutFatigue > 0 then
            local ok, erreur = LCM.Entities.SetGauge(entity, "fatigue",
                (tonumber(fatigue.current) or 0) - coutFatigue)
            if not ok then LCM.Alerte(tostring(erreur or "impossible de dépenser la fatigue.")); return end
            LCM.Info("Tentative de verrou : -" .. coutFatigue .. " PF.")
        end
        if m.usureOutils then
            for _, outil in ipairs(outils) do
                for _ = 1, tonumber(outil.quantite) or 1 do UserOutil(entity, outil.entree) end
            end
        end
        for _, aide in pairs(f.aides) do
            local objetId = tostring(aide.ref or ""):match("^objets/(.+)$")
            if objetId and LCM.Objets and LCM.Objets.UserInventaire then
                LCM.Objets.UserInventaire(entity, objetId, 1)
            end
        end
        f:MettreAJourTentative()
        local score, dd = tonumber(resultat.total) or 0, tonumber(m.dd) or 0
        LCM.Actions.Annoncer(LCM.Roll.Describe(resultat) .. " contre DD " .. m.dd)
        f.outilsEnAttente = score >= dd and LCM.Copie(outils) or nil
        C.Envoyer("forcer", { expertise = m.id, score = score, total = score, dd = dd })
    end)
    f.forcer:SetSize(300, 26)
    f.forcer:ClearAllPoints()
    f.forcer:SetPoint("TOP", f.contenu, "TOP", 0, -210)
    f.forcer:Hide()
    f.grille = UI.Defilement(f.contenu)
    f.grille:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -48)
    f.grille:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 36)
    f.cases = {}

    function f:PeutPrendre(ref, quantite)
        local copie = LCM.Copie(LCM.Entities.Self())
        return LCM.Inventaire.Deposer(copie, ref, quantite)
    end

    function f:Prendre(ref, quantite)
        if self.priseGlissee then LCM.Alerte("un transfert est déjà en attente."); return false end
        local ok, raison = self:PeutPrendre(ref, quantite)
        if not ok then LCM.Alerte(raison or "aucune place libre."); return false end
        return C.Envoyer("prendre", { e = ref, q = quantite })
    end

    function f:Ranger(objet)
        if objet.retirer then objet.retirer() end
        self.rangementEnAttente = objet
        local ok, raison = C.Envoyer("ranger", { e = objet.ref, q = objet.quantite or 1 })
        if not ok then
            if objet.rendre then objet.rendre() end
            self.rangementEnAttente = nil
            LCM.Alerte(raison or "transfert impossible.")
        end
    end

    function f:ObjetGlissable(pile)
        local demande = { ref = pile.ref, quantite = pile.quantite }
        return {
            icone = pile.element and LCM.Icone(pile.element.icone) or nil,
            nom = pile.element and pile.element.label or pile.ref,
            ref = pile.ref, quantite = pile.quantite, element = pile.element,
            origine = { coffre = true, point = self.pointId },
            retirer = function()
                demande.envoyee = true
                f.priseGlissee = demande
                local ok, raison = C.Envoyer("prendre", { e = demande.ref, q = demande.quantite })
                if not ok then
                    demande.reponse = false
                    demande.raison = raison
                end
            end,
            rendre = function() demande.annulee = true end,
        }
    end

    function f:NouvelleCase(index)
        local b = CreateFrame("Button", nil, self.grille.contenu)
        b:SetSize(CASE, CASE)
        b.index = index
        b:RegisterForClicks("RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b.fond = UI.Aplat(b, { 0, 0, 0, 0.28 })
        b.fond:SetAllPoints(b)
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -5)
        b.icone:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 5)
        b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.nombre = UI.Texte(b, "", { 1, 0.92, 0.48 }, "GameFontNormal")
        b.nombre:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 3)
        b.nombre:SetJustifyH("RIGHT")
        b.survol = UI.Aplat(b, UI.C.survol, "HIGHLIGHT")
        b.survol:SetAllPoints(b)
        UI.Glisser.Cible(b, function(objet)
            if not f.ouvert then return false, "le coffre est verrouillé." end
            if b.pile then return false, "cet emplacement est déjà occupé." end
            if f.rangementEnAttente then return false, "un rangement est déjà en attente." end
            if not objet.origine or not objet.origine.case then
                return false, "seuls les objets de ton inventaire peuvent être rangés."
            end
            if not tostring(objet.ref or ""):match("^objets/") then
                return false, "le coffre n'accepte que des objets."
            end
            return true
        end, function(objet) f:Ranger(objet) end)
        b:SetScript("OnDragStart", function(self)
            if not self.pile or f.priseGlissee then return end
            local ok, raison = f:PeutPrendre(self.pile.ref, self.pile.quantite)
            if not ok then LCM.Alerte(raison or "aucune place libre."); return end
            if Ecran.carteSurvol then Ecran.carteSurvol:Hide() end
            UI.Glisser.Commencer(f:ObjetGlissable(self.pile))
        end)
        b:SetScript("OnDragStop", function() UI.Glisser.Lacher() end)
        b:SetScript("OnClick", function(self, bouton)
            if bouton ~= "RightButton" or not self.pile then return end
            UI.MenuContexte():Ouvrir(self, {
                { label = "Prendre", action = function()
                    f:Prendre(self.pile.ref, self.pile.quantite)
                end },
                { label = "Voir", action = function() Voir(self.pile.ref, f) end },
            })
        end)
        b:SetScript("OnEnter", function(self)
            if not self.pile then return end
            local element, categorie = LCM.Compendium.Resoudre(self.pile.ref)
            local carte = element and categorie and CarteSurvol()
            if carte then
                carte.placee = nil
                carte:Montrer(categorie, element, self)
                carte:SetFrameStrata("TOOLTIP")
            end
        end)
        b:SetScript("OnLeave", function()
            if Ecran.carteSurvol then Ecran.carteSurvol:Hide() end
        end)
        self.cases[index] = b
        return b
    end

    f.Afficher = function() Ecran.MettreAJour() end
    f:HookScript("OnHide", function() if f.ouvert then C.Envoyer("fermer") end end)
    Ecran.frame = f
    return f
end

function Ecran.Ouvrir(id)
    local f = Ecran.frame or Construire()
    f.pointId = id
    f.aides = {}
    f.expertise = nil
    f.choixExpertise.label:SetText("Choisir une expertise")
    f:Show(); f:Afficher(); f:Raise()
end

function Ecran.MettreAJour()
    local f = Ecran.frame
    if not f or not f:IsShown() then return end
    local p = C.points[C.courant or ""]
    local d = p and C.definitions[p.def]
    local e = C.etat
    if not p then f:Hide(); return end
    f:Titre(tostring(d and d.label or "Coffre"))
    if not e then
        f.verrousBrises:Hide()
        f.statut:ClearAllPoints()
        f.statut:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
        f.statut:SetText("Chargement du coffre…")
        f.grille:Hide()
        f.choixExpertise:Hide(); f.aidesTitre:Hide(); f.bonusTentative:Hide()
        f.ddTentative:Hide(); f.forcer:Hide()
        for _, case in ipairs(f.aideCases) do case:Hide() end
        for _, b in ipairs(f.cases) do b:Hide() end
        f:SetSize(LARGEUR_VERROUILLEE, f.insetHaut + 90 + f.insetBas)
        return
    end
    f.etatRecu = e
    f.ouvert = e.s == true
    local places = d and d.coffre and d.coffre.places or 0
    local brises = 0
    for _, reverrouillable in ipairs(e.vo or {}) do if not reverrouillable then brises = brises + 1 end end
    f.verrousBrises:SetText(brises == 1 and "1 verrou brisé."
        or (brises > 1 and string.format("%d verrous brisés.", brises) or ""))
    f.verrousBrises:SetShown(brises > 0)
    f.statut:ClearAllPoints()
    f.statut:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, brises > 0 and -20 or 0)
    f.statut:SetText(e.f and string.format("Verrouillé — %d verrou(x) restant(s).", e.v or 0)
        or string.format("%s — %d / %d emplacements occupés.", f.ouvert and "Ouvert" or "Fermé",
            Occuper(e.o), places))
    local verrousOuverts = e.vo or {}
    local reverrouillable = not (d and d.coffre and d.coffre.reset) and #verrousOuverts > 0
    for _, autorise in ipairs(verrousOuverts) do if not autorise then reverrouillable = false; break end end
    f.verrouiller:SetShown(f.ouvert and reverrouillable)
    local verrouille = e.f == true
    f.choixExpertise:SetShown(verrouille)
    f.aidesTitre:SetShown(verrouille)
    f.bonusTentative:SetShown(verrouille)
    f.ddTentative:SetShown(verrouille)
    f.forcer:SetShown(verrouille)
    for _, case in ipairs(f.aideCases) do case:SetShown(verrouille) end
    if verrouille then
        local methode = f:MethodeCourante()
        local verbe = methode and methode.id == C.METHODE_CLEF and "Ouvrir avec la clef" or "Forcer le verrou"
        f.forcer.label:SetText(string.format("%s (%d verrou%s restant%s / %d)", verbe,
            tonumber(e.v) or 0, (tonumber(e.v) or 0) > 1 and "s" or "",
            (tonumber(e.v) or 0) > 1 and "s" or "", tonumber(d.coffre.verrous) or 0))
        f:MettreAJourTentative()
    end
    local piles = f.ouvert and Piles(e.o) or {}
    local colonnes = math.max(1, math.min(COLONNES_MAX, places))
    local lignes = math.max(1, math.ceil(places / colonnes))
    if f.ouvert then
        f.grille:ClearAllPoints()
        f.grille:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -48)
        f.grille:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0,
            reverrouillable and 36 or 0)
        f.grille:Show()
        for index = 1, places do
            local b = f.cases[index] or f:NouvelleCase(index)
            b.pile = piles[index]
            b.icone:SetTexture(b.pile and b.pile.element and LCM.Icone(b.pile.element.icone) or VIDE)
            b.icone:SetAlpha(b.pile and 1 or 0.18)
            b.fond:SetColorTexture(0, 0, 0, b.pile and 0.24 or 0.10)
            b.nombre:SetText(b.pile and b.pile.quantite > 1 and tostring(b.pile.quantite) or "")
            local colonne = (index - 1) % colonnes
            local ligne = math.floor((index - 1) / colonnes)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f.grille.contenu, "TOPLEFT",
                colonne * (CASE + ECART), -ligne * (CASE + ECART))
            b:Show()
        end
    else
        f.grille:Hide()
        for _, b in ipairs(f.cases) do b:Hide() end
    end
    for index = places + 1, #f.cases do f.cases[index]:Hide() end
    local hauteurGrille = lignes * (CASE + ECART) - ECART
    f.grille:Regler(hauteurGrille)
    if e.f then
        f:SetSize(500, f.insetHaut + 250 + f.insetBas)
    else
        local largeurGrille = colonnes * (CASE + ECART) - ECART
        local largeur = math.max(LARGEUR_MIN, largeurGrille + f.insetCote * 2)
        local margeBas = reverrouillable and 44 or 12
        f:SetSize(largeur, f.insetHaut + 48 + hauteurGrille + margeBas + f.insetBas)
    end
end

function Ecran.Proche(point) AfficherProche(point) end
C.onChange = Ecran.MettreAJour

function Ecran.Repondre(expediteur, data)
    local f = Ecran.frame
    if not f then return end
    if data.msg and not data.ok then LCM.Alerte(tostring(data.msg)) end
    if data.action == nil then return end
    if data.action == "ranger" and f.rangementEnAttente then
        if data.ok then f.rangementEnAttente = nil
        elseif f.rangementEnAttente.rendre then
            f.rangementEnAttente.rendre(); f.rangementEnAttente = nil
        end
    elseif data.action == "prendre" and f.priseGlissee then
        local demande = f.priseGlissee
        demande.reponse = data.ok == true
        if data.ok and data.objet and LCM.Echange and LCM.Echange.ImporterObjetPartage then
            LCM.Echange.ImporterObjetPartage({ ref = data.e, definition = data.objet })
        end
        C_Timer.After(0, function()
            if f.priseGlissee ~= demande then return end
            if demande.reponse and demande.annulee then
                C.Envoyer("ranger", { e = demande.ref, q = demande.quantite })
            elseif not demande.reponse and not demande.annulee then
                for _ = 1, demande.quantite do LCM.Inventaire.Prendre(LCM.Entities.Self(), demande.ref) end
            end
            f.priseGlissee = nil
        end)
    elseif data.action == "prendre" and data.ok then
        local item = data.objet
        if item and LCM.Echange and LCM.Echange.ImporterObjetPartage then
            LCM.Echange.ImporterObjetPartage({ ref = data.e, definition = item })
        end
        local ok, raison = LCM.Inventaire.Deposer(LCM.Entities.Self(), data.e, tonumber(data.q) or 1)
        if not ok then C.Envoyer("ranger", { e = data.e, q = tonumber(data.q) or 1 }); LCM.Alerte(raison) end
    elseif data.action == "forcer" and data.ok and f.outilsEnAttente then
        for _, outil in ipairs(f.outilsEnAttente) do
            if outil.consomme then
                for _ = 1, outil.consommeQuantite do
                    ConsommerOutil(LCM.Entities.Self(), outil.entree)
                end
            end
        end
        f.outilsEnAttente = nil
    elseif data.action == "forcer" and not data.ok then
        f.outilsEnAttente = nil
    end
end

function Ecran.Retirer(id)
    local f = Ecran.frame
    if f and tostring(f.pointId or "") == tostring(id or "") then f:Hide() end
end

C.onChange = function() Ecran.MettreAJour() end
C.onReponse = Ecran.Repondre

