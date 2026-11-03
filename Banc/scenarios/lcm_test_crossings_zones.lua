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

dire("== ajouter un sommet sur une arete")
-- Clic droit entre le 8 et le 9 : le nouveau devient le 9, l'ancien 9 passe
-- 10. Sans ca, un contour ne s'affinait qu'en le refaisant.
local carre = Tracer(ZG:CreateSubZone(region.id, "Le Carre", nil, "polygon"),
    { { 0, 0 }, { 10, 0 }, { 10, 10 }, { 0, 10 } })
ZG:FinishRegion(carre.id)
ZG:DeclareBorder(carre.id, "Le cote nord", 3, 4, true)
attendu("on insere entre le 1 et le 2", ZG:InsertRegionPoint(carre.id, 1, 5, 0), true)
attendu("  il y a un sommet de plus", #carre.points, 5)
attendu("  le nouveau prend le rang 2", carre.points[2].x .. "," .. carre.points[2].y, "5,0")
attendu("  l'ancien 2 passe 3", carre.points[3].x .. "," .. carre.points[3].y, "10,0")
-- Une frontiere declaree designe ses sommets par leur RANG : elle suit.
attendu("la frontiere declaree a suivi", carre.borders[1].from .. ">" .. carre.borders[1].to, "4>5")
attendu("la zone reste fermee", carre.regionReady, true)
-- La fermeture est une arete comme une autre : on insere entre le dernier
-- sommet et le premier.
attendu("on insere sur la fermeture", ZG:InsertRegionPoint(carre.id, 5, -1, 5), true)
attendu("  il se pose en queue", #carre.points, 6)
attendu("  juste apres le dernier", carre.points[6].x .. "," .. carre.points[6].y, "-1,5")
-- Et le retrait defait l'insertion, rang par rang.
attendu("le retrait enleve le bon", ZG:RemoveRegionPointAt(carre.id, 2), true)
attendu("  le carre a retrouve son cote", carre.points[2].x .. "," .. carre.points[2].y, "10,0")
attendu("  et la frontiere est revenue", carre.borders[1].from .. ">" .. carre.borders[1].to, "3>4")
ZG:RemoveSubZone(carre.id)

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

dire("== un lieu se range dans un autre lieu")
-- Du rangement seulement : la geometrie n'en sait rien. Un hameau dans sa
-- foret, une crypte sous son mausolee.
local foret = ZG:CreatePlace(region.id, "La Foret")
local hameau = ZG:CreatePlace(region.id, "Le Hameau")
local cave = ZG:CreatePlace(region.id, "La Cave")
attendu("on range le hameau dans la foret", ZG:SetPlaceParent(hameau.id, foret.id), true)
attendu("  et la cave dans le hameau", ZG:SetPlaceParent(cave.id, hameau.id), true)
attendu("la foret contient le hameau", #ZG:GetChildPlaces(region.id, foret.id), 1)
attendu("  le hameau contient la cave", #ZG:GetChildPlaces(region.id, hameau.id), 1)
-- Les racines : ce qui n'est range sous rien.
local racines = ZG:GetLieuList(region.id, true)
local dansRacines = {}
for _, p in ipairs(racines) do dansRacines[p.id] = true end
attendu("la foret est une racine", dansRacines[foret.id], true)
attendu("  le hameau, non", dansRacines[hameau.id], nil)
-- Une boucle se refuse : un lieu range sous son propre descendant
-- disparaitrait de l'arbre, et son parcours ne finirait jamais.
attendu("on refuse la boucle directe", ZG:SetPlaceParent(foret.id, foret.id), false)
attendu("on refuse la boucle indirecte", ZG:SetPlaceParent(foret.id, cave.id), false)
attendu("  la foret n'a pas bouge", foret.parent, nil)
-- Supprimer le parent fait remonter ses enfants, il ne les emporte pas.
ZG:RemovePlace(hameau.id)
attendu("la cave survit", ZG:FindPlace(cave.id) ~= nil, true)
attendu("  et remonte a la racine", cave.parent, nil)
ZG:RemovePlace(cave.id); ZG:RemovePlace(foret.id)

dire("== le pays dessine toutes ses regions")
local royaume = ZG:CreateCountry("Le Royaume")
ZG:SetZoneCountry(region.id, royaume.id)
local voisine = ZG:CreateZone("La Marche Haute", royaume.id)
local V = Tracer(ZG:CreateSubZone(voisine.id, "Le Plateau", nil, "polygon"),
    { { 600, 600 }, { 630, 600 }, { 630, 630 } })
ZG:FinishRegion(V.id)
essai("la fiche du pays s'ouvre", function()
    panneau.mode, panneau.countryId = "country", royaume.id
    panneau:RefreshAll()
end)
local cartePays = panneau.paysMap
attendu("le pays a sa carte", cartePays ~= nil, true)
local vuesPays = {}
for _, e in ipairs(cartePays:Dessinables()) do vuesPays[e.sub.id] = e.mienne end
attendu("les zones des DEUX regions y sont", vuesPays[A.id] and vuesPays[V.id], true)
attendu("  et elles sont toutes a lui", vuesPays[V.id], true)
attendu("la couleur distingue les regions", cartePays.parRegion, true)
-- Dans UNE region, c'est l'inverse : une couleur par zone.
carte:Dessinables()
attendu("  mais pas dans une seule region", carte.parRegion, false)

dire("== le mode nomade sort la carte du panneau")
-- Le panneau entier occupe l'ecran et cache le jeu, or c'est en jeu qu'on
-- releve un contour. En nomade, la page Carte DEMENAGE dans une petite
-- fenetre : une seconde carte entretenue en double aurait fini par ne plus
-- montrer la meme chose que la premiere.
essai("la region s'ouvre sur sa carte", function()
    panneau.mode, panneau.zoneId, panneau.zoneTab = "zone", region.id, "carte"
    panneau:RefreshAll()
end)
local pageCarte = panneau.zonePages and panneau.zonePages.carte
attendu("la page Carte existe", pageCarte ~= nil, true)
local parentAvant = pageCarte and pageCarte:GetParent()
attendu("le bouton Nomade est la", panneau.carteBoutons.nomade ~= nil, true)
essai("on passe en nomade", function() panneau:ModeNomade(true) end)
attendu("la fenetre s'ouvre", panneau.carteFenetre:IsShown(), true)
attendu("  le panneau s'efface", panneau:IsShown(), false)
attendu("  la page a demenage", pageCarte:GetParent() == panneau.carteFenetre, true)
attendu("  le bouton propose de fermer", panneau.carteBoutons.nomade:GetText(), "Fermer")
-- Les boutons de la carte sont venus avec elle : ce sont les memes.
attendu("les gestes suivent la carte",
    panneau.carteBoutons.weld:GetParent() == pageCarte, true)
essai("on revient au panneau", function() panneau:ModeNomade(false) end)
attendu("la fenetre se ferme", panneau.carteFenetre:IsShown(), false)
attendu("  la page est rentree", pageCarte:GetParent() == parentAvant, true)
attendu("  et le bouton reproposer le nomade", panneau.carteBoutons.nomade:GetText(), "Nomade")
-- Fermee par Echap, la page rentre quand meme : sans ca le panneau rouvrirait
-- sur un onglet Carte vide.
panneau:ModeNomade(true)
panneau.carteFenetre:Hide()
attendu("fermee a la main, la page rentre", pageCarte:GetParent() == parentAvant, true)

dire("== le terrain du jeu se pose en fond de la carte nomade")
-- On voit sur quoi on pose ses sommets au lieu de les deviner sur un
-- quadrillage vide. C'est l'IMAGE DE LA ZONE du jeu, en tuiles : des textures
-- ordinaires, rognees au cadre, sur la zone entiere. La minimap avait ete
-- essayee et retiree — un disque de 230 yards ne couvre pas une region, et le
-- jeu refuse de la rogner.
local coinAvant = Minimap:GetParent()
__carte(1, 1000, 1000)
panneau:ModeNomade(true)
local bouton = panneau.carteBoutons.minimap
attendu("le bouton de fond est la", bouton ~= nil, true)
attendu("  on part sans fond", bouton:GetText(), "Fond : aucun")

essai("un clic : le terrain", function() bouton:Click() end)
attendu("le fond est pose", bouton:GetText(), "Fond : carte")
attendu("  et la carte le sait", panneau.zoneMap.fondPose, true)
-- La minimap du joueur n'est pas touchee : rien n'est emprunte.
attendu("  la minimap reste dans son coin", Minimap:GetParent() == coinAvant, true)

-- Les TUILES DE MINIMAP du client, une par bloc ADT de 533,33 yards. C'est
-- la seule source qui existe sur une carte personnalisee, et c'est celle
-- qu'on essaie en premier.
__carteNom("Aelskar")
local ADT = 533.33333
-- Vue centree sur le bloc colonne 28, ligne 20 : la colonne compte vers
-- l'OUEST, la ligne vers le NORD, toutes deux depuis le centre du monde (32).
panneau.zoneMap.cx = (32 - 28.5) * ADT
panneau.zoneMap.cy = (32 - 20.5) * ADT
panneau.zoneMap.scale = 2
bouton:Click(); bouton:Click()
attendu("le dossier se devine du nom de la carte", panneau.zoneMap.fondDossier, "aelskar")
local chemins = {}
for _, t in ipairs(panneau.zoneMap.tuiles or {}) do
    if t:GetTexture() then chemins[t:GetTexture()] = true end
end
attendu("la tuile du bloc survole est posee",
    chemins["world\\minimaps\\aelskar\\map28_20.blp"], true)
-- Le dossier se regle a la main quand la devinette tombe a cote : le nom
-- n'est pas expose aux addons.
ZG:SetMinimapDir(1, "monpatch")
bouton:Click(); bouton:Click()
attendu("le reglage a la main l'emporte", panneau.zoneMap.fondDossier, "monpatch")
ZG:SetMinimapDir(1, "")

essai("un second clic : plus de terrain", function() bouton:Click() end)
attendu("on est revenu sans fond", bouton:GetText(), "Fond : aucun")

-- Les deux sources muettes (carte personnalisee sans nom lisible et sans
-- image publiee) : le fond se refuse et DIT pourquoi. Sans la raison, un
-- mauvais dossier et une carte sans image se ressemblent.
__carteArt(false)
__carteNom("")
bouton:Click()
attendu("sans source, le fond se refuse", bouton:GetText(), "Fond : aucun")
attendu("  et la raison s'affiche",
    (panneau.carteBoutons.hint:GetText() or ""):find("Pas de terrain", 1, true) ~= nil, true)
__carteArt(true)
__carteNom("Carte")
panneau:ModeNomade(false)

dire("== coller deux regions depuis la carte du pays")
-- Le meme geste que dans une region, mais entre deux REGIONS. Sans lui, deux
-- regions voisines ne se collent pas : leur frontiere commune derive des deux
-- cotes des qu'on retouche l'une d'elles.
local paysBoutons = panneau.paysBoutons
attendu("la carte du pays a ses boutons", paysBoutons ~= nil and paysBoutons.weld ~= nil, true)
cartePays:Deselectionner()
panneau:RefreshAll()
attendu("rien de choisi : on ne soude pas", paysBoutons.weld:IsEnabled(), false)
cartePays:Basculer(A.id, 3)
panneau:RefreshAll()
attendu("une seule region : pas encore", paysBoutons.weld:IsEnabled(), false)
cartePays:Basculer(V.id, 1)
panneau:RefreshAll()
attendu("un sommet de chaque region : on peut", paysBoutons.weld:IsEnabled(), true)
essai("les confondre", function() paysBoutons.weld:Click() end)
attendu("les deux portent la meme soudure",
    A.points[3].weld ~= nil and A.points[3].weld == V.points[1].weld, true)
-- Deplacer l'un deplace l'autre, par-dela la limite des regions.
ZG:MoveRegionPoint(A.id, 3, 777, 888)
attendu("deplacer l'un deplace l'autre",
    V.points[1].x .. "/" .. V.points[1].y, "777/888")
-- Et le geste se defait, depuis la meme carte.
cartePays:Deselectionner()
cartePays:Basculer(A.id, 3)
panneau:RefreshAll()
attendu("un sommet soude : on peut separer", paysBoutons.unweld:IsEnabled(), true)
essai("les separer", function() paysBoutons.unweld:Click() end)
attendu("plus de soudure", A.points[3].weld, nil)
attendu("  des deux cotes", V.points[1].weld, nil)
-- On remet le sommet ou il etait : un essai ne laisse pas le decor tordu
-- derriere lui, la suite du scenario compte sur la forme de ce carre.
ZG:MoveRegionPoint(A.id, 3, 30, 30)

dire("== la region a son propre contour")
-- Hors de tout lieu mais dans la region, la banniere ne disait rien. La
-- region a desormais sa propre etendue, qui contient ses lieux. Dans les
-- donnees c'est un lieu marque `pourRegion`, que rien ne liste.
local lieuxAvant = #ZG:GetLieuList(region.id)
local nomRegion = ZG:GetZone(region.id).name
local contour, lieuRegion = ZG:CreateRegionArea(region.id)
attendu("le contour est cree", contour ~= nil, true)
attendu("  sous le nom de la region", contour.name, nomRegion)
attendu("  c'est une etendue", contour.shape, "polygon")
attendu("  il n'ajoute aucun lieu", #ZG:GetLieuList(region.id), lieuxAvant)
local dansLaListe = false
for _, p in ipairs(ZG:GetPlaceList(region.id)) do
    if p.id == lieuRegion.id then dansLaListe = true end
end
attendu("  et aucune liste ne le montre", dansLaListe, false)
local dansLaListeComplete = false
for _, p in ipairs(ZG:GetPlaceList(region.id, true)) do
    if p.id == lieuRegion.id then dansLaListeComplete = true end
end
attendu("  sauf quand on le demande", dansLaListeComplete, true)
-- Le redemander ne cree pas un second contour.
attendu("  on n'en cree pas deux", (ZG:CreateRegionArea(region.id)).id, contour.id)

-- Il porte le nom de la region, et le suit.
ZG:RenameZone(region.id, "Le Bois Dormant")
attendu("renommer la region renomme son contour", contour.name, "Le Bois Dormant")
attendu("  et le lieu cache qui le porte", lieuRegion.name, "Le Bois Dormant")
ZG:RenameZone(region.id, nomRegion)

-- Il entoure les lieux : au coeur d'un lieu c'est le lieu qui parle, entre
-- deux lieux c'est la region.
Tracer(contour, { { 100, 100 }, { 400, 100 }, { 400, 400 }, { 100, 400 } })
ZG:FinishRegion(contour.id)
attendu("au coeur d'un lieu, c'est le lieu",
    (ZG:LieuContenant(250, 250, G.mapID)), petite.id)
attendu("entre deux lieux, c'est la region",
    (ZG:LieuContenant(150, 150, G.mapID)), lieuRegion.id)
local titreR, sousR = ZG:ResolveBannerText(lieuRegion, ZG:GetZone(region.id))
attendu("sa banniere porte la region", titreR, nomRegion)
attendu("  sans la repeter en sous-titre", sousR, nil)

-- Le trajet : dehors, dans la region, dans un lieu, et retour a la region.
local annonces = {}
local vraiBanner = ZG.ShowBanner
function ZG:ShowBanner(titre, sous, theme)
    annonces[#annonces + 1] = sous or titre
    return vraiBanner(self, titre, sous, theme)
end
-- Quitter un lieu pour la region est un RETOUR : l'arrivee est muette, mais
-- le depart du lieu quitte doit partir quand meme, sinon son aura resterait
-- sur le dos du joueur. Avec un contour de region, toute sortie est un retour.
local partis = {}
local vraieAction = ZG.RunPlaceAction
function ZG:RunPlaceAction(place, mode) partis[#partis + 1] = (place.name or "?") .. ":" .. mode end
ZG.quietUntil = 0
Aller(600, 600)
annonces, partis = {}, {}
Aller(150, 150)
attendu("on entre dans la region", annonces[#annonces], nomRegion)
Aller(210, 210)
attendu("puis dans un de ses lieux", annonces[#annonces], "La Grande Foret")
Aller(150, 150)
attendu("en ressortant, la region revient", annonces[#annonces], nomRegion)
local depart = false
for _, p in ipairs(partis) do if p == "La Grande Foret:leave" then depart = true end end
attendu("  et le lieu quitte l'est pour de bon", depart, true)
ZG.ShowBanner, ZG.RunPlaceAction = vraiBanner, vraieAction
Aller(600, 600)

-- Sur la carte, il se reconnait : c'est lui qu'on ne remplit pas.
local marque
for _, e in ipairs(carte:Dessinables()) do
    if e.sub.id == contour.id then marque = e.region end
end
attendu("la carte le reconnait comme contour de region", marque, true)

-- L'effacer efface le lieu cache : sans trace il ne sert plus a rien.
local idCache = lieuRegion.id
ZG:RemoveSubZone(contour.id)
attendu("effacer le contour efface son lieu cache", (ZG:FindPlace(idCache)), nil)
attendu("  et la region peut en reprendre un", ZG:CreateRegionArea(region.id) ~= nil, true)

dire("== un lieu supprime emporte ses zones")
-- Elles restaient la, sans lieu ou aller : un fantome qui se dessinait encore
-- sur la carte, portait encore ses auras, et qu'aucune fiche ne montrait plus.
-- Un de ces fantomes a fini par recouvrir toute une region.
local fantomes = ZG:CreateZone("Le Pays Perdu")
local condamne = ZG:CreatePlace(fantomes.id, "Le Hameau")
local temoin = ZG:CreatePlace(fantomes.id, "Le Gue")
local Z = Tracer(ZoneDuLieu(condamne), { { 10, 10 }, { 40, 10 }, { 40, 40 } })
-- Une porte dont on SORT chez le condamne : elle appartient a son autre bout,
-- elle ne doit pas partir avec lui.
local pont = ZG:CreateSubZone(fantomes.id, "Le Pont", temoin.id)
ZG:SetPassagePlace(pont.id, "leave", condamne.id)

local nZones, nSommets = ZG:PlaceEmporterait(condamne.id)
attendu("on annonce ce qui part", nZones, 1)
attendu("  et combien de sommets", nSommets, 3)
attendu("  la porte partagee n'est pas comptee", ZG:FindSubZone(pont.id) ~= nil, true)

ZG:RemovePlace(condamne.id)
attendu("la zone du lieu est partie", ZG:FindSubZone(Z.id), nil)
attendu("  la porte partagee est restee", ZG:FindSubZone(pont.id) ~= nil, true)
attendu("  mais ne mene plus chez lui", ZG:FindSubZone(pont.id).leave, nil)
attendu("  et le lieu temoin n'a pas bouge", #ZG:GetPlaceAreas(temoin.id), 1)
-- Plus aucune zone orpheline derriere : c'etait tout le probleme.
local orphelines = 0
for _, sub in ipairs(ZG:GetAreaList(fantomes.id)) do
    if not sub.enterPlace then orphelines = orphelines + 1 end
end
attendu("aucune zone orpheline ne subsiste", orphelines, 0)

-- Et celles d'avant se jettent a la main, depuis la carte de la region.
local reste = Tracer(ZG:CreateSubZone(fantomes.id, "Vieux trace", nil, "polygon"),
    { { 80, 80 }, { 110, 80 }, { 110, 110 } })
essai("la carte de la region s'ouvre", function()
    panneau.mode, panneau.zoneId, panneau.zoneTab = "zone", fantomes.id, "carte"
    panneau:RefreshAll()
end)
attendu("le bouton de suppression existe", panneau.carteBoutons.jeter ~= nil, true)
attendu("  cache tant qu'aucune orpheline n'est designee",
    panneau.carteBoutons.jeter:IsShown(), false)
essai("on designe l'orpheline", function()
    panneau.zoneMap.hooks.OuvrirZone(reste, fantomes)
end)
attendu("  le bouton sort", panneau.carteBoutons.jeter:IsShown(), true)

dire("== supprimer une zone ne laisse pas de soudure fantome")
ZG:WeldPoints(A.id, 2, B.id, 1)
attendu("les deux sont soudes", A.points[2].weld ~= nil, true)
ZG:RemoveSubZone(B.id)
attendu("la soudure du survivant s'efface", A.points[2].weld, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
