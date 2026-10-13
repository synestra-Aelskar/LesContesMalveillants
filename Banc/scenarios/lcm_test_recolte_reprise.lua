-- Les points de recolte survivent a une reconnexion (13 octobre 2026).
--
-- Constate en jeu : un point pose, un crash, et au retour le point etait
-- toujours dans le carnet de placement mais plus sur le terrain — pas de
-- bouton « Recolter ». Les points poses etaient bien sauvegardes ; c'est leur
-- DEFINITION qui manquait au demarrage : elle vit dans un brouillon, et les
-- brouillons se rechargeaient apres que les recoltes s'etaient reconstruites.
--
-- Ici, on part d'une sauvegarde qui contient deja la definition (brouillon) et
-- un point pose, comme apres un /reload, et on verifie qu'il est actif.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- La sauvegarde d'avant le crash : la definition en brouillon, le point pose.
LCM.Brouillons.Set("ressources", { id = "eau_temoin", label = "Eau témoin" })
LCM.Brouillons.Set("points", {
    id = "puiser_temoin", label = "Puiser de l'eau", nature = "ressource", offres = {},
    recolte = { entree = "ressources/eau_temoin", min = 1, max = 1, dd = 0, rayon = 3 },
})
LCM.EnsureDatabase()
LCM.db.recoltes = { r_avant = { def = "puiser_temoin", x = 10, y = 20, source = "monde",
    carte = LCM.Recolte.Carte(), quand = 1 } }

attendu("avant la connexion, la définition n'est pas chargée", LCM.Points.Get("puiser_temoin"), nil)

__declencher("PLAYER_LOGIN")
__personnage()

dire("== au retour, le point est actif")
attendu("la définition est rechargée", LCM.Points.Get("puiser_temoin") ~= nil, true)
attendu("le carnet a toujours le point", LCM.Recoltes.Compte("puiser_temoin"), 1)
attendu("le point est connu sur le terrain", LCM.Recolte.points.r_avant ~= nil, true)
__position(11, 21, 0)
__avancer(0.3)
local bouton = LCM.UI.Recolte.bouton
attendu("le bouton « Récolter » apparaît", bouton and bouton:IsShown(), true)
attendu("  pour ce point", bouton and bouton.nom:GetText(), "Puiser de l'eau")

dire("== et un joueur qui le demande le reçoit")
__groupe({ LCM.PlayerId(), "Claydenn-Apertus" })
-- Le MJ voit Claydenn arriver et le sert aussitot, a lui seul.
local avant = #__envois
__declencher("GROUP_ROSTER_UPDATE")
attendu("Claydenn est servi à son arrivée", #__envois > avant, true)
avant = #__envois
LCM.Reseau.Recevoir("Claydenn-Apertus", "1:1:1:" .. LCM.Recolte.SUJETS.demande .. "|" .. LCM.Reseau.Encoder({}))
attendu("une réponse lui part", #__envois > avant, true)

-- Les envois d'un sujet depuis `depuis` : { canal, cible } de chacun.
local function Envois(sujet, depuis)
    local out = {}
    for i = depuis + 1, #__envois do
        local e = __envois[i]
        local corps = e.message:match("^%d+:%d+:%d+:(.*)$")
        if corps and corps:sub(1, #sujet + 1) == sujet .. "|" then out[#out + 1] = e end
    end
    return out
end
local DEF = LCM.Recolte.SUJETS.definition

dire("== un joueur arrive dans le groupe : il reçoit sans rien demander")
-- Pas de /reload chez lui : c'est le MJ qui le sert en le voyant arriver.
avant = #__envois
__groupe({ LCM.PlayerId(), "Claydenn-Apertus", "Nytherah-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")
local partis = Envois(DEF, avant)
attendu("une définition part", #partis, 1)
attendu("  au seul nouveau venu", partis[1] and partis[1].cible, "Nytherah-Apertus")
attendu("  en chuchotement", partis[1] and partis[1].canal, "WHISPER")
avant = #__envois
__declencher("GROUP_ROSTER_UPDATE")
attendu("rien de nouveau dans le groupe : rien ne part", #Envois(DEF, avant), 0)

dire("== un groupe entier d'un coup : une seule diffusion")
avant = #__envois
__groupe({ LCM.PlayerId(), "Claydenn-Apertus", "Nytherah-Apertus",
    "A-Apertus", "B-Apertus", "C-Apertus", "D-Apertus" }, true)
__declencher("GROUP_ROSTER_UPDATE")
partis = Envois(DEF, avant)
attendu("un seul envoi", #partis, 1)
attendu("  au raid", partis[1] and partis[1].canal, "RAID")

dire("== le MJ se connecte : ceux déjà là reçoivent tout")
-- Le joueur deja connecte n'a pas a se reconnecter : le MJ, des qu'il est
-- pret, envoie ses points au groupe. Une question posee par le joueur a
-- l'instant de la connexion du MJ arriverait avant que son addon n'ecoute.
avant = #__envois
LCM.Recoltes.Reconstruire()
-- On rejoue l'arrivee du MJ : il ne connait encore personne.
__groupe({ LCM.PlayerId(), "Claydenn-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")
__groupe({ LCM.PlayerId(), "Claydenn-Apertus", "A-Apertus", "B-Apertus", "C-Apertus", "D-Apertus", "E-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")
attendu("des points partent au groupe", #Envois(DEF, avant) > 0, true)

dire("== groupe permanent : celui qui se RECONNECTE est servi")
-- Le groupe ne se defait jamais (constate en jeu, 13 octobre 2026) : un joueur
-- deconnecte reste dans la liste, et a son retour il n'etait pas « nouveau ».
-- Rien ne lui partait des points poses pendant son absence.
__groupe({ LCM.PlayerId(), "Claydenn-Apertus" })
__declencher("GROUP_ROSTER_UPDATE")
UnitIsConnected = function(unite) return (UnitName(unite)) ~= "Claydenn" end
__declencher("UNIT_CONNECTION")
avant = #__envois
UnitIsConnected = nil
__declencher("UNIT_CONNECTION")
attendu("pas tout de suite : son addon charge encore", #Envois(DEF, avant), 0)
__avancer(6)
local servi = Envois(DEF, avant)
attendu("quelques secondes après, il est servi", #servi, 1)
attendu("  à lui seul", servi[1] and servi[1].cible, "Claydenn-Apertus")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
