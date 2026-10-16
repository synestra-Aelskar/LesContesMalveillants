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
local Points = LCM.Points
local function Combien(nature)
    return #Points.Nature(nature)
end

dire("== le registre : une copie, pas un alias")
local original = Points.Get("etal_temoin")
local copie = Points.Dupliquer(original)
attendu("nouvel identifiant", copie.id ~= original.id, true)
attendu("nom marqué « (copie) »", copie.label, "Étal témoin (copie)")
attendu("plus d'identifiant Arcanum", copie.arcId, nil)
attendu("clé de stock effacée", copie.onglets[1].offres[1].cle, nil)
-- Le prix construit est une liste de facons de payer (16 octobre 2026).
copie.onglets[1].offres[1].formules[1][1].quantite = 99
attendu("l'original ne partage pas ses tables", original.onglets[1].offres[1].formules[1][1].quantite, 3)

dire("== Coffres")
LCM.UI.CoffresMJ.Basculer()
local fc = LCM.UI.CoffresMJ.frame
fc:Choisir("coffre_temoin")
local avant = Combien("coffre")
fc.dupliquer:Click()
attendu("la copie s'ouvre en création", fc.creation:IsShown(), true)
attendu("  sous le nom proposé", fc.nom:GetText(), "Coffre témoin (copie)")
attendu("  avec le contenu de l'original", fc.travail.coffre.objets[1].entree, "objets/cle_temoin")
attendu("  sans rien enregistrer encore", Combien("coffre"), avant)
fc.nom:Saisir("Coffre jumeau")
fc.enregistrer:Click()
attendu("enregistrée : un coffre de plus", Combien("coffre"), avant + 1)
local jumeau = fc:Point()
attendu("la copie est sélectionnée", jumeau and jumeau.label, "Coffre jumeau")
attendu("  avec ses quatre emplacements", jumeau and jumeau.coffre.places, 4)
attendu("l'original est intact", Points.Get("coffre_temoin").label, "Coffre témoin")
LCM.CoffresMJ.Placer("coffre_temoin")
fc:Choisir("coffre_temoin")
fc.dupliquer:Click()
fc.nom:Saisir("Coffre triple")
fc.enregistrer:Click()
attendu("un coffre posé reste à l'original", #LCM.CoffresMJ.Points("coffre_temoin"), 1)
attendu("  la copie n'en hérite pas", #LCM.CoffresMJ.Points(fc:Point().id), 0)
fc:Choisir(nil)
fc.dupliquer:Click()
attendu("sans sélection, rien n'est copié", Combien("coffre"), avant + 2)

dire("== Ressources")
LCM.UI.Recoltes.Basculer()
local fr = LCM.UI.Recoltes.frame
fr:Choisir("filon_temoin")
avant = Combien("ressource")
fr.dupliquer:Click()
attendu("la copie s'ouvre en création", fr.creation:IsShown(), true)
attendu("  sous le nom proposé", fr.creation.nom:GetText(), "Filon témoin (copie)")
attendu("  sans rien enregistrer encore", Combien("ressource"), avant)
fr.creation.nom:Saisir("Filon jumeau")
fr.creation.enregistrer:Click()
attendu("enregistrée : un point de plus", Combien("ressource"), avant + 1)
local filon = fr:Point()
attendu("la copie est sélectionnée", filon and filon.label, "Filon jumeau")
attendu("  avec la ressource de l'original", filon and filon.recolte.ressources[1].entree, HERBE)
attendu("  et sa quantité maximale", filon and filon.recolte.ressources[1].max, 3)
attendu("l'original est intact", Points.Get("filon_temoin").label, "Filon témoin")

dire("== Vendeur : la copie passe par le constructeur")
LCM.UI.MarchandsMJ.Basculer()
local fv = LCM.UI.MarchandsMJ.frame
fv:Choisir("etal_temoin")
avant = Combien("vendeur")
fv.dupliquer:Click()
local ed = LCM.UI.Points.Editeur("vendeur")
attendu("le constructeur s'ouvre", ed:IsShown(), true)
attendu("  sur une création neuve", ed.creation, true)
attendu("  sous un nouvel identifiant", ed.travail.id ~= "etal_temoin", true)
attendu("  avec les articles de l'original", ed.travail.onglets[1].offres[1].entree, HERBE)
attendu("  sans rien enregistrer encore", Combien("vendeur"), avant)
attendu("plus de champ Arcanum dans le constructeur", ed.arcId, nil)
ed.nom:Saisir("Étal jumeau")
attendu("enregistrer suffit, sans publication", ed:Sauver(false), true)
attendu("le constructeur se referme", ed:IsShown(), false)
attendu("un vendeur de plus", Combien("vendeur"), avant + 1)
local etal = Points.Get(ed.travail.id)
attendu("la copie porte son nom", etal and etal.label, "Étal jumeau")
attendu("  et son propre stock", etal and etal.onglets[1].offres[1].cle, ed.travail.id .. "/herbe")
attendu("  sans identifiant Arcanum", etal and etal.arcId, nil)
attendu("l'original est intact", Points.Get("etal_temoin").label, "Étal témoin")
attendu("  son stock aussi", Points.Get("etal_temoin").onglets[1].offres[1].cle, "etal_temoin/herbe")

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
