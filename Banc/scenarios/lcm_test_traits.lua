-- Traits, bonus, avantage, jets.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local moi = LCM.Entities.Self()

dire("== la regle : pas de bonus aux primaires")
local interdit = pcall(function()
    LCM.Traits.Add({ id = "triche", label = "Triche", bonus = { force = 5 } })
end)
attendu("un trait qui vise la Force est refuse", interdit, false)
local permis = pcall(function()
    LCM.Traits.Add({ id = "test_ok", label = "Test", bonus = { course = 2 } })
end)
attendu("un trait qui vise une expertise passe", permis, true)

dire("== porter un trait")
attendu("au depart", #LCM.Traits.Owned(moi), 0)
LCM.Traits.Grant(moi, "escalade_jungle")
attendu("apres attribution", #LCM.Traits.Owned(moi), 1)
attendu("deux fois le meme", LCM.Traits.Grant(moi, "escalade_jungle"), false)
attendu("bonus en escalade", LCM.Traits.Bonus(moi, "escalade"), 3)
attendu("bonus ailleurs", LCM.Traits.Bonus(moi, "course"), 0)

dire("== avantage")
attendu("accorde en escalade", LCM.Traits.Advantage(moi, "escalade") ~= nil, true)
attendu("pas en course", LCM.Traits.Advantage(moi, "course"), "nil")

dire("== jets")
math.randomseed(1)
LCM.Entities.Set_Value(moi, "escalade", 4)
local r = LCM.Roll.Field(moi, "escalade")
attendu("un seul de sans avantage", #r.jets, 1)
attendu("la valeur entre dans le total", r.valeur, 4)
attendu("le bonus de trait aussi", r.bonus, 3)
attendu("total coherent", r.total, r.garde + 4 + 3)

local ra = LCM.Roll.Field(moi, "escalade", { avantage = true })
attendu("deux des avec avantage", #ra.jets, 2)
attendu("on garde le meilleur", ra.garde, math.max(ra.jets[1], ra.jets[2]))
attendu("le trait est nomme", ra.trait.label, "Escalade de la jungle")
dire("   " .. LCM.Roll.Describe(ra))

dire("== cocher la case sans trait ne donne rien")
local rc = LCM.Roll.Field(moi, "course", { avantage = true })
attendu("un seul de", #rc.jets, 1)
attendu("et on le dit", rc.avantageRefuse, true)

dire("== retirer le trait")
LCM.Traits.Revoke(moi, "escalade_jungle")
attendu("plus de bonus", LCM.Traits.Bonus(moi, "escalade"), 0)
attendu("plus rien en sauvegarde", moi.traits, "nil")

dire("== formules de fatigue et d'initiative")
LCM.Entities.Set_Value(moi, "niveau", 5)
LCM.Entities.Set_Value(moi, "esprit", 8)
LCM.Entities.Set_Value(moi, "constitution", 6)
LCM.Entities.Set_Value(moi, "perception", 10)
LCM.Entities.Set_Value(moi, "endurance", 3)
LCM.Entities.Set_Value(moi, "sec_fatigue", 2)
-- Template : 15 + 2x5 + 8 + 2x6 + Endurance totale (3 + 0,35x6 -> 5) + 3x2 = 56
local f = LCM.Entities.Gauge(moi, "fatigue")
attendu("fatigue max", f.max, 56)
-- Template : 0 + 5/2 + 8/2 + 10/2 = 11,5 -> 11
attendu("initiative", LCM.Entities.Get_Value(moi, "initiative"), 11)
local ri = LCM.Roll.Field(moi, "initiative")
attendu("le jet d'initiative part de la formule", ri.valeur, 11)

dire("== un jet ne peut viser qu'un champ lancable")
local _, err = LCM.Roll.Field(moi, "force")
attendu("la Force ne se lance pas", err, "ce champ ne se lance pas")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
