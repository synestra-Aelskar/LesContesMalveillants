-- Le panneau du maitre du jeu.
--
-- Il vit dans le COMPAGNON, et pas dans l'addon principal : c'est la seule
-- protection qui vaille. Un joueur n'a pas ce dossier, donc il n'a pas ce
-- code — le reste (verifications, droits) n'arrete que les curieux.
--
-- Refait le 3 octobre 2026 d'apres la fenetre du MJ de Necronicon
-- (Master.lua), en quatre onglets :
--   Joueurs   le suivi du groupe (Suivis de Necronicon) : addon present,
--             niveau et PV quand la fiche est arrivee, consulter, donner l'XP ;
--   Combat    ce qui etait la fenetre de combat a part (Combat.lua) ;
--   Contenu   les outils MJ deja ecrits mais eparpilles : la scene et
--             Incarner, l'Atelier, le compendium, les brouillons ;
--   Outils    annonces, compteurs, barres et notes partages avec les joueurs
--             (Core/Outils.lua ; les Outils de Necronicon).
-- Les onglets Général et Permissions de Necronicon ne sont pas repris : il n'y
-- a ici ni assistants MJ ni droits par interaction.
--
-- La consultation est a sens unique, et le joueur consulte en est prevenu
-- (Core/Fiches.lua) : on regarde par-dessus l'epaule, pas dans le dos.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local Ecran = {}
UI.PanneauMJ = Ecran
MJ.Panneau = Ecran

local LARGEUR, HAUTEUR = 700, 540
local LIGNE = 28

Ecran.ONGLETS = {
    { id = "joueurs", label = "Joueurs" },
    { id = "combat",  label = "Combat" },
    { id = "contenu", label = "PNJ & contenu" },
    { id = "outils",  label = "Outils" },
}

