-- La boussole des Lieux : ou est le nord, dans chaque source de position.
--
-- C'est le seul endroit de l'addon qui ait besoin d'une orientation ABSOLUE.
-- Partout ailleurs on ne calcule que des distances, et une distance est la
-- meme quel que soit le sens des axes — c'est pour ca que le desaccord entre
-- les trois sources n'avait jamais gene personne.
--
-- Le radar de l'atelier, lui, serait illisible avec un nord de travers, et
-- pire : il se lirait tres bien, en miroir, et on ne s'en apercevrait qu'en
-- posant une porte a l'envers. On ne DEDUIT donc plus le nord des conventions,
-- on le MESURE en regardant marcher le MJ, contre la fraction de carte — qui
-- est au nord par construction. Ce fichier verifie les deux moities : le
-- solveur, et la mesure en situation.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function vecteur(v)
    if not v then return "nil" end
    return string.format("%.2f,%.2f", v[1] + 0, v[2] + 0)
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local L = LCM.Lieux

dire("== le solveur, sur des transformations connues")
-- La carte alignee sur la source : l'est est +x, et le nord est -y parce que
-- la fraction d'une carte DESCEND vers le sud.
local est, nord = L.ResoudreBoussole({ 1, 0 }, { 1, 0 }, { 0, 1 }, { 0, 1 })
attendu("carte alignée : est", vecteur(est), "1.00,0.00")
attendu("carte alignée : nord", vecteur(nord), "0.00,-1.00")

-- Une carte en MIROIR sur x — c'est le cas reel de la source « monde ».
est, nord = L.ResoudreBoussole({ 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, 1 })
attendu("carte en miroir : est", vecteur(est), "-1.00,0.00")
attendu("carte en miroir : nord", vecteur(nord), "0.00,-1.00")

-- Une carte tournee d'un quart de tour.
est, nord = L.ResoudreBoussole({ 1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 0 })
attendu("carte tournée : est", vecteur(est), "0.00,1.00")
attendu("carte tournée : nord", vecteur(nord), "1.00,0.00")

dire("== le solveur refuse ce qu'il ne sait pas résoudre")
local rien, raison = L.ResoudreBoussole({ 1, 0 }, { 1, 0 }, { 2, 0 }, { 2, 0 })
attendu("deux déplacements parallèles", rien, nil)
attendu("et il dit pourquoi", tostring(raison):find("parallèles") ~= nil, true)
-- Un est et un nord qui ne sont pas perpendiculaires : les deux releves ne
-- viennent pas du meme endroit. Mieux vaut jeter la mesure que poser un nord
-- de travers.
rien, raison = L.ResoudreBoussole({ 1, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 })
attendu("relevés incohérents", rien, nil)
attendu("et il dit pourquoi", tostring(raison):find("incohérente") ~= nil, true)

dire("== sans carte, on retombe sur la convention, et on le sait")
LCM.db.boussoles = {}
__carte(nil)
local droite, haut, mesuree = L.Boussole(585, "monde")
attendu("ce n'est pas mesuré", mesuree, false)
attendu("c'est la convention du monde", vecteur(droite), "-1.00,0.00")
attendu("et son nord", vecteur(haut), "0.00,-1.00")
attendu("rien à calibrer sans carte", L.Calibrer("monde", 0, 0), false)

dire("== en marchant, on la mesure — et elle confirme la convention")
-- Le vrai client : notre x est worldY (UnitPosition rend y avant x), worldY
-- croit vers l'OUEST et worldX vers le SUD. La fraction de carte va donc en
-- -x vers l'est et en +y vers le sud.
LCM.db.boussoles = {}
__carte(1, 1000, 1000)
__carteAxes(-1, 0, 0, 1)
L.OublierBoussole(1, "monde")

-- `Calibrer` recoit la position dans la source et va lire la carte ET la
-- fraction lui-meme : c'est la comparaison des deux qui donne le nord. Il faut
-- donc deplacer le personnage pour de bon, pas seulement annoncer une
-- position.
local function marcher(x, y)
    __position(x, y, 0)
    return L.Calibrer("monde", x, y)
end
attendu("le premier relevé ne conclut rien", marcher(0, 0), false)
attendu("un seul déplacement non plus", marcher(20, 0), false)
attendu("le second, perpendiculaire, conclut", marcher(20, 20), true)

