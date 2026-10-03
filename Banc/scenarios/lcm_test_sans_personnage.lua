-- Une installation toute neuve : aucun personnage.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")

dire("== rien ne se cree tout seul")
attendu("aucun personnage", LCM.Personnages.Compte(), 0)
attendu("et personne a jouer", LCM.Entities.Self(), nil)
-- Ouvrir des fenetres ne doit en fabriquer aucun : c'est ce qui arrivait avant
-- le 3 octobre 2026, ou le simple fait d'afficher une fiche creait un
-- personnage au nom du personnage WoW, sans race ni points.
LCM.UI.Fiche.Fenetre():Montrer()
LCM.UI.Inventaires.Basculer()
LCM.UI.Bourse.Basculer()
attendu("ouvrir des fenetres n'en cree pas", LCM.Personnages.Compte(), 0)

dire("== le sceau mene a la creation")
local R = LCM.UI.Radial
local sceau = R.Fenetre()
sceau.sceau:Click("LeftButton")
attendu("la creation s'ouvre", LCM.UI.Creation.frame:IsShown(), true)
attendu("et pas la couronne des fenetres", sceau.ouvert, nil)
LCM.UI.Creation.frame:Hide()

dire("== une fois un personnage cree, le sceau reprend son role")
local moi = LCM.Personnages.Creer("Ysolde", { race = "humain", niveau = 5 })
attendu("il existe", LCM.Personnages.Compte(), 1)
attendu("et c'est lui qu'on joue", LCM.Entities.Self().id, moi.id)
sceau.sceau:Click("LeftButton")
attendu("le sceau ouvre la couronne", sceau.ouvert ~= nil, true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
