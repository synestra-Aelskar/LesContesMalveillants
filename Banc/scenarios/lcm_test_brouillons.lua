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
LCM.Brouillons.Set("races", { id = "gobelin", label = "Gobelin", morphology = "humanoide" })

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit

dire("== les brouillons sont jouables tout de suite")
attendu("le trait existe", LCM.Traits.Get("oeil_du_faucon") ~= nil, true)
attendu("la race aussi", LCM.Races.Get("gobelin") ~= nil, true)
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

dire("== la synchro entre maitres du jeu")
-- On est deux a ecrire en seance : ce que l'un cree part TOUT DE SUITE chez
-- l'autre et s'y applique sans rien demander (5 octobre 2026).
local B2 = LCM.Brouillons
local avant = #__envois

-- Emission : ecrire un brouillon met un message sur le reseau.
B2.Enregistrer("traits", { id = "souffle_sync", label = "Souffle partagé", cout = 1 }, true)
local partis = 0
for i = avant + 1, #__envois do
    if tostring(__envois[i].message or ""):find("brouillon") then partis = partis + 1 end
end
attendu("l'ecriture part sur le reseau", partis > 0, true)

-- Reception : ce qui arrive s'applique, sans question.
B2.Supprimer("traits", "souffle_sync")
attendu("retire chez nous", B2.Get("traits", "souffle_sync"), nil)
local paquet = LCM.Reseau.Encoder({ f = "traits",
    e = { id = "souffle_sync", label = "Souffle partagé", cout = 1 } })
LCM.Reseau.Recevoir("Akriaxx", "7:1:1:brouillon|" .. paquet)
attendu("arrive chez nous tout seul", B2.Get("traits", "souffle_sync") ~= nil, true)
attendu("et devient jouable", LCM.Traits.Get("souffle_sync") ~= nil, true)

-- Ce qui arrive ne REPART pas : sinon deux ateliers se le renvoient sans fin.
local avantRenvoi = #__envois
LCM.Reseau.Recevoir("Akriaxx", "8:1:1:brouillon|" .. paquet)
local renvois = 0
for i = avantRenvoi + 1, #__envois do
    if tostring(__envois[i].message or ""):find("brouillon") then renvois = renvois + 1 end
end
attendu("rien n'est renvoye", renvois, 0)

-- Une suppression voyage aussi.
LCM.Reseau.Recevoir("Akriaxx", "9:1:1:brouillon-|" .. LCM.Reseau.Encoder({ f = "traits", id = "souffle_sync" }))
attendu("la suppression arrive aussi", B2.Get("traits", "souffle_sync"), nil)

-- Un JOUEUR ne recoit rien : il n'a pas d'atelier.
local etaitCharge = __addonsCharges["LesContesMalveillants_MJ"]
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = nil
attendu("on joue bien en joueur", LCM.IsMaster(), false)
LCM.Reseau.Recevoir("Akriaxx", "10:1:1:brouillon|" .. paquet)
attendu("un joueur n'en herite pas", B2.Get("traits", "souffle_sync"), nil)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = etaitCharge

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
