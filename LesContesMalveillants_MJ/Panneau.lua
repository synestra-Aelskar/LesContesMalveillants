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

local LARGEUR, HAUTEUR = 700, 540
local LIGNE = 28

Ecran.ONGLETS = {
    { id = "joueurs", label = "Joueurs" },
    { id = "traits", label = "Traits" },
    { id = "etats", label = "États" },
    { id = "combat",  label = "Combat" },
    { id = "pnj",     label = "PNJ" },
    { id = "contenus", label = "Contenus" },
    { id = "outils",  label = "Outils" },
    { id = "equilibrage", label = "Équilibrage" },
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
    -- Pas de SetNumeric : il refuse le signe moins, et un chiffre negatif
    -- RETIRE des points (le MJ, 23 octobre 2026). La lecture est faite a la
    -- validation, qui refuse ce qui n'est pas un nombre entier.
    regain.montant = UI.Champ(regain.contenu, 72, 22, nil)
    regain.montant:SetMaxLetters(6)
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

    -- Recherche sans accents ni majuscules : « echo » trouve « Écho ».
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

function Pages.etats(page)
    page.titre = Titre(page, "Imposer un état")
    page.titre:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    page.aideEtats = UI.Texte(page,
        "Glisse un état sur un joueur. Durée vide : jusqu’au retrait. Clique un joueur pour voir ses états.", UI.C.discret)
    UI.Police(page.aideEtats, 10)
    page.aideEtats:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -20)
    page.aideEtats:SetPoint("RIGHT", page, "RIGHT", -2, 0)
    page.aideEtats:SetJustifyH("LEFT")

    page.dureeLabel = UI.Texte(page, "Durée (rounds) :", UI.C.libelle)
    page.dureeLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -43)
    page.duree = UI.Champ(page, 64, 22)
    page.duree:SetNumeric(true)
    page.duree:SetText("")
    page.duree:SetPoint("LEFT", page.dureeLabel, "RIGHT", 8, 0)
    UI.Bulle(page.duree, "Durée de l’état",
        "Nombre de rounds avant expiration. Laisse vide pour un état sans expiration automatique.")

    page.recherche = UI.Champ(page, 126, 22, function() page:Afficher() end)
    page.recherche:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    page.recherche:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    page.recherche.label = UI.Texte(page, "Rechercher :", UI.C.libelle)

    page.zoneEtats = UI.Defilement(page)
    page.zoneEtats:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -96)
    page.zoneEtats:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    page.zoneEtats:SetWidth(210)
    -- La recherche filtre le catalogue : elle reste dans sa colonne,
    -- sous la duree et juste au-dessus des etats disponibles.
    page.recherche:SetPoint("BOTTOMRIGHT", page.zoneEtats, "TOPRIGHT", 0, 6)
    page.recherche.label:SetPoint("BOTTOMLEFT", page.zoneEtats, "TOPLEFT", 0, 11)
    UI.Police(page.recherche.label, 10)
    page.zoneActifs = UI.Defilement(page)
    page.zoneActifs:SetPoint("TOPLEFT", page.zoneEtats, "TOPRIGHT", 12, 0)
    page.zoneActifs:SetPoint("BOTTOMLEFT", page.zoneEtats, "BOTTOMRIGHT", 12, 0)
    page.zoneActifs:SetWidth(240)
    page.titreActifs = UI.Texte(page, "États du personnage", UI.C.libelle)
    page.titreActifs:SetPoint("BOTTOMLEFT", page.zoneActifs, "TOPLEFT", 2, 6)
    page.videActifs = UI.Texte(page.zoneActifs.contenu, "Sélectionne un personnage.", UI.C.discret)
    page.videActifs:SetPoint("TOPLEFT", page.zoneActifs.contenu, "TOPLEFT", 4, -4)
    page.videActifs:SetWidth(225)
    page.lignesActifs = {}
    page.zoneJoueurs = UI.Defilement(page)
    page.zoneJoueurs:SetPoint("TOPLEFT", page.zoneActifs, "TOPRIGHT", 12, 0)
    page.zoneJoueurs:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
    page.lignesEtats, page.lignesJoueurs = {}, {}
    page.videEtats = UI.Texte(page.zoneEtats.contenu, "Aucun état dans le compendium.", UI.C.discret)
    page.videEtats:SetPoint("TOPLEFT", page.zoneEtats.contenu, "TOPLEFT", 6, -6)
    page.videJoueursEtats = UI.Texte(page.zoneJoueurs.contenu, "Aucun joueur dans le groupe.", UI.C.discret)
    page.videJoueursEtats:SetPoint("TOPLEFT", page.zoneJoueurs.contenu, "TOPLEFT", 6, -6)

    local function BoutonLigne(parent, hauteur)
        local ligne = CreateFrame("Button", nil, parent)
        ligne:SetHeight(hauteur or 26)
        if UI.SurfaceLigne then UI.SurfaceLigne(ligne) end
        return ligne
    end

    function page:Appliquer(joueur, definition)
        self.joueurActif = joueur
        local texte = (self.duree:GetText() or ""):match("^%s*(.-)%s*$")
        local rounds = nil
        if texte ~= "" then
            rounds = tonumber(texte)
            if not rounds or rounds ~= math.floor(rounds) or rounds < 1 then
                LCM.Alerte("la durée doit être un nombre entier positif, ou vide.")
                return
            end
        end
        local ok, raison
        if EstMoi(joueur) then
            local entity = LCM.Entities.Personnage and LCM.Entities.Personnage()
                or LCM.Entities.Self()
            if entity then
                LCM.EtatsTemporaires.Poser(entity, {
                    nom = definition.label, icone = definition.icone,
                    description = definition.description, bonus = definition.bonus,
                    desavantage = definition.desavantage,
                    rounds = rounds, conteneur = LCM.Etats.Conteneur(definition),
                    debuff = definition.debuff == true, id = definition.id,
                })
                ok = true
            else
                raison = "aucune fiche de personnage active."
            end
        else
            self:DemanderEtats(joueur)
            ok, raison = LCM.EtatsTemporaires.Envoyer(joueur, definition.id, rounds)
        end
        if ok then
            LCM.Ok(string.format("« %s » imposé à %s (%s).", definition.label,
                NomPersonnage(joueur), rounds and (rounds .. " round" .. (rounds > 1 and "s" or ""))
                    or "jusqu'au retrait"))
            self:Afficher()
        elseif raison then
            LCM.Alerte(tostring(raison))
        end
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
        self:Afficher()
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

    function page:AfficherActifs()
        local entity = self.joueurActif and FicheJoueur(self.joueurActif)
        local liste = {}
        if entity then
            for _, etat in ipairs(LCM.EtatsTemporaires.Liste(entity)) do
                liste[#liste + 1] = { nom = etat.nom, icone = etat.icone,
                    duree = LCM.EtatsTemporaires.Duree(etat) }
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
                self.lignesActifs[i] = l
            end
            l.etat = etat
            l.nom:SetText(etat.nom)
            l.duree:SetText(etat.duree)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zoneActifs.contenu, "TOPLEFT", 2, -(i - 1) * 46)
            l:SetPoint("RIGHT", self.zoneActifs.contenu, "RIGHT", -2, 0)
            l:Show()
        end
        for i = #liste + 1, #self.lignesActifs do self.lignesActifs[i]:Hide() end
        self.videActifs:SetText(entity and "Aucun état sur ce personnage."
            or (self.joueurActif and "Fiche indisponible : clique le personnage pour la demander." or "Sélectionne un personnage."))
        self.videActifs:SetShown(#liste == 0)
        self.zoneActifs:Regler(math.max(1, #liste * 46))
    end

    LCM.Entities.Ecouter(function(entity)
        if page:IsVisible() and page.joueurActif and entity == FicheJoueur(page.joueurActif) then
            page:AfficherActifs()
        end
    end)

    function page:Afficher()
        local recherche = tostring(self.recherche:GetText() or ""):lower()
        local definitions = {}
        for _, definition in ipairs(LCM.Etats.list or {}) do
            if recherche == "" or tostring(definition.label):lower():find(recherche, 1, true) then
                definitions[#definitions + 1] = definition
            end
        end
        table.sort(definitions, function(a, b) return tostring(a.label):lower() < tostring(b.label):lower() end)
        local y = 0
        for rang, definition in ipairs(definitions) do
            local l = self.lignesEtats[rang]
            if not l then
                l = BoutonLigne(self.zoneEtats.contenu, 26)
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
                self.lignesEtats[rang] = l
            end
            l.definition = definition
            l.icone:SetTexture(LCM.Icone(definition.icone))
            l.nom:SetText(definition.label)
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zoneEtats.contenu, "TOPLEFT", 2, -y)
            l:SetPoint("RIGHT", self.zoneEtats.contenu, "RIGHT", -2, 0)
            l:Show()
            y = y + 28
        end
        for rang = #definitions + 1, #self.lignesEtats do self.lignesEtats[rang]:Hide() end
        self.videEtats:SetShown(#definitions == 0)
        self.zoneEtats:Regler(math.max(1, y))

        local joueurs = Groupe()
        local selectionPresente = false
        for _, joueur in ipairs(joueurs) do if joueur == self.joueurActif then selectionPresente = true end end
        if not selectionPresente then self.joueurActif = nil end
        local yJoueurs = 0
        for rang, joueur in ipairs(joueurs) do
            local l = self.lignesJoueurs[rang]
            if not l then
                l = BoutonLigne(self.zoneJoueurs.contenu, 34)
                l.nom = UI.Texte(l, "", UI.C.texte)
                l.nom:SetPoint("LEFT", l, "LEFT", 8, 0)
                l.nom:SetPoint("RIGHT", l, "RIGHT", -8, 0)
                l.nom:SetJustifyH("LEFT")
                l:SetScript("OnClick", function(ligne) page:ChoisirJoueur(ligne.joueur) end)
                UI.Glisser.Cible(l, function(objet)
                    return objet and objet.categorie == "etats" and type(objet.element) == "table",
                        "dépose ici un état du compendium"
                end, function(objet)
                    page:Appliquer(l.joueur, objet.element)
                end)
                self.lignesJoueurs[rang] = l
            end
            l.joueur = joueur
            l.nom:SetText((joueur == self.joueurActif and "> " or "") .. NomPersonnage(joueur) .. (EstMoi(joueur) and "  (vous)" or ""))
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zoneJoueurs.contenu, "TOPLEFT", 2, -yJoueurs)
            l:SetPoint("RIGHT", self.zoneJoueurs.contenu, "RIGHT", -2, 0)
            l:Show()
            yJoueurs = yJoueurs + 38
        end
        for rang = #joueurs + 1, #self.lignesJoueurs do self.lignesJoueurs[rang]:Hide() end
        self.videJoueursEtats:SetShown(#joueurs == 0)
        self.zoneJoueurs:Regler(math.max(1, yJoueurs))
        self:AfficherActifs()
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

    -- La liste « Brouillons (en attente d'export) » vivait ici. Une entree
    -- enregistree existe, elle n'attend rien (15 octobre 2026) : la liste n'a
    -- plus d'objet.
    function page:Afficher() end
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

function Pages.equilibrage(page, f)
    local R = LCM.Reglages
    local largeur = LARGEUR - 24
    local largeurGroupes = 150

    page.titre = Titre(page, "Vecteurs d'équilibrage")
    page.titre:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)

    page.resume = UI.Texte(page, "", UI.C.discret)
    UI.Police(page.resume, 11)
    page.resume:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -18)
    page.resume:SetPoint("RIGHT", page, "RIGHT", -4, 0)
    page.resume:SetJustifyH("LEFT")
    page.resume:SetWordWrap(true)

    -- La colonne des groupes.
    page.groupes = UI.Defilement(page)
    page.groupes:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -48)
    page.groupes:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    page.groupes:SetWidth(largeurGroupes)
    page.boutonsGroupe = {}

    -- Le tableau.
    page.zone = UI.Defilement(page)
    page.zone:SetPoint("TOPLEFT", page, "TOPLEFT", largeurGroupes + 12, -48)
    page.zone:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 0)
    page.lignes = {}
    page.groupe = nil

    function page:Choisir(groupe)
        self.groupe = groupe
        self:Afficher()
    end

    function page:Afficher()
        if not LCM.IsMaster() then return end
        local groupes = R.Groupes()
        if not self.groupe then self.groupe = groupes[1] end

        local n = R.Compte()
        self.resume:SetText(n > 0
            and string.format("%d réglage(s) en cours — ils s'appliquent chez tout le monde "
                .. "et restent à exporter.", n)
            or "Aucun réglage : le jeu tourne sur les valeurs du fichier.")

        local y = 0
        for rang, groupe in ipairs(groupes) do
            local b = self.boutonsGroupe[rang]
            if not b then
                b = UI.Bouton(self.groupes.contenu, "", largeurGroupes - 20, 22, function()
                    page:Choisir(page.boutonsGroupe[rang].groupe)
                end)
                self.boutonsGroupe[rang] = b
            end
            b.groupe = groupe
            b.label:SetText(groupe)
            b:Selectionner(groupe == self.groupe)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.groupes.contenu, "TOPLEFT", 0, -y)
            b:Show()
            y = y + 24
        end
        for rang = #groupes + 1, #self.boutonsGroupe do self.boutonsGroupe[rang]:Hide() end
        self.groupes:Regler(math.max(1, y))

        local vecteurs = R.Vecteurs(self.groupe)
        local yv = 0
        for rang, v in ipairs(vecteurs) do
            local l = self.lignes[rang]
            if not l then
                l = CreateFrame("Frame", nil, self.zone.contenu)
                l:SetHeight(LIGNE_REGLAGE - 2)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.nom = UI.Texte(l, "", UI.C.texte)
                UI.Police(l.nom, 11)
                l.nom:SetPoint("LEFT", l, "LEFT", 6, 0)
                l.nom:SetWordWrap(false)
                -- Remettre par defaut : le bouton n'apparait que s'il y a
                -- quelque chose a defaire.
                l.defaut = UI.Bouton(l, "Défaut", 62, 18, function()
                    local ok, raison = R.Retirer(l.chemin)
                    if not ok then LCM.Alerte(tostring(raison)) end
                    page:Afficher()
                end)
                l.defaut:SetPoint("RIGHT", l, "RIGHT", -6, 0)
                l.saisie = UI.Champ(l, 70, 18, nil)
                l.saisie:SetPoint("RIGHT", l.defaut, "LEFT", -6, 0)
                l.poser = UI.Bouton(l, "OK", 32, 18, function()
                    local ok, raison = R.Definir(l.chemin, l.saisie:GetText())
                    if not ok then LCM.Alerte(tostring(raison)) return end
                    LCM.Ok(string.format("%s = %s", l.chemin, l.saisie:GetText()))
                    page:Afficher()
                end)
                l.poser:SetPoint("RIGHT", l.saisie, "LEFT", -4, 0)
                l.nom:SetPoint("RIGHT", l.poser, "LEFT", -8, 0)
                self.lignes[rang] = l
            end
            l.chemin = v.chemin
            -- Le chemin SANS son groupe : il est deja dans la colonne de
            -- gauche, le repeter sur chaque ligne mangeait la place.
            l.nom:SetText((v.chemin:gsub("^" .. self.groupe .. "%.", "")))
            if not l.saisie:HasFocus() then l.saisie:SetText(tostring(v.valeur)) end
            -- Regle : on le voit. La valeur du fichier reste lisible a cote.
            local regle = R.Surcharges()[v.chemin] ~= nil
            local couleur = regle and UI.C.accent or UI.C.texte
            l.nom:SetTextColor(couleur[1], couleur[2], couleur[3])
            l.defaut:SetShown(regle)
            if regle then
                UI.Bulle(l, v.chemin, string.format("Réglé à %s. Le fichier dit %s.",
                    tostring(v.valeur), tostring(v.defaut)))
            else
                UI.Bulle(l, v.chemin, "Valeur du fichier.")
            end
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -yv)
            l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -yv)
            l:Show()
            yv = yv + LIGNE_REGLAGE
        end
        for rang = #vecteurs + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.zone:Regler(math.max(1, yv))
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
        self.modeSeul = nil
        self:Titre("Panel MJ")
        self.barre:Show()
        for _, page in pairs(self.pages) do
            page:ClearAllPoints()
            page:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", 0, -(hauteurBandeau + 10))
        end
        local outils = self.pages.outils
        outils.barre:Show()
        for _, sous in pairs(outils.sous) do
            sous:ClearAllPoints()
            sous:SetPoint("TOPLEFT", outils, "TOPLEFT", 0, -28)
            sous:SetPoint("BOTTOMRIGHT", outils, "BOTTOMRIGHT", 0, 0)
        end
        self:PlacerBas()
        self:Show()
        self:Onglet(id or self.onglet or "joueurs")
        self.nombreAffiche = self.pages.joueurs.nombreAffiche
    end

    function f:MontrerSeul(id, titre, sorte)
        self:Montrer(id)
        self.modeSeul = true
        self:Titre(titre)
        self.barre:Hide()
        local page = self.pages[id]
        page:ClearAllPoints()
        page:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", 0, 0)
        self:PlacerBas()
        if sorte then
            page:Sous(sorte)
            page.barre:Hide()
            local sous = page.sous[sorte]
            sous:ClearAllPoints()
            sous:SetAllPoints(page)
        end
    end

    return f
