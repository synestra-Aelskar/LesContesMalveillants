-- Fenetre aventurier : consulter, prendre et ranger les objets d'un coffre.

local _, LCM = ...
local UI, C = LCM.UI, LCM.Coffres
local Ecran = {}
UI.Coffre = Ecran

local CASE, ECART, COLONNES = 58, 8, 8
local VIDE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function Libelle(parent, texte, x, y)
    local t = UI.Texte(parent, texte, UI.C.discret, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return t
end

local function InventaireTotal(entity, ref)
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

-- Une carte légère au survol : même contenu que « Voir », sans créer une
-- fenêtre persistante à chaque passage de souris.
local function CarteSurvol()
    if Ecran.carteSurvol then return Ecran.carteSurvol end
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetFrameStrata("TOOLTIP")
    p:SetSize(360, 120)
    p:SetClampedToScreen(true)
    p:EnableMouse(false)
    p.fond = UI.Aplat(p, { 0.04, 0.04, 0.05, 0.97 })
    p.fond:SetAllPoints(p)
    UI.BordureFine(p, 0.45)
    p.icone = p:CreateTexture(nil, "ARTWORK")
    p.icone:SetSize(42, 42)
    p.icone:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -10)
    p.icone:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p.nom = UI.Texte(p, "", UI.C.titre)
    p.nom:SetPoint("TOPLEFT", p.icone, "TOPRIGHT", 10, -2)
    p.nom:SetPoint("TOPRIGHT", p, "TOPRIGHT", -10, -10)
    p.nom:SetJustifyH("LEFT")
    p.sousTitre = UI.Texte(p, "", UI.C.accent, "GameFontNormalSmall")
    p.sousTitre:SetPoint("TOPLEFT", p.nom, "BOTTOMLEFT", 0, -3)
    p.sousTitre:SetPoint("RIGHT", p, "RIGHT", -10, 0)
    p.sousTitre:SetJustifyH("LEFT")
    p.corps = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
    p.corps:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -62)
    p.corps:SetWidth(340)
    p.corps:SetJustifyH("LEFT")
    p.corps:SetWordWrap(true)

    function p:Montrer(ref, ancre)
        local element, categorie = LCM.Compendium.Resoudre(ref)
        if not (element and categorie) then self:Hide(); return end
        local d = LCM.Compendium.Carte(categorie, element)
        local lignes = {}
        if d.entete ~= "" then lignes[#lignes + 1] = d.entete end
        if d.meta ~= "" then lignes[#lignes + 1] = d.meta end
        for _, section in ipairs(d.corps or {}) do
            local texte = section.texte or ""
            if section.composants then
                local composants = {}
                for _, composant in ipairs(section.composants) do
                    composants[#composants + 1] = composant.nom .. " x" .. tostring(composant.quantite)
                end
                texte = table.concat(composants, ", ")
            end
            if texte ~= "" then
                lignes[#lignes + 1] = (section.titre and section.titre ~= "")
                    and (section.titre .. " : " .. texte) or texte
            end
        end
        local statistiques = {}
        for index, stat in ipairs(d.stats or {}) do
            if index > 9 then statistiques[#statistiques + 1] = "…"; break end
            statistiques[#statistiques + 1] = stat.label .. " " .. tostring(stat.valeur)
        end
        if #statistiques > 0 then lignes[#lignes + 1] = table.concat(statistiques, "  ·  ") end
        if d.pied ~= "" then lignes[#lignes + 1] = d.pied end
        self.icone:SetTexture(d.icone)
        self.nom:SetText(d.nom)
        self.sousTitre:SetText(d.sousTitre or "")
        self.corps:SetText(table.concat(lignes, "\n"))
        self:SetHeight(math.min(420, math.max(72, 72 + (self.corps:GetStringHeight() or 0))))
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", ancre, "TOPRIGHT", 12, 0)
        self:Show()
    end

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
    local f = UI.Fenetre("coffre_joueur", "Coffre", 600, 470, { x = 0, y = -30 })
    f.fermer = UI.Bouton(f.contenu, "Fermer", 100, 24, function() f:Hide() end)
    f.fermer:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, 2)
    f.verrouiller = UI.Bouton(f.contenu, "Verrouiller", 120, 24, function() C.Envoyer("verrouiller") end)
    f.verrouiller:SetPoint("RIGHT", f.fermer, "LEFT", -8, 0)
    f.verrousBrises = UI.Texte(f.contenu, "", UI.C.plein, "GameFontNormalSmall")
    f.verrousBrises:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.statut = UI.Texte(f.contenu, "", UI.C.discret, "GameFontNormalSmall")
    f.statut:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.choixExpertise = UI.Bouton(f.contenu, "Choisir une expertise", 250, 24, function()
        local d = C.definitions[(C.points[C.courant] or {}).def]
        local options = {}
        for _, m in ipairs((d and d.coffre and d.coffre.expertises) or {}) do
            local champ = LCM.Schema.Field(m.id)
            options[#options + 1] = { id = m.id,
                label = (champ and champ.label or m.id) .. " — DD " .. tostring(m.dd) }
        end
        UI.Choix("coffre_expertise_ouverture", "Expertise pour ouvrir")
            :Proposer(f.choixExpertise, options, function(id)
                f.expertise = id
                for _, o in ipairs(options) do if o.id == id then f.choixExpertise.label:SetText(o.label) end end
            end)
    end)
    f.choixExpertise:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -42)
    f.forcer = UI.Bouton(f.contenu, "Forcer un verrou", 150, 24, function()
        local d = C.definitions[(C.points[C.courant] or {}).def]
        local m
        for _, method in ipairs((d and d.coffre and d.coffre.expertises) or {}) do
            if method.id == f.expertise then m = method break end
        end
        if not m then LCM.Alerte("choisis une expertise autorisée."); return end
        local entity = LCM.Entities.Self()
        for _, tool in ipairs(d.coffre.outils or {}) do
            if InventaireTotal(entity, tool.entree) < tool.quantite then
                LCM.Alerte("outil requis absent : " .. tostring((LCM.Compendium.Resoudre(tool.entree) or {}).label or tool.entree)); return
            end
        end
        local resultat, raison = LCM.Roll.Field(entity, m.id)
        if not resultat then LCM.Alerte(tostring(raison or "jet impossible.")); return end
        LCM.Actions.Annoncer(LCM.Roll.Describe(resultat) .. " contre DD " .. m.dd)
        f.outilsEnAttente = resultat.total >= m.dd and LCM.Copie(d.coffre.outils or {}) or nil
        C.Envoyer("forcer", { expertise = m.id, total = resultat.total })
    end)
    f.forcer:SetPoint("LEFT", f.choixExpertise, "RIGHT", 8, 0)
    f.forcer:Hide()
    f.grille = UI.Defilement(f.contenu)
    f.grille:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -78)
    f.grille:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
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
        UI.BordureFine(b, 0.32)
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
            if self.pile then CarteSurvol():Montrer(self.pile.ref, self) end
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
        for _, b in ipairs(f.cases) do b:Hide() end
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
    f.choixExpertise:SetShown(e.f == true)
    f.forcer:SetShown(e.f == true)
    local piles = f.ouvert and Piles(e.o) or {}
    for index = 1, places do
        local b = f.cases[index] or f:NouvelleCase(index)
        b.pile = piles[index]
        b.icone:SetTexture(b.pile and b.pile.element and LCM.Icone(b.pile.element.icone) or VIDE)
        b.icone:SetAlpha(b.pile and 1 or 0.24)
        b.nombre:SetText(b.pile and b.pile.quantite > 1 and tostring(b.pile.quantite) or "")
        local colonne = (index - 1) % COLONNES
        local ligne = math.floor((index - 1) / COLONNES)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f.grille.contenu, "TOPLEFT",
            colonne * (CASE + ECART), -ligne * (CASE + ECART))
        b:Show()
    end
    for index = places + 1, #f.cases do f.cases[index]:Hide() end
    f.grille:Regler(math.max(CASE, math.ceil(places / COLONNES) * (CASE + ECART) - ECART))
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
                for _ = 1, outil.consommeQuantite do LCM.Inventaire.Prendre(LCM.Entities.Self(), outil.entree) end
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

