-- Les panneaux d'affichage (31 octobre 2026) : un support, des affiches
-- (titre, texte, image), poses dans le monde par le MJ et lus par qui passe
-- devant.
--
-- Ce qu'on verifie :
--   * un panneau refuse ce qui ne tient pas (sans titre, trop d'affiches,
--     support inconnu) — et dit pourquoi ;
--   * l'atelier construit un panneau de bout en bout, le pose, le retire ;
--   * devant le panneau, « Lire » apparait ; loin, il disparait ;
--   * le panneau s'ouvre et ses affiches se lisent ;
--   * ce qui part aux joueurs se relit a l'identique (paquet reseau) ;
--   * l'entree Affichage du radial est liee.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM.db.settings.modeJoueur = nil
LCM._masterCompanion = true

local A, AMJ = LCM.Affichages, LCM.AffichagesMJ

dire("== un panneau refuse ce qui ne tient pas")
local function Refus(affichage)
    local ok, raison = pcall(LCM.Points.Construire, { id = "panneau_refus", label = "Refus",
        nature = "affichage", affichage = affichage })
    return ok and "accepte" or tostring(raison)
end
attendu("une affiche sans titre", Refus({ affiches = { { titre = "", texte = "x" } } }):find("pas de titre", 1, true) ~= nil, true)
local trop = {}
for i = 1, (LCM.Equilibrage.affichages.maxAffiches + 1) do trop[i] = { titre = "A" .. i } end
attendu("trop d'affiches", Refus({ affiches = trop }):find("au plus", 1, true) ~= nil, true)
attendu("un support inconnu", Refus({ support = "marbre", affiches = {} }):find("support", 1, true) ~= nil, true)
attendu("un panneau vide est permis", Refus({ affiches = {} }), "accepte")

-- Une carte temoin, pour la punaiser sur une affiche (31 octobre 2026).
local ZG = LCM.Crossings
__position(0, 0, 0)
local marais = ZG:CreateZone("Marais Gris")
local tour = ZG:CreatePlace(marais.id, "Tour noyée")
LCM.Cartes.Add({ id = "carte_marais", label = "Carte du marais",
    regions = { { id = marais.id, nom = marais.name } }, lieux = { { id = tour.id, nom = tour.name } } })
attendu("un lien vers une carte disparue ne fait pas tomber le panneau",
    Refus({ affiches = { { titre = "Vieille carte", carte = "carte_supprimee" } } }), "accepte")

