-- Inventaires : les sacs (catalogue) et la fenetre en grille du template.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("sacs", { id = "gros_sac", label = "Gros sac", places = 12, icone = "inv_misc_bag_30" })
LCM.Brouillons.Set("sacs", { id = "sac_de_gros", label = "Sac de gros", places = 25 })
__declencher("PLAYER_LOGIN")
local S = LCM.Sacs
local moi = LCM.Entities.Self()

dire("== le catalogue des sacs")
attendu("places", S.Get("gros_sac").places, 12)
attendu("places de devise par defaut", S.Get("gros_sac").placesDevise, 0)
attendu("icone", S.Get("gros_sac").icone, "Interface\\Icons\\inv_misc_bag_30")
local ok = pcall(S.Construire, { id = "x", places = 0 })
attendu("un sac sans place est refuse", ok, false)
ok = pcall(S.Construire, { id = "x", places = "beaucoup" })
attendu("un nombre illisible aussi", ok, false)
attendu("quatre sacs au plus", S.Capacite("sac"), 4)

dire("== porter des sacs, identiques compris")
attendu("un", S.Placer(moi, "gros_sac"), true)
attendu("le meme une seconde fois", S.Placer(moi, "gros_sac"), true)
attendu("deux sacs", #S.Ids(moi, "sac"), 2)
S.Placer(moi, "sac_de_gros")
S.Placer(moi, "sac_de_gros")
local refus, raison = S.Placer(moi, "gros_sac")
attendu("le cinquieme est refuse", refus, false)
dire("     " .. tostring(raison))
attendu("un sac ne donne rien", LCM.Effets.Bonus(moi, "force"), 0)
S.Enlever(moi, "gros_sac")
attendu("retirer n'enleve qu'un exemplaire", #S.Ids(moi, "sac"), 3)

dire("== la fenetre")
local M = LCM.UI.Menu
attendu("entree du menu allumee", M.EstLiee("inventaires"), true)
M.Trouver("inventaires").onClick()
local f = LCM.UI.Inventaires.frame
attendu("ouverte", f:IsShown(), true)
attendu("categorie Sacs", f.barre.boutons[1].label:GetText(), "Sacs")
attendu("occupation", f.occupation:GetText(), "3 / 4 sacs")
local carte = f.cartes[1]
attendu("une carte par sac", carte.nom:GetText(), "Gros sac")
attendu("son nombre de places", carte.description:GetText(), "12 places")
attendu("carte d'ajout (MJ)", f.cartes[4].ajout, true)
attendu("cartes en grille : la deuxieme a droite", select(4, f.cartes[2]:GetPoint(1)) > select(4, carte:GetPoint(1)), true)
f.cartes[4].action:Click()
for _, b in ipairs(f.choix.lignes) do if b:IsShown() and b.choix == "gros_sac" then b:Click() end end
attendu("sac ajoute", #S.Ids(moi, "sac"), 4)
attendu("plus de carte d'ajout", f.cartes[5] == nil or not f.cartes[5]:IsShown(), true)
f.cartes[1].action:Click()
attendu("sac retire", #S.Ids(moi, "sac"), 3)

dire("== le joueur voit ses sacs, ne les touche pas")
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Afficher()
attendu("pas de bouton retirer", f.cartes[1].action:IsShown(), false)
attendu("pas de carte d'ajout", f.cartes[4]:IsShown(), false)
LCM._masterCompanion = true
__addonsCharges["LesContesMalveillants_MJ"] = true

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
