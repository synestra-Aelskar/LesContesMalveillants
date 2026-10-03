-- Les fenetres tirees de la fiche (declarees dans Data/Vues.lua) : la Fiche
-- elle-meme, Sante, Expertises, Penetration & Resistances...
--
-- Une fenetre par vue, construite au premier clic et gardee ensuite. Une vue a
-- plusieurs onglets recoit la bande d'onglets du modele ; chaque onglet est une
-- page (UI.Fiche.Page) dans une zone qui defile et rogne.
--
-- Elle montre le personnage joue, relu a chaque ouverture : changer de
-- personnage puis rouvrir ne laisse pas l'ancien a l'ecran.

local _, LCM = ...
local UI = LCM.UI

local Ecran = { frames = {} }
UI.Vues = Ecran

-- Decalage de la premiere ouverture, pour que deux vues ne naissent pas l'une
-- sur l'autre (la position est ensuite retenue par fenetre).
local DECALAGE = 28

local LARGEUR_SOMMAIRE = 162
local LIGNE_SOMMAIRE = 20

-- ===== Le sommaire =========================================================
-- Les chapitres (les onglets de la vue) toujours visibles ; sous le chapitre
-- ouvert, ses sous-chapitres, qui sont les titres de blocs de la page. Cliquer
-- un sous-chapitre fait defiler jusqu'a son bloc.
--
-- Seul le chapitre ouvert deplie ses sous-chapitres : huit chapitres de cinq
-- blocs feraient quarante lignes, et une table des matieres qu'on doit faire
-- defiler pour s'y retrouver ne sert plus a rien.
local function Sommaire(f, vue)
    local s = UI.Defilement(f.contenu)
    s:SetWidth(LARGEUR_SOMMAIRE)
    s.entrees = {}

    local function Entree(rang)
        local b = s.entrees[rang]
        if b then return b end
        b = UI.Bouton(s.contenu, "", LARGEUR_SOMMAIRE, LIGNE_SOMMAIRE, function(self)
            f:Afficher(self.ongletId)
            -- Un chapitre repart du haut ; un sous-chapitre va se montrer.
            f.zone:Aller(self.cible or 0)
        end)
        b.label:ClearAllPoints()
        b.label:SetJustifyH("LEFT")
        b.label:SetWordWrap(false)

        -- La puce : allumee sur l'endroit ou l'on se trouve, eteinte ailleurs.
        -- Sans elle, deux lignes a peine differemment teintees ne disent pas
        -- ou on en est — et c'est tout ce qu'un sommaire a a dire.
        --
        -- C'est la gemme de l'atlas, celle qui coiffe les titres de bloc, et
        -- pas un losange tape au clavier : la police du jeu n'a pas ce signe et
        -- l'affichait en carre vide. Sans atlas (habillage Incritas), on
        -- retombe sur un chevron, qui lui existe partout.
        if UI.AelRef then
            b.puce = UI.AelRef(b, 501, 656, 27, 25, "OVERLAY")
            b.puce:SetSize(7, 7)
            function b:Marque(etat)
                self.marque = etat
                self.puce:SetShown(etat ~= "")
                self.puce:SetAlpha(etat == "ici" and 1 or 0.45)
            end
        else
            b.puce = UI.Texte(b, "", UI.C.accent)
            b.puce:SetJustifyH("CENTER")
            UI.Police(b.puce, 10)
            function b:Marque(etat)
                self.marque = etat
                self.puce:SetText(etat == "ici" and ">" or "")
            end
        end
        s.entrees[rang] = b
        return b
    end

    -- Marque l'endroit ou l'on se trouve : le chapitre ouvert, et parmi ses
    -- sous-chapitres le dernier qu'on ait depasse en descendant.
    function s:Marquer(decalage)
        decalage = tonumber(decalage) or (f.zone and f.zone.decalage) or 0
        local courant
        for _, b in ipairs(self.entrees) do
            if b:IsShown() and b.ongletId == f.onglet and b.cible <= decalage + 2 then
                if not courant or b.cible >= courant.cible then courant = b end
            end
        end
        for _, b in ipairs(self.entrees) do
            if b:IsShown() then
                local ici = (b == courant)
                b:Marque(ici and "ici" or (b.chapitre and "chapitre" or ""))
                local teinte = ici and UI.C.titre or (b.chapitre and UI.C.texte or UI.C.discret)
                b.label:SetTextColor(teinte[1], teinte[2], teinte[3])
                b:Selectionner(ici)
            end
        end
    end

    function s:Actualiser()
        local y, rang = 0, 0
        for _, onglet in ipairs(vue.onglets) do
            rang = rang + 1
            local b = Entree(rang)
            b.ongletId, b.cible, b.chapitre = onglet.id, 0, true
            b.label:SetText(onglet.label)
            b.label:SetPoint("LEFT", b, "LEFT", 18, 0)
            b.label:SetWidth(LARGEUR_SOMMAIRE - 24)
            UI.Police(b.label, 12)
            b.puce:SetPoint("LEFT", b, "LEFT", 5, 0)
            UI.Police(b.puce, 10)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", 0, -y)
            b:Show()
            y = y + LIGNE_SOMMAIRE

            -- Un seul bloc dans la page (une famille des Statistiques) : il
            -- n'y a nulle part ou aller, et son titre redirait le chapitre.
            local page = f.pages[onglet.id]
            local blocs = (page and page.blocs) or {}
            if onglet.id == f.onglet and #blocs > 1 then
                for _, bloc in ipairs(blocs) do
                    local titre = bloc.section and tostring(bloc.section.label or "")
                    if titre and titre ~= "" then
                        rang = rang + 1
                        local sb = Entree(rang)
                        sb.ongletId, sb.chapitre = onglet.id, false
                        -- La place du bloc dans la page : page:Disposer l'y a
                        -- ancre a -y, c'est exactement le defilement a poser.
                        local _, _, _, _, dy = bloc:GetPoint(1)
                        sb.cible = math.max(0, -(dy or 0))
                        sb.label:SetText(titre)
                        sb.label:SetPoint("LEFT", sb, "LEFT", 30, 0)
                        sb.label:SetWidth(LARGEUR_SOMMAIRE - 34)
                        UI.Police(sb.label, 10)
                        sb.puce:SetPoint("LEFT", sb, "LEFT", 17, 0)
                        UI.Police(sb.puce, 10)
                        sb:ClearAllPoints()
                        sb:SetPoint("TOPLEFT", self.contenu, "TOPLEFT", 0, -y)
                        sb:Show()
                        y = y + LIGNE_SOMMAIRE - 2
                    end
                end
            end
        end
        for index = rang + 1, #self.entrees do self.entrees[index]:Hide() end
        self:Regler(y)
        self:Marquer()
    end

    return s
