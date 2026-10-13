-- Les points de recolte (13 octobre 2026).
--
-- Le MJ cree « Miner du fer » (ressource, quantite, metier, DD, rayon), puis le
-- pose en marchant : un clic, un point, a sa position. Un aventurier qui se
-- tient dessus voit « Recolter », lance D15 + metier contre le DD et, s'il
-- reussit, recoit sa part ; le point disparait pour tout le monde. Les joueurs
-- n'ont rien dans leur addon : ils demandent, le MJ repond et arbitre.
--
-- Contenu TEMOIN : une ressource et un sac d'essai, jamais ceux de la campagne.

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu),
        ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end

LCM.Brouillons.Set("ressources", { id = "minerai_temoin", label = "Minerai témoin", icone = "inv_ore_iron_01" })
LCM.Brouillons.Set("sacs", { id = "sac_temoin", label = "Sac témoin", places = 12, icone = "inv_misc_bag_30" })
__declencher("PLAYER_LOGIN")
__personnage()
local moi = LCM.Entities.Self()
LCM.Inventaire.Poser(moi, "sacs", 1, "sac_temoin", true)
LCM.Metiers.Gagner(moi, "mineur", LCM.Metiers.XPPourNiveau(6))
local BONUS = LCM.Metiers.Bonus(moi, "mineur")
local MOI = LCM.PlayerId()
__groupe({ MOI, "Syn-Apertus", "Claydenn-Apertus" })

local REF = "ressources/minerai_temoin"
local R, Rs = LCM.Recolte, LCM.Recoltes

-- Les des sont pipes : chaque appel prend la valeur suivante de la file.
local vraiDes = LCM.Roll.Des
local file = {}
LCM.Roll.Des = function(a, b)
    local v = table.remove(file, 1)
    if v == nil then return vraiDes(a, b) end
    return v, a, b
end

local function Combien(ref)
    local n = 0
    for _, categorie in ipairs(LCM.Inventaire.categories) do
        for index = 1, LCM.Inventaire.Capacite(categorie.id) do
            local e = LCM.Inventaire.Emplacement(moi, categorie.id, index)
            if e then
                local total = LCM.Inventaire.Cases(e)
                for case = 1, total do
                    local c = LCM.Inventaire.Case(e, case)
                    if c and c.ref == ref then n = n + (tonumber(c.quantite) or 1) end
                end
            end
        end
    end
    return n
end

