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
local f = Ed.frame
attendu("l'editeur s'ouvre", f ~= nil and f:IsShown(), true)
attendu("il est modifiable", f.lecture, false)

dire("== l'apercu est un bouton")
local ic = f.panneauIcone
attendu("c'est un bouton", ic.apercuBouton ~= nil, true)
attendu("avec son selecteur", ic.selecteur ~= nil, true)
ic.apercuBouton:Click()
attendu("le selecteur s'ouvre", ic.selecteur:IsShown(), true)

dire("== choisir une icone la pose")
local choisie
for _, b in ipairs(ic.selecteur.cases) do
    if b:IsShown() and not choisie then choisie = b end
end
attendu("il propose des icones", choisie ~= nil, true)
choisie:Click()
attendu("le chemin est recopie", ic.chemin:GetText(), choisie.chemin)
attendu("et retenu sur l'entree", f.travail.e.icone, choisie.chemin)
attendu("le selecteur se referme", ic.selecteur:IsShown(), false)

dire("== en lecture seule, on ne propose rien")
f.lecture = true
ic.apercuBouton:Click()
attendu("le selecteur reste ferme", ic.selecteur:IsShown(), false)
attendu("et on dit quoi faire",
    __sansCouleur(__sorties[#__sorties]):find("duplique") ~= nil, true)

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
navigateur:Proposer(ic.apercuBouton, function(chemin) selection = chemin end)
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
