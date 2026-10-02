-- Recevoir une action : « Vous etes la cible de », la defense, la repartition,
-- le compte rendu.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end
local function dernierEnvoi() return __envois[#__envois] end

__declencher("PLAYER_LOGIN")
local A, E, B = LCM.Actions, LCM.Entities, LCM.Body
local U = LCM.UI.Resolution
local moi = E.Self()
E.Set_Value(moi, "constitution", 6)
E.Set_Value(moi, "resi_tranchant", 2)
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })

local function attaque(rand, extra)
    local v = { ["Total Normal"] = "8", ["Total Critique"] = "12", ["Type Physique"] = "Tranchant",
                ["Type Elementaire"] = "?", ["Rand Nom"] = "Adresse", ["Rand Résultat"] = tostring(rand),
                ["Perce armure"] = "50", Zones = "#sante #bouclier #armure" }
    local p = { t = "t1", n = "Attaque", a = "Nytherah-Apertus", rp = "Nytherah", v = v }
    for k, x in pairs(extra or {}) do p[k] = x end
    return p
end
local function blessures()
    local n = 0
    for _, z in ipairs(B.State(moi, B.MaxTotal(moi))) do n = n + z.wound end
    return n
end

dire("== la nature trouve sa resolution")
attendu("Attaque -> Defense", A.ResolutionPour("Attaque").id, "defense_auto_v3")
attendu("Perce armure aussi", A.ResolutionPour("Perce-armure").id, "defense_auto_v3")
attendu("jamais une entree d'emission", A.ResolutionPour("Attaque").emission, false)

dire("== recue d'un etranger : ignoree")
recevoir("Etranger-Apertus", "act", attaque(0))
attendu("rien", U.recu == nil or not U.recu:IsShown(), true)

dire("== « Vous etes la cible de : »")
recevoir("Nytherah-Apertus", "act", attaque(99))
local P = U.recu
attendu("affichee", P:IsShown(), true)
attendu("la nature et l'auteur", P.sous:GetText():find("Attaque", 1, true) ~= nil and P.sous:GetText():find("Nytherah", 1, true) ~= nil, true)
attendu("un bouton Resoudre", P.resoudre:IsShown(), true)

dire("== Encaisser : un coup critique (rand adverse 99)")
P.resoudre:Click()
local C = U.choix
attendu("la reaction", C.titre:GetText(), "Réaction")
attendu("apercu du coup normal", C.apercus[1].valeur:GetText(), "1")
attendu("apercu du critique", C.apercus[2].valeur:GetText(), "5")
attendu("le perce-armure", C.apercus[3].titre:GetText(), "Perce-armure 50%")
attendu("Parer coute", C.boutons[2].label:GetText():find("( 1 PA - 1 PF )", 1, true) ~= nil, true)
attendu("l'aide au survol", C.boutons[1].spec.aide:find("Encaisser", 1, true) ~= nil, true)
C.boutons[1]:Click()
attendu("on choisit son jet", C.titre:GetText(), "Opposer avec")
attendu("avec sa plage", C.boutons[1].label:GetText():find("0-15", 1, true) ~= nil, true)
C.boutons[1]:Click()
attendu("le message", C.titre:GetText(), "Encaissement critique")
C.boutons[1]:Click()
local R = U.repartition
attendu("la repartition s'ouvre", R:IsShown(), true)
attendu("le degat critique net", R.montant, 5)
attendu("le perce-armure impose", R.minimum, 3)
attendu("#armure n'a pas de jauge : dit", R.aide.texte:GetText():find("#armure", 1, true) ~= nil, true)
attendu("on ne peut pas appliquer sans tout placer", R.appliquer:IsEnabled(), false)
-- Tout sur les Boucliers (vides) : impossible ; deux en tete, trois au torse.
local boucliers
for i, c in ipairs(R.cases) do if c.id == "armure" then boucliers = i end end
R.lignes[boucliers].tout:Click()
attendu("des boucliers vides n'absorbent rien", R.valeurs[boucliers], 0)
R.lignes[1].plus:Click() R.lignes[1].plus:Click()
attendu("perce-armure pas encore atteint", R.appliquer:IsEnabled(), false)
R.lignes[2].tout:Click()
attendu("reste 0", R.reste.valeur:GetText(), "0")
attendu("on peut appliquer", R.appliquer:IsEnabled(), true)
local avant = blessures()
local n = #__envois
R.appliquer:Click()
attendu("les blessures sont posees", blessures(), avant + 5)
local cr = __envois[n + 1]
attendu("le compte rendu part a l'attaquant", cr and cr.cible, "Nytherah-Apertus")
attendu("il dit ce qui s'est passe", cr and cr.message:find("Encaissement critique", 1, true) ~= nil, true)

