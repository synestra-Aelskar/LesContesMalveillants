-- Coffres : contenu persistant, capacite, prises concurrentes et verrous.

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
local MOI = LCM.PlayerId()
__groupe({ MOI, "Syn-Apertus", "Claydenn-Apertus" })
__position(100, 200, 0)

local REF, REF2 = "objets/cle_temoin", "objets/outil_temoin"
LCM.Objets.Add({ id = "cle_temoin", label = "Clé témoin", categorie = "accessoire",
    icone = "inv_misc_key_01", etat = { courant = 1, max = 1 }, pileMax = 1 })
LCM.Objets.Add({ id = "outil_temoin", label = "Outil témoin", categorie = "accessoire",
    icone = "inv_misc_gear_01", etat = { courant = 1, max = 1 }, pileMax = 1 })
local definition = { id = "coffre_temoin", label = "Coffre témoin", nature = "coffre",
    coffre = { places = 1, rayon = 7, verrous = 1, reset = false,
        objets = { { entree = REF, quantite = 1 } },
        expertises = { { id = "vue", dd = 8, reverrouillable = true } },
        outils = { { entree = REF2, quantite = 1, consomme = true, consommeQuantite = 1 } } } }
local sauvegarde, erreur = LCM.Brouillons.Enregistrer("points", definition, true)
attendu("définition enregistrée", sauvegarde, true)
if not sauvegarde then dire("raison de l'erreur :", tostring(erreur)) end

local id, raison = LCM.CoffresMJ.Placer("coffre_temoin")
attendu("coffre posé", id ~= nil, true)
if not id then dire("raison du refus :", tostring(raison)) end
local C, MJ = LCM.Coffres, LCM.CoffresMJ
local p = MJ.Points("coffre_temoin")[1]
attendu("stock initial", p and p.objets[1] and p.objets[1].quantite, 1)
attendu("configuration connue côté client", C.definitions.coffre_temoin ~= nil, true)

dire("== ouvrir, déverrouiller, puis reverrouiller selon la méthode")
C.Ouvrir(id)
attendu("coffre encore verrouillé", p.verrouille, true)
local ok = C.Envoyer("forcer", { expertise = "vue", total = 8 })
attendu("expertise autorisée", ok, true)
attendu("verrou ouvert", p.verrouille, false)
attendu("ouverture conservée", p.ouvert, true)
C.Envoyer("verrouiller")
attendu("verrou replacé", p.verrouille, true)
attendu("compteur restauré", p.verrousRestants, 1)
C.Envoyer("forcer", { expertise = "vue", total = 8 })
attendu("nouveau déverrouillage", p.ouvert, true)
local coffreUI = LCM.UI.Coffre.frame
attendu("le nom du coffre remplace le titre générique", coffreUI.titre:GetText(), "COFFRE TÉMOIN")
attendu("le contenu est présenté en grille", coffreUI.cases[1] and coffreUI.cases[1].pile.ref, REF)
coffreUI.cases[1]:GetScript("OnEnter")(coffreUI.cases[1])
attendu("la carte apparaît au survol", LCM.UI.Coffre.carteSurvol:IsShown(), true)
coffreUI.cases[1]:GetScript("OnLeave")(coffreUI.cases[1])
coffreUI.cases[1]:GetScript("OnClick")(coffreUI.cases[1], "RightButton")
attendu("le clic droit propose Prendre", LCM.UI.menuContexte.lignes[1].texte:GetText(), "Prendre")
attendu("le clic droit propose Voir", LCM.UI.menuContexte.lignes[2].texte:GetText(), "Voir")
LCM.UI.menuContexte:Hide()
p.verrousOuverts, C.etat.vo = { false }, { false }
C.onChange()
attendu("un verrou brisé est signalé", coffreUI.verrousBrises:GetText(), "1 verrou brisé.")
p.verrousOuverts, C.etat.vo = { true }, { true }
C.onChange()

