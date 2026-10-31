-- Crossings dans la base commune (31 octobre 2026).
--
-- Les pays, regions, lieux, passages et themes de Crossings ne vivaient que
-- dans la sauvegarde de leur auteur. Ils partent maintenant dans la base,
-- famille « crossings », reservee au MJ, par la meme file que les poses.
-- Ce qu'on verifie :
--   * ce que j'ai cree part dans la file d'envoi, une entree par chose, les
--     points d'un perimetre plies en une chaine ;
--   * une entree qui n'a pas change ne repart pas ;
--   * une suppression part explicitement (masque) ;
--   * la base rend ce qui MANQUE (une sauvegarde perdue, ou l'autre MJ), sans
--     rien ecraser de ce qui existe ;
--   * la famille ne part jamais chez les joueurs.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local ZG, Base, B = LCM.Crossings, LCM.CrossingsBase, LCM.Brouillons
local function Entree(id)
    for _, e in ipairs(B.List("crossings")) do if e.id == id then return e end end
end

dire("== ce que je cree part dans la base")
__position(0, 0, 0)
local pays = ZG:CreateCountry("Aelskar")
local zone = ZG:CreateZone("Forêt Automnale", pays.id)
local lieu = ZG:CreatePlace(zone.id, "Bois des Sorcières")
local sub = ZG:CreateSubZone(zone.id, "Lisière", lieu.id)
ZG:SetSubZoneShape(sub.id, "polygon")
for _, p in ipairs({ { 0, 0 }, { 30, 0 }, { 30, 30 }, { 0, 30 } }) do
    __position(p[1], p[2], 0)
    ZG:AddRegionPoint(sub.id)
end
ZG:FinishRegion(sub.id)
local theme = ZG:CreateTheme("Automne")
__avancer(3)
attendu("le pays est dans la file", Entree(pays.id) and Entree(pays.id).genre, "pays")
attendu("la region aussi", Entree(zone.id) and Entree(zone.id).genre, "region")
attendu("avec ses lieux", Entree(zone.id) and Entree(zone.id).donnees.places[lieu.id] ~= nil, true)
attendu("mais sans ses passages (a part)", Entree(zone.id) and Entree(zone.id).donnees.subZones, nil)
attendu("le passage a son entree", Entree(sub.id) and Entree(sub.id).genre, "passage")
attendu("ses points plies en une chaine", Entree(sub.id) and type(Entree(sub.id).donnees.points), "string")
attendu("et sa region", Entree(sub.id) and Entree(sub.id).donnees.zoneId, zone.id)
attendu("le theme aussi", Entree(theme.id) and Entree(theme.id).genre, "theme")

dire("== une entree inchangee ne repart pas")
local ecrites = Base.Noter()
attendu("rien a ecrire", ecrites, 0)
ZG:RenameZone(zone.id, "Forêt d'Automne")
__avancer(3)
attendu("un renommage repart", Entree(zone.id) and Entree(zone.id).label, "Forêt d'Automne")

dire("== la base rend ce qui manque")
-- Une sauvegarde perdue : tout disparait ici, la base l'a encore.
local db = ZG:GetDB()
local sauve = LCM.Copie(db)
db.countries, db.zones, db.themes = {}, {}, {}
local rendus = Base.Rendre()
attendu("tout revient", rendus, 4)
attendu("la region", db.zones[zone.id] and db.zones[zone.id].name, "Forêt d'Automne")
attendu("son lieu", db.zones[zone.id] and db.zones[zone.id].places[lieu.id] ~= nil, true)
local revenu = db.zones[zone.id] and db.zones[zone.id].subZones[sub.id]
attendu("son passage, avec ses quatre sommets", revenu and #revenu.points, 4)
attendu("des sommets en nombres", revenu and type(revenu.points[1].x), "number")
attendu("le pays", db.countries[pays.id] ~= nil, true)
attendu("le theme", db.themes[theme.id] ~= nil, true)
-- Ce qui existe deja n'est pas ecrase.
db.zones[zone.id].name = "Nom de seance"
attendu("rien a rendre quand rien ne manque", Base.Rendre(), 0)
attendu("la seance l'emporte", db.zones[zone.id].name, "Nom de seance")
ZG:RenameZone(zone.id, "Forêt d'Automne")

dire("== une suppression part explicitement")
ZG:RemoveZone(zone.id)
__avancer(3)
attendu("la region quitte la file", Entree(zone.id), nil)
attendu("et part en suppression", B.Masques("crossings")[zone.id], true)
attendu("son passage aussi", B.Masques("crossings")[sub.id], true)
attendu("le pays reste", Entree(pays.id) ~= nil, true)

dire("== reservee au MJ")
attendu("famille connue de la file d'envoi", (function()
    for _, f in ipairs(B.FAMILLES) do if f == "crossings" then return true end end
    return false end)(), true)
attendu("jamais poussee aux joueurs en seance", LCM.BasePublique.REGISTRES.crossings, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
