-- Crossings : les zones, la carte de region et la frontiere (1er nov. 2026).
--
-- Le systeme du binome etait bon, son ergonomie non. Ce qu'on verifie ici :
--
--   * une ZONE (contour dessine) et un PASSAGE (porte droite) se comptent et
--     se listent separement — ils partageaient une liste ou il fallait
--     deviner lequel etait lequel ;
--   * la region porte une carte de toutes ses zones, le nom au centre, et un
--     clic sur ce nom ouvre le LIEU que la zone dessert, sur son onglet Zone ;
--   * fermer une zone relie bien le dernier sommet au premier ;
--   * la FRONTIERE : on designe des sommets de deux zones deja dessinees et
--     on dit qu'ils se confondent. Les sommets de la seconde rejoignent ceux
--     de la premiere, et deplacer l'un deplace l'autre POUR TOUJOURS. C'est
--     ce qui manquait : l'ancienne reprise de troncon ne savait qu'ajouter
--     des points a la SUITE du trace en cours, donc une troisieme zone collee
--     a deux voisines etait hors de portee.

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

-- Une region, deux lieux, et deux carres voisins a un yard l'un de l'autre.
local region = ZG:CreateZone("La Marche")
local ouest = ZG:CreatePlace(region.id, "Le Val")
local est = ZG:CreatePlace(region.id, "La Lande")

-- UnitPosition rend y AVANT x, et GetPlayerPose remet les deux dans l'ordre
-- (voir Core/Crossings.lua). Le banc reproduit le client, donc on pose (y, x)
-- pour que le sommet soit range en (x, y) : sans ca les carres de ce scenario
-- seraient leur propre miroir, et les coordonnees attendues ne colleraient pas.
local function Poser(x, y) __position(y, x, 0) end

local function Tracer(sub, points)
    for _, p in ipairs(points) do
        Poser(p[1], p[2])
        ZG:AddRegionPoint(sub.id)
    end
    return sub
end
-- Chaque lieu nait avec sa zone : on la trace, on n'en cree pas une seconde.
local function ZoneDuLieu(place) return ZG:GetPlaceAreas(place.id)[1].sub end
-- Une zone sans lieu : il en existe (un gue, un pont), et la carte doit les
-- montrer comme les autres.
local function Dessiner(nom, _, points)
    return Tracer(ZG:CreateSubZone(region.id, nom, nil, "polygon"), points)
end

local A = Tracer(ZoneDuLieu(ouest), { { 0, 0 }, { 30, 0 }, { 30, 30 }, { 0, 30 } })
local B = Tracer(ZoneDuLieu(est), { { 31, 1 }, { 61, 1 }, { 61, 31 }, { 31, 31 } })
local porte = ZG:CreateSubZone(region.id, "La poterne", ouest.id)

