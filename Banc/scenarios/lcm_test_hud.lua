-- Le HUD du personnage : sa place, et le fait qu'il y reste (10 octobre 2026).
--
-- Il naissait a dix-huit unites du coin, et son bas mordait sur les cadres de
-- groupe. Il naît maintenant au ras de l'angle — mais surtout, il RETIENT sa
-- place : il etait deplaçable sans que rien ne la garde, donc on le poussait
-- hors des cadres de groupe et le /reload suivant le ramenait dessus. Ca ne se
-- voyait pas, parce qu'on ne deplace un HUD qu'une fois.

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

local H = LCM.UI.HUD

dire("== il naît au ras de l'angle")
LCM.db.fenetres = {}
H.Actualiser()
local f = H.frame
attendu("le cadre existe", f ~= nil, true)
local point, _, relPoint, x, y = f:GetPoint()
attendu("ancré en haut à gauche", point, "TOPLEFT")
attendu("  sur le coin de l'écran", relPoint, "TOPLEFT")
attendu("  à quatre unités", string.format("%d,%d", x, y), "4,-4")

dire("== on le déplace, et il retient sa place")
f:ClearAllPoints()
f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -300)
f.Retenir()
attendu("la place est en sauvegarde", LCM.db.fenetres.hud ~= nil, true)
attendu("  avec son ancrage", LCM.db.fenetres.hud.point, "TOPLEFT")
attendu("  et ses coordonnées",
    string.format("%d,%d", LCM.db.fenetres.hud.x, LCM.db.fenetres.hud.y), "60,-300")

dire("== et il la retrouve au rechargement")
-- Un /reload, vu du banc : on refait le cadre, la sauvegarde est toujours la.
H.frame = nil
H.Actualiser()
f = H.frame
point, _, relPoint, x, y = f:GetPoint()
attendu("il revient où on l'a laissé", string.format("%d,%d", x, y), "60,-300")

dire("== « remettre les fenêtres à leur place » le ramène dans son angle")
-- Et il y revient DANS SON ANGLE, pas au centre : la remise en place forçait
-- un ancrage CENTER pour tout le monde, ce qui aurait planté le HUD au milieu
-- de l'écran.
LCM.UI.ReplacerFenetres()
point, _, relPoint, x, y = f:GetPoint()
attendu("en haut à gauche", point, "TOPLEFT")
attendu("  et pas au centre", relPoint, "TOPLEFT")
attendu("  à sa place de naissance", string.format("%d,%d", x, y), "4,-4")
attendu("et la sauvegarde est oubliée", LCM.db.fenetres.hud, nil)

dire("== une fenêtre ordinaire, elle, revient bien au centre")
local ordinaire = LCM.UI.Fenetre("essai_hud", "Essai", 300, 200, { x = 10, y = -20 })
LCM.UI.ReplacerFenetres()
point, _, relPoint = ordinaire:GetPoint()
attendu("ancrée au centre", point, "CENTER")
attendu("  sur le centre de l'écran", relPoint, "CENTER")

dire("== le fond d'une fenêtre passe SOUS ses bordures")
-- Il s'arrêtait au rectangle de la fenêtre alors que les bandes du cadre
-- débordent au-dehors : entre le noir et l'or, on voyait le jeu. Invisible sur
-- un fond sombre, criant sur un ciel clair (11 octobre 2026).
local cadre = LCM.UI.Fenetre("essai_bordures", "Essai", 600, 400, { x = 0, y = 0 })
local decor = cadre.decor
attendu("la fenêtre est habillée", decor ~= nil, true)
if decor then
    attendu("le débord du haut est connu", type(decor.debordHaut), "number")
    attendu("celui de gauche aussi", type(decor.debordGauche), "number")
    attendu("celui de droite aussi", type(decor.debordDroite), "number")
    attendu("celui du bas aussi", type(decor.debordBas), "number")
    -- Les trois nouveaux ne sont pas nuls : les bandes débordent vraiment.
    attendu("la bordure déborde à gauche", decor.debordGauche > 0, true)
    attendu("  et à droite", decor.debordDroite > 0, true)
    attendu("  et en bas", decor.debordBas > 0, true)
    -- Et le fond va les chercher : ses ancrages sortent du rectangle.
    local _, _, _, dx, dy = cadre.fond:GetPoint(1)
    attendu("le fond déborde à gauche", dx < 0, true)
    attendu("  et remonte sous le rail du haut", dy >= 0, true)
    local _, _, _, dx2, dy2 = cadre.fond:GetPoint(2)
    attendu("le fond déborde à droite", dx2 > 0, true)
    attendu("  et descend sous le bas", dy2 < 0, true)
    -- Il ne doit pas aller plus loin que la bande : sinon c'est un bandeau
    -- noir qui dépasse par-dessus la bordure, le piège déjà payé en haut.
    attendu("mais pas au-delà de la bande de gauche",
        -dx <= decor.debordGauche + 0.01, true)
    attendu("  ni de celle du bas", -dy2 <= decor.debordBas + 0.01, true)
end

dire("== sa taille est la sienne, pas celle des fenêtres")
-- Il suivait « Taille de l'interface ». Or il n'est pas une fenetre qu'on
-- ouvre : il reste a l'ecran contre les cadres de groupe du jeu, et agrandir
-- l'interface pour la lire le faisait mordre sur le raid (11 octobre 2026).
local UI = LCM.UI
attendu("il porte le marqueur", f.echellePropre, true)
attendu("il est dans la liste des fenêtres", (function()
    for _, w in ipairs(UI.fenetres) do if w == f then return true end end
    return false
end)(), true)

