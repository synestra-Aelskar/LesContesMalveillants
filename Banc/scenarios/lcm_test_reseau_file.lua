-- La file reseau (3 novembre 2026), apres l'audit « l'addon peut-il
-- provoquer des desync ? » :
--   1. la reponse du jeu est LUE : un message refuse pour debit depasse
--      attend son tour et repart, au lieu de disparaitre en silence ;
--   2. des priorites (urgent > normal > fond), des PAQUETS (les petits
--      messages vers le meme endroit partent ensemble quand le jeu freine),
--      des remplacements (une `cle` remplace sa version pas encore partie),
--      et des compteurs pour le diagnostic ;
--   3. un message recu a moitie ne reste plus pour toujours, et ne se colle
--      plus a un message neuf qui reprend son numero ;
--   et une seule piste : les Crossings passent par la meme file.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local R = LCM.Reseau
local CIBLE = "Nytherah-Apertus"
-- Les autres modules parlent aussi pendant que le temps avance (presence,
-- annonces) : on ne compte que ce que le test envoie, par son sujet.
local function partis(depuis, prefixe, motif)
    local n = 0
    for i = depuis + 1, #__envois do
        local e = __envois[i]
        if (not prefixe or e.prefixe == prefixe)
            and (not motif or tostring(e.message):find(motif, 1, true)) then n = n + 1 end
    end
    return n
end
local function dernier(motif)
    for i = #__envois, 1, -1 do
        if tostring(__envois[i].message):find(motif, 1, true) then return __envois[i].message end
    end
end
local function vider()
    __avancer(30)
    attendu("  (la file s'est vidée)", R.FileEnvoi(), 0)
end

dire("== rien ne freine : un message part tout de suite")
local avant = #__envois
attendu("envoyé", (R.Envoyer("essai", { a = 1 }, "WHISPER", CIBLE)), true)
attendu("  sur le champ", partis(avant), 1)
attendu("  rien en file", R.FileEnvoi(), 0)

dire("== 1. le jeu refuse : le message attend et repart")
local s0 = R.Stats()
__refuserEnvois(3)
avant = #__envois
attendu("un refus n'est pas un échec", (R.Envoyer("essai", { a = 2 }, "WHISPER", CIBLE)), true)
attendu("  rien n'est parti", partis(avant), 0)
attendu("  il attend", R.FileEnvoi(), 1)
attendu("  le refus est compté", R.Stats().refuses - s0.refuses, 1)
__avancer(0.5)
attendu("le jeu a besoin de temps : on n'insiste pas", partis(avant, nil, "a=2"), 0)
__avancer(6)
attendu("il finit par partir", partis(avant, nil, "a=2"), 1)
attendu("  après trois refus", R.Stats().refuses - s0.refuses, 3)
attendu("  la file est vide", R.FileEnvoi(), 0)

dire("== une vraie erreur ne se reprend pas")
__refuserEnvois(1, Enum.SendAddonMessageResult.NotInGroup)
attendu("refusé pour de bon", (R.Envoyer("essai", { a = 3 }, "PARTY")), false)
attendu("  rien en file", R.FileEnvoi(), 0)

