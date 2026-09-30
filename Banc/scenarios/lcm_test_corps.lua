-- Morphologies, repartition des PV, blessures.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")

dire("== morphologies declarees")
attendu("nombre", #LCM.Morphologies.list, 4)
for _, m in ipairs(LCM.Morphologies.list) do
    local somme = 0
    for _, p in ipairs(m.parts) do somme = somme + p.share end
    dire(string.format("   %-12s %d parties, %.0f%%", m.id, #m.parts, somme))
end

dire("== repartition des points de vie")
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "humain")
LCM.Entities.Set_Value(moi, "pv_max_override", 36)
local etat, morpho = LCM.Body.State(moi)
attendu("morphologie retenue", morpho.id, "humanoide")
attendu("parties", #etat, 7)
local somme = 0
for _, p in ipairs(etat) do
    somme = somme + p.max
    dire(string.format("   %-14s %d pv", p.label, p.max))
end
attendu("la somme des parties vaut le total", somme, 36)

dire("== le reste des arrondis ne se perd pas")
for _, total in ipairs({ 1, 7, 13, 36, 37, 100, 999 }) do
    LCM.Entities.Set_Value(moi, "pv_max_override", total)
    local s = 0
    for _, p in ipairs(LCM.Body.State(moi)) do s = s + p.max end
    attendu("total " .. total, s, total)
end

dire("== blessures")
LCM.Entities.Set_Value(moi, "pv_max_override", 36)
LCM.Body.Damage(moi, "bras_1", 3)
local courant, maximum = LCM.Body.Totals(moi)
attendu("apres 3 degats au bras", courant .. "/" .. maximum, "33/36")
LCM.Body.Damage(moi, "bras_1", 99)
local etat2 = LCM.Body.State(moi)
for _, p in ipairs(etat2) do
    if p.id == "bras_1" then
        attendu("un membre ne descend pas sous zero", p.current, 0)
        attendu("et pas au-dela de son maximum", p.wound, p.max)
    end
end
LCM.Body.Heal(moi, "bras_1", 1000)
attendu("soigne", select(1, LCM.Body.Totals(moi)), 36)
local n = 0
for _ in pairs(moi.body or {}) do n = n + 1 end
attendu("un corps intact ne laisse rien en sauvegarde", n, 0)

dire("== changer de race change la silhouette")
LCM.Entities.Set_Value(moi, "morphologie", "quadrupede")
local etatLoup, morphoLoup = LCM.Body.State(moi)
attendu("morphologie", morphoLoup.id, "quadrupede")
attendu("parties", #etatLoup, 8)
local sommeLoup = 0
for _, p in ipairs(etatLoup) do sommeLoup = sommeLoup + p.max end
attendu("meme total de pv", sommeLoup, 36)

LCM.Entities.Set_Value(moi, "morphologie", "aile")
local etatAile = LCM.Body.State(moi)
attendu("une harpie a des ailes", #etatAile, 9)
local ailes = false
for _, p in ipairs(etatAile) do if p.part.category == "aile" then ailes = true end end
attendu("aile gauche presente", ailes, true)

dire("== une race inconnue retombe sur l'humanoide")
LCM.Entities.Set_Value(moi, "morphologie", nil) LCM.Entities.Set_Value(moi, "race", "dragon_inexistant")
attendu("morphologie de repli", select(2, LCM.Body.State(moi)).id, "humanoide")

dire("== un PNJ quadrupede")
LCM.Entities.Set_Value(moi, "race", "humain")
LCM.Entities.Set_Value(moi, "morphologie", nil)
local golem = LCM.Entities.Create("pnj_loup", "Loup des cendres", "npc")
LCM.Entities.Set_Value(golem, "morphologie", "quadrupede")
LCM.Entities.Set_Value(golem, "pv_max_override", 80)
LCM.Body.Damage(golem, "jambe_1", 5)
local c, m = LCM.Body.Totals(golem)
attendu("son corps", c .. "/" .. m, "75/80")
local function poids(v, vu)
    vu = vu or {}
    local t = type(v)
    if t == "string" then return #v + 2 end
    if t == "number" then return 8 end
    if t == "boolean" then return 1 end
    if t ~= "table" or vu[v] then return 0 end
    vu[v] = true
    local n = 0
    for k, val in pairs(v) do n = n + poids(k, vu) + poids(val, vu) end
    return n
end
dire("  ce PNJ blesse pese", poids(golem), "octets")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
