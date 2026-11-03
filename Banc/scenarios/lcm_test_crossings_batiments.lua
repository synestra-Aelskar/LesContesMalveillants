-- Crossings : les batiments, leurs pieces et leur tranche d'altitude
-- (2 novembre 2026).
--
-- Une zone a ciel ouvert monte et descend sans fin, EXPRES : survoler sa
-- region, c'est encore y etre. Un interieur, lui, doit se refermer — sinon
-- une cave et la place au-dessus d'elle seraient le meme endroit.
--
-- Ce qu'on verifie :
--
--   * un BATIMENT est un lieu dont l'etendue porte une tranche d'altitude
--     (bas / haut en yards depuis le sol releve en le posant) ;
--   * on ne dessine pas un volume sommet par sommet : on dessine son sol,
--     puis on dit de combien il descend et monte ;
--   * ses PIECES se rangent dessous et heritent de sa tranche ; un batiment
--     est a ses pieces ce qu'une region est a ses lieux ;
--   * un interieur ne s'etale pas sur la carte de la region : il s'y marque
--     d'un point, et sa propre carte montre ses cloisons ;
--   * et tout cela traverse la serialisation, sinon rien n'arriverait au
--     binome.

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

-- UnitPosition rend y AVANT x (voir Core/Crossings.lua) : on pose (y, x, z)
-- pour que le sommet soit range en (x, y). L'altitude, elle, vient en clair.
local function Poser(x, y, z) __position(y, x, z or 0) end
local function Tracer(sub, points, z)
    for _, p in ipairs(points) do
        Poser(p[1], p[2], z)
        ZG:AddRegionPoint(sub.id)
    end
    return sub
end
local function ZoneDuLieu(place) return ZG:GetPlaceAreas(place.id)[1].sub end

local region = ZG:CreateZone("Le Haut Pays")
local place = ZG:CreatePlace(region.id, "La Place")
Tracer(ZoneDuLieu(place), { { 0, 0 }, { 100, 0 }, { 100, 100 }, { 0, 100 } })
ZG:FinishRegion(ZoneDuLieu(place).id)

dire("== un batiment nait avec son empreinte et sa hauteur")
-- Au sol 50 : la tour monte de 12 et descend de 6 par defaut.
Poser(40, 40, 50)
local tour = ZG:CreateBuildingPlace(region.id, place.id, "Tour d'Asrena")
attendu("le batiment est cree", tour ~= nil, true)
attendu("  c'en est un", ZG:EstBatiment(tour), true)
attendu("  range sous son lieu", tour.parent, place.id)
local empreinte = ZG:GetBatimentArea(tour.id)
attendu("son empreinte nait avec lui", empreinte ~= nil, true)
attendu("  c'est une etendue", empreinte.shape, "polygon")
attendu("  avec un sol releve", empreinte.z, 50)
attendu("  qui descend", empreinte.bas, 6)
attendu("  et qui monte", empreinte.haut, 12)
-- Un lieu ordinaire, lui, n'a pas de tranche : sa hauteur est infinie.
attendu("un lieu ordinaire n'a pas de tranche", ZoneDuLieu(place).bas, nil)
attendu("  ni de plafond", ZoneDuLieu(place).haut, nil)

-- On dessine son sol, puis on dit jusqu'ou il va : pas de sommet en 3D.
Tracer(empreinte, { { 30, 30 }, { 60, 30 }, { 60, 60 }, { 30, 60 } }, 50)
ZG:FinishRegion(empreinte.id)
attendu("l'empreinte se ferme", empreinte.regionReady, true)
attendu("on regle sa tranche", ZG:SetSubZoneHeights(empreinte.id, 8, 30), true)
attendu("  elle descend de 8", empreinte.bas, 8)
attendu("  et monte de 30", empreinte.haut, 30)
-- Zero = pas de limite de ce cote : un sous-sol sans fond se dit ainsi.
ZG:SetSubZoneHeights(empreinte.id, 0, 30)
attendu("zero vaut « sans limite »", empreinte.bas, nil)
ZG:SetSubZoneHeights(empreinte.id, 8, 30)