dire("== 2. quand le jeu freine, les petits messages partent en paquet")
local recus = {}
R.Ecouter("essai_paquet", function(expediteur, donnees) recus[#recus + 1] = donnees.n end)
__refuserEnvois(1)
avant = #__envois
for n = 1, 6 do R.Envoyer("essai_paquet", { n = n }, "WHISPER", CIBLE) end
attendu("six messages en attente", R.FileEnvoi(), 6)
__avancer(3)
attendu("un seul paquet est parti", partis(avant, nil, "essai_paquet"), 1)
local paquet = dernier("essai_paquet")
attendu("  un paquet regroupé", paquet:match("^%d+:1:1:~|") ~= nil, true)
attendu("  sous la limite", #paquet <= R.LIMITE, true)
R.Recevoir(CIBLE, paquet, "WHISPER")
attendu("à l'arrivée, chacun est servi", table.concat(recus, ","), "1,2,3,4,5,6")
attendu("les regroupés sont comptés", R.Stats().regroupes >= 6, true)
-- Ce qui va ailleurs ne voyage pas dans le meme paquet.
__refuserEnvois(1)
avant = #__envois
R.Envoyer("essai_paquet", { n = 7 }, "WHISPER", CIBLE)
R.Envoyer("essai_paquet", { n = 8 }, "WHISPER", "Blud-Apertus")
__avancer(3)
attendu("deux destinataires : deux paquets", partis(avant, nil, "essai_paquet"), 2)

dire("== les priorités : le fond ne passe pas devant le jeu")
__refuserEnvois(1)
avant = #__envois
R.Envoyer("essai_gros", { corps = string.rep("x", 3000) }, "WHISPER", CIBLE, { etale = true })
R.Envoyer("essai", { action = "frappe" }, "WHISPER", CIBLE)
__avancer(1.3)
local premier = __envois[avant + 1] and __envois[avant + 1].message or ""
attendu("le message de jeu part avant la suite du gros", premier:match("essai|") ~= nil and premier:match("essai_gros") == nil, true)
vider()

dire("== une clé remplace sa version pas encore partie")
__refuserEnvois(1)
avant = #__envois
local s1 = R.Stats()
R.Envoyer("essai_cle", { v = 1 }, "WHISPER", CIBLE, { cle = "fiche:x", etale = true })
R.Envoyer("essai_cle", { v = 2 }, "WHISPER", CIBLE, { cle = "fiche:x", etale = true })
attendu("une seule version attend", R.FileEnvoi(), 1)
attendu("  le remplacement est compté", R.Stats().remplaces - s1.remplaces, 1)
vider()
attendu("c'est la dernière qui part", partis(avant, nil, "v=2") == 1 and partis(avant, nil, "v=1") == 0, true)

dire("== un message refusé trop longtemps est abandonné, et ça se dit")
local s2 = R.Stats()
__refuserEnvois(R.ESSAIS_MAX + 5)
R.Envoyer("essai", { a = 4 }, "WHISPER", CIBLE)
__avancer(R.ESSAIS_MAX * (R.REPRISE + R.CADENCE) + 5)
attendu("abandonné", R.Stats().abandonnes - s2.abandonnes, 1)
__refuserEnvois(0)
vider()

dire("== 3. un message reçu à moitié")
local servis = {}
R.Ecouter("essai_recu", function(_, d) servis[#servis + 1] = d.v end)
local charge = "essai_recu|" .. R.Encoder({ v = "neuf" })
R.Recevoir("Blud-Apertus", "42:1:2:essai_recu|v=vie", "WHISPER")
attendu("reste en attente", R.EnAttente(), 1)
-- Blud fait /reload et reprend le numero 42 pour un message neuf : l'ancien
-- morceau 1 ne doit pas s'y coller.
R.Recevoir("Blud-Apertus", "42:1:2:" .. charge:sub(1, 8), "WHISPER")
R.Recevoir("Blud-Apertus", "42:2:2:" .. charge:sub(9), "WHISPER")
attendu("le message neuf arrive entier", servis[1], "neuf")
attendu("  l'ancien est compté écrasé", R.Stats().ecrases >= 1, true)
R.Recevoir("Blud-Apertus", "77:1:3:essai_recu|v=x", "WHISPER")
__avancerTemps(R.PEREMPTION + 1)
R.Recevoir("Blud-Apertus", "78:1:1:essai_recu|v=y", "WHISPER")
attendu("un message figé depuis une minute est jeté", R.EnAttente(), 0)
attendu("  et compté", R.Stats().perimes >= 1, true)

dire("== une seule piste : les Crossings passent par la même file")
__refuserEnvois(1)
avant = #__envois
attendu("un envoi brut est accepté", (R.EnvoyerBrut("ZGATE1", { "Z|1|1|2|aa", "Z|1|2|2|bb" }, "WHISPER", CIBLE)), true)
R.Envoyer("essai", { a = 5 }, "WHISPER", CIBLE)
vider()
attendu("les deux morceaux bruts partent, sous leur préfixe", partis(avant, "ZGATE1"), 2)
attendu("  et le message ordinaire aussi", partis(avant, R.PREFIXE, "a=5"), 1)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
