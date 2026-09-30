-- La fenetre Inventaires.
--
-- Reprise de la fenetre « Inventaires » du template : une categorie « Sacs »
-- en vue grille, une carte par sac (Inventory.lua : cartes de 112 de haut,
-- colonnes d'environ 180, 8 d'ecart ; icone de 36 centree en haut, nom et
-- description centres dessous, boutons en bas).
--
-- Ce qu'on range dans les sacs (les placements) viendra ensuite : ici, on
-- pose et retire les sacs eux-memes. Geste de MJ, comme l'equipement.

local _, LCM = ...
local UI = LCM.UI
local Sacs = LCM.Sacs

local Ecran = {}
UI.Inventaires = Ecran

local LARGEUR, HAUTEUR = 600, 560
local CARTE_H, ECART, COLONNE_MIN = 112, 8, 180

local function Carte(parent, f)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(CARTE_H)
    if UI.SurfaceLigne then UI.SurfaceLigne(c) end
    c.icone = c:CreateTexture(nil, "ARTWORK")
    c.icone:SetSize(36, 36)
    c.icone:SetPoint("TOP", c, "TOP", 0, -10)
    c.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if UI.AelCadre then
        local support = CreateFrame("Frame", nil, c)
        support:SetPoint("TOPLEFT", c.icone, "TOPLEFT", -2, 2)
        support:SetPoint("BOTTOMRIGHT", c.icone, "BOTTOMRIGHT", 2, -2)
        c.cadreIcone = UI.AelCadre(support, "icone")
    end
    c.nom = UI.Texte(c, "", UI.C.titre)
    UI.Police(c.nom, 13)
    c.nom:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -52)
    c.nom:SetPoint("TOPRIGHT", c, "TOPRIGHT", -8, -52)
    c.nom:SetJustifyH("CENTER")
    c.nom:SetWordWrap(false)
    c.description = UI.Texte(c, "", UI.C.discret)
    UI.Police(c.description, 11)
    c.description:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -2)
    c.description:SetPoint("TOPRIGHT", c.nom, "BOTTOMRIGHT", 0, -2)
    c.description:SetJustifyH("CENTER")
    c.description:SetWordWrap(false)
    -- Une carte porte son rang dans la liste des sacs (plusieurs sacs peuvent
    -- etre identiques : c'est le rang qui designe celui qu'on retire).
    c.action = UI.Bouton(c, "", 90, 22, function()
        if c.ajout then f:Proposer(c.action) else f:Retirer(c.sacId) end
    end)
    c.action:SetPoint("BOTTOM", c, "BOTTOM", 0, 8)
    return c
end

local function Construire()
    local f = UI.Fenetre("inventaires", "Inventaires", LARGEUR, HAUTEUR, { x = 240, y = 20 })
    Ecran.frame = f
    f.nom = f.sousTitre
    local largeurContenu = LARGEUR - 24

    -- Une seule categorie, comme le template : « Sacs ».
    f.barre = UI.BandeauOnglets(f.contenu, { { id = "sacs", label = "Sacs" } }, function() end)
    f.barre:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.barre:SetWidth(largeurContenu)
    local haut = f.barre:Disposer(largeurContenu, f.mesures.onglet) + 10

    f.occupation = UI.Texte(f.contenu, "", UI.C.titre)
    UI.Police(f.occupation, 13)
    f.occupation:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", -4, -haut)
    haut = haut + 22

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -haut)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.cartes = {}
    f.choix = UI.Choix("inventaires", "Sacs")
    f:HookScript("OnHide", function() f.choix:Hide() end)

    local colonnes = math.max(1, math.floor((largeurContenu + ECART) / COLONNE_MIN))
    local largeurCarte = math.floor((largeurContenu - (colonnes - 1) * ECART) / colonnes)

    function f:Afficher()
        local mj = LCM.IsMaster()
        local portes = Sacs.Ids(self.entity, "sac")
        local places = Sacs.Capacite("sac")
        self.occupation:SetText(string.format("%d / %d sacs", #portes, places))
        -- Les sacs portes, puis une carte d'ajout pour le MJ s'il reste de la
        -- place (comme une case libre d'un conteneur).
        local n = #portes + ((mj and #portes < places) and 1 or 0)
        for index = 1, n do
            local c = self.cartes[index]
            if not c then
                c = Carte(self.zone.contenu, self)
                self.cartes[index] = c
            end
            local col, rang = (index - 1) % colonnes, math.floor((index - 1) / colonnes)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", col * (largeurCarte + ECART), -rang * (CARTE_H + ECART))
            c:SetWidth(largeurCarte)
            local id = portes[index]
            c.sacId, c.ajout = id, id == nil
            if id then
                local sac = Sacs.Get(id)
                c.icone:SetTexture(sac and sac.icone or "Interface\\Icons\\INV_Misc_QuestionMark")
                c.icone:SetDesaturated(false)
                c.nom:SetText(sac and sac.label or ("? " .. tostring(id)))
                c.description:SetText(sac and string.format("%d places", sac.places) or "N'existe pas dans cette version.")
                c.action.label:SetText("Retirer")
                c.action:SetShown(mj)
            else
                c.icone:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
                c.icone:SetDesaturated(true)
                c.nom:SetText("Emplacement de sac")
                c.description:SetText("Disponible")
                c.action.label:SetText("+  Ajouter")
                c.action:Show()
            end
            c:Show()
        end
        for index = n + 1, #self.cartes do self.cartes[index]:Hide() end
        local rangs = math.max(1, math.ceil(n / colonnes))
        self.zone:Regler(rangs * (CARTE_H + ECART) - ECART)
    end

    function f:Proposer(ancre)
        if not LCM.IsMaster() then return end
        local options = {}
        for _, sac in ipairs(Sacs.Candidats(self.entity, "sac")) do
            options[#options + 1] = { id = sac.id, label = string.format("%s  (%d places)", sac.label, sac.places) }
        end
        if #options == 0 then
            LCM.Alerte("aucun sac a ajouter.")
            return
        end
        table.sort(options, function(a, b) return a.label:lower() < b.label:lower() end)
        self.choix:Proposer(ancre, options, function(id)
            local ok, raison = Sacs.Placer(self.entity, id)
            if not ok then LCM.Alerte(raison) end
            self:Afficher()
        end)
    end

    -- Retirer se rattrape (on repose le sac) : pas de confirmation. Quand les
    -- placements existeront, un sac plein demandera confirmation.
    function f:Retirer(id)
        if not LCM.IsMaster() then return end
        if Sacs.Enlever(self.entity, id) then self:Afficher() end
    end

    function f:Montrer(entity)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self:SousTitre(self.entity.name or self.entity.id)
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

LCM.WhenReady(function()
    UI.Menu.Lier("inventaires", Ecran.Basculer)
end)
