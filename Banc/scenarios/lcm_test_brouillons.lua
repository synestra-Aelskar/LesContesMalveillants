-- Brouillons du MJ : creation en seance, prise en compte immediate.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Le MJ cree un trait AVANT la connexion (comme s'il venait d'une seance
-- precedente, deja en sauvegarde).
LCM.Brouillons.Set("traits", {
    id = "oeil_du_faucon",
    label = "Oeil du faucon",
    description = "Repere ce que les autres manquent.",
    bonus = { vue = 2, investigation = 1 },
    avantage = { "vue" },
})
LCM.Brouillons.Set("races", { id = "orc", label = "Orc", morphology = "humanoide" })

__declencher("PLAYER_LOGIN")

dire("== les brouillons sont jouables tout de suite")
attendu("le trait existe", LCM.Traits.Get("oeil_du_faucon") ~= nil, true)
attendu("la race aussi", LCM.Races.Get("orc") ~= nil, true)
attendu("comptage", LCM.Brouillons.Count(), 2)

local moi = LCM.Entities.Self()
LCM.Traits.Grant(moi, "oeil_du_faucon")
attendu("bonus en vue", LCM.Traits.Bonus(moi, "vue"), 2)
attendu("bonus en investigation", LCM.Traits.Bonus(moi, "investigation"), 1)
attendu("avantage en vue", LCM.Traits.Advantage(moi, "vue") ~= nil, true)

dire("== un brouillon fautif est refuse, pas avale")
local avant = #__sorties
LCM.Brouillons.Set("traits", { id = "triche", label = "Triche", bonus = { force = 9 } })
-- il ne sera declare qu'au prochain WhenReady ; on force la declaration ici
local ok = pcall(LCM.Traits.Add, LCM.Brouillons.Get("traits", "triche"))
attendu("refus d un bonus primaire", ok, false)

dire("== une race inconnue en morphologie est refusee")
local ok2 = pcall(LCM.Races.Add, { id = "chimere", label = "Chimere", morphology = "nexistepas" })
attendu("refus", ok2, false)

dire("== ce qui est deja publie est signale")
LCM.Brouillons.Set("traits", {
    id = "escalade_jungle", label = "Escalade de la jungle (doublon)",
    bonus = { escalade = 1 },
})
local publies = LCM.Brouillons.Published()
attendu("le doublon est repere", #publies, 1)
dire("   ->", publies[1])

dire("== la commande /lcm brouillons")
local n = #__sorties
SlashCmdList.LCM("brouillons")
attendu("elle repond", #__sorties > n, true)
for i = n + 1, #__sorties do dire("   " .. __sansCouleur(__sorties[i])) end

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
