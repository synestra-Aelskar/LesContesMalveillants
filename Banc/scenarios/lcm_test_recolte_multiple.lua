-- Plusieurs ressources par point : chance, quantite, regeneration et limite.
local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(nom, obtenu, voulu)
    if tostring(obtenu) ~= tostring(voulu) then
        ko = ko + 1
        dire("KO", nom, tostring(obtenu), "attendu", tostring(voulu))
    else dire("ok", nom) end
end

LCM.Brouillons.Set("ressources", { id = "fer_multiple", label = "Fer témoin" })
LCM.Brouillons.Set("ressources", { id = "caillou_multiple", label = "Caillou témoin",
    pileMax = 1 })
LCM.Brouillons.Set("sacs", { id = "sac_multiple", label = "Sac témoin", places = 12 })
__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
LCM.Inventaire.Poser(moi, "sacs", 1, "sac_multiple", true)
local R, Rs = LCM.Recolte, LCM.Recoltes
local f = LCM.UI.Recoltes.Fenetre()
f:Montrer()
f:Nouveau()
local c = f.creation
c.nom:Saisir("Miner du fer")
local function ajouter(ref)
    LCM.UI.Glisser.Commencer({ ref = ref, nom = ref, categorie = "ressources" })
    c.ajouter.__survol = true
    __souris.LeftButton = false
    __avancer(0.05)
    c.ajouter.__survol = nil
