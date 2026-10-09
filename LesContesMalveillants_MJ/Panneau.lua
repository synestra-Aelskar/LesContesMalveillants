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
--   Contenus  le systeme et les brouillons en attente d'export ;
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
    { id = "pnj",     label = "PNJ" },
    { id = "contenus", label = "Contenus" },
    { id = "outils",  label = "Outils" },
}

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

    -- L'XP se distribue en une fois a plusieurs joueurs. Elle ne vit plus sur
    -- chaque ligne : le geste de fin de scene a son propre panneau.
    page.xpBouton = UI.Bouton(page, "XP", 72, 22, function()
        page.xpPanneau:Ouvrir()
    end)
    page.xpBouton:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)

    page.regainBouton = UI.Bouton(page, "Regain", 82, 22, function()
        page.regainPanneau:Ouvrir()
    end)
    page.regainBouton:SetPoint("RIGHT", page.xpBouton, "LEFT", -8, 0)

    local xp = UI.Fenetre("xp_groupe", "Attribuer de l'expérience", 570, 440,
        { x = 90, y = 20 })
    page.xpPanneau = xp
    xp.selection = {}

    xp.montantLabel = UI.Texte(xp.contenu, "XP à attribuer :", UI.C.libelle)
    xp.montantLabel:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 0, -2)
    xp.montant = UI.Champ(xp.contenu, 90, 22, nil)
    xp.montant:SetPoint("LEFT", xp.montantLabel, "RIGHT", 8, 0)
    xp.montant:SetNumeric(true)
    xp.raisonLabel = UI.Texte(xp.contenu, "Motif :", UI.C.libelle)
    xp.raisonLabel:SetPoint("LEFT", xp.montant, "RIGHT", 18, 0)
    xp.raison = UI.Champ(xp.contenu, 220, 22, nil)
    xp.raison:SetPoint("LEFT", xp.raisonLabel, "RIGHT", 8, 0)

    xp.enteteNom = UI.Texte(xp.contenu, "Joueur", UI.C.discret)
    xp.enteteNom:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 32, -36)
    xp.enteteNiveau = UI.Texte(xp.contenu, "Niveau", UI.C.discret)
    xp.enteteNiveau:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 250, -36)
    xp.enteteProgression = UI.Texte(xp.contenu, "Progression XP", UI.C.discret)
    xp.enteteProgression:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 322, -36)

    xp.zone = UI.Defilement(xp.contenu)
    xp.zone:SetPoint("TOPLEFT", xp.contenu, "TOPLEFT", 0, -56)
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
        l.niveau:SetWidth(64)
        l.niveau:SetJustifyH("LEFT")
        l.barre = UI.Barre(l, { 0.25, 0.52, 0.88, 1 }, 220, 16)
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
            if entity then
                l.niveau:SetText("Niv. " .. LCM.Experience.NiveauFiche(entity))
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

    function xp:Ouvrir()
        self.selection = {}
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
        regain.montant:SetEnabled(mode == "exact")
        regain.montant:SetAlpha(mode == "exact" and 1 or 0.4)
    end
    regain.modes.max = UI.Bouton(regain.contenu, "Max", 82, 22, function() ChoisirMode("max") end)
    regain.modes.max:SetPoint("BOTTOMLEFT", regain.contenu, "BOTTOMLEFT", 116, 48)
    regain.modes.min = UI.Bouton(regain.contenu, "Min", 82, 22, function() ChoisirMode("min") end)
    regain.modes.min:SetPoint("LEFT", regain.modes.max, "RIGHT", 8, 0)
    regain.modes.exact = UI.Bouton(regain.contenu, "Chiffre précis", 116, 22, function() ChoisirMode("exact") end)
    regain.modes.exact:SetPoint("LEFT", regain.modes.min, "RIGHT", 8, 0)
    regain.montant = UI.Champ(regain.contenu, 72, 22, nil)
    regain.montant:SetNumeric(true)
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
        local montant = math.floor(tonumber(regain.montant:GetText()) or 0)
        if regain.mode == "exact" and montant <= 0 then LCM.Alerte("indique un chiffre positif.") return end

        local envoyes = 0
        for _, joueur in ipairs(cibles) do
            local estMoi = EstMoi(joueur)
            local ok, raison
            if estMoi then
                local resultat
                resultat, raison = LCM.Regain.Appliquer(FicheJoueur(joueur), regain.ressources, regain.mode, montant)
                ok = resultat ~= nil
                if ok and LCM.UI.Regain then LCM.UI.Regain.Afficher(resultat) end
            else
                ok, raison = LCM.Regain.Envoyer(joueur, regain.ressources, regain.mode, montant)
                if ok then
                    local entity = FicheJoueur(joueur)
                    if entity then LCM.Regain.Appliquer(entity, regain.ressources, regain.mode, montant) end
                end
            end
            if ok then envoyes = envoyes + 1 elseif raison then LCM.Alerte(joueur .. " : " .. tostring(raison)) end
        end
        if envoyes > 0 then
            LCM.Ok(string.format("Regain envoyé à %d personnage%s.", envoyes, envoyes > 1 and "s" or ""))
            regain.selection = {}
            regain:Hide()
        end
    end)
    regain.envoyer:SetPoint("BOTTOMRIGHT", regain.contenu, "BOTTOMRIGHT", 0, 4)

    function regain:Ouvrir()
        self.selection = {}
        self.ressources = {}
        self.mode = nil
        self.montant:SetText("")
        for _, case in pairs(self.casesRessources) do case:Cocher(false) end
        for _, bouton in pairs(self.modes) do bouton:Selectionner(false) end
        self.montant:SetEnabled(false)
        self.montant:SetAlpha(0.4)
        self:Remplir(true)
        self:Show()
        self:Raise()
    end

    -- Alias conserve pour les appels existants du banc ou d'autres modules :
    -- le motif appartient desormais au panneau XP, plus au bandeau Joueurs.
    page.raison = xp.raison

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
            local entity = FicheJoueur(cible)
            if entity then
                MJ.Consultation.Ouvrir(entity, "fiche")
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
        l.consulter:SetPoint("RIGHT", l, "RIGHT", -6, 0)
        l.reedition = UI.Bouton(l, "Réédition", 82, 20, function()
            local ok, raison = LCM.Creation.EnvoyerJeton(l.joueur)
            if not ok then LCM.Alerte(tostring(raison)) return end
            -- La réception répondra : on distingue ainsi « envoyé » de
            -- « réellement remis au personnage ».
            LCM.Info(string.format("jeton de réédition envoyé à %s…", tostring(l.joueur)))
        end)
        l.reedition:SetPoint("RIGHT", l.consulter, "LEFT", -8, 0)
        page.lignes[rang] = l
        return l
    end

    -- Ce qu'on sait d'un joueur, sans rien lui demander : l'addon vu ou non,
    -- et ce que dit sa derniere fiche recue.
    local function Detail(joueur)
        local morceaux = {}
        local present = LCM.Presence and LCM.Presence.Confirmee and LCM.Presence.Confirmee(joueur)
        morceaux[#morceaux + 1] = present and "addon présent" or "addon non confirmé"
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
        return table.concat(morceaux, "  ·  ")
    end

    function page:Afficher()
        local membres = Groupe()
        local y = 0
        for rang, joueur in ipairs(membres) do
            local l = self.lignes[rang] or Ligne(rang)
            l.joueur = joueur
            l.nom:SetText(NomPersonnage(joueur))
            l.detail:SetText(Detail(joueur))
            l.reedition:SetShown(not EstMoi(joueur))
            Poser(l, self.zone.contenu, y)
            y = y + LIGNE + 6
        end
        for rang = #membres + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.zone:Regler(y)
        self.nombreAffiche = #membres
        self.vide:SetText(#membres > 0 and "" or "Personne dans le groupe.")
        self.etat:SetText(string.format("%d joueur%s", #membres, #membres > 1 and "s" or ""))
        if self.xpPanneau:IsShown() then self.xpPanneau:Remplir(false) end
        if self.regainPanneau:IsShown() then self.regainPanneau:Remplir(false) end
    end
end

-- ===== Combat ==============================================================

function Pages.combat(page, f)
    -- Resolu ici et pas au chargement : Combat.lua se charge apres ce fichier.
    page.combat = MJ.Combat.Construire(page, f)
    function page:Afficher() self.combat:Afficher() end
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

function Pages.pnj(page, f)
    local largeur = LARGEUR - 24
    page.titreScene = Titre(page, "PNJ en scène")
    page.titreScene:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.incarner = UI.Bouton(page, "Incarner…", 100, 22, function()
        if UI.Incarner then UI.Incarner.Basculer() end
    end)
    page.incarner:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 2)
    page.zoneScene = UI.Defilement(page)
    page.zoneScene:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28)
    page.zoneScene:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 34)
    page.lignesScene = {}
    page.sceneVide = UI.Texte(page, "", UI.C.discret)
    UI.Police(page.sceneVide, 11)
    page.sceneVide:SetPoint("TOPLEFT", page.zoneScene, "TOPLEFT", 4, -4)
    page.sceneVide:SetPoint("TOPRIGHT", page.zoneScene, "TOPRIGHT", -4, -4)
    page.sceneVide:SetWordWrap(true)
    -- Les joueurs recoivent la scene a chaque changement ; ce bouton sert
    -- quand l'un d'eux arrive en cours de route ou a recharge.
    page.diffuser = UI.Bouton(page, "Renvoyer la scène au groupe", largeur, 24, function()
        if Dire(LCM.Scene.Diffuser(), "hors groupe : personne à qui envoyer la scène.") then
            LCM.Ok("scène renvoyée au groupe.")
        end
    end)
    page.diffuser:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)

    function page:Afficher()
        local scene = LCM.Incarnation.Liste()
        local y = 0
        for rang, instance in ipairs(scene) do
            local l = LigneIcone(self.lignesScene, self.zoneScene, rang)
            l.icone:SetTexture(LCM.Icone(instance.icon))
            l.nom:SetText(tostring(instance.name))
            Poser(l, self.zoneScene.contenu, y)
            y = y + 24
        end
        for rang = #scene + 1, #self.lignesScene do self.lignesScene[rang]:Hide() end
        self.zoneScene:Regler(y)
        self.nombreScene = #scene
        self.sceneVide:SetText(#scene > 0 and ""
            or "Aucun PNJ en jeu. « Incarner… » en met en scène ; ce sont eux que les joueurs peuvent cibler.")
    end
