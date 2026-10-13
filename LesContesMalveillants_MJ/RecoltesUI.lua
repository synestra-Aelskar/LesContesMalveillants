-- La fenetre « Ressources » du MJ : creer des points de recolte, puis les poser
-- sur la carte (13 octobre 2026).
--
-- Deux onglets, dans l'ordre ou on s'en sert :
--   * CREATION — « Miner du fer » : quelle ressource (choisie, ou glissee depuis
--     le compendium), combien on en tire (fixe, ou entre un minimum et un
--     maximum), quel metier et quel DD, a quelle distance on peut recolter ;
--   * PLACEMENT — on choisit « Miner du fer », on marche, et chaque clic sur
--     « Creer un point de recolte » en pose un ICI. Tous les points poses de
--     cette ressource sont listes en dessous, et se retirent un par un.
--
-- Elle remplace l'ancien editeur a offres pour les ressources : un point de
-- recolte ne se « vend » pas en liste, il se trouve sur le terrain. Le vendeur,
-- lui, garde son constructeur (MJ/PointsUI.lua).

local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Points = LCM.Points
local Recoltes = LCM.Recoltes

local Ecran = {}
UI.Recoltes = Ecran

local LARGEUR, HAUTEUR = 760, 500
local COLONNE = 210
local LIGNE = 26

local function Eq() return (LCM.Equilibrage and LCM.Equilibrage.recolte) or {} end