-- Le dernier envoi d'un sujet, recolle et decode.
local function DernierEnvoi(sujet)
    for i = #__envois, 1, -1 do
        local e = __envois[i]
        local corps = e.message:match("^%d+:%d+:%d+:(.*)$")
        if corps and corps:sub(1, #sujet + 1) == sujet .. "|" then
            return e, LCM.Reseau.Decoder(corps:sub(#sujet + 2))
        end
    end
end

local function Recevoir(expediteur, sujet, donnees)
    return LCM.Reseau.Recevoir(expediteur, "1:1:1:" .. sujet .. "|" .. LCM.Reseau.Encoder(donnees))
end

dire("== l'entrée « Ressources » du menu ouvre la nouvelle fenêtre")
LCM.UI.Menu.Trouver("ressources").onClick()
local f = LCM.UI.Recoltes.frame
attendu("ouverte", f and f:IsShown(), true)
attendu("sur la création", f.creation:IsShown(), true)
attendu("  le placement est caché", f.placement:IsShown(), false)
local c = f.creation

dire("== un refus dit pourquoi")
f:Nouveau()
c.enregistrer:Click()
attendu("pas de nom", c.erreur:GetText(), "donne un nom au point de récolte.")
c.nom:Saisir("Miner du témoin")
c.enregistrer:Click()
attendu("pas de ressource", c.erreur:GetText(), "choisis la ressource que le point donne.")

dire("== uniquement des ressources")
-- Un point de recolte ne donne pas d'objet ni de tente : la liste ne propose
-- que la categorie Ressources, et la case refuse le reste (13 octobre 2026).
c.entree:Click()
local seulesRessources, temoinPropose, intertitre = true, false, false
for _, ligne in ipairs(f.choixEntree.lignes) do
    if ligne:IsShown() then
        if not tostring(ligne.choix):match("^ressources/") then seulesRessources = false end
        if ligne.choix == REF then temoinPropose = true end
    end
end
for _, t in ipairs(f.choixEntree.intertitres) do if t:IsShown() then intertitre = true end end
f.choixEntree:Hide()
attendu("la liste ne propose que des ressources", seulesRessources, true)
attendu("  dont la ressource témoin", temoinPropose, true)
attendu("  sans intertitre de famille", intertitre, false)
LCM.UI.Glisser.Commencer({ ref = "sacs/sac_temoin", nom = "Sac témoin", categorie = "sacs" })
c.entree.__survol = true
__souris.LeftButton = false
__avancer(0.05)
c.entree.__survol = nil
attendu("un sac lâché sur la case est refusé", f.travail.recolte.entree, "")

dire("== la ressource se glisse depuis le compendium")
LCM.UI.Glisser.Commencer({ ref = REF, nom = "Minerai témoin", categorie = "ressources" })
c.entree.__survol = true
__souris.LeftButton = false
__avancer(0.05)
c.entree.__survol = nil
attendu("elle est retenue", f.travail.recolte.entree, REF)
attendu("  et la case la nomme", c.entree.label:GetText(), "Minerai témoin")

dire("== quantité aléatoire, métier, DD, rayon")
c.aleatoire:Click()
attendu("le maximum apparaît", c.max:IsShown(), true)
c.min:Saisir("4")
c.max:Saisir("2")
c.enregistrer:Click()
attendu("max sous le min : refusé", c.erreur:GetText(),
    "le maximum doit être un entier, au moins égal au minimum.")
c.min:Saisir("2")
c.max:Saisir("4")
c.metier:Click()
local choixMineur
for _, ligne in ipairs(f.choixMetier.lignes) do
    if ligne:IsShown() and ligne.choix == "mineur" then choixMineur = ligne end
end
attendu("le mineur est proposé", choixMineur ~= nil, true)
if choixMineur then choixMineur:Click() end
c.dd:Saisir("10")
c.rayon:Saisir("500")
c.enregistrer:Click()
attendu("un rayon démesuré est refusé", c.erreur:GetText(),
    string.format("le rayon doit être entre 0 et %d yards.", LCM.Equilibrage.recolte.rayonMax))
c.rayon:Saisir("3")
c.enregistrer:Click()
attendu("enregistré", c.erreur:GetText(), "")
local def = f:Point()
attendu("le point existe", def and def.label, "Miner du témoin")
attendu("  nature ressource", def and def.nature, "ressource")
attendu("  quantité 2 à 4", def and (def.recolte.min .. "-" .. def.recolte.max), "2-4")
attendu("  métier", def and def.recolte.metier, "mineur")
attendu("  DD", def and def.recolte.dd, 10)
attendu("  rayon", def and def.recolte.rayon, 3)

dire("== le placeur : un clic, un point, à ma position")
f:Onglet("placement")
local p = f.placement
attendu("le placement est montré", p:IsShown(), true)
attendu("le titre est la ressource choisie", p.titre:GetText(), "Miner du témoin")
attendu("aucun point au départ", p.vide:IsShown(), true)
__position(100, 200, 0)
local avant = #__envois
p.poser:Click()
__position(140, 200, 0)
p.poser:Click()
__position(180, 260, 0)
p.poser:Click()
attendu("trois points posés", Rs.Compte(def.id), 3)
-- « disponible(s) » : depuis les statuts (Créé / En attente / Récolté), le
-- carnet garde aussi les points récoltés, et les compte à part.
attendu("tous listés", p.compte:GetText(), "3 disponible(s)")
attendu("  trois lignes", p.lignes[3] and p.lignes[3]:IsShown(), true)
attendu("le plus récent en tête", p.lignes[1].texte:GetText():match("^#3") ~= nil, true)
attendu("  à sa position", p.lignes[1].texte:GetText():find("180.0, 260.0", 1, true) ~= nil, true)
attendu("chaque pose est diffusée au groupe", #__envois > avant, true)
local envoi, paquet = DernierEnvoi(R.SUJETS.definition)
attendu("  avec ses trois points", paquet and #R.Deplier(paquet.p), 3)
attendu("  jamais au-delà de 255 octets", __plusGrosEnvoi() <= 255, true)
attendu("la liste de gauche compte les points", f.lignes[1].label:GetText():find("(3)", 1, true) ~= nil, true)

dire("== loin de tout point, pas de bouton")
__position(0, 0, 0)
__avancer(0.3)
local bouton = LCM.UI.Recolte.bouton
attendu("rien n'apparaît", bouton == nil or not bouton:IsShown(), true)

dire("== sur un point (à 2 yards), le bouton apparaît")
__position(101, 201.5, 0)
__avancer(0.3)
bouton = LCM.UI.Recolte.bouton
attendu("« Récolter »", bouton and bouton:IsShown(), true)
attendu("  avec le nom du point", bouton and bouton.nom:GetText(), "Miner du témoin")

dire("== jet raté : rien ne bouge, on peut retenter")
file = { 0 }
local chats = #__chats
bouton:Click()
attendu("le point reste", Rs.Compte(def.id), 3)
attendu("rien dans le sac", Combien(REF), 0)
attendu("le jet est annoncé", #__chats > chats, true)
attendu("  raté", tostring(__chats[#__chats] and __chats[#__chats].texte):find("raté", 1, true) ~= nil, true)

dire("== jet réussi : le MJ tire la quantité, le point disparaît")
file = { 10 - BONUS, 3 }
bouton:Click()
attendu("trois minerais dans le sac", Combien(REF), 3)
attendu("le point a disparu", Rs.Compte(def.id), 2)
attendu("  la liste le suit", p.compte:GetText(), "2 disponible(s), 1 récolté(s)")
attendu("  le point récolté reste au carnet", #LCM.Recoltes.Carnet(def.id), 3)
local _, retrait = DernierEnvoi(R.SUJETS.retrait)
attendu("le retrait est annoncé au groupe", retrait and retrait.i ~= nil, true)
__avancer(0.3)
attendu("le bouton s'efface", bouton:IsShown(), false)

dire("== un joueur demande : le MJ répond en silence, à lui seul")
avant = #__envois
Recevoir("Claydenn-Apertus", R.SUJETS.demande, {})
envoi, paquet = DernierEnvoi(R.SUJETS.definition)
attendu("une définition lui part", #__envois > avant, true)
attendu("  en chuchotement", envoi and envoi.canal, "WHISPER")
attendu("  à lui", envoi and envoi.cible, "Claydenn-Apertus")
attendu("  avec les deux points restants", paquet and #R.Deplier(paquet.p), 2)
attendu("  la ressource", paquet and paquet.e, REF)
attendu("  le DD", paquet and tostring(paquet.d), "10")

dire("== un joueur réussit : le MJ arbitre")
local restant = Rs.Points(def.id)[1].id
file = { 4 }
Recevoir("Claydenn-Apertus", R.SUJETS.prendre, { i = restant })
envoi, paquet = DernierEnvoi(R.SUJETS.reponse)
attendu("réponse chuchotée au joueur", envoi and envoi.cible, "Claydenn-Apertus")
attendu("  sa quantité", paquet and tostring(paquet.q), "4")
attendu("  sa ressource", paquet and paquet.e, REF)
attendu("le point est retiré", Rs.Compte(def.id), 1)
Recevoir("Syn-Apertus", R.SUJETS.prendre, { i = restant })
envoi, paquet = DernierEnvoi(R.SUJETS.reponse)
attendu("le même point une seconde fois : refusé", paquet and paquet.q, nil)
attendu("  et on dit pourquoi", paquet and paquet.n, "ce point a déjà été récolté.")
attendu("accordé, il est en attente chez le MJ", LCM.db.recoltes[restant].statut, "attente")
attendu("  au nom du joueur", LCM.db.recoltes[restant].par, "Claydenn-Apertus")
Recevoir("Syn-Apertus", R.SUJETS.rendre, { i = restant })
attendu("un autre ne peut pas le rendre", LCM.db.recoltes[restant].statut, "attente")
Recevoir("Claydenn-Apertus", R.SUJETS.rendre, { i = restant })
attendu("sac plein chez le joueur : le point revient", Rs.Compte(def.id), 2)
attendu("  à l'état créé", LCM.db.recoltes[restant].statut, nil)
file = { 2 }
Recevoir("Claydenn-Apertus", R.SUJETS.prendre, { i = restant })
Recevoir("Syn-Apertus", R.SUJETS.confirmer, { i = restant })
attendu("un autre ne peut pas confirmer", LCM.db.recoltes[restant].statut, "attente")
attendu("le carnet le montre en attente", (function()
    f:Afficher()
    return p.compte:GetText()
end)(), "1 disponible(s), 1 en attente, 1 récolté(s)")
Recevoir("Claydenn-Apertus", R.SUJETS.confirmer, { i = restant })
attendu("le joueur confirme : récolté", LCM.db.recoltes[restant].statut, "recolte")
-- On le rend au carnet pour la suite du scenario, qui compte deux points.
LCM.db.recoltes[restant].statut, LCM.db.recoltes[restant].par = nil, nil
Rs.Reconstruire()

dire("== côté aventurier : les points d'un autre MJ")
-- Un point porte toujours sa carte : sans elle, il ne se mesure nulle part.
-- Un second MJ du groupe pose « Cueillir » : on recoit, on marche, on demande.
Recevoir("Syn-Apertus", R.SUJETS.definition, R.Paquet({
    id = "def_distante", label = "Cueillir", entree = REF, min = 1, max = 1,
    metier = nil, dd = 0, rayon = 4,
}, { { id = "rd1", x = 500, y = 500, source = "monde", carte = R.Carte() },
     { id = "rd2", x = 520, y = 500, source = "monde", carte = R.Carte() } }))
attendu("deux points reçus", R.points.rd1 ~= nil and R.points.rd2 ~= nil, true)
attendu("  leur auteur est retenu", R.definitions.def_distante.auteur, "Syn-Apertus")
__position(503, 500, 0)
__avancer(0.3)
attendu("le bouton nomme le point", bouton:IsShown() and bouton.nom:GetText(), "Cueillir")
chats = #__chats
bouton:Click()
envoi, paquet = DernierEnvoi(R.SUJETS.prendre)
attendu("sans métier ni DD : pas de jet", #__chats, chats)
attendu("la prise est demandée à son MJ", envoi and envoi.cible, "Syn-Apertus")
attendu("  pour ce point", paquet and paquet.i, "rd1")
local avantMinerai = Combien(REF)
Recevoir("Claydenn-Apertus", R.SUJETS.reponse, { i = "rd1", q = 9, e = REF })
attendu("une réponse d'un autre que son MJ est ignorée", Combien(REF), avantMinerai)
Recevoir("Syn-Apertus", R.SUJETS.reponse, { i = "rd1", q = 2, e = REF })
attendu("sa part arrive dans le sac", Combien(REF), avantMinerai + 2)
attendu("le point est oublié", R.points.rd1, nil)

dire("== seul l'auteur retire un point")
Recevoir("Claydenn-Apertus", R.SUJETS.retrait, { i = "rd2" })
attendu("un autre ne peut pas", R.points.rd2 ~= nil, true)
Recevoir("Syn-Apertus", R.SUJETS.retrait, { i = "rd2" })
attendu("son auteur, si", R.points.rd2, nil)

dire("== une autre source de position ne se mélange pas")
Recevoir("Syn-Apertus", R.SUJETS.definition, R.Paquet({
    id = "def_gps", label = "Pêcher", entree = REF, min = 1, max = 1, dd = 0, rayon = 4,
}, { { id = "rg1", x = 0, y = 0, source = "gps", carte = R.Carte() } }))
__position(0, 0, 0)
__avancer(0.3)
attendu("un point posé au .gps ne se mesure pas au monde", bouton:IsShown(), false)

dire("== supprimer la définition emporte ses points")
f:Onglet("creation")
f:Choisir(def.id)
f.supprimer:Click()
f.confirmation.oui:Click()
attendu("plus de point posé", Rs.Compte(def.id), 0)
attendu("plus rien à récolter chez soi", (function()
    for _, pt in pairs(R.points) do if pt.def == def.id then return false end end
    return true
end)(), true)

LCM.Roll.Des = vraiDes
dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
