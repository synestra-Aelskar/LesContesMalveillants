-- Un objet supprime ne fait pas disparaitre le coffre qui le contenait
-- (20 octobre 2026). Le MJ : « il ne doit pas disparaitre en entier si un de
-- ses objets a ete supprime, mais si TOUS ses objets l'ont ete ».
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.Objets.Add({ id = "garde_temoin", label = "Objet gardé", categorie = "accessoire",
    icone = "inv_misc_key_01", etat = { courant = 1, max = 1 }, pileMax = 1 })

local function Coffre(id, objets)
    return { id = id, label = id, nature = "coffre",
        coffre = { places = 4, rayon = 5, verrous = 0, objets = objets, expertises = {}, outils = {} } }
end

dire("== un objet sur deux a disparu : le coffre reste")
local ok = LCM.Brouillons.Enregistrer("points", Coffre("coffre_moitie", {
    { entree = "objets/garde_temoin", quantite = 2 },
    { entree = "objets/supprime_temoin", quantite = 1 } }), true)
attendu("le coffre est accepte", ok, true)
local p = LCM.Points.Get("coffre_moitie")
attendu("il existe", p ~= nil, true)
attendu("  avec l'objet qui reste", p and #p.coffre.objets == 1 and p.coffre.objets[1].entree, "objets/garde_temoin")
attendu("  et sa quantite", p and p.coffre.objets[1].quantite, 2)
local dernier = __sansCouleur(__sorties[#__sorties] or "")
attendu("on dit ce qui a ete laisse de cote", dernier:find("supprime_temoin", 1, true) ~= nil
    and dernier:find("laissé", 1, true) ~= nil, true)

dire("== tous ses objets ont disparu : le coffre tombe, et on dit pourquoi")
local ok2, raison = LCM.Brouillons.Enregistrer("points", Coffre("coffre_vide", {
    { entree = "objets/supprime_temoin", quantite = 1 },
    { entree = "objets/autre_supprime", quantite = 1 } }), true)
attendu("refuse", ok2 == true, false)
attendu("  la raison le dit", tostring(raison):find("tous les objets", 1, true) ~= nil, true)
attendu("  il n'existe pas", LCM.Points.Get("coffre_vide"), nil)

dire("== un coffre pose vide reste valide")
attendu("accepte", LCM.Brouillons.Enregistrer("points", Coffre("coffre_sans_rien", {}), true), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
