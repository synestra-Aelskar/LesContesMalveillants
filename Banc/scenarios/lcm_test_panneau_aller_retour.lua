-- Aller-retour entre le Panel MJ et sa version compacte (3 novembre 2026).
-- En jeu : « Panneau.lua: Action[SetPoint] failed because[SetPoint would
-- result in anchor family connection] ». Le banc acceptait les boucles
-- d'ancrage ; il les refuse maintenant, comme le jeu.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local Ecran = LCM.UI.PanneauMJ

dire("== le banc refuse une boucle d'ancrage")
local a, b = CreateFrame("Frame"), CreateFrame("Frame")
a:SetPoint("TOPLEFT", b, "TOPLEFT")
attendu("B sur A, quand A est sur B : refusé", pcall(b.SetPoint, b, "TOPLEFT", a, "TOPLEFT"), false)

dire("== ouvrir, réduire, étendre, plusieurs fois")
local function geste(libelle, fn)
    local ok, erreur = pcall(fn)
    attendu(libelle, ok and "ok" or tostring(erreur), "ok")
end
geste("ouvrir le panneau complet", function() Ecran.Mode(false) end)
for _, id in ipairs({ "joueurs", "pnj", "combat", "equilibrage", "traits" }) do
    geste("  page " .. id, function() Ecran.Fenetre():Onglet(id) end)
end
geste("passer en compact", function() Ecran.Mode(true) end)
geste("revenir au complet", function() Ecran.Mode(false) end)
geste("repasser en compact", function() Ecran.Mode(true) end)
geste("revenir encore", function() Ecran.Mode(false) end)
geste("fermer, rouvrir", function() Ecran.Fenetre():Hide() Ecran.Basculer() end)

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
