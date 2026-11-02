-- Les sons de l'addon (2 novembre 2026) : l'appel de raid quand un combat
-- invite, le son de la fenetre du personnage sur Maj + C, et la case
-- « Couper le son » des parametres qui les tait tous.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end
local function dernierSon() local s = __sons[#__sons] return s and (s.id .. "/" .. s.canal) or "aucun" end
local function vider() for i = #__sons, 1, -1 do __sons[i] = nil end end

__declencher("PLAYER_LOGIN")
__personnage()
local C = LCM.Combat
LCM.CouperSons(false)

dire("== le MJ lance l'invitation : l'appel de raid")
__groupe({ "Nytherah" })
vider()
C.Inviter({ moi = true, pnj = {} })
attendu("le ready check, sur le canal Master", dernierSon(), "8960/Master")
C.Annuler()

dire("== le joueur la recoit : l'appel de raid aussi")
LCM.BasculerModeJoueur(true)
vider()
recevoir("Nytherah-Apertus", "combat?", { s = "son1" })
attendu("l'invitation est proposee", C.invitationRecue ~= nil, true)
attendu("  avec le son de l'appel", dernierSon(), "8960/Master")
C.invitationRecue = nil
LCM.BasculerModeJoueur(false)

dire("== Maj + C : le son de la fenetre du personnage")
local fiche, equipement = LCM.UI.Fiche.Fenetre(), LCM.UI.Vues.Fenetre("equipement")
fiche:Hide() equipement:Hide()
vider()
LCM_TogglePersonnage()
attendu("a l'ouverture", dernierSon(), "839/SFX")
LCM_TogglePersonnage()
attendu("a la fermeture", dernierSon(), "840/SFX")

dire("== « Couper le son » dans les parametres")
local P = LCM.UI.Parametres
P.Basculer()
local f = P.Fenetre()
f:Actualiser()
attendu("la case est la, decochee", f.sons:EstCochee(), false)
f.sons:Click()
attendu("la cocher coupe les sons", LCM.SonsCoupes(), true)
vider()
LCM_TogglePersonnage()
LCM_TogglePersonnage()
C.Inviter({ moi = true, pnj = {} })
C.Annuler()
attendu("plus rien ne joue", #__sons, 0)
f.sons:Click()
attendu("la decocher les rend", LCM.SonsCoupes(), false)
LCM_TogglePersonnage()
attendu("  et ils rejouent", dernierSon(), "839/SFX")
LCM_TogglePersonnage()
f:Hide()

print(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
