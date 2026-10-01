-- Parametres : affichage, personnage, depannage.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")

dire("== la fenetre")
local f = LCM.UI.Parametres.Basculer()
attendu("ouverte", f:IsShown(), true)
attendu("l'entree du menu est allumee", LCM.UI.Menu.EstLiee("parametres"), true)

dire("== affichage : le sceau")
attendu("coche, le sceau est la", f.sceau:EstCochee(), true)
attendu("et il est visible", LCM.UI.Radial.frame:IsShown(), true)
f.sceau:Click()
attendu("decoche : le sceau se cache", LCM.UI.Radial.frame:IsShown(), false)
attendu("retenu en sauvegarde", LCM.db.settings.radialCache, true)
f.sceau:Click()
attendu("recoche : il revient", LCM.UI.Radial.frame:IsShown(), true)
attendu("et la sauvegarde est nettoyee", LCM.db.settings.radialCache, nil)

dire("== remettre les fenetres a leur place")
local fiche = LCM.UI.Fiche.Fenetre()
-- On la deplace comme le ferait un joueur, et on retient sa place.
fiche:ClearAllPoints()
fiche:SetPoint("CENTER", UIParent, "CENTER", 900, -400)
LCM.db.fenetres = { fiche = { point = "CENTER", relPoint = "CENTER", x = 900, y = -400 } }
local _, _, _, x = fiche:GetPoint(1)
attendu("elle est loin", x, 900)
f.replacer:Click()
local _, _, _, apres = fiche:GetPoint(1)
attendu("elle revient chez elle", apres, fiche.defautPosition.x)
attendu("les places retenues sont oubliees", next(LCM.db.fenetres), nil)

dire("== personnage")
attendu("il dit lequel on joue", f.joue:GetText(), "Tu joues Reika.")
f.choisir:Click()
attendu("et ouvre la selection", LCM.UI.Personnages.frame:IsShown(), true)
LCM.UI.Personnages.frame:Hide()

dire("== depannage")
attendu("les traces sont coupees", f.traces:EstCochee(), false)
f.traces:Click()
attendu("activees", LCM.db.settings.debug, true)
f.traces:Click()
attendu("et recoupees sans laisser de trace", LCM.db.settings.debug, nil)

attendu("la version est dite", __sansCouleur(f.version:GetText()):find("0.1.0") ~= nil, true)
attendu("le prefixe est enregistre", __sansCouleur(f.reseau:GetText()):find("enregistré") ~= nil, true)
attendu("aucun message en attente", f.attente:GetText(), "Aucun message en attente.")

dire("== un envoi tombe en route se voit")
-- Un message annonce en deux morceaux dont un seul arrive.
LCM.Reseau.Recevoir("Fantome-Royaume", "42:1:2:sort|label=Moitie")
f:Actualiser()
attendu("un message incomplet", LCM.Reseau.EnAttente(), 1)
attendu("et la fenetre le dit", __sansCouleur(f.attente:GetText()):find("incomplet") ~= nil, true)
LCM.Reseau.Recevoir("Fantome-Royaume", "42:2:2:")
f:Actualiser()
attendu("le morceau manquant arrive", LCM.Reseau.EnAttente(), 0)
attendu("et la ligne se calme", f.attente:GetText(), "Aucun message en attente.")

