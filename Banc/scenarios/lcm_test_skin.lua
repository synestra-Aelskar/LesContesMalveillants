-- Le cadre Ael'Raz'kah : decoupage, echelle, bornes.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")

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
attendu("fenetre large : 820", creation:GetWidth(), 820)
-- 820 / 1340 x 0,75 = 0,459, borne haute a 0,40.
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

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
