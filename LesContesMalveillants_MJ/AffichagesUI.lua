-- L'atelier « Affichage » du MJ (31 octobre 2026) : construire des panneaux,
-- puis les poser dans le monde. La meme fenetre que Coffres, Ressources et
-- Vendeurs (UI.AtelierInteractions) :
--   * CONFIGURATION — le nom du panneau, son support, et ses affiches (un
--     titre, un texte, une image chacune) ;
--   * PLACEMENT — on marche jusqu'au panneau, « Poser le panneau ici ».
local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI
local Points = LCM.Points
local Affichages = LCM.AffichagesMJ

local Ecran = {}
UI.AffichagesMJ = Ecran

local LARGEUR, HAUTEUR = 860, 660
local LIGNE = 36

local function Texte(v) return (tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function NouvelleAffiche() return { titre = "Nouvelle affiche", texte = "" } end

local function Construire()
    local f = UI.Fenetre("affichages_mj", "Affichage", LARGEUR, HAUTEUR, { x = 0, y = -20 },
        { enTeteSimple = true, sobre = true })
    f.onglet = "creation"

    -- ----- Bibliotheque ----------------------------------------------------
    f.liste = UI.Defilement(f.contenu)
    f.lignes = {}
    f.nouveau = UI.Bouton(f.contenu, "+ Nouveau", 100, 24, function() f:Nouveau() end)
    f.dupliquer = UI.Bouton(f.contenu, "Dupliquer", 206, 24, function() f:Dupliquer() end)
    f.supprimer = UI.Bouton(f.contenu, "Supprimer", 206, 24, function() f:Supprimer() end)
    f.confirmation = UI.Confirmer(f, "", "Confirmer")

    f.droite = CreateFrame("Frame", nil, f.contenu)
    f.boutonCreation = UI.Bouton(f.droite, "Configuration", 120, 24, function() f:Onglet("creation") end)
    f.boutonCreation:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, 0)
    f.boutonPlacement = UI.Bouton(f.droite, "Placement", 120, 24, function() f:Onglet("placement") end)
    f.boutonPlacement:SetPoint("LEFT", f.boutonCreation, "RIGHT", 6, 0)

    -- ----- CONFIGURATION ---------------------------------------------------
    local c = CreateFrame("Frame", nil, f.droite)
    f.creation = c
    local function Legende(texte, x, y)
        local fs = UI.Texte(c, texte, UI.C.discret, "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
        return fs
    end
    Legende("Nom du panneau", 0, 4)
    c.nom = UI.Champ(c, 360, 28, function(texte) if f.travail then f.travail.label = texte end end)
    c.nom:SetMaxLetters(80)
    c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -20)
    Legende("Support", 380, 4)
    c.support = UI.Deroulant(c, 200, 28, function()
        local options = {}
        for _, s in ipairs(LCM.Affichages.Supports()) do options[#options + 1] = { id = s.id, label = s.label } end
        return options
    end, function(id) if f.travail then f.travail.affichage.support = id end end)
    c.support:SetPoint("TOPLEFT", c, "TOPLEFT", 380, -20)

    Legende("Affiches", 0, 62)
    c.affiches = UI.Defilement(c)
    c.affiches:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -80)
    c.affiches:SetSize(180, 300)
    c.lignes = {}
    c.ajouter = UI.Bouton(c, "+ Affiche", 88, 24, function() f:AjouterAffiche() end)
    c.ajouter:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -388)
    c.retirer = UI.Bouton(c, "Retirer", 88, 24, function() f:RetirerAffiche() end)
    c.retirer:SetPoint("LEFT", c.ajouter, "RIGHT", 4, 0)

    -- L'affiche choisie.
    c.edition = CreateFrame("Frame", nil, c)
    c.edition:SetPoint("TOPLEFT", c, "TOPLEFT", 200, -62)
    c.edition:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 60)
    local e = c.edition
    local function LegendeE(texte, x, y)
        local fs = UI.Texte(e, texte, UI.C.discret, "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", e, "TOPLEFT", x, -y)
        return fs
    end
    LegendeE("Titre", 0, 0)
    e.titre = UI.Champ(e, 380, 26, function(texte)
        local a = f:Affiche()
        if a then a.titre = texte; f:AfficherListe() end
    end)
    e.titre:SetMaxLetters(80)
    e.titre:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -16)
    LegendeE("Image", 0, 52)
    e.apercuImage = e:CreateTexture(nil, "ARTWORK")
    e.apercuImage:SetSize(40, 40)
    e.apercuImage:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -68)
    e.image = UI.Bouton(e, "Choisir une image", 150, 24, function(self)
        Ecran.selecteur = Ecran.selecteur or UI.SelecteurIcone("affiche")
        Ecran.selecteur:Proposer(self, function(chemin)
            local a = f:Affiche()
            if a then a.image = chemin; f:AfficherAffiche() end
        end)
    end)
    e.image:SetPoint("TOPLEFT", e, "TOPLEFT", 50, -70)
    e.sansImage = UI.Bouton(e, "Sans image", 100, 24, function()
        local a = f:Affiche()
        if a then a.image = nil; f:AfficherAffiche() end
    end)
    e.sansImage:SetPoint("LEFT", e.image, "RIGHT", 6, 0)
    -- Une carte du compendium punaisee sur l'affiche : on la consulte sur le
    -- panneau (31 octobre 2026). Elle part avec le panneau, aplatie.
    LegendeE("Carte", 0, 108)
    e.carte = UI.Deroulant(e, 380, 24, function()
        local options = { { id = "__aucune", label = "Aucune carte" } }
        for _, carte in ipairs(LCM.Cartes and LCM.Cartes.list or {}) do
            options[#options + 1] = { id = carte.id, label = carte.label or carte.id }
        end
        return options
    end, function(id)
        local a = f:Affiche()
        if a then a.carte = id ~= "__aucune" and id or nil; f:AfficherAffiche() end
    end)
    e.carte:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -124)
    LegendeE("Fond de l'affiche", 0, 158)
    LegendeE("Écriture", 190, 158)
    local function Options(liste)
        local options = {}
        for _, item in ipairs(liste) do options[#options + 1] = { id = item.id, label = item.label } end
        return options
    end
    e.theme = UI.Deroulant(e, 180, 26, function() return Options(LCM.Affichages.Themes()) end,
        function(id)
            local a = f:Affiche()
            if a then a.theme = id; f:AfficherAffiche() end
        end)
    e.theme:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -174)
    e.police = UI.Deroulant(e, 190, 26, function()
        local options = Options(LCM.Affichages.Polices())
        table.insert(options, 1, { id = "auto", label = "Selon le thème" })
        return options
    end, function(id)
        local a = f:Affiche()
        if a then a.police = id ~= "auto" and id or nil; f:AfficherAffiche() end
    end)
    e.police:SetPoint("TOPLEFT", e, "TOPLEFT", 190, -174)
    LegendeE("Texte", 0, 210)
    e.texte = UI.Zone(e, 380, 120, function(texte)
        local a = f:Affiche()
        if a then a.texte = texte end
    end)
    e.texte.saisie:SetMaxLetters(tonumber(LCM.Equilibrage.affichages and LCM.Equilibrage.affichages.texteMax) or 2000)
    e.texte:SetPoint("TOPLEFT", e, "TOPLEFT", 0, -226)
    e.vide = UI.Texte(c, "Ce panneau n'a encore aucune affiche : « + Affiche » pour en punaiser une.",
        UI.C.discret, "GameFontNormalSmall")
    e.vide:SetPoint("TOPLEFT", c, "TOPLEFT", 200, -90)
    e.vide:SetWidth(380)

    c.erreur = UI.Texte(c, "", { 1, 0.4, 0.35 }, "GameFontNormalSmall")
    c.erreur:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 40)
    c.erreur:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 40)
    c.apercu = UI.Bouton(c, "Aperçu", 105, 28, function()
        if not f.travail then return end
        UI.Affichage.Ouvrir(nil, { id = f.travail.id, label = f.travail.label,
            support = f.travail.affichage.support, affiches = f.travail.affichage.affiches })
    end)
    c.apercu:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
    c.enregistrer = UI.Bouton(c, "Enregistrer le panneau", 164, 28, function() f:Enregistrer() end)
    c.enregistrer:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)

    -- ----- PLACEMENT -------------------------------------------------------
    local p = CreateFrame("Frame", nil, f.droite)
    f.placement = p
    p.titre = UI.Texte(p, "", UI.C.titre)
    UI.Police(p.titre, 14)
    p.position = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
    p.position:SetJustifyH("LEFT")
    p.poser = UI.Bouton(p, "Poser le panneau ici", 260, 34, function() f:Poser() end)
    p.compte = UI.Texte(p, "", UI.C.accent, "GameFontNormalSmall")
    p.toutRetirer = UI.Bouton(p, "Tout retirer", 110, 22, function() f:ToutRetirer() end)
    p.renvoyer = UI.Bouton(p, "Renvoyer à tous", 130, 22, function()
        local n = tonumber(Affichages.Renvoyer()) or 0
        if n == 0 then LCM.Alerte("rien à renvoyer : aucun panneau posé, ou personne à qui l'envoyer.") return end
        LCM.Ok(string.format("panneau(x) renvoyé(s) à tous : %d.", n))
    end)
    p.zone = UI.Defilement(p)
    p.lignes = {}
    p.vide = UI.Texte(p, "Aucun emplacement. Marche jusqu'au panneau et clique sur « Poser le panneau ici ».",
        UI.C.discret, "GameFontNormalSmall")
    p.vide:SetPoint("TOP", p.zone, "TOP", 0, -20)
    p.vide:SetWidth(380)
    p.vide:SetWordWrap(true)
    p.attente = 0
    p:SetScript("OnUpdate", function(self, dt)
        self.attente = self.attente + (dt or 0)
        if self.attente < 0.5 then return end
        self.attente = 0
        f:Position()
    end)

    -- ----- Gestes ------------------------------------------------------------
    function f:Point() return self.pointId and Points.Get(self.pointId) or nil end
    function f:Affiche()
        return self.travail and self.travail.affichage.affiches[self.selection or 0] or nil
    end

    function f:Onglet(onglet)
        self.onglet = onglet
        self.boutonCreation:Selectionner(onglet == "creation")
        self.boutonPlacement:Selectionner(onglet == "placement")
        self.creation:SetShown(onglet == "creation")
        self.placement:SetShown(onglet == "placement")
        self:Afficher()
    end

    -- La copie de travail du panneau choisi ; rien ne change avant
    -- « Enregistrer le panneau ».
    function f:Choisir(id)
        self.pointId = id
        local point = self:Point()
        self.travail = point and LCM.Copie(point) or nil
        if self.travail then
            self.travail.affichage = self.travail.affichage or { affiches = {} }
            self.travail.affichage.affiches = self.travail.affichage.affiches or {}
        end
        self.creationNeuve = false
        self.selection = self.travail and #self.travail.affichage.affiches > 0 and 1 or nil
        c.erreur:SetText("")
        self:Afficher()
    end

    function f:Nouveau()
        self.pointId = nil
        self.travail = { id = LCM.Brouillons.NouvelIdentifiant(), label = "Nouveau panneau",
            nature = "affichage", affichage = { support = (LCM.Affichages.Supports()[1] or {}).id,
                affiches = { NouvelleAffiche() } } }
        self.referenceTravail = nil
        self.creationNeuve = true
        self.selection = 1
        self:Onglet("creation")
    end

    function f:Dupliquer()
        local point = self:Point()
        if not point then LCM.Alerte("choisis d'abord le panneau à dupliquer.") return end
        self.travail = LCM.Copie(point)
        self.travail.id = LCM.Brouillons.NouvelIdentifiant()
        self.travail.label = Texte(point.label) .. " (copie)"
        self.pointId, self.creationNeuve, self.referenceTravail = nil, true, nil
        self.selection = #self.travail.affichage.affiches > 0 and 1 or nil
        self:Onglet("creation")
    end

    function f:Supprimer()
        local point = self:Point()
        if not point then return end
        self.confirmation:Demander(string.format("Supprimer le panneau « %s » ?", point.label), function()
            local ok, raison = LCM.Brouillons.Supprimer("points", point.id)
            if not ok then LCM.Alerte(tostring(raison)) return end
            self:Choisir(nil)
        end)
    end

    function f:AjouterAffiche()
        if not self.travail then return end
        local liste = self.travail.affichage.affiches
        local max = tonumber(LCM.Equilibrage.affichages and LCM.Equilibrage.affichages.maxAffiches) or 12
        if #liste >= max then c.erreur:SetText(max .. " affiches au plus sur un panneau.") return end
        liste[#liste + 1] = NouvelleAffiche()
        self.selection = #liste
        self:Afficher()
    end

    function f:RetirerAffiche()
        local liste = self.travail and self.travail.affichage.affiches
        if not liste or not liste[self.selection or 0] then return end
        table.remove(liste, self.selection)
        self.selection = #liste > 0 and math.min(self.selection, #liste) or nil
        self:Afficher()
    end

    function f:Enregistrer()
        if not self.travail then return false end
        if not Texte(self.travail.label):match("%S") then c.erreur:SetText("Donne un nom au panneau.") return false end
        local ok, raison = pcall(Points.Construire, self.travail)
        if not ok then
            c.erreur:SetText((tostring(raison):gsub("^LCM/Points : ", "")))
            return false
        end
        local fait, erreur = LCM.Brouillons.Enregistrer("points", self.travail, self.creationNeuve)
        if not fait then c.erreur:SetText(tostring(erreur)) return false end
        c.erreur:SetText("")
        LCM.Ok(string.format("Panneau « %s » enregistré.", self.travail.label))
        if Affichages.Compte(self.travail.id) > 0 then
            Affichages.Rafraichir(self.travail.id)
            Affichages.Diffuser(self.travail.id)
        end
        self:Choisir(self.travail.id)
        return true
    end

    function f:Poser()
        local point = self:Point()
        if not point then LCM.Alerte("choisis d'abord un panneau enregistré.") return end
        local id, raison = Affichages.Placer(point.id)
        if not id then LCM.Alerte(tostring(raison)) return end
        self:Afficher()
    end

    function f:ToutRetirer()
        local point = self:Point()
        if not point then return end
        local n = Affichages.Compte(point.id)
        if n == 0 then return end
        self.confirmation:Demander(string.format("Retirer les %d emplacement(s) de « %s » ?", n, point.label),
            function() Affichages.RetirerTout(point.id) self:Afficher() end)
    end

    function f:Position()
        local x, y, source, z = LCM.Recolte.Position3D()
        if x then
            local carte = LCM.Recolte.Carte()
            p.position:SetText(string.format("Tu es en %.1f, %.1f, %.1f  (%s%s)", x, y, z or 0, tostring(source),
                carte and (", carte " .. carte) or ""))
        else
            p.position:SetText("Position inconnue ici : le clic demandera « .gps ».")
        end
    end

    -- ----- Affichage de l'atelier --------------------------------------------
    function f:AfficherListe()
        local liste = self.travail and self.travail.affichage.affiches or {}
        for i, a in ipairs(liste) do
            local b = c.lignes[i]
            if not b then
                b = UI.Bouton(c.affiches.contenu, "", 172, 26, function(bouton)
                    f.selection = bouton.index
                    f:AfficherListe()
                    f:AfficherAffiche()
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
                b.label:SetJustifyH("LEFT")
                b.label:SetWordWrap(false)
                c.lignes[i] = b
            end
            b.index = i
            b.label:SetText(Texte(a.titre) ~= "" and a.titre or "(sans titre)")
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", c.affiches.contenu, "TOPLEFT", 0, -(i - 1) * 28)
            b:Selectionner(i == self.selection)
            b:Show()
        end
        for i = #liste + 1, #c.lignes do c.lignes[i]:Hide() end
        c.affiches:Regler(#liste * 28)
    end

    function f:AfficherAffiche()
        local a = self:Affiche()
        e:SetShown(a ~= nil)
        e.vide:SetShown(self.travail ~= nil and a == nil)
        c.retirer:SetEnabled(a ~= nil)
        if not a then return end
        e.titre:SetText(a.titre or "")
        e.apercuImage:SetShown(a.image ~= nil)
        if a.image then e.apercuImage:SetTexture(LCM.Icone(a.image)) end
        e.texte:SetText(a.texte or "")
        local theme = LCM.Affichages.Theme(a.theme)
        local police = LCM.Affichages.Police(a.police or theme.police)
        e.theme:Definir(theme.id, theme.label)
        e.police:Definir(a.police or "auto", a.police and police.label or "Selon le thème")
        e.texte.saisie:SetFont(police.chemin, 16 * (police.facteur or 1), "")
        local carte = a.carte and LCM.Cartes and LCM.Cartes.Get(a.carte)
        e.carte:Definir(a.carte or "__aucune", carte and carte.label
            or (a.carte and ("? " .. a.carte) or "Aucune carte"))
    end

    function f:AfficherPoints()
        local point = self:Point()
        local miens = point and Affichages.Points(point.id) or {}
        local liste = point and LCM.Poses.Composer("affichage", point.id, miens) or {}
        local h = 0
        for rang, pose in ipairs(liste) do
            local l = p.lignes[rang]
            if not l then
                l = CreateFrame("Frame", nil, p.zone.contenu)
                l:SetHeight(LIGNE - 2)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.texte = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
                l.texte:SetPoint("LEFT", l, "LEFT", 8, 0)
                l.texte:SetPoint("RIGHT", l, "RIGHT", -156, 0)
                l.texte:SetJustifyH("LEFT")
                l.retirer = UI.Bouton(l, "x", 24, 20, function(b)
                    Affichages.Retirer(b:GetParent().poseId)
                    f:Afficher()
                end)
                l.retirer:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                l.teleporter = UI.Bouton(l, "S'y téléporter", 112, 20, function(b)
                    local pose = b:GetParent().pose
                    local ok, raison
                    if pose and pose.autre then ok, raison = LCM.Poses.Teleporter(pose)
                    else ok, raison = Affichages.Teleporter(b:GetParent().poseId) end
                    if not ok then LCM.Alerte(tostring(raison)) end
                end)
                l.teleporter:SetPoint("RIGHT", l, "RIGHT", -34, 0)
                p.lignes[rang] = l
            end
            l.poseId, l.pose = pose.id, pose
            l.retirer:SetShown(not pose.autre)
            l.texte:SetText(LCM.Poses.Prefixe(pose) .. string.format("#%d   %.1f, %.1f, %s   (%s%s)",
                #liste - rang + 1, pose.x, pose.y, pose.z and string.format("%.1f", pose.z) or "Z ?",
                tostring(pose.source), pose.carte and (", carte " .. pose.carte) or ""))
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", p.zone.contenu, "TOPLEFT", 0, -h)
            l:SetPoint("TOPRIGHT", p.zone.contenu, "TOPRIGHT", 0, -h)
            l:Show()
            h = h + LIGNE
        end
        for rang = #liste + 1, #p.lignes do p.lignes[rang]:Hide() end
        p.zone:Regler(h)
        p.titre:SetText(point and point.label or "Choisis un panneau à gauche")
        p.vide:SetShown(point ~= nil and #liste == 0)
        p.compte:SetText(point and string.format("%d emplacement(s)", #liste) or "")
        p.poser:SetEnabled(point ~= nil)
        p.toutRetirer:SetEnabled(#miens > 0)
        self:Position()
    end

    function f:Afficher()
        local definitions = self:FiltrerDefinitions(Affichages.Definitions())
        if self.pointId and not Points.Get(self.pointId) then self.pointId = nil end
        if not self.pointId and not self.creationNeuve and definitions[1] then
            return self:Choisir(definitions[1].id)
        end
        for rang, point in ipairs(definitions) do
            local b = self.lignes[rang]
            if not b then
                b = UI.Bouton(self.liste.contenu, "", 186, LIGNE - 2, function(bouton)
                    f:ChangerModele(function() f:Choisir(bouton.pointId) end)
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetPoint("RIGHT", b, "RIGHT", -6, 0)
                b.label:SetJustifyH("LEFT")
                self.lignes[rang] = b
            end
            b.pointId = point.id
            local n = Affichages.Compte(point.id)
            b.label:SetText(n > 0 and string.format("%s  |cff9d9d9d(%d)|r", point.label, n) or point.label)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.liste.contenu, "TOPLEFT", 0, -(rang - 1) * LIGNE)
            b:Show()
        end
        for rang = #definitions + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.liste:Regler(#definitions * LIGNE)
        self.supprimer:SetEnabled(self:Point() ~= nil)

        local t = self.travail
        c.nom:SetText(t and t.label or "")
        local support = t and LCM.Affichages.Support(t.affichage.support)
        c.support:Definir(t and t.affichage.support or nil, support and support.label or "—")
        c.enregistrer:SetEnabled(t ~= nil)
        c.apercu:SetEnabled(t ~= nil)
        c.ajouter:SetEnabled(t ~= nil)
        self:AfficherListe()
        self:AfficherAffiche()
        self:AfficherPoints()
    end

    function f:Montrer()
        self:Onglet(self.onglet or "creation")
        self:Show()
    end

    UI.AtelierInteractions(f, "affichage")
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
    UI.Menu.Lier("affichage", function() Ecran.Basculer() end)
    Affichages.onChange = function()
        local f = Ecran.frame
        if f and f:IsShown() then f:Afficher() end
    end
end)
