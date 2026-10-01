-- Creation de personnage : l'ecran.
--
-- Organise comme la fenetre « Creation » du template Necronicon : sept
-- onglets (Bienvenue, Generale, Statistiques, Expertises, Penetrations,
-- Resistances, Traits), avec ses textes, et une grille de repartition par
-- budget. Chaque grille est un bloc du modele (titre en capitales, compte
-- « reste / total », remise a zero).
--
-- L'ecran ne connait aucune regle : il demande a `LCM.Creation` ce qu'on peut
-- poser et affiche ce qu'on lui repond — y compris les refus. Ajouter une
-- statistique ou un type de degat ne demande pas une ligne ici.

local _, LCM = ...
local UI = LCM.UI
local C = LCM.Creation

local Ecran = {}
UI.Creation = Ecran

local LARGEUR, HAUTEUR = 760, 720
local LARGEUR_PAGE = LARGEUR - 24
local LIGNE = 24
local LARGEUR_LABEL = 150
local ECART_BLOCS = 14

-- ===== Textes du template ==================================================

local TEXTES = {
    introduction = "Bienvenue dans le système des Contes Malveillants !\n\n"
        .. "Au fil des prochains onglets, tu seras invité à donner vie à ton personnage en choisissant sa race, "
        .. "ses caractéristiques, ses expertises et toutes les particularités qui le rendront unique.\n\n"
        .. "Chaque onglet t'accompagnera dans sa création et t'expliquera les différentes mécaniques de notre "
        .. "système de jeu.\n\n"
        .. "Et si tu as la moindre question, n'hésite surtout pas à te tourner vers Syn ou Talyah. Nous serons "
        .. "là pour te guider !",
    reglesImportantes = "Lors de la création de ton personnage, veille à respecter le niveau qui t'a été attribué.\n\n"
        .. "Tu pourras également proposer tes propres traits en effectuant une demande de création directement "
        .. "sur notre site internet.\n\n"
        .. "Enfin, prends le temps de répartir tes points en fonction du personnage que tu souhaites incarner. "
        .. "L'idée est avant tout que ses caractéristiques et ses compétences reflètent au mieux sa personnalité, "
        .. "son histoire et ses aptitudes !",
    race = "Choisis la race de ton personnage pour bénéficier de bonus de statistiques reflétant ses forces et "
        .. "ses faiblesses.\n\nTa race devra être créée et validée par un maître du jeu avant de pouvoir être utilisée.",
    niveau = "Par défaut, ton personnage commence au niveau cinq ! Les niveaux inférieurs représentent des "
        .. "créatures plus faibles qu'un aventurier lambda.\n\nSauf indication contraire de la part d'un maître "
        .. "du jeu, veille bien à commencer niveau 5.",
    informations = "Tu retrouveras ci-dessous le nombre de points dont tu disposes pour personnaliser ton "
        .. "personnage au fil des prochains onglets.",
    statistiques = "Il est temps de répartir tes points de statistiques primaires et secondaires !\n\n"
        .. "Les statistiques primaires représentent les aptitudes fondamentales de ton personnage. Elles "
        .. "interviennent dans tes jets de dés et servent de base au calcul de tes expertises et de tes bonus "
        .. "de dégâts.\n\n"
        .. "Les statistiques secondaires, quant à elles, te permettent de développer des aptitudes "
        .. "principalement liées au combat.\n\n"
        .. "Répartis tes points en fonction des forces et des faiblesses que tu souhaites donner à ton personnage !",
    statistiquesGenerales = "Répartissez ci-dessous vos points de statistiques. Les points de statistiques "
        .. "primaires influent sur l'ensemble de vos compétences. Elles constituent le socle de votre personnage.",
    expertises = "Les expertises représentent les compétences diverses et variées qu'un personnage sait faire "
        .. "ou non.\n\nIl est possible que certaines expertises ne soient pas présentées dans cette liste ; le "
        .. "cas échéant, celles-ci sont traitées soit au feeling, soit par aval d'un maître du jeu.",
    penetrations = "Les pénétrations représentent les compétences du personnage dans un domaine lorsqu'il "
        .. "s'agit de manipuler ce dernier à des fins actives.\n\n"
        .. "Comprenez par là qu'une pénétration permet autant de définir les dégâts produits par un type que la "
        .. "puissance d'un soin. Elle s'ajoute en outre en tant que bonus lors d'une action liée à ce type.\n\n"
        .. "Celles-ci sont divisées en 3 catégories : physiques, élémentaires et cosmologiques.\n\n"
        .. "Il n'y a aucune restriction au nombre de types que votre personnage sait ou non manier, mais un type "
        .. "ne peut être augmenté qu'à un seuil lié à vos trois statistiques de dégâts (Force, Mystique, Perception).",
    resistances = "Les résistances représentent les compétences du personnage dans un domaine lorsqu'il s'agit "
        .. "de se prémunir de ce dernier.\n\n"
        .. "Une résistance représente autant les actions naturelles que les mécanismes qu'un personnage met en "
        .. "place pour s'en défendre.\n\n"
        .. "Celles-ci sont divisées en 3 catégories : physiques, élémentaires et cosmologiques.\n\n"
        .. "Il n'y a aucune restriction au nombre de types que votre personnage sait ou non manier, mais un type "
        .. "ne peut être augmenté qu'à un seuil maximal lié à votre constitution.",
    traits = "Tout personnage commence avec 2 traits de personnage. Il peut ensuite sélectionner un trait "
        .. "supplémentaire tous les 5 niveaux.\n\n"
        .. "Les traits doivent être confectionnés par un maître du jeu.\n\n"
        .. "Ils apportent ou retirent des statistiques directement à la fiche. Ils représentent les affinités, "
        .. "particularités, etc., du personnage. À la différence de l'équipement, ils ne peuvent pas être amputés "
        .. "du personnage. De plus, chaque trait s'accompagne d'un « avantage ou désavantage » offrant des bonus "
        .. "ou malus dans des situations précises.",
}

