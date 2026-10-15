-- Le radial des fenêtres regroupe les écrans Système et Outils ; Coffres est
-- accessible à part et son constructeur n'est plus enfoui dans Ressources.
local ko = 0
local function attendu(nom, obtenu, voulu)
    if tostring(obtenu) ~= tostring(voulu) then
        ko = ko + 1
        print("  KO  " .. nom .. " = " .. tostring(obtenu) .. " (attendu " .. tostring(voulu) .. ")")
    else
        print("  ok  " .. nom .. " = " .. tostring(obtenu))
    end
end

__declencher("PLAYER_LOGIN")
__personnage()
local M = LCM.UI.Menu
local function enfants(id)
    local out = {}
    for _, e in ipairs(M.Trouver(id).enfants) do out[#out + 1] = e.id end
    return table.concat(out, ",")
end

attendu("onglet Système", enfants("systeme"), "systeme_aelskar,lieux,ressources,vendeur,coffres,regles")
attendu("onglet Outils", enfants("outils"), "campement,incarner,atelier,panneau_mj,parametres")
attendu("coffres relié au radial", M.EstLiee("coffres"), true)
SlashCmdList.LCM("coffres")
local coffre = LCM.UI.CoffresMJ and LCM.UI.CoffresMJ.frame
attendu("/lcm coffres ouvre le constructeur", coffre and coffre:IsShown(), true)
if coffre then coffre:Hide() end
LCM.UI.Recoltes.Basculer()
attendu("pas de bouton Coffres dans Ressources", LCM.UI.Recoltes.frame.boutonCoffres, nil)

if ko > 0 then error(tostring(ko) .. " vérification(s) en échec") end
print("TOUT PASSE")
