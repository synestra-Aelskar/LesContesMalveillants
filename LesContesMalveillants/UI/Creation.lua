-- Creation de personnage : l'ecran.
--
-- Il ne connait aucune regle. Il demande a `LCM.Creation` ce qu'on peut poser
-- et affiche ce qu'on lui repond — y compris les refus. Ajouter une statistique
-- ou un type de degat ne demande pas une ligne ici : les pages se construisent
-- a partir de l'equilibrage et du schema.
--
-- A gauche, un recapitulatif replie par categorie, qui suit ce qu'on investit.
-- A droite, une grille d'onglets et la page en cours.

local _, LCM = ...
local UI = LCM.UI
local C = LCM.Creation

local Ecran = {}
UI.Creation = Ecran

local LIGNE = 20
local LARGEUR_LABEL = 122
local LARGEUR_RECAP = 226
local COLONNE = 268

-- ===== Fabriques de pages ==================================================

-- Pose des compteurs sur `colonnes` colonnes. Chaque compteur sait quelle
-- categorie et quel champ il porte ; la page ne garde qu'une liste a rafraichir.
local function Compteurs(page, categorie, lignes, colonnes, f)
    colonnes = colonnes or 1
    local parColonne = math.ceil(#lignes / colonnes)
    local groupeCourant
    local y, colonne, index = 0, 0, 0

    for _, ligne in ipairs(lignes) do
        -- Un intertitre quand le groupe change (domaine d'expertise, groupe de
        -- types). Il compte comme une ligne pour le decoupage en colonnes.
        if ligne.groupe and ligne.groupe ~= groupeCourant then
            groupeCourant = ligne.groupe
            local titre = UI.Texte(page, ligne.groupe, UI.C.accent, "GameFontNormalSmall")
            titre:SetPoint("TOPLEFT", page, "TOPLEFT", colonne * COLONNE, -y)
            y = y + LIGNE
        end

        local compteur = UI.Compteur(page, ligne.label, LARGEUR_LABEL, {
            change = function(valeur)
                local ok, raison = C.Definir(f.brouillon, categorie, ligne.id, valeur)
                if not ok then
                    LCM.Alerte(string.format("%s : %s", ligne.label, tostring(raison)))
                    return false
                end
                f:Actualiser()
            end,
            max = function() return C.Maximum(f.brouillon, categorie, ligne.id) end,
        })
        compteur:SetPoint("TOPLEFT", page, "TOPLEFT", colonne * COLONNE, -y)
        compteur:SetWidth(COLONNE - 14)
        compteur.champ = ligne.id
        compteur.categorie = categorie
        page.compteurs[#page.compteurs + 1] = compteur

        y = y + LIGNE + 2
        index = index + 1
        if colonnes > 1 and index % parColonne == 0 then
            colonne = colonne + 1
            y = 0
            groupeCourant = nil
        end
    end
end

-- Un en-tete de groupe pose en haut d'une page, avec la remise a zero de la
-- categorie entiere.
local function EnTete(page, f, libelle, categorie)
    local h = UI.EnTeteGroupe(page, libelle, function()
        C.RemettreCategorie(f.brouillon, categorie)
        f:Actualiser()
    end)
    h:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    h:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, 0)
    page.entete, page.enteteCategorie = h, categorie
    return h
end

local Pages = {}

function Pages.identite(page, f)
    local y = 4
    local function Etiquette(texte, dy)
        local fs = UI.Texte(page, texte, UI.C.texte, "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -dy)
        return fs
    end

    Etiquette("Nom", y)
    page.nom = UI.Champ(page, 240, 22, function(texte)
        f.brouillon.nom = texte
        f:Actualiser()
    end)
    page.nom:SetPoint("TOPLEFT", page, "TOPLEFT", LARGEUR_LABEL, -y + 2)
    y = y + 30

    -- Age, sexe et poids ne coutent rien : ce sont des champs d'identite, pas
    -- des investissements. Ils vivent donc a part des compteurs.
    Etiquette("Age", y)
    page.age = UI.Champ(page, 70, 22, function(texte)
        f.brouillon.valeurs.age = tonumber(texte)
        f:Actualiser()
    end)
    page.age:SetPoint("TOPLEFT", page, "TOPLEFT", LARGEUR_LABEL, -y + 2)
    page.age:SetNumeric(true)

    Etiquette("Poids (kg)", y + 30)
    page.poids = UI.Champ(page, 70, 22, function(texte)
        f.brouillon.valeurs.poids = tonumber(texte)
        f:Actualiser()
    end)
    page.poids:SetPoint("TOPLEFT", page, "TOPLEFT", LARGEUR_LABEL, -(y + 30) + 2)
    page.poids:SetNumeric(true)
    y = y + 60

    Etiquette("Sexe", y)
    page.sexes = {}
    local precedent
    for _, sexe in ipairs({ "Féminin", "Masculin", "Autre" }) do
        local b = UI.Bouton(page, sexe, 78, 22, function()
            f.brouillon.valeurs.sexe = sexe
            f:Actualiser()
        end)
        b.sexe = sexe
        if precedent then
            b:SetPoint("LEFT", precedent, "RIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", page, "TOPLEFT", LARGEUR_LABEL, -y + 2)
        end
        precedent = b
        page.sexes[#page.sexes + 1] = b
    end
    y = y + 32

    page.niveau = UI.Compteur(page, "Niveau", LARGEUR_LABEL, function(valeur)
        if valeur < 1 then return false end
        f.brouillon.niveau = valeur
        f:Actualiser()
    end)
    page.niveau:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    page.niveau.maximum:Hide()
    y = y + 26

    local aide = UI.Texte(page, "Les budgets se recalculent au niveau choisi.", UI.C.discret, "GameFontNormalSmall")
    aide:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    y = y + 26

    local titre = UI.Texte(page, "Race", UI.C.accent, "GameFontNormalSmall")
    titre:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
    y = y + LIGNE

    page.races = {}
    for _, race in ipairs(LCM.Races.list) do
        local b = UI.Bouton(page, race.label, 160, 22, function()
            f.brouillon.race = race.id
            f:Actualiser()
        end)
        b.raceId = race.id
        b:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -y)
        page.races[#page.races + 1] = b
        y = y + 24
    end
    if #page.races == 0 then
        UI.Texte(page, "Aucune race declaree.", UI.C.discret, "GameFontNormalSmall")
            :SetPoint("TOPLEFT", page, "TOPLEFT", 8, -y)
    end

    function page:Actualiser()
        local b = f.brouillon
        if self.nom:GetText() ~= b.nom then self.nom:SetText(b.nom or "") end
        local age = tostring(b.valeurs.age or "")
        if self.age:GetText() ~= age then self.age:SetText(age) end
        local poids = tostring(b.valeurs.poids or "")
        if self.poids:GetText() ~= poids then self.poids:SetText(poids) end
        self.niveau:Regler(b.niveau, 20)
        for _, bouton in ipairs(self.sexes) do bouton:Selectionner(bouton.sexe == b.valeurs.sexe) end
        for _, bouton in ipairs(self.races) do bouton:Selectionner(bouton.raceId == b.race) end
    end
end

function Pages.primaires(page, f)
    EnTete(page, f, "STATISTIQUES PRIMAIRES", "primaires")
    local corps = CreateFrame("Frame", nil, page)
    corps:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -26)
    corps:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    corps.compteurs = page.compteurs
    Compteurs(corps, "primaires", C.Lignes("primaires"), 1, f)

    -- Le cout n'est pas le meme pour tout le monde : il est ecrit a cote.
    for _, compteur in ipairs(page.compteurs) do
        local cout = C.Cout("primaires", compteur.champ)
        if cout > 1 then
            local note = UI.Texte(compteur, string.format("%d pts", cout), UI.C.discret, "GameFontNormalSmall")
            note:SetPoint("LEFT", compteur.maximum, "RIGHT", 8, 0)
        end
    end
end

local function PageSimple(libelle, categorie, colonnes)
    return function(page, f)
        EnTete(page, f, libelle, categorie)
        local corps = CreateFrame("Frame", nil, page)
        corps:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -26)
        corps:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
        corps.compteurs = page.compteurs
        Compteurs(corps, categorie, C.Lignes(categorie), colonnes, f)
        return corps
    end
end

Pages.expertises = PageSimple("EXPERTISES", "expertises", 2)
Pages.mecaniques = PageSimple("MÉCANIQUES DE COMPÉTENCE", "mecaniques", 2)

function Pages.secondaires(page, f)
    PageSimple("STATISTIQUES SECONDAIRES", "secondaires", 1)(page, f)
    for _, compteur in ipairs(page.compteurs) do
        local cout = C.Cout("secondaires", compteur.champ)
        if cout > 1 then
            local note = UI.Texte(compteur, string.format("%d pts", cout), UI.C.discret, "GameFontNormalSmall")
            note:SetPoint("LEFT", compteur.maximum, "RIGHT", 8, 0)
        end
    end
end

function Pages.types(page, f)
    page.enteteGauche = UI.EnTeteGroupe(page, "PÉNÉTRATIONS", function()
        C.RemettreCategorie(f.brouillon, "penetration")
        f:Actualiser()
    end)
    page.enteteGauche:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.enteteGauche:SetWidth(COLONNE - 14)

    page.enteteDroite = UI.EnTeteGroupe(page, "RÉSISTANCES", function()
        C.RemettreCategorie(f.brouillon, "resistance")
        f:Actualiser()
    end)
    page.enteteDroite:SetPoint("TOPLEFT", page, "TOPLEFT", COLONNE, 0)
    page.enteteDroite:SetWidth(COLONNE - 14)

    local gauche = CreateFrame("Frame", nil, page)
    gauche:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -26)
    gauche:SetSize(COLONNE, 460)
    gauche.compteurs = page.compteurs

    local droite = CreateFrame("Frame", nil, page)
    droite:SetPoint("TOPLEFT", page, "TOPLEFT", COLONNE, -26)
    droite:SetSize(COLONNE, 460)
    droite.compteurs = page.compteurs

    Compteurs(gauche, "penetration", C.Lignes("penetration"), 1, f)
    Compteurs(droite, "resistance", C.Lignes("resistance"), 1, f)