end

-- ===== Contenus ============================================================

function Pages.contenus(page, f)
    local largeur = LARGEUR - 24
    page.titreContenu = Titre(page, "Contenus")
    page.titreContenu:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
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
        local bouton = UI.Bouton(page, b[2], largeur, 24, b[3])
        bouton:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
        page.boutons[b[1]] = bouton
        y = y + 30
    end

    page.titreBrouillons = Titre(page, "Brouillons")
    page.titreBrouillons:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(y + 8))
    page.zoneBrouillons = UI.Defilement(page)
    page.zoneBrouillons:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -(y + 34))
    page.zoneBrouillons:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.lignesBrouillons = {}

    function page:Afficher()
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
            local l = LigneIcone(self.lignesBrouillons, self.zoneBrouillons, rang)
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
    -- L'annonce de presence transporte aussi le personnage actif. Elle peut
    -- arriver apres l'ouverture du panneau : le libelle se remplace alors
    -- sans attendre un clic sur Rafraichir.
    if LCM.Presence and LCM.Presence.Suivre then
        LCM.Presence.Suivre(function()
            if Ecran.frame and Ecran.frame:IsShown() then
                Ecran.frame.pages.joueurs:Afficher()
            end
        end)
    end
    -- Une fiche qui arrive pendant que le panneau est ouvert s'y affiche.
    LCM.Fiches.onRecue = function(joueur, entity)
        LCM.Info(string.format("fiche de %s reçue.", tostring(joueur)))
        local silencieuse = PrendreDemandeXP(joueur)
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
        if not silencieuse then MJ.Consultation.Ouvrir(entity, "fiche") end
    end
end)
