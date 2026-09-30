-- Silhouette : les parties du corps et leurs points de vie.
--
-- Le dessin decoule du plan de montage de la morphologie (rangee, place dans la
-- rangee) : rien n'est code pour une espece en particulier. Deux jambes ou
-- douze, la silhouette se compose toute seule.
--
-- Chaque partie est une petite barre verticale, sa hauteur remplie donnant ses
-- points restants. Les internes se superposent au buste, en liseré.

local _, LCM = ...
local UI = LCM.UI

local Silhouette = {}
UI.Silhouette = Silhouette

local MARGE = 6
local ESPACE = 4

-- Cree (ou recupere) le cadre de silhouette d'une entite.
function Silhouette.Creer(parent, largeur, hauteur)
    local cadre = CreateFrame("Frame", nil, parent)
    cadre:SetSize(largeur or 220, hauteur or 200)
    cadre.parties = {}

    -- Une partie : un fond, une barre qui se remplit par le bas, un libelle.
    local function CreerPartie()
        local p = CreateFrame("Button", nil, cadre)
        p.fond = UI.Aplat(p, UI.C.vieVide)
        p.fond:SetAllPoints(p)
        p.plein = UI.Aplat(p, UI.C.vie, "ARTWORK")
        p.plein:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
        p.plein:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
        UI.Bordure(p, { UI.C.bordure[1], UI.C.bordure[2], UI.C.bordure[3], 0.25 })
        p.label = UI.Texte(p, "", UI.C.texte, "GameFontNormalSmall")
        p.label:SetPoint("TOP", p, "BOTTOM", 0, -1)
        p.label:SetJustifyH("CENTER")
        p.survol = UI.Aplat(p, UI.C.survol, "HIGHLIGHT")
        p.survol:SetAllPoints(p)
        return p
    end

    -- Redessine pour une entite donnee.
    function cadre:Actualiser(entity)
        self.entity = entity
        local etat, morphologie = LCM.Body.State(entity)
        self.morphologie = morphologie
        if not morphologie then return end

        -- Combien de rangees, et combien de places dans la plus large : la
        -- silhouette s'etale sur la place disponible, sans taille codee en dur.
        local rangees = morphologie.rows or 1
        local placesMax = 1
        for _, partie in ipairs(morphologie.parts) do
            if (partie.slots or 1) > placesMax then placesMax = partie.slots end
        end

        local largeurUtile = self:GetWidth() - (MARGE * 2)
        local hauteurUtile = self:GetHeight() - (MARGE * 2)
        local largeurCase = (largeurUtile - (placesMax - 1) * ESPACE) / placesMax
        local hauteurCase = (hauteurUtile - (rangees - 1) * ESPACE) / rangees

        for index, donnees in ipairs(etat) do
            local p = self.parties[index]
            if not p then
                p = CreerPartie()
                self.parties[index] = p
            end
            local partie = donnees.part
            local places = partie.slots or 1
            local place = partie.slot or 1

            -- Centrage : une rangee de 2 dans une grille de 5 reste centree.
            local largeurRangee = places * largeurCase + (places - 1) * ESPACE
            local departX = MARGE + (largeurUtile - largeurRangee) / 2
            local x = departX + (place - 1) * (largeurCase + ESPACE)
            local y = -(MARGE + (partie.row - 1) * (hauteurCase + ESPACE))

            p:ClearAllPoints()
            p:SetSize(largeurCase, hauteurCase)
            p:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)

            if partie.inner then
                -- Les internes se lisent par-dessus le buste : plus etroits,
                -- decales, pour qu'on voie les deux. ClearAllPoints d'abord :
                -- un second SetPoint s'AJOUTE au premier, il ne le remplace pas.
                p:ClearAllPoints()
                p:SetSize(largeurCase * 0.5, hauteurCase * 0.5)
                p:SetPoint("TOPLEFT", self, "TOPLEFT", x + largeurCase * 0.25, y - hauteurCase * 0.25)
            end

            local part = donnees.max > 0 and (donnees.current / donnees.max) or 0
            p.plein:SetHeight(math.max(part > 0 and 2 or 0, p:GetHeight() * part))
            p.plein:SetShown(part > 0)
            p.label:SetText(string.format("%d/%d", donnees.current, donnees.max))
            p.partieId = donnees.id
            p.donnees = donnees
            p:Show()

            -- Molette : blesser / soigner sans ouvrir de fenetre.
            p:EnableMouseWheel(true)
            p:SetScript("OnMouseWheel", function(bouton, delta)
                if not self.entity then return end
                LCM.Body.Damage(self.entity, bouton.partieId, -delta)
                self:Actualiser(self.entity)
                -- Le total et le reste de la fiche vivent hors de la
                -- silhouette : on previent, sinon ils restent sur l'ancienne
                -- valeur.
                if self.onChange then self.onChange(self.entity) end
            end)
        end

        for index = #etat + 1, #self.parties do
            self.parties[index]:Hide()
        end
    end

    return cadre
end
