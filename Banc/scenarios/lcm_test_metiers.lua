-- Metiers : les 32 metiers du template, paliers incrementaux, fenetre.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()   -- ce scenario joue un personnage : il le dit
local M = LCM.Metiers
local moi = LCM.Entities.Self()

dire("== les metiers du template")
attendu("32 metiers", #M.list, 32)
attendu("le premier", M.list[1].label, "Dépeçeur")
attendu("Artiste disponible", M.Get("artiste").label, "Artiste")
attendu("le dernier", M.list[32].label, "Informaticien")
attendu("icone", M.Get("mineur").icone, "Interface\\Icons\\inv_misc_profession_book_mining")

dire("== paliers (table XP METIER, incrementale)")
-- Le bareme a ete REECRIT : six couleurs de cinq niveaux, trente rangs, et
-- « Non appris » tant que le premier n'est pas paye. Il en avait sept, et le
-- premier coutait 5 XP (change par l'utilisateur, constate le 11 octobre
-- 2026 ; c'est le code qui fait foi).
--
-- Les bornes se lisent DANS le bareme, pas en dur : il a le droit de rebouger
-- sans qu'on ait a revenir ici. Ce qu'on verifie, c'est la MECANIQUE — on
-- reste au rang tant qu'on n'a pas paye, on passe quand on a paye, et le
-- bonus de jet suit la couleur.
local paliers = LCM.Equilibrage.metiers.paliers
attendu("trente rangs", #paliers, 30)
attendu("six couleurs", paliers[#paliers].rangCouleur, 6)
local p = M.Palier(moi, "mineur")
attendu("au depart : non appris", p.nom, "Non appris")
attendu("  rang zero", p.rang, 0)
attendu("  il reste a payer le premier palier", p.xpRestante, paliers[1].xp)
attendu("  et le bonus de jet est nul", M.Bonus(moi, "mineur"), 0)
attendu("rien en sauvegarde", moi.metiers, nil)
M.Gagner(moi, "mineur", paliers[1].xp - 1)
attendu("un point avant : toujours non appris", M.Palier(moi, "mineur").nom, "Non appris")
M.Gagner(moi, "mineur", 1)
local p1 = M.Palier(moi, "mineur")
attendu("le compte juste : premier rang", p1.rang, 1)
attendu("  son libelle", p1.libelle, paliers[1].nom .. " " .. paliers[1].niveau)
attendu("  rien d'acquis dans le nouveau palier", p1.xpDansPalier, 0)
attendu("  et le suivant coute ce qu'il coute", p1.xpRestante, paliers[2].xp)
attendu("  le bonus suit la couleur", M.Bonus(moi, "mineur"), paliers[1].rangCouleur)
M.Gagner(moi, "mineur", paliers[#paliers].cumul)
local haut = M.Palier(moi, "mineur")
attendu("tout en haut", haut.libelle, paliers[#paliers].nom .. " " .. paliers[#paliers].niveau)
attendu("palier maximal", haut.max, true)
attendu("bonus au plafond", M.Bonus(moi, "mineur"), paliers[#paliers].rangCouleur)
M.Gagner(moi, "mineur", -1000000)
attendu("pas sous zero, et efface", moi.metiers, nil)

dire("== la fenetre")
attendu("entree du menu allumee", LCM.UI.Menu.EstLiee("metiers"), true)
LCM.UI.Menu.Trouver("metiers").onClick()
local f = LCM.UI.Metiers.frame
attendu("ouverte", f:IsShown(), true)
attendu("une ligne par metier", #f.lignes, 32)
attendu("premier choisi", f.metierId, "depeceur")
attendu("detail", f.detail.label:GetText(), "Dépeçeur")
f.lignes[2]:Click()
attendu("mineur choisi", f.detail.label:GetText(), "Mineur")
attendu("palier affiche", f.detail.palier:GetText(), "Palier : Niveau 0")
-- Le bouton donne 10 XP. Le premier palier en coute davantage depuis la
-- reecriture du bareme : on clique jusqu'a le franchir, et on verifie que
-- c'est bien CE passage qui est annonce.
local premier = paliers[1]
local clics = math.ceil(premier.xp / 10)
for _ = 1, clics do f.detail.boutons[6]:Click() end
attendu("+10 XP par clic (MJ)", M.XP(moi, "mineur"), clics * 10)
local attenduLibelle = premier.nom .. " " .. premier.niveau
attendu("le premier palier est franchi", f.detail.palier:GetText(), "Palier : " .. attenduLibelle)
attendu("le passage est annonce",
    __sansCouleur(__sorties[#__sorties]):find("passe : " .. attenduLibelle) ~= nil, true)
attendu("dans la liste aussi", f.lignes[2].palier:GetText(), attenduLibelle)
attendu("barre", f.detail.barre.label:GetText(),
    string.format("%d / %d", clics * 10 - premier.cumul, paliers[2].xp))

LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Afficher()
attendu("le joueur ne donne pas d'XP", f.detail.boutons[1]:IsShown(), false)
-- Ce qu'on verifie, c'est que RIEN ne bouge : on compare a ce qu'il y avait
-- avant l'appel, pas a un nombre en dur qui depend de ce que le MJ a donne
-- plus haut.
local xpAvant = M.XP(moi, "mineur")
f:Gagner(10)
attendu("meme par appel direct", M.XP(moi, "mineur"), xpAvant)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
