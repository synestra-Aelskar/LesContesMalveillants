-- Les auras du jeu sur la cible (13 octobre 2026).
--
-- Le portrait compact du HUD cache TargetFrame, et avec lui la rangee d'auras
-- que Blizzard pose dessous. Un bouton « Aura » sous le portrait deplie juste
-- en dessous un petit cadre d'icones ; le survol donne l'infobulle du jeu.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
__temps(1000)

local H, A = LCM.UI.HUD, LCM.UI.Auras

dire("== sans cible, pas de bouton")
H.Actualiser()
local carte = H.frame.cible
attendu("le portrait de cible est caché", carte:IsShown(), false)
attendu("  et le bouton avec lui", carte.aura:IsVisible(), false)

dire("== on cible quelqu'un : le bouton est sous son portrait")
__cible("Nytherah", {
    utiles = {
        { nom = "Bénédiction de force", icone = 135906, duree = 3600, expiration = 1000 + 1830 },
        { nom = "Robe de prêtre", icone = 133770 },
    },
    nefastes = {
        { nom = "Poison mortel", icone = 132290, piles = 3, type = "Poison", duree = 12,
          expiration = 1000 + 8.2 },
    },
})
__declencher("PLAYER_TARGET_CHANGED")
attendu("le portrait de cible apparaît", carte:IsShown(), true)
attendu("  et le bouton Aura", carte.aura:IsVisible(), true)
local point, relatif, relPoint = carte.aura:GetPoint()
attendu("  posé sous le portrait", point .. ">" .. relPoint, "TOP>BOTTOM")
attendu("  du portrait de cible", relatif == carte, true)

dire("== le bouton déplie le petit cadre sous lui")
carte.aura:Click()
local f = A.frame
attendu("le cadre est ouvert", f and f:IsVisible(), true)
point, relatif, relPoint = f:GetPoint()
attendu("  sous le bouton", point .. ">" .. relPoint, "TOP>BOTTOM")
attendu("  du bouton Aura", relatif == carte.aura, true)
attendu("  enfant du portrait (même échelle)", f:GetParent() == carte, true)
attendu("deux bénéfiques", #f.utiles, 2)
attendu("une néfaste", #f.nefastes, 1)

local i1, i2, i3 = A.icones[1], A.icones[2], A.icones[3]
attendu("1re icône", i1.texture:GetTexture(), 135906)
attendu("  sa durée", i1.temps:GetText(), "31m")
attendu("2e : une aura sans fin n'écrit rien", i2.temps:GetText(), "")
attendu("  une seule pile ne s'affiche pas", i2.piles:GetText(), "")
attendu("3e : le poison", i3.texture:GetTexture(), 132290)
attendu("  ses piles", i3.piles:GetText(), "3")
attendu("  ses secondes", i3.temps:GetText(), "9s")
attendu("les néfastes sur leur propre rangée",
    select(5, i3:GetPoint()) < select(5, i1:GetPoint()), true)
attendu("  à gauche", select(4, i3:GetPoint()), select(4, i1:GetPoint()))
attendu("pas de « Aucune aura. »", f.vide:IsShown(), false)

dire("== le temps s'égrène")
__avancerTemps(5)
__avancer(1.1)
attendu("le poison est à 4s", i3.temps:GetText(), "4s")

dire("== l'infobulle est celle du jeu")
i3:GetScript("OnEnter")(i3)
attendu("elle demande l'aura à la cible", GameTooltip.__aura and GameTooltip.__aura.unite, "target")
attendu("  par son index", GameTooltip.__aura and GameTooltip.__aura.index, 1)
attendu("  dans les néfastes", GameTooltip.__aura and GameTooltip.__aura.filtre, "HARMFUL")

dire("== une aura qui tombe se voit aussitôt")
__cible("Nytherah", { utiles = {}, nefastes = {
    { nom = "Poison mortel", icone = 132290, piles = 3, type = "Poison" } } })
__declencher("UNIT_AURA", "player")
attendu("une aura du joueur ne redessine pas", #f.utiles, 2)
__declencher("UNIT_AURA", "target")
attendu("une aura de la cible, si", #f.utiles, 0)
attendu("  sans icône fantôme", i2:IsShown(), false)

dire("== changer de cible redessine")
__cible("Claydenn", {})
__declencher("PLAYER_TARGET_CHANGED")
attendu("plus aucune icône", i1:IsShown(), false)
attendu("  et c'est dit", f.vide:IsShown(), true)

dire("== plus de cible : le cadre part avec le portrait")
__cible(nil)
__declencher("PLAYER_TARGET_CHANGED")
attendu("le bouton est caché", carte.aura:IsVisible(), false)
attendu("  le cadre aussi", f:IsVisible(), false)

dire("== le bouton replie ce qu'il a déplié")
__cible("Nytherah", {})
__declencher("PLAYER_TARGET_CHANGED")
attendu("le cadre revient avec la cible", f:IsVisible(), true)
carte.aura:Click()
attendu("replié", f:IsShown(), false)

dire("== un client récent : C_UnitAuras")
-- Le client d'Epsilon parle UnitAura ; un client Dragonflight et suivants ne
-- connait plus que C_UnitAuras. Le cadre lit celle qui repond.
C_UnitAuras = { GetAuraDataByIndex = function(u, index, filtre)
    if filtre == "HELPFUL" and index == 1 then
        return { name = "Esprit divin", icon = 135898, applications = 2,
                 duration = 0, expirationTime = 0, spellId = 1 }
    end
end }
carte.aura:Click()
attendu("l'aura est lue", A.icones[1].texture:GetTexture(), 135898)
attendu("  avec ses piles", A.icones[1].piles:GetText(), "2")
C_UnitAuras = nil

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
