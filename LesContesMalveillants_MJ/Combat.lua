-- Mener un combat : l'onglet Combat du Panel MJ.
--
-- C'etait une fenetre a part jusqu'au 3 octobre 2026 ; elle est devenue un
-- onglet du panneau (LesContesMalveillants_MJ/Panneau.lua), comme le combat
-- dans la fenetre du MJ de Necronicon. Construire(page, fenetre) remplit la
-- page que le panneau lui donne ; `/lcm combat` ouvre le panneau sur cet
-- onglet.
--
-- A gauche, qui entre au combat : soi-meme (coche par defaut, comme dans
-- Necronicon) et les PNJ en jeu (ceux de la fenetre Incarner). A droite, ceux
-- qu'on a invites et leur reponse, puis, le combat lance, l'ordre d'initiative.
--
-- Le choix des PNJ reste dans la fenetre, en memoire : une rencontre ne se
-- prepare pas d'une seance a l'autre ici, et rien n'entre en sauvegarde.
--
-- Toute la logique est dans Core/Combat.lua ; cette fenetre ne fait qu'appeler.

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end

local UI = LCM.UI
local C = LCM.Combat
local Ecran = {}
UI.CombatMJ = Ecran
MJ.Combat = Ecran

local COLONNE = 300
local LIGNE = 26
-- La page se lit de haut en bas (le MJ, 2 novembre 2026 : « ca fait moche ») :
-- un bandeau d'etat, deux colonnes encadrees comme celles de la page Groupe,
-- puis une barre d'actions sous un filet.
local ENTETE = 30
local BARRE = 34
-- Les rounds d'un tour, en pastilles : de quoi en montrer huit.
local PASTILLES = 8
local PAS_PASTILLE = 12

-- Les couleurs d'une reponse : qui est pret, qui a refuse, qui reste a
-- attendre se lit sans lire.
local VERT = { 0.55, 0.80, 0.45 }

