-- Le cadre Ael'Raz'kah : decoupage, echelle, bornes.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit

dire("== toute fenetre recoit le cadre")
local fiche = LCM.UI.Fiche.Fenetre()
attendu("la fiche a son decor", fiche.decor ~= nil, true)
-- Les pieces sont fabriquees par habillage, a la demande.
attendu("l'habillage en cours", fiche.decor.theme, "leger")
attendu("six pieces fixes", #fiche.decor.jeux.leger.fixes, 6)
attendu("six bandes etirees", #fiche.decor.jeux.leger.bandes, 6)
attendu("titre centre", fiche.titreCentre, true)
local point = fiche.titre:GetPoint(1)
attendu("et centre sur le haut (en-tete Necronicon)", point, "CENTER")

dire("== l'echelle suit la largeur, entre deux bornes")
local creation = LCM.UI.Creation.Fenetre()
attendu("fenetre large : 1040", creation:GetWidth(), 1040)
-- 1040 / 1340 x 0,75 = 0,582, borne haute a 0,40.
attendu("echelle bornee en haut", creation.decor.echelle, 0.4)
local etroite = LCM.UI.Fenetre("banc_etroit", "Etroite", 300, 200)
attendu("fenetre etroite : 300", etroite:GetWidth(), 300)
-- 300 / 1340 x 0,75 = 0,168, borne basse a 0,26.
attendu("echelle bornee en bas", etroite.decor.echelle, 0.26)

dire("== le motif du haut est rogne pour le titre")
local haut
for index, piece in ipairs(fiche.decor.jeux.leger.fixes) do
    if index == 5 then haut = piece end
end
local _, _, y0, y1 = unpack(haut.__texCoord)
-- 102 / 1024 au lieu de 200 / 1024 : les pendentifs ne couvrent pas le titre.
attendu("hauteur rognee", string.format("%.4f", y1 - y0), string.format("%.4f", 102 / 1024))

dire("== les bandes n'echantillonnent que leur milieu")
local bande = fiche.decor.jeux.leger.bandes[1]
local bx0, bx1 = unpack(bande.__texCoord)
attendu("trois pixels ronges de chaque cote",
    string.format("%.4f", bx1 - bx0), string.format("%.4f", (12 - 6) / 1024))

dire("== le decor est bien porte par la fenetre")
attendu("parent", fiche.decor.parent == fiche, true)

dire("== la fermeture passe devant l'habillage")
attendu("la fiche a sa croix", fiche.fermer ~= nil, true)
attendu("elle est au-dessus du decor", fiche.fermer:GetFrameLevel() > fiche.decor:GetFrameLevel(), true)
fiche:Show()
fiche.fermer:Click()
attendu("et elle ferme", fiche:IsShown(), false)

dire("== la croix et la pastille de canal evitent les coins, en miroir")
-- Mesure de l'atlas (alpha, 3 octobre 2026) : sous le rail, la draperie du
-- coin « leger » est opaque jusqu'au bord de sa piece, 132 unites depuis le
-- bord interieur a gauche, 138 a droite ; l'equerre du « lourd » entre de 68.
--
-- Depuis le 3 octobre 2026, chacun s'ecarte ENCORE de sa propre largeur vers
-- le bord : poses pile apres l'ornement ils avaient l'air au milieu de la
-- feuille. On verifie donc qu'ils restent en miroir et dans le cadre, et non
-- plus qu'ils commencent apres l'ornement.
local function coins(f, piece)
    -- Le cadre leger a des encoches (4 octobre 2026) : les boutons y sont
    -- centres, sur les mesures de l'atlas. Le lourd n'en a pas : miroir.
    local enc = LCM.UI.AelEncoches(f)
    if enc then
        local pc, _, rc, xc, yc = f.coinGauche:GetPoint(1)
        local pf, _, rf, xf, yf = f.fermer:GetPoint(1)
        attendu("  pastille centree dans l'encoche gauche", pc .. rc .. xc .. yc,
            "CENTERTOPLEFT" .. enc.gauche[1] .. enc.gauche[2])
        attendu("  croix centree dans l'encoche droite", pf .. rf .. xf .. yf,
            "CENTERTOPRIGHT" .. enc.droite[1] .. enc.droite[2])
        return
    end
    local _, _, _, xc, yc = f.coinGauche:GetPoint(1)
    local _, _, _, xf, yf = f.fermer:GetPoint(1)
    attendu("  miroir horizontal", xc, -xf)
    attendu("  meme hauteur", yc, yf)
    attendu("  ecarte de sa largeur (" .. piece .. " unites)",
        xc <= piece * f.decor.echelle, true)
    attendu("  mais toujours dans le cadre", xc >= 0 and xf <= 0, true)
end
local fv = LCM.UI.Vues.Fenetre("fiche")
coins(fv, 138)
local stats = LCM.UI.Vues.Fenetre("statistiques")
coins(stats, 138)
LCM.UI.AppliquerTheme("lourd")
coins(fv, 68)
LCM.UI.AppliquerTheme("incritas")
local _, _, _, xi = fv.coinGauche:GetPoint(1)
attendu("  sans habillage, plus rien a eviter", xi < 10, true)
LCM.UI.AppliquerTheme("leger")
attendu("  un titre court garde ses ornements", fv.ornementG:IsShown(), true)
local pr = LCM.UI.Vues.Fenetre("penetrations_resistances")
-- Ses ornements s'effacaient : ils seraient passes sous la croix. Depuis le
-- 4 octobre 2026 la croix est dans son encoche, a l'interieur de la piece
-- d'angle : elle ne les gene plus.
attendu("  un titre long garde ses ornements (croix dans l'encoche)", pr.ornementG:IsShown(), true)
attendu("  mais garde son texte", pr.titre:GetText(), "PÉNÉTRATION & RÉSISTANCES")

dire("== deux fenetres ne naissent pas au meme endroit")
local doc = LCM.UI.Document.Fenetre()
local _, _, _, xf = fiche:GetPoint(1)
local _, _, _, xd = doc:GetPoint(1)
attendu("places distinctes", xf ~= xd, true)

dire("== cliquer une fenetre la ramene devant")
fiche:Show()
doc:Show()
local rangDoc = doc.rangDevant
fiche:GetScript("OnMouseDown")(fiche)
attendu("la fiche passe devant", fiche.rangDevant > rangDoc, true)
fiche:Hide()
doc:Hide()

dire("== creation et selection ne se recouvrent pas")
local selection = LCM.UI.Personnages.Ouvrir()
attendu("selection ouverte", selection:IsShown(), true)
selection.creer:Click()
attendu("la selection s'efface", selection:IsShown(), false)
local creation = LCM.UI.Creation.frame
attendu("la creation prend la place", creation:IsShown(), true)
attendu("abandonner est la", creation.abandonner ~= nil, true)
creation.abandonner:Click()
attendu("la creation se ferme", creation:IsShown(), false)
attendu("et la selection revient", selection:IsShown(), true)
selection:Hide()

dire("== le fond remonte sous la couronne du cadre")
-- Les pieces du haut debordent du bord de la fenetre (c'est voulu), mais le
-- fond s'arretait au bord : il restait une bande transparente entre la bordure
-- doree et le noir, par laquelle on voyait le jeu (4 octobre 2026).
local fiche = LCM.UI.Vues.Fenetre("fiche")
fiche:Montrer()
local debord = LCM.UI.AelDebordHaut(fiche)
attendu("l'habillage deborde bien vers le haut", debord > 0, true)
local _, _, _, _, yFond = fiche.fond:GetPoint(1)
attendu("et le fond monte d'autant", yFond, debord)
-- Mais pas plus haut que le RAIL : les tours d'angle et l'ornement central
-- montent au-dessus de lui, et suivre LA piece la plus haute faisait depasser
-- un bandeau noir par-dessus la bordure.
local plusHaut = 0
local jeu = fiche.decor.jeux[fiche.decor.theme]
for _, t in ipairs(jeu.fixes) do
    local _, _, rel, _, y = t:GetPoint(1)
    if tostring(rel):find("TOP") then plusHaut = math.max(plusHaut, y or 0) end
end
attendu("le fond ne depasse pas la couronne", debord < plusHaut, true)
fiche:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
