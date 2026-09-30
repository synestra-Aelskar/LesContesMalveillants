-- Fenetre de documentation.
--
-- Le registre est dans Core/Documents.lua ; ici, seulement l'affichage : une
-- liste a gauche, le contenu a droite.

local _, LCM = ...
local UI = LCM.UI
local Documents = LCM.Documents

local Document = {}
UI.Document = Document

-- ===== Fenetre =============================================================

local function Vider(page)
    for _, region in ipairs(page.blocs or {}) do region:Hide() end
    page.blocs = page.blocs or {}
end

function Document.Fenetre()
    if Document.frame then return Document.frame end

    local f = UI.Fenetre("document", "Documentation", 520, 560, { x = 200, y = 0 })
    Document.frame = f

    -- Colonne de gauche : la liste des documents. A droite : le contenu.
    f.liste = CreateFrame("Frame", nil, f.contenu)
    f.liste:SetPoint("TOPLEFT", f.contenu, "TOPLEFT", 0, 0)
    f.liste:SetPoint("BOTTOMLEFT", f.contenu, "BOTTOMLEFT", 0, 0)
    f.liste:SetWidth(140)
    f.liste.boutons = {}

    f.page = CreateFrame("Frame", nil, f.contenu)
    f.page:SetPoint("TOPLEFT", f.liste, "TOPRIGHT", 10, 0)
    f.page:SetPoint("BOTTOMRIGHT", f.contenu, "BOTTOMRIGHT", 0, 0)
    f.page.blocs = {}

    local function Bloc(gabarit, couleur)
        local fs = UI.Texte(f.page, "", couleur, gabarit)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        return fs
    end

    function f:AfficherDocument(id)
        local doc = Documents.Get(id)
        if not doc then return end
        self.documentId = id
        for _, bouton in ipairs(self.liste.boutons) do
            bouton:Selectionner(bouton.documentId == id)
        end
        Vider(self.page)

        local y = 0
        local index = 0
        for _, bloc in ipairs(doc.blocs) do
            index = index + 1
            local fs = self.page.blocs[index]
            if not fs then
                fs = Bloc("GameFontNormalSmall", UI.C.texte)
                self.page.blocs[index] = fs
            end
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", self.page, "TOPLEFT", 0, -y)
            fs:SetPoint("TOPRIGHT", self.page, "TOPRIGHT", 0, -y)
            fs:Show()

            if bloc.kind == "titre" then
                fs:SetText(bloc.texte)
                fs:SetTextColor(UI.C.accent[1], UI.C.accent[2], UI.C.accent[3])
                y = y + 24
            elseif bloc.kind == "separateur" then
                fs:SetText("")
                y = y + 10
            elseif bloc.kind == "liste" then
                local lignes = {}
                for _, item in ipairs(bloc.items or {}) do
                    lignes[#lignes + 1] = "  - " .. tostring(item)
                end
                fs:SetText(table.concat(lignes, "\n"))
                fs:SetTextColor(UI.C.texte[1], UI.C.texte[2], UI.C.texte[3])
                y = y + 16 * math.max(1, #lignes) + 6
            else
                fs:SetText(bloc.texte)
                fs:SetTextColor(UI.C.texte[1], UI.C.texte[2], UI.C.texte[3])
                -- Hauteur estimee : un retour a la ligne tous les ~70 signes.
                local lignes = math.max(1, math.ceil(#bloc.texte / 70))
                y = y + 16 * lignes + 6
            end
        end
        self.hauteur = y
    end

    function f:Reconstruire()
        local docs = Documents.Visibles()
        local precedent
        for index, doc in ipairs(docs) do
            local b = self.liste.boutons[index]
            if not b then
                b = UI.Bouton(self.liste, "", 138, 22, function()
                    self:AfficherDocument(self.liste.boutons[index].documentId)
                end)
                self.liste.boutons[index] = b
            end
            b.documentId = doc.id
            b.label:SetText(doc.label)
            b:ClearAllPoints()
            if precedent then
                b:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, -4)
            else
                b:SetPoint("TOPLEFT", self.liste, "TOPLEFT", 0, 0)
            end
            b:Show()
            precedent = b
        end
        for index = #docs + 1, #self.liste.boutons do self.liste.boutons[index]:Hide() end
        self.documents = docs
    end

    function f:Montrer(id)
        self:Reconstruire()
        local cible = id or self.documentId
        if not cible or not Documents.Get(cible) then
            cible = self.documents[1] and self.documents[1].id
        end
        if cible then self:AfficherDocument(cible) end
        self:Show()
    end

    return f
end

LCM.AddCommand("doc", "ouvre la documentation", function(argument)
    local f = Document.Fenetre()
    if f:IsShown() then
        f:Hide()
        return
    end
    local cible = tostring(argument or ""):gsub("^%s+", ""):gsub("%s+$", "")
    f:Montrer(cible ~= "" and cible or nil)
end)
