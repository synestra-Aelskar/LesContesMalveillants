-- L'atelier des CADAVRES (le MJ, 3 novembre 2026), Système › Interactions ›
-- Cadavres : poser une creature deja morte, sans combat. Le PNJ du compendium
-- tient lieu de modele — son equipement et son butin (onglet Loot de sa
-- creation) remplissent le cadavre. On choisit, on se tient la ou il gît, et
-- « Poser un cadavre ici ». En dessous : ceux qui sont poses, a ouvrir (pour
-- corriger) ou a retirer.
local _, MJ = ...
local LCM = _G.LCM
if not LCM then return end
local UI = LCM.UI

local Ecran = {}
UI.CadavresMJ = Ecran

local LARGEUR, HAUTEUR = 460, 520
local LIGNE = 26

local function Construire()
    local f = UI.Fenetre("cadavres_mj", "Cadavres", LARGEUR, HAUTEUR, { x = 0, y = -20 },
        { enTeteSimple = true, sobre = true })
    Ecran.frame = f
    local c = f.contenu

    f.aide = UI.Texte(c, "Choisis un PNJ : son équipement et son butin (onglet Loot de sa création) "
        .. "remplissent le cadavre. Tiens-toi là où il gît, puis pose-le.", UI.C.discret, "GameFontNormalSmall")
    f.aide:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -2)
    f.aide:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -2)
    f.aide:SetJustifyH("LEFT")
    f.aide:SetWordWrap(true)

    f.libellePNJ = UI.Texte(c, "PNJ", UI.C.libelle, "GameFontNormalSmall")
    f.libellePNJ:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -46)
    f.choixPNJ = UI.Deroulant(c, 260, 22, function()
        local options = {}
        for _, pnj in ipairs(LCM.PNJ.list or {}) do
            options[#options + 1] = { id = pnj.id, label = tostring(pnj.label or pnj.id) }
        end
        table.sort(options, function(a, b) return a.label:lower() < b.label:lower() end)
        return options
    end, function(id)
        f.pnjId = id
        f:Afficher()
    end)
    f.choixPNJ:SetPoint("TOPLEFT", c, "TOPLEFT", 40, -42)
    f.resume = UI.Texte(c, "", UI.C.discret, "GameFontNormalSmall")
    f.resume:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -72)
    f.resume:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -72)
    f.resume:SetJustifyH("LEFT")
    f.resume:SetWordWrap(true)

    f.poser = UI.Bouton(c, "Poser un cadavre ici", 200, 26, function()
        local id, raison = MJ.Cadavres.PoserPNJ(f.pnjId)
        if not id then LCM.Alerte(tostring(raison)) return end
        LCM.Ok("Cadavre posé à tes pieds.")
        f:Afficher()
    end)
    f.poser:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -104)

    f.titrePoses = UI.Texte(c, "CADAVRES POSÉS", UI.C.libelle, "GameFontNormalSmall")
    f.titrePoses:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -146)
    f.filet = UI.Filet(c, true)
    f.filet:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -161)
    f.filet:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -161)
    f.zone = UI.Defilement(c)
    f.zone:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -168)
    f.zone:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -10, 4)
    f.vide = UI.Texte(f.zone.contenu, "Aucun cadavre posé.", UI.C.discret, "GameFontNormalSmall")
    f.vide:SetPoint("TOPLEFT", f.zone.contenu, "TOPLEFT", 4, -6)
    f.lignes = {}

    local function Ligne(n)
        local l = f.lignes[n]
        if l then return l end
        l = CreateFrame("Frame", nil, f.zone.contenu)
        l:SetHeight(LIGNE - 2)
        l.fond = UI.Aplat(l, { 1, 1, 1, 0.035 }, "BACKGROUND")
        l.fond:SetAllPoints(l)
        l.icone = l:CreateTexture(nil, "ARTWORK")
        l.icone:SetSize(20, 20)
        l.icone:SetPoint("LEFT", l, "LEFT", 4, 0)
        l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        l.retirer = UI.Bouton(l, "×", 22, 20, function()
            MJ.Cadavres.Supprimer(l.cadavreId)
            f:Afficher()
        end)
        l.retirer:SetPoint("RIGHT", l, "RIGHT", -2, 0)
        UI.Bulle(l.retirer, "Retirer", "Le cadavre disparaît pour tout le monde, avec ce qu'il porte encore.")
        l.ouvrir = UI.Bouton(l, "Ouvrir", 64, 20, function()
            if LCM.UI.Cadavre then LCM.UI.Cadavre.Ouvrir(l.cadavreId) end
        end)
        l.ouvrir:SetPoint("RIGHT", l.retirer, "LEFT", -4, 0)
        UI.Bulle(l.ouvrir, "Ouvrir", "Voir et corriger ce qu'il porte (clic droit sur un objet).")
        l.nom = UI.Texte(l, "", UI.C.texte, "GameFontNormalSmall")
        l.nom:SetPoint("LEFT", l.icone, "RIGHT", 8, 0)
        l.nom:SetPoint("RIGHT", l.ouvrir, "LEFT", -8, 0)
        l.nom:SetJustifyH("LEFT")
        l.nom:SetWordWrap(false)
        f.lignes[n] = l
        return l
    end

    function f:Afficher()
        local pnj = self.pnjId and LCM.PNJ.Get(self.pnjId)
        self.choixPNJ:Definir(pnj and pnj.id or nil, pnj and pnj.label or "— choisis un PNJ —")
        if pnj then
            local n = { equipe = 0 }
            for _, ids in pairs(pnj.equipement or {}) do n.equipe = n.equipe + #(ids or {}) end
            for _, section in ipairs(LCM.SECTIONS_LOOT) do n[section] = #((pnj.loot or {})[section] or {}) end
            self.resume:SetText(string.format("Équipé : %d · Sac : %d · Naturel : %d · Ventre : %d",
                n.equipe, n.sacs, n.naturel, n.ventre))
        else
            self.resume:SetText("")
        end
        self.poser:SetEnabled(pnj ~= nil)
        local liste = MJ.Cadavres.Liste()
        local y = 0
        for n, cadavre in ipairs(liste) do
            local l = Ligne(n)
            l.cadavreId = cadavre.id
            l.icone:SetTexture(LCM.Icone(cadavre.icone))
            local restant = 0
            for _, lot in ipairs(cadavre.lots or {}) do if lot.actif ~= false then restant = restant + 1 end end
            l.nom:SetText(string.format("%s  |cff99907f%d objet(s)%s|r", tostring(cadavre.nom), restant,
                cadavre.fouille and (" · " .. tostring(cadavre.fouille.par) .. " fouille") or ""))
            l:ClearAllPoints()
            l:SetPoint("TOPLEFT", self.zone.contenu, "TOPLEFT", 0, -y)
            l:SetPoint("TOPRIGHT", self.zone.contenu, "TOPRIGHT", 0, -y)
            l:Show()
            y = y + LIGNE
        end
        for n = #liste + 1, #self.lignes do self.lignes[n]:Hide() end
        self.vide:SetShown(#liste == 0)
        self.zone:Regler(math.max(1, y))
    end

    function f:Montrer()
        self:Show()
        self:Afficher()
    end
    return f
end

function Ecran.Fenetre() return Ecran.frame or Construire() end

function Ecran.Basculer()
    if not LCM.IsMaster() then return nil end
    local f = Ecran.Fenetre()
    if f:IsShown() then f:Hide() else f:Montrer() end
    return f
end

LCM.WhenReady(function()
    if UI.Menu and UI.Menu.Lier then UI.Menu.Lier("cadavres", function() Ecran.Basculer() end) end
    MJ.Cadavres.onChange = function()
        local f = Ecran.frame
        if f and f:IsShown() then f:Afficher() end
    end
end)
