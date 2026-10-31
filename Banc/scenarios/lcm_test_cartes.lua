-- Les cartes (31 octobre 2026) : un objet du compendium qui devoile une region
-- de Crossings, certains de ses lieux et des reperes.
--
-- Ce qu'on verifie :
--   * une carte se construit, et refuse ce qui ne tient pas (sans region,
--     qui se reprend elle-meme, qui boucle) ;
--   * la lire apprend pour de bon la region et les lieux devoiles — et PAS
--     les autres lieux de la region ;
--   * la vue ne montre que les lieux devoiles, et les reperes ;
--   * une carte qui en reprend une autre voyage avec le contenu APLATI :
--     celui qui la trouve n'a pas la carte reprise, reservee au MJ ;
--   * la famille est reservee au MJ : jamais poussee aux joueurs en seance ;
--   * l'editeur construit une carte de bout en bout, repere compris ;
--   * l'entree Cartes du radial est liee.

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

local ZG = LCM.Crossings
local Cartes = LCM.Cartes

-- Une region temoin : la Foret Automnale, deux lieux dont un seul sera
-- devoile, chacun avec un perimetre.
__position(0, 0, 0)
local foret = ZG:CreateZone("Forêt Automnale")
local bois = ZG:CreatePlace(foret.id, "Bois des Sorcières")
local antre = ZG:CreatePlace(foret.id, "Antre secret")
local function Perimetre(lieu, x0, y0)
    local sub = ZG:CreateSubZone(foret.id, lieu.name, lieu.id)
    ZG:SetSubZoneShape(sub.id, "polygon")
    for _, p in ipairs({ { x0, y0 }, { x0 + 20, y0 }, { x0 + 20, y0 + 20 }, { x0, y0 + 20 } }) do
        __position(p[1], p[2], 0)
        ZG:AddRegionPoint(sub.id)
    end
    ZG:FinishRegion(sub.id)
    return sub
end
Perimetre(bois, 0, 0)
Perimetre(antre, 100, 100)
__position(500, 500, 0)

dire("== une carte se construit, et refuse ce qui ne tient pas")
local ok = pcall(Cartes.Construire, { id = "sans_region", label = "Vide" })
attendu("sans region : refusee", ok, false)
ok = pcall(Cartes.Construire, { id = "boucle", label = "Boucle", reprend = "boucle" })
attendu("qui se reprend elle-meme : refusee", ok, false)

