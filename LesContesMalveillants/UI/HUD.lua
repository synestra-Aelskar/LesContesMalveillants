-- HUD du personnage LCM : remplace le portrait et les jauges Blizzard par
-- l'artwork du personnage, l'etat en pourcentage de chaque zone du corps, les
-- PV globaux et la fatigue.

local _, LCM = ...
local UI = LCM.UI

local Ecran = { pastilles = {} }
UI.HUD = Ecran

local DOSSIER_HUD = "Interface\\AddOns\\LesContesMalveillants\\ressources\\hud\\"
local LARGEUR, HAUTEUR = 650, 190
local PASTILLE, ECART = 68, 3
local ZONES_X, ZONES_Y = 178, -44
local CIBLE_L, CIBLE_H = 82, 112

local ORBES = {
    { "zone-1", 188 / 256, 198 / 256 },
    { "zone-2", 191 / 256, 197 / 256 },
    { "zone-3", 191 / 256, 196 / 256 },
    { "zone-4", 188 / 256, 193 / 256 },
    { "zone-5", 189 / 256, 196 / 256 },
}

local function TextureHUD(parent, niveau, fichier, u, v)
    local texture = parent:CreateTexture(nil, niveau or "ARTWORK")
    texture:SetTexture(DOSSIER_HUD .. fichier .. ".tga")
    texture.u, texture.v = u or 1, v or 1
    texture:SetTexCoord(0, texture.u, 0, texture.v)
    return texture
end

local function MasquerPortraitBlizzard(masquer)
    if not PlayerFrame then return end
    -- PlayerFrame est protege en combat. Il est normalement deja cache avant
    -- l'engagement ; si Blizzard tente de le retablir, on attend la sortie de
    -- combat plutot que de provoquer une action bloquee.
    if InCombatLockdown and InCombatLockdown() then return end
    if masquer then
        if PlayerFrame:IsShown() then PlayerFrame:Hide() end
    elseif not PlayerFrame:IsShown() then
        PlayerFrame:Show()
    end
end

local function MasquerCibleBlizzard(masquer)
    if not TargetFrame then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if masquer then
        if TargetFrame:IsShown() then TargetFrame:Hide() end
    elseif UnitExists and UnitExists("target") and not TargetFrame:IsShown() then
        TargetFrame:Show()
    end
end

local function Pastille(parent, index)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(PASTILLE, PASTILLE + 18)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT",
        ZONES_X + (index - 1) * (PASTILLE + ECART), ZONES_Y)
    p.orbe = TextureHUD(p, "ARTWORK", ORBES[1][1], ORBES[1][2], ORBES[1][3])
    p.orbe:SetSize(PASTILLE, PASTILLE)
    p.orbe:SetPoint("TOP", p, "TOP", 0, 0)
    p.pourcent = UI.Texte(p, "", UI.C.texte)
    UI.Police(p.pourcent, 11, "OUTLINE")
    p.pourcent:SetSize(PASTILLE - 14, 20)
    p.pourcent:SetPoint("CENTER", p.orbe, "CENTER", 0, 0)
    p.pourcent:SetJustifyH("CENTER")
    p.nom = UI.Texte(p, "", UI.C.libelle)
    UI.Police(p.nom, 8)
    p.nom:SetPoint("TOPLEFT", p, "TOPLEFT", -3, -PASTILLE + 1)
    p.nom:SetPoint("TOPRIGHT", p, "TOPRIGHT", 3, -PASTILLE + 1)
    p.nom:SetJustifyH("CENTER")
    p.nom:SetWordWrap(false)
    UI.Bulle(p, function(soi) return soi.libelle end,
        function(soi) return string.format("%d / %d — %d %%", soi.courant, soi.maximum, soi.pct) end, 0.25)
    Ecran.pastilles[index] = p
    return p
end

