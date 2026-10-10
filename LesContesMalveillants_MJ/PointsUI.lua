-- Vendeurs et points de recolte.
--
-- Deux entrees de menu, une seule fenetre : « Vendeur » et « Ressources » ne
-- different que par ce qu'on y lit et par le prix. Une liste des points connus
-- a gauche, les offres du point choisi a droite.
--
-- Le stock affiche est celui qu'on connait, et on le DEMANDE en ouvrant : ce
-- qui a ete ramasse pendant qu'on n'etait pas la ne se devine pas.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Points = LCM.Points

local Ecran = { frames = {} }
UI.Points = Ecran

local LARGEUR, HAUTEUR = 560, 420
local COLONNE = 200
local LIGNE = 28

local MOTS = {
    vendeur   = { titre = "Vendeur",    action = "Acheter",  vide = "Aucun vendeur connu." },
    ressource = { titre = "Ressources", action = "Récolter", vide = "Aucun point de récolte connu." },
}

local function Autorise()
    if LCM.IsMaster() then return true end
    LCM.Alerte("cet outil est reserve au maitre du jeu.")
    return false
end

local function CopiePoint(point, nature)
    if point then
        local copie = LCM.Copie(point)
        copie.brouillon, copie.remplacePublie = nil, nil
        for _, offre in ipairs(copie.offres or {}) do offre.cle, offre.restant = nil, nil end
        return copie
    end
    return {
        id = LCM.Brouillons.NouvelIdentifiant(), nature = nature,
        label = "", description = "", offres = {},
    }
end

local function OptionsEntrees()
    local options = {}
    local noms = {
        objets = "Objets", ressources = "Ressources", sacs = "Sacs",
        devises = "Devises", connaissances = "Connaissances",
        informations = "Informations", listes = "Listes", calculateurs = "Calculateurs",
        traits = "Traits", races = "Races", etats = "États",
        apprentissages = "Apprentissages", resolutions = "Résolutions", pnj = "PNJ",
        tentes = "Tentes", accessoires_camping = "Accessoires de camping",
    }
    for famille, registreNom in pairs((LCM.Compendium and LCM.Compendium.FAMILLES) or {}) do
        local registre = LCM[registreNom]
        for _, entree in ipairs((registre and registre.list) or {}) do
            options[#options + 1] = {
                id = famille .. "/" .. entree.id,
                label = entree.label or entree.id, groupe = noms[famille] or famille,
                famille = famille,
            }
        end
    end
    table.sort(options, function(a, b)
        if a.groupe == b.groupe then return tostring(a.label) < tostring(b.label) end
        return tostring(a.groupe) < tostring(b.groupe)
    end)
    return options
end

