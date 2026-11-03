-- banc: --sans-mj
-- La synchronisation forcee, cote JOUEUR (Core/Synchro.lua, 3 novembre 2026) :
-- l'annonce « synchro! » d'un MJ fait relancer les demandes de connexion,
-- dont la base publique, meme si la derniere demande date de moins de 30 s.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__groupe({ "Meneur-Apertus" })
__declencher("PLAYER_LOGIN")
__personnage()

local R = LCM.Reseau
attendu("joueur, pas MJ", LCM.IsMaster(), false)
local envois = {}
local envoyer = R.Envoyer
R.Envoyer = function(sujet, donnees, canal, cible, options)
    envois[#envois + 1] = { sujet = sujet }
    return envoyer(sujet, donnees, canal, cible, options)
end
local function compte(sujet)
    local n = 0
    for _, e in ipairs(envois) do if e.sujet == sujet then n = n + 1 end end
    return n
end

-- Une demande vient de partir (la connexion) : sans la synchro, la suivante
-- attendrait 30 secondes.
LCM.BasePublique.Demander(true)
__avancerTemps(5)
__avancer(5)
envois = {}

local numero = 900
R.Recevoir("Meneur-Apertus", string.format("%d:1:1:%s|%s", numero, "synchro!", R.Encoder({})))
attendu("la base publique est redemandée", compte("base?") >= 1, true)
attendu("et les autres demandes avec elle", #envois >= 3, true)
attendu("les accès aux traits aussi", compte("traits_acces_demande") >= 1, true)

dire("== la liste poussée par le MJ, sans l'avoir demandée")
-- Le bouton du MJ pousse sa liste a tous : le joueur la compare a la sienne
-- et ne reclame que ce qui lui manque. Une entree inconnue d'ici :
__avancerTemps(40)
__avancer(40)
envois = {}
local corps = LCM.Lien.Serialiser({ ["traits/trait_inconnu_synchro"] = "rev1" })
R.Recevoir("Meneur-Apertus", string.format("%d:1:1:%s|%s", numero + 5, "base_liste", R.Encoder({ corps = corps })))
attendu("le joueur réclame ce qui lui manque", compte("base_demande"), 1)

dire("== une annonce de quelqu'un hors du groupe et hors canal est ignorée")
__avancerTemps(30)
envois = {}
R.Recevoir("Inconnu-Apertus", string.format("%d:1:1:%s|%s", numero + 1, "synchro!", R.Encoder({})), "WHISPER")
attendu("rien ne part", #envois, 0)

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
