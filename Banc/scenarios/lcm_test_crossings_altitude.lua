-- Crossings : d'ou vient l'ALTITUDE d'un interieur (3 novembre 2026).
--
-- Les tranches des batiments ne fermaient rien en jeu alors que le banc les
-- voyait marcher. La raison : Crossings lisait l'altitude dans le troisieme
-- retour de UnitPosition, qui vaut TOUJOURS zero chez le client. Tous les
-- sols se retrouvaient donc au meme etage, et « Reprendre le sol ici » ne
-- reprenait rien du tout.
--
-- Le reste de l'addon (coffres, recolte, marchands) prend deja sa hauteur sur
-- la position SERVEUR, celle que DeplacementForce tient a jour. Crossings
-- etait le seul a s'en passer.
--
-- Ce qu'on verifie :
--
--   * un zero de UnitPosition n'est pas une altitude : sans serveur pour
--     repondre, GetPlayerPose n'en annonce aucune ;
--   * quand le serveur repond, c'est SA hauteur que les zones relevent ;
--   * une tranche posee sans repere ne se referme pas — elle ne doit surtout
--     pas enfermer le joueur dehors sans rien dire ;
--   * et « reprendre le sol » monte bien d'un etage.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local ZG = LCM.Crossings
local DF = LCM.DeplacementForce

-- UnitPosition rend y AVANT x (voir Core/Crossings.lua).
local function Poser(x, y, z) __position(y, x, z or 0) end
-- Ce que le serveur repond a `.gps` : x, y, z, carte, cap.
local function Gps(x, y, z)
    DF.NoterGPS(string.format("%.6f %.6f %.6f 1 0.000000", x, y, z))
end

dire("== sans serveur, le zero de UnitPosition n'est pas une altitude")
Poser(10, 20, 0)
local px, py, _, carte, pz = ZG:GetPlayerPose()
attendu("la position, elle, reste bonne", math.floor(px) .. "/" .. math.floor(py), "10/20")
attendu("la carte du jeu aussi", carte ~= nil, true)
attendu("mais pas d'altitude", pz, nil)

dire("== quand le serveur repond, c'est sa hauteur qui compte")
Gps(10, 20, 137.5)
local _, _, _, _, pz2 = ZG:GetPlayerPose()
attendu("l'altitude vient du serveur", pz2, 137.5)
-- Le serveur fait foi meme si le client pretend autre chose : c'est lui qui
-- sait, et deux sources contradictoires finiraient par diverger.
Poser(10, 20, 999)
local _, _, _, _, pz3 = ZG:GetPlayerPose()
attendu("  et le client ne le contredit pas", pz3, 137.5)

dire("== une zone posee releve ce sol-la")
local region = ZG:CreateZone("Les Profondeurs")
local lieu = ZG:CreatePlace(region.id, "Le Puits")
local tour = ZG:CreateBuildingPlace(region.id, lieu.id, "La Crypte")
local empreinte = ZG:GetBatimentArea(tour.id)
attendu("l'empreinte nait avec le sol du serveur", empreinte.z, 137.5)
attendu("  elle descend", empreinte.bas, 6)
attendu("  et elle monte", empreinte.haut, 12)

dire("== la tranche se referme vraiment")
attendu("au niveau du sol, dedans", ZG.DansLaTranche(empreinte, 137.5), true)
attendu("sous les fondations, dehors", ZG.DansLaTranche(empreinte, 120), false)
attendu("au-dessus du toit, dehors", ZG.DansLaTranche(empreinte, 160), false)

dire("== reprendre le sol monte d'un etage")
Gps(10, 20, 157.5)
attendu("on reprend le sol ici", ZG:RecaptureSubZoneHeight(empreinte.id), true)
attendu("  le repere a monte", empreinte.z, 157.5)
attendu("l'ancien rez-de-chaussee est sous la cave", ZG.DansLaTranche(empreinte, 137.5), false)
attendu("  et l'etage est chez lui", ZG.DansLaTranche(empreinte, 160), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
