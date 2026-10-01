-- Ecrire un sort de son grimoire.
--
-- Petite fenetre, six champs, et c'est tout : un sort est fait pour etre cite
-- dans une conversation, pas pour etre une fiche de plus. Les bornes de
-- longueur viennent de Core/Sorts.lua, et c'est lui qui accepte ou refuse —
-- l'ecran ne fait que porter le refus a l'ecran.

local _, LCM = ...
local UI = LCM.UI
local Sorts = LCM.Sorts

local Editeur = {}
UI.SortEditeur = Editeur

local LARGEUR, HAUTEUR = 420, 330
local ETIQUETTE = 92

local function Ligne(f, libelle, y, largeur)
    local fs = UI.Texte(f.contenu, libelle, UI.C.texte)
    UI.Police(fs, 11)
    fs:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
    local champ = UI.Champ(f.contenu, largeur or 280, 22)
    champ:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", ETIQUETTE, -y + 3)
    return champ
end

local function Construire()
    local f = UI.Fenetre("sort_editeur", "Sort", LARGEUR, HAUTEUR, { x = 260, y = -60 })
    Editeur.frame = f

    local y = 4
    f.nom = Ligne(f, "Nom", y) y = y + 30
    f.icone = Ligne(f, "Icône", y) y = y + 30
    f.description = Ligne(f, "Description", y) y = y + 30
    f.champ1 = Ligne(f, "Champ 1", y) y = y + 30
    f.champ2 = Ligne(f, "Champ 2", y) y = y + 30

    local fs = UI.Texte(f.contenu, "Jet", UI.C.texte)
    UI.Police(fs, 11)
    fs:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
    f.jetMin = UI.Champ(f.contenu, 60, 22)
    f.jetMin:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", ETIQUETTE, -y + 3)
    f.jetMin:SetNumeric(true)
    local a = UI.Texte(f.contenu, "à", UI.C.discret)
    UI.Police(a, 11)
    a:SetPoint("LEFT", f.jetMin, "RIGHT", 8, 0)
    f.jetMax = UI.Champ(f.contenu, 60, 22)
    f.jetMax:SetPoint("LEFT", a, "RIGHT", 8, 0)
    f.jetMax:SetNumeric(true)
    local aide = UI.Texte(f.contenu, "laisser vide pour un sort sans jet", UI.C.discret)
    UI.Police(aide, 10)
    aide:SetPoint("LEFT", f.jetMax, "RIGHT", 10, 0)
    y = y + 36

    f.probleme = UI.Texte(f.contenu, "", UI.C.plein)
    UI.Police(f.probleme, 10)
    f.probleme:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, -y)
    f.probleme:SetPoint("TOPRIGHT", f.contenu, "TOPRIGHT", 0, -y)

    f.valider = UI.Bouton(f.contenu, "Enregistrer", 120, 24, function() f:Enregistrer() end)
    f.valider:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.annuler = UI.Bouton(f.contenu, "Annuler", 100, 24, function() f:Hide() end)
    f.annuler:SetPoint("LEFT", f.valider, "RIGHT", 8, 0)

    function f:Definition()
        local jetMin = tonumber(self.jetMin:GetText())
        local jetMax = tonumber(self.jetMax:GetText())
        return {
            label = self.nom:GetText(),
            icone = self.icone:GetText(),
            description = self.description:GetText(),
            champ1 = self.champ1:GetText(),
            champ2 = self.champ2:GetText(),
            jet = (jetMin or jetMax) and { min = jetMin or 0, max = jetMax or 0 } or nil,
        }
    end

    function f:Enregistrer()
        local definition = self:Definition()
        local sort, raison
        if self.sortId then
            sort, raison = Sorts.Modifier(self.entity, self.sortId, definition)
        else
            sort, raison = Sorts.Ajouter(self.entity, definition)
        end
        if not sort then
            self.probleme:SetText(tostring(raison))
            return
        end
        self.probleme:SetText("")
        LCM.Ok(string.format("%s %s.", tostring(sort.label),
            self.sortId and "corrige" or "ecrit dans ton grimoire"))
        self:Hide()
        local livre = UI.Grimoire.frame
        if livre and livre:IsShown() then livre:Afficher(livre.sousRang) end
        local hub = UI.Grimoires.frame
        if hub and hub:IsShown() then hub:Afficher() end
    end

    function f:Montrer(entity, sort)
        self.entity = entity or LCM.Entities.Self()
        if not self.entity then
            LCM.Alerte("aucun personnage.")
            return
        end
        self.sortId = sort and sort.id or nil
        self:Titre(sort and "Corriger un sort" or "Nouveau sort")
        self:SousTitre(self.entity.name or self.entity.id)
        self.nom:SetText(sort and sort.label or "")
        self.icone:SetText(sort and sort.icone or "")
        self.description:SetText(sort and sort.description or "")
        self.champ1:SetText(sort and sort.champ1 or "")
        self.champ2:SetText(sort and sort.champ2 or "")
        self.jetMin:SetText(sort and sort.jet and tostring(sort.jet.min) or "")
        self.jetMax:SetText(sort and sort.jet and tostring(sort.jet.max) or "")
        self.probleme:SetText("")
        self:Show()
    end

    return f
end

function Editeur.Fenetre()
    if not Editeur.frame then Construire() end
    return Editeur.frame
end

function Editeur.Ouvrir(entity, sort)
    local f = Editeur.Fenetre()
    f:Montrer(entity, sort)
    return f
end
