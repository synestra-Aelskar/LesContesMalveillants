-- Un coffre qui ne repond pas ne se verrouille pas pour toujours
-- (20 octobre 2026).
--
-- Ranger ou prendre attend la reponse du proprietaire du coffre et refuse le
-- transfert suivant en attendant. Si elle ne venait jamais (proprietaire
-- deconnecte, message perdu, .gps muet ou qui trouve le joueur trop loin), le
-- coffre repondait « déjà en attente » a tout jusqu'au /reload, et l'objet
-- retire du sac ne revenait pas.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local C, Ecran = LCM.Coffres, LCM.UI.Coffre
pcall(Ecran.Ouvrir, "coffre_fantome")
local f = Ecran.frame
attendu("la fenetre du coffre existe", f ~= nil, true)

-- Le proprietaire ne repond jamais.
local envoyer = C.Envoyer
C.Envoyer = function() return true end

dire("== ranger sans reponse")
local rendus, retraits = 0, 0
local objet = { ref = "objets/x", quantite = 1, origine = { case = 1 },
    retirer = function() retraits = retraits + 1 end, rendre = function() rendus = rendus + 1 end }
attendu("le rangement part", f:Ranger(objet), true)
attendu("l'objet a quitte le sac", retraits, 1)
attendu("le suivant attend", f:Ranger(objet), false)
__avancer(11)
attendu("au bout du delai : l'objet revient", rendus, 1)
attendu("  et le coffre se deverrouille", f.rangementEnAttente, nil)
attendu("  il le dit", __sansCouleur(__sorties[#__sorties]):find("n'a pas répondu", 1, true) ~= nil, true)

dire("== une reponse tardive qui accepte reprend l'objet")
Ecran.Repondre("Proprio-Apertus", { action = "ranger", ok = true })
attendu("l'objet ressort du sac", retraits, 2)
attendu("  une seule fois", f.rangementExpire, nil)

dire("== une reponse a l'heure ne declenche rien plus tard")
rendus = 0
f:Ranger(objet)
f.rangementEnAttente = nil   -- la reponse est arrivee
__avancer(11)
attendu("rien n'est rendu en double", rendus, 0)

dire("== prendre sans reponse")
local prises = 0
local prendre = LCM.Inventaire.Prendre
LCM.Inventaire.Prendre = function() prises = prises + 1 return true end
local glisse = f:ObjetGlissable({ ref = "objets/y", quantite = 2 })
glisse.retirer()
attendu("la prise attend", f.priseGlissee ~= nil, true)
__avancer(11)
attendu("au bout du delai : le verrou tombe", f.priseGlissee, nil)
attendu("  ce qui avait ete pose d'avance ressort du sac", prises, 2)
LCM.Inventaire.Prendre = prendre

C.Envoyer = envoyer
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