end
attendu("une seule ligne d'ajout au départ", #f.travail.recolte.ressources, 0)
ajouter("ressources/fer_multiple")
c.lignesRessources[1]:Click()
c.aleatoire:Click()
c.min:Saisir("1")
c.max:Saisir("3")
ajouter("ressources/caillou_multiple")
attendu("deux ressources dans l'éditeur", #f.travail.recolte.ressources, 2)
attendu("deux lignes compactes", c.lignesRessources[2]:GetHeight(), 28)
attendu("ligne d'ajout conservée", c.ajouter:IsShown(), true)
c.lignesRessources[2]:Click()
c.min:Saisir("2")
c.chance:Saisir("24")
c.regeneration:Click()
c.minutes:Saisir("10")
c.limite:Saisir("3")
attendu("ligne : chance du caillou", c.lignesRessources[2].chanceResume:GetText(), "24%")
c.lignesRessources[2]:Click()
attendu("second clic : réglages refermés", c.lignesRessources[2].detail:IsShown(), false)
attendu("valeurs brutes conservées", c.lignesRessources[2].repousseResume:GetText(), "10 min")
c.lignesRessources[1]:Click()
attendu("première ligne ouverte", f.ressourceOuverte, 1)
c.lignesRessources[2]:Click()
attendu("seconde ligne ouverte", f.ressourceOuverte, 2)
c.chance:Saisir("101")
c.lignesRessources[1]:Click()
c.enregistrer:Click()
attendu("erreur : ligne fautive dépliée", f.ressourceOuverte, 2)
c.chance:Saisir("24")
c.enregistrer:Click()
attendu("enregistrement valide", c.erreur:GetText(), "")
local def = f:Point()
attendu("deux ressources enregistrées", #def.recolte.ressources, 2)
attendu("chance par ressource", def.recolte.ressources[2].chance, 24)
attendu("limite en nombre de récoltes", def.recolte.limite, 3)

local paquet = R.Paquet(def.recolte, {})
paquet.i, paquet.n = def.id, def.label
local lu = R.Lire(LCM.Reseau.Decoder(LCM.Reseau.Encoder(paquet)))
attendu("règles reçues par réseau", #lu.ressources, 2)
attendu("régénération reçue", lu.ressources[2].regeneration, true)

local horloge = 1000
local vraieHeure = time
time = function() return horloge end
local vraiDes = LCM.Roll.Des
local file = {}
LCM.Roll.Des = function(a, b)
    local v = table.remove(file, 1)
    if v ~= nil then return v end
    return vraiDes(a, b)
end
__position(100, 200, 0)
local id = Rs.Placer(def.id)
attendu("point posé", id ~= nil, true)
local p = LCM.db.recoltes[id]
local function tirer(valeurs)
    file = valeurs
    local lots = Rs.Accorder(id, LCM.PlayerId())
    if lots then Rs.Confirmer(id, LCM.PlayerId()) end
    return lots
end
local lots = tirer({ 2, 50 })
attendu("fer tiré entre 1 et 3", lots[1].quantite, 2)
attendu("caillou absent quand le jet dépasse 24", #lots, 1)
attendu("point conservé après une récolte", p.statut, nil)
attendu("fer non régénérable consommé", p.consomme[1], true)
attendu("chance ratée : caillou encore disponible", R.Disponible(p, def.recolte, horloge), true)
lots = tirer({ 1, 2 })
attendu("caillou obtenu à la récolte suivante", lots[1].entree, "ressources/caillou_multiple")
attendu("quantité fixe du caillou", lots[1].quantite, 2)
attendu("deux récoltes sur trois", p.usages, 2)
attendu("caillou en régénération", R.Disponible(p, def.recolte, horloge), false)
horloge = 1600
lots = tirer({ 50 })
attendu("caillou disponible après 10 minutes", lots ~= nil, true)
attendu("prise vide si aucun drop", #lots, 0)
attendu("point épuisé à trois récoltes", p.statut, "recolte")
attendu("point retiré du terrain", Rs.Compte(def.id), 0)

-- La limite infinie conserve un point régénérable.
f:Choisir(def.id)
c.infini:Click()
attendu("case Infini règle le point", f.travail.recolte.limite, 0)
c.enregistrer:Click()
local infini = f:Point()
horloge = 3000
local id2 = Rs.Placer(infini.id)
local p2 = LCM.db.recoltes[id2]
file = { 1, 1, 2 }
local premiere = Rs.Accorder(id2, LCM.PlayerId())
Rs.Confirmer(id2, LCM.PlayerId())
attendu("point infini conservé", p2.statut, nil)
attendu("limite infinie normalisée", infini.recolte.limite, 0)

-- Une interaction reelle range les deux lots ensemble dans le sac.
local function Combien(ref)
    local n = 0
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local emplacement = LCM.Inventaire.Emplacement(moi, categorie.id, index)
            if emplacement then
                for case = 1, LCM.Inventaire.Cases(emplacement) do
                    local contenu = LCM.Inventaire.Case(emplacement, case)
                    if contenu and contenu.ref == ref then n = n + (contenu.quantite or 1) end
                end
            end
        end
    end
    return n
end
__position(200, 300, 0)
local id3 = Rs.Placer(infini.id)
file = { 2, 1, 2 }
local ok = R.Tenter(id3)
attendu("récolte multi ressource acceptée", ok, true)
attendu("fer rangé dans le sac", Combien("ressources/fer_multiple"), 2)
attendu("caillou rangé dans le sac", Combien("ressources/caillou_multiple"), 2)
attendu("point infini présent après réception", LCM.db.recoltes[id3].statut, nil)

-- Le retrait peut arriver avant la réponse du MJ distant. La réponse doit
-- encore être attribuée à son auteur et les deux lots doivent être rangés.
__groupe({ LCM.PlayerId(), "Syn-Apertus" })
local distante = { id = "distant_multiple", label = "Gisement distant",
    entree = "ressources/fer_multiple", min = 1, max = 1, dd = 0, rayon = 3,
    limite = 2, ressources = {
        { entree = "ressources/fer_multiple", min = 1, max = 1, chance = 100 },
        { entree = "ressources/caillou_multiple", min = 2, max = 2, chance = 100 },
    } }
R.Connaitre(distante, { { id = "rem_multi", x = 400, y = 500, z = 0,
    carte = R.Carte(), source = "monde" } }, "Syn-Apertus")
__position(400, 500, 0)
attendu("prise distante demandée", R.Tenter("rem_multi"), true)
local function recevoir(sujet, donnees)
    LCM.Reseau.Recevoir("Syn-Apertus", "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end
recevoir(R.SUJETS.retrait, { i = "rem_multi" })
local ferAvant, pierreAvant = Combien("ressources/fer_multiple"), Combien("ressources/caillou_multiple")
recevoir(R.SUJETS.reponse, { i = "rem_multi", q = 0, l = {
    { entree = "ressources/fer_multiple", quantite = 1 },
    { entree = "ressources/caillou_multiple", quantite = 2 },
} })
attendu("fer distant reçu", Combien("ressources/fer_multiple"), ferAvant + 1)
attendu("caillou distant reçu", Combien("ressources/caillou_multiple"), pierreAvant + 2)
ferAvant = Combien("ressources/fer_multiple")
local range = R.Recevoir("essai_sac_plein", {
    { entree = "ressources/fer_multiple", quantite = 1 },
    { entree = "ressources/caillou_multiple", quantite = 100000 },
}, nil, distante.id)
attendu("sac insuffisant : prise refusée", range, false)
attendu("aucun lot partiel rangé", Combien("ressources/fer_multiple"), ferAvant)

LCM.Roll.Des, time = vraiDes, vraieHeure
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
