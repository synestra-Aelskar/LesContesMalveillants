-- I ouvre l'inventaire de l'addon, et les touches natives qui ouvrent
-- un seul sac de WoW ne font plus rien (20 octobre 2026). Le tout par
-- surcharges : les raccourcis enregistres du joueur ne sont pas reecrits.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

-- Le joueur a mis son sac 2 sur une touche a lui : elle doit etre lue, pas
-- supposee.
__raccourcis.F10 = nil
__raccourcis["CTRL-2"] = "TOGGLEBAG2"
-- Un sac temoin, pour ecouter un vrai sac s'ouvrir.
LCM.Brouillons.Set("sacs", { id = "sac_d_essai", label = "Sac d'essai", places = 12, icone = "inv_misc_bag_30" })
__declencher("PLAYER_LOGIN")
__personnage()

local R = LCM.UI.Raccourcis
local MUET = "CLICK LCM_RaccourciMuet:LeftButton"

dire("== I")
attendu("I ouvre l'inventaire (il recouvre la recherche de groupe)", GetBindingAction("I"), "LCM_INVENTAIRE")
local f = LCM.UI.Inventaires.Fenetre()
f:Hide()
LCM_ToggleInventaire()
attendu("l'action ouvre la fenetre", f:IsShown(), true)
LCM_ToggleInventaire()
attendu("et la referme", f:IsShown(), false)

dire("== le son des sacs de WoW")
local function dernierSon() return __sons[#__sons] and __sons[#__sons].id end
LCM_ToggleInventaire()
attendu("ouvrir l'inventaire sonne comme un sac", dernierSon(), SOUNDKIT.IG_BACKPACK_OPEN)
LCM_ToggleInventaire()
attendu("le fermer aussi", dernierSon(), SOUNDKIT.IG_BACKPACK_CLOSE)
LCM.Inventaire.Poser(LCM.Entities.Self(), "sacs", 1, "sac_d_essai", true)
local sac = LCM.UI.Inventaires.OuvrirSac("sacs", 1)
attendu("un sac ouvert sonne", dernierSon(), SOUNDKIT.IG_BACKPACK_OPEN)
sac:Hide()
attendu("un sac ferme sonne", dernierSon(), SOUNDKIT.IG_BACKPACK_CLOSE)
-- Un emplacement sans sac : la fenetre se referme aussitot, sans sonner une
-- ouverture qui n'a pas eu lieu.
local avant = #__sons
LCM.UI.Inventaires.OuvrirSac("sacs", 2)
attendu("un emplacement vide ne sonne pas l'ouverture", __sons[avant + 1] == nil or __sons[#__sons].id ~= SOUNDKIT.IG_BACKPACK_OPEN, true)

dire("== Maj + C : la fiche et l'equipement")
attendu("Maj + C ouvre le personnage", GetBindingAction("SHIFT-C"), "LCM_PERSONNAGE")
local fiche, equipement = LCM.UI.Fiche.Fenetre(), LCM.UI.Vues.Fenetre("equipement")
fiche:Hide() equipement:Hide()
LCM_TogglePersonnage()
attendu("la fiche s'ouvre", fiche:IsShown(), true)
attendu("l'equipement aussi", equipement:IsShown(), true)
-- Fiche a gauche, equipement a droite, et leurs bordures (qui debordent du
-- rectangle) ne se touchent pas. Le banc ne calcule pas de bords d'ecran :
-- on lit les ancrages.
local function ancre(f)
    local point, relatif, relPoint, x = f:GetPoint(1)
    return point, relatif, relPoint, x, f:GetNumPoints()
end
local ecartMini = (fiche.decor and fiche.decor.debordDroite or 0)
    + (equipement.decor and equipement.decor.debordGauche or 0)
-- Depuis la maquette du MJ (20 octobre 2026) : alignees par le haut, la meme
-- hauteur, et de l'air entre les deux (la poignee du volet d'artwork depasse
-- du bord droit de la fiche).
local p, rel, rp, x, n = ancre(fiche)
attendu("la fiche a gauche du centre",
    p == "TOPRIGHT" and rel == UIParent and rp == "CENTER" and x < 0 and n == 1, true)
local p2, rel2, rp2, x2, n2 = ancre(equipement)
attendu("l'equipement a sa droite, haut contre haut",
    p2 == "TOPLEFT" and rel2 == fiche and rp2 == "TOPRIGHT" and select(5, equipement:GetPoint(1)) == 0 and n2 == 1, true)
attendu("  avec de l'air entre les bordures", x2 - ecartMini >= 40, true)
attendu("  et la meme hauteur", equipement:GetHeight(), fiche:GetHeight())
LCM_TogglePersonnage()
attendu("les deux se ferment", fiche:IsShown() or equipement:IsShown(), false)
equipement:Montrer()
LCM_TogglePersonnage()
attendu("une seule ouverte : la touche ouvre l'autre", fiche:IsShown() and equipement:IsShown(), true)
local p3, rel3, rp3, x3, n3 = ancre(fiche)
attendu("  la fiche vient se coller a sa gauche",
    p3 == "TOPRIGHT" and rel3 == equipement and rp3 == "TOPLEFT" and -x3 > ecartMini and n3 == 1, true)
fiche:Hide() equipement:Hide()

dire("== les sacs natifs")
for _, touche in ipairs({ "F12", "SHIFT-B", "F11", "F9", "F8", "CTRL-2" }) do
    attendu(touche .. " ne fait plus rien", GetBindingAction(touche), MUET)
end
attendu("le bouton muet existe", _G.LCM_RaccourciMuet ~= nil, true)
attendu("B (tous les sacs) reste a WoW", GetBindingAction("B"), "OPENALLBAGS")
attendu("une touche sans rapport n'est pas touchee", GetBindingAction("L"), "TOGGLEQUESTLOG")
attendu("les raccourcis du joueur ne sont pas reecrits", __raccourcis.F12, "TOGGLEBACKPACK")

dire("== reposer ne double rien")
R.Poser()
attendu("autant de touches neutralisees", #R.neutralisees, 6)

dire("== un sac sur I : l'inventaire gagne")
__raccourcis["I"] = "TOGGLEBAG3"
R.Poser()
attendu("I ouvre toujours l'inventaire", GetBindingAction("I"), "LCM_INVENTAIRE")

dire("== en combat, on attend la fin")
local combat = InCombatLockdown
InCombatLockdown = function() return true end
attendu("pas de surcharge en combat", R.Poser(), false)
InCombatLockdown = combat
__declencher("PLAYER_REGEN_ENABLED")
attendu("posees a la sortie du combat", R.enAttente, nil)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
