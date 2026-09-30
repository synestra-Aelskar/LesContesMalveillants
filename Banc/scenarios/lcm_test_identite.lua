-- Identite : le profil Total RP 3 (nom RP, icone), comme Necronicon.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local I = LCM.Identite
local M = LCM.UI.Menu
local bouton = M.Bouton()

dire("== sans TRP3")
attendu("pas de profil", I.ProfilTRP(), nil)
attendu("nom du personnage WoW", I.Joueur().nom, UnitName("player"))
attendu("pas d'icone", I.Joueur().icone, nil)
attendu("bouton : repli", bouton.icone:GetTexture(), "Interface\\Icons\\INV_Misc_QuestionMark")

dire("== TRP3 se charge apres nous")
TRP3_API = { profile = { getData = function(qui)
    return { characteristics = { FN = " Erzah ", LN = "Vel'Dran", IC = "inv_misc_head_dragon_01" } }
end } }
__declencher("ADDON_LOADED", "totalRP3")
attendu("nom RP", I.Joueur().nom, "Erzah Vel'Dran")
attendu("icone TRP3", I.Joueur().icone, "Interface\\Icons\\inv_misc_head_dragon_01")
attendu("le bouton du menu la prend", bouton.icone:GetTexture(), "Interface\\Icons\\inv_misc_head_dragon_01")
attendu("identifiant inchange", I.Joueur().joueur, LCM.PlayerId())

dire("== profil incomplet")
TRP3_API.profile.getData = function() return { characteristics = { FN = "", LN = "", IC = "" } } end
attendu("nom vide : nom WoW", I.Joueur().nom, UnitName("player"))
attendu("icone vide : rien", I.IconeTRP(), nil)

dire("== TRP3 qui plante ne nous fait pas tomber")
TRP3_API.profile.getData = function() error("boum") end
attendu("pas d'erreur, pas de profil", I.ProfilTRP(), nil)
M.ActualiserIcone()
attendu("bouton : repli", bouton.icone:GetTexture(), "Interface\\Icons\\INV_Misc_QuestionMark")
TRP3_API = nil

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