local function OrbeTotal(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(164, 164)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -14)
    p.orbe = TextureHUD(p, "ARTWORK", "pv-total", 420 / 512, 440 / 512)
    p.orbe:SetAllPoints(p)
    p.valeur = UI.Texte(p, "", UI.C.texte)
    UI.Police(p.valeur, 20, "OUTLINE")
    p.valeur:SetPoint("CENTER", p, "CENTER", 0, 7)
    p.valeur:SetJustifyH("CENTER")
    p.maximumTexte = UI.Texte(p, "", UI.C.texte)
    UI.Police(p.maximumTexte, 13, "OUTLINE")
    p.maximumTexte:SetPoint("TOP", p.valeur, "BOTTOM", 0, -2)
    p.maximumTexte:SetJustifyH("CENTER")
    p.pourcent = UI.Texte(p, "", UI.C.texte)
    p.pourcent:Hide()
    UI.Bulle(p, "Points de vie totaux", function(soi)
        return string.format("%d / %d — %d %%", soi.courant, soi.maximum, soi.pct)
    end, 0.25)
    return p
end

local function BarreFatigue(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(430, 62)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 174, -116)
    b.fond = TextureHUD(b, "ARTWORK", "fatigue-vide", 738 / 1024, 112 / 128)
    b.fond:SetAllPoints(b)
    b.remplissage = TextureHUD(b, "ARTWORK", "fatigue-plein", 590 / 1024, 28 / 32)
    b.remplissage:SetPoint("LEFT", b, "LEFT", 62, -1)
    b.remplissage:SetHeight(22)
    b.largeurRemplissage = 349
    b.label = UI.Texte(b, "", UI.C.texte)
    UI.Police(b.label, 11, "OUTLINE")
    b.label:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -5, 1)
    b.titre = UI.Texte(b, "FATIGUE", UI.C.libelle)
    UI.Police(b.titre, 9)
    b.titre:SetPoint("BOTTOM", b, "BOTTOM", -10, 1)
    function b:Regler(courant, maximum)
        courant, maximum = tonumber(courant) or 0, tonumber(maximum) or 0
        local proportion = maximum > 0 and math.max(0, math.min(1, courant / maximum)) or 0
        self.remplissage:SetWidth(math.max(0.01, self.largeurRemplissage * proportion))
        self.remplissage:SetTexCoord(0, self.remplissage.u * proportion,
            0, self.remplissage.v)
        self.remplissage:SetShown(proportion > 0)
        self.label:SetText(string.format("%d / %d", courant, maximum))
    end
    return b
end

local function Construire()
    local f = CreateFrame("Frame", "LCM_HUDPersonnage", UIParent)
    f:SetSize(LARGEUR, HAUTEUR)
    -- La composition source est tres detaillee : on la dessine a sa taille
    -- logique puis on la ramene a 72 % pour qu'elle remplace le portrait sans
    -- occuper tout le quart superieur de l'ecran.
    f:SetScale(0.72)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 18, -18)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    -- Aucun panneau noir : les TGA portent leur propre transparence et doivent
    -- sembler poses directement sur le monde.
    f.nom = UI.Texte(f, "", UI.C.texte)
    UI.Police(f.nom, 16)
    f.nom:SetPoint("TOPLEFT", f, "TOPLEFT", ZONES_X + 6, -14)
    f.nom:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -14)
    f.nom:SetJustifyH("LEFT")
    f.nom:SetWordWrap(false)
    f.total = OrbeTotal(f)
    f.fatigue = BarreFatigue(f)

    -- Carte compacte de la cible : elle remplace TargetFrame seulement quand
    -- l'addon connait réellement l'artwork du personnage sélectionné.
    f.cible = CreateFrame("Frame", nil, f)
    f.cible:SetSize(CIBLE_L, CIBLE_H)
    f.cible:SetPoint("LEFT", f, "RIGHT", 7, 0)
    f.cible.fond = UI.Aplat(f.cible, UI.C.fond, "BACKGROUND")
    f.cible.fond:SetAllPoints(f.cible)
    if UI.AelCadre then f.cible.cadre = UI.AelCadre(f.cible, "icone")
    else UI.Bordure(f.cible) end
    f.cible.art = f.cible:CreateTexture(nil, "ARTWORK")
    f.cible.art:SetPoint("TOPLEFT", f.cible, "TOPLEFT", 4, -4)
    f.cible.art:SetPoint("BOTTOMRIGHT", f.cible, "BOTTOMRIGHT", -4, 4)
    f.cible.modele = CreateFrame("PlayerModel", nil, f.cible)
    f.cible.modele:SetPoint("TOPLEFT", f.cible, "TOPLEFT", 4, -4)
    f.cible.modele:SetPoint("BOTTOMRIGHT", f.cible, "BOTTOMRIGHT", -4, 4)
    f.cible.modele:Hide()
    f.cible.nomFond = UI.Aplat(f.cible, { 0.02, 0.015, 0.01, 0.86 }, "OVERLAY")
    f.cible.nomFond:SetPoint("BOTTOMLEFT", f.cible, "BOTTOMLEFT", 4, 4)
    f.cible.nomFond:SetPoint("BOTTOMRIGHT", f.cible, "BOTTOMRIGHT", -4, 4)
    f.cible.nomFond:SetHeight(19)
    f.cible.nom = UI.Texte(f.cible, "", UI.C.titre)
    UI.Police(f.cible.nom, 9)
    f.cible.nom:SetPoint("BOTTOMLEFT", f.cible, "BOTTOMLEFT", 6, 7)
    f.cible.nom:SetPoint("BOTTOMRIGHT", f.cible, "BOTTOMRIGHT", -6, 7)
    f.cible.nom:SetJustifyH("CENTER")
    f.cible.nom:SetWordWrap(false)
    f.cible:Hide()

    f:Hide()
    Ecran.frame = f
    return f
