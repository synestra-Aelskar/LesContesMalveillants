-- Formule de PV max et somme des parties.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "race", "humain")

dire("== formule : base 2 + 1.5/niveau + 0.25/constitution + 3/vitalite")
LCM.Entities.Set_Value(moi, "niveau", 1)
LCM.Entities.Set_Value(moi, "constitution", 0)
LCM.Entities.Set_Value(moi, "sec_vitalite", 0)
attendu("niveau 1, rien d autre", LCM.Entities.Get_Value(moi, "pv_max"), 3)

LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.Set_Value(moi, "constitution", 6)
LCM.Entities.Set_Value(moi, "sec_vitalite", 4)
-- 2 + 7.5 + 1.5 + 12 = 23
attendu("niveau 5, const 6, vitalite 4", LCM.Entities.Get_Value(moi, "pv_max"), 23)

dire("== les PV courants sont la somme des parties, jamais stockes")
local courant, maximum = LCM.Body.Totals(moi)
attendu("intact", courant .. "/" .. maximum, "23/23")
LCM.Body.Damage(moi, "bras_1", 2)
LCM.Body.Damage(moi, "tete", 1)
courant, maximum = LCM.Body.Totals(moi)
attendu("apres 3 degats", courant .. "/" .. maximum, "20/23")

dire("== saisie directe des PV d une partie")
LCM.Body.SetCurrent(moi, "buste", 1)
local etat = LCM.Body.State(moi)
for _, p in ipairs(etat) do
    if p.id == "buste" then attendu("buste fixe a 1", p.current, 1) end
end

dire("== monter de niveau ne dereglee pas les blessures")
LCM.Entities.Set_Value(moi, "niveau", 10)
-- 2 + 1.5*10 + 0.25*6 + 3*4 = 30.5 -> 30
attendu("nouveau maximum", LCM.Entities.Get_Value(moi, "pv_max"), 30)
local c2, m2 = LCM.Body.Totals(moi)
attendu("les blessures sont conservees", m2 - c2 >= 3, true)
attendu("et le total suit", m2, 30)

dire("== un PNJ aux PV imposes")
local boss = LCM.Entities.Create("boss", "Chose", "npc")
LCM.Entities.Set_Value(boss, "morphologie", "aberration")
LCM.Entities.Set_Value(boss, "pv_max_override", 400)
local etatBoss, morpho = LCM.Body.State(boss)
attendu("morphologie", morpho.id, "aberration")
attendu("parties", #etatBoss, 19)
local somme = 0
for _, p in ipairs(etatBoss) do somme = somme + p.max end
attendu("somme des parties", somme, 400)
dire("  ses parties :")
local parCategorie = {}
for _, p in ipairs(etatBoss) do
    parCategorie[p.part.category] = (parCategorie[p.part.category] or 0) + 1
end
for categorie, n in pairs(parCategorie) do dire("    ", categorie, "x" .. n) end

dire("== placement sur la silhouette")
local _, m = LCM.Body.State(moi)
for _, p in ipairs(m.parts) do
    dire(string.format("    %-14s rangee %d, place %d/%d%s", p.label, p.row, p.slot or 0, p.slots or 0, p.inner and "  (interne)" or ""))
end

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))

dire("== silhouette d'une harpie (ailes au bord)")
local h = LCM.Entities.Create("harpie_test", "Harpie", "npc")
LCM.Entities.Set_Value(h, "morphologie", "aile")
local _, mh = LCM.Body.State(h)
local rangee2 = {}
for _, p in ipairs(mh.parts) do
    if p.row == 2 and not p.inner then rangee2[p.slot] = p.label end
end
dire("    rangee 2 : " .. table.concat(rangee2, " | "))
