-- Un objet de sac au clic droit : Voir, Échanger, Jeter, pour tout le monde.
-- Et le lacher dans le vide qui propose de jeter (13 octobre 2026 : il avait
-- disparu, et l'echange comme le jet n'avaient qu'un geste qu'on ne devine pas).
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("sacs", { id = "sac_d_essai", label = "Sac d'essai", places = 12, icone = "inv_misc_bag_30" })
__declencher("PLAYER_LOGIN")
local I = LCM.Inventaire
__personnage()
local moi = LCM.Entities.Self()
I.Poser(moi, "sacs", 1, "sac_d_essai", true)
local DAGUE = "objets/dague_d_assassin_du_culte"
local function dague() local c = I.Case(I.Emplacement(moi, "sacs", 1), 3) return c and c.ref end
I.Ranger(moi, "sacs", 1, 3, DAGUE, 1)

-- On joue en JOUEUR : ces gestes ne sont pas reserves au MJ.
LCM._masterCompanion = false
__addonsCharges["LesContesMalveillants_MJ"] = false

LCM.UI.Menu.Trouver("inventaires").onClick()
local f = LCM.UI.Inventaires.frame
f.cartes[1]:Click("LeftButton")
local ligne = f.lignes[3]
-- Le menu est cree au premier usage : on le demande au kit.
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

dire("== clic droit dans le panneau de contenu")
ligne:Click("RightButton")
attendu("le menu s'ouvre", menu:IsShown(), true)
attendu("Voir, Échanger, Jeter", libelles(), "Voir,Échanger,Détruire")

dire("== Jeter demande, et Annuler ne jette rien")
cliquer("Détruire")
local d
for _, cadre in ipairs({ UIParent:GetChildren() }) do
    if cadre.oui and cadre.non and cadre:IsShown() then d = cadre end
end
attendu("une confirmation", d ~= nil, true)
attendu("elle nomme l'objet", d and d.texte:GetText():find("Détruire « ", 1, true) ~= nil, true)
d.non:Click()
attendu("annule : la dague est la", dague(), DAGUE)

dire("== Jeter, puis oui")
ligne:Click("RightButton")
cliquer("Détruire")
d.oui:Click()
attendu("la dague est jetee", dague(), nil)
attendu("la ligne le montre", ligne.nom:GetText(), "Vide")

dire("== l'objet a bouge entre la question et la reponse")
I.Ranger(moi, "sacs", 1, 3, DAGUE, 1)
f:Rafraichir()
ligne:Click("RightButton")
cliquer("Détruire")
I.Vider(moi, "sacs", 1, 3)
I.Ranger(moi, "sacs", 1, 3, "ressources/eau", 1)
d.oui:Click()
attendu("ce qui a pris sa place n'est pas jete", I.Case(I.Emplacement(moi, "sacs", 1), 3).ref, "ressources/eau")
I.Vider(moi, "sacs", 1, 3)
I.Ranger(moi, "sacs", 1, 3, DAGUE, 1)
f:Rafraichir()

dire("== Échanger : la liste du groupe")
ligne:Click("RightButton")
cliquer("Échanger")
local dit = false
for _, sortie in ipairs(__sorties) do
    -- Sans :lower() : il abime les accents UTF-8 (« à »).
    if __sansCouleur(sortie):find("ersonne à qui le donner", 1, true) then dit = true end
end
attendu("seul, on dit pourquoi", dit, true)
__groupe({ "Nytherah-Apertus" })
ligne:Click("RightButton")
attendu("en groupe : un sous-menu", libelles(), "Voir,Échanger >,Détruire")
cliquer("Échanger >")
attendu("le membre du groupe", menu.sousLignes[1].texte:GetText(), "Nytherah-Apertus")
menu.sousLignes[1]:Click()
attendu("l'echange est propose", LCM.Echange.courant ~= nil and LCM.Echange.courant.qui, "Nytherah-Apertus")
attendu("la dague attend la reponse, encore au sac", dague(), DAGUE)
LCM.Echange.Annuler("essai", true)
__groupe({})

dire("== lacher dans le vide : l'objet tombe au sol")
-- 16 octobre 2026 (le MJ) : un objet lache hors de l'inventaire n'est plus
-- detruit, il TOMBE et se ramasse (Core/SacsAuSol.lua). Detruire, c'est le
-- clic droit, « Détruire ». Ce passage proposait de jeter ; il verifie
-- maintenant la chute, puis remet la dague a sa place pour la suite.
__position(5, 5, 0)
local function lacherSur(focus)
    __focusSouris(focus)
    __souris.LeftButton = true
    ligne:GetScript("OnDragStart")(ligne)
    __avancer(0.02, 0.02)
    __souris.LeftButton = false
    __avancer(0.02, 0.02)
    __focusSouris(nil)
end
lacherSur(nil)
attendu("pas de confirmation : rien n'est detruit", d:IsShown(), false)
attendu("la dague a quitte le sac", dague(), nil)
local auSol
for id, s in pairs(LCM.SacsAuSol.sacs) do if s.objet and s.objets[1].entree == DAGUE then auSol = id end end
attendu("  elle est au sol, a ramasser", auSol ~= nil, true)
-- On la remet a sa place pour la suite.
if auSol then LCM.SacsAuSol.Mourir(auSol) end
LCM.Inventaire.Ranger(LCM.Entities.Self(), "sacs", 1, 3, DAGUE, 1)
attendu("et la dague est revenue", dague(), DAGUE)
lacherSur(f)
attendu("lache sur une fenetre : rien a jeter", d:IsShown(), false)
attendu("la dague est toujours la", dague(), DAGUE)

dire("== dans la fenetre du sac, le meme menu")
local s = LCM.UI.Inventaires.OuvrirSac("sacs", 1)
local case
for _, b in ipairs(s.cases) do if b:IsShown() and b.index == 3 then case = b end end
case:Click("RightButton")
attendu("joueur : Voir, Échanger, Jeter", libelles(), "Voir,Échanger,Détruire")
menu:Hide()

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