droite, haut, mesuree = L.Boussole(1, "monde")
attendu("c'est mesuré", mesuree, true)
attendu("l'est", vecteur(droite), "-1.00,0.00")
attendu("le nord", vecteur(haut), "0.00,-1.00")
-- Le point de tout l'exercice : la table de convention disait vrai pour
-- « monde ». On ne la croit plus sur parole pour autant.
attendu("la convention disait la même chose",
    vecteur(L.CONVENTION.monde.droite) .. " / " .. vecteur(L.CONVENTION.monde.haut),
    vecteur(droite) .. " / " .. vecteur(haut))

dire("== une carte tournée est mesurée comme telle")
-- Une carte custom n'a aucune raison d'etre alignee comme les autres. C'est
-- exactement le cas qu'une table de conventions ne peut pas couvrir. Celle de
-- la carte 1 reste en place : chaque carte a la sienne.
__carte(7, 1000, 1000)
__carteAxes(0, 1, -1, 0)
attendu("premier relevé", marcher(0, 0), false)
attendu("deuxième", marcher(30, 0), false)
attendu("troisième", marcher(30, 30), true)
droite, haut, mesuree = L.Boussole(7, "monde")
attendu("mesurée", mesuree, true)
attendu("l'est suit la carte", vecteur(droite), "0.00,1.00")
attendu("le nord aussi", vecteur(haut), "1.00,0.00")
-- Et la convention, elle, se serait trompee.
attendu("la convention aurait donné autre chose",
    vecteur(L.CONVENTION.monde.droite) ~= vecteur(droite), true)

dire("== chaque carte a la sienne, et elle survit")
attendu("la carte 1 n'a pas bougé", vecteur((L.Boussole(1, "monde"))), "-1.00,0.00")
attendu("elle est en sauvegarde", LCM.db.boussoles["1/monde"] ~= nil, true)
attendu("la carte 7 aussi", LCM.db.boussoles["7/monde"] ~= nil, true)
-- Une source differente sur la meme carte est une autre boussole : « gps » ne
-- nomme pas ses axes comme « monde ».
attendu("gps n'est pas encore mesuré", select(3, L.Boussole(1, "gps")), false)

dire("== une boussole mesurée ne se remesure pas toute seule")
__carte(1, 1000, 1000)
__carteAxes(-1, 0, 0, 1)
local avant = LCM.db.boussoles["1/monde"]
attendu("on ne recalibre pas", marcher(500, 500), false)
attendu("et rien n'a change", LCM.db.boussoles["1/monde"], avant)
L.OublierBoussole(1, "monde")
attendu("oubliée, on repart de la convention", select(3, L.Boussole(1, "monde")), false)

dire("== le radar de l'atelier dit laquelle il applique")
LCM.db.boussoles = {}
LCM.db.lieux = {}
__carte(1, 1000, 1000)
__carteAxes(-1, 0, 0, 1)
__position(0, 0, 0)
local lieu = L.Creer("Les Marches Grises")
local seuil = L.CreerSeuil(lieu.id, "Porte du Nord", "porte")
__position(0, 10, 0)
L.PoserBorne(seuil.id)

local A = LCM.UI.LieuxMJ
A.lieu, A.seuil = lieu.id, seuil.id
local f = A.Fenetre()
f:Montrer()
attendu("le nord est signalé comme supposé", f.radar.nord:GetText(), "N ?")
attendu("et la ligne d'état le dit",
    __sansCouleur(f.etat:GetText()):find("convention") ~= nil, true)

-- On marche : deux jambes non paralleles, le pouls mesure.
__position(40, 0, 0) f:Pouls()
__position(40, 40, 0) f:Pouls()
attendu("le nord devient mesuré", f.radar.nord:GetText(), "N")
attendu("et la ligne d'état aussi",
    __sansCouleur(f.etat:GetText()):find("nord mesuré") ~= nil, true)
f:Hide()

dire("== le cap : le solveur, sur des conventions connues")
-- Le radar tourne avec le personnage, donc il lui faut son cap. Le client rend
-- un angle, mais dans quel sens ? On ne le croit pas sur parole non plus.
local signe, decalage = L.ResoudreCap(0, 0, 1.0, -1.0)
attendu("sens trigonométrique (la convention) : signe", signe, -1)
attendu("  et pas de décalage", string.format("%.2f", decalage), "0.00")