end

local function IdentiteCible()
    if not (UnitExists and UnitExists("target") and UnitName) then return nil end
    local nom, royaume = UnitName("target")
    if not nom then return nil end
    local joueur = (royaume and royaume ~= "" and (nom .. "-" .. royaume)) or nom
    if UnitIsUnit and UnitIsUnit("target", "player") then
        local moi = LCM.Entities.Personnage and LCM.Entities.Personnage()
        return moi, joueur, nom
    end
    local entity = LCM.Fiches and LCM.Fiches.Recue and LCM.Fiches.Recue(joueur)
    if entity and LCM.Portraits.Of(entity) then return entity, joueur, nom end
    local portrait = LCM.Presence and LCM.Presence.Portrait and LCM.Presence.Portrait(joueur)
    local nomPersonnage = LCM.Presence and LCM.Presence.Personnage
        and LCM.Presence.Personnage(joueur)
    if not portrait and LCM.Presence and LCM.Presence.ParPersonnage then
        local joueurTrouve, presence = LCM.Presence.ParPersonnage(nom)
        if presence then
            joueur = joueurTrouve or joueur
            portrait = presence.portrait
            nomPersonnage = presence.personnage
        end
    end
    if portrait and LCM.Portraits.Get(portrait) then
        return {
            id = joueur,
            name = nomPersonnage or nom,
            values = { portrait = portrait },
        }, joueur, nom
    end
    -- Une cible sans fiche LCM reste une vraie cible : son modele 3D remplace
    -- le portrait Blizzard au lieu de laisser les deux interfaces cohabiter.
    return nil, joueur, nom
end

local function ActualiserCible(f)
    local entity, joueur, nomUnite = IdentiteCible()
    if not joueur then
        f.cible:Hide()
        f.cible.entity, f.cible.joueur = nil, nil
        MasquerCibleBlizzard(false)
        return
    end
    if entity and LCM.Portraits.Of(entity) then
        LCM.Portraits.Appliquer(f.cible.art, entity)
        f.cible.art:Show()
        f.cible.modele:Hide()
    else
        f.cible.art:Hide()
        f.cible.modele:Show()
        if f.cible.modele.ClearModel then f.cible.modele:ClearModel() end
        if f.cible.modele.SetUnit then pcall(f.cible.modele.SetUnit, f.cible.modele, "target") end
        if f.cible.modele.SetPortraitZoom then
            pcall(f.cible.modele.SetPortraitZoom, f.cible.modele, 0.72)
        end
        if f.cible.modele.SetAnimation then
            pcall(f.cible.modele.SetAnimation, f.cible.modele, 0)
        end
        -- Une présence ancienne peut ne pas encore contenir l'artwork. Le
        -- ping est temporisé par Presence lui-même ; sa réponse rappellera
        -- automatiquement Actualiser via Presence.Suivre.
        if LCM.Presence and LCM.Presence.Demander then LCM.Presence.Demander(false) end
    end
    local nom = entity and entity.name
        or (LCM.Presence and LCM.Presence.Personnage and LCM.Presence.Personnage(joueur))
        or nomUnite or joueur
    f.cible.nom:SetText(tostring(nom))
    f.cible.entity, f.cible.joueur = entity, joueur
    f.cible:Show()
    MasquerCibleBlizzard(true)
