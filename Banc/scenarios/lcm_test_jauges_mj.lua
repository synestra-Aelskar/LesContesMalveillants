-- Les jauges de la fiche (13 octobre 2026) : les boutons -, +, R sont au MJ, et
-- le MJ peut cliquer sur la barre pour taper la valeur. Le joueur lit ses
-- jauges ; c'est la partie qui les fait bouger.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local E = LCM.Entities
local moi = E.Self()
local f = LCM.UI.Fiche.Fenetre()

local function ligneDe(nom)
    for _, ligne in ipairs(f.pages[f.onglet].lignes) do
        if ligne.barre and ligne.nom and ligne.nom:GetText() == nom then return ligne end
    end
end
local function rouvrir()
    f:Hide()
    f:Montrer(moi)
end

dire("== MJ : boutons, et la barre se saisit")
rouvrir()
local pa = ligneDe("PA")
attendu("la ligne PA", pa ~= nil, true)
attendu("les boutons", pa.boutons[1]:IsShown(), true)
attendu("la barre se clique", pa.saisie:IsShown(), true)
local maxPA = E.Gauge(moi, "pa").max
pa.saisie:Click()
local d = LCM_Demande
attendu("on demande la valeur", d:IsShown(), true)
d.saisie:SetText("2")
d.valider:Click()
attendu("posee", E.Gauge(moi, "pa").current, 2)
attendu("la demande se ferme", d:IsShown(), false)
pa.saisie:Click()
d.saisie:SetText(tostring(maxPA + 1))
d.valider:Click()
attendu("au-dessus du maximum : refus dit", (d.message:GetText() or ""):find("maximum", 1, true) ~= nil, true)
attendu("rien n'a bouge", E.Gauge(moi, "pa").current, 2)
d.saisie:SetText("-1")
d.valider:Click()
attendu("negatif : refus", E.Gauge(moi, "pa").current, 2)
d.saisie:SetText("abc")
d.valider:Click()
attendu("illisible : refus dit", (d.message:GetText() or ""):find("illisible", 1, true) ~= nil, true)
d:Hide()
local largeurMJ = pa.barre:GetWidth()

dire("== joueur : ni boutons ni saisie, la barre prend la place")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
rouvrir()
pa = ligneDe("PA")
attendu("plus de boutons", pa.boutons[1]:IsShown(), false)
attendu("plus de saisie", pa.saisie:IsShown(), false)
attendu("la barre s'allonge", pa.barre:GetWidth() > largeurMJ, true)
local fatigue = ligneDe("Fatigue")
attendu("pareil pour la fatigue", fatigue and fatigue.boutons[2]:IsShown(), false)
-- Meme si le bouton etait atteint, le geste est refuse.
local avant = E.Gauge(moi, "pa").current
pa.boutons[2]:Click()
attendu("le geste est refuse", E.Gauge(moi, "pa").current, avant)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