UI.EchelleHUD(50)
local reference = f:GetScale()
attendu("à 50, sa taille de référence", string.format("%.2f", reference), "0.72")

-- L'échelle générale ne le touche plus...
-- Une VRAIE fenetre temoin : celle qui n'a pas d'echelle propre.
local autre
for _, w in ipairs(UI.fenetres) do if not w.echellePropre then autre = autre or w end end
attendu("une fenêtre témoin existe", autre ~= nil, true)
UI.Echelle(100)
attendu("l'échelle générale agrandit les fenêtres",
    autre == nil or autre:GetScale() > 1, true)
attendu("  et laisse le bandeau tranquille", string.format("%.2f", f:GetScale()), "0.72")
UI.Echelle(0)
attendu("  dans les deux sens", string.format("%.2f", f:GetScale()), "0.72")
UI.Echelle(50)

-- ... et la sienne ne touche que lui.
local avantAutre = autre and autre:GetScale()
UI.EchelleHUD(100)
attendu("son curseur l'agrandit", f:GetScale() > reference, true)
attendu("  sans toucher aux fenêtres", autre and autre:GetScale(), avantAutre)
attendu("  et c'est retenu", LCM.db.settings.echelleHud, 100)
UI.EchelleHUD(0)
attendu("il rapetisse aussi", f:GetScale() < reference, true)
-- 50 est la valeur neutre : on ne garde rien en sauvegarde pour elle.
UI.EchelleHUD(50)
attendu("et 50 ne laisse rien en sauvegarde", LCM.db.settings.echelleHud, nil)
attendu("  en revenant à la référence", string.format("%.2f", f:GetScale()), "0.72")

dire("== il suit le PNJ incarné, comme les fiches")
-- Il restait sur le personnage du MJ : la seule fenetre a ne pas changer de
-- corps quand on incarne (13 octobre 2026).
local moi = LCM.Entities.Personnage()
H.Actualiser()
attendu("avant : le personnage", f.entity == moi, true)
local garde = LCM.Incarnation.Incarner(LCM.PNJ.list[1].id, "Garde du HUD")
attendu("le PNJ est incarné", garde ~= nil, true)
attendu("le HUD passe au PNJ", f.entity == garde, true)
attendu("  avec son nom", f.nom:GetText(), "Garde du HUD")
local pv, pvMax = LCM.Body.Totals(garde)
attendu("  et ses PV", f.total.valeur:GetText(), tostring(pv))
local fatigue = LCM.Entities.Gauge(garde, "fatigue") or { current = 0, max = 0 }
attendu("  et sa fatigue", f.fatigue.label:GetText(),
    string.format("%d / %d", fatigue.current, fatigue.max))
-- Un changement du PNJ se voit tout de suite, comme pour un personnage :
-- l'ecoute comparait a Personnage(), et le PNJ n'y passait jamais.
f.nom:SetText("périmé")
LCM.Entities.Changed(garde)
attendu("un changement du PNJ le rafraîchit", f.nom:GetText(), "Garde du HUD")
LCM.Incarnation.Relacher()
attendu("relâché : retour au personnage", f.entity == moi, true)
attendu("  avec son nom", f.nom:GetText(), tostring(moi.name or moi.id))

dire("== le bouclier ponctuel apparaît sur l'orbe seulement quand il en reste")
LCM.Entities.SetGauge(moi, "armure", 118)
attendu("le marqueur de bouclier apparaît", f.total.bouclier:IsShown(), true)
attendu("  avec une valeur à trois chiffres non tronquée", f.total.bouclier.valeur:GetText(), "118")
attendu("  avec un badge réduit de quinze pour cent", f.total.bouclier:GetWidth(), 71)
local _, ancreBouclier, _, bx, by = f.total.bouclier.valeur:GetPoint()
attendu("  dont le nombre est centré sur l'icone", ancreBouclier == f.total.bouclier.icone, true)
attendu("  avec la correction du centre visuel", string.format("%d,%d", bx, by), "3,3")
local bouclierHUD = f.total.bouclier
bouclierHUD:GetScript("OnEnter")(bouclierHUD)
bouclierHUD:GetScript("OnUpdate")(bouclierHUD, 0.25)
attendu("  et dont le survol donne la valeur actuelle",
    LCM.UI.infoBulle.lignes[1]:GetText():find("118 points") ~= nil, true)
bouclierHUD:GetScript("OnLeave")(bouclierHUD)
LCM.Entities.SetGauge(moi, "armure", 0)
attendu("il disparaît à zéro", f.total.bouclier:IsShown(), false)

dire("== l'orbe des PV ouvre la Sante")
-- Clic gauche sur l'orbe (le MJ, 24 octobre 2026) : c'est elle qu'on regarde
-- quand on se demande ou l'on en est, et le detail par zone etait a trois
-- crans du menu radial.
if LCM.UI.Vues.frames.sante then LCM.UI.Vues.frames.sante:Hide() end
f.total:Click("LeftButton")
attendu("la fenêtre Santé s'ouvre", LCM.UI.Vues.frames.sante ~= nil
    and LCM.UI.Vues.frames.sante:IsShown(), true)
f.total:Click("LeftButton")
attendu("  et le même clic la referme", LCM.UI.Vues.frames.sante:IsShown(), false)

dire("== la generation d'un bouclier arrondit les points")
local calculerAvant = LCM.Actions.Calculer
LCM.Actions.Calculer = function() return 46.41 end
local ctxBouclier = { vars = {}, journal = {} }
LCM.Actions.Pas.compute({ label = "Bouclier généré", out = "bTot" }, ctxBouclier, function() end)
attendu("46,41 points deviennent 46", ctxBouclier.vars.bTot, 46)
LCM.Actions.Calculer = calculerAvant

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