end

function Pages.traits(page, f)
    EnTete(page, f, "TRAITS", "traits")
    page.traits = {}
    local y = 26
    for _, trait in ipairs(LCM.Traits.list) do
        local l = CreateFrame("Frame", nil, page)
        l:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
        l:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -y)
        l:SetHeight(34)
        l.traitId = trait.id
        l.nom = UI.Texte(l, string.format("%s  (%d pt%s)", trait.label, trait.cout,
            trait.cout > 1 and "s" or ""), UI.C.texte, "GameFontNormalSmall")
        l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
        l.description = UI.Texte(l, trait.description, UI.C.discret, "GameFontNormalSmall")
        l.description:SetPoint("TOPLEFT", l, "TOPLEFT", 8, -14)
        l.description:SetWidth(380)
        l.bouton = UI.Bouton(l, "Prendre", 80, 20, function()
            if not C.RetirerTrait(f.brouillon, trait.id) then
                local ok, raison = C.AjouterTrait(f.brouillon, trait.id)
                if not ok then LCM.Alerte(tostring(raison)) end
            end
            f:Actualiser()
        end)
        l.bouton:SetPoint("TOPRIGHT", l, "TOPRIGHT", 0, 0)
        page.traits[#page.traits + 1] = l
        y = y + 38
    end
    if #page.traits == 0 then
        UI.Texte(page, "Aucun trait declare pour l'instant.", UI.C.discret, "GameFontNormalSmall")
            :SetPoint("TOPLEFT", page, "TOPLEFT", 0, -30)
    end

    function page:Actualiser()
        for _, l in ipairs(self.traits) do
            local pris = false
            for _, id in ipairs(f.brouillon.traits) do
                if id == l.traitId then pris = true end
            end
            l.bouton.label:SetText(pris and "Retirer" or "Prendre")
            l.bouton:Selectionner(pris)
        end
    end
end

-- ===== Le recapitulatif ====================================================
-- Une categorie repliee ne coute qu'une ligne ; depliee, elle montre ce qui a
-- ete investi. On ne liste pas les zeros : a 104 champs, ce serait illisible.

local RECAP = {
    { id = "identite",    label = "Identité" },
    { id = "primaires",   label = "Statistiques" },
    { id = "secondaires", label = "Secondaires" },
    { id = "expertises",  label = "Expertises" },
    { id = "mecaniques",  label = "Mécaniques" },
    { id = "penetration", label = "Pénétrations" },
    { id = "resistance",  label = "Résistances" },
    { id = "traits",      label = "Traits" },
}

local function LignesRecap(f, categorie)
    local b = f.brouillon
    local out = {}
    if categorie == "identite" then
        local race = LCM.Races.Get(b.race)
        out[#out + 1] = { "Nom", b.nom ~= "" and b.nom or "—" }
        out[#out + 1] = { "Race", race and race.label or "—" }
        out[#out + 1] = { "Niveau", tostring(b.niveau) }
        if b.valeurs.sexe then out[#out + 1] = { "Sexe", tostring(b.valeurs.sexe) } end
        if b.valeurs.age then out[#out + 1] = { "Age", tostring(b.valeurs.age) } end
        if b.valeurs.poids then out[#out + 1] = { "Poids", tostring(b.valeurs.poids) .. " kg" } end
        return out
    end
    if categorie == "traits" then
        for _, id in ipairs(b.traits) do
            local trait = LCM.Traits.Get(id)
            out[#out + 1] = { trait and trait.label or id, tostring(trait and trait.cout or 1) }
        end
        return out
    end
    for _, ligne in ipairs(C.Lignes(categorie)) do
        local valeur = C.Valeur(b, ligne.id)
        if valeur > 0 then out[#out + 1] = { ligne.label, tostring(valeur) } end
    end
    return out
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("creation", "Création de personnage", 820, 640)
    Ecran.frame = f
    f.brouillon = C.Nouveau()
    f.deplie = { identite = true, primaires = true }

    -- ----- recapitulatif --------------------------------------------------
    f.recap = CreateFrame("Frame", nil, f.contenu)
    f.recap:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.recap:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.recap:SetWidth(LARGEUR_RECAP)
    f.recap.fond = UI.Aplat(f.recap, UI.C.fondClair)
    f.recap.fond:SetAllPoints(f.recap)
    UI.Bordure(f.recap)

    f.recap.titre = UI.Texte(f.recap, "Récapitulatif", UI.C.titre, "GameFontNormalSmall")
    f.recap.titre:SetPoint("TOPLEFT", f.recap, "TOPLEFT", 10, -10)

    f.defilement = UI.Defilement(f.recap)
    f.defilement:SetPoint("TOPLEFT", f.recap, "TOPLEFT", 10, -30)
    f.defilement:SetPoint("BOTTOMRIGHT", f.recap, "BOTTOMRIGHT", -8, 10)
    f.recap.entetes, f.recap.lignes = {}, {}

    -- ----- onglets --------------------------------------------------------
    local onglets = {}
    for _, etape in ipairs(C.ETAPES) do
        onglets[#onglets + 1] = { id = etape.id, label = etape.label }
    end

    f.barre = UI.Onglets(f.contenu, onglets, function(id) f:Afficher(id) end,
        { parRangee = 3, largeur = 164, hauteur = 24 })
    f.barre:SetPoint("TOPLEFT", f.recap, "TOPRIGHT", 12, 0)
    f.barre:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, 0)

    -- Pas de ligne de budget ici : chaque page porte son en-tete de groupe, qui
    -- dit deja « reste / total ». La repeter au-dessus ne faisait qu'occuper une
    -- ligne et semer le doute sur laquelle des deux fait foi.
    f.zone = CreateFrame("Frame", nil, f.contenu)
    f.zone:SetPoint("TOPLEFT", f.barre, "BOTTOMLEFT", 0, -10)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 56)

    f.probleme = UI.Texte(f.contenu, "", UI.C.discret, "GameFontNormalSmall")
    f.probleme:SetPoint("BOTTOMLEFT", f.zone, "BOTTOMLEFT", 0, -22)
    f.probleme:SetPoint("BOTTOMRIGHT", f.zone, "BOTTOMRIGHT", 0, -22)

    f.valider = UI.Bouton(f.contenu, "Créer le personnage", 170, 24, function()
        local entity, erreur = C.Appliquer(f.brouillon)
        if not entity then
            LCM.Alerte(tostring(erreur))
            return
        end
        LCM.Ok(string.format("%s rejoint les Contes.", tostring(entity.name)))
        f:Hide()
        if UI.Personnages and UI.Personnages.frame and UI.Personnages.frame:IsShown() then
            UI.Personnages.frame:Montrer()
        end
        UI.Fiche.Fenetre():Montrer(entity)
    end)
    f.valider:SetPoint("BOTTOMLEFT", f.zone, "BOTTOMLEFT", 0, -50)

    -- Abandonner : la fenetre se ferme et le brouillon part. Une fermeture par
    -- la croix fait la meme chose — un brouillon a moitie rempli qui ressurgit
    -- plus tard est plus genant qu'utile.
    f.abandonner = UI.Bouton(f.contenu, "Abandonner", 110, 24, function() f:Hide() end)
    f.abandonner:SetPoint("LEFT", f.valider, "RIGHT", 8, 0)

    -- Tout remettre a zero se confirme : c'est le seul bouton de cet ecran
    -- qu'on ne peut pas defaire d'un clic.
    f.confirmation = UI.Confirmer(f, "", "Tout remettre a zero")
    f.remiseTotale = UI.Bouton(f.contenu, "Tout remettre à zéro", 150, 24, function()
        f.confirmation:Demander(
            "Remettre a zero tous les points depenses ?\nLe nom, la race et l'identite sont conserves.",
            function()
                C.RemettreTout(f.brouillon)
                f:Actualiser()
            end)
    end)
    f.remiseTotale:SetPoint("BOTTOMRIGHT", f.zone, "BOTTOMRIGHT", 0, -50)

    -- ----- pages ----------------------------------------------------------
    f.pages = {}
    for _, etape in ipairs(C.ETAPES) do
        local page = CreateFrame("Frame", nil, f.zone)
        page:SetAllPoints(f.zone)
        page.compteurs = {}
        Pages[etape.id](page, f)
        page:Hide()
        f.pages[etape.id] = page
    end

    function f:Afficher(etapeId)
        self.etape = etapeId
        for id, page in pairs(self.pages) do page:SetShown(id == etapeId) end
        self:Actualiser()
    end

    function f:ActualiserRecap()
        local y = 0
        local index, indexLigne = 0, 0
        for _, categorie in ipairs(RECAP) do
            index = index + 1
            local h = self.recap.entetes[index]
            if not h then
                -- `index` est declare AVANT la boucle : les huit fermetures le
                -- partageraient et repliieraient toutes la derniere categorie.
                -- On capture donc l'identifiant de l'iteration, pas le rang.
                local categorieId = categorie.id
                h = UI.Bouton(self.defilement.contenu, "", LARGEUR_RECAP - 22, 18, function()
                    self.deplie[categorieId] = not self.deplie[categorieId]
                    self:ActualiserRecap()
                end)
                h.label:ClearAllPoints()
                h.label:SetPoint("LEFT", h, "LEFT", 4, 0)
                h.label:SetJustifyH("LEFT")
                h.compte = UI.Texte(h, "", UI.C.discret, "GameFontNormalSmall")
                h.compte:SetPoint("RIGHT", h, "RIGHT", -4, 0)
                self.recap.entetes[index] = h
            end
            h.categorieId = categorie.id
            local ouvert = self.deplie[categorie.id] and true or false
            h.label:SetText((ouvert and "- " or "+ ") .. categorie.label)
            h:Selectionner(ouvert)
            if categorie.id == "identite" then
                h.compte:SetText("")
            else
                local budget = C.Budget(self.brouillon, categorie.id)
                h.compte:SetText(string.format("%d / %d", budget.reste, budget.total))
            end
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", self.defilement.contenu, "TOPLEFT", 0, -y)
            h:Show()
            y = y + 20

            if ouvert then
                for _, paire in ipairs(LignesRecap(self, categorie.id)) do
                    indexLigne = indexLigne + 1
                    local l = self.recap.lignes[indexLigne]
                    if not l then
                        l = CreateFrame("Frame", nil, self.defilement.contenu)
                        l:SetSize(LARGEUR_RECAP - 30, 14)
                        l.nom = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
                        l.nom:SetPoint("LEFT", l, "LEFT", 10, 0)
                        l.valeur = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                        l.valeur:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                        l.valeur:SetJustifyH("RIGHT")
                        self.recap.lignes[indexLigne] = l
                    end
                    l.nom:SetText(paire[1])
                    l.valeur:SetText(paire[2])
                    l:ClearAllPoints()
                    l:SetPoint("TOPLEFT", self.defilement.contenu, "TOPLEFT", 0, -y)
                    l:Show()
                    y = y + 15
                end
                y = y + 4
            end
        end
        for i = index + 1, #self.recap.entetes do self.recap.entetes[i]:Hide() end
        for i = indexLigne + 1, #self.recap.lignes do self.recap.lignes[i]:Hide() end
        self.defilement:Regler(y)
    end

    function f:Actualiser()
        local page = self.pages[self.etape]
        if not page then return end

        -- Les compteurs relisent tout : un plafond peut avoir bouge a cause
        -- d'une modification faite dans une autre etape.
        for _, compteur in ipairs(page.compteurs) do
            compteur:Regler(C.Valeur(self.brouillon, compteur.champ),
                C.Plafond(self.brouillon, compteur.categorie, compteur.champ))
        end
        if page.Actualiser then page:Actualiser() end

        if page.entete then
            local budget = C.Budget(self.brouillon, page.enteteCategorie)
            page.entete:Regler(budget.reste, budget.total)
        end
        if page.enteteGauche then
            local pen = C.Budget(self.brouillon, "penetration")
            local resi = C.Budget(self.brouillon, "resistance")
            page.enteteGauche:Regler(pen.reste, pen.total)
            page.enteteDroite:Regler(resi.reste, resi.total)
        end

        local problemes = C.Problemes(self.brouillon)
        self.probleme:SetText(problemes[1] or "")
        self.valider:SetEnabled(#problemes == 0)
        local teinte = (#problemes == 0) and UI.C.titre or UI.C.discret
        self.valider.label:SetTextColor(teinte[1], teinte[2], teinte[3])

        self:ActualiserRecap()
    end

    f:SetScript("OnHide", function(self)
        self.confirmation:Hide()
        if self.retourSelection then
            self.retourSelection = nil
            UI.Personnages.Fenetre():Montrer()
        end
    end)

    function f:Montrer(brouillon)
        self.brouillon = brouillon or self.brouillon or C.Nouveau()
        self.barre:Selectionner(C.ETAPES[1].id)
        self:Afficher(C.ETAPES[1].id)
        self:Show()
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

-- Toujours sur un brouillon neuf : « creer un personnage » ne doit pas reprendre
-- les restes de la fois d'avant.
function Ecran.Ouvrir()
    local f = Ecran.Fenetre()
    f:Montrer(C.Nouveau())
    return f
end

LCM.AddCommand("creer", "cree un personnage", function() Ecran.Ouvrir() end)