local function Libelle(parent, texte, x, y)
    local t = UI.Texte(parent, texte, UI.C.discret, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return t
end

local function Entier(texte)
    local n = tonumber(texte)
    return n and math.floor(n) or nil
end

-- Un point de recolte ne donne QUE des ressources (famille « ressources » du
-- compendium) : ni objet, ni tente, ni accessoire de camping (13 octobre 2026).
local FAMILLE = "ressources"

local function EstRessource(ref)
    return tostring(ref or ""):sub(1, #FAMILLE + 1) == FAMILLE .. "/"
end

local function OptionsEntrees()
    local options = {}
    local registreNom = LCM.Compendium and LCM.Compendium.FAMILLES and LCM.Compendium.FAMILLES[FAMILLE]
    local registre = registreNom and LCM[registreNom]
    for _, entree in ipairs((registre and registre.list) or {}) do
        options[#options + 1] = { id = FAMILLE .. "/" .. entree.id, label = entree.label or entree.id }
    end
    table.sort(options, function(a, b) return tostring(a.label) < tostring(b.label) end)
    return options
end

local function OptionsMetiers()
    local options = { { id = "", label = "Aucun métier (pas de jet)" } }
    for _, metier in ipairs(LCM.Metiers.list) do
        options[#options + 1] = { id = metier.id, label = metier.label }
    end
    return options
end

local function Travail(point)
    if point then
        local copie = LCM.Copie(point)
        copie.brouillon, copie.remplacePublie = nil, nil
        copie.recolte = copie.recolte or {}
        return copie
    end
    return {
        id = LCM.Brouillons.NouvelIdentifiant(), nature = "ressource",
        label = "", description = "", offres = {},
        recolte = { entree = "", min = 1, max = 1, aleatoire = false, dd = 0,
                    rayon = Eq().rayon },
    }
end

-- « Mineur, DD 8 — 2 à 4 Minerai de fer, à 3 m »
local function Resume(point)
    local r = point and point.recolte
    if not r then return "Pas encore configuré : passe par l'onglet Création." end
    local ressource = LCM.Compendium.Resoudre(r.entree)
    local nom = (ressource and ressource.label) or (r.entree ~= "" and r.entree) or "aucune ressource"
    local quantite = r.aleatoire and r.max > r.min and string.format("%d à %d", r.min, r.max)
        or tostring(r.min)
    local metier = r.metier and LCM.Metiers.Get(r.metier)
    local jet = metier and string.format("%s, DD %d", metier.label, r.dd)
        or (r.dd > 0 and string.format("DD %d", r.dd) or "sans jet")
    return string.format("%s %s — %s — rayon %s yards", quantite, nom, jet,
        tostring(r.rayon or Eq().rayon or 3))
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("recoltes", "Ressources", LARGEUR, HAUTEUR, { x = 100, y = -40 })
    f.onglet = "creation"

    -- ----- les points de recolte, a gauche --------------------------------
    f.liste = UI.Defilement(f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 34)
    f.liste:SetWidth(COLONNE)
    f.lignes = {}
    f.nouveau = UI.Bouton(f.contenu, "+ Nouveau", 100, 24, function() f:Nouveau() end)
    f.nouveau:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.supprimer = UI.Bouton(f.contenu, "Supprimer", 100, 24, function() f:Supprimer() end)
    f.supprimer:SetPoint("LEFT", f.nouveau, "RIGHT", 6, 0)
    f.confirmation = UI.Confirmer(f, "", "Confirmer")

    f.droite = CreateFrame("Frame", nil, f.contenu)
    f.droite:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 16, 0)
    f.droite:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.boutonCreation = UI.Bouton(f.droite, "Création", 120, 24, function() f:Onglet("creation") end)
    f.boutonCreation:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, 0)
    f.boutonPlacement = UI.Bouton(f.droite, "Placement", 120, 24, function() f:Onglet("placement") end)
    f.boutonPlacement:SetPoint("LEFT", f.boutonCreation, "RIGHT", 6, 0)

    -- ----- CREATION -------------------------------------------------------
    local c = CreateFrame("Frame", nil, f.droite)
    c:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -34)
    c:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.creation = c
    f.choixEntree = UI.Choix("recolte_entree", "Ressource donnée")
    f.choixMetier = UI.Choix("recolte_metier", "Métier du jet")

    Libelle(c, "Nom", 0, -6)
    c.nom = UI.Champ(c, 300, 22, function(texte) if f.travail then f.travail.label = texte end end)
    c.nom:SetMaxLetters(80)
    c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 110, 0)

    Libelle(c, "Ressource", 0, -44)
    -- La case de la ressource : on clique pour choisir, ou on y lache une
    -- entree glissee depuis le compendium.
    c.entree = UI.Bouton(c, "", 300, 30, function()
        f.choixEntree:Proposer(c.entree, OptionsEntrees(), function(ref)
            if f.travail then f.travail.recolte.entree = ref f:Remplir() end
        end)
    end)
    c.entree:SetPoint("TOPLEFT", c, "TOPLEFT", 110, -36)
    c.entree.icone = c.entree:CreateTexture(nil, "ARTWORK")
    c.entree.icone:SetSize(24, 24)
    c.entree.icone:SetPoint("LEFT", c.entree, "LEFT", 4, 0)
    c.entree.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    c.entree.label:ClearAllPoints()
    c.entree.label:SetPoint("LEFT", c.entree.icone, "RIGHT", 8, 0)
    c.entree.label:SetPoint("RIGHT", c.entree, "RIGHT", -6, 0)
    c.entree.label:SetJustifyH("LEFT")
    UI.Glisser.Cible(c.entree, function(objet)
        if not (objet and EstRessource(objet.ref)) then
            return false, "seule une ressource du compendium (catégorie Ressources) se récolte."
        end
        return true
    end, function(objet)
        if f.travail then f.travail.recolte.entree = objet.ref f:Remplir() end
    end)
    c.aideEntree = UI.Texte(c, "Clique pour choisir, ou glisse une ressource du compendium ici.",
        UI.C.discret, "GameFontNormalSmall")
    c.aideEntree:SetPoint("TOPLEFT", c.entree, "BOTTOMLEFT", 0, -3)

    Libelle(c, "Quantité", 0, -98)
    c.aleatoire = UI.Case(c, "Aléatoire", function(coche)
        if f.travail then f.travail.recolte.aleatoire = coche f:Remplir() end
    end)
    c.aleatoire:SetPoint("TOPLEFT", c, "TOPLEFT", 110, -96)
    c.libelleMin = Libelle(c, "", 200, -98)
    c.min = UI.Champ(c, 50, 22, function(texte)
        if f.travail then f.travail.recolte.min = texte end
    end)
    c.min:SetPoint("TOPLEFT", c, "TOPLEFT", 250, -92)
    c.libelleMax = Libelle(c, "Max", 315, -98)
    c.max = UI.Champ(c, 50, 22, function(texte)
        if f.travail then f.travail.recolte.max = texte end
    end)
    c.max:SetPoint("TOPLEFT", c, "TOPLEFT", 350, -92)

    Libelle(c, "Métier", 0, -138)
    c.metier = UI.Bouton(c, "", 200, 22, function()
        f.choixMetier:Proposer(c.metier, OptionsMetiers(), function(id)
            if f.travail then
                f.travail.recolte.metier = (id ~= "" and id) or nil
                f:Remplir()
            end
        end)
    end)
    c.metier:SetPoint("TOPLEFT", c, "TOPLEFT", 110, -132)
    Libelle(c, "DD", 325, -138)
    c.dd = UI.Champ(c, 50, 22, function(texte)
        if f.travail then f.travail.recolte.dd = texte end
    end)
    c.dd:SetPoint("TOPLEFT", c, "TOPLEFT", 350, -132)
    c.aideJet = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    c.aideJet:SetPoint("TOPLEFT", c, "TOPLEFT", 110, -160)
    c.aideJet:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    c.aideJet:SetJustifyH("LEFT")

    Libelle(c, "Rayon (yards)", 0, -192)
    c.rayon = UI.Champ(c, 50, 22, function(texte)
        if f.travail then f.travail.recolte.rayon = texte end
    end)
    c.rayon:SetPoint("TOPLEFT", c, "TOPLEFT", 110, -186)
    c.aideRayon = UI.Texte(c, "Distance à laquelle le bouton « Récolter » apparaît.",
        UI.C.discret, "GameFontNormalSmall")
    c.aideRayon:SetPoint("LEFT", c.rayon, "RIGHT", 10, 0)

    c.erreur = UI.Texte(c, "", UI.C.plein, "GameFontNormalSmall")
    c.erreur:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 6)
    c.erreur:SetPoint("RIGHT", c, "RIGHT", -150, 0)
    c.erreur:SetJustifyH("LEFT")
    c.enregistrer = UI.Bouton(c, "Enregistrer", 140, 26, function() f:Enregistrer() end)
    c.enregistrer:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)

    -- ----- PLACEMENT ------------------------------------------------------
    local p = CreateFrame("Frame", nil, f.droite)
    p:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -34)
    p:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.placement = p

    p.titre = UI.Texte(p, "", UI.C.titre)
    UI.Police(p.titre, 14)
    p.titre:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -2)
    p.resume = UI.Texte(p, "", UI.C.discret, "GameFontNormalSmall")
    p.resume:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -22)
    p.resume:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    p.resume:SetJustifyH("LEFT")
    p.position = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
    p.position:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -44)
    p.position:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    p.position:SetJustifyH("LEFT")

    p.poser = UI.Bouton(p, "Créer un point de récolte", 260, 34, function() f:Poser() end)
    p.poser:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -66)
    p.compte = UI.Texte(p, "", UI.C.accent, "GameFontNormalSmall")
    p.compte:SetPoint("LEFT", p.poser, "RIGHT", 12, 0)
    p.toutRetirer = UI.Bouton(p, "Tout retirer", 110, 22, function() f:ToutRetirer() end)
    p.toutRetirer:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -72)

    p.zone = UI.Defilement(p)
    p.zone:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -110)
    p.zone:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -10, 0)
    p.lignes = {}
    p.vide = UI.Texte(p, "Aucun point posé. Marche jusqu'à l'endroit voulu et clique sur « Créer un point de récolte ».",
        UI.C.discret, "GameFontNormalSmall")
    p.vide:SetPoint("TOP", p.zone, "TOP", 0, -20)
    p.vide:SetWidth(380)
    p.vide:SetJustifyH("CENTER")
    p.vide:SetWordWrap(true)

    -- La position s'affiche en direct : on pose en marchant, il faut voir ou
    -- l'on est au moment ou l'on clique.
    p.attente = 0
    p:SetScript("OnUpdate", function(self, dt)
        self.attente = self.attente + (dt or 0)
        if self.attente < 0.5 then return end
        self.attente = 0
        f:Position()
    end)

    -- ----- comportement ---------------------------------------------------

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
        self.remplacePublie = point and LCM.Brouillons.EstPublie("points", point.id) or false
        self.creation.erreur:SetText("")
        self:Remplir()
        self:Afficher()
    end

    function f:Nouveau()
        self:Choisir(nil)
        self:Onglet("creation")
    end

    function f:Remplir()
        local t = self.travail
        if not t then return end
        local r = t.recolte
        c.nom:SetText(t.label or "")
        local ressource = LCM.Compendium.Resoudre(r.entree)
        c.entree.label:SetText((ressource and ressource.label)
            or ((r.entree or "") ~= "" and r.entree) or "Choisir une ressource")
        c.entree.icone:SetTexture((ressource and ressource.icone) or "Interface\\ICONS\\INV_Misc_QuestionMark")
        c.aleatoire:Cocher(r.aleatoire)
        c.libelleMin:SetText(r.aleatoire and "Min" or "Fixe")
        c.min:SetText(tostring(r.min or 1))
        c.max:SetText(tostring(r.max or r.min or 1))
        c.max:SetShown(r.aleatoire == true)
        c.libelleMax:SetShown(r.aleatoire == true)
        local metier = r.metier and LCM.Metiers.Get(r.metier)
        c.metier.label:SetText(metier and metier.label or "Aucun métier")
        c.dd:SetText(tostring(r.dd or 0))
        local des = Eq().des or {}
        c.aideJet:SetText(string.format("Jet : D%d + bonus du métier, contre le DD. Raté, on peut retenter.",
            des.max or 15))
        c.rayon:SetText(tostring(r.rayon or Eq().rayon or 3))
    end

    -- Un refus dit pourquoi, et ne corrige rien en douce.
    function f:Valider()
        local t = self.travail
        local r = t.recolte
        if not tostring(t.label or ""):match("%S") then return nil, "donne un nom au point de récolte." end
        if (r.entree or "") == "" or not LCM.Compendium.Resoudre(r.entree) then
            return nil, "choisis la ressource que le point donne."
        end
        -- Un point enregistre avant la restriction peut encore porter un objet :
        -- on le refuse a l'enregistrement plutot que de le changer en douce.
        if not EstRessource(r.entree) then
            return nil, "un point de récolte ne donne qu'une ressource (catégorie Ressources)."
        end
        local mini = Entier(r.min)
        if not mini or mini < 1 then return nil, "la quantité doit être un nombre entier, au moins 1." end
        local maxi = mini
        if r.aleatoire then
            maxi = Entier(r.max)
            if not maxi or maxi < mini then return nil, "le maximum doit être un entier, au moins égal au minimum." end
        end
        local dd = Entier(r.dd)
        if not dd or dd < 0 then return nil, "le DD doit être un entier positif (0 : réussite assurée)." end
        local rayon = tonumber(r.rayon)
        local rayonMax = Eq().rayonMax or 30
        if not rayon or rayon <= 0 or rayon > rayonMax then
            return nil, string.format("le rayon doit être entre 0 et %d yards.", rayonMax)
        end
        return { entree = r.entree, min = mini, max = maxi, aleatoire = r.aleatoire and true or false,
                 metier = r.metier, dd = dd, rayon = rayon }
    end

    function f:Enregistrer()
        local recolte, raison = self:Valider()
        if not recolte then
            c.erreur:SetText(raison)
            LCM.Alerte(raison)
            return
        end
        c.erreur:SetText("")
        self.travail.recolte = recolte
        local ok, erreur = LCM.Brouillons.Enregistrer("points", self.travail,
            self.creationNeuve, self.remplacePublie)
        if not ok then LCM.Alerte(tostring(erreur)) return end
        local id = self.travail.id
        -- Les points deja poses changent de regle tout de suite, chez tous.
        if Recoltes.Compte(id) > 0 then Recoltes.Diffuser(id) end
        if Recoltes.onChange then Recoltes.onChange(id) end
        LCM.Ok(string.format("Point de récolte « %s » enregistré.", self.travail.label))
        self:Choisir(id)
    end

    function f:Supprimer()
        local point = self:Point()
        if not point then return end
        local n = Recoltes.Compte(point.id)
        local texte = n > 0 and string.format("Supprimer « %s » et ses %d point(s) posé(s) ?", point.label, n)
            or string.format("Supprimer « %s » ?", point.label)
        self.confirmation:Demander(texte, function()
            local ok, raison
            if point.brouillon == true then ok = LCM.Brouillons.Supprimer("points", point.id)
            else ok, raison = LCM.Brouillons.Masquer("points", point.id) end
            if not ok then LCM.Alerte(tostring(raison or "suppression impossible")) return end
            Recoltes.RetirerTout(point.id)
            local premier = Points.Nature("ressource")[1]
            self:Choisir(premier and premier.id)
        end)
    end

    function f:Poser()
        local point = self:Point()
        if not point then LCM.Alerte("choisis d'abord un point de récolte.") return end
        local id, raison = Recoltes.Placer(point.id)
        if not id then LCM.Alerte(tostring(raison)) return end
        self:Afficher()
    end

    function f:ToutRetirer()
        local point = self:Point()
        if not point then return end
        local n = Recoltes.Compte(point.id)
        if n == 0 then return end
        self.confirmation:Demander(string.format("Retirer les %d point(s) posé(s) de « %s » ?", n, point.label),
            function()
                Recoltes.RetirerTout(point.id)
                self:Afficher()
            end)
    end

    function f:Position()
        local x, y, source = LCM.Recolte.Position()
        if x then
            local carte = LCM.Recolte.Carte()
            p.position:SetText(string.format("Tu es en %.1f, %.1f  (%s%s)", x, y, tostring(source),
                carte and (", carte " .. carte) or ""))
        else
            p.position:SetText("Position inconnue ici : le clic demandera « .gps ».")
        end
        return x, y, source
    end

    function f:AfficherPoints()
        local point = self:Point()
        local liste = point and Recoltes.Points(point.id) or {}
        local x, y, source = self:Position()
        local carte = LCM.Recolte.Carte()
        local h = 0
        for rang, pose in ipairs(liste) do
            local l = p.lignes[rang]
            if not l then
                l = CreateFrame("Frame", nil, p.zone.contenu)
                l:SetHeight(LIGNE - 2)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.texte = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                l.texte:SetPoint("LEFT", l, "LEFT", 8, 0)
                l.texte:SetPoint("RIGHT", l, "RIGHT", -40, 0)
                l.texte:SetJustifyH("LEFT")
                l.retirer = UI.Bouton(l, "x", 24, 20, function(b)
                    Recoltes.Retirer(b:GetParent().poseId)
                    self:Afficher()
                end)
                l.retirer:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                p.lignes[rang] = l
            end
            l.poseId = pose.id
            -- La distance quand elle se mesure : meme source, meme carte.
            local distance = ""
            if x and pose.source == source and pose.carte == carte then
                distance = string.format("  —  à %.0f yards", math.sqrt((x - pose.x) ^ 2 + (y - pose.y) ^ 2))
            elseif pose.carte ~= carte then
                distance = "  —  autre carte"
            end
            l.texte:SetText(string.format("#%d   %.1f, %.1f   (%s%s)%s", #liste - rang + 1,
                pose.x, pose.y, tostring(pose.source), pose.carte and (", carte " .. pose.carte) or "",
                distance))
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", p.zone.contenu, "TOPLEFT", 0, -h)
            l:SetPoint("TOPRIGHT", p.zone.contenu, "TOPRIGHT", 0, -h)
            l:Show()
            h = h + LIGNE
        end
        for rang = #liste + 1, #p.lignes do p.lignes[rang]:Hide() end
        p.zone:Regler(h)
        p.vide:SetShown(point ~= nil and #liste == 0)
        p.compte:SetText(point and string.format("%d point(s) posé(s)", #liste) or "")
        p.toutRetirer:SetEnabled(#liste > 0)
    end

    function f:Afficher()
        local definitions = Points.Nature("ressource")
        local y = 0
        for rang, point in ipairs(definitions) do
            local b = self.lignes[rang]
            if not b then
                b = UI.Bouton(self.liste.contenu, "", COLONNE - 10, LIGNE - 2, function(bouton)
                    self:Choisir(bouton.pointId)
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
                b.label:SetJustifyH("LEFT")
                self.lignes[rang] = b
            end
            b.pointId = point.id
            local n = Recoltes.Compte(point.id)
            b.label:SetText(n > 0 and string.format("%s  |cff9d9d9d(%d)|r", point.label, n) or point.label)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.liste.contenu, "TOPLEFT", 0, -y)
            b:Selectionner(point.id == self.pointId)
            b:Show()
            y = y + LIGNE
        end
        for rang = #definitions + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.liste:Regler(y)
        self.supprimer:SetEnabled(self:Point() ~= nil)

        local point = self:Point()
        p.titre:SetText(point and point.label or "Choisis un point de récolte à gauche")
        p.resume:SetText(point and Resume(point) or "")
        p.poser:SetEnabled(point ~= nil and point.recolte ~= nil)
        self:AfficherPoints()
    end

    function f:Montrer()
        local premier = Points.Nature("ressource")[1]
        if not self.travail then self:Choisir(premier and premier.id) end
        self:Onglet(self.onglet or "creation")
        self:Show()
    end

    UI.SuivrePersonnage(f, function(self) self:Afficher() end)
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

LCM.WhenReady(function()
    -- L'entree « Ressources » du menu ouvre cette fenetre. Posee apres
    -- MJ/PointsUI.lua, cette liaison remplace l'ancien editeur a offres.
    UI.Menu.Lier("ressources", function() Ecran.Basculer() end)
    Recoltes.onChange = function()
        local f = Ecran.frame
        if f and f:IsShown() then f:Afficher() end
    end
    local precedent = LCM.Brouillons.onSynchro
    LCM.Brouillons.onSynchro = function(famille, entree)
        if precedent then precedent(famille, entree) end
        if famille ~= "points" then return end
        local f = Ecran.frame
        if f and f:IsShown() then f:Afficher() end
    end
end)