-- ===== Une page : des blocs empiles ========================================

local function NouvellePage(f)
    local page = CreateFrame("Frame", nil, f.zone.contenu)
    page:SetPoint("TOPLEFT", f.zone.contenu, "TOPLEFT", 0, 0)
    page:SetPoint("TOPRIGHT", f.zone.contenu, "TOPRIGHT", 0, 0)
    page.blocs, page.compteurs, page.budgets = {}, {}, {}

    -- Chaque bloc connait sa hauteur interieure (`bloc.hauteurContenu`) ; la
    -- page les pose l'un sous l'autre.
    function page:Disposer()
        local y = 0
        for _, bloc in ipairs(self.blocs) do
            local h = bloc.hautTitre + 8
            if bloc.paragraphe then h = h + (bloc.paragraphe:GetStringHeight() or 14) + 12 end
            h = h + (bloc.hauteurContenu or 0) + UI.Fiche.MARGE_BLOC
            bloc:ClearAllPoints()
            bloc:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            bloc:SetSize(LARGEUR_PAGE, h)
            y = y + h + ECART_BLOCS
        end
        self.hauteur = math.max(1, y - ECART_BLOCS)
        self:SetHeight(self.hauteur)
    end
    page:Hide()
    return page
end

-- Un bloc du modele, avec un texte eventuel. Le contenu se pose sous le
-- texte : `Haut(bloc)` donne ou commencer.
local function Bloc(page, titre, texte)
    local bloc = UI.Fiche.Bloc(page, { label = titre or "", texte = texte }, LARGEUR_PAGE)
    page.blocs[#page.blocs + 1] = bloc
    return bloc
end

local function Haut(bloc)
    local y = bloc.hautTitre + 8
    if bloc.paragraphe then y = y + (bloc.paragraphe:GetStringHeight() or 14) + 12 end
    return y
end

-- Le compte « reste / total » et la remise a zero d'une categorie, dans le
-- titre du bloc.
local function Budget(page, f, bloc, categorie)
    bloc.budget = UI.Texte(bloc, "", UI.C.titre)
    UI.Police(bloc.budget, 14)
    bloc.remise = UI.Bouton(bloc, "R", 22, 20, function()
        C.RemettreCategorie(f.brouillon, categorie)
        f:Actualiser()
    end)
    bloc.remise:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -14, -(bloc.hautTitre - 20) / 2)
    bloc.budget:SetPoint("RIGHT", bloc.remise, "LEFT", -8, 0)
    bloc.categorie = categorie
    page.budgets[#page.budgets + 1] = bloc
end

-- Une grille de repartition : un compteur par ligne de la categorie, sur une
-- ou deux colonnes, avec un intertitre quand le groupe change.
local function Grille(page, f, titre, texte, categorie, colonnes)
    local bloc = Bloc(page, titre, texte)
    Budget(page, f, bloc, categorie)
    colonnes = colonnes or 1
    local lignes = C.Lignes(categorie)
    local marge = UI.Fiche.MARGE_BLOC + 6
    local largeurColonne = (LARGEUR_PAGE - 2 * marge) / colonnes
    local parColonne = math.ceil(#lignes / colonnes)
    local haut = Haut(bloc)
    local y, colonne, index, groupeCourant, hauteurMax = haut, 0, 0, nil, 0

    for _, ligne in ipairs(lignes) do
        if ligne.groupe and ligne.groupe ~= groupeCourant then
            groupeCourant = ligne.groupe
            local t = UI.Texte(bloc, UI.Majuscules(ligne.groupe), UI.C.accent)
            UI.Police(t, 12)
            t:SetPoint("TOPLEFT", bloc, "TOPLEFT", marge + colonne * largeurColonne, -y)
            y = y + 20
        end
        local compteur = UI.Compteur(bloc, ligne.label, LARGEUR_LABEL, {
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
        compteur:SetHeight(LIGNE - 2)
        compteur:SetPoint("TOPLEFT", bloc, "TOPLEFT", marge + colonne * largeurColonne, -y)
        compteur:SetWidth(largeurColonne - 12)
        compteur.champ, compteur.categorie = ligne.id, categorie
        -- Le cout n'est pas le meme pour tout le monde : il est ecrit a cote.
        local cout = C.Cout(categorie, ligne.id)
        if cout > 1 then
            local note = UI.Texte(compteur, string.format("%d pts", cout), UI.C.discret, "GameFontNormalSmall")
            note:SetPoint("LEFT", compteur.maximum, "RIGHT", 8, 0)
        end
        page.compteurs[#page.compteurs + 1] = compteur
        y = y + LIGNE
        index = index + 1
        hauteurMax = math.max(hauteurMax, y)
        if colonnes > 1 and index % parColonne == 0 and index < #lignes then
            colonne = colonne + 1
            y, groupeCourant = haut, nil
        end
    end
    bloc.hauteurContenu = hauteurMax - haut
    return bloc
end

-- Une ligne de lecture : libelle a gauche, valeur a droite.
local VIDE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local function Teinte(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function Lecture(bloc, libelle, y)
    local l = CreateFrame("Frame", nil, bloc)
    l:SetHeight(LIGNE)
    l:SetPoint("TOPLEFT", bloc, "TOPLEFT", UI.Fiche.MARGE_BLOC, -y)
    l:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -UI.Fiche.MARGE_BLOC, -y)
    if UI.SurfaceLigne then UI.SurfaceLigne(l) end
    l.nom = UI.Texte(l, libelle, UI.C.texte)
    UI.Police(l.nom, 13)
    l.nom:SetPoint("LEFT", l, "LEFT", 10, 0)
    l.valeur = UI.Texte(l, "", UI.C.titre)
    UI.Police(l.valeur, 13)
    l.valeur:SetPoint("RIGHT", l, "RIGHT", -12, 0)
    l.valeur:SetJustifyH("RIGHT")
    return l
end

-- Une entite de passage, faite du brouillon : les formules de la fiche (PV,
-- fatigue) s'y appliquent telles quelles, race et traits compris.
local function Apercu(brouillon)
    local values = {}
    for cle, valeur in pairs(brouillon.valeurs) do values[cle] = valeur end
    values.race, values.niveau = brouillon.race, brouillon.niveau
    return { id = "__apercu", name = brouillon.nom, kind = "player", values = values, traits = brouillon.traits }
end

-- ===== Les onglets =========================================================

local Pages = {}

function Pages.bienvenue(page)
    Bloc(page, "Introduction", TEXTES.introduction)
    Bloc(page, "Règles importantes", TEXTES.reglesImportantes)
end

function Pages.generale(page, f)
    -- Identite : ce que le template prend au personnage WoW ; ici, saisi.
    local identite = Bloc(page, "Identité")
    local y = Haut(identite)
    local x = UI.Fiche.MARGE_BLOC + 6
    local function Etiquette(texte, dy)
        local fs = UI.Texte(identite, texte, UI.C.texte)
        UI.Police(fs, 13)
        fs:SetPoint("TOPLEFT", identite, "TOPLEFT", x, -dy - 3)
        return fs
    end
    Etiquette("Nom", y)
    page.nom = UI.Champ(identite, 260, 22, function(texte)
        f.brouillon.nom = texte
        f:Actualiser()
    end)
    page.nom:SetPoint("TOPLEFT", identite, "TOPLEFT", x + LARGEUR_LABEL, -y)
    y = y + 30
    -- Age, sexe et poids ne coutent rien : ce sont des champs d'identite, pas
    -- des investissements.
    Etiquette("Âge", y)
    page.age = UI.Champ(identite, 70, 22, function(texte)
        f.brouillon.valeurs.age = tonumber(texte)
        f:Actualiser()
    end)
    page.age:SetPoint("TOPLEFT", identite, "TOPLEFT", x + LARGEUR_LABEL, -y)
    page.age:SetNumeric(true)
    Etiquette("Poids (kg)", y + 30)
    page.poids = UI.Champ(identite, 70, 22, function(texte)
        f.brouillon.valeurs.poids = tonumber(texte)
        f:Actualiser()
    end)
    page.poids:SetPoint("TOPLEFT", identite, "TOPLEFT", x + LARGEUR_LABEL, -(y + 30))
    page.poids:SetNumeric(true)
    y = y + 60
    Etiquette("Sexe", y)
    page.sexes = {}
    local precedent
    for _, sexe in ipairs({ "Féminin", "Masculin", "Autre" }) do
        local b = UI.Bouton(identite, sexe, 90, 22, function()
            f.brouillon.valeurs.sexe = sexe
            f:Actualiser()
        end)
        b.sexe = sexe
        if precedent then b:SetPoint("LEFT", precedent, "RIGHT", 4, 0)
        else b:SetPoint("TOPLEFT", identite, "TOPLEFT", x + LARGEUR_LABEL, -y) end
        precedent = b
        page.sexes[#page.sexes + 1] = b
    end
    identite.hauteurContenu = y + 26 - Haut(identite)

    -- Race : un CONTENEUR d'un emplacement dans le template (Creation ›
    -- Generale, « RACE », ajout limite a la categorie Races du compendium).
    -- On y depose une race en la glissant depuis le compendium ; un clic droit
    -- sur la case occupee la montre ou la retire.
    local race = Bloc(page, "Race", TEXTES.race)
    local c = UI.AelColonnes(LARGEUR_PAGE - 2 * UI.Fiche.MARGE_BLOC)
    local slot = UI.Fiche.Ligne(race, c)
    slot:SetHeight(math.max(48, c.ligne))
    slot:SetPoint("TOPLEFT", race, "TOPLEFT", UI.Fiche.MARGE_BLOC, -Haut(race))
    slot:SetPoint("TOPRIGHT", race, "TOPRIGHT", -UI.Fiche.MARGE_BLOC, -Haut(race))
    UI.Fiche.Icone(slot, c, VIDE)
    UI.Fiche.Nom(slot, c, "Emplacement", true)
    slot.effets = UI.Texte(slot, "", UI.C.accent)
    UI.Police(slot.effets, c.police * 0.72)
    slot.effets:SetPoint("LEFT", slot, "LEFT", c.plage, 0)
    slot.effets:SetPoint("RIGHT", slot, "RIGHT", -12 * c.echelle, 0)
    slot.effets:SetJustifyH("RIGHT")
    slot.effets:SetWordWrap(false)
    slot:EnableMouse(true)
    page.race = slot
    UI.Glisser.Cible(slot, function(objet)
        if objet.categorie ~= "races" then
            return false, "cet emplacement n'accepte qu'une race (catégorie Races du compendium)."
        end
        return true
    end, function(objet)
        f.brouillon.race = objet.element.id
        f:Actualiser()
    end)
    slot:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local r = f.brouillon.race ~= "" and LCM.Races.Get(f.brouillon.race)
        if r then
            GameTooltip:SetText(r.label)
            if r.description ~= "" then GameTooltip:AddLine(r.description, 0.88, 0.84, 0.76, true) end
            local effets = UI.Fiche.Effets(r)
            if effets ~= "" then GameTooltip:AddLine(effets, 0.83, 0.68, 0.33, true) end
            GameTooltip:AddLine("Clic droit : voir ou retirer.", 0.6, 0.56, 0.5)
        else
            GameTooltip:SetText("Emplacement")
            GameTooltip:AddLine("Glisse ici une race depuis le compendium (Système d'Aelskar, catégorie Races).",
                0.88, 0.84, 0.76, true)
        end
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    slot.menu = UI.Choix("creation_race", "Race")
    slot:SetScript("OnMouseUp", function(self, bouton)
        if bouton ~= "RightButton" or f.brouillon.race == "" then return end
        local r = LCM.Races.Get(f.brouillon.race)
        local options = { { id = "retirer", label = "Retirer" } }
        if r then table.insert(options, 1, { id = "voir", label = "Voir" }) end
        self.menu:Proposer(self, options, function(choix)
            if choix == "voir" and r then
                UI.Compendium.Voir(LCM.Compendium.Get("races"), r, f)
            elseif choix == "retirer" then
                f.brouillon.race = ""
                f:Actualiser()
            end
        end)
    end)
    race.hauteurContenu = slot:GetHeight()

    -- Niveau d'aventure : un champ de la fiche (« Niveau du personnage »,
    -- modifiable en vue), comme les lignes d'informations qui suivent. La
    -- valeur se saisit a droite ; une saisie illisible reste affichee en
    -- rouge et bloque la creation, rien n'est corrige en douce.
    local niveau = Bloc(page, "Niveau d'aventure", TEXTES.niveau)
    local ligneNiveau = Lecture(niveau, "Niveau du personnage (5 par défaut)", Haut(niveau))
    ligneNiveau.valeur:Hide()
    ligneNiveau.saisie = UI.Champ(ligneNiveau, 56, LIGNE - 6, function(texte)
        local n = tonumber(texte)
        if n and n == math.floor(n) and n >= 1 then
            f.brouillon.niveau = n
            f.brouillon.niveauSaisie = nil
        else
            f.brouillon.niveauSaisie = texte
        end
        f:Actualiser()
    end)
    ligneNiveau.saisie:SetMaxLetters(3)
    ligneNiveau.saisie:SetJustifyH("RIGHT")
    ligneNiveau.saisie:SetPoint("RIGHT", ligneNiveau, "RIGHT", -8, 0)
    UI.Police(ligneNiveau.saisie, 13)
    page.niveau = ligneNiveau
    niveau.hauteurContenu = LIGNE

    -- Informations generales : ce qu'on a a repartir, au niveau choisi.
    local infos = Bloc(page, "Informations générales", TEXTES.informations)
    y = Haut(infos)
    page.infos = {}
    for _, def in ipairs({ { "primaires", "Points de statistiques" }, { "secondaires", "Points de statistiques secondaires" },
                           { "expertises", "Points d'expertises" } }) do
        local l = Lecture(infos, def[2], y)
        l.categorie = def[1]
        page.infos[#page.infos + 1] = l
        y = y + LIGNE + 4
    end
    infos.hauteurContenu = y - Haut(infos)

    function page:Actualiser()
        local b = f.brouillon
        if self.nom:GetText() ~= b.nom then self.nom:SetText(b.nom or "") end
        local age = tostring(b.valeurs.age or "")
        if self.age:GetText() ~= age then self.age:SetText(age) end
        local poids = tostring(b.valeurs.poids or "")
        if self.poids:GetText() ~= poids then self.poids:SetText(poids) end
        -- Une saisie en cours (meme illisible) n'est pas remplacee.
        local saisie = self.niveau.saisie
        if b.niveauSaisie == nil and saisie:GetText() ~= tostring(b.niveau) then saisie:SetText(tostring(b.niveau)) end
        local teinte = b.niveauSaisie ~= nil and UI.C.plein or UI.C.titre
        saisie:SetTextColor(teinte[1], teinte[2], teinte[3])
        self.niveau.valeur = b.niveau
        for _, bouton in ipairs(self.sexes) do bouton:Selectionner(bouton.sexe == b.valeurs.sexe) end
        -- La case de race : la race deposee, ou « Emplacement ». Une race
        -- disparue reste visible, marquee, et bloque la creation.
        local slot, r = self.race, b.race ~= "" and LCM.Races.Get(b.race)
        if b.race == "" then
            slot.icone:SetTexture(VIDE)
            slot.nom:SetText("Emplacement")
            Teinte(slot.nom, UI.C.discret)
            slot.effets:SetText("")
        elseif r then
            slot.icone:SetTexture(r.icone)
            slot.nom:SetText(r.label)
            slot.nom:SetTextColor(UI.Compendium.Couleur(r.couleurTitre or LCM.COULEUR_TITRE))
            slot.effets:SetText(UI.Fiche.Effets(r))
        else
            slot.icone:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            slot.nom:SetText("? " .. tostring(b.race))
            Teinte(slot.nom, UI.C.plein)
            slot.effets:SetText("")
        end
        for _, l in ipairs(self.infos) do l.valeur:SetText(tostring(C.Total(b, l.categorie))) end
    end
end

function Pages.statistiques(page, f)
    Bloc(page, "Statistiques", TEXTES.statistiques)
    -- Ce que la repartition donne deja : les formules de la fiche, sur le
    -- brouillon.
    local general = Bloc(page, "Général")
    local y = Haut(general)
    page.pv = Lecture(general, "Points de vie", y)
    page.fatigue = Lecture(general, "Fatigue", y + LIGNE + 4)
    general.hauteurContenu = 2 * (LIGNE + 4)
    Grille(page, f, "Statistiques générales", TEXTES.statistiquesGenerales, "primaires", 2)
    Grille(page, f, "Statistiques secondaires", nil, "secondaires", 2)

    function page:Actualiser()
        local e = Apercu(f.brouillon)
        self.pv.valeur:SetText(tostring(LCM.Entities.Get_Value(e, "pv_max") or 0))
        local fatigue = LCM.Entities.Gauge(e, "fatigue")
        self.fatigue.valeur:SetText(tostring(fatigue and fatigue.max or 0))
    end
end

function Pages.expertises(page, f)
    Grille(page, f, "Expertises et compétences", TEXTES.expertises, "expertises", 2)
    Grille(page, f, "Mécanique de compétence", nil, "mecaniques", 2)
end

function Pages.penetrations(page, f)
    Grille(page, f, "Pénétrations", TEXTES.penetrations, "penetration", 2)
end

function Pages.resistances(page, f)
    Grille(page, f, "Résistances", TEXTES.resistances, "resistance", 2)
end

-- Traits : le conteneur « Traits » du template (10 places), sous le total.
-- Pas de liste « prendre ou laisser » : le choix des traits se fera
-- autrement. Pour l'instant, les emplacements seulement — les pris, puis une
-- case libre tant qu'il en reste (trente cases vides ne disent rien de plus).

function Pages.traits(page, f)
    Bloc(page, "Traits de votre personnage", TEXTES.traits)
    local bloc = Bloc(page, "Traits totaux")
    Budget(page, f, bloc, "traits")
    local largeurLigne = LARGEUR_PAGE - 2 * UI.Fiche.MARGE_BLOC
    local c = UI.AelColonnes(largeurLigne)
    page.emplacements = {}

    local function Emplacement(index)
        local l = UI.Fiche.Ligne(bloc, c)
        l:SetHeight(math.max(48, c.ligne))
        UI.Fiche.Icone(l, c, VIDE)
        UI.Fiche.Nom(l, c, "Emplacement", true)
        page.emplacements[index] = l
        return l
    end

    function page:Actualiser()
        local pris = f.brouillon.traits
        local places = tonumber(LCM.Equilibrage.conteneurs.traits) or 0
        local n = math.max(#pris, math.min(places, #pris + 1))
        local y = Haut(bloc)
        for index = 1, n do
            local l = self.emplacements[index] or Emplacement(index)
            local id = pris[index]
            local trait = id and LCM.Traits.Get(id)
            l.traitId = id
            if id then
                l.icone:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                l.nom:SetText(trait and trait.label or ("? " .. tostring(id)))
                l.nom:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
            else
                l.icone:SetTexture(VIDE)
                l.nom:SetText("Emplacement")
                l.nom:SetTextColor(UI.C.discret[1], UI.C.discret[2], UI.C.discret[3])
            end
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", bloc, "TOPLEFT", UI.Fiche.MARGE_BLOC, -y)
            l:SetPoint("TOPRIGHT", bloc, "TOPRIGHT", -UI.Fiche.MARGE_BLOC, -y)
            l:Show()
            y = y + l:GetHeight() + UI.Fiche.ECART_LIGNES
        end
        for index = n + 1, #self.emplacements do self.emplacements[index]:Hide() end
        bloc.hauteurContenu = y - Haut(bloc)
    end
    page:Actualiser()
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("creation", "Création", LARGEUR, HAUTEUR)
    Ecran.frame = f
    f.brouillon = C.Nouveau()
    local m = f.mesures

    local onglets = {}
    for _, etape in ipairs(C.ETAPES) do onglets[#onglets + 1] = { id = etape.id, label = etape.label } end
    f.barre = UI.BandeauOnglets(f.contenu, onglets, function(id) f:Afficher(id) end)
    f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.barre:SetWidth(LARGEUR_PAGE)
    local hauteurBandeau = f.barre:Disposer(LARGEUR_PAGE, m.onglet)

    -- En bas : ce qui bloque, et les trois gestes.
    f.valider = UI.Bouton(f.contenu, "Créer le personnage", 190, 26, function()
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
    f.valider:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    -- Abandonner : la fenetre se ferme et le brouillon part.
    f.abandonner = UI.Bouton(f.contenu, "Abandonner", 120, 26, function() f:Hide() end)
    f.abandonner:SetPoint("LEFT", f.valider, "RIGHT", 8, 0)
    -- Tout remettre a zero se confirme : c'est le seul geste qu'on ne peut pas
    -- defaire d'un clic.
    f.confirmation = UI.Confirmer(f, "", "Tout remettre a zero")
    f.remiseTotale = UI.Bouton(f.contenu, "Tout remettre à zéro", 170, 26, function()
        f.confirmation:Demander(
            "Remettre a zero tous les points depenses ?\nLe nom, la race et l'identite sont conserves.",
            function()
                C.RemettreTout(f.brouillon)
                f:Actualiser()
            end)
    end)
    f.remiseTotale:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.probleme = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.probleme, 12)
    f.probleme:SetPoint("BOTTOMLEFT", f.valider, "TOPLEFT", 0, 8)
    f.probleme:SetPoint("BOTTOMRIGHT", f.remiseTotale, "TOPRIGHT", 0, 8)

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -(hauteurBandeau + 10))
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 60)

    f.pages = {}
    for _, etape in ipairs(C.ETAPES) do
        local page = NouvellePage(f)
        Pages[etape.id](page, f)
        page:Disposer()
        f.pages[etape.id] = page
    end

    function f:Afficher(etapeId)
        self.etape = etapeId
        self.barre:Selectionner(etapeId)
        for id, page in pairs(self.pages) do page:SetShown(id == etapeId) end
        self.zone.decalage = 0
        self:Actualiser()
    end

    function f:Actualiser()
        local page = self.pages[self.etape]
        if not page then return end
        -- Les compteurs relisent tout : un plafond peut avoir bouge a cause
        -- d'une modification faite dans un autre onglet.
        for _, compteur in ipairs(page.compteurs) do
            compteur:Regler(C.Valeur(self.brouillon, compteur.champ),
                C.Plafond(self.brouillon, compteur.categorie, compteur.champ))
        end
        for _, bloc in ipairs(page.budgets) do
            local budget = C.Budget(self.brouillon, bloc.categorie)
            bloc.budget:SetText(string.format("%d / %d", budget.reste, budget.total))
            local couleur = UI.C.titre
            if budget.reste < 0 then couleur = UI.C.plein elseif budget.reste == 0 then couleur = UI.C.discret end
            bloc.budget:SetTextColor(couleur[1], couleur[2], couleur[3])
        end
        if page.Actualiser then page:Actualiser() end
        page:Disposer()
        self.zone:Regler(page.hauteur)

        local problemes = C.Problemes(self.brouillon)
        self.probleme:SetText(problemes[1] or "")
        self.valider:SetEnabled(#problemes == 0)
        local teinte = (#problemes == 0) and UI.C.titre or UI.C.discret
        self.valider.label:SetTextColor(teinte[1], teinte[2], teinte[3])
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
