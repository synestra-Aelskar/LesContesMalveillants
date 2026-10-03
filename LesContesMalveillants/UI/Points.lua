-- Vendeurs et points de recolte.
--
-- Deux entrees de menu, une seule fenetre : « Vendeur » et « Ressources » ne
-- different que par ce qu'on y lit et par le prix. Une liste des points connus
-- a gauche, les offres du point choisi a droite.
--
-- Le stock affiche est celui qu'on connait, et on le DEMANDE en ouvrant : ce
-- qui a ete ramasse pendant qu'on n'etait pas la ne se devine pas.

local _, LCM = ...
local UI = LCM.UI
local Points = LCM.Points

local Ecran = { frames = {} }
UI.Points = Ecran

local LARGEUR, HAUTEUR = 560, 420
local COLONNE = 200
local LIGNE = 28

local MOTS = {
    vendeur   = { titre = "Vendeur",    action = "Acheter",  vide = "Aucun vendeur connu." },
    ressource = { titre = "Ressources", action = "Récolter", vide = "Aucun point de récolte connu." },
}

local function Construire(nature)
    local mots = MOTS[nature]
    local f = UI.Fenetre("points_" .. nature, mots.titre, LARGEUR, HAUTEUR,
        { x = nature == "vendeur" and -80 or 100, y = -40 })
    f.nature = nature

    -- ----- les points -----------------------------------------------------
    f.liste = UI.Defilement(f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.liste:SetWidth(COLONNE)
    f.lignes = {}

    -- ----- les offres -----------------------------------------------------
    f.droite = CreateFrame("Frame", nil, f.contenu)
    f.droite:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", COLONNE + 12, 0)
    f.droite:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.description = UI.Texte(f.droite, "", UI.C.discret)
    UI.Police(f.description, 11)
    f.description:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, 0)
    f.description:SetPoint("TOPRIGHT", f.droite, "TOPRIGHT", 0, 0)
    f.description:SetJustifyH("LEFT")
    f.description:SetWordWrap(true)

    f.zone = UI.Defilement(f.droite)
    f.zone:SetPoint("TOPLEFT", f.droite, "TOPLEFT", 0, -30)
    f.zone:SetPoint("BOTTOMRIGHT", f.droite, "BOTTOMRIGHT", 0, 0)
    f.offres = {}

    f.vide = UI.Texte(f.droite, "", UI.C.discret)
    UI.Police(f.vide, 11)
    f.vide:SetPoint("CENTER", f.zone, "CENTER", 0, 0)
    f.vide:SetJustifyH("CENTER")

    function f:Point()
        return self.pointId and Points.Get(self.pointId) or Points.Nature(self.nature)[1]
    end

    function f:Choisir(id)
        self.pointId = id
        local point = self:Point()
        for _, b in ipairs(self.lignes) do b:Selectionner(b.pointId == id) end
        self.description:SetText(point and tostring(point.description or "") or "")
        -- Ce qui s'est passe pendant notre absence ne se devine pas : on demande.
        if point then
            for _, offre in ipairs(point.offres) do
                if offre.stock.limite > 0 then LCM.Stock.Demander(offre.cle) end
            end
        end
        self:Afficher()
    end

    function f:Afficher()
        -- La colonne des points.
        local points = Points.Nature(self.nature)
        local y = 0
        for rang, point in ipairs(points) do
            local b = self.lignes[rang]
            if not b then
                b = UI.Bouton(self.liste.contenu, "", COLONNE - 10, LIGNE - 4, function()
                    self:Choisir(self.lignes[rang].pointId)
                end)
                b.label:ClearAllPoints()
                b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
                b.label:SetJustifyH("LEFT")
                self.lignes[rang] = b
            end
            b.pointId = point.id
            b.label:SetText(point.label)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self.liste.contenu, "TOPLEFT", 0, -y)
            b:Selectionner(point.id == self.pointId)
            b:Show()
            y = y + LIGNE
        end
        for rang = #points + 1, #self.lignes do self.lignes[rang]:Hide() end
        self.liste:Regler(y)

        -- Les offres du point choisi.
        local point = self:Point()
        y = 0
        local nombre = 0
        for rang, offre in ipairs(point and point.offres or {}) do
            local l = self.offres[rang]
            if not l then
                l = CreateFrame("Frame", nil, self.zone.contenu)
                l:SetHeight(LIGNE)
                if UI.SurfaceLigne then UI.SurfaceLigne(l) end
                l.icone = l:CreateTexture(nil, "ARTWORK")
                l.icone:SetSize(20, 20)
                l.icone:SetPoint("LEFT", l, "LEFT", 4, 0)
                l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                l.nom = UI.Texte(l, "", UI.C.texte)
                UI.Police(l.nom, 11)
                l.nom:SetPoint("LEFT", l.icone, "RIGHT", 6, 0)
                l.stock = UI.Texte(l, "", UI.C.discret)
                UI.Police(l.stock, 10)
                l.stock:SetPoint("RIGHT", l, "RIGHT", -96, 0)
                l.prendre = UI.Bouton(l, mots.action, 84, 20, function()
                    local ligne = self.offres[rang]
                    local ok, raison = Points.Prendre(LCM.Entities.Self(), self.pointId or (point and point.id), ligne.offreId)
                    if not ok then LCM.Alerte(tostring(raison)) self:Afficher() return end
                    LCM.Ok(string.format("%s : %s x%d.", mots.action,
                        Points.Libelle(raison), raison.quantite))
                    self:Afficher()
                end)
                l.prendre:SetPoint("RIGHT", l, "RIGHT", -4, 0)
                self.offres[rang] = l
            end
            l.offreId = offre.id
            l.icone:SetTexture(Points.Icone(offre))
            local nom = Points.Libelle(offre)
            if offre.quantite > 1 then nom = nom .. "  x" .. offre.quantite end
            if offre.prix then
                -- Le libelle de la devise, pas son identifiant : « 5 Écus »,
                -- pas « 5 ecus ».
                local devise = offre.devise and LCM.Devises.Get(offre.devise)
                nom = string.format("%s   |cffffd36b%s %s|r", nom, tostring(offre.prix),
                    (devise and devise.label) or tostring(offre.devise or ""))
            end
            l.nom:SetText(nom)

            if offre.stock.limite > 0 then
                local restant = LCM.Stock.Restant(offre.cle)
                l.stock:SetText(string.format("%d / %d", restant, offre.stock.limite))
                local couleur = restant == 0 and UI.C.plein or (restant < offre.stock.limite and UI.C.accent or UI.C.discret)
                l.stock:SetTextColor(couleur[1], couleur[2], couleur[3])
                l.prendre:SetEnabled(restant > 0)
            else
                l.stock:SetText("")
                l.prendre:SetEnabled(true)
            end

            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE + 2
            nombre = rang
        end
        for rang = nombre + 1, #self.offres do self.offres[rang]:Hide() end
        self.zone:Regler(y)
        self.nombreAffiche = nombre
        self.vide:SetText(#points > 0 and "" or mots.vide)
    end

    function f:Montrer()
        self:Choisir(self.pointId or (Points.Nature(self.nature)[1] or {}).id)
        self:Show()
    end

    -- Le personnage change (equipement, sac, trait...) : la fenetre suit.
    UI.SuivrePersonnage(f, function(self) self:Afficher() end)
    return f
end

function Ecran.Fenetre(nature)
    if not Ecran.frames[nature] then Ecran.frames[nature] = Construire(nature) end
    return Ecran.frames[nature]
end

function Ecran.Basculer(nature)
    local f = Ecran.Fenetre(nature)
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.AddCommand("vendeur", "ouvre les vendeurs", function() Ecran.Basculer("vendeur") end)
LCM.AddCommand("ressources", "ouvre les points de recolte", function() Ecran.Basculer("ressource") end)

LCM.WhenReady(function()
    UI.Menu.Lier("vendeur", function() Ecran.Basculer("vendeur") end)
    UI.Menu.Lier("ressources", function() Ecran.Basculer("ressource") end)
    -- Un stock qui bouge ailleurs se voit ici sans qu'on rouvre la fenetre.
    LCM.Stock.onChange = function()
        for _, f in pairs(Ecran.frames) do
            if f:IsShown() then f:Afficher() end
        end
    end
end)
