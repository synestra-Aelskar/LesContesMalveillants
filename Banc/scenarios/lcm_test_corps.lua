-- Morphologies, zones du corps, blessures (regle du template : chaque zone
-- vaut 30 % des PV max ; PV courants = PV max - blessures).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit

dire("== morphologies declarees")
attendu("nombre", #LCM.Morphologies.list, 4)
for _, m in ipairs(LCM.Morphologies.list) do
    local noms = {}
    for _, p in ipairs(m.parts) do noms[#noms + 1] = p.label end
    dire(string.format("   %-12s %2d zones : %s", m.id, #m.parts, table.concat(noms, ", ")))
end

dire("== l'humanoide suit le template : cinq zones")
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "humain")
-- Plus de « PV max impose » : les PV viennent de la feuille, comme en jeu.
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.Set_Value(moi, "constitution", 4)
local total = LCM.Body.MaxTotal(moi)
local parZone = math.floor(total * LCM.Equilibrage.pv.parZone)
dire(string.format("   PV max calcules : %d, soit %d par zone", total, parZone))
local etat, morpho = LCM.Body.State(moi)
attendu("morphologie retenue", morpho.id, "humanoide")
local noms = {}
for _, p in ipairs(etat) do noms[#noms + 1] = p.label end
attendu("zones", table.concat(noms, ", "), "Tête, Torse, Bras, Jambes, Internes")
for _, p in ipairs(etat) do
    attendu(p.label .. " : 30 % du total", p.max, parZone)
    attendu(p.label .. " : icone", p.part.icone ~= nil, true)
    attendu(p.label .. " : description", (p.part.description or "") ~= "", true)
end

dire("== blessures")
LCM.Body.Damage(moi, "bras", 3)
local courant, maximum = LCM.Body.Totals(moi)
attendu("apres 3 degats au bras", courant .. "/" .. maximum, (total - 3) .. "/" .. total)
LCM.Body.Damage(moi, "bras", 99)
for _, p in ipairs(LCM.Body.State(moi)) do
    if p.id == "bras" then
        attendu("une zone ne descend pas sous zero", p.current, 0)
        attendu("et sa blessure plafonne a son maximum", p.wound, p.max)
    end
end
attendu("les PV globaux suivent", select(1, LCM.Body.Totals(moi)), total - parZone)
LCM.Body.Damage(moi, "tete", 10)
LCM.Body.Damage(moi, "buste", 10)
LCM.Body.Damage(moi, "jambe", 10)
-- Quatre zones a fond (bras, tete, torse, jambes), chacune plafonnee a sa
-- part : les zones valent ensemble plus que le total, donc on passe sous zero.
attendu("sous zero quand tout est touche", select(1, LCM.Body.Totals(moi)),
    total - 4 * parZone)
LCM.Body.HealAll(moi)
attendu("soigne", select(1, LCM.Body.Totals(moi)), total)
local n = 0
for _ in pairs(moi.body or {}) do n = n + 1 end
attendu("un corps intact ne laisse rien en sauvegarde", n, 0)

dire("== d'autres morphologies")
LCM.Entities.Set_Value(moi, "morphologie", "quadrupede")
local etatLoup, morphoLoup = LCM.Body.State(moi)
attendu("quadrupede", morphoLoup.id, "quadrupede")
attendu("zones", #etatLoup, 8)
attendu("chacune 30 %", etatLoup[1].max, parZone)

LCM.Entities.Set_Value(moi, "morphologie", "aile")
local ailes = 0
for _, p in ipairs(LCM.Body.State(moi)) do if p.part.category == "aile" then ailes = ailes + 1 end end
attendu("deux ailes", ailes, 2)

dire("== une race inconnue retombe sur l'humanoide")
LCM.Entities.Set_Value(moi, "morphologie", nil) LCM.Entities.Set_Value(moi, "race", "dragon_inexistant")
attendu("morphologie de repli", select(2, LCM.Body.State(moi)).id, "humanoide")

dire("== un PNJ quadrupede")
local loup = LCM.Entities.Create("pnj_loup", "Loup des cendres", "npc")
LCM.Entities.Set_Value(loup, "morphologie", "quadrupede")
LCM.Entities.Set_Value(loup, "niveau", 8)
LCM.Entities.Set_Value(loup, "constitution", 7)
local totalLoup = LCM.Body.MaxTotal(loup)
LCM.Body.Damage(loup, "jambe_1", 5)
local c, m = LCM.Body.Totals(loup)
attendu("son corps", c .. "/" .. m, (totalLoup - 5) .. "/" .. totalLoup)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