-- Le groupe, vu d'ici. Hors groupe, la liste est vide et la fenetre le dit —
-- plutot que de laisser croire a une panne.
local function Groupe()
    local out = {}
    if not (GetNumGroupMembers and UnitName) then return out end
    local nombre = GetNumGroupMembers() or 0
    if nombre == 0 then return out end
    local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
    local moi = LCM.PlayerId()
    for index = 1, nombre do
        local nom, royaume = UnitName(prefixe .. index)
        if nom then
            local complet = (royaume and royaume ~= "" and (nom .. "-" .. royaume)) or nom
            if complet ~= moi then out[#out + 1] = complet end
        end
    end
    table.sort(out)
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

-- ===== Joueurs =============================================================

function Pages.joueurs(page, f)
    -- La barre du haut : rafraichir a gauche, le motif commun a droite. Le
    -- motif avait sa place DANS la liste et recouvrait la premiere ligne.
    page.rafraichir = UI.Bouton(page, "Rafraîchir", 110, 22, function()
        if LCM.Presence and LCM.Presence.Demander then LCM.Presence.Demander(true) end
        page:Afficher()
    end)
    page.rafraichir:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.etat = UI.Texte(page, "", UI.C.discret)
    UI.Police(page.etat, 11)
    page.etat:SetPoint("LEFT", page.rafraichir, "RIGHT", 10, 0)

    -- Pourquoi on donne : le meme pour tout le monde a la fin d'une scene, donc
    -- une seule case pour la tablee plutot qu'une par joueur.
    page.raison = UI.Champ(page, 220, 20, nil)
    page.raison:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -1)
    page.raisonLabel = UI.Texte(page, "Motif de l'XP :", UI.C.discret)
    UI.Police(page.raisonLabel, 11)
    page.raisonLabel:SetPoint("RIGHT", page.raison, "LEFT", -6, 0)

    page.zone = UI.Defilement(page)
    page.zone:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -32)
    page.zone:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.lignes = {}
    page.vide = UI.Texte(page, "", UI.C.discret)
    UI.Police(page.vide, 11)
    page.vide:SetPoint("CENTER", page.zone, "CENTER", 0, 0)

    local function Ligne(rang)
        local l = Rangee(page.zone.contenu, LIGNE + 6)
        l.nom = UI.Texte(l, "", UI.C.texte)
        UI.Police(l.nom, 12)
        l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", 8, -3)
        l.detail = UI.Texte(l, "", UI.C.discret)
        UI.Police(l.detail, 10)
        l.detail:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -1)
        -- Le joueur est lu sur la ligne au moment du clic : les lignes sont
        -- reutilisees quand le groupe change.
        l.consulter = UI.Bouton(l, "Consulter", 90, 20, function()
            local cible = l.joueur
            local entity = LCM.Fiches.Recue(cible)
            if entity then
                MJ.Consultation.Ouvrir(entity, "fiche")
                return
            end
            local ok, raison = LCM.Fiches.Demander(cible)
            if not ok then LCM.Alerte(tostring(raison)) return end
            LCM.Info(string.format("fiche demandee a %s…", cible))
        end)
        l.consulter:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        l.reedition = UI.Bouton(l, "Réédition", 82, 20, function()
            local ok, raison = LCM.Creation.EnvoyerJeton(l.joueur)
            if not ok then LCM.Alerte(tostring(raison)) return end
            -- La réception répondra : on distingue ainsi « envoyé » de
            -- « réellement remis au personnage ».
            LCM.Info(string.format("jeton de réédition envoyé à %s…", tostring(l.joueur)))
        end)
        l.reedition:SetPoint("RIGHT", l.consulter, "LEFT", -8, 0)
        -- Donner de l'experience : le montant se tape a cote du nom, et le
        -- bouton l'envoie. Pas de menu, pas de fenetre a part — c'est un geste
        -- de fin de scene, repete, sur plusieurs joueurs d'affilee.
        l.xp = UI.Champ(l, 52, 20, nil)
        l.xp:SetPoint("RIGHT", l.reedition, "LEFT", -8, 0)
        l.xp:SetNumeric(true)
        l.donner = UI.Bouton(l, "+ XP", 52, 20, function()
            local montant = tonumber(l.xp:GetText())
            if not montant or montant <= 0 then
                LCM.Alerte("indique d'abord combien d'expérience.")
                return
            end
            local ok, raison = LCM.Experience.Envoyer(l.joueur, montant, page.raison:GetText())
            if not ok then LCM.Alerte(tostring(raison)) return end
            LCM.Ok(string.format("%d XP envoyés à %s.", montant, l.joueur))
            l.xp:SetText("")
        end)
        l.donner:SetPoint("RIGHT", l.xp, "LEFT", -4, 0)
        page.lignes[rang] = l
        return l
    end

    -- Ce qu'on sait d'un joueur, sans rien lui demander : l'addon vu ou non,
    -- et ce que dit sa derniere fiche recue.
    local function Detail(joueur)
        local morceaux = {}
        local present = LCM.Presence and LCM.Presence.Confirmee and LCM.Presence.Confirmee(joueur)
        morceaux[#morceaux + 1] = present and "addon présent" or "addon non confirmé"
        local entity, perimee = LCM.Fiches.Recue(joueur)
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
        return table.concat(morceaux, "  ·  ")
    end

    function page:Afficher()
        local membres = Groupe()
        local y = 0
        for rang, joueur in ipairs(membres) do
            local l = self.lignes[rang] or Ligne(rang)
            l.joueur = joueur
            l.nom:SetText(joueur)
            l.detail:SetText(Detail(joueur))
            Poser(l, self.zone.contenu, y)
            y = y + LIGNE + 6
        end
        for rang = #membres + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.zone:Regler(y)
        self.nombreAffiche = #membres
        self.vide:SetText(#membres > 0 and "" or "Personne dans le groupe.")
        self.etat:SetText(string.format("%d joueur%s", #membres, #membres > 1 and "s" or ""))
    end
end

-- ===== Combat ==============================================================

function Pages.combat(page, f)
    -- Resolu ici et pas au chargement : Combat.lua se charge apres ce fichier.
    page.combat = MJ.Combat.Construire(page, f)
    function page:Afficher() self.combat:Afficher() end
end

-- ===== PNJ & contenu =======================================================

function Pages.contenu(page, f)
    local MOITIE = (LARGEUR - 24) / 2 - 8

    -- ----- la scene : les PNJ en jeu ---------------------------------------
    page.titreScene = Titre(page, "PNJ en scène")
    page.titreScene:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.incarner = UI.Bouton(page, "Incarner…", 100, 22, function()
        if UI.Incarner then UI.Incarner.Basculer() end
    end)
    page.incarner:SetPoint("TOPLEFT", page, "TOPLEFT", MOITIE - 100, 2)
    page.zoneScene = UI.Defilement(page)
    page.zoneScene:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28)
    page.zoneScene:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 34)
    page.zoneScene:SetWidth(MOITIE)
    page.lignesScene = {}
    page.sceneVide = UI.Texte(page, "", UI.C.discret)
    UI.Police(page.sceneVide, 11)
    page.sceneVide:SetPoint("TOPLEFT", page.zoneScene, "TOPLEFT", 4, -4)
    page.sceneVide:SetPoint("TOPRIGHT", page.zoneScene, "TOPRIGHT", -4, -4)
    page.sceneVide:SetWordWrap(true)
    -- Les joueurs recoivent la scene a chaque changement ; ce bouton sert
    -- quand l'un d'eux arrive en cours de route ou a recharge.
    page.diffuser = UI.Bouton(page, "Renvoyer la scène au groupe", MOITIE, 24, function()
        if Dire(LCM.Scene.Diffuser(), "hors groupe : personne à qui envoyer la scène.") then
            LCM.Ok("scène renvoyée au groupe.")
        end
    end)
    page.diffuser:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)

    -- ----- le contenu : ou on le cree, ce qui attend -----------------------
    local x = MOITIE + 16
    page.titreContenu = Titre(page, "Contenu")
    page.titreContenu:SetPoint("TOPLEFT", page, "TOPLEFT", x, 0)
    -- Les fenetres sont ouvertes par leur entree de menu quand elles en ont
    -- une : le panneau ne double pas leur chemin, il le raccourcit.
    local function Entree(id)
        local noeud = UI.Menu.Trouver(id)
        return function()
            if noeud and type(noeud.onClick) == "function" then noeud.onClick()
            else LCM.Alerte("fenêtre indisponible.") end
        end
    end
    local boutons = {
        { "systeme", "Système d'A'Hell'Razkah", Entree("systeme_aelskar") },
    }
    page.boutons = {}
    local y = 28
    for _, b in ipairs(boutons) do
        local bouton = UI.Bouton(page, b[2], MOITIE, 24, b[3])
        bouton:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y)
        page.boutons[b[1]] = bouton
        y = y + 30
    end

    page.titreBrouillons = Titre(page, "Brouillons")
    page.titreBrouillons:SetPoint("TOPLEFT", page, "TOPLEFT", x, -(y + 8))
    page.zoneBrouillons = UI.Defilement(page)
    page.zoneBrouillons:SetPoint("TOPLEFT", page, "TOPLEFT", x, -(y + 34))
    page.zoneBrouillons:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.lignesBrouillons = {}

    local function Ligne(liste, zone, rang)
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

    function page:Afficher()
        local scene = LCM.Incarnation.Liste()
        local y2 = 0
        for rang, instance in ipairs(scene) do
            local l = Ligne(self.lignesScene, self.zoneScene, rang)
            l.icone:SetTexture(LCM.Icone(instance.icon))
            l.nom:SetText(tostring(instance.name))
            Poser(l, self.zoneScene.contenu, y2)
            y2 = y2 + 24
        end
        for rang = #scene + 1, #self.lignesScene do self.lignesScene[rang]:Hide() end
        self.zoneScene:Regler(y2)
        self.nombreScene = #scene
        self.sceneVide:SetText(#scene > 0 and ""
            or "Aucun PNJ en jeu. « Incarner… » en met en scène ; ce sont eux que les joueurs peuvent cibler.")

        local B = LCM.Brouillons
        local lignes = {}
        if B then
            for _, famille in ipairs(B.FAMILLES) do
                for _, entree in ipairs(B.List(famille)) do
                    lignes[#lignes + 1] = { icone = entree.icone,
                        nom = string.format("%s  (%s)", tostring(entree.label or entree.id), famille) }
                end
            end
        end
        local y3 = 0
        for rang, ligne in ipairs(lignes) do
            local l = Ligne(self.lignesBrouillons, self.zoneBrouillons, rang)
            l.icone:SetTexture(LCM.Icone(ligne.icone))
            l.nom:SetText(ligne.nom)
            Poser(l, self.zoneBrouillons.contenu, y3)
            y3 = y3 + 24
        end
        for rang = #lignes + 1, #self.lignesBrouillons do self.lignesBrouillons[rang]:Hide() end
        self.zoneBrouillons:Regler(y3)
        self.nombreBrouillons = #lignes
        self.titreBrouillons:SetText(#lignes > 0
            and string.format("Brouillons (%d, en attente d'export)", #lignes) or "Brouillons (aucun)")
    end
end

-- ===== Outils partages =====================================================

function Pages.outils(page, f)
    local O = LCM.Outils
    local largeur = LARGEUR - 24

    -- ----- l'annonce --------------------------------------------------------
    page.titreAnnonce = Titre(page, "Annonce")
    page.titreAnnonce:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.annonce = UI.Champ(page, largeur - 130, 22, nil)
    page.annonce:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -20)
    page.annoncer = UI.Bouton(page, "Annoncer", 120, 22, function()
        if Dire(O.Annoncer(page.annonce:GetText())) then
            LCM.Ok("annonce envoyée.")
            page.annonce:SetText("")
        end
    end)
    page.annoncer:SetPoint("LEFT", page.annonce, "RIGHT", 10, 0)

    -- ----- creer -------------------------------------------------------------
    page.titreCreer = Titre(page, "Créer un outil")
    page.titreCreer:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -54)
    local function Etiquette(texte, ancre, dx)
        local t = UI.Texte(page, texte, UI.C.discret)
        UI.Police(t, 11)
        t:SetPoint("LEFT", ancre, "RIGHT", dx or 10, 0)
        return t
    end
    page.libelleLabel = UI.Texte(page, "Libellé", UI.C.discret)
    UI.Police(page.libelleLabel, 11)
    page.libelleLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -80)
    page.libelle = UI.Champ(page, 200, 22, nil)
    page.libelle:SetPoint("LEFT", page.libelleLabel, "RIGHT", 6, 0)
    page.valeurLabel = Etiquette("Valeur", page.libelle, 12)
    page.valeur = UI.Champ(page, 52, 22, nil)
    page.valeur:SetPoint("LEFT", page.valeurLabel, "RIGHT", 6, 0)
    page.valeur:SetText("0")
    page.maximumLabel = Etiquette("Max", page.valeur, 12)
    page.maximum = UI.Champ(page, 52, 22, nil)
    page.maximum:SetPoint("LEFT", page.maximumLabel, "RIGHT", 6, 0)
    page.maximum:SetText("10")

    local function Creer(sorte)
        local o, ok, raison = O.Creer(sorte, page.libelle:GetText(), page.valeur:GetText(),
            page.maximum:GetText(), page.texte:GetText())
        -- Refuse : la raison est dite, et la saisie reste la pour corriger.
        if not o then LCM.Alerte(tostring(ok)) return end
        if not ok and raison then LCM.Alerte(tostring(raison)) end
        page.libelle:SetText("")
        page.texte:SetText("")
        page:Afficher()
    end
    page.creerCompteur = UI.Bouton(page, "+ Compteur", 100, 22, function() Creer("compteur") end)
    page.creerCompteur:SetPoint("LEFT", page.maximum, "RIGHT", 12, 0)
    page.creerBarre = UI.Bouton(page, "+ Barre", 80, 22, function() Creer("barre") end)
    page.creerBarre:SetPoint("LEFT", page.creerCompteur, "RIGHT", 6, 0)

    page.texte = UI.Zone(page, largeur - 110, 54, nil)
    page.texte.saisie:SetMaxLetters(O.TEXTE_MAX)
    page.texte:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -110)
    page.creerNote = UI.Bouton(page, "+ Note", 100, 22, function() Creer("note") end)
    page.creerNote:SetPoint("TOPLEFT", page.texte, "TOPRIGHT", 10, 0)

    -- ----- ce qui est partage ----------------------------------------------
    page.titreListe = Titre(page, "Partagés avec le groupe")
    page.titreListe:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -176)
    page.renvoyer = UI.Bouton(page, "Tout renvoyer", 110, 20, function()
        O.Renvoyer()
        LCM.Ok("outils renvoyés au groupe.")
    end)
    page.renvoyer:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -174)
    page.zone = UI.Defilement(page)
    page.zone:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -200)
    page.zone:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.lignes = {}
    page.vide = UI.Texte(page, "", UI.C.discret)
    UI.Police(page.vide, 11)
    page.vide:SetPoint("TOP", page.zone, "TOP", 0, -10)

    local function Ligne(rang)
        local l = page.lignes[rang]
        if l then return l end
        l = Rangee(page.zone.contenu, LIGNE)
        l.sorte = UI.Texte(l, "", UI.C.accent)
        UI.Police(l.sorte, 10)
        l.sorte:SetPoint("LEFT", l, "LEFT", 8, 0)
        l.sorte:SetWidth(70)
        l.sorte:SetJustifyH("LEFT")
        l.nom = UI.Texte(l, "", UI.C.texte)
        UI.Police(l.nom, 12)
        l.nom:SetPoint("LEFT", l, "LEFT", 82, 0)
        l.retirer = UI.Bouton(l, "Retirer", 70, 20, function() Dire(O.Retirer(l.outilId)) end)
        l.retirer:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        l.plus = UI.Bouton(l, "+1", 30, 20, function() Dire(O.Ajouter(l.outilId, 1)) end)
        l.plus:SetPoint("RIGHT", l.retirer, "LEFT", -10, 0)
        l.moins = UI.Bouton(l, "-1", 30, 20, function() Dire(O.Ajouter(l.outilId, -1)) end)
        l.moins:SetPoint("RIGHT", l.plus, "LEFT", -4, 0)
        l.valeur = UI.Texte(l, "", UI.C.accent)
        UI.Police(l.valeur, 12)
        l.valeur:SetPoint("RIGHT", l.moins, "LEFT", -10, 0)
        l.valeur:SetJustifyH("RIGHT")
        page.lignes[rang] = l
        return l
    end

    function page:Afficher()
        local liste = O.Liste()
        local y = 0
        for rang, o in ipairs(liste) do
            local l = Ligne(rang)
            l.outilId = o.id
            l.sorte:SetText(O.SORTES[o.sorte])
            l.nom:SetText(o.libelle)
            local chiffre = o.sorte ~= "note"
            l.plus:SetShown(chiffre)
            l.moins:SetShown(chiffre)
            if o.sorte == "barre" then
                l.valeur:SetText(string.format("%d / %d", o.valeur, o.maximum))
            elseif o.sorte == "compteur" then
                l.valeur:SetText(tostring(o.valeur))
            else
                l.valeur:SetText(string.format("%d caractères", #(o.texte or "")))
            end
            Poser(l, self.zone.contenu, y)
            y = y + LIGNE
        end
        for rang = #liste + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.zone:Regler(y)
        self.nombre = #liste
        self.vide:SetText(#liste > 0 and "" or "Rien de partagé pour l'instant.")
    end

    O.onChangeMJ = function()
        if f:IsShown() and f.onglet == "outils" then page:Afficher() end
    end
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("panneau_mj", "Panel MJ", LARGEUR, HAUTEUR, { x = 40, y = 20 })
    Ecran.frame = f

    f.barre = UI.BandeauOnglets(f.contenu, Ecran.ONGLETS, function(id) f:Onglet(id) end)
    f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    local largeur = LARGEUR - 2 * (f.insetCote or 12)
    f.barre:SetWidth(largeur)
    local hauteurBandeau = f.barre:Disposer(largeur, f.mesures.onglet, { uneRangee = true })

    f.pages = {}
    for _, onglet in ipairs(Ecran.ONGLETS) do
        local page = CreateFrame("Frame", nil, f.contenu)
        page:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -(hauteurBandeau + 10))
        page:Hide()
        f.pages[onglet.id] = page
        Pages[onglet.id](page, f)
    end

    -- Le bas des pages s'arrete avant ce que l'habillage mange a l'interieur
    -- de la fenetre (liseré, equerres des coins : UI.AelEmprise). Refait a
    -- chaque ouverture, le theme a pu changer.
    function f:PlacerBas()
        local e = UI.AelEmprise(self)
        local dy = math.max(0, math.ceil(e.bas + 4 - (self.insetBas or 0)))
        local dx = math.max(0, math.ceil(e.cote + 4 - (self.insetCote or 0)))
        for _, page in pairs(self.pages) do
            page:SetPoint("BOTTOMRIGHT", self.contenu, "BOTTOMRIGHT", -dx, dy)
        end
    end
    f:PlacerBas()

    function f:Onglet(id)
        if not self.pages[id] then id = "joueurs" end
        self.onglet = id
        self.barre:Selectionner(id)
        for cle, page in pairs(self.pages) do page:SetShown(cle == id) end
        self.pages[id]:Afficher()
    end

    -- Rafraichit tout ; les champs que d'autres fichiers (et le banc) lisent
    -- sur la fenetre restent ceux de l'onglet Joueurs.
    function f:Afficher()
        for _, page in pairs(self.pages) do page:Afficher() end
        self.nombreAffiche = self.pages.joueurs.nombreAffiche
    end
    f.lignes = f.pages.joueurs.lignes
    f.raison = f.pages.joueurs.raison

    function f:Montrer(id)
        self:PlacerBas()
        self:Show()
        self:Onglet(id or self.onglet or "joueurs")
        self.nombreAffiche = self.pages.joueurs.nombreAffiche
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.WhenReady(function()
    UI.Menu.Lier("panneau_mj", Ecran.Basculer)
    -- Une fiche qui arrive pendant que le panneau est ouvert s'y affiche.
    LCM.Fiches.onRecue = function(joueur, entity)
        LCM.Info(string.format("fiche de %s reçue.", tostring(joueur)))
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
        MJ.Consultation.Ouvrir(entity, "fiche")
    end
end)
