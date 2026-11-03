-- Crossings : les ETAGES d'un batiment (3 novembre 2026).
--
-- Une piece porte son NIVEAU : 0 au rez, negatif dans les caves, de -8000 a
-- 8000. Il ne sert qu'a l'AFFICHAGE — on ne montre d'un batiment qu'un etage
-- a la fois, sans quoi ses cloisons se superposeraient toutes sur le meme
-- plan et ne se liraient plus.
--
-- C'est la TRANCHE d'altitude, elle, qui decide ou l'on est vraiment (voir
-- lcm_test_crossings_altitude) : un etage mal numerote se lit de travers, il
-- n'enferme personne.
--
-- Ce qu'on verifie :
--
--   * le niveau se pose, se borne, et zero ne s'ecrit pas ;
--   * la liste des etages d'un batiment, du plus bas au plus haut ;
--   * la carte du joueur ne montre que l'etage regarde, empreinte comprise ;
--   * on arrive a l'etage ou l'on se tient ;
--   * la carte de l'editeur suit la meme regle ;
--   * et tout cela traverse la serialisation.

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
local panneau = LCMCrossingsPanel
local function Poser(x, y, z) __position(y, x, z or 0) end
local function Tracer(sub, points, z)
    for _, p in ipairs(points) do
        Poser(p[1], p[2], z)
        ZG:AddRegionPoint(sub.id)
    end
    return sub
end
local function ZoneDuLieu(place) return ZG:GetPlaceAreas(place.id)[1].sub end

local perso = __personnage()
LCM.Personnages.Choisir(perso.id)

local region = ZG:CreateZone("Les Cimes")
local clairiere = ZG:CreatePlace(region.id, "La Clairiere")
Tracer(ZoneDuLieu(clairiere), { { 0, 0 }, { 100, 0 }, { 100, 100 }, { 0, 100 } })
ZG:FinishRegion(ZoneDuLieu(clairiere).id)

Poser(50, 50, 100)
local tour = ZG:CreateBuildingPlace(region.id, clairiere.id, "Tour des lamentations")
local empreinte = ZG:GetBatimentArea(tour.id)
Tracer(empreinte, { { 30, 30 }, { 70, 30 }, { 70, 70 }, { 30, 70 } }, 100)
ZG:FinishRegion(empreinte.id)
ZG:SetSubZoneHeights(empreinte.id, 20, 60)

dire("== une piece porte son etage")
local cave = ZG:CreateRoomPlace(tour.id, "La Cave", -1)
local hall = ZG:CreateRoomPlace(tour.id, "Le Hall")
local chambre = ZG:CreateRoomPlace(tour.id, "La Chambre", 2)
attendu("la cave est au -1", ZG:GetNiveau(cave), -1)
attendu("le hall est au rez", ZG:GetNiveau(hall), 0)
attendu("  et zero ne s'ecrit meme pas", hall.niveau, nil)
attendu("la chambre est au 2", ZG:GetNiveau(chambre), 2)

ZG:SetNiveau(hall.id, 1)
attendu("on le change a la main", ZG:GetNiveau(hall), 1)
ZG:SetNiveau(hall.id, 0)
attendu("  et on revient au rez", ZG:GetNiveau(hall), 0)
-- Les bornes : -8000 a 8000, et pas au-dela.
ZG:SetNiveau(chambre.id, 99999)
attendu("on ne monte pas au-dessus de 8000", ZG:GetNiveau(chambre), 8000)
ZG:SetNiveau(chambre.id, -99999)
attendu("  ni au-dessous de -8000", ZG:GetNiveau(chambre), -8000)
ZG:SetNiveau(chambre.id, 2)

