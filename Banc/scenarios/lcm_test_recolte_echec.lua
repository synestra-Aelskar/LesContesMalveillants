-- Un jet rate ne consomme le point que si sa definition le demande.
local ko = 0
local function attendu(nom, obtenu, voulu)
    if tostring(obtenu) ~= tostring(voulu) then
        ko = ko + 1
        print("KO", nom, tostring(obtenu), "attendu", tostring(voulu))
    else print("ok", nom) end
end

LCM.Brouillons.Set("ressources", { id = "plante_echec", label = "Plante témoin" })
__declencher("PLAYER_LOGIN")
__personnage()
local R, Rs = LCM.Recolte, LCM.Recoltes
local f = LCM.UI.Recoltes.Fenetre()
f:Montrer()
f:Nouveau()
local c = f.creation
c.nom:Saisir("Couper une plante")
LCM.UI.Glisser.Commencer({ ref = "ressources/plante_echec",
    nom = "Plante témoin", categorie = "ressources" })
c.ajouter.__survol = true
__souris.LeftButton = false
__avancer(0.05)
c.ajouter.__survol = nil
c.dd:Saisir("15")
c.limite:Saisir("2")
attendu("raté gratuit par défaut", f.travail.recolte.echecConsomme, nil)
c.echecConsomme:Click()
c.enregistrer:Click()
attendu("réglage sauvegardé", f:Point().recolte.echecConsomme, true)
local def = f:Point()
local paquet = R.Paquet(def.recolte, {})
paquet.i = def.id
local lu = R.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)))
attendu("réglage transmis", lu.echecConsomme, true)

__position(100, 200, 0)
local id = Rs.Placer(def.id)
local vraiDes = LCM.Roll.Des
LCM.Roll.Des = function() return 1 end
local ok, raison = R.Tenter(id)
attendu("premier échec", ok, false)
attendu("raison indique la consommation", raison, "jet raté : une récolte a été consommée.")
attendu("une récolte consommée", Rs.Carnet(def.id)[1].usages, 1)
attendu("point toujours disponible", R.Disponible(R.points[id], def.recolte), true)
ok = R.Tenter(id)
attendu("second échec", ok, false)
attendu("deux récoltes consommées", Rs.Carnet(def.id)[1].usages, 2)
attendu("point épuisé", R.Disponible(Rs.Carnet(def.id)[1], def.recolte), false)
local carnet = Rs.Carnet(def.id)[1]
attendu("aucune ressource attribuée", carnet.consomme and carnet.consomme[1], nil)

-- Hors ligne, la perte reste locale et sera annoncee au retour du MJ.
local distant = "Syn-Apertus"
local copie = { id = "echec_distant", x = carnet.x, y = carnet.y,
    source = carnet.source, carte = carnet.carte, usages = 0 }
local definition = R.Lire(paquet)
R.Connaitre(definition, { copie }, distant)
local vraiePresence = R.EnLigne
R.EnLigne = function() return false end
ok = R.Tenter(copie.id)
attendu("échec sans MJ", ok, false)
attendu("utilisation locale perdue", R.points[copie.id].usages, 1)
attendu("échec conservé pour le MJ", R.echecs[copie.id].n, 1)
attendu("échec sauvegardé", LCM.db.recolte.echecs[copie.id].n, 1)
R.EnLigne = vraiePresence
R.Oublier(copie.id)

-- Sans l'option, le même jet laisse le compteur intact.
local libre = { id = "echec_gratuit", label = "Filon témoin", dd = 15,
    limite = 2, rayon = def.recolte.rayon, ressources = def.recolte.ressources,
    auteur = distant }
R.Connaitre(libre, { { id = "gratuit", x = carnet.x, y = carnet.y,
    source = carnet.source, carte = carnet.carte, usages = 0 } }, distant)
ok, raison = R.Tenter("gratuit")
attendu("échec gratuit", ok, false)
attendu("message de nouvelle tentative", raison, "jet raté : tu peux retenter.")
attendu("compteur intact", R.points.gratuit.usages, 0)

-- La règle reste facultative pour les anciens points et les filons.
local ancien = R.Lire({ i = "ancien", d = 15 })
attendu("ancienne définition : échec gratuit", ancien.echecConsomme, false)
LCM.Roll.Des = vraiDes
if ko == 0 then print("TOUT PASSE") else print(ko .. " ECHEC(S)") end
