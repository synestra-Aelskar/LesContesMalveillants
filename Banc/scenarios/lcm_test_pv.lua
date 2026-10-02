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
-- Template : 2 + 1,5 x 5 + 3 x 4 + 6 x (2 + 6 x 0,25) = 42,5 -> 42
attendu("niveau 5, const 6, vitalite 4", LCM.Entities.Get_Value(moi, "pv_max"), 42)

dire("== les PV courants = PV max - blessures, jamais stockes")
local courant, maximum = LCM.Body.Totals(moi)
attendu("intact", courant .. "/" .. maximum, "42/42")
LCM.Body.Damage(moi, "bras", 2)
LCM.Body.Damage(moi, "tete", 1)
courant, maximum = LCM.Body.Totals(moi)
attendu("apres 3 degats", courant .. "/" .. maximum, "39/42")

dire("== saisie directe des PV d une partie")
LCM.Body.SetCurrent(moi, "buste", 1)
local etat = LCM.Body.State(moi)
for _, p in ipairs(etat) do
    if p.id == "buste" then attendu("buste fixe a 1", p.current, 1) end
end

dire("== monter de niveau ne dereglee pas les blessures")
LCM.Entities.Set_Value(moi, "niveau", 10)
-- 2 + 1,5 x 10 + 3 x 4 + 6 x (2 + 6 x 0,25) = 50
attendu("nouveau maximum", LCM.Entities.Get_Value(moi, "pv_max"), 50)
local c2, m2 = LCM.Body.Totals(moi)
attendu("les blessures sont conservees", m2 - c2 >= 3, true)
attendu("et le total suit", m2, 50)

dire("== un PNJ aberrant")
local boss = LCM.Entities.Create("boss", "Chose", "npc")
LCM.Entities.Set_Value(boss, "morphologie", "aberration")
-- Ses PV sortent de sa feuille comme ceux de tout le monde : une constitution
-- de monstre, et rien d'autre a regler.
LCM.Entities.Set_Value(boss, "niveau", 20)
LCM.Entities.Set_Value(boss, "constitution", 30)
local etatBoss, morpho = LCM.Body.State(boss)
attendu("morphologie", morpho.id, "aberration")
attendu("zones", #etatBoss, 19)
-- Chaque zone vaut 30 % du total, quelle que soit la morphologie.
local totalBoss = LCM.Body.MaxTotal(boss)
attendu("une zone", etatBoss[1].max, math.floor(totalBoss * LCM.Equilibrage.pv.parZone))
attendu("et il a de quoi encaisser", totalBoss > 200, true)
dire("  ses zones :")
local parCategorie = {}
for _, p in ipairs(etatBoss) do
    parCategorie[p.part.category] = (parCategorie[p.part.category] or 0) + 1
end
for categorie, n in pairs(parCategorie) do dire("    ", categorie, "x" .. n) end

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