local function Teinte(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

-- Un bouton desactive du Kit garde l'air actif : « Precedent » bloque au
-- premier passage passait pour un bouton qui ne repond pas. Son libelle se
-- grise ; actif, il reprend sa teinte (`b.ton`).
local function Activer(b, oui)
    oui = oui and true or false
    b:SetEnabled(oui)
    Teinte(b.label, oui and (b.ton or UI.C.texte) or UI.C.discret)
end

local function Ton(b, couleur)
    b.ton = couleur
    Teinte(b.label, couleur)
end

-- L'unite du groupe qui porte ce nom. Un joueur qui n'est pas encore au
-- combat n'a pas d'icone connue — son profil TRP3 n'arrive qu'avec sa
-- reponse — et la liste montrait un point d'interrogation (21 octobre 2026).
-- Le portrait du jeu dit au moins de qui il s'agit.
local function Unite(joueur)
    local court = tostring(joueur or ""):match("^([^-]+)")
    if not court or not UnitName then return nil end
    if UnitName("player") == court then return "player" end
    local nombre = GetNumGroupMembers and GetNumGroupMembers() or 0
    local prefixe = (IsInRaid and IsInRaid()) and "raid" or "party"
    for index = 1, nombre do
        if UnitName(prefixe .. index) == court then return prefixe .. index end
    end
end

local function PoserIcone(texture, icone, joueur)
    local unite = not icone and joueur and Unite(joueur)
    if unite and SetPortraitTexture then
        SetPortraitTexture(texture, unite)
    else
        texture:SetTexture(LCM.Icone(icone))
    end
end

-- Le nom a montrer pour un joueur : celui de son PERSONNAGE actif (le MJ,
-- 2 novembre 2026), lu sur sa fiche recue ou son annonce de presence ; le
-- nom de compte seulement faute de mieux. L'adresse reseau reste `cle`.
local function NomPersonnage(joueur)
    local fiche = LCM.Fiches and LCM.Fiches.Recue and LCM.Fiches.Recue(joueur)
    local nom = fiche and tostring(fiche.name or "") or ""
    if nom == "" and LCM.Presence and LCM.Presence.Personnage then
        nom = tostring(LCM.Presence.Personnage(joueur) or "")
    end
    if nom == "" and joueur == LCM.PlayerId() and LCM.Entities.Personnage then
        local moi = LCM.Entities.Personnage()
        nom = moi and tostring(moi.name or "") or ""
    end
    return nom ~= "" and nom or tostring(joueur)
end

-- Une ligne : un fond a peine marque (sans lui, les noms flottaient), une
-- case OU un rang a gauche, l'icone, le nom, et a droite l'etat ou
-- l'initiative. Celui qui joue porte un halo dore et un trait a gauche.
local function Rangee(parent)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(LIGNE - 2)
    l.fond = UI.Aplat(l, { 1, 1, 1, 0.035 }, "BACKGROUND")
    l.fond:SetAllPoints(l)
    l.halo = UI.Aplat(l, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 0.16 }, "BORDER")
    l.halo:SetAllPoints(l)
    l.halo:Hide()
    l.marque = UI.Aplat(l, { UI.C.accent[1], UI.C.accent[2], UI.C.accent[3], 1 }, "ARTWORK")
    l.marque:SetWidth(3)
    l.marque:SetPoint("TOPLEFT", l, "TOPLEFT", 0, 0)
    l.marque:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT", 0, 0)
    l.marque:Hide()
    l.rang = UI.Texte(l, "", UI.C.discret)
    UI.Police(l.rang, 11)
    l.rang:SetPoint("CENTER", l, "LEFT", 15, 0)
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(18, 18)
    l.icone:SetPoint("LEFT", l, "LEFT", 28, 0)
    l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    l.etat = UI.Texte(l, "", UI.C.discret)
    UI.Police(l.etat, 11)
    l.etat:SetPoint("RIGHT", l, "RIGHT", -8, 0)
    l.etat:SetJustifyH("RIGHT")
    l.nom = UI.Texte(l, "", UI.C.texte)
    UI.Police(l.nom, 11)
    l.nom:SetPoint("LEFT", l.icone, "RIGHT", 6, 0)
    -- Un nom long s'arrete avant l'etat au lieu de passer dessous.
    l.nom:SetPoint("RIGHT", l.etat, "LEFT", -56, 0)
    l.nom:SetJustifyH("LEFT")
    l.nom:SetWordWrap(false)
    return l
end

local function Poser(l, parent, y)
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    l:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
    l:Show()
end

local function Dire(ok, raison)
    if not ok and raison then LCM.Alerte(tostring(raison)) end
end

