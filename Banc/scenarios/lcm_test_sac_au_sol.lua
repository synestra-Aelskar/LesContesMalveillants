-- Un sac lache au sol (16 octobre 2026, Core/SacsAuSol.lua) : glisse hors de
-- l'inventaire, il se pose la ou l'on est, AVEC son contenu, et devient un
-- coffre que n'importe qui ouvre, ou l'on prend quelques objets, ou que l'on
-- ramasse en entier pour se l'equiper.
--
-- Sans MJ, c'est une donnee « fantome » : celui qui l'a lache la garde et
-- arbitre ; s'il part, un autre joueur reprend la garde ; un MJ, des qu'il la
-- voit, en fait une vraie entree « Coffre » (decisions du MJ, le meme jour).
--
-- Contenu TEMOIN : deux sacs, une sacoche, deux ressources.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("sacs", { id = "sac_lache", label = "Sac témoin", nature = "sac", places = 6 })
LCM.Brouillons.Set("sacs", { id = "sac_reserve", label = "Sac de réserve", nature = "sac", places = 6 })
LCM.Brouillons.Set("ressources", { id = "pierre_sol", label = "Pierre" })
LCM.Brouillons.Set("ressources", { id = "herbe_sol", label = "Herbe" })
local PIERRE, HERBE = "ressources/pierre_sol", "ressources/herbe_sol"

