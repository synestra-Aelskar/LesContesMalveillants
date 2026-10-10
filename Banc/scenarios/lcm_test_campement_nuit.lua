-- Le deroule d'un campement (10 octobre 2026) : un joueur lance, le groupe
-- accepte ou refuse, le MJ donne les unites de temps, chacun les repartit et
-- se dit pret, le responsable valide la nuit, chacun encaisse, puis les PS
-- passent du soigneur aux blesses et le surplus revient.
--
-- Le banc ne joue qu'un client : les autres sont simules en lui donnant leurs
-- messages (Reseau.Recevoir) et en lisant ce qu'on leur envoie (__envois).

local function dire(...) print(table.concat({ ... }, " ")) end
local ko = 0
local function attendu(libelle, obtenu, voulu)
    local ok = tostring(obtenu) == tostring(voulu)
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(obtenu), ok and "" or ("(attendu " .. tostring(voulu) .. ")"))
end
local function contient(libelle, texte, morceau)
    local ok = tostring(texte or ""):find(morceau, 1, true) ~= nil
    if not ok then ko = ko + 1 end
    dire(ok and "  ok  " or "  KO  ", libelle, "=", tostring(texte), ok and "" or ("(attendu « " .. morceau .. " »)"))
end

__declencher("PLAYER_LOGIN")
__personnage()
LCM._masterCompanion = true
-- On commence JOUEUR : le compagnon est la, mais en veille.
LCM.db.settings.modeJoueur = true

local K, I = LCM.Campement, LCM.Inventaire
local moi = LCM.Entities.Self()
local MOI = LCM.PlayerId()
local AMI, MJ = "Akriaxx-Apertus", "Synestra-Apertus"

local function envoye(sujet, depuis)
    for i = (depuis or 0) + 1, #__envois do
        local m = tostring(__envois[i].message or "")
        if m:find(sujet .. "|", 1, true) then return __envois[i], LCM.Reseau.Decoder(m:match("|(.*)$")) end
    end
end
local numero = 0
local function recevoir(qui, sujet, donnees)
    numero = numero + 1
    LCM.Reseau.Recevoir(qui, string.format("%d:1:1:%s|%s", numero, sujet, LCM.Reseau.Encoder(donnees or {})))
end

-- La tente de survie de la feuille : 4 lits, Fatigue +30 %, PV +30 %.
LCM.Publier(LCM.Tentes, { id = "tente_survie_l", label = "Tente de survie de Taille L", lits = 4,
    accessoiresMax = 6, bonus = { securite = -20, recup_fatigue = 30, recup_pv = 30 } })

dire("== lancer : il faut un groupe, et sa propre tente")
__groupe({})
local ok, raison = K.Lancer(nil)
attendu("seul, on ne campe pas", ok, false)
contient("     raison", raison, "en groupe")
__groupe({ AMI, MJ })
ok, raison = K.Lancer("tente_survie_l")
attendu("une tente qu'on n'a pas est refusee", ok, false)
contient("     raison", raison, "pas équipée")

dire("== la tente se porte comme un sac, sur une sacoche")
-- Elle a son registre, mais c'est un sac : on l'equipe sur un emplacement de
-- sacoche, et ses cases ne recoivent que des accessoires de camping.
I.Poser(moi, "sacs", 1, "gros_sac", true)
ok, raison = I.Poser(moi, "sacs", 2, "tentes/tente_survie_l")
attendu("pas sur un emplacement de sac", ok, false)
contient("     raison", raison, "emplacement de sacoche")
attendu("pas rangee dans un sac non plus", (I.Ranger(moi, "sacs", 1, 1, "tentes/tente_survie_l", 1)), false)
attendu("le rangement automatique l'equipe sur une sacoche", (I.Deposer(moi, "tentes/tente_survie_l", 1)), true)
local porte = K.TentesPossedees(moi)[1]
attendu("elle est equipee", porte and porte.tente.id, "tente_survie_l")
attendu("sur une sacoche", porte and porte.onglet, "saccoches")
local e = I.Emplacement(moi, porte.onglet, porte.index)
attendu("6 cases, ses accessoires max", (I.Cases(e)), 6)
ok, raison = I.Ranger(moi, porte.onglet, porte.index, 1, "objets/dague_d_assassin_du_culte", 1)
attendu("une dague n'entre pas dans une tente", ok, false)
contient("     raison", raison, "que des accessoires de camping")
attendu("un accessoire, si", I.Ranger(moi, porte.onglet, porte.index, 1, "accessoires_camping/accessoire_reparation_kalea", 1), true)
attendu("il compte comme installe", K.TentesPossedees(moi)[1].installes[1], "accessoire_reparation_kalea")
attendu("un accessoire voyage aussi dans un sac", I.Ranger(moi, "sacs", 1, 2, "accessoires_camping/accessoire_reparation_kalea", 1), true)
I.Vider(moi, "sacs", 1, 2)
-- La fenetre Inventaires la montre comme un sac : son nom et son remplissage.
LCM.UI.Menu.Trouver("inventaires").onClick()
local fi = LCM.UI.Inventaires.frame
local carteTente
for _, carte in ipairs(fi.cartes) do
    if carte.onglet == porte.onglet and carte.index == porte.index then carteTente = carte end