local carte = Cartes.Add({
    id = "carte_foret", label = "Carte de la forêt", region = foret.id, regionNom = foret.name,
    lieux = { { id = bois.id, nom = bois.name } },
    reperes = {
        { genre = "ressource", label = "Champignons", x = 5, y = 5, lieu = bois.id },
        { genre = "pnj", label = "La vieille", x = 12, y = 8 },
    },
})
attendu("la carte existe", carte ~= nil, true)
attendu("un seul lieu devoile", #carte.lieux, 1)
attendu("deux reperes", #carte.reperes, 2)
attendu("une carte ne s'empile pas", carte.pileMax, 1)

local gravee = Cartes.Add({ id = "carte_gravee", label = "Carte gravée", reprend = "carte_foret" })
attendu("une carte peut en reprendre une autre", Cartes.Contenu(gravee) == carte, true)
Cartes.Add({ id = "boucle_a", label = "A", reprend = "boucle_b" })
Cartes.Add({ id = "boucle_b", label = "B", reprend = "boucle_a" })
local contenu, raison = Cartes.Contenu(Cartes.Get("boucle_a"))
attendu("une boucle ne se resout pas", contenu, nil)
attendu("et le dit", raison, "les cartes se reprennent en boucle")

dire("== le MJ voit tout, le joueur ce que son personnage a appris")
-- La regle du 31 octobre 2026 : un MJ ne voit aucun nom masque — il prepare
-- le jeu, y compris ce que l'autre MJ a cree. Un joueur ne sait que ce que SON
-- personnage (la fiche LCM jouee) a appris. Ce qu'on APPREND se verifie donc
-- en mode joueur.
attendu("le MJ connait une region qu'on ne lui a pas apprise", ZG:HasLearnedZoneName(foret.id), true)
LCM.db.settings.modeJoueur = true
attendu("en joueur, il ne la connait pas", ZG:HasLearnedZoneName(foret.id), false)
do
    -- Deux fiches sur le meme personnage WoW ne partagent pas ce qu'elles savent.
    local P = LCM.Personnages
    local actif = P.Actif
    local autre = { id = "fiche_temoin_2" }
    P.Actif = function() return autre end
    ZG:MarkLearnedZoneName(foret.id)
    attendu("la seconde fiche l'apprend", ZG:HasLearnedZoneName(foret.id), true)
    P.Actif = actif
    attendu("la premiere ne le sait pas pour autant", ZG:HasLearnedZoneName(foret.id), false)
end

dire("== lire apprend les lieux devoiles, et seulement eux")
attendu("avant : la region est inconnue", ZG:HasLearnedZoneName(foret.id), false)
local vue, appris = Cartes.Lire("cartes/carte_foret")
attendu("la lecture reussit", vue ~= nil, true)
attendu("la region est apprise", ZG:HasLearnedZoneName(foret.id), true)
attendu("le lieu devoile est appris", ZG:KnowsPlaceName(bois), true)
attendu("l'autre lieu reste inconnu", ZG:KnowsPlaceName(antre), false)
attendu("ce qu'on a appris est dit", table.concat(appris, ", "), "Forêt Automnale, Bois des Sorcières")
local _, rien = Cartes.Lire("cartes/carte_foret")
attendu("relire n'apprend plus rien", #rien, 0)
local _, viaGravee = Cartes.Lire("cartes/carte_gravee")
attendu("la carte gravee montre la meme chose", viaGravee and #viaGravee, 0)
LCM.db.settings.modeJoueur = nil

dire("== la vue ne montre que ce que la carte devoile")
attendu("la carte s'ouvre", LCM.UI.Cartes.Ouvrir("cartes/carte_foret"), true)
local win = LCMCrossingsRegionMap
attendu("dans la fenetre de la carte des regions", win:IsShown(), true)
attendu("en mode carte lue", win.carte ~= nil, true)
attendu("titre de la carte", __sansCouleur(win.fenetre.titre:GetText()), "CARTE DE LA FORÊT")
local passages = win:Subs()
-- Toute la region se dessine (31 octobre 2026) : ses lieux non devoiles lui
-- donnent sa forme, en gris et sans nom. Avant, seul le lieu devoile l'etait.
attendu("la region entiere se dessine", #passages, 2)
local sous = win.fenetre.sousTitre:GetText() or ""
attendu("le lieu devoile est nomme", sous:find("Bois des Sorcières", 1, true) ~= nil, true)
attendu("pas l'autre", sous:find("Antre", 1, true) == nil, true)
-- M rouvre la vraie carte des regions, pas la carte lue.
ZG:ShowRegionMap()
attendu("M revient a la carte des regions", win.carte, nil)
win:Hide()

dire("== une carte voyage avec son contenu, aplati")
local def = LCM.Lisibles.Definition("cartes/carte_gravee")
attendu("la definition part avec l'objet", def ~= nil, true)
attendu("elle ne renvoie plus a la carte reprise", def.reprend, nil)
-- Une carte devoile une LISTE de regions depuis le 31 octobre 2026 ; la
-- carte temoin, ecrite a l'ancienne avec une seule `region`, s'y convertit.
attendu("elle porte la region", def.regions and def.regions[1] and def.regions[1].id, foret.id)
attendu("et les reperes", #def.reperes, 2)
-- Une carte se range comme un livre : oubliee des listes d'autorisation, elle
-- ne tenait dans aucun sac (le MJ, 31 octobre 2026).
attendu("une carte se range dans un sac", (LCM.Inventaire.Accepte(nil, 1, "cartes/carte_foret")), true)
attendu("un coffre l'accepte", (LCM.Coffres.Accepte("cartes/carte_foret")), true)
attendu("l'echange la connait aussi", LCM.Echange.DefinitionPartagee("cartes/carte_gravee") ~= nil, true)
local copie = LCM.Copie(def)
copie.id = "carte_trouvee"
attendu("une carte trouvee s'importe", LCM.Lisibles.Importer("cartes/carte_trouvee", copie), true)
attendu("et reste apres /reload", LCM.db.cartesRecues.carte_trouvee ~= nil, true)

dire("== reservee au MJ")
attendu("famille connue de la file d'envoi", (function()
    for _, f in ipairs(LCM.Brouillons.FAMILLES) do if f == "cartes" then return true end end
    return false end)(), true)
attendu("jamais poussee aux joueurs en seance", LCM.BasePublique.REGISTRES.cartes, nil)
attendu("le compendium sait la resoudre", (LCM.Compendium.Resoudre("cartes/carte_foret")) ~= nil, true)

dire("== l'editeur construit une carte de bout en bout")
-- Une seconde region, dans un pays : Osol, ou le pirate a cache un coffre.
local paysOsol = ZG:CreateCountry("Osol")
local osol = ZG:CreateZone("Côte d'Osol", paysOsol.id)
local crique = ZG:CreatePlace(osol.id, "Crique aux Os")
do
    local sub = ZG:CreateSubZone(osol.id, crique.name, crique.id)
    ZG:SetSubZoneShape(sub.id, "polygon")
    for _, pt in ipairs({ { 200, 200 }, { 220, 200 }, { 220, 220 }, { 200, 220 } }) do
        __position(pt[1], pt[2], 0)
        ZG:AddRegionPoint(sub.id)
    end
    ZG:FinishRegion(sub.id)
end
-- Les points poses : les repères en viennent TOUS, et se placent seuls a leurs
-- coordonnees X, Y, Z (le MJ, 31 octobre 2026 : plus d'epingle a la main).
-- Les points de LCM retiennent x, y comme UnitPosition les donne ; Crossings
-- les range dans l'autre ordre.
local pointsAvant = LCM.CoffresMJ.Points
LCM.CoffresMJ.Points = function()
    return { { id = "p1", def = "coffre_temoin", x = 10, y = 5, z = 3, source = "monde" },
             { id = "tresor", def = "coffre_temoin", x = 210, y = 210, z = 1, source = "monde" },
             { id = "nulle_part", def = "coffre_temoin", x = 900, y = 900, source = "monde" },
             { id = "p2", def = "coffre_temoin", x = 0.4, y = 0.6, source = "carte" } }
end
local panneauxAvant = LCM.AffichagesMJ.Points
LCM.AffichagesMJ.Points = function()
    return { { id = "pan1", def = "panneau_temoin", x = 15, y = 15, z = 0, source = "monde" } }
end
-- Un vendeur pose par l'autre MJ : la base commune le connait.
LCM.Poses.Noter("vendeur", "autre1", { def = "vendeur_temoin", x = 8, y = 12, z = 0, source = "monde",
    posePar = "Collegue-Apertus", auteur = "Collegue-Apertus" })

local E = LCM.CartesUI
E.Editer(nil)
local f = E.frame
attendu("l'editeur s'ouvre", f:IsShown(), true)
attendu("plus de bouton « Épingler ici »", f.epingler, nil)
f.nom:Saisir("Carte du pirate")
-- « Ce que la carte dévoile » : un arbre region › lieux, une case partout
-- (le menu « Région » ne disait pas ce qu'il faisait, et n'en prenait qu'une).
local function Noeud(zone, place)
    for _, n in ipairs(f.noeuds) do
        if n:IsShown() and n.zone == zone and n.place == place then return n end
    end
end
attendu("une case par region", Noeud(foret) ~= nil and Noeud(osol) ~= nil, true)
attendu("et une par lieu, sous sa region", Noeud(foret, bois) ~= nil and Noeud(osol, crique) ~= nil, true)
Noeud(foret, bois):Click()
attendu("cocher un lieu le devoile", f.travail.lieux[1] and f.travail.lieux[1].id, bois.id)
attendu("et coche sa region", f.travail.regions[1] and f.travail.regions[1].id, foret.id)
Noeud(osol, crique):Click()
attendu("plusieurs regions se devoilent", #f.travail.regions, 2)
Noeud(osol):Click()
attendu("decocher une region la retire", #f.travail.regions, 1)
attendu("avec ses lieux", #f.travail.lieux, 1)

f.choisirPoints:Click()
local d = E.choix
attendu("les points poses s'ouvrent dans leur fenetre", d and d:IsShown(), true)
local function Ligne(id)
    for _, l in ipairs(d.lignes) do if l:IsShown() and l.point and l.point.id == id then return l end end
end
local function Rang(id)
    for i, l in ipairs(d.lignes) do if l:IsShown() and l.point and l.point.id == id then return i end end
end
attendu("les regions devoilees viennent d'abord", (d.lignes[1].texte:GetText() or ""):find("Forêt Automnale", 1, true) ~= nil, true)
attendu("mon coffre de la region y est", Ligne("coffre:p1") ~= nil, true)
attendu("le vendeur du collegue aussi", Ligne("vendeur:autre1") ~= nil, true)
attendu("avec le nom de qui l'a pose", (Ligne("vendeur:autre1").texte:GetText() or ""):find("Collegue", 1, true) ~= nil, true)
attendu("et les panneaux d'affichage", Ligne("affichage:pan1") ~= nil, true)
attendu("le coffre d'Osol est propose aussi", Ligne("coffre:tresor") ~= nil, true)
attendu("mais apres ceux de la region", Rang("coffre:tresor") > Rang("coffre:p1"), true)
attendu("range sous son pays et sa region", (function()
    for i = Rang("coffre:tresor") - 1, 1, -1 do
        local l = d.lignes[i]
        if not l.point then return (l.texte:GetText() or ""):find("Osol › Côte d'Osol", 1, true) ~= nil end
    end
    return false end)(), true)
attendu("un point hors de toute region reste propose", Ligne("coffre:nulle_part") ~= nil, true)
-- Devoiler Osol aussi : son coffre passe dans le premier groupe.
Noeud(osol):Click()
attendu("Osol devoilee : son coffre passe en tete", (function()
    for i = Rang("coffre:tresor") - 1, 1, -1 do
        local l = d.lignes[i]
        if not l.point then return (l.texte:GetText() or ""):find("Dans les régions", 1, true) ~= nil end
    end
    return false end)(), true)
Noeud(osol):Click()
attendu("le point pose par la carte du jeu est signale", (d.note:GetText() or ""):find("carte du jeu", 1, true) ~= nil, true)

Ligne("coffre:p1").case:Click()
local r = f.travail.reperes[1]
attendu("cocher en fait un repere", r and r.genre, "coffre")
attendu("place a ses coordonnees (repere Crossings)", r and (r.x .. "," .. r.y .. "," .. tostring(r.z)), "5,10,3")
attendu("il retient de quel point il vient", r and r.point, "coffre:p1")
attendu("et ou il est", r and r.lieuNom, "Bois des Sorcières")
Ligne("coffre:tresor").case:Click()
local t2 = f.travail.reperes[2]
attendu("le coffre du pirate a Osol", t2 and LCM.Cartes.Emplacement(t2), "Osol › Côte d'Osol › Crique aux Os")
Ligne("coffre:p1").case:Click()
attendu("decocher retire le repere", #f.travail.reperes, 1)
Ligne("coffre:p1").case:Click()
attendu("et le remet", #f.travail.reperes, 2)
f.enregistrer:Click()
attendu("enregistree", f:IsShown(), false)
attendu("la fenetre des points se ferme avec", d:IsShown(), false)
local pirate
for _, c in ipairs(Cartes.list) do if c.label == "Carte du pirate" then pirate = c end end
attendu("la carte est au compendium", pirate ~= nil, true)

dire("== la carte du pirate, lue")
LCM.db.settings.modeJoueur = true
local vueP, apprisP = Cartes.Lire("cartes/" .. pirate.id)
-- Ce que la carte DESSINE et ce qu'elle DEVOILE sont deux choses : Osol porte
-- un repere, elle se dessine, mais sans son nom — la carte ne la devoile pas
-- (le MJ, 31 octobre 2026 : « bah c'est par la »).
attendu("les deux reperes se dessinent", #vueP.reperes, 2)
attendu("Osol se dessine, pour placer son coffre", (function()
    for _, id in ipairs(vueP.dessinees) do if id == osol.id then return true end end
    return false end)(), true)
attendu("mais la carte ne devoile pas Osol", vueP.regions[osol.id], nil)
attendu("la lecture n'apprend donc pas la crique", ZG:KnowsPlaceName(crique), false)
attendu("ni la region d'Osol", ZG:HasLearnedZoneName(osol.id), false)
LCM.db.settings.modeJoueur = nil
LCM.UI.Cartes.Ouvrir("cartes/" .. pirate.id)
local zonesDessinees = {}
for _, z in ipairs(LCMCrossingsRegionMap:Zones()) do zonesDessinees[z.id] = true end
attendu("la carte lue dessine Osol", zonesDessinees[osol.id], true)
attendu("sans la nommer dans le sous-titre",
    (LCMCrossingsRegionMap.fenetre.sousTitre:GetText() or ""):find("Osol", 1, true) == nil, true)
LCMCrossingsRegionMap:Hide()

-- Le cas du MJ : une carte qui n'a QU'UN repere dans la Foret Automnale, sans
-- rien cocher. La foret se dessine, anonyme, avec le repere dedans ; son nom
-- ne doit apparaitre nulle part (il fuyait dans le sous-titre).
local ressources = Cartes.Add({ id = "carte_ressources", label = "Carte aux ressources",
    reperes = { { genre = "ressource", label = "Filon", x = 5, y = 5, region = foret.id,
        regionNom = foret.name, lieu = bois.id, lieuNom = bois.name } } })
LCM.UI.Cartes.Ouvrir("cartes/carte_ressources")
attendu("la foret se dessine", #LCMCrossingsRegionMap:Subs() > 0, true)
attendu("son nom n'apparait pas dans le sous-titre",
    (LCMCrossingsRegionMap.fenetre.sousTitre:GetText() or ""):find("Forêt", 1, true) == nil, true)
LCMCrossingsRegionMap:Hide()

-- Une carte au tresor sans region principale : seulement des reperes.
ok = pcall(Cartes.Construire, { id = "tresor_seul", label = "Trésor",
    reperes = { { genre = "coffre", label = "Coffre", x = 210, y = 210, region = osol.id } } })
attendu("une carte sans region mais avec un repere est permise", ok, true)
LCM.CoffresMJ.Points = pointsAvant
LCM.AffichagesMJ.Points = panneauxAvant

E.Editer(nil)
f.nom:Saisir("Sans rien")
f.enregistrer:Click()
attendu("sans region : l'editeur refuse et le dit", f.erreur:GetText() ~= "", true)
attendu("et reste ouvert", f:IsShown(), true)
f:Hide()

dire("== le radial")
attendu("l'entree Cartes est liee", LCM.UI.Menu.EstLiee("cartes"), true)
LCM.UI.Menu.Trouver("cartes").onClick()
attendu("elle ouvre le compendium sur les cartes", LCM.UI.Compendium.Fenetre().actif, "cartes")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
