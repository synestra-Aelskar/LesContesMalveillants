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

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
