-- Dupliquer un preset (15 octobre 2026) : coffre, point de recolte, vendeur.
-- La copie s'ouvre comme une creation neuve, sous un nouvel identifiant, et
-- n'existe qu'une fois enregistree. L'original ne doit pas bouger, ni ses
-- exemplaires poses, et un vendeur copie a son propre stock.
-- Le meme jour, le vendeur a perdu sa publication en sort Arcanum : l'etal
-- pose au GPS l'a remplacee. Une copie ne garde donc aucun `arcId`.
--
-- Contenu TEMOIN uniquement.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

local HERBE = "ressources/herbe_temoin"
LCM.Brouillons.Set("ressources", { id = "herbe_temoin", label = "Herbe témoin" })
LCM.Brouillons.Set("devises", { id = "piece_temoin", label = "Pièce témoin" })
LCM.Objets.Add({ id = "cle_temoin", label = "Clé témoin", categorie = "accessoire",
    icone = "inv_misc_key_01", etat = { courant = 1, max = 1 }, pileMax = 1 })
LCM.Brouillons.Set("points", { id = "coffre_temoin", label = "Coffre témoin", nature = "coffre",
    coffre = { places = 4, rayon = 5, verrous = 0, reset = false,
        objets = { { entree = "objets/cle_temoin", quantite = 1 } }, expertises = {}, outils = {} } })
LCM.Brouillons.Set("points", { id = "filon_temoin", label = "Filon témoin", nature = "ressource",
    offres = {}, recolte = { dd = 0, rayon = 3, limite = 1, metiers = {},
        ressources = { { entree = HERBE, min = 1, max = 3, aleatoire = true, chance = 100 } } } })
LCM.Brouillons.Set("points", {
    -- Un `arcId` hérité d'avant le 15 octobre : la copie ne doit pas le garder.
    id = "etal_temoin", label = "Étal témoin", nature = "vendeur", deviseDefaut = "piece_temoin",
    arcId = "vendeur_ancien",
    onglets = { { id = "o1", label = "Articles", offres = {
        { id = "herbe", entree = HERBE, quantite = 1, prix = 3, devise = "piece_temoin",
          stock = { limite = 2, unites = 0, minutes = 0 } },
    } } },
    rachats = { { id = "r1", label = "Rachats", offres = {} } },
})

__declencher("PLAYER_LOGIN")
__personnage()
__position(10, 10, 0)

local UI = LCM.UI
for _, cas in ipairs({ { UI.CoffresMJ, "coffre_temoin" }, { UI.Recoltes, "filon_temoin" } }) do
    local f = cas[1].Fenetre()
    f:Montrer()
    f:Choisir(cas[2])
    local c = f.creation
    attendu("formulaire initial non modifie", f:Modifie(), false)
    c.pages.boutons[2]:Click()
    attendu("page de regles ouverte", c.pages[2]:IsShown(), true)
    attendu("contenu masque", c.pages[1]:IsShown(), false)
    c.nom:Saisir("Brouillon conserve")
    attendu("modification detectee", f:Modifie(), true)
    f.recherche:Saisir("aucun-resultat-unique")
    attendu("recherche sans resultat", f.listeVide:IsShown(), true)
    attendu("rechercher conserve la saisie", f.travail.label, "Brouillon conserve")
    f.recherche:Saisir("témoin")
    attendu("recherche retrouve les modeles", f.listeVide:IsShown(), false)
    f.nouveau:Click()
    attendu("nouveau demande avant de perdre le travail", f.confirmation:IsShown(), true)
    f.confirmation.non:Click()
    attendu("annuler conserve la saisie", f.travail.label, "Brouillon conserve")
    f:Onglet("placement")
    -- Deux facons de ne jamais poser une ancienne version : griser le bouton
    -- (les points de recolte), ou ENREGISTRER avant de poser (les coffres,
    -- depuis 6c95453, 16 octobre 2026). Ce scenario n'attendait que la
    -- premiere ; on verifie maintenant le resultat, quel que soit le chemin.
    if f.placement.poser:IsEnabled() then
        f.placement.poser:Click()
        attendu("placer enregistre d'abord : pas d'ancienne version", f:Modifie(), false)
        attendu("  le modele porte la saisie", f:Point() and f:Point().label, "Brouillon conserve")
    else
        attendu("pas de placement d'une ancienne version", f.placement.poser:IsEnabled(), false)
    end
    f:Onglet("creation")
    f.nouveau:Click()
    -- Rien a perdre apres un enregistrement : pas de question.
    if f.confirmation:IsShown() then f.confirmation.oui:Click() end
    attendu("confirmer cree un modele vierge", f.travail.label, "")
    attendu("hauteur constante", f:GetHeight(), 640)
    attendu("habillage compact", f.decor, nil)
end
if ko > 0 then error(ko .. " ECHEC(S)") end
dire("TOUT PASSE")
