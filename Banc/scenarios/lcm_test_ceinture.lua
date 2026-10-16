-- La ceinture (13 octobre 2026) : un emplacement toujours la, avec ses cases
-- de base meme nu ; un objet « ceinture » pose par-dessus y AJOUTE les siennes.
-- Et le clic droit sur un emplacement : Ouvrir, Voir, Échanger, Jeter.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("sacs", { id = "sac_d_essai", label = "Sac d'essai", places = 12, icone = "inv_misc_bag_30" })
LCM.Brouillons.Set("sacs", { id = "ceinture_d_essai", label = "Ceinture d'essai", nature = "ceinture",
                              places = 2, icone = "inv_belt_05" })
__declencher("PLAYER_LOGIN")
__personnage()
local I = LCM.Inventaire
local moi = LCM.Entities.Self()
local BASE = LCM.Equilibrage.inventaire.placesCeinture
local function ceinture() return I.Emplacement(moi, "ceintures", 1) end

dire("== nue, elle a ses cases de base")
attendu("trois de base (equilibrage)", BASE, 3)
attendu("un emplacement", I.Capacite("ceintures"), 1)
attendu("jamais vide", ceinture() ~= nil, true)
attendu("ses cases", I.Cases(ceinture()), BASE)
attendu("la lire n'ecrit rien", moi.inventaire, nil)
attendu("on y range", I.Ranger(moi, "ceintures", 1, 1, "ressources/eau", 1), true)
attendu("c'est rangé", I.Case(ceinture(), 1).ref, "ressources/eau")
attendu("pas de sac dans une ceinture", (I.Ranger(moi, "ceintures", 1, 2, "sacs/sac_d_essai", 1)), false)
attendu("vidée, la sauvegarde s'efface", (function() I.Vider(moi, "ceintures", 1, 1) return moi.inventaire end)(), nil)
attendu("une recolte sans sac y tombe", (I.Deposer(moi, "ressources/eau", 1)), true)
attendu("dans la ceinture", I.Case(ceinture(), 1) and I.Case(ceinture(), 1).ref, "ressources/eau")

dire("== l'objet ceinture va sur la ceinture, et nulle part ailleurs")
local refus, raison = I.Poser(moi, "sacs", 1, "ceinture_d_essai")
attendu("pas sur un emplacement de sac", refus, false)
dire("     " .. tostring(raison))
refus, raison = I.Poser(moi, "ceintures", 1, "sac_d_essai")
attendu("un sac ne se pose pas sur la ceinture", refus, false)
dire("     " .. tostring(raison))

dire("== glisser l'objet d'une case sur la ceinture : il quitte sa case")
I.Poser(moi, "sacs", 1, "sac_d_essai")
I.Ranger(moi, "sacs", 1, 5, "sacs/ceinture_d_essai", 1)
LCM.UI.Menu.Trouver("inventaires").onClick()
local f = LCM.UI.Inventaires.frame
local carteCeinture
for _, c in ipairs(f.cartes) do if c:IsShown() and c.onglet == "ceintures" then carteCeinture = c end end
attendu("la ceinture est dans la colonne", carteCeinture ~= nil, true)
attendu("nue : son nom et ses cases", carteCeinture.nom:GetText(), "Ceinture (1/3)")
-- Une ligne de description sur la carte, le reste dans l'infobulle : elle
-- sortait de la carte (13 octobre 2026).
attendu("la description ne passe pas a la ligne", carteCeinture.description:CanWordWrap(), false)
carteCeinture:GetScript("OnEnter")(carteCeinture)
local bulle = LCM.UI.Infobulle()
local entiere = false
for i = 1, bulle.nombreLignes do
    if bulle.lignes[i]:GetText() == carteCeinture.description:GetText() then entiere = true end
end
attendu("l'infobulle la donne entiere", entiere, true)
carteCeinture:GetScript("OnLeave")(carteCeinture)
f.cartes[1]:Click("LeftButton")
local ligne = f.lignes[5]
__souris.LeftButton = true
ligne:GetScript("OnDragStart")(ligne)
carteCeinture.__survol = true
__avancer(0.02, 0.02)
__souris.LeftButton = false
__avancer(0.02, 0.02)
carteCeinture.__survol = nil
attendu("posée par-dessus", ceinture().sac, "ceinture_d_essai")
attendu("et partie de sa case (pas de double)", I.Case(I.Emplacement(moi, "sacs", 1), 5), nil)
attendu("3 + 2 cases", I.Cases(ceinture()), BASE + 2)
attendu("ce qu'elle tenait est toujours la", I.Case(ceinture(), 1).ref, "ressources/eau")
attendu("la carte le dit", carteCeinture.nom:GetText(), "Ceinture d'essai (1/5)")
refus, raison = I.Poser(moi, "ceintures", 1, "ceinture_d_essai")
attendu("une seule a la fois", refus, false)

dire("== la retirer : refusée tant que ses cases en plus sont pleines")
I.Ranger(moi, "ceintures", 1, 4, "ressources/eau", 1)
refus, raison = I.Retirer(moi, "ceintures", 1)
attendu("refus", refus, false)
attendu("et pourquoi", raison, "vide d'abord les cases au-delà de 3.")
I.Vider(moi, "ceintures", 1, 4)

dire("== clic droit sur la ceinture : Ouvrir, Voir, Échanger, Jeter")
local menu = LCM.UI.MenuContexte()
local function libelles()
    local t = {}
    for _, l in ipairs(menu.lignes) do if l:IsShown() then t[#t + 1] = l.texte:GetText() end end
    return table.concat(t, ",")
end
local function cliquer(libelle)
    for _, l in ipairs(menu.lignes) do
        if l:IsShown() and l.texte:GetText() == libelle then l:Click() return true end
    end
    return false
end
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false
f:Rafraichir()
carteCeinture:Click("RightButton")
attendu("le menu du joueur", libelles(), "Ouvrir,Voir,Échanger,Détruire")
cliquer("Détruire")
local d
for _, cadre in ipairs({ UIParent:GetChildren() }) do
    if cadre.oui and cadre.non and cadre:IsShown() then d = cadre end
end
attendu("on demande", d ~= nil, true)
d.oui:Click()
attendu("l'objet ceinture est jeté", ceinture().sac, nil)
attendu("les cases de base gardent leur contenu", I.Case(ceinture(), 1).ref, "ressources/eau")
attendu("redevenue nue", I.Cases(ceinture()), BASE)

dire("== nue, rien a jeter ni a echanger")
carteCeinture:Click("RightButton")
attendu("seulement Ouvrir", libelles(), "Ouvrir")
menu:Hide()

dire("== un sac plein ne s'echange ni ne se jette : on dit pourquoi")
I.Ranger(moi, "sacs", 1, 1, "ressources/eau", 1)
f.cartes[1]:Click("RightButton")
attendu("le menu d'un sac", libelles(), "Ouvrir,Voir,Échanger,Détruire")
cliquer("Détruire")
local dit = false
for _, sortie in ipairs(__sorties) do
    if __sansCouleur(sortie):find("pas vide", 1, true) then dit = true end
end
attendu("refus dit", dit, true)
attendu("le sac est toujours la", I.Emplacement(moi, "sacs", 1).sac, "sac_d_essai")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