dire("== les etages d'un batiment se listent, du bas vers le haut")
local niveaux = ZG:GetNiveauxBatiment(tour.id)
attendu("il en a trois", #niveaux, 3)
attendu("  dans l'ordre", table.concat(niveaux, ","), "-1,0,2")
local vide = ZG:CreateBuildingPlace(region.id, clairiere.id, "La Remise")
attendu("un batiment sans piece a quand meme un sol",
    table.concat(ZG:GetNiveauxBatiment(vide.id), ","), "0")

-- Chaque piece a son plan AU MEME ENDROIT : c'est tout l'interet des etages.
-- Ce qui les separe, c'est leur TRANCHE d'altitude — le niveau n'est qu'un
-- numero pour la carte, c'est la hauteur qui dit ou l'on est vraiment.
for _, p in ipairs({ { cave, 80 }, { hall, 100 }, { chambre, 140 } }) do
    local sub = ZoneDuLieu(p[1])
    Tracer(sub, { { 35, 35 }, { 65, 35 }, { 65, 65 }, { 35, 65 } }, p[2])
    ZG:FinishRegion(sub.id)
    sub.z = p[2]
    ZG:SetSubZoneHeights(sub.id, 9, 9)
end

dire("== la carte du joueur ne montre qu'un etage")
essai("la carte s'ouvre", function() ZG:ShowRegionMap() end)
local win = LCMCrossingsRegionMap
essai("on entre dans la tour", function() win:ShowBatiment(tour) end)
attendu("on arrive au rez", win.etage, 0)
local function PlansVus()
    local vus = {}
    for _, e in ipairs(win:Subs()) do
        local lieu = e.sub.enterPlace and ZG:FindPlace(e.sub.enterPlace)
        if lieu then vus[lieu.id] = true end
    end
    return vus
end
local vus = PlansVus()
attendu("l'empreinte est la", vus[tour.id], true)
attendu("  le hall aussi", vus[hall.id], true)
attendu("  la cave, non", vus[cave.id], nil)
attendu("  la chambre non plus", vus[chambre.id], nil)

essai("on descend a la cave", function() win:ShowEtage(-1) end)
vus = PlansVus()
attendu("la cave est la", vus[cave.id], true)
attendu("  le hall, non", vus[hall.id], nil)
attendu("l'empreinte reste a tous les etages", vus[tour.id], true)

dire("== on arrive a l'etage ou l'on se tient")
-- Dans la chambre : l'entree dans le batiment doit ouvrir le 2.
ZG.here = { [chambre.id] = true }
essai("on rouvre la tour", function() win:ShowBatiment(tour) end)
attendu("on arrive au 2", win.etage, 2)
ZG.here = {}

dire("== la carte de l'editeur suit la meme regle")
essai("la fiche du batiment s'ouvre", function()
    panneau.mode, panneau.placeId, panneau.zoneId, panneau.placeTab =
        "place", tour.id, region.id, "carte"
    panneau.batiNiveau = 0
    panneau:RefreshAll()
end)
local dedans = {}
for _, e in ipairs(panneau.batiMap:Dessinables()) do
    local lieu = e.sub.enterPlace and ZG:FindPlace(e.sub.enterPlace)
    if lieu then dedans[lieu.id] = true end
end
attendu("le hall s'y dessine", dedans[hall.id], true)
attendu("  la chambre, non", dedans[chambre.id], nil)
attendu("  l'empreinte sert de contour", dedans[tour.id], true)

essai("on passe au 2", function()
    panneau.batiNiveau = 2
    panneau:RefreshAll()
end)
dedans = {}
for _, e in ipairs(panneau.batiMap:Dessinables()) do
    local lieu = e.sub.enterPlace and ZG:FindPlace(e.sub.enterPlace)
    if lieu then dedans[lieu.id] = true end
end
attendu("la chambre s'y dessine", dedans[chambre.id], true)
attendu("  le hall, non", dedans[hall.id], nil)

dire("== dans un batiment, le dehors ne compte plus")
-- Nos interieurs sont batis ailleurs sur la carte du monde — SOUS la region,
-- le plus souvent, pour les images par seconde. Leurs cloisons croisent alors
-- des frontieres de plein air qui n'ont rien a voir avec eux : on traversait
-- des lieux de la foret en marchant dans une cave.
--
-- Ici, la tour est posee EN PLEIN DANS la clairiere, et sa tranche la separe
-- en hauteur : sol a 100, de -20 a +60.
local carte = empreinte.mapID
attendu("au sol de la clairiere, on est dehors",
    (ZG:LieuContenant(50, 50, carte, nil, 300)), clairiere.id)
attendu("dans la tranche du hall, on est dans le hall",
    (ZG:LieuContenant(50, 50, carte, nil, 100)), hall.id)
attendu("  dix yards plus bas, dans la cave",
    (ZG:LieuContenant(50, 50, carte, nil, 80)), cave.id)
attendu("  et c'est bien la tour qu'on trouve",
    (ZG:BatimentContenant(50, 50, carte, 100)).id, tour.id)
attendu("  au-dessus du toit, plus de batiment",
    ZG:BatimentContenant(50, 50, carte, 300), nil)

-- Et le tic ne fait plus traverser les frontieres du dehors.
ZG.quietUntil = 0
ZG.here = {}
Poser(50, 50, 300); ZG:Tick()
attendu("dehors, on est dans la clairiere", ZG:IsInPlace(clairiere.id), true)
Poser(50, 50, 100); ZG:Tick()
attendu("dedans, on est dans le hall", ZG:IsInPlace(hall.id), true)
-- La clairiere est GELEE, pas oubliee : on y est toujours, mais ses
-- frontieres ne se traversent plus tant qu'on est a l'interieur.
Poser(55, 55, 100); ZG:Tick()
attendu("  et le dehors ne se retraverse pas", ZG:IsInPlace(hall.id), true)
ZG.here = {}

dire("== dans un batiment, c'est la piece puis le batiment")
-- La region n'apprend plus rien une fois dedans : on sait dans quel bois se
-- tient la tour. La banniere annonce la piece, et le batiment la situe.
local titre, sous = ZG:ResolveBannerText(hall, ZG:GetZone(region.id))
attendu("la banniere nomme la piece", titre, "Le Hall")
attendu("  puis le batiment", sous, "Tour des lamentations")
-- Dehors, rien ne change : la region, puis le lieu.
titre, sous = ZG:ResolveBannerText(clairiere, ZG:GetZone(region.id))
attendu("dehors, la region d'abord", titre, "Les Cimes")
attendu("  puis le lieu", sous, "La Clairiere")
-- Sur la CARTE, l'ordre est celui de ce qu'on vise : le lieu, puis son cadre.
titre, sous = ZG:ResolveMapText(clairiere, ZG:GetZone(region.id))
attendu("sur la carte, le lieu d'abord", titre, "La Clairiere")
attendu("  puis la region", sous, "Les Cimes")
titre, sous = ZG:ResolveMapText(hall, ZG:GetZone(region.id))
attendu("dans un batiment, les deux ordres se rejoignent", titre, "Le Hall")
attendu("  et le batiment situe", sous, "Tour des lamentations")

dire("== tout cela traverse la serialisation")
local texte = ZG.PackState()
local avant = LCM_Crossings
LCM_Crossings = { countries = {}, zones = {}, themes = {}, continents = {} }
for ligne in (texte .. "\n"):gmatch("([^\n]+)") do ZG.ApplyStateLine(ligne, UnitName("player")) end
local relu = LCM_Crossings.zones[region.id]
attendu("la cave garde son etage", relu.places[cave.id].niveau, -1)
attendu("la chambre aussi", relu.places[chambre.id].niveau, 2)
attendu("le rez ne s'ecrit toujours pas", relu.places[hall.id].niveau, nil)
LCM_Crossings = avant

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