end

function Ecran.Fenetre()
    if not Ecran.frame then Construire() end
    return Ecran.frame
end

function Ecran.Basculer()
    local f = Ecran.Fenetre()
    if f:IsShown() and not f.modeSeul then f:Hide() else f:Montrer() end
    return f
end

-- Ce menu appartient au compagnon MJ, sans dupliquer les panneaux ni leur
-- logique reseau. Le clic gauche conserve le panneau complet.
local artMJ = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\"
local function Raccourci(id, label, icone, page, sorte)
    return { id = id, label = label, icone = artMJ .. icone .. ".tga", onClick = function()
        if not LCM.IsMaster() then return end
        local f = Ecran.Fenetre()
        if id == "mj_regain" then
            f:Hide()
            f.pages.joueurs.regainPanneau:Ouvrir()
        else
            f.pages.joueurs.regainPanneau:Hide()
            f:MontrerSeul(page, label, sorte)
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

LCM.WhenReady(function()
    UI.Menu.Lier("panneau_mj", Ecran.Basculer)
    UI.Menu.Trouver("panneau_mj").onRightClick = function()
        if LCM.IsMaster() then UI.Radial.Basculer("mj") end
    end
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
    LCM.Fiches.onRecue = function(joueur, entity, actualisation)
        if not actualisation then LCM.Info(string.format("fiche de %s reçue.", tostring(joueur))) end
        local silencieuse = PrendreDemandeXP(joueur)
        local etats = Ecran.frame and Ecran.frame.pages.etats
        if etats and etats:IsVisible() and etats.joueurActif
            and NomCourt(etats.joueurActif) == NomCourt(joueur) then silencieuse = true end
        if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
        if not silencieuse then
            local consultation = MJ.Consultation
            if consultation.fenetre and consultation.fenetre:IsShown()
                and consultation.joueur == joueur then
                consultation.Ouvrir(entity, consultation.onglet or "fiche", joueur)
            elseif not consultation.joueur then
                consultation.Ouvrir(entity, "fiche", joueur)
            end
        end
    end
end)
