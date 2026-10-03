-- Reagir a une action : devier, proposer d'intervenir, intervenir.
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
local function dernier(sujet)
    for i = #__envois, 1, -1 do
        if __envois[i].message:find(":" .. sujet .. "|", 1, true) then return __envois[i] end
    end
end
local function chatDit(motif)
    for i = #__chats, 1, -1 do if __chats[i].texte:find(motif, 1, true) then return __chats[i] end end
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local A, E, R = LCM.Actions, LCM.Entities, LCM.Reactions
local U = LCM.UI.Resolution
local moi = E.Self()
E.Set_Value(moi, "esprit", 4)
__groupe({ "Reika-Apertus", "Nytherah-Apertus", "Bram-Apertus" }, true)
local function plein() E.SetGauge(moi, "pa", 10) E.SetGauge(moi, "fatigue", 40, 40) end
plein()

local n = 0
local function attaque(rand, extra)
    n = n + 1
    local p = { t = "a" .. n, n = "Attaque", a = "Nytherah-Apertus", rp = "Nytherah", ci = LCM.PlayerId(),
                v = { ["Total Normal"] = "5", ["Total Critique"] = "8", ["Rand Nom"] = "Esprit",
                      ["Rand Résultat"] = tostring(rand), ["Cout PA"] = "1", ["Type action"] = "Corps à corps",
                      Zones = "#sante" } }
    for k, x in pairs(extra or {}) do p[k] = x end
    return p
end

dire("== on peut devier : le prompt le propose")
recevoir("Nytherah-Apertus", "act", attaque(0))
local P = U.recu
attendu("devier", P.devier:IsShown() and P.devier.label:GetText(), "Dévier vers une autre cible (1 PA + 5 PF)")
attendu("proposer", P.proposer:IsShown(), true)

dire("== devier vers Bram : reussi (le jet bat 0)")
P.devier:Click()
local W = U.reaction
attendu("la fenetre de deviation", W:IsShown() and W.titre:GetText(), "Déviation — Attaque")
attendu("rien sans competence ni cible", W.agir:IsEnabled(), false)
W.jets[1]:Click()
local bram
for _, b in ipairs(W.second) do if b:IsShown() and b.cible and b.cible.id == "Bram-Apertus" then bram = b end end
bram:Click()
attendu("pret", W.agir:IsEnabled(), true)
attendu("l'attaquant est proposable", (function()
    for _, b in ipairs(W.second) do if b:IsShown() and b.cible and b.cible.id == "Nytherah-Apertus" then return true end end
    return false
end)(), true)
local pa, pf = E.Gauge(moi, "pa").current, E.Gauge(moi, "fatigue").current
W.agir:Click()
attendu("PA payes (ceux de l'action)", E.Gauge(moi, "pa").current, pa - 1)
attendu("PF payes", E.Gauge(moi, "fatigue").current, pf - 5)
attendu("le jet est annonce", chatDit("[Déviation — Rand Esprit]") ~= nil, true)
attendu("et la reussite", chatDit("dévie « Attaque » de Nytherah vers Bram-Apertus") ~= nil, true)
local act = dernier("act")
attendu("l'action part a Bram", act and act.cible, "Bram-Apertus")
attendu("redirigee par moi", act and act.message:find("rd=", 1, true) ~= nil, true)
attendu("plus de prompt", P:IsShown(), false)

dire("== une deviation ratee : l'action revient, sans autre detour")
plein()
recevoir("Nytherah-Apertus", "act", attaque(99))
P.devier:Click()
W.jets[1]:Click()
for _, b in ipairs(W.second) do if b:IsShown() and b.cible and b.cible.id == "Bram-Apertus" then b:Click() end end
W.agir:Click()
attendu("echec annonce", chatDit("échoue à dévier") ~= nil, true)
attendu("l'action revient", P:IsShown(), true)
attendu("on ne peut plus la detourner", P.devier:IsShown(), false)
attendu("et on dit pourquoi", P.resume:GetText():find("redirection a déjà échoué", 1, true) ~= nil, true)
U.Ignorer()

dire("== ce qui ne se devie pas")
local zone = attaque(0)
zone.v.Zone = "8 yards"
recevoir("Nytherah-Apertus", "act", zone)
attendu("une zone", P.devier:IsShown(), false)
U.Ignorer()
local sansJet = attaque(0)
sansJet.v["Rand Résultat"] = nil
recevoir("Nytherah-Apertus", "act", sansJet)
attendu("sans jet d'attaquant : dit", P.resume:GetText():find("Rand Résultat", 1, true) ~= nil, true)
U.Ignorer()

dire("== proposer une intervention : refusee")
plein()
recevoir("Nytherah-Apertus", "act", attaque(0, { a = "Bram-Apertus", rp = "Bram" }))
P.proposer:Click()
local S = U.sollicitation
attendu("le groupe a solliciter", S:IsShown() and S.lignes[1]:IsShown(), true)
local nyt
for _, b in ipairs(S.lignes) do if b:IsShown() and b.joueur == "Nytherah-Apertus" then nyt = b end end
nyt:Click()
local prop = dernier("interv?")
attendu("la proposition part", prop and prop.cible, "Nytherah-Apertus")
recevoir("Nytherah-Apertus", "interv-", { t = "a" .. n, ok = 0 })
attendu("refusee : l'action revient", P:IsShown() and P.recu.paquet.t, "a" .. n)
U.Ignorer()

dire("== on me propose d'intervenir : j'accepte, et je reussis")
plein()
local demande = attaque(0, { ci = "Nytherah-Apertus", pb = "Nytherah-Apertus", pbrp = "Nytherah",
                              a = "Bram-Apertus", rp = "Bram" })
recevoir("Nytherah-Apertus", "interv?", demande)
attendu("la fenetre d'intervention", W:IsShown() and W.titre:GetText(), "Intervention — Attaque")
attendu("cout de l'intervention", W.agir.label:GetText(), "Intervention (1 PA + 3 PF)")
W.jets[1]:Click()
W.agir:Click()
local devie = dernier("devie")
attendu("la cible d'origine est prevenue", devie and devie.cible, "Nytherah-Apertus")
attendu("en attendant sa reponse, rien n'arrive", P:IsShown(), false)
recevoir("Nytherah-Apertus", "devie+", { t = demande.t })
attendu("l'action m'arrive", P:IsShown() and P.titre:GetText():find("redirigée sur vous", 1, true) ~= nil, true)
U.Ignorer()

dire("== je refuse une intervention")
recevoir("Nytherah-Apertus", "interv?", attaque(0, { pb = "Nytherah-Apertus" }))
W.annuler:Click()
local non = dernier("interv-")
attendu("le refus part", non and non.message:find("ok=0", 1, true) ~= nil, true)

dire("== cible d'origine : un detour annule mon prompt, sauf si j'ai commence")
recevoir("Nytherah-Apertus", "act", attaque(0))
local t = P.recu.paquet.t
recevoir("Bram-Apertus", "devie", { t = t, vers = "Bram", par = "Bram" })
attendu("le prompt se ferme", P:IsShown(), false)
local ack = dernier("devie+")
attendu("et on accuse reception au reacteur", ack and ack.cible, "Bram-Apertus")
recevoir("Nytherah-Apertus", "act", attaque(0))
t = P.recu.paquet.t
P.resoudre:Click()
recevoir("Bram-Apertus", "devie", { t = t, vers = "Bram", par = "Bram" })
attendu("trop tard : on le dit au reacteur", dernier("devie!") ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
