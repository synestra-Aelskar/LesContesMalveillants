-- Plusieurs métiers autorisés, bonus choisi par métier et compatibilité réseau.
local ko = 0
local function attendu(nom, obtenu, voulu)
    if tostring(obtenu) ~= tostring(voulu) then
        ko = ko + 1
        print("KO", nom, tostring(obtenu), "attendu", tostring(voulu))
    else print("ok", nom) end
end

LCM.Brouillons.Set("ressources", { id = "minerai_metiers", label = "Minerai témoin" })
__declencher("PLAYER_LOGIN")
__personnage()
local f = LCM.UI.Recoltes.Fenetre()
f:Montrer()
f:Nouveau()
local c = f.creation
c.nom:Saisir("Miner du témoin")
LCM.UI.Glisser.Commencer({ ref = "ressources/minerai_metiers",
    nom = "Minerai témoin", categorie = "ressources" })
c.ajouter.__survol = true
__souris.LeftButton = false
__avancer(0.05)
c.ajouter.__survol = nil

local function ajouterMetier(id)
    c.metier:Click()
    for _, ligne in ipairs(f.choixMetier.lignes) do
        if ligne:IsShown() and ligne.choix == id then ligne:Click() return end
    end
    attendu("métier proposé : " .. id, false, true)
end
attendu("aucun métier obligatoire au départ", #f.travail.recolte.metiers, 0)
ajouterMetier("mineur")
ajouterMetier("herboriste")
attendu("deux métiers dans l'éditeur", #f.travail.recolte.metiers, 2)
attendu("bonus actif par défaut", f.travail.recolte.metiers[1].bonus, true)
c.lignesMetiers[2].bonus:Click()
attendu("bonus herboriste désactivé", f.travail.recolte.metiers[2].bonus, false)
attendu("ligne métier sans bonus", c.lignesMetiers[2].bonus.label:GetText(), "Non")
c.dd:Saisir("10")
c.enregistrer:Click()
attendu("point enregistré", c.erreur:GetText(), "")
local def = f:Point().recolte
attendu("deux métiers sauvegardés", #def.metiers, 2)
attendu("bonus sauvegardé", def.metiers[2].bonus, false)

local R = LCM.Recolte
local paquet = R.Paquet(def, {})
paquet.i, paquet.n = f:Point().id, f:Point().label
local lu = R.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)))
attendu("deux métiers transmis", #lu.metiers, 2)
attendu("bonus transmis", lu.metiers[2].bonus, false)

__position(100, 200, 0)
-- Un point pose part tout eteint (20 octobre 2026) : on allume tout son
-- modele, ce que ce scenario recolte.
local pointId = LCM.Recoltes.Placer(f:Point().id)
LCM.Recoltes.Allumer(pointId)
attendu("point posé pour le joueur", pointId ~= nil, true)
local prise, refusPrise = R.Tenter(pointId)
attendu("récolte refusée sans métier", prise, false)
attendu("motif visible à la récolte", refusPrise, "aucun des métiers requis n'est appris.")

local ancienDes = LCM.Roll.Des
local appels = 0
LCM.Roll.Des = function() appels = appels + 1 return 7 end
local niveauBleu = LCM.Metiers.XPPourNiveau(11)
local sansMetier = { metiers = {} }
local refus, raison = R.Jet(sansMetier, lu)
attendu("sans métier autorisé : refus", refus, nil)
attendu("motif du refus", raison, "aucun des métiers requis n'est appris.")
attendu("aucun dé lancé avant le refus", appels, 0)

local mineur = { metiers = { mineur = niveauBleu } }
local jetMineur = R.Jet(mineur, lu)
attendu("bonus du mineur appliqué", jetMineur.bonus, 3)
attendu("total avec bonus", jetMineur.total, 10)
attendu("mineur retenu", jetMineur.metier, "mineur")

local herboriste = { metiers = { herboriste = niveauBleu } }
local jetHerboriste = R.Jet(herboriste, lu)
attendu("herboriste autorisé", jetHerboriste.metier, "herboriste")
attendu("son bonus désactivé", jetHerboriste.bonus, 0)
attendu("D15 brut", jetHerboriste.total, 7)

local lesDeux = { metiers = { mineur = niveauBleu, herboriste = niveauBleu } }
attendu("meilleur bonus autorisé", R.Jet(lesDeux, lu).bonus, 3)
local libre = { metiers = {}, dd = 10 }
attendu("sans restriction : dé brut", R.Jet(sansMetier, libre).bonus, 0)

local ancien = R.Lire({ i = "ancien", m = "mineur", d = 10 })
attendu("ancien point à un métier toujours lisible", R.Jet(mineur, ancien).bonus, 3)

ajouterMetier(R.METIER_AUCUN)
attendu("aucun métier apparaît comme une ligne", #f.travail.recolte.metiers, 3)
attendu("bonus inutile sur cette ligne", c.lignesMetiers[3].bonus:IsShown(), false)
c.enregistrer:Click()
local avecAucun = f:Point().recolte
attendu("option sans métier sauvegardée", avecAucun.metiers[3].id, R.METIER_AUCUN)
attendu("sans métier admis au jet brut", R.Jet(sansMetier, avecAucun).bonus, 0)
attendu("mineur conserve son bonus", R.Jet(mineur, avecAucun).bonus, 3)
local paquetLibre = R.Paquet(avecAucun, {})
paquetLibre.i = f:Point().id
local luLibre = R.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquetLibre)))
attendu("option sans métier transmise", luLibre.metiers[3].id, R.METIER_AUCUN)
LCM.Roll.Des = ancienDes

if ko == 0 then print("TOUT PASSE") else print(ko .. " ECHEC(S)") end
