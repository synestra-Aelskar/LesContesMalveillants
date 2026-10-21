-- banc: --sans-mj
-- Interface aventurier des coffres, sans l'addon MJ.

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
__groupe({ LCM.PlayerId(), "Syn-Apertus" })
__position(50, 60, 0)
-- La distance se mesure sur TROIS axes depuis le 17 octobre 2026 : sans
-- lecture `.gps`, Coffres.Proche() ne reconnait plus rien. Le scenario posait
-- une position de carte et s'arretait la.
LCM.DeplacementForce.NoterGPS(
    "Map: 585 (Magisters' Terrace) Zone: 0 ( <unknown> ), Area: 0 ( <unknown> ), "
    .. "Phase: 158070, X: 50.000000, Y: 60.000000, Z: 0.000000, O: 1.904451")

local REF = "objets/coffre_joueur_temoin"
LCM.Objets.Add({ id = "coffre_joueur_temoin", label = "Potion du coffre", categorie = "accessoire",
    icone = "inv_potion_01", etat = { courant = 1, max = 1 }, pileMax = 10 })
local C = LCM.Coffres
local definition = { id = "coffre_externe", label = "Coffre partagé", auteur = "Syn-Apertus",
    coffre = { places = 3, verrous = 0, reset = false,
        objets = { { entree = REF, quantite = 2 } }, expertises = {}, outils = {} } }
local point = { id = "coffre_externe_1", x = 50, y = 60, z = 0, source = "gps",
    carte = LCM.Recolte.Carte() }
local paquet = C.Paquet(definition, { point })
paquet = LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet))
LCM.Objets.Retirer("coffre_joueur_temoin")
local def, points = C.Lire(paquet)
C.Connaitre(def, points, "Syn-Apertus")

attendu("définition de coffre reçue sans MJ", C.definitions.coffre_externe.label, "Coffre partagé")
attendu("objet importé sans compendium local préalable",
    LCM.Compendium.Resoudre(REF) and LCM.Compendium.Resoudre(REF).label, "Potion du coffre")
attendu("point sur la carte reconnu", C.Proche() and C.Proche().id, point.id)

C.Ouvrir(point.id)
attendu("fenêtre de consultation ouverte", LCM.UI.Coffre.frame and LCM.UI.Coffre.frame:IsShown(), true)
local envoi
for i = #__envois, 1, -1 do
    if __envois[i].message:find("cof!", 1, true) then envoi = __envois[i]; break end
end
attendu("demande transmise au MJ propriétaire", envoi and envoi.cible, "Syn-Apertus")
attendu("addon MJ absent", LCM.CoffresMJ == nil, true)

dire("== un coffre VERROUILLE, vu par le joueur distant")
-- Le defaut du 20 octobre 2026 : la fenetre s'ouvrait sur « Verrouille — 2
-- verrou(x) restant(s) » et RIEN d'autre. Pas de choix d'expertise, pas de
-- bouton pour forcer. L'etat voyage en texte : `e.f` valait la chaine « true »,
-- et l'affichage des boutons tenait a `e.f == true`, faux pour tout le monde
-- sauf le proprietaire (qui, lui, pose son etat en memoire sans passer par le
-- reseau).
local verrou = { id = "coffre_ferme", label = "Coffre solidement verrouillé.",
    auteur = "Syn-Apertus",
    coffre = { places = 3, verrous = 2, reset = false, objets = {},
        expertises = { { id = "vue", dd = 15, fatigue = 3, usureOutils = false,
            reverrouillable = false } }, outils = {} } }
local pointVerrou = { id = "coffre_ferme_1", x = 50, y = 60, z = 0, source = "gps",
    carte = LCM.Recolte.Carte() }
local paquetVerrou = LCM.Reseau.Decoder(LCM.Reseau.Encoder(C.Paquet(verrou, { pointVerrou })))
local defVerrou, pointsVerrou = C.Lire(paquetVerrou)
C.Connaitre(defVerrou, pointsVerrou, "Syn-Apertus")
attendu("les verrous ont voyagé", defVerrou.coffre.verrous, 2)
attendu("  et l'expertise qui les force", defVerrou.coffre.expertises[1]
    and defVerrou.coffre.expertises[1].id, "vue")

C.Ouvrir(pointVerrou.id)
-- Le proprietaire repond l'etat : verrouille, deux verrous restants.
local etat = { i = pointVerrou.id, f = true, s = false, v = 2, o = {}, vo = {},
    ok = true, action = "ouvrir" }
LCM.Reseau.Recevoir("Syn-Apertus",
    "1:1:1:" .. C.SUJETS.etat .. "|" .. LCM.Reseau.Encoder(etat), "CHANNEL")
local w = LCM.UI.Coffre.frame
attendu("l'état est arrivé", C.etat and C.etat.i, pointVerrou.id)
-- Un booleen doit redevenir un booleen : « false » est VRAI en Lua, et c'est
-- ce qui faisait avaler les refus du proprietaire comme des reussites.
-- Le TYPE, pas la valeur : tostring(true) et la chaine « true » se
-- ressemblent trop pour qu'une comparaison de texte prouve quoi que ce soit.
attendu("  verrouillé est un vrai booléen", type(C.etat.f), "boolean")
attendu("  ouvert aussi", type(C.etat.s), "boolean")
attendu("  et il est faux", C.etat.s == false, true)
attendu("la fenêtre le dit", w.statut:GetText():find("2 verrou", 1, true) ~= nil, true)
attendu("et elle offre de le forcer", w.forcer:IsShown(), true)
attendu("  avec le choix de l'expertise", w.choixExpertise:IsShown(), true)
attendu("  et le compte des verrous", w.forcer.label:GetText():find("2 verrou", 1, true) ~= nil, true)
attendu("le contenu reste caché tant que c'est fermé", w.grille:IsShown(), false)

dire("== une fois ouvert, le contenu se voit")
LCM.Reseau.Recevoir("Syn-Apertus", "1:1:1:" .. C.SUJETS.etat .. "|" .. LCM.Reseau.Encoder({
    i = pointVerrou.id, f = false, s = true, v = 0, o = {}, vo = {} }), "CHANNEL")
attendu("plus de bouton pour forcer", w.forcer:IsShown(), false)
attendu("et les emplacements sont là", w.grille:IsShown(), true)

if ko > 0 then error(tostring(ko) .. " vérification(s) en échec") end
dire("TOUT PASSE")