end
attendu("sa carte d'emplacement", carteTente and carteTente.nom:GetText(), "Tente de survie de Taille L (1/6)")
fi:Hide()

local avant = #__envois
attendu("on lance sous sa tente", K.Lancer("tente_survie_l"), true)
local msg, invite = envoye("CAMP_INVITE", avant)
attendu("l'invitation part au groupe", msg and msg.canal, "PARTY")
attendu("elle nomme la tente", invite and invite.t, "tente_survie_l")
attendu("et ce qui y est installe", invite and invite.a and invite.a[1], "accessoire_reparation_kalea")
attendu("l'armure de l'accessoire installe compte", K.BonusCamp("recup_armure"), 0.4)
attendu("le responsable campe d'office", K.Participe(), true)
attendu("les autres sont invites", K.courant.membres[AMI].statut, "invite")
attendu("un second lancement est refuse", (K.Lancer(nil)), false)

dire("== les reponses")
local id = K.courant.id
recevoir(AMI, "CAMP_REPONSE", { c = id, ok = 1 })
recevoir(MJ, "CAMP_REPONSE", { c = id, ok = 0, mj = 1 })
attendu("l'ami campe", K.courant.membres[AMI].statut, "oui")
attendu("le MJ ne campe pas", K.courant.membres[MJ].statut, "mj")
attendu("deux campeurs", #K.Participants(), 2)
recevoir(AMI, "CAMP_REPONSE", { c = "un_autre_camp", ok = 0 })
attendu("un message d'un autre camp est ignore", K.courant.membres[AMI].statut, "oui")

dire("== repartir avant les unites du MJ")
ok, raison = K.Valider()
attendu("sans unites, pas de validation", ok, false)
contient("     raison", raison, "unités de temps")
ok, raison = K.FixerUnites(22)
attendu("un joueur ne donne pas les unites", ok, false)
attendu("ni ne regle le danger", (K.ChoisirDanger("normal")), false)

dire("== le MJ donne 22 h (1320 minutes : les unites sont des minutes)")
recevoir(MJ, "CAMP_UNITES", { c = id, u = 1320 })
attendu("1320 minutes", K.courant.unites, 1320)
attendu("donnees par le MJ", K.courant.fixePar, MJ)
K.Repartir("garde", 420)
K.Repartir("reposer", 840)
ok, raison = K.Valider()
attendu("21 h / 22 h : refuse", ok, false)
contient("     raison", raison, "21 h / 22 h")

dire("== les boutons +1h / -1h")
attendu("+1h sur Prier : la derniere heure", K.Ajouter("prier", 60), true)
attendu("60 minutes posees", K.courant.heures.prier, 60)
ok, raison = K.Ajouter("prier", 60)
attendu("plus rien a repartir : refuse", ok, false)
contient("     raison", raison, "il ne reste que 0 min")
attendu("-1h la rend", K.Ajouter("prier", -60), true)
attendu("plus rien sur Prier", K.courant.heures.prier, nil)
ok, raison = K.Ajouter("prier", -60)
attendu("sous zero : refuse", ok, false)
attendu("une duree lisible", K.Duree(80) .. " | " .. K.Duree(240) .. " | " .. K.Duree(45), "1 h 20 | 4 h | 45 min")
-- Dans la fenetre : [R][-1h][-] valeur [+][+1h][M], comme les autres compteurs.
local fr = LCM.UI.Campement.Frame()
fr:Show()
fr:Rendre()
local lignePrier = fr.compteurs[#fr.compteurs].ligne
attendu("-1h juste avant le -", select(2, lignePrier.moins:GetPoint(1)) == lignePrier.moinsPas, true)
attendu("-1h juste apres R", select(2, lignePrier.moinsPas:GetPoint(1)) == lignePrier.remise, true)
attendu("+1h juste apres le +", select(2, lignePrier.plusPas:GetPoint(1)) == lignePrier.plus, true)
attendu("M apres +1h", select(2, lignePrier.maximum:GetPoint(1)) == lignePrier.plusPas, true)
attendu("libelles des pas", lignePrier.moinsPas.label:GetText() .. " " .. lignePrier.plusPas.label:GetText(), "-1h +1h")
lignePrier.plusPas:Click()
attendu("+1h clique : 60 minutes sur Prier", K.courant.heures.prier, 60)
lignePrier.moinsPas:Click()
attendu("-1h clique : rendues", K.courant.heures.prier, nil)
K.Repartir("soigner", 60)
avant = #__envois
attendu("22 h / 22 h : valide", K.Valider(), true)
local _, pret = envoye("CAMP_PRET", avant)
attendu("le pret part avec les heures", pret and pret.h and pret.h.reposer, 840)

dire("== le responsable attend tout le monde")
ok, raison = K.Conclure()
attendu("l'ami n'est pas pret : refuse", ok, false)
contient("     raison", raison, AMI)
recevoir(AMI, "CAMP_PRET", { c = id, ok = 1, h = { reposer = 1320 } })
attendu("l'ami est pret", K.courant.membres[AMI].pret, true)
K.Repartir("soigner", 0)
attendu("retoucher ses heures retire son pret", K.courant.pret, false)
K.Repartir("soigner", 60)
K.Valider()
attendu("de nouveau pret", K.courant.pret, true)

dire("== le calcul")
-- Valeurs de BANC, pas des regles : la feuille ne donne pas encore le
-- coefficient de fatigue de chaque action. On en pose un pour verifier la
-- formule ; il est retire juste apres.
local E = LCM.Equilibrage.campement
local resultat = K.Calculer(moi, K.courant.heures, K.Tente(), 2)
-- PS de la feuille : 2 x (1 x 15 + 14 x 1) x 1,3 = 75,4 -> 76. C'est le
-- chiffre de l'ecran « Campement » de la feuille, avec les memes choix.
attendu("76 PS, comme la feuille", resultat.ps, 76)
-- Fatigue : les « Impacte » de la feuille. Monter la garde 7 x -0,2, Se reposer 14 x 1,
-- Soigner 1 x -0,5 : 12,1 unites ponderees.
local max = LCM.Entities.Gauge(moi, "fatigue").max
local voulu = math.ceil(max * 0.05 * 1.3 * 12.1 - 1e-9)
attendu("fatigue = max x 0,05 x 1,3 x 12,1", resultat.fatigue, voulu)
attendu("rien ne manque", #resultat.manques, 0)
local serre = K.Calculer(moi, K.courant.heures, K.Tente(), 6)
attendu("6 campeurs pour 4 lits : -20 %", serre.fatigue, math.ceil(voulu * 0.8 - 1e-9))
-- Une nuit blanche a monter la garde COUTE de la fatigue : l'arrondi se fait
-- loin de zero, comme ARRONDI.SUP de la feuille sur une valeur negative.
local veille = K.Calculer(moi, { garde = 600 }, nil, 1)
attendu("10 de garde sans tente : perte", veille.fatigue, -math.ceil(max * 0.05 * 2 - 1e-9))
-- Les actions nouvelles de la liste du MJ n'ont pas encore de coefficient :
-- elles ne rendent rien, et le recap le dit au lieu de deviner.
local apprendre = K.Calculer(moi, { apprendre = 120, prier = 120 }, nil, 1)
attendu("prier rend (0,3 x 2)", apprendre.fatigue, math.ceil(max * 0.05 * 0.6 - 1e-9))
contient("apprendre n'a pas encore de categorie", table.concat(apprendre.manques, " / "), "Apprendre")
attendu("huit actions, dans l'ordre du MJ", E.actions[1].label .. " … " .. E.actions[#E.actions].label,
    "Se reposer … Prier")

dire("== la nuit")
LCM.Entities.SetGauge(moi, "fatigue", 0)
avant = #__envois
attendu("le responsable valide", K.Conclure(), true)
local _, fin = envoye("CAMP_FIN", avant)
attendu("la fin dit le nombre de campeurs", fin and fin.n, 2)
attendu("la fatigue est rendue", LCM.Entities.Gauge(moi, "fatigue").current, math.min(max, voulu))
attendu("76 PS a donner", K.courant.psDisponibles, 76)
attendu("on passe aux soins", K.courant.etape, "soins")

dire("== les PS")
ok, raison = K.DonnerPS(AMI, 100)
attendu("on ne donne pas ce qu'on n'a pas", ok, false)
ok, raison = K.DonnerPS(MJ, 5)
attendu("le MJ ne campe pas : refuse", ok, false)
avant = #__envois
attendu("20 PS a l'ami", K.DonnerPS(AMI, 20), true)
local chuchote, ps = envoye("CAMP_PS", avant)
attendu("en chuchotement", chuchote and chuchote.canal, "WHISPER")
attendu("a l'ami", chuchote and chuchote.cible, AMI)
attendu("20 PS", ps and ps.n, 20)
attendu("il m'en reste 56", K.courant.psDisponibles, 56)
attendu("je m'en garde 10", K.DonnerPS(MOI, 10), true)
attendu("il m'en reste 46", K.courant.psDisponibles, 46)
attendu("10 PS recus", K.PSRecus(), 10)

-- La zone la plus solide, mise a zero : la blessure vaut tout son maximum.
local partie = LCM.Body.State(moi)[1]
local blessure = partie.max
LCM.Body.SetCurrent(moi, partie.id, 0)
ok, raison = K.Soigner(partie.id, blessure + 1)
attendu("soigner plus que la blessure est refuse", ok, false)
contient("     raison", raison, string.format("ne manque que de %d PV", blessure))
-- Le panneau des soins : une ligne par campeur a qui donner, une par zone a
-- soigner. « Soigner » sans montant soigne toute la blessure, dans la limite
-- des PS recus.
local fen = LCM.UI.Campement.frame
fen:Show()
fen:Rendre()
attendu("une ligne de don par campeur", fen.blocDon.lignes[2]:IsShown() and not fen.blocDon.lignes[3]:IsShown(), true)
local ligneZone
for _, l in ipairs(fen.blocSoin.lignes) do if l:IsShown() and l.cle == partie.id then ligneZone = l end end
attendu("la zone blessee a sa ligne", ligneZone ~= nil, true)
attendu("elle montre ses PV", ligneZone and ligneZone.info:GetText(), string.format("0 / %d PV", partie.max))
-- Les memes boutons que partout : R, -, +, M. M pose tout ce qui manque (dans
-- la limite des PS recus), le bouton soigne.
ligneZone.plus:Click()
attendu("+ : un PS de plus", ligneZone.montant, 1)
ligneZone.remise:Click()
attendu("R : remis a zero", ligneZone.montant, 0)
ligneZone.maximum:Click()
attendu("M : toute la blessure", ligneZone.montant, partie.max)
attendu("affiche montant / plafond", ligneZone.chiffre:GetText(), string.format("%d / %d", partie.max, partie.max))
ligneZone.bouton:Click()
attendu("la blessure soignee", LCM.Body.State(moi)[1].current, partie.max)
attendu("le montant repart de zero", ligneZone.montant, 0)
attendu("la zone est pleine", LCM.Body.State(moi)[1].current, partie.max)
attendu("le reste des PS recus", K.PSRecus(), 10 - blessure)
attendu("le reste repart", K.RendrePS(), true)
attendu("chez moi, le soigneur", K.courant.psDisponibles, 46 + 10 - blessure)
recevoir(AMI, "CAMP_PS_RETOUR", { c = id, n = 7 })
attendu("l'ami rend 7 PS", K.courant.psDisponibles, 46 + 10 - blessure + 7)

dire("== retirer un etat avec des PS")
-- L'exemple du MJ : un etat rose vaut 6 points, il faut 12 PS pour le retirer.
LCM.Forge.Add({ id = "jeu_etats_banc", label = "Etats (banc)", categorie = "etats",
    raretes = { { id = "rose", label = "Rose", points = 6, couleur = "FF8CB8" } } })
LCM.Etats.Add({ id = "fievre_banc", label = "Fièvre", categorie = "etat", forge = "jeu_etats_banc/rose",
    bonus = { force = -1 } })
LCM.Etats.Add({ id = "malediction_banc", label = "Malédiction", categorie = "etat", bonus = { force = -1 } })
attendu("on attrape la fievre", (LCM.Etats.Placer(moi, "fievre_banc")), true)
LCM.Etats.Placer(moi, "malediction_banc")
local prix = {}
for _, e in ipairs(K.EtatsSoignables(moi)) do prix[e.element.id] = e.cout or "MJ" end
attendu("un etat rose coute 12 PS", prix.fievre_banc, 12)
attendu("sans jeu d'equilibrage, c'est le MJ", prix.malediction_banc, "MJ")
K.DonnerPS(MOI, 5)
ok, raison = K.RetirerEtat("fievre_banc")
attendu("5 PS ne suffisent pas", ok, false)
contient("     raison", raison, "coûte 12 PS, tu en as reçu 5")
K.DonnerPS(MOI, 7)
attendu("12 PS : retire", K.RetirerEtat("fievre_banc"), true)
attendu("la fievre est partie", LCM.Etats.Porte(moi, "fievre_banc"), false)
attendu("les 12 PS sont depenses", K.PSRecus(), 0)
ok, raison = K.RetirerEtat("malediction_banc")
attendu("la malediction reste au MJ", ok, false)
contient("     raison", raison, "le MJ doit le retirer")
LCM.Etats.Enlever(moi, "malediction_banc")
attendu("on quitte", K.Quitter(), true)
attendu("plus de campement", K.courant, nil)

dire("== invite : rejoindre ou refuser")
recevoir(AMI, "CAMP_INVITE", { c = "camp_ami", t = "tente_survie_l" })
attendu("une invitation arrive", K.courant and K.courant.role, "invite")
attendu("la fenetre s'ouvre", LCM.UI.Campement.frame and LCM.UI.Campement.frame:IsShown(), true)
attendu("elle propose de rejoindre", LCM.UI.Campement.frame.invitation:IsShown(), true)
avant = #__envois
attendu("on refuse", K.Repondre(false), true)
local _, refus = envoye("CAMP_REPONSE", avant)
attendu("le refus part", refus and refus.ok, 0)
attendu("plus de campement", K.courant, nil)
recevoir(AMI, "CAMP_INVITE", { c = "camp_ami2" })
attendu("on rejoint", K.Repondre(true), true)
attendu("on participe", K.Participe(), true)
local etatJoueur = LCM.UI.Campement.frame.etat:GetText()
attendu("le joueur ne voit pas la securite", tostring(etatJoueur):find("Sécurité", 1, true) == nil, true)
contient("     mais voit ses recuperations", etatJoueur, "Fatigue +0 %")
recevoir(MJ, "CAMP_UNITES", { c = "camp_ami2", u = 180 })
K.Repartir("reposer", 180)
K.Valider()
recevoir(AMI, "CAMP_FIN", { c = "camp_ami2", n = 2 })
attendu("la nuit passe chez l'invite aussi", K.courant and K.courant.etape, "soins")
-- Sans tente, pas de bonus de PV : 2 x 3 x 1.
attendu("sans tente : 2 x 3 = 6 PS", K.courant.psDisponibles, 6)
K.Quitter()

dire("== le MJ")
LCM.db.settings.modeJoueur = nil
avant = #__envois
recevoir(AMI, "CAMP_INVITE", { c = "camp_mj", t = "tente_survie_l" })
attendu("le MJ suit le campement", K.courant and K.courant.role, "mj")
local _, auto = envoye("CAMP_REPONSE", avant)
attendu("il se declare MJ", auto and auto.mj, 1)
attendu("la fenetre montre ses unites", LCM.UI.Campement.frame.mj:IsShown(), true)
contient("le MJ voit la securite", LCM.UI.Campement.frame.etat:GetText(), "Sécurité")
ok, raison = K.FixerUnites(2.5)
attendu("pas d'unites decimales", ok, false)
avant = #__envois
attendu("il donne 10 unites", K.FixerUnites(10), true)
local _, unites = envoye("CAMP_UNITES", avant)
attendu("au groupe", unites and unites.u, 10)

dire("== le risque d'embuscade, chez le MJ")
-- Proche de la ligne MJ de la feuille : deux campeurs, 22 h (1320 minutes), la
-- tente de survie (securite -20 %), 7 h de garde au total. Normal :
-- 0,05 x 22 - 0,1 x 2 - 0,1 x (-0,2) - 0,1 x 7 = 0,22.
local MIO = "Mio-Apertus"
recevoir(MIO, "CAMP_REPONSE", { c = "camp_mj", ok = 1 })
K.FixerUnites(1320)
recevoir(AMI, "CAMP_PRET", { c = "camp_mj", ok = 1, h = { garde = 420, reposer = 900 } })
recevoir(MIO, "CAMP_PRET", { c = "camp_mj", ok = 1, h = { reposer = 1320 } })
local risque = K.Embuscade()
attendu("sans danger choisi, compte Normal", risque.risque, 0.22)
contient("     et le dit", table.concat(risque.manques, " / "), "non choisi")
attendu("7 h de garde (420 minutes)", risque.garde, 420)
attendu("Normal", K.ChoisirDanger("normal"), true)
attendu("22 %", K.Embuscade().risque, 0.22)
K.ChoisirDanger("dangereux")
attendu("Dangereux : +30 points", K.Embuscade().risque, 0.52)
K.ChoisirDanger("tres_calme")
attendu("Tres calme : borne a 0", K.Embuscade().risque, 0)
-- « Aucun » force 0 %, meme sur un camp qui serait attaque sans lui.
K.ChoisirDanger("extremement_dangereux")
attendu("Extremement dangereux : 92 %", K.Embuscade().risque, 0.92)
attendu("Aucun", K.ChoisirDanger("aucun"), true)
attendu("Aucun : 0 % force", K.Embuscade().risque, 0)
attendu("Aucun est le premier choix", LCM.Equilibrage.campement.embuscade.dangers[1].label, "Aucun")
contient("la fenetre du MJ l'affiche", LCM.UI.Campement.frame.mjRisque:GetText(), "Risque d'embuscade : 0 %")
attendu("un danger inconnu est refuse", (K.ChoisirDanger("apocalypse")), false)

dire("== le jet d'embuscade : un d100 sous ou egal au risque")
-- L'exemple du MJ, transpose a 22 % : 21 et 22 attaquent, 23 sauve. Le de
-- est truque pour le banc.
K.ChoisirDanger("normal")
local vraiDe = LCM.Roll.Des
local face
LCM.Roll.Des = function(a, b) return face, a, b end
face = 21
attendu("21 sur 22 % : embuscade", K.TirerEmbuscade().attaque, true)
face = 22
attendu("22 sur 22 % : embuscade aussi", K.TirerEmbuscade().attaque, true)
face = 23
attendu("23 sur 22 % : sauves", K.TirerEmbuscade().attaque, false)
face = 5
recevoir(AMI, "CAMP_FIN", { c = "camp_mj", n = 2 })
attendu("la nuit passe : le de est tire chez le MJ", K.courant.embuscade and K.courant.embuscade.jet, 5)
contient("la fenetre du MJ le dit", LCM.UI.Campement.frame.etat:GetText(), "EMBUSCADE")
LCM.Roll.Des = vraiDe
K.Quitter()

dire("== le MJ peut lancer lui-meme")
-- Celui qui a le compagnon joue souvent aussi un personnage : le bouton de
-- lancement lui etait cache, il ne pouvait pas camper (10 octobre 2026).
K.Quitter()
local fen = LCM.UI.Campement.frame
fen:Rendre()
attendu("sans campement, le MJ voit le lancement", fen.lancement:IsShown(), true)
attendu("le MJ lance", K.Lancer(nil), true)
attendu("il est responsable", K.courant.role, "chef")
attendu("il campe", K.Participe(), true)
attendu("il donne les unites", K.FixerUnites(4), true)
attendu("il regle le danger", K.ChoisirDanger("calme"), true)
fen:Show()
fen:Rendre()
attendu("ses reglages sont la", fen.mj:IsShown(), true)
attendu("et sa repartition aussi", fen.repartition:IsShown(), true)
local _, _, _, _, yRepartition = fen.repartition:GetPoint(1)
-- -240 : sous le resume (84 + 12) et les reglages du MJ (144), mise en page
-- du 10 octobre 2026.
attendu("la repartition passe sous les reglages", yRepartition, -240)
K.Quitter()

dire("== la fenetre")
attendu("l'entree de menu est liee", LCM.UI.Menu.EstLiee("campement"), true)
attendu("une ligne par action", #LCM.UI.Campement.frame.compteurs, #E.actions)

dire(ko == 0 and "TOUT PASSE" or (ko .. " ECHEC(S)"))
