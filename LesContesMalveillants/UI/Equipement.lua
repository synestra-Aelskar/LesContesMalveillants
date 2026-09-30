-- La fenetre d'equipement.
--
-- Trois groupes, un par categorie (Arme, Equipement, Accessoire), chacun avec
-- son nombre d'emplacements (Equilibrage.emplacements). Un objet equipe est une
-- carte, comme un trait dans la fiche : description et effets.
--
-- Equiper et retirer sont des gestes de MJ tant qu'il n'y a pas d'inventaire :
-- sans lui, le joueur pourrait s'equiper de n'importe quel objet existant.
-- Le joueur, lui, voit ce qu'il porte.

local _, LCM = ...
local UI = LCM.UI
local Objets = LCM.Objets

local Ecran = {}
UI.Equipement = Ecran

local LARGEUR, HAUTEUR = 540, 620

-- ===== Un groupe (une categorie) ===========================================

local function Groupe(f, parent, categorie)
    local g = { categorie = categorie, cartes = {} }

    g.entete = UI.EnTeteGroupe(parent, categorie.label:upper())
    g.ajouter = UI.Bouton(parent, "+  Équiper", 90, 18, function() f:Proposer(g) end)
    g.vide = UI.Texte(parent, "Aucun.", UI.C.discret, "GameFontNormalSmall")

    -- Pose le groupe a partir de `y` et renvoie le `y` suivant.
    function g:Disposer(entity, y, mj)
        local ids = Objets.Ids(entity, categorie.id)
        local places = Objets.Emplacements(categorie.id)

        self.entete:ClearAllPoints()
        self.entete:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        self.entete:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -100, -y)
        -- Occupe / total. Au-dessus du total (emplacements reduits apres coup),
        -- le chiffre passe au rouge : rien n'est retire en douce.
        self.entete.budget:SetText(string.format("%d / %d", #ids, places))
        local couleur = (#ids > places) and UI.C.plein or ((#ids == places) and UI.C.discret or UI.C.titre)
        self.entete.budget:SetTextColor(couleur[1], couleur[2], couleur[3])

        self.ajouter:ClearAllPoints()
        self.ajouter:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y + 1)
        self.ajouter:SetShown(mj and #ids < places)
        y = y + 26

        for index, id in ipairs(ids) do
            local c = self.cartes[index]
            if not c then
                c = UI.Fiche.Carte(parent, function(objetId) f:Retirer(objetId) end)
                self.cartes[index] = c
            end
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
            c:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
            local hauteur = c:Habiller(id, Objets.Get(id), mj)
            c:SetHeight(hauteur)
            c:Show()
            y = y + hauteur + 6
        end
        for index = #ids + 1, #self.cartes do self.cartes[index]:Hide() end

        self.vide:ClearAllPoints()
        self.vide:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -y)
        self.vide:SetShown(#ids == 0)
        if #ids == 0 then y = y + 20 end
        return y + 10
    end
    return g
end

-- ===== La fenetre ==========================================================

local function Construire()
    local f = UI.Fenetre("equipement", "Équipement", LARGEUR, HAUTEUR, { x = 220, y = 10 })
    Ecran.frame = f

    f.nom = UI.Texte(f, "", UI.C.texte, "GameFontNormalSmall")
    f.nom:SetPoint("TOPLEFT", f.titre, "BOTTOMLEFT", 0, -4)

    f.zone = UI.Defilement(f.contenu)
    f.zone:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -18)
    f.zone:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)

    f.choix = UI.Choix("equipement", "")
    f:HookScript("OnHide", function() f.choix:Hide() end)

    f.groupes = {}
    for _, categorie in ipairs(Objets.CATEGORIES) do
        f.groupes[#f.groupes + 1] = Groupe(f, f.zone.contenu, categorie)
    end

    function f:Afficher()
        local mj = LCM.IsMaster()
        local y = 0
        for _, g in ipairs(self.groupes) do y = g:Disposer(self.entity, y, mj) end
        self.zone:Regler(y)
    end

    -- Les objets de la categorie qu'on ne porte pas deja.
    function f:Proposer(g)
        if not LCM.IsMaster() then return end
        local options = {}
        for _, objet in ipairs(Objets.list) do
            if objet.categorie == g.categorie.id and not Objets.EstEquipe(self.entity, objet.id) then
                options[#options + 1] = {
                    id = objet.id,
                    label = objet.label .. (objet.brouillon and "  · brouillon" or ""),
                }
            end
        end
        if #options == 0 then
            LCM.Alerte(string.format("aucun objet de categorie %s a equiper.", g.categorie.label:lower()))
            return
        end
        table.sort(options, function(a, b) return a.label:lower() < b.label:lower() end)
        self.choix.titre:SetText(g.categorie.label)
        self.choix:Proposer(g.ajouter, options, function(id)
            local ok, raison = Objets.Equiper(self.entity, id)
            if not ok then LCM.Alerte(raison) end
            self:Afficher()
        end)
    end

    -- Retirer se rattrape (on reequipe) : pas de confirmation.
    function f:Retirer(id)
        if not LCM.IsMaster() then return end
        if Objets.Desequiper(self.entity, id) then self:Afficher() end
    end

    function f:Montrer(entity)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucune entite a afficher.")
            return
        end
        self.nom:SetText(tostring(self.entity.name or self.entity.id))
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
    UI.Radial.Lier("equipement", Ecran.Basculer)
end)
