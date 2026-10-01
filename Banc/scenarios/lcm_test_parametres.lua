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

dire("== la commande")
f:Hide()
SlashCmdList.LCM("parametres")
attendu("elle ouvre la fenetre", LCM.UI.Parametres.frame:IsShown(), true)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