dire("== Apparences")
f.barre.boutons[2]:Click()
attendu("l'onglet existe", f.onglet, "apparences")
local app = f.pages.apparences
attendu("deux sous-onglets", #app.barre.boutons, 2)
attendu("on arrive sur General", f.apparence, "general")
-- UI.Onglets centre ses boutons sur le HAUT de la barre : sans largeur, ce
-- haut est le bord gauche et les onglets partent hors de la fenetre. Une barre
-- n'a de largeur que si elle est ancree des deux cotes (ou dimensionnee).
local function largeurResolue(cadre)
    if cadre:GetWidth() > 0 then return true end
    local gauche, droite = false, false
    for i = 1, cadre:GetNumPoints() do
        local point = cadre:GetPoint(i)
        if tostring(point):find("LEFT") then gauche = true end
        if tostring(point):find("RIGHT") then droite = true end
    end
    return gauche and droite
end
attendu("la barre d'onglets a une largeur", largeurResolue(f.barre), true)
attendu("celle des sous-onglets aussi", largeurResolue(app.barre), true)
-- UI.Curseur nait cachee (c'est d'abord un ascenseur) : une barre de reglage
-- qui ne se montre pas est une barre qu'on ne peut pas tirer.
attendu("la barre d'opacite se voit", app.opacite:IsShown(), true)
attendu("celle de la taille aussi", app.echelle:IsShown(), true)

dire("   opacite et taille")
app.opacite:Aller(40)
attendu("opacite retenue", LCM.db.settings.opacite, 40)
attendu("appliquee aux fenetres", math.abs(f:GetAlpha() - (0.1 + 0.9 * 0.4)) < 0.001, true)
app.opacite:Aller(100)
attendu("a 100 rien n'est retenu", LCM.db.settings.opacite, nil)
app.echelle:Aller(75)
attendu("taille retenue", LCM.db.settings.echelle, 75)
attendu("appliquee", f:GetScale(), 1.25)
app.echelle:Aller(50)
attendu("50 = taille normale", f:GetScale(), 1)
attendu("et rien n'est retenu", LCM.db.settings.echelle, nil)

dire("   la taille ne s'applique qu'au lacher")
-- Appliquer l'echelle pendant qu'on tire redimensionne la fenetre qui porte la
-- barre : la gouttiere grandit sous la poignee et le curseur part tout seul.
local avant = f:GetScale()
app.echelle.enGlissement = true
app.echelle:Aller(90)
attendu("pendant le glissement, rien n'est applique", f:GetScale(), avant)
attendu("mais le chiffre suit", app.echelleValeur:GetText(), "140 %")
attendu("et rien n'est encore retenu", LCM.db.settings.echelle, nil)
app.echelle.poignee:GetScript("OnMouseUp")(app.echelle.poignee)
attendu("au lacher, c'est applique", f:GetScale(), 1.4)
attendu("et retenu", LCM.db.settings.echelle, 90)
-- L'opacite, elle, ne change aucune taille : elle reste immediate.
app.opacite.enGlissement = true
app.opacite:Aller(60)
attendu("l'opacite suit le doigt", math.abs(f:GetAlpha() - (0.1 + 0.9 * 0.6)) < 0.001, true)
app.opacite.enGlissement = false
app.opacite:Aller(100)
app.echelle:Aller(50)

dire("   themes")
f:AfficherApparence("theme")
attendu("quatre habillages", #app.themes, 4)
attendu("le leger par defaut", LCM.UI.ThemeActuel(), "leger")
app.themes[1]:Click()
attendu("Incritas : aucun habillage", LCM.UI.ThemeActuel(), "incritas")
attendu("le decor n'a plus d'echelle", LCM.UI.Fiche.Fenetre().decor.echelle, nil)
app.themes[3]:Click()
attendu("Ael'Raz'kah lourd", LCM.UI.ThemeActuel(), "lourd")
attendu("son atlas est pose", LCM.UI.Fiche.Fenetre().decor.jeux.lourd ~= nil, true)
app.themes[2]:Click()
attendu("Necronicon n'est pas porte : refus", LCM.UI.ThemeActuel(), "lourd")
attendu("et on le dit", __sansCouleur(__sorties[#__sorties]):find("pas encore porté") ~= nil, true)
app.themes[4]:Click()
attendu("retour au leger", LCM.UI.ThemeActuel(), "leger")
f.barre.boutons[1]:Click()

dire("== la commande")
f:Hide()
SlashCmdList.LCM("parametres")
attendu("elle ouvre la fenetre", LCM.UI.Parametres.frame:IsShown(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