__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
local MOI = LCM.PlayerId()
local I, Sol, C = LCM.Inventaire, LCM.SacsAuSol, LCM.Coffres
__groupe({ MOI, "Syn-Apertus", "Zed-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")
__position(10, 10, 0)

local function Recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end
local function Envoye(sujet, depuis)
    for i = #__envois, (depuis or 0) + 1, -1 do
        if tostring(__envois[i].message):find(":" .. sujet:gsub("%p", "%%%0") .. "|", 1) then return __envois[i] end
    end
end
local function Combien(ref) return LCM.Prix.Avoir(moi, ref) end
-- Une reponse de .gps a cette position, comme le guetteur de chat la noterait.
-- Ouvrir ou ramasser exige une mesure recente des trois axes depuis le
-- 17 octobre 2026 (Core/Coffres.lua) ; sans elle, le geste part demander le
-- .gps et n'aboutit pas dans le banc (21 octobre 2026).
local function Gps(x, y, z)
    LCM.DeplacementForce.NoterGPS(string.format("Map: 585 (Magisters' Terrace) Zone: 0 ( <unknown> ), "
        .. "Area: 0 ( <unknown> ), Phase: 158070, X: %.6f, Y: %.6f, Z: %.6f, O: 1.904451", x, y, z))
end
local function SeulSac()
    local id, sol = next(Sol.sacs)
    return id, sol
end

-- On joue un JOUEUR : sans MJ, le sac reste un fantome.
local mjCharge = __addonsCharges["LesContesMalveillants_MJ"]
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = nil
attendu("on joue en joueur", LCM.IsMaster(), false)

I.Poser(moi, "sacs", 1, "sac_lache")
I.Poser(moi, "sacs", 2, "sac_reserve")
I.Ranger(moi, "sacs", 1, 1, PIERRE, 3)
I.Ranger(moi, "sacs", 1, 2, HERBE, 2)

dire("== le lacher hors de l'inventaire, avec confirmation")
LCM.UI.Inventaires.Basculer()
local Inv = LCM.UI.Inventaires
local avant = #__envois
Inv.PoserAuSol({ nom = "Sac témoin", origine = { onglet = "sacs", index = 1, emplacement = true } })
attendu("on demande d'abord", I.Emplacement(moi, "sacs", 1) ~= nil, true)
Inv.confirmationSol.oui:Click()
attendu("le sac a quitte l'inventaire", I.Emplacement(moi, "sacs", 1), nil)
local id, sol = SeulSac()
attendu("il est au sol", sol ~= nil, true)
attendu("  a son nom", sol and sol.label:find("^Sac témoin de ") ~= nil, true)
attendu("  avec tout son contenu", sol and (#sol.objets .. ":" .. sol.objets[1].quantite .. ":" .. sol.objets[2].quantite), "2:3:2")
attendu("  garde par celui qui l'a lache", sol and sol.gardien, MOI)
attendu("le groupe en est averti", Envoye(Sol.SUJETS.etat, avant) ~= nil, true)
attendu("c'est un coffre qu'on peut ouvrir", C.points[id] ~= nil and C.definitions[id].coffre.sac, "sac_lache")

dire("== quelqu'un y prend un objet : le gardien arbitre")
avant = #__envois
Recevoir("Syn-Apertus", C.SUJETS.action, { i = id, a = "prendre", e = HERBE, q = 1 })
attendu("une herbe en moins", sol.objets[2].quantite, 1)
attendu("Syn recoit sa part", Envoye(C.SUJETS.etat, avant) ~= nil, true)
attendu("la copie du groupe suit", sol.version, 2)

dire("== le gardien part : la garde passe")
-- Un sac garde par Syn, puis Syn se deconnecte. Reika est le plus petit nom
-- en ligne (Zed est l'autre) : elle reprend la garde.
Recevoir("Syn-Apertus", Sol.SUJETS.etat, { i = "solsyn", n = "Sacoche de Syn", b = "sac_reserve", s = 6,
    o = { { e = PIERRE, q = 5 } }, x = 10, y = 10, r = sol.position.source, k = sol.position.carte,
    a = "Syn-Apertus", g = "Syn-Apertus", v = 4 })
attendu("on garde une copie", Sol.sacs.solsyn and Sol.sacs.solsyn.gardien, "Syn-Apertus")
__deconnecter("Syn-Apertus")
Sol.Veiller()
attendu("la garde passe a Reika", Sol.sacs.solsyn.gardien, MOI)
attendu("  plus recente", Sol.sacs.solsyn.version, 5)
Recevoir("Syn-Apertus", Sol.SUJETS.etat, { i = "solsyn", n = "Sacoche de Syn", b = "sac_reserve", s = 6,
    o = { { e = PIERRE, q = 5 } }, x = 10, y = 10, a = "Syn-Apertus", g = "Syn-Apertus", v = 4 })
attendu("une copie perimee ne la reprend pas", Sol.sacs.solsyn.gardien, MOI)
__deconnecter("Syn-Apertus", false)

dire("== ramasser le sac en entier")
-- Ouvrir exige une mesure .gps recente des trois axes depuis le 17 octobre
-- 2026 (Core/Coffres.lua, Ouvrir) : sans elle, l'ouverture part demander le
-- .gps et la fenetre n'existe pas encore. Le banc en joue une, la ou l'on se
-- tient, comme lcm_test_coffres (21 octobre 2026).
Gps(10, 10, 0)
C.Ouvrir(id)
local fenetre = LCM.UI.Coffre.frame
attendu("le bouton est la", fenetre.ramasser:IsShown(), true)
fenetre.ramasser:Click()
attendu("le sac est equipe", I.Emplacement(moi, "sacs", 1) and I.Emplacement(moi, "sacs", 1).sac, "sac_lache")
attendu("  avec ce qu'il contenait encore", Combien(PIERRE) .. "/" .. Combien(HERBE), "3/1")
attendu("il n'est plus au sol", Sol.sacs[id], nil)
attendu("  ni un coffre", C.points[id], nil)
avant = #__envois
Recevoir("Zed-Apertus", Sol.SUJETS.etat, LCM.SacsAuSol.Paquet({ id = id, label = "x", places = 6,
    objets = {}, position = {}, auteur = "Zed-Apertus", gardien = "Zed-Apertus", version = 9 }))
attendu("une vieille copie ne le ressuscite pas", Sol.sacs[id], nil)
attendu("  et on le redit", Envoye(Sol.SUJETS.retrait, avant) ~= nil, true)

dire("== A pose, part ; B garde et prend ; B part ; C garde ; A revient")
-- Reika joue A. Elle lache un sac, puis se deconnecte : on rejoue sa
-- reconnexion en vidant sa memoire et en relisant sa sauvegarde.
I.Poser(moi, "sacs", 1, "sac_reserve")
I.Ranger(moi, "sacs", 1, 1, PIERRE, 4)
Sol.Lacher("sacs", 1)
local idA
for k, s in pairs(Sol.sacs) do if s.auteur == MOI and s.version == 1 then idA = k end end
attendu("A a pose son sac (version 1)", idA ~= nil, true)
local copie = LCM.Copie(Sol.sacs[idA])
-- Pendant son absence : B (Syn) prend la garde et y prend 3 pierres (v3),
-- puis part ; C (Zed) prend la garde (v4). Reika ne voit rien de tout ca.
Sol.sacs = {}
for k in pairs(LCM.Coffres.points) do LCM.Coffres.points[k] = nil end
Sol.Charger()
attendu("au retour, la copie est endormie", Sol.Endormi(idA), true)
avant = #__envois
C.Ouvrir(idA)
local refus = LCM.Coffres.etat
attendu("  A n'arbitre pas avec sa vieille copie", refus and refus.ok, false)
attendu("  et ne la rediffuse pas", Envoye(Sol.SUJETS.etat, avant), nil)
Sol.Demander()
local demande = Envoye(Sol.SUJETS.demande, avant)
attendu("A demande la version a jour", demande ~= nil, true)
-- C (Zed) repond avec la version a jour : 1 pierre, gardien Zed.
local aJour = LCM.Copie(copie)
aJour.objets = { { entree = PIERRE, quantite = 1 } }
aJour.gardien, aJour.version = "Zed-Apertus", 4
Recevoir("Zed-Apertus", Sol.SUJETS.etat, Sol.Paquet(aJour))
local recu = Sol.sacs[idA]
attendu("A recoit l'etat actuel", recu.version .. ":" .. recu.objets[1].quantite, "4:1")
attendu("  pas de duplication : les 3 pierres de B n'y sont plus", recu.objets[1].quantite, 1)
attendu("  le gardien est C", recu.gardien, "Zed-Apertus")
attendu("  la copie est reveillee", Sol.Endormi(idA), false)
-- B revient a son tour avec sa copie v3 et la diffuse : A, a jour, la
-- corrige au lieu de reculer.
local deB = LCM.Copie(aJour)
deB.objets = { { entree = PIERRE, quantite = 1 } }
deB.gardien, deB.version = "Syn-Apertus", 3
avant = #__envois
Recevoir("Syn-Apertus", Sol.SUJETS.etat, Sol.Paquet(deB))
attendu("pas de perte : la v3 de B ne remplace pas la v4", Sol.sacs[idA].version, 4)
local correction = Envoye(Sol.SUJETS.etat, avant)
attendu("  B recoit la version a jour", correction and correction.cible, "Syn-Apertus")
-- Et si personne ne repond : apres le delai, la copie se reveille.
Sol.sacs[idA].gardien = MOI
Sol.sacs = { [idA] = Sol.sacs[idA] }
LCM.db.solSacs = { sacs = { [idA] = Sol.sacs[idA] }, morts = {} }
Sol.sacs = {}
Sol.Charger()
Sol.Demander()
Sol.Veiller()
attendu("sans reponse : encore endormie", Sol.Endormi(idA), true)
__avancerTemps(Sol.CONFIRMATION + 1)
Sol.Veiller()
attendu("  puis reveillee apres le delai", Sol.Endormi(idA), false)

dire("== un objet lache hors de l'inventaire tombe au sol")
-- Un seul objet (sa pile), une seule collecte, sans jet ni DD ; le point
-- disparait des qu'il est ramasse (le MJ, 16 octobre 2026).
I.Ranger(moi, "sacs", 2, 3, HERBE, 4)
-- Loin des sacs deja au sol : le bouton montre le plus proche.
__position(60, 60, 0)
local caseHerbe = { ref = HERBE, quantite = 4, nom = "Herbe",
    origine = { onglet = "sacs", index = 2, case = 3 },
    retirer = function() I.Vider(moi, "sacs", 2, 3) end,
    rendre = function() I.Ranger(moi, "sacs", 2, 3, HERBE, 4) end }
local herbesAvant = Combien(HERBE)
attendu("pose au sol", Sol.LacherObjet(caseHerbe), true)
attendu("  il a quitte le sac", Combien(HERBE), herbesAvant - 4)
local idObjet
for k, s in pairs(Sol.sacs) do if s.objet then idObjet = k end end
attendu("  c'est un objet seul au sol", idObjet ~= nil and Sol.sacs[idObjet].label, "Herbe x4")
__avancer(0.3)
local bouton = LCM.UI.Coffre.bouton
attendu("devant lui : « Ramasser », pas « Ouvrir »", bouton and bouton:IsShown() and bouton.titre:GetText(), "Ramasser")
Gps(60, 60, 0)
bouton:Click()
attendu("un clic, et les 4 herbes reviennent", Combien(HERBE), herbesAvant)
attendu("  le point a disparu", Sol.sacs[idObjet], nil)
attendu("  et n'est plus un coffre", C.points[idObjet], nil)

dire("== un MJ arrive : il securise")
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = mjCharge
attendu("on joue en MJ", LCM.IsMaster(), true)
avant = #__envois
-- Avec son altitude, comme tout sac lache (Sol.Lacher la releve) : le coffre
-- qui le securise exige les trois axes depuis le 16 octobre 2026 (21 octobre 2026).
Recevoir("Zed-Apertus", Sol.SUJETS.etat, { i = "solzed", n = "Sac de réserve de Zed", b = "sac_reserve", s = 6,
    o = { { e = PIERRE, q = 2 } }, x = 30, y = 40, z = 0, r = sol.position.source, k = sol.position.carte,
    a = "Zed-Apertus", g = "Zed-Apertus", v = 1 })
attendu("le fantome disparait", Sol.sacs.solzed, nil)
attendu("  et on le dit au groupe", Envoye(Sol.SUJETS.retrait, avant) ~= nil, true)
local coffre
for _, p in ipairs(LCM.Points.Nature("coffre")) do
    if p.label == "Sac de réserve de Zed" then coffre = p end
end
attendu("c'est une vraie entree Coffre", coffre ~= nil, true)
attendu("  qui sait quel sac elle est", coffre and coffre.coffre.sac, "sac_reserve")
local poses = coffre and LCM.CoffresMJ.Points(coffre.id) or {}
attendu("  posee la ou le sac etait", poses[1] and (poses[1].x .. "," .. poses[1].y), "30,40")
attendu("  avec son contenu", poses[1] and poses[1].objets[1].quantite, 2)

dire("== et se ramasse aussi en entier chez le MJ")
avant = #__envois
LCM.CoffresMJ.Traiter("Zed-Apertus", { i = poses[1].id, a = "emporter" })
local reponse = Envoye(C.SUJETS.etat, avant)
attendu("Zed recoit le sac et son contenu", reponse ~= nil, true)
attendu("le coffre quitte le monde", #LCM.CoffresMJ.Points(coffre.id), 0)
attendu("  et la base", LCM.Points.Get(coffre.id), nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
