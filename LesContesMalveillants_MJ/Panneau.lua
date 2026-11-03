-- Le panneau du maitre du jeu.
--
-- Il vit dans le COMPAGNON, et pas dans l'addon principal : c'est la seule
-- protection qui vaille. Un joueur n'a pas ce dossier, donc il n'a pas ce
-- code — le reste (verifications, droits) n'arrete que les curieux.
--
-- Refait le 3 octobre 2026 d'apres la fenetre du MJ de Necronicon
-- (Master.lua), en cinq onglets :
--   Joueurs   le suivi du groupe (Suivis de Necronicon) : addon present,
--             niveau et PV quand la fiche est arrivee, consulter, donner l'XP ;
--   Combat    ce qui etait la fenetre de combat a part (Combat.lua) ;
--   PNJ       les PNJ en scene, leur incarnation et le renvoi de la scene ;
--   Contenus  le systeme ;
--   Outils    annonces, barres, compteurs et notes partages avec les joueurs,
--             en quatre sous-onglets (OutilsUI.lua, Core/Outils.lua ; les
--             Outils de Necronicon, repris en entier le 20 octobre 2026).
-- Les onglets Général et Permissions de Necronicon ne sont pas repris : il n'y
-- a ici ni assistants MJ ni droits par interaction.
--
-- Refait encore le 2 novembre 2026 (« il est moche », le MJ). Huit onglets en
-- une rangee de 700 px, et ce qui touche un joueur eparpille : Consulter dans
-- Joueurs, ses etats dans Etats, XP et Regain dans deux fenetres a part.
-- Maintenant :
--   * une COLONNE de navigation a gauche, en deux sections — En seance /
--     Preparation — et les quatre outils partages en sous-entrees (leur
--     propre rangee d'onglets, dans l'onglet Outils, disparait) ;
--   * Joueurs et Etats ne font plus qu'une page, « Groupe & etats », en trois
--     colonnes : le catalogue d'etats, le groupe, le personnage choisi.
--     Le catalogue reste OUVERT : poser des etats « a la pelle » (le MJ) est
--     le geste a proteger — on glisse sur un joueur, ou sur la zone « les
--     cochés » pour tous ceux qu'on a coches d'un coup ;
--   * les raccourcis du menu radial ouvrent le panneau sur la bonne entree,
--     au lieu d'un mode « page seule » qui masquait la barre.
-- Les identifiants de page (joueurs, etats, combat...) n'ont pas bouge : le
-- reste du compagnon et le banc les emploient. « etats » mene a la page
-- Groupe, et `pages.etats` designe sa partie etats.
--
-- La consultation est a sens unique, et le joueur consulte en est prevenu
-- (Core/Fiches.lua) : on regarde par-dessus l'epaule, pas dans le dos.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local GameTooltip = UI.Infobulle()
local Ecran = {}
UI.PanneauMJ = Ecran
MJ.Panneau = Ecran

-- 960 : trois colonnes sur la page Groupe (catalogue 232, detail 250, le
-- groupe entre les deux) a cote d'une navigation de 150. A 700, l'ancienne
-- page Etats tenait ses trois colonnes en 210/240/reste et rognait les noms.
-- 640 de haut : le detail porte aussi le regain (huit ressources, le mode)
-- au-dessus des etats portes, qui gardent de quoi en montrer trois ou quatre.
local LARGEUR, HAUTEUR = 960, 640
local LIGNE = 28
local NAV = 150

-- Les pages, dans l'ordre de construction. La navigation les range autrement
-- (Ecran.NAVIGATION) ; cette liste reste la reference des identifiants.
Ecran.ONGLETS = {
    { id = "joueurs", label = "Groupe & états" },
    { id = "combat",  label = "Combat" },
    { id = "pnj",     label = "Scène & PNJ" },
    { id = "outils",  label = "Outils partagés" },
    { id = "traits", label = "Traits visibles" },
    { id = "equilibrage", label = "Équilibrage" },
}

-- Anciens identifiants, encore appeles (menu radial, autres fichiers).
local ALIAS = { etats = "joueurs" }

local function Navigation()
    local outils = {}
    for _, sorte in ipairs(LCM.Outils and LCM.Outils.ORDRE or {}) do
        outils[#outils + 1] = { id = "outils:" .. sorte,
            label = sorte == "annonce" and "Annonces" or (LCM.Outils.SORTES[sorte] .. "s") }
    end
    return {
        { titre = "En séance", entrees = {
            { id = "joueurs", label = "Groupe & états" },
            { id = "combat",  label = "Combat" },
            { id = "pnj",     label = "Scène & PNJ" },
            { id = "outils",  label = "Outils partagés", enfants = outils },
        } },
        { titre = "Préparation", entrees = {
            { id = "traits",      label = "Traits visibles" },
            -- Pas une page : une porte vers le Compendium (le MJ, 2 novembre
            -- 2026). La page « Contenus » n'avait plus qu'un bouton, celui-la.
            { id = "compendium",  label = "Compendium" },
            { id = "equilibrage", label = "Équilibrage" },
        } },
    }
end

-- Recherche sans accents ni majuscules : « echo » trouve « Écho ». Partagee
-- par les traits et le catalogue d'etats.
local ACCENTS = { ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["é"] = "e", ["è"] = "e",
    ["ê"] = "e", ["ë"] = "e", ["î"] = "i", ["ï"] = "i", ["ô"] = "o", ["ö"] = "o",
    ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ç"] = "c", ["À"] = "a", ["Â"] = "a",
    ["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Î"] = "i", ["Ô"] = "o", ["Û"] = "u",
    ["Ç"] = "c" }
local function Cherchable(texte)
    texte = tostring(texte or "")
    for avec, sans in pairs(ACCENTS) do texte = texte:gsub(avec, sans) end
    return texte:lower()
end

-- Une colonne : fond sombre, filet fin, titre en capitales (UI.Colonne, Kit).
local function Colonne(parent, titre) return UI.Colonne(parent, titre) end