-- `page` : le cadre de l'onglet, que le panneau dimensionne. `fenetre` : le
-- panneau lui-meme (la confirmation, elle, se pose sur la page : voir plus bas).
function Ecran.Construire(page, fenetre)
    local f = CreateFrame("Frame", nil, page)
    f:SetAllPoints(page)
    -- Le reste du fichier pose tout « dans le contenu » : la page en tient lieu.
    f.contenu = f
    Ecran.frame = f
    -- Les PNJ coches, par identifiant d'instance.
    f.choisis = {}
    -- Les joueurs du groupe ECARTES de l'invitation (le MJ, 2 novembre 2026 :
    -- « choisir qui est invite ou non, pas uniquement les PNJ »). Par defaut
    -- tout le groupe est invite : on coche pour exclure, pas pour inclure.
    f.exclus = {}

    -- ----- le bandeau d'etat ----------------------------------------------
    -- Ce qui se passe a gauche, ou l'on en est a droite (tour, puis un rond
    -- par round). Une seule phrase melangeait les deux. Le liseré de gauche
    -- dit l'etat : gris au repos, or pendant l'invitation, rouge en combat.
    local entete = CreateFrame("Frame", nil, f)
    f.entete = entete
    entete:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    entete:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    entete:SetHeight(ENTETE)
    entete.fond = UI.Aplat(entete, { 0, 0, 0, 0.35 }, "BACKGROUND")
    entete.fond:SetAllPoints(entete)
    UI.BordureFine(entete, 0.18)
    entete.liseret = UI.Aplat(entete, { 1, 1, 1, 1 }, "ARTWORK")
    entete.liseret:SetWidth(3)
    entete.liseret:SetPoint("TOPLEFT", entete, "TOPLEFT", 0, 0)
    entete.liseret:SetPoint("BOTTOMLEFT", entete, "BOTTOMLEFT", 0, 0)
    f.pastilles = {}
    for index = 1, PASTILLES do
        local p = UI.Aplat(entete, { 1, 1, 1, 1 }, "ARTWORK")
        p:SetSize(8, 8)
        p:Hide()
        f.pastilles[index] = p
    end
    f.compteur = UI.Texte(entete, "", UI.C.libelle)
    UI.Police(f.compteur, 11)
    f.compteur:SetJustifyH("RIGHT")
    f.bandeau = UI.Texte(entete, "", UI.C.texte)
    UI.Police(f.bandeau, 12)
    f.bandeau:SetPoint("LEFT", entete, "LEFT", 12, 0)
    f.bandeau:SetPoint("RIGHT", f.compteur, "LEFT", -10, 0)
    f.bandeau:SetJustifyH("LEFT")
    f.bandeau:SetWordWrap(false)

    -- ----- a gauche : qui entre au combat ---------------------------------
    f.colGauche = UI.Colonne(f, "Joueurs du groupe", true)
    f.titreQui = f.colGauche.titre
    f.colGauche.compte = UI.Texte(f.colGauche, "", UI.C.discret)
    UI.Police(f.colGauche.compte, 11)
    f.colGauche.compte:SetPoint("TOPRIGHT", f.colGauche, "TOPRIGHT", -8, -8)

    f.moi = UI.Case(f.colGauche, "M'inclure au combat")
    f.moi:SetPoint("TOPLEFT", f.colGauche, "TOPLEFT", 8, -(f.colGauche.haut + 2))
    f.moi:Cocher(true)

    f.zonePNJ = UI.Defilement(f.colGauche)
    f.lignesPNJ = {}
    f.aucunPNJ = UI.Texte(f.colGauche, "", UI.C.discret)
    UI.Police(f.aucunPNJ, 11)
    f.aucunPNJ:SetPoint("TOPLEFT", f.zonePNJ, "TOPLEFT", 4, -4)
    f.aucunPNJ:SetPoint("TOPRIGHT", f.zonePNJ, "TOPRIGHT", -4, -4)
    f.aucunPNJ:SetWordWrap(true)

    -- ----- a droite : les PNJ, puis l'ordre d'initiative ------------------
    f.colDroite = UI.Colonne(f, "PNJ en scène", true)
    f.titreListe = f.colDroite.titre
    f.colDroite.compte = UI.Texte(f.colDroite, "", UI.C.discret)
    UI.Police(f.colDroite.compte, 11)
    f.colDroite.compte:SetPoint("TOPRIGHT", f.colDroite, "TOPRIGHT", -8, -8)
    f.zoneListe = UI.Defilement(f.colDroite)
    -- La barre de defilement vit hors de la zone : 12 de marge a droite.
    f.zoneListe:SetPoint("TOPLEFT", f.colDroite, "TOPLEFT", 6, -(f.colDroite.haut + 2))
    f.zoneListe:SetPoint("BOTTOMRIGHT", f.colDroite, "BOTTOMRIGHT", -12, 6)
    f.lignesListe = {}
    f.aucunListe = UI.Texte(f.colDroite, "", UI.C.discret)
    UI.Police(f.aucunListe, 11)
    f.aucunListe:SetPoint("TOPLEFT", f.zoneListe, "TOPLEFT", 4, -4)
    f.aucunListe:SetPoint("TOPRIGHT", f.zoneListe, "TOPRIGHT", -4, -4)
    f.aucunListe:SetWordWrap(true)

    -- ----- la barre d'actions ---------------------------------------------
    f.filetBas = UI.Filet(f, true)
    f.filetBas:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, BARRE - 4)
    f.filetBas:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, BARRE - 4)

    f.lancer = UI.Bouton(f.contenu, "Lancer le combat", 140, 24, function()
        local pnj = {}
        for _, instance in ipairs(LCM.Incarnation.Liste()) do
            if f.choisis[instance.id] then pnj[#pnj + 1] = instance.id end
        end
        local joueurs = {}
        for _, joueur in ipairs(C.Membres()) do
            if not f.exclus[joueur] then joueurs[#joueurs + 1] = joueur end
        end
        local fait, raison = C.Inviter({ pnj = pnj, moi = f.moi:EstCochee(), joueurs = joueurs })
        Dire(fait, raison)
        f:Afficher()
    end)
    f.lancer:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    Ton(f.lancer, UI.C.accent)

    -- Ceux qui n'ont pas repondu restent dehors : Necronicon appelait ca
    -- « lancer quand meme ».
    f.forcer = UI.Bouton(f.contenu, "Lancer sans attendre", 150, 24, function()
        Dire(C.Lancer())
        f:Afficher()
    end)
    f.forcer:SetPoint("LEFT", f.lancer, "RIGHT", 8, 0)
    Ton(f.forcer, UI.C.accent)
    f.annuler = UI.Bouton(f.contenu, "Annuler", 90, 24, function()
        C.Annuler()
        f:Afficher()
    end)
    f.annuler:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    -- « Integrer au combat » ne se montre qu'en combat, comme les tours : il
    -- ouvre la rangee, les tours le suivent. Ancres tous au coin, ils se
    -- recouvraient (constate le 16 octobre 2026).
    f.integrer = UI.Bouton(f.contenu, "Intégrer au combat", 150, 24, function()
        local ids = {}
        for _, candidat in ipairs(f.candidats or {}) do
            if f.choisis[candidat.id] then ids[#ids + 1] = candidat.id end
        end
        local invitation, raison = C.Integrer(ids)
        Dire(invitation ~= nil, raison)
        f:Afficher()
    end)
    f.integrer:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)

    f.precedent = UI.Bouton(f.contenu, "Tour précédent", 120, 24, function() Dire(C.Avancer(-1)) end)
    f.precedent:SetPoint("LEFT", f.integrer, "RIGHT", 8, 0)
    -- Le geste qu'on fait le plus : en or.
    f.suivant = UI.Bouton(f.contenu, "Tour suivant", 120, 24, function() Dire(C.Avancer(1)) end)
    f.suivant:SetPoint("LEFT", f.precedent, "RIGHT", 8, 0)
    Ton(f.suivant, UI.C.accent)
    -- Arreter un combat se confirme : un clic de travers le ferait chez tout
    -- le monde.
    -- Posee sur la PAGE, pas sur la fenetre : en mode compact, la page est
    -- empruntee et le grand panneau cache — la question s'y ouvrait
    -- invisible, et « Terminer » semblait ne rien faire (le MJ, 2 novembre
    -- 2026). La strate FULLSCREEN_DIALOG la met devant tout de toute facon.
    f.confirmer = UI.Confirmer(f, "", "Terminer")
    f.terminer = UI.Bouton(f.contenu, "Terminer le combat", 150, 24, function()
        f.confirmer:Demander("Terminer le combat pour tout le monde ?", function()
            Dire(C.Terminer())
        end)
    end)
    f.terminer:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    -- En rouge : on ne le prend pas pour « Tour suivant ».
    Ton(f.terminer, UI.C.plein)

    function f:AfficherPNJ(modifiable)
        local etat = C.Etat()
        local actifs = {}
        if etat then
            for _, entree in ipairs(etat.entrees) do actifs[entree.id] = true end
        end
        local liste = LCM.Incarnation.Liste()
        -- Combat lance : les PNJ en jeu qui n'y sont pas encore, puis les
        -- joueurs du groupe. Les uns comme les autres peuvent le rejoindre.
        local candidats = {}
        if etat then
            for _, instance in ipairs(liste) do
                if not actifs[instance.id] then candidats[#candidats + 1] = instance end
            end
            for _, joueur in ipairs(C.Membres()) do
                if not actifs[joueur] then
                    candidats[#candidats + 1] = { id = joueur, name = NomPersonnage(joueur), joueur = joueur }
                end
            end
        end
        self.candidats = candidats
        -- Avant le combat (le MJ, 2 novembre 2026) : a GAUCHE les joueurs du
        -- groupe, a inviter ou non ; a DROITE les PNJ de la scene
        -- (AfficherListe). Pendant l'invitation, chaque joueur dit sa reponse.
        local avant = {}
        if not etat then
            for _, joueur in ipairs(C.Membres()) do
                avant[#avant + 1] = { id = joueur, name = NomPersonnage(joueur), joueur = joueur, invite = true }
            end
        end
        -- « M'inclure » n'a de sens qu'avant le combat : ensuite, la colonne
        -- remonte et prend sa place.
        self.moi:SetShown(not etat)
        local haut = self.colGauche.haut + (etat and 2 or 28)
        self.zonePNJ:ClearAllPoints()
        self.zonePNJ:SetPoint("TOPLEFT", self.colGauche, "TOPLEFT", 6, -haut)
        self.zonePNJ:SetPoint("BOTTOMLEFT", self.colGauche, "BOTTOMLEFT", 6, 6)

        local source = etat and candidats or avant
        local y, invites = 0, 0
        for rang, instance in ipairs(source) do
            local l = self.lignesPNJ[rang]
            if not l then
                l = Rangee(self.zonePNJ.contenu)
                local ligne = l
                l.case = UI.Case(l, "", function(coche)
                    if ligne.invite then self.exclus[ligne.cle] = (not coche) or nil
                    else self.choisis[ligne.cle] = coche or nil end
                    self:Compter()
                end)
                l.case:SetPoint("LEFT", l, "LEFT", 4, 0)
                self.lignesPNJ[rang] = l
            end
            l.cle = instance.id
            l.invite = instance.invite == true
            PoserIcone(l.icone, instance.icon, instance.joueur)
            l.nom:SetText(tostring(instance.name))
            if l.invite then l.case:Cocher(not self.exclus[instance.id])
            else l.case:Cocher(self.choisis[instance.id] == true) end
            if l.case:EstCochee() then invites = invites + 1 end
            -- La reponse a l'invitation, sur la ligne du joueur, en couleur.
            local reponse, teinte = "", UI.C.discret
            local invitation = C.invitation
            if l.invite and invitation and not etat then
                if not invitation.cibles[instance.id] then reponse = "non invité"
                else
                    local r = invitation.reponses[instance.id]
                    if r and r.ok then reponse, teinte = string.format("accepte (%d)", r.v), VERT
                    elseif r then reponse, teinte = "refuse", UI.C.plein
                    else reponse = "attend…" end
                end
            end
            l.etat:SetText(reponse)
            Teinte(l.etat, teinte)
            l.case:SetEnabled(etat ~= nil or modifiable)
            Poser(l, self.zonePNJ.contenu, y)
            y = y + LIGNE
        end
        for rang = #source + 1, #self.lignesPNJ do self.lignesPNJ[rang]:Hide() end
        self.zonePNJ:Regler(y)
        self.titreQui:SetText(etat and "À intégrer" or "Joueurs du groupe")
        self.aucunPNJ:SetText(#source > 0 and ""
            or (etat and "Personne hors du combat : ni joueur du groupe, ni PNJ en jeu."
                or "Personne dans le groupe : le combat se fera entre toi et les PNJ."))
        self.nombreGauche, self.cochesGauche = #source, invites
        self.integrer:SetShown(etat ~= nil)
        Activer(self.integrer, etat ~= nil and #candidats > 0)
    end

    function f:AfficherListe()
        local etat = C.Etat()
        local invitation = C.invitation
        local lignes = {}
        if etat then
            self.titreListe:SetText("Ordre d'initiative")
            for index, e in ipairs(etat.entrees) do
                lignes[#lignes + 1] = { icone = e.icone, nom = e.nom, joueur = not e.pnj and e.id or nil,
                    etat = tostring(e.v), actif = index == etat.c, rang = index, ko = e.ko,
                    instance = e.pnj and e.id or nil }
            end
            local tardive = C.invitationTardive
            if tardive then
                local noms = {}
                for joueur in pairs(tardive.cibles) do noms[#noms + 1] = joueur end
                table.sort(noms)
                for _, joueur in ipairs(noms) do
                    lignes[#lignes + 1] = { nom = NomPersonnage(joueur), joueur = joueur, etat = "attend…" }
                end
            end
        else
            -- Hors combat, invitation comprise : les PNJ de la scene, a cocher
            -- (les reponses des joueurs se lisent sur leur ligne, a gauche).
            self.titreListe:SetText("PNJ en scène")
            for _, instance in ipairs(LCM.Incarnation.Liste()) do
                lignes[#lignes + 1] = { nom = tostring(instance.name), icone = instance.icon,
                    pnjId = instance.id, etat = "" }
            end
        end
        local y, coches = 0, 0
        local libre = not etat and not invitation
        for rang, ligne in ipairs(lignes) do
            local l = self.lignesListe[rang]
            if not l then
                l = Rangee(self.zoneListe.contenu)
                local rangee = l
                l.case = UI.Case(l, "", function(coche)
                    if rangee.pnjId then self.choisis[rangee.pnjId] = coche or nil end
                    self:Compter()
                end)
                l.case:SetPoint("LEFT", l, "LEFT", 4, 0)
                -- « Mort » (le MJ, 3 novembre 2026) : un PNJ tombe a 0 PV, son
                -- nom passe au rouge et ce bouton fait apparaitre son cadavre
                -- a la position du MJ (MJ/Cadavres.lua).
                l.mort = UI.Bouton(l, "Mort", 46, 18, function()
                    local id, raison = MJ.Cadavres.Mort(rangee.instance)
                    if not id then LCM.Alerte(tostring(raison)) return end
                    LCM.Ok("Le cadavre est posé à tes pieds. Corrige ce qu'il porte, puis les joueurs pourront le fouiller.")
                    if LCM.UI.Cadavre then LCM.UI.Cadavre.Ouvrir(id) end
                    self:AfficherListe()
                end)
                l.mort:SetPoint("RIGHT", l.etat, "LEFT", -6, 0)
                l.mort:Hide()
                UI.Bulle(l.mort, "Mort", "Fait apparaître son cadavre à ta position, avec ce qu'il portait et son butin.")
                self.lignesListe[rang] = l
            end
            l.pnjId = ligne.pnjId
            l.instance = ligne.instance
            local instance = ligne.instance and LCM.Incarnation.Instance(ligne.instance)
            local sansCadavre = instance and not (instance.cadavre and MJ.Cadavres.Get(instance.cadavre))
            l.mort:SetShown(ligne.ko == true and sansCadavre == true)
            l.case:SetShown(ligne.pnjId ~= nil)
            if ligne.pnjId then
                l.case:Cocher(self.choisis[ligne.pnjId] == true)
                l.case:SetEnabled(libre)
                if l.case:EstCochee() then coches = coches + 1 end
            end
            -- Le rang dans l'ordre d'initiative, la ou se tient la case.
            l.rang:SetText(ligne.rang and tostring(ligne.rang) or "")
            PoserIcone(l.icone, ligne.icone, ligne.joueur)
            l.nom:SetText(ligne.nom)
            l.etat:SetText(ligne.etat)
            l.halo:SetShown(ligne.actif == true)
            l.marque:SetShown(ligne.actif == true)
            -- Un PNJ a 0 PV au ROUGE (le MJ, 3 novembre 2026) : c'est la que
            -- « Mort » apparait. Un joueur KO reste en discret.
            local couleurNom = (ligne.ko and ligne.instance and UI.C.plein) or (ligne.actif and UI.C.titre)
                or (ligne.ko and UI.C.discret) or UI.C.texte
            Teinte(l.nom, couleurNom)
            Teinte(l.rang, ligne.actif and UI.C.accent or UI.C.discret)
            -- L'initiative en or ; « attend… » en discret.
            Teinte(l.etat, ligne.rang and UI.C.accent or UI.C.discret)
            UI.Police(l.etat, ligne.rang and 12 or 11)
            Poser(l, self.zoneListe.contenu, y)
            y = y + LIGNE
        end
        for rang = #lignes + 1, #self.lignesListe do self.lignesListe[rang]:Hide() end
        self.zoneListe:Regler(y)
        self.nombreListe = #lignes
        self.cochesDroite = coches
        self.aucunListe:SetText((not etat and #lignes == 0)
            and "Aucun PNJ en scène. « + Scène » (Scène & PNJ) en met un en jeu." or "")
    end

    -- Les comptes, en haut a droite de chaque colonne. Appele aussi quand une
    -- case change, sans tout redessiner.
    function f:Compter()
        local etat = C.Etat()
        if etat then
            self.colGauche.compte:SetText(self.nombreGauche and self.nombreGauche > 0
                and tostring(self.nombreGauche) or "")
            local n = #etat.entrees
            self.colDroite.compte:SetText(string.format("%d combattant%s", n, n > 1 and "s" or ""))
            return
        end
        local invites, total = 0, 0
        for _, l in ipairs(self.lignesPNJ) do
            if l:IsShown() and l.invite then
                total = total + 1
                if l.case:EstCochee() then invites = invites + 1 end
            end
        end
        self.colGauche.compte:SetText(total > 0 and string.format("%d / %d", invites, total) or "")
        local coches, pnj = 0, 0
        for _, l in ipairs(self.lignesListe) do
            if l:IsShown() and l.pnjId then
                pnj = pnj + 1
                if l.case:EstCochee() then coches = coches + 1 end
            end
        end
        self.colDroite.compte:SetText(pnj > 0 and string.format("%d / %d", coches, pnj) or "")
    end

    -- Le bandeau : la phrase a gauche, le tour et ses rounds a droite.
    function f:AfficherEntete()
        local etat = C.Etat()
        local invitation = C.invitation
        local liseret, teinte = UI.C.discret, UI.C.discret
        local rm, r = 0, 0
        if etat then
            local courant = C.Courant()
            self.bandeau:SetText(string.format("Combat en cours — à %s de jouer.", courant and courant.nom or "?"))
            liseret, teinte = UI.C.plein, UI.C.titre
            rm = math.min(PASTILLES, math.max(0, tonumber(etat.rm) or 0))
            r = tonumber(etat.r) or 1
            self.compteur:SetText(self.compact and string.format("TOUR %d", etat.t)
                or string.format("TOUR %d · ROUND %d/%d", etat.t, etat.r, etat.rm))
        elseif invitation then
            local attendus = #C.Attendus()
            self.bandeau:SetText(string.format("Invitation envoyée : %d réponse%s attendue%s.",
                attendus, attendus > 1 and "s" or "", attendus > 1 and "s" or ""))
            liseret, teinte = UI.C.accent, UI.C.accent
            self.compteur:SetText("")
        else
            self.bandeau:SetText("Aucun combat. Choisis qui y prend part, puis lance.")
            self.compteur:SetText("")
        end
        self.entete.liseret:SetColorTexture(liseret[1], liseret[2], liseret[3], 1)
        Teinte(self.bandeau, teinte)
        -- Un rond par round : passes en or terne, l'actuel en or plein, ceux
        -- a venir a peine marques.
        for index, p in ipairs(self.pastilles) do
            if index <= rm then
                p:ClearAllPoints()
                p:SetPoint("RIGHT", self.entete, "RIGHT", -(12 + (rm - index) * PAS_PASTILLE), 0)
                local a = UI.C.accent
                if index < r then p:SetColorTexture(a[1], a[2], a[3], 0.45)
                elseif index == r then p:SetColorTexture(a[1], a[2], a[3], 1)
                else p:SetColorTexture(1, 1, 1, 0.15) end
                p:Show()
            else
                p:Hide()
            end
        end
        self.compteur:ClearAllPoints()
        self.compteur:SetPoint("RIGHT", self.entete, "RIGHT", -(rm > 0 and (18 + rm * PAS_PASTILLE) or 12), 0)
    end

    function f:Afficher()
        local etat = C.Etat()
        local invitation = C.invitation
        self:AfficherEntete()
        local libre = not etat and not invitation
        self.moi:SetEnabled(libre)
        self:AfficherPNJ(libre)
        self:AfficherListe()
        self:Compter()
        self.lancer:SetShown(not etat and not invitation)
        Activer(self.lancer, libre)
        self.forcer:SetShown(invitation ~= nil)
        self.annuler:SetShown(invitation ~= nil)
        self.precedent:SetShown(etat ~= nil)
        -- Bloque au tout premier passage (tour 1, round 1, premier joueur).
        Activer(self.precedent, etat ~= nil and not C.AuDebut(etat))
        self.suivant:SetShown(etat ~= nil)
        self.terminer:SetShown(etat ~= nil)
        self.integrer:SetShown(etat ~= nil)
    end

    -- Deux densites (le MJ, 2 novembre 2026) : la page sert aussi la fenetre
    -- compacte du Panel MJ, large de 480. Colonnes resserrees, boutons plus
    -- courts ; « Terminer » reste en bas a droite.
    function f:Disposer(compact)
        local c = compact and true or false
        self.compact = c
        local colonne = c and 220 or COLONNE
        self.colGauche:ClearAllPoints()
        self.colGauche:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(ENTETE + 8))
        self.colGauche:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, BARRE + 4)
        self.colGauche:SetWidth(colonne)
        -- La barre de defilement vit hors de la zone : 18 de marge en tout.
        self.zonePNJ:SetWidth(colonne - 18)
        self.colDroite:ClearAllPoints()
        self.colDroite:SetPoint("TOPLEFT", self.colGauche, "TOPRIGHT", 10, 0)
        self.colDroite:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, BARRE + 4)
        self.precedent:SetWidth(c and 66 or 120)
        self.suivant:SetWidth(c and 76 or 120)
        self.precedent.label:SetText(c and "Préc." or "Tour précédent")
        self.suivant.label:SetText(c and "Suivant" or "Tour suivant")
        self.integrer:SetWidth(c and 96 or 150)
        self.integrer.label:SetText(c and "Intégrer" or "Intégrer au combat")
        self.terminer:SetWidth(c and 120 or 150)
        self.terminer.label:SetText(c and "Terminer" or "Terminer le combat")
        self.forcer:SetWidth(c and 130 or 150)
        self.forcer.label:SetText(c and "Sans attendre" or "Lancer sans attendre")
        self.lancer:SetWidth(c and 120 or 140)
        self.lancer.label:SetText(c and "Inviter" or "Lancer le combat")
        self:Afficher()
    end

    -- Une premiere disposition, pour que la page tienne avant que le panneau
    -- ne la regle.
    f:Disposer(false)
    return f
end

-- Le contenu de l'onglet : construit avec le panneau.
function Ecran.Fenetre()
    UI.PanneauMJ.Fenetre()
    return Ecran.frame
end

-- Ouvre le panneau sur l'onglet Combat, ou le referme s'il y est deja.
function Ecran.Basculer()
    local p = UI.PanneauMJ.Fenetre()
    if p:IsShown() and p.onglet == "combat" then p:Hide() else p:Montrer("combat") end
    return Ecran.frame
end

-- La page se redessine des qu'elle est A L'ECRAN, quel que soit le panneau
-- qui la porte. On ne regardait que le grand panneau : en compact, il est
-- cache, et la page restait figee — round 2 affiche quand on etait revenu au
-- round 1 (le MJ, 2 novembre 2026). La barre du compact suit aussi.
local function Rafraichir()
    if Ecran.frame and Ecran.frame:IsVisible() then Ecran.frame:Afficher() end
    local compact = UI.PanneauMJ.compact
    if compact and compact:IsShown() and compact.AfficherCombat then compact:AfficherCombat() end
end

-- Le bandeau s'abonne deja a onChange : on passe apres lui, sans le remplacer.
local avant = C.onChange
C.onChange = function(etat)
    if avant then avant(etat) end
    Rafraichir()
end
C.onInvitation = function() Rafraichir() end
