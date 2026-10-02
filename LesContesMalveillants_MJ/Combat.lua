-- Mener un combat : la fenetre du maitre du jeu.
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

local LARGEUR, HAUTEUR = 640, 480
local COLONNE = 300
local LIGNE = 26

local function Rangee(parent)
    local l = CreateFrame("Frame", nil, parent)
    l:SetHeight(LIGNE - 2)
    if UI.SurfaceLigne then UI.SurfaceLigne(l) end
    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetSize(18, 18)
    l.icone:SetPoint("LEFT", l, "LEFT", 28, 0)
    l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    l.nom = UI.Texte(l, "", UI.C.texte)
    UI.Police(l.nom, 11)
    l.nom:SetPoint("LEFT", l.icone, "RIGHT", 6, 0)
    l.etat = UI.Texte(l, "", UI.C.discret)
    UI.Police(l.etat, 11)
    l.etat:SetPoint("RIGHT", l, "RIGHT", -6, 0)
    l.etat:SetJustifyH("RIGHT")
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

local function Construire()
    local f = UI.Fenetre("combat_mj", "Combat", LARGEUR, HAUTEUR, { x = 120, y = -40 })
    Ecran.frame = f
    -- Les PNJ coches, par identifiant d'instance.
    f.choisis = {}

    f.bandeau = UI.Texte(f.contenu, "", UI.C.accent)
    UI.Police(f.bandeau, 12)
    f.bandeau:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)

    -- ----- qui entre au combat --------------------------------------------
    f.titreQui = UI.Texte(f.contenu, "Au combat", UI.C.titre)
    UI.Police(f.titreQui, 11)
    f.titreQui:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -28)

    f.moi = UI.Case(f.contenu, "M'inclure au combat")
    f.moi:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -48)
    f.moi:Cocher(true)

    f.zonePNJ = UI.Defilement(f.contenu)
    f.zonePNJ:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -74)
    f.zonePNJ:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 34)
    f.zonePNJ:SetWidth(COLONNE)
    f.lignesPNJ = {}

    f.aucunPNJ = UI.Texte(f.contenu, "", UI.C.discret)
    UI.Police(f.aucunPNJ, 11)
    f.aucunPNJ:SetPoint("TOPLEFT", f.zonePNJ, "TOPLEFT", 4, -4)
    f.aucunPNJ:SetPoint("TOPRIGHT", f.zonePNJ, "TOPRIGHT", -4, -4)
    f.aucunPNJ:SetWordWrap(true)

    -- ----- les combattants ------------------------------------------------
    f.titreListe = UI.Texte(f.contenu, "", UI.C.titre)
    UI.Police(f.titreListe, 11)
    f.titreListe:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 16, -28)

    f.zoneListe = UI.Defilement(f.contenu)
    f.zoneListe:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 16, -48)
    f.zoneListe:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 34)
    f.lignesListe = {}

    -- ----- les actions ----------------------------------------------------
    f.lancer = UI.Bouton(f.contenu, "Lancer le combat", 140, 24, function()
        local pnj = {}
        for _, instance in ipairs(LCM.Incarnation.Liste()) do
            if f.choisis[instance.id] then pnj[#pnj + 1] = instance.id end
        end
        local fait, raison = C.Inviter({ pnj = pnj, moi = f.moi:EstCochee() })
        Dire(fait, raison)
        f:Afficher()
    end)
    f.lancer:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)

    -- Ceux qui n'ont pas repondu restent dehors : Necronicon appelait ca
    -- « lancer quand meme ».
    f.forcer = UI.Bouton(f.contenu, "Lancer sans attendre", 150, 24, function()
        Dire(C.Lancer())
        f:Afficher()
    end)
    f.forcer:SetPoint("LEFT", f.lancer, "RIGHT", 8, 0)
    f.annuler = UI.Bouton(f.contenu, "Annuler", 90, 24, function()
        C.Annuler()
        f:Afficher()
    end)
    f.annuler:SetPoint("LEFT", f.forcer, "RIGHT", 8, 0)

    f.precedent = UI.Bouton(f.contenu, "Tour précédent", 120, 24, function() Dire(C.Avancer(-1)) end)
    f.precedent:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.suivant = UI.Bouton(f.contenu, "Tour suivant", 120, 24, function() Dire(C.Avancer(1)) end)
    f.suivant:SetPoint("LEFT", f.precedent, "RIGHT", 8, 0)
    -- Arreter un combat se confirme : un clic de travers le ferait chez tout
    -- le monde.
    f.confirmer = UI.Confirmer(f, "", "Terminer")
    f.terminer = UI.Bouton(f.contenu, "Terminer le combat", 150, 24, function()
        f.confirmer:Demander("Terminer le combat pour tout le monde ?", function()
            Dire(C.Terminer())
        end)
    end)
    f.terminer:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    function f:AfficherPNJ(modifiable)
        local liste = LCM.Incarnation.Liste()
        local y = 0
        for rang, instance in ipairs(liste) do
            local l = self.lignesPNJ[rang]
            if not l then
                l = Rangee(self.zonePNJ.contenu)
                l.case = UI.Case(l, "", function(coche)
                    self.choisis[self.lignesPNJ[rang].instanceId] = coche or nil
                end)
                l.case:SetPoint("LEFT", l, "LEFT", 4, 0)
                self.lignesPNJ[rang] = l
            end
            l.instanceId = instance.id
            l.icone:SetTexture(LCM.Icone(instance.icon))
            l.nom:SetText(tostring(instance.name))
            l.case:Cocher(self.choisis[instance.id] == true)
            l.case:SetEnabled(modifiable)
            Poser(l, self.zonePNJ.contenu, y)
            y = y + LIGNE
        end
        for rang = #liste + 1, #self.lignesPNJ do self.lignesPNJ[rang]:Hide() end
        self.zonePNJ:Regler(y)
        self.aucunPNJ:SetText(#liste > 0 and ""
            or "Aucun PNJ en jeu. Mets-en en jeu depuis la fenêtre Incarner pour qu'ils combattent.")
    end

    function f:AfficherListe()
        local etat = C.Etat()
        local invitation = C.invitation
        local lignes = {}
        if etat then
            self.titreListe:SetText("Ordre d'initiative")
            for index, e in ipairs(etat.entrees) do
                lignes[#lignes + 1] = { icone = e.icone, nom = e.nom,
                    etat = tostring(e.v), actif = index == etat.c }
            end
        elseif invitation then
            self.titreListe:SetText("Invités")
            local noms = {}
            for joueur in pairs(invitation.cibles) do noms[#noms + 1] = joueur end
            table.sort(noms)
            for _, joueur in ipairs(noms) do
                local r = invitation.reponses[joueur]
                local texte = "attend…"
                if r and r.ok then texte = string.format("accepte (%d)", r.v)
                elseif r then texte = "refuse" end
                lignes[#lignes + 1] = { nom = r and r.nom or joueur, etat = texte }
            end
        else
            self.titreListe:SetText("")
        end
        local y = 0
        for rang, ligne in ipairs(lignes) do
            local l = self.lignesListe[rang]
            if not l then
                l = Rangee(self.zoneListe.contenu)
                self.lignesListe[rang] = l
            end
            l.icone:SetTexture(LCM.Icone(ligne.icone))
            l.nom:SetText(ligne.nom)
            l.etat:SetText(ligne.etat)
            local couleur = ligne.actif and UI.C.accent or UI.C.texte
            l.nom:SetTextColor(couleur[1], couleur[2], couleur[3])
            Poser(l, self.zoneListe.contenu, y)
            y = y + LIGNE
        end
        for rang = #lignes + 1, #self.lignesListe do self.lignesListe[rang]:Hide() end
        self.zoneListe:Regler(y)
        self.nombreListe = #lignes
    end

    function f:Afficher()
        local etat = C.Etat()
        local invitation = C.invitation
        if etat then
            local courant = C.Courant()
            self.bandeau:SetText(string.format("Combat en cours — tour %d, round %d/%d. À %s.",
                etat.t, etat.r, etat.rm, courant and courant.nom or "?"))
        elseif invitation then
            local attendus = #C.Attendus()
            self.bandeau:SetText(string.format("Invitation envoyée : %d réponse%s attendue%s.",
                attendus, attendus > 1 and "s" or "", attendus > 1 and "s" or ""))
        else
            self.bandeau:SetText("Aucun combat.")
        end
        local libre = not etat and not invitation
        self.moi:SetEnabled(libre)
        self:AfficherPNJ(libre)
        self:AfficherListe()
        self.lancer:SetShown(not etat)
        self.lancer:SetEnabled(libre)
        self.forcer:SetShown(invitation ~= nil)
        self.annuler:SetShown(invitation ~= nil)
        self.precedent:SetShown(etat ~= nil)
        self.suivant:SetShown(etat ~= nil)
        self.terminer:SetShown(etat ~= nil)
    end

    function f:Montrer()
        self:Afficher()
        self:Show()
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

local function Rafraichir()
    if Ecran.frame and Ecran.frame:IsShown() then Ecran.frame:Afficher() end
end

-- Le bandeau s'abonne deja a onChange : on passe apres lui, sans le remplacer.
local avant = C.onChange
C.onChange = function(etat)
    if avant then avant(etat) end
    Rafraichir()
end
C.onInvitation = function() Rafraichir() end