dire("== la tranche decide si l'on est dedans")
attendu("au niveau du sol, dedans", ZG.DansLaTranche(empreinte, 50), true)
attendu("un etage plus haut, dedans", ZG.DansLaTranche(empreinte, 70), true)
attendu("au-dessus du toit, dehors", ZG.DansLaTranche(empreinte, 90), false)
attendu("sous les fondations, dehors", ZG.DansLaTranche(empreinte, 40), false)
-- Altitude introuvable : on ne fait pas valoir la tranche, plutot que
-- d'enfermer le joueur dehors sans rien dire.
attendu("altitude inconnue : on ne bloque pas", ZG.DansLaTranche(empreinte, nil), true)
-- Et le lieu qui nous entoure suit la meme regle.
attendu("au sol, on est dans la tour",
    (ZG:LieuContenant(45, 45, empreinte.mapID, nil, 55)), tour.id)
attendu("au-dessus du toit, on est sur la place",
    (ZG:LieuContenant(45, 45, empreinte.mapID, nil, 200)), place.id)

dire("== ses pieces heritent de sa tranche")
local atrium = ZG:CreateRoomPlace(tour.id, "Atrium")
attendu("la piece est creee", atrium ~= nil, true)
attendu("  rangee dans la tour", atrium.parent, tour.id)
attendu("  ce n'est pas un batiment", ZG:EstBatiment(atrium), false)
local salle = ZoneDuLieu(atrium)
attendu("  sa zone reprend le sol", salle.z, 50)
attendu("  et la tranche", salle.bas .. "/" .. salle.haut, "8/30")
attendu("la tour la compte", #ZG:GetPieceList(tour.id), 1)
-- Un etage se fait en reprenant la hauteur de la piece la ou l'on se tient.
Poser(45, 45, 70)
attendu("on reprend le sol d'un etage", ZG:RecaptureSubZoneHeight(salle.id), true)
attendu("  le repere a monte", salle.z, 70)
salle.z = 50

-- La piece est un INTERIEUR, l'empreinte du batiment non : c'est elle qui
-- porte le point sur la carte du dehors.
Tracer(salle, { { 35, 35 }, { 55, 35 }, { 55, 55 }, { 35, 55 } }, 50)
ZG:FinishRegion(salle.id)
attendu("la piece est un interieur", ZG:EstInterieur(salle), true)
attendu("l'empreinte du batiment, non", ZG:EstInterieur(empreinte), false)
attendu("une zone a ciel ouvert non plus", ZG:EstInterieur(ZoneDuLieu(place)), false)
attendu("le batiment de la piece, c'est la tour", (ZG:BatimentDe(atrium)).id, tour.id)
attendu("  celui de la tour, elle-meme", (ZG:BatimentDe(tour)).id, tour.id)
attendu("  la place n'est dans aucun", ZG:BatimentDe(place), nil)

dire("== la carte de la region ne montre pas l'interieur")
essai("la fiche de la region s'ouvre", function()
    panneau.mode, panneau.zoneId, panneau.zoneTab = "zone", region.id, "carte"
    panneau:RefreshAll()
end)
local vues = {}
for _, e in ipairs(panneau.zoneMap:Dessinables()) do
    vues[(e.sub and e.sub.id) or (e.place and e.place.id)] =
        e.marqueur and "point" or (e.region and "contour" or "zone")
end
attendu("la place s'y dessine", vues[ZoneDuLieu(place).id], "zone")
attendu("la tour s'y marque d'un point", vues[empreinte.id], "point")
attendu("sa piece n'y est pas du tout", vues[salle.id], nil)

-- L'EMPLACEMENT : ou le batiment se tient DANS sa region, sans rapport avec
-- l'endroit du monde ou son interieur est bati. Nous construisons nos
-- interieurs ailleurs sur la carte — sous elle, le plus souvent, pour les
-- images par seconde — et l'empreinte doit pouvoir partir la-bas sans
-- emporter le point que les joueurs voient (3 novembre 2026).
dire("== le batiment se tient a son emplacement, pas a son empreinte")
local m0, ex0, ey0 = ZG:GetEmplacement(tour)
attendu("il en a un des sa naissance", ex0 ~= nil, true)
attendu("  pose la ou l'on se tenait", math.floor(ex0) .. "/" .. math.floor(ey0), "40/40")
attendu("  sur la carte du jeu d'ici", m0, empreinte.mapID)

-- On deplace l'empreinte tres loin : c'est ce que fait un interieur construit
-- sous la carte. Le carre du batiment, lui, ne doit pas bouger d'un pouce.
for i, p in ipairs(empreinte.points) do
    empreinte.points[i] = { x = p.x + 5000, y = p.y + 5000, weld = p.weld }
end
for i, p in ipairs(salle.points) do
    salle.points[i] = { x = p.x + 5000, y = p.y + 5000, weld = p.weld }
end
local _, ex1, ey1 = ZG:GetEmplacement(tour)
attendu("l'empreinte part au loin, le carre reste",
    math.floor(ex1) .. "/" .. math.floor(ey1), "40/40")

essai("la carte de la region se redessine", function()
    panneau.mode, panneau.zoneId, panneau.zoneTab = "zone", region.id, "carte"
    panneau:RefreshAll()
end)
local marque
for _, e in ipairs(panneau.zoneMap:Dessinables()) do
    if e.marqueur and e.place and e.place.id == tour.id then marque = e end
end
attendu("le marqueur porte l'emplacement", marque ~= nil, true)
if marque then
    attendu("  et non l'empreinte", math.floor(marque.ex) .. "/" .. math.floor(marque.ey), "40/40")
end
-- Le cadrage suit la region, pas l'intérieur parti a 5000 yards.
panneau.zoneMap:Fit()
attendu("la vue d'ensemble ne court pas apres l'empreinte",
    panneau.zoneMap.cx < 1000 and panneau.zoneMap.cy < 1000, true)

-- On le repose a la main, la ou le temple se voit depuis la route.
Poser(70, 20, 50)
attendu("on pose l'emplacement ici", ZG:PoserEmplacementIci(tour.id), true)
local _, ex2, ey2 = ZG:GetEmplacement(tour)
attendu("  le carre a suivi", math.floor(ex2) .. "/" .. math.floor(ey2), "70/20")
attendu("on le pose aussi a la main", ZG:SetEmplacement(tour.id, 1, 12, 34), true)
local _, ex3, ey3 = ZG:GetEmplacement(tour)
attendu("  il obeit", ex3 .. "/" .. ey3, "12/34")
-- L'oublier rend la main a l'empreinte : c'est elle qui refait le point.
attendu("on peut l'oublier", ZG:ClearEmplacement(tour.id), true)
local _, ex4 = ZG:GetEmplacement(tour)
attendu("  l'empreinte reprend le point", ex4 > 5000, true)
ZG:SetEmplacement(tour.id, empreinte.mapID, 70, 20)

dire("== le batiment a sa propre carte")
essai("sa fiche s'ouvre sur sa carte", function()
    panneau.mode, panneau.placeId, panneau.zoneId, panneau.placeTab =
        "place", tour.id, region.id, "carte"
    panneau:RefreshAll()
end)
attendu("l'onglet Carte existe pour lui", panneau.placeTabs.carte.cache, false)
local dedans = {}
for _, e in ipairs(panneau.batiMap:Dessinables()) do
    dedans[e.sub.id] = e.region and "contour" or "piece"
end
attendu("son empreinte y sert de contour", dedans[empreinte.id], "contour")
attendu("sa piece y est dessinee", dedans[salle.id], "piece")
attendu("la place du dehors n'y est pas", dedans[ZoneDuLieu(place).id], nil)
-- Les memes gestes que sur la carte d'une region : on y colle les cloisons.
attendu("elle a ses boutons", panneau.batiBoutons.weld ~= nil, true)
-- Et les deux gestes de l'emplacement, qui ne regardent pas l'empreinte.
attendu("  et de quoi poser l'emplacement", panneau.batiBoutons.poser ~= nil, true)
attendu("  et de quoi l'oublier", panneau.batiBoutons.oublier ~= nil, true)

-- Le carre du batiment se saisit comme un sommet, sur la carte de la REGION.
dire("== le carre du batiment se glisse")
essai("on revient a la carte de la region", function()
    panneau.mode, panneau.zoneId, panneau.zoneTab = "zone", region.id, "carte"
    panneau:RefreshAll()
end)
local prise
for _, h in ipairs(panneau.zoneMap.poignees or {}) do
    if h.emplacement == tour.id then prise = h end
end
attendu("il a sa poignee", prise ~= nil, true)
-- Ce que fait le glissement, sans la souris : reposer l'emplacement.
ZG:SetEmplacement(tour.id, empreinte.mapID, 55, 25, true)
local _, gx, gy = ZG:GetEmplacement(tour)
attendu("  le glissement le repose", math.floor(gx) .. "/" .. math.floor(gy), "55/25")
ZG:SetEmplacement(tour.id, empreinte.mapID, 70, 20)

-- Un lieu ordinaire n'a pas de carte : l'onglet se cache, et les autres se
-- repartagent la largeur.
essai("la fiche d'un lieu ordinaire s'ouvre", function()
    panneau.mode, panneau.placeId, panneau.placeTab = "place", place.id, "carte"
    panneau:RefreshAll()
end)
attendu("l'onglet Carte se cache", panneau.placeTabs.carte.cache, true)
attendu("  et on retombe sur la Zone", panneau.placeTab, "zone")

dire("== les trois lettres de l'arbre creent les trois sortes")
essai("l'arbre se redessine", function() panneau:RefreshTree() end)
local lignes = panneau.treeRows or {}
local trouvee
for _, row in ipairs(lignes) do
    if row:IsShown() and row.creer and row.creer[1]:IsShown() then trouvee = row; break end
end
attendu("une ligne porte ses trois lettres", trouvee ~= nil, true)
if trouvee then
    attendu("  L pour un lieu", trouvee.creer[1].sign:GetText(), "L")
    attendu("  P pour une porte", trouvee.creer[2].sign:GetText(), "P")
    attendu("  B pour un batiment", trouvee.creer[3].sign:GetText(), "B")
    attendu("  et chacune sait quoi faire", type(trouvee.creer[3].faire), "function")
end
-- Plus de lignes « + Nouveau lieu » / « + Porte » : elles se repetaient sous
-- chaque lieu et mangeaient la colonne.
local creations = 0
for _, row in ipairs(lignes) do
    if row:IsShown() and (row.label:GetText() or ""):find("Nouveau lieu", 1, true) then
        creations = creations + 1
    end
end
attendu("plus de ligne « + Nouveau lieu »", creations, 0)

dire("== une porte se pose aussi dans un batiment")
local huis = ZG:CreateDoorPlace(region.id, tour.id, "L'huis")
attendu("la porte est rangee sous la tour", huis.parent, tour.id)
attendu("  son batiment, c'est la tour", (ZG:BatimentDe(huis)).id, tour.id)
attendu("  elle ne compte pas comme piece", #ZG:GetPieceList(tour.id), 1)

dire("== tout cela traverse la serialisation")
local texte = ZG.PackState()
attendu("l'etat s'encode", type(texte), "string")
-- On relit dans une base vide : c'est ce que recoit le binome.
local avant = LCM_Crossings
LCM_Crossings = { countries = {}, zones = {}, themes = {} }
for ligne in (texte .. "\n"):gmatch("([^\n]+)") do ZG.ApplyStateLine(ligne, UnitName("player")) end
local relu = LCM_Crossings.zones[region.id]
local tourRelue = relu and relu.places[tour.id]
local empreinteRelue = relu and relu.subZones[empreinte.id]
attendu("le batiment revient", tourRelue ~= nil and tourRelue.batiment, true)
attendu("  son rangement aussi", tourRelue and tourRelue.parent, place.id)
attendu("l'empreinte garde son sol", empreinteRelue and empreinteRelue.z, 50)
attendu("  sa descente", empreinteRelue and empreinteRelue.bas, 8)
attendu("  et sa montee", empreinteRelue and empreinteRelue.haut, 30)
local salleRelue = relu and relu.subZones[salle.id]
attendu("la piece garde la sienne", salleRelue and salleRelue.haut, 30)
local poseRelue = tourRelue and tourRelue.emplacement
attendu("l'emplacement traverse aussi", poseRelue ~= nil, true)
if poseRelue then
    attendu("  avec ses coordonnees", poseRelue.x .. "/" .. poseRelue.y, "70/20")
    attendu("  et sa carte du jeu", poseRelue.mapID, empreinte.mapID)
end
-- Un auteur plus ancien n'envoie pas les champs de queue : son batiment
-- revient sans emplacement, et c'est l'empreinte qui refait le point —
-- exactement ce qu'elle faisait avant qu'on en pose un. On coupe la ligne
-- apres le 19e champ (la couleur), le dernier du format d'alors.
LCM_Crossings = { countries = {}, zones = {}, themes = {} }
local function Tronquer(ligne, combien)
    local champs = { strsplit(":", ligne) }
    while #champs > combien do table.remove(champs) end
    return table.concat(champs, ":")
end
for ligne in (texte .. "\n"):gmatch("([^\n]+)") do
    if ligne:find("^PLACE:" .. tour.id .. ":") then ligne = Tronquer(ligne, 19) end
    ZG.ApplyStateLine(ligne, UnitName("player"))
end
local tourAncienne = LCM_Crossings.zones[region.id]
tourAncienne = tourAncienne and tourAncienne.places[tour.id]
attendu("sans le champ, pas d'emplacement", tourAncienne and tourAncienne.emplacement, nil)
attendu("  mais le batiment est bien la", tourAncienne ~= nil and tourAncienne.batiment, true)
LCM_Crossings = avant

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
