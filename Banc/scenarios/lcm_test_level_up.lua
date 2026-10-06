-- Montees de niveau en attente : notification radiale et repartition palier par palier.
local function dire(...) print(table.concat({...}, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local X, C = LCM.Experience, LCM.Creation
local moi = LCM.Entities.Self()
LCM.Entities.Set_Value(moi, "niveau", 5)
moi.xp = 0

local function visible(noeuds, id)
    for _, n in ipairs(LCM.UI.Menu.Visibles(noeuds)) do if n.id == id then return n end end
end

dire("== l'XP cree une file, sans monter la fiche")
attendu("aucun niveau au depart", X.NiveauxEnAttente(moi), 0)
attendu("pas d'entree level-up", visible(LCM.UI.Menu.Trouver("fiches_personnages").enfants, "montee_niveau"), nil)
local gain = X.Donner(moi, 1000)
attendu("droit au niveau 9", gain.apres, 9)
attendu("quatre niveaux attendent", X.NiveauxEnAttente(moi), 4)
attendu("la fiche reste niveau 5", LCM.Entities.Get_Value(moi, "niveau"), 5)
attendu("l'entree apparait", visible(LCM.UI.Menu.Trouver("fiches_personnages").enfants, "montee_niveau").id, "montee_niveau")

dire("== la notification est visible dans le radial")
local R = LCM.UI.Radial
local radial = R.frame
radial.sceau:Click("LeftButton")
__avancer(1)
local couronne = radial.couronnes.fenetres
local personnage
for i = 1, couronne.nombreCategories do
    local b = couronne.boutonsCategorie[i]
    if b.cible.id == "fiches_personnages" then personnage = b end
end
attendu("badge sur Personnage", personnage.badge:IsShown(), true)
attendu("badge compte quatre niveaux", personnage.badge.texte:GetText(), "4")
personnage:Click("LeftButton")
__avancer(1)
local levelup
for i = 1, couronne.nombreEntrees do
    local b = couronne.boutonsEntree[i]
    if b.cible.id == "montee_niveau" then levelup = b end
end
attendu("icone de niveau dans l'eventail", levelup ~= nil, true)
attendu("son badge compte aussi quatre", levelup.badge.texte:GetText(), "4")
levelup:Click("LeftButton")

dire("== le createur passe un seul niveau")
local f = LCM.UI.Creation.frame
attendu("mode niveau", f.brouillon.mode, "niveau")
attendu("premier passage 5 vers 6", f.brouillon.niveauAvant .. " -> " .. f.brouillon.niveau, "5 -> 6")
attendu("Bienvenue masquee", f.barre.boutons[1]:IsShown(), false)
attendu("Generale ouverte", f.etape, "generale")
attendu("Traits masque sans nouveau point", f.barre.boutons[#f.barre.boutons]:IsShown(), false)

local generale = f.pages.generale
local gains = {}
for _, ligne in ipairs(generale.gains) do
    if ligne:IsShown() then gains[ligne.categorie] = C.Budget(f.brouillon, ligne.categorie).total end
end
attendu("trois statistiques gagnees", gains.primaires, 3)
attendu("quatre secondaires gagnees", gains.secondaires, 4)
attendu("deux expertises gagnees", gains.expertises, 2)
attendu("trois mecaniques gagnees", gains.mecaniques, 3)
attendu("aucun ancien point dans le budget", C.Budget(f.brouillon, "primaires").depense, 0)

local function depenser(brouillon, categorie)
    local garde = 0
    while C.Budget(brouillon, categorie).reste > 0 and garde < 500 do
        garde = garde + 1
        local avance = false
        if categorie == "traits" then
            for _, trait in ipairs(LCM.Traits.list) do
                if not C.ATrait(brouillon, trait.id) then
                    local ok = C.AjouterTrait(brouillon, trait.id)
                    if ok then avance = true break end
                end
            end
        else
            for _, ligne in ipairs(C.Lignes(categorie)) do
                local id = ligne.id or ligne
                local ok = C.Definir(brouillon, categorie, id, C.Valeur(brouillon, id) + 1)
                if ok then avance = true break end
            end
        end
        if not avance then break end
    end
end

local function finirNiveau()
    for _, categorie in ipairs(C.CATEGORIES) do depenser(f.brouillon, categorie) end
    -- Les secondaires peuvent ouvrir de nouveaux budgets : un second passage
    -- ramasse les dependances devenues disponibles.
    for _, categorie in ipairs(C.CATEGORIES) do depenser(f.brouillon, categorie) end
    attendu("niveau sans probleme", #C.Problemes(f.brouillon), 0)
    f.valider:Click()
end

finirNiveau()
attendu("un seul niveau valide", LCM.Entities.Get_Value(moi, "niveau"), 6)
attendu("trois restent", X.NiveauxEnAttente(moi), 3)
attendu("la fenetre enchaine 6 vers 7", f.brouillon.niveauAvant .. " -> " .. f.brouillon.niveau, "6 -> 7")
attendu("la limite est celle du niveau 7", C.Plafond(f.brouillon, "primaires", "force"), 11)

finirNiveau()
attendu("deuxieme validation niveau 7", LCM.Entities.Get_Value(moi, "niveau"), 7)
finirNiveau()
attendu("troisieme validation niveau 8", LCM.Entities.Get_Value(moi, "niveau"), 8)
finirNiveau()
attendu("quatrieme validation niveau 9", LCM.Entities.Get_Value(moi, "niveau"), 9)
attendu("file vide", X.NiveauxEnAttente(moi), 0)
attendu("fenetre fermee", f:IsShown(), false)
attendu("entree retiree du menu", visible(LCM.UI.Menu.Trouver("fiches_personnages").enfants, "montee_niveau"), nil)
attendu("badge Personnage retire", personnage.badge:IsShown(), false)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
