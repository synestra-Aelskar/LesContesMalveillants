-- Regression : icones des definitions, et reinitialisation entre deux cibles.
local UI, C = LCM.UI, LCM.Coffres
local art = "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\"
LCM.Brouillons.Set("sacs", { id = "sac_icone", label = "Sac", nature = "sac", places = 5, icone = "inv_misc_bag_09" })
LCM.Brouillons.Set("ressources", { id = "herbe_icone", label = "Herbe", icone = "inv_misc_herb_01" })
__declencher("PLAYER_LOGIN")
__personnage()
local function verifier(label, obtenu, voulu)
    assert(obtenu == voulu, label .. " : " .. tostring(obtenu) .. " au lieu de " .. tostring(voulu))
    print("ok : " .. label)
end
C.definitions.icone = { label = "Sac", coffre = { sac = "sac_icone" } }
UI.Coffre.Proche({ id = "point", def = "icone" })
verifier("icone du sac reel", UI.Coffre.bouton.icone:GetTexture(), LCM.Icone("inv_misc_bag_09"))
C.definitions.icone.coffre = { objet = true, objets = { { entree = "ressources/herbe_icone", quantite = 1 } } }
UI.Coffre.Proche({ id = "point", def = "icone" })
verifier("icone de l'objet au sol", UI.Coffre.bouton.icone:GetTexture(), LCM.Icone("inv_misc_herb_01"))
C.definitions.icone.coffre = {}
UI.Coffre.Proche({ id = "point", def = "icone" })
verifier("coffre propre apres un objet", UI.Coffre.bouton.icone:GetTexture(), art .. "fenetres-coffres.tga")
LCM.Recolte.definitions.icone = { label = "Herbe", ressources = { { entree = "ressources/herbe_icone" } } }
UI.Recolte.Actualiser({ id = "point", def = "icone" })
verifier("ressource unique", UI.Recolte.bouton.icone:GetTexture(), LCM.Icone("inv_misc_herb_01"))
table.insert(LCM.Recolte.definitions.icone.ressources, { entree = "ressources/herbe_icone" })
UI.Recolte.Actualiser({ id = "point", def = "icone" })
verifier("point multiple", UI.Recolte.bouton.icone:GetTexture(), art .. "fenetres-recoltes.tga")
print("TOUT PASSE")