dire("== Parer : rand adverse 0, la parade reussit")
B.HealAll(moi)
local pa, pf = E.Gauge(moi, "pa").current, E.Gauge(moi, "fatigue").current
recevoir("Nytherah-Apertus", "act", attaque(0))
U.recu.resoudre:Click()
C.boutons[2]:Click()
attendu("la fatigue est payee tout de suite", E.Gauge(moi, "fatigue").current, pf - 1)
C.boutons[1]:Click()
attendu("parade reussie", C.titre:GetText():find("Parade", 1, true) ~= nil, true)
C.boutons[1]:Click()
attendu("aucun degat : pas de repartition", R:IsShown(), false)
attendu("aucune blessure", blessures(), 0)
attendu("le PA : paye, ou rembourse sur un critique", E.Gauge(moi, "pa").current <= pa, true)

dire("== deux actions : la seconde attend la premiere")
recevoir("Nytherah-Apertus", "act", attaque(0, { t = "a1" }))
recevoir("Nytherah-Apertus", "act", attaque(0, { t = "a2", n = "Brise-armure" }))
attendu("la premiere s'affiche", U.recu.recu.paquet.t, "a1")
U.Ignorer()
attendu("puis la seconde", U.recu:IsShown() and U.recu.recu.paquet.t, "a2")
U.Ignorer()
attendu("plus rien", U.recu:IsShown(), false)

dire("== une nature sans resolution")
recevoir("Nytherah-Apertus", "act", attaque(0, { n = "Chant" }))
attendu("on le dit", U.recu.resume:GetText():find("Aucune résolution", 1, true) ~= nil, true)
attendu("pas de Resoudre", U.recu.resoudre:IsShown(), false)
U.recu.ignorer:Click()

dire("== un bouclier recu")
recevoir("Nytherah-Apertus", "act", { t = "b1", n = "Bouclier", a = "Nytherah-Apertus", v = { Bouclier = "7" } })
U.recu.resoudre:Click()
attendu("le message", C.titre:GetText(), "Bouclier reçu")
C.boutons[1]:Click()
attendu("les Boucliers montent", E.Gauge(moi, "armure").current, 7)

dire("== un PNJ vise : le MJ resout sur sa fiche")
local garde = LCM.Incarnation.Instancier(LCM.PNJ.list[1].id, "Garde")
-- Un coup fort : le garde a sa propre constitution, qui absorbe les petits.
local fort = attaque(99, { t = "p1", p = garde.id, pn = "Garde" })
fort.v["Total Critique"] = "60"
recevoir("Nytherah-Apertus", "act", fort)
attendu("le PNJ est nomme", U.recu.sous:GetText():find("[PNJ : Garde]", 1, true) ~= nil, true)
U.recu.resoudre:Click()
C.boutons[1]:Click() C.boutons[1]:Click() C.boutons[1]:Click()
attendu("la repartition porte sur le garde", R.ctx.entity, garde)
R.lignes[1].tout:Click()
for i = 2, #R.cases do if R.appliquer:IsEnabled() then break end R.lignes[i].tout:Click() end
R.appliquer:Click()
local blesse = 0
for _, z in ipairs(B.State(garde, B.MaxTotal(garde))) do blesse = blesse + z.wound end
attendu("le garde est blesse, pas moi", blesse > 0 and blessures() == 0, true)

dire("== un joueur ne resout pas pour un PNJ")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
attendu("refuse", A.Recevoir(attaque(0, { p = garde.id }), "Nytherah-Apertus"), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
