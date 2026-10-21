-- Types d'outils, bonus de métier et prérequis de coffre.
local ko = 0
local function attendu(nom, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    print((ok and "  ok  " or "  KO  ") .. nom .. " = " .. tostring(obtenu)
        .. (ok and "" or " (attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
local personnage = LCM.Entities.Self()
__groupe({ LCM.PlayerId(), "Temoin-Apertus" })
__position(100, 200, 0)
LCM.DeplacementForce.NoterGPS("100.000000 200.000000 0.000000 585 0.000000")
local typesAvant = #LCM.Listes.De("outils")
local outilsAvant = #LCM.Compendium.Entrees(LCM.Compendium.Get("outils"))

LCM.Listes.Add({ id = "serrurerie_temoin", liste = "outils", label = "Serrurerie" })
LCM.Listes.Add({ id = "autre_liste_temoin", liste = "armes", label = "Autre liste" })
local mauvaisType = pcall(LCM.Points.Construire, { id = "coffre_mauvais_type",
    nature = "coffre", coffre = { expertises = { { id = "vue", dd = 10 } },
        outils = { { typeOutil = "autre_liste_temoin", expertise = "vue" } } } })
attendu("une entrée d'une autre liste reste refusée", mauvaisType, false)
-- Un type d'outil SUPPRIME depuis ne fait plus tomber le coffre : sa ligne
-- est laissee de cote, et on le dit. « Cassier fermé. » disparaissait du jeu
-- pour ses deux types d'outil effaces (21 octobre 2026). La saisie fausse
-- ci-dessus, elle, reste refusee.
local okDisparu, coffreDisparu = pcall(LCM.Points.Construire, { id = "coffre_type_disparu",
    nature = "coffre", coffre = { verrous = 1, expertises = { { id = "vue", dd = 10 } },
        outils = { { typeOutil = "type_efface_temoin", expertise = "vue" },
                   { typeOutil = "serrurerie_temoin", expertise = "vue" } } } })
attendu("un type supprimé ne fait pas tomber le coffre", okDisparu, true)
attendu("  sa ligne est laissée de côté", okDisparu and #coffreDisparu.coffre.outils, 1)
attendu("  l'autre reste", okDisparu and coffreDisparu.coffre.outils[1].typeOutil, "serrurerie_temoin")
local ditLaisse = false
for _, l in ipairs(__sorties) do if l:find("type_efface_temoin", 1, true) then ditLaisse = true end end
attendu("  et on le dit", ditLaisse, true)
LCM.Listes.Retirer("autre_liste_temoin")
attendu("liste de types visible", LCM.Compendium.Get("liste_outils") ~= nil, true)
attendu("type d'outil proposé", #LCM.Listes.De("outils"), typesAvant + 1)
local outil = LCM.Objets.Add({ id = "outil_serrure_temoin", label = "Crochet témoin",
    categorie = "outil", type = "serrurerie_temoin", etat = { courant = 10, max = 10 },
    bonus = { ["metier:mineur"] = 3 } })
LCM.Objets.Add({ id = "outil_serrure_secours", label = "Crochet de secours",
    categorie = "outil", type = "serrurerie_temoin", etat = { courant = 10, max = 10 } })
attendu("outil accepté par le registre", outil.categorie, "outil")
attendu("outil classé dans le compendium", #LCM.Compendium.Entrees(LCM.Compendium.Get("outils")), outilsAvant + 2)
local metierForge
for _, champ in ipairs(LCM.Forge.Statistiques(LCM.Compendium.Get("outils"))) do
    if champ.cle == "metier:mineur" then metierForge = champ break end
end
attendu("métier réglable dans la forge", metierForge and metierForge.dossier, "Métiers")
attendu("forge d'outil disponible", LCM.UI.Forge.EstCategorie(LCM.Compendium.Get("outils")), true)
attendu("la forge reprend la Liste outils", LCM.UI.Forge.ListeDuType(LCM.Compendium.Get("outils")), "outils")
local jeu = LCM.Forge.Add({ id = "jeu_outils_temoin", label = "Équilibrage des outils",
    categorie = "outils", raretes = { { id = "rare", label = "Rare", points = 10,
        couleur = "4D8CFF" } },
    champs = { ["metier:mineur"] = { min = 0, base = 0, max = 5, cout = 2 } } })
attendu("coût de métier réglable par un jeu", LCM.Forge.Limites(jeu, "metier:mineur", "rare").cout, 2)
attendu("emplacement d'outil disponible", LCM.Objets.Emplacements("outil"), 1)
attendu("équipement de l'outil", LCM.Objets.Placer(personnage, outil.id), true)
attendu("chaque point ajoute un au jet de métier", LCM.Metiers.Bonus(personnage, "mineur"), 3)

local ref = "objets/outil_serrure_temoin"
local secours = "objets/outil_serrure_secours"
local requis = { { entree = ref, quantite = 1 },
    { typeOutil = "serrurerie_temoin", quantite = 1, consomme = true, consommeQuantite = 1 } }
local concret, manquant = LCM.UI.Coffre.ResoudreOutils(personnage, requis)
attendu("un exemplaire ne satisfait pas deux prérequis", concret, nil)
attendu("le type manquant est nommé", manquant, "Serrurerie")
attendu("second outil rangé", LCM.Inventaire.Deposer(personnage, secours, 1), true)
concret = LCM.UI.Coffre.ResoudreOutils(personnage, requis)
attendu("deux prérequis satisfaits", #concret, 2)
attendu("l'outil précis est réservé d'abord", concret[1].entree, ref)
attendu("le type choisit l'autre outil", concret[2].entree, secours)
attendu("la consommation cible l'outil utilisé", concret[2].consommeQuantite, 1)

local definition = { id = "coffre_outils_temoin", label = "Coffre à outils",
    nature = "coffre", coffre = { places = 1, rayon = 4, verrous = 1,
        objets = {}, expertises = { { id = "vue", dd = 10, fatigue = 0 } },
        outils = { { typeOutil = "serrurerie_temoin", expertise = "vue", quantite = 1,
            consomme = false, consommeQuantite = 1 } } } }
local ok, raison = LCM.Brouillons.Enregistrer("points", definition, true)
attendu("type d'outil enregistré sur le coffre", ok, true)
if not ok then print(tostring(raison)) end
local editeur = LCM.UI.CoffresMJ.Fenetre()
editeur:Choisir(definition.id)
attendu("type visible dans l'éditeur de coffre", editeur.lignesOutils[1].nom.label:GetText(),
    "Type : Serrurerie")
editeur.depotOutils:Click()
local typePropose = false
for _, ligne in ipairs(editeur.choixOutil.lignes) do
    if ligne:IsShown() and ligne.choix == "type_outil/serrurerie_temoin" then typePropose = true end
end
attendu("type proposé dans le sélecteur d'outils", typePropose, true)
editeur.travail.coffre.outils = {}
editeur:Ajouter("outils", "type_outil/serrurerie_temoin")
attendu("sélectionner un type n'ajoute pas d'objet précis",
    editeur.travail.coffre.outils[1].entree, nil)
local coffreSaisi, refusSaisie = editeur:Valider()
attendu("le coffre saisi dans la fenêtre est valide", coffreSaisi ~= nil, true)
if not coffreSaisi then print(tostring(refusSaisie)) end
attendu("le type reste sans référence d'objet après validation",
    coffreSaisi and coffreSaisi.outils[1].entree, nil)
attendu("la fenêtre MJ peut enregistrer ce type", editeur:Enregistrer(), true)
local id = LCM.CoffresMJ.Placer(definition.id)
attendu("coffre à type posé", id ~= nil, true)
local paquet = LCM.Coffres.Paquet(LCM.Points.Get(definition.id), LCM.CoffresMJ.Points(definition.id))
local recu = LCM.Coffres.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)))
attendu("type transmis au joueur", recu.coffre.outils[1].typeOutil, "serrurerie_temoin")

if ko == 0 then print("TOUT PASSE") else error(ko .. " échec(s)") end