dire("== stock non renouvelable et capacité en emplacements")
C.Envoyer("prendre", { e = REF, q = 1 })
attendu("le contenu est épuisé", #p.objets, 0)
C.Envoyer("prendre", { e = REF, q = 1 })
attendu("une prise après épuisement reste refusée", #p.objets, 0)
C.Envoyer("ranger", { e = REF, q = 1 })
attendu("retour au coffre accepté", p.objets[1] and p.objets[1].quantite, 1)
C.Envoyer("ranger", { e = REF2, q = 1 })
attendu("un deuxième type dépasse la capacité", #p.objets, 1)
attendu("le refus ne modifie pas le contenu", p.objets[1] and p.objets[1].entree, REF)

dire("== le paquet transporte les outils et les expertises")
local paquet = C.Paquet(C.definitions.coffre_temoin, { p })
paquet = LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet))
local def, points = C.Lire(paquet)
attendu("quantité d'outil", def.coffre.outils[1].quantite, 1)
attendu("consommation configurée", def.coffre.outils[1].consomme, true)
attendu("consommation paramétrée", def.coffre.outils[1].consommeQuantite, 1)
attendu("DD transmis", def.coffre.expertises[1].dd, 8)
attendu("réglage reverrouillable transmis", def.coffre.expertises[1].reverrouillable, true)
attendu("rayon transmis", def.coffre.rayon, 7)
attendu("emplacement conservé", points[1].id, id)
attendu("coffre visible dans son rayon", C.Proche({ [p.source] = { x = p.x + 6, y = p.y } }).id, id)
attendu("coffre invisible hors de son rayon", C.Proche({ [p.source] = { x = p.x + 8, y = p.y } }), nil)
C.definitions.coffre_temoin.coffre.reset = true
LCM.Points.Get("coffre_temoin").coffre.reset = true
C.Envoyer("fermer")
attendu("fermeture et reset auto replacent les verrous", p.verrouille, true)
attendu("le coffre est fermé", p.ouvert, false)

dire("== constructeur MJ et réglages multiples")
LCM.UI.Recoltes.Basculer()
local ressources = LCM.UI.Recoltes.frame
attendu("le constructeur n'est plus enfoui dans Ressources", ressources.boutonCoffres, nil)
attendu("entrée Coffres liée dans le radial", LCM.UI.Menu.EstLiee("coffres"), true)
SlashCmdList.LCM("coffres")
local editeur = LCM.UI.CoffresMJ.frame
attendu("/lcm coffres ouvre la fenêtre de gestion", editeur and editeur:IsShown(), true)
editeur:Nouveau()
editeur.nom:Saisir("Brouillon de coffre")
attendu("onglet Création visible", editeur.creation:IsShown(), true)
attendu("onglet Placement caché", editeur.placement:IsShown(), false)
local function ChoisirDans(popup, id)
    for _, ligne in ipairs(popup.lignes) do
        if ligne:IsShown() and ligne.choix == id then ligne:Click(); return true end
    end
    return false
end
editeur.depotObjets:Click()
attendu("la liste d'objets propose le contenu", ChoisirDans(editeur.choixObjet, REF), true)
editeur.depotOutils:Click()
attendu("la liste d'objets propose l'outil", ChoisirDans(editeur.choixOutil, REF2), true)
editeur.ajouterExpertise:Click()
attendu("la liste propose une expertise", ChoisirDans(editeur.choixExpertise, "vue"), true)
attendu("ligne de contenu créée", editeur.lignesObjets[1] and editeur.lignesObjets[1]:IsShown(), true)
attendu("case de consommation affichée", editeur.lignesOutils[1].consommer:IsShown(), true)
attendu("champ de quantité consommée affiché", editeur.lignesOutils[1].nc:IsShown(), false)
editeur.lignesOutils[1].consommer:Click()
attendu("le champ apparaît quand la consommation est activée", editeur.lignesOutils[1].nc:IsShown(), true)
attendu("expertise ajoutée", editeur.lignesExpertises[1] and editeur.lignesExpertises[1]:IsShown(), true)
editeur:Choisir("coffre_temoin")
attendu("rayon affiché dans le constructeur", editeur.rayon:GetText(), "7")
editeur:Onglet("placement")
attendu("onglet Placement visible", editeur.placement:IsShown(), true)
attendu("onglet Création caché", editeur.creation:IsShown(), false)
attendu("placement listé pour sa définition", editeur.placements[1] and editeur.placements[1]:IsShown(), true)
editeur.placements[1]:Click()
attendu("un placement peut être sélectionné", editeur.pointPose, id)
attendu("le bouton de retrait apparaît", editeur.retirer:IsShown(), true)
editeur:Hide()

dire("== retirer un placement le fait disparaître immédiatement")
attendu("retrait accepté", MJ.Retirer(id), true)
attendu("placement retiré du magasin MJ", MJ.Points("coffre_temoin")[1], nil)
attendu("placement retiré du client local", C.points[id], nil)
attendu("fenêtre du coffre refermée", coffreUI:IsShown(), false)

if ko > 0 then error(tostring(ko) .. " vérification(s) en échec") end
dire("TOUT PASSE")