end

local function ReglerPastille(p, libelle, courant, maximum)
    courant, maximum = tonumber(courant) or 0, tonumber(maximum) or 0
    local pct = maximum > 0 and math.max(0, math.min(100, math.floor(courant * 100 / maximum + 0.5))) or 0
    p.libelle, p.courant, p.maximum, p.pct = libelle, courant, maximum, pct
    local etat = pct > 80 and 1 or pct > 60 and 2 or pct > 40 and 3 or pct > 20 and 4 or 5
    local asset = ORBES[etat]
    p.orbe:SetTexture(DOSSIER_HUD .. asset[1] .. ".tga")
    p.orbe:SetTexCoord(0, asset[2], 0, asset[3])
    p.pourcent:SetText(pct .. "%")
    local nom = tostring(libelle or "")
        :gsub("à", "À"):gsub("â", "Â"):gsub("ä", "Ä")
        :gsub("é", "É"):gsub("è", "È"):gsub("ê", "Ê"):gsub("ë", "Ë")
        :gsub("î", "Î"):gsub("ï", "Ï"):gsub("ô", "Ô"):gsub("ö", "Ö")
        :gsub("ù", "Ù"):gsub("û", "Û"):gsub("ü", "Ü"):gsub("ç", "Ç")
        :upper()
    p.nom:SetText(nom)
    p:Show()
end

function Ecran.Actualiser()
    local f = Ecran.frame or Construire()
    -- Le HUD represente le personnage du joueur, jamais le PNJ qu'un MJ est
    -- en train d'incarner pour la scene.
    local entity = LCM.Entities.Personnage()
    if not entity then
        f:Hide()
        f.cible:Hide()
        MasquerPortraitBlizzard(false)
        MasquerCibleBlizzard(false)
        return
    end

    MasquerPortraitBlizzard(true)
    f.nom:SetText(tostring(entity.name or entity.id))

    local etat = LCM.Body.State(entity)
    local totalCourant, totalMaximum = LCM.Body.Totals(entity)
    local nombre = #etat + 1

    for index, partie in ipairs(etat) do
        local p = Ecran.pastilles[index] or Pastille(f, index)
        ReglerPastille(p, partie.label, partie.current, partie.max)
    end
    local total = f.total
    total.courant, total.maximum = tonumber(totalCourant) or 0, tonumber(totalMaximum) or 0
    total.pct = total.maximum > 0 and math.max(0,
        math.min(100, math.floor(total.courant * 100 / total.maximum + 0.5))) or 0
    total.valeur:SetText(tostring(total.courant))
    total.maximumTexte:SetText("/ " .. tostring(total.maximum))
    total.pourcent:SetText(total.pct .. "%")
    total:Show()
    Ecran.pastilles[nombre] = total
    for index = #etat + 1, #Ecran.pastilles do
        if Ecran.pastilles[index] ~= total then Ecran.pastilles[index]:Hide() end
    end

    local fatigue = LCM.Entities.Gauge(entity, "fatigue") or { current = 0, max = 0 }
    f.fatigue:Regler(fatigue.current, fatigue.max)
    f.entity, f.nombreZones = entity, #etat
    f:Show()
    ActualiserCible(f)
end

-- Les degats, soins et depenses de fatigue se voient immediatement.
LCM.Entities.Ecouter(function(entity)
    local personnage = LCM.Entities.Personnage()
    if entity == personnage then Ecran.Actualiser() end
end)
LCM.Entities.EcouterSoi(function() Ecran.Actualiser() end)

LCM.WhenReady(function()
    Ecran.Actualiser()
    local veille = CreateFrame("Frame")
    veille:RegisterEvent("PLAYER_ENTERING_WORLD")
    veille:RegisterEvent("PLAYER_ALIVE")
    veille:RegisterEvent("PLAYER_REGEN_ENABLED")
    veille:RegisterEvent("PLAYER_TARGET_CHANGED")
    veille:SetScript("OnEvent", function() Ecran.Actualiser() end)
    Ecran.veille = veille
    if LCM.Presence and LCM.Presence.Suivre then
        LCM.Presence.Suivre(function() Ecran.Actualiser() end)
    end
end)
