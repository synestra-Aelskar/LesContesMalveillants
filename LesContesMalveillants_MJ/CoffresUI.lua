-- La fenêtre « Coffres » du MJ : créer les modèles, puis les placer dans le
-- monde. Elle reprend volontairement la structure de Ressources : définitions
-- à gauche, onglets Création / Placement à droite et tableaux éditables.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Points = LCM.Points
local Coffres = LCM.CoffresMJ

local Ecran = {}
UI.CoffresMJ = Ecran

local LARGEUR, HAUTEUR = 820, 640
local COLONNE, LIGNE = 210, 36
local function Eq() return (LCM.Equilibrage and LCM.Equilibrage.coffres) or {} end
local function NomMethode(id)
    if id == LCM.Coffres.METHODE_CLEF then return "Clef" end
    local champ = LCM.Schema.Field(id)
    return (champ and champ.label) or tostring(id or "Expertise inconnue")
end

local function Libelle(parent, texte, x, y)
    local t = UI.Texte(parent, texte, UI.C.texte, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return t
end

local function Entier(valeur)
    local n = tonumber(valeur)
    return n and n == math.floor(n) and n or nil
end

local function OptionsExpertises(choix, exception)
    local deja = {}
    for index, methode in ipairs(choix or {}) do
        if index ~= exception then deja[methode.id] = true end
    end
    local out = {}
    for _, tab in ipairs(LCM.Schema.Tabs()) do
        for _, section in ipairs(tab.sections) do
            for _, field in ipairs(section.fields) do
                if field.jetExpertise and not deja[field.id] then
                    out[#out + 1] = { id = field.id, label = field.label }
                end
            end
        end
    end
    if not deja[LCM.Coffres.METHODE_CLEF] then
        out[#out + 1] = { id = LCM.Coffres.METHODE_CLEF, label = "Clef" }
    end
    table.sort(out, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return out
end

local function OptionsObjets(choix, exception, doublons)
    local deja = {}
    for index, objet in ipairs(choix or {}) do
        if not doublons and index ~= exception then deja[objet.entree] = true end
    end
    local out = {}
    for _, objet in ipairs((LCM.Objets and LCM.Objets.list) or {}) do
        local ref = "objets/" .. tostring(objet.id)
        if not deja[ref] then
            out[#out + 1] = { id = ref, label = objet.label or objet.id,
                groupe = objet.categorie or "Objets" }
        end
    end
    if not doublons then
        for _, livre in ipairs((LCM.Livres and LCM.Livres.list) or {}) do
            local ref = "livres/" .. tostring(livre.id)
            if not deja[ref] then
                out[#out + 1] = { id = ref, label = livre.label or livre.id, groupe = "Livres" }
            end
        end
        -- Un coffre contient aussi des ressources, et les monnaies qui ont une
        -- forme (le MJ, 19 octobre 2026). Une monnaie qui n'existe qu'en solde
        -- de bourse n'a rien a y poser : LCM.Coffres.Accepte en juge.
        for _, ressource in ipairs((LCM.Ressources and LCM.Ressources.list) or {}) do
            local ref = "ressources/" .. tostring(ressource.id)
            if not deja[ref] then
                out[#out + 1] = { id = ref, label = ressource.label or ressource.id,
                    groupe = "Ressources" }
            end
        end
        for _, devise in ipairs((LCM.Devises and LCM.Devises.list) or {}) do
            local ref = "devises/" .. tostring(devise.id)
            if not deja[ref] and LCM.Coffres.Accepte(ref) == true then
                out[#out + 1] = { id = ref, label = devise.label or devise.id, groupe = "Devises" }
            end
        end
        -- Un sac se pose dans un coffre comme n'importe quelle entree : il se
        -- range, il se transporte (le MJ, 20 octobre 2026).
        for _, sac in ipairs((LCM.Sacs and LCM.Sacs.list) or {}) do
            local ref = "sacs/" .. tostring(sac.id)
            if not deja[ref] then
                out[#out + 1] = { id = ref, label = sac.label or sac.id, groupe = "Sacs" }
            end
        end
    end
    if doublons then
        for _, typeOutil in ipairs(LCM.Listes.De("outils")) do
            out[#out + 1] = { id = "type_outil/" .. typeOutil.id,
                label = "Tout outil de type « " .. typeOutil.label .. " »",
                groupe = "Types d’outils" }
        end
    end
    table.sort(out, function(a, b)
        if a.groupe ~= b.groupe then return tostring(a.groupe) < tostring(b.groupe) end
        return tostring(a.label) < tostring(b.label)
    end)
    return out
end

local function OptionsExpertisesOutils(methodes)
    local out = {}
    for _, methode in ipairs(methodes or {}) do
        out[#out + 1] = { id = methode.id, label = NomMethode(methode.id) }
    end
    return out
end

local function Travail(point)
    if point then
        local copie = LCM.Copie(point)
        copie.coffre = copie.coffre or {}
        copie.coffre.places = copie.coffre.places or 10
        copie.coffre.rayon = copie.coffre.rayon or Eq().rayon or 4
        copie.coffre.verrous = copie.coffre.verrous or 0
        copie.coffre.objets = copie.coffre.objets or {}
        copie.coffre.expertises = copie.coffre.expertises or {}
        copie.coffre.outils = copie.coffre.outils or {}
        local expertiseDefaut = copie.coffre.expertises[1] and copie.coffre.expertises[1].id
        for _, outil in ipairs(copie.coffre.outils) do
            if not outil.expertise or outil.expertise == "" then outil.expertise = expertiseDefaut end
        end
        return copie
    end
    return {
        id = LCM.Brouillons.NouvelIdentifiant(), nature = "coffre",
        label = "", description = "", coffre = {
            places = 10, rayon = Eq().rayon or 4, verrous = 0, reset = false,
            objets = {}, expertises = {}, outils = {},
        },
    }
end

local function Cases(objets)
    local total = 0
    for _, objet in ipairs(objets or {}) do
        local entree = LCM.Compendium.Resoudre(objet.entree)
        local pile = math.max(1, tonumber(entree and entree.pileMax) or 1)
        total = total + math.ceil((tonumber(objet.quantite) or 0) / pile)
    end
    return total
end

local function Resume(point)
    local c = point and point.coffre
    if not c then return "Pas encore configuré : passe par l’onglet Création." end
    return string.format("%d emplacement(s) — %d objet(s) — %d verrou(s) — rayon %s yards",
        tonumber(c.places) or 0, #(c.objets or {}), tonumber(c.verrous) or 0,
        tostring(c.rayon or Eq().rayon or 4))
end

local function Tableau(parent, y, colonnes, hauteur)
    local cadre = CreateFrame("Frame", nil, parent)
    cadre:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    cadre:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, y)
    cadre:SetHeight(hauteur)
    UI.BordureFine(cadre, 0.18)
    local entete = CreateFrame("Frame", nil, cadre)
    entete:SetPoint("TOPLEFT", cadre, "TOPLEFT", 1, -1)
    entete:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", -1, -1)
    entete:SetHeight(23)
    local fond = UI.Aplat(entete, { 0.07, 0.07, 0.07, 0.30 })
    fond:SetAllPoints(entete)
    for index, colonne in ipairs(colonnes) do
        local titre = Libelle(entete, colonne[1], colonne[2], -6)
        titre:SetWidth(colonne[3])
        titre:SetJustifyH("CENTER")
        if index > 1 then
            local trait = UI.Filet(entete, false, true)
            trait:SetPoint("TOPLEFT", entete, "TOPLEFT", colonne[2], 0)
            trait:SetPoint("BOTTOMLEFT", entete, "BOTTOMLEFT", colonne[2], 0)
        end
    end
    local zone = UI.Defilement(cadre)
    zone:SetPoint("TOPLEFT", cadre, "TOPLEFT", 1, -24)
    zone:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", -1, 1)
    -- `hauteur` est un PLAFOND : le tableau grandit avec ses lignes jusque-la,
    -- puis defile (AjusterTableau).
    cadre.maxVisible = hauteur - 25
    return cadre, zone
end

-- Le tableau a la hauteur de ce qu'il contient : l'en-tete, ses lignes et la
-- ligne « + Ajouter ». Il avait une hauteur fixe, et trois objets laissaient
-- un grand vide sous eux (16 octobre 2026). Rien n'est ajoute pour le remplir.
local function AjusterTableau(cadre, zone, contenu)
    cadre:SetHeight(25 + math.min(contenu, cadre.maxVisible))
    zone:Regler(contenu)
end

local function FondLigne(ligne)
    local fond = UI.Aplat(ligne, { 0.07, 0.07, 0.07, 0.10 })
    fond:SetAllPoints(ligne)
    UI.BordureFine(ligne, 0.14)
end

local function BoutonTexte(parent, largeur)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(largeur, 24)
    b.label = UI.Texte(b, "", UI.C.texte, "GameFontNormalSmall")
    b.label:SetAllPoints(b)
    b.label:SetJustifyH("LEFT")
    local survol = UI.Aplat(b, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
    survol:SetAllPoints(b)
    return b
end

local function Construire()
    local f = UI.Fenetre("coffres_mj", "Coffres", LARGEUR, HAUTEUR, { x = 0, y = -20 }, { enTeteSimple = true, sobre = true })
    f.onglet = "creation"
    f.lignes, f.lignesObjets, f.lignesExpertises, f.lignesOutils, f.placements = {}, {}, {}, {}, {}
    f.choixObjet = UI.Choix("coffre_objet", "Objet du coffre")
    f.choixOutil = UI.Choix("coffre_outil", "Outil requis")
    f.choixExpertise = UI.Choix("coffre_expertise", "Expertise de déverrouillage")
    f.choixExpertiseOutil = UI.Choix("coffre_expertise_outil", "Expertise associée à l’outil")
    f.confirmation = UI.Confirmer(f, "", "Confirmer")

    f.liste = UI.Defilement(f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 64)
    f.liste:SetWidth(COLONNE)
    f.nouveau = UI.Bouton(f.contenu, "+ Nouveau", 100, 24, function() f:Nouveau() end)
    f.nouveau:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.supprimer = UI.Bouton(f.contenu, "Supprimer", 100, 24, function() f:Supprimer() end)
    f.supprimer:SetPoint("LEFT", f.nouveau, "RIGHT", 6, 0)
    f.dupliquer = UI.Bouton(f.contenu, "Dupliquer", 206, 24, function() f:Dupliquer() end)
    f.dupliquer:SetPoint("BOTTOMLEFT", f.nouveau, "TOPLEFT", 0, 6)

    f.droite = CreateFrame("Frame", nil, f.contenu)
    f.droite:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 16, 0)
    f.droite:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.boutonCreation = UI.Bouton(f.droite, "Création", 120, 24, function() f:Onglet("creation") end)
    f.boutonCreation:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, 0)
    f.boutonPlacement = UI.Bouton(f.droite, "Placement", 120, 24, function() f:Onglet("placement") end)
    f.boutonPlacement:SetPoint("LEFT", f.boutonCreation, "RIGHT", 6, 0)

    local c = CreateFrame("Frame", nil, f.droite)
    c:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -34)
    c:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.creation = c
    Libelle(c, "Nom", 0, -6)
    c.nom = UI.Champ(c, 300, 22, function(texte) if f.travail then f.travail.label = texte end end)
    c.nom:SetMaxLetters(80)
    c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 110, 0)
    c.pages = UI.PagesFormulaire(c, { "Contenu du coffre", "Accès & outils" })
    Libelle(c.pages[1], "Emplacements", 0, -8)
    c.places = UI.Champ(c.pages[1], 50, 22, function(texte) if f.travail then f.travail.coffre.places = texte end end)
    c.places:SetPoint("TOPLEFT", c.pages[1], "TOPLEFT", 110, -2)
    Libelle(c.pages[1], "Nombre de verrous", 190, -8)
    c.verrous = UI.Champ(c.pages[1], 50, 22, function(texte) if f.travail then f.travail.coffre.verrous = texte end end)
    c.verrous:SetPoint("TOPLEFT", c.pages[1], "TOPLEFT", 320, -2)
    Libelle(c.pages[1], "Rayon (yards)", 382, -8)
    c.rayon = UI.Champ(c.pages[1], 50, 22, function(texte) if f.travail then f.travail.coffre.rayon = texte end end)
    c.rayon:SetPoint("TOPLEFT", c.pages[1], "TOPLEFT", 470, -2)
    c.reset = UI.Case(c.pages[1], "Réinitialiser à la fermeture", function(coche)
        if f.travail then f.travail.coffre.reset = coche end
    end)
    c.reset:SetPoint("TOPLEFT", c.pages[1], "TOPLEFT", 0, -34)
    local aideRayon = Libelle(c.pages[1], "Distance à laquelle le bouton « Ouvrir » apparaît.", 210, -36)
    aideRayon:SetWidth(310)
    Libelle(c.pages[1], "Objets contenus", 0, -76)
    c.tableauObjets, c.zoneObjets = Tableau(c.pages[1], -98, {
        { "I", 0, 31 }, { "OBJET", 31, 309 }, { "QUANTITÉ", 340, 110 }, { "", 450, 48 },
    }, 226)
    Libelle(c.pages[2], "Méthodes autorisées — chaque réussite ouvre un verrou", 0, -2)
    c.tableauExpertises, c.zoneExpertises = Tableau(c.pages[2], -26, {
        { "EXPERTISE", 0, 150 }, { "DD", 150, 48 }, { "FATIGUE", 198, 65 },
        { "USURE OUTILS", 263, 98 }, { "REVERROUILLER", 361, 111 }, { "", 472, 26 },
    }, 150)
    -- Les outils suivent le tableau des expertises, qui grandit avec ses
    -- lignes : poses a une hauteur fixe, ils laisseraient un trou entre eux.
    local titreOutils = Libelle(c.pages[2], "Outils requis", 0, -194)
    titreOutils:ClearAllPoints()
    titreOutils:SetPoint("TOPLEFT", c.tableauExpertises, "BOTTOMLEFT", 0, -18)
    c.tableauOutils, c.zoneOutils = Tableau(c.pages[2], -218, {
        { "OUTIL", 0, 168 }, { "EXPERTISE", 168, 114 }, { "REQUIS", 282, 55 },
        { "CONSOMMÉ", 337, 73 }, { "QTÉ CONS.", 410, 62 }, { "", 472, 26 },
    }, 142)
    c.tableauOutils:ClearAllPoints()
    c.tableauOutils:SetPoint("TOPLEFT", c.tableauExpertises, "BOTTOMLEFT", 0, -42)
    c.tableauOutils:SetPoint("TOPRIGHT", c.tableauExpertises, "BOTTOMRIGHT", 0, -42)
    c.erreur = UI.Texte(c, "", UI.C.plein, "GameFontNormalSmall")
    c.erreur:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 6)
    c.erreur:SetPoint("RIGHT", c, "RIGHT", -150, 0)
    c.erreur:SetJustifyH("LEFT")
    c.enregistrer = UI.Bouton(c, "Enregistrer", 140, 26, function() f:Enregistrer() end)
    c.enregistrer:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)

    f.nom, f.places, f.verrous, f.rayon, f.reset, f.enregistrer =
        c.nom, c.places, c.verrous, c.rayon, c.reset, c.enregistrer
    f.zoneObjets, f.zoneExpertises, f.zoneOutils = c.zoneObjets, c.zoneExpertises, c.zoneOutils

    local p = CreateFrame("Frame", nil, f.droite)
    p:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -34)
    p:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.placement = p
    p.titre = UI.Texte(p, "", UI.C.titre)
    UI.Police(p.titre, 14)
    p.titre:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -2)
    -- La liste est PERSONNELLE ; ce que les autres ont pose se demande ici.
    p.filtre = LCM.Poses.Selecteur(p, f, function()
        return LCM.Poses.Poseurs("coffre", Coffres.Points())
    end, function()
        f.pointPose = nil
        f:AfficherPlacements()
    end)
    p.filtre:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
    p.titre:SetPoint("RIGHT", p.filtre, "LEFT", -8, 0)
    p.resume = UI.Texte(p, "", UI.C.discret, "GameFontNormalSmall")
    p.resume:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -22)
    p.resume:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    p.resume:SetJustifyH("LEFT")
    p.position = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
    p.position:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -44)
    p.position:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    p.position:SetJustifyH("LEFT")
    p.poser = UI.Bouton(p, "Placer un coffre", 220, 34, function() f:Poser() end)
    p.poser:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -66)
    p.compte = UI.Texte(p, "", UI.C.accent, "GameFontNormalSmall")
    p.compte:SetPoint("LEFT", p.poser, "RIGHT", 12, 0)
    p.toutRetirer = UI.Bouton(p, "Tout retirer", 110, 22, function() f:ToutRetirer() end)
    p.toutRetirer:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -72)
    p.retirer = UI.Bouton(p, "Retirer la sélection", 150, 22, function()
        if f.pointPose then Coffres.Retirer(f.pointPose); f.pointPose = nil; f:Afficher() end
    end)
    p.retirer:SetPoint("RIGHT", p.toutRetirer, "LEFT", -8, 0)
    -- Forcer l'envoi : tout ce que j'ai pose repart a tous ceux qui ont
    -- l'addon (canal de Core/Presence.lua). De quoi rattraper un joueur qui
    -- arrive sans rien, sans rien deplacer ni reenregistrer (20 octobre 2026).
    p.renvoyer = UI.Bouton(p, "Renvoyer à tous", 130, 22, function()
        local n = tonumber(Coffres.Renvoyer()) or 0
        if n == 0 then
            LCM.Alerte("rien à renvoyer : aucun emplacement posé, ou personne à qui l'envoyer.")
            return
        end
        LCM.Ok(string.format("coffre(s) renvoyé(s) à tous : %d.", tonumber(n) or 0))
    end)
    p.renvoyer:SetPoint("RIGHT", p.retirer, "LEFT", -8, 0)
    f.poser, f.retirer = p.poser, p.retirer
    p.zone = UI.Defilement(p)
    p.zone:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -110)
    p.zone:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -10, 0)
    p.vide = UI.Texte(p,
        "Aucun coffre placé. Marche jusqu’à l’endroit voulu et clique sur « Placer un coffre ».",
        UI.C.discret, "GameFontNormalSmall")
    p.vide:SetPoint("TOP", p.zone, "TOP", 0, -20)
    p.vide:SetWidth(380)
    p.vide:SetJustifyH("CENTER")
    p.vide:SetWordWrap(true)
    p.attente = 0
    p:SetScript("OnUpdate", function(self, dt)
        self.attente = self.attente + (dt or 0)
        if self.attente < 0.5 then return end
        self.attente = 0
        f:Position()
    end)

    function f:Point()
        return self.pointId and Points.Get(self.pointId) or nil
    end

    function f:Onglet(onglet)
        self.onglet = onglet
        self.boutonCreation:Selectionner(onglet == "creation")
        self.boutonPlacement:Selectionner(onglet == "placement")
        self.creation:SetShown(onglet == "creation")
        self.placement:SetShown(onglet == "placement")
        self:Afficher()
    end

    function f:Choisir(id)
        self.pointId = id
        local point = self:Point()
        self.creationNeuve = point == nil
        self.travail = Travail(point)
        self.pointPose = nil
        c.erreur:SetText("")
        self:Remplir()
        self:Afficher()
    end

    function f:Nouveau()
        self:Choisir(nil)
        self:Onglet("creation")
        c.pages:Choisir(1)
    end

    -- La copie s'ouvre comme une creation neuve, pas encore enregistree : elle
    -- ne part dans la base qu'une fois renommee et validee par « Enregistrer ».
    function f:Dupliquer()
        local point = self:Point()
        if not point then LCM.Alerte("choisis d'abord le coffre à dupliquer.") return end
        self.pointId = nil
        self.creationNeuve = true
        self.travail = Travail(Points.Dupliquer(point))
        self.pointPose = nil
        c.erreur:SetText("")
        self:Remplir()
        self:Onglet("creation")
    end

    local function AccepterObjet(objet)
        if not objet then return false, "choisis une entrée du compendium." end
        local accueilli, pourquoi = LCM.Coffres.Accepte(objet.ref)
        if accueilli then return true end
        return false, pourquoi or "choisis une entrée que le coffre accueille."
    end
    local function AccepterOutil(objet)
        if objet and tostring(objet.ref or ""):match("^objets/") then return true end
        return false, "choisis un outil du compendium."
    end

    function f:Ajouter(typeListe, ref)
        local typeOutil = typeListe == "outils" and tostring(ref or ""):match("^type_outil/(.+)$")
        -- Les outils d'une tentative sont des objets ; le CONTENU accepte
        -- tout ce qu'un coffre accueille (le MJ, 19 octobre 2026).
        local contenu = typeListe == "objets" and LCM.Coffres.Accepte(ref) == true
        if not self.travail or not (contenu or typeOutil
            or tostring(ref or ""):match("^objets/")) then return end
        local liste = self.travail.coffre[typeListe]
        if type(liste) ~= "table" then return end
        if typeListe ~= "outils" then
            for _, objet in ipairs(liste) do
                if objet.entree == ref then
                    objet.quantite = (tonumber(objet.quantite) or 1) + 1
                    self:AfficherDetails()
                    return
                end
            end
        end
        liste[#liste + 1] = { entree = not typeOutil and ref or nil, typeOutil = typeOutil, quantite = 1,
            consomme = false, consommeQuantite = 1,
            expertise = typeListe == "outils" and self.travail.coffre.expertises[1]
                and self.travail.coffre.expertises[1].id or nil }
        self:AfficherDetails()
    end

    function f:AjouterExpertise(id)
        local options = OptionsExpertises(self.travail.coffre.expertises)
        id = id or (options[1] and options[1].id)
        if not id then return end
        self.travail.coffre.expertises[#self.travail.coffre.expertises + 1] = {
            id = id, dd = 10, fatigue = 0, usureOutils = false, reverrouillable = true,
        }
        for _, outil in ipairs(self.travail.coffre.outils) do
            if not outil.expertise or outil.expertise == "" then outil.expertise = id end
        end
        self:AfficherDetails()
    end

    function f:AfficherObjets(typeListe, zone, cache, choixPopup, outils)
        local liste = self.travail and self.travail.coffre[typeListe] or {}
        local pas = 28
        for index, objet in ipairs(liste) do
            local ligne = cache[index]
            if not ligne then
                ligne = CreateFrame("Frame", nil, zone.contenu)
                ligne:SetHeight(pas)
                FondLigne(ligne)
                ligne.nom = BoutonTexte(ligne, outils and 123 or 298)
                ligne.nom:SetPoint("TOPLEFT", ligne, "TOPLEFT", 37, -2)
                ligne.icone = ligne:CreateTexture(nil, "ARTWORK")
                ligne.icone:SetSize(18, 18)
                ligne.icone:SetPoint("TOPLEFT", ligne, "TOPLEFT", 7, -5)
                ligne.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                ligne.nom:SetScript("OnClick", function()
                    choixPopup:Proposer(ligne.nom,
                        OptionsObjets(f.travail.coffre[typeListe], ligne.index, outils), function(ref)
                            local courant = f.travail.coffre[typeListe][ligne.index]
                            if courant then
                                courant.typeOutil = outils and tostring(ref):match("^type_outil/(.+)$") or nil
                                courant.entree = not courant.typeOutil and ref or nil
                                f:AfficherDetails()
                            end
                        end)
                end)
                UI.Glisser.Cible(ligne.nom, outils and AccepterOutil or AccepterObjet, function(donnees)
                    local courant = f.travail.coffre[typeListe][ligne.index]
                    if courant then courant.entree = donnees.ref; courant.typeOutil = nil; f:AfficherDetails() end
                end)
                ligne.quantite = UI.Champ(ligne, 48, 20, function(texte)
                    local courant = f.travail.coffre[typeListe][ligne.index]
                    if courant then courant.quantite = texte end
                end)
                if outils then
                    ligne.expertise = BoutonTexte(ligne, 106)
                    ligne.expertise:SetPoint("TOPLEFT", ligne, "TOPLEFT", 170, -2)
                    ligne.expertise:SetScript("OnClick", function()
                        f.choixExpertiseOutil:Proposer(ligne.expertise,
                            OptionsExpertisesOutils(f.travail.coffre.expertises), function(id)
                                local courant = f.travail.coffre.outils[ligne.index]
                                if courant then courant.expertise = id; f:AfficherOutils() end
                            end)
                    end)
                    ligne.quantite:SetWidth(42)
                    ligne.quantite:SetPoint("TOPLEFT", ligne, "TOPLEFT", 289, -4)
                    ligne.consommer = UI.Case(ligne, "Oui", function(coche)
                        local courant = f.travail.coffre.outils[ligne.index]
                        if courant then courant.consomme = coche; f:AfficherOutils() end
                    end)
                    ligne.consommer:SetPoint("TOPLEFT", ligne, "TOPLEFT", 347, -6)
                    ligne.nc = UI.Champ(ligne, 42, 20, function(texte)
                        local courant = f.travail.coffre.outils[ligne.index]
                        if courant then courant.consommeQuantite = texte end
                    end)
                    ligne.nc:SetPoint("TOPLEFT", ligne, "TOPLEFT", 420, -4)
                else
                    ligne.quantite:SetPoint("TOPLEFT", ligne, "TOPLEFT", 372, -4)
                end
                ligne.retirer = CreateFrame("Button", nil, ligne)
                ligne.retirer:SetSize(24, 22)
                ligne.retirer:SetPoint("RIGHT", ligne, "RIGHT", -4, 0)
                ligne.retirer.label = UI.Texte(ligne.retirer, "×", UI.C.discret, "GameFontNormalSmall")
                ligne.retirer.label:SetAllPoints(ligne.retirer)
                ligne.retirer.label:SetJustifyH("CENTER")
                ligne.retirer:SetScript("OnClick", function()
                    table.remove(f.travail.coffre[typeListe], ligne.index)
                    f:AfficherDetails()
                end)
                cache[index] = ligne
            end
            ligne.index = index
            ligne.item = objet
            local entree = objet.typeOutil and LCM.Listes.Get(objet.typeOutil)
                or LCM.Compendium.Resoudre(objet.entree)
            ligne.nom.label:SetText(objet.typeOutil and ("Type : " .. tostring(entree and entree.label or objet.typeOutil))
                or ((entree and entree.label) or objet.entree or "Objet inconnu"))
            ligne.icone:SetTexture((entree and entree.icone) or "Interface\\ICONS\\INV_Misc_QuestionMark")
            ligne.quantite:SetText(tostring(objet.quantite or 1))
            if outils then
                local champ = LCM.Schema.Field(objet.expertise)
                ligne.expertise.label:SetText((champ and champ.label) or objet.expertise or "Choisir…")
                ligne.consommer:Cocher(objet.consomme == true)
                ligne.nc:SetText(tostring(objet.consommeQuantite or 1))
                ligne.nc:SetShown(objet.consomme == true)
            end
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", zone.contenu, "TOPLEFT", 0, -(index - 1) * pas)
            ligne:SetPoint("TOPRIGHT", zone.contenu, "TOPRIGHT", 0, -(index - 1) * pas)
            ligne:Show()
        end
        for index = #liste + 1, #cache do cache[index]:Hide() end
        local cle = outils and "ajouterOutil" or "ajouterObjet"
        if not c[cle] then
            local ajouter = CreateFrame("Button", nil, zone.contenu)
            ajouter:SetHeight(pas)
            FondLigne(ajouter)
            ajouter.label = UI.Texte(ajouter,
                outils and "+ Ajouter un outil" or "+ Ajouter un objet",
                UI.C.discret, "GameFontNormalSmall")
            ajouter.label:SetAllPoints(ajouter)
            ajouter.label:SetJustifyH("CENTER")
            local survol = UI.Aplat(ajouter, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
            survol:SetAllPoints(ajouter)
            ajouter:SetScript("OnClick", function()
                choixPopup:Proposer(ajouter, OptionsObjets(f.travail.coffre[typeListe], nil, outils), function(ref)
                    f:Ajouter(typeListe, ref)
                end)
            end)
            UI.Glisser.Cible(ajouter, outils and AccepterOutil or AccepterObjet,
                function(objet) f:Ajouter(typeListe, objet.ref) end)
            c[cle] = ajouter
            if outils then f.depotOutils = ajouter else f.depotObjets = ajouter end
        end
        c[cle]:ClearAllPoints()
        c[cle]:SetPoint("TOPLEFT", zone.contenu, "TOPLEFT", 0, -#liste * pas)
        c[cle]:SetPoint("TOPRIGHT", zone.contenu, "TOPRIGHT", 0, -#liste * pas)
        AjusterTableau(outils and c.tableauOutils or c.tableauObjets, zone, (#liste + 1) * pas)
    end

    function f:AfficherContenu()
        self:AfficherObjets("objets", c.zoneObjets, self.lignesObjets, self.choixObjet, false)
    end

    function f:AfficherOutils()
        self:AfficherObjets("outils", c.zoneOutils, self.lignesOutils, self.choixOutil, true)
    end

    function f:AfficherExpertises()
        local liste = self.travail and self.travail.coffre.expertises or {}
        local pas = 28
        for index, methode in ipairs(liste) do
            local ligne = self.lignesExpertises[index]
            if not ligne then
                ligne = CreateFrame("Frame", nil, c.zoneExpertises.contenu)
                ligne:SetHeight(pas)
                FondLigne(ligne)
                ligne.nom = BoutonTexte(ligne, 134)
                ligne.nom:SetPoint("TOPLEFT", ligne, "TOPLEFT", 8, -2)
                ligne.nom:SetScript("OnClick", function()
                    f.choixExpertise:Proposer(ligne.nom,
                        OptionsExpertises(f.travail.coffre.expertises, ligne.index), function(id)
                            local courant = f.travail.coffre.expertises[ligne.index]
                            if courant then
                                local ancien = courant.id
                                courant.id = id
                                for _, outil in ipairs(f.travail.coffre.outils) do
                                    if outil.expertise == ancien then outil.expertise = id end
                                end
                                f:AfficherDetails()
                            end
                        end)
                end)
                ligne.dd = UI.Champ(ligne, 36, 20, function(texte)
                    local courant = f.travail.coffre.expertises[ligne.index]
                    if courant then courant.dd = texte end
                end)
                ligne.dd:SetPoint("TOPLEFT", ligne, "TOPLEFT", 156, -4)
                ligne.fatigue = UI.Champ(ligne, 42, 20, function(texte)
                    local courant = f.travail.coffre.expertises[ligne.index]
                    if courant then courant.fatigue = texte end
                end)
                ligne.fatigue:SetPoint("TOPLEFT", ligne, "TOPLEFT", 208, -4)
                ligne.usureOutils = UI.Case(ligne, "Oui", function(coche)
                    local courant = f.travail.coffre.expertises[ligne.index]
                    if courant then courant.usureOutils = coche end
                end)
                ligne.usureOutils:SetPoint("TOPLEFT", ligne, "TOPLEFT", 277, -6)
                ligne.relock = UI.Case(ligne, "Oui", function(coche)
                    local courant = f.travail.coffre.expertises[ligne.index]
                    if courant then courant.reverrouillable = coche end
                end)
                ligne.relock:SetPoint("TOPLEFT", ligne, "TOPLEFT", 375, -6)
                ligne.retirer = CreateFrame("Button", nil, ligne)
                ligne.retirer:SetSize(24, 22)
                ligne.retirer:SetPoint("RIGHT", ligne, "RIGHT", -4, 0)
                ligne.retirer.label = UI.Texte(ligne.retirer, "×", UI.C.discret, "GameFontNormalSmall")
                ligne.retirer.label:SetAllPoints(ligne.retirer)
                ligne.retirer.label:SetJustifyH("CENTER")
                ligne.retirer:SetScript("OnClick", function()
                    local retiree = table.remove(f.travail.coffre.expertises, ligne.index)
                    local remplacement = f.travail.coffre.expertises[1]
                        and f.travail.coffre.expertises[1].id or nil
                    for _, outil in ipairs(f.travail.coffre.outils) do
                        if retiree and outil.expertise == retiree.id then outil.expertise = remplacement end
                    end
                    f:AfficherDetails()
                end)
                self.lignesExpertises[index] = ligne
            end
            ligne.index = index
            local avecClef = methode.id == LCM.Coffres.METHODE_CLEF
            ligne.nom.label:SetText(NomMethode(methode.id))
            ligne.dd:SetShown(not avecClef)
            ligne.fatigue:SetShown(not avecClef)
            if not avecClef then
                ligne.dd:SetText(tostring(methode.dd or 0))
                ligne.fatigue:SetText(tostring(methode.fatigue or 0))
            end
            ligne.usureOutils:Cocher(methode.usureOutils == true)
            ligne.relock:Cocher(methode.reverrouillable == true)
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", c.zoneExpertises.contenu, "TOPLEFT", 0, -(index - 1) * pas)
            ligne:SetPoint("TOPRIGHT", c.zoneExpertises.contenu, "TOPRIGHT", 0, -(index - 1) * pas)
            ligne:Show()
        end
        for index = #liste + 1, #self.lignesExpertises do self.lignesExpertises[index]:Hide() end
        if not c.ajouterExpertise then
            c.ajouterExpertise = CreateFrame("Button", nil, c.zoneExpertises.contenu)
            c.ajouterExpertise:SetHeight(pas)
            FondLigne(c.ajouterExpertise)
            c.ajouterExpertise.label = UI.Texte(c.ajouterExpertise,
                "+ Ajouter une méthode", UI.C.discret, "GameFontNormalSmall")
            c.ajouterExpertise.label:SetAllPoints(c.ajouterExpertise)
            c.ajouterExpertise.label:SetJustifyH("CENTER")
            local survol = UI.Aplat(c.ajouterExpertise, { 0.85, 0.75, 0.40, 0.08 }, "HIGHLIGHT")
            survol:SetAllPoints(c.ajouterExpertise)
            c.ajouterExpertise:SetScript("OnClick", function()
                f.choixExpertise:Proposer(c.ajouterExpertise,
                    OptionsExpertises(f.travail.coffre.expertises), function(id)
                        f:AjouterExpertise(id)
                    end)
            end)
            f.ajouterExpertise = c.ajouterExpertise
        end
        c.ajouterExpertise:ClearAllPoints()
        c.ajouterExpertise:SetPoint("TOPLEFT", c.zoneExpertises.contenu, "TOPLEFT", 0, -#liste * pas)
        c.ajouterExpertise:SetPoint("TOPRIGHT", c.zoneExpertises.contenu, "TOPRIGHT", 0, -#liste * pas)
        AjusterTableau(c.tableauExpertises, c.zoneExpertises, (#liste + 1) * pas)
    end

    function f:AfficherDetails()
        self:AfficherContenu()
        self:AfficherExpertises()
        self:AfficherOutils()
    end

    function f:Remplir()
        if not self.travail then return end
        local coffre = self.travail.coffre
        c.nom:SetText(self.travail.label or "")
        c.places:SetText(tostring(coffre.places or 10))
        c.verrous:SetText(tostring(coffre.verrous or 0))
        c.rayon:SetText(tostring(coffre.rayon or Eq().rayon or 4))
        c.reset:Cocher(coffre.reset == true)
        self:AfficherDetails()
    end

    function f:Valider()
        local t, coffre = self.travail, self.travail and self.travail.coffre
        if not t or not tostring(t.label or ""):match("%S") then return nil, "donne un nom au coffre." end
        local places = Entier(coffre.places)
        if not places or places < 1 then return nil, "le nombre d’emplacements doit être un entier supérieur à zéro." end
        local verrous = Entier(coffre.verrous)
        if not verrous or verrous < 0 then return nil, "le nombre de verrous doit être un entier positif ou nul." end
        local rayon, rayonMax = tonumber(coffre.rayon), tonumber(Eq().rayonMax) or 30
        if not rayon or rayon <= 0 or rayon > rayonMax then
            return nil, string.format("le rayon doit être entre 0 et %d yards.", rayonMax)
        end
        local objets = {}
        for _, objet in ipairs(coffre.objets or {}) do
            local q = Entier(objet.quantite)
            if not LCM.Compendium.Resoudre(objet.entree) then return nil, "choisis un objet valide pour le contenu." end
            if not q or q < 1 then return nil, "les quantités du contenu doivent être des entiers supérieurs à zéro." end
            objets[#objets + 1] = { entree = objet.entree, quantite = q }
        end
        if Cases(objets) > places then return nil, "le contenu dépasse le nombre d’emplacements du coffre." end
        local expertises = {}
        local expertisesParId = {}
        local clefPresente = false
        for _, methode in ipairs(coffre.expertises or {}) do
            local champ, dd = LCM.Schema.Field(methode.id), Entier(methode.dd)
            local fatigue = Entier(methode.fatigue or 0)
            local avecClef = methode.id == LCM.Coffres.METHODE_CLEF
            if not avecClef and (not champ or not champ.jetExpertise) then
                return nil, "choisis une expertise valide."
            end
            if not avecClef and (not dd or dd < 0) then
                return nil, "le DD doit être un entier positif ou nul."
            end
            if not avecClef and (not fatigue or fatigue < 0) then
                return nil, "le coût en fatigue doit être un entier positif ou nul."
            end
            expertises[#expertises + 1] = { id = methode.id, dd = avecClef and 0 or dd,
                fatigue = avecClef and 0 or fatigue,
                usureOutils = methode.usureOutils == true,
                reverrouillable = methode.reverrouillable == true }
            expertisesParId[methode.id] = true
            if avecClef then clefPresente = true end
        end
        local outils = {}
        local outilPourClef = false
        for _, outil in ipairs(coffre.outils or {}) do
            local q, consomme = Entier(outil.quantite), Entier(outil.consommeQuantite)
            local typeOutil = outil.typeOutil and LCM.Listes.Get(outil.typeOutil)
            if outil.typeOutil then
                if not typeOutil or typeOutil.liste ~= "outils" then
                    return nil, "choisis un type d’outil valide."
                end
            elseif not LCM.Compendium.Resoudre(outil.entree) then
                return nil, "choisis un outil valide."
            end
            if not q or q < 1 then return nil, "les quantités requises doivent être des entiers supérieurs à zéro." end
            if not expertisesParId[outil.expertise] then
                return nil, "associe chaque outil à une expertise autorisée."
            end
            if outil.consomme and (not consomme or consomme < 1 or consomme > q) then
                return nil, "la quantité consommée doit être comprise entre 1 et la quantité requise."
            end
            outils[#outils + 1] = { entree = not outil.typeOutil and outil.entree or nil,
                typeOutil = outil.typeOutil, quantite = q,
                consomme = outil.consomme == true, consommeQuantite = consomme or 1,
                expertise = outil.expertise }
            if outil.expertise == LCM.Coffres.METHODE_CLEF then outilPourClef = true end
        end
        if clefPresente and not outilPourClef then
            return nil, "la méthode Clef doit avoir au moins un objet requis associé."
        end
        if verrous > 0 and #expertises == 0 and #outils == 0 then
            return nil, "ajoute au moins une expertise ou un outil pour ouvrir ce coffre verrouillé."
        end
        return { places = places, rayon = rayon, verrous = verrous, reset = coffre.reset == true,
            objets = objets, expertises = expertises, outils = outils }
    end

    function f:Enregistrer()
        local coffre, raison = self:Valider()
        if not coffre then c.erreur:SetText(raison); LCM.Alerte(raison); return false end
        c.erreur:SetText("")
        self.travail.coffre = coffre
        local ok, erreur = LCM.Brouillons.Enregistrer("points", self.travail,
            self.creationNeuve)
        if not ok then LCM.Alerte(tostring(erreur)); return false end
        if Coffres.Renvoyer then Coffres.Renvoyer() end
        LCM.Ok(string.format("Coffre « %s » enregistré.", self.travail.label))
        self:Choisir(self.travail.id)
        return true
    end

    function f:Supprimer()
        local point = self:Point()
        if not point then return end
        local poses = Coffres.Points(point.id)
        local texte = #poses > 0
            and string.format("Supprimer « %s » et ses %d coffre(s) placé(s) ?", point.label, #poses)
            or string.format("Supprimer « %s » ?", point.label)
        self.confirmation:Demander(texte, function()
            local ok, raison = LCM.Brouillons.Supprimer("points", point.id)
            if not ok then LCM.Alerte(tostring(raison or "suppression impossible")); return end
            for _, pose in ipairs(poses) do Coffres.Retirer(pose.id) end
            local premier = Points.Nature("coffre")[1]
            self:Choisir(premier and premier.id)
        end)
    end

    function f:Position()
        local D = LCM.DeplacementForce
        local x, y, z, source = D.Position("gps")
        local mapid = D.CarteGPS()
        if x and z and mapid then
            local carte = LCM.Recolte.Carte()
            p.position:SetText(string.format("Tu es en %.1f, %.1f, %.1f  (serveur, carte %d%s)", x, y, z, mapid,
                carte and (" ; interface " .. carte) or ""))
        else
            p.position:SetText("Position serveur inconnue : le clic demandera « .gps ».")
        end
        return x, y, source, z
    end

    function f:Poser()
        if (self.creationNeuve or self:Modifie()) and not self:Enregistrer() then return end
        local point = self:Point()
        if not point then LCM.Alerte("choisis d’abord un coffre."); return end
        local id, raison = Coffres.Placer(point.id)
        if not id then LCM.Alerte(tostring(raison)); return end
        self.pointPose = id
        self:Afficher()
    end

    function f:ToutRetirer()
        local point = self:Point()
        if not point then return end
        local poses = Coffres.Points(point.id)
        if #poses == 0 then return end
        self.confirmation:Demander(string.format("Retirer les %d coffre(s) placé(s) de « %s » ?", #poses, point.label),
            function()
                for _, pose in ipairs(poses) do Coffres.Retirer(pose.id) end
                self.pointPose = nil
                self:Afficher()
            end)
    end

    function f:AfficherPlacements()
        local point = self:Point()
        local miens = point and Coffres.Points(point.id) or {}
        local poses = point and LCM.Poses.Composer("coffre", point.id, miens, self.filtrePoses,
            Coffres.CopiesDeGarde(point.id)) or {}
        p.filtre:Actualiser()
        local x, y, source, z = self:Position()
        local carte = LCM.Recolte.Carte()
        for index, pose in ipairs(poses) do
            local ligne = self.placements[index]
            if not ligne then
                ligne = UI.Bouton(p.zone.contenu, "", 490, LIGNE - 2, function(bouton)
                    -- Celui d'un autre se consulte, il ne se selectionne pas
                    -- pour etre retire.
                    if bouton.pose and bouton.pose.autre then return end
                    self.pointPose = bouton.pointPose
                    self:AfficherPlacements()
                end)
                ligne.label:ClearAllPoints()
                ligne.label:SetPoint("LEFT", ligne, "LEFT", 8, 0)
                ligne.label:SetPoint("RIGHT", ligne, "RIGHT", -156, 0)
                ligne.label:SetJustifyH("LEFT")
                ligne.teleporter = UI.Bouton(ligne, "S'y téléporter", 112, 20, function(bouton)
                    local pose = bouton:GetParent().pose
                    local ok, raison
                    if pose and pose.autre then ok, raison = LCM.Poses.Teleporter(pose)
                    else ok, raison = Coffres.Teleporter(bouton:GetParent().pointPose) end
                    if not ok then LCM.Alerte(tostring(raison)) end
                    if ok then self:AfficherPlacements() end
                end)
                ligne.teleporter:SetPoint("RIGHT", ligne, "RIGHT", -34, 0)
                ligne.retirer = UI.Bouton(ligne, "×", 24, 20, function(bouton)
                    Coffres.Retirer(bouton:GetParent().pointPose)
                    if self.pointPose == bouton:GetParent().pointPose then self.pointPose = nil end
                    self:Afficher()
                end)
                ligne.retirer:SetPoint("RIGHT", ligne, "RIGHT", -4, 0)
                self.placements[index] = ligne
            end
            ligne.pointPose, ligne.pose = pose.id, pose
            ligne.retirer:SetShown(not pose.autre)
            local distance = ""
            if x and pose.source == source and pose.carte == carte then
                local d = LCM.Recolte.Distance(pose, { x = x, y = y, z = z })
                distance = d and string.format(" — à %.0f yards", d) or " — altitude inconnue : replacer"
            elseif pose.carte ~= carte then distance = " — autre carte" end
            ligne.label:SetText(LCM.Poses.Prefixe(pose) .. string.format("#%d   %.1f, %.1f, %s (%s%s)%s", #poses - index + 1,
                tonumber(pose.x) or 0, tonumber(pose.y) or 0, pose.z and string.format("%.1f", pose.z) or "Z ?", tostring(pose.source),
                pose.mapid and (", carte serveur " .. pose.mapid)
                    or (pose.carte and ", carte serveur ?" or ""), distance))
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", p.zone.contenu, "TOPLEFT", 0, -(index - 1) * LIGNE)
            ligne:SetPoint("TOPRIGHT", p.zone.contenu, "TOPRIGHT", 0, -(index - 1) * LIGNE)
            ligne:Selectionner(self.pointPose == pose.id)
            ligne:Show()
        end
        for index = #poses + 1, #self.placements do self.placements[index]:Hide() end
        p.zone:Regler(#poses * LIGNE)
        p.vide:SetShown(point ~= nil and #poses == 0)
        p.compte:SetText(point and string.format("%d coffre(s) placé(s)", #poses) or "")
        -- « Tout retirer » ne vise que les miens.
        p.toutRetirer:SetEnabled(#miens > 0)
        p.retirer:SetShown(self.pointPose ~= nil)
    end

    function f:Afficher()
        local definitions = self:FiltrerDefinitions(Points.Nature("coffre"))
        for index, point in ipairs(definitions) do
            local bouton = self.lignes[index]
            if not bouton then
                bouton = UI.Bouton(self.liste.contenu, "", COLONNE - 10, LIGNE - 2, function(b)
                    self:ChangerModele(function() self:Choisir(b.pointId) end)
                end)
                bouton.label:ClearAllPoints()
                bouton.label:SetPoint("LEFT", bouton, "LEFT", 6, 0)
                bouton.label:SetPoint("RIGHT", bouton, "RIGHT", -6, 0)
                bouton.label:SetJustifyH("LEFT")
                self.lignes[index] = bouton
            end
            bouton.pointId = point.id
            local n = #Coffres.Points(point.id)
            bouton.label:SetText(n > 0 and string.format("%s  |cff9d9d9d(%d)|r", point.label, n) or point.label)
            bouton:ClearAllPoints()
            bouton:SetPoint("TOPLEFT", self.liste.contenu, "TOPLEFT", 0, -(index - 1) * LIGNE)
            bouton:Selectionner(point.id == self.pointId)
            bouton:Show()
        end
        for index = #definitions + 1, #self.lignes do self.lignes[index]:Hide() end
        self.liste:Regler(#definitions * LIGNE)
        self.supprimer:SetEnabled(self:Point() ~= nil)
        local point = self:Point()
        p.titre:SetText(point and point.label or "Choisis un coffre à gauche")
        p.resume:SetText(point and Resume(point) or "")
        p.poser:SetEnabled(point ~= nil and point.coffre ~= nil)
        self:AfficherPlacements()
    end

    function f:Montrer()
        local premier = Points.Nature("coffre")[1]
        if not self.travail then self:Choisir(premier and premier.id) end
        self:Onglet(self.onglet or "creation")
        self:Show()
        self:Raise()
    end

    UI.AtelierInteractions(f, "coffre")
    f:Hide()
    return f
end

function Ecran.Fenetre()
    if not LCM.IsMaster() then
        LCM.Alerte("cet outil est réservé au maître du jeu.")
        return nil
    end
    Ecran.frame = Ecran.frame or Construire()
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if not f then return nil end
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.AddCommand("coffres", "ouvre le constructeur et le placement des coffres", function() Ecran.Basculer() end, true)
LCM.AddCommand("coffre", "ouvre le constructeur et le placement des coffres", function() Ecran.Basculer() end, true)

LCM.WhenReady(function()
    if UI.Menu then UI.Menu.Lier("coffres", Ecran.Basculer) end
    local precedent = LCM.Brouillons.onSynchro
    LCM.Brouillons.onSynchro = function(famille, entree)
        if precedent then precedent(famille, entree) end
        if famille ~= "points" then return end
        local f = Ecran.frame
        if f and f:IsShown() then f:Afficher() end
    end
end)
