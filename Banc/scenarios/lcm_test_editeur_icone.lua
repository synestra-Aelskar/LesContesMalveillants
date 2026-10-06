-- L'editeur d'entree du compendium : l'icone se choisit au clic.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
local C = LCM.Compendium
local Ed = LCM.CompendiumEditeur

dire("== une entree qu'on peut modifier")
-- Un brouillon : le contenu publie est en lecture seule, on le duplique.
local categorie = C.Get("armes")
LCM.Brouillons.Set("objets", { id = "essai_icone", label = "Essai", categorie = "armes" })
local brouillon = LCM.Brouillons.Get("objets", "essai_icone")
attendu("brouillon cree", brouillon ~= nil, true)
Ed.Ouvrir(categorie, brouillon)
local f = LCM.UI.Forge.Fenetre()
attendu("la Forge s'ouvre", f ~= nil and f:IsShown(), true)
attendu("elle modifie la bonne entrée", LCM.UI.Forge.courant.editionId, "essai_icone")

dire("== l'apercu est un bouton")
local ic = f.icone
attendu("c'est un bouton", ic ~= nil, true)
attendu("avec son selecteur", f.selecteurIcone ~= nil, true)
ic:Click()
attendu("le selecteur s'ouvre", f.selecteurIcone:IsShown(), true)

dire("== choisir une icone la pose")
local choisie
for _, b in ipairs(f.selecteurIcone.cases) do
    if b:IsShown() and not choisie then choisie = b end
end
attendu("il propose des icones", choisie ~= nil, true)
choisie:Click()
attendu("et retenu dans la Forge", LCM.UI.Forge.courant.icone, choisie.chemin)
attendu("l'apercu est actualise", ic.texture:GetTexture(), LCM.Icone(choisie.chemin))
attendu("le selecteur se referme", f.selecteurIcone:IsShown(), false)

dire("== navigateur Omega : pool fixe et catalogue complet")
attendu("chemin WoW avec slash normalise", LCM.Icone("Interface/ICONS/INV_Misc_Book_09"),
    "Interface\\ICONS\\INV_Misc_Book_09")
attendu("chemin addon avec slash normalise", LCM.Icone("Interface/AddOns/LesContesMalveillants/ressources/radial/icones/animation.tga"),
    "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\animation.tga")
attendu("nom court conserve", LCM.Icone("INV_Misc_Book_09"), "Interface\\Icons\\INV_Misc_Book_09")
local iconesCampagne = LCM.UI.CatalogueIcones("addon")
local aIconeRadiale = false
for _, chemin in ipairs(iconesCampagne) do
    if chemin == "Interface\\AddOns\\LesContesMalveillants\\ressources\\radial\\icones\\animation.tga" then
        aIconeRadiale = true
        break
    end
end
attendu("icone creee disponible dans le catalogue", aIconeRadiale, true)
local catalogueOriginal = LCM.UI.CatalogueIcones
local catalogue = {}
for i = 1, 1200 do catalogue[i] = "Interface/Icons/Test_" .. i end
LCM.UI.CatalogueIcones = function() return catalogue end
local navigateur = LCM.UI.SelecteurIcone("test_grille_omega")
local selection
navigateur:Proposer(ic, function(chemin) selection = chemin end)
attendu("84 boutons seulement", #navigateur.cases, 84)
navigateur:Defiler(10000)
attendu("la derniere icone est accessible", navigateur.cases[84].chemin, catalogue[1200])
attendu("pool inchange apres defilement", #navigateur.cases, 84)
navigateur.recherche:Saisir("Test_1200")
attendu("recherche au dela des 900 premieres", #navigateur.resultats, 1)
navigateur.cases[1]:Click()
attendu("selection depuis le resultat", selection, catalogue[1200])
navigateur:Remplir("introuvable")
attendu("message sans resultat", navigateur.vide:IsShown(), true)
LCM.UI.CatalogueIcones = catalogueOriginal
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
