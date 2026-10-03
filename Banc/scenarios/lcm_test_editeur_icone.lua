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

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
