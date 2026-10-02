-- Le combat vu d'un joueur, SANS le compagnon MJ : a jouer aussi avec
-- --sans-mj. Le MJ (Nytherah) est simule par les messages qu'il enverrait.
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
local C = LCM.Combat
local B = LCM.UI.Combat
local moi = LCM.PlayerId()
__groupe({ "Reika-Apertus", "Nytherah-Apertus" })

dire("== la fenetre du MJ n'existe que chez le MJ")
attendu("chez un joueur, pas de fenetre", LCM.IsMaster() or LCM.UI.CombatMJ == nil, true)

dire("== l'invitation")
recevoir("Nytherah-Apertus", "combat?", { s = "s9" })
attendu("proposee", B.invitation and B.invitation:IsShown(), true)
B.invitation.oui:Click()
local envoi = dernierEnvoi()
attendu("la reponse part au MJ", envoi.cible, "Nytherah-Apertus")
attendu("en chuchotant", envoi.canal, "WHISPER")
local corps = LCM.Reseau.Decoder(envoi.message:match("^%d+:%d+:%d+:combat%+|(.*)$") or "")
attendu("acceptee", corps.ok, "1")
attendu("avec le jet", tonumber(corps.v) ~= nil, true)
attendu("pour cette invitation", corps.s, "s9")

dire("== le combat")
recevoir("Nytherah-Apertus", "combat=", C.Paquet({ s = "s9", c = 1, t = 1, r = 1, rm = 3, entrees = {
    { id = moi, nom = "Reika", v = 9 }, { id = "Nytherah-Apertus", nom = "Nytherah", v = 4 } } }))
attendu("le bandeau s'affiche", B.frame:IsShown(), true)
attendu("c'est mon tour", B.frame.avis:IsShown(), true)
B.frame.passer:Click()
attendu("je demande au MJ de passer", dernierEnvoi().message:find("combat>", 1, true) ~= nil, true)
recevoir("Nytherah-Apertus", "combat~", { s = "s9", c = 2, t = 1, r = 1 })
attendu("le tour avance", C.Courant().id, "Nytherah-Apertus")
attendu("bouton eteint", B.frame.passer:IsEnabled(), false)
recevoir("Nytherah-Apertus", "combat.", { s = "s9" })
attendu("fin", B.frame:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
