-- Le .gps de fond : on ne le redemande qu'a portee d'un point pose au GPS.
--
-- Jusqu'au 16 octobre 2026, les marchands, la recolte et les lieux le
-- redemandaient des que la derniere reponse avait trois secondes, partout sur
-- la carte, et sans fin quand le serveur ne repondait pas.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__groupe({ "Nytherah-Apertus" })
__declencher("PLAYER_LOGIN")
local DF = LCM.DeplacementForce
local M = LCM.Marchands

-- Une carte d'instance : ni UnitPosition, ni la carte ne repondent.
__positionMonde(false)
__carte(585, 0, 0)

local function gpsEnvoyes()
    local n = 0
    for _, c in ipairs(__chats) do if c.texte == ".gps" then n = n + 1 end end
    return n
end
local function ligne(x, y)
    return string.format("Map: 585 (Magisters' Terrace) Zone: 0 Area: 0 Phase: 158070, "
        .. "X: %.6f, Y: %.6f, Z: -81.208794, O: 1.904451", x, y)
end
-- Le serveur repond un instant apres la demande.
local function repondre(x, y) DF.NoterGPS(ligne(x, y)) end
-- `x, y` : le serveur repond, a cette position, a chaque demande.
local function battre(secondes, x, y)
    for _ = 1, math.floor(secondes * 4) do
        __avancerTemps(0.25)
        local avant = gpsEnvoyes()
        M.Tick()
        if x and gpsEnvoyes() > avant then repondre(x, y) end
    end
end

dire("== sans point pose au GPS, aucune demande")
battre(10)
attendu("rien n'est parti", gpsEnvoyes(), 0)

-- Un vendeur pose au GPS sur cette carte, a (1000, 1000).
M.definitions.temoin_gps = { id = "temoin_gps", label = "Vendeur témoin", offres = {}, rachats = {} }
M.points.temoin_gps_1 = { def = "temoin_gps", x = 1000, y = 1000, carte = 585, source = "gps" }

dire("== on ne sait pas ou l'on est : une demande, pour le savoir")
battre(0.25)
attendu("une demande", gpsEnvoyes(), 1)
-- Et sa reponse ne s'affiche pas : c'est l'addon qui a pose la question.
attendu("la reponse est retiree du chat", __filtreChat("CHAT_MSG_SYSTEM", ligne(0, 0)), true)
repondre(0, 0)

dire("== loin du point, on attend le temps d'y arriver")
-- A 1414 yards, la portee (rayon + 30) n'est pas atteignable avant 30 s
-- (le plafond d'attente). L'attente part quand la reponse perime, 3 s apres
-- elle : la reverification tombe donc vers 33 s.
local avant = gpsEnvoyes()
battre(32, 0, 0)
attendu("rien pendant l'attente", gpsEnvoyes() - avant, 0)
battre(2, 0, 0)
attendu("une seule reverification au bout", gpsEnvoyes() - avant, 1)

dire("== a portee, la position se tient a jour")
repondre(990, 1000)
avant = gpsEnvoyes()
battre(17.5, 990, 1000)
-- Une reponse vaut 3 s : environ une demande toutes les 3,25 s.
attendu("on redemande quand la position perime", gpsEnvoyes() - avant, 5)

dire("== le serveur ne repond plus : trois essais, puis le silence")
avant = gpsEnvoyes()
battre(20)
attendu("trois demandes sans reponse, pas plus", gpsEnvoyes() - avant, 3)
battre(60)
attendu("un nouvel essai apres une minute de repos", gpsEnvoyes() - avant > 3, true)

dire("== un .gps tape a la main repond normalement")
__avancerTemps(10)
attendu("sa reponse s'affiche", __filtreChat("CHAT_MSG_SYSTEM", ligne(0, 0)), false)

M.points.temoin_gps_1 = nil
M.definitions.temoin_gps = nil

if ko == 0 then dire("TOUT PASSE") else dire(ko .. " ECHEC(S)") end