local function OptionsCategories()
    local vus, options = {}, { { id = "", label = "Toutes les catégories" } }
    for _, entree in ipairs(OptionsEntrees()) do
        if not vus[entree.famille] then
            vus[entree.famille] = true
            options[#options + 1] = { id = entree.famille, label = entree.groupe }
        end
    end
    table.sort(options, function(a, b)
        if a.id == "" then return true end
        if b.id == "" then return false end
        return tostring(a.label) < tostring(b.label)
    end)
    return options
end

local function OptionsDevises()
    local options = {}
    for _, devise in ipairs((LCM.Devises and LCM.Devises.list) or {}) do
        options[#options + 1] = { id = devise.id, label = devise.label or devise.id }
    end
    table.sort(options, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return options
end

local function Libelle(parent, texte, x, y)
    local t = UI.Texte(parent, texte, UI.C.discret, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return t
end

-- ===== Publication Arcanum ================================================
-- L'identifiant du point LCM et l'ArcID n'ont pas le meme role. Le premier
-- relie le contenu de campagne ; le second est la cle du sort dans les coffres
-- Arcanum personnel et de phase.

local ACTION_VENDEUR = "lcm_vendeur_open"
local ICONE_VENDEUR = "Interface\\Icons\\INV_Misc_Coin_02"
local publicationEnCours = false

local function NettoyerArcId(valeur)
    local arcId = tostring(valeur or ""):match("^%s*(.-)%s*$") or ""
    if arcId == "" then return nil, "donne un identifiant Arcanum unique." end
    if #arcId > 40 then return nil, "l'identifiant Arcanum est limité à 40 caractères." end
    if arcId:find("[^%w_]") then
        return nil, "l'identifiant Arcanum accepte uniquement lettres, chiffres et _."
    end
    return arcId
end

local function ArcIdParDefaut(id)
    local suffixe = tostring(id or ""):gsub("[^%w_]", "_")
    suffixe = suffixe:sub(math.max(1, #suffixe - 30))
    return "vendeur_" .. suffixe
end

local function ProfilArcanum()
    local profil = type(SpellCreatorMasterTable) == "table"
        and type(SpellCreatorMasterTable.Options) == "table"
        and SpellCreatorMasterTable.Options.defaultProfile or nil
    return profil == "Account" and "Account" or (UnitName and UnitName("player") or "Account")
end

local function IconeArcanum(chemin)
    chemin = tostring(chemin or ICONE_VENDEUR)
    if tonumber(chemin) then return tonumber(chemin) end
    chemin = chemin:gsub("/", "\\")
    if GetFileIDFromPath then
        local id = GetFileIDFromPath(chemin)
        if tonumber(id) then return tonumber(id) end
    end
    return chemin
end

local function SortVendeur(point)
    local arcId, raison = NettoyerArcId(point and point.arcId)
    if not arcId then return nil, raison end
    return {
        profile = ProfilArcanum(),
        commID = arcId,
        fullName = tostring(point.label or "Vendeur"),
        description = "Ouvre un vendeur des Contes Malveillants.",
        icon = IconeArcanum(point.icone),
        author = UnitName and UnitName("player") or "Les Contes Malveillants",
        actions = {
            { actionType = ACTION_VENDEUR, delay = 0, vars = tostring(point.id), selfOnly = true },
        },
    }
end

local function PublierVendeurArcanum(point, callback)
    local fini = false
    local function Terminer(ok, message)
        if fini then return end
        fini = true
        publicationEnCours = false
        if callback then callback(ok, message) end
    end

    if publicationEnCours then
        fini = true
        if callback then callback(false, "une publication Arcanum est déjà en cours.") end
        return false
    end
    local sort, raison = SortVendeur(point)
    if not sort then Terminer(false, raison) return false end
    if not (C_Epsilon and ((C_Epsilon.IsMember and C_Epsilon.IsMember())
        or (C_Epsilon.IsOfficer and C_Epsilon.IsOfficer())
        or (C_Epsilon.IsOwner and C_Epsilon.IsOwner()))) then
        Terminer(false, "tu dois être membre, officier ou propriétaire de la phase.")
        return false
    end
    if not (EpsilonLib and EpsilonLib.PhaseAddonData
        and EpsilonLib.PhaseAddonData.Get and EpsilonLib.PhaseAddonData.Set) then
        Terminer(false, "le stockage de phase EpsilonLib est indisponible.")
        return false
    end
    local ace = LibStub and LibStub("AceSerializer-3.0", true)
    local deflate = LibStub and LibStub("LibDeflate", true)
    if not (ace and deflate and deflate.CompressDeflate and deflate.EncodeForWoWChatChannel
        and deflate.DecodeForWoWChatChannel and deflate.DecompressDeflate) then
        Terminer(false, "les bibliothèques de sérialisation Arcanum sont indisponibles.")
        return false
    end

    local function Encoder(valeur)
        local ok, serialise = pcall(ace.Serialize, ace, valeur)
        if not ok or type(serialise) ~= "string" then return nil end
        ok, serialise = pcall(deflate.CompressDeflate, deflate, serialise, { level = 9 })
        if not ok or type(serialise) ~= "string" then return nil end
        ok, serialise = pcall(deflate.EncodeForWoWChatChannel, deflate, serialise)
        return ok and type(serialise) == "string" and serialise or nil
    end
    local function Decoder(valeur)
        if type(valeur) ~= "string" or valeur == "" then return {} end
        local ok, donnees = pcall(deflate.DecodeForWoWChatChannel, deflate, valeur)
        if not ok then return nil end
        ok, donnees = pcall(deflate.DecompressDeflate, deflate, donnees)
        if not ok or type(donnees) ~= "string" then return nil end
        local succes
        ok, succes, donnees = pcall(ace.Deserialize, ace, donnees)
        return ok and succes and type(donnees) == "table" and donnees or nil
    end

    local sortEncode = Encoder(sort)
    if not sortEncode then Terminer(false, "la compression du sort Arcanum a échoué.") return false end

    -- Comme Necronicon : le coffre personnel reçoit la meme version, sans
    -- appeler l'interface sécurisée d'Arcanum depuis notre bouton.
    SpellCreatorSavedSpells = type(SpellCreatorSavedSpells) == "table" and SpellCreatorSavedSpells or {}
    SpellCreatorSavedSpells[sort.commID] = sort
    publicationEnCours = true
    if C_Timer and C_Timer.After then
        C_Timer.After(20, function()
            if publicationEnCours and not fini then
                Terminer(false, "le serveur n'a pas répondu pendant la publication Arcanum.")
            end
        end)
    end

    EpsilonLib.PhaseAddonData.Get("SCFORGE_KEYS%s", function(indexEncode)
        if fini then return end
        local ids = Decoder(indexEncode)
        if not ids then Terminer(false, "l'index du coffre Arcanum de phase est illisible.") return end
        local present = false
        for _, id in ipairs(ids) do
            if tostring(id) == sort.commID then present = true break end
        end
        if not present then ids[#ids + 1] = sort.commID end
        local nouvelIndex = Encoder(ids)
        if not nouvelIndex then Terminer(false, "la mise à jour de l'index Arcanum a échoué.") return end
        local ok, erreur = pcall(function()
            EpsilonLib.PhaseAddonData.Set("SCFORGE_S%s_" .. sort.commID, sortEncode)
            if not present then EpsilonLib.PhaseAddonData.Set("SCFORGE_KEYS%s", nouvelIndex) end
        end)
        if not ok then Terminer(false, "écriture du coffre de phase impossible : " .. tostring(erreur)) return end

        local essais = 0
        local function Verifier()
            essais = essais + 1
            EpsilonLib.PhaseAddonData.Get("SCFORGE_S%s_" .. sort.commID, function(valeur)
                if fini then return end
                if type(valeur) == "string" and valeur ~= "" then
                    Terminer(true, string.format("Vendeur « %s » enregistré et sort « %s » publié dans la phase.",
                        tostring(point.label or "Vendeur"), sort.commID))
                elseif essais < 4 and C_Timer and C_Timer.After then
                    C_Timer.After(0.5, Verifier)
                else
                    Terminer(false, "le serveur n'a pas confirmé le sort dans le coffre de phase.")
                end
            end)
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.25, Verifier) else Verifier() end
    end)
    return true
end

local function ConstruireEditeurSimple(nature)
    local mots = MOTS[nature]
    local ed = UI.Fenetre("editeur_point_" .. nature,
        nature == "vendeur" and "Éditeur de vendeur" or "Éditeur de ressource", 680, 540,
        { x = nature == "vendeur" and 40 or 120, y = -20 })
    ed.nature = nature
    ed.choixEntree = UI.Choix("point_entree_" .. nature, "Contenu donné")
    ed.choixDevise = UI.Choix("point_devise_" .. nature, "Devise")

    Libelle(ed.contenu, "Nom", 0, -5)
    ed.nom = UI.Champ(ed.contenu, 360, 22, function(texte)
        if ed.travail then ed.travail.label = texte end
    end)
    ed.nom:SetMaxLetters(80)
    ed.nom:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 90, 0)
    ed.ident = UI.Texte(ed.contenu, "", UI.C.discret, "GameFontNormalSmall")
    ed.ident:SetPoint("TOPRIGHT", ed.contenu, "TOPRIGHT", 0, -5)

    Libelle(ed.contenu, "Description", 0, -36)
    ed.description = UI.Zone(ed.contenu, 550, 62, function(texte)
        if ed.travail then ed.travail.description = texte end
    end)
    ed.description:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 90, -31)

    ed.titreOffres = UI.Texte(ed.contenu, "OFFRES", UI.C.titre, "GameFontNormalSmall")
    ed.titreOffres:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 0, -105)
    ed.ajouterOffre = UI.Bouton(ed.contenu, "+ Ajouter une offre", 150, 22, function()
        local offre = {
            id = LCM.Brouillons.NouvelIdentifiant(), entree = "", label = "", quantite = 1,
            prix = nature == "vendeur" and 0 or nil, devise = nil,
            stock = { limite = 0, unites = 0, minutes = 0 },
        }
        ed.travail.offres[#ed.travail.offres + 1] = offre
        ed.offreIndex = #ed.travail.offres
        ed:AfficherOffres()
        ed:RemplirOffre()
    end)
    ed.ajouterOffre:SetPoint("TOPRIGHT", ed.contenu, "TOPRIGHT", 0, -100)

    ed.listeOffres = UI.Defilement(ed.contenu)
    ed.listeOffres:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 0, -130)
    ed.listeOffres:SetPoint("TOPRIGHT", ed.contenu, "TOPRIGHT", 0, -130)
    ed.listeOffres:SetHeight(102)
    ed.lignesOffres = {}

    ed.details = CreateFrame("Frame", nil, ed.contenu)
    ed.details:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 0, -242)
    ed.details:SetPoint("TOPRIGHT", ed.contenu, "TOPRIGHT", 0, -242)
    ed.details:SetHeight(190)
    if UI.BordureFine then UI.BordureFine(ed.details, 0.35) end

    Libelle(ed.details, "Contenu", 10, -13)
    ed.entree = UI.Bouton(ed.details, "Choisir une entrée", 250, 22, function()
        ed.choixEntree:Proposer(ed.entree, OptionsEntrees(), function(ref)
            local offre = ed.travail and ed.travail.offres[ed.offreIndex]
            if not offre then return end
            offre.entree = ref
            ed:RemplirOffre()
            ed:AfficherOffres()
        end)
    end)
    ed.entree:SetPoint("TOPLEFT", ed.details, "TOPLEFT", 90, -8)

    Libelle(ed.details, "Libellé libre", 355, -13)
    ed.libelleOffre = UI.Champ(ed.details, 220, 22, function(texte)
        local offre = ed.travail and ed.travail.offres[ed.offreIndex]
        if offre then
            offre.label = texte
            ed:AfficherOffres()
        end
    end)
    ed.libelleOffre:SetPoint("TOPLEFT", ed.details, "TOPLEFT", 435, -8)

    Libelle(ed.details, "Quantité", 10, -47)
    ed.quantite = UI.Champ(ed.details, 55, 22, function(texte)
        local offre = ed.travail and ed.travail.offres[ed.offreIndex]
        if offre then offre.quantite = texte end
    end)
    ed.quantite:SetPoint("TOPLEFT", ed.details, "TOPLEFT", 90, -42)

    Libelle(ed.details, "Prix", 170, -47)
    ed.prix = UI.Champ(ed.details, 70, 22, function(texte)
        local offre = ed.travail and ed.travail.offres[ed.offreIndex]
        if offre then offre.prix = texte end
    end)
    ed.prix:SetPoint("TOPLEFT", ed.details, "TOPLEFT", 215, -42)
    ed.devise = UI.Bouton(ed.details, "Choisir la devise", 190, 22, function()
        ed.choixDevise:Proposer(ed.devise, OptionsDevises(), function(id)
            local offre = ed.travail and ed.travail.offres[ed.offreIndex]
            if offre then
                offre.devise = id
                ed:RemplirOffre()
            end
        end)
    end)
    ed.devise:SetPoint("TOPLEFT", ed.details, "TOPLEFT", 295, -42)

    Libelle(ed.details, "Stock maximum", 10, -82)
    ed.limite = UI.Champ(ed.details, 55, 22, function(texte)
        local offre = ed.travail and ed.travail.offres[ed.offreIndex]
        if offre then offre.stock.limite = texte end
    end)
    ed.limite:SetPoint("TOPLEFT", ed.details, "TOPLEFT", 115, -77)
    Libelle(ed.details, "Recharge", 190, -82)
    ed.unites = UI.Champ(ed.details, 55, 22, function(texte)
        local offre = ed.travail and ed.travail.offres[ed.offreIndex]
        if offre then offre.stock.unites = texte end
    end)
    ed.unites:SetPoint("TOPLEFT", ed.details, "TOPLEFT", 255, -77)
    Libelle(ed.details, "unité(s) toutes les", 320, -82)
    ed.minutes = UI.Champ(ed.details, 55, 22, function(texte)
        local offre = ed.travail and ed.travail.offres[ed.offreIndex]
        if offre then offre.stock.minutes = texte end
    end)
    ed.minutes:SetPoint("TOPLEFT", ed.details, "TOPLEFT", 445, -77)
    Libelle(ed.details, "minute(s)", 510, -82)

    ed.aideStock = UI.Texte(ed.details,
        "0 = stock illimité. Une recharge à 0 ne régénère pas automatiquement.",
        UI.C.discret, "GameFontNormalSmall")
    ed.aideStock:SetPoint("TOPLEFT", ed.details, "TOPLEFT", 10, -112)

    ed.retirerOffre = UI.Bouton(ed.details, "Supprimer cette offre", 180, 22, function()
        if not ed.offreIndex then return end
        table.remove(ed.travail.offres, ed.offreIndex)
        ed.offreIndex = math.min(ed.offreIndex, #ed.travail.offres)
        if ed.offreIndex == 0 then ed.offreIndex = nil end
        ed:AfficherOffres()
        ed:RemplirOffre()
    end)
    ed.retirerOffre:SetPoint("BOTTOMRIGHT", ed.details, "BOTTOMRIGHT", -10, 10)

    ed.enregistrer = UI.Bouton(ed.contenu, "Enregistrer", 140, 26, function() ed:Sauver() end)
    ed.enregistrer:SetPoint("BOTTOMRIGHT", ed.contenu, "BOTTOMRIGHT", 0, 0)
    ed.annuler = UI.Bouton(ed.contenu, "Annuler", 110, 26, function() ed:Hide() end)
    ed.annuler:SetPoint("RIGHT", ed.enregistrer, "LEFT", -8, 0)

    function ed:AfficherOffres()
        local y = 0
        for index, offre in ipairs((self.travail and self.travail.offres) or {}) do
            local ligne = self.lignesOffres[index]
            if not ligne then
                ligne = UI.Bouton(self.listeOffres.contenu, "", 10, 24, function(b)
                    self.offreIndex = b.index
                    self:AfficherOffres()
                    self:RemplirOffre()
                end)
                ligne.label:ClearAllPoints()
                ligne.label:SetPoint("LEFT", ligne, "LEFT", 8, 0)
                ligne.label:SetJustifyH("LEFT")
                self.lignesOffres[index] = ligne
            end
            ligne.index = index
            local texte = tostring(offre.label or "")
            if texte == "" then
                local entree = LCM.Compendium.Resoudre(offre.entree)
                texte = (entree and entree.label) or (offre.entree ~= "" and offre.entree) or "Offre sans contenu"
            end
            ligne.label:SetText(texte)
            ligne:Selectionner(index == self.offreIndex)
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", self.listeOffres.contenu, "TOPLEFT", 0, -y)
            ligne:SetPoint("TOPRIGHT", self.listeOffres.contenu, "TOPRIGHT", 0, -y)
            ligne:Show()
            y = y + 26
        end
        for index = #((self.travail and self.travail.offres) or {}) + 1, #self.lignesOffres do
            self.lignesOffres[index]:Hide()
        end
        self.listeOffres:Regler(y)
    end

    function ed:RemplirOffre()
        local offre = self.travail and self.offreIndex and self.travail.offres[self.offreIndex]
        self.details:SetShown(offre ~= nil)
        if not offre then return end
        offre.stock = type(offre.stock) == "table" and offre.stock or {}
        local entree = LCM.Compendium.Resoudre(offre.entree)
        self.entree.label:SetText((entree and entree.label) or (offre.entree ~= "" and offre.entree)
            or "Choisir une entrée")
        self.libelleOffre:SetText(offre.label or "")
        self.quantite:SetText(tostring(offre.quantite or 1))
        self.prix:SetText(tostring(offre.prix or 0))
        local devise = offre.devise and LCM.Devises.Get(offre.devise)
        self.devise.label:SetText((devise and devise.label) or offre.devise or "Choisir la devise")
        self.limite:SetText(tostring(offre.stock.limite or 0))
        self.unites:SetText(tostring(offre.stock.unites or 0))
        self.minutes:SetText(tostring(offre.stock.minutes or 0))
    end

    function ed:Ouvrir(point)
        self.creation = point == nil
        self.remplacePublie = point and LCM.Brouillons.EstPublie("points", point.id) or false
        self.travail = CopiePoint(point, self.nature)
        self.offreIndex = #self.travail.offres > 0 and 1 or nil
        self.nom:SetText(self.travail.label or "")
        self.description:SetText(self.travail.description or "")
        self.ident:SetText(self.travail.id)
        self.prix:SetShown(self.nature == "vendeur")
        self.devise:SetShown(self.nature == "vendeur")
        self:AfficherOffres()
        self:RemplirOffre()
        self:Show()
        self:Raise()
    end

    function ed:Sauver()
        if not self.travail or tostring(self.travail.label or ""):match("%S") == nil then
            LCM.Alerte("donne un nom au point.") return
        end
        for _, offre in ipairs(self.travail.offres or {}) do
            if self.nature == "vendeur" and tostring(offre.devise or "") == "" then
                LCM.Alerte("choisis une devise pour chaque offre du vendeur.") return
            end
        end
        local ok, raison = LCM.Brouillons.Enregistrer("points", self.travail,
            self.creation, self.remplacePublie)
        if not ok then LCM.Alerte(tostring(raison)) return end
        local point = Points.Get(self.travail.id)
        Points.ActualiserRegles(point)
        self:Hide()
        for _, fenetre in pairs(Ecran.frames) do
            if fenetre.nature == self.nature then fenetre:Choisir(self.travail.id) end
        end
        LCM.Ok(string.format("%s « %s » enregistré.", mots.titre, self.travail.label))
    end

    ed:Hide()
    return ed
end

-- ===== Constructeur de vendeur ===========================================
-- Le port du constructeur Necronicon garde sa vraie organisation : catalogue
-- a gauche, ventes/achats et onglets au centre, reglages d'article dans une
-- fenetre dediee. Le contenu reste un brouillon LCM synchronise ; son bouton
-- d'enregistrement fabrique aussi l'ArcSpell et le publie dans la phase.

local function NouvelleOffre(ref, devise)
    return {
        id = LCM.Brouillons.NouvelIdentifiant(), entree = tostring(ref or ""),
        label = "", quantite = 1, prix = 0, devise = devise,
        stock = { limite = 0, unites = 0, minutes = 0 },
    }
end

local function NomEntree(ref)
    local entree = LCM.Compendium.Resoudre(ref)
    return (entree and entree.label) or tostring(ref or "")
end

local function IconeEntree(ref)
    local entree = LCM.Compendium.Resoudre(ref)
    return (entree and entree.icone) or "Interface\\ICONS\\INV_Misc_QuestionMark"
end

local function ConstruireReglageOffre(proprietaire)
    local d = UI.Fenetre("reglage_offre_vendeur", "Réglage de l'article", 540, 350,
        { x = 180, y = -40 })
    d.choixDevise = UI.Choix("reglage_offre_devise", "Devise de l'article")
    d.nom = UI.Texte(d.contenu, "", UI.C.titre, "GameFontNormal")
    d.nom:SetPoint("TOPLEFT", d.contenu, "TOPLEFT", 0, 0)
    d.nom:SetPoint("TOPRIGHT", d.contenu, "TOPRIGHT", 0, 0)
    d.ref = UI.Texte(d.contenu, "", UI.C.discret, "GameFontNormalSmall")
    d.ref:SetPoint("TOPLEFT", d.contenu, "TOPLEFT", 0, -25)

    Libelle(d.contenu, "Libellé personnalisé", 0, -61)
    d.libelle = UI.Champ(d.contenu, 330, 22, function(texte)
        if d.offre then d.offre.label = texte end
    end)
    d.libelle:SetPoint("TOPLEFT", d.contenu, "TOPLEFT", 150, -56)
    Libelle(d.contenu, "Quantité donnée", 0, -95)
    d.quantite = UI.Champ(d.contenu, 70, 22, function(texte)
        if d.offre then d.offre.quantite = texte end
    end)
    d.quantite:SetPoint("TOPLEFT", d.contenu, "TOPLEFT", 150, -90)

    Libelle(d.contenu, "Prix", 0, -129)
    d.prix = UI.Champ(d.contenu, 70, 22, function(texte)
        if d.offre then d.offre.prix = texte end
    end)
    d.prix:SetPoint("TOPLEFT", d.contenu, "TOPLEFT", 150, -124)
    d.devise = UI.Bouton(d.contenu, "Devise par défaut", 210, 22, function()
        local options = { { id = "", label = "Devise par défaut" } }
        for _, option in ipairs(OptionsDevises()) do options[#options + 1] = option end
        d.choixDevise:Proposer(d.devise, options, function(id)
            if d.offre then d.offre.devise = id ~= "" and id or nil end
            d:Remplir()
        end)
    end)
    d.devise:SetPoint("LEFT", d.prix, "RIGHT", 10, 0)

    Libelle(d.contenu, "Stock maximum", 0, -176)
    d.limite = UI.Champ(d.contenu, 60, 22, function(texte)
        if d.offre then d.offre.stock.limite = texte end
    end)
    d.limite:SetPoint("TOPLEFT", d.contenu, "TOPLEFT", 105, -171)
    Libelle(d.contenu, "Recharge", 185, -176)
    d.unites = UI.Champ(d.contenu, 55, 22, function(texte)
        if d.offre then d.offre.stock.unites = texte end
    end)
    d.unites:SetPoint("TOPLEFT", d.contenu, "TOPLEFT", 250, -171)
    Libelle(d.contenu, "toutes les", 320, -176)
    d.minutes = UI.Champ(d.contenu, 55, 22, function(texte)
        if d.offre then d.offre.stock.minutes = texte end
    end)
    d.minutes:SetPoint("TOPLEFT", d.contenu, "TOPLEFT", 385, -171)
    Libelle(d.contenu, "minutes", 450, -176)
    d.aide = UI.Texte(d.contenu,
        "Stock 0 : illimité. Recharge 0 : aucune régénération automatique.",
        UI.C.discret, "GameFontNormalSmall")
    d.aide:SetPoint("TOPLEFT", d.contenu, "TOPLEFT", 0, -210)

    d.valider = UI.Bouton(d.contenu, "Terminer", 130, 26, function()
        d:Hide()
        if d.proprietaire then d.proprietaire:AfficherOffres() end
    end)
    d.valider:SetPoint("BOTTOMRIGHT", d.contenu, "BOTTOMRIGHT", 0, 0)

    function d:Remplir()
        local offre = self.offre
        if not offre then return end
        offre.stock = type(offre.stock) == "table" and offre.stock or {}
        self.nom:SetText(NomEntree(offre.entree) ~= "" and NomEntree(offre.entree) or "Article")
        self.ref:SetText(offre.entree or "")
        self.libelle:SetText(offre.label or "")
        self.quantite:SetText(tostring(offre.quantite or 1))
        self.prix:SetText(tostring(offre.prix or 0))
        local devise = offre.devise and LCM.Devises.Get(offre.devise)
        self.devise.label:SetText((devise and devise.label) or offre.devise or "Devise par défaut")
        self.limite:SetText(tostring(offre.stock.limite or 0))
        self.unites:SetText(tostring(offre.stock.unites or 0))
        self.minutes:SetText(tostring(offre.stock.minutes or 0))
    end

    function d:Ouvrir(offre, owner)
        self.offre, self.proprietaire = offre, owner or proprietaire
        self:Remplir()
        self:Show()
        self:Raise()
    end
    d:Hide()
    return d
end

local function ConstruireVendeur()
    local ed = UI.Fenetre("constructeur_vendeur", "Constructeur de vendeur", 1120, 620,
        { x = 0, y = -10 })
    ed.nature = "vendeur"
    ed.lignesCatalogue, ed.lignesOffres, ed.boutonsOnglets = {}, {}, {}
    ed.mode = "ventes"
    ed.choixDevise = UI.Choix("vendeur_devise_defaut", "Monnaie par défaut")
    ed.choixCategorie = UI.Choix("vendeur_categorie", "Catégorie du catalogue")
    ed.reglageOffre = ConstruireReglageOffre(ed)

    Libelle(ed.contenu, "Icône", 0, -4)
    ed.iconeBouton = CreateFrame("Button", nil, ed.contenu)
    ed.iconeBouton:SetSize(30, 30)
    ed.iconeBouton:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 0, -20)
    ed.iconeBouton.texture = ed.iconeBouton:CreateTexture(nil, "ARTWORK")
    ed.iconeBouton.texture:SetAllPoints(ed.iconeBouton)
    ed.iconeBouton.texture:SetTexCoord(0.09, 0.91, 0.09, 0.91)
    ed.iconeBouton.survol = UI.Aplat(ed.iconeBouton, UI.C.survol, "HIGHLIGHT")
    ed.iconeBouton.survol:SetAllPoints(ed.iconeBouton)
    if UI.BordureFine then UI.BordureFine(ed.iconeBouton, 0.45) end
    ed.iconeBouton:SetScript("OnClick", function(self)
        ed.selecteurIcone = ed.selecteurIcone or UI.SelecteurIcone("vendeur")
        ed.selecteurIcone:Proposer(self, function(chemin)
            if not ed.travail then return end
            ed.travail.icone = chemin
            ed.iconeBouton.texture:SetTexture(chemin)
        end)
    end)
    UI.Bulle(ed.iconeBouton, "Icône du sort", "Clic : choisir l'icône du vendeur dans le piqueur LCM.")

    Libelle(ed.contenu, "Identifiant unique LCM", 42, -4)
    ed.ident = UI.Texte(ed.contenu, "", UI.C.discret, "GameFontNormalSmall")
    ed.ident:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 42, -22)
    ed.ident:SetWidth(195)

    Libelle(ed.contenu, "Identifiant unique Arcanum", 250, -4)
    ed.arcId = UI.Champ(ed.contenu, 195, 22, function(texte)
        if ed.travail then ed.travail.arcId = texte end
    end)
    ed.arcId:SetMaxLetters(40)
    ed.arcId:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 250, -20)

    Libelle(ed.contenu, "Nom de la fenêtre", 460, -4)
    ed.nom = UI.Champ(ed.contenu, 250, 22, function(texte)
        if ed.travail then ed.travail.label = texte end
    end)
    ed.nom:SetMaxLetters(80)
    ed.nom:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 460, -20)
    Libelle(ed.contenu, "Monnaie par défaut", 725, -4)
    ed.deviseDefaut = UI.Bouton(ed.contenu, "Aucune devise", 235, 22, function()
        local options = { { id = "", label = "Aucune devise" } }
        for _, option in ipairs(OptionsDevises()) do options[#options + 1] = option end
        ed.choixDevise:Proposer(ed.deviseDefaut, options, function(id)
            ed.travail.deviseDefaut = id ~= "" and id or nil
            ed:MajDevise()
            ed:AfficherOffres()
        end)
    end)
    ed.deviseDefaut:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 725, -20)

    ed.apercu = UI.Bouton(ed.contenu, "Aperçu", 120, 24, function()
        if ed:Sauver(true) then
            local f = Ecran.Fenetre("vendeur")
            f:Choisir(ed.travail.id)
            f:Show()
        end
    end)
    ed.apercu:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 0, -55)

    -- Catalogue de tout ce qui peut etre depose dans un inventaire.
    ed.catalogue = CreateFrame("Frame", nil, ed.contenu)
    ed.catalogue:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 0, -94)
    ed.catalogue:SetPoint("BOTTOMLEFT", ed.contenu, "BOTTOMLEFT", 0, 45)
    ed.catalogue:SetWidth(330)
    if UI.BordureFine then UI.BordureFine(ed.catalogue, 0.35) end
    ed.titreCatalogue = UI.Texte(ed.catalogue, "Catalogue du compendium", UI.C.titre, "GameFontNormal")
    ed.titreCatalogue:SetPoint("TOPLEFT", ed.catalogue, "TOPLEFT", 10, -10)
    ed.compteCatalogue = UI.Texte(ed.catalogue, "", UI.C.discret, "GameFontNormalSmall")
    ed.compteCatalogue:SetPoint("TOPLEFT", ed.catalogue, "TOPLEFT", 10, -34)
    ed.recherche = UI.Champ(ed.catalogue, 310, 22, function() ed:AfficherCatalogue() end)
    ed.recherche:SetPoint("TOPLEFT", ed.catalogue, "TOPLEFT", 10, -57)
    ed.recherche:SetMaxLetters(80)
    ed.categorie = UI.Bouton(ed.catalogue, "Toutes les catégories", 310, 22, function()
        local options = OptionsCategories()
        ed.choixCategorie:Proposer(ed.categorie, options, function(id)
            ed.categorieId = id
            local label = "Toutes les catégories"
            for _, option in ipairs(options) do if option.id == id then label = option.label break end end
            ed.categorie.label:SetText(label)
            ed:AfficherCatalogue()
        end)
    end)
    ed.categorie:SetPoint("TOPLEFT", ed.catalogue, "TOPLEFT", 10, -86)
    ed.zoneCatalogue = UI.Defilement(ed.catalogue)
    ed.zoneCatalogue:SetPoint("TOPLEFT", ed.catalogue, "TOPLEFT", 10, -116)
    ed.zoneCatalogue:SetPoint("BOTTOMRIGHT", ed.catalogue, "BOTTOMRIGHT", -16, 10)

    ed.modeVentes = UI.Bouton(ed.contenu, "Ventes", 108, 24, function()
        ed.mode = "ventes" ed:AfficherOnglets() ed:AfficherOffres()
    end)
    ed.modeVentes:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 350, -94)
    ed.modeAchats = UI.Bouton(ed.contenu, "Achats", 108, 24, function()
        ed.mode = "achats" ed:AfficherOnglets() ed:AfficherOffres()
    end)
    ed.modeAchats:SetPoint("LEFT", ed.modeVentes, "RIGHT", 8, 0)

    ed.barreOnglets = CreateFrame("Frame", nil, ed.contenu)
    ed.barreOnglets:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 350, -128)
    ed.barreOnglets:SetPoint("TOPRIGHT", ed.contenu, "TOPRIGHT", 0, -128)
    ed.barreOnglets:SetHeight(26)
    ed.ajouterOnglet = UI.Bouton(ed.barreOnglets, "+", 28, 22, function() ed:AjouterOnglet() end)
    ed.ajouterOnglet:SetPoint("RIGHT", ed.barreOnglets, "RIGHT", -170, 0)
    ed.renommerOnglet = UI.Bouton(ed.barreOnglets, "Renommer", 78, 22, function() ed:RenommerOnglet() end)
    ed.renommerOnglet:SetPoint("LEFT", ed.ajouterOnglet, "RIGHT", 6, 0)
    ed.supprimerOnglet = UI.Bouton(ed.barreOnglets, "Supprimer", 78, 22, function() ed:SupprimerOnglet() end)
    ed.supprimerOnglet:SetPoint("LEFT", ed.renommerOnglet, "RIGHT", 6, 0)

    ed.zoneOffres = UI.Defilement(ed.contenu)
    ed.zoneOffres:SetPoint("TOPLEFT", ed.contenu, "TOPLEFT", 350, -162)
    ed.zoneOffres:SetPoint("BOTTOMRIGHT", ed.contenu, "BOTTOMRIGHT", 0, 45)
    ed.videOffres = UI.Texte(ed.contenu,
        "Ajoutez ici des entrées avec le bouton + du catalogue.", UI.C.discret, "GameFontNormal")
    ed.videOffres:SetPoint("CENTER", ed.zoneOffres, "CENTER", 0, 20)

    ed.status = UI.Texte(ed.contenu, "", UI.C.discret, "GameFontNormalSmall")
    ed.status:SetPoint("BOTTOMLEFT", ed.contenu, "BOTTOMLEFT", 0, 8)
    ed.status:SetPoint("BOTTOMRIGHT", ed.contenu, "BOTTOMRIGHT", -330, 8)
    ed.retour = UI.Bouton(ed.contenu, "Retour à la liste", 145, 26, function() ed:Hide() end)
    ed.retour:SetPoint("BOTTOMLEFT", ed.contenu, "BOTTOMLEFT", 0, -22)
    ed.enregistrer = UI.Bouton(ed.contenu, "Enregistrer / mettre à jour", 210, 26, function()
        ed:Sauver(false)
    end)
    ed.enregistrer:SetPoint("BOTTOMRIGHT", ed.contenu, "BOTTOMRIGHT", 0, -22)

    function ed:Onglets()
        if self.mode == "achats" then return self.travail.rachats end
        return self.travail.onglets
    end
    function ed:IndexOnglet()
        return self.mode == "achats" and self.indexRachat or self.indexVente
    end
    function ed:ReglerIndex(index)
        if self.mode == "achats" then self.indexRachat = index else self.indexVente = index end
    end
    function ed:Onglet()
        local tabs = self:Onglets()
        local index = math.max(1, math.min(#tabs, self:IndexOnglet() or 1))
        self:ReglerIndex(index)
        return tabs[index]
    end
    function ed:MajDevise()
        local devise = self.travail.deviseDefaut and LCM.Devises.Get(self.travail.deviseDefaut)
        self.deviseDefaut.label:SetText((devise and devise.label) or "Aucune devise")
    end
    function ed:AjouterDepuisCatalogue(ref)
        local tab = self:Onglet()
        if not tab then return end
        tab.offres[#tab.offres + 1] = NouvelleOffre(ref, self.travail.deviseDefaut)
        self:AfficherOffres()
    end
    function ed:AfficherCatalogue()
        local query = tostring(self.recherche:GetText() or ""):lower()
        local visibles = {}
        for _, option in ipairs(OptionsEntrees()) do
            local famille = option.id:match("^([^/]+)/") or ""
            if (not self.categorieId or self.categorieId == "" or famille == self.categorieId)
                and (query == "" or tostring(option.label):lower():find(query, 1, true)) then
                visibles[#visibles + 1] = option
            end
        end
        local y = 0
        for index, option in ipairs(visibles) do
            local ligne = self.lignesCatalogue[index]
            if not ligne then
                ligne = CreateFrame("Frame", nil, self.zoneCatalogue.contenu)
                ligne:SetHeight(46)
                if UI.SurfaceLigne then UI.SurfaceLigne(ligne) end
                ligne.icone = ligne:CreateTexture(nil, "ARTWORK")
                ligne.icone:SetSize(32, 32)
                ligne.icone:SetPoint("LEFT", ligne, "LEFT", 6, 0)
                ligne.nom = UI.Texte(ligne, "", UI.C.texte, "GameFontNormalSmall")
                ligne.nom:SetPoint("TOPLEFT", ligne.icone, "TOPRIGHT", 7, -3)
                ligne.nom:SetWidth(205)
                ligne.groupe = UI.Texte(ligne, "", UI.C.discret, "GameFontNormalSmall")
                ligne.groupe:SetPoint("TOPLEFT", ligne.nom, "BOTTOMLEFT", 0, -3)
                ligne.ajouter = UI.Bouton(ligne, "+", 28, 22, function(b)
                    self:AjouterDepuisCatalogue(b.ref)
                end)
                ligne.ajouter:SetPoint("RIGHT", ligne, "RIGHT", -5, 0)
                self.lignesCatalogue[index] = ligne
            end
            ligne.ajouter.ref = option.id
            ligne.icone:SetTexture(IconeEntree(option.id))
            ligne.nom:SetText(option.label)
            ligne.groupe:SetText(option.groupe)
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", self.zoneCatalogue.contenu, "TOPLEFT", 0, -y)
            ligne:SetPoint("TOPRIGHT", self.zoneCatalogue.contenu, "TOPRIGHT", 0, -y)
            ligne:Show()
            y = y + 50
        end
        for index = #visibles + 1, #self.lignesCatalogue do self.lignesCatalogue[index]:Hide() end
        self.zoneCatalogue:Regler(y)
        self.compteCatalogue:SetText(string.format("%d entrée(s) — cliquez sur + pour ajouter.", #visibles))
    end
    function ed:AfficherOnglets()
        local tabs = self:Onglets()
        self.modeVentes:Selectionner(self.mode == "ventes")
        self.modeAchats:Selectionner(self.mode == "achats")
        local largeur = math.max(70, math.min(120, math.floor(520 / math.max(1, #tabs))))
        for index, tab in ipairs(tabs) do
            local bouton = self.boutonsOnglets[index]
            if not bouton then
                bouton = UI.Bouton(self.barreOnglets, "", largeur, 22, function(b)
                    self:ReglerIndex(b.index)
                    self:AfficherOnglets()
                    self:AfficherOffres()
                end)
                self.boutonsOnglets[index] = bouton
            end
            bouton.index = index
            bouton:SetSize(largeur, 22)
            bouton.label:SetText(((self:IndexOnglet() or 1) == index and "• " or "") .. tab.label)
            bouton:Selectionner((self:IndexOnglet() or 1) == index)
            bouton:ClearAllPoints()
            bouton:SetPoint("LEFT", self.barreOnglets, "LEFT", (index - 1) * largeur, 0)
            bouton:Show()
        end
        for index = #tabs + 1, #self.boutonsOnglets do self.boutonsOnglets[index]:Hide() end
    end
    function ed:AjouterOnglet()
        local tabs = self:Onglets()
        tabs[#tabs + 1] = {
            id = LCM.Brouillons.NouvelIdentifiant(),
            label = self.mode == "achats" and ("Rachats " .. (#tabs + 1)) or ("Onglet " .. (#tabs + 1)),
            offres = {},
        }
        self:ReglerIndex(#tabs)
        self:AfficherOnglets() self:AfficherOffres()
    end
    function ed:RenommerOnglet()
        local tab = self:Onglet()
        if not tab then return end
        UI.Demande():Demander("Nom de l'onglet", tab.label, function(texte)
            if tostring(texte or ""):match("%S") == nil then return false, "nom vide." end
            tab.label = texte
            self:AfficherOnglets()
            return true
        end)
    end
    function ed:SupprimerOnglet()
        local tabs = self:Onglets()
        if #tabs <= 1 then LCM.Alerte("un vendeur doit conserver au moins un onglet.") return end
        table.remove(tabs, self:IndexOnglet())
        self:ReglerIndex(math.min(self:IndexOnglet(), #tabs))
        self:AfficherOnglets() self:AfficherOffres()
    end
    function ed:AfficherOffres()
        local tab = self:Onglet()
        local offres = tab and tab.offres or {}
        local y = 0
        for index, offre in ipairs(offres) do
            local ligne = self.lignesOffres[index]
            if not ligne then
                ligne = CreateFrame("Frame", nil, self.zoneOffres.contenu)
                ligne:SetHeight(58)
                if UI.SurfaceLigne then UI.SurfaceLigne(ligne) end
                ligne.icone = ligne:CreateTexture(nil, "ARTWORK")
                ligne.icone:SetSize(40, 40)
                ligne.icone:SetPoint("LEFT", ligne, "LEFT", 10, 0)
                ligne.nom = UI.Texte(ligne, "", UI.C.titre, "GameFontNormal")
                ligne.nom:SetPoint("TOPLEFT", ligne.icone, "TOPRIGHT", 9, -3)
                ligne.nom:SetWidth(235)
                ligne.ref = UI.Texte(ligne, "", UI.C.discret, "GameFontNormalSmall")
                ligne.ref:SetPoint("TOPLEFT", ligne.nom, "BOTTOMLEFT", 0, -5)
                ligne.ref:SetWidth(235)
                ligne.prix = UI.Texte(ligne, "", UI.C.accent, "GameFontNormalSmall")
                ligne.prix:SetPoint("RIGHT", ligne, "RIGHT", -224, 0)
                ligne.prix:SetWidth(135)
                ligne.prix:SetJustifyH("RIGHT")
                ligne.prixBouton = UI.Bouton(ligne, "Prix...", 66, 22, function(b)
                    self.reglageOffre:Ouvrir(b.offre, self)
                end)
                ligne.prixBouton:SetPoint("RIGHT", ligne, "RIGHT", -150, 0)
                ligne.stockBouton = UI.Bouton(ligne, "Stock...", 66, 22, function(b)
                    self.reglageOffre:Ouvrir(b.offre, self)
                end)
                ligne.stockBouton:SetPoint("RIGHT", ligne, "RIGHT", -78, 0)
                ligne.retirer = UI.Bouton(ligne, "Retirer", 66, 22, function(b)
                    table.remove(self:Onglet().offres, b.index)
                    self:AfficherOffres()
                end)
                ligne.retirer:SetPoint("RIGHT", ligne, "RIGHT", -6, 0)
                self.lignesOffres[index] = ligne
            end
            ligne.icone:SetTexture(IconeEntree(offre.entree))
            ligne.nom:SetText(offre.label ~= "" and offre.label or NomEntree(offre.entree))
            ligne.ref:SetText(offre.entree)
            local deviseId = offre.devise or self.travail.deviseDefaut
            local devise = deviseId and LCM.Devises.Get(deviseId)
            ligne.prix:SetText(string.format("%s %s", tostring(offre.prix or 0),
                (devise and devise.label) or deviseId or "sans devise"))
            ligne.prixBouton.offre, ligne.stockBouton.offre = offre, offre
            ligne.retirer.index = index
            ligne:ClearAllPoints()
            ligne:SetPoint("TOPLEFT", self.zoneOffres.contenu, "TOPLEFT", 0, -y)
            ligne:SetPoint("TOPRIGHT", self.zoneOffres.contenu, "TOPRIGHT", 0, -y)
            ligne:Show()
            y = y + 64
        end
        for index = #offres + 1, #self.lignesOffres do self.lignesOffres[index]:Hide() end
        self.zoneOffres:Regler(y)
        self.videOffres:SetShown(#offres == 0)
        local total = 0
        for _, onglet in ipairs(self:Onglets()) do total = total + #(onglet.offres or {}) end
        self.status:SetText(string.format("%d article(s) dans cet onglet, %d au total.", #offres, total))
    end
    function ed:Ouvrir(point)
        self.creation = point == nil
        self.remplacePublie = point and LCM.Brouillons.EstPublie("points", point.id) or false
        self.travail = CopiePoint(point, "vendeur")
        self.travail.arcId = tostring(self.travail.arcId or "")
        if self.travail.arcId == "" then self.travail.arcId = ArcIdParDefaut(self.travail.id) end
        self.travail.icone = tostring(self.travail.icone or ICONE_VENDEUR)
        self.travail.deviseDefaut = self.travail.deviseDefaut or nil
        if type(self.travail.onglets) ~= "table" or #self.travail.onglets == 0 then
            self.travail.onglets = { { id = "onglet_1", label = "Articles", offres = self.travail.offres or {} } }
        end
        if type(self.travail.rachats) ~= "table" or #self.travail.rachats == 0 then
            self.travail.rachats = { { id = "rachat_1", label = "Rachats", offres = {} } }
        end
        self.mode, self.indexVente, self.indexRachat = "ventes", 1, 1
        self.nom:SetText(self.travail.label or "")
        self.ident:SetText(self.travail.id)
        self.arcId:SetText(self.travail.arcId)
        self.iconeBouton.texture:SetTexture(self.travail.icone)
        self:MajDevise()
        self:AfficherCatalogue()
        self:AfficherOnglets()
        self:AfficherOffres()
        self:Show()
        self:Raise()
    end
    function ed:Sauver(apercu)
        if not self.travail or tostring(self.travail.label or ""):match("%S") == nil then
            LCM.Alerte("donne un nom au vendeur.") return false
        end
        local arcId, erreurArcId = NettoyerArcId(self.travail.arcId)
        if not arcId then LCM.Alerte(erreurArcId) return false end
        self.travail.arcId = arcId
        self.arcId:SetText(arcId)
        for _, collection in ipairs({ self.travail.onglets, self.travail.rachats }) do
            for _, onglet in ipairs(collection) do
                for _, offre in ipairs(onglet.offres or {}) do
                    if not offre.devise and not self.travail.deviseDefaut then
                        LCM.Alerte("choisis une monnaie par défaut ou une devise pour chaque article.")
                        return false
                    end
                end
            end
        end
        -- Evite de sauvegarder la vue plate heritee d'une ancienne version :
        -- le registre la reconstruit depuis les onglets.
        self.travail.offres = nil
        local ok, raison = LCM.Brouillons.Enregistrer("points", self.travail,
            self.creation, self.remplacePublie)
        if not ok then LCM.Alerte(tostring(raison)) return false end
        self.creation, self.remplacePublie = false, false
        Points.ActualiserRegles(Points.Get(self.travail.id))
        for _, fenetre in pairs(Ecran.frames) do
            if fenetre.nature == "vendeur" then fenetre:Choisir(self.travail.id) end
        end
        if apercu then return true end

        self.enregistrer:SetEnabled(false)
        self.status:SetText("Vendeur enregistré. Publication du sort Arcanum dans la phase…")
        local demarre = PublierVendeurArcanum(self.travail, function(publie, message)
            self.enregistrer:SetEnabled(true)
            self.status:SetText(tostring(message or ""))
            if publie then
                self:Hide()
                LCM.Ok(message)
            else
                LCM.Alerte("vendeur enregistré localement, mais publication Arcanum impossible : "
                    .. tostring(message or "erreur inconnue"))
            end
        end)
        if not demarre then self.enregistrer:SetEnabled(true) end
        return true
    end

    ed:Hide()
    return ed
end

function Ecran.Editeur(nature)
    Ecran.editeurs = Ecran.editeurs or {}
    if not Ecran.editeurs[nature] then
        Ecran.editeurs[nature] = nature == "vendeur" and ConstruireVendeur()
            or ConstruireEditeurSimple(nature)
    end
    return Ecran.editeurs[nature]
end

local function Construire(nature)
    local mots = MOTS[nature]
    local f = UI.Fenetre("points_" .. nature, mots.titre, LARGEUR, HAUTEUR,
        { x = nature == "vendeur" and -80 or 100, y = -40 })
    f.nature = nature

    -- ----- les points -----------------------------------------------------
    f.liste = UI.Defilement(f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 34)
    f.liste:SetWidth(COLONNE)
    f.lignes = {}

    f.nouveau = UI.Bouton(f.contenu, "+ Nouveau", 82, 24, function()
        Ecran.Editeur(nature):Ouvrir(nil)
    end)
    f.nouveau:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.modifier = UI.Bouton(f.contenu, "Modifier", 62, 24, function()
        local point = f:Point()
        if point then Ecran.Editeur(nature):Ouvrir(point) end
    end)
    f.modifier:SetPoint("LEFT", f.nouveau, "RIGHT", 4, 0)
    f.supprimer = UI.Bouton(f.contenu, "x", 24, 24, function()
        local point = f:Point()
        if not point then return end
        f.confirmation:Demander(string.format("Supprimer « %s » ?", point.label), function()
            local ok, raison
            if point.brouillon == true then
                ok = LCM.Brouillons.Supprimer("points", point.id)
            else
                ok, raison = LCM.Brouillons.Masquer("points", point.id)
            end
            if not ok then LCM.Alerte(tostring(raison or "suppression impossible")) return end
            f.pointId = nil
            f:Choisir((Points.Nature(nature)[1] or {}).id)
        end)
    end)
    f.supprimer:SetPoint("LEFT", f.modifier, "RIGHT", 4, 0)
    f.confirmation = UI.Confirmer(f, "", "Supprimer")

    -- ----- les offres -----------------------------------------------------
    f.droite = CreateFrame("Frame", nil, f.contenu)
    f.droite:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 12, 0)
    f.droite:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.description = UI.Texte(f.droite, "", UI.C.discret)
    UI.Police(f.description, 11)
    f.description:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, 0)
    f.description:SetPoint("TOPRIGHT", f.droite, "TOPRIGHT", 0, 0)
    f.description:SetJustifyH("LEFT")
    f.description:SetWordWrap(true)

    f.mode = "ventes"
    f.barreMode = CreateFrame("Frame", nil, f.droite)
    f.barreMode:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -28)
    f.barreMode:SetSize(210, 24)
    f.modeVentes = UI.Bouton(f.barreMode, "Ventes", 98, 22, function()
        f.mode, f.ongletIndex = "ventes", 1
        f:Afficher()
    end)
    f.modeVentes:SetPoint("LEFT", f.barreMode, "LEFT", 0, 0)
    f.modeAchats = UI.Bouton(f.barreMode, "Achats", 98, 22, function()
        f.mode, f.ongletIndex = "achats", 1
        f:Afficher()
    end)
    f.modeAchats:SetPoint("LEFT", f.modeVentes, "RIGHT", 6, 0)
    f.barreMode:SetShown(nature == "vendeur")

    f.barreOnglets = CreateFrame("Frame", nil, f.droite)
    f.barreOnglets:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, nature == "vendeur" and -56 or -28)
    f.barreOnglets:SetPoint("TOPRIGHT", f.droite, "TOPRIGHT", 0, nature == "vendeur" and -56 or -28)
    f.barreOnglets:SetHeight(24)
    f.boutonsOnglets = {}

    f.zone = UI.Defilement(f.droite)
    f.zone:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, nature == "vendeur" and -86 or -58)
    f.zone:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.offres = {}

    f.vide = UI.Texte(f.droite, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("CENTER", f.zone, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")

    function f:Point()
        return self.pointId and Points.Get(self.pointId) or Points.Nature(self.nature)[1]
    end

    function f:Choisir(id)
        self.pointId = id
        self.ongletIndex = 1
        self.mode = "ventes"
        local point = self:Point()
        for _, b in ipairs(self.lignes) do b:Selectionner(b.pointId == id) end
        self.description:SetText(point and tostring(point.description or "") or "")
        -- Ce qui s'est passe pendant notre absence ne se devine pas : on demande.
        if point then
            for _, offre in ipairs(point.offres) do
                if offre.stock.limite > 0 then LCM.Stock.Demander(offre.cle) end
            end
        end
        self:Afficher()
    end

    function f:Afficher()
        -- La colonne des points.
        local points = Points.Nature(self.nature)
        local y = 0
        for rang, point in ipairs(points) do
            local b = self.lignes[rang]
            if not b then
                b = UI.Bouton(self.liste.contenu, "", COLONNE - 10, LIGNE - 4, function()
                    self:Choisir(self.lignes[rang].pointId)
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetJustifyH("LEFT")
                self.lignes[rang] = b
            end
            b.pointId = point.id
            b.label:SetText(point.label)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.liste.contenu, "TOPLEFT", 0, -y)
            b:Selectionner(point.id == self.pointId)
            b:Show()
            y = y + LIGNE
        end
        for rang = #points + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.liste:Regler(y)

        -- Les offres du point choisi.
        local point = self:Point()
        local onglets = point and (self.mode == "achats" and point.rachats or point.onglets) or {}
        self.modeVentes:Selectionner(self.mode ~= "achats")
        self.modeAchats:Selectionner(self.mode == "achats")
        self.ongletIndex = math.max(1, math.min(#onglets, self.ongletIndex or 1))
        local largeurOnglet = math.max(60, math.min(110,
            math.floor((self.barreOnglets:GetWidth() > 0 and self.barreOnglets:GetWidth() or 320)
                / math.max(1, #onglets))))
        for index, onglet in ipairs(onglets) do
            local bouton = self.boutonsOnglets[index]
            if not bouton then
                bouton = UI.Bouton(self.barreOnglets, "", largeurOnglet, 22, function(b)
                    self.ongletIndex = b.index
                    self:Afficher()
                end)
                self.boutonsOnglets[index] = bouton
            end
            bouton.index = index
            bouton:SetSize(largeurOnglet, 22)
            bouton.label:SetText((index == self.ongletIndex and "• " or "") .. onglet.label)
            bouton:Selectionner(index == self.ongletIndex)
            bouton:ClearAllPoints()
            bouton:SetPoint("LEFT", self.barreOnglets, "LEFT", (index - 1) * largeurOnglet, 0)
            bouton:Show()
        end
        for index = #onglets + 1, #self.boutonsOnglets do self.boutonsOnglets[index]:Hide() end
        self.barreOnglets:SetShown(#onglets > 1)
        self.zone:ClearAllPoints()
        local haut
        if self.nature == "vendeur" then haut = #onglets > 1 and -86 or -58
        else haut = #onglets > 1 and -58 or -30 end
        self.zone:SetPoint("TOPLEFT", self.droite, "TOPLEFT", 0, haut)
        self.zone:SetPoint("BOTTOMRIGHT", self.droite, "BOTTOMRIGHT", 0, 0)
        local offresAffichees = (onglets[self.ongletIndex] and onglets[self.ongletIndex].offres)
            or (point and point.offres) or {}
        y = 0
        local nombre = 0
        for rang, offre in ipairs(offresAffichees) do
            local l = self.offres[rang]
            if not l then
                l = CreateFrame("Frame", nil, self.zone.contenu)
                l:SetHeight(LIGNE)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.icone = l:CreateTexture(nil, "ARTWORK")
                l.icone:SetSize(20, 20)
                l.icone:SetPoint("LEFT", l, "LEFT", 4, 0)
                l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                l.nom = UI.Texte(l, "", UI.C.texte)
                UI.Police(l.nom, 11)
                l.nom:SetPoint("LEFT", l.icone, "RIGHT", 6, 0)
                l.stock = UI.Texte(l, "", UI.C.discret)
                UI.Police(l.stock, 10)
                l.stock:SetPoint("RIGHT", l, "RIGHT", -96, 0)
                l.prendre = UI.Bouton(l, mots.action, 84, 20, function()
                    local ligne = self.offres[rang]
                    local rachat = self.nature == "vendeur" and self.mode == "achats"
                    local ok, raison
                    if rachat then
                        ok, raison = Points.Racheter(LCM.Entities.Self(),
                            self.pointId or (point and point.id), ligne.offreId)
                    else
                        ok, raison = Points.Prendre(LCM.Entities.Self(),
                            self.pointId or (point and point.id), ligne.offreId)
                    end
                    if not ok then LCM.Alerte(tostring(raison)) self:Afficher() return end
                    local action = rachat and "Revendre" or mots.action
                    LCM.Ok(string.format("%s : %s x%d.", action,
                        Points.Libelle(raison), raison.quantite))
                    self:Afficher()
                end)
                l.prendre:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                self.offres[rang] = l
            end
            l.offreId = offre.id
            l.prendre.label:SetText(self.mode == "achats" and "Revendre" or mots.action)
            l.icone:SetTexture(Points.Icone(offre))
            local nom = Points.Libelle(offre)
            if offre.quantite > 1 then nom = nom .. "  x" .. offre.quantite end
            if offre.prix then
                -- Le libelle de la devise, pas son identifiant : « 5 Écus »,
                -- pas « 5 ecus ».
                local devise = offre.devise and LCM.Devises.Get(offre.devise)
                nom = string.format("%s   |cffffd36b%s %s|r", nom, tostring(offre.prix),
                    (devise and devise.label) or tostring(offre.devise or ""))
            end
            l.nom:SetText(nom)

            if self.mode ~= "achats" and offre.stock.limite > 0 then
                local restant = LCM.Stock.Restant(offre.cle)
                l.stock:SetText(string.format("%d / %d", restant, offre.stock.limite))
                local couleur = restant == 0 and UI.C.plein or (restant < offre.stock.limite and UI.C.accent or UI.C.discret)
                l.stock:SetTextColor(couleur[1], couleur[2], couleur[3])
                l.prendre:SetEnabled(restant > 0)
            else
                l.stock:SetText("")
                l.prendre:SetEnabled(true)
            end

            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE + 2
            nombre = rang
        end
        for rang = nombre + 1, #self.offres do self.offres[rang]:Hide() end
        self.zone:Regler(y)
        self.nombreAffiche = nombre
        self.vide:SetText(#points > 0 and "" or mots.vide)
        self.modifier:SetEnabled(point ~= nil)
        self.supprimer:SetEnabled(point ~= nil)
    end

    function f:Montrer()
        self:Choisir(self.pointId or (Points.Nature(self.nature)[1] or {}).id)
        self:Show()
    end

    -- Le personnage change (equipement, sac, trait...) : la fenetre suit.
    UI.SuivrePersonnage(f, function(self) self:Afficher() end)
    return f
end

function Ecran.Fenetre(nature)
    if not Autorise() then return nil end
    if not Ecran.frames[nature] then Ecran.frames[nature] = Construire(nature) end
    return Ecran.frames[nature]
end

function Ecran.Basculer(nature)
    if not Autorise() then return nil end
    local f = Ecran.Fenetre(nature)
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

local actionArcanumEnregistree = false
local function EnregistrerActionArcanum()
    if actionArcanumEnregistree then return true end
    if not (ARC and ARC.RegisterAction) then return false end
    local ok, resultat = pcall(ARC.RegisterAction,
        "Les Contes Malveillants",
        ACTION_VENDEUR,
        "script",
        "Ouvrir un vendeur LCM",
        {
            command = function(pointId)
                if not Autorise() then return false end
                pointId = tostring(pointId or "")
                local point = Points.Get(pointId)
                if not point or point.nature ~= "vendeur" then
                    LCM.Alerte("ce vendeur LCM est inconnu : " .. pointId)
                    return false
                end
                local fenetre = Ecran.Fenetre("vendeur")
                if not fenetre then return false end
                fenetre:Choisir(pointId)
                fenetre:Show()
                if fenetre.Raise then fenetre:Raise() end
                return true
            end,
            description = "Ouvre un vendeur construit dans le plugin MJ des Contes Malveillants.",
            dataName = "Identifiant du vendeur",
            inputDescription = "Identifiant interne généré automatiquement par LCM.",
            example = "Utilisez /lcm vendeur pour créer ou modifier ce sort.",
        })
    actionArcanumEnregistree = ok and resultat ~= false
    return actionArcanumEnregistree
end

LCM.AddCommand("vendeur", "ouvre les vendeurs", function() Ecran.Basculer("vendeur") end, true)
LCM.AddCommand("ressources", "ouvre les points de recolte", function() Ecran.Basculer("ressource") end, true)

LCM.WhenReady(function()
    EnregistrerActionArcanum()
    UI.Menu.Lier("vendeur", function() Ecran.Basculer("vendeur") end)
    UI.Menu.Lier("ressources", function() Ecran.Basculer("ressource") end)
    -- Un stock qui bouge ailleurs se voit ici sans qu'on rouvre la fenetre.
    LCM.Stock.onChange = function()
        for _, f in pairs(Ecran.frames) do
            if f:IsShown() then f:Afficher() end
        end
    end
    local precedent = LCM.Brouillons.onSynchro
    LCM.Brouillons.onSynchro = function(famille, entree)
        if precedent then precedent(famille, entree) end
        if famille ~= "points" then return end
        if entree then Points.ActualiserRegles(Points.Get(entree.id)) end
        for _, f in pairs(Ecran.frames) do
            if f:IsShown() then f:Choisir(f.pointId) end
        end
    end
end)

LCM.On("ADDON_LOADED", function(nom)
    if nom == "SpellCreator" or nom == "Arcanum" then EnregistrerActionArcanum() end
end)