signe, decalage = L.ResoudreCap(0, 0, 1.0, 1.0)
attendu("sens horaire : signe", signe, 1)
attendu("  et pas de décalage", string.format("%.2f", decalage), "0.00")

-- Une origine decalee d'un quart de tour : 0 a l'est au lieu du nord.
local quart = math.pi / 2
signe, decalage = L.ResoudreCap(0, quart, 1.0, quart - 1.0)
attendu("origine décalée : signe", signe, -1)
attendu("  décalage d'un quart de tour", string.format("%.2f", decalage),
    string.format("%.2f", quart))

dire("== et il refuse ce qu'il ne sait pas trancher")
local rien, raison = L.ResoudreCap(0.4, -0.4, 0.45, -0.45)
attendu("deux trajets dans la même direction", rien, nil)
attendu("et il dit pourquoi", tostring(raison):find("même direction") ~= nil, true)
rien, raison = L.ResoudreCap(0, 0.9, 1.0, -1.0)
attendu("un trajet de travers", rien, nil)
attendu("et il dit pourquoi", tostring(raison):find("incohérents") ~= nil, true)

dire("== sans mesure, on applique la convention, et on le sait")
LCM.db.cap = {}
__cap(0)
local theta, capMesure = L.Cap()
attendu("ce n'est pas mesuré", capMesure, false)
attendu("face au nord, le radar ne tourne pas", string.format("%.2f", theta), "0.00")
__cap(quart)
attendu("un quart de tour à gauche", string.format("%.2f", (L.Cap())),
    string.format("%.2f", -quart))

dire("== en marchant droit, on le mesure")
-- On simule un client qui suit la convention : regarder en phi, c'est avancer
-- vers le cap -phi. La carte 1 a ete mesuree plus haut (est = -x, nord = -y),
-- donc avancer vers le cap theta deplace de (-sin theta, -cos theta).
LCM.db.cap = {}
L.OublierCap()
__carte(1, 1000, 1000)
__carteAxes(-1, 0, 0, 1)

local px, py = 0, 0
local function regarder(phi)
    __cap(phi)
    __position(px, py, 0)
    return L.CalibrerCap("monde", px, py)
end
local function avancer(phi, distance)
    local theta = -phi
    px = px - math.sin(theta) * distance
    py = py - math.cos(theta) * distance
    __position(px, py, 0)
    return L.CalibrerCap("monde", px, py)
end

attendu("on se place", regarder(0), false)
attendu("premier trajet", avancer(0, 20), false)
attendu("on se tourne", regarder(1.0), false)
attendu("second trajet, cap différent", avancer(1.0, 20), true)

theta, capMesure = L.Cap()
attendu("c'est mesuré", capMesure, true)
attendu("et ça confirme la convention", LCM.db.cap.signe, -1)
__cap(0)
attendu("face au nord, rien ne tourne", string.format("%.2f", (L.Cap())), "0.00")

dire("== un client au sens inverse serait mesuré comme tel")
LCM.db.cap = {}
L.OublierCap()
px, py = 0, 0
local function avancerInverse(phi, distance)
    -- Ici regarder en phi, c'est avancer vers le cap +phi.
    px = px - math.sin(phi) * distance
    py = py - math.cos(phi) * distance
    __position(px, py, 0)
    return L.CalibrerCap("monde", px, py)
end
regarder(0)
avancerInverse(0, 20)
regarder(1.0)
attendu("mesuré à l'envers", avancerInverse(1.0, 20), true)
attendu("et le signe le dit", LCM.db.cap.signe, 1)

dire("== le radar tourne, et le nord quitte le haut")
LCM.db.cap = {}
L.OublierCap()
__cap(0)
A.lieu, A.seuil = lieu.id, seuil.id
f:Montrer()
attendu("le regard est montré", f.radar.regard:IsShown(), true)
local _, yNord = f.radar.nord:GetPoint()
attendu("face au nord, le N est en haut",
    string.format("%.0f", select(5, f.radar.nord:GetPoint())), "78")
__cap(math.pi)
f:Pouls()
attendu("demi-tour : le N passe en bas",
    string.format("%.0f", select(5, f.radar.nord:GetPoint())), "-78")
attendu("et l'état dit d'où vient le cap",
    __sansCouleur(f.etat:GetText()):find("cap") ~= nil, true)
f:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