dire("== l'atelier construit un panneau")
attendu("l'entree Affichage du radial est liee", LCM.UI.Menu.EstLiee("affichage"), true)
LCM.UI.Menu.Trouver("affichage").onClick()
local f = LCM.UI.AffichagesMJ.frame
attendu("l'atelier s'ouvre", f and f:IsShown(), true)
attendu("dans le cadre commun des ateliers", f.compteModeles ~= nil, true)
f:Nouveau()
f.creation.nom:Saisir("Tableau de la milice")
f.creation.edition.titre:Saisir("Avis de recherche")
f.creation.edition.texte.saisie:Saisir("Recherché : le voleur de poules.")
attendu("le texte saisi va dans l'affiche", f.travail.affichage.affiches[1].texte, "Recherché : le voleur de poules.")
-- L'image vient du selecteur d'icones du Kit ; on la pose comme il le ferait.
f.travail.affichage.affiches[1].image = "INV_Misc_Note_01"
f:AjouterAffiche()
f.creation.edition.titre:Saisir("Couvre-feu")
attendu("deux affiches", #f.travail.affichage.affiches, 2)
f.creation.edition.carte.choisir("carte_marais")
attendu("une affiche porte une carte", f.travail.affichage.affiches[2].carte, "carte_marais")
f.creation.enregistrer:Click()
local panneau
for _, p in ipairs(AMJ.Definitions()) do if p.label == "Tableau de la milice" then panneau = p end end
attendu("le panneau est enregistre", panneau ~= nil, true)
attendu("avec ses affiches", panneau and #panneau.affichage.affiches, 2)
attendu("et son support bois", panneau and panneau.affichage.support, "bois")

dire("== le poser, et le lire en passant devant")
__position(100, 100, 10)
f:Onglet("placement")
f.placement.poser:Click()
attendu("un emplacement", AMJ.Compte(panneau.id), 1)
attendu("le MJ le connait aussi en joueur", next(A.points) ~= nil, true)
__avancer(0.5)
local bouton = LCM.UI.Affichage.bouton
attendu("devant : « Lire » apparait", bouton and bouton:IsShown(), true)
attendu("avec le nom du panneau", bouton and bouton.nom:GetText(), "Tableau de la milice")
bouton:Click()
local fen = LCM.UI.Affichage.frame
attendu("le panneau s'ouvre", fen and fen:IsShown(), true)
-- « Panneau », tout court : le nom du modele reste dans l'atelier du MJ
-- (31 octobre 2026 ; avant, le titre reprenait ce nom).
attendu("titre de la fenetre", fen and __sansCouleur(fen.titre:GetText()), "PANNEAU")
local visibles = 0
for _, feuille in ipairs(fen.feuilles) do if feuille:IsShown() then visibles = visibles + 1 end end
attendu("deux affiches punaisees", visibles, 2)
fen.feuilles[1]:Click()
attendu("une affiche se lit", fen.lecture:IsShown(), true)
attendu("son titre", fen.lecture.titre:GetText(), "Avis de recherche")
attendu("son texte", fen.lecture.corps:GetText(), "Recherché : le voleur de poules.")
attendu("une affiche sans carte n'a pas de lien de carte", fen.lecture.lien:IsShown(), false)
fen.lecture.retour:Click()
attendu("retour au panneau", fen.lecture:IsShown(), false)
fen.feuilles[2]:Click()
-- La carte d'une affiche se montre comme un LIEN (le MJ, 31 octobre 2026) :
-- un clic la consulte ; « Arracher la carte » la met dans l'inventaire.
attendu("l'affiche montre le lien de sa carte", fen.lecture.lien:IsShown(), true)
attendu("pas encore rature", fen.lecture.lien.rature:IsShown(), false)
attendu("sous son nom, entre crochets", fen.lecture.lien.texte:GetText(), "[Carte du marais]")
-- Le MJ voit tout (31 octobre 2026) : ce qu'on APPREND se verifie en joueur.
LCM.db.settings.modeJoueur = true
attendu("avant : le marais est inconnu du joueur", ZG:HasLearnedZoneName(marais.id), false)
fen.lecture.lien:Click()
attendu("consulter ouvre la carte", LCMCrossingsRegionMap:IsShown() and LCMCrossingsRegionMap.carte ~= nil, true)
attendu("et apprend ce qu'elle devoile", ZG:HasLearnedZoneName(marais.id) and ZG:KnowsPlaceName(tour), true)
LCM.db.settings.modeJoueur = nil
LCMCrossingsRegionMap:Hide()
local moi = LCM.Entities.Self()
attendu("avant : la carte n'est pas dans l'inventaire", LCM.Inventaire.Chercher(moi, "cartes/carte_marais") ~= nil, false)
fen.lecture.arracher:Click()
attendu("arracher la met dans l'inventaire", LCM.Inventaire.Chercher(moi, "cartes/carte_marais") ~= nil, true)
attendu("une seule fois par personnage", fen.lecture.arracher:IsEnabled(), false)
-- Arrachee, la carte n'est plus au panneau : son lien se rature et ne se
-- clique plus (le MJ, 31 octobre 2026).
attendu("le lien se rature", fen.lecture.lien.rature:IsShown(), true)
attendu("et ne se clique plus", fen.lecture.lien:IsMouseEnabled(), false)
local deux, pourquoi = LCM.Affichages.Arracher(fen.pointId, fen.definition, 2)
attendu("une seconde fois : refuse", deux, false)
attendu("et le dit", pourquoi, "tu as déjà arraché cette carte.")
fen.lecture.retour:Click()
fen:Hide()

__position(300, 300, 10)
__avancer(0.5)
attendu("loin : « Lire » disparait", bouton:IsShown(), false)

dire("== ce qui part aux joueurs se relit a l'identique")
local paquet = A.Paquet({ id = panneau.id, label = panneau.label, support = panneau.affichage.support,
    affiches = panneau.affichage.affiches }, AMJ.Points(panneau.id))
local recu, points = A.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)))
attendu("le panneau arrive", recu and recu.label, "Tableau de la milice")
attendu("ses affiches", recu and #recu.affiches, 2)
attendu("leur image", recu and recu.affiches[1].image, "INV_Misc_Note_01")
-- Les cartes sont reservees au MJ : le joueur n'a que celle qui arrive avec
-- le panneau, et la lit sans qu'elle entre dans son registre.
attendu("la carte de l'affiche voyage avec le panneau", recu and recu.affiches[2].carteDef ~= nil, true)
attendu("sous son identifiant", recu and recu.affiches[2].carte, "carte_marais")
attendu("et se lit depuis sa definition", LCM.UI.Cartes.Ouvrir(nil, recu.affiches[2].carteDef), true)
LCMCrossingsRegionMap:Hide()
attendu("ses emplacements", points and #points, 1)

dire("== retirer")
f:Onglet("placement")
AMJ.RetirerTout(panneau.id)
attendu("plus d'emplacement", AMJ.Compte(panneau.id), 0)
attendu("le joueur l'oublie aussi", next(A.points), nil)

dire("== themes et ecritures")
attendu("six panneaux", #A.Supports(), 6)
attendu("six fonds d'affiches", #A.Themes(), 6)
attendu("six ecritures", #A.Polices(), 6)
attendu("ancien support migre", A.Normaliser({ support = "provisoire" }, error).support, "bois")
attendu("un theme inconnu refuse", Refus({ affiches = { { titre = "Test", theme = "absent" } } }):find("thème", 1, true) ~= nil, true)
attendu("une police inconnue refuse", Refus({ affiches = { { titre = "Test", police = "absente" } } }):find("écriture", 1, true) ~= nil, true)
for _, support in ipairs(A.Supports()) do
    for _, theme in ipairs(A.Themes()) do
        for _, police in ipairs(A.Polices()) do
            local d = { id = "test_style", label = "Styles", support = support.id,
                affiches = { { titre = "Écriture à l'essai", texte = "À bientôt, cœur fidèle.", theme = theme.id, police = police.id } } }
            local lu = A.Lire(A.Paquet(d, {}))
            assert(lu and lu.support == support.id and lu.affiches[1].theme == theme.id and lu.affiches[1].police == police.id)
            LCM.UI.Affichage.Ouvrir(nil, lu)
            fen:Lire(1)
            assert(fen.lecture.fond:GetTexture() == theme.texture)
            assert(fen.lecture.corps:GetFont() == police.chemin)
        end
    end
end
attendu("216 combinaisons transmises et lues", true, true)
f:Nouveau()
f.creation.edition.theme.choisir("numerique")
f.creation.edition.police.choisir("machine")
attendu("choix du fond dans l'atelier", f:Affiche().theme, "numerique")
attendu("choix de l'ecriture dans l'atelier", f:Affiche().police, "machine")
f.creation.edition.police.choisir("auto")
local auto = A.Normaliser(f.travail.affichage, error).affiches[1]
attendu("ecriture automatique conservee", auto.police, nil)
LCM.UI.Affichage.Ouvrir(nil, { label = "Terminal", support = "numerique", affiches = { auto } })
fen:Lire(1)
attendu("theme numerique choisit sa police futuriste", fen.lecture.corps:GetFont(), A.Police("numerique").chemin)
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
