-- Crossings : la carte M du joueur — ses trois menus, et ses batiments
-- (3 novembre 2026).
--
-- On descendait du pays a la region, puis au batiment, d'un clic sur la
-- carte : il fallait savoir ou viser, et un bout de region devoile au bord de
-- l'ecran ne se cliquait pas. Trois menus disent maintenant ce qu'on connait
-- et y menent : Pays, Region, Batiment.
--
-- Les batiments ne se listent QUE dans une region : au niveau du pays ils
-- feraient une liste de tout ce qui a quatre murs.
--
-- Et un batiment ne s'etale plus sur la carte du dehors : son EMPREINTE est
-- batie ou l'on veut sur la carte du monde — sous elle, le plus souvent, pour
-- les images par seconde — tandis que son EMPLACEMENT dit ou il se tient dans
-- sa region. Les dessiner au meme endroit posait le temple a des lieues de
-- son village.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function essai(libelle, fn)
    local ok, err = pcall(fn)
    attendu(libelle, ok and "ok" or tostring(err), "ok")
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local ZG = LCM.Crossings
local function Poser(x, y, z) __position(y, x, z or 0) end
local function Tracer(sub, points)
    for _, p in ipairs(points) do
        Poser(p[1], p[2])
        ZG:AddRegionPoint(sub.id)
    end
    return sub
end
local function ZoneDuLieu(place) return ZG:GetPlaceAreas(place.id)[1].sub end
local function Joueur() LCM.db.settings.modeJoueur = true; LCM._masterCompanion = nil end
local function Maitre() LCM.db.settings.modeJoueur = nil; LCM._masterCompanion = true end

local perso = __personnage()
LCM.Personnages.Choisir(perso.id)

local pays = ZG:CreateCountry("Aelskar")
local combe = ZG:CreateZone("La Combe", pays.id)
local marches = ZG:CreateZone("Les Marches Grises", pays.id)
local village = ZG:CreatePlace(combe.id, "Le Village")
local donjon = ZG:CreatePlace(marches.id, "Le Donjon")
Tracer(ZoneDuLieu(village), { { 0, 0 }, { 80, 0 }, { 80, 80 }, { 0, 80 } })
Tracer(ZoneDuLieu(donjon), { { 900, 900 }, { 960, 900 }, { 960, 960 }, { 900, 960 } })
ZG:FinishRegion(ZoneDuLieu(village).id)
ZG:FinishRegion(ZoneDuLieu(donjon).id)

-- Un temple dans le village, dont l'interieur est bati a 4000 yards de la :
-- c'est ainsi qu'on gagne des images par seconde, et la carte ne doit pas s'en
-- apercevoir.
Poser(40, 40)
local temple = ZG:CreateBuildingPlace(combe.id, village.id, "Le Temple")
local empreinte = ZG:GetBatimentArea(temple.id)
Tracer(empreinte, { { 4000, 4000 }, { 4040, 4000 }, { 4040, 4040 }, { 4000, 4040 } })
ZG:FinishRegion(empreinte.id)
local nef = ZG:CreateRoomPlace(temple.id, "La Nef")
Tracer(ZoneDuLieu(nef), { { 4005, 4005 }, { 4035, 4005 }, { 4035, 4035 }, { 4005, 4035 } })
ZG:FinishRegion(ZoneDuLieu(nef).id)

essai("la carte des regions s'ouvre", function() ZG:ShowRegionMap() end)
local win = LCMCrossingsRegionMap
attendu("la fenetre existe", win ~= nil, true)

dire("== le dehors ne montre ni l'empreinte ni les pieces")
essai("on ouvre la region", function() win:ShowRegion(combe) end)
local dessinees = {}
for _, e in ipairs(win:Subs()) do dessinees[e.sub.id] = true end
attendu("la zone du village s'y dessine", dessinees[ZoneDuLieu(village).id], true)
attendu("l'empreinte du temple, non", dessinees[empreinte.id], nil)
attendu("sa nef non plus", dessinees[ZoneDuLieu(nef).id], nil)

dire("== le temple s'y marque a son emplacement")
local vus = win:Batiments()
attendu("un batiment est marque", #vus, 1)
if vus[1] then
    attendu("  c'est le temple", vus[1].place.id, temple.id)
    attendu("  pose dans le village", math.floor(vus[1].x) .. "/" .. math.floor(vus[1].y), "40/40")
end
-- Et la vue d'ensemble ne part pas chercher l'interieur a 4000 yards.
essai("la vue d'ensemble se cadre", function() win:Fit() end)
attendu("elle reste sur la region", win.cx < 500 and win.cy < 500, true)

dire("== sur sa propre carte, le temple montre son interieur")
essai("on ouvre le temple", function() win:ShowBatiment(temple) end)
local dedans = {}
for _, e in ipairs(win:Subs()) do dedans[e.sub.id] = true end
attendu("son empreinte y sert de contour", dedans[empreinte.id], true)
attendu("  sa nef y est dessinee", dedans[ZoneDuLieu(nef).id], true)
attendu("  le village du dehors n'y est pas", dedans[ZoneDuLieu(village).id], nil)

dire("== les trois menus")
attendu("le menu des pays existe", win.picker ~= nil, true)
attendu("celui des regions aussi", win.pickerRegion ~= nil, true)
attendu("celui des batiments aussi", win.pickerBati ~= nil, true)

-- Au niveau du pays, le menu des batiments se cache : il listerait tout ce
-- qui a quatre murs dans toutes les regions.
essai("on remonte au pays", function() win:ShowCountry(pays.id) end)
attendu("les batiments ne se listent pas ici", win.pickerBati:IsShown(), false)
attendu("  le menu des regions, si", win.pickerRegion:IsShown(), true)
essai("on redescend dans la region", function() win:ShowRegion(combe) end)
attendu("et la, ils se listent", win.pickerBati:IsShown(), true)

dire("== en MJ, les menus montrent tout")
attendu("les deux regions se listent", #win:RegionsListables(), 2)
attendu("  et le temple aussi", #win:BatimentsListables(), 1)
attendu("le menu des regions nomme la region ouverte",
    win.pickerRegion:GetText(), "La Combe")

dire("== en joueur, ils ne montrent que ce qu'on a foule et appris")
Joueur()
ZG:OublierDecouvertes()
essai("on rouvre la region", function() win:ShowRegion(combe) end)
attendu("aucune region connue", #win:RegionsListables(), 0)
attendu("  le menu s'eteint", win.pickerRegion.enabled, false)
attendu("  et aucun batiment", #win:BatimentsListables(), 0)

-- On marche dans le village : sa region se liste, son nom reste masque tant
-- qu'on ne nous l'a pas donne.
ZG.quietUntil = 0
Poser(40, 40); ZG:Tick()
attendu("la region foulee se liste", #win:RegionsListables(), 1)
attendu("  la region voisine, non", #win:RegionsListables() < 2, true)
essai("le menu se met a jour", function() win:ShowRegion(combe) end)
attendu("son nom reste masque", win.pickerRegion:GetText():find("La Combe") == nil, true)

-- Le nom du temple, lui, se donne. Sans cela son point ne se pose meme pas.
attendu("le temple inconnu ne se liste pas", #win:BatimentsListables(), 0)
attendu("  et son point ne se pose pas", #win:Batiments(), 0)
Maitre(); ZG:MarkLearnedSubZoneName(temple.id, true); Joueur()
attendu("le temple donne se liste", #win:BatimentsListables(), 1)
attendu("  et son point revient", #win:Batiments(), 1)

Maitre()
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