end

local function Construire(vue, rang)
    local f = UI.Fenetre("vue_" .. vue.id, vue.titre, vue.largeur, vue.hauteur,
        { x = 180 + rang * DECALAGE, y = -rang * DECALAGE },
        { redimensionnable = true })
    f.vue = vue
    f.nom = f.sousTitre
    -- Une hauteur deja retenue en sauvegarde est un choix du joueur : on ne la
    -- recalcule pas sous ses yeux a la premiere ouverture.
    local memoire = LCM.db and LCM.db.fenetres and LCM.db.fenetres["vue_" .. vue.id]
    f.hauteurChoisie = type(memoire) == "table" and tonumber(memoire.hauteur) ~= nil or nil
    local largeurContenu = vue.largeur - 24

    -- Le canal des jets, en haut a droite comme dans le modele. Il ne regarde
    -- que les vues qui montrent un personnage : sur les Regles, il n'y a rien
    -- a lancer.
    local haut = 0
    if not vue.sansPersonnage then
        -- Une pastille dans l'EN-TETE, a gauche, en miroir de la croix de
        -- fermeture : meme taille, meme retrait du coin. Elle est ainsi sur la
        -- ligne du titre, et ne prend rien au contenu.
        f.canal = UI.Bouton(f, "", 20, 20, function(self)
            local options = {}
            for _, canal in ipairs(LCM.Canal.LISTE) do
                options[#options + 1] = { id = canal.id, label = canal.label }
            end
            f.canalMenu:Proposer(self, options, function(choix)
                LCM.Canal.Choisir(choix)
                f:ActualiserCanal()
            end)
        end)
        f.canal:SetSize(f.fermer:GetWidth(), f.fermer:GetHeight())
        -- La fenetre place elle-meme ses deux coins hauts, en miroir et apres
        -- l'ornement d'angle : on lui confie la pastille.
        f.coinGauche = f.canal
        f:PlacerCoinsHaut()
        -- Au-dessus de l'habillage, comme la croix : l'ornement du coin passait
        -- sinon par-dessus.
        f.canal:SetFrameLevel(f:GetFrameLevel() + 6)
        f.canalMenu = UI.Choix("canal_" .. vue.id, "Canal des jets")

        function f:ActualiserCanal()
            local canal = LCM.Canal.Actuel()
            self.canal.label:SetText(canal.lettre or "?")
            -- Sa couleur, sauf s'il n'est pas disponible (pas de groupe, pas de
            -- raid) : rouge, pour qu'on ne lance pas dans le vide sans le voir.
            local teinte = LCM.Canal.Disponible(canal) and (canal.couleur or UI.C.titre) or UI.C.plein
            self.canal.label:SetTextColor(teinte[1], teinte[2], teinte[3])
            UI.Bulle(self.canal, "Canal des jets", canal.label)
        end
        f:ActualiserCanal()
    end

    -- Une vue en sommaire (les Regles) range ses chapitres a gauche plutot que
    -- dans une bande d'onglets : huit onglets etales sur trois rangees au-dessus
    -- d'un texte, c'est un livre dont la table des matieres serait au milieu de
    -- la page. La colonne prend de la largeur au contenu.
    -- 11 = la barre de defilement du sommaire (posee a +3, large de 6) et deux
    -- pixels d'air. Ajouter une marge en plus creusait un couloir vide entre la
    -- table des matieres et le texte.
    local gauche = vue.sommaire and (LARGEUR_SOMMAIRE + 11) or 0
    local largeurPage = largeurContenu - gauche

    if vue.sommaire then
        f.sommaire = Sommaire(f, vue)
        f.sommaire:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -haut)
        f.sommaire:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    elseif #vue.onglets > 1 then
        local onglets = {}
        for _, onglet in ipairs(vue.onglets) do onglets[#onglets + 1] = { id = onglet.id, label = onglet.label } end
        f.barre = UI.BandeauOnglets(f.contenu, onglets, function(id) f:Afficher(id) end)
        f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -haut)
        f.barre:SetWidth(largeurContenu)
        haut = haut + f.barre:Disposer(largeurContenu, f.mesures.onglet) + 6
    end

    f.zone = UI.Defilement(f.contenu)
    f.hautZone = haut
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", gauche, -haut)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    if f.sommaire then
        f.zone.onDefilement = function(decalage) f.sommaire:Marquer(decalage) end
    end

    f.pages = {}
    for _, onglet in ipairs(vue.onglets) do
        local page = UI.Fiche.Page(f.zone.contenu, onglet.sections, largeurPage)
        page.onHauteur = function(h) if page:IsShown() then f.zone:Regler(h) end end
        f.pages[onglet.id] = page
    end
    -- Une vue simple : sa page unique, sous le nom qu'on lui a toujours donne.
    f.page = f.pages[vue.onglets[1].id]

    function f:Afficher(ongletId)
        self.onglet = ongletId
        if self.barre then self.barre:Selectionner(ongletId) end
        for id, page in pairs(self.pages) do page:SetShown(id == ongletId) end
        local page = self.pages[ongletId]
        if page then
            if self.entity then page:Actualiser(self.entity) end
            self.zone.decalage = 0
            self.zone:Regler(page.hauteur)
        end
        -- Apres la page : le sommaire lit la place des blocs, qui n'est connue
        -- qu'une fois la page disposee.
        if self.sommaire then self.sommaire:Actualiser() end
        self:AjusterHauteur()
    end

    -- La fenetre prend la hauteur de son contenu : on ne fait pas defiler une
    -- fiche, on la lit. Elle s'arrete a 85 % de l'ecran — au-dela, le
    -- defilement reprend son role, c'est pour ca qu'il reste.
    --
    -- Des que le joueur a tire la poignee, c'est SA hauteur qui vaut : on ne
    -- vient pas corriger derriere lui a chaque changement d'onglet.
    function f:AjusterHauteur()
        if vue.sommaire or self.hauteurChoisie then return end
        local page = self.onglet and self.pages[self.onglet]
        if not page then return end
        -- Ce que l'habillage prend, plus ce qui est pose au-dessus de la zone
        -- (pastille de canal, bande d'onglets). Calcule, pas mesure : les
        -- hauteurs d'ancrage ne sont pas lisibles partout.
        local chrome = (self.insetHaut or 0) + (self.insetBas or 0) + (self.hautZone or 0)
        local voulue = chrome + page.hauteur
        local plafond = (UIParent and UIParent:GetHeight() or 1080) * 0.85
        self:SetHeight(math.max(160, math.min(voulue, plafond)))
        self.zone:Regler(page.hauteur)
    end

    function f:Montrer(entity)
        if vue.sansPersonnage then
            self:Afficher(self.onglet or vue.onglets[1].id)
            self:Show()
            return
        end
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self:SousTitre(self.entity.name or self.entity.id)
        if self.ActualiserCanal then self:ActualiserCanal() end
        self:Afficher(self.onglet or vue.onglets[1].id)
        self:Show()
    end

    function f:Actualiser()
        local page = self.onglet and self.pages[self.onglet]
        if self.entity and page then page:Actualiser(self.entity) end
    end

    -- Une vue qu'on lit se tire aux dimensions qu'on veut : un chapitre de
    -- regles n'a pas de raison de tenir dans la fenetre que j'ai choisie.
    -- Reserve au texte : les pages de fiche gardent les colonnes du depart
    -- (voir page:Largeur), les etirer ferait mentir leurs mesures.
    -- Une vue de fiche se tire en HAUTEUR seulement : ses colonnes sont
    -- calculees a la construction et ne sauraient pas suivre un elargissement
    -- (voir page:Largeur). Tirer vers le haut rend le defilement a ce qui
    -- depasse ; c'est a ca qu'il sert une fois la hauteur automatique en place.
    -- Un sommaire devant des lignes de fiche (les Statistiques) suit la meme
    -- regle : seule une vue de pur texte (les Regles) s'elargit.
    local texteSeul = true
    for _, page in pairs(f.pages) do
        if #page.lignes > 0 then texteSeul = false end
    end

    if not texteSeul then
        UI.Redimensionner(f, vue.largeur, 160, function()
            f.hauteurChoisie = true
            local page = f.onglet and f.pages[f.onglet]
            if page then f.zone:Regler(page.hauteur) end
        end, vue.largeur)
    end

    if texteSeul then
        UI.Redimensionner(f, 420, 320, function()
            local l = f.contenu:GetWidth() - gauche
            for _, page in pairs(f.pages) do page:Largeur(l) end
            local page = f.onglet and f.pages[f.onglet]
            if page then f.zone:Regler(page.hauteur) end
            if f.sommaire then f.sommaire:Actualiser() end
        end)
    end
    return f
end

function Ecran.Fenetre(id)
    local vue = LCM.Vues.Get(id)
    if not vue then return nil end
    if not Ecran.frames[vue.id] then
        local rang = 0
        for index, v in ipairs(LCM.Vues.list) do
            if v.id == vue.id then rang = index - 1 end
        end
        Ecran.frames[vue.id] = Construire(vue, rang)
    end
    return Ecran.frames[vue.id]
end

function Ecran.Basculer(id)
    local f = Ecran.Fenetre(id)
    if not f then return nil end
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

-- Remet a jour toutes les vues OUVERTES. Une vue fermee se reconstruit a
-- l'ouverture : la rafraichir ne servirait qu'a payer le calcul deux fois.
function Ecran.Rafraichir()
    for _, f in pairs(Ecran.frames) do
        if f:IsShown() and f.Actualiser then f:Actualiser() end
    end
end

-- Le personnage change (une action vient de prelever des PA, le MJ ajuste une
-- jauge, un trait tombe) : ce qui est affiche suit, immediatement. Avant, il
-- fallait fermer la fiche et la rouvrir pour voir ses propres PA descendre.
LCM.WhenReady(function()
    LCM.Entities.onChange = function(entity)
        -- Une fiche montre UN personnage : celle qui regarde quelqu'un d'autre
        -- n'a aucune raison de se recalculer.
        for _, f in pairs(Ecran.frames) do
            if f:IsShown() and f.Actualiser and (f.entity == nil or f.entity == entity) then
                f:Actualiser()
            end
        end
    end
end)

-- Chaque vue allume l'entree du menu du meme nom. Une vue sans entree est une
-- faute d'ecriture : Menu.Lier la signale.
LCM.WhenReady(function()
    for _, vue in ipairs(LCM.Vues.list) do
        local id = vue.id
        UI.Menu.Lier(id, function() Ecran.Basculer(id) end)
    end
end)
