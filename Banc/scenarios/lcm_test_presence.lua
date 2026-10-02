-- Le ping de presence : qui a l'addon, sur tout le serveur.
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
local function envoisDe(sujet)
    local out = {}
    for _, e in ipairs(__envois) do if e.message:find(":" .. sujet .. "|", 1, true) then out[#out + 1] = e end end
    return out
end

__declencher("PLAYER_LOGIN")
local P = LCM.Presence

dire("== a la connexion : le canal, et le ping")
attendu("le canal est rejoint", __canaux[1], P.CANAL)
attendu("et retire des fenetres de discussion", __canauxCaches[P.CANAL], true)
local ping = envoisDe("ici%?")[1] or envoisDe("ici?")[1]
attendu("un ping part sur le canal", ping and ping.canal, "CHANNEL")
attendu("au bon numero", ping and ping.cible, P.Canal())

dire("== quelqu'un, n'importe ou, pingue : on le note et on lui repond")
local n = #__envois
recevoir("Lointain-Autreroyaume", "ici?", { v = "0.1.0" })
attendu("il est connu", P.Confirmee("Lointain-Autreroyaume"), true)
attendu("meme sans son royaume", P.Confirmee("Lointain"), true)
local reponse = __envois[n + 1]
attendu("on lui repond", reponse and reponse.message:find(":ici|", 1, true) ~= nil, true)
attendu("en prive", reponse and reponse.canal .. " " .. reponse.cible, "WHISPER Lointain-Autreroyaume")

dire("== une reponse suffit aussi")
recevoir("Ami-Apertus", "ici", { v = "0.1.0" })
attendu("connu", P.Confirmee("Ami-Apertus"), true)
attendu("un inconnu ne l'est pas", P.Confirmee("Personne-Apertus"), false)
attendu("moi, toujours", P.Confirmee(LCM.PlayerId()), true)

dire("== pas de peremption")
__avancerTemps(86400)
attendu("un jour plus tard", P.Confirmee("Ami-Apertus"), true)

dire("== connu n'est pas ciblable : seulement le groupe ou le raid")
__groupe({ "Reika-Apertus", "Ami-Apertus" })
local joueurs = LCM.Actions.Cibles()
local ids = {}
for _, j in ipairs(joueurs) do ids[#ids + 1] = j.id end
attendu("moi et le groupe, pas le lointain", table.concat(ids, ","), LCM.PlayerId() .. ",Ami-Apertus")

dire("== le canal rejoint plus tard : le ping part a ce moment")
n = #__envois
__declencher("CHAT_MSG_CHANNEL_NOTICE", "YOU_JOINED", "", "", "5. " .. P.CANAL, "", "", 0, 5, P.CANAL)
attendu("un nouveau ping", #envoisDe("ici?") > 0 and __envois[n + 1] ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