-- Le groupe, vu d'ici. Le MJ reste toujours visible : sa fiche locale est
-- utile meme lorsqu'il joue seul, et ne doit pas passer par le reseau.
local function Groupe()
    local out = {}
    local moi = LCM.PlayerId()
    local moiCourt = tostring(moi or ""):match("^([^-]+)")
    moiCourt = moiCourt and moiCourt:lower() or ""
    if GetNumGroupMembers and UnitName then
        local nombre = GetNumGroupMembers() or 0
        local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
        for index = 1, nombre do
            local nom, royaume = UnitName(prefixe .. index)
            if nom then
                local complet = (royaume and royaume ~= "" and (nom .. "-" .. royaume)) or nom
                local completCourt = tostring(complet):match("^([^-]+)")
                completCourt = completCourt and completCourt:lower() or ""
                if complet ~= moi and completCourt ~= moiCourt then out[#out + 1] = complet end
            end
        end
    end
    table.sort(out)
    if moi and moi ~= "" then out[#out + 1] = moi end
    return out
end
Ecran.Groupe = Groupe

local function Dire(ok, raison)
    if not ok and raison then LCM.Alerte(tostring(raison)) end
    return ok
end

-- Une ligne de liste : fond, et ce qu'on y pose ensuite.
local function Rangee(parent, hauteur)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight((hauteur or LIGNE) - 2)
    if UI.SurfaceLigne then UI.SurfaceLigne(l) end
    return l
end

local function Poser(l, parent, y)
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    l:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
    l:Show()
end

local function Titre(parent, texte)
    local t = UI.Texte(parent, texte, UI.C.titre)
    UI.Police(t, 12)
    return t
end

local Pages = {}
local demandesFichesXP = {}

local function NomCourt(joueur)
    local court = tostring(joueur or ""):match("^([^-]+)") or ""
    return court:lower()
end

local function EstMoi(joueur)
    local moi = tostring(LCM.PlayerId() or "")
    joueur = tostring(joueur or "")
    return joueur ~= "" and (joueur == moi or NomCourt(joueur) == NomCourt(moi))
end

-- Une fiche distante vient du cache de consultation. La fiche du MJ, elle,
-- est deja en memoire : la demander en WHISPER a soi-meme est refuse par le
-- protocole et faisait echouer Consultation comme la jauge d'XP.
local function FicheJoueur(joueur)
    if EstMoi(joueur) then
        local entity = LCM.Entities.Personnage and LCM.Entities.Personnage()
            or (LCM.Entities.Self and LCM.Entities.Self())
        return entity, entity
    end
    return LCM.Fiches.Recue(joueur)
end

-- La liste du groupe peut contenir « Nom », tandis que le transport repond
-- avec « Nom-Royaume ». Une reponse attendue par le panneau XP doit rester
-- silencieuse dans les deux cas : elle alimente les jauges, elle n'ouvre pas
-- la consultation du joueur.
local function PrendreDemandeXP(joueur)
    joueur = tostring(joueur or "")
    if demandesFichesXP[joueur] then
        demandesFichesXP[joueur] = nil
        return true
    end
    local court, trouve = NomCourt(joueur), false
    for demande in pairs(demandesFichesXP) do
        if NomCourt(demande) == court then
            demandesFichesXP[demande] = nil
            trouve = true
        end
    end
    return trouve
end

-- Ce panneau parle des PERSONNAGES suivis par le MJ. Le nom de compte reste
-- seulement l'adresse reseau conservee dans `l.joueur` pour les boutons.
local function NomPersonnage(joueur)
    local entity = FicheJoueur(joueur)
    local nom = entity and tostring(entity.name or "") or ""
    if nom == "" and LCM.Presence and LCM.Presence.Personnage then
        nom = tostring(LCM.Presence.Personnage(joueur) or "")
    end
    return nom ~= "" and nom or tostring(joueur)
end

-- ===== Joueurs =============================================================

local ConstruireEtats

-- La page « Groupe & etats ». Trois colonnes, de gauche a droite : ce qu'on
-- pose (le catalogue d'etats), sur qui (le groupe, avec ses cases), et ce
-- que porte deja celui qu'on a clique. Le catalogue a gauche parce qu'on
-- glisse de gauche a droite, vers le groupe, sans traverser le detail.
function Pages.joueurs(page, f)
    page.colCatalogue = Colonne(page, "Catalogue d'états")
    page.colCatalogue:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.colCatalogue:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    page.colCatalogue:SetWidth(232)
    page.colDetail = Colonne(page, "Personnage")
    page.colDetail:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    page.colDetail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.colDetail:SetWidth(250)
    page.colGroupe = Colonne(page, "Groupe")
    page.colGroupe:SetPoint("TOPLEFT", page.colCatalogue, "TOPRIGHT", 10, 0)
    page.colGroupe:SetPoint("BOTTOMRIGHT", page.colDetail, "BOTTOMLEFT", -10, 0)
    local groupe = page.colGroupe

    -- Le compte et Rafraichir vivent dans le titre de la colonne : la barre
    -- du haut qui les portait coutait une rangee a toute la page.
    page.rafraichir = UI.Bouton(groupe, "Rafraîchir", 76, 18, function()
        if LCM.Presence and LCM.Presence.Demander then LCM.Presence.Demander(true) end
        page:Afficher()
    end)
    page.rafraichir:SetPoint("TOPRIGHT", groupe, "TOPRIGHT", -6, -4)
    UI.Bulle(page.rafraichir, "Rafraîchir", "Redemande au groupe qui a l'addon et quel personnage il joue.")
    page.etat = UI.Texte(groupe, "", UI.C.discret)
    UI.Police(page.etat, 10)
    page.etat:SetPoint("LEFT", groupe.titre, "RIGHT", 8, 0)

    -- La colonne fait ~248 de large (page ~750, moins 232 + 250 + 20) : les
    -- trois boutons du bas tiennent en 80 + 72 + 56 avec leurs marges.
    -- Ce qui se fait a plusieurs se fait sur les COCHES : XP, regain, et le
    -- depot d'un etat sur la zone du bas. Une seule selection, au lieu
    -- d'une par fenetre a recocher a chaque fois.
    page.selection = {}
    function page:Coches()
        local out = {}
        for _, l in ipairs(self.lignes) do
            if l:IsShown() and l.joueur and self.selection[l.joueur] then out[#out + 1] = l.joueur end
        end
        return out
    end

    page.xpBouton = UI.Bouton(groupe, "XP…", 56, 22, function()
        page.xpPanneau:Ouvrir()
    end)
    page.xpBouton:SetPoint("BOTTOMRIGHT", groupe, "BOTTOMRIGHT", -8, 8)
    UI.Bulle(page.xpBouton, "Attribuer de l'expérience", "Aux joueurs cochés (modifiable dans la fenêtre).")
    page.regainBouton = UI.Bouton(groupe, "Regain…", 72, 22, function()
        page.regainPanneau:Ouvrir()
    end)
    page.regainBouton:SetPoint("RIGHT", page.xpBouton, "LEFT", -6, 0)
    UI.Bulle(page.regainBouton, "Regain des ressources", "Aux joueurs cochés (modifiable dans la fenêtre).")
    page.tousBouton = UI.Bouton(groupe, "Tout cocher", 80, 22, function()
        local tous = true
        for _, l in ipairs(page.lignes) do
            if l:IsShown() and l.joueur and not page.selection[l.joueur] then tous = false end
        end
        for _, l in ipairs(page.lignes) do
            if l:IsShown() and l.joueur then
                page.selection[l.joueur] = (not tous) or nil
                l.case:Cocher(not tous)
            end
        end
        page:AfficherCoches()
    end)
    page.tousBouton:SetPoint("BOTTOMLEFT", groupe, "BOTTOMLEFT", 8, 8)

    -- La zone « les cochés » : lacher un etat ici le pose sur tous les
    -- coches, avec la duree du catalogue.
    page.depot = CreateFrame("Frame", nil, groupe)
    page.depot:SetHeight(38)
    page.depot:SetPoint("BOTTOMLEFT", groupe, "BOTTOMLEFT", 8, 36)
    page.depot:SetPoint("BOTTOMRIGHT", groupe, "BOTTOMRIGHT", -8, 36)
    page.depot.fond = UI.Aplat(page.depot, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.06 })
    page.depot.fond:SetAllPoints(page.depot)
    UI.BordureFine(page.depot, 0.35)
    page.depot.texte = UI.Texte(page.depot, "", UI.C.discret)
    UI.Police(page.depot.texte, 11)
    page.depot.texte:SetPoint("LEFT", page.depot, "LEFT", 8, 0)
    page.depot.texte:SetPoint("RIGHT", page.depot, "RIGHT", -8, 0)
    page.depot.texte:SetJustifyH("CENTER")
    UI.Glisser.Cible(page.depot, function(objet)
        local ok = objet and objet.categorie == "etats" and type(objet.element) == "table"
        return ok, "dépose ici : l'état va à tous les cochés"
    end, function(objet) page.etats:AppliquerCoches(objet.element) end)

    function page:AfficherCoches()
        local n = #self:Coches()
        if self.compact then
            self.depot.texte:SetText(n > 0 and string.format("Lâcher ici : aux %d coché%s", n, n > 1 and "s" or "")
                or "Coche, puis lâche ici")
        else
            self.depot.texte:SetText(n > 0
                and string.format("Lâche un état ici : il va aux %d coché%s", n, n > 1 and "s" or "")
                or "Coche des joueurs, puis lâche un état ici pour tous")
        end
        local c = n > 0 and UI.C.texte or UI.C.discret
        self.depot.texte:SetTextColor(c[1], c[2], c[3])
        self.depot.fond:SetAlpha(n > 0 and 1 or 0.4)
    end

    local xp = UI.Fenetre("xp_groupe", "Attribuer de l'expérience", 570, 470,
        { x = 90, y = 20 })
    page.xpPanneau = xp
    xp.selection = {}
    -- De l'XP de PERSONNAGE ou de METIER (le MJ, 2 novembre 2026). Pour un
    -- metier, en XP ou en NIVEAUX : « donner un niveau de metier ». Le choix
    -- vit dans la fenetre, en memoire, comme les coches.
    xp.mode, xp.unite = "personnage", "xp"

    local function Bascule(libelle, largeur, onClick)
        local b = UI.Bouton(xp.contenu, libelle, largeur, 22, onClick)
        return b
    end
    xp.modePersonnage = Bascule("Personnage", 100, function() xp:Mode("personnage") end)
    xp.modePersonnage:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 0, -2)
    xp.modeMetier = Bascule("Métier", 100, function() xp:Mode("metier") end)
    xp.modeMetier:SetPoint("LEFT", xp.modePersonnage, "RIGHT", 6, 0)
    -- Les metiers, rangés par categorie, comme la fenetre Metiers.
    xp.metier = UI.Deroulant(xp.contenu, 220, 22, function()
        local options = {}
        for _, categorie in ipairs(LCM.Metiers.Categories()) do
            for _, metier in ipairs(categorie.metiers) do
                options[#options + 1] = { id = metier.id, label = metier.label }
            end
        end
        return options
    end, function(id)
        xp.metierId = id
        xp:Remplir(false)
    end)
    xp.metier:SetPoint("LEFT", xp.modeMetier, "RIGHT", 14, 0)

    xp.montantLabel = UI.Texte(xp.contenu, "XP à attribuer :", UI.C.libelle)
    xp.montantLabel:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 0, -38)
    xp.montant = UI.Champ(xp.contenu, 70, 22, nil)
    xp.montant:SetPoint("LEFT", xp.montantLabel, "RIGHT", 8, 0)
    xp.montant:SetNumeric(true)
    xp.uniteXP = Bascule("XP", 46, function() xp:Unite("xp") end)
    xp.uniteXP:SetPoint("LEFT", xp.montant, "RIGHT", 8, 0)
    xp.uniteNiveaux = Bascule("Niveaux", 64, function() xp:Unite("niveaux") end)
    xp.uniteNiveaux:SetPoint("LEFT", xp.uniteXP, "RIGHT", 4, 0)
    xp.raison = UI.Champ(xp.contenu, 170, 22, nil)
    xp.raison:SetPoint("TOPRIGHT", xp.contenu, "TOPRIGHT", -14, -38)
    xp.raisonLabel = UI.Texte(xp.contenu, "Motif :", UI.C.libelle)
    xp.raisonLabel:SetPoint("RIGHT", xp.raison, "LEFT", -8, 0)

    xp.enteteNom = UI.Texte(xp.contenu, "Joueur", UI.C.discret)
    xp.enteteNom:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 32, -72)
    xp.enteteNiveau = UI.Texte(xp.contenu, "Niveau", UI.C.discret)
    xp.enteteNiveau:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 250, -72)
    xp.enteteProgression = UI.Texte(xp.contenu, "Progression XP", UI.C.discret)
    xp.enteteProgression:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 334, -72)

    function xp:Mode(mode)
        self.mode = mode == "metier" and "metier" or "personnage"
        if self.mode == "metier" and not self.metierId then
            local premiere = LCM.Metiers.Categories()[1]
            local metier = premiere and premiere.metiers[1] or LCM.Metiers.list[1]
            self.metierId = metier and metier.id
        end
        if self.mode == "personnage" then self.unite = "xp" end
        self:Remplir(false)
    end

    function xp:Unite(unite)
        self.unite = (self.mode == "metier" and unite == "niveaux") and "niveaux" or "xp"
        self:Remplir(false)
    end

    -- Les bascules et les libelles suivent le mode : ce qu'on voit est ce
    -- qu'on donnera.
    function xp:AfficherMode()
        local metier = self.mode == "metier"
        self.modePersonnage:Selectionner(not metier)
        self.modeMetier:Selectionner(metier)
        self.metier:SetShown(metier)
        if metier then self.metier:Definir(self.metierId) end
        self.uniteXP:SetShown(metier)
        self.uniteNiveaux:SetShown(metier)
        self.uniteXP:Selectionner(self.unite == "xp")
        self.uniteNiveaux:Selectionner(self.unite == "niveaux")
        self.montantLabel:SetText(metier and "À attribuer :" or "XP à attribuer :")
        self.enteteNiveau:SetText(metier and "Palier" or "Niveau")
        self.enteteProgression:SetText(metier and "Progression du métier" or "Progression XP")
        self.envoyer.label:SetText(metier and (self.unite == "niveaux" and "Donner les niveaux"
            or "Attribuer l'XP de métier") or "Attribuer l'XP")
    end

    xp.zone = UI.Defilement(xp.contenu)
    xp.zone:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 0, -92)
    xp.zone:SetPoint("BOTTOMRIGHT", xp.contenu, "BOTTOMRIGHT", 0, 48)
    xp.lignes = {}
    xp.vide = UI.Texte(xp.zone.contenu, "Personne dans le groupe.", UI.C.discret)
    xp.vide:SetPoint("CENTER", xp.zone, "CENTER", 0, 0)

    local function Progression(entity)
        if not entity then return nil end
        local p = LCM.Experience.Progression(entity)
        local debut = 0
        for _, palier in ipairs(LCM.Equilibrage.experience.paliers or {}) do
            if palier.xp <= p.xp then debut = palier.xp else break end
        end
        if not p.prochainXp then return p, 1, 1, "Palier maximal" end
        return p, math.max(0, p.xp - debut), math.max(1, p.prochainXp - debut)
    end

    local function DemanderPourXP(joueur)
        demandesFichesXP[joueur] = true
        local ok = LCM.Fiches.Demander(joueur)
        if not ok then demandesFichesXP[joueur] = nil end
        -- Si le joueur ne répond pas, une consultation manuelle ultérieure ne
        -- doit pas rester silencieuse à cause d'une vieille demande XP.
        if ok and C_Timer and C_Timer.After then
            C_Timer.After(60, function() demandesFichesXP[joueur] = nil end)
        end
        return ok
    end

    local function LigneXP(rang)
        local l = Rangee(xp.zone.contenu, 34)
        l.case = UI.Case(l, "", function(cochee)
            if l.joueur then xp.selection[l.joueur] = cochee or nil end
        end)
        l.case:SetPoint("LEFT", l, "LEFT", 5, 0)
        l.nom = UI.Texte(l, "", UI.C.texte)
        l.nom:SetPoint("LEFT", l, "LEFT", 34, 0)
        l.nom:SetWidth(208)
        l.nom:SetJustifyH("LEFT")
        l.niveau = UI.Texte(l, "Niv. —", UI.C.titre)
        l.niveau:SetPoint("LEFT", l, "LEFT", 250, 0)
        -- « Non appris », « Violet 5 » : un palier de metier est plus long
        -- qu'un « Niv. 5 ».
        l.niveau:SetWidth(78)
        l.niveau:SetJustifyH("LEFT")
        l.niveau:SetWordWrap(false)
        l.barre = UI.Barre(l, { 0.25, 0.52, 0.88, 1 }, 206, 16)
        l.barre:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        xp.lignes[rang] = l
        return l
    end

    function xp:Remplir(redemander)
        local membres = Groupe()
        local presents = {}
        local y = 0
        for rang, joueur in ipairs(membres) do
            presents[joueur] = true
            local l = self.lignes[rang] or LigneXP(rang)
            l.joueur = joueur
            l.nom:SetText(NomPersonnage(joueur))
            l.case:Cocher(self.selection[joueur] == true)
            local entity = FicheJoueur(joueur)
            local progression, courant, maximum, texte = Progression(entity)
            if entity and self.mode == "metier" and self.metierId then
                -- Le palier du metier, dans sa couleur, et la barre du palier.
                local p = LCM.Metiers.Palier(entity, self.metierId)
                l.niveau:SetText(p.libelle)
                local c = p.rang > 0 and p.couleur or UI.C.discret
                l.niveau:SetTextColor(c[1], c[2], c[3])
                if p.max then
                    l.barre:Regler(1, 1)
                    l.barre.label:SetText("Maîtrisé")
                else
                    l.barre:Regler(p.xpDansPalier, p.xpPalier)
                end
            elseif entity then
                l.niveau:SetText("Niv. " .. LCM.Experience.NiveauFiche(entity))
                l.niveau:SetTextColor(UI.C.titre[1], UI.C.titre[2], UI.C.titre[3])
                l.barre:Regler(courant, maximum)
                if texte then l.barre.label:SetText(texte) end
            else
                l.niveau:SetText("Niv. —")
                l.barre:Regler(0, 0)
                l.barre.label:SetText("fiche en attente…")
                if redemander and not EstMoi(joueur) then DemanderPourXP(joueur) end
            end
            Poser(l, self.zone.contenu, y)
            y = y + 34
        end
        for joueur in pairs(self.selection) do
            if not presents[joueur] then self.selection[joueur] = nil end
        end
        for rang = #membres + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.nombre = #membres
        self.vide:SetShown(#membres == 0)
        self.zone:Regler(y)
        self:AfficherMode()
    end

    xp.tous = UI.Bouton(xp.contenu, "Tout cocher", 110, 22, function()
        for rang = 1, xp.nombre or 0 do
            local l = xp.lignes[rang]
            xp.selection[l.joueur] = true
            l.case:Cocher(true)
        end
    end)
    xp.tous:SetPoint("BOTTOMLEFT", xp.contenu, "BOTTOMLEFT", 0, 4)
    xp.envoyer = UI.Bouton(xp.contenu, "Attribuer l'XP", 145, 24, function()
        local montant = math.floor(tonumber(xp.montant:GetText()) or 0)
        if montant <= 0 then LCM.Alerte("indique d'abord combien d'expérience.") return end
        local cibles = {}
        for rang = 1, xp.nombre or 0 do
            local l = xp.lignes[rang]
            if l.case:EstCochee() then cibles[#cibles + 1] = l.joueur end
        end
        if #cibles == 0 then LCM.Alerte("coche au moins un joueur.") return end
        if xp.mode == "metier" then xp:EnvoyerMetier(montant, cibles) return end
        local envoyes = 0
        for _, joueur in ipairs(cibles) do
            local estMoi = EstMoi(joueur)
            local resultat, raison
            if estMoi then
                resultat, raison = LCM.Experience.Donner(FicheJoueur(joueur), montant,
                    xp.raison:GetText())
            else
                resultat, raison = LCM.Experience.Envoyer(joueur, montant, xp.raison:GetText())
            end
            local ok = resultat ~= nil and resultat ~= false
            if ok then
                envoyes = envoyes + 1
                if estMoi then
                    if LCM.UI.Experience and LCM.UI.Experience.Afficher then
                        LCM.UI.Experience.Afficher(montant, xp.raison:GetText(), resultat)
                    end
                else
                    -- Retour visuel immediat. Ne pas redemander toute la fiche
                    -- juste derriere : en attribution multiple cela doublait
                    -- la rafale de messages et pouvait faire jeter les gains
                    -- par le serveur avant leur reception.
                    local entity = FicheJoueur(joueur)
                    if entity then entity.xp = LCM.Experience.Total(entity) + montant end
                end
            elseif raison then
                LCM.Alerte(string.format("%s : %s", joueur, tostring(raison)))
            end
        end
        if envoyes > 0 then
            LCM.Ok(string.format("%d XP envoyés à %d joueur%s.", montant, envoyes,
                envoyes > 1 and "s" or ""))
            xp.montant:SetText("")
            xp.selection = {}
            xp:Hide()
        end
    end)
    xp.envoyer:SetPoint("BOTTOMRIGHT", xp.contenu, "BOTTOMRIGHT", 0, 4)

    -- L'XP de metier : en XP, ou en niveaux que la fiche du joueur convertit
    -- elle-meme (Core/Metiers.lua, Metiers.Donner).
    function xp:EnvoyerMetier(montant, cibles)
        local metier = LCM.Metiers.Get(self.metierId)
        if not metier then LCM.Alerte("choisis d'abord un métier.") return end
        local niveaux = self.unite == "niveaux" and montant or 0
        local enXP = self.unite == "niveaux" and 0 or montant
        local raisonTexte = self.raison:GetText()
        local envoyes = 0
        for _, joueur in ipairs(cibles) do
            local resultat, raison
            if EstMoi(joueur) then
                resultat, raison = LCM.Metiers.Donner(FicheJoueur(joueur), metier.id, enXP, niveaux)
                if resultat then LCM.Metiers.Annoncer(metier.id, resultat, nil, raisonTexte) end
            else
                resultat, raison = LCM.Metiers.Envoyer(joueur, metier.id, enXP, niveaux, raisonTexte)
                -- Retour visuel immediat sur la copie connue, sans annonce :
                -- la vraie conversion se fait chez le joueur.
                local entity = resultat and FicheJoueur(joueur)
                if entity then LCM.Metiers.Donner(entity, metier.id, enXP, niveaux) end
            end
            if resultat then envoyes = envoyes + 1
            elseif raison then LCM.Alerte(string.format("%s : %s", NomPersonnage(joueur), tostring(raison))) end
        end
        if envoyes > 0 then
            if niveaux > 0 then
                LCM.Ok(string.format("%d niveau%s de %s donné%s à %d joueur%s.", niveaux,
                    niveaux > 1 and "x" or "", metier.label, niveaux > 1 and "s" or "",
                    envoyes, envoyes > 1 and "s" or ""))
            else
                LCM.Ok(string.format("%d XP de %s envoyés à %d joueur%s.", enXP, metier.label,
                    envoyes, envoyes > 1 and "s" or ""))
            end
            self.montant:SetText("")
            self.selection = {}
            self:Hide()
        end
    end

    -- Les coches du groupe arrivent deja cochees : on a choisi ses joueurs
    -- une fois, dans le panneau, pas une fois par fenetre.
    local function SelectionDuGroupe()
        local selection = {}
        for _, joueur in ipairs(page:Coches()) do selection[joueur] = true end
        return selection
    end

    function xp:Ouvrir()
        self.selection = SelectionDuGroupe()
        self:Remplir(true)
        self:Show()
        self:Raise()
    end

    -- Regain de groupe : ressources generales sur une ligne, puis les cinq
    -- zones de PV sur une seconde. Cette separation garde les choix lisibles
    -- sans transformer la fenetre en grille compacte.
    local regain = UI.Fenetre("regain_groupe", "Regain des ressources", 640, 520,
        { x = 105, y = 20 })
    page.regainPanneau = regain
    regain.selection = {}
    regain.ressources = {}

    regain.enteteNom = UI.Texte(regain.contenu, "Personnage", UI.C.discret)
    regain.enteteNom:SetPoint("TOPLEFT", regain.contenu, "TOPLEFT", 32, -2)
    regain.enteteJauges = UI.Texte(regain.contenu, "Ressources actuelles", UI.C.discret)
    regain.enteteJauges:SetPoint("TOPLEFT", regain.contenu, "TOPLEFT", 220, -2)
    regain.zone = UI.Defilement(regain.contenu)
    regain.zone:SetPoint("TOPLEFT", regain.contenu, "TOPLEFT", 0, -24)
    regain.zone:SetPoint("BOTTOMRIGHT", regain.contenu, "BOTTOMRIGHT", 0, 184)
    regain.lignes = {}
    regain.vide = UI.Texte(regain.zone.contenu, "Personne dans le groupe.", UI.C.discret)
    regain.vide:SetPoint("CENTER", regain.zone, "CENTER", 0, 0)

    local function EtatJauge(entity, id)
        local j = entity and LCM.Regain.Etat(entity, id)
        return j and string.format("%d/%d", j.current, j.max) or "—/—"
    end

    local function LigneRegain(rang)
        local l = Rangee(regain.zone.contenu, 58)
        l.case = UI.Case(l, "", function(cochee)
            if l.joueur then regain.selection[l.joueur] = cochee or nil end
        end)
        l.case:SetPoint("LEFT", l, "LEFT", 5, 0)
        l.nom = UI.Texte(l, "", UI.C.texte)
        l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", 34, -5)
        l.nom:SetWidth(176)
        l.nom:SetJustifyH("LEFT")
        l.jauges = UI.Texte(l, "", UI.C.titre)
        l.jauges:SetPoint("TOPLEFT", l, "TOPLEFT", 220, -5)
        l.jauges:SetPoint("TOPRIGHT", l, "TOPRIGHT", -8, -5)
        l.jauges:SetJustifyH("LEFT")
        l.detail = UI.Texte(l, "", UI.C.discret, "GameFontNormalSmall")
        l.detail:SetPoint("TOPLEFT", l, "TOPLEFT", 34, -30)
        l.detail:SetPoint("TOPRIGHT", l, "TOPRIGHT", -8, -30)
        regain.lignes[rang] = l
        return l
    end

    function regain:Remplir(redemander)
        local membres, presents, y = Groupe(), {}, 0
        for rang, joueur in ipairs(membres) do
            presents[joueur] = true
            local l = self.lignes[rang] or LigneRegain(rang)
            l.joueur = joueur
            l.nom:SetText(NomPersonnage(joueur))
            l.case:Cocher(self.selection[joueur] == true)
            local entity = FicheJoueur(joueur)
            if entity then
                l.jauges:SetText(string.format("Fatigue %s   ·   PA %s   ·   Bouclier %s",
                    EtatJauge(entity, "fatigue"), EtatJauge(entity, "pa"), EtatJauge(entity, "armure")))
                l.detail:SetText(string.format("PV  Tête %s  ·  Torse %s  ·  Bras %s  ·  Jambes %s  ·  Internes %s",
                    EtatJauge(entity, "pv_tete"), EtatJauge(entity, "pv_buste"),
                    EtatJauge(entity, "pv_bras"), EtatJauge(entity, "pv_jambe"),
                    EtatJauge(entity, "pv_internes")))
            else
                l.jauges:SetText("Fatigue —/—   ·   PA —/—   ·   Bouclier —/—")
                l.detail:SetText("fiche en attente…")
                if redemander and not EstMoi(joueur) then DemanderPourXP(joueur) end
            end
            Poser(l, self.zone.contenu, y)
            y = y + 58
        end
        for joueur in pairs(self.selection) do
            if not presents[joueur] then self.selection[joueur] = nil end
        end
        for rang = #membres + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.nombre = #membres
        self.vide:SetShown(#membres == 0)
        self.zone:Regler(y)
    end

    regain.ressourceTitre = UI.Texte(regain.contenu, "Ressources concernées :", UI.C.libelle)
    regain.ressourceTitre:SetPoint("BOTTOMLEFT", regain.contenu, "BOTTOMLEFT", 0, 148)
    local ressourcesUI = {
        { id = "fatigue", label = "Fatigue", x = 0 },
        { id = "pa", label = "PA", x = 145 },
        { id = "armure", label = "Bouclier", x = 250 },
    }
    regain.casesRessources = {}
    for _, def in ipairs(ressourcesUI) do
        local id = def.id
        local case = UI.Case(regain.contenu, def.label, function(cochee)
            regain.ressources[id] = cochee or nil
        end)
        case:SetPoint("BOTTOMLEFT", regain.contenu, "BOTTOMLEFT", def.x, 120)
        regain.casesRessources[id] = case
    end

    regain.pvTitre = UI.Texte(regain.contenu, "PV :", UI.C.libelle)
    regain.pvTitre:SetPoint("BOTTOMLEFT", regain.contenu, "BOTTOMLEFT", 0, 88)
    for _, def in ipairs({
        { id = "pv_tete", label = "Tête", x = 48 },
        { id = "pv_buste", label = "Torse", x = 145 },
        { id = "pv_bras", label = "Bras", x = 242 },
        { id = "pv_jambe", label = "Jambes", x = 339 },
        { id = "pv_internes", label = "Internes", x = 452 },
    }) do
        local id = def.id
        local case = UI.Case(regain.contenu, def.label, function(cochee)
            regain.ressources[id] = cochee or nil
        end)
        case:SetPoint("BOTTOMLEFT", regain.contenu, "BOTTOMLEFT", def.x, 82)
        regain.casesRessources[id] = case
    end

    regain.modeTitre = UI.Texte(regain.contenu, "Valeur appliquée :", UI.C.libelle)
    regain.modeTitre:SetPoint("BOTTOMLEFT", regain.contenu, "BOTTOMLEFT", 0, 56)
    regain.modes = {}
    local function ChoisirMode(mode)
        regain.mode = mode
        for id, bouton in pairs(regain.modes) do bouton:Selectionner(id == mode) end
        regain.montant:SetAlpha(mode == "exact" and 1 or 0.55)
    end
    regain.modes.max = UI.Bouton(regain.contenu, "Max", 82, 22, function() ChoisirMode("max") end)
    regain.modes.max:SetPoint("BOTTOMLEFT", regain.contenu, "BOTTOMLEFT", 116, 48)
    regain.modes.min = UI.Bouton(regain.contenu, "Min", 82, 22, function() ChoisirMode("min") end)
    regain.modes.min:SetPoint("LEFT", regain.modes.max, "RIGHT", 8, 0)
    regain.modes.exact = UI.Bouton(regain.contenu, "Chiffre précis", 116, 22, function() ChoisirMode("exact") end)
    regain.modes.exact:SetPoint("LEFT", regain.modes.min, "RIGHT", 8, 0)
    -- Pas de SetNumeric : il refuse le signe moins, et un chiffre negatif
    -- RETIRE des points (le MJ, 23 octobre 2026). La lecture est faite a la
    -- validation, qui refuse ce qui n'est pas un nombre entier.
    regain.montant = UI.Champ(regain.contenu, 72, 22, nil)
    regain.montant:SetMaxLetters(6)
    -- Cliquer dans le champ choisit « Chiffre précis » : un geste, pas deux.
    regain.montant:HookScript("OnEditFocusGained", function() ChoisirMode("exact") end)
    regain.montant:SetPoint("LEFT", regain.modes.exact, "RIGHT", 8, 0)

    regain.tous = UI.Bouton(regain.contenu, "Tout cocher", 110, 22, function()
        for rang = 1, regain.nombre or 0 do
            local l = regain.lignes[rang]
            regain.selection[l.joueur] = true
            l.case:Cocher(true)
        end
    end)
    regain.tous:SetPoint("BOTTOMLEFT", regain.contenu, "BOTTOMLEFT", 0, 4)
    regain.envoyer = UI.Bouton(regain.contenu, "Valider le regain", 145, 24, function()
        local cibles = {}
        for rang = 1, regain.nombre or 0 do
            local l = regain.lignes[rang]
            if l.case:EstCochee() then cibles[#cibles + 1] = l.joueur end
        end
        if #cibles == 0 then LCM.Alerte("coche au moins un personnage.") return end
        if not next(regain.ressources) then LCM.Alerte("coche au moins une ressource.") return end
        if not regain.mode then LCM.Alerte("choisis Max, Min ou Chiffre précis.") return end
        local saisi = tonumber((tostring(regain.montant:GetText() or ""):gsub("%s", "")))
        if regain.mode == "exact" and (not saisi or saisi ~= math.floor(saisi) or saisi == 0) then
            LCM.Alerte("indique un nombre entier : positif pour donner, négatif pour retirer.")
            return
        end
        local montant = saisi or 0

        local envoyes = 0
        for _, joueur in ipairs(cibles) do
            local ok, raison = regain.AppliquerA(joueur, regain.ressources, regain.mode, montant)
            if ok then envoyes = envoyes + 1 elseif raison then LCM.Alerte(joueur .. " : " .. tostring(raison)) end
        end
        if envoyes > 0 then
            LCM.Ok(string.format("Regain envoyé à %d personnage%s.", envoyes, envoyes > 1 and "s" or ""))
            regain.selection = {}
            regain:Hide()
        end
    end)
    regain.envoyer:SetPoint("BOTTOMRIGHT", regain.contenu, "BOTTOMRIGHT", 0, 4)

    -- Un regain sur UN personnage : la fenetre (sur les coches) et le detail
    -- de la page Groupe (sur le choisi) passent par la meme porte.
    function regain.AppliquerA(joueur, ressources, mode, montant)
        if EstMoi(joueur) then
            local resultat, raison = LCM.Regain.Appliquer(FicheJoueur(joueur), ressources, mode, montant)
            if resultat ~= nil and LCM.UI.Regain then LCM.UI.Regain.Afficher(resultat) end
            return resultat ~= nil, raison
        end
        local ok, raison = LCM.Regain.Envoyer(joueur, ressources, mode, montant)
        if ok then
            -- Retour visuel immediat sur la copie : la fiche fraiche suivra.
            local entity = FicheJoueur(joueur)
            if entity then LCM.Regain.Appliquer(entity, ressources, mode, montant) end
        end
        return ok, raison
    end

    function regain:Ouvrir()
        self.selection = SelectionDuGroupe()
        self.ressources = {}
        self.mode = nil
        self.montant:SetText("")
        for _, case in pairs(self.casesRessources) do case:Cocher(false) end
        for _, bouton in pairs(self.modes) do bouton:Selectionner(false) end
        self.montant:SetAlpha(0.55)
        self:Remplir(true)
        self:Show()
        self:Raise()
    end

    -- Alias conserve pour les appels existants du banc ou d'autres modules :
    -- le motif appartient desormais au panneau XP, plus au bandeau Joueurs.
    page.raison = xp.raison

    -- La liste du groupe : entre le titre et la zone de depot.
    page.zone = UI.Defilement(groupe)
    page.zone:SetPoint("TOPLEFT", groupe, "TOPLEFT", 6, -groupe.haut)
    page.zone:SetPoint("BOTTOMRIGHT", page.depot, "TOPRIGHT", 0, 8)
    page.lignes = {}
    page.vide = UI.Texte(groupe, "", UI.C.discret)
    UI.Police(page.vide, 11)
    page.vide:SetPoint("CENTER", page.zone, "CENTER", 0, 0)

    -- Une ligne par personnage : sa case, son nom, ce qu'on sait de lui. Un
    -- clic la choisit (colonne de droite), un etat lache dessus lui est pose.
    -- Consulter et Reedition sont passes dans le detail : sur la ligne, ils
    -- mangeaient la place du nom pour un geste qu'on fait rarement.
    local HAUTEUR_LIGNE = 40
    local function Ligne(rang)
        local l = CreateFrame("Button", nil, page.zone.contenu)
        l:SetHeight(HAUTEUR_LIGNE - 2)
        if UI.SurfaceLigne then UI.SurfaceLigne(l) end
        l.choisi = UI.Aplat(l, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.9 }, "OVERLAY")
        l.choisi:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
        l.choisi:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT", 0, 0)
        l.choisi:SetWidth(3)
        l.choisi:Hide()
        l.case = UI.Case(l, "", function(cochee)
            if l.joueur then page.selection[l.joueur] = cochee or nil end
            page:AfficherCoches()
        end)
        l.case:SetPoint("LEFT", l, "LEFT", 6, 0)
        l.nom = UI.Texte(l, "", UI.C.texte)
        UI.Police(l.nom, 12)
        l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", 32, -5)
        l.nom:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        l.nom:SetJustifyH("LEFT")
        l.nom:SetWordWrap(false)
        l.detail = UI.Texte(l, "", UI.C.discret)
        UI.Police(l.detail, 10)
        l.detail:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -2)
        l.detail:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        l.detail:SetJustifyH("LEFT")
        l.detail:SetWordWrap(false)
        l:SetScript("OnClick", function(ligne) page.etats:ChoisirJoueur(ligne.joueur) end)
        UI.Glisser.Cible(l, function(objet)
            return objet and objet.categorie == "etats" and type(objet.element) == "table",
                "dépose ici un état du compendium"
        end, function(objet)
            page.etats:Appliquer(l.joueur, objet.element)
        end)
        page.lignes[rang] = l
        return l
    end

    -- Ce qu'on sait d'un joueur, sans rien lui demander : l'addon vu ou non,
    -- et ce que dit sa derniere fiche recue.
    local function Detail(joueur)
        local morceaux = {}
        local present = LCM.Presence and LCM.Presence.Confirmee and LCM.Presence.Confirmee(joueur)
        local entity, perimee = FicheJoueur(joueur)
        if entity then
            local niveau = tonumber(LCM.Entities.Get_Value(entity, "niveau")) or 1
            morceaux[#morceaux + 1] = string.format("niv. %d", niveau)
            local courant, maximum = LCM.Body.Totals(entity)
            morceaux[#morceaux + 1] = string.format("PV %d / %d", courant, maximum)
        elseif perimee then
            morceaux[#morceaux + 1] = "fiche périmée"
        else
            morceaux[#morceaux + 1] = "fiche pas encore consultée"
        end
        if not EstMoi(joueur) then
            morceaux[#morceaux + 1] = present and "addon présent" or "addon non confirmé"
        end
        return table.concat(morceaux, "  ·  ")
    end
    page.Detail = Detail

    -- ----- colonne de droite : le personnage choisi ------------------------
    local detail = page.colDetail
    page.nomChoisi = UI.Texte(detail, "", UI.C.titre)
    UI.Police(page.nomChoisi, 14)
    page.nomChoisi:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -detail.haut)
    page.nomChoisi:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
    page.nomChoisi:SetJustifyH("LEFT")
    page.nomChoisi:SetWordWrap(false)
    page.detailChoisi = UI.Texte(detail, "", UI.C.discret)
    UI.Police(page.detailChoisi, 10)
    page.detailChoisi:SetPoint("TOPLEFT", page.nomChoisi, "BOTTOMLEFT", 0, -3)
    page.detailChoisi:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
    page.detailChoisi:SetJustifyH("LEFT")

    -- Consulter et Reedition restent TOUJOURS a leur place (le MJ, 2 novembre
    -- 2026) : un bouton qui apparait et disparait se cherche. Sans joueur
    -- choisi, ils le disent ; Reedition sur soi, c'est Creation qui refuse,
    -- avec sa raison.
    local function Choisi()
        local cible = page.etats.joueurActif
        if not cible then LCM.Alerte("choisis d'abord un personnage dans le groupe.") end
        return cible
    end
    page.consulter = UI.Bouton(detail, "Consulter", 114, 22, function()
        local cible = Choisi()
        if not cible then return end
        local entity = FicheJoueur(cible)
        if entity then
            MJ.Consultation.Ouvrir(entity, "fiche", not EstMoi(cible) and cible or nil)
            if not EstMoi(cible) then LCM.Fiches.Demander(cible) end
            return
        end
        if EstMoi(cible) then
            LCM.Alerte("aucun personnage actif.")
            return
        end
        local ok, raison = LCM.Fiches.Demander(cible)
        if not ok then LCM.Alerte(tostring(raison)) return end
        LCM.Info(string.format("fiche demandee a %s…", cible))
    end)
    page.consulter:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -(detail.haut + 38))
    page.reedition = UI.Bouton(detail, "Réédition", 114, 22, function()
        local cible = Choisi()
        if not cible then return end
        local ok, raison = LCM.Creation.EnvoyerJeton(cible)
        if not ok then LCM.Alerte(tostring(raison)) return end
        -- La réception répondra : on distingue ainsi « envoyé » de
        -- « réellement remis au personnage ».
        LCM.Info(string.format("jeton de réédition envoyé à %s…", tostring(cible)))
    end)
    page.reedition:SetPoint("LEFT", page.consulter, "RIGHT", 6, 0)
    UI.Bulle(page.reedition, "Jeton de réédition",
        "Permet au joueur de rouvrir sa création une fois.")

    -- ----- le regain, sur le personnage choisi -----------------------------
    -- Tout ce que la fenetre Regain offrait, ici (le MJ, 2 novembre 2026) :
    -- les ressources actuelles, celles qu'on touche, Max / Min / chiffre
    -- precis. La fenetre reste pour le regain de GROUPE (bouton Regain… sous
    -- la liste, sur les coches) ; ici, c'est le cas d'un seul, sans detour.
    local function SousTitre(texte, y)
        local t = UI.Texte(detail, UI.Majuscules(texte), UI.C.libelle, "GameFontNormalSmall")
        UI.Police(t, 10)
        t:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -y)
        local filet = UI.Filet(detail, true)
        filet:SetPoint("TOPLEFT", detail, "TOPLEFT", 6, -(y + 15))
        filet:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -6, -(y + 15))
        t.filet = filet
        return t
    end
    local yRegain = detail.haut + 68
    page.titreRegain = SousTitre("Ressources", yRegain)

    page.regain = { ressources = {}, cases = {}, valeurs = {}, ordre = {} }
    local regainDetail = page.regain
    -- « Tout » coche les huit, ou les decoche si elles l'etaient deja.
    regainDetail.tout = UI.Bouton(detail, "Tout", 44, 16, function()
        local tout = true
        for _, def in ipairs(LCM.Regain.RESSOURCES) do
            if not regainDetail.ressources[def.cle] then tout = false end
        end
        for _, def in ipairs(LCM.Regain.RESSOURCES) do
            regainDetail.ressources[def.cle] = (not tout) or nil
            regainDetail.cases[def.cle]:Cocher(not tout)
        end
    end)
    regainDetail.tout:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -8, -(yRegain - 2))

    local yLigne = yRegain + 21
    for _, def in ipairs(LCM.Regain.RESSOURCES) do
        local cle = def.cle
        local case = UI.Case(detail, def.label, function(cochee)
            regainDetail.ressources[cle] = cochee or nil
        end)
        case:SetPoint("TOPLEFT", detail, "TOPLEFT", 10, -yLigne)
        UI.Police(case.label, 11)
        local valeur = UI.Texte(detail, "—/—", UI.C.discret, "GameFontNormalSmall")
        UI.Police(valeur, 11)
        valeur:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
        valeur:SetPoint("TOP", case, "TOP", 0, -2)
        valeur:SetJustifyH("RIGHT")
        regainDetail.cases[cle], regainDetail.valeurs[cle] = case, valeur
        regainDetail.ordre[#regainDetail.ordre + 1] = def
        yLigne = yLigne + 20
    end

    -- Le mode, puis Valider : une ressource ne se vide pas sur un clic
    -- egare, il faut le geste en deux temps de l'ancienne fenetre.
    regainDetail.modes = {}
    local function ChoisirMode(mode)
        regainDetail.mode = mode
        for id, bouton in pairs(regainDetail.modes) do bouton:Selectionner(id == mode) end
        regainDetail.montant:SetAlpha(mode == "exact" and 1 or 0.55)
    end
    regainDetail.ChoisirMode = ChoisirMode
    local yMode = yLigne + 4
    regainDetail.modes.max = UI.Bouton(detail, "Max", 50, 22, function() ChoisirMode("max") end)
    regainDetail.modes.max:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -yMode)
    regainDetail.modes.min = UI.Bouton(detail, "Min", 50, 22, function() ChoisirMode("min") end)
    regainDetail.modes.min:SetPoint("LEFT", regainDetail.modes.max, "RIGHT", 4, 0)
    regainDetail.modes.exact = UI.Bouton(detail, "Chiffre", 66, 22, function() ChoisirMode("exact") end)
    regainDetail.modes.exact:SetPoint("LEFT", regainDetail.modes.min, "RIGHT", 4, 0)
    UI.Bulle(regainDetail.modes.exact, "Chiffre précis",
        "Ajoute le nombre saisi à droite. Négatif : retire des points.")
    -- Pas de SetNumeric : il refuse le signe moins, et un chiffre negatif
    -- RETIRE des points (le MJ, 23 octobre 2026).
    regainDetail.montant = UI.Champ(detail, 10, 22, nil)
    regainDetail.montant:SetMaxLetters(6)
    regainDetail.montant:SetJustifyH("CENTER")
    regainDetail.montant:SetPoint("LEFT", regainDetail.modes.exact, "RIGHT", 4, 0)
    regainDetail.montant:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
    regainDetail.montant:SetAlpha(0.55)
    -- Cliquer dans le champ, c'est vouloir un chiffre (le MJ, 2 novembre
    -- 2026) : le champ etait DESACTIVE tant qu'on n'avait pas choisi
    -- « Chiffre », et il fallait deux clics pour un geste.
    regainDetail.montant:HookScript("OnEditFocusGained", function() ChoisirMode("exact") end)

    regainDetail.valider = UI.Bouton(detail, "Valider le regain", 10, 22, function()
        local cible = Choisi()
        if not cible then return end
        if not next(regainDetail.ressources) then LCM.Alerte("coche au moins une ressource.") return end
        local mode = regainDetail.mode
        if not mode then LCM.Alerte("choisis Max, Min ou Chiffre.") return end
        local saisi = tonumber((tostring(regainDetail.montant:GetText() or ""):gsub("%s", "")))
        if mode == "exact" and (not saisi or saisi ~= math.floor(saisi) or saisi == 0) then
            LCM.Alerte("indique un nombre entier : positif pour donner, négatif pour retirer.")
            return
        end
        local ok, raison = page.regainPanneau.AppliquerA(cible, regainDetail.ressources, mode, saisi or 0)
        if not ok then
            if raison then LCM.Alerte(tostring(raison)) end
            return
        end
        LCM.Ok(string.format("regain envoyé à %s.", NomPersonnage(cible)))
        page:AfficherDetail()
    end)
    regainDetail.valider:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -(yMode + 28))
    regainDetail.valider:SetPoint("RIGHT", detail, "RIGHT", -8, 0)

    local yActifs = yMode + 60
    page.titreActifs = SousTitre("États portés", yActifs)
    page.hautActifs = yActifs + 20

    page.etats = CreateFrame("Frame", nil, page)
    page.etats:SetAllPoints(page)
    ConstruireEtats(page.etats, page)

    -- ----- deux mises en page : etendue, compacte ---------------------------
    -- La meme page sert les deux fenetres (Ecran.Compact) : un seul code pour
    -- poser un etat ou faire un regain, deux densites. La compacte doit etre
    -- « la plus petite possible » (le MJ, 2 novembre 2026) : colonnes sans
    -- titre, lignes de 20, police de 9 a 11, ressources sur deux colonnes avec
    -- leur valeur collee au nom, le regain sur une rangee. Tous les nombres
    -- de mise en page sont ICI, des deux cotes, pour se comparer d'un coup.
    local COURT = { fatigue = "Fatigue", pa = "PA", armure = "Bouclier", pv_tete = "Tête",
        pv_buste = "Torse", pv_bras = "Bras", pv_jambe = "Jambes", pv_internes = "Internes" }
    local ETENDU = {
        catalogue = 232, detail = 250, ecart = 10, marge = 8, haut = 30,
        ligne = HAUTEUR_LIGNE, case = 18, policeNom = 12, decalNom = 32,
        depot = 38, policeDepot = 11, tous = { 80, 22 }, policeBouton = 12,
        bouton = { 114, 22 }, nom = 14, regain = 20, caseRes = 18, policeRes = 11,
        mode = { 50, 22 }, montant = 0, sousTitre = 10,
    }
    local COMPACT = {
        catalogue = 150, detail = 186, ecart = 6, marge = 5, haut = 4,
        ligne = 22, case = 14, policeNom = 11, decalNom = 24,
        depot = 30, policeDepot = 9, tous = { 64, 18 }, policeBouton = 10,
        bouton = { 80, 18 }, nom = 11, regain = 16, caseRes = 13, policeRes = 9,
        mode = { 32, 18 }, montant = 40, sousTitre = 9,
    }
    page.hauteurLigne = HAUTEUR_LIGNE

    local function PlacerSousTitre(t, y, K)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", detail, "TOPLEFT", K.marge, -y)
        UI.Police(t, K.sousTitre)
        t.filet:ClearAllPoints()
        t.filet:SetPoint("TOPLEFT", detail, "TOPLEFT", K.marge - 2, -(y + K.sousTitre + 4))
        t.filet:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -(K.marge - 2), -(y + K.sousTitre + 4))
    end

    local function Taille(bouton, dims, police)
        bouton:SetSize(dims[1], dims[2])
        if police then UI.Police(bouton.label, police) end
    end

    function page:FormeLigne(l)
        local K = self.compact and COMPACT or ETENDU
        l:SetHeight(K.ligne - 2)
        l.case:SetSize(K.case, K.case)
        l.case:ClearAllPoints()
        l.case:SetPoint("LEFT", l, "LEFT", self.compact and 4 or 6, 0)
        UI.Police(l.nom, K.policeNom)
        l.detail:SetShown(not self.compact)
        l.nom:ClearAllPoints()
        if self.compact then
            l.nom:SetPoint("LEFT", l, "LEFT", K.decalNom, 0)
        else
            l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", K.decalNom, -5)
        end
        l.nom:SetPoint("RIGHT", l, "RIGHT", -4, 0)
    end

    function page:Disposer(compact)
        local c = compact and true or false
        self.compact = c
        local K = c and COMPACT or ETENDU
        local h = K.haut

        -- Les colonnes, et leurs titres : en compact, le contenu dit assez
        -- ce qu'est chaque colonne.
        self.colCatalogue:SetWidth(K.catalogue)
        self.colDetail:SetWidth(K.detail)
        self.colGroupe:ClearAllPoints()
        self.colGroupe:SetPoint("TOPLEFT", self.colCatalogue, "TOPRIGHT", K.ecart, 0)
        self.colGroupe:SetPoint("BOTTOMRIGHT", self.colDetail, "BOTTOMLEFT", -K.ecart, 0)
        for _, col in ipairs({ self.colCatalogue, self.colGroupe, self.colDetail }) do
            col.titre:SetShown(not c)
            col.filet:SetShown(not c)
        end

        -- Le groupe. En compact, ni compte ni Rafraichir (la presence se
        -- rafraichit seule), ni les gestes a fenetre (XP, regain de groupe).
        local groupe = self.colGroupe
        self.etat:SetShown(not c)
        self.rafraichir:SetShown(not c)
        self.xpBouton:SetShown(not c)
        self.regainBouton:SetShown(not c)
        self.hauteurLigne = K.ligne
        for _, l in ipairs(self.lignes) do self:FormeLigne(l) end
        Taille(self.tousBouton, K.tous, K.policeBouton)
        self.tousBouton:ClearAllPoints()
        self.tousBouton:SetPoint("BOTTOMLEFT", groupe, "BOTTOMLEFT", K.marge, K.marge)
        self.depot:SetHeight(K.depot)
        self.depot:ClearAllPoints()
        self.depot:SetPoint("BOTTOMLEFT", groupe, "BOTTOMLEFT", K.marge, K.marge + K.tous[2] + 6)
        self.depot:SetPoint("BOTTOMRIGHT", groupe, "BOTTOMRIGHT", -K.marge, K.marge + K.tous[2] + 6)
        UI.Police(self.depot.texte, K.policeDepot)
        self.zone:ClearAllPoints()
        self.zone:SetPoint("TOPLEFT", groupe, "TOPLEFT", K.marge - 2, -h)
        self.zone:SetPoint("BOTTOMRIGHT", self.depot, "TOPRIGHT", 0, K.ecart)

        -- Le personnage.
        UI.Police(self.nomChoisi, K.nom)
        self.nomChoisi:ClearAllPoints()
        self.nomChoisi:SetPoint("TOPLEFT", detail, "TOPLEFT", K.marge, -h)
        self.nomChoisi:SetPoint("RIGHT", detail, "RIGHT", -K.marge, 0)
        self.detailChoisi:SetShown(not c)
        local yBoutons = c and (h + 16) or (h + 38)
        Taille(self.consulter, K.bouton, K.policeBouton)
        Taille(self.reedition, K.bouton, K.policeBouton)
        self.consulter:ClearAllPoints()
        self.consulter:SetPoint("TOPLEFT", detail, "TOPLEFT", K.marge, -yBoutons)
        self.reedition:ClearAllPoints()
        self.reedition:SetPoint("LEFT", self.consulter, "RIGHT", c and 4 or 6, 0)

        local rg = self.regain
        local yRegain = yBoutons + K.bouton[2] + (c and 6 or 8)
        PlacerSousTitre(self.titreRegain, yRegain, K)
        Taille(rg.tout, c and { 34, 14 } or { 44, 16 }, c and 9 or 10)
        rg.tout:ClearAllPoints()
        rg.tout:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -K.marge, -(yRegain - 2))
        local y = yRegain + K.sousTitre + 8
        local demi = math.floor((K.detail - 2 * K.marge) / 2)
        for i, def in ipairs(rg.ordre) do
            local case, valeur = rg.cases[def.cle], rg.valeurs[def.cle]
            case:SetSize(K.caseRes, K.caseRes)
            case:ClearAllPoints()
            valeur:ClearAllPoints()
            case.label:SetText(c and COURT[def.cle] or def.label)
            UI.Police(case.label, K.policeRes)
            UI.Police(valeur, K.policeRes)
            case.label:ClearAllPoints()
            case.label:SetPoint("LEFT", case, "RIGHT", c and 3 or 6, 0)
            case.label:SetWordWrap(false)
            case.label:SetJustifyH("LEFT")
            if c then
                -- Chaque ressource a sa demi-colonne : la valeur s'aligne a
                -- droite de la sienne, le nom s'arrete avant. Collee au nom,
                -- « Bouclier 0/10 » debordait sur la colonne d'a cote
                -- (capture du MJ, 2 novembre 2026).
                local colonne, rang = (i - 1) % 2, math.floor((i - 1) / 2)
                local gauche = K.marge + colonne * demi
                case:SetPoint("TOPLEFT", detail, "TOPLEFT", gauche, -(y + rang * K.regain))
                valeur:SetPoint("TOPRIGHT", detail, "TOPLEFT", gauche + demi - 5, -(y + rang * K.regain + 2))
                valeur:SetJustifyH("RIGHT")
                valeur:SetWordWrap(false)
                case.label:SetPoint("RIGHT", valeur, "LEFT", -2, 0)
            else
                case:SetPoint("TOPLEFT", detail, "TOPLEFT", 10, -(y + (i - 1) * K.regain))
                valeur:SetPoint("RIGHT", detail, "RIGHT", -10, 0)
                valeur:SetPoint("TOP", case, "TOP", 0, -2)
                valeur:SetJustifyH("RIGHT")
            end
        end
        local lignesRes = c and math.ceil(#rg.ordre / 2) or #rg.ordre
        local yMode = y + lignesRes * K.regain + (c and 3 or 4)
        Taille(rg.modes.max, K.mode, K.policeBouton)
        Taille(rg.modes.min, K.mode, K.policeBouton)
        rg.modes.max:ClearAllPoints()
        rg.modes.max:SetPoint("TOPLEFT", detail, "TOPLEFT", K.marge, -yMode)
        -- En compact, pas de bouton « Chiffre » : cliquer dans le champ le
        -- choisit (le MJ, 2 novembre 2026). Il reste en etendu, ou il dit
        -- ce que fait le champ.
        rg.modes.exact:SetShown(not c)
        rg.montant:ClearAllPoints()
        rg.montant:SetHeight(K.mode[2])
        rg.valider:ClearAllPoints()
        rg.valider:SetHeight(K.mode[2])
        UI.Police(rg.valider.label, K.policeBouton)
        if c then
            rg.montant:SetPoint("LEFT", rg.modes.min, "RIGHT", 3, 0)
            rg.montant:SetWidth(K.montant)
            rg.valider:SetPoint("LEFT", rg.montant, "RIGHT", 3, 0)
            rg.valider:SetPoint("RIGHT", detail, "RIGHT", -K.marge, 0)
            rg.valider.label:SetText("OK")
        else
            Taille(rg.modes.exact, { 66, 22 }, K.policeBouton)
            rg.montant:SetPoint("LEFT", rg.modes.exact, "RIGHT", 4, 0)
            rg.montant:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
            rg.valider:SetPoint("TOPLEFT", detail, "TOPLEFT", 8, -(yMode + 28))
            rg.valider:SetPoint("RIGHT", detail, "RIGHT", -8, 0)
            rg.valider.label:SetText("Valider le regain")
        end

        local yActifs = yMode + (c and (K.mode[2] + 6) or 60)
        PlacerSousTitre(self.titreActifs, yActifs, K)
        self.hautActifs = yActifs + K.sousTitre + 8
        local zone = self.etats.zoneActifs
        zone:ClearAllPoints()
        zone:SetPoint("TOPLEFT", detail, "TOPLEFT", c and 2 or 4, -self.hautActifs)
        zone:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", c and -2 or -4, c and 3 or 6)
        self.etats.videActifs:SetWidth(K.detail - 25)

        self.etats:Disposer(c)
        if self:IsVisible() then self:Afficher() end
    end

    function page:AfficherDetail()
        local joueur = self.etats.joueurActif
        local choisi = joueur ~= nil
        self.nomChoisi:SetText(choisi and (NomPersonnage(joueur) .. (EstMoi(joueur) and "  (vous)" or ""))
            or "Aucun personnage choisi")
        local c = choisi and UI.C.titre or UI.C.discret
        self.nomChoisi:SetTextColor(c[1], c[2], c[3])
        self.detailChoisi:SetText(choisi and Detail(joueur) or "Clique un personnage du groupe.")
        -- Les valeurs suivent la derniere fiche connue ; sans fiche, des
        -- tirets, et c'est la consultation qui la fera venir.
        local entity = choisi and FicheJoueur(joueur) or nil
        for _, def in ipairs(LCM.Regain.RESSOURCES) do
            local jauge = entity and LCM.Regain.Etat(entity, def.cle)
            local texte = self.regain.valeurs[def.cle]
            if jauge then
                texte:SetText(string.format(self.compact and "%d/%d" or "%d / %d", jauge.current, jauge.max))
                local couleur = UI.CouleurEtat(jauge.current, jauge.max)
                if jauge.current >= jauge.max then couleur = UI.C.texte end
                texte:SetTextColor(couleur[1], couleur[2], couleur[3])
            else
                texte:SetText("—")
                texte:SetTextColor(UI.C.discret[1], UI.C.discret[2], UI.C.discret[3])
            end
        end
    end

    function page:Afficher()
        local membres = Groupe()
        local y = 0
        for rang, joueur in ipairs(membres) do
            local l = self.lignes[rang] or Ligne(rang)
            l.joueur = joueur
            l.nom:SetText(NomPersonnage(joueur) .. (EstMoi(joueur) and "  (vous)" or ""))
            l.detail:SetText(Detail(joueur))
            l.case:Cocher(self.selection[joueur] == true)
            l.choisi:SetShown(joueur == self.etats.joueurActif)
            self:FormeLigne(l)
            local c = joueur == self.etats.joueurActif and UI.C.accent or UI.C.texte
            l.nom:SetTextColor(c[1], c[2], c[3])
            Poser(l, self.zone.contenu, y)
            y = y + self.hauteurLigne
        end
        local presents = {}
        for _, joueur in ipairs(membres) do presents[joueur] = true end
        for joueur in pairs(self.selection) do
            if not presents[joueur] then self.selection[joueur] = nil end
        end
        for rang = #membres + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.zone:Regler(y)
        self.nombreAffiche = #membres
        self.vide:SetText(#membres > 0 and "" or "Personne dans le groupe.")
        self.etat:SetText(string.format("%d", #membres))
        self:AfficherCoches()
        self.etats:Afficher()
        self:AfficherDetail()
        if self.xpPanneau:IsShown() then self.xpPanneau:Remplir(false) end
        if self.regainPanneau:IsShown() then self.regainPanneau:Remplir(false) end
    end
end

-- ===== Visibilite des traits ===============================================

function Pages.traits(page, f)
    page.titre = Titre(page, "Traits visibles par joueur")
    page.titre:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.aideTraits = UI.Texte(page,
        "Coche les traits que chaque joueur peut consulter dans son compendium et sa création.", UI.C.discret)
    UI.Police(page.aideTraits, 10)
    page.aideTraits:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -20)
    page.aideTraits:SetPoint("RIGHT", page, "RIGHT", -2, 0)
    page.aideTraits:SetJustifyH("LEFT")
    page.joueursZone = UI.Defilement(page)
    page.joueursZone:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -46)
    page.joueursZone:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    page.joueursZone:SetWidth(190)
    page.joueurs = {}
    page.joueurActif = nil
    page.videJoueurs = UI.Texte(page.joueursZone.contenu, "Aucun joueur dans le groupe.", UI.C.discret)
    page.videJoueurs:SetPoint("TOPLEFT", page.joueursZone.contenu, "TOPLEFT", 6, -6)

    -- A droite : une barre (recherche, filtre, compte), des en-tetes de
    -- colonne, puis la liste. Avant (21 octobre 2026), c'etait une colonne de
    -- cases « Nom · 2 pts » sans recherche : trouver un trait parmi une
    -- centaine demandait de tout faire defiler.
    page.droite = CreateFrame("Frame", nil, page)
    page.droite:SetPoint("TOPLEFT", page.joueursZone, "TOPRIGHT", 12, 0)
    page.droite:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    local droite = page.droite

    page.rechercheTraits = UI.Champ(droite, 170, 22, function() page:AfficherTraits() end)
    page.rechercheTraits:SetPoint("TOPLEFT", droite, "TOPLEFT", 74, 0)
    page.rechercheTraits:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    page.rechercheTraits:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    page.rechercheTraits.label = UI.Texte(droite, "Rechercher :", UI.C.libelle)
    page.rechercheTraits.label:SetPoint("RIGHT", page.rechercheTraits, "LEFT", -6, 0)
    UI.Bulle(page.rechercheTraits, "Rechercher un trait",
        "Dans le nom et la description, sans tenir compte des accents ni des majuscules.")

    -- Le filtre : tout, ou seulement ce que le joueur voit, ou ce qu'il ne
    -- voit pas — « qu'est-ce que je lui ai deja ouvert ? » est la question
    -- qu'on se pose en seance.
    page.filtreTraits = "tous"
    page.filtres = UI.Onglets(droite, { { id = "tous", label = "Tous" },
                                        { id = "visibles", label = "Visibles" },
                                        { id = "caches", label = "Cachés" } },
        function(id) page.filtreTraits = id page:AfficherTraits() end, { largeur = 64 })
    page.filtres:SetPoint("TOPLEFT", page.rechercheTraits, "TOPRIGHT", 10, 0)
    page.filtres:SetWidth(3 * 64 + 2 * 4)

    page.compteTraits = UI.Texte(droite, "", UI.C.discret)
    UI.Police(page.compteTraits, 10)
    page.compteTraits:SetPoint("TOPLEFT", droite, "TOPLEFT", 2, -30)

    page.enteteNom = UI.Texte(droite, "TRAIT", UI.C.libelle)
    UI.Police(page.enteteNom, 10)
    page.enteteNom:SetPoint("TOPLEFT", droite, "TOPLEFT", 34, -48)
    page.enteteCout = UI.Texte(droite, "COÛT", UI.C.libelle)
    UI.Police(page.enteteCout, 10)
    page.enteteCout:SetPoint("TOPRIGHT", droite, "TOPRIGHT", -30, -48)

    page.traitsZone = UI.Defilement(droite)
    page.traitsZone:SetPoint("TOPLEFT", droite, "TOPLEFT", 0, -62)
    page.traitsZone:SetPoint("BOTTOMRIGHT", droite, "BOTTOMRIGHT", 0, 0)
    page.lignesTraits = {}
    page.videTraits = UI.Texte(page.traitsZone.contenu, "Choisis un joueur à gauche.", UI.C.discret)
    page.videTraits:SetPoint("TOPLEFT", page.traitsZone.contenu, "TOPLEFT", 6, -6)

    local function Visible(traitId)
        return page.joueurActif ~= nil and MJ.AccesTraits
            and MJ.AccesTraits.Liste(page.joueurActif)[traitId] == true or false
    end

    -- Une ligne entiere se clique, pas seulement sa case : viser un carre de
    -- dix-huit pixels cent fois de suite, c'est ce qui rendait la page penible.
    local function Basculer(ligne)
        if not (page.joueurActif and ligne.traitId and MJ.AccesTraits) then return end
        local cochee = not Visible(ligne.traitId)
        MJ.AccesTraits.Definir(page.joueurActif, ligne.traitId, cochee)
        page:PeindreLigne(ligne, cochee)
        page:Compter()
    end

    local function LigneTrait(rang)
        local l = CreateFrame("Button", nil, page.traitsZone.contenu)
        l:SetHeight(26)
        if UI.SurfaceLigne then UI.SurfaceLigne(l) end
        l.case = UI.Case(l, "", function() Basculer(l) end)
        l.case:SetPoint("LEFT", l, "LEFT", 8, 0)
        l.case.label:Hide()
        l.cout = UI.Texte(l, "", UI.C.titre)
        UI.Police(l.cout, 11)
        l.cout:SetPoint("RIGHT", l, "RIGHT", -14, 0)
        l.cout:SetJustifyH("RIGHT")
        l.cout:SetWidth(50)
        l.nom = UI.Texte(l, "", UI.C.texte)
        UI.Police(l.nom, 12)
        l.nom:SetPoint("LEFT", l.case, "RIGHT", 10, 0)
        l.nom:SetPoint("RIGHT", l.cout, "LEFT", -8, 0)
        l.nom:SetJustifyH("LEFT")
        l.nom:SetWordWrap(false)
        l:SetScript("OnClick", function(self) Basculer(self) end)
        -- La description au survol : la liste reste courte, et on lit le
        -- trait avant de l'ouvrir au joueur.
        l:SetScript("OnEnter", function(self)
            if not self.trait or not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tostring(self.trait.label), 1, 0.82, 0.3)
            local description = tostring(self.trait.description or "")
            if description ~= "" then GameTooltip:AddLine(description, 0.9, 0.9, 0.9, true) end
            GameTooltip:Show()
        end)
        l:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        page.lignesTraits[rang] = l
        return l
    end

    -- Ce qui est ouvert au joueur s'ecrit en clair, le reste s'estompe : on
    -- lit d'un coup d'oeil ce qu'il voit.
    function page:PeindreLigne(l, cochee)
        l.case:Cocher(cochee)
        local c = cochee and UI.C.texte or UI.C.discret
        l.nom:SetTextColor(c[1], c[2], c[3])
    end

    function page:Compter()
        local total, visibles = #LCM.Traits.list, 0
        for _, trait in ipairs(LCM.Traits.list) do
            if Visible(trait.id) then visibles = visibles + 1 end
        end
        self.compteTraits:SetText(self.joueurActif and string.format(
            "%d trait%s affiché%s  ·  %d sur %d visible%s par %s", self.nombreTraits or 0,
            (self.nombreTraits or 0) > 1 and "s" or "", (self.nombreTraits or 0) > 1 and "s" or "",
            visibles, total, visibles > 1 and "s" or "", NomPersonnage(self.joueurActif)) or "")
    end

    function page:ChoisirJoueur(joueur)
        self.joueurActif = joueur
        self:AfficherTraits()
    end

    function page:AfficherTraits()
        self.filtres:Selectionner(self.filtreTraits)
        local recherche = Cherchable(self.rechercheTraits:GetText())
        local liste = {}
        for _, trait in ipairs(LCM.Traits.list) do
            local garde = recherche == ""
                or Cherchable(trait.label):find(recherche, 1, true)
                or Cherchable(trait.description):find(recherche, 1, true)
            if garde and self.filtreTraits ~= "tous" then
                garde = Visible(trait.id) == (self.filtreTraits == "visibles")
            end
            if garde then liste[#liste + 1] = trait end
        end
        table.sort(liste, function(a, b) return Cherchable(a.label) < Cherchable(b.label) end)
        local actif = self.joueurActif ~= nil
        local y = 0
        if actif then
            for rang, trait in ipairs(liste) do
                local l = self.lignesTraits[rang] or LigneTrait(rang)
                l.trait, l.traitId = trait, trait.id
                l.nom:SetText(tostring(trait.label))
                local cout = LCM.Traits.Cout(trait)
                l.cout:SetText(string.format("%d pt%s", cout, cout > 1 and "s" or ""))
                self:PeindreLigne(l, Visible(trait.id))
                Poser(l, self.traitsZone.contenu, y)
                y = y + 28
            end
        end
        for rang = (actif and #liste or 0) + 1, #self.lignesTraits do self.lignesTraits[rang]:Hide() end
        self.nombreTraits = actif and #liste or 0
        self.videTraits:SetText(not actif and "Choisis un joueur à gauche."
            or (#liste == 0 and "Aucun trait ne correspond." or ""))
        self.videTraits:SetShown(not actif or #liste == 0)
        self.traitsZone:Regler(math.max(1, y))
        self:Compter()
    end

    function page:Afficher()
        local membres = {}
        for _, joueur in ipairs(Groupe()) do
            if not EstMoi(joueur) then membres[#membres + 1] = joueur end
        end
        local encore = false
        local y = 0
        for rang, joueur in ipairs(membres) do
            if joueur == self.joueurActif then encore = true end
            local b = self.joueurs[rang]
            if not b then
                b = UI.Bouton(self.joueursZone.contenu, "", 178, 24, function(bouton)
                    page:ChoisirJoueur(bouton.joueur)
                    page:Afficher()
                end)
                self.joueurs[rang] = b
            end
            b.joueur = joueur
            b.label:SetText(NomPersonnage(joueur))
            b:Selectionner(joueur == self.joueurActif)
            b:SetPoint("TOPLEFT", self.joueursZone.contenu, "TOPLEFT", 4, -y)
            b:Show()
            y = y + 28
        end
        for rang = #membres + 1, #self.joueurs do self.joueurs[rang]:Hide() end
        self.joueursZone:Regler(math.max(1, y))
        self.videJoueurs:SetShown(#membres == 0)
        if not encore then self.joueurActif = membres[1] end
        self:AfficherTraits()
    end
end

-- ===== Imposer des etats ===================================================

-- La partie etats de la page Groupe. `page` est l'objet etats (le banc et
-- le reste du compagnon l'appellent `pages.etats`), `proprio` la page Groupe
-- qui lui pretes ses colonnes : le catalogue a gauche, les etats portes dans
-- le detail a droite. La liste des joueurs, elle, est celle du groupe — il
-- n'y a plus de seconde liste de cibles.
ConstruireEtats = function(page, proprio)
    page.proprio = proprio
    local cat = proprio.colCatalogue
    local detail = proprio.colDetail

    page.dureeLabel = UI.Texte(cat, "Durée", UI.C.libelle)
    page.dureeLabel:SetPoint("TOPLEFT", cat, "TOPLEFT", 8, -(cat.haut + 4))
    page.duree = UI.Champ(cat, 46, 20)
    page.duree:SetNumeric(true)
    page.duree:SetText("")
    page.duree:SetJustifyH("CENTER")
    page.duree:SetPoint("LEFT", page.dureeLabel, "RIGHT", 8, 0)
    page.dureeAide = UI.Texte(cat, "rounds · vide : jusqu'au retrait", UI.C.discret)
    UI.Police(page.dureeAide, 9)
    page.dureeAide:SetPoint("LEFT", page.duree, "RIGHT", 6, 0)
    page.dureeAide:SetPoint("RIGHT", cat, "RIGHT", -6, 0)
    page.dureeAide:SetJustifyH("LEFT")
    page.dureeAide:SetWordWrap(false)
    UI.Bulle(page.duree, "Durée de l’état",
        "Nombre de rounds avant expiration. Laisse vide pour un état sans expiration automatique.")

    -- La recherche ne tient compte ni des accents ni des majuscules, et lit
    -- aussi le TYPE : « saign » trouve Saignement, « poison » tout ce qui est
    -- range sous ce type.
    page.recherche = UI.Champ(cat, 10, 20, function() page:Afficher() end)
    page.recherche:SetPoint("TOPLEFT", cat, "TOPLEFT", 8, -(cat.haut + 30))
    page.recherche:SetPoint("RIGHT", cat, "RIGHT", -8, 0)
    page.recherche:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    page.recherche:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    page.recherche.indice = UI.Texte(page.recherche, "Rechercher…", UI.C.discret)
    UI.Police(page.recherche.indice, 10)
    page.recherche.indice:SetPoint("LEFT", page.recherche, "LEFT", 6, 0)
    UI.Bulle(page.recherche, "Rechercher un état",
        "Dans le nom et le type, sans tenir compte des accents ni des majuscules.")

    -- Le filtre : un conteneur (etats divers, maladies, intangibles) ou un
    -- type precis. Sans filtre, le catalogue est CLASSE par type, chaque type
    -- sous son en-tete : c'est ainsi que le MJ pense ses etats.
    page.filtre = "tous"
    local function Options()
        local out = { { id = "tous", label = "Tous les états" } }
        for _, c in ipairs(LCM.Etats.CATEGORIES or {}) do
            out[#out + 1] = { id = "c:" .. c.id, label = c.bloc or c.onglet or c.label }
        end
        local types = {}
        for _, e in ipairs(LCM.Listes.list or {}) do
            if e.liste == "type_etats" then types[#types + 1] = e end
        end
        table.sort(types, function(a, b) return Cherchable(a.label) < Cherchable(b.label) end)
        for _, e in ipairs(types) do
            out[#out + 1] = { id = "t:" .. e.id, label = "   " .. tostring(e.label or e.id) }
        end
        out[#out + 1] = { id = "t:", label = "   Sans type" }
        return out
    end
    page.filtreChoix = UI.Deroulant(cat, 10, 20, Options, function(id)
        page.filtre = id
        page:Afficher()
    end)
    page.filtreChoix:SetPoint("TOPLEFT", cat, "TOPLEFT", 8, -(cat.haut + 56))
    page.filtreChoix:SetPoint("RIGHT", cat, "RIGHT", -8, 0)
    page.filtreChoix:Definir("tous")

    page.compte = UI.Texte(cat, "", UI.C.discret)
    UI.Police(page.compte, 9)
    page.compte:SetPoint("BOTTOMLEFT", cat, "BOTTOMLEFT", 8, 6)
    page.compte:SetPoint("RIGHT", cat, "RIGHT", -8, 0)
    page.compte:SetJustifyH("LEFT")

    page.zoneEtats = UI.Defilement(cat)
    page.zoneEtats:SetPoint("TOPLEFT", cat, "TOPLEFT", 4, -(cat.haut + 84))
    page.zoneEtats:SetPoint("BOTTOMRIGHT", cat, "BOTTOMRIGHT", -4, 20)
    page.lignesEtats, page.entetesEtats = {}, {}
    page.videEtats = UI.Texte(page.zoneEtats.contenu, "Aucun état dans le compendium.", UI.C.discret)
    page.videEtats:SetPoint("TOPLEFT", page.zoneEtats.contenu, "TOPLEFT", 6, -6)

    page.zoneActifs = UI.Defilement(detail)
    page.zoneActifs:SetPoint("TOPLEFT", detail, "TOPLEFT", 4, -proprio.hautActifs)
    page.zoneActifs:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -4, 6)
    page.videActifs = UI.Texte(page.zoneActifs.contenu, "", UI.C.discret)
    page.videActifs:SetPoint("TOPLEFT", page.zoneActifs.contenu, "TOPLEFT", 4, -4)
    page.videActifs:SetWidth(225)
    page.videActifs:SetJustifyH("LEFT")
    page.lignesActifs = {}
    -- Les cibles de depot sont les lignes du groupe : un seul jeu de lignes.
    page.lignesJoueurs = proprio.lignes

    -- Le catalogue, dans ses deux densites (voir proprio:Disposer). En
    -- compact : la duree et la recherche partagent une rangee, sans l'aide
    -- ni le compte.
    function page:Disposer(c)
        local m = c and 5 or 8
        local h = c and 4 or cat.haut
        local haute = c and 18 or 20
        UI.Police(self.dureeLabel, c and 10 or 12)
        self.dureeLabel:ClearAllPoints()
        self.dureeLabel:SetPoint("TOPLEFT", cat, "TOPLEFT", m, -(h + (c and 3 or 4)))
        self.duree:SetSize(c and 30 or 46, haute)
        self.dureeAide:SetShown(not c)
        self.recherche:ClearAllPoints()
        self.recherche:SetHeight(haute)
        if c then
            self.recherche:SetPoint("LEFT", self.duree, "RIGHT", 5, 0)
        else
            self.recherche:SetPoint("TOPLEFT", cat, "TOPLEFT", m, -(h + 30))
        end
        self.recherche:SetPoint("RIGHT", cat, "RIGHT", -m, 0)
        UI.Police(self.recherche.indice, c and 9 or 10)
        self.recherche.indice:SetText(c and "Chercher…" or "Rechercher…")
        local yFiltre = c and (h + 24) or (h + 56)
        self.filtreChoix:ClearAllPoints()
        self.filtreChoix:SetHeight(haute)
        self.filtreChoix:SetPoint("TOPLEFT", cat, "TOPLEFT", m, -yFiltre)
        self.filtreChoix:SetPoint("RIGHT", cat, "RIGHT", -m, 0)
        UI.Police(self.filtreChoix.label, c and 10 or 12)
        self.compte:SetShown(not c)
        self.zoneEtats:ClearAllPoints()
        self.zoneEtats:SetPoint("TOPLEFT", cat, "TOPLEFT", c and 2 or 4, -(yFiltre + haute + (c and 4 or 8)))
        self.zoneEtats:SetPoint("BOTTOMRIGHT", cat, "BOTTOMRIGHT", c and -2 or -4, c and 3 or 20)
    end
    local function BoutonLigne(parent, hauteur)
        local ligne = CreateFrame("Button", nil, parent)
        ligne:SetHeight(hauteur or 26)
        if UI.SurfaceLigne then UI.SurfaceLigne(ligne) end
        return ligne
    end

    -- La duree du catalogue, lue une fois par geste. Vide : jusqu'au retrait.
    -- Le refus se dit et rien n'est pose.
    function page:LireDuree()
        local texte = (self.duree:GetText() or ""):match("^%s*(.-)%s*$")
        if texte == "" then return true, nil end
        local rounds = tonumber(texte)
        if not rounds or rounds ~= math.floor(rounds) or rounds < 1 then
            LCM.Alerte("la durée doit être un nombre entier positif, ou vide.")
            return false
        end
        return true, rounds
    end

    local function Rounds(rounds)
        return rounds and (rounds .. " round" .. (rounds > 1 and "s" or "")) or "jusqu'au retrait"
    end

    -- Pose sans rien dire : Appliquer et AppliquerCoches font leur message.
    -- `suivre` : redemander la fiche pour voir l'etat arriver. Seulement pour
    -- le joueur CHOISI — la reponse d'un autre ouvrirait sa consultation
    -- (Fiches.onRecue), et poser sur cinq coches ouvrait cinq fenetres.
    function page:Poser(joueur, definition, rounds, suivre)
        if EstMoi(joueur) then
            local entity = LCM.Entities.Personnage and LCM.Entities.Personnage()
                or LCM.Entities.Self()
            if not entity then return false, "aucune fiche de personnage active." end
            -- Sans duree, il rejoint les etats portes : c'est Imposer qui
            -- en decide, pour que les trois chemins (ici, la fiche, le
            -- reseau) rangent l'etat au meme endroit.
            return LCM.EtatsTemporaires.Imposer(entity, definition, rounds)
        end
        if suivre then self:DemanderEtats(joueur) end
        return LCM.EtatsTemporaires.Envoyer(joueur, definition.id, rounds)
    end

    function page:Appliquer(joueur, definition)
        self.joueurActif = joueur
        local valide, rounds = self:LireDuree()
        if not valide then return end
        local ok, raison = self:Poser(joueur, definition, rounds, true)
        if ok then
            LCM.Ok(string.format("« %s » imposé à %s (%s).", definition.label,
                NomPersonnage(joueur), Rounds(rounds)))
            self.proprio:Afficher()
        elseif raison then
            LCM.Alerte(tostring(raison))
        end
    end

    -- Le geste « a la pelle » : un etat, tous les coches. La selection du
    -- detail ne bouge pas — on continue a regarder celui qu'on regardait.
    function page:AppliquerCoches(definition)
        local cibles = self.proprio:Coches()
        if #cibles == 0 then LCM.Alerte("coche d'abord les joueurs à qui poser l'état.") return end
        local valide, rounds = self:LireDuree()
        if not valide then return end
        local poses = 0
        for _, joueur in ipairs(cibles) do
            local ok, raison = self:Poser(joueur, definition, rounds, joueur == self.joueurActif)
            if ok then poses = poses + 1
            elseif raison then LCM.Alerte(string.format("%s : %s", NomPersonnage(joueur), tostring(raison))) end
        end
        if poses > 0 then
            LCM.Ok(string.format("« %s » imposé à %d personnage%s (%s).", definition.label,
                poses, poses > 1 and "s" or "", Rounds(rounds)))
        end
        self.proprio:Afficher()
        return poses
    end

    function page:DemanderEtats(joueur)
        -- La reception reste silencieuse tant que cet onglet suit ce joueur.
        -- Ne pas reutiliser les demandes XP : une reponse tardive ne doit pas
        -- avaler une consultation explicite faite depuis un autre onglet.
        local ok, raison = LCM.Fiches.Demander(joueur)
        if not ok then LCM.Alerte(tostring(raison)) end
    end

    function page:ChoisirJoueur(joueur)
        self.joueurActif = joueur
        if joueur and not EstMoi(joueur) then self:DemanderEtats(joueur) end
        self.proprio:Afficher()
    end

    function page:RetirerEtat(ligne)
        local joueur, etat = self.joueurActif, ligne.etat
        if not joueur or not etat then return end
        local ok, raison
        if EstMoi(joueur) then
            local entity = FicheJoueur(joueur)
            if not entity then return end
            if etat.catalogue then
                ok = LCM.Etats.Enlever(entity, etat.id)
                if ok then LCM.Entities.Changed(entity, "etats") end
            else
                ok, raison = LCM.EtatsTemporaires.RetirerForce(entity, etat.nom)
            end
        else
            ok, raison = LCM.EtatsTemporaires.EnvoyerRetrait(joueur,
                etat.catalogue and etat.id or etat.nom, etat.catalogue)
            if ok then self:DemanderEtats(joueur) end
        end
        if not ok and raison then LCM.Alerte(tostring(raison)) end
        self:AfficherActifs()
    end

    -- La duree saisie sur une ligne, posee sur l'etat. Vide : jusqu'au
    -- retrait. Le refus se dit, il ne se devine pas a l'affichage qui n'a
    -- pas bouge.
    function page:FixerDuree(ligne)
        local joueur, etat = self.joueurActif, ligne.etat
        if not (joueur and etat) then return end
        local texte = tostring(ligne.saisie:GetText() or ""):match("^%s*(.-)%s*$")
        local rounds
        if texte ~= "" then
            rounds = tonumber(texte)
            if not rounds or rounds ~= math.floor(rounds) or rounds < 1 then
                LCM.Alerte("la durée doit être un nombre entier positif, ou vide.")
                return
            end
        end
        local ok, raison
        if EstMoi(joueur) then
            local entity = FicheJoueur(joueur)
            if not entity then return end
            ok, raison = LCM.EtatsTemporaires.FixerDuree(entity, etat.nom, rounds, etat.id)
        else
            ok, raison = LCM.EtatsTemporaires.EnvoyerDuree(joueur, etat.nom, rounds, etat.id)
            if ok then self:DemanderEtats(joueur) end
        end
        if not ok then
            LCM.Alerte(tostring(raison or "la durée n'a pas pu être changée."))
        else
            LCM.Ok(string.format("« %s » : %s.", etat.nom,
                rounds and (rounds .. " round" .. (rounds > 1 and "s" or "")) or "jusqu'au retrait"))
        end
        self:AfficherActifs()
    end

    function page:AfficherActifs()
        local entity = self.joueurActif and FicheJoueur(self.joueurActif)
        local liste = {}
        if entity then
            for _, etat in ipairs(LCM.EtatsTemporaires.Liste(entity)) do
                liste[#liste + 1] = { nom = etat.nom, icone = etat.icone, id = etat.id,
                    restant = etat.restant, duree = LCM.EtatsTemporaires.Duree(etat) }
            end
            for _, categorie in ipairs(LCM.Etats.CATEGORIES) do
                for _, id in ipairs(LCM.Etats.Ids(entity, categorie.id)) do
                    local def = LCM.Etats.Get(id)
                    liste[#liste + 1] = { nom = def and def.label or id,
                        icone = def and def.icone, id = id, catalogue = true,
                        duree = "jusqu’à retrait" }
                end
            end
        end
        for i, etat in ipairs(liste) do
            local l = self.lignesActifs[i]
            if not l then
                l = BoutonLigne(self.zoneActifs.contenu, 42)
                l.nom = UI.Texte(l, "", UI.C.texte)
                l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", 5, -4)
                l.nom:SetPoint("RIGHT", l, "RIGHT", -30, 0)
                l.nom:SetWordWrap(false)
                l.duree = UI.Texte(l, "", UI.C.discret)
                UI.Police(l.duree, 10)
                l.duree:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -3)
                local ligne = l
                l.retirer = UI.Bouton(l, "×", 22, 22, function() page:RetirerEtat(ligne) end)
                l.retirer:SetPoint("RIGHT", l, "RIGHT", -3, 0)
                -- Changer la duree en seance, sans retirer puis reposer l'etat
                -- (le MJ, 24 octobre 2026). Vide = jusqu'au retrait, et l'etat
                -- rejoint alors les etats portes : c'est la duree qui decide
                -- de son logement (Core/EtatsTemporaires.lua).
                l.valider = UI.Bouton(l, "V", 20, 20, function() page:FixerDuree(ligne) end)
                l.valider:SetPoint("RIGHT", l.retirer, "LEFT", -3, 0)
                UI.Bulle(l.valider, "Changer la durée",
                    "Poser la durée saisie à gauche. Vide : jusqu'au retrait.")
                l.saisie = UI.Champ(l, 36, 20)
                l.saisie:SetJustifyH("CENTER")
                l.saisie:SetPoint("RIGHT", l.valider, "LEFT", -3, 0)
                l.saisie:SetScript("OnEnterPressed", function(e)
                    e:ClearFocus()
                    page:FixerDuree(ligne)
                end)
                l.saisie:SetScript("OnEscapePressed", function(e)
                    e:ClearFocus()
                    page:AfficherActifs()
                end)
                -- Le nom et la duree s'arretent avant la saisie : sans cela
                -- ils passaient dessous.
                l.duree:SetPoint("RIGHT", l.saisie, "LEFT", -6, 0)
                l.duree:SetWordWrap(false)
                self.lignesActifs[i] = l
            end
            l.etat = etat
            self:FormeActif(l)
            l.nom:SetText(etat.nom)
            l.duree:SetText(etat.duree)
            -- La saisie montre la duree en cours, pas un champ vide : on
            -- corrige « 3 » en « 5 » sans avoir a retrouver ce qu'il restait.
            -- Pas pendant qu'on y tape, sinon le rafraichissement de la
            -- seance effacerait ce qu'on est en train d'ecrire.
            if not l.saisie:HasFocus() then
                l.saisie:SetText(etat.restant and tostring(etat.restant) or "")
            end
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zoneActifs.contenu, "TOPLEFT", 2, -(i - 1) * self:PasActif())
            l:SetPoint("RIGHT", self.zoneActifs.contenu, "RIGHT", -2, 0)
            l:Show()
        end
        for i = #liste + 1, #self.lignesActifs do self.lignesActifs[i]:Hide() end
        self.videActifs:SetText(entity and "Aucun état sur ce personnage."
            or (self.joueurActif and "Fiche indisponible : clique le personnage pour la demander." or ""))
        self.videActifs:SetShown(#liste == 0)
        self.zoneActifs:Regler(math.max(1, #liste * self:PasActif()))
    end

    -- Un etat porte : deux lignes en etendu (nom, duree), une seule en
    -- compact — la saisie dit deja ce qu'il reste.
    function page:PasActif() return self.proprio.compact and 22 or 46 end
    function page:FormeActif(l)
        local c = self.proprio.compact
        l:SetHeight(c and 20 or 42)
        l.duree:SetShown(not c)
        UI.Police(l.nom, c and 10 or 12)
        l.retirer:SetSize(c and 16 or 22, c and 16 or 22)
        l.valider:SetSize(c and 16 or 20, c and 16 or 20)
        l.saisie:SetSize(c and 26 or 36, c and 16 or 20)
        l.nom:ClearAllPoints()
        if c then
            l.nom:SetPoint("LEFT", l, "LEFT", 4, 0)
            l.nom:SetPoint("RIGHT", l.saisie, "LEFT", -4, 0)
        else
            l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", 5, -4)
            l.nom:SetPoint("RIGHT", l, "RIGHT", -30, 0)
        end
    end

    LCM.Entities.Ecouter(function(entity)
        if page:IsVisible() and page.joueurActif and entity == FicheJoueur(page.joueurActif) then
            page:AfficherActifs()
            -- Les ressources du detail aussi : un coup recu en combat doit
            -- se voir sans recliquer le joueur.
            page.proprio:AfficherDetail()
        end
    end)

    -- La duree restante vieillit toute seule : ce qui est affiche doit suivre
    -- (le MJ, 24 octobre 2026). Chez un joueur distant, elle ne vieillit pas
    -- ICI — c'est sa fiche qui compte les rounds — donc on redemande sa copie
    -- plutot que de rafraichir un chiffre fige.
    function page:Reclamer()
        if not (self:IsVisible() and self.joueurActif) then return end
        if not EstMoi(self.joueurActif) then self:DemanderEtats(self.joueurActif) end
        self:AfficherActifs()
    end

    -- A chaque changement de round, et sinon toutes les vingt minutes : hors
    -- combat rien ne bouge, et une table qui dure n'a pas a montrer un
    -- decompte de la veille.
    local avantCombat = LCM.Combat and LCM.Combat.onChange
    if LCM.Combat then
        LCM.Combat.onChange = function(...)
            if avantCombat then avantCombat(...) end
            page:Reclamer()
        end
    end
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(20 * 60, function() page:Reclamer() end)
    end

    -- Le type d'un etat, lisible : l'entree de la liste « type d'etats »
    -- qu'il designe, ou rien. Le conteneur range les types entre eux, dans
    -- l'ordre de la fenetre Sante (etats divers, maladies, intangibles).
    local RANG_CONTENEUR = {}
    for rang, c in ipairs(LCM.Etats.CATEGORIES or {}) do RANG_CONTENEUR[c.id] = rang end
    local function TypeDe(definition)
        local entree = definition.type and LCM.Listes.Get(definition.type)
        if entree and entree.liste == "type_etats" then return entree.id, tostring(entree.label or entree.id) end
        return "", "Sans type"
    end

    local function LigneCatalogue(rang)
        local l = BoutonLigne(page.zoneEtats.contenu, 24)
        l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        l.icone = l:CreateTexture(nil, "ARTWORK")
        l.icone:SetSize(18, 18)
        l.icone:SetPoint("LEFT", l, "LEFT", 5, 0)
        l.nom = UI.Texte(l, "", UI.C.texte)
        l.nom:SetPoint("LEFT", l.icone, "RIGHT", 6, 0)
        l.nom:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        l.nom:SetJustifyH("LEFT")
        l.nom:SetWordWrap(false)
        l:RegisterForDrag("LeftButton")
        l:SetScript("OnDragStart", function(ligne)
            local etat = ligne.definition
            if etat then
                UI.Glisser.Commencer({ icone = LCM.Icone(etat.icone), nom = etat.label,
                    categorie = "etats", element = etat })
            end
        end)
        -- Clic droit : aux coches, sans glisser. Pour enchainer dix etats
        -- sur le meme groupe, c'est dix clics au lieu de dix trajets.
        l:SetScript("OnClick", function(ligne, bouton)
            if bouton == "RightButton" and ligne.definition then page:AppliquerCoches(ligne.definition) end
        end)
        l:SetScript("OnEnter", function(ligne)
            local d = ligne.definition
            if not d then return end
            GameTooltip:SetOwner(ligne, "ANCHOR_RIGHT")
            GameTooltip:SetText(tostring(d.label), 1, 0.82, 0)
            local _, typeLabel = TypeDe(d)
            GameTooltip:AddLine(typeLabel, 0.7, 0.7, 0.7)
            if d.description and d.description ~= "" then
                GameTooltip:AddLine(tostring(d.description), 1, 1, 1, true)
            end
            GameTooltip:AddLine("Glisse sur un joueur, ou sur la zone des cochés.", 0.6, 0.8, 1, true)
            GameTooltip:AddLine("Clic droit : aux joueurs cochés.", 0.6, 0.8, 1, true)
            GameTooltip:Show()
        end)
        l:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page.lignesEtats[rang] = l
        return l
    end

    local function EnTete(rang)
        local h = page.entetesEtats[rang]
        if h then return h end
        h = CreateFrame("Frame", nil, page.zoneEtats.contenu)
        h:SetHeight(18)
        h.texte = UI.Texte(h, "", UI.C.libelle, "GameFontNormalSmall")
        UI.Police(h.texte, 10)
        h.texte:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 4, 3)
        h.nombre = UI.Texte(h, "", UI.C.discret, "GameFontNormalSmall")
        UI.Police(h.nombre, 9)
        h.nombre:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -4, 3)
        h.filet = UI.Filet(h, true)
        h.filet:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 2, 0)
        h.filet:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -2, 0)
        page.entetesEtats[rang] = h
        return h
    end

    function page:Afficher()
        local brut = tostring(self.recherche:GetText() or "")
        self.recherche.indice:SetShown(brut == "" and not self.recherche:HasFocus())
        local recherche = Cherchable(brut)
        local filtre = self.filtre or "tous"
        local compact = self.proprio.compact
        local definitions = {}
        for _, definition in ipairs(LCM.Etats.list or {}) do
            local typeId, typeLabel = TypeDe(definition)
            local conteneur = LCM.Etats.Conteneur(definition)
            local garde = filtre == "tous"
                or (filtre:sub(1, 2) == "c:" and conteneur == filtre:sub(3))
                or (filtre:sub(1, 2) == "t:" and typeId == filtre:sub(3))
            if garde and recherche ~= "" then
                garde = Cherchable(definition.label):find(recherche, 1, true) ~= nil
                    or Cherchable(typeLabel):find(recherche, 1, true) ~= nil
            end
            if garde then
                definitions[#definitions + 1] = { def = definition, typeId = typeId,
                    typeLabel = typeLabel, rang = RANG_CONTENEUR[conteneur] or 99,
                    cle = Cherchable(definition.label) }
            end
        end
        -- Classe par conteneur, puis par type, puis par nom. « Sans type »
        -- ferme chaque conteneur : ce sont les etats qu'il reste a ranger.
        table.sort(definitions, function(a, b)
            if a.rang ~= b.rang then return a.rang < b.rang end
            if (a.typeId == "") ~= (b.typeId == "") then return b.typeId == "" end
            if a.typeLabel ~= b.typeLabel then return Cherchable(a.typeLabel) < Cherchable(b.typeLabel) end
            return a.cle < b.cle
        end)
        -- Un en-tete par type des qu'on regarde plus d'un type a la fois.
        local parType = filtre:sub(1, 2) ~= "t:"
        local nombres = {}
        for _, e in ipairs(definitions) do
            local cle = e.rang .. "|" .. e.typeId
            nombres[cle] = (nombres[cle] or 0) + 1
        end
        local y, nLignes, nEntetes, precedent = 0, 0, 0, nil
        for _, e in ipairs(definitions) do
            local cle = e.rang .. "|" .. e.typeId
            if parType and cle ~= precedent then
                precedent = cle
                nEntetes = nEntetes + 1
                local h = EnTete(nEntetes)
                h.texte:SetText(UI.Majuscules(e.typeLabel))
                h.nombre:SetText(tostring(nombres[cle]))
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", self.zoneEtats.contenu, "TOPLEFT", 0, -y)
                h:SetPoint("RIGHT", self.zoneEtats.contenu, "RIGHT", 0, 0)
                h:Show()
                h:SetHeight(compact and 14 or 18)
                UI.Police(h.texte, compact and 9 or 10)
                y = y + (compact and 16 or 22)
            end
            nLignes = nLignes + 1
            local l = self.lignesEtats[nLignes] or LigneCatalogue(nLignes)
            l.definition = e.def
            l:SetHeight(compact and 18 or 24)
            l.icone:SetSize(compact and 14 or 18, compact and 14 or 18)
            UI.Police(l.nom, compact and 10 or 12)
            l.icone:SetTexture(LCM.Icone(e.def.icone))
            l.nom:SetText(e.def.label)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zoneEtats.contenu, "TOPLEFT", 2, -y)
            l:SetPoint("RIGHT", self.zoneEtats.contenu, "RIGHT", -2, 0)
            l:Show()
            y = y + (compact and 20 or 26)
        end
        for rang = nLignes + 1, #self.lignesEtats do self.lignesEtats[rang]:Hide() end
        for rang = nEntetes + 1, #self.entetesEtats do self.entetesEtats[rang]:Hide() end
        local total = #(LCM.Etats.list or {})
        self.videEtats:SetText(total == 0 and "Aucun état dans le compendium." or "Aucun état ne correspond.")
        self.videEtats:SetShown(nLignes == 0)
        self.compte:SetText(nLignes == total and string.format("%d états", total)
            or string.format("%d sur %d états", nLignes, total))
        self.zoneEtats:Regler(math.max(1, y))

        -- Un joueur choisi qui a quitte le groupe ne l'est plus.
        if self.joueurActif then
            local present = false
            for _, joueur in ipairs(Groupe()) do if joueur == self.joueurActif then present = true end end
            if not present then self.joueurActif = nil end
        end
        self:AfficherActifs()
    end
end

-- ===== Combat ==============================================================

function Pages.combat(page, f)
    -- Resolu ici et pas au chargement : Combat.lua se charge apres ce fichier.
    page.combat = MJ.Combat.Construire(page, f)
    function page:Afficher() self.combat:Afficher() end
    function page:Disposer(compact) self.combat:Disposer(compact) end
end

-- Les deux pages emploient les memes lignes compactes avec icone. Garder la
-- fabrique ici evite que les listes divergent lors de leurs evolutions.
local function LigneIcone(liste, zone, rang)
    local l = liste[rang]
    if l then return l end
    l = Rangee(zone.contenu, 24)
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(16, 16)
    l.icone:SetPoint("LEFT", l, "LEFT", 6, 0)
    l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    l.nom = UI.Texte(l, "", UI.C.texte)
    UI.Police(l.nom, 11)
    l.nom:SetPoint("LEFT", l.icone, "RIGHT", 6, 0)
    l.nom:SetPoint("RIGHT", l, "RIGHT", -6, 0)
    l.nom:SetJustifyH("LEFT")
    l.nom:SetWordWrap(false)
    liste[rang] = l
    return l
end

-- ===== PNJ =================================================================

-- La scene se remplit ICI (2 novembre 2026). Elle ne se remplissait qu'en
-- incarnant, depuis une fenetre a part que le bouton « Incarner… » ouvrait
-- DERRIERE le panneau : le MJ cliquait, rien ne semblait venir, « on ne peut
-- pas rajouter de PNJ dans une scene ». A gauche le catalogue des PNJ, a
-- droite ceux de la scene. SEUL « + Scène » fait entrer un PNJ. « Incarner »,
-- au catalogue, fait JOUER le PNJ sans le mettre en scene — il en creait un
-- exemplaire en scene a chaque clic (le MJ, 2 novembre 2026) : il reprend
-- desormais son exemplaire hors scene (Incarnation.Incarner). Un PNJ deja en
-- scene s'incarne sur sa ligne.
function Pages.pnj(page, f)
    page.bandeau = UI.Texte(page, "", UI.C.accent)
    UI.Police(page.bandeau, 12)
    page.bandeau:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -4)
    page.relacher = UI.Bouton(page, "Reprendre ma place", 150, 22, function()
        if LCM.Incarnation.Relacher() then LCM.Ok("tu reprends ta place.") end
        page:Afficher()
    end)
    page.relacher:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)

    page.colCatalogue = Colonne(page, "Catalogue des PNJ")
    page.colCatalogue:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -30)
    page.colCatalogue:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 32)
    page.colScene = Colonne(page, "En scène")
    page.colScene:SetPoint("TOPLEFT", page.colCatalogue, "TOPRIGHT", 10, 0)
    page.colScene:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 32)
    page.compte = UI.Texte(page.colScene, "", UI.C.discret)
    UI.Police(page.compte, 10)
    page.compte:SetPoint("LEFT", page.colScene.titre, "RIGHT", 8, 0)

    local cat = page.colCatalogue
    page.recherche = UI.Champ(cat, 10, 20, function() page:Afficher() end)
    page.recherche:SetPoint("TOPLEFT", cat, "TOPLEFT", 8, -cat.haut)
    page.recherche:SetPoint("RIGHT", cat, "RIGHT", -8, 0)
    page.recherche:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    page.recherche:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    page.recherche.indice = UI.Texte(page.recherche, "Rechercher un PNJ…", UI.C.discret)
    UI.Police(page.recherche.indice, 10)
    page.recherche.indice:SetPoint("LEFT", page.recherche, "LEFT", 6, 0)
    page.zoneCatalogue = UI.Defilement(cat)
    page.zoneCatalogue:SetPoint("TOPLEFT", cat, "TOPLEFT", 4, -(cat.haut + 26))
    page.zoneCatalogue:SetPoint("BOTTOMRIGHT", cat, "BOTTOMRIGHT", -4, 6)
    page.lignesCatalogue = {}
    page.videCatalogue = UI.Texte(page.zoneCatalogue.contenu, "", UI.C.discret)
    page.videCatalogue:SetPoint("TOPLEFT", page.zoneCatalogue.contenu, "TOPLEFT", 6, -6)

    local scene = page.colScene
    page.zoneScene = UI.Defilement(scene)
    page.zoneScene:SetPoint("TOPLEFT", scene, "TOPLEFT", 4, -scene.haut)
    page.zoneScene:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", -4, 6)
    page.lignesScene = {}
    page.sceneVide = UI.Texte(scene, "", UI.C.discret)
    UI.Police(page.sceneVide, 11)
    page.sceneVide:SetPoint("TOPLEFT", page.zoneScene, "TOPLEFT", 6, -6)
    page.sceneVide:SetPoint("TOPRIGHT", page.zoneScene, "TOPRIGHT", -6, -6)
    page.sceneVide:SetWordWrap(true)
    page.sceneVide:SetJustifyH("LEFT")

    -- Les joueurs recoivent la scene a chaque changement ; ce bouton sert
    -- quand l'un d'eux arrive en cours de route ou a recharge.
    page.diffuser = UI.Bouton(page, "Renvoyer la scène au groupe", 220, 24, function()
        if Dire(LCM.Scene.Diffuser(), "hors groupe : personne à qui envoyer la scène.") then
            LCM.Ok("scène renvoyée au groupe.")
        end
    end)
    page.diffuser:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)

    function page:MettreEnScene(pnjId)
        local instance, raison = LCM.Incarnation.Instancier(pnjId)
        if not instance then LCM.Alerte(tostring(raison)) return end
        LCM.Ok(string.format("%s entre en scène.", tostring(instance.name)))
        self:Afficher()
        return instance
    end

    function page:Incarner(pnjId)
        local instance, raison = LCM.Incarnation.Incarner(pnjId)
        if not instance then LCM.Alerte(tostring(raison)) return end
        LCM.Ok(string.format("tu incarnes %s, hors scène.", tostring(instance.name)))
        self:Afficher()
        return instance
    end

    local function LigneCatalogue(rang)
        local l = LigneIcone(page.lignesCatalogue, page.zoneCatalogue, rang)
        l.incarner = UI.Bouton(l, "Incarner", 62, 18, function() page:Incarner(l.pnjId) end)
        l.incarner:SetPoint("RIGHT", l, "RIGHT", -3, 0)
        UI.Bulle(l.incarner, "Incarner",
            "Le jouer, sans le mettre en scène : les joueurs ne le voient pas dans leurs cibles. Le même exemplaire est repris à chaque fois.")
        l.ajouter = UI.Bouton(l, "+ Scène", 58, 18, function() page:MettreEnScene(l.pnjId) end)
        l.ajouter:SetPoint("RIGHT", l.incarner, "LEFT", -3, 0)
        UI.Bulle(l.ajouter, "Mettre en scène",
            "Le PNJ entre en jeu sans que tu le joues : les joueurs peuvent le cibler, le combat peut l'inviter. Plusieurs fois : plusieurs exemplaires.")
        l.nom:SetPoint("RIGHT", l.ajouter, "LEFT", -4, 0)
        return l
    end

    local function LigneScene(rang)
        local l = LigneIcone(page.lignesScene, page.zoneScene, rang)
        l.oublier = UI.Bouton(l, "×", 20, 18, function()
            LCM.Incarnation.Oublier(l.instanceId)
            page:Afficher()
        end)
        l.oublier:SetPoint("RIGHT", l, "RIGHT", -3, 0)
        UI.Bulle(l.oublier, "Retirer de la scène", "Le PNJ quitte le jeu, et ses blessures avec lui.")
        l.prendre = UI.Bouton(l, "Incarner", 66, 18, function()
            local prise, raison = LCM.Incarnation.Prendre(l.instanceId)
            if not prise then LCM.Alerte(tostring(raison)) return end
            LCM.Ok(string.format("tu incarnes %s.", tostring(prise.name)))
            page:Afficher()
        end)
        l.prendre:SetPoint("RIGHT", l.oublier, "LEFT", -3, 0)
        -- « Mort » (le MJ, 3 novembre 2026) : en combat, un PNJ a 0 PV passe
        -- au rouge et peut laisser son cadavre (MJ/Cadavres.lua).
        l.mort = UI.Bouton(l, "Mort", 46, 18, function()
            local id, raison = MJ.Cadavres.Mort(l.instanceId)
            if not id then LCM.Alerte(tostring(raison)) return end
            LCM.Ok("Le cadavre est posé à tes pieds. Corrige ce qu'il porte, puis les joueurs pourront le fouiller.")
            if LCM.UI.Cadavre then LCM.UI.Cadavre.Ouvrir(id) end
            page:Afficher()
        end)
        l.mort:SetPoint("RIGHT", l.prendre, "LEFT", -3, 0)
        l.mort:Hide()
        UI.Bulle(l.mort, "Mort", "Fait apparaître son cadavre à ta position, avec ce qu'il portait et son butin.")
        l.pv = UI.Texte(l, "", UI.C.discret)
        UI.Police(l.pv, 10)
        l.pv:SetPoint("RIGHT", l.mort, "LEFT", -6, 0)
        l.nom:SetPoint("RIGHT", l.pv, "LEFT", -4, 0)
        return l
    end

    -- Deux densites, comme la page Groupe. En compact : pas de titre de
    -- colonne, des lignes de 20, « Jouer » au lieu d'« Incarner » / « Prendre ».
    function page:Disposer(compact)
        local c = compact and true or false
        self.compact = c
        local haut = c and 4 or 30
        local m = c and 5 or 8
        UI.Police(self.bandeau, c and 10 or 12)
        self.relacher:SetSize(c and 70 or 150, c and 18 or 22)
        UI.Police(self.relacher.label, c and 10 or 12)
        self.relacher.label:SetText(c and "Reprendre" or "Reprendre ma place")
        local haute = c and 22 or 30
        for _, col in ipairs({ self.colCatalogue, self.colScene }) do
            col.titre:SetShown(not c)
            col.filet:SetShown(not c)
        end
        self.compte:SetShown(not c)
        self.colCatalogue:SetWidth(c and 200 or 330)
        self.colCatalogue:ClearAllPoints()
        self.colCatalogue:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -haute)
        self.colCatalogue:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, c and 22 or 32)
        self.colScene:ClearAllPoints()
        self.colScene:SetPoint("TOPLEFT", self.colCatalogue, "TOPRIGHT", c and 6 or 10, 0)
        self.colScene:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, c and 22 or 32)
        self.recherche:ClearAllPoints()
        self.recherche:SetHeight(c and 18 or 20)
        self.recherche:SetPoint("TOPLEFT", self.colCatalogue, "TOPLEFT", m, -haut)
        self.recherche:SetPoint("RIGHT", self.colCatalogue, "RIGHT", -m, 0)
        self.zoneCatalogue:ClearAllPoints()
        self.zoneCatalogue:SetPoint("TOPLEFT", self.colCatalogue, "TOPLEFT", c and 2 or 4, -(haut + (c and 22 or 26)))
        self.zoneCatalogue:SetPoint("BOTTOMRIGHT", self.colCatalogue, "BOTTOMRIGHT", c and -2 or -4, c and 3 or 6)
        self.zoneScene:ClearAllPoints()
        self.zoneScene:SetPoint("TOPLEFT", self.colScene, "TOPLEFT", c and 2 or 4, -haut)
        self.zoneScene:SetPoint("BOTTOMRIGHT", self.colScene, "BOTTOMRIGHT", c and -2 or -4, c and 3 or 6)
        self.diffuser:SetSize(c and 130 or 220, c and 18 or 24)
        UI.Police(self.diffuser.label, c and 10 or 12)
        self.diffuser.label:SetText(c and "Renvoyer la scène" or "Renvoyer la scène au groupe")
        if self:IsVisible() then self:Afficher() end
    end

    local function FormeLigne(l, c)
        l:SetHeight(c and 18 or 22)
        l.icone:SetSize(c and 14 or 16, c and 14 or 16)
        UI.Police(l.nom, c and 10 or 11)
        if l.ajouter then
            l.ajouter:SetSize(c and 22 or 58, c and 16 or 18)
            l.ajouter.label:SetText(c and "+" or "+ Scène")
            UI.Police(l.ajouter.label, c and 10 or 12)
            l.incarner:SetSize(c and 40 or 62, c and 16 or 18)
            l.incarner.label:SetText(c and "Jouer" or "Incarner")
            UI.Police(l.incarner.label, c and 10 or 12)
        else
            l.oublier:SetSize(c and 16 or 20, c and 16 or 18)
            l.prendre:SetSize(c and 40 or 66, c and 16 or 18)
            UI.Police(l.pv, c and 9 or 10)
            UI.Police(l.oublier.label, c and 10 or 12)
            UI.Police(l.prendre.label, c and 10 or 12)
        end
    end
    page.FormeLigne = FormeLigne
    page:Disposer(false)

    function page:Afficher()
        local actuelle = LCM.Incarnation.Actuelle()
        self.bandeau:SetText(actuelle
            and string.format("Tu incarnes |cffffd36b%s|r%s.", tostring(actuelle.name),
                actuelle.horsScene and ", hors scène" or "")
            or "Tu es toi-même.")
        self.relacher:SetShown(actuelle ~= nil)

        local brut = tostring(self.recherche:GetText() or "")
        self.recherche.indice:SetShown(brut == "" and not self.recherche:HasFocus())
        local recherche = Cherchable(brut)
        local modeles = {}
        for _, modele in ipairs(LCM.PNJ.list or {}) do
            if recherche == "" or Cherchable(modele.label):find(recherche, 1, true) then
                modeles[#modeles + 1] = modele
            end
        end
        table.sort(modeles, function(a, b) return Cherchable(a.label) < Cherchable(b.label) end)
        local y = 0
        for rang, modele in ipairs(modeles) do
            local l = self.lignesCatalogue[rang] and self.lignesCatalogue[rang].ajouter
                and self.lignesCatalogue[rang] or LigneCatalogue(rang)
            l.pnjId = modele.id
            FormeLigne(l, self.compact)
            l.icone:SetTexture(LCM.Icone(modele.icone))
            l.nom:SetText(tostring(modele.label))
            Poser(l, self.zoneCatalogue.contenu, y)
            y = y + (self.compact and 20 or 24)
        end
        for rang = #modeles + 1, #self.lignesCatalogue do self.lignesCatalogue[rang]:Hide() end
        self.zoneCatalogue:Regler(math.max(1, y))
        self.videCatalogue:SetText(#(LCM.PNJ.list or {}) == 0 and "Aucun PNJ dans le compendium."
            or "Aucun PNJ ne correspond.")
        self.videCatalogue:SetShown(#modeles == 0)

        local liste = LCM.Incarnation.Liste()
        y = 0
        for rang, instance in ipairs(liste) do
            local l = self.lignesScene[rang] and self.lignesScene[rang].prendre
                and self.lignesScene[rang] or LigneScene(rang)
            l.instanceId = instance.id
            FormeLigne(l, self.compact)
            l.icone:SetTexture(LCM.Icone(instance.icon))
            l.nom:SetText(tostring(instance.name))
            local courant, maximum = LCM.Body.Totals(instance)
            l.pv:SetText(string.format("%d/%d PV", courant, maximum))
            -- 0 PV EN COMBAT : nom rouge et « Mort », tant qu'aucun cadavre
            -- n'est pose pour lui.
            local enCombat = LCM.Combat and LCM.Combat.Etat and LCM.Combat.Etat()
            local ko = enCombat and courant <= 0
            local cadavre = instance.cadavre and MJ.Cadavres and MJ.Cadavres.Get(instance.cadavre)
            l.mort:SetShown((ko and not cadavre) and true or false)
            local teinte = ko and UI.C.plein or UI.C.texte
            l.nom:SetTextColor(teinte[1], teinte[2], teinte[3])
            local joue = actuelle and actuelle.id == instance.id
            l.prendre.label:SetText(joue and "en cours" or (self.compact and "Jouer" or "Incarner"))
            l.prendre:Selectionner(joue and true or false)
            Poser(l, self.zoneScene.contenu, y)
            y = y + (self.compact and 20 or 24)
        end
        for rang = #liste + 1, #self.lignesScene do self.lignesScene[rang]:Hide() end
        self.zoneScene:Regler(math.max(1, y))
        self.nombreScene = #liste
        self.compte:SetText(tostring(#liste))
        self.sceneVide:SetText(#liste > 0 and ""
            or "Personne en scène. « + Scène » met un PNJ en jeu : c'est eux que les joueurs peuvent cibler, et toi incarner.")
    end
end


-- ===== Outils partages =====================================================

-- ===== Equilibrage =========================================================
-- Le tableau de tous les nombres du jeu, reglables en seance.
--
-- « Le perce-armure est trop fort, on passe ses degats a 90 % » demandait
-- d'ouvrir Data/Equilibrage.lua, de republier, et de faire mettre a jour tout
-- le monde (9 octobre 2026). Ici on regle, ca s'applique tout de suite, ca part
-- chez les joueurs, et ca reste a exporter.
--
-- Deux colonnes : les GROUPES a gauche (pv, dot, forge...), leurs nombres a
-- droite. Sans ce decoupage, les quelque deux cents vecteurs faisaient une
-- liste ou l'on ne trouvait rien.

local LIGNE_REGLAGE = 24

-- ===== Nommages =============================================================
-- L'echelle des paliers (Core/Nommages.lua), dans l'onglet Equilibrage, au-
-- dessus des difficultes (le MJ, 2 novembre 2026) : renommer, recolorer (clic
-- sur la pastille), ajouter, retirer, et reordonner au glisser-deposer ou aux
-- fleches. L'ordre se lit par numero croissant, 9 avant 10.
--
-- Tout passe par les REGLAGES (texte pour les noms et les couleurs) : pas de
-- contenu, rien au compendium. Deplacer ou retirer un palier change des
-- NUMEROS, et ce qui s'y refere suit (Remapper) : une difficulte Rose reste
-- Rose, la grille d'XP garde ses coefficients avec leurs couleurs. Une
-- difficulte dont le palier est retire est ecartee.
local Nommages = {}
MJ.Nommages = Nommages
Ecran.Nommages = Nommages

local function N() return LCM.Nommages end
local function R() return LCM.Reglages end

-- Pose nom et couleur a une place, seulement ce qui change.
local function PoserA(rang, nom, hex)
    local ok, raison = true, nil
    local p = N().Get(rang)
    if not p or p.nom ~= nom then ok, raison = R().Definir(N().Chemin(rang, "nom"), nom) end
    if not ok then return false, raison end
    if not p or p.hex ~= hex then ok, raison = R().Definir(N().Chemin(rang, "couleur"), hex) end
    return ok, raison
end

local function PoserNombre(n)
    if N().Nombre() == n then return true end
    return R().Definir("nommages.nombre", n)
end

-- Ce qui se refere aux numeros, photographie AVANT le changement.
local function Photo()
    local photo = { niveaux = {}, matrice = {} }
    for cle, rang in pairs(LCM.Equilibrage.difficultes.niveaux or {}) do
        local v, r = tonumber(cle), tonumber(rang)
        if v and r and r >= 1 then photo.niveaux[#photo.niveaux + 1] = { valeur = v, rang = r } end
    end
    local total = N().Nombre()
    for m = 1, #LCM.Difficultes.CouleursMetier() do
        photo.matrice[m] = {}
        for d = 1, total do
            photo.matrice[m][d] = tonumber(R().Lire(LCM.Difficultes.CheminCoefficient(m, d)))
        end
    end
    return photo
end

-- `table_` : ancien numero -> nouveau (nil : retire).
local function Remapper(photo, table_)
    local D = LCM.Difficultes
    for _, d in ipairs(photo.niveaux) do
        local nouveau = table_[d.rang]
        if not nouveau then D.Retirer(d.valeur)
        elseif nouveau ~= d.rang then D.Definir(d.valeur, nouveau) end
    end
    -- Seul l'indice de DIFFICULTE suit l'echelle : la couleur du metier est
    -- une des sept de base, que reordonner les Nommages ne deplace pas (le
    -- MJ, 3 novembre 2026). Une case dont la difficulte a ete retiree se perd.
    local grille = {}
    for m, ligne in pairs(photo.matrice) do
        for d, valeur in pairs(ligne) do
            local d2 = table_[d]
            if d2 then
                grille[m] = grille[m] or {}
                grille[m][d2] = valeur
            end
        end
    end
    for m2, ligne in pairs(grille) do
        for d2, valeur in pairs(ligne) do
            local chemin = D.CheminCoefficient(m2, d2)
            if tonumber(R().Lire(chemin)) ~= valeur then R().Definir(chemin, valeur) end
        end
    end
end

-- Pose un nouvel ordre : la liste des ANCIENS numeros, de bas en haut.
function Nommages.Ordonner(anciens)
    local liste = N().Liste()
    local photo = Photo()
    local table_ = {}
    for nouveau, ancien in ipairs(anciens) do
        local p = liste[ancien]
        if p then
            table_[ancien] = nouveau
            local ok, raison = PoserA(nouveau, p.nom, p.hex)
            if not ok then return false, raison end
        end
    end
    Remapper(photo, table_)
    return true
end

local function Ordre()
    local out = {}
    for rang = 1, N().Nombre() do out[#out + 1] = rang end
    return out
end

-- Poser le palier `source` a la place de `cible` (glisser-deposer).
function Nommages.Deplacer(source, cible)
    source, cible = tonumber(source), tonumber(cible)
    local ordre = Ordre()
    if not source or not cible or source == cible or not ordre[source] or not ordre[cible] then return false end
    table.remove(ordre, source)
    table.insert(ordre, cible, source)
    return Nommages.Ordonner(ordre)
end

function Nommages.Decaler(rang, sens)
    rang = tonumber(rang)
    local cible = rang and rang + sens
    if not cible or cible < 1 or cible > N().Nombre() then return false end
    return Nommages.Deplacer(rang, cible)
end

function Nommages.Renommer(rang, nom)
    nom = tostring(nom or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if nom == "" then return false, "un palier a besoin d'un nom." end
    if #nom > 24 then return false, "24 caractères au plus pour le nom d'un palier." end
    if not N().Get(rang) then return false, "palier inconnu." end
    return R().Definir(N().Chemin(rang, "nom"), nom)
end

function Nommages.Recolorer(rang, hex)
    hex = tostring(hex or ""):gsub("^%s*#?", ""):gsub("%s+$", ""):upper()
    if not hex:match("^%x%x%x%x%x%x$") then
        return false, "une couleur s'écrit en six chiffres hexadécimaux (FF8CBF)."
    end
    if not N().Get(rang) then return false, "palier inconnu." end
    return R().Definir(N().Chemin(rang, "couleur"), hex)
end

function Nommages.Ajouter()
    local n = N().Nombre() + 1
    local ok, raison = R().Definir(N().Chemin(n, "nom"), "Nouveau palier")
    if ok then ok, raison = R().Definir(N().Chemin(n, "couleur"), "CCCCCC") end
    if ok then ok, raison = PoserNombre(n) end
    return ok, raison
end

function Nommages.Retirer(rang)
    rang = tonumber(rang)
    local liste = N().Liste()
    if #liste <= 1 then return false, "l'échelle garde au moins un palier." end
    if not rang or not liste[rang] then return false, "palier inconnu." end
    local photo = Photo()
    local table_ = {}
    for ancien = 1, #liste do
        if ancien < rang then table_[ancien] = ancien
        elseif ancien > rang then
            table_[ancien] = ancien - 1
            local ok, raison = PoserA(ancien - 1, liste[ancien].nom, liste[ancien].hex)
            if not ok then return false, raison end
        end
    end
    local ok, raison = PoserNombre(#liste - 1)
    if not ok then return false, raison end
    Remapper(photo, table_)
    return true
end

-- La premiere version rangeait les paliers en CONTENU (liste « paliers ») ;
-- le MJ les veut hors du compendium (2 novembre 2026). Ce qu'il en reste est
-- repris en reglages, dans son ordre, puis supprime du contenu. Une fois.
function Nommages.Reprendre()
    local entrees = {}
    for _, e in ipairs(LCM.Listes and LCM.Listes.list or {}) do
        if e.liste == "paliers" then entrees[#entrees + 1] = e end
    end
    if #entrees == 0 then return 0 end
    table.sort(entrees, function(a, b)
        local ra, rb = tonumber(a.rang) or 0, tonumber(b.rang) or 0
        if ra ~= rb then return ra < rb end
        return tostring(a.id) < tostring(b.id)
    end)
    for rang, e in ipairs(entrees) do
        PoserA(rang, tostring(e.label or ("Palier " .. rang)), tostring(e.couleur or "CCCCCC"):upper())
    end
    PoserNombre(#entrees)
    for _, e in ipairs(entrees) do LCM.Brouillons.Supprimer("listes", e.id) end
    LCM.Info(string.format("Nommages : %d palier(s) repris en réglages d'équilibrage et retirés du contenu.", #entrees))
    return #entrees
end

local function ConstruireNommages(page, parent)
    local e = CreateFrame("Frame", nil, parent)
    e:Hide()
    e.titre = Titre(e, "Nommages")
    e.titre:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
    e.aide = UI.Texte(e, "L'échelle des paliers, de bas en haut. Elle nomme les difficultés, les couleurs des métiers "
        .. "et la grille d'XP. Glisse une ligne sur une autre pour la déplacer ; clique la pastille pour la couleur.",
        UI.C.discret)
    UI.Police(e.aide, 10)
    e.aide:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -18)
    e.aide:SetPoint("RIGHT", e, "RIGHT", 0, 0)
    e.aide:SetJustifyH("LEFT")
    e.aide:SetWordWrap(true)
    e.source = UI.Texte(e, "", UI.C.discret)
    UI.Police(e.source, 9)
    e.source:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -46)

    e.zone = UI.Defilement(e)
    e.zone:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -62)
    e.zone:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", 0, 34)
    e.lignes = {}
    e.confirmer = UI.Confirmer(e, "", "Retirer")

    local function Agir(ok, raison)
        if not ok and raison then LCM.Alerte(tostring(raison)) end
        e:Afficher()
        return ok
    end

    local FL = "Interface\\Buttons\\"
    local function Fleche(bouton, chemin)
        bouton.icone = bouton:CreateTexture(nil, "OVERLAY")
        bouton.icone:SetTexture(FL .. chemin)
        bouton.icone:SetSize(14, 14)
        bouton.icone:SetPoint("CENTER", bouton, "CENTER", 0, 0)
    end

    local function Ligne(rang)
        local l = CreateFrame("Button", nil, e.zone.contenu)
        l:SetHeight(26)
        if UI.SurfaceLigne then UI.SurfaceLigne(l) end
        -- Toute la ligne se glisse, et recoit un palier lache dessus.
        l:RegisterForDrag("LeftButton")
        l:SetScript("OnDragStart", function(ligne)
            UI.Glisser.Commencer({ categorie = "palier", element = ligne.rang, nom = ligne.nomPalier })
        end)
        UI.Glisser.Cible(l, function(objet)
            return objet and objet.categorie == "palier" and objet.element ~= l.rang,
                "lâche ici pour prendre sa place"
        end, function(objet) Agir(Nommages.Deplacer(objet.element, l.rang)) end)
        l.poignee = UI.Texte(l, "::", UI.C.discret)
        l.poignee:SetPoint("LEFT", l, "LEFT", 6, 0)
        l.numero = UI.Texte(l, "", UI.C.titre)
        UI.Police(l.numero, 13)
        l.numero:SetPoint("LEFT", l, "LEFT", 24, 0)
        l.numero:SetWidth(26)
        -- La couleur : une pastille qu'on clique (le selecteur du Kit).
        l.pastille = CreateFrame("Button", nil, l)
        l.pastille:SetSize(18, 18)
        l.pastille:SetPoint("LEFT", l, "LEFT", 54, 0)
        l.pastille.fond = UI.Aplat(l.pastille, { 1, 1, 1, 1 }, "ARTWORK")
        l.pastille.fond:SetAllPoints(l.pastille)
        UI.BordureFine(l.pastille, 0.6)
        l.pastille:SetScript("OnClick", function(bouton)
            UI.SelecteurCouleur():Ouvrir(bouton, l.hex, function(hex) Agir(Nommages.Recolorer(l.rang, hex)) end)
        end)
        UI.Bulle(l.pastille, "Couleur", function() return "#" .. tostring(l.hex) .. " — clique pour la changer." end)
        l.nom = UI.Champ(l, 170, 20, nil)
        l.nom:SetPoint("LEFT", l.pastille, "RIGHT", 8, 0)
        l.nom:SetMaxLetters(24)
        l.nom:SetScript("OnEnterPressed", function(c) c:ClearFocus(); Agir(Nommages.Renommer(l.rang, c:GetText())) end)
        l.nom:SetScript("OnEscapePressed", function(c) c:ClearFocus(); e:Afficher() end)
        l.retirer = UI.Bouton(l, "×", 20, 20, function()
            e.confirmer:Demander(string.format("Retirer le palier « %s » ? Les difficultés qui l'utilisent seront écartées.",
                tostring(l.nomPalier)), function() Agir(Nommages.Retirer(l.rang)) end)
        end)
        l.retirer:SetPoint("RIGHT", l, "RIGHT", -4, 0)
        l.descendre = UI.Bouton(l, "", 22, 20, function() Agir(Nommages.Decaler(l.rang, 1)) end)
        Fleche(l.descendre, "Arrow-Down-Up")
        l.descendre:SetPoint("RIGHT", l.retirer, "LEFT", -6, 0)
        l.monter = UI.Bouton(l, "", 22, 20, function() Agir(Nommages.Decaler(l.rang, -1)) end)
        Fleche(l.monter, "Arrow-Up-Up")
        l.monter:SetPoint("RIGHT", l.descendre, "LEFT", -3, 0)
        e.lignes[rang] = l
        return l
    end

    e.ajouter = UI.Bouton(e, "+ Ajouter un palier", 160, 24, function() Agir(Nommages.Ajouter()) end)
    e.ajouter:SetPoint("BOTTOMLEFT", e, "BOTTOMLEFT", 0, 2)

    function e:Afficher()
        local liste = N().Liste()
        for rang, p in ipairs(liste) do
            local l = self.lignes[rang] or Ligne(rang)
            l.rang, l.nomPalier, l.hex = p.rang, p.nom, p.hex
            l.numero:SetText(tostring(p.rang))
            l.pastille.fond:SetColorTexture(p.couleur[1], p.couleur[2], p.couleur[3], 1)
            if not l.nom:HasFocus() then l.nom:SetText(p.nom) end
            l.nom:SetTextColor(p.couleur[1], p.couleur[2], p.couleur[3])
            l.monter:SetEnabled(rang > 1)
            l.descendre:SetEnabled(rang < #liste)
            Poser(l, self.zone.contenu, (rang - 1) * 28)
        end
        for rang = #liste + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.zone:Regler(math.max(1, #liste * 28))
        self.nombre = #liste
        self.source:SetText(N().Reglee() and "Échelle réglée en séance : à exporter, comme le reste de l'équilibrage."
            or "Échelle du fichier (Data/Equilibrage.lua).")
    end

    page.nommages = e
    return e
end

-- L'editeur des DIFFICULTES (2 novembre 2026), a la place du tableau quand
-- on choisit ce groupe. Le tableau generique montrait « niveaux.15 = 3 » et
-- « couleurs.2.dessus = 2 » : juste, mais illisible, et il ne savait pas
-- AJOUTER une ligne. Ici : la liste croissante des difficultes avec leur
-- couleur, une rangee pour en ajouter, et les coefficients d'XP par couleur
-- de metier. Tout passe par LCM.Difficultes et les reglages : diffuse au
-- groupe, a exporter, comme le reste.
local function ConstruireDifficultes(page, parent)
    local D = LCM.Difficultes
    local R = LCM.Reglages
    local e = CreateFrame("Frame", nil, parent)
    e:Hide()

    local function Peindre(fs, couleur)
        if couleur then fs:SetTextColor(couleur[1], couleur[2], couleur[3]) end
    end
    local function OptionsCouleurs()
        local out = {}
        -- Chaque palier dans sa couleur : on le reconnait avant de le lire
        -- (le MJ, 2 novembre 2026).
        for _, c in ipairs(D.Couleurs()) do
            out[#out + 1] = { id = c.rang,
                label = string.format("|cff%s%s|r", LCM.Nommages.Hex(c.couleur), tostring(c.nom)) }
        end
        return out
    end

    e.titre = Titre(e, "Difficultés")
    e.titre:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
    e.aide = UI.Texte(e, "Un nombre, rangé dans une couleur. Ce sont les seuls DD proposés partout : épreuves, jets d'expertise, ressources.",
        UI.C.discret)
    UI.Police(e.aide, 10)
    e.aide:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -18)
    e.aide:SetPoint("RIGHT", e, "RIGHT", 0, 0)
    e.aide:SetJustifyH("LEFT")

    -- Ajouter : la valeur, sa couleur, et le bouton. Entree dans le champ
    -- ajoute aussi : on enchaine « 1, Rose ; 5, Rose ; 12, Vert ».
    e.nouvelle = UI.Champ(e, 56, 22)
    e.nouvelle:SetNumeric(true)
    e.nouvelle:SetJustifyH("CENTER")
    e.nouvelle:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -40)
    e.couleurNouvelle = UI.Deroulant(e, 110, 22, OptionsCouleurs, function() end)
    e.couleurNouvelle:SetPoint("LEFT", e.nouvelle, "RIGHT", 6, 0)
    e.couleurNouvelle:Definir(1)
    function e:Ajouter()
        local ok, raison = D.Definir(self.nouvelle:GetText(), self.couleurNouvelle.valeur)
        if not ok then LCM.Alerte(tostring(raison)) return false end
        local d = D.Get(self.nouvelle:GetText())
        LCM.Ok(string.format("difficulté %s : %s.", tostring(d and d.valeur), tostring(d and d.nom)))
        self.nouvelle:SetText("")
        self:Afficher()
        return true
    end
    e.ajouter = UI.Bouton(e, "Ajouter", 80, 22, function() e:Ajouter() end)
    e.ajouter:SetPoint("LEFT", e.couleurNouvelle, "RIGHT", 6, 0)
    e.nouvelle:SetScript("OnEnterPressed", function() e:Ajouter() end)

    -- La liste, sur toute la hauteur : les coefficients d'XP ont quitte cet
    -- ecran pour les metiers (ConstruireCoefficients, plus bas).
    e.zone = UI.Defilement(e)
    e.zone:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -70)
    e.zone:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", 0, 0)
    e.lignes = {}
    e.vide = UI.Texte(e.zone.contenu, "Aucune difficulté : ajoute la première ci-dessus.", UI.C.discret)
    e.vide:SetPoint("TOPLEFT", e.zone.contenu, "TOPLEFT", 6, -6)

    local function Ligne(rang)
        local l = CreateFrame("Frame", nil, e.zone.contenu)
        l:SetHeight(24)
        if UI.SurfaceLigne then UI.SurfaceLigne(l) end
        -- Le nombre se MODIFIE sur place (le MJ, 2 novembre 2026) : Entree le
        -- deplace, la couleur reste. Un nombre deja pris est refuse et le dit.
        l.valeur = UI.Champ(l, 50, 20, nil)
        l.valeur:SetPoint("LEFT", l, "LEFT", 4, 0)
        l.valeur:SetNumeric(true)
        l.valeur:SetJustifyH("CENTER")
        l.valeur:SetScript("OnEnterPressed", function(c)
            c:ClearFocus()
            local ok, raison = D.Renumeroter(l.difficulte, c:GetText())
            if not ok and raison then LCM.Alerte(tostring(raison)) end
            e:Afficher()
        end)
        l.valeur:SetScript("OnEscapePressed", function(c) c:ClearFocus(); e:Afficher() end)
        UI.Bulle(l.valeur, "Valeur de la difficulté",
            "Tape le nouveau nombre puis Entrée : la difficulté change de valeur et garde sa couleur. "
            .. "Une ressource ou un coffre qui utilisait l'ancien DD le garde, marqué « hors liste ».")
        l.pastille = UI.Aplat(l, { 1, 1, 1, 1 }, "ARTWORK")
        l.pastille:SetSize(10, 10)
        l.pastille:SetPoint("LEFT", l, "LEFT", 62, 0)
        l.couleur = UI.Deroulant(l, 110, 20, OptionsCouleurs, function(id)
            local ok, raison = D.Definir(l.difficulte, id)
            if not ok then LCM.Alerte(tostring(raison)) end
            e:Afficher()
        end)
        l.couleur:SetPoint("LEFT", l.pastille, "RIGHT", 6, 0)
        l.retirer = UI.Bouton(l, "×", 20, 20, function()
            local ok, raison = D.Retirer(l.difficulte)
            if not ok then LCM.Alerte(tostring(raison)) end
            e:Afficher()
        end)
        l.retirer:SetPoint("RIGHT", l, "RIGHT", -4, 0)
        e.lignes[rang] = l
        return l
    end

    function e:Afficher()
        local liste = D.Liste()
        for rang, d in ipairs(liste) do
            local l = self.lignes[rang] or Ligne(rang)
            l.difficulte = d.valeur
            if not l.valeur:HasFocus() then l.valeur:SetText(tostring(d.valeur)) end
            l.couleur:Definir(d.rang, d.nom)
            Peindre(l.couleur.label, d.couleur)
            l.pastille:SetColorTexture(d.couleur[1], d.couleur[2], d.couleur[3], 1)
            Poser(l, self.zone.contenu, (rang - 1) * 26)
        end
        for rang = #liste + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.vide:SetShown(#liste == 0)
        self.zone:Regler(math.max(1, #liste * 26))
        self.nombre = #liste
    end

    page.difficultes = e
    return e
end

-- L'editeur des METIERS (2 novembre 2026) : un seul tableau, les six couleurs
-- en colonnes, pour deux choses qui se lisent ensemble.
--   * La PROGRESSION : le cout en XP pour achever chaque niveau. Le seuil
--     cumule se CALCULE (Metiers.Paliers) : il est en infobulle sur chaque
--     case, et la rangee « Fin de couleur » donne celui du dernier niveau.
--   * L'XP GAGNEE : le coefficient applique a N selon que la difficulte est
--     plus basse, de la meme couleur, ou plus haute que le metier.
-- La premiere version empilait « seuil 400 » sous chaque case et rangeait les
-- coefficients ailleurs, en lignes ; « pas super glamour » (le MJ). Les
-- chemins de reglage n'ont pas change : « metiers.paliers.N.xp » et
-- « difficultes.matrice.<metier>.<difficulte> » (une case par couple de
-- couleurs depuis le 2 novembre 2026, au lieu de trois relations).
local function ConstruirePaliers(page, parent)
    local R = LCM.Reglages
    local D = LCM.Difficultes
    local e = CreateFrame("Frame", nil, parent)
    e:Hide()

    -- Sept colonnes depuis le Noir (3 novembre 2026) : a 110 + 7 x 68 la
    -- derniere sortait du Panel. 104 + 7 x 62 = 538 tient dans la page.
    local ETIQUETTE, COL, CASE, LIGNE_T = 104, 62, 50, 26

    e.titre = Titre(e, "Métiers")
    e.titre:SetPoint("TOPLEFT", e, "TOPLEFT", 0, 0)
    e.aide = UI.Texte(e, "Le coût pour achever chaque niveau, puis l'XP gagnée selon la difficulté affrontée (récolte, campement…). "
        .. "Le seuil cumulé se calcule seul : survole une case.", UI.C.discret)
    UI.Police(e.aide, 10)
    e.aide:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -18)
    e.aide:SetPoint("RIGHT", e, "RIGHT", 0, 0)
    e.aide:SetJustifyH("LEFT")
    e.aide:SetWordWrap(true)

    local couleurs = D.CouleursMetier()
    local largeur = ETIQUETTE + #couleurs * COL
    local y = 0

    -- Le tableau DEFILE (le MJ, 3 novembre 2026) : depuis que l'echelle a
    -- pris 19 paliers, la grille d'XP sortait par le bas du Panel. Le titre
    -- et l'aide restent en place ; tout le tableau passe dans la zone.
    e.zone = UI.Defilement(e)
    e.zone:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -50)
    e.zone:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -10, 0)
    local tab = e.zone.contenu

    -- L'en-tete : le nom de chaque couleur, souligne de sa teinte.
    for i, c in ipairs(couleurs) do
        local x = ETIQUETTE + (i - 1) * COL
        local t = UI.Texte(tab, UI.Majuscules(c.nom), UI.C.titre, "GameFontNormalSmall")
        UI.Police(t, 11)
        t:SetTextColor(c.couleur[1], c.couleur[2], c.couleur[3])
        t:SetPoint("TOPLEFT", tab, "TOPLEFT", x, -y)
        t:SetWidth(COL - 6)
        t:SetJustifyH("CENTER")
        local trait = UI.Aplat(tab, { c.couleur[1], c.couleur[2], c.couleur[3], 0.85 }, "ARTWORK")
        trait:SetHeight(2)
        trait:SetPoint("TOPLEFT", tab, "TOPLEFT", x + 4, -(y + 16))
        trait:SetWidth(COL - 14)
    end
    y = y + 24

    -- Une rangee : un fond de ligne sur toute la largeur du tableau, son
    -- etiquette a gauche, et une case par couleur.
    local function Rangee(etiquette)
        local r = CreateFrame("Frame", nil, tab)
        r:SetSize(largeur, LIGNE_T - 2)
        r:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -y)
        if UI.SurfaceLigne then UI.SurfaceLigne(r) end
        r.etiquette = UI.Texte(r, etiquette, UI.C.texte)
        UI.Police(r.etiquette, 11)
        r.etiquette:SetPoint("LEFT", r, "LEFT", 10, 0)
        y = y + LIGNE_T
        return r
    end
    local function Section(texte)
        y = y + 8
        local t = UI.Texte(tab, UI.Majuscules(texte), UI.C.libelle, "GameFontNormalSmall")
        UI.Police(t, 10)
        t:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -y)
        local filet = UI.Filet(tab, true)
        filet:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -(y + 15))
        filet:SetWidth(largeur)
        y = y + 20
    end
    local function Case(rangee, i, chemin, valider)
        local champ = UI.Champ(rangee, CASE, 20)
        champ:SetJustifyH("CENTER")
        champ:SetPoint("LEFT", rangee, "LEFT", ETIQUETTE + (i - 1) * COL + (COL - 6 - CASE) / 2, 0)
        champ.chemin = chemin
        champ:SetScript("OnEnterPressed", function(self)
            local ok, raison = valider(self:GetText())
            if ok then
                ok, raison = R.Definir(self.chemin, tonumber(self:GetText()))
            end
            if not ok and raison then LCM.Alerte(tostring(raison)) end
            self:ClearFocus()
            e:Afficher()
        end)
        champ:SetScript("OnEscapePressed", function(self) self:ClearFocus() e:Afficher() end)
        UI.Bulle(champ, function(soi) return soi.bulleTitre end, function(soi) return soi.bulleTexte end)
        return champ
    end

    -- ----- la progression ---------------------------------------------------
    local function CoutValide(texte)
        local v = tonumber(texte)
        if not v or v < 0 or v ~= math.floor(v) then
            return false, "le coût d'un niveau est un nombre entier d'XP, positif."
        end
        return true
    end
    Section("Progression : XP pour achever le niveau")
    e.cases = {}
    local paliers = LCM.Metiers.Paliers()
    local parPlace = {}
    for indice, palier in ipairs(paliers) do
        parPlace[(tonumber(palier.niveau) or 0) .. ":" .. (tonumber(palier.rangCouleur) or 0)] = indice
    end
    for niveau = 1, 5 do
        local r = Rangee("Niveau " .. niveau)
        for i, c in ipairs(couleurs) do
            local indice = parPlace[niveau .. ":" .. c.rang]
            if indice then
                local champ = Case(r, i, string.format("metiers.paliers.%d.xp", indice), CoutValide)
                champ.indice = indice
                e.cases[indice] = champ
            end
        end
    end
    -- La fin de chaque couleur : le seuil cumule de son niveau 5, en lecture.
    local fin = Rangee("Fin de couleur")
    fin.etiquette:SetTextColor(UI.C.discret[1], UI.C.discret[2], UI.C.discret[3])
    e.fins = {}
    for i, c in ipairs(couleurs) do
        local t = UI.Texte(fin, "", UI.C.discret)
        UI.Police(t, 10)
        t:SetPoint("LEFT", fin, "LEFT", ETIQUETTE + (i - 1) * COL, 0)
        t:SetWidth(COL - 6)
        t:SetJustifyH("CENTER")
        e.fins[c.rang] = t
    end

    -- ----- l'XP gagnee -------------------------------------------------------
    local function CoefValide(texte)
        local v = tonumber(texte)
        if not v or v < 0 then return false, "un coefficient est un nombre positif (0,5 = la moitié de N)." end
        return true
    end
    -- Une rangee par couleur de difficulte, une colonne par couleur de METIER :
    -- chaque couple a son coefficient (le MJ, 2 novembre 2026 : « Rose qui
    -- mine du Vert, 1,5 ; Rouge qui mine de l'Orange, 0,5 »). La case ou les
    -- deux couleurs se rencontrent est soulignee.
    -- Les rangees suivent l'echelle des Nommages (les difficultes), les
    -- colonnes les sept couleurs de base des metiers, qui n'en dependent pas
    -- (le MJ, 3 novembre 2026). « Se rencontrer » se lit donc au NOM : la
    -- case Rose × Rose est soulignee, pas Rose × « Rose Facile » qui porte le
    -- numero 1 — le MJ veut « le milieu de chaque couleur ».
    Section("XP gagnée : N × coefficient, selon la difficulté")
    e.coefs = {}
    for _, diff in ipairs(D.Couleurs()) do
        local r = Rangee(diff.nom)
        r.etiquette:SetTextColor(diff.couleur[1], diff.couleur[2], diff.couleur[3])
        for i, c in ipairs(couleurs) do
            e.coefs[c.rang] = e.coefs[c.rang] or {}
            local champ = Case(r, i, D.CheminCoefficient(c.rang, diff.rang), CoefValide)
            champ.bulleTitre = string.format("Métier %s sur une difficulté %s", c.nom, diff.nom)
            champ.metier, champ.difficulte = c, diff
            -- Le cote GRAPHIQUE (le MJ) : la case se teinte selon sa valeur,
            -- la grille se lit comme une carte de chaleur (Afficher, plus bas).
            champ.chaleur = UI.Aplat(r, { 1, 1, 1, 0 }, "BACKGROUND")
            champ.chaleur:SetPoint("TOPLEFT", champ, "TOPLEFT", -5, 3)
            champ.chaleur:SetPoint("BOTTOMRIGHT", champ, "BOTTOMRIGHT", 5, -3)
            -- La case ou les deux couleurs se rencontrent : un trait de la
            -- couleur, sous la case.
            if tostring(c.nom):lower() == tostring(diff.nom):lower() then
                champ.rencontre = true
                local trait = UI.Aplat(r, { c.couleur[1], c.couleur[2], c.couleur[3], 0.9 }, "ARTWORK")
                trait:SetHeight(2)
                trait:SetPoint("TOPLEFT", champ, "BOTTOMLEFT", 2, -1)
                trait:SetPoint("TOPRIGHT", champ, "BOTTOMRIGHT", -2, -1)
            end
            e.coefs[c.rang][diff.rang] = champ
        end
    end

    e.total = UI.Texte(tab, "", UI.C.libelle)
    UI.Police(e.total, 11)
    e.total:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -(y + 8))

    -- La grille PAR DEFAUT, d'un geste (le MJ, 3 novembre 2026 : « que le
    -- bouton reset tout »). Chaque case reprend la regle de
    -- Equilibrage.difficultes.defaut appliquee a la COULEUR du palier (Core/
    -- Difficultes.lua) : la case soulignee vaut 1. La matrice du fichier,
    -- rangee par numero sur l'echelle de depart, mettait 1,5 sur Rose x Rose
    -- des que l'echelle a ete decoupee. Un geste du MJ, confirme, pas une
    -- correction au chargement : ce qu'il a saisi a la main est remplace.
    -- Un palier sans couleur reconnaissable dans son nom garde ses cases, et
    -- c'est dit. Rend le nombre de cases changees et de paliers ignores.
    function e:RemettreParDefaut()
        local n, ignores, vus = 0, 0, {}
        for _, ligne in pairs(self.coefs) do
            for _, champ in pairs(ligne) do
                local v = D.CoefficientParDefaut(champ.metier.rang, champ.difficulte.nom)
                if v == nil then
                    if not vus[champ.difficulte.rang] then
                        vus[champ.difficulte.rang] = true
                        ignores = ignores + 1
                    end
                elseif tonumber(R.Lire(champ.chemin)) ~= v then
                    if R.Definir(champ.chemin, v) then n = n + 1 end
                end
            end
        end
        self:Afficher()
        local texte = string.format("Grille d'XP remise par défaut : %d case(s) changée(s).", n)
        if ignores > 0 then
            texte = texte .. string.format(" %d palier(s) sans couleur reconnue dans leur nom gardent leurs cases.", ignores)
        end
        LCM.Info(texte)
        return n, ignores
    end
    e.confirmerGrille = UI.Confirmer(e, "", "Remettre")
    e.aligner = UI.Bouton(tab, "Grille par défaut", 150, 22, function()
        e.confirmerGrille:Demander("Remettre toute la grille d'XP par défaut ? Les coefficients saisis à la main "
            .. "seront remplacés (1 sur les cases soulignées, +0,5 par couleur au-dessus, 0,5 une couleur "
            .. "en dessous, 0 au-delà).", function() e:RemettreParDefaut() end)
    end)
    e.aligner:SetPoint("TOPRIGHT", tab, "TOPLEFT", largeur, -(y + 4))
    UI.Bulle(e.aligner, "Grille par défaut",
        "Remet chaque case de la grille d'XP selon la règle de départ, appliquée à la couleur du palier : "
        .. "Rose Facile, Rose et Rose Difficile comptent comme du Rose. Demande confirmation.")

    e.zone:Regler(y + 36)

    function e:Afficher()
        local paliers = LCM.Metiers.Paliers()
        local surcharges = R.Surcharges()
        local function Teinter(champ)
            local c = surcharges[champ.chemin] ~= nil and UI.C.accent or UI.C.texte
            champ:SetTextColor(c[1], c[2], c[3])
            return surcharges[champ.chemin] ~= nil
        end
        for indice, champ in pairs(self.cases) do
            local palier = paliers[indice]
            if not champ:HasFocus() then champ:SetText(tostring(palier.xp)) end
            local regle = Teinter(champ)
            champ.bulleTitre = string.format("%s %s", tostring(palier.nom), tostring(palier.niveau))
            champ.bulleTexte = string.format("Coût pour achever ce niveau : %s XP.\nSeuil cumulé (calculé) : %s XP.%s",
                tostring(palier.xp), UI.Nombre(palier.cumul),
                regle and ("\nRéglé. Le fichier dit " .. tostring(R.Defaut(champ.chemin)) .. ".") or "")
        end
        for _, palier in ipairs(paliers) do
            if tonumber(palier.niveau) == 5 and self.fins[tonumber(palier.rangCouleur)] then
                self.fins[tonumber(palier.rangCouleur)]:SetText(UI.Nombre(palier.cumul))
            end
        end
        -- La chaleur : rouge sombre a x0, rien a x1, de plus en plus vert
        -- au-dessus, rapporte au plus grand coefficient de la grille.
        local plusGrand = 1
        for _, ligne in pairs(self.coefs) do
            for _, champ in pairs(ligne) do
                plusGrand = math.max(plusGrand, tonumber(R.Lire(champ.chemin)) or 0)
            end
        end
        for _, ligne in pairs(self.coefs) do
            for cle, champ in pairs(ligne) do
                local valeur = tonumber(R.Lire(champ.chemin)) or 1
                if valeur < 1 then
                    champ.chaleur:SetColorTexture(0.65, 0.12, 0.10, 0.12 + 0.38 * (1 - valeur))
                elseif valeur > 1 then
                    local part = plusGrand > 1 and (valeur - 1) / (plusGrand - 1) or 0
                    champ.chaleur:SetColorTexture(0.20, 0.70, 0.25, 0.10 + 0.45 * part)
                else
                    champ.chaleur:SetColorTexture(1, 1, 1, 0)
                end
                if not champ:HasFocus() then champ:SetText(tostring(R.Lire(champ.chemin) or "")) end
                local regle = Teinter(champ)
                champ.bulleTexte = string.format("Un métier %s face à une difficulté %s gagne N × ce coefficient.%s",
                    champ.metier.nom, champ.difficulte.nom,
                    regle and ("\nRéglé. Le fichier dit " .. tostring(R.Defaut(champ.chemin)) .. ".") or "")
            end
        end
        local dernier = paliers[#paliers]
        self.total:SetText(dernier and string.format("Maîtrise complète : %s XP.", UI.Nombre(dernier.cumul)) or "")
    end

    page.paliers = e
    return e
end

-- La page, refaite le 2 novembre 2026 sur la vue de EquilibrageVue.lua :
-- themes et groupes nommes a gauche, sous-sections a droite, un libelle lu
-- plutot qu'un identifiant, la valeur posee a Entree. RIEN n'a change dans
-- la facon de regler : meme LCM.Reglages, meme chemin, meme diffusion, meme
-- export. Seul l'ecran a change.
local ACCENTS_MAJ = { ["é"] = "É", ["è"] = "È", ["ê"] = "Ê", ["à"] = "À", ["â"] = "Â", ["î"] = "Î",
    ["ô"] = "Ô", ["û"] = "Û", ["ç"] = "Ç" }

local function Capitale(texte)
    texte = tostring(texte or "")
    for minuscule, majuscule in pairs(ACCENTS_MAJ) do
        if texte:sub(1, #minuscule) == minuscule then return majuscule .. texte:sub(#minuscule + 1) end
    end
    return texte:sub(1, 1):upper() .. texte:sub(2)
end

-- « coutPASoin » -> { "cout", "PA", "Soin" } ; « pen_lumiere » -> { "pen", "lumiere" }.
local function Mots(segment)
    local s = tostring(segment or "")
    s = s:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2"):gsub("[_:]", " ")
    local out = {}
    for mot in s:gmatch("%S+") do out[#out + 1] = mot end
    return out
end

local function Lire(mots)
    local vue = MJ.EquilibrageVue
    local out = {}
    for _, mot in ipairs(mots) do
        out[#out + 1] = (vue and vue.mots[mot:lower()]) or mot:lower()
    end
    return table.concat(out, " ")
end

-- Un segment de chemin, lisible. Un indice de liste prend le nom de ce
-- qu'il designe (« secondaires.4 » -> « Points d'action ») ; un niveau de
-- metier, sa couleur et son rang (« Vert 3 »).
local function Segment(segment, noeud, parent)
    local indice = tonumber(segment)
    if indice and type(noeud) == "table" then
        if noeud.label then return tostring(noeud.label) end
        if noeud.nom and noeud.niveau then return tostring(noeud.nom) .. " " .. tostring(noeud.niveau) end
        if noeud.nom then return tostring(noeud.nom) end
        if noeud.id then return Capitale(Lire(Mots(noeud.id))) end
        if noeud.niveau then return "Niveau " .. tostring(noeud.niveau) end
    end
    if indice then
        return (tostring(parent) == "niveaux" and "Niveau " or "n° ") .. tostring(indice)
    end
    return Capitale(Lire(Mots(segment)))
end

-- Les lignes d'un groupe de la vue : { chemin, valeur, defaut, section,
-- libelle }. Les sous-sections viennent du chemin ; dans un groupe « plat »
-- (actions : quarante-six nombres au meme niveau), du PREMIER MOT, des que
-- deux nombres le partagent.
local function Masque(chemin)
    for _, motif in ipairs(MJ.EquilibrageVue and MJ.EquilibrageVue.masques or {}) do
        if tostring(chemin):find(motif) then return true end
    end
    return false
end

local function LignesGroupe(g)
    local R = LCM.Reglages
    local vue = MJ.EquilibrageVue or {}
    local out = {}
    if g.chemins then
        for _, chemin in ipairs(g.chemins) do
            local valeur = R.Lire(chemin)
            if type(valeur) == "number" then
                out[#out + 1] = { chemin = chemin, valeur = valeur, defaut = R.Defaut(chemin),
                    section = "", libelle = (vue.libelles or {})[chemin] or Segment(chemin) }
            end
        end
        return out
    end
    local racine = LCM.Equilibrage[g.id]
    local premiers = {}
    for _, v in ipairs(R.Vecteurs(g.id)) do
        if not Masque(v.chemin) then
            local relatif = v.chemin:sub(#g.id + 2)
            local bouts = {}
            for b in relatif:gmatch("[^%.]+") do bouts[#bouts + 1] = b end
            local noms, noeud, parent = {}, racine, nil
            for i, b in ipairs(bouts) do
                local cle = tonumber(b) and type(noeud) == "table" and noeud[tonumber(b)] ~= nil and tonumber(b) or b
                noeud = type(noeud) == "table" and noeud[cle] or nil
                noms[i] = Segment(b, noeud, parent)
                parent = b
            end
            local ligne = { chemin = v.chemin, valeur = v.valeur, defaut = v.defaut, bouts = bouts }
            -- Le dernier ELEMENT DE LISTE du chemin (« campement.actions.4 »),
            -- pour replier plus bas les elements qui ne portent qu'un ou deux
            -- nombres : trente sections « Rose 1 », « Rose 2 » de deux lignes
            -- chacune se lisaient moins bien qu'une section de soixante.
            for k = #bouts - 1, 1, -1 do
                if tonumber(bouts[k]) then
                    local parent, reste = {}, {}
                    for i = 1, k - 1 do parent[#parent + 1] = noms[i] end
                    for i = k + 1, #bouts do reste[#reste + 1] = Lire(Mots(bouts[i])) end
                    ligne.pli = { cle = table.concat(bouts, ".", 1, k), parent = table.concat(parent, " · "),
                        libelle = noms[k] .. " · " .. table.concat(reste, " ") }
                    break
                end
            end
            if #bouts == 1 then
                local mots = Mots(bouts[1])
                ligne.plat = true
                ligne.premier = mots[1] and mots[1]:lower() or ""
                ligne.sectionPlate = Capitale(Lire({ mots[1] or "" }))
                local reste = {}
                for i = 2, #mots do reste[#reste + 1] = mots[i] end
                ligne.reste = #reste > 0 and Capitale(Lire(reste)) or nil
                ligne.libelle = noms[1]
                premiers[ligne.premier] = (premiers[ligne.premier] or 0) + 1
            else
                ligne.section = table.concat(noms, " · ", 1, #noms - 1)
                ligne.libelle = noms[#noms]
            end
            ligne.libelle = (vue.libelles or {})[v.chemin] or ligne.libelle
            out[#out + 1] = ligne
        end
    end
    local parElement = {}
    for _, l in ipairs(out) do
        if l.pli then parElement[l.pli.cle] = (parElement[l.pli.cle] or 0) + 1 end
    end
    for _, l in ipairs(out) do
        if l.pli and parElement[l.pli.cle] <= 3 and not (vue.libelles or {})[l.chemin] then
            l.section, l.libelle = l.pli.parent, l.pli.libelle
        end
    end
    for _, l in ipairs(out) do
        if l.plat then
            if premiers[l.premier] >= 2 and l.reste and not (vue.libelles or {})[l.chemin] then
                l.section, l.libelle = l.sectionPlate, l.reste
            else
                l.section = ""
            end
        end
    end
    -- L'ordre : les nombres sans section d'abord, puis section par section,
    -- les indices dans l'ordre des nombres (2 avant 10).
    local function Comparer(a, b)
        if (a.section == "") ~= (b.section == "") then return a.section == "" end
        local ba, bb = a.bouts or {}, b.bouts or {}
        for i = 1, math.max(#ba, #bb) do
            local x, y = ba[i], bb[i]
            if x == nil then return true end
            if y == nil then return false end
            if x ~= y then
                local nx, ny = tonumber(x), tonumber(y)
                if nx and ny then return nx < ny end
                return tostring(x) < tostring(y)
            end
        end
        return false
    end
    table.sort(out, Comparer)
    return out
end

-- Tous les groupes : ceux de la vue, puis « Autres » pour ce que la vue ne
-- nomme pas. Un nombre ajoute a l'equilibrage sans etre range ici reste
-- donc a l'ecran.
local function GroupesVue()
    local vue = MJ.EquilibrageVue or { themes = {} }
    local themes, connus = {}, {}
    for _, theme in ipairs(vue.themes or {}) do
        local t = { titre = theme.titre, groupes = {} }
        for _, g in ipairs(theme.groupes or {}) do
            if g.chemins or type(LCM.Equilibrage[g.id]) == "table" then
                t.groupes[#t.groupes + 1] = g
                connus[g.id] = true
            end
        end
        themes[#themes + 1] = t
    end
    local autres = { titre = "Autres", groupes = {} }
    for _, id in ipairs(LCM.Reglages.Groupes()) do
        if not connus[id] then autres.groupes[#autres.groupes + 1] = { id = id, label = Capitale(Lire(Mots(id))) } end
    end
    if #autres.groupes > 0 then themes[#themes + 1] = autres end
    return themes
end

function Pages.equilibrage(page, f)
    local R = LCM.Reglages
    local NAV_EQ = 180
    local LIGNE_EQ = 24

    page.titre = Titre(page, "Équilibrage")
    page.titre:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -2)
    -- La recherche traverse TOUS les groupes : on sait ce qu'on cherche,
    -- rarement ou il est range.
    page.recherche = UI.Champ(page, 220, 22, function() page:Afficher() end)
    page.recherche:SetPoint("LEFT", page.titre, "RIGHT", 16, 0)
    page.recherche:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    page.recherche:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    page.recherche.indice = UI.Texte(page.recherche, "Chercher un réglage…", UI.C.discret)
    UI.Police(page.recherche.indice, 10)
    page.recherche.indice:SetPoint("LEFT", page.recherche, "LEFT", 6, 0)
    page.resume = UI.Texte(page, "", UI.C.discret)
    UI.Police(page.resume, 10)
    page.resume:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -6)
    page.resume:SetJustifyH("RIGHT")

    -- La colonne : themes et groupes, dans la navigation du Panel.
    page.colonne = UI.Defilement(page)
    page.colonne:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -32)
    page.colonne:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    page.colonne:SetWidth(NAV_EQ)
    page.themes = GroupesVue()
    page.parId = {}
    local sections = {}
    for _, theme in ipairs(page.themes) do
        local entrees = {}
        for _, g in ipairs(theme.groupes) do
            entrees[#entrees + 1] = { id = g.id, label = g.label }
            page.parId[g.id] = g
        end
        sections[#sections + 1] = { titre = theme.titre, entrees = entrees }
    end
    page.nav = UI.Navigation(page.colonne.contenu, sections, function(id) page:Choisir(id) end,
        { largeur = NAV_EQ - 14, hauteur = 22 })
    page.nav:SetPoint("TOPLEFT", page.colonne.contenu, "TOPLEFT", 0, 0)
    page.colonne:Regler(page.nav:GetHeight())
    -- L'ancien nom, que le banc et d'autres lisaient.
    page.boutonsGroupe = page.nav.boutons

    -- Le tableau.
    page.zone = UI.Defilement(page)
    page.zone:SetPoint("TOPLEFT", page, "TOPLEFT", NAV_EQ + 12, -32)
    page.zone:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 0)
    page.lignes, page.entetes = {}, {}
    page.vide = UI.Texte(page.zone.contenu, "", UI.C.discret)
    page.vide:SetPoint("TOPLEFT", page.zone.contenu, "TOPLEFT", 6, -6)
    page.groupe = nil
    ConstruireDifficultes(page, page)
    page.difficultes:SetPoint("TOPLEFT", page.zone, "TOPLEFT", 0, 0)
    page.difficultes:SetPoint("BOTTOMRIGHT", page.zone, "BOTTOMRIGHT", 0, 0)
    ConstruireNommages(page, page)
    page.nommages:SetPoint("TOPLEFT", page.zone, "TOPLEFT", 0, 0)
    page.nommages:SetPoint("BOTTOMRIGHT", page.zone, "BOTTOMRIGHT", 0, 0)
    ConstruirePaliers(page, page)
    page.paliers:SetPoint("TOPLEFT", page.zone, "TOPLEFT", 0, 0)
    page.paliers:SetPoint("BOTTOMRIGHT", page.zone, "BOTTOMRIGHT", 0, 0)
    -- Les groupes qui ont leur propre editeur plutot que le tableau.
    page.editeurs = { difficultes = page.difficultes, metiers = page.paliers, nommages = page.nommages }

    local function EnTete(rang)
        local h = page.entetes[rang]
        if h then return h end
        h = CreateFrame("Frame", nil, page.zone.contenu)
        h:SetHeight(22)
        h.texte = UI.Texte(h, "", UI.C.libelle, "GameFontNormalSmall")
        UI.Police(h.texte, 11)
        h.texte:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 4, 4)
        h.filet = UI.Filet(h, true)
        h.filet:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 1)
        h.filet:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 1)
        page.entetes[rang] = h
        return h
    end

    -- Une ligne : le libelle, et a droite la valeur. Entree pose, Echap rend
    -- ce qui est en vigueur. Une valeur reglee passe en or, dit ce que le
    -- fichier disait et offre d'y revenir.
    local function Ligne(rang)
        local l = page.lignes[rang]
        if l then return l end
        l = CreateFrame("Frame", nil, page.zone.contenu)
        l:SetHeight(LIGNE_EQ - 2)
        if UI.SurfaceLigne then UI.SurfaceLigne(l) end
        l.saisie = UI.Champ(l, 72, 18, nil)
        l.saisie:SetJustifyH("RIGHT")
        l.saisie:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        l.saisie:SetScript("OnEnterPressed", function(e)
            local ok, raison = R.Definir(l.chemin, e:GetText())
            e:ClearFocus()
            if not ok then LCM.Alerte(tostring(raison)) end
            page:Afficher()
        end)
        l.saisie:SetScript("OnEscapePressed", function(e)
            e:ClearFocus()
            page:Afficher()
        end)
        l.defaut = UI.Bouton(l, "", 20, 18, function()
            local ok, raison = R.Retirer(l.chemin)
            if not ok then LCM.Alerte(tostring(raison)) end
            page:Afficher()
        end)
        l.defaut:SetPoint("RIGHT", l.saisie, "LEFT", -4, 0)
        l.defaut.icone = l.defaut:CreateTexture(nil, "OVERLAY")
        l.defaut.icone:SetTexture("Interface\\Buttons\\UI-RefreshButton")
        l.defaut.icone:SetSize(12, 12)
        l.defaut.icone:SetPoint("CENTER", l.defaut, "CENTER", 0, 0)
        UI.Bulle(l.defaut, "Revenir au fichier", "Retire le réglage : la valeur du fichier revient.")
        l.fichier = UI.Texte(l, "", UI.C.discret)
        UI.Police(l.fichier, 10)
        l.fichier:SetPoint("RIGHT", l.defaut, "LEFT", -6, 0)
        l.nom = UI.Texte(l, "", UI.C.texte)
        UI.Police(l.nom, 11)
        l.nom:SetPoint("LEFT", l, "LEFT", 14, 0)
        l.nom:SetPoint("RIGHT", l.fichier, "LEFT", -8, 0)
        l.nom:SetJustifyH("LEFT")
        l.nom:SetWordWrap(false)
        -- UNE infobulle, posee ici : elle lit le texte de la ligne au survol.
        -- L'appeler a chaque rafraichissement empilait un crochet de plus.
        UI.Bulle(l, function(soi) return soi.bulleTitre end, function(soi) return soi.bulleTexte end)
        -- Pour le banc et l'ancien code : `poser` valide la saisie.
        l.poser = { Click = function() l.saisie:GetScript("OnEnterPressed")(l.saisie) end }
        page.lignes[rang] = l
        return l
    end

    function page:Choisir(groupe)
        self.groupe = groupe
        if self.recherche:GetText() ~= "" then self.recherche:SetText("") end
        self:Afficher()
    end

    -- Les lignes a montrer : le groupe choisi, ou tout ce que la recherche
    -- trouve, en-tete par groupe.
    function page:Collecter()
        local terme = Cherchable(self.recherche:GetText() or "")
        if terme == "" then
            local g = self.parId[self.groupe]
            if not g then return {} end
            return LignesGroupe(g), false
        end
        local out = {}
        for _, theme in ipairs(self.themes) do
            for _, g in ipairs(theme.groupes) do
                if g.id ~= "difficultes" then
                    for _, l in ipairs(LignesGroupe(g)) do
                        local texte = Cherchable(table.concat({ g.label, l.section or "", l.libelle or "", l.chemin }, " "))
                        if texte:find(terme, 1, true) then
                            l.section = g.label .. ((l.section or "") ~= "" and (" · " .. l.section) or "")
                            out[#out + 1] = l
                        end
                    end
                end
            end
        end
        return out, true
    end

    function page:Afficher()
        if not LCM.IsMaster() then return end
        if not self.groupe or not self.parId[self.groupe] then
            local premier = self.themes[1] and self.themes[1].groupes[1]
            self.groupe = premier and premier.id
        end
        local brut = self.recherche:GetText() or ""
        self.recherche.indice:SetShown(brut == "" and not self.recherche:HasFocus())
        self.nav:Selectionner(brut == "" and self.groupe or nil)

        local n = R.Compte()
        self.resume:SetText(n > 0
            and string.format("%d réglage%s à exporter — ils valent déjà chez tout le monde.", n, n > 1 and "s" or "")
            or "Aucun réglage : le jeu tourne sur le fichier.")

        -- Les groupes a editeur : les difficultes (une liste a laquelle on
        -- AJOUTE) et les paliers des metiers (une grille, seuils calcules).
        local editeur = brut == "" and self.editeurs[self.groupe] or nil
        for _, e in pairs(self.editeurs) do e:SetShown(e == editeur) end
        self.zone:SetShown(editeur == nil)
        if editeur then
            editeur:Afficher()
            return
        end

        local lignes, recherche = self:Collecter()
        local surcharges = R.Surcharges()
        local y, nL, nE, section = 0, 0, 0, nil
        for _, v in ipairs(lignes) do
            if (v.section or "") ~= section then
                section = v.section or ""
                if section ~= "" then
                    nE = nE + 1
                    local h = EnTete(nE)
                    h.texte:SetText(UI.Majuscules(section))
                    h:ClearAllPoints()
                    h:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
                    h:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
                    h:Show()
                    y = y + 24
                end
            end
            nL = nL + 1
            local l = Ligne(nL)
            l.chemin = v.chemin
            l.nom:SetText(v.libelle)
            if not l.saisie:HasFocus() then l.saisie:SetText(tostring(v.valeur)) end
            local regle = surcharges[v.chemin] ~= nil
            local c = regle and UI.C.accent or UI.C.texte
            l.nom:SetTextColor(c[1], c[2], c[3])
            l.saisie:SetTextColor(c[1], c[2], c[3])
            l.defaut:SetShown(regle)
            l.fichier:SetShown(regle)
            l.fichier:SetText(regle and ("fichier : " .. tostring(v.defaut)) or "")
            -- L'infobulle dit d'abord a quoi sert le nombre (EquilibrageVue,
            -- Vue.Aide), puis son etat, et l'identifiant en dernier, en gris.
            local aide = MJ.EquilibrageVue and MJ.EquilibrageVue.Aide and MJ.EquilibrageVue.Aide(v.chemin)
            l.bulleTitre = v.libelle
            l.bulleTexte = (aide and (aide .. "\n\n") or "") .. (regle
                and string.format("Réglé à %s. Le fichier dit %s.", tostring(v.valeur), tostring(v.defaut))
                or "Valeur du fichier. Entrée pour en valider une autre.")
                .. "\n|cff808080" .. v.chemin .. "|r"
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE_EQ
        end
        for rang = nL + 1, #self.lignes do self.lignes[rang]:Hide() end
        for rang = nE + 1, #self.entetes do self.entetes[rang]:Hide() end
        self.vide:SetText(recherche and "Rien ne correspond." or "Rien à régler ici.")
        self.vide:SetShown(nL == 0)
        self.nombreLignes = nL
        self.zone:Regler(math.max(1, y))
    end

    -- Un reglage reçu d'ailleurs rafraichit le tableau : les deux MJ regardent
    -- la meme chose.
    local avant = R.onChange
    R.onChange = function(...)
        if avant then avant(...) end
        if f:IsShown() and f.onglet == "equilibrage" then page:Afficher() end
    end
end

-- Les outils partages ont leur propre fichier, et leur propre sous-menu
-- (OutilsUI.lua) : annonces, barres, compteurs et notes, chacun avec son
-- apparence, sa portee et sa bibliotheque. Cette page les tenait en une seule
-- vue tassee ou rien ne se reglait (le MJ, 20 octobre 2026).
function Pages.outils(page, f)
    if MJ.OutilsUI then MJ.OutilsUI.Page(page, f) end
end

-- ===== La fenetre ==========================================================

-- La preference etendu / compact : une preference d'ECRAN, comme la place
-- des fenetres. Elle ne decrit aucune structure ; effacee, le panneau
-- revient en etendu.
local function PreferenceCompact()
    LCM.EnsureDatabase()
    return type(LCM.db.panneauMJ) == "table" and LCM.db.panneauMJ.compact == true
end
local function RetenirCompact(compact)
    LCM.EnsureDatabase()
    if compact then
        LCM.db.panneauMJ = { compact = true }
    else
        LCM.db.panneauMJ = nil
    end
end

-- Basculer de version : un bouton DANS le contenu. Pose dans l'en-tete, a
-- cote de la croix, il chevauchait l'ornement du coin (capture du MJ,
-- 2 novembre 2026) — l'en-tete est au decor.
local function BoutonVersion(parent, texte, largeur, bulle, onClick)
    local b = UI.Bouton(parent, texte, largeur, 22, onClick)
    UI.Bulle(b, texte, bulle)
    return b
end

-- Au pied de la navigation, habille comme ses entrees (le MJ, 3 novembre
-- 2026 : « Version compacte » en bouton simple detonnait sous les onglets).
local function BoutonPied(parent, texte, largeur, bulle, onClick)
    local b = UI.BoutonNavigation(parent, texte, largeur, 26, onClick)
    UI.Bulle(b, texte, bulle)
    return b
end

-- Forcer la synchronisation (le MJ, 3 novembre 2026 : le binome s'etait
-- connecte sans rien recevoir). Le travail est dans Core/Synchro.lua ; ici,
-- on le dit en clair, y compris quand il n'y avait personne a joindre.
local function Synchroniser()
    local r = LCM.Synchro.Forcer()
    if not r.annonce then
        LCM.Alerte("synchronisation : personne à joindre (ni groupe, ni canal de l'addon).")
        return r
    end
    LCM.Info(string.format("Synchronisation relancée : base publique (%d entrées) proposée à tous, "
        .. "chacun reprend ce qui lui manque ; %d réglage(s) et %d entrée(s) en attente renvoyés aux MJ.",
        r.base, r.reglages, r.envois))
    return r
end
Ecran.Synchroniser = Synchroniser

-- Ce que l'habillage mange a l'interieur de la fenetre (liseré, equerres) :
-- le contenu commence et finit apres. A gauche, la navigation passait sous
-- la bordure doree (capture du MJ, 2 novembre 2026) ; seuls le bas et la
-- droite avaient leur retrait.
local function Retraits(f)
    local e = UI.AelEmprise(f)
    local dy = math.max(0, math.ceil(e.bas + 4 - (f.insetBas or 0)))
    local dx = math.max(0, math.ceil(e.cote + 4 - (f.insetCote or 0)))
    return dx, dy
end

local function Construire()
    local f = UI.Fenetre("panneau_mj", "Panel MJ", LARGEUR, HAUTEUR, { x = 40, y = 20 })
    Ecran.frame = f

    -- La navigation, a gauche. `f.barre` garde son nom : le reste du
    -- compagnon et le banc y cherchent les entrees (b.ongletId, b:Click()).
    f.barre = UI.Navigation(f.contenu, Navigation(), function(id, parentId)
        if id == "compendium" then
            -- Ouvrir le Compendium sans quitter la page en cours : la
            -- navigation se rallume sur celle-ci.
            local noeud = UI.Menu.Trouver("systeme_aelskar")
            if noeud and type(noeud.onClick) == "function" then noeud.onClick()
            else LCM.Alerte("le Compendium n'est pas disponible.") end
            f:Onglet(f.onglet or "joueurs")
            return
        end
        if parentId == "outils" then
            f:Onglet("outils", id:match("^outils:(.+)$"))
        else
            f:Onglet(id)
        end
    end, { largeur = NAV })
    f.separation = UI.Filet(f.contenu, true, true)

    f.pages = {}
    for _, onglet in ipairs(Ecran.ONGLETS) do
        local page = CreateFrame("Frame", nil, f.contenu)
        page:Hide()
        f.pages[onglet.id] = page
        Pages[onglet.id](page, f)
    end
    -- `pages.etats` : la partie etats de la page Groupe, pas une page de plus.
    -- Les boucles sur les pages passent donc par Ecran.ONGLETS.
    f.pages.etats = f.pages.joueurs.etats

    -- Les outils partages sont choisis par la navigation : leur propre
    -- rangee d'onglets ferait doublon, et leurs pages montent prendre sa place.
    local outils = f.pages.outils
    if outils.barre then outils.barre:Hide() end
    for _, sous in pairs(outils.sous or {}) do
        sous:ClearAllPoints()
        sous:SetPoint("TOPLEFT", outils, "TOPLEFT", 0, 0)
        sous:SetPoint("BOTTOMRIGHT", outils, "BOTTOMRIGHT", 0, 0)
    end

    -- Place la navigation et les pages dans les retraits de l'habillage.
    -- Refait a chaque ouverture : le theme a pu changer, et une page a pu
    -- revenir de la fenetre compacte.
    f.versCompact = BoutonPied(f.contenu, "Version compacte", NAV,
        "Une petite fenêtre pour la séance : états, groupe, personnage, scène et combat.",
        function() Ecran.Mode(true) end)
    f.synchroniser = BoutonPied(f.contenu, "Synchroniser", NAV,
        "Envoie la base publique à tous les joueurs connectés : chacun reprend ce qui lui manque "
        .. "ou a changé, compendium compris. Renvoie aussi tes réglages d'équilibrage et tes entrées "
        .. "pas encore dans la base commune aux autres MJ, et fait redemander coffres, récolte et "
        .. "vendeurs. Pour un binôme ou un joueur qui n'a rien reçu.",
        function() Synchroniser() end)

    function f:PlacerBas()
        local dx, dy = Retraits(self)
        self.barre:ClearAllPoints()
        self.barre:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", dx, -2)
        self.separation:ClearAllPoints()
        self.separation:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", dx + NAV + 7, 0)
        self.separation:SetPoint("BOTTOMLEFT", self.contenu, "BOTTOMLEFT", dx + NAV + 7, dy)
        -- Au pied de la navigation : on change de version comme on change de page.
        self.versCompact:ClearAllPoints()
        self.versCompact:SetPoint("BOTTOMLEFT", self.contenu, "BOTTOMLEFT", dx, dy)
        self.synchroniser:ClearAllPoints()
        self.synchroniser:SetPoint("BOTTOMLEFT", self.versCompact, "TOPLEFT", 0, 3)
        for _, onglet in ipairs(Ecran.ONGLETS) do
            local page = self.pages[onglet.id]
            page:SetParent(self.contenu)
            page:ClearAllPoints()
            page:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", dx + NAV + 14, 0)
            page:SetPoint("BOTTOMRIGHT", self.contenu, "BOTTOMRIGHT", -dx, dy)
        end
    end
    f:PlacerBas()

    -- `sorte` : pour les outils, lequel des quatre.
    function f:Onglet(id, sorte)
        id = ALIAS[id] or id
        if not self.pages[id] or id == "etats" then id = "joueurs" end
        self.onglet = id
        for _, onglet in ipairs(Ecran.ONGLETS) do
            self.pages[onglet.id]:SetShown(onglet.id == id)
        end
        local page = self.pages[id]
        if id == "outils" then
            page:Afficher()
            page:Sous(sorte or page.sorte)
            self.barre:Selectionner("outils:" .. tostring(page.sorte))
        else
            self.barre:Selectionner(id)
            page:Afficher()
        end
    end

    -- Rafraichit tout ; les champs que d'autres fichiers (et le banc) lisent
    -- sur la fenetre restent ceux de l'onglet Joueurs.
    function f:Afficher()
        for _, onglet in ipairs(Ecran.ONGLETS) do self.pages[onglet.id]:Afficher() end
        if Ecran.compact and Ecran.compact:IsShown() then Ecran.compact:AfficherCombat() end
        self.nombreAffiche = self.pages.joueurs.nombreAffiche
    end
    f.lignes = f.pages.joueurs.lignes
    f.raison = f.pages.joueurs.raison

    function f:Montrer(id, sorte)
        if Ecran.compact then Ecran.compact:Hide() end
        self.pages.joueurs:Disposer(false)
        self.pages.pnj:Disposer(false)
        self.pages.combat:Disposer(false)
        self:PlacerBas()
        self:Show()
        self:Onglet(id or self.onglet or "joueurs", sorte)
        self.nombreAffiche = self.pages.joueurs.nombreAffiche
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

-- ===== La version compacte =================================================
-- « Pour MJ en tranquillite et rapidite » (le MJ, 2 novembre 2026) : les
-- trois colonnes de la page Groupe, resserrees, la scene a un onglet, et un
-- seul bouton pour le combat. Les PAGES sont celles du panneau, deplacees
-- d'une fenetre a l'autre : il n'y a qu'un code pour poser un etat, faire un
-- regain ou remplir la scene.

-- « Que ca ne prenne pas un quart de l'ecran » (le MJ, 2 novembre 2026) :
-- une fenetre SOBRE (sans couronne ni cadre dore, comme les outils Coffres
-- et Cartes), et tout ce qui commande — onglets, Etendre, Combat — dans sa
-- barre de titre. 480 : 150 de catalogue, 186 de personnage, le groupe
-- entre les deux. La premiere version faisait 720 x 540.
local LARGEUR_COMPACTE, HAUTEUR_COMPACTE = 480, 380
local BARRE_COMPACTE = 24

local function ConstruireCompact()
    local panneau = Ecran.Fenetre()
    local c = UI.Fenetre("panneau_mj_compact", "MJ", LARGEUR_COMPACTE, HAUTEUR_COMPACTE, { x = 60, y = 0 },
        { enTeteSimple = true, sobre = true })
    Ecran.compact = c
    -- Le contenu commence sous la barre de titre, pas sous l'en-tete du
    -- modele qu'une fenetre sobre n'a pas.
    c.insetHaut, c.insetBas, c.insetCote = BARRE_COMPACTE + 4, 5, 5
    c.contenu:ClearAllPoints()
    c.contenu:SetPoint("TOPLEFT", c, "TOPLEFT", c.insetCote, -c.insetHaut)
    c.contenu:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -c.insetCote, c.insetBas)
    UI.Police(c.titre, 12)
    c.titre:ClearAllPoints()
    c.titre:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -8)

    c.barre = UI.Onglets(c, { { id = "joueurs", label = "Groupe" }, { id = "pnj", label = "Scène" } },
        function(id) c:Onglet(id) end, { largeur = 58, hauteur = 18 })
    c.barre:SetWidth(2 * 58 + 4)
    for _, b in ipairs(c.barre.boutons) do UI.Police(b.label, 10) end

    -- Le combat a la volee, en un bouton qui dit ce qu'il fera :
    --   rien en cours      -> invite le groupe et TOUTE la scene ;
    --   invitation lancee  -> lance sans attendre ceux qui n'ont pas repondu ;
    --   combat en cours    -> tour suivant.
    -- Le detail (choisir ses PNJ, revenir d'un tour) reste dans la version
    -- etendue, onglet Combat.
    local C = LCM.Combat
    -- Le bouton Combat (le MJ, 2 novembre 2026) : il OUVRE la page Combat
    -- dans la fenetre compacte — on y choisit qui est invite (PNJ et
    -- joueurs), on attend les reponses, on lance quand tout le monde est pret.
    -- Pendant un combat, il devient « Fin de combat », qui se confirme : un
    -- clic de travers l'arreterait chez tout le monde.
    c.confirmer = UI.Confirmer(c, "", "Terminer")
    -- Le bouton RAMENE toujours a la vue Combat (le MJ, 2 novembre 2026 : en
    -- la quittant, on ne pouvait plus y revenir). Pendant un combat il passe
    -- en rouge ; « Terminer le combat » est dans la page, en bas a droite.
    c.combat = UI.Bouton(c, "", 132, 18, function() c:Onglet("combat") end)
    -- Garde pour l'ancien code ; la page Combat porte Annuler et ses tours.
    c.terminer = UI.Bouton(c, "Terminer", 58, 18, function() end)
    c.terminer:Hide()

    function c:AfficherCombat()
        local etat = C.Etat()
        local texte, bulle
        if etat then
            texte, bulle = "Combat", "Un combat est en cours : clique pour y revenir. « Terminer le combat » est en bas à droite."
        elseif C.invitation then
            texte, bulle = "Combat (invitation)", "Les invités répondent : lance quand tout le monde est prêt."
        else
            texte, bulle = "Combat", "Ouvre le combat : choisis les PNJ et les joueurs invités."
        end
        self.combat.label:SetText(texte)
        self.combat.bulleTexte = bulle
        self.combat:Selectionner(self.onglet == "combat")
        -- En combat, le bouton passe au ROUGE (le MJ, 2 novembre 2026) : le
        -- CONTOUR et le texte, pas le coeur — un fond rouge noyait le libelle.
        -- Un cadre a part, un niveau au-dessus, pour que le contour du bouton
        -- ne le recouvre pas.
        if not self.combat.alerte then
            local alerte = CreateFrame("Frame", nil, self.combat)
            alerte:SetAllPoints(self.combat)
            alerte:SetFrameLevel(self.combat:GetFrameLevel() + 1)
            alerte:EnableMouse(false)
            UI.Bordure(alerte, { 0.90, 0.18, 0.14, 1 })
            self.combat.alerte = alerte
        end
        self.combat.alerte:SetShown(etat ~= nil)
        if etat then self.combat.label:SetTextColor(1, 0.35, 0.30) end
        self.terminer:Hide()
    end
    UI.Bulle(c.combat, "Combat", function(soi) return soi.bulleTexte end)

    -- La barre de titre : « MJ », les onglets, Etendre a gauche ; la croix,
    -- Combat et Terminer a droite. Refaite a chaque ouverture : la croix
    -- d'une fenetre peut etre re-posee par l'habillage.
    function c:Placer()
        local milieu = -(BARRE_COMPACTE / 2 + 2)
        self.fermer:ClearAllPoints()
        self.fermer:SetSize(16, 16)
        self.fermer:SetPoint("RIGHT", self, "TOPRIGHT", -6, milieu)
        self.barre:ClearAllPoints()
        self.barre:SetPoint("LEFT", self.titre, "RIGHT", 10, 0)
        self.barre:SetHeight(18)
        self.versEtendu:ClearAllPoints()
        self.versEtendu:SetPoint("LEFT", self.barre, "RIGHT", 6, 0)
        self.combat:ClearAllPoints()
        self.combat:SetPoint("RIGHT", self.fermer, "LEFT", -6, 0)
        self.terminer:ClearAllPoints()
        self.terminer:SetPoint("RIGHT", self.combat, "LEFT", -4, 0)
        for _, id in ipairs({ "joueurs", "pnj", "combat" }) do
            local page = panneau.pages[id]
            page:SetParent(self.contenu)
            page:ClearAllPoints()
            page:SetAllPoints(self.contenu)
        end
    end

    -- Trois vues : Groupe et Scene (les onglets), et Combat (le bouton).
    function c:Onglet(id)
        if id ~= "pnj" and id ~= "combat" then id = "joueurs" end
        self.onglet = id
        self.barre:Selectionner(id)
        for _, vue in ipairs({ "joueurs", "pnj", "combat" }) do
            panneau.pages[vue]:SetShown(vue == id)
        end
        panneau.pages[id]:Afficher()
        if self.AfficherCombat then self:AfficherCombat() end
    end

    function c:Montrer(id)
        panneau:Hide()
        panneau.pages.joueurs:Disposer(true)
        panneau.pages.pnj:Disposer(true)
        panneau.pages.combat:Disposer(true)
        self:Placer()
        self:Show()
        self:Onglet(id or self.onglet or "joueurs")
        self:AfficherCombat()
    end

    -- A cote des onglets : la seule autre « page » que la compacte n'a pas.
    c.versEtendu = BoutonVersion(c, "Étendre", 52,
        "Le panneau complet : combat détaillé, outils partagés, traits, équilibrage.",
        function() Ecran.Mode(false) end)
    c.versEtendu:SetHeight(18)
    UI.Police(c.versEtendu.label, 10)
    UI.Police(c.combat.label, 10)
    UI.Police(c.terminer.label, 10)

    -- Le combat change chez lui : le bouton suit.
    if C.Suivre then C.Suivre(function() if c:IsShown() then c:AfficherCombat() end end) end
    local avantInvitation = C.onInvitation
    C.onInvitation = function(...)
        if avantInvitation then avantInvitation(...) end
        if c:IsShown() then c:AfficherCombat() end
    end
    return c
end

function Ecran.Compact()
    if not Ecran.compact then ConstruireCompact() end
    return Ecran.compact
end

-- Passer d'une version a l'autre, sur la meme page quand elle existe des deux
-- cotes, et s'en souvenir pour la prochaine ouverture.
function Ecran.Mode(compact)
    RetenirCompact(compact)
    local panneau = Ecran.Fenetre()
    if compact then
        local id = (panneau.onglet == "pnj") and "pnj" or "joueurs"
        Ecran.Compact():Montrer(id)
        return Ecran.compact
    end
    local id = Ecran.compact and Ecran.compact.onglet or nil
    panneau:Montrer(id)
    return panneau
end

-- La fenetre ouverte, quelle que soit sa version.
function Ecran.Ouverte()
    if Ecran.compact and Ecran.compact:IsShown() then return Ecran.compact end
    if Ecran.frame and Ecran.frame:IsShown() then return Ecran.frame end
end

function Ecran.Basculer()
    local ouverte = Ecran.Ouverte()
    if ouverte then ouverte:Hide() return ouverte end
    if PreferenceCompact() then
        Ecran.Compact():Montrer()
        return Ecran.compact
    end
    local f = Ecran.Fenetre()
    f:Montrer()
    return f
end

-- Ce menu appartient au compagnon MJ, sans dupliquer les panneaux ni leur
-- logique reseau. Un raccourci ouvre le panneau sur la bonne entree — dans
-- la version compacte si c'est elle qu'on utilise et qu'elle a cette page.
-- L'ancien mode « page seule » cachait la navigation, et il fallait refermer
-- puis rouvrir pour passer d'un outil a l'autre.
local artMJ = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\"
local function Raccourci(id, label, icone, page, sorte)
    return { id = id, label = label, icone = artMJ .. icone .. ".tga", onClick = function()
        if not LCM.IsMaster() then return end
        local f = Ecran.Fenetre()
        if id == "mj_regain" then
            f:Hide()
            if Ecran.compact then Ecran.compact:Hide() end
            f.pages.joueurs.regainPanneau:Ouvrir()
            return
        end
        f.pages.joueurs.regainPanneau:Hide()
        local cible = ALIAS[page] or page
        if PreferenceCompact() and (cible == "joueurs" or cible == "pnj") then
            Ecran.Compact():Montrer(cible)
        else
            f:Montrer(page, sorte)
        end
    end }
end
UI.Menu.MJ = {
    Raccourci("mj_joueurs", "Joueurs", "fenetres-personnages", "joueurs"),
    Raccourci("mj_regain", "Regain", "actions-generation_soin", "joueurs"),
    Raccourci("mj_etats", "État", "actions-generation_debuff", "etats"),
    Raccourci("mj_combat", "Combats", "actions-offensives", "combat"),
    { id = "mj_outils", label = "Outils", icone = artMJ .. "fenetres-outils.tga", enfants = {
        Raccourci("mj_barres", "Barres", "actions-generation_bouclier", "outils", "barre"),
        Raccourci("mj_compteurs", "Compteurs", "actions-competences", "outils", "compteur"),
        Raccourci("mj_annonce", "Annonce", "actions-animation", "outils", "annonce"),
        Raccourci("mj_notes", "Notes", "fenetres-grimoires", "outils", "note"),
    } },
}

-- Une incarnation prise, rendue, un PNJ entre ou sort de scene — depuis la
-- fenetre Incarner, la fiche ou le combat : la page Scene suit, et le bouton
-- Combat de la version compacte (il compte les PNJ en scene). On enrobe les
-- quatre fonctions, comme Core/Scene.lua le fait pour diffuser : Incarner.lua
-- tient deja `Incarnation.onChange`, et il ne couvre ni l'entree ni la sortie.
local function SuivreScene()
    local pnj = Ecran.frame and Ecran.frame.pages.pnj
    if pnj and pnj:IsVisible() then pnj:Afficher() end
    if Ecran.compact and Ecran.compact:IsShown() then Ecran.compact:AfficherCombat() end
end
for _, nom in ipairs({ "Instancier", "Oublier", "Prendre", "Relacher" }) do
    local origine = LCM.Incarnation[nom]
    LCM.Incarnation[nom] = function(...)
        local a, b = origine(...)
        SuivreScene()
        return a, b
    end
end

LCM.WhenReady(function()
    UI.Menu.Lier("panneau_mj", Ecran.Basculer)
    -- Les paliers des Nommages rangés en contenu par la premiere version
    -- (liste « paliers ») passent en reglages, puis quittent le contenu.
    if LCM.IsMaster() and MJ.Nommages and MJ.Nommages.Reprendre then
        local ok, erreur = pcall(MJ.Nommages.Reprendre)
        if not ok then LCM.Erreur("reprise des Nommages : " .. tostring(erreur)) end
    end
    -- Changer d'incarnation rafraichit ce qui est ouvert : la fiche ne doit pas
    -- rester sur le personnage d'avant. Repris de la fenetre Incarner, retiree
    -- le 2 novembre 2026 au profit de la page Scène & PNJ.
    LCM.Incarnation.onChange = function()
        local fiche = UI.Fiche and UI.Fiche.frame
        if fiche and fiche:IsShown() then fiche:Montrer(LCM.Entities.Self()) end
        SuivreScene()
    end

    UI.Menu.Trouver("panneau_mj").onRightClick = function()
        if LCM.IsMaster() then UI.Radial.Basculer("mj") end
    end
    -- L'annonce de presence transporte aussi le personnage actif. Elle peut
    -- arriver apres l'ouverture du panneau : le libelle se remplace alors
    -- sans attendre un clic sur Rafraichir.
    if LCM.Presence and LCM.Presence.Suivre then
        LCM.Presence.Suivre(function()
            if Ecran.Ouverte() then
                Ecran.frame.pages.joueurs:Afficher()
            end
        end)
    end
    -- Une fiche qui arrive pendant que le panneau est ouvert s'y affiche.
    LCM.Fiches.onRecue = function(joueur, entity, actualisation)
        if not actualisation then LCM.Info(string.format("fiche de %s reçue.", tostring(joueur))) end
        local silencieuse = PrendreDemandeXP(joueur)
        local etats = Ecran.frame and Ecran.frame.pages.etats
        if etats and etats:IsVisible() and etats.joueurActif
            and NomCourt(etats.joueurActif) == NomCourt(joueur) then silencieuse = true end
        if Ecran.Ouverte() then Ecran.frame:Afficher() end
        local consultation = MJ.Consultation
        -- Une consultation DEJA ouverte sur ce joueur suit toujours sa fiche :
        -- le silence n'interdit que d'en ouvrir une. Depuis que la page Groupe
        -- choisit le joueur pour Consulter ET pour ses etats (2 novembre
        -- 2026), le silence des etats figeait la fenetre qu'on venait d'ouvrir.
        if consultation.fenetre and consultation.fenetre:IsShown()
            and consultation.joueur == joueur then
            consultation.Ouvrir(entity, consultation.onglet or "fiche", joueur)
        elseif not silencieuse then
            if not consultation.joueur and not actualisation then
                -- Seulement la PREMIERE fiche d'un joueur ouvre la fenetre.
                -- Une actualisation en ouvrait une aussi : poser un etat ou
                -- faire un regain depuis le panneau faisait repondre le
                -- joueur, et la fiche de l'autre s'ouvrait toute seule au
                -- milieu du geste (le MJ, 1er novembre 2026). Une
                -- consultation explicite ouvre la fenetre d'elle-meme, avant
                -- meme la reponse : elle ne passe pas par ici.
                consultation.Ouvrir(entity, "fiche", joueur)
            end
        end
    end
end)