dire("== un lieu nait avec sa zone")
-- Un lieu sans etendue n'existe pas en pratique : la creer a la main coutait
-- trois clics et un nom a retaper.
local bourg = ZG:CreatePlace(region.id, "Le Bourg")
local siennes = ZG:GetPlaceAreas(bourg.id)
attendu("une zone est nee avec lui", #siennes, 1)
attendu("  elle porte son nom", siennes[1].sub.name, "Le Bourg")
attendu("  c'est un contour", siennes[1].sub.shape, "polygon")
attendu("  encore vide", #siennes[1].sub.points, 0)
attendu("  et elle mene a lui", siennes[1].sub.enterPlace, bourg.id)
-- Renommer le lieu renomme la zone qui porte ENCORE son ancien nom.
ZG:RenamePlace(bourg.id, "Le Bourg Noir")
attendu("la zone suit le renommage", siennes[1].sub.name, "Le Bourg Noir")
-- Celle qu'on a nommee soi-meme ne bouge plus.
ZG:RenameSubZone(siennes[1].sub.id, "Les Remparts")
ZG:RenamePlace(bourg.id, "Le Bourg Blanc")
attendu("une zone nommee a la main ne suit pas", siennes[1].sub.name, "Les Remparts")
ZG:RemoveSubZone(siennes[1].sub.id)
ZG:RemovePlace(bourg.id)

dire("== zone et passage ne se melangent plus")
attendu("deux zones dessinees", #ZG:GetAreaList(region.id), 2)
attendu("un passage droit", #ZG:GetDoorList(region.id), 1)
attendu("la porte n'est pas une zone", ZG:IsArea(porte), false)
attendu("le contour, si", ZG:IsArea(A), true)
-- Le nom par defaut compte les objets de SA forme : sinon une premiere zone
-- posee apres deux portes s'appellerait « Zone 3 ».
local anonyme = ZG:CreateSubZone(region.id, "", nil, "polygon")
attendu("une zone sans nom se numerote parmi les zones", anonyme.name, "Zone 3")
local porte2 = ZG:CreateSubZone(region.id, "")
attendu("et un passage parmi les passages", porte2.name, "Passage 2")
ZG:RemoveSubZone(anonyme.id); ZG:RemoveSubZone(porte2.id)

dire("== fermer une zone relie le dernier sommet au premier")
attendu("ouverte, elle ne vaut rien", A.regionReady, false)
attendu("on la ferme", ZG:FinishRegion(A.id), true)
attendu("elle est fermee", A.regionReady, true)
attendu("sans perdre un sommet", #A.points, 4)
-- Le carre a quatre sommets, donc trois segments dessines : c'est la
-- fermeture qui ferme le quatrieme cote, et sans elle (15, 15) ne serait pas
-- « dedans ».
ZG:FinishRegion(B.id)
local Geo = ZG.Geo
attendu("le centre du carre est dedans", Geo.PointInPolygon(A.points, 15, 15), true)
attendu("un point au-dela, dehors", Geo.PointInPolygon(A.points, 45, 15), false)
-- Trois sommets au minimum : deux ne delimitent rien.
local maigre = ZG:CreateSubZone(region.id, "Trop maigre", nil, "polygon")
for _, p in ipairs({ { 0, 0 }, { 5, 0 } }) do
    Poser(p[1], p[2]); ZG:AddRegionPoint(maigre.id)
end
attendu("deux sommets ne se ferment pas", ZG:FinishRegion(maigre.id), false)
ZG:RemoveSubZone(maigre.id)

dire("== la frontiere : deux sommets qui se confondent")
-- L'exemple demande : les sommets 2 et 3 du Val (le cote est du carre) et
-- les sommets 1 et 4 de la Lande (son cote ouest).
local couples = ZG:WeldSeam(A.id, { 2, 3 }, B.id, { 1, 4 })
attendu("la soudure se pose", couples ~= nil, true)
attendu("  deux couples", couples and #couples, 2)
-- L'appariement suit le contour et garde le sens qui deplace le moins : 2
-- avec 1, 3 avec 4. L'autre sens croiserait la frontiere.
attendu("  2 va avec 1", couples and (couples[1].a .. ">" .. couples[1].b), "2>1")
attendu("  3 va avec 4", couples and (couples[2].a .. ">" .. couples[2].b), "3>4")
attendu("la Lande a rejoint le Val en x", B.points[1].x, A.points[2].x)
attendu("et en y", B.points[1].y, A.points[2].y)
attendu("le Val n'a pas bouge", A.points[2].x .. "," .. A.points[2].y, "30,0")
attendu("les deux sommets portent la meme soudure",
    A.points[2].weld ~= nil and A.points[2].weld == B.points[1].weld, true)
attendu("fermer n'a pas ete defait par la soudure", A.regionReady, true)

dire("== deplacer l'un deplace l'autre")
attendu("on deplace le sommet du Val", ZG:MoveRegionPoint(A.id, 2, 40, -5), true)
attendu("la Lande a suivi en x", B.points[1].x, 40)
attendu("et en y", B.points[1].y, -5)
attendu("la zone reste fermee", A.regionReady, true)
-- Le sommet non soude, lui, ne bouge pas tout seul.
attendu("le sommet voisin reste ou il est", B.points[2].x, 61)
-- Les deux centres se recalculent : ils servent au rangement et au radar.
attendu("le centre du Val a suivi", A.x ~= nil and A.x ~= 0, true)

dire("== trois zones au meme coin")
local C = Dessiner("Le Gue", nil, { { 30, 40 }, { 60, 40 }, { 60, 70 }, { 30, 70 } })
ZG:FinishRegion(C.id)
-- On soude le Gue au sommet DEJA soude du Val : les trois groupes n'en font
-- plus qu'un. C'est exactement ce que l'ancienne frontiere ne savait pas
-- faire.
attendu("on soude une troisieme zone au meme sommet", ZG:WeldPoints(A.id, 3, C.id, 1), true)
attendu("  le Val et le Gue partagent la soudure", A.points[3].weld == C.points[1].weld, true)
attendu("  et la Lande est du meme groupe", B.points[4].weld == A.points[3].weld, true)
local groupe = ZG:WeldGroups()[A.points[3].weld]
attendu("  trois sommets confondus", groupe and #groupe, 3)
ZG:MoveRegionPoint(A.id, 3, 25, 35)
attendu("  les trois suivent (Lande)", B.points[4].x .. "," .. B.points[4].y, "25,35")
attendu("  les trois suivent (Gue)", C.points[1].x .. "," .. C.points[1].y, "25,35")

dire("== separer")
attendu("on separe un sommet", ZG:UnweldPoint(C.id, 1), true)
attendu("  il n'a plus de soudure", C.points[1].weld, nil)
attendu("  les deux autres se confondent encore", A.points[3].weld == B.points[4].weld, true)
ZG:MoveRegionPoint(A.id, 3, 10, 10)
attendu("  le separe ne bouge plus", C.points[1].x .. "," .. C.points[1].y, "25,35")
-- Une soudure a un seul membre ne confond rien : elle s'efface d'elle-meme.
ZG:UnweldPoint(A.id, 3)
attendu("une soudure orpheline disparait", B.points[4].weld, nil)

dire("== la soudure voyage")
-- Reseau ET base commune lisent le MEME format : la copie qui vivait dans
-- CrossingsBase ignorait la soudure, donc une frontiere ne serait jamais
-- entree dans la base.
ZG:WeldPoints(A.id, 2, B.id, 1)
local plie = ZG.PackPoints(A.points)
attendu("la chaine porte la soudure", plie:find("~", 1, true) ~= nil, true)
local relu = ZG.UnpackPoints(plie)
attendu("  relue, elle la rend", relu[2].weld, A.points[2].weld)
attendu("  avec les coordonnees", relu[2].x .. "," .. relu[2].y, A.points[2].x .. "," .. A.points[2].y)
attendu("la base commune plie pareil", LCM.CrossingsBase.Plier(A.points), plie)
attendu("  et deplie pareil", LCM.CrossingsBase.Deplier(plie)[2].weld, A.points[2].weld)
-- Une chaine d'avant les soudures se relit telle quelle.
local ancienne = ZG.UnpackPoints("1.0,2.0;3.0,4.0,Gue du Nord")
attendu("une ancienne chaine se relit", #ancienne, 2)
attendu("  son nom de sommet est intact", ancienne[2].name, "Gue du Nord")
attendu("  et elle n'a pas de soudure", ancienne[2].weld, nil)

dire("== la carte des zones")
panneau:Toggle()
panneau.mode, panneau.zoneId, panneau.zoneTab = "zone", region.id, "carte"
panneau:RefreshAll()
local carte = panneau.zoneMap
attendu("la carte existe", carte ~= nil, true)
essai("elle se dessine", function() carte:Fit(); carte:Draw() end)
-- Les zones VOISINES comptent aussi : une frontiere ne s'arrete pas au bord
-- d'une region.
local autre = ZG:CreateZone("L'autre rive")
local D = ZG:CreateSubZone(autre.id, "Rive", nil, "polygon")
for _, p in ipairs({ { 100, 100 }, { 130, 100 }, { 130, 130 } }) do
    Poser(p[1], p[2]); ZG:AddRegionPoint(D.id)
end
ZG:FinishRegion(D.id)
local dessinables = carte:Dessinables()
local vues = {}
for _, e in ipairs(dessinables) do vues[e.sub.id] = e.mienne end
attendu("les zones de la region sont a elle", vues[A.id], true)
attendu("celle d'a cote est une voisine", vues[D.id], false)
-- Les portes se dessinent aussi, en rouge : on a besoin de voir ou elles
-- coupent les zones. Elles sont marquees, pour ne pas se souder.
local estPorte = {}
for _, e in ipairs(dessinables) do estPorte[e.sub.id] = e.porte end
attendu("la porte droite est dessinee", vues[porte.id], true)
attendu("  et marquee comme telle", estPorte[porte.id], true)
attendu("  la zone, non", estPorte[A.id], nil)

dire("== choisir des sommets, puis les confondre")
local boutons = panneau.carteBoutons
carte:Deselectionner()
panneau:RefreshCarte()
attendu("rien de choisi : on ne soude pas", boutons.weld:IsEnabled(), false)
carte:Basculer(A.id, 1)
panneau:RefreshCarte()
attendu("un seul cote : pas encore", boutons.weld:IsEnabled(), false)
carte:Basculer(B.id, 2)
panneau:RefreshCarte()
attendu("un sommet de chaque cote : on peut", boutons.weld:IsEnabled(), true)
carte:Basculer(B.id, 3)
panneau:RefreshCarte()
attendu("deux d'un cote, un de l'autre : non", boutons.weld:IsEnabled(), false)
carte:Basculer(A.id, 4)
panneau:RefreshCarte()
attendu("deux et deux : on peut", boutons.weld:IsEnabled(), true)
-- L'ordre compte : la premiere zone designee fait foi.
local a, b, cotes = carte:Cotes()
attendu("deux cotes", cotes, 2)
attendu("  le Val a ete designe en premier", a.id, A.id)
boutons.weld:Click()
attendu("la soudure est posee", A.points[1].weld ~= nil and A.points[1].weld == B.points[2].weld, true)
attendu("la selection est oubliee", #carte.sel, 0)

dire("== un clic sur le nom ouvre le lieu, sur son onglet Zone")
local dessinee = nil
for _, e in ipairs(carte:Dessinables()) do if e.sub.id == A.id then dessinee = e end end
attendu("la zone est bien dessinee", dessinee ~= nil, true)
-- Le clic lui-meme ne se rejoue pas hors du jeu ; ce qu'il appelle, oui.
panneau.placeTab = "banner"
essai("le clic ouvre", function()
    local sub, zone = ZG:FindSubZone(A.id)
    carte.hooks.OuvrirZone(sub, zone)
end)
attendu("on est sur le lieu", panneau.mode, "place")
attendu("  c'est le Val", panneau.placeId, ouest.id)
attendu("  sur l'onglet Zone", panneau.placeTab, "zone")
-- Et cet onglet ne propose QUE les zones de ce lieu.
local proposees = panneau.pickers.passage.items()
attendu("  une seule zone proposee", #proposees, 1)
attendu("  c'est la sienne", proposees[1].value, A.id)
panneau:Hide()

dire("== annuler le dernier changement")
-- Un sommet lache au mauvais endroit ne se remet pas a la main : on ne
-- retrouve pas ses coordonnees au yard pres. La pile couvre les trois gestes
-- qui touchent la geometrie, pas seulement le glissement.
panneau.mode, panneau.zoneId, panneau.zoneTab = "zone", region.id, "carte"
panneau:RefreshAll()
carte.pile = {}
panneau:RefreshCarte()
attendu("rien a annuler au depart", boutons.undo:IsEnabled(), false)

-- Un deplacement, comme le fait le glissement : instantane AVANT, puis pile.
local avantX, avantY = A.points[1].x, A.points[1].y
local trace = carte:Instantane({ { subId = A.id, index = 1 } })
ZG:MoveRegionPoint(A.id, 1, 999, 999)
carte:Empiler(trace, "le déplacement d'un sommet")
panneau:RefreshCarte()
attendu("le sommet a bouge", A.points[1].x, 999)
attendu("on peut annuler", boutons.undo:IsEnabled(), true)
attendu("  et le bouton dit quoi", boutons.undo:GetText(), "Annuler : le déplacement d'un sommet")
carte:Annuler()
attendu("le sommet est revenu en x", A.points[1].x, avantX)
attendu("  et en y", A.points[1].y, avantY)
panneau:RefreshCarte()
attendu("la pile est vide", boutons.undo:IsEnabled(), false)

-- Une soudure s'annule aussi : le sommet revient OU il etait, et il ne se
-- confond plus. Les deux a la fois, sinon le retour laisserait un lien mort.
local E = Dessiner("Le Pont", nil, { { 80, 0 }, { 110, 0 }, { 110, 30 } })
ZG:FinishRegion(E.id)
local sommetE = { x = E.points[1].x, y = E.points[1].y }
carte:Deselectionner()
carte:Basculer(A.id, 1)
carte:Basculer(E.id, 1)
panneau:RefreshCarte()
local avantSoudure = carte:Instantane(carte.sel)
boutons.weld:Click()
attendu("la soudure est posee", E.points[1].weld ~= nil, true)
attendu("  et le sommet a rejoint l'autre", E.points[1].x, A.points[1].x)
panneau:RefreshCarte()
attendu("elle s'annule", boutons.undo:GetText(), "Annuler : la frontière posée")
carte:Annuler()
attendu("  le sommet est revenu", E.points[1].x .. "," .. E.points[1].y, sommetE.x .. "," .. sommetE.y)
attendu("  et ne se confond plus", E.points[1].weld, nil)
-- Annuler rend l'etat d'AVANT, pas un etat vierge : le Val etait deja soude
-- a la Lande, il l'est encore. Sans ca, defaire une frontiere en defairait
-- d'autres au passage.
attendu("  le Val retrouve sa soudure d'avant",
    A.points[1].weld ~= nil and A.points[1].weld == B.points[2].weld, true)

dire("== on voit ou l'on se tient")
-- La carte du JOUEUR cache sa position ; celle du MJ la montre, puisqu'on y
-- pose les sommets en marchant.
Poser(15, 15)
__cap(0)
essai("le repere se place", function() carte:Draw() end)
attendu("la carte sait le faire", type(carte.Moi), "function")

dire("== une zone dans une zone se passe la main toute seule")
-- La question posee le 1er novembre 2026 : « si ma petite zone A est dans ma
-- grande zone B, faut-il se taper une frontiere a la main ? » Non. Deux zones
-- qui se TOUCHENT se passent la main par la fusion de ZG:Tick (sortie et
-- entree dans la meme seconde) ; deux zones EMBOITEES, non — on sort de la
-- petite sans entrer nulle part, et la banniere ne disait rien.
local grande = ZG:CreatePlace(region.id, "La Grande Foret")
local petite = ZG:CreatePlace(region.id, "Le Sanctuaire")
local G = Tracer(ZoneDuLieu(grande), { { 200, 200 }, { 300, 200 }, { 300, 300 }, { 200, 300 } })
local P = Tracer(ZoneDuLieu(petite), { { 240, 240 }, { 260, 240 }, { 260, 260 }, { 240, 260 } })
ZG:FinishRegion(G.id); ZG:FinishRegion(P.id)

-- Au centre, c'est la PLUS PETITE qui dit ou l'on est.
attendu("au coeur, on est dans le sanctuaire",
    (ZG:LieuContenant(250, 250, G.mapID)), petite.id)
attendu("plus loin, dans la foret",
    (ZG:LieuContenant(210, 210, G.mapID)), grande.id)
attendu("dehors, nulle part",
    (ZG:LieuContenant(500, 500, G.mapID)), nil)
-- En sortant du sanctuaire, c'est la foret qu'on cherche, pas le sanctuaire.
attendu("on s'exclut soi-meme",
    (ZG:LieuContenant(250, 250, G.mapID, P.id)), grande.id)

-- Le trajet complet : dehors, dans la foret, dans le sanctuaire, et retour.
-- La banniere porte la region en titre et le LIEU en sous-titre : c'est le
-- sous-titre qui dit ou l'on vient d'arriver.
local bannieres = {}
local montrer = ZG.ShowBanner
function ZG:ShowBanner(titre, sous, theme)
    bannieres[#bannieres + 1] = sous
    return montrer(self, titre, sous, theme)
end
local function Aller(x, y)
    Poser(x, y)
    ZG:Tick()
end
ZG.quietUntil = 0
Aller(500, 500)
bannieres = {}
Aller(210, 210)
attendu("on entre dans la foret", bannieres[#bannieres], "La Grande Foret")
Aller(250, 250)
attendu("puis dans le sanctuaire", bannieres[#bannieres], "Le Sanctuaire")
local avantRetour = #bannieres
Aller(210, 210)
attendu("en ressortant, la foret revient d'elle-meme", bannieres[#bannieres], "La Grande Foret")
attendu("  et elle s'est bien annoncee", #bannieres > avantRetour, true)
Aller(500, 500)
ZG.ShowBanner = montrer

dire("== les auras se reglent dans la fiche du lieu")
-- Elles vivaient sur la ZONE, derriere un bouton de l'editeur de geometrie :
-- on ne les trouvait qu'en passant par la region. Elles se posent en entrant
-- dans un LIEU, donc elles se reglent dans sa fiche.
local zoneDuVal = ZoneDuLieu(ouest)
attendu("une aura s'ajoute a la zone du lieu", ZG:AddPassageAura(zoneDuVal.id, 1000509, "phase"), true)
essai("l'onglet Aura s'ouvre", function()
    panneau.mode, panneau.placeId, panneau.zoneId, panneau.placeTab =
        "place", ouest.id, region.id, "aura"
    panneau:RefreshAll()
end)
local lignes = panneau.auraPage.lignes
attendu("la premiere ligne la montre", lignes[1].texte:IsShown(), true)
attendu("  avec son identifiant", lignes[1].texte:GetText():find("1000509", 1, true) ~= nil, true)
attendu("  et de quoi la retirer", lignes[1].retirer:IsShown(), true)
attendu("la deuxieme ligne reste vide", lignes[2].texte:IsShown(), false)
lignes[1].retirer:Click()
attendu("le retrait passe par la fiche", #ZG:GetPassageAuras(zoneDuVal.id), 0)
panneau:RefreshAll()
attendu("  et la ligne disparait", lignes[1].texte:IsShown(), false)

dire("== une zone sans lieu se rattache depuis la carte")
-- L'onglet Zones de la region a disparu : sans ce menu, une zone orpheline
-- (un gue, un pont) n'aurait plus aucun endroit ou se regler.
local orpheline = Dessiner("Le Vieux Pont", nil, { { 400, 400 }, { 430, 400 }, { 430, 430 } })
ZG:FinishRegion(orpheline.id)
panneau.mode, panneau.zoneId, panneau.zoneTab = "zone", region.id, "carte"
panneau:RefreshAll()
local rattacher = panneau.carteBoutons.rattacher
attendu("sans zone designee, pas de menu", rattacher:IsShown(), false)
carte.hooks.OuvrirZone(orpheline, ZG:GetZone(region.id))
attendu("la designer ne quitte pas la carte", panneau.zoneTab, "carte")
attendu("  et le menu de rattachement sort", rattacher:IsShown(), true)
local proposes = rattacher.items()
local trouve = false
for _, item in ipairs(proposes) do if item.value == est.id then trouve = true end end
attendu("  il propose les lieux de la region", trouve, true)
rattacher.onSelect(est.id)
attendu("le rattachement a pris", orpheline.enterPlace, est.id)
attendu("  et on atterrit sur le lieu", panneau.placeId, est.id)
attendu("  sur son onglet Zone", panneau.placeTab, "zone")
ZG:RemoveSubZone(orpheline.id)

dire("== une porte est un lieu qui se traverse")
-- Un lieu dessine une etendue, une porte se traverse. Elles vivent dans la
-- meme table (zone.places), la porte marquee `porte` : tout ce qui sait
-- traiter un lieu la traite, seules les listes font le tri.
local poterne = ZG:CreateDoorPlace(region.id, ouest.id, "La Poterne")
attendu("la porte est creee", poterne ~= nil, true)
attendu("  c'est une porte", ZG:EstPorte(poterne), true)
attendu("  rangee sous son lieu", poterne.parent, ouest.id)
local saGeometrie = ZG:GetPlacePassages(poterne.id)
attendu("  sa geometrie nait avec elle", #saGeometrie, 1)
attendu("  et c'est une porte droite", saGeometrie[1].sub.shape, "line")
attendu("  sous le meme nom", saGeometrie[1].sub.name, "La Poterne")

-- Les listes font le tri : les lieux d'un cote, les portes de l'autre.
local lieux = ZG:GetLieuList(region.id)
local portes = ZG:GetPorteList(region.id)
local dansLesLieux = false
for _, p in ipairs(lieux) do if p.id == poterne.id then dansLesLieux = true end end
attendu("la porte n'est pas dans les lieux", dansLesLieux, false)
attendu("elle est dans les portes", #portes, 1)
attendu("  celles d'un lieu precis aussi", #ZG:GetPorteList(region.id, ouest.id), 1)
attendu("  celles d'un autre lieu, non", #ZG:GetPorteList(region.id, est.id), 0)

-- Sa fiche est celle d'un lieu, et son onglet Zone montre sa porte droite.
essai("sa fiche s'ouvre", function()
    panneau.mode, panneau.placeId, panneau.zoneId, panneau.placeTab =
        "place", poterne.id, region.id, "zone"
    panneau:RefreshAll()
end)
attendu("l'onglet Zone propose sa porte", panneau.passageId, saGeometrie[1].sub.id)

-- Supprimer le lieu ne doit pas emporter la porte : son trace est du travail.
local refuge = ZG:CreatePlace(region.id, "Le Refuge")
local porteDuRefuge = ZG:CreateDoorPlace(region.id, refuge.id, "Huis")
ZG:RemovePlace(refuge.id)
attendu("la porte survit a son lieu", ZG:FindPlace(porteDuRefuge.id) ~= nil, true)
attendu("  et remonte d'un cran", porteDuRefuge.parent, nil)
attendu("  on la retrouve sans parent", #ZG:GetPorteList(region.id, ""), 1)
ZG:RemovePlace(porteDuRefuge.id)

attendu("le parent se range", ZG:SetPorteParent(poterne.id, est.id), true)
attendu("  et se relit", poterne.parent, est.id)
attendu("un lieu ordinaire refuse d'etre range", ZG:SetPorteParent(ouest.id, est.id), false)

dire("== supprimer une zone ne laisse pas de soudure fantome")
ZG:WeldPoints(A.id, 2, B.id, 1)
attendu("les deux sont soudes", A.points[2].weld ~= nil, true)
ZG:RemoveSubZone(B.id)
attendu("la soudure du survivant s'efface", A.points[2].weld, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
