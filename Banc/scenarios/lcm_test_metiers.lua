-- Metiers : les 31 metiers du template, paliers incrementaux, fenetre.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local M = LCM.Metiers
local moi = LCM.Entities.Self()

dire("== les metiers du template")
attendu("31 metiers", #M.list, 31)
attendu("le premier", M.list[1].label, "Dépeçeur")
attendu("le dernier", M.list[31].label, "Informaticien")
attendu("icone", M.Get("mineur").icone, "Interface\\Icons\\inv_misc_profession_book_mining")

dire("== paliers (table XP METIER, incrementale)")
local p = M.Palier(moi, "mineur")
attendu("au depart : Rose", p.nom, "Rose")
attendu("5 XP pour passer", p.xpRestante, 5)
attendu("bonus de jet = rang", M.Bonus(moi, "mineur"), 1)
attendu("rien en sauvegarde", moi.metiers, nil)
M.Gagner(moi, "mineur", 3)
attendu("3 XP", M.XP(moi, "mineur"), 3)
attendu("encore Rose", M.Palier(moi, "mineur").nom, "Rose")
M.Gagner(moi, "mineur", 2)
attendu("5 XP : Vert", M.Palier(moi, "mineur").nom, "Vert")
attendu("XP dans le palier", M.Palier(moi, "mineur").xpDansPalier, 0)
attendu("20 pour le suivant", M.Palier(moi, "mineur").xpRestante, 20)
M.Gagner(moi, "mineur", 5 + 20 + 50 + 100 + 200 + 500 - 5 + 10000)
attendu("tout en haut : Noir", M.Palier(moi, "mineur").nom, "Noir")
attendu("palier maximal", M.Palier(moi, "mineur").max, true)
attendu("bonus 7", M.Bonus(moi, "mineur"), 7)
M.Gagner(moi, "mineur", -1000000)
attendu("pas sous zero, et efface", moi.metiers, nil)

dire("== la fenetre")
attendu("entree du menu allumee", LCM.UI.Menu.EstLiee("metiers"), true)
LCM.UI.Menu.Trouver("metiers").onClick()
local f = LCM.UI.Metiers.frame
attendu("ouverte", f:IsShown(), true)
attendu("une ligne par metier", #f.lignes, 31)
attendu("premier choisi", f.metierId, "depeceur")
attendu("detail", f.detail.label:GetText(), "Dépeçeur")
f.lignes[2]:Click()
attendu("mineur choisi", f.detail.label:GetText(), "Mineur")
attendu("palier affiche", f.detail.palier:GetText(), "Palier : Rose")
f.detail.boutons[6]:Click()
attendu("+10 XP (MJ)", M.XP(moi, "mineur"), 10)
attendu("palier Vert", f.detail.palier:GetText(), "Palier : Vert")
attendu("le passage est annonce", __sansCouleur(__sorties[#__sorties]):find("passe : Vert") ~= nil, true)
attendu("dans la liste aussi", f.lignes[2].palier:GetText(), "Vert")
attendu("barre", f.detail.barre.label:GetText(), "5 / 20")

LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Afficher()
attendu("le joueur ne donne pas d'XP", f.detail.boutons[1]:IsShown(), false)
f:Gagner(10)
attendu("meme par appel direct", M.XP(moi, "mineur"), 10)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
