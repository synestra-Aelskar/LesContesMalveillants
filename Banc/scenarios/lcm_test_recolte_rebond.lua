-- Un clic, un jet ; et un point « Infini » ne s'epuise jamais (le MJ,
-- 2 novembre 2026 : « un seul clic a provoqué quatre tentatives », puis
-- « ce point ne donne plus rien » sur un point infini).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("ressources", { id = "pierre_rebond", label = "Pierre témoin" })
__declencher("PLAYER_LOGIN")
__personnage()
local R = LCM.Recolte

dire("== un point infini ne s'epuise pas")
-- Une definition temoin : une ressource SANS regeneration, limite 0.
local def = { id = "def_rebond", label = "Filon témoin", limite = 0,
    ressources = { { entree = "ressources/pierre_rebond", min = 1, max = 1, chance = 100 } } }
local point = { id = "p_rebond", def = def.id, usages = 0 }
local lots, etat = R.Tirer(point, def)
attendu("première prise", lots and #lots, 1)
point.usages, point.consomme, point.prochain = etat.usages, etat.consomme, etat.prochain
attendu("  la ressource n'est pas consommée", point.consomme[1], nil)
attendu("  toujours disponible", R.Disponible(point, def), true)
lots = R.Tirer(point, def)
attendu("seconde prise", lots and #lots, 1)
-- Un point deja marque consomme (sauvegarde d'avant le correctif) redonne.
point.consomme = { [1] = true }
attendu("un point marqué d'avant redonne", R.Disponible(point, def), true)
attendu("  et jamais épuisé", R.Epuise(point, def), false)
local limite = { id = "def_limite", label = "Filon limité", limite = 3,
    ressources = def.ressources }
local p2 = { id = "p_limite", def = limite.id, usages = 0 }
local _, etat2 = R.Tirer(p2, limite)
attendu("hors infini, la ressource reste consommée", etat2.consomme[1], true)

dire("== un clic, un jet")
local appels = 0
local vraiJet = R.Jet
R.Jet = function() appels = appels + 1
    return { reussi = false, jet = 3, bonus = 0, total = 3, dd = 10, min = 1, max = 15, fatigue = 0 } end
local vraiProche = R.Proche
local ici = { id = "p_clic", def = "def_clic", usages = 0 }
R.definitions["def_clic"] = { id = "def_clic", label = "Filon clic", dd = 10, limite = 0,
    ressources = def.ressources }
R.points["p_clic"] = ici
R.Proche = function() return ici end
local vraiAnnoncer = LCM.Reseau.Envoyer
R.Tenter("p_clic")
R.Tenter("p_clic")
R.Tenter("p_clic")
attendu("trois appels dans la seconde : un seul jet", appels, 1)
__avancerTemps(1.2)
R.Tenter("p_clic")
attendu("une seconde après : on peut retenter", appels, 2)
R.attenteGPS = "p_clic"
__avancerTemps(2)
R.Tenter("p_clic")
attendu("pendant la mesure GPS : rien ne part", appels, 2)
R.attenteGPS = nil
R.Jet, R.Proche = vraiJet, vraiProche
R.points["p_clic"], R.definitions["def_clic"] = nil, nil

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
