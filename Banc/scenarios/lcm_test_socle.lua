-- Socle : schema, entites, valeurs, jauges, commandes.
local function dire(...) print(table.concat({...}, " ")) end
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
    return ok
end

-- Connexion simulee
__declencher("PLAYER_LOGIN")

dire("== schema")
attendu("champs declares", LCM.Schema.Count(), 108)
attendu("onglets", #LCM.Schema.Tabs(), 7)
attendu("le champ armure existe", LCM.Schema.Field("armure") ~= nil, true)
attendu("son type", LCM.Schema.Field("armure").kind, "gauge")
attendu("un champ inconnu", LCM.Schema.Field("nexistepas"), "nil")

dire("== entites")
local moi = LCM.Entities.Self()
attendu("mon identite", moi.id, "Reika-Apertus")
attendu("mon type", moi.kind, "player")
local golem = LCM.Entities.Create("pnj_golem", "Golem de glace", "npc")
attendu("pnj cree", golem.name, "Golem de glace")
attendu("meme feuille pour les deux", LCM.Schema.Count(), 108)

dire("== valeurs")
attendu("force par defaut", LCM.Entities.Get_Value(moi, "force"), 0)
LCM.Entities.Set_Value(moi, "force", 3)
LCM.Entities.Set_Value(golem, "force", 12)
attendu("ma force", LCM.Entities.Get_Value(moi, "force"), 3)
attendu("celle du golem", LCM.Entities.Get_Value(golem, "force"), 12)
attendu("un champ inconnu est refuse", LCM.Entities.Set_Value(moi, "nexistepas", 1), false)

dire("== la sauvegarde ne garde que l'ecart")
local n = 0
for _ in pairs(moi.values) do n = n + 1 end
attendu("valeurs stockees pour moi", n, 1)
LCM.Entities.Set_Value(moi, "force", 0)
n = 0
for _ in pairs(moi.values) do n = n + 1 end
attendu("revenu au defaut : plus rien de stocke", n, 0)

dire("== jauges")
local pv = LCM.Entities.Gauge(moi, "armure")
attendu("armure au max par defaut", pv.current .. "/" .. pv.max, "1000/1000")
LCM.Entities.SetGauge(moi, "armure", 12)
pv = LCM.Entities.Gauge(moi, "armure")
attendu("apres depense", pv.current .. "/" .. pv.max, "12/1000")
LCM.Entities.SetGauge(golem, "armure", 80, 80)
local pvGolem = LCM.Entities.Gauge(golem, "armure")
attendu("le golem a son propre maximum", pvGolem.current .. "/" .. pvGolem.max, "80/80")
attendu("sans toucher au schema", LCM.Schema.Field("armure").max, 1000)
LCM.Entities.SetGauge(moi, "armure", 99999)
pv = LCM.Entities.Gauge(moi, "armure")
attendu("on ne depasse pas le maximum", pv.current, 1000)

dire("== droits")
attendu("compagnon MJ present", LCM.IsMaster(), true)

dire("== commandes")
local avant = #__sorties
SlashCmdList.LCM("version")
local ligne = __sansCouleur(__sorties[#__sorties])
dire("  ->", ligne)
attendu("la commande repond", #__sorties > avant, true)

dire("== poids d'un PNJ")
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
dire("  un PNJ complet pese", poids(golem), "octets")
